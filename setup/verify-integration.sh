#!/usr/bin/env bash
# End-to-end integration verification in a per-run isolated temp dir (mktemp -d).
set -uo pipefail
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
PASS=0
FAIL=0
ok()   { echo "✓ $1"; PASS=$((PASS+1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# Fresh isolated dir from mktemp -d above — no shared-path reset needed.
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

# E2E.F — enforce-rpi-bash blocks code authored via shell redirection (no plan)
FRESH_F=$(mktemp -d)
EVENT=$(node -e '
  const o = {tool_name:"Bash", tool_input:{command:"cat > app.py <<EOF\nprint(1)\nEOF"}, cwd:process.argv[1]};
  process.stdout.write(JSON.stringify(o));
' "$FRESH_F")
RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-rpi-bash.sh" >/dev/null 2>&1; echo $?)
[ "$RC" = "2" ] && ok "E2E.F: enforce-rpi-bash blocks shell-authored code without plan" || fail "E2E.F: rc=$RC"

# E2E.G — enforce-secret-scan blocks a secret in a Bash command (fake key built at runtime)
AWSK="AKIA"; AWSK="${AWSK}ZZ1234567890ABCD"
EVENT=$(node -e '
  const o = {tool_name:"Bash", tool_input:{command:"echo "+JSON.stringify(process.argv[1])}, cwd:"/tmp"};
  process.stdout.write(JSON.stringify(o));
' "$AWSK")
RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-secret-scan.sh" >/dev/null 2>&1; echo $?)
[ "$RC" = "2" ] && ok "E2E.G: enforce-secret-scan blocks a secret in a Bash command" || fail "E2E.G: rc=$RC"

# E2E.H — verify-loop-watch advises (systemMessage) on unverified code changes
VL=$(mktemp -d)
( cd "$VL"; git init -q; git config user.email t@t; git config user.name t
  mkdir -p docs/superpowers/plans scripts src
  printf '# p\n**Status:** active\n- [ ] s\n' > docs/superpowers/plans/p.md
  printf '#!/bin/sh\n' > scripts/check.sh; printf 'x=1\n' > src/a.py
  git add -A >/dev/null 2>&1; git commit -qm init >/dev/null 2>&1
  printf 'x=2\ny=3\n' > src/a.py )
rm -f /tmp/verify-reminded-e2eH
OUT=$(echo "{\"session_id\":\"e2eH\",\"stop_hook_active\":false,\"cwd\":\"$VL\"}" | "$HOME/.claude/hooks/verify-loop-watch.sh" 2>/dev/null)
rm -f /tmp/verify-reminded-e2eH
echo "$OUT" | grep -q 'verify-loop' && ok "E2E.H: verify-loop-watch advises on unverified changes" || fail "E2E.H: no advice emitted"

echo
echo "verify-integration: PASS=$PASS FAIL=$FAIL"
exit $FAIL
