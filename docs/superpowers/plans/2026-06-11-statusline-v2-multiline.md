# Statusline v2 Multiline Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 22
**Started:** 2026-06-11

**Goal:** Rewrite `~/.claude/statusline.sh` as the spec'd 5-line status line (model/effort, workspace/cost, context bar, 5h+7d Claude rate-limit bars for both CCS accounts) with emoji icons, 256-color gradient bars, async-cached OAuth usage API, and Fable 5 `[1m]` window mapping.

**Architecture:** Single bash script, one foreground jq pass (stdin JSON + 2 slurped usage caches → all scalars), git info cached per-session (v1 mechanism), usage fetched by a detached background subshell guarded by an mkdir lock with atomic mv writes. No new foreground process spawns vs v1 (epoch/tz via `printf '%(%s)T'` builtins).

**Tech Stack:** bash 5 (Git Bash/mingw), jq, curl, git. Spec: `docs/superpowers/specs/2026-05-31-statusline-balanced-design.md` (v2).

**Files:**
- Create: `tests/statusline/fixtures/base-fable.json`, `tests/statusline/fixtures/fable-1m.json`, `tests/statusline/fixtures/opus.json`, `tests/statusline/fixtures/nongit.json`
- Create: `tests/statusline/run-tests.sh`
- Rewrite: `statusline.sh` (repo root = `~/.claude`)
- No change: `settings.json` (`statusLine` block already correct)

---

### Task 1: Test fixtures + runner (RED)

**Files:**
- Create: `tests/statusline/fixtures/*.json` (4 files)
- Create: `tests/statusline/run-tests.sh`

- [x] **Step 1.1: Create fixture `tests/statusline/fixtures/base-fable.json`** (real capture, trimmed; base Fable = 200K window, effort max, thinking on)

```json
{
  "session_id": "test-base-fable",
  "cwd": "C:\\Users\\12132\\.claude",
  "effort": { "level": "max" },
  "model": { "id": "claude-fable-5", "display_name": "Fable 5" },
  "workspace": { "current_dir": "C:\\Users\\12132\\.claude", "project_dir": "C:\\Users\\12132\\.claude" },
  "version": "2.1.172",
  "output_style": { "name": "default" },
  "cost": {
    "total_cost_usd": 2.2729669999999995,
    "total_duration_ms": 821563,
    "total_api_duration_ms": 362730,
    "total_lines_added": 0,
    "total_lines_removed": 0
  },
  "context_window": {
    "total_input_tokens": 74536,
    "total_output_tokens": 35,
    "context_window_size": 200000,
    "used_percentage": 37,
    "remaining_percentage": 63
  },
  "exceeds_200k_tokens": false,
  "thinking": { "enabled": true }
}
```

- [x] **Step 1.2: Create fixture `tests/statusline/fixtures/fable-1m.json`** (real capture from the 1M-variant session)

```json
{
  "session_id": "test-fable-1m",
  "cwd": "C:\\Users\\12132\\.claude",
  "effort": { "level": "max" },
  "model": { "id": "claude-fable-5[1m]", "display_name": "Fable 5" },
  "workspace": { "current_dir": "C:\\Users\\12132\\.claude", "project_dir": "C:\\Users\\12132\\.claude" },
  "version": "2.1.170",
  "output_style": { "name": "default" },
  "cost": {
    "total_cost_usd": 54.915023,
    "total_duration_ms": 79388850,
    "total_api_duration_ms": 4300729,
    "total_lines_added": 172,
    "total_lines_removed": 12
  },
  "context_window": {
    "total_input_tokens": 238991,
    "total_output_tokens": 2261,
    "context_window_size": 1000000,
    "used_percentage": 24,
    "remaining_percentage": 76
  },
  "exceeds_200k_tokens": true,
  "thinking": { "enabled": true }
}
```

- [x] **Step 1.3: Create fixture `tests/statusline/fixtures/opus.json`** (synthetic: proxy under-reports 200K for Opus → must floor to 1M, recompute % = 74536*100/1000000 = 7)

```json
{
  "session_id": "test-opus",
  "cwd": "C:\\Users\\12132\\.claude",
  "effort": { "level": "xhigh" },
  "model": { "id": "claude-opus-4-8", "display_name": "Opus 4.8" },
  "workspace": { "current_dir": "C:\\Users\\12132\\.claude" },
  "output_style": { "name": "default" },
  "cost": { "total_cost_usd": 0, "total_duration_ms": 30000, "total_lines_added": 0, "total_lines_removed": 0 },
  "context_window": { "total_input_tokens": 74536, "context_window_size": 200000, "used_percentage": 37 },
  "thinking": { "enabled": false }
}
```

- [x] **Step 1.4: Create fixture `tests/statusline/fixtures/nongit.json`** (cwd exists but is not a git repo → no branch segment)

```json
{
  "session_id": "test-nongit",
  "cwd": "C:\\Windows",
  "effort": { "level": "high" },
  "model": { "id": "claude-sonnet-4-6", "display_name": "Sonnet 4.6" },
  "workspace": { "current_dir": "C:\\Windows" },
  "output_style": { "name": "default" },
  "cost": { "total_cost_usd": 0.05, "total_duration_ms": 95000 },
  "context_window": { "total_input_tokens": 12000, "context_window_size": 1000000, "used_percentage": 1 },
  "thinking": { "enabled": true }
}
```

- [x] **Step 1.5: Create `tests/statusline/run-tests.sh`** (exact content below)

```bash
#!/usr/bin/env bash
# Fixture-driven tests for statusline.sh v2 (spec: 2026-05-31-statusline-balanced-design.md v2).
# Isolation: HOME/TMPDIR/USERPROFILE point at a throwaway dir per test, so
#   - usage caches are the seeded ones (no real ~/.ccs tokens, no network),
#   - the bg refresher finds no auth files and exits without curling.
set -u
SL="${SL:-$HOME/.claude/statusline.sh}"
FX="$(cd "$(dirname "$0")" && pwd)/fixtures"
PASS=0; FAIL=0

strip() { sed -e 's/\x1b\[[0-9;]*m//g'; }

run() { # run <fixture-file> <fake-home>   -> stdout (ANSI-stripped)
  HOME="$2" USERPROFILE="$2" TMPDIR="$2" bash "$SL" <"$FX/$1" 2>/dev/null | strip
}

seed_caches() { # seed_caches <dir> <age-secs> -> biz 25/26, indie 13/20; 5h reset +3h30m, 7d +24h
  local d=$1 age=$2 now fat r5 r7 tag u5 u7 spec
  printf -v now '%(%s)T' -1
  fat=$(( now - age )); r5=$(( now + 12630 )); r7=$(( now + 86400 ))
  for spec in "biz 25.0 26.0" "indie 13.0 20.0"; do
    read -r tag u5 u7 <<<"$spec"
    jq -n --argjson fat "$fat" --argjson u5 "$u5" --argjson u7 "$u7" \
          --argjson r5 "$r5" --argjson r7 "$r7" \
      '{fetched_at:$fat, data:{five_hour:{utilization:$u5, resets_at:($r5|todate)},
                               seven_day:{utilization:$u7, resets_at:($r7|todate)}}}' \
      >"$d/ccstatus-usage-$tag.json"
  done
}

check() { # check <desc> <haystack> <ERE-needle>
  if grep -qE -- "$3" <<<"$2"; then PASS=$((PASS+1)); echo "ok   - $1"
  else FAIL=$((FAIL+1)); echo "FAIL - $1 (wanted /$3/)"; sed 's/^/    | /' <<<"$2"; fi
}

# --- T1: base Fable (fresh caches) ---
d=$(mktemp -d); seed_caches "$d" 5
out=$(run base-fable.json "$d")
check "T1 renders 5 lines"            "$(wc -l <<<"$out")" '^5$'
check "T1 model name"                 "$out" 'Fable 5'
check "T1 no 1M chip on base model"   "$(head -1 <<<"$out")" '^[^[]*$'
check "T1 effort max"                 "$out" '✦ max'
check "T1 output style"               "$out" '⏵ default'
check "T1 thinking icon"              "$out" '🧠'
check "T1 full path"                  "$out" 'C:/Users/12132/\.claude'
check "T1 git branch shown"           "$out" '⎇'
check "T1 cost"                       "$out" '\$2\.27'
check "T1 duration 13m"               "$out" '⏱ 13m'
check "T1 context pct+tokens"         "$out" '37% \(74k/200k\)'
check "T1 5h biz 25%"                 "$out" 'biz [█░]+ 25%'
check "T1 5h indie 13%"               "$out" 'indie [█░]+ 13%'
check "T1 5h relative reset"          "$out" '\(3h(29|30)m\)'
check "T1 7d utils"                   "$out" 'biz [█░]+ 26% · indie [█░]+ 20%'
check "T1 7d date reset"              "$out" '\([0-9]{1,2}/[0-9]{1,2}(·[0-9]{1,2}/[0-9]{1,2})?\)'
check "T1 not stale"                  "$(grep -c stale <<<"$out")" '^0$'
rm -rf "$d"

# --- T2: Fable [1m] variant ---
d=$(mktemp -d); seed_caches "$d" 5
out=$(run fable-1m.json "$d")
check "T2 1M chip"                    "$out" '\[1M\]'
check "T2 ctx 24% 238k/1M"            "$out" '24% \(238k/1M\)'
check "T2 lines added/removed"        "$out" '✚172.*✖12'
check "T2 duration 22h3m"             "$out" '⏱ 22h3m'
rm -rf "$d"

# --- T3: Opus floor 200K -> 1M ---
d=$(mktemp -d); seed_caches "$d" 5
out=$(run opus.json "$d")
check "T3 floored window + recomputed pct" "$out" ' 7% \(74k/1M\)'
check "T3 zero cost hidden"           "$(grep -c '💰' <<<"$out")" '^0$'
rm -rf "$d"

# --- T4: missing caches -> placeholders, no crash ---
d=$(mktemp -d)
out=$(run base-fable.json "$d")
check "T4 still 5 lines"              "$(wc -l <<<"$out")" '^5$'
check "T4 placeholder gauges"         "$out" 'biz …'
check "T4 no stale marker on empty"   "$(grep -c stale <<<"$out")" '^0$'
rm -rf "$d"

# --- T5: stale caches (age 20min) ---
d=$(mktemp -d); seed_caches "$d" 1200
out=$(run base-fable.json "$d")
check "T5 utils still shown"          "$out" 'biz [█░]+ 25%'
check "T5 stale marker"               "$out" '\(stale\)'
rm -rf "$d"

# --- T6: non-git cwd ---
d=$(mktemp -d); seed_caches "$d" 5
out=$(run nongit.json "$d")
check "T6 no branch glyph"            "$(grep -c '⎇' <<<"$out")" '^0$'
check "T6 path shown"                 "$out" 'C:/Windows'
rm -rf "$d"

echo "---"
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [x] **Step 1.6: Run the suite — expect RED** (v1 prints 1 line, no emoji/limit lines)

Run: `bash ~/.claude/tests/statusline/run-tests.sh`
Expected: many `FAIL` lines (e.g. "T1 renders 5 lines" wants `^5$`, gets `1`), exit code 1.

### Task 2: Rewrite `statusline.sh`

**Files:**
- Rewrite: `statusline.sh` (full replacement; exact content below)

- [x] **Step 2.1: Replace `~/.claude/statusline.sh` with:**

```bash
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
def datefmt: . + $tz | gmtime | strftime("%m/%d") | sub("^0";"") | sub("/0";"/");
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

# gradient bar: filled cells colored by their POSITION on the scale (danger zone visible)
mkbar() { # mkbar <pct> <cells> <t1> <t2>   -> $BAR
  local pct=$1 cells=$2 t1=$3 t2=$4 out="" i p c filled
  filled=$(( pct * cells / 100 )); (( filled > cells )) && filled=$cells
  for (( i=1; i<=cells; i++ )); do
    if (( i <= filled )); then
      p=$(( i * 100 / cells ))
      if   (( p >= t2 )); then c=196
      elif (( p >= t1 )); then c=221
      else                     c=114; fi
      out+=$'\033[38;5;'${c}$'m█'
    else out+=$'\033[38;5;238m░'; fi
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
       *Opus*)                       CW=1000000 ;;  # proxy under-reports Opus
       *GPT-5.5*|*gpt-5.5*)          CW=272000  ;;  # custom slot (OpenAI std tier)
       *Haiku*|*mini*|*Mini*)        CW=272000  ;;  # haiku slot -> gpt-5.4-mini
       *)                            CW=0       ;;  # base Fable/Sonnet report correctly
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
[ "${ADDED:-0}" -gt 0 ] 2>/dev/null && L2+=" ${GR}✚${ADDED}${R}"
[ "${REMOVED:-0}" -gt 0 ] 2>/dev/null && L2+=" ${RD}✖${REMOVED}${R}"

# ---------- L3: context (ramp keyed to autocompact override 55%) ----------
mkbar "$PCT" 15 40 55
UK=$(( USED / 1000 ))
if (( SIZE >= 1000000 )); then SK="1M"; else SK="$(( SIZE / 1000 ))k"; fi
L3="⚡ ${B}Context${R}  ${BAR} ${PCT}% ${D}(${UK}k/${SK})${R}"

# ---------- L4/L5: Claude rate limits, both accounts ----------
acct_seg() { # acct_seg <tag> <tagcolor> <util>  -> $SEG
  local tag=$1 tc=$2 u=$3
  if [ "${u:--1}" -lt 0 ] 2>/dev/null; then SEG="${tc}${tag}${R} ${D}…${R}"
  else mkbar "$u" 8 50 80; SEG="${tc}${tag}${R} ${BAR} ${u}%"; fi
}
combine() { # combine <a> <b> -> $COMB ("a", "a·b", or "")
  local a=$1 b=$2
  if   [ -z "$a" ] && [ -z "$b" ]; then COMB=""
  elif [ -z "$b" ]; then COMB=$a
  elif [ -z "$a" ]; then COMB=$b
  elif [ "$a" = "$b" ]; then COMB=$a
  else COMB="$a·$b"; fi
}
STALE=""
{ [ "${B5:--1}" -ge 0 ] && [ "${BAGE:-0}" -gt "$STALE_AT" ]; } 2>/dev/null && STALE=" ${D}(stale)${R}"
{ [ "${I5:--1}" -ge 0 ] && [ "${IAGE:-0}" -gt "$STALE_AT" ]; } 2>/dev/null && STALE=" ${D}(stale)${R}"

acct_seg biz "$BLU" "$B5"; S1=$SEG
acct_seg indie "$MAG" "$I5"; S2=$SEG
combine "$B5R" "$I5R"
L4="🕐 ${B}5H Limit${R} $S1 ${D}·${R} $S2"
[ -n "$COMB" ] && L4+=" ${D}(${COMB})${R}"
L4+=$STALE

acct_seg biz "$BLU" "$B7"; S1=$SEG
acct_seg indie "$MAG" "$I7"; S2=$SEG
combine "$B7R" "$I7R"
L5="📅 ${B}7D Limit${R} $S1 ${D}·${R} $S2"
[ -n "$COMB" ] && L5+=" ${D}(${COMB})${R}"
L5+=$STALE

printf '%s\n%s\n%s\n%s\n%s\n' "$L1" "$L2" "$L3" "$L4" "$L5"
```

Implementation notes locked by spec (do not deviate):
- `parsedate` is offset-aware (Gate-R reviewer flag) — never assume `+00:00`.
- Usage cache is account-global (`ccstatus-usage-<tag>.json`), NOT session-scoped.
- Failed curl never overwrites the last good cache (`-f` + `|| continue` + atomic `mv`).
- The script only reads `access_token`; it never refreshes tokens (CCS proxy owns refresh).

### Task 3: Run tests → GREEN

- [x] **Step 3.1: Run the suite**

Run: `bash ~/.claude/tests/statusline/run-tests.sh`
Expected: every line `ok   - ...`, final `pass=N fail=0`, exit 0.

- [x] **Step 3.2: If any FAIL** — fix `statusline.sh` (not the assertions, unless an assertion contradicts the spec) and re-run until `fail=0`.

### Task 4: Live smoke + performance

- [x] **Step 4.1: Live render with real HOME** (real caches/auth; first run may fire the bg refresh, second run renders real utilization)

Run: `bash ~/.claude/statusline.sh < ~/.claude/tests/statusline/fixtures/base-fable.json; sleep 3; bash ~/.claude/statusline.sh < ~/.claude/tests/statusline/fixtures/base-fable.json`
Expected: second render shows real `biz NN%` / `indie NN%` bars (no `…`), reset strings shaped `(XhYm)` and `(M/D…)`.

- [x] **Step 4.2: Foreground latency**

Run: `time (bash ~/.claude/statusline.sh < ~/.claude/tests/statusline/fixtures/base-fable.json >/dev/null)`
Expected: real ≤ ~1s.

### Task 5: Commit

- [x] **Step 5.1: Commit all v2 artifacts**

```bash
git -C ~/.claude add statusline.sh tests/statusline/ \
  docs/superpowers/specs/2026-05-31-statusline-balanced-design.md \
  docs/superpowers/plans/2026-06-11-statusline-v2-multiline.md
git -C ~/.claude commit -m "feat(statusline): v2 5-line redesign — 5h/7d rate-limit bars, Fable [1m] mapping, emoji/gradient (cycle-22)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Expected: clean commit; `git status` shows only pre-existing unrelated changes (`skills/ui-design/design.md`, `plugins/`) untouched.
