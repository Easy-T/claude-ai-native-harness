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
witness() { local f; for f in state.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv skills/ui-design/design.md opencode-harness/skill/ui-design/design.md agents/explore-strict.md settings.example.json setup/doctor.sh skills/start-rpi-cycle/SKILL.md setup/verify-setup.sh hooks/surface-model-policy.sh; do
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
  for d in hooks setup skills agents commands workflows; do   # workflows: seal #45 C12 conjunct가 rpi-implement.js 검사
    [ -d "$SRC/$d" ] && cp -a "$SRC/$d" "$C/$d"
  done
  mkdir -p "$C/docs/superpowers/plans"
  cp -a "$SRC/docs/superpowers/plans/." "$C/docs/superpowers/plans/" 2>/dev/null || true
  # v3: replicate opencode mirror (design.md만 — seal #43이 비교하는 유일 파일) so 미러-sync seal 검증 가능.
  if [ -f "$SRC/opencode-harness/skill/ui-design/design.md" ]; then
    mkdir -p "$C/opencode-harness/skill/ui-design"
    cp -p "$SRC/opencode-harness/skill/ui-design/design.md" "$C/opencode-harness/skill/ui-design/design.md"
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
