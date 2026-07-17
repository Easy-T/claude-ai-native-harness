#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
# file_path + session_id + tool_name 을 node 1회로(스폰 0 추가) — RL_* 는 run-log 인리치(GAP-003)
IFS=$'\037' read -r FILE_PATH RL_SID RL_TOOL <<< "$(echo "$INPUT" | json_get_many tool_input.file_path session_id tool_name)"
export RL_SID RL_TOOL
FILE_PATH=$(normalize_path "$FILE_PATH")

# 1. 대상 path 확인 — */skills/*/SKILL.md (대소문자 무시: skill.md/Skill.md 등도 검증, S13)
shopt -s nocasematch
if [[ "$FILE_PATH" != */skills/*/skill.md ]]; then shopt -u nocasematch; exit 0; fi
shopt -u nocasematch

# 2~4. 골격 카운트 — 권위 정의는 hooks/lib/skeleton-scan.js (단위테스트 가능).
#  Edit는 on-disk+old→new 재구성 파일 전체로 검증(S3), HTML 주석 제거 후 Agent() 카운트(S4).
SKEL=$(echo "$INPUT" | FP="$FILE_PATH" node "$HOME/.claude/hooks/lib/skeleton-scan.js")
[ "$SKEL" = "ERR" ] && { hook_log "enforce-orchestrator" "$FILE_PATH" "FAILOPEN" "skeleton-scan ERR (파서 실패 fail-open)"; exit 0; }  # 파싱 실패 → fail-safe 통과 (무로깅 0화, GAP-010 D1 L5)
[ "$SKEL" = "EMPTY" ] && exit 0    # 컨텐츠 없음 → 통과
read -r HAS_MARKER PHASE_COUNT AGENT_CALLS HAS_CONTRACT <<< "$SKEL"

# orchestrator 마커 없으면 통과(opt-out)
if [ "$HAS_MARKER" != "1" ]; then
  hook_log "enforce-orchestrator" "$FILE_PATH" "PASS" "no-marker"
  exit 0
fi

REASON=""
if (( PHASE_COUNT < 3 )); then
  REASON="phase=${PHASE_COUNT}<3"
elif (( AGENT_CALLS < 1 )); then
  REASON="agent_calls=0"
elif (( HAS_CONTRACT < 1 )); then
  REASON="no-protocol-section"
fi

if [ -n "$REASON" ]; then
  hook_log "enforce-orchestrator" "$FILE_PATH" "BLOCK" "$REASON"
  cat >&2 <<EOF
[orchestrator] FAIL: $REASON
  Orchestrator skill 골격 누락:
    - Phase 마커 ≥ 3 (현재 $PHASE_COUNT)
    - Agent(subagent_type=...) 호출 ≥ 1 (현재 $AGENT_CALLS)
    - Communication Protocol 섹션 ≥ 1 (현재 $HAS_CONTRACT)
  해결: create-orchestrator-skill을 사용해 다시 생성하거나, 골격을 직접 추가하세요.
  검증 우회 (단순 텍스트 변환 skill 등): frontmatter에서 \`orchestrator_skill: true\` 제거.
EOF
  exit 2
fi

hook_log "enforce-orchestrator" "$FILE_PATH" "PASS" ""
exit 0
