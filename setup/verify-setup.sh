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

# 8. 9 hook scripts executable
for h in enforce-orchestrator stable-claude-md auto-compact-watch enforce-rpi-cycle enforce-rpi-bash enforce-secret-scan verify-loop-watch session-start-audit surface-constitution; do
  [ -x "$HOME/.claude/hooks/$h.sh" ] && ok "hook: $h" || fail "hook missing or non-executable: $h"
done

# 9. _common.sh exists
[ -f "$HOME/.claude/hooks/_common.sh" ] && ok "_common.sh" || fail "_common.sh missing"

# 10. /init-ai-ready command
[ -f "$HOME/.claude/commands/init-ai-ready.md" ] && ok "command: init-ai-ready" || fail "command missing"

# 11. 12 templates + 2 references
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

# 14. settings.json has >=9 hook command entries (4 PreToolUse Write|Edit|NotebookEdit + 2 Bash + 1 PostToolUse + 1 SessionStart + 1 Stop)
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

# 23. settings.json ↔ settings.example.json hook command basename 순서+이름 parity (값/시크릿 미접근).
sj_hooks() {
  node -e '
    let c={}; try{c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))}catch(e){process.exit(0)}
    const out=[]; for(const ph of Object.values(c.hooks||{})) for(const e of ph) for(const h of (e.hooks||[])) out.push(String(h.command||"").split("/").pop());
    process.stdout.write(out.join(","));
  ' "$1" 2>/dev/null
}
HA=$(sj_hooks "$HOME/.claude/settings.json")
HB=$(sj_hooks "$HOME/.claude/settings.example.json")
if [ -z "$HB" ]; then
  fail "settings.example.json hook 추출 실패"
elif [ "$HA" = "$HB" ]; then
  ok "settings.json ↔ example hook parity"
else
  fail "settings/example hook drift (순서/이름 불일치)"
fi

# 24. doctor REQUIRED_HOOKS 가 디스크의 모든 hooks/*.sh 를 커버하는가 (F4b 재발 방지; disk=SSOT, _common 제외).
DISK_H=$(for f in "$HOME/.claude/hooks/"*.sh; do basename "$f" .sh; done | grep -v '^_common$' | sort -u)
DOC_H=$(awk '/REQUIRED_HOOKS=\(/{f=1;next} /^\)/{f=0} f' "$HOME/.claude/setup/doctor.sh" 2>/dev/null \
        | grep -oE '[a-z_-]+\.sh' | sed 's/\.sh$//' | grep -v '^_common$' | sort -u)
MISS24=$(comm -23 <(printf '%s\n' "$DISK_H") <(printf '%s\n' "$DOC_H"))
[ -z "$MISS24" ] && ok "doctor REQUIRED_HOOKS ⊇ hooks/*.sh" || fail "doctor REQUIRED_HOOKS omits:$(printf ' %s' $MISS24)"

echo
echo "verify-setup: PASS=$PASS FAIL=$FAIL"
exit $FAIL
