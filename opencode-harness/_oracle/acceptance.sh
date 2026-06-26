#!/usr/bin/env bash
# _oracle/acceptance.sh — BUILD-BOX zip acceptance test (lives in _oracle/, zip-EXCLUDED).
# Produces the SHIP tree (stage_bundle = the exact set the README zip ships), round-trips it
# through a REAL archive (zip on Linux, else PowerShell Compress-Archive on Windows), unzips to
# a fresh temp, and asserts the result is SELF-CONTAINED + OFFLINE-LOADABLE. Non-destructive:
# never touches ~/.config/opencode. Exit 1 on any FAIL.
#
# Usage:  bash _oracle/acceptance.sh
set -uo pipefail
# Build-box PATH (this script never ships): ensure node, git, unzip, and PowerShell are reachable.
export PATH="/usr/bin:/bin:/c/Program Files/nodejs:/c/Program Files/Git/cmd:/c/Windows/System32:/c/Windows/System32/WindowsPowerShell/v1.0:$PATH"
ORACLE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE="$(cd "$ORACLE/.." && pwd)"
PASS=0; FAIL=0
ok()   { echo "✓ $1"; PASS=$((PASS+1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }
command -v node  >/dev/null 2>&1 || { echo "✗ node not on PATH — cannot run acceptance"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "✗ unzip not on PATH — cannot run acceptance"; exit 1; }

source "$ORACLE/_stage.sh"
WORK="$(mktemp -d)"; ZIP="$WORK/opencode-harness.zip"; OUT="$WORK/unzipped"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

# 1. SHIP tree = stage_bundle (identical exclusion set to the README zip -x list: _oracle, tests,
#    node_modules, .git, lockfiles — package.json KEPT). Then a real archive round-trip.
SHIP="$(stage_bundle "$BUNDLE")"
make_zip_ok=0
if command -v zip >/dev/null 2>&1; then
  ( cd "$SHIP" && zip -rq "$ZIP" . ) && make_zip_ok=1   # Linux/company: real `zip`
elif command -v powershell.exe >/dev/null 2>&1; then
  SW="$(cygpath -w "$SHIP")"; ZW="$(cygpath -w "$ZIP")"
  powershell.exe -NoProfile -Command "Compress-Archive -Path '$SW\\*' -DestinationPath '$ZW' -Force" >/dev/null 2>&1 && make_zip_ok=1
fi
if [ "$make_zip_ok" = 1 ] && [ -f "$ZIP" ]; then
  ok "zip built ($(du -h "$ZIP" 2>/dev/null | cut -f1 || echo '?'))"
  # Info-ZIP `unzip` exits 1 with a warning on PowerShell Compress-Archive's backslash-separator
  # zips (a Windows-only Compress-Archive quirk; the documented `zip` on Linux is forward-slash and
  # clean). Extraction still succeeds — verify by the extracted tree, not unzip's exit code.
  ( cd "$OUT" && unzip -qo "$ZIP" >/dev/null 2>&1 ) || true
  if [ -f "$OUT/package.json" ] && [ -d "$OUT/plugin" ]; then ok "unzip extracted ship tree"; else fail "unzip produced no usable tree"; fi
else
  fail "no archiver (zip/PowerShell) available — falling back to staged ship tree (round-trip skipped)"
  cp -r "$SHIP"/. "$OUT"/ 2>/dev/null
fi
rm -rf "$SHIP"

# 2. install triggers / build-box-only payload MUST be absent from the shipped tree
for bad in node_modules package-lock.json _oracle tests .git; do
  if [ -e "$OUT/$bad" ]; then fail "ship leaked: $bad"; else ok "ship excludes $bad"; fi
done
if ls "$OUT"/bun.lock* >/dev/null 2>&1; then fail "ship leaked: bun.lock*"; else ok "ship excludes bun.lock*"; fi

# 3. required SHIP files present
for need in package.json AGENTS.md opencode.json README.md install.sh PREREQUISITES.md \
            plugin/governance.js plugin/lib/advisories.js plugin/lib/worktree.js plugin/lib/fail-open.js \
            plugin/gates/rpi-gate.js plugin/gates/secret-gate.js plugin/gates/orchestrator-gate.js \
            agent/explore-strict.md agent/review-strict.md agent/execute-strict.md; do
  if [ -f "$OUT/$need" ]; then ok "ships: $need"; else fail "MISSING: $need"; fi
done

# 4. package.json: type:module + NO runtime @opencode-ai/plugin dependency (offline-safe)
if grep -q '"type"[[:space:]]*:[[:space:]]*"module"' "$OUT/package.json"; then ok "package.json type:module"; else fail "package.json not type:module"; fi
if ( cd "$OUT" && node -e "const p=require('./package.json'); process.exit(p.dependencies && p.dependencies['@opencode-ai/plugin'] ? 1 : 0)" ); then ok "no runtime @opencode-ai/plugin dependency"; else fail "@opencode-ai/plugin is a runtime dependency"; fi

# 5. opencode.json: no network skills.urls, has permission.skill
if grep -qE '"urls"' "$OUT/opencode.json"; then fail "opencode.json declares network skills.urls"; else ok "no network skills.urls"; fi
if ( cd "$OUT" && node -e "const c=require('./opencode.json'); process.exit(c.permission&&c.permission.skill?0:1)" ); then ok "permission.skill present"; else fail "permission.skill missing"; fi

# 6. skills shipped (>=20 SKILL.md in the unzipped tree)
SKN="$(find "$OUT/skill" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
if [ "${SKN:-0}" -ge 20 ]; then ok "shipped skill/ has $SKN SKILL.md (>=20)"; else fail "shipped skill/ has only ${SKN:-0} SKILL.md"; fi

# 7. OFFLINE plugin import + init from the unzipped tree (the decisive load proof)
if ( cd "$OUT" && node --input-type=module -e "await import('./plugin/governance.js').then(m=>m.Governance({client:{},directory:'.'}))" ) >/tmp/_acc_plug.log 2>&1; then
  ok "shipped plugin imports + inits offline"
else
  fail "shipped plugin import/init failed — see /tmp/_acc_plug.log"
fi

echo "acceptance: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
