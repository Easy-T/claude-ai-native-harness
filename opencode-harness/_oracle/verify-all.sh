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

# 1. unit tests
if node --test tests/*.test.mjs >/tmp/_va_unit.log 2>&1; then
  ok "unit tests ($(grep -oE '# pass [0-9]+' /tmp/_va_unit.log | head -1 || echo pass))"
else
  fail "unit tests — see /tmp/_va_unit.log"
fi

# 2. differential parser oracle
if node _oracle/diff-parsers.mjs 2>/dev/null | grep -q "OK diff==0"; then ok "differential parser oracle (diff==0)"; else fail "differential parser oracle"; fi

# 3. skill discovery (>=20, 0 violations)
SK="$(node _oracle/skill-discovery.mjs 2>/dev/null)"
if echo "$SK" | grep -q "0 violations"; then ok "skill-discovery — $SK"; else fail "skill-discovery — $SK"; fi

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
if grep -qE '"urls"' "$S/opencode.json" 2>/dev/null; then fail "stage: opencode.json declares network skills.urls"; else ok "stage: opencode.json has no network skills.urls"; fi
# offline plugin import + init (relative specifier; cwd = stage)
if ( cd "$S" && node --input-type=module -e "await import('./plugin/governance.js').then(m=>m.Governance({client:{},directory:'.'}))" ) >/tmp/_va_plug.log 2>&1; then
  ok "stage: plugin imports + inits offline"
else
  fail "stage: plugin import/init failed — see /tmp/_va_plug.log"
fi

echo "verify-all: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
