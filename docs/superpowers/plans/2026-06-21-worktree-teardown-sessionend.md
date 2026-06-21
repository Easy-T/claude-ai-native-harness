# Worktree Teardown SessionEnd Hook — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Steps use `- [ ]`.

**Status:** completed

**Goal:** Add a global `SessionEnd` hook that, when a worktree session ends, junction-safely deletes that worktree (`<repo>/.claude/worktrees/<name>`), kills its dev servers, and prunes git bookkeeping — with a hard data-loss-0 invariant and an operator review gate before activation.

**Architecture:** Single bash hook `~/.claude/hooks/worktree-teardown.sh` sourcing `_common.sh`, guarded by cwd-marker + path-sanity + linked-worktree proof, using PowerShell for reparse pre-removal (mandatory precondition of `rm`) and process kill, POSIX `rm -rf` for deletion. Design record: `docs/superpowers/specs/2026-06-21-worktree-teardown-sessionend-design.md`.

**Tech Stack:** Git Bash (POSIX sh), PowerShell (Win32_Process, reparse enumeration, non-recursive Delete), git worktree, `_common.sh` helpers.

## Global Constraints

- **Data-loss = 0 (hard invariant):** never `git worktree remove --force`; `rm` runs ONLY after PowerShell confirms 0 reparse points remain under the worktree; only LINKED worktrees (git-dir≠git-common-dir) are ever targeted; reject `/`,`$HOME`,empty,non-marker paths.
- **No-op outside scope:** cwd not under `*/.claude/worktrees/<name>` → exit 0, no action.
- **Always `exit 0`** (SessionEnd cannot block).
- **Additive only:** do not clobber existing hooks/settings; `$HOME/.claude/hooks/X.sh` command form; SessionEnd block identical in `settings.json` and `settings.example.json` (#23).
- **Activation gated** on operator review of guards + rm path math (success criterion ⑥).
- Keep harness gates green: doctor `REQUIRED_HOOKS` (#24), README counts (#20 only if test cases added), bash -n (#28).

---

### Task 1: Create the inert hook script (not yet wired)

**Files:**
- Create: `C:\Users\12132\.claude\hooks\worktree-teardown.sh`
- Modify: `C:\Users\12132\.claude\setup\doctor.sh` (add to `REQUIRED_HOOKS`)
- Modify: `C:\Users\12132\.claude\setup\verify-setup.sh` (optional: add to #8 exec list)

- [ ] **Step 1: Write `worktree-teardown.sh`** with exactly this content:

```bash
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

# GUARD 1: cwd 가 .claude/worktrees/<name> 안인가
case "$CWD" in
  */.claude/worktrees/*) : ;;
  *) hook_log "worktree-teardown" "$CWD" "PASS" "noop:not-worktree"; exit 0 ;;
esac

REPO_ROOT="${CWD%%/.claude/worktrees/*}"
REST="${CWD#*/.claude/worktrees/}"
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
#  --absolute-git-dir 이 /worktrees/ 세그먼트 포함 + basename==NAME 일 때만. (git-dir vs git-common-dir
#  문자열비교는 절대/상대 혼용 출력로 메인 repo 오판정 → 폐기; T6 가 봉인.)
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
```

- [ ] **Step 2: `chmod +x`** the script. Run: `chmod +x ~/.claude/hooks/worktree-teardown.sh`
- [ ] **Step 3: `bash -n`** verify syntax (verify-setup #28). Expected: no output, exit 0.
- [ ] **Step 4: Add to `doctor.sh REQUIRED_HOOKS`** (mandatory for verify-setup #24 disk⊇doctor). Add the line `"worktree-teardown.sh"` to the array.
- [ ] **Step 5: (optional) Add `worktree-teardown` to verify-setup #8** exec-check loop list.
- [ ] **Step 6: Run `bash ~/.claude/setup/verify-setup.sh`** — expect still green (PASS count +0 or +1 if #8 edited). Hook is inert (not in settings) → no behavior change.

### Task 2: Measured simulation tests (success criteria ①②③④)

**Files:**
- Create: `C:\Users\12132\.claude\hooks\tests\worktree-teardown.test.sh` (standalone measured verification; isolated temp repo — never touches the real project).

- [ ] **Step 1: Write the test** that, in a `mktemp -d` temp repo, creates a real linked worktree (`git worktree add -b worktree-cycle-_test .claude/worktrees/_test-teardown`), plus a nested junction `…/_test-teardown/app/frontend/node_modules` → a scratch "main node_modules" target with sentinel files, plus a fake dev-server process (`python -c sleep` with the worktree path + a unique marker in argv). Then drive the hook with stdin JSON and assert:
  - **T1 (①③):** `{cwd: <worktree>, reason: prompt_input_exit}` → worktree dir gone, **target sentinels intact (count unchanged)**, branch `worktree-cycle-_test` deleted, fake process (unique marker) gone.
  - **T2 (②):** `{cwd: <repo root>}` → **no-op** (repo + worktrees intact).
  - **T3 (④):** `{cwd: /}`, `{cwd: $HOME}`, `{cwd: ""}`, `{cwd: <repo>/some/other/dir}` → **no-op** each (no deletion).
  - **T4 (idempotency):** rerun T1's cwd after deletion → clean no-op (exit 0, no error).
  - **T5 (reason gate):** `{cwd: <worktree>, reason: clear}` on a fresh worktree → **no-op** (worktree intact).
  Each assertion prints `PASS`/`FAIL`; script exits non-zero on any FAIL. Clean up the temp repo at the end (POSIX `rm -rf` of the temp tree — itself junction-free after the hook ran, or pre-removed).
- [ ] **Step 2: Run** `bash ~/.claude/hooks/tests/worktree-teardown.test.sh` and confirm **all assertions PASS** (this is the "verify=실측" evidence, not unit tests).

### Task 3: ★ Operator review gate (success criterion ⑥) — BLOCKING

- [ ] **Step 1: Present to the operator** for review BEFORE any `settings.json` change: (a) the three guards (marker / sanity / linked-worktree proof) and the exact `WT_ROOT`/`REPO_ROOT`/`BRANCH` path computation, (b) the reparse-precondition-of-rm safety, (c) the matcher scope (`prompt_input_exit|logout|other`, excludes clear/resume/bypass), (d) the measured test results from Task 2. **Do not proceed to Task 4 without explicit approval.**

### Task 4: Activation — wire SessionEnd (post-approval, update-config skill)

**Files:**
- Modify: `C:\Users\12132\.claude\settings.json` (add `SessionEnd` block)
- Modify: `C:\Users\12132\.claude\settings.example.json` (add IDENTICAL `SessionEnd` block — #23 parity)

- [ ] **Step 1:** Via **update-config skill**, add to both files' `hooks` object:
```json
"SessionEnd": [
  {
    "matcher": "prompt_input_exit|logout|other",
    "hooks": [
      { "type": "command", "command": "$HOME/.claude/hooks/worktree-teardown.sh", "timeout": 30 }
    ]
  }
]
```
- [ ] **Step 2:** `bash ~/.claude/setup/verify-all.sh` → expect **ALL PASS** (#23 parity holds: identical blocks; #14 lower-bound 9→10 passes).

### Task 5: Docs / SSOT sync (post-approval)

**Files:**
- Modify: `README.md` (`### 9개 hook` → `10개`; add a SessionEnd row to the table; PASS count if #8 edited)
- Modify: `SECURITY.md` (new subsection: worktree-teardown data-deletion safety model)
- Modify: `CONTEXT.md` (term: "worktree teardown" / "reparse pre-removal")

- [ ] **Step 1:** README: bump heading to `### 10개 hook (활성)`, add table row `| worktree-teardown | 정리 | SessionEnd (prompt_input_exit/logout/other) | 그 세션의 링크된 워크트리를 정션-안전하게 삭제 + dev서버 kill + worktree prune/branch -D. 가드 3중·rm 전 reparse 선제거 의무 |`.
- [ ] **Step 2:** SECURITY.md: add the safety-model subsection (guards, reparse precondition, never `git worktree remove --force`, single-operator-only).
- [ ] **Step 3:** CONTEXT.md: add the term(s).
- [ ] **Step 4:** Final `bash ~/.claude/setup/verify-all.sh` → **ALL PASS**.

### Task 6: Closeout

- [ ] **Step 1:** review-strict drift check (plan vs implementation, no scope creep).
- [ ] **Step 2:** Mark this plan **Status: completed**; update memory.
- [ ] **Step 3:** (optional, deferred) belt-and-suspenders `closeout-pr-cycle` clause: cd repo-root + kill dev servers before session end.

## Self-Review

- **Spec coverage:** R①SessionEnd contract→Task4 matcher+timeout; R②self-cwd→Step `cd REPO_ROOT`+retry; R③guard→Task1 GUARD1-3; R④process kill→STEP A; R⑤deny-only-agent-Bash→confirmed E6 (hook rm not intercepted); R⑥failure modes→spec §4; R⑦junction→STEP B + tests T1; ⑤ADR→spec; ⑥review gate→Task3. ✓
- **Placeholder scan:** none — full script + concrete assertions. ✓
- **Type/name consistency:** `WT_ROOT`/`REPO_ROOT`/`NAME`/`BRANCH`/`WT_WIN`/`SAFE_TO_RM`/`RM_OK` consistent across steps. ✓
