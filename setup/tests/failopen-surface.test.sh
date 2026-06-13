#!/usr/bin/env bash
# Meta-test (cycle-32, rank6/G6-a·G3-b): 차단 hook이 lib 파서 크래시 시 fail-open 하더라도
# '침묵'이 아니라 '표면화'됨을 증명. 두 채널:
#   ① enforce-rpi-bash.sh — redirect-targets.js 크래시 → hook_log FAILOPEN + stderr, fail-open 유지(exit 0).
#   ② session-start-audit.sh — lib/*.js 런타임 스모크 → 손상 파서 → hook_log ALERT + stderr.
# Acceptance-tier (seal-regression.test.sh / verify-integration.sh 동급), verify-all STAGE 2c 로 배선 —
# hooks/tests/cases.tsv 단위케이스 아님(파서는 정상 CMD로 throw 안 함 G1-c; run-all 129 불변).
#
# 격리(cycle-18/#25/cycle-31 청사진): 라이브 ~/.claude hooks 서브셋을 임시 $HOME 으로 복제하고
# 복제본 파서에만 크래시 스텁을 주입, 복제본 hook 을 HOME=<복제본> 으로 실행한다.
# 라이브 파서/로그는 절대 쓰지 않음 — 종료 시 cksum witness 로 증명.
set -uo pipefail
SRC="$HOME/.claude"
PASS=0; FAIL=0
ok()  { echo "✓ $1"; PASS=$((PASS+1)); }
bad() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# --- live immutability witnesses: 버그난 테스트가 건드릴 수 있는 파서+편집 hook 의 cksum ---
witness() { local f; for f in hooks/lib/redirect-targets.js hooks/lib/skeleton-scan.js \
                                hooks/lib/transcript-usage.js hooks/lib/model-window.js \
                                hooks/enforce-rpi-bash.sh hooks/session-start-audit.sh; do
              cksum "$SRC/$f" 2>/dev/null; done; }
LIVE_BEFORE="$(witness)"

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

# --- helpers ---
make_replica() {  # $1 = replica home root
  local C="$1/.claude"
  mkdir -p "$C"
  cp -p "$SRC/CLAUDE.md" "$C/CLAUDE.md" 2>/dev/null || true   # session-start-audit 가 읽음
  [ -d "$SRC/hooks" ] && cp -a "$SRC/hooks" "$C/hooks"
  rm -rf "$C/hooks/.log"                                       # 새 로그 라인 단언 위해 clean 시작
  chmod +x "$C/hooks/"*.sh 2>/dev/null || true                # win32 cp -a +x 손실 방어
}
mk_bash_event() {  # $1=cmd $2=cwd
  CMD="$1" CWD="$2" node -e 'process.stdout.write(JSON.stringify({tool_name:"Bash",tool_input:{command:process.env.CMD},cwd:process.env.CWD}))'
}
mk_ssa_event() {   # $1=cwd
  CWD="$1" node -e 'process.stdout.write(JSON.stringify({session_id:"s",cwd:process.env.CWD}))'
}
replica_log() { cat "$1/.claude/hooks/.log/"*.log 2>/dev/null; }
CRASH_STUB='process.exit(1);'   # 비정상 종료 + 빈 stdout = 손상/throw 파서 시뮬

# === ① enforce-rpi-bash : redirect-targets.js 크래시 → fail-open 유지(exit 0) + FAILOPEN 로깅 ===
# ①control: HEALTHY 복제본은 무-plan 코드쓰기를 여전히 BLOCK(exit 2) — 새 분기가 정상 차단을 안 깬다.
H="$ROOT/erb_ok"; mkdir -p "$H"; make_replica "$H"
rc=0
mk_bash_event 'echo x > evil.py' "$H/.claude" | HOME="$H" bash "$H/.claude/hooks/enforce-rpi-bash.sh" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
  ok "①control: healthy parser still BLOCKs code-write w/o plan (exit 2)"
else
  bad "①control: expected exit 2 (block), got $rc — 새 분기가 정상 차단을 깸"
fi

# ①crash: 크래시 스텁 → 여전히 fail-open(exit 0, 차단 아님) AND FAILOPEN 로깅.
H="$ROOT/erb_crash"; mkdir -p "$H"; make_replica "$H"
printf '%s' "$CRASH_STUB" > "$H/.claude/hooks/lib/redirect-targets.js"
rc=0
mk_bash_event 'echo x > evil.py' "$H/.claude" | HOME="$H" bash "$H/.claude/hooks/enforce-rpi-bash.sh" >/dev/null 2>&1 || rc=$?
LOG="$(replica_log "$H")"
if [ "$rc" -eq 0 ] && printf '%s' "$LOG" | grep -qF 'FAILOPEN'; then
  ok "①crash: 파서 크래시 → fail-open 유지(exit 0) + FAILOPEN 로깅"
else
  bad "①crash: rc=$rc(want 0), FAILOPEN in log? log=[$(printf '%s' "$LOG" | tr '\n' '|')]"
fi

# === ② session-start-audit : lib/*.js 런타임 스모크 → 손상 파서 ALERT ===
# ②control: HEALTHY 복제본은 lib-runtime ALERT 를 false-fire 하지 않는다.
H="$ROOT/ssa_ok"; mkdir -p "$H"; make_replica "$H"
err="$(mk_ssa_event "$H" | HOME="$H" bash "$H/.claude/hooks/session-start-audit.sh" 2>&1 >/dev/null)"
if printf '%s' "$err" | grep -qF 'lib 파서 런타임 고장'; then
  bad "②control: healthy 복제본이 lib runtime ALERT 를 false-fire"
else
  ok "②control: healthy 복제본 → lib runtime ALERT 없음(no false-fire)"
fi

# ②crash: lib/*.js 1개 손상 → selfcheck ALERT (stderr 특정 문자열 + log lib-selfcheck).
H="$ROOT/ssa_crash"; mkdir -p "$H"; make_replica "$H"
printf '%s' "$CRASH_STUB" > "$H/.claude/hooks/lib/skeleton-scan.js"
err="$(mk_ssa_event "$H" | HOME="$H" bash "$H/.claude/hooks/session-start-audit.sh" 2>&1 >/dev/null)"
LOG="$(replica_log "$H")"
if printf '%s' "$err" | grep -qF 'lib 파서 런타임 고장' && printf '%s' "$LOG" | grep -qF 'lib-selfcheck'; then
  ok "②crash: 손상 skeleton-scan.js → selfcheck ALERT (stderr + log)"
else
  bad "②crash: lib-runtime ALERT 누락. err=[$(printf '%s' "$err" | tr '\n' '|')] log=[$(printf '%s' "$LOG" | tr '\n' '|')]"
fi

# === live immutability: witness 파일 byte-동일(모든 변이는 복제본 내부) ===
LIVE_AFTER="$(witness)"
if [ "$LIVE_BEFORE" = "$LIVE_AFTER" ]; then
  ok "live ~/.claude 파서+hook 비변형 (witness cksum 안정)"
else
  bad "live ~/.claude 변형됨 — 격리 breach"
fi

echo
echo "failopen-surface: PASS=$PASS FAIL=$FAIL"
exit $FAIL
