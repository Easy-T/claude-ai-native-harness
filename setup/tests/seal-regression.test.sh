#!/usr/bin/env bash
# Meta-test (cycle-31, G4-a): prove verify-setup.sh drift seals actually FAIL + non-zero exit
# when drift is injected. Acceptance-tier (peer of doctor.test.sh / verify-integration.sh),
# wired into verify-all.sh STAGE 2b — NOT a hooks/tests/cases.tsv unit case
# (so run-all stays 129 and verify-setup stays 65; this runner lives OUTSIDE verify-setup).
#
# Isolation (cycle-18 / #25 blueprint): replicate the live ~/.claude subset that verify-setup
# inspects into a fresh temp $HOME, mutate ONLY the replica, then run the replica's own
# verify-setup.sh under HOME=<replica>. The live ~/.claude is never written — proven at the
# end via cksum witnesses on every file any mutator could touch.
set -uo pipefail
SRC="$HOME/.claude"
PASS=0; FAIL=0
ok()  { echo "✓ $1"; PASS=$((PASS+1)); }
bad() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# --- live immutability witnesses: cksum files any mutator could touch, before & after ---
witness() { local f; for f in state.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv; do
              cksum "$SRC/$f" 2>/dev/null; done; }
LIVE_BEFORE="$(witness)"

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

# --- replicate the harness subset verify-setup.sh inspects (runtime dirs excluded for speed) ---
make_replica() {
  local C="$1/.claude" f d
  mkdir -p "$C"
  for f in CLAUDE.md README.md SECURITY.md settings.json settings.example.json state.json state.schema.json; do
    [ -f "$SRC/$f" ] && cp -p "$SRC/$f" "$C/$f"
  done
  for d in hooks setup skills agents commands; do
    [ -d "$SRC/$d" ] && cp -a "$SRC/$d" "$C/$d"
  done
  mkdir -p "$C/docs/superpowers/plans"
  cp -a "$SRC/docs/superpowers/plans/." "$C/docs/superpowers/plans/" 2>/dev/null || true
  rm -rf "$C/hooks/.log"   # drop runtime noise the seals never read
  chmod +x "$C/hooks/"*.sh "$C/setup/"*.sh 2>/dev/null || true  # guard cp -a +x loss on win32
}

run_replica_verify() {  # $1 = replica HOME ; echoes verify-setup output; return code = its exit
  HOME="$1" bash "$1/.claude/setup/verify-setup.sh" 2>&1
}

# === Control: an unmutated replica must PASS (seals do not false-fire on a clean copy) ===
CTRL="$ROOT/control"; mkdir -p "$CTRL"; make_replica "$CTRL"
OUT="$(run_replica_verify "$CTRL")"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q 'FAIL=0'; then
  ok "control: unmutated replica → verify-setup exit 0, FAIL=0"
else
  bad "control: replica exit=$RC (expected 0) — replica build/baseline broken. tail: $(printf '%s' "$OUT" | tail -3 | tr '\n' '|')"
fi

# === Mutant driver: build replica, apply mutator, require non-zero exit AND the seal's FAIL line ===
assert_seal_fires() {  # $1=label  $2=mutator-fn  $3=expected FAIL substring
  local label="$1" mut="$2" needle="$3"
  local h="$ROOT/mut_$label"; mkdir -p "$h"; make_replica "$h"
  "$mut" "$h/.claude"
  local out rc
  out="$(run_replica_verify "$h")"; rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qF "$needle"; then
    ok "mutant[$label]: exit=$rc (non-zero) + seal FAIL «$needle»"
  else
    bad "mutant[$label]: rc=$rc, missing «$needle». tail: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  fi
}

# Mutator 1 — seal #30 (state.json ↔ schema): corrupt cycle.count integer → string.
mut_state_count_string() { sed -i -E 's/("count":[[:space:]]*)([0-9]+)/\1"\2"/' "$1/state.json"; }
# Mutator 2 — seal #23 (settings.json ↔ example harness-hook parity): shrink a harness hook matcher.
mut_settings_matcher()   { sed -i 's/"Write|Edit|NotebookEdit"/"Write|Edit"/' "$1/settings.json"; }
# Mutator 3 — seal #20 (README cases count ↔ cases.tsv actual): drift the declared count down by 1.
mut_readme_cases() {
  local actual; actual=$(grep -vcE '^[[:space:]]*(#|$)' "$1/hooks/tests/cases.tsv")
  sed -i -E "s/${actual} (케이스|cases?)/$((actual-1)) \1/g" "$1/README.md"
}

assert_seal_fires "state_schema"    mut_state_count_string "state.json schema 위반"
assert_seal_fires "settings_parity" mut_settings_matcher   "settings/example harness-hook drift"
assert_seal_fires "readme_cases"    mut_readme_cases       "README cases drift"

# === Live immutability: witnessed files byte-identical (all mutation stayed in replicas) ===
LIVE_AFTER="$(witness)"
if [ "$LIVE_BEFORE" = "$LIVE_AFTER" ]; then
  ok "live ~/.claude untouched (witness cksum stable across run)"
else
  bad "live ~/.claude MUTATED during run — isolation breach"
fi

echo
echo "seal-regression: PASS=$PASS FAIL=$FAIL"
exit $FAIL
