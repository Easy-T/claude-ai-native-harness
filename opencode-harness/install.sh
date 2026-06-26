#!/usr/bin/env bash
# install.sh — opencode governance harness installer (SHIPS in the bundle).
# Deploys this unzipped bundle to ~/.config/opencode. Offline-safe; backs up any
# existing config before writing. Idempotent. See PREREQUISITES.md first.
#
# Usage (after unzipping the bundle):
#   cd <unzipped-bundle> && bash install.sh
#   then set your internal model provider in ~/.config/opencode/opencode.json and restart opencode.
set -uo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
STAMP="$(date +%Y%m%d-%H%M%S)"
# Safety: never operate on an empty / root / bare-home TARGET — guards the rm -rf in step 3.
case "$TARGET" in
  ""|"/"|"$HOME"|"$HOME/") echo "✗ refusing to operate on unsafe TARGET='$TARGET'"; exit 1 ;;
esac

echo "=================================================="
echo "  opencode governance harness — installer"
echo "=================================================="

# --- 1. prerequisites ---
echo "[1/4] prerequisites..."
MISSING=""
command -v git >/dev/null 2>&1 || MISSING="$MISSING git"
if command -v opencode >/dev/null 2>&1; then
  VER="$(opencode --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  FLOOR="1.17.11"
  if [ -n "$VER" ] && [ "$(printf '%s\n%s\n' "$FLOOR" "$VER" | sort -V | head -1)" = "$FLOOR" ]; then
    echo "  ✓ opencode $VER (>= $FLOOR)"
  else
    echo "  ⚠ opencode ${VER:-unknown} < $FLOOR — subagent enforcement (R1) degraded; primary-agent path still enforced. See PREREQUISITES.md."
  fi
else
  echo "  ⚠ opencode not on PATH — install opencode >= 1.17.11 before use (PREREQUISITES.md)."
fi
if [ -n "$MISSING" ]; then echo "  ✗ missing:$MISSING — install then re-run."; exit 1; fi

# --- 2. backup existing config (HARD gate: no destructive step runs unless backup succeeded) ---
echo "[2/4] backup existing config..."
BK=""
if [ -e "$TARGET" ]; then
  BK="$TARGET.pre-harness-$STAMP"
  [ -e "$BK" ] && BK="$BK-$$"                                  # collision-proof (same-second re-run)
  if [ -e "$BK" ]; then echo "  ✗ backup path already exists: $BK — abort"; exit 1; fi
  if ! mv "$TARGET" "$BK"; then
    echo "  ✗ backup failed ($TARGET → $BK) — refusing to deploy over a live, un-backed-up config"; exit 1
  fi
  if [ -e "$TARGET" ]; then echo "  ✗ TARGET still present after backup — abort (will not overwrite)"; exit 1; fi
  echo "  ✓ moved existing config → $BK"
fi
mkdir -p "$TARGET"

# --- 3. deploy (KEEP package.json — opencode hangs at plugin load without it, spec §15; ---
#         strip the CANONICAL exclusion set, same as _oracle/_stage.sh + README zip -x) ---
echo "[3/4] deploying bundle → $TARGET ..."
if ! cp -r "$SRC"/. "$TARGET"/; then
  echo "  ✗ deploy copy failed — config may be incomplete; restore from ${BK:-(no prior config)}"; exit 1
fi
# strip relative to $TARGET (never an absolute rm -rf path); install.sh removed last (it is mid-run from SRC, not TARGET).
( cd "$TARGET" && rm -rf _oracle tests node_modules .git .gitignore package-lock.json bun.lock* _skills_capture.jsonl install.sh 2>/dev/null )
for f in package.json plugin/governance.js opencode.json AGENTS.md; do
  [ -f "$TARGET/$f" ] || { echo "  ✗ load-critical file missing after deploy: $f — restore from ${BK:-(no prior config)}"; exit 1; }
done
SKN="$(ls -1 "$TARGET/skill" 2>/dev/null | wc -l | tr -d ' ')"
echo "  ✓ deployed ($SKN skill groups; package.json kept)"

# --- 4. next steps ---
echo "[4/4] next steps:"
[ -n "$BK" ] && echo "  · previous config backed up at: $BK  (remove after verifying the new install)"
echo "  1. Set your internal LLM provider in $TARGET/opencode.json (provider + model). No CCS proxy."
echo "  2. Restart opencode (the global config dir is loaded at startup)."
echo "  3. (build box) run 'bash _oracle/verify-all.sh' from the SOURCE bundle to verify."
echo "  Offline: no runtime internet is required. A first-run 'background dependency install failed'"
echo "  WARN is harmless offline — the pure-ESM plugin loads regardless (see PREREQUISITES.md)."
echo "done."
