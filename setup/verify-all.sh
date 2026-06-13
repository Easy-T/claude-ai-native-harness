#!/usr/bin/env bash
set -uo pipefail
echo "=== STAGE 1: doctor ==="
bash "$HOME/.claude/setup/doctor.sh"           || { echo "FAIL doctor"; exit 1; }
echo
echo "=== STAGE 1b: doctor self-test ==="
bash "$HOME/.claude/setup/tests/doctor.test.sh" || { echo "FAIL doctor.test"; exit 1; }
echo
echo "=== STAGE 2: verify-setup ==="
bash "$HOME/.claude/setup/verify-setup.sh"     || { echo "FAIL verify-setup"; exit 1; }
echo
echo "=== STAGE 2b: seal-regression meta-test ==="
bash "$HOME/.claude/setup/tests/seal-regression.test.sh" || { echo "FAIL seal-regression"; exit 1; }
echo
echo "=== STAGE 3: hook unit tests ==="
bash "$HOME/.claude/hooks/tests/run-all.sh"    || { echo "FAIL hook tests"; exit 1; }
echo
echo "=== STAGE 4: integration ==="
bash "$HOME/.claude/setup/verify-integration.sh" || { echo "FAIL integration"; exit 1; }
echo
echo "ALL PASS — system meets §6.6 acceptance gate."
exit 0
