#!/usr/bin/env bash
# Common prologue for all ~/.claude/hooks/*.sh
# Sourced, not executed. Provides json_get, log, common error handling.

set -euo pipefail

# --- json_get: stdin JSON에서 dot-path로 값 추출 ---
# Usage: VAR=$(echo "$INPUT" | json_get 'tool_input.file_path')
# - 값 없으면 빈 문자열 출력
# - JSON 파싱 실패 시 빈 문자열 (장애 안전)
json_get() {
  node -e '
    let data = "";
    process.stdin.on("data", c => data += c);
    process.stdin.on("end", () => {
      try {
        const obj = JSON.parse(data);
        const keys = process.argv[1].split(".");
        let v = obj;
        for (const k of keys) v = v?.[k];
        if (v !== undefined && v !== null) {
          console.log(typeof v === "string" ? v : JSON.stringify(v));
        }
      } catch (e) { /* silent — graceful fail */ }
    });
  ' "$1"
}

# --- hook_log: ~/.claude/hooks/.log/YYYY-MM.log에 한 줄 누적 ---
# Usage: hook_log "<hook-name>" "<target>" "<verdict>" "[<reason>]"
hook_log() {
  local hook="$1"; local target="$2"; local verdict="$3"; local reason="${4:-}"
  local logdir="$HOME/.claude/hooks/.log"
  local logfile="$logdir/$(date +%Y-%m).log"
  mkdir -p "$logdir" 2>/dev/null || return 0
  local ts
  ts=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
  printf "%s\t%s\t%s\t%s\t%s\n" "$ts" "$hook" "$target" "$verdict" "$reason" >> "$logfile" 2>/dev/null || true
}

# --- node 가용성 체크 (Claude Code 런타임이라 보장되지만 방어적) ---
require_node() {
  command -v node >/dev/null 2>&1 || {
    # node 없으면 작업을 막지 않고 통과 (장애 안전)
    exit 0
  }
}

# --- INPUT 읽기 헬퍼 (모든 hook이 첫 줄로 사용) ---
read_input() {
  cat
}

# --- normalize_path: cross-platform path normalization ---
# Linux/WSL: no-op (no backslashes in path).
# Windows (Git Bash): C:\Users\... → C:/Users/... so case patterns like
# */.claude/* match uniformly. Required because Claude Code on Windows
# may pass tool_input.file_path with backslashes.
normalize_path() {
  local p="${1:-}"
  echo "${p//\\//}"
}
