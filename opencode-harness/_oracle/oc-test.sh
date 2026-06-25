#!/usr/bin/env bash
# BUILD-BOX ONLY test runner (lives in _oracle/, EXCLUDED from the shipped zip).
# Stages the bundle into a fresh temp config dir (clean-unzip sim; never mutates the
# tracked build dir) and injects the CCS proxy as a TEST-ONLY anthropic-compatible
# model backend via OPENCODE_CONFIG_CONTENT (so the shipped opencode.json never
# carries proxy creds — R7 / goal constraint).
#
# Usage: bash _oracle/oc-test.sh [opencode run args...]
#   e.g. bash _oracle/oc-test.sh --print-logs "say hello"
set -uo pipefail

ORACLE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING="$(cd "$ORACLE/.." && pwd)"
source "$ORACLE/_stage.sh"

# Ensure the npm-global opencode is reachable even when PATH is minimal.
case ":$PATH:" in
  *":/c/Users/12132/AppData/Roaming/npm:"*) : ;;
  *) PATH="/c/Users/12132/AppData/Roaming/npm:$PATH" ;;
esac
export PATH

STAGED="$(stage_bundle "$STAGING")"
RUNDIR="$(mktemp -d)"
trap 'rm -rf "$STAGED" "$RUNDIR"' EXIT

export OPENCODE_CONFIG_DIR="$STAGED"
# Proxy creds injected at runtime ONLY — never written into the shipped bundle.
export OPENCODE_CONFIG_CONTENT='{"provider":{"anthropic":{"options":{"baseURL":"http://127.0.0.1:8317/v1","apiKey":"ccs-internal-managed"}}}}'

# Run from a scratch cwd so a stray project AGENTS.md never interferes.
# --dangerously-skip-permissions auto-approves "ask"; explicit "deny" still blocks.
cd "$RUNDIR" || exit 1
opencode run --model anthropic/claude-sonnet-4-6 --dangerously-skip-permissions "$@"
