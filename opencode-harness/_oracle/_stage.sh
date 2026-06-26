#!/usr/bin/env bash
# BUILD-BOX ONLY (lives in _oracle/, EXCLUDED from the shipped zip).
# Stage the shipped bundle into a FRESH temp config dir — a faithful "clean unzip"
# simulation. Strips build-box-only + GENERATED files (node_modules + lockfiles).
# package.json IS kept: opencode HANGS at plugin load when no package.json exists in
# the config dir (live-verified, spec §15). Its background dependency install is
# fail-open — offline it logs a WARN and loads the local pure-ESM plugin anyway — so
# node_modules/lockfiles are not needed and (platform-specific + regenerated) are
# stripped to keep the stage faithful to the shipped zip.
#
# Usage: STAGED="$(stage_bundle /path/to/opencode-harness)"; trap 'rm -rf "$STAGED"' EXIT
stage_bundle() {
  local src="$1" dst
  dst="$(mktemp -d)"
  cp -r "$src"/. "$dst"/ 2>/dev/null
  rm -rf "$dst/_oracle" "$dst/tests" "$dst/node_modules" "$dst/.git" \
         "$dst/package-lock.json" "$dst"/bun.lock* 2>/dev/null
  printf '%s\n' "$dst"
}
