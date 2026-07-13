#!/usr/bin/env bash
# enforce-session-budget.sh — 무인 goal-loop 폭주 방지 결정론 상한 (GAP-002).
# PreToolUse matcher "*"(전 도구)에 배선. 세션당 도구호출 카운터를 증분,
# SESSION_TOOL_BUDGET 초과 시 exit 2 로 차단(에이전트 밖 강제 — 프롬프트 지시는 과제 동기 시 무시됨, 02 §5).
# 기본 OFF: SESSION_TOOL_BUDGET 미설정이면 _common.sh source 전 즉시 통과(최소 비용).
# fail-open: SID 부재·카운터 I/O 실패 → 통과(예산은 back-pressure이지 하드 보안 아님).

# --- 기본 OFF: source 전 최소 비용 게이트 ---
[ -z "${SESSION_TOOL_BUDGET:-}" ] && exit 0
# 비숫자/≤0 예산 → 무효, 통과
case "$SESSION_TOOL_BUDGET" in ''|*[!0-9]*) exit 0 ;; esac
[ "$SESSION_TOOL_BUDGET" -le 0 ] && exit 0

source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
IFS=$'\037' read -r SID TOOL <<< "$(echo "$INPUT" | json_get_many session_id tool_name)"
[ -z "$SID" ] && exit 0   # 세션 식별 불가 → fail-open 통과 (카운터 키 없음)
export RL_SID="$SID" RL_TOOL="$TOOL"   # run-log 인리치(C2 피기백)

BDIR="${BUDGET_DIR:-$HOME/.claude/hooks/.budget}"
mkdir -p "$BDIR" 2>/dev/null || exit 0   # 디렉터리 불가 → fail-open
BF="$BDIR/$SID"
CNT=$(cat "$BF" 2>/dev/null || echo 0)
case "$CNT" in ''|*[!0-9]*) CNT=0 ;; esac   # 손상 카운터 → 리셋
CNT=$((CNT + 1))
printf '%s' "$CNT" > "$BF" 2>/dev/null || true

# --- 명시 우회 (GOAL_BUDGET_SKIP) ---
if [ -n "${GOAL_BUDGET_SKIP:-}" ]; then
  hook_log "enforce-session-budget" "count=$CNT/$SESSION_TOOL_BUDGET" "PASS" "skip:${GOAL_BUDGET_SKIP}"
  surface_bypass "session-budget" "$SID" "⚠ 세션 도구 예산 우회 (GOAL_BUDGET_SKIP='${GOAL_BUDGET_SKIP}') — 카운터 계속 증가($CNT/$SESSION_TOOL_BUDGET); 의도된 연장인지 확인"
  exit 0
fi

# --- 예산 초과 → 차단 ---
if [ "$CNT" -gt "$SESSION_TOOL_BUDGET" ]; then
  hook_log "enforce-session-budget" "count=$CNT/$SESSION_TOOL_BUDGET" "BLOCK" "budget-exceeded"
  cat >&2 <<EOF
[session-budget] 차단: 세션 도구 호출 $CNT > 예산 $SESSION_TOOL_BUDGET.
  무인 루프 폭주 방지 결정론 상한(SESSION_TOOL_BUDGET). 작업을 체크포인트(spec/plan)로 슬라이스하거나,
  의도된 연장이면: export GOAL_BUDGET_SKIP="<이유>" (1회 우회) 또는 SESSION_TOOL_BUDGET 상향.
EOF
  exit 2
fi

# --- 80% 경고 (최초 도달 1회, additionalContext 모델 표면화) ---
WARN_AT=$(( (SESSION_TOOL_BUDGET * 8 + 9) / 10 ))   # ceil(budget*0.8)
if [ "$CNT" -ge "$WARN_AT" ]; then
  WMARK="$BDIR/.warned-$SID"
  if [ ! -f "$WMARK" ]; then
    : > "$WMARK" 2>/dev/null || true
    hook_log "enforce-session-budget" "count=$CNT/$SESSION_TOOL_BUDGET" "ALERT" "budget-80pct"
    emit_additional_context "⚠ 세션 도구 예산 ${CNT}/${SESSION_TOOL_BUDGET} (80%↑) — 체크포인트/압축 고려. 초과 시 차단(GOAL_BUDGET_SKIP 우회)." || true
    exit 0
  fi
fi

exit 0   # within-budget: silent 증분(로그 무 — 노이즈 방지)
