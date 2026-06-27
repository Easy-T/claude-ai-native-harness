#!/usr/bin/env bash
# _oracle/verify-all.sh — BUILD-BOX single verification entrypoint (lives in _oracle/, zip-EXCLUDED).
# Runs every unit test + the differential & discovery oracles + a clean-stage offline gate.
# Offline + NON-DESTRUCTIVE: never mutates ~/.config/opencode. Exit 1 on any FAIL.
#
# Usage:  bash _oracle/verify-all.sh
set -uo pipefail
ORACLE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE="$(cd "$ORACLE/.." && pwd)"
PASS=0; FAIL=0
ok()   { echo "✓ $1"; PASS=$((PASS+1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }

command -v node >/dev/null 2>&1 || { echo "✗ node not on PATH — cannot verify"; exit 1; }
command -v git  >/dev/null 2>&1 || echo "⚠ git not on PATH (worktree-prune live path untestable; non-fatal here)"

cd "$BUNDLE" || { echo "✗ cannot cd to bundle"; exit 1; }

# 1. unit tests — must run a REAL suite: an empty glob / 0 tests exits 0 and would
#    otherwise read as green (M7). Enforce a test-count floor + fail==0, not just exit code.
node --test tests/*.test.mjs >/tmp/_va_unit.log 2>&1; UT_RC=$?
# summary lines are "ℹ tests N" (spec reporter) or "# tests N" (tap reporter); match either.
_utn() { grep -oE "[[:space:]]$1 [0-9]+$" /tmp/_va_unit.log | grep -oE '[0-9]+$' | head -1; }
UT_TESTS="$(_utn tests)"; UT_PASS="$(_utn pass)"; UT_FAIL="$(_utn fail)"
UT_FLOOR=80   # current suite: 84 tests. Floor catches an empty glob (0) or a catastrophic drop.
if [ "$UT_RC" -eq 0 ] && [ -n "${UT_TESTS:-}" ] && [ "$UT_TESTS" -ge "$UT_FLOOR" ] && [ "${UT_FAIL:-1}" -eq 0 ]; then
  ok "unit tests (${UT_PASS:-?}/${UT_TESTS} pass, >= $UT_FLOOR floor)"
else
  fail "unit tests — rc=$UT_RC tests=${UT_TESTS:-0} fail=${UT_FAIL:-?} (floor $UT_FLOOR) — see /tmp/_va_unit.log"
fi

# 2. differential parser oracle
if node _oracle/diff-parsers.mjs 2>/dev/null | grep -q "OK diff==0"; then ok "differential parser oracle (diff==0)"; else fail "differential parser oracle"; fi

# 3. skill discovery (>=21, 0 violations)
SK="$(node _oracle/skill-discovery.mjs 2>/dev/null)"
if echo "$SK" | grep -q "0 violations"; then ok "skill-discovery — $SK"; else fail "skill-discovery — $SK"; fi

# 3b. init-ai-ready-project emission oracle (renders templates -> valid opencode-target project, spec §18)
if node _oracle/init-emission.mjs 2>/dev/null | grep -q "OK init-emission"; then ok "init-emission oracle (12 files, 0 violations)"; else fail "init-emission oracle — run: node _oracle/init-emission.mjs"; fi

# 4. clean-stage gate (spec §15/§17): the shipped stage is offline-loadable + install-trigger-free
source "$ORACLE/_stage.sh"
S="$(stage_bundle "$BUNDLE")"
trap 'rm -rf "$S"' EXIT
if [ -f "$S/package.json" ] && grep -q '"type"[[:space:]]*:[[:space:]]*"module"' "$S/package.json"; then
  ok "stage: package.json ships + type:module (plugin-load requirement)"
else
  fail "stage: package.json missing or not type:module"
fi
if [ ! -d "$S/node_modules" ] && [ ! -f "$S/package-lock.json" ] && ! ls "$S"/bun.lock* >/dev/null 2>&1; then
  ok "stage: no node_modules/lockfiles (offline-safe, no auto-install pollution)"
else
  fail "stage: install triggers leaked into the shipped stage"
fi
if [ ! -f "$S/opencode.json" ]; then fail "stage: opencode.json missing from shipped stage"; elif grep -qE '"urls"' "$S/opencode.json"; then fail "stage: opencode.json declares network skills.urls"; else ok "stage: opencode.json has no network skills.urls"; fi
# offline plugin import + init (relative specifier; cwd = stage)
if ( cd "$S" && node --input-type=module -e "await import('./plugin/governance.js').then(m=>m.Governance({client:{},directory:'.'}))" ) >/tmp/_va_plug.log 2>&1; then
  ok "stage: plugin imports + inits offline"
else
  fail "stage: plugin import/init failed — see /tmp/_va_plug.log"
fi

echo "verify-all: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
