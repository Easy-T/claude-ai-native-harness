#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')

# 1. 대상 path 확인 — */skills/*/SKILL.md
[[ "$FILE_PATH" != */skills/*/SKILL.md ]] && exit 0

# 2. 작성될 컨텐츠 추출
CONTENT=$(echo "$INPUT" | json_get 'tool_input.content')
[ -z "$CONTENT" ] && CONTENT=$(echo "$INPUT" | json_get 'tool_input.new_string')
[ -z "$CONTENT" ] && exit 0

# 3. orchestrator 마커 검사 (검증 대상 결정론화)
echo "$CONTENT" | grep -q '^orchestrator_skill: true$' || {
  hook_log "enforce-orchestrator" "$FILE_PATH" "PASS" "no-marker"
  exit 0
}

# 4. 골격 검증 — 3가지 (Phase ≥3, Agent ≥1, Communication Protocol)
PHASE_COUNT=$(echo "$CONTENT" | grep -cE '^# Phase ' || true)
AGENT_CALLS=$(echo "$CONTENT" | grep -cE 'Agent\(subagent_type=' || true)
HAS_CONTRACT=$(echo "$CONTENT" | grep -c 'Communication Protocol' || true)

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
