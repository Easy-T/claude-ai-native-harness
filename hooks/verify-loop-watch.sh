#!/usr/bin/env bash
# verify-loop-watch.sh — advisory Stop hook (Patch B).
# 마무리(턴 종료) 시점에 '미검증 코드 변경'을 환기한다. 차단하지 않는다(advisory).
# 모든 세션에 전역 적용되므로 보수적으로: 아래 조건을 모두 충족할 때만 1세션 1회 알림.
#   1) stop_hook_active != true  (연속 실행 중 재알림 방지)
#   2) /tmp/verify-reminded-<session> 마커 없음 (1세션 1회)
#   3) cwd에 active plan 존재
#   4) cwd/scripts/check.sh 존재 (하네스 로컬 품질 게이트)
#   5) git에 커밋 안 된 코드 변경(.md/.txt 제외) 존재
# 위반/불충족/파싱 실패 시 조용히 통과(exit 0). decision:block 없음 → 절대 차단 안 함.
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)

# 1) 연속 실행(이미 한 번 stop을 가로챈 상태)에서는 재알림 안 함
STOP_ACTIVE=$(echo "$INPUT" | json_get 'stop_hook_active')
[ "$STOP_ACTIVE" = "true" ] && exit 0

# 2) 세션당 1회
SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"
MARKER="/tmp/verify-reminded-${SESSION_ID}"
[ -f "$MARKER" ] && exit 0

CWD=$(echo "$INPUT" | json_get 'cwd'); CWD=$(normalize_path "$CWD"); [ -z "$CWD" ] && CWD="."

# 3) active plan
PLAN=$(has_active_plan "$CWD") || exit 0
# 4) 로컬 품질 게이트 존재
[ -f "$CWD/scripts/check.sh" ] || exit 0
# 5) 커밋 안 된 코드 변경(.md/.txt/.gitignore 제외). git repo 아니면 판단 불가 → 통과.
DIRTY=$(git -C "$CWD" status --porcelain 2>/dev/null | grep -vE '\.(md|txt|gitignore)$' | grep -c '.' || true)
[ -z "$DIRTY" ] && DIRTY=0
(( DIRTY > 0 )) || exit 0

touch "$MARKER" 2>/dev/null || true
hook_log "verify-loop-watch" "plan=$(basename "$PLAN")" "ALERT" "dirty=$DIRTY"
node -e "process.stdout.write(JSON.stringify({systemMessage:'[verify-loop] 미검증 코드 변경 '+${DIRTY}+'건 + active plan 감지. 마무리 전에 scripts/check.sh 실행 + closeout(review-strict drift + state.json 갱신)을 권장합니다. (1세션 1회 advisory — 차단 아님)'}))"
exit 0
