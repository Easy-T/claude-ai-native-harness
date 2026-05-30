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

# 6. 5 global skills
for s in common-agent-contract create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle improve-codebase-architecture ui-design; do
  [ -f "$HOME/.claude/skills/$s/SKILL.md" ] && ok "skill: $s" || fail "skill missing: $s"
done

# 7. orchestrator marker triple on 6 of 7 skills
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

# 8. 8 hook scripts executable
for h in enforce-orchestrator stable-claude-md auto-compact-watch enforce-rpi-cycle enforce-rpi-bash enforce-secret-scan verify-loop-watch session-start-audit; do
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
for j in redirect-targets skeleton-scan transcript-usage; do
  [ -f "$HOME/.claude/hooks/lib/$j.js" ] && ok "lib: $j" || fail "hooks/lib/$j.js missing"
done

echo
echo "verify-setup: PASS=$PASS FAIL=$FAIL"
exit $FAIL
