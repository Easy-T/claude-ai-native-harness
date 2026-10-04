#!/usr/bin/env bash
# Fixture-driven tests for statusline.sh v3 (spec: 2026-05-31-statusline-balanced-design.md v3).
# Isolation: HOME/TMPDIR/USERPROFILE point at a throwaway dir per test. L4/L5 data comes only from the
#   stdin `rate_limits` injected into the fixture — no caches, no tokens, no network.
set -u
SL="${SL:-$HOME/.claude/statusline.sh}"
FX="$(cd "$(dirname "$0")" && pwd)/fixtures"
PASS=0; FAIL=0

strip() { sed -e 's/\x1b\[[0-9;]*m//g'; }

run() { # run <fixture-file|abs-path> <fake-home>   -> stdout (ANSI-stripped)
  local f="$1"; [ -f "$f" ] || f="$FX/$1"
  HOME="$2" USERPROFILE="$2" TMPDIR="$2" bash "$SL" <"$f" 2>/dev/null | strip
}

with_limits() { # with_limits <fixture> <u5> <u7> [iso|isoneg|nores|junk] -> writes $d/in.json (needs $d); 5h reset +3h30m, 7d +24h
  # isoneg also writes $d/ref.json: the same instants as epoch seconds (the deterministic expectation).
  local now r5 r7; printf -v now '%(%s)T' -1; r5=$(( now + 12630 )); r7=$(( now + 86400 ))
  case "${4:-}" in
    iso)  jq --argjson u5 "$2" --argjson u7 "$3" --argjson r5 "$r5" --argjson r7 "$r7" \
            '. + {rate_limits:{five_hour:{used_percentage:$u5,resets_at:($r5|todate)},seven_day:{used_percentage:$u7,resets_at:($r7|todate)}}}' "$FX/$1" >"$d/in.json" ;;
    isoneg) # local wall time at -05:00 = UTC - 5h; 5h value carries fractional seconds
          jq --argjson u5 "$2" --argjson u7 "$3" --argjson r5 "$r5" --argjson r7 "$r7" \
            '. + {rate_limits:{five_hour:{used_percentage:$u5,resets_at:((($r5-18000)|todate|rtrimstr("Z"))+".250-05:00")},seven_day:{used_percentage:$u7,resets_at:((($r7-18000)|todate|rtrimstr("Z"))+"-05:00")}}}' "$FX/$1" >"$d/in.json"
          jq --argjson u5 "$2" --argjson u7 "$3" --argjson r5 "$r5" --argjson r7 "$r7" \
            '. + {rate_limits:{five_hour:{used_percentage:$u5,resets_at:$r5},seven_day:{used_percentage:$u7,resets_at:$r7}}}' "$FX/$1" >"$d/ref.json" ;;
    nores) jq --argjson u5 "$2" --argjson u7 "$3" --argjson r7 "$r7" \
            '. + {rate_limits:{five_hour:{used_percentage:$u5},seven_day:{used_percentage:$u7,resets_at:$r7}}}' "$FX/$1" >"$d/in.json" ;;
    junk) jq --argjson u5 "$2" --argjson u7 "$3" --argjson r7 "$r7" \
            '. + {rate_limits:{five_hour:{used_percentage:$u5,resets_at:"not-a-date"},seven_day:{used_percentage:$u7,resets_at:$r7}}}' "$FX/$1" >"$d/in.json" ;;
    *)    jq --argjson u5 "$2" --argjson u7 "$3" --argjson r5 "$r5" --argjson r7 "$r7" \
            '. + {rate_limits:{five_hour:{used_percentage:$u5,resets_at:$r5},seven_day:{used_percentage:$u7,resets_at:$r7}}}' "$FX/$1" >"$d/in.json" ;;
  esac
}

check() { # check <desc> <haystack> <ERE-needle>
  # LC_ALL=C: byte-wise match — mingw grep's 16-bit wchar_t chokes on astral-plane
  # emoji (🧠) in UTF-8 mode; all needles are byte-safe under C locale.
  if LC_ALL=C grep -qE -- "$3" <<<"$2"; then PASS=$((PASS+1)); echo "ok   - $1"
  else FAIL=$((FAIL+1)); echo "FAIL - $1 (wanted /$3/)"; sed 's/^/    | /' <<<"$2"; fi
}

# --- T1: base Fable (stdin rate_limits) ---
d=$(mktemp -d); with_limits base-fable.json 25 26
out=$(run "$d/in.json" "$d")
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
check "T1 base Fable floored to 1M"   "$out" ' 7% \(74k/1M\)'
check "T1 5h bar + inline reset"      "$out" '5H Limit [█░]+ 25% \(3h(29|30)m\)'
check "T1 7d bar + date/hour"         "$out" '7D Limit [█░]+ 26% \([0-9]{1,2}/[0-9]{1,2} [0-9]{1,2}(am|pm)\)'
check "T1 no account tags"            "$(grep -cE 'biz|indie' <<<"$out")" '^0$'
# Claude Code truncates statusline output at ~1024 raw bytes (live v2.1 finding) — hard budget.
rawbytes=$(HOME="$d" USERPROFILE="$d" TMPDIR="$d" bash "$SL" <"$d/in.json" 2>/dev/null | wc -c)
check "T1 raw output ≤1000 bytes"     "$rawbytes" '^([1-9][0-9]{0,2}|1000)$'
rm -rf "$d"

# --- T2: Fable [1m] variant ---
d=$(mktemp -d)
out=$(run fable-1m.json "$d")
check "T2 1M chip"                    "$out" '\[1M\]'
check "T2 ctx 24% 238k/1M"            "$out" '24% \(238k/1M\)'
check "T2 lines added/removed ASCII"  "$out" '\+172.*-12'
check "T2 duration 22h3m"             "$out" '⏱ 22h3m'
rm -rf "$d"

# --- T3: Opus floor 200K -> 1M ---
d=$(mktemp -d)
out=$(run opus.json "$d")
check "T3 floored window + recomputed pct" "$out" ' 7% \(74k/1M\)'
check "T3 zero cost hidden"           "$(grep -c '💰' <<<"$out")" '^0$'
rm -rf "$d"

# --- T4: no rate_limits in stdin (API-key auth / older CC / before 1st response) -> placeholders, no crash ---
d=$(mktemp -d)
out=$(run base-fable.json "$d")
check "T4 still 5 lines"              "$(wc -l <<<"$out")" '^5$'
check "T4 5h placeholder"             "$out" '5H Limit …'
check "T4 7d placeholder"             "$out" '7D Limit …'
rm -rf "$d"

# --- T5: resets_at as ISO-8601 string (robustness) ---
d=$(mktemp -d); with_limits base-fable.json 25 26 iso
out=$(run "$d/in.json" "$d")
check "T5 ISO resets_at parsed"       "$out" '5H Limit [█░]+ 25% \(3h(29|30)m\)'
rm -rf "$d"

# --- T5b: unparseable resets_at -> bar kept, suffix dropped, field alignment intact ---
d=$(mktemp -d); with_limits base-fable.json 25 26 junk
out=$(run "$d/in.json" "$d")
check "T5b unparseable reset -> bar kept, no suffix" "$out" '5H Limit [█░]+ 25%$'
check "T5b 7d unaffected"             "$out" '7D Limit [█░]+ 26% \('
rm -rf "$d"

# --- T5c: ISO resets_at with a NEGATIVE offset (-05:00, 5h also fractional) == the same instant as epoch ---
d=$(mktemp -d); with_limits base-fable.json 25 26 isoneg
out=$(run "$d/in.json" "$d"); ref=$(run "$d/ref.json" "$d")
for n in 4 5; do
  got=$(sed -n "${n}p" <<<"$out"); want=$(sed -n "${n}p" <<<"$ref")
  check "T5c -05:00 ISO line $n == epoch render" "$([ "$got" = "$want" ] && echo same || echo "got=[$got] want=[$want]")" '^same$'
done
check "T5c 5h suffix present"         "$out" '5H Limit [█░]+ 25% \(3h(29|30)m\)$'
rm -rf "$d"

# --- T5d: used_percentage without resets_at -> bar + % kept, suffix omitted, other fields not shifted ---
d=$(mktemp -d); with_limits base-fable.json 25 26 nores
out=$(run "$d/in.json" "$d")
check "T5d no resets_at -> bar kept, no suffix" "$out" '5H Limit [█░]+ 25%$'
check "T5d 7d not shifted"            "$out" '7D Limit [█░]+ 26% \([0-9]{1,2}/[0-9]{1,2} [0-9]{1,2}(am|pm)\)$'
rm -rf "$d"

# --- T6: non-git cwd ---
d=$(mktemp -d)
out=$(run nongit.json "$d")
check "T6 no branch glyph"            "$(grep -c '⎇' <<<"$out")" '^0$'
check "T6 path shown"                 "$out" 'C:/Windows'
rm -rf "$d"

# --- T7: GPT-5.6 slot floor 200K -> 372K (v2.2, gpt-5.6 Sol/Luna swap 2026-07-12) ---
d=$(mktemp -d)
out=$(run gpt56-luna.json "$d")
check "T7 floored to 372k + recomputed pct" "$out" '20% \(74k/372k\)'
check "T7 no 1M chip on gpt slot"     "$(head -1 <<<"$out")" '^[^[]*$'
rm -rf "$d"

# --- T8: v3 reads no credential file and makes no network call ---
check "T8 no credential read / network" "$(grep -vE '^[[:space:]]*#' "$SL" | grep -ciE 'curl|wget|fetch|https?://|/dev/tcp|Invoke-WebRequest|\.ccs|auth\.json|credentials|access_token|\.codex/|\.opencodex/')" '^0$'

echo "---"
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
