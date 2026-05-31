#!/usr/bin/env bash
# Claude Code status line — "Balanced" single-line design (RPI cycle 11).
# Layout: model · dir (branch +staged~modified) · context-bar pct usedk/sizek · $cost
# Reads session JSON on stdin. Docs: https://code.claude.com/docs/en/statusline
#   - git status is cached per session_id (5s TTL) to survive the ~300ms refresh cadence.
#   - bar color thresholds (40/55) are tuned to this user's autocompact override (55%).
#   - no emoji, forward-slash paths, printf output → robust on Windows Git Bash.
#   - fields joined by \037 (unit separator), NOT tab: tab is IFS-whitespace and would
#     collapse consecutive separators / strip leading empties, mangling empty fields.
in=$(cat)

# One jq pass → \037-separated scalars (model, dir, pct, used_tokens, size, cost, cents, session_id).
IFS=$'\037' read -r MODEL DIR PCT USED SIZE COST CENTS SID <<<"$(jq -r '[
  .model.display_name // "",
  (.workspace.current_dir // .cwd // ""),
  (.context_window.used_percentage // 0 | floor),
  (.context_window.total_input_tokens // 0),
  (.context_window.context_window_size // 200000),
  (.cost.total_cost_usd // 0),
  ((.cost.total_cost_usd // 0) * 100 | floor),
  (.session_id // "nosess")
] | map(tostring) | join("")' <<<"$in")"

DIR=${DIR//\\//}; NAME=${DIR##*/}            # normalize Windows backslashes, take basename

B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
CY=$'\033[36m'; GR=$'\033[32m'; YL=$'\033[33m'; RD=$'\033[31m'
SEP="${D} · ${R}"

# git branch + staged/modified counts, cached per session (5s TTL) — avoids running git every refresh.
CACHE="${TMPDIR:-/tmp}/ccstatus-git-${SID}"
mtime=$(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0)
if [ ! -f "$CACHE" ] || [ "$(( $(date +%s) - mtime ))" -gt 5 ]; then
  if [ -n "$DIR" ] && BR=$(git -C "$DIR" branch --show-current 2>/dev/null); then
    ST=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | grep -c .)
    MD=$(git -C "$DIR" diff          --numstat 2>/dev/null | grep -c .)
  else
    BR=""; ST=0; MD=0
  fi
  printf '%s\037%s\037%s\n' "$BR" "$ST" "$MD" >"$CACHE"
fi
IFS=$'\037' read -r BR ST MD <"$CACHE"

# The CCS proxy under-reports context_window_size (often 200000) regardless of the model's true
# window, so % can look maxed when it isn't. Map the visible model -> its real window as a FLOOR:
# only raise a too-small reported size, never lower a correctly-large one (so an opt-in 1M still
# wins), then recompute % from the actual token count. NOTE: reasoning effort (xhigh/max/...)
# does NOT change the window — it only spends thinking tokens within it; the window is per-model.
# Official windows researched 2026-05, reflecting THIS user's routing (Sonnet/Haiku -> GPT):
#   Opus 4.x               1,000,000   Anthropic: 1M default (API/Bedrock/Vertex)
#   Sonnet slot -> GPT-5.5    272,000   OpenAI standard tier (1M is a paid opt-in)
#   Haiku slot  -> GPT-5.4-mini 272,000 OpenAI GPT-5.4 family standard tier
#   (real Claude Sonnet 4.6 is itself 1M — raise the Sonnet line if you stop routing it to GPT)
case "$MODEL" in
  *Opus*)                        CW=1000000 ;;
  *Sonnet*|*GPT-5.5*|*gpt-5.5*)  CW=272000  ;;
  *Haiku*|*mini*|*Mini*)         CW=272000  ;;
  *)                             CW=0       ;;
esac
if (( CW > 0 && SIZE < CW )); then SIZE=$CW; (( SIZE > 0 )) && PCT=$(( USED * 100 / SIZE )); fi

# context bar (10 cells); threshold color keyed to the 55% autocompact point.
(( PCT < 0 )) && PCT=0; (( PCT > 100 )) && PCT=100
FILLED=$(( PCT / 10 )); EMPTY=$(( 10 - FILLED ))
printf -v F "%${FILLED}s"; printf -v E "%${EMPTY}s"
BAR="${F// /▓}${E// /░}"
if   (( PCT >= 55 )); then BC=$RD
elif (( PCT >= 40 )); then BC=$YL
else                       BC=$GR; fi

UK=$(( USED / 1000 ))
if (( SIZE >= 1000000 )); then SK="1M"; else SK="$(( SIZE / 1000 ))k"; fi

OUT="${B}${MODEL}${R}${SEP}${NAME}"
[ -n "$BR" ] && OUT+=" ${CY}(${BR})${R}"
[ "${ST:-0}" -gt 0 ] 2>/dev/null && OUT+=" ${GR}+${ST}${R}"
[ "${MD:-0}" -gt 0 ] 2>/dev/null && OUT+=" ${YL}~${MD}${R}"
OUT+="${SEP}${BC}${BAR} ${PCT}%${R} ${D}${UK}k/${SK}${R}"
(( ${CENTS:-0} > 0 )) && OUT+="${SEP}${D}$(printf '$%.2f' "$COST")${R}"

printf '%s\n' "$OUT"
