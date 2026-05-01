#!/usr/bin/env bash
# Project-level deny pattern enforcement.
# Parses docs/ai-context/deny-patterns.md, blocks tool calls matching any "- ❌ " line.

set -euo pipefail

[ -f "$HOME/.claude/hooks/_common.sh" ] && source "$HOME/.claude/hooks/_common.sh"

INPUT="$(cat)"
DENY_FILE="docs/ai-context/deny-patterns.md"
[ ! -f "$DENY_FILE" ] && exit 0

TOOL_INPUT="$(echo "$INPUT" | node -e '
  let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>{
    try { const o=JSON.parse(d); console.log(JSON.stringify(o.tool_input||{})); } catch(e){}
  });
')"
[ -z "$TOOL_INPUT" ] && exit 0

while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  if echo "$TOOL_INPUT" | grep -qiF -- "$pattern"; then
    echo "[deny-pattern] 차단: $pattern" >&2
    echo "[deny-pattern] 출처: $DENY_FILE" >&2
    exit 2
  fi
done < <(grep -E '^- ❌ ' "$DENY_FILE" | sed 's/^- ❌ //')

exit 0
