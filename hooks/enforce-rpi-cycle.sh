#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')
FILE_PATH=$(normalize_path "$FILE_PATH")
TOOL=$(echo "$INPUT" | json_get 'tool_name')
CWD=$(echo "$INPUT" | json_get 'cwd')
CWD=$(normalize_path "$CWD")
[ -z "$CWD" ] && CWD="."

# === 화이트리스트 1: 비코드 파일 통과 ===
case "$FILE_PATH" in
  *.md|*.txt|*.gitignore|*/CLAUDE.md|*/README*|*/.gitkeep) exit 0 ;;
  */docs/*) exit 0 ;;
  */.claude/*) exit 0 ;;          # 프로젝트 .claude 설정
  */.github/*) exit 0 ;;          # CI 설정
  */superpowers/*) exit 0 ;;      # superpowers 디렉터리
esac

# === 화이트리스트 2: trivial change (≤5 라인) ===
OLD="" NEW=""
if [[ "$TOOL" == "Edit" ]]; then
  OLD=$(echo "$INPUT" | json_get 'tool_input.old_string')
  NEW=$(echo "$INPUT" | json_get 'tool_input.new_string')
elif [[ "$TOOL" == "Write" ]]; then
  NEW=$(echo "$INPUT" | json_get 'tool_input.content')
fi
if [[ -n "$OLD$NEW" ]]; then
  TOTAL_LINES=$(printf '%s\n%s\n' "$OLD" "$NEW" | wc -l)
  (( TOTAL_LINES <= 5 )) && {
    hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "trivial"
    exit 0
  }
fi

# === 화이트리스트 3: 명시 우회 ===
if [ -n "${RPI_SKIP:-}" ]; then
  hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "skip:${RPI_SKIP}"
  echo "[rpi] SKIP: $RPI_SKIP" >&2
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

# 활성 plan 식별 (우선순위)
ACTIVE=""
for plan in "$PLAN_DIR"/*.md; do
  [ ! -f "$plan" ] && continue
  # 1순위: 명시적 Status (있으면 우선)
  STATUS=$(head -20 "$plan" | grep -m1 -E '^\*?\*?[Ss]tatus:?\*?\*?' | sed -E 's/^\*?\*?[Ss]tatus:?\*?\*?\s*//' | tr -d ' ' || true)
  case "$STATUS" in
    completed|abandoned|archived|paused) continue ;;     # paused 명시 (체크박스 fallback 회피)
    active|in_progress) ACTIVE="$plan"; break ;;
  esac
  # 2순위: frontmatter 없으면 미완료 체크박스 존재 여부로 판별
  if grep -qE '^- \[ \]' "$plan"; then
    ACTIVE="$plan"
    break
  fi
done

if [ -z "$ACTIVE" ]; then
  hook_log "enforce-rpi-cycle" "$FILE_PATH" "BLOCK" "no-active-plan"
  cat >&2 <<EOF
[rpi] 차단: 활성 plan 없음 (docs/superpowers/plans/*.md).
  start-rpi-cycle을 사용해 R→P 단계를 먼저 완료하세요.
  trivial 변경(≤5라인) 또는 docs 변경은 자동 허용.
  명시 우회: export RPI_SKIP="<이유>"
EOF
  exit 2
fi

hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "plan=$(basename "$ACTIVE")"
exit 0
