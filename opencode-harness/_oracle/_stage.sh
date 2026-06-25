#!/usr/bin/env bash
# BUILD-BOX ONLY (lives in _oracle/, EXCLUDED from the shipped zip).
# Stage the shipped bundle into a FRESH temp config dir — a faithful "clean unzip"
# simulation. Excludes build-box-only + generated files so opencode never finds a
# package.json to auto-install (which mutates devDeps->deps and writes a lockfile,
# and would attempt a NETWORK install in the offline company env). The runtime
# plugin is pure ESM with relative imports only, so it needs no package.json.
#
# Usage: STAGED="$(stage_bundle /path/to/opencode-harness)"; trap 'rm -rf "$STAGED"' EXIT
stage_bundle() {
  local src="$1" dst
  dst="$(mktemp -d)"
  cp -r "$src"/. "$dst"/ 2>/dev/null
  rm -rf "$dst/_oracle" "$dst/tests" "$dst/node_modules" "$dst/.git" \
         "$dst/package.json" "$dst/package-lock.json" "$dst"/bun.lock* 2>/dev/null
  printf '%s\n' "$dst"
}
