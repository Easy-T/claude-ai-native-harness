#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')
FILE_PATH=$(normalize_path "$FILE_PATH")
CWD=$(echo "$INPUT" | resolve_cwd) || CWD=""   # cwd 불명 → "." 기본값 미사용; 아래 "./CLAUDE.md"/"CLAUDE.md" 리터럴 케이스는 유지

# 글로벌 ~/.claude/CLAUDE.md 제외 (글로벌은 별도 audit hook이 관리)
[[ "$FILE_PATH" == "$HOME/.claude/CLAUDE.md" ]] && exit 0

# 모듈 CLAUDE.md 제외 (docs/modules/*/CLAUDE.md 등)
[[ "$FILE_PATH" == */modules/*/CLAUDE.md ]] && exit 0

# 루트 CLAUDE.md 매칭 (정확히 "CLAUDE.md" 또는 "<cwd>/CLAUDE.md" 또는 "./CLAUDE.md")
case "$FILE_PATH" in
  "$CWD/CLAUDE.md"|"./CLAUDE.md"|"CLAUDE.md") ;;
  *) exit 0 ;;
esac

hook_log "stable-claude-md" "$FILE_PATH" "ALERT" ""
cat >&2 <<EOF
[cache-stability] 루트 CLAUDE.md 수정 감지.
  세션 중 수정 시 prefix 캐시가 무효화됩니다 (다음 세션 비용 ≈20배).
  가능하면 세션 종료 직전에 모아서 수정하세요.
  (작업은 허용됨)
EOF
exit 0
