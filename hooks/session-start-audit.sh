#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
[ ! -f "$CLAUDE_MD" ] && {
  echo "[audit] 글로벌 CLAUDE.md 없음. /init-ai-ready 1회 실행 권장." >&2
  exit 0
}

# audit 마커 추출 — 가장 최근 것
MARKER=$(grep -E '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD" | tail -1 | sed -E 's/.*audit: ([0-9-]+).*/\1/')

if [ -z "$MARKER" ]; then
  echo "[audit] 마커 없음. 다음 /init-ai-ready 실행 시 자동 점검됩니다." >&2
  exit 0
fi

# 30일 경과 계산 (YYYY-MM-DD 비교)
TODAY=$(date +%Y-%m-%d)
DAYS_AGO=$(node -e '
  const m = process.argv[1];
  const t = process.argv[2];
  const ms = (new Date(t) - new Date(m)) / 86400000;
  console.log(isNaN(ms) ? 0 : Math.floor(ms));
' "$MARKER" "$TODAY")

if (( DAYS_AGO > 30 )); then
  hook_log "session-start-audit" "global-CLAUDE.md" "ALERT" "${DAYS_AGO}d"
  cat >&2 <<EOF
[audit] 마지막 audit 후 ${DAYS_AGO}일 경과 (마커: $MARKER).
  다음 /init-ai-ready 실행 시 자동 점검됩니다.
  강제 점검: bash ~/.claude/setup/doctor.sh
EOF
fi
exit 0
