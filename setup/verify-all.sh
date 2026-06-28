#!/usr/bin/env bash
set -uo pipefail
echo "=== STAGE 0: RPI 전제조건 (superpowers 핵심 트리오) ==="
# verify-all 은 수용 게이트. RPI 엔진인 superpowers 트리오
# (start-rpi-cycle Phase R/P/I 가 호출: brainstorming/writing-plans/executing-plans)가 부재하면
# 최종 수용 메시지를 거짓 보증하므로 차단. (doctor.sh 20b WARN 는 install-time advisory 로 유지 — run-context 분리;
#  이 트리오는 doctor 20b 4종의 수용-임계 부분집합으로 의도적 비동일.)
RPI_PREREQ_MISSING=""
for sk in brainstorming writing-plans executing-plans; do
  ls "$HOME"/.claude/plugins/cache/*/superpowers/*/skills/"$sk"/SKILL.md >/dev/null 2>&1 \
    || RPI_PREREQ_MISSING="$RPI_PREREQ_MISSING $sk"
done
if [ -n "$RPI_PREREQ_MISSING" ]; then
  echo "FAIL STAGE 0: superpowers 핵심 skill 부재 —$RPI_PREREQ_MISSING" >&2
  echo "  RPI(start-rpi-cycle Phase R/P/I)가 작동하지 않습니다. 설치: /plugin install superpowers@claude-plugins-official" >&2
  echo "  (이 게이트 미통과 시 최종 수용 메시지를 출력하지 않음 — 거짓 보증 방지)" >&2
  exit 1
fi
echo "[stage0] RPI 전제조건 OK (brainstorming/writing-plans/executing-plans present)"
echo
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
echo "=== STAGE 2c: fail-open surface meta-test ==="
bash "$HOME/.claude/setup/tests/failopen-surface.test.sh" || { echo "FAIL failopen-surface"; exit 1; }
echo
echo "=== STAGE 2d: RPI prereq gate meta-test ==="
bash "$HOME/.claude/setup/tests/rpi-prereq-gate.test.sh" || { echo "FAIL rpi-prereq-gate"; exit 1; }
echo
echo "=== STAGE 3: hook unit tests ==="
bash "$HOME/.claude/hooks/tests/run-all.sh"    || { echo "FAIL hook tests"; exit 1; }
echo
echo "=== STAGE 3b: worktree-teardown E2E (Windows 정션·powershell 가드) ==="
if command -v powershell >/dev/null 2>&1; then
  bash "$HOME/.claude/hooks/tests/worktree-teardown.test.sh" || { echo "FAIL worktree-teardown.test"; exit 1; }
else
  echo "[stage3b] skip — powershell 부재(비-Windows): worktree-teardown E2E는 Windows 정션 전용"
fi
echo
echo "=== STAGE 4: integration ==="
bash "$HOME/.claude/setup/verify-integration.sh" || { echo "FAIL integration"; exit 1; }
echo
echo "ALL PASS — system meets §6.6 acceptance gate."
exit 0
