#!/usr/bin/env bash
# surface-model-policy.sh — advisory PreToolUse hook (Agent 매처; tri-model C11, spec 2026-07-25 §5).
# 역할×모델 매트릭스(docs/ai-context/model-policy.md)의 L2: Rule A(fable 세션 실행자 하향 미적용)·
# Rule B(검증자 하향, 전 세션)를 additionalContext 로 환기. 차단하지 않는다(항상 exit 0, fail-open).
# 세션 모델은 hook stdin 에 없어 transcript 의 assistant 라인 message.model 로 판별(실측 shape).
# 라인 내 첫 매치만 취해 content 의 모델 id 인용에 면역(assistant JSON 은 model 이 content 앞).
# reload/upgrade 내성: settings.json 배선 + 라이브 tool_input 관측 — skill 텍스트와 무관 (spec §5).
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
TOOL=$(echo "$INPUT" | json_get 'tool_name')
case "$TOOL" in Agent|Workflow) ;; *) exit 0 ;; esac

# Rule C — Workflow 경로 (C12 spec §10): fable 세션의 인라인/scriptPath 스크립트가
# execute-strict 스테이지를 model 토큰 없이 스폰하려는 순간 환기. 텍스트 휴리스틱(정직 공개:
# 변수 조립·주석 회피는 미검출 — 망각이 위협 모델). execute-strict 부재 스크립트는 무발화(오탐 0).
if [ "$TOOL" = "Workflow" ]; then
  WF_TEXT=$(echo "$INPUT" | json_get 'tool_input.script')
  if [ -z "$WF_TEXT" ]; then
    WF_SP=$(echo "$INPUT" | json_get 'tool_input.scriptPath')
    { [ -n "$WF_SP" ] && [ -f "$WF_SP" ]; } && WF_TEXT=$(head -c 262144 "$WF_SP" 2>/dev/null) || WF_TEXT=""
  fi
  [ -n "$WF_TEXT" ] || exit 0
  printf '%s' "$WF_TEXT" | grep -q "execute-strict" || exit 0
  printf '%s' "$WF_TEXT" | grep -qE "model[[:space:]]*:" && exit 0
  TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
  SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"
  { [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0
  WF_SESSION_MODEL=$(tail -c 200000 "$TRANSCRIPT" 2>/dev/null | awk '
    /"type":"assistant"/ && match($0, /"model":"claude-[a-z0-9.-]+"/) { m = substr($0, RSTART+9, RLENGTH-10) }
    END { if (m != "") print m }')
  case "$WF_SESSION_MODEL" in claude-fable-*) ;; *) exit 0 ;; esac
  MARKER="$(session_marker model-policy-c "$SESSION_ID")"
  [ -f "$MARKER" ] && exit 0
  touch "$MARKER" 2>/dev/null || true
  hook_log "surface-model-policy" "workflow:execute-strict-nomodel" "ALERT" "rule-c-workflow-downshift-missing"
  emit_additional_context "[model-policy] Workflow 스크립트가 execute-strict 스테이지를 model 지정 없이 스폰합니다 — fable 세션의 구현 스테이지는 model:'opus' 고정이 정책(canonical: workflows/rpi-implement.js를 scriptPath로 사용 권장). SSOT: docs/ai-context/model-policy.md §10 (advisory · 1세션 1회 · 차단 아님)"
  exit 0
fi

SUB=$(echo "$INPUT" | json_get 'tool_input.subagent_type')
case "$SUB" in execute-strict|review-strict) ;; *) exit 0 ;; esac

REQ_MODEL=$(echo "$INPUT" | json_get 'tool_input.model')
TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"
{ [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0

SESSION_MODEL=$(tail -c 200000 "$TRANSCRIPT" 2>/dev/null | awk '
  /"type":"assistant"/ && match($0, /"model":"claude-[a-z0-9.-]+"/) { m = substr($0, RSTART+9, RLENGTH-10) }
  END { if (m != "") print m }')
[ -n "$SESSION_MODEL" ] || exit 0

tier_of() {
  case "$1" in
    fable|claude-fable-*)   echo 4 ;;
    opus|claude-opus-*)     echo 3 ;;
    sonnet|claude-sonnet-*) echo 2 ;;
    haiku|claude-haiku-*)   echo 1 ;;
    *)                      echo 0 ;;
  esac
}
SESSION_TIER=$(tier_of "$SESSION_MODEL")

# Rule A — fable 세션의 실행자가 하향 미적용(model 부재 또는 fable 명시)
if [ "$SUB" = "execute-strict" ] && [ "$SESSION_TIER" = "4" ]; then
  if [ -z "$REQ_MODEL" ] || [ "$REQ_MODEL" = "fable" ]; then
    MARKER="$(session_marker model-policy-a "$SESSION_ID")"
    [ -f "$MARKER" ] && exit 0
    touch "$MARKER" 2>/dev/null || true
    hook_log "surface-model-policy" "execute-strict:${REQ_MODEL:-inherit}" "ALERT" "rule-a-downshift-missing"
    emit_additional_context "[model-policy] fable 세션의 실행자(execute-strict) 위임은 model:'opus' 명시가 정책 기본(구현=opus — 역할×모델 매트릭스). SSOT: docs/ai-context/model-policy.md (advisory · 1세션 1회 · 차단 아님)"
    exit 0
  fi
fi

# Rule B — 검증자 하향 감지(전 세션): 명시 model 티어 < 세션 티어
if [ "$SUB" = "review-strict" ] && [ -n "$REQ_MODEL" ] && [ "$SESSION_TIER" != "0" ]; then
  REQ_TIER=$(tier_of "$REQ_MODEL")
  if [ "$REQ_TIER" != "0" ] && [ "$REQ_TIER" -lt "$SESSION_TIER" ]; then
    MARKER="$(session_marker model-policy-b "$SESSION_ID")"
    [ -f "$MARKER" ] && exit 0
    touch "$MARKER" 2>/dev/null || true
    hook_log "surface-model-policy" "review-strict:$REQ_MODEL" "ALERT" "rule-b-verifier-downshift"
    emit_additional_context "[model-policy] 검증자(review-strict) 하향 감지(세션=$SESSION_MODEL > 요청=$REQ_MODEL) — 검증자 티어 ≥ 작업자가 원칙(cross-family-review.md §3). 의도된 하향이면 DOWNGRADE-DECLARED(사유) 선언 필요. (advisory · 1세션 1회 · 차단 아님)"
    exit 0
  fi
fi

exit 0
