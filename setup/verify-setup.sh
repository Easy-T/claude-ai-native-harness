#!/usr/bin/env bash
set -uo pipefail
PASS=0
FAIL=0
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }
ok()   { echo "✓ $1"; PASS=$((PASS+1)); }

# 1. CLAUDE.md exists + ≤200 lines
L=$(wc -l < "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo 9999)
[ -f "$HOME/.claude/CLAUDE.md" ] && [ "$L" -le 200 ] && ok "CLAUDE.md exists, $L lines" || fail "CLAUDE.md size $L"

# 2. 8 meta rule markers
R=$(grep -c '^## §[1-8]\.' "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo 0)
[ "$R" -eq 8 ] && ok "8 meta rules present" || fail "meta rules=$R"

# 3. 3 wrapper agents
for a in explore-strict review-strict execute-strict; do
  [ -f "$HOME/.claude/agents/$a.md" ] && ok "agent: $a" || fail "agent missing: $a"
done

# 4. agents have skills:[common-agent-contract]
for a in explore-strict review-strict execute-strict; do
  grep -q 'common-agent-contract' "$HOME/.claude/agents/$a.md" 2>/dev/null && ok "$a has contract" || fail "$a missing contract"
done

# 5. agents model:inherit
for a in explore-strict review-strict execute-strict; do
  grep -q '^model: inherit$' "$HOME/.claude/agents/$a.md" 2>/dev/null && ok "$a model:inherit" || fail "$a model"
done

# 6. 7 tracked global skills (grill-with-docs는 doctor가 upstream에서 auto-install → gitignore라 제외)
for s in common-agent-contract create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle improve-codebase-architecture ui-design; do
  [ -f "$HOME/.claude/skills/$s/SKILL.md" ] && ok "skill: $s" || fail "skill missing: $s"
done

# 7. orchestrator marker triple (위 7개 중 common-agent-contract는 contract라 마커 없음 — opt-out, 그래서 6개 검사)
for s in create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle improve-codebase-architecture ui-design; do
  f="$HOME/.claude/skills/$s/SKILL.md"
  if grep -q '^orchestrator_skill: true$' "$f" 2>/dev/null \
    && grep -q '^generated_by:' "$f" 2>/dev/null \
    && grep -q '^orchestrator_version:' "$f" 2>/dev/null; then
    ok "$s marker triple"
  else
    fail "$s missing marker triple"
  fi
done

# 8. 10 hook scripts executable
for h in enforce-orchestrator stable-claude-md auto-compact-watch enforce-rpi-cycle enforce-rpi-bash enforce-secret-scan verify-loop-watch session-start-audit surface-constitution worktree-teardown; do
  [ -x "$HOME/.claude/hooks/$h.sh" ] && ok "hook: $h" || fail "hook missing or non-executable: $h"
done

# 9. _common.sh exists
[ -f "$HOME/.claude/hooks/_common.sh" ] && ok "_common.sh" || fail "_common.sh missing"

# 10. /init-ai-ready command
[ -f "$HOME/.claude/commands/init-ai-ready.md" ] && ok "command: init-ai-ready" || fail "command missing"

# 11. 13 templates + 2 references
T=$(find "$HOME/.claude/skills/init-ai-ready-project/templates/" -maxdepth 1 -type f 2>/dev/null | wc -l)
R=$(find "$HOME/.claude/skills/init-ai-ready-project/references/" -maxdepth 1 -type f 2>/dev/null | wc -l)
[ "$T" -ge 13 ] && [ "$R" -ge 2 ] && ok "templates=$T, refs=$R" || fail "templates=$T (need 13), refs=$R"
# 11b. PR lifecycle templates specifically
[ -f "$HOME/.claude/skills/init-ai-ready-project/templates/scripts-check.sh.tpl" ] \
  && ok "template: scripts-check.sh.tpl" || fail "template missing: scripts-check.sh.tpl"
[ -f "$HOME/.claude/skills/init-ai-ready-project/templates/github-ci.yml.tpl" ] \
  && ok "template: github-ci.yml.tpl" || fail "template missing: github-ci.yml.tpl"

# 11c. runbook.md.tpl has PR lifecycle sections
grep -q 'Local Quality Gate' "$HOME/.claude/skills/init-ai-ready-project/templates/runbook.md.tpl" 2>/dev/null \
  && ok "runbook.tpl: Local Quality Gate" || fail "runbook.tpl missing: Local Quality Gate"
grep -q 'Merge Policy' "$HOME/.claude/skills/init-ai-ready-project/templates/runbook.md.tpl" 2>/dev/null \
  && ok "runbook.tpl: Merge Policy" || fail "runbook.tpl missing: Merge Policy"
grep -q 'AI는 merge를 결정하지 않는다' "$HOME/.claude/skills/init-ai-ready-project/templates/runbook.md.tpl" 2>/dev/null \
  && ok "runbook.tpl: merge policy principle" || fail "runbook.tpl missing merge policy principle"

# 12. setup scripts executable
for s in doctor.sh verify-setup.sh verify-integration.sh verify-all.sh; do
  [ -x "$HOME/.claude/setup/$s" ] && ok "setup: $s" || fail "setup missing: $s"
done

# 13. .installed marker
[ -f "$HOME/.claude/setup/.installed" ] && ok ".installed marker" || fail ".installed missing"

# 14. settings.json has >=9 hook command entries (실측 11: 5 PreToolUse W|E|N + 2 Bash + 1 PostToolUse + 1 SessionStart + 1 Stop + 1 SessionEnd — >=9는 하한 게이트)
COUNT=$(node -e '
  const cfg = JSON.parse(require("fs").readFileSync(process.env.HOME + "/.claude/settings.json", "utf8"));
  const all = [];
  for (const phase of Object.values(cfg.hooks||{})) for (const e of phase) for (const h of (e.hooks||[])) all.push(h.command);
  console.log(all.filter(c => /\.claude\/hooks\/.*\.sh/.test(c)).length);
' 2>/dev/null || echo 0)
[ "$COUNT" -ge 9 ] && ok "settings.json: $COUNT hooks" || fail "settings.json hooks=$COUNT"

# 15. SECURITY.md threat-model doc exists
[ -f "$HOME/.claude/SECURITY.md" ] && ok "SECURITY.md" || fail "SECURITY.md missing"

# 16. hooks/lib extracted parsers (load-bearing — hooks fail-open silently if missing)
for j in redirect-targets skeleton-scan transcript-usage model-window; do
  [ -f "$HOME/.claude/hooks/lib/$j.js" ] && ok "lib: $j" || fail "hooks/lib/$j.js missing"
done

# 17. RPI phase vocabulary: CLAUDE.md §3 must name every tool start-rpi-cycle Phase R names.
#     content drift guard — skill body = SSOT, §3 asserted as superset. "§3 omits grill" 클래스 봉인.
SK17="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
PR17=$(awk '/^# Phase R/{f=1;next} /^# Phase /{f=0} f' "$SK17" 2>/dev/null)
S3_17=$(awk '/^## §3\./{f=1;next} /^## §[0-9]/{f=0} f' "$HOME/.claude/CLAUDE.md" 2>/dev/null)
if [ -z "$PR17" ] || [ -z "$S3_17" ]; then
  fail "drift-guard #17: Phase R 또는 §3 섹션 추출 실패 (헤더 변경?)"
else
  MISS17=""
  for t in grill-with-docs brainstorming explore-strict; do
    printf '%s' "$PR17" | grep -q "$t" && ! printf '%s' "$S3_17" | grep -q "$t" && MISS17="$MISS17 $t"
  done
  [ -z "$MISS17" ] && ok "§3 ↔ start-rpi-cycle Phase R tools agree" || fail "§3 omits Phase-R tool(s):$MISS17 (drift vs start-rpi-cycle)"
fi

# 18. next-cycle-goal 라벨 parity: sub-step 7(절차)와 Communication Protocol(출력 계약)이 같은 3 라벨을 열거해야.
#     둘 다 설계상 필수(계약에 라벨 없으면 report-time 표면화 약화)라 dedupe 불가 → #17 패턴의 파일-내 인스턴스로 봉인.
#     ("모든 중복 비교" generalized 프레임워크 아님 — 특정 인스턴스, grill spec이 남긴 확장 여지 내.)
SK18="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
C1_18=$(awk '/^## Step C-1/{f=1;next} /^## Sub-cycle states/{f=0} f' "$SK18" 2>/dev/null)
CP_18=$(awk '/^## Communication Protocol/{f=1} f' "$SK18" 2>/dev/null)
if [ -z "$C1_18" ] || [ -z "$CP_18" ]; then
  fail "drift-guard #18: Step C-1 또는 Communication Protocol 섹션 추출 실패 (헤더 변경?)"
else
  MISS18=""
  for t in 'goal:' 'read-before:' 'autonomy:'; do
    printf '%s' "$C1_18" | grep -q "$t" && printf '%s' "$CP_18" | grep -q "$t" || MISS18="$MISS18 $t"
  done
  [ -z "$MISS18" ] && ok "next-cycle-goal 라벨 ↔ sub-step 7/Communication Protocol parity" || fail "next-cycle-goal 라벨 drift:$MISS18 (sub-step 7 ↔ Communication Protocol 불일치)"
fi

# 19. harness-verify 필드 parity: sub-step 6(verify-setup 실행 절차)과 Communication Protocol(출력 계약)이
#     같은 'harness-verify' 토큰을 가져야. 둘 다 필수 — 계약에 토큰 없으면 verify-setup PASS가 복합 evidence에
#     접혀 cycle-14 마스킹 클래스 재발(F1/F6) → dedupe 불가 → #18 패턴의 파일-내 인스턴스로 봉인.
SK19="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
C1_19=$(awk '/^## Step C-1/{f=1;next} /^## Sub-cycle states/{f=0} f' "$SK19" 2>/dev/null)
CP_19=$(awk '/^## Communication Protocol/{f=1} f' "$SK19" 2>/dev/null)
if [ -z "$C1_19" ] || [ -z "$CP_19" ]; then
  fail "drift-guard #19: Step C-1 또는 Communication Protocol 섹션 추출 실패 (헤더 변경?)"
else
  if printf '%s' "$C1_19" | grep -q 'harness-verify' && printf '%s' "$CP_19" | grep -q 'harness-verify'; then
    ok "harness-verify 필드 ↔ sub-step 6/Communication Protocol parity"
  else
    fail "harness-verify 필드 drift (sub-step 6 ↔ Communication Protocol 불일치)"
  fi
fi

# 20. cases.tsv 실측 == README 선언 카운트 (재드리프트 봉인). README 가 cases.tsv 를 언급한 줄의
#     '<N> 케이스/case' 숫자가 실측과 다르면 FAIL. (historical "원안 65개"는 케이스/case 미동반이라 비매칭.)
ACT_CASES=$(grep -vcE '^[[:space:]]*(#|$)' "$HOME/.claude/hooks/tests/cases.tsv")
BAD20=$(grep -E 'cases\.tsv' "$HOME/.claude/README.md" 2>/dev/null \
        | grep -oE '[0-9]+ ?(케이스|cases?)' | grep -oE '^[0-9]+' | grep -vx "$ACT_CASES" | head -1)
[ -z "$BAD20" ] && ok "README cases 카운트 == 실측($ACT_CASES)" || fail "README cases drift: 선언 $BAD20 ≠ 실측 $ACT_CASES"

# 21. verify-integration E2E 실측 == README 선언 카운트.
ACT_E2E=$(grep -cE 'ok "E2E\.' "$HOME/.claude/setup/verify-integration.sh")
BAD21=$(grep -oE '[0-9]+개 E2E' "$HOME/.claude/README.md" 2>/dev/null | grep -oE '^[0-9]+' | grep -vx "$ACT_E2E" | head -1)
[ -z "$BAD21" ] && ok "README E2E 카운트 == 실측($ACT_E2E)" || fail "README E2E drift: 선언 $BAD21 ≠ 실측 $ACT_E2E"

# 22. phase-skills 필드 parity: Step C-1(sub-step 8) ↔ Communication Protocol 두 곳 'phase-skills' 토큰 필연 중복 (#18/#19 인스턴스).
SK22="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
C1_22=$(awk '/^## Step C-1/{f=1;next} /^## Sub-cycle states/{f=0} f' "$SK22" 2>/dev/null)
CP_22=$(awk '/^## Communication Protocol/{f=1} f' "$SK22" 2>/dev/null)
if [ -z "$C1_22" ] || [ -z "$CP_22" ]; then
  fail "drift-guard #22: Step C-1 또는 Communication Protocol 섹션 추출 실패"
elif printf '%s' "$C1_22" | grep -q 'phase-skills' && printf '%s' "$CP_22" | grep -q 'phase-skills'; then
  ok "phase-skills 필드 ↔ Step C-1/Communication Protocol parity"
else
  fail "phase-skills 필드 drift (Step C-1 ↔ Communication Protocol 불일치)"
fi

# 23. settings.json ↔ settings.example.json 하네스 hook (phase|matcher|basename) parity (값/시크릿 미접근).
#     isHarness 한정(cycle-24 승격): S3 보존 병합 불변식(하네스 hook=템플릿 entry에만) 위에서 matcher drift 감지
#     + 사용자 커스텀 hook 오탐 제거. (구 basename-only는 matcher 축소를 미감지 — cycle-23 수락 잔여 ① 이행.)
sj_hooks() {
  node -e '
    let c={}; try{c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))}catch(e){process.exit(0)}
    const isHarness=h=>/\.claude\/hooks\/[^/]+\.sh/.test(String((h||{}).command||""));
    const out=[]; for(const [ph,es] of Object.entries(c.hooks||{})) for(const e of es) for(const h of (e.hooks||[]))
      if(isHarness(h)) out.push(ph+"|"+String(e.matcher??"")+"|"+String(h.command||"").split("/").pop());
    process.stdout.write(out.join(","));
  ' "$1" 2>/dev/null
}
HA=$(sj_hooks "$HOME/.claude/settings.json")
HB=$(sj_hooks "$HOME/.claude/settings.example.json")
if [ -z "$HB" ]; then
  fail "settings.example.json hook 추출 실패"
elif [ "$HA" = "$HB" ]; then
  ok "settings.json ↔ example harness-hook matcher parity"
else
  fail "settings/example harness-hook drift (phase/matcher/이름 불일치)"
fi

# 24. doctor REQUIRED_HOOKS 가 디스크의 모든 hooks/*.sh 를 커버하는가 (F4b 재발 방지; disk=SSOT, _common 제외).
DISK_H=$(for f in "$HOME/.claude/hooks/"*.sh; do basename "$f" .sh; done | grep -v '^_common$' | sort -u)
DOC_H=$(awk '/REQUIRED_HOOKS=\(/{f=1;next} /^\)/{f=0} f' "$HOME/.claude/setup/doctor.sh" 2>/dev/null \
        | grep -oE '[a-z_-]+\.sh' | sed 's/\.sh$//' | grep -v '^_common$' | sort -u)
MISS24=$(comm -23 <(printf '%s\n' "$DISK_H") <(printf '%s\n' "$DOC_H"))
[ -z "$MISS24" ] && ok "doctor REQUIRED_HOOKS ⊇ hooks/*.sh" || fail "doctor REQUIRED_HOOKS omits:$(printf ' %s' $MISS24)"

# 25. verify-integration.sh per-run 격리 봉인 (cycle-18 회귀 방지): 메인 TEST_DIR이
#     mktemp -d로 할당 + 고정 $HOME 경로 미사용. 서브픽스처(BAD_SKILL=/FRESH_F=/VL=)는
#     ^TEST_DIR= 앵커로 비매칭 → 메인 격리만 단언. (#17/#19/#22 content-drift 패턴 + 부정 단언.)
VI="$HOME/.claude/setup/verify-integration.sh"
if grep -qE '^TEST_DIR=\$\(mktemp -d\)' "$VI" 2>/dev/null \
   && ! grep -qE '^TEST_DIR=.*\$HOME' "$VI" 2>/dev/null; then
  ok "verify-integration TEST_DIR mktemp-isolated (고정 \$HOME 없음)"
else
  fail "verify-integration TEST_DIR 격리 drift (mktemp 부재 또는 고정 \$HOME 복원 — cycle-18 회귀)"
fi

# 27. plan lifecycle 봉인 (D-LIFECYCLE, cycle-23): 모든 plans/*.md 명시 Status 보유 + active ≤ 1.
#     Closeout step-2(Status flip) silent-skip이 게이트를 영구 개방하던 stale-active 재발 방지.
#     (#26은 미채택·번호 소각 — spec-count parity, 안정 앵커 부재.)
NOSTAT27=""; ACT27=0
for p27 in "$HOME/.claude/docs/superpowers/plans"/*.md; do
  [ -f "$p27" ] || continue
  ST27=$(head -20 "$p27" | grep -m1 -iE '^\*?\*?status:?\*?\*?' \
    | sed -E 's/^\*?\*?[Ss]tatus:?\*?\*?[[:space:]]*//' | awk '{print tolower($1)}' | tr -d '*')
  [ -z "$ST27" ] && NOSTAT27="$NOSTAT27 $(basename "$p27")"
  case "$ST27" in active|in_progress) ACT27=$((ACT27+1)) ;; esac
done
if [ -z "$NOSTAT27" ] && [ "$ACT27" -le 1 ]; then
  ok "plan lifecycle: 전 plan 명시 Status + active=$ACT27 (≤1)"
else
  fail "plan lifecycle drift: Status 없는 plan:${NOSTAT27:-없음} / active=$ACT27 (stale-active 의심 — Closeout step-2 누락?)"
fi

# 28. hooks/*.sh + setup/*.sh bash -n 문법 (fail-open 무표면 방지, D-FAILOPEN-SURFACE cycle-23)
SYN28=""
for f28 in "$HOME/.claude/hooks/"*.sh "$HOME/.claude/setup/"*.sh; do
  bash -n "$f28" 2>/dev/null || SYN28="$SYN28 $(basename "$f28")"
done
[ -z "$SYN28" ] && ok "bash -n: hooks+setup 문법 OK" || fail "bash -n 실패:$SYN28"

# 29. install.sh REQUIRED ⊇ verify-setup item-6 7 tracked skill (신선-클론 install이 광고한 게이트를
#     스스로 검증 — 누락 skill이 install PASS인데 verify-all FAIL 나던 drift 봉인, cycle-27 NEW-install-required-skills).
INSTALL29="$HOME/.claude/setup/install.sh"
MISS29=""
for s29 in common-agent-contract create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle improve-codebase-architecture ui-design; do
  grep -qF "skills/$s29/SKILL.md" "$INSTALL29" 2>/dev/null || MISS29="$MISS29 $s29"
done
[ -z "$MISS29" ] && ok "install.sh REQUIRED ⊇ 7 tracked skills" || fail "install.sh REQUIRED skill 누락:$MISS29 (verify-setup item6와 drift)"

# 30. state.json ↔ state.schema.json 검증 (dead-spec 활성화 — closeout이 쓴 state 무결성, cycle-28 NEW-state-schema-unverified).
#     스키마-구동: 스키마 파일을 읽어 사용된 draft-07 부분집합(required/type/minimum/format:date)으로 재귀 검사 → 스키마 변경 자동 추종.
ERR30=$(SCHEMA="$HOME/.claude/state.schema.json" DATA="$HOME/.claude/state.json" node -e '
  const fs=require("fs");
  let sc,d;
  try{ sc=JSON.parse(fs.readFileSync(process.env.SCHEMA,"utf8")); }catch(e){ process.stdout.write("schema 파싱 실패"); process.exit(0); }
  try{ d=JSON.parse(fs.readFileSync(process.env.DATA,"utf8")); }catch(e){ process.stdout.write("state.json 파싱 실패"); process.exit(0); }
  const errs=[], isDate=s=>/^\d{4}-\d{2}-\d{2}$/.test(s);
  (function chk(schema,val,path){
    if(schema.required) for(const k of schema.required) if(!val||!(k in val)) errs.push(path+"."+k+" 누락(required)");
    if(schema.properties&&val&&typeof val==="object") for(const [k,ps] of Object.entries(schema.properties)){
      if(!(k in val)) continue; const v=val[k], p=path+"."+k;
      if(ps.type==="integer"&&!Number.isInteger(v)) errs.push(p+" 정수 아님");
      else if(ps.type==="string"&&typeof v!=="string") errs.push(p+" 문자열 아님");
      else if(ps.type==="boolean"&&typeof v!=="boolean") errs.push(p+" 불리언 아님");
      else if(ps.type==="object"){ if(typeof v!=="object"||v===null) errs.push(p+" 객체 아님"); else chk(ps,v,p); }
      if(ps.type==="integer"&&typeof ps.minimum==="number"&&v<ps.minimum) errs.push(p+" < minimum "+ps.minimum);
      if(ps.format==="date"&&typeof v==="string"&&!isDate(v)) errs.push(p+" 날짜형식(YYYY-MM-DD) 아님");
    }
  })(sc,d,"state");
  process.stdout.write(errs.join("; "));
' 2>/dev/null)
[ -z "$ERR30" ] && ok "state.json ↔ schema 검증" || fail "state.json schema 위반: $ERR30"

# 31. cwd-drift 앵커 (item①·non-obvious:152 재발3): 공유 루트해소가 git rev-parse --show-toplevel 앵커 사용 +
#     enforce-rpi-cycle 이 그 앵커(resolve_project_root)를 소비. 미이행 시 즉시 RED(cwd-상대 단일레벨 회귀).
A31A=$(grep -c 'rev-parse --show-toplevel' "$HOME/.claude/hooks/_common.sh" 2>/dev/null || echo 0)
A31B=$(grep -c 'resolve_project_root' "$HOME/.claude/hooks/enforce-rpi-cycle.sh" 2>/dev/null || echo 0)
if [ "$A31A" -ge 1 ] && [ "$A31B" -ge 1 ]; then
  ok "cwd-drift 앵커: _common rev-parse($A31A) + enforce-rpi-cycle resolve_project_root($A31B)"
else
  fail "cwd-drift 앵커 미이행 (_common rev-parse=$A31A, enforce-rpi-cycle resolve_project_root=$A31B — cwd-상대 단일레벨 회귀)"
fi

# 32. cwd-drift 서브디렉터리 회귀 (item①, 실측): 임시 git repo + 루트 active plan, cwd=$repo/app/frontend 에서
#     plan-dir 게이트(코드 Write exit0 / plan부재 exit2) + spec-dir 게이트(plan Write·spec부재 exit2 / spec존재 exit0).
#     주: JSON content 는 node JSON.stringify 로 이스케이프(printf+리터럴 개행=무효 JSON→no-cwd-failopen 위양성 회피).
T32=$(mktemp -d)
git -C "$T32" init -q 2>/dev/null
git -C "$T32" -c user.email=t@t -c user.name=t commit -q --allow-empty -m i 2>/dev/null
mkdir -p "$T32/docs/superpowers/plans" "$T32/app/frontend/src"
printf '# p\n**Status:** active\n' > "$T32/docs/superpowers/plans/p.md"
ev32(){ FP="$1" CT="$2" CW="$3" node -e 'console.log(JSON.stringify({tool_name:"Write",tool_input:{file_path:process.env.FP,content:process.env.CT},cwd:process.env.CW}))'; }
B32=$'a\nb\nc\nd\ne\nf\ng'
R32_OK=$(ev32 "$T32/app/frontend/src/x.ts" "$B32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
printf '# p\n**Status:** completed\n' > "$T32/docs/superpowers/plans/p.md"
R32_NO=$(ev32 "$T32/app/frontend/src/x.ts" "$B32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
printf '# p\n**Status:** active\n' > "$T32/docs/superpowers/plans/p.md"
PB32=$'# Plan\n**Status:** active\n- [ ] s'
R32_NOSPEC=$(ev32 "$T32/docs/superpowers/plans/new.md" "$PB32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
mkdir -p "$T32/docs/superpowers/specs"; printf '# d\n' > "$T32/docs/superpowers/specs/x.md"
R32_SPEC=$(ev32 "$T32/docs/superpowers/plans/new.md" "$PB32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
rm -rf "$T32"
if [ "$R32_OK" = 0 ] && [ "$R32_NO" = 2 ] && [ "$R32_NOSPEC" = 2 ] && [ "$R32_SPEC" = 0 ]; then
  ok "cwd-drift subdir 게이트: plan(0/2)+spec(2/0) — 서브디렉터리 cwd 회귀 가드"
else
  fail "cwd-drift subdir 게이트 회귀: plan-ok=$R32_OK(want0) plan-no=$R32_NO(want2) spec-no=$R32_NOSPEC(want2) spec-yes=$R32_SPEC(want0)"
fi

# 33. worktree-teardown E2E 배선 + 핵심 단언 (item②·non-obvious:211): 고아화 봉인.
#     (a) verify-all.sh 에 worktree-teardown.test.sh 배선됨 (b) 테스트가 stale-정리(마커 fallback)+정션-불변 단언 보유.
WTT="$HOME/.claude/hooks/tests/worktree-teardown.test.sh"
if grep -q 'worktree-teardown.test.sh' "$HOME/.claude/setup/verify-all.sh" 2>/dev/null \
   && grep -q '마커 fallback' "$WTT" 2>/dev/null \
   && grep -q 'junction NOT followed' "$WTT" 2>/dev/null; then
  ok "worktree-teardown E2E 배선(verify-all 3b) + Ta(마커 fallback)·T1(정션 불변) 단언 실재"
else
  fail "worktree-teardown E2E 미배선 또는 핵심 단언 부재 (item② 고아화 — verify-all 배선/Ta/T1 확인)"
fi

# 34. 동시-세션 격리 규약 (item③·non-obvious:93): SECURITY.md 에 "상대 프로세스 kill 금지" 규약 실재.
if grep -q '동시-세션 격리' "$HOME/.claude/SECURITY.md" 2>/dev/null \
   && grep -q 'kill 금지' "$HOME/.claude/SECURITY.md" 2>/dev/null; then
  ok "동시-세션 격리 규약 SECURITY.md 실재 (상대 프로세스 kill 금지)"
else
  fail "동시-세션 격리 규약 SECURITY.md 부재 (item③ 미인코딩)"
fi

# 35. Best-Direction Mandate 토큰 parity (GAP-001, #17 동형): start-rpi-cycle 본문에
#     Phase P 필수 필드 'Best-Direction Check'(Phase P + Gate P = >=2)와 'DOWNGRADE-DECLARED'(>=1) 실재.
SRC_SKILL="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
BD_CNT=$(grep -c 'Best-Direction Check' "$SRC_SKILL" 2>/dev/null || true)
DG_CNT=$(grep -c 'DOWNGRADE-DECLARED' "$SRC_SKILL" 2>/dev/null || true)
if [ "${BD_CNT:-0}" -ge 2 ] && [ "${DG_CNT:-0}" -ge 1 ]; then
  ok "Best-Direction Mandate 토큰: start-rpi-cycle 'Best-Direction Check' x${BD_CNT}(>=2) + 'DOWNGRADE-DECLARED' x${DG_CNT}(>=1)"
else
  fail "Best-Direction Mandate 토큰 부재/부족 (GAP-001): 'Best-Direction Check' x${BD_CNT:-0}(<2) 또는 'DOWNGRADE-DECLARED' x${DG_CNT:-0}(<1) — skills/start-rpi-cycle/SKILL.md"
fi

# 36. verify-setup 총 체크수 <-> README 선언 parity (GAP-009 M1 봉인, 런타임 자기-카운트):
#     이 시점까지의 PASS+FAIL+1(이 체크 자신) == README "(현재 N PASS)" 선언. 체크 추가 시 README 미동기가 자동 FAIL.
EXPECTED_TOTAL=$((PASS + FAIL + 1))
README_DECL=$(grep -oE '현재 [0-9]+ PASS' "$HOME/.claude/README.md" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
if [ -n "$README_DECL" ] && [ "$README_DECL" -eq "$EXPECTED_TOTAL" ]; then
  ok "verify-setup 카운트 seal: README 선언(${README_DECL}) == 런타임 실측(${EXPECTED_TOTAL})"
else
  fail "verify-setup 카운트 drift (GAP-009 M1): README 선언(${README_DECL:-부재}) != 런타임 실측(${EXPECTED_TOTAL}) — README.md '현재 N PASS' 동기 필요"
fi

echo
echo "verify-setup: PASS=$PASS FAIL=$FAIL"
exit $FAIL
