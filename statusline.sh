#!/usr/bin/env bash
# Claude Code status line — v2 "screenshot-parity" 5-line design (RPI cycle 22).
# Spec: docs/superpowers/specs/2026-05-31-statusline-balanced-design.md (v2 2026-06-11).
#   L1 model [1M] · effort · output-style · thinking
#   L2 path · git(branch +staged~mod) · cost · duration · lines±
#   L3 context gradient bar (floor-mapped window, autocompact-55% ramp)
#   L4/L5 Claude 5h/7d rate limits for BOTH CCS accounts (OAuth usage API, async cache)
# Constraints: ~300ms refresh cadence on Windows Git Bash → no new foreground spawns:
#   one jq pass for everything; epoch/tz via printf builtins; git cached 5s/session;
#   usage fetched by a detached bg subshell (mkdir lock, atomic mv, 60s TTL).
in=$(cat)

# ---------- config ----------
ACCTS=(biz:claude-bizdev@nice.co.kr indie:claude-indietogo@gmail.com)  # tag:email (auth file stem)
AUTH_DIR="$HOME/.ccs/cliproxy/auth"
TMP="${TMPDIR:-/tmp}"
USAGE_TTL=60 STALE_AT=900 LOCK="$TMP/ccstatus-usage.lock"

printf -v NOW '%(%s)T' -1
printf -v TZOFF '%(%z)T' -1                    # e.g. +0900
TZSEC=$(( 10#${TZOFF:1:2} * 3600 + 10#${TZOFF:3:2} * 60 ))
[ "${TZOFF:0:1}" = "-" ] && TZSEC=$(( -TZSEC ))

BC="$TMP/ccstatus-usage-biz.json"; IC="$TMP/ccstatus-usage-indie.json"
[ -s "$BC" ] || printf '{}' >"$BC"
[ -s "$IC" ] || printf '{}' >"$IC"

# ---------- single jq pass: stdin fields + both usage caches ----------
# resets_at arrives as ISO8601 with fractional seconds and an offset (+00:00 observed,
# but parse offset-aware rather than assuming UTC). 7d reset renders as LOCAL M/D via
# epoch+TZSEC+gmtime (mingw jq localtime is unreliable).
JQ='
def parsedate:
  try (capture("^(?<d>[0-9T:-]+)(\\.[0-9]+)?(?<o>Z|[+-][0-9]{2}:[0-9]{2})?$")
       | ((.d + "Z") | fromdateiso8601)
         - (if .o == null or .o == "Z" then 0
            else (if .o[0:1] == "-" then -1 else 1 end) * ((.o[1:3]|tonumber)*3600 + (.o[4:6]|tonumber)*60)
            end))
  catch null;
def relfmt: ((./3600)|floor) as $h | (((. % 3600)/60)|floor) as $m
  | if . <= 0 then "now" elif $h > 0 then "\($h)h\($m)m" else "\($m)m" end;
def datefmt: . + $tz | gmtime as $t | $t[3] as $h
  | "\($t[1]+1)/\($t[2]) \(if $h % 12 == 0 then 12 else $h % 12 end)\(if $h < 12 then "am" else "pm" end)";
def age($c): ($c[0] // {}) | if .fetched_at then ($now - .fetched_at) else 999999 end;
def acct($c): (($c[0] // {}).data // {}) as $d
  | [ ($d.five_hour.utilization  // -1 | floor),
      (($d.five_hour.resets_at  // null | if . then parsedate else null end) as $r
        | if $r then (($r - $now) | relfmt) else "" end),
      ($d.seven_day.utilization  // -1 | floor),
      (($d.seven_day.resets_at  // null | if . then parsedate else null end) as $r
        | if $r then ($r | datefmt) else "" end),
      age($c) ];
[ .model.display_name // "",
  .model.id // "",
  (.workspace.current_dir // .cwd // ""),
  (.context_window.used_percentage // 0 | floor),
  (.context_window.total_input_tokens // 0),
  (.context_window.context_window_size // 200000),
  (.cost.total_cost_usd // 0),
  ((.cost.total_cost_usd // 0) * 100 | floor),
  (.session_id // "nosess"),
  (.effort.level // ""),
  (.output_style.name // ""),
  (if .thinking.enabled == true then 1 else 0 end),
  ((.cost.total_duration_ms // 0) / 1000 | floor),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0) ]
+ acct($B) + acct($I)
+ [ (if (age($B) > '$USAGE_TTL') or (age($I) > '$USAGE_TTL') then 1 else 0 end) ]
| map(tostring) | join("")'

IFS=$'\037' read -r MODEL MID DIR PCT USED SIZE COST CENTS SID EFFORT OSTYLE THINK DSEC ADDED REMOVED \
  B5 B5R B7 B7R BAGE I5 I5R I7 I7R IAGE REFRESH \
  <<<"$(jq -r --slurpfile B "$BC" --slurpfile I "$IC" --argjson now "$NOW" --argjson tz "$TZSEC" "$JQ" <<<"$in")"

# ---------- background usage refresh (never blocks rendering) ----------
if [ "${REFRESH:-0}" = "1" ]; then
  if mkdir "$LOCK" 2>/dev/null; then
    (
      trap 'rmdir "$LOCK" 2>/dev/null' EXIT
      for spec in "${ACCTS[@]}"; do
        tag=${spec%%:*}; email=${spec#*:}
        f="$AUTH_DIR/$email.json"; cache="$TMP/ccstatus-usage-$tag.json"
        [ -f "$f" ] || continue
        tok=$(jq -r '.access_token // empty' "$f" 2>/dev/null)
        [ -n "$tok" ] || continue
        resp=$(curl -fs --max-time 8 \
                 -H "Authorization: Bearer $tok" \
                 -H "anthropic-beta: oauth-2025-04-20" \
                 https://api.anthropic.com/api/oauth/usage) || continue
        printf -v fnow '%(%s)T' -1
        printf '{"fetched_at":%s,"data":%s}' "$fnow" "$resp" >"$cache.tmp" \
          && mv -f "$cache.tmp" "$cache"        # atomic; failures keep last good cache
      done
    ) </dev/null >/dev/null 2>&1 & disown 2>/dev/null
  else  # contended/stuck lock: rare path, stat spawn acceptable here
    lm=$(stat -c %Y "$LOCK" 2>/dev/null || echo "$NOW")
    [ $(( NOW - lm )) -gt 300 ] && rm -rf "$LOCK" 2>/dev/null
  fi
fi

# ---------- ANSI palette ----------
B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
CY=$'\033[36m'; GR=$'\033[32m'; YL=$'\033[33m'; RD=$'\033[31m'
BLU=$'\033[94m'; MAG=$'\033[95m'; DCY=$'\033[2;36m'

# gradient bar: filled cells colored by their POSITION on the scale (danger zone visible).
# Run-length ANSI (emit a color code only when it CHANGES): Claude Code truncates the whole
# statusline at ~1024 raw bytes, and per-cell codes alone blew that budget (v2.1 fix).
mkbar() { # mkbar <pct> <cells> <t1> <t2>   -> $BAR
  local pct=$1 cells=$2 t1=$3 t2=$4 out="" i p c filled last="" ch
  filled=$(( pct * cells / 100 )); (( filled > cells )) && filled=$cells
  for (( i=1; i<=cells; i++ )); do
    if (( i <= filled )); then
      p=$(( i * 100 / cells ))
      if   (( p >= t2 )); then c=196
      elif (( p >= t1 )); then c=221
      else                     c=114; fi
      ch='█'
    else c=238; ch='░'; fi
    [ "$c" != "$last" ] && { out+=$'\033[38;5;'${c}m; last=$c; }
    out+=$ch
  done
  BAR="$out$R"
}

# ---------- git (v1 mechanism: per-session cache, 5s TTL) ----------
DIR=${DIR//\\//}
GCACHE="$TMP/ccstatus-git-$SID"
mtime=$(stat -c %Y "$GCACHE" 2>/dev/null || stat -f %m "$GCACHE" 2>/dev/null || echo 0)
if [ ! -f "$GCACHE" ] || [ $(( NOW - mtime )) -gt 5 ]; then
  if [ -n "$DIR" ] && BRA=$(git -C "$DIR" branch --show-current 2>/dev/null); then
    ST=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | grep -c .)
    MD=$(git -C "$DIR" diff          --numstat 2>/dev/null | grep -c .)
  else BRA=""; ST=0; MD=0; fi
  printf '%s\037%s\037%s\n' "$BRA" "$ST" "$MD" >"$GCACHE"
fi
IFS=$'\037' read -r BRA ST MD <"$GCACHE"

# ---------- context window mapping (FLOOR: only raise; [1m] id is SSOT for 1M) ----------
case "$MID" in
  *"[1m]") CW=1000000 ;;                         # any 1M picker variant
  *) case "$MODEL" in
       *Opus*|*Fable*)               CW=1000000 ;;  # CC under-reports both (Fable: live 368k/200k, v2.1)
       *GPT-5.6*|*gpt-5.6*)          CW=372000  ;;  # v2.2 Sol/Luna slots (CLIProxy 7.2.62-5 catalog)
       *GPT-5.5*|*gpt-5.5*)          CW=272000  ;;  # legacy custom slot (OpenAI std tier)
       *Haiku*|*mini*|*Mini*)        CW=272000  ;;  # legacy haiku slot -> gpt-5.4-mini
       *)                            CW=0       ;;  # real Sonnet reports correctly
     esac ;;
esac
if (( CW > 0 && SIZE < CW )); then SIZE=$CW; (( SIZE > 0 )) && PCT=$(( USED * 100 / SIZE )); fi
(( PCT < 0 )) && PCT=0; (( PCT > 100 )) && PCT=100

# ---------- L1: model & session mode ----------
L1="⚡ ${B}${MODEL}${R}"
case "$MID" in *"[1m]") L1+=" ${DCY}[1M]${R}" ;; esac
case "$EFFORT" in
  max)   EC=$MAG ;;
  xhigh) EC=$'\033[38;5;208m' ;;
  high)  EC=$YL ;;
  *)     EC=$D ;;
esac
[ -n "$EFFORT" ] && L1+=" ${EC}✦ ${EFFORT}${R}"
[ -n "$OSTYLE" ] && L1+=" ${DCY}⏵ ${OSTYLE}${R}"
[ "$THINK" = "1" ] && L1+=" 🧠"

# ---------- L2: workspace & session stats ----------
H=${HOME//\\//}; UP=${USERPROFILE:-}; UP=${UP//\\//}
case "$H" in /[a-zA-Z]/*) drv=${H:1:1}; WH="${drv^^}:${H:2}" ;; *) WH="$H" ;; esac
SHOW=$DIR
for pre in "$UP" "$WH" "$H"; do
  [ -n "$pre" ] || continue
  case "$SHOW" in "$pre") SHOW="~"; break ;; "$pre"/*) SHOW="~${SHOW#"$pre"}"; break ;; esac
done
L2="📁 ${BLU}${SHOW}${R}"
[ -n "$BRA" ] && L2+=" ${CY}⎇ ${BRA}${R}"
[ "${ST:-0}" -gt 0 ] 2>/dev/null && L2+=" ${GR}+${ST}${R}"
[ "${MD:-0}" -gt 0 ] 2>/dev/null && L2+=" ${YL}~${MD}${R}"
(( ${CENTS:-0} > 0 )) && L2+=" ${D}💰 $(printf '$%.2f' "$COST")${R}"
if   (( DSEC >= 3600 )); then DUR="$(( DSEC / 3600 ))h$(( (DSEC % 3600) / 60 ))m"
elif (( DSEC >= 60 ));   then DUR="$(( DSEC / 60 ))m"
else                          DUR=""; fi
[ -n "$DUR" ] && L2+=" ${D}⏱ ${DUR}${R}"
# ASCII +/- here: ✚/✖ render emoji-width and collide with the digits (v2.1)
[ "${ADDED:-0}" -gt 0 ] 2>/dev/null && L2+=" ${GR}+${ADDED}${R}"
[ "${REMOVED:-0}" -gt 0 ] 2>/dev/null && L2+=" ${RD}-${REMOVED}${R}"

# ---------- L3: context (ramp keyed to autocompact override 55%) ----------
mkbar "$PCT" 15 40 55
UK=$(( USED / 1000 ))
if (( SIZE >= 1000000 )); then SK="1M"; else SK="$(( SIZE / 1000 ))k"; fi
L3="⚡ ${B}Context${R}  ${BAR} ${PCT}% ${D}(${UK}k/${SK})${R}"

# ---------- L4/L5: Claude rate limits, both accounts ----------
# Reset time is INLINE per account (v2.1): the merged trailing display was ambiguous
# when the two accounts reset at different times.
acct_seg() { # acct_seg <tag> <tagcolor> <util> <reset>  -> $SEG
  local tag=$1 tc=$2 u=$3 rst=$4
  if [ "${u:--1}" -lt 0 ] 2>/dev/null; then SEG="${tc}${tag}${R} ${D}…${R}"
  else
    mkbar "$u" 8 50 80
    SEG="${tc}${tag}${R} ${BAR} ${u}%"
    [ -n "$rst" ] && SEG+=" ${D}(${rst})${R}"
  fi
}
STALE=""
{ [ "${B5:--1}" -ge 0 ] && [ "${BAGE:-0}" -gt "$STALE_AT" ]; } 2>/dev/null && STALE=" ${D}(stale)${R}"
{ [ "${I5:--1}" -ge 0 ] && [ "${IAGE:-0}" -gt "$STALE_AT" ]; } 2>/dev/null && STALE=" ${D}(stale)${R}"

acct_seg biz "$BLU" "$B5" "$B5R"; S1=$SEG
acct_seg indie "$MAG" "$I5" "$I5R"; S2=$SEG
L4="🕐 ${B}5H Limit${R} $S1 ${D}·${R} $S2$STALE"

acct_seg biz "$BLU" "$B7" "$B7R"; S1=$SEG
acct_seg indie "$MAG" "$I7" "$I7R"; S2=$SEG
L5="📅 ${B}7D Limit${R} $S1 ${D}·${R} $S2$STALE"

printf '%s\n%s\n%s\n%s\n%s\n' "$L1" "$L2" "$L3" "$L4" "$L5"
