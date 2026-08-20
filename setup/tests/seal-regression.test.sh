#!/usr/bin/env bash
# Meta-test (cycle-31, G4-a): prove verify-setup.sh drift seals actually FAIL + non-zero exit
# when drift is injected. Acceptance-tier (peer of doctor.test.sh / verify-integration.sh),
# wired into verify-all.sh STAGE 2b — NOT a hooks/tests/cases.tsv unit case
# (so this runner adds nothing to run-all's count and lives OUTSIDE verify-setup's own count —
#  those counts' SSOTs are cases.tsv and README "현재 N PASS" respectively; no numbers here).
#
# Isolation (cycle-18 / #25 blueprint): replicate the live ~/.claude subset that verify-setup
# inspects into a fresh temp $HOME, mutate ONLY the replica, then run the replica's own
# verify-setup.sh under HOME=<replica>. The live ~/.claude is never written — proven at the
# end via cksum witnesses on every file any mutator could touch.
set -uo pipefail
SRC="$HOME/.claude"
PASS=0; FAIL=0
ok()  { echo "✓ $1"; PASS=$((PASS+1)); }
bad() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# --- live immutability witnesses: cksum files any mutator could touch, before & after ---
witness() { local f; for f in state.json state.schema.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv hooks/tests/run-all.sh skills/ui-design/design.md opencode-harness/skill/ui-design/design.md agents/explore-strict.md agents/execute-strict.md agents/review-strict.md settings.example.json setup/doctor.sh skills/start-rpi-cycle/SKILL.md setup/verify-setup.sh hooks/surface-model-policy.sh docs/ai-context/review-yield.md docs/ai-context/cross-family-review.md docs/ai-context/model-policy.md docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md docs/ai-context/c21-orca-mode-design.md; do
              cksum "$SRC/$f" 2>/dev/null; done; }
LIVE_BEFORE="$(witness)"

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

# --- replicate the harness subset verify-setup.sh inspects (runtime dirs excluded for speed) ---
make_replica() {
  local C="$1/.claude" f d
  mkdir -p "$C"
  for f in CLAUDE.md README.md SECURITY.md settings.json settings.example.json state.json state.schema.json; do
    [ -f "$SRC/$f" ] && cp -p "$SRC/$f" "$C/$f"
  done
  for d in hooks setup skills agents commands workflows modes; do   # workflows: seal #45 C12 conjunct가 rpi-implement.js 검사 · modes: seal #51 C20 vacuous-방지 arm이 modes/*.json 검사
    [ -d "$SRC/$d" ] && cp -a "$SRC/$d" "$C/$d"
  done
  mkdir -p "$C/docs/superpowers/plans"
  cp -a "$SRC/docs/superpowers/plans/." "$C/docs/superpowers/plans/" 2>/dev/null || true
  # v3: replicate opencode mirror (design.md만 — seal #43이 비교하는 유일 파일) so 미러-sync seal 검증 가능.
  if [ -f "$SRC/opencode-harness/skill/ui-design/design.md" ]; then
    mkdir -p "$C/opencode-harness/skill/ui-design"
    cp -p "$SRC/opencode-harness/skill/ui-design/design.md" "$C/opencode-harness/skill/ui-design/design.md"
  fi
  # C18: seal #50 conjunct ③(미러 parity)이 비교하는 파일 — 미복제 시 그 conjunct 가 replica 에서
  # vacuous 가 된다(#43 design.md 복제와 동형 이유).
  if [ -f "$SRC/opencode-harness/skill/start-rpi-cycle/SKILL.md" ]; then
    mkdir -p "$C/opencode-harness/skill/start-rpi-cycle"
    cp -p "$SRC/opencode-harness/skill/start-rpi-cycle/SKILL.md" "$C/opencode-harness/skill/start-rpi-cycle/SKILL.md"
  fi
  # C19: seal #50 확장 arm(§18.3)이 검사하는 미러 create-orchestrator — 미복제 시 그 arm 이 replica
  # 에서 vacuous 가 된다(#43 design.md · C18 미러 start-rpi 복제와 동형 이유).
  if [ -f "$SRC/opencode-harness/skill/create-orchestrator-skill/SKILL.md" ]; then
    mkdir -p "$C/opencode-harness/skill/create-orchestrator-skill"
    cp -p "$SRC/opencode-harness/skill/create-orchestrator-skill/SKILL.md" "$C/opencode-harness/skill/create-orchestrator-skill/SKILL.md"
  fi
  mkdir -p "$C/docs/ai-context"   # seal #37 (GAP-005) inspects docs/ai-context/scaffold-registry.md
  cp -a "$SRC/docs/ai-context/." "$C/docs/ai-context/" 2>/dev/null || true
  rm -rf "$C/hooks/.log"   # drop runtime noise the seals never read
  chmod +x "$C/hooks/"*.sh "$C/setup/"*.sh 2>/dev/null || true  # guard cp -a +x loss on win32
}

run_replica_verify() {  # $1 = replica HOME ; echoes verify-setup output; return code = its exit
  HOME="$1" bash "$1/.claude/setup/verify-setup.sh" 2>&1
}

# === Control: an unmutated replica must PASS (seals do not false-fire on a clean copy) ===
CTRL="$ROOT/control"; mkdir -p "$CTRL"; make_replica "$CTRL"
OUT="$(run_replica_verify "$CTRL")"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q 'FAIL=0'; then
  ok "control: unmutated replica → verify-setup exit 0, FAIL=0"
else
  bad "control: replica exit=$RC (expected 0) — replica build/baseline broken. tail: $(printf '%s' "$OUT" | tail -3 | tr '\n' '|')"
fi

# === Mutant driver: build replica, apply mutator, require non-zero exit AND the seal's FAIL line ===
assert_seal_fires() {  # $1=label  $2=mutator-fn  $3=expected FAIL substring
  local label="$1" mut="$2" needle="$3"
  local h="$ROOT/mut_$label"; mkdir -p "$h"; make_replica "$h"
  "$mut" "$h/.claude"
  local out rc
  out="$(run_replica_verify "$h")"; rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qF "$needle"; then
    ok "mutant[$label]: exit=$rc (non-zero) + seal FAIL «$needle»"
  else
    bad "mutant[$label]: rc=$rc, missing «$needle». tail: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  fi
}

# Mutator 1 — seal #30 (state.json ↔ schema): corrupt cycle.count integer → string.
mut_state_count_string() { sed -i -E 's/("count":[[:space:]]*)([0-9]+)/\1"\2"/' "$1/state.json"; }
# Mutator 2 — seal #23 (settings.json ↔ example harness-hook parity): shrink a harness hook matcher.
mut_settings_matcher()   { sed -i 's/"Write|Edit|NotebookEdit"/"Write|Edit"/' "$1/settings.json"; }
# Mutator 3 — seal #20 (README cases count ↔ cases.tsv actual): drift the declared count down by 1.
mut_readme_cases() {
  local actual; actual=$(grep -vcE '^[[:space:]]*(#|$)' "$1/hooks/tests/cases.tsv")
  sed -i -E "s/${actual} (케이스|cases?)/$((actual-1)) \1/g" "$1/README.md"
}
# Mutator 4 — seal #41 (explore-strict Rule-of-Two): reader tools 에 Write 부여 → #41 FAIL.
mut_explore_write() { sed -i -E 's/^(tools:.*WebFetch.*)$/\1, Write/' "$1/agents/explore-strict.md"; }
# Mutator 5 — seal #42 (deny 최후방어선): settings.example 의 deny 규칙 블록 제거 → #42 FAIL.
mut_strip_deny() { sed -i -E '/"deny"[[:space:]]*:/,/\]/d' "$1/settings.example.json"; }
# Mutator 6 — seal #43 (opencode 미러 byte-sync): 미러만 발산(비-floor 편집) → 정본≠미러, §6 카운트 불변.
mut_mirror_drift() { printf '\n<!-- v3 seal-regression mirror-drift probe -->\n' >> "$1/opencode-harness/skill/ui-design/design.md"; }
# Mutator 7 — seal #44 (§6 floor-18): §6 첫 체크박스를 정본·미러 양쪽에서 삭제(byte-동일 유지 → #43 불감, #44만 발화).
mut_floor_shrink() {
  local F
  for F in "skills/ui-design/design.md" "opencode-harness/skill/ui-design/design.md"; do
    [ -f "$1/$F" ] || continue
    awk '/^# 6\./{d=1} /^# 7\./{d=0} d && /^- \[ \]/ && !x {x=1; next} {print}' "$1/$F" > "$1/$F.t" && mv "$1/$F.t" "$1/$F"
  done
}
# Mutator 8 — seal #46 (hooks/lib 매니페스트 디스크=SSOT): doctor 21b 목록에서 파서 하나를 빼면
#   디스크 대조가 발화해야 한다. C13 의 M1/M7(신규 파서가 매니페스트 3곳 중 2곳에서 누락) 재발 방지.
mut_doctor_lib_drop() { sed -i -E 's/(for lf in [a-z-]+ [a-z-]+ [a-z-]+ [a-z-]+) workflow-spawns;/\1;/' "$1/setup/doctor.sh"; }
# Mutator 9/10 — seal #45 conjunct ②(explore-strict frontmatter) 커버 (C14-F):
#   C13 이 세운 effort/WebSearch 앵커가 **실제로 발화하는가**를 증명한다. 종전엔 explore 대상 뮤테이터가
#   mut_explore_write(seal #41) 뿐이라 "9/0 통과"가 #45 의 발화를 증언하지 못했다.
mut_explore_effort()    { sed -i -E 's/^effort:[[:space:]]*xhigh/effort: medium/' "$1/agents/explore-strict.md"; }
mut_explore_websearch() { sed -i -E 's/^(tools:.*), WebSearch/\1/' "$1/agents/explore-strict.md"; }
# Mutator 11 — seal #48 (C14-J): skill 이 스캐폴드 산출물 경로를 지시하면서 "실재하는 것만" 선언을
#   지우면 발화해야 한다(무조건 지시로의 회귀 봉인).
mut_skill_conditional() { sed -i 's/실재하는/존재하는/g' "$1/skills/start-rpi-cycle/SKILL.md"; }
# Mutator 12/13 — 주석-마스킹 봉인 (C14 GPT 교차리뷰): seal #46/#47 이 파일 **전문** grep 이던 시절엔
#   설명 주석이 매니페스트/제외목록을 가려, 실효 라인에서 지워도 통과했다(vacuity). 이 두 뮤테이터는
#   *주석은 남기고 실효 라인만* 지우므로, 마스킹이 살아있으면 GREEN(=테스트 실패)이 된다.
mut_verify_item16_drop() { sed -i -E 's/^(for j in [a-z-]+ [a-z-]+ [a-z-]+ [a-z-]+) workflow-spawns; do/\1; do/' "$1/setup/verify-setup.sh"; }
mut_c3_exclude_drop()    { sed -i -E "s/^([[:space:]]*)explore-strict\|execute-strict\|review-strict\|'\\*'\\)/\\1execute-strict|review-strict|'*')/" "$1/hooks/surface-model-policy.sh"; }
# Mutator 14 — seal #49 (C16 §15.3): layer-yield 축적 대장을 삭제하면 발화해야 한다
#   (필드 parity 만 있고 대장이 없으면 per-layer 수율이 축적되지 않아 floor·배분 재심 데이터가 죽는다).
mut_yield_ledger_drop() { rm -f "$1/docs/ai-context/review-yield.md"; }
# Mutator 15/16 — seal #5·#45 conjunct ③ (C17 frontmatter opus): 실행자/검증자 frontmatter 를 inherit 로
# 되돌리면(Option 1 회귀 = hook "무지정=opus" 평가의 물리 전제 붕괴) #5 와 #45 가 각각 발화해야 한다.
# 기존 변이에 model 축 커버 0건 실측(C17 Phase R) — 이 변이들이 그 공백의 해소. 단언은 seal 별 분리
# (§16.8 C5 — "execute-strict model" 은 #5 만의 문자열이라 #45 결손을 못 잡는다).
mut_exec_model()   { perl -pi -e 's/^model: opus(\r?)$/model: inherit$1/' "$1/agents/execute-strict.md"; }
mut_review_model() { perl -pi -e 's/^model: opus(\r?)$/model: inherit$1/' "$1/agents/review-strict.md"; }
# Mutator 17 — seal #50 (C18 spec §17.1): start-rpi-cycle 의 FABLE-TAKEOVER 토큰이 소실되면(skill
# 재생성·문면 재작성 클래스) 발화해야 한다. §17.7-2 가 재작성 상한·골격 계약의 hook 강제를 수용
# 잔여로 둔 자리라 이 seal 이 유일한 물리 봉인 — 변이 커버가 없으면 그 봉인이 헛돈다(#49/M14 동형).
# 토큰만 치환해 conjunct ①을 단독 격리한다(다른 conjunct 는 건드리지 않음).
mut_drafting_token_drop() { perl -pi -e 's/FABLE-TAKEOVER/FABLE-HANDOVER/g' "$1/skills/start-rpi-cycle/SKILL.md"; }
# Mutator 18 — seal #50 conjunct ②(cross-family-review §2) 커버: M17 이 conjunct ① 만 격리하므로 ②는
# 변이 커버 0건이었다. 규범 문구를 **부정-반전**(위임 가능→위임 금지)해 "긍정-구절 앵커"가 실제로
# 발화하는지 증명한다 — bare '증거 수집' 토큰은 반전 후에도 잔존하므로, 이 변이는 앵커가 실물
# 긍정-구절로 확장돼 있을 때만 RED 가 된다(#3 경화의 증인).
mut_crossfamily_norm_flip() { perl -pi -e 's/증거 수집은 위임 가능/증거 수집은 위임 금지/g' "$1/docs/ai-context/cross-family-review.md"; }
# Mutator 19 — seal #49 (C16 §15.3) 마스킹 봉인: Communication Protocol 의 `layer-yield:` **필드 정의행**만
# 삭제하고 다른 언급(C18 신규 2곳)은 남긴다. bare 토큰 존재 검사였던 시절엔 그 잔존 언급이 정의행
# 삭제를 가려 GREEN 이었다(격리-사본 실험 확정) — 필드 계약이 죽어도 seal 이 침묵하는 vacuity.
mut_yield_cp_field_drop() { perl -ni -e 'print unless /^- layer-yield: \*\*고유 필수 필드\*\*/' "$1/skills/start-rpi-cycle/SKILL.md"; }
# Mutator 20 — seal #50 **부정-단언 arm** 커버 (C19 spec §18.3): C18 은 이 arm 을 변이 미커버로 남겼다
# (C18 plan :484 정직 부기). replica 정본 start-rpi-cycle 에 구 단정 '위임 X' 를 주입해 half-landing
# /롤백-혼입 클래스를 재현한다 — 긍정 토큰은 전부 살아있으므로 부정-단언 arm 만이 이 변이를 잡는다.
mut_old_assertion_revival() { printf '\n   sub-agent에 위임 X — 메인이 직접.\n' >> "$1/skills/start-rpi-cycle/SKILL.md"; }
# Mutator 21 — seal #45 conjunct ① 앵커 경화의 RED (C19 spec §18.2 #14·G4): 광역 grep 은 표적 행 삭제를,
# 행-선두 앵커는 모델-셀 변조(비고 셀의 opus 가 .* 을 타고 가림)를 각각 미탐했다(슬롯1 G4 재현).
# 열-스코프 앵커로 경화된 뒤에만 이 변이(더 미묘한 쪽 = 모델-셀 opus→sonnet 변조)가 RED 가 된다.
mut_mp_model_flip() { perl -pi -e 's/^(\| 구현 heavy [^|]*\| *execute-strict *\| *)\*\*opus\*\*/${1}**sonnet**/' "$1/docs/ai-context/model-policy.md"; }
# Mutator 22 — seal #30 스키마 골격 conjunct 의 RED (C19 spec §18.2 #13·G5): #30 의 node 검사는
# **스키마-구동**이라 required 배열을 [] 로 값-약화하면 state.json 이 무엇이든 통과한다(오라클 침묵 —
# 라인 삭제보다 강한 변이: 리터럴 존재-검사까지 함께 우회). 내용-앵커 conjunct 결합 후에만 RED.
mut_schema_required_empty() { perl -pi -e 's/"required":\s*\[[^\]]*\]/"required": []/g' "$1/state.schema.json"; }

# Mutator 23 (C21) — seal #52(경로-전달 규약)의 RED: replica 의 테스트 파일에 겹따옴표 인라인 소스 +
# 셸 변수 보간을 1건 주입한다. non-obvious #3 이 기술한 실패 형태 그 자체이며, seal 이 대상 계수만
# 하고 위반 판정을 안 하면(vacuous) GREEN 으로 새어 나간다.
# ★위반 문자열은 **런타임 조립**한다 — 소스에 `node -e "…$VAR…"` 를 리터럴로 적으면 이 파일 자신이
#   seal 스캔 대상(setup/tests/*.sh)에 걸려 **seal 이 자기 자신을 위반으로 계수**한다(C21 Gate P F1 실측:
#   리터럴형 정의행 1줄 추가 → verify-setup FAIL=1 · control replica 도 동반 오염 → assert_seal_fires
#   24건이 전부 vacuous PASS). 아래 형태는 정의행 스캔 시 VIOLATION=0, 주입 결과는 VIOLATION=1 [실측].
mut_pathpass_interp() {
  local q='"'
  printf '%s\n' "PPV=\$(mktemp -d); node -e ${q}console.log(\$PPV)${q}" >> "$1/hooks/tests/run-all.sh"
}

# Mutator 24 (C23) — seal #53 의 RED ⓐ: 대장 **밖** plan 에 격리 없는 캐리어 호출을 1건 주입한다.
# ★호출 문자열은 **런타임 조립**한다 — 소스에 리터럴로 적으면 이 파일이 스캔 대상은 아니지만
#   (코퍼스는 plans/ + docs/ai-context/) 같은 클래스의 자기-오염을 습관으로 만들지 않기 위함이다.
mut_s53_unisolated() {
  local p; p="$1/docs/superpowers/plans/c23-mutant-probe.md"
  # ★`**Status:** completed` 는 장식이 아니라 **판별력 격리**다: 이 줄이 없으면 프로브가 seal #27
  #   (plan lifecycle — `NOSTAT27`)까지 동반 발화시켜, 「exit≠0」축만 보는 독자가 #53 없이도 통과
  #   가능하다고 오해할 여지를 남긴다. 단언 자체는 #53 고유 needle 로 판정하므로 오염은 없었으나,
  #   뮤테이터는 **표적 seal 하나만** 깨우는 것이 옳다(C23 Task 7 실측 후속).
  { printf '# mutant\n\n'; printf '**Status:** completed\n\n';
    printf 'bash bin/orca-%s.sh spawn --run r --task t\n' "rpi"; printf '\n'; } > "$p"
}
# Mutator 25 (C23) — seal #53 의 RED ⓑ: 대장 파일에서 **개수를 유지한 채 치환**한다(기존 위반 1건에
# 격리 접두를 붙이고 텍스트가 다른 새 위반 1건을 추가). 개수 동결이면 6→6 이라 무발화하고,
# 호출 줄 집합 cksum 동결에서만 RED 가 된다 — 「개수가 아니라 동일성」이 load-bearing 함의 증명.
mut_s53_substitute() {
  local p; p="$1/docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md"
  perl -0777 -i -pe 's{^(bin/orca-rpi\.sh spawn --run run_x --task task_x --model opus; echo "rc=\$\?")$}{ORCA_CLI_COMMAND=/x ORCA_RPI_RUNDIR=/y $1}m' "$p"
  # ★치환 성공을 스스로 단언한다(슬롯 1 C5). 대상 줄의 공백·인자 순서가 미래에 바뀌면 치환이 0건이 되고
  #   append 만 남아 **6→7 순증**이 된다 — cksum 은 어차피 바뀌므로 테스트는 계속 PASS 하는데
  #   「개수 유지 치환을 잡는다」는 이 뮤테이터의 존재 이유만 조용히 거짓이 된다.
  grep -q 'ORCA_CLI_COMMAND=/x ORCA_RPI_RUNDIR=/y bin/orca-rpi.sh spawn' "$p" \
    || { echo "  (mut_s53_substitute: 치환 0건 — 대상 줄이 바뀌었다. 개수-유지 변이를 만들지 못했다)"; return 1; }
  { printf '\n'; printf 'bash bin/orca-%s.sh gate create --task t9 --question q9\n' "rpi"; printf '\n'; } >> "$p"
}

# Mutator 26 (C23) — seal #53 의 RED ⓒ **커맨드-위치**: 캐리어가 줄의 첫 실토큰이 **아닌** 형태.
# M24/M25 는 둘 다 맨 `bash bin/orca-rpi.sh …` 리터럴이라, 탐지자가 첫 세그먼트만 재도 전건 GREEN 이었다
# (실측: 정정 전 코드에서 이 프로브는 출력 0줄 = 침묵 미탐). cycle-37 install/rsync 앵커와 동형으로
# **모든 커맨드 위치**를 재야만 RED 가 된다.
# ★`**Status:** completed` 는 판별력 격리(M24 와 동일 이유 — seal #27 공발화 차단).
mut_s53_cmdpos() {
  local p; p="$1/docs/superpowers/plans/c23-cmdpos-probe.md"
  { printf '# mutant\n\n'; printf '**Status:** completed\n\n';
    printf 'cd /tmp && bash bin/orca-%s.sh run --objective x\n' "rpi"; printf '\n'; } > "$p"
}
# Mutator 27 (C23) — seal #53 의 RED ⓓ **변수-간접 경로**: `bash "$CARRIER" <sub>` 하우스 스타일.
# 리터럴 경로 정규식만으로는 따옴표를 벗겨도 토큰이 `$CARRIER` 라 탈락한다(정정 전 실측 출력 0줄).
# ★이 프로브에는 캐리어 경로 리터럴이 **한 글자도 없다** — 경로 아암이 살아 있어도 잡히지 않으므로,
#   변수-간접 아암이 실재할 때만 RED 가 된다(아암 격리).
mut_s53_varindirect() {
  local p; p="$1/docs/superpowers/plans/c23-varindirect-probe.md"
  { printf '# mutant\n\n'; printf '**Status:** completed\n\n';
    printf 'bash "$CARRIER" %s --run r --task t\n' "spawn"; printf '\n'; } > "$p"
}

assert_seal_fires "state_schema"    mut_state_count_string "state.json schema 위반"
assert_seal_fires "settings_parity" mut_settings_matcher   "settings/example harness-hook drift"
assert_seal_fires "readme_cases"    mut_readme_cases       "README cases drift"
assert_seal_fires "explore_rule_of_two" mut_explore_write   "explore-strict Rule-of-Two 위반"
assert_seal_fires "deny_last_line"      mut_strip_deny      "deny 최후방어선 부재"
assert_seal_fires "mirror_sync"     mut_mirror_drift       "opencode 미러 design.md drift"
assert_seal_fires "floor_18"        mut_floor_shrink       "§6 floor 카운트 drift"
assert_seal_fires "lib_manifest"    mut_doctor_lib_drop    "hooks/lib 매니페스트 drift"
assert_seal_fires "explore_effort"    mut_explore_effort     "역할×모델 매트릭스 봉인 붕괴"
assert_seal_fires "explore_websearch" mut_explore_websearch  "역할×모델 매트릭스 봉인 붕괴"
assert_seal_fires "skill_conditional" mut_skill_conditional  "skill context_paths 무조건 지시"
assert_seal_fires "verify_item16_drop" mut_verify_item16_drop "hooks/lib 매니페스트 drift"
assert_seal_fires "c3_exclude_drop"    mut_c3_exclude_drop    "Rule C3 제외목록 drift"
assert_seal_fires "seal49_ledger_missing" mut_yield_ledger_drop "layer-yield drift"
assert_seal_fires "exec_fm_model_s5"    mut_exec_model    "execute-strict model"
assert_seal_fires "exec_fm_model_s45"   mut_exec_model    "역할×모델 매트릭스 봉인 붕괴"
assert_seal_fires "review_fm_model_s5"  mut_review_model  "review-strict model"
assert_seal_fires "review_fm_model_s45" mut_review_model  "역할×모델 매트릭스 봉인 붕괴"
assert_seal_fires "drafting_delegation_token" mut_drafting_token_drop "집필-위임 규약 토큰 drift"
assert_seal_fires "crossfamily_norm_flip"     mut_crossfamily_norm_flip "집필-위임 규약 토큰 drift"
assert_seal_fires "yield_cp_field_drop"       mut_yield_cp_field_drop   "layer-yield drift"
assert_seal_fires "old_assertion_revival" mut_old_assertion_revival "집필-위임 규약 토큰 drift"
assert_seal_fires "mp_model_flip"        mut_mp_model_flip        "역할×모델 매트릭스 봉인 붕괴"
assert_seal_fires "schema_required_empty" mut_schema_required_empty "state.json schema 위반"
assert_seal_fires "pathpass_interp"       mut_pathpass_interp       "경로-전달 규약 위반"
assert_seal_fires "s53_unisolated"  mut_s53_unisolated  "부작용-차단 주입 누락"
assert_seal_fires "s53_substitute"  mut_s53_substitute  "1회성 예외 대장 drift"
assert_seal_fires "s53_cmdpos"      mut_s53_cmdpos      "부작용-차단 주입 누락"
assert_seal_fires "s53_varindirect" mut_s53_varindirect "부작용-차단 주입 누락"

# === Live immutability: witnessed files byte-identical (all mutation stayed in replicas) ===
LIVE_AFTER="$(witness)"
if [ "$LIVE_BEFORE" = "$LIVE_AFTER" ]; then
  ok "live ~/.claude untouched (witness cksum stable across run)"
else
  bad "live ~/.claude MUTATED during run — isolation breach"
fi

echo
echo "seal-regression: PASS=$PASS FAIL=$FAIL"
exit $FAIL
