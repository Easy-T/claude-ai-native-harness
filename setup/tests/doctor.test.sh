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

# Test 3 (cycle-29): audit 마커 no-overwrite 불변식 — 마커가 있으면 doctor는 '보존'(today로 덮어쓰지 않음).
# 무조건 갱신은 §3 staleness 게이트를 위조하고 §1 prefix 캐시를 무효화하므로 제거됨.
# (구 Test3는 "doctor가 방금 만든 마커 존재" tautological — doctor 행동을 검증 못 함.)
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [ -f "$CLAUDE_MD" ] && grep -qE '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD"; then
  BEFORE=$(grep -oE '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD" | head -1)
  bash "$DOCTOR" > /dev/null 2>&1 || true
  AFTER=$(grep -oE '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD" | head -1)
  [ "$BEFORE" = "$AFTER" ] || { echo "FAIL: doctor가 기존 audit 마커를 덮어씀 ($BEFORE → $AFTER) — no-overwrite 위반"; exit 1; }
fi

# Test 4: backup — git-managed 홈에선 doctor가 백업을 만들지 않음(의도) → SKIP. 비-git만 검사.
if [ -d "$HOME/.claude/.git" ]; then
  echo "SKIP: backup test (git-managed home — doctor skips backup by design)"
else
  ls -d "$HOME"/.claude.backup-* > /dev/null 2>&1 || \
    { echo "FAIL: no backup directory created"; exit 1; }
fi

echo "PASS: all doctor.sh tests"
