#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
# 스칼라 필드(file_path/notebook_path/tool_name)를 node 1회로 추출 ([10] json_get_many)
IFS=$'\037' read -r FILE_PATH NB_PATH TOOL <<< "$(echo "$INPUT" | json_get_many tool_input.file_path tool_input.notebook_path tool_name)"
[ -z "$FILE_PATH" ] && FILE_PATH="$NB_PATH"   # NotebookEdit는 file_path 대신 notebook_path 사용
FILE_PATH=$(normalize_path "$FILE_PATH")
# 빈/누락 cwd → plan 위치 판단 불가 → fail-open (S12, resolve_cwd 공유)
CWD=$(echo "$INPUT" | resolve_cwd) || { hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "no-cwd-failopen"; exit 0; }

# === Spec-before-plan 게이트 (cycle-12): Phase-P plan은 Phase-R design spec을 전제 ===
# plans/*.md 작성 시 sibling specs/*.md 가 없으면 차단 (grill→spec 역류 누락의 기계적 바닥).
case "$FILE_PATH" in
  */docs/superpowers/plans/*.md)
    if [ -z "${RPI_SKIP:-}" ] && ! ls "$CWD/docs/superpowers/specs"/*.md >/dev/null 2>&1; then
      hook_log "enforce-rpi-cycle" "$FILE_PATH" "BLOCK" "no-spec-before-plan"
      cat >&2 <<EOF
[rpi] 차단: plan 작성 전 design spec 없음 (docs/superpowers/specs/*.md).
  Phase R(brainstorming→grill→spec 역류)로 spec을 먼저 만든 뒤 writing-plans로 진행하세요.
  명시 우회: export RPI_SKIP="<이유>"
EOF
      exit 2
    fi
    ;;
esac

# === 화이트리스트 1: 비실행 산출물은 확장자 기준으로 항상 통과 (디렉터리 무관) ===
case "$FILE_PATH" in
  *.md|*.txt|*.gitignore|*/CLAUDE.md|*/README|*/README.rst|*/README.adoc|*/README.markdown|*/README.org|*/.gitkeep) exit 0 ;;
esac

# === 화이트리스트 2: infra/config 디렉터리는 '비코드 파일'에 한해 통과 ===
# 실행/코드 확장자는 어떤 디렉터리에 있어도 디렉터리-면제를 받지 못함
# → docs//.claude//.github/ 로의 코드 밀반입(S5) + governance hook 자기수정(S11) 차단.
# 참고: docs/superpowers/* 의 plan·spec은 .md이므로 화이트리스트1에서 이미 통과.
#       따라서 기존 */superpowers/* 디렉터리 면제는 제거 → vendor/superpowers/x.py 우회(S16)도 차단.
if is_code_path "$FILE_PATH"; then
  :   # 코드/실행 확장자 → 디렉터리 면제 없이 plan 게이트로 낙하 (SSOT: _common.sh CODE_EXTS)
else
  case "$FILE_PATH" in
    */.claude/*|*/docs/*|*/.github/*) exit 0 ;;   # 비코드 config/doc만 통과
  esac
fi

# === 화이트리스트 2: trivial change (≤5 라인) ===
OLD="" NEW=""
if [[ "$TOOL" == "Edit" ]]; then
  OLD=$(echo "$INPUT" | json_get 'tool_input.old_string')
  NEW=$(echo "$INPUT" | json_get 'tool_input.new_string')
elif [[ "$TOOL" == "Write" ]]; then
  NEW=$(echo "$INPUT" | json_get 'tool_input.content')
fi
if [[ -n "$OLD$NEW" ]]; then
  # 변경 라인 수 = max(OLD 라인, NEW 라인). OLD+NEW 합산이 아니라 '바뀐 라인' 기준(S7).
  # → "≤5 라인 변경" 정책과 일치 (3↔3 교체는 trivial).
  OLD_LINES=$(printf '%s' "$OLD" | awk 'END{print NR}')
  NEW_LINES=$(printf '%s' "$NEW" | awk 'END{print NR}')
  CHANGED_LINES=$(( OLD_LINES > NEW_LINES ? OLD_LINES : NEW_LINES ))
  (( CHANGED_LINES <= 5 )) && {
    hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "trivial"
    exit 0
  }
fi

# === 화이트리스트 3: 명시 우회 ===
if [ -n "${RPI_SKIP:-}" ]; then
  hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "skip:${RPI_SKIP}"
  echo "[rpi] SKIP: $RPI_SKIP" >&2
  surface_bypass "rpi-cycle" "$(echo "$INPUT" | json_get session_id)" "⚠ RPI 게이트 우회 (RPI_SKIP='${RPI_SKIP}') — 이 세션 코드변경에 RPI 미적용; 의도된 우회인지 확인"
  exit 0
fi

# === 검증: 활성 plan 존재 확인 ===
PLAN_DIR="$CWD/docs/superpowers/plans"
if [ ! -d "$PLAN_DIR" ]; then
  hook_log "enforce-rpi-cycle" "$FILE_PATH" "BLOCK" "no-plans-dir"
  cat >&2 <<EOF
[rpi] 차단: docs/superpowers/plans/ 디렉터리 없음.
  코드 변경 전 RPI 사이클을 시작하세요:
    "start-rpi-cycle 사용해서 <작업 설명>"
  trivial한 변경(≤5라인)이거나 docs 변경은 자동 허용됩니다.
  명시 우회: export RPI_SKIP="<이유>"
EOF
  exit 2
fi

# 활성 plan 식별 (로직은 _common.sh has_active_plan 으로 공유 — enforce-rpi-bash 와 동일 기준)
if ACTIVE=$(has_active_plan "$CWD"); then
  hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "plan=$(basename "$ACTIVE")"
  exit 0
fi

hook_log "enforce-rpi-cycle" "$FILE_PATH" "BLOCK" "no-active-plan"
cat >&2 <<EOF
[rpi] 차단: 활성 plan 없음 (docs/superpowers/plans/*.md).
  start-rpi-cycle을 사용해 R→P 단계를 먼저 완료하세요.
  ※ plan은 head-20에 명시 헤더 필요: **Status:** active (미체크 박스만으론 active 아님 — cycle-23)
  trivial 변경(≤5라인) 또는 docs 변경은 자동 허용.
  명시 우회: export RPI_SKIP="<이유>"
EOF
exit 2
