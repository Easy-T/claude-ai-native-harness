#!/usr/bin/env bash
# BUILD-BOX ONLY (lives in _oracle/, EXCLUDED from the shipped zip).
# Runs `opencode run` against the local capture-server so we can inspect the
# EXACT system prompt opencode transmits (ground-truth L1 verification).
# Stages the bundle into a fresh temp config dir (clean-unzip sim; never mutates
# the tracked build dir). The capture-server must already listen on $CAP_PORT.
#
# Usage: bash _oracle/oc-capture.sh [port] [prompt]
set -uo pipefail

ORACLE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING="$(cd "$ORACLE/.." && pwd)"
source "$ORACLE/_stage.sh"
CAP_PORT="${1:-8319}"
PROMPT="${2:-say OK}"

case ":$PATH:" in
  *":/c/Users/12132/AppData/Roaming/npm:"*) : ;;
  *) PATH="/c/Users/12132/AppData/Roaming/npm:$PATH" ;;
esac
export PATH

STAGED="$(stage_bundle "$STAGING")"
RUNDIR="$(mktemp -d)"
trap 'rm -rf "$STAGED" "$RUNDIR"' EXIT

export OPENCODE_CONFIG_DIR="$STAGED"
export OPENCODE_CONFIG_CONTENT="{\"provider\":{\"anthropic\":{\"options\":{\"baseURL\":\"http://127.0.0.1:${CAP_PORT}/v1\",\"apiKey\":\"capture-test\"}}}}"

# Run from a scratch cwd with NO AGENTS.md, isolating the global/config-dir load path.
cd "$RUNDIR" || exit 1
opencode run --model anthropic/claude-sonnet-4-6 --dangerously-skip-permissions "$PROMPT"
