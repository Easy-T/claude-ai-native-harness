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

# --- has_active_plan: <cwd>의 docs/superpowers/plans에 active plan이 있으면 경로 출력+return 0 ---
# Usage: if PLAN=$(has_active_plan "$CWD"); then ...; fi
# enforce-rpi-cycle 와 enforce-rpi-bash 가 공유 (로직 drift 방지). 판별 우선순위는
# 기존 enforce-rpi-cycle 인라인 로직과 동일: 명시 Status > 미완료 체크박스 fallback.
has_active_plan() {
  local cwd="${1:-.}"
  local plan_dir="$cwd/docs/superpowers/plans"
  [ -d "$plan_dir" ] || return 1
  local plan status
  for plan in "$plan_dir"/*.md; do
    [ -f "$plan" ] || continue
    # 1순위: 명시적 Status — 첫 단어만 추출(소문자). "completed - cleanup pending" 같은 후행 텍스트도 정확 인식(S14)
    status=$(head -20 "$plan" | grep -m1 -iE '^\*?\*?status:?\*?\*?' | sed -E 's/^\*?\*?[Ss]tatus:?\*?\*?[[:space:]]*//' | awk '{print tolower($1)}' | tr -d '*' || true)
    case "$status" in
      completed|abandoned|archived|paused) continue ;;
      active|in_progress) printf '%s' "$plan"; return 0 ;;
    esac
    # 2순위: 미완료 체크박스 존재
    if grep -qE '^- \[ \]' "$plan"; then printf '%s' "$plan"; return 0; fi
  done
  return 1
}

# --- 코드/실행 확장자 단일 정의 (SSOT) ---
# enforce-rpi-cycle(is_code_path) 과 enforce-rpi-bash(code_ext_regex) 가 공유한다.
# 새 언어 추가 시 이 한 줄만 수정 → 두 게이트가 자동 동기화 (Write vs Bash 비대칭 우회 방지).
CODE_EXTS="sh bash zsh py rb js mjs cjs ts tsx jsx go rs php pl ps1 psm1 c cc cpp h hpp java kt swift scala lua sql ipynb"

# is_code_path <path>: 코드/실행 파일이면 return 0 (Dockerfile 포함).
is_code_path() {
  local p="${1:-}" ext
  case "$p" in */Dockerfile|Dockerfile) return 0 ;; esac
  for ext in $CODE_EXTS; do
    case "$p" in *."$ext") return 0 ;; esac
  done
  return 1
}

# code_ext_regex: CODE_EXTS 로부터 JS 정규식 `\.(ext1|ext2|...)$` 생성 (enforce-rpi-bash node 용).
code_ext_regex() { printf '\\.(%s)$' "$(printf '%s' "$CODE_EXTS" | tr ' ' '|')"; }
