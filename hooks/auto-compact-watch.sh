#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
SESSION_ID=$(echo "$INPUT" | json_get 'session_id')

[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

# 1세션 1회 알림 마커 (중복 방지)
ALERT_MARKER="/tmp/compact-alerted-${SESSION_ID}"
[ -f "$ALERT_MARKER" ] && exit 0

# 모델 컨텍스트 한도 (env로 override 가능)
LIMIT="${CONTEXT_LIMIT:-200000}"
THRESHOLD=$(( LIMIT * 40 / 100 ))

# transcript에서 누적 토큰 추출 (jsonl 가정)
USED=$(node -e '
  const fs = require("fs");
  try {
    const lines = fs.readFileSync(process.argv[1], "utf8").trim().split("\n");
    let last = 0;
    for (const ln of lines) {
      try {
        const obj = JSON.parse(ln);
        const u = obj?.message?.usage;
        if (u) {
          const total = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
          if (total > last) last = total;
        }
      } catch (e) { /* skip bad lines */ }
    }
    console.log(last);
  } catch (e) { console.log(0); }
' "$TRANSCRIPT")

[ -z "$USED" ] && USED=0

if (( USED >= THRESHOLD )); then
  PCT=$(( USED * 100 / LIMIT ))
  touch "$ALERT_MARKER"
  hook_log "auto-compact-watch" "session=$SESSION_ID" "ALERT" "${PCT}%"
  node -e "process.stdout.write(JSON.stringify({systemMessage:'[auto-compact] 컨텍스트 사용률 '+${PCT}+'% ('+${USED}+'/'+${LIMIT}+'). 60% 도달 시 native auto-compact 자동 발동. 지금 /compact 실행을 권장합니다.'}))"
fi
exit 0
