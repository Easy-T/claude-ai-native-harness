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

# --- json_get_many <path1> <path2> ...: stdin JSON에서 여러 dot-path를 US(\x1f) 구분 한 줄로 출력 (node 1회) ---
# Usage: IFS=$'\037' read -r A B C <<< "$(echo "$INPUT" | json_get_many p1 p2 p3)"
# 구분자는 US(0x1f) — TAB/스페이스가 IFS면 bash read가 연속 구분자를 합쳐 빈 필드를 버리므로
# 비공백 US를 써서 중간 빈 필드(예: notebook_path 미존재)도 보존한다.
# 주의: 개행 없는 '스칼라' 필드 전용(file_path/tool_name 등). 다중행 값(content/new_string)엔 json_get 사용.
json_get_many() {
  node -e '
    let data = "";
    process.stdin.on("data", c => data += c);
    process.stdin.on("end", () => {
      let obj = {}; try { obj = JSON.parse(data); } catch (e) { /* graceful */ }
      const out = process.argv.slice(1).map(p => {
        let v = obj;
        for (const k of p.split(".")) v = v?.[k];
        return (v === undefined || v === null) ? "" : (typeof v === "string" ? v : JSON.stringify(v));
      });
      process.stdout.write(out.join("\x1f"));
    });
  ' "$@"
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

# --- plan_status <plan.md>: head-20의 명시 Status 첫 단어(소문자) 출력. 없으면 빈 문자열 ---
# "completed - cleanup pending" 같은 후행 텍스트도 첫 단어만 정확 인식(S14).
# has_active_plan / session-start-audit 가 공유 (status 추출 로직 단일화).
plan_status() {
  head -20 "$1" 2>/dev/null | grep -m1 -iE '^\*?\*?status:?\*?\*?' \
    | sed -E 's/^\*?\*?[Ss]tatus:?\*?\*?[[:space:]]*//' | awk '{print tolower($1)}' | tr -d '*' || true
}

# --- has_active_plan: <cwd>의 docs/superpowers/plans에 active plan이 있으면 경로 출력+return 0 ---
# Usage: if PLAN=$(has_active_plan "$CWD"); then ...; fi
# enforce-rpi-cycle 와 enforce-rpi-bash 가 공유 (로직 drift 방지).
# cycle-23 D-LIFECYCLE: 명시 Status(active|in_progress)만 인정 — checkbox-fallback 제거
# (Status 없는 plan이 게이트를 영구 개방하던 stale-active 경로 봉쇄. seal #27 + session-start 표면과 3중.)
has_active_plan() {
  local cwd="${1:-.}"
  local plan_dir="$cwd/docs/superpowers/plans"
  [ -d "$plan_dir" ] || return 1
  local plan
  for plan in "$plan_dir"/*.md; do
    [ -f "$plan" ] || continue
    case "$(plan_status "$plan")" in
      active|in_progress) printf '%s' "$plan"; return 0 ;;
    esac
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

# --- session_marker <name> <session_id>: 1세션-1회 알림 마커 경로 (auto-compact-watch / verify-loop-watch 공유) ---
session_marker() { printf '/tmp/%s-%s' "$1" "${2:-unknown}"; }

# --- emit_system_message <msg>: systemMessage JSON 을 stdout 에 안전 출력 (hook→UI 알림 프로토콜 단일화) ---
emit_system_message() { MSG="$1" node -e 'process.stdout.write(JSON.stringify({systemMessage:process.env.MSG}))'; }

# --- emit_additional_context <msg>: PreToolUse additionalContext JSON 을 stdout 에 안전 출력 ---
# systemMessage(=사용자 UI 경고)와 달리 additionalContext 는 "모델 컨텍스트에 주입"되는 유일한 비차단 경로.
# (공식 hooks 문서: PreToolUse exit 0 시 stdout JSON 만 파싱; stderr 는 모델에 도달 안 함.)
emit_additional_context() { MSG="$1" node -e 'process.stdout.write(JSON.stringify({hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:process.env.MSG}}))'; }

# --- resolve_cwd: stdin JSON 의 cwd 를 정규화해 출력. 비면 비-zero return (호출자가 fail-open/skip 결정, S12) ---
# Usage: CWD=$(echo "$INPUT" | resolve_cwd) || { <empty 처리>; }
# 비결정적 "." 기본값을 쓰지 않도록 cwd 해석을 4개 hook 에서 단일화.
resolve_cwd() {
  local c; c=$(json_get 'cwd'); c=$(normalize_path "$c")
  [ -z "$c" ] && return 1
  printf '%s' "$c"
}
