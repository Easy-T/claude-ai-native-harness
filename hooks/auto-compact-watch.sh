#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
SESSION_ID=$(echo "$INPUT" | json_get 'session_id')

[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

# 1세션 1회 알림 마커 (중복 방지)
ALERT_MARKER="$(session_marker compact-alerted "$SESSION_ID")"
[ -f "$ALERT_MARKER" ] && exit 0

# transcript에서 누적 토큰(USED) + 마지막 모델명 추출 (item5: 모델-인지). 파서는 hooks/lib/transcript-usage.js.
READ=$(node "$HOME/.claude/hooks/lib/transcript-usage.js" "$TRANSCRIPT")
USED="${READ%%$'\t'*}"; MODEL="${READ#*$'\t'}"
[ -z "$USED" ] && USED=0

# 컨텍스트 창(LIMIT): hooks/lib/model-window.js 가 모델명→창 매핑(+ CONTEXT_LIMIT override)을 단일 관리.
# transcript엔 창 크기 필드가 없어 모델명 매핑 사용. effort(high/xhigh/max)는 창을 바꾸지 않음.
LIMIT=$(node "$HOME/.claude/hooks/lib/model-window.js" "$MODEL")

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
  emit_system_message "[auto-compact] 컨텍스트 사용률 약 ${PCT}% (${USED}/${LIMIT}, model=${MODEL:-?}). native auto-compact는 ${OVERRIDE_PCT}%에서 발동합니다. 길게 이어갈 작업이면 지금 /compact 권장. (1세션 1회, 창은 CONTEXT_LIMIT로 보정 가능)"
fi
exit 0
