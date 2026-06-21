#!/usr/bin/env bash
# worktree-teardown.sh — SessionEnd hook (action/cleanup). 세션 종료 시 그 세션의 *링크된* 워크트리를 정리.
#  ① dev서버(node/esbuild/vite/python/uvicorn) kill(best-effort, 경로 정확매칭)
#  ② reparse point(정션/심링크) 링크-only 선제거 → 잔존 0 단언 (데이터손실 방지 핵심; rm 의 전제조건)
#  ③ POSIX `rm -rf` (정션-free 가 된 워크트리) ④ `git worktree prune` + 컨벤션 브랜치(worktree-*) `branch -D`
#
# 안전 불변식(데이터손실 0): cwd 가 */.claude/worktrees/<name> 안일 때만 + git rev-parse 로 *링크된*
#  워크트리(git-dir≠git-common-dir)임이 확인될 때만 동작. reparse 잔존/powershell 부재 시 rm 생략(잔존).
#  `git worktree remove --force` 절대 사용 안 함(repo non-obvious #61 1차 범인). SessionEnd 는 차단 불가 → 항상 exit 0.
# matcher(settings.json)로 clear/resume/bypass_permissions_disabled 제외(세션 지속·모호 → 활성 워크트리 삭제 위험).
source "$HOME/.claude/hooks/_common.sh"
set +e +u; set +o pipefail   # best-effort: 첫 실패로 중단 금지(차단 hook 아님)

INPUT=$(read_input)
SID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SID" ] && SID="unknown"

# reason 자가-게이트(있을 때만; stdin 미보장이라 matcher 가 1차 게이트)
REASON=$(echo "$INPUT" | json_get 'reason')
case "$REASON" in
  clear|resume|bypass_permissions_disabled)
    hook_log "worktree-teardown" "-" "PASS" "noop:reason=$REASON"; exit 0 ;;
esac

CWD=$(echo "$INPUT" | resolve_cwd) || { hook_log "worktree-teardown" "-" "PASS" "noop:no-cwd"; exit 0; }

# GUARD 1 (+ 마커 fallback): teardown 대상 경로 결정 — cwd(authoritative) 또는 session_id 마커(fallback).
#  세션이 워크트리 밖으로 cd 해도(closeout 가 메인루트로 이동) SessionStart 가 남긴 마커로 정리. 마커는 GUARD2/3 가 검증(맹신 안 함).
SRCPATH=""
case "$CWD" in
  */.claude/worktrees/*) SRCPATH="$CWD" ;;   # authoritative: 현재 cwd 가 워크트리 안
esac
# 자기 SID 마커만 읽고 소비. C1: 빈/unknown SID → 마커 완전 skip (동시 세션 'unknown' 공유 시 타 세션 활성 워크트리 오정리 방지).
if [ "$SID" != "unknown" ] && [ -n "$SID" ]; then
  MK=$(wt_marker_path "$SID")
  if [ -z "$SRCPATH" ] && [ -f "$MK" ]; then
    MVAL=$(head -1 "$MK" 2>/dev/null); MVAL=$(normalize_path "$MVAL")
    case "$MVAL" in
      */.claude/worktrees/*) SRCPATH="$MVAL" ;;   # fallback: 마커가 가리키는 WT_ROOT
    esac
  fi
  rm -f "$MK" 2>/dev/null   # 자기 마커 소비(있든 없든): 본 세션 종료이므로 더는 불필요
fi
if [ -z "$SRCPATH" ]; then
  hook_log "worktree-teardown" "$CWD" "PASS" "noop:not-worktree"; exit 0
fi

REPO_ROOT="${SRCPATH%%/.claude/worktrees/*}"
REST="${SRCPATH#*/.claude/worktrees/}"
NAME="${REST%%/*}"
WT_ROOT="$REPO_ROOT/.claude/worktrees/$NAME"

# GUARD 2: 파생 경로 sanity
if [ -z "$NAME" ] || [ -z "$REPO_ROOT" ]; then
  hook_log "worktree-teardown" "$CWD" "PASS" "noop:empty-derivation"; exit 0
fi
case "$NAME" in .|..) hook_log "worktree-teardown" "$NAME" "PASS" "noop:bad-name"; exit 0 ;; esac
case "$WT_ROOT" in /|"$HOME"|"$HOME/") hook_log "worktree-teardown" "$WT_ROOT" "PASS" "noop:dangerous-root"; exit 0 ;; esac
case "$WT_ROOT" in
  */.claude/worktrees/*) : ;;
  *) hook_log "worktree-teardown" "$WT_ROOT" "PASS" "noop:no-marker"; exit 0 ;;
esac

# GUARD 3: WT_ROOT 가 *링크된* git 워크트리인가 (메인 체크아웃·비-worktree 보호).
#  --absolute-git-dir 이 <repo>/.git/worktrees/<name> (/worktrees/ 세그먼트) 이고 basename==NAME 일 때만 동작.
#  메인 체크아웃·비-worktree 서브디렉터리는 .../.git (worktrees 세그먼트 없음) → 거부.
#  (주의: git-dir 은 절대, git-common-dir 은 상대(../../../.git)로 혼용 출력돼 문자열비교가 메인 repo 를
#   링크 워크트리로 오판정함 → 그 방식 폐기. absolute-git-dir 단일 신호로 견고화 — 실측으로 봉인.)
command -v git >/dev/null 2>&1 || { hook_log "worktree-teardown" "$WT_ROOT" "PASS" "noop:no-git"; exit 0; }
ABS_GD=$(git -C "$WT_ROOT" rev-parse --absolute-git-dir 2>/dev/null)
case "$ABS_GD" in
  */worktrees/*) : ;;
  *) hook_log "worktree-teardown" "$WT_ROOT" "PASS" "noop:not-linked-worktree"; exit 0 ;;
esac
if [ "$(basename "$ABS_GD")" != "$NAME" ]; then
  hook_log "worktree-teardown" "$WT_ROOT" "PASS" "noop:wt-name-mismatch=$(basename "$ABS_GD")"; exit 0
fi

BRANCH=$(git -C "$WT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
cd "$REPO_ROOT" 2>/dev/null || cd "$HOME" 2>/dev/null || cd / 2>/dev/null

# 워크트리 경로의 Windows 형태(정확매칭·reparse 처리용)
if command -v cygpath >/dev/null 2>&1; then WT_WIN=$(cygpath -w "$WT_ROOT" 2>/dev/null); else WT_WIN=$(printf '%s' "$WT_ROOT" | sed 's|/|\\|g'); fi

# STEP A: dev서버 kill (best-effort, 이름 한정 + 경로 정확매칭)
if command -v powershell >/dev/null 2>&1 && [ -n "$WT_WIN" ]; then
  WT_WIN="$WT_WIN" powershell -NoProfile -Command '
    $wt = $env:WT_WIN.ToLower()
    $names = @("node","esbuild","vite","python","python3","py","uvicorn","npm")
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
      $n = ($_.Name -replace "\.exe$","").ToLower()
      ($names -contains $n) -and ((("" + $_.CommandLine + " " + $_.ExecutablePath).ToLower()).Contains($wt))
    } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
  ' >/dev/null 2>&1
fi

# STEP B: reparse 선제거(링크-only) → 잔존 0 일 때만 rm 허용 (powershell 부재/잔존 → rm 생략)
SAFE_TO_RM=0
if command -v powershell >/dev/null 2>&1 && [ -n "$WT_WIN" ]; then
  REMAIN=$(WT_WIN="$WT_WIN" powershell -NoProfile -Command '
    $wt = $env:WT_WIN
    if (Test-Path -LiteralPath $wt) {
      $rps = Get-ChildItem -LiteralPath $wt -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
      foreach ($rp in $rps) { try { [System.IO.Directory]::Delete($rp.FullName, $false) } catch {} }
      $left = @(Get-ChildItem -LiteralPath $wt -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
      Write-Output $left.Count
    } else { Write-Output 0 }
  ' 2>/dev/null | tr -d "[:space:]")
  if [ "$REMAIN" = "0" ]; then SAFE_TO_RM=1
  else
    hook_log "worktree-teardown" "$WT_ROOT" "ALERT" "abort-rm:reparse-remaining=${REMAIN:-?}"
    echo "[worktree-teardown] ⚠ reparse point 잔존(${REMAIN:-?}) → rm 중단(데이터손실 방지). 수동 점검: $WT_ROOT" >&2
  fi
else
  hook_log "worktree-teardown" "$WT_ROOT" "ALERT" "abort-rm:no-powershell"
  echo "[worktree-teardown] ⚠ powershell 부재 → reparse 검증 불가 → rm 생략(잔존). 수동 정리: $WT_ROOT" >&2
fi

# STEP C: POSIX rm -rf (정션-free) + 락 해제 재시도
RM_OK=0
if [ "$SAFE_TO_RM" = "1" ]; then
  for _att in 1 2 3 4 5; do
    [ -e "$WT_ROOT" ] || { RM_OK=1; break; }
    rm -rf "$WT_ROOT" 2>/dev/null
    [ -e "$WT_ROOT" ] || { RM_OK=1; break; }
    sleep 1
  done
fi

# STEP D: prune + 컨벤션 브랜치 삭제
git -C "$REPO_ROOT" worktree prune 2>/dev/null
BR_NOTE="branch-skip"
if [ "$RM_OK" = "1" ] && [ -n "$BRANCH" ] && [ "$BRANCH" != "HEAD" ]; then
  case "$BRANCH" in
    master|main) BR_NOTE="branch-protected=$BRANCH" ;;
    worktree-*) git -C "$REPO_ROOT" branch -D "$BRANCH" >/dev/null 2>&1 && BR_NOTE="branch-deleted=$BRANCH" || BR_NOTE="branch-Dfail=$BRANCH" ;;
    *) BR_NOTE="branch-nonconvention=$BRANCH" ;;
  esac
fi

hook_log "worktree-teardown" "$WT_ROOT" "PASS" "done:rm_ok=$RM_OK $BR_NOTE reason=${REASON:-NA}"
exit 0
