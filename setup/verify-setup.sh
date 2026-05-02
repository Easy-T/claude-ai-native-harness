#!/usr/bin/env bash
set -uo pipefail
PASS=0
FAIL=0
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }
ok()   { echo "✓ $1"; PASS=$((PASS+1)); }

# 1. CLAUDE.md exists + ≤200 lines
L=$(wc -l < "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo 9999)
[ -f "$HOME/.claude/CLAUDE.md" ] && [ "$L" -le 200 ] && ok "CLAUDE.md exists, $L lines" || fail "CLAUDE.md size $L"

# 2. 6 meta rule markers
R=$(grep -c '^## §[1-6]\.' "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo 0)
[ "$R" -eq 6 ] && ok "6 meta rules present" || fail "meta rules=$R"

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

# 6. 4 global skills
for s in common-agent-contract create-orchestrator-skill init-ai-ready-project start-rpi-cycle; do
  [ -f "$HOME/.claude/skills/$s/SKILL.md" ] && ok "skill: $s" || fail "skill missing: $s"
done

# 7. orchestrator marker triple on 3 of 4 skills
for s in create-orchestrator-skill init-ai-ready-project start-rpi-cycle; do
  f="$HOME/.claude/skills/$s/SKILL.md"
  if grep -q '^orchestrator_skill: true$' "$f" 2>/dev/null \
    && grep -q '^generated_by:' "$f" 2>/dev/null \
    && grep -q '^orchestrator_version:' "$f" 2>/dev/null; then
    ok "$s marker triple"
  else
    fail "$s missing marker triple"
  fi
done

# 8. 5 hook scripts executable
for h in enforce-orchestrator stable-claude-md auto-compact-watch enforce-rpi-cycle session-start-audit; do
  [ -x "$HOME/.claude/hooks/$h.sh" ] && ok "hook: $h" || fail "hook missing or non-executable: $h"
done

# 9. _common.sh exists
[ -f "$HOME/.claude/hooks/_common.sh" ] && ok "_common.sh" || fail "_common.sh missing"

# 10. /init-ai-ready command
[ -f "$HOME/.claude/commands/init-ai-ready.md" ] && ok "command: init-ai-ready" || fail "command missing"

# 11. 10 templates + 2 references
T=$(find "$HOME/.claude/skills/init-ai-ready-project/templates/" -maxdepth 1 -type f 2>/dev/null | wc -l)
R=$(find "$HOME/.claude/skills/init-ai-ready-project/references/" -maxdepth 1 -type f 2>/dev/null | wc -l)
[ "$T" -ge 10 ] && [ "$R" -ge 2 ] && ok "templates=$T, refs=$R" || fail "templates=$T, refs=$R"

# 12. setup scripts executable
for s in doctor.sh verify-setup.sh verify-integration.sh verify-all.sh; do
  [ -x "$HOME/.claude/setup/$s" ] && ok "setup: $s" || fail "setup missing: $s"
done

# 13. .installed marker
[ -f "$HOME/.claude/setup/.installed" ] && ok ".installed marker" || fail ".installed missing"

# 14. settings.json has 5 hooks registered
COUNT=$(node -e '
  const cfg = JSON.parse(require("fs").readFileSync(process.env.HOME + "/.claude/settings.json", "utf8"));
  const all = [];
  for (const phase of Object.values(cfg.hooks||{})) for (const e of phase) for (const h of (e.hooks||[])) all.push(h.command);
  console.log(all.filter(c => /\.claude\/hooks\/.*\.sh/.test(c)).length);
' 2>/dev/null || echo 0)
[ "$COUNT" -ge 5 ] && ok "settings.json: $COUNT hooks" || fail "settings.json hooks=$COUNT"

echo
echo "verify-setup: PASS=$PASS FAIL=$FAIL"
exit $FAIL
