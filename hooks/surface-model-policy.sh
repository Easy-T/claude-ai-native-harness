#!/usr/bin/env bash
# surface-model-policy.sh — advisory PreToolUse hook (Agent|Workflow 매처; tri-model C11+C12, spec 2026-07-25 §5·§10).
# 역할×모델 매트릭스(docs/ai-context/model-policy.md)의 L2: Rule A(fable 세션 실행자 하향 미적용)·
# Rule B(검증자 하향, 전 세션)·Rule C/C2(Workflow 스크립트 경로 — C12)를 additionalContext 로 환기.
# 차단하지 않는다(항상 exit 0, fail-open — ERR trap 이 내부 실패도 exit 0 으로 흡수).
# 세션 모델은 hook stdin 에 없어 transcript 의 assistant 라인 message.model 로 판별(실측 shape).
# 라인 내 첫 매치만 취해 content 의 모델 id 인용에 면역(assistant JSON 은 model 이 content 앞).
# 스크립트 검사는 파이프 대신 bash [[ =~ ]] — pipefail+SIGPIPE 로 인한 거짓 판정 원천 차단.
# reload/upgrade 내성: settings.json 배선 + 라이브 tool_input 관측 — skill 텍스트와 무관 (spec §5).
source "$HOME/.claude/hooks/_common.sh"
trap 'exit 0' ERR EXIT   # advisory 불변식: 어떤 내부 실패(set -eu 포함)도 비-0 종료로 승격되지 않는다 (fail-open)
require_node

INPUT=$(read_input)
TOOL=$(echo "$INPUT" | json_get 'tool_name')
case "$TOOL" in Agent|Workflow) ;; *) exit 0 ;; esac

tier_of() {
  case "$1" in
    fable|claude-fable-*)   echo 4 ;;
    opus|claude-opus-*)     echo 3 ;;
    sonnet|claude-sonnet-*) echo 2 ;;
    haiku|claude-haiku-*)   echo 1 ;;
    *)                      echo 0 ;;
  esac
}

session_model_of() {  # $1=transcript path — 마지막 assistant 라인의 message.model (라인-내 첫 매치)
  tail -c 1000000 "$1" 2>/dev/null | awk '
    /"type":"assistant"/ && match($0, /"model":[[:space:]]*"claude-[a-z0-9.-]+"/) {
      m = substr($0, RSTART, RLENGTH); sub(/^"model":[[:space:]]*"/, "", m); sub(/"$/, "", m) }
    END { if (m != "") print m }'
}

# Rule C/C2 — Workflow 경로 (C12 spec §10): 같은-중괄호 근사([^}]*) 텍스트 휴리스틱. 정직 공개:
# 변수 조립·주석 내 언급은 오판 가능(주석의 execute-strict 는 오탐, 조립은 미검출) — 위협 모델은
# 적대 우회가 아닌 망각이고, canonical workflows/rpi-implement.js 가 1차 방어. model 키는 따옴표
# 유무 무관("model": 포함). scriptPath 는 선두 256KiB 만 검사(초과분 미검사 — 수용 잔여).
if [ "$TOOL" = "Workflow" ]; then
  WF_TEXT=$(echo "$INPUT" | json_get 'tool_input.script')
  if [ -z "$WF_TEXT" ]; then
    WF_SP=$(echo "$INPUT" | json_get 'tool_input.scriptPath')
    case "$WF_SP" in "~/"*) WF_SP="$HOME/${WF_SP#\~/}" ;; esac   # 방어적 — 도구 자체는 ~ 미확장(절대경로 권장)
    { [ -n "$WF_SP" ] && [ -f "$WF_SP" ]; } && WF_TEXT=$(head -c 262144 "$WF_SP" 2>/dev/null) || WF_TEXT=""
  fi
  [ -n "$WF_TEXT" ] || exit 0
  WF_NORM=$(printf '%s' "$WF_TEXT" | tr '\n\t' '  ')
  case "$WF_NORM" in *execute-strict*|*review-strict*) ;; *) exit 0 ;; esac
  TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
  SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"
  { [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0
  WF_SESSION_MODEL=$(session_model_of "$TRANSCRIPT")
  [ -n "$WF_SESSION_MODEL" ] || exit 0
  WF_TIER=$(tier_of "$WF_SESSION_MODEL")
  MPQ="['\"]"
  RE_EX_MODEL_AFTER="execute-strict${MPQ}[^}]*${MPQ}?model${MPQ}?[[:space:]]*:"
  RE_EX_MODEL_BEFORE="${MPQ}?model${MPQ}?[[:space:]]*:[[:space:]]*${MPQ}[a-zA-Z0-9.-]+${MPQ}[^}]*execute-strict"
  RE_EX_FABLE_AFTER="execute-strict${MPQ}[^}]*${MPQ}?model${MPQ}?[[:space:]]*:[[:space:]]*${MPQ}((claude-)?fable|inherit)"
  RE_EX_FABLE_BEFORE="${MPQ}?model${MPQ}?[[:space:]]*:[[:space:]]*${MPQ}((claude-)?fable[a-z0-9.-]*|inherit)${MPQ}[^}]*execute-strict"
  RE_REV_MODEL_AFTER="review-strict${MPQ}[^}]*${MPQ}?model${MPQ}?[[:space:]]*:[[:space:]]*${MPQ}([a-zA-Z0-9.-]+)${MPQ}"
  RE_REV_MODEL_BEFORE="${MPQ}?model${MPQ}?[[:space:]]*:[[:space:]]*${MPQ}([a-zA-Z0-9.-]+)${MPQ}[^}]*review-strict"

  # Rule C — fable 세션: execute-strict 스폰 객체에 model 키 부재(상속=fable 역류) 또는 fable 명시
  if [ "$WF_TIER" = "4" ] && [[ "$WF_NORM" == *execute-strict* ]]; then
    EX_HAS_MODEL=0; EX_FABLE=0
    [[ "$WF_NORM" =~ $RE_EX_MODEL_AFTER ]] && EX_HAS_MODEL=1
    [[ "$WF_NORM" =~ $RE_EX_MODEL_BEFORE ]] && EX_HAS_MODEL=1
    [[ "$WF_NORM" =~ $RE_EX_FABLE_AFTER ]] && EX_FABLE=1
    [[ "$WF_NORM" =~ $RE_EX_FABLE_BEFORE ]] && EX_FABLE=1
    if [ "$EX_HAS_MODEL" = "0" ] || [ "$EX_FABLE" = "1" ]; then
      MARKER="$(session_marker model-policy-c "$SESSION_ID")"
      if [ ! -f "$MARKER" ]; then
        touch "$MARKER" 2>/dev/null || true
        hook_log "surface-model-policy" "workflow:execute-strict-nomodel" "ALERT" "rule-c-workflow-downshift-missing"
        emit_additional_context "[model-policy] Workflow 스크립트가 execute-strict 스테이지를 model 지정 없이(또는 fable 로) 스폰합니다 — fable 세션의 구현 스테이지는 model:'opus' 고정이 정책. canonical: \$HOME/.claude/workflows/rpi-implement.js 를 절대경로 scriptPath 로 사용 권장(도구는 ~ 미확장). SSOT: docs/ai-context/model-policy.md §2 모드(A)·spec §10 (advisory · 1세션 1회 · 차단 아님)"
        exit 0
      fi
    fi
  fi

  # Rule C2 — 전 claude 세션: review-strict 스폰 객체의 model 리터럴 티어 < 세션 티어 (검증자 하향)
  if [ "$WF_TIER" != "0" ]; then
    REV_MODEL=""
    if [[ "$WF_NORM" =~ $RE_REV_MODEL_AFTER ]]; then REV_MODEL="${BASH_REMATCH[1]}"
    elif [[ "$WF_NORM" =~ $RE_REV_MODEL_BEFORE ]]; then REV_MODEL="${BASH_REMATCH[1]}"
    fi
    if [ -n "$REV_MODEL" ]; then
      REV_TIER=$(tier_of "$REV_MODEL")
      if [ "$REV_TIER" != "0" ] && [ "$REV_TIER" -lt "$WF_TIER" ]; then
        MARKER="$(session_marker model-policy-c2 "$SESSION_ID")"
        if [ ! -f "$MARKER" ]; then
          touch "$MARKER" 2>/dev/null || true
          hook_log "surface-model-policy" "workflow:review-strict:$REV_MODEL" "ALERT" "rule-c2-workflow-verifier-downshift"
          emit_additional_context "[model-policy] Workflow 스크립트가 검증자(review-strict)를 하향 model('$REV_MODEL' < 세션 $WF_SESSION_MODEL)로 스폰합니다 — 검증자는 model 무지정(상속)이 정책, 하향 금지(cross-family-review.md §3). 의도 하향이면 DOWNGRADE-DECLARED(사유) 선언 필요. (advisory · 1세션 1회 · 차단 아님)"
          exit 0
        fi
      fi
    fi
  fi
  exit 0
fi

SUB=$(echo "$INPUT" | json_get 'tool_input.subagent_type')
case "$SUB" in execute-strict|review-strict) ;; *) exit 0 ;; esac

REQ_MODEL=$(echo "$INPUT" | json_get 'tool_input.model')
TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"
{ [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0

SESSION_MODEL=$(session_model_of "$TRANSCRIPT")
[ -n "$SESSION_MODEL" ] || exit 0

SESSION_TIER=$(tier_of "$SESSION_MODEL")

# Rule A — fable 세션의 실행자가 하향 미적용(model 부재, 또는 fable/claude-fable-* 명시 = tier 4)
if [ "$SUB" = "execute-strict" ] && [ "$SESSION_TIER" = "4" ]; then
  if [ -z "$REQ_MODEL" ] || [ "$REQ_MODEL" = "inherit" ] || [ "$(tier_of "$REQ_MODEL")" = "4" ]; then
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
    emit_additional_context "[model-policy] 검증자(review-strict) 하향 감지(세션=$SESSION_MODEL > 요청=$REQ_MODEL) — 검증자 티어 ≥ 세션 티어(작업자 기준선)가 원칙(cross-family-review.md §3). 의도된 하향이면 DOWNGRADE-DECLARED(사유) 선언 필요. (advisory · 1세션 1회 · 차단 아님)"
    exit 0
  fi
fi

exit 0
