#!/usr/bin/env bash
# surface-model-policy.sh — advisory PreToolUse hook (Agent|Workflow 매처; tri-model C11+C12, spec 2026-07-25 §5·§10).
# 역할×모델 매트릭스(docs/ai-context/model-policy.md)의 L2: Rule A(fable 세션 실행자 하향 미적용)·
# Rule B(검증자가 기준선 max(세션,작업자) 미만, 전 세션)·Rule C/C3(Workflow 스크립트 경로 — C12·C13)·
# Rule C2(Workflow 검증자가 작업자 티어 미만 — 임무-분리 floor, spec §15.1)를 additionalContext 로 환기.
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

# Rule C/C2/C3 — Workflow 경로 (C12 spec §10, C13 spec §12.3 per-spawn 전환). 정직 공개:
# 스폰 추출은 hooks/lib/workflow-spawns.js (node) — 스크립트 전역 boolean OR 로 인한 마스킹을
# 해소하고 프롬프트 문자열 내부를 마스킹해 오탐/미탐을 함께 줄인다. 동적 조립('execute'+'-strict')은
# 여전히 미검출(텍스트 휴리스틱 상한 — canonical workflows/rpi-implement.js 가 1차 방어).
# scriptPath 는 선두 256KiB 만 검사(초과분 미검사 — 수용 잔여).
if [ "$TOOL" = "Workflow" ]; then
  WF_TEXT=$(echo "$INPUT" | json_get 'tool_input.script')
  if [ -z "$WF_TEXT" ]; then
    WF_SP=$(echo "$INPUT" | json_get 'tool_input.scriptPath')
    case "$WF_SP" in "~/"*) WF_SP="$HOME/${WF_SP#\~/}" ;; esac   # 방어적 — 도구 자체는 ~ 미확장(절대경로 권장)
    { [ -n "$WF_SP" ] && [ -f "$WF_SP" ]; } && WF_TEXT=$(head -c 262144 "$WF_SP" 2>/dev/null) || WF_TEXT=""
  fi
  [ -n "$WF_TEXT" ] || exit 0
  TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
  SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"
  { [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0
  WF_SESSION_MODEL=$(session_model_of "$TRANSCRIPT")
  [ -n "$WF_SESSION_MODEL" ] || exit 0
  WF_TIER=$(tier_of "$WF_SESSION_MODEL")
  [ "$WF_TIER" = "0" ] && exit 0

  SPAWNS=$(printf '%s' "$WF_TEXT" | node "$HOME/.claude/hooks/lib/workflow-spawns.js" 2>/dev/null)
  [ -n "$SPAWNS" ] || exit 0

  # 1패스: 위반 수집. WORKER_TIER = 실행자 최고 티어의 순수 관측(0=실행자 부재 — 검증자 floor 산정용, spec §15.1).
  C_HIT=0; C3_HIT=0; C2_HIT=""; WORKER_TIER=0
  while IFS="$(printf '\t')" read -r SP_TYPE SP_MODEL; do
    [ -n "$SP_TYPE" ] || continue
    if [ "$SP_TYPE" = "execute-strict" ]; then
      case "$SP_MODEL" in
        -|inherit|'*') SP_T="$WF_TIER" ;;   # C16 S1/S2: 상속=세션 평가(검증자와 동일 규칙)·동적=세션 상계(보수)
        *)             SP_T=$(tier_of "$SP_MODEL") ;;
      esac
      [ "$SP_T" -gt "$WORKER_TIER" ] 2>/dev/null && WORKER_TIER="$SP_T"
      # Rule C: fable 세션의 실행자가 무선언(-) 또는 inherit/fable 명시 = 하향 미적용
      if [ "$WF_TIER" = "4" ]; then
        case "$SP_MODEL" in
          -|inherit) C_HIT=1 ;;
          '*') ;;   # C15: 동적 선언 — 하향 미적용을 단언 불가(agentType '*' 면제와 동일 원리, spec §14.1)
          *) [ "$SP_T" = "4" ] && C_HIT=1 ;;
        esac
      fi
    else
      # Rule C3 (spec §13.3, C14 축 재정의): 세션 모델을 상속하는 스폰 = **model 을 선언하지 않는** 스폰.
      # 판정 축은 agentType 의 명시 여부가 아니라 model 선언의 존재다 —
      #   ① '?'(agentType 키 부재)는 §11.3 실측대로 상속
      #   ② 리터럴 agentType 중 frontmatter 에 model 을 선언하지 않는 것(builtin general-purpose/Explore/
      #      Plan 등 — agents/*.md 파일 자체가 없다)도 **통상** 상속한다(예외: 일부 builtin 은 CC 자체
      #      바인딩 — Explore=opus·claude-code-guide=haiku, spec §14.2 실측).
      # 제외(3 사유): explore-strict=frontmatter model 선언 보유 / execute·review-strict=Rule C·C2 전담 /
      #   '*'=동적이라 상속 단언 불가(GPT [C]4). 제외목록 ①축은 seal #47 이 디스크와 ⊆ 대조한다.
      case "$SP_TYPE" in
        explore-strict|execute-strict|review-strict|'*') ;;
        # ★C14 GPT 교차리뷰 정정: 명시 `model:'inherit'` 도 세션 상속이다(§13.3 표가 그렇게 규정).
        # '-'(무선언)만 보면 `{agentType:'general-purpose', model:'inherit'}` 가 빠져나갔다.
        *) [ "$WF_TIER" = "4" ] && { [ "$SP_MODEL" = "-" ] || [ "$SP_MODEL" = "inherit" ]; } && C3_HIT=1 ;;
      esac
    fi
  done <<EOF
$SPAWNS
EOF

  # 2패스: 검증자 floor — 임무-분리 (C16 spec §15.1, C13 §12.1 supersede).
  # Workflow 경로(준수-확인 임무) floor = **작업자 티어** (실행자 부재/전량-동적 스크립트는 세션 티어 폴백 — 보수 유지).
  # 무지정('-')·inherit 는 **세션 티어로 평가**한다(C13 Closeout 정정 불변 — 폐기 아님).
  # 하한 불변식: 검증자 < 작업자 는 어떤 임무에서도 위반(goal §5-12). 판단-게이트(Agent 경로 Rule B)는 max(세션,작업자) 유지.
  FLOOR_TIER="$WORKER_TIER"; [ "$FLOOR_TIER" -gt 0 ] 2>/dev/null || FLOOR_TIER="$WF_TIER"
  while IFS="$(printf '\t')" read -r SP_TYPE SP_MODEL; do
    [ "$SP_TYPE" = "review-strict" ] || continue
    case "$SP_MODEL" in
      '*')       continue ;;   # C15: 동적 선언 — floor 미달 단언 불가(tier 0 오평가 방지, spec §14.1)
      -|inherit) SP_T="$WF_TIER"; SP_LABEL="상속(세션=$WF_SESSION_MODEL)" ;;
      *)         SP_T=$(tier_of "$SP_MODEL"); SP_LABEL="$SP_MODEL" ;;
    esac
    [ "$SP_T" -lt "$FLOOR_TIER" ] 2>/dev/null && C2_HIT="$SP_LABEL"
  done <<EOF
$SPAWNS
EOF

  # 발화: 규칙마다 **독립 마커**로 dedup 하되, 한 호출에서 성립한 규칙은 **모두** 한 번에 emit 한다.
  # (종전 구현은 첫 규칙에서 exit 해 나머지를 삼켰다 — per-call 파싱으로 없앤 마스킹을 규칙 우선순위로
  #  되살리는 셈이었다. GPT [C]5 REAL. additionalContext 는 호출당 JSON 1개라 문자열로 합쳐 emit.)
  MSGS=""
  add_msg() { MSGS="${MSGS:+$MSGS
}$1"; }
  fire_once() {  # $1=marker slug — 이 세션에서 처음이면 0
    local mk; mk="$(session_marker "$1" "$SESSION_ID")"
    [ -f "$mk" ] && return 1
    touch "$mk" 2>/dev/null || true
    return 0
  }

  if [ "$C_HIT" = "1" ] && fire_once model-policy-c; then
    hook_log "surface-model-policy" "workflow:execute-strict-nomodel" "ALERT" "rule-c-workflow-downshift-missing"
    add_msg "[model-policy] Workflow 스크립트가 execute-strict 스테이지를 model 지정 없이(또는 fable 로) 스폰합니다 — fable 세션의 구현 스테이지는 model:'opus' 고정이 정책. canonical: \$HOME/.claude/workflows/rpi-implement.js 를 절대경로 scriptPath 로 사용 권장(도구는 ~ 미확장). SSOT: docs/ai-context/model-policy.md §2 모드(A)·spec §10 (advisory · 1세션 1회 · 차단 아님)"
  fi
  if [ "$C3_HIT" = "1" ] && fire_once model-policy-c3; then
    hook_log "surface-model-policy" "workflow:agentless-inherit" "ALERT" "rule-c3-workflow-fanout-inherit"
    add_msg "[model-policy] Workflow 스크립트가 **model 을 선언하지 않는** 서브에이전트를 스폰합니다(agentType 부재 또는 frontmatter 에 model 이 없는 builtin) — 이 경로는 **통상 세션 모델을 상속**하므로(spec §11.3·§13.3) fable 세션에선 리서치 fan-out 전체가 플래그십으로 역류합니다(일부 builtin 은 CC 자체 바인딩으로 하위 티어에 돌 수 있음 — spec §14.2 실측; Explore·claude-code-guide). 역할에 맞는 하위 모델을 opts.model 로 명시하십시오(탐색=sonnet). SSOT: docs/ai-context/model-policy.md (advisory · 1세션 1회 · 차단 아님)"
  fi
  if [ -n "$C2_HIT" ] && fire_once model-policy-c2; then
    hook_log "surface-model-policy" "workflow:review-strict:$C2_HIT" "ALERT" "rule-c2-workflow-verifier-downshift"
    add_msg "[model-policy] Workflow 스크립트의 검증자(review-strict)가 기준선 미만입니다(관측='$C2_HIT', 필요 티어=$FLOOR_TIER). 기준선은 작업자 티어(실행자 부재 시 세션 티어)입니다(spec §15.1 임무-분리 — Agent 경로 게이트는 max(세션,작업자) 유지) — **실행자를 세션 위로 상향했다면 model 을 지우는 것(상속)만으로는 해소되지 않습니다**(상속 = 세션 티어). 실행자 티어 이상을 명시하거나 실행자 상향을 되돌리십시오. 의도 하향이면 DOWNGRADE-DECLARED(사유) 선언이 필요합니다. (advisory · 1세션 1회 · 차단 아님)"
  fi
  [ -n "$MSGS" ] && emit_additional_context "$MSGS"
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
    emit_additional_context "[model-policy] 검증자(review-strict) 하향 감지(세션=$SESSION_MODEL > 요청=$REQ_MODEL) — 검증자 기준선은 max(세션 티어, 작업자 티어)입니다(spec §12.1, SSOT: docs/ai-context/model-policy.md). 의도된 하향이면 DOWNGRADE-DECLARED(사유) 선언 필요. (advisory · 1세션 1회 · 차단 아님)"
    exit 0
  fi
fi

exit 0
