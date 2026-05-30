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

# transcript에서 누적 토큰(USED) + 마지막 모델명 추출 (item5: 모델-인지)
READ=$(node -e '
  const fs = require("fs");
  try {
    const lines = fs.readFileSync(process.argv[1], "utf8").trim().split("\n");
    let last = 0, model = "";
    for (const ln of lines) {
      try {
        const obj = JSON.parse(ln);
        const u = obj?.message?.usage;
        if (u) {
          const total = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
          if (total > last) last = total;
        }
        if (obj?.message?.model) model = obj.message.model;
      } catch (e) { /* skip bad lines */ }
    }
    process.stdout.write(last + "\t" + model);
  } catch (e) { process.stdout.write("0\t"); }
' "$TRANSCRIPT")
USED="${READ%%$'\t'*}"; MODEL="${READ#*$'\t'}"
[ -z "$USED" ] && USED=0

# 컨텍스트 창(LIMIT): CONTEXT_LIMIT env가 있으면 우선, 없으면 모델명에서 도출.
# transcript엔 창 크기 필드가 없어 모델명 매핑 사용(opus-4-7/4-8 및 '1m' 계열 → 1M, 그 외 200K).
# effort(high/xhigh/max)는 창을 바꾸지 않음 — 창은 모델이 결정. 비표준/엣지 선택은 CONTEXT_LIMIT로 강제.
if [ -n "${CONTEXT_LIMIT:-}" ]; then
  LIMIT="$CONTEXT_LIMIT"
else
  case "$MODEL" in
    *opus-4-7*|*opus-4-8*|*1m*|*1M*) LIMIT=1000000 ;;
    *) LIMIT=200000 ;;
  esac
fi

# native auto-compact 발동 %(= CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, 기본 95). 경고는 그보다 먼저.
OVERRIDE_PCT="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-95}"
case "$OVERRIDE_PCT" in *[!0-9]*|"") OVERRIDE_PCT=95 ;; esac
WARN_PCT="${COMPACT_WARN_PCT:-}"
if [ -z "$WARN_PCT" ]; then WARN_PCT=$(( OVERRIDE_PCT > 15 ? OVERRIDE_PCT - 10 : OVERRIDE_PCT )); fi
THRESHOLD=$(( LIMIT * WARN_PCT / 100 ))

if (( USED >= THRESHOLD )); then
  PCT=$(( USED * 100 / LIMIT ))
  touch "$ALERT_MARKER"
  hook_log "auto-compact-watch" "session=$SESSION_ID model=${MODEL:-?}" "ALERT" "${PCT}% (warn@${WARN_PCT}% native@${OVERRIDE_PCT}% win=${LIMIT})"
  MODEL="$MODEL" USED="$USED" LIMIT="$LIMIT" PCT="$PCT" OVERRIDE_PCT="$OVERRIDE_PCT" node -e 'process.stdout.write(JSON.stringify({systemMessage:"[auto-compact] 컨텍스트 사용률 약 "+process.env.PCT+"% ("+process.env.USED+"/"+process.env.LIMIT+", model="+(process.env.MODEL||"?")+"). native auto-compact는 "+process.env.OVERRIDE_PCT+"%에서 발동합니다. 길게 이어갈 작업이면 지금 /compact 권장. (1세션 1회, 창은 CONTEXT_LIMIT로 보정 가능)"}))'
fi
exit 0
