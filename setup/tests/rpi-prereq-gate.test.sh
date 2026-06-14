#!/usr/bin/env bash
# setup/tests/rpi-prereq-gate.test.sh
# verify-all STAGE 0 (RPI 전제조건 게이트) 메타테스트 — cycle-33 G7-b.
#  ① superpowers 트리오 부재 복제본 → verify-all 이 최종 수용 메시지 거부(exit≠0 + STAGE0 메시지, no "ALL PASS")
#  ② 라이브 트리오 존재(STAGE 0 라이브 통과 = 무회귀)  ③ 라이브 verify-all.sh 무변형 witness
set -uo pipefail
PASS=0; FAIL=0
LIVE_VA="$HOME/.claude/setup/verify-all.sh"
WIT_BEFORE=$(cksum "$LIVE_VA" 2>/dev/null || echo "NA")

# ① 부재 복제본 → 최종 수용 메시지 거부
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude/setup"
cp "$LIVE_VA" "$TMP/.claude/setup/verify-all.sh"
OUT=$(HOME="$TMP" bash "$TMP/.claude/setup/verify-all.sh" 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && printf '%s' "$OUT" | grep -q 'STAGE 0' \
   && printf '%s' "$OUT" | grep -q 'superpowers 핵심 skill 부재' \
   && ! printf '%s' "$OUT" | grep -q 'ALL PASS'; then
  echo "✓ no-superpowers replica → 최종 수용 메시지 거부 (exit=$RC, STAGE0 fail msg, no ALL PASS)"; PASS=$((PASS+1))
else
  echo "✗ no-superpowers replica: expected exit≠0 + STAGE0 fail msg + no ALL PASS (got rc=$RC)"; FAIL=$((FAIL+1))
fi

# ② 라이브 트리오 존재 = STAGE 0 라이브 통과 (무회귀)
MISS=""
for sk in brainstorming writing-plans executing-plans; do
  ls "$HOME"/.claude/plugins/cache/*/superpowers/*/skills/"$sk"/SKILL.md >/dev/null 2>&1 || MISS="$MISS $sk"
done
if [ -z "$MISS" ]; then
  echo "✓ live trio present (STAGE 0 passes live — no regression)"; PASS=$((PASS+1))
else
  echo "✗ live trio missing:$MISS"; FAIL=$((FAIL+1))
fi

# ③ 라이브 verify-all.sh 무변형 witness
WIT_AFTER=$(cksum "$LIVE_VA" 2>/dev/null || echo "NA")
if [ "$WIT_BEFORE" = "$WIT_AFTER" ]; then
  echo "✓ live verify-all.sh untouched (cksum stable)"; PASS=$((PASS+1))
else
  echo "✗ live verify-all.sh mutated"; FAIL=$((FAIL+1))
fi

echo
echo "rpi-prereq-gate: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
