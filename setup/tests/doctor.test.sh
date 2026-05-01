#!/usr/bin/env bash
# Test: doctor.sh diagnoses env correctly and creates artifacts.
set -euo pipefail

DOCTOR="$HOME/.claude/setup/doctor.sh"

# Test 1: doctor.sh exists and is executable
[ -x "$DOCTOR" ] || { echo "FAIL: doctor.sh not executable"; exit 1; }

# Test 2: running doctor.sh creates .installed marker
rm -f "$HOME/.claude/setup/.installed"
bash "$DOCTOR" > /dev/null 2>&1 || { echo "FAIL: doctor.sh exit non-zero"; exit 1; }
[ -f "$HOME/.claude/setup/.installed" ] || { echo "FAIL: .installed marker not created"; exit 1; }

# Test 3: running doctor.sh creates audit marker in CLAUDE.md if missing
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  grep -qE '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD" || \
    { echo "FAIL: audit marker not in CLAUDE.md"; exit 1; }
fi

# Test 4: running doctor.sh creates a backup directory under $HOME
ls -d "$HOME"/.claude.backup-* > /dev/null 2>&1 || \
  { echo "FAIL: no backup directory created"; exit 1; }

echo "PASS: all doctor.sh tests"
