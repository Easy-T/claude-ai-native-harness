#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"

# --- D-LIFECYCLE 표면 ②: active plan 상시 1줄 (cwd 기준; stale-active 즉시 가시화, cycle-23) ---
INPUT=$(read_input)
CWD=$(echo "$INPUT" | resolve_cwd) || CWD=""

# --- WORKTREE MARKER (SessionEnd teardown fallback): 워크트리 절대경로가 도달하는 PreToolUse(enforce-rpi-cycle/bash)
#   가 1차 기록(cycle-40, spec §10). 여기(SessionStart)는 *보조* — 드물게 워크트리에서 직접 claude 를 띄워 cwd 가
#   워크트리인 경우만 기록. (SessionStart/End cwd 는 CLI 실행디렉터리=메인루트라 일반적으론 워크트리 아님 — cycle-39 전제 오류.)
#   strictly fail-open(set -e 안전: record_worktree_marker 가 항상 return 0; 빈/unknown SID 는 helper 내부에서 skip).
SID=$(echo "$INPUT" | json_get 'session_id'); [ -n "$SID" ] || SID="unknown"
WT_MARK_DIR="$HOME/.claude/worktrees-marker"
record_worktree_marker "$SID" "$CWD"
# 스테일 마커 prune: 기록된 WT_ROOT 가 더는 없으면(크래시로 SessionEnd 미발화) 마커파일만 제거(디렉터리/타세션 활성 워크트리 절대 미삭제).
if [ -d "$WT_MARK_DIR" ]; then
  for _mk in "$WT_MARK_DIR"/*; do
    [ -f "$_mk" ] || continue
    _mv=$(head -1 "$_mk" 2>/dev/null)
    if [ -n "$_mv" ] && [ ! -d "$_mv" ]; then rm -f "$_mk" 2>/dev/null || true; fi
  done
fi

# --- self-healing sweep (cycle-41): harness-worktree 프로젝트의 git 등록(prunable)/고아 worktree-* 브랜치 잔여 청소 ---
#   dir 제거 주체가 harness/외부라 글로벌 SessionEnd 훅이 noop인 잔여를 식별-무관하게 청소(spec §11). cwd=메인루트서 발화.
#   게이트: .claude/worktrees 존재(harness-worktree 프로젝트만 — 무관 repo의 worktree-* 브랜치 비건드림). fail-open(helper 가 항상 return 0).
if [ -n "$CWD" ] && [ -d "$CWD/.claude/worktrees" ]; then
  sweep_orphan_worktrees "$CWD"
fi

if [ -n "$CWD" ] && [ -d "$CWD/docs/superpowers/plans" ]; then
  ACT_N=0; ACT_NAMES=""
  for p in "$CWD/docs/superpowers/plans"/*.md; do
    [ -f "$p" ] || continue
    case "$(plan_status "$p")" in
      active|in_progress) ACT_N=$((ACT_N+1)); ACT_NAMES="$ACT_NAMES $(basename "$p")" ;;
    esac
  done
  if (( ACT_N > 1 )); then
    echo "[plan] ⚠ active plan ${ACT_N}개(≤1 기대):$ACT_NAMES — stale-active 정리 필요 (Status: completed로)" >&2
  elif (( ACT_N == 1 )); then
    echo "[plan] active plan: 1 —$ACT_NAMES" >&2
  else
    echo "[plan] active plan: 0" >&2
  fi
fi

# --- D-FAILOPEN-SURFACE: 차단 hook 자가점검 (알림형 — fail-open은 유지, 고장만 표면화, cycle-23) ---
SELFCHECK_BAD=""
command -v node >/dev/null 2>&1 || SELFCHECK_BAD=" node-missing"
for hf in "$HOME/.claude/hooks/"*.sh; do
  bash -n "$hf" 2>/dev/null || SELFCHECK_BAD="$SELFCHECK_BAD syntax:$(basename "$hf")"
  [ -x "$hf" ] || SELFCHECK_BAD="$SELFCHECK_BAD nonexec:$(basename "$hf")"
done
if [ -n "$SELFCHECK_BAD" ]; then
  hook_log "session-start-audit" "hook-selfcheck" "ALERT" "$SELFCHECK_BAD"
  echo "[hook-selfcheck] ⚠ 차단 hook fail-open 위험:$SELFCHECK_BAD — bash ~/.claude/setup/doctor.sh 로 점검" >&2
fi

# --- D-FAILOPEN-SURFACE ②: lib/*.js 런타임 스모크 (cycle-32 rank6/G6-a) ---
# bash -n 은 .sh 구문만 잡는다 — .js 런타임 손상(throw/syntax)은 못 잡는다. 각 파서를 무해 입력
# (</dev/null + 무-env/argv)으로 1회 실행: 건강한 파서는 graceful exit 0, 손상 파서만 비정상 종료한다.
# 손상 파서는 차단 hook 의 게이트를 조용히 무력화하므로 차기 세션 시작에 ALERT 로 표면화(fail-open 유지).
if command -v node >/dev/null 2>&1; then
  JS_BAD=""
  for jf in "$HOME/.claude/hooks/lib/"*.js; do
    [ -e "$jf" ] || continue
    node "$jf" </dev/null >/dev/null 2>&1 || JS_BAD="$JS_BAD $(basename "$jf")"
  done
  if [ -n "$JS_BAD" ]; then
    hook_log "session-start-audit" "lib-selfcheck" "ALERT" "jsruntime:$JS_BAD"
    echo "[hook-selfcheck] ⚠ lib 파서 런타임 고장:$JS_BAD — bash ~/.claude/setup/doctor.sh 로 점검" >&2
  fi
fi

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
[ ! -f "$CLAUDE_MD" ] && {
  echo "[audit] 글로벌 CLAUDE.md 없음. /init-ai-ready 1회 실행 권장." >&2
  exit 0
}

# audit 마커 추출 — 가장 최근 것
MARKER=$(grep -E '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD" | tail -1 | sed -E 's/.*audit: ([0-9-]+).*/\1/')

if [ -z "$MARKER" ]; then
  echo "[audit] 마커 없음. 다음 /init-ai-ready 실행 시 자동 점검됩니다." >&2
  exit 0
fi

# 30일 경과 계산 (YYYY-MM-DD 비교)
TODAY=$(date +%Y-%m-%d)
DAYS_AGO=$(node -e '
  const m = process.argv[1];
  const t = process.argv[2];
  const ms = (new Date(t) - new Date(m)) / 86400000;
  console.log(isNaN(ms) ? 0 : Math.floor(ms));
' "$MARKER" "$TODAY")

if (( DAYS_AGO > 30 )); then
  hook_log "session-start-audit" "global-CLAUDE.md" "ALERT" "${DAYS_AGO}d"
  cat >&2 <<EOF
[audit] 마지막 audit 후 ${DAYS_AGO}일 경과 (마커: $MARKER).
  다음 /init-ai-ready 실행 시 자동 점검됩니다.
  강제 점검: bash ~/.claude/setup/doctor.sh
EOF
fi
exit 0
