#!/usr/bin/env bash
# End-to-end integration verification using ~/Documents/test-ai-ready/
set -uo pipefail
TEST_DIR="$HOME/Documents/test-ai-ready"
PASS=0
FAIL=0
ok()   { echo "✓ $1"; PASS=$((PASS+1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# Reset
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
git init -q

# E2E.A — Negative path: enforce-rpi-cycle blocks code change before /init
# Simulate a Write via piped JSON to the hook directly.
CODE_FILE="$TEST_DIR/src/auth.ts"
mkdir -p "$(dirname "$CODE_FILE")"
EVENT=$(node -e '
  const o = {tool_name:"Write", tool_input:{file_path:process.argv[1], content:"export function f(){}\nexport function g(){}\nexport function h(){}\nexport function i(){}\nexport function j(){}\nexport function k(){}"}, cwd:process.argv[2]};
  process.stdout.write(JSON.stringify(o));
' "$CODE_FILE" "$TEST_DIR")
RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
[ "$RC" = "2" ] && ok "E2E.A: enforce-rpi-cycle blocks code without plans/" || fail "E2E.A: rc=$RC"

# E2E.B — Whitelist: docs change passes
DOC_FILE="$TEST_DIR/docs/ai-context/non-obvious.md"
mkdir -p "$(dirname "$DOC_FILE")"
EVENT=$(node -e '
  const o = {tool_name:"Write", tool_input:{file_path:process.argv[1], content:"hi"}, cwd:process.argv[2]};
  process.stdout.write(JSON.stringify(o));
' "$DOC_FILE" "$TEST_DIR")
RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
[ "$RC" = "0" ] && ok "E2E.B: docs whitelist passes" || fail "E2E.B: rc=$RC"

# E2E.C — RPI_SKIP override
EVENT=$(node -e '
  const o = {tool_name:"Write", tool_input:{file_path:process.argv[1], content:"x".repeat(200)}, cwd:process.argv[2]};
  process.stdout.write(JSON.stringify(o));
' "$CODE_FILE" "$TEST_DIR")
RC=$(echo "$EVENT" | RPI_SKIP="hotfix" "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
[ "$RC" = "0" ] && ok "E2E.C: RPI_SKIP=hotfix passes" || fail "E2E.C: rc=$RC"

# E2E.D — active plan unblocks code
mkdir -p "$TEST_DIR/docs/superpowers/plans"
cat > "$TEST_DIR/docs/superpowers/plans/p.md" <<'PLAN'
# P
- [ ] step1
PLAN
EVENT=$(node -e '
  const o = {tool_name:"Edit", tool_input:{file_path:process.argv[1], old_string:"a\nb\nc\nd\ne\nf", new_string:"A\nB\nC\nD\nE\nF\nG"}, cwd:process.argv[2]};
  process.stdout.write(JSON.stringify(o));
' "$CODE_FILE" "$TEST_DIR")
RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
[ "$RC" = "0" ] && ok "E2E.D: active plan unblocks code" || fail "E2E.D: rc=$RC"

# E2E.E — orchestrator hook on a malformed skill
BAD_SKILL=$(mktemp -d)/skills/bad/SKILL.md
mkdir -p "$(dirname "$BAD_SKILL")"
EVENT=$(node -e '
  const content = `---\norchestrator_skill: true\n---\n# Setup\nNo phases.`;
  const o = {tool_name:"Write", tool_input:{file_path:process.argv[1], content}, cwd:"/tmp"};
  process.stdout.write(JSON.stringify(o));
' "$BAD_SKILL")
RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-orchestrator.sh" >/dev/null 2>&1; echo $?)
[ "$RC" = "2" ] && ok "E2E.E: enforce-orchestrator blocks malformed skill" || fail "E2E.E: rc=$RC"

echo
echo "verify-integration: PASS=$PASS FAIL=$FAIL"
exit $FAIL
