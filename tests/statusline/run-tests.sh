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
  # LC_ALL=C: byte-wise match — mingw grep's 16-bit wchar_t chokes on astral-plane
  # emoji (🧠) in UTF-8 mode; all needles are byte-safe under C locale.
  if LC_ALL=C grep -qE -- "$3" <<<"$2"; then PASS=$((PASS+1)); echo "ok   - $1"
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
