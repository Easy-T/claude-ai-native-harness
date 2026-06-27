#!/usr/bin/env bash
# scripts/check.sh — local quality gate for {{PROJECT_NAME}}
# Run before every PR. Must pass before gh pr create.
set -euo pipefail

echo "== {{PROJECT_NAME}} check =="

{{CHECK_COMMANDS}}

echo "== check complete =="
