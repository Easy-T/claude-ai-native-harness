# Worktree Teardown Robustness (cd-out marker fallback) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 39
**Started:** 2026-06-22
**Completed:** 2026-06-22

> Closeout evidence: worktree-teardown.test.sh **13/13** (RED 11/2 → GREEN 13/0), run-all **146/146** + cases.tsv 정합 (146==146), verify-all **ALL PASS** (doctor 34/0·verify-setup 66/0·meta 5/5/3·run-all 146·integration 8/0). Gate R/P/Closeout review-strict 전부 PASS. #61 데이터손실 불변식 유지(마커 경로도 GUARD2/3 통과). Task 3 Step 3/5 의 run-all RED/GREEN 은 격리 타깃 체크로 1차 확인 후 full run-all(verify-all STAGE 3)로 권위 확정.

**Goal:** Make the SessionEnd worktree-teardown hook clean a worktree even when the session `cd`'d out of it (RPI closeout returns to the repo root) by adding a `session_id`-keyed marker fallback (SessionStart writes, SessionEnd consumes), without weakening any data-loss=0 guard.

**Architecture:** SessionStart (`session-start-audit.sh`) records `$HOME/.claude/worktrees-marker/<session_id>` = WT_ROOT when its cwd is a linked worktree; SessionEnd (`worktree-teardown.sh`) determines the teardown target as cwd (authoritative GUARD 1) **else** its own SID's marker (fallback), then unlinks the marker. The marker-derived path passes the unchanged GUARD 2 (sanity) + GUARD 3 (`--absolute-git-dir` linked-worktree proof) before any `rm`. A shared `_common.sh` helper keeps the marker path identical on both sides.

**Tech Stack:** POSIX sh / Git Bash (MSYS2) hooks, Node `json_get`, PowerShell for reparse/junction handling, real `git worktree` E2E tests.

## Global Constraints

- **C1 — empty/`unknown` `session_id` ⇒ skip marker WRITE *and* CONSUME** (cwd GUARD 1 only). Prevents concurrent SID-less sessions sharing one `unknown` marker and mis-deleting another session's *active* worktree.
- **C2 — marker is not trusted:** marker-derived path passes the same GUARD 2 + GUARD 3 as cwd before any `rm`.
- **C3 — #61 defenses unchanged:** reparse pre-removal → `remaining==0` assert → POSIX `rm -rf`; **`git worktree remove --force` forbidden**; `branch -D` only `worktree-*`, never `master|main|HEAD`.
- **C4 — marker ops strictly non-blocking / fail-open** (`|| true`, `2>/dev/null`). Under `session-start-audit.sh`'s active `set -euo pipefail`, the SID default uses the `||` form `[ -n "$SID" ] || SID="unknown"` (the `&&` form would exit on a non-empty SID).
- **C5 — non-worktree / main-repo / general sessions stay clean no-op** (GLOBAL config — all projects). GUARD 1/2/3 preserved.
- Always `exit 0`. No `settings.json`/`settings.example.json` change (both events already wired). No new hook file.

---

## File Structure

- `hooks/_common.sh` — **Modify**: add `wt_marker_path` helper (SSOT for the marker path used by both hooks).
- `hooks/session-start-audit.sh` — **Modify**: add marker WRITE + stale-marker prune near the top (after cwd resolution, before early exits).
- `hooks/worktree-teardown.sh` — **Modify**: GUARD 1 region becomes "cwd-or-marker target resolution + own-marker consume".
- `hooks/tests/worktree-teardown.test.sh` — **Modify**: add cd-out (marker fallback) + empty-SID tests (standalone; not in cases.tsv).
- `hooks/tests/run-all.sh` — **Modify**: add SessionStart marker WRITE/skip/prune cases (156-160).
- `hooks/tests/cases.tsv` — **Modify**: declare the 5 new cases (run-all ↔ cases.tsv reconciliation).
- `README.md` — **Modify**: cases count `141`→`146` (×2 mentions; verify-setup #20).

---

### Task 1: `wt_marker_path` helper (_common.sh SSOT)

**Files:**
- Modify: `C:\Users\12132\.claude\hooks\_common.sh` (insert after `session_marker`, ~line 142)

**Interfaces:**
- Produces: `wt_marker_path <session_id>` → prints `$HOME/.claude/worktrees-marker/<session_id>` (default `unknown`). Consumed by Task 2 (write) and Task 3 (consume).

- [x] **Step 1: Add the helper** after the `session_marker` line.

```bash
# --- wt_marker_path <session_id>: worktree-teardown 의 session_id-키 마커 절대경로 (SessionStart write ↔ SessionEnd consume SSOT) ---
# 세션이 워크트리 밖으로 cd 해도 그 세션의 워크트리를 SessionEnd 가 식별하도록 SessionStart 가 여기에 WT_ROOT 를 기록.
# 빈/unknown SID 는 호출자가 차단(동시 세션의 'unknown' 마커 공유 → 타 세션의 *활성* 워크트리 오정리 방지).
wt_marker_path() { printf '%s/.claude/worktrees-marker/%s' "$HOME" "${1:-unknown}"; }
```

- [x] **Step 2: Verify _common.sh still parses** (lockout safety — _common.sh is sourced by every PreToolUse hook).

Run: `bash -n "$HOME/.claude/hooks/_common.sh" && echo OK`
Expected: `OK`

- [x] **Step 3: Verify the helper output**

Run: `bash -c 'source "$HOME/.claude/hooks/_common.sh"; wt_marker_path abc123'`
Expected: `<your-home>/.claude/worktrees-marker/abc123`

- [x] **Step 4: Commit**

```bash
git add hooks/_common.sh
git commit -m "feat(hooks): wt_marker_path SSOT helper (worktree-teardown cd-out fallback)"
```

---

### Task 2: SessionEnd marker CONSUME fallback (worktree-teardown.sh) — RED→GREEN

**Files:**
- Test: `C:\Users\12132\.claude\hooks\tests\worktree-teardown.test.sh` (add Ta cd-out + Te empty-SID)
- Modify: `C:\Users\12132\.claude\hooks\worktree-teardown.sh` (replace GUARD 1 region, current lines 26-35)

**Interfaces:**
- Consumes: `wt_marker_path` (Task 1), existing `normalize_path` / `json_get` / GUARD 2 (lines 37-46) / GUARD 3 (lines 48-61).
- Produces: teardown that fires for cwd-in-worktree **or** own-SID marker; `noop:not-worktree` only when neither yields a worktree path.

- [x] **Step 1: Write the failing tests.** Append before the cleanup block (after T4, ~line 73) in `worktree-teardown.test.sh`:

```bash
echo "== Ta: cd-out 세션(메인루트 cwd) → 마커 fallback 으로 워크트리 정리(★핵심 회귀) =="
make_worktree
MK_DIR="$HOME/.claude/worktrees-marker"; mkdir -p "$MK_DIR"
MK_SID="wtjtest_a_$$"
printf '%s\n' "$WT" > "$MK_DIR/$MK_SID"     # SessionStart 가 기록했을 마커(=WT_ROOT)
printf '{"session_id":"%s","cwd":"%s","reason":"prompt_input_exit"}' "$MK_SID" "$REPO" | bash "$HOOK" >/dev/null 2>&1
TGT_A=$(ls -1 "$MAIN_NM" 2>/dev/null | wc -l | tr -d ' ')
[ ! -e "$WT" ] && ok "★ cd-out 워크트리 삭제됨(마커 fallback)" || no "★ cd-out 워크트리 미삭제 — 마커 fallback 실패"
[ "$TGT_A" = "$TARGET_BEFORE" ] && ok "cd-out: target(main) 무사 ($TGT_A/$TARGET_BEFORE)" || no "cd-out DATA LOSS: $TGT_A/$TARGET_BEFORE"
[ ! -f "$MK_DIR/$MK_SID" ] && ok "cd-out: 마커 소비됨(unlink)" || no "cd-out: 마커 미소비"
rm -f "$MK_DIR/$MK_SID" 2>/dev/null

echo "== Te: 빈 session_id → 마커 미사용/미소비(cwd-only) — 타세션 활성 워크트리 보호 =="
make_worktree
mkdir -p "$MK_DIR"
printf '%s\n' "$WT" > "$MK_DIR/unknown"      # 'unknown' 마커(동시세션 공유 위험 모사)
printf '{"session_id":"","cwd":"%s","reason":"prompt_input_exit"}' "$REPO" | bash "$HOOK" >/dev/null 2>&1
{ [ -d "$WT" ] && [ -f "$MK_DIR/unknown" ]; } && ok "빈 SID: 워크트리 보존 + 'unknown' 마커 미소비" || no "빈 SID 처리 위반(워크트리/마커 변경됨)"
rm -f "$MK_DIR/unknown" 2>/dev/null
printf '{"session_id":"wtjcleanup_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1  # 정리: 보존된 WT teardown
```

- [x] **Step 2: Run to verify RED** (Ta fails: current code does `noop:not-worktree` on cwd=main root; Te passes as an invariant guard).

Run: `bash "$HOME/.claude/hooks/tests/worktree-teardown.test.sh"; echo "exit=$?"`
Expected: FAIL — `★ cd-out 워크트리 미삭제` (and `cd-out: 마커 미소비`), `exit=1`.

- [x] **Step 3: Implement marker consume.** Replace the GUARD 1 block + derivation (current lines 26-35) in `worktree-teardown.sh` with:

```bash
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
```

- [x] **Step 4: Run to verify GREEN** (all existing T1-T6 + new Ta/Te pass).

Run: `bash "$HOME/.claude/hooks/tests/worktree-teardown.test.sh"; echo "exit=$?"`
Expected: `worktree-teardown.test: PASS=13 FAIL=0`, `exit=0` (9 prior + Ta 3 + Te 1).

- [x] **Step 5: Verify worktree-teardown.sh parses**

Run: `bash -n "$HOME/.claude/hooks/worktree-teardown.sh" && echo OK`
Expected: `OK`

- [x] **Step 6: Commit**

```bash
git add hooks/worktree-teardown.sh hooks/tests/worktree-teardown.test.sh
git commit -m "feat(hooks): SessionEnd marker consume fallback for cd-out cleanup (cycle-39)"
```

---

### Task 3: SessionStart marker WRITE + stale prune (session-start-audit.sh) — RED→GREEN

**Files:**
- Modify: `C:\Users\12132\.claude\hooks\tests\run-all.sh` (add marker test helper + cases 156-160)
- Modify: `C:\Users\12132\.claude\hooks\tests\cases.tsv` (declare 156-160)
- Modify: `C:\Users\12132\.claude\hooks\session-start-audit.sh` (insert WRITE + prune after cwd resolution, ~after line 6)

**Interfaces:**
- Consumes: `wt_marker_path` (Task 1), existing `json_get` / `resolve_cwd`.
- Produces: a marker file `$HOME/.claude/worktrees-marker/<sid>` = WT_ROOT for worktree-cwd sessions with a valid SID; pruning of markers whose recorded path is absent.

- [x] **Step 1: Declare the 5 cases** in `cases.tsv` (append at end):

```
# cycle-39 (2026-06-22) — SessionStart 워크트리 마커 write/skip/prune (cd-out teardown fallback)
session-start-audit	156-marker-write	written	gen_ssa_mark_write
session-start-audit	157-marker-empty-skip	absent	gen_ssa_mark_empty
session-start-audit	158-marker-nonwt-skip	absent	gen_ssa_mark_nonwt
session-start-audit	159-marker-stale-prune	pruned	gen_ssa_mark_prune
session-start-audit	160-marker-active-keep	kept	gen_ssa_mark_keep
```

- [x] **Step 2: Add the test cases** to `run-all.sh` (after the cycle-23 SESSION-START-AUDIT block, before PATCH-D, ~line 442):

```bash
# ==================== CYCLE-39: SESSION-START-AUDIT 워크트리 마커 (cd-out teardown fallback) ====================
# 실제 $HOME/.claude/worktrees-marker 사용 — 고유 SID + 즉시 정리(실 세션 SID 는 UUID 라 충돌 없음).
WT_MARK_DIR="$HOME/.claude/worktrees-marker"
ssa_mark_ev() { printf '{"session_id":"%s","cwd":"%s"}' "$1" "$2"; }
WTM="$SCRATCH/wtmrepo/.claude/worktrees/cycle-z"; mkdir -p "$WTM"
# write/skip: cwd+SID 조합별 마커 파일 존재 여부
test_ssa_mark() {
  local name="$1"; local sid="$2"; local cwd="$3"; local want="$4"   # want: written|absent
  TOTAL=$((TOTAL+1))
  local mp; mp=$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; wt_marker_path "$1"' _ "$sid")
  rm -f "$mp" 2>/dev/null
  echo "$(ssa_mark_ev "$sid" "$cwd")" | "$HOOKS/session-start-audit.sh" >/dev/null 2>&1
  local got=absent; [ -f "$mp" ] && got=written
  rm -f "$mp" 2>/dev/null
  [ "$got" = "$want" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$name (want=$want got=$got)")
}
test_ssa_mark "156-marker-write"      "wtm156_$$" "$WTM"      written
test_ssa_mark "157-marker-empty-skip" ""          "$WTM"      absent
test_ssa_mark "158-marker-nonwt-skip" "wtm158_$$" "$SCRATCH"  absent
# prune: 기록된 WT_ROOT 부재→마커 제거, 존재→보존 (SessionStart cwd=비-워크트리라 자기 마커는 미기록)
test_ssa_prune() {
  local name="$1"; local target="$2"; local want="$3"   # want: pruned|kept
  TOTAL=$((TOTAL+1))
  mkdir -p "$WT_MARK_DIR" 2>/dev/null
  local psid="wtmp_${name}_$$"
  printf '%s\n' "$target" > "$WT_MARK_DIR/$psid"
  echo "$(ssa_mark_ev "wtmfresh_$$" "$SCRATCH")" | "$HOOKS/session-start-audit.sh" >/dev/null 2>&1
  local got=kept; [ -f "$WT_MARK_DIR/$psid" ] || got=pruned
  rm -f "$WT_MARK_DIR/$psid" 2>/dev/null
  [ "$got" = "$want" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$name (want=$want got=$got)")
}
test_ssa_prune "159-marker-stale-prune" "$SCRATCH/gone-nonexistent-$$" pruned
test_ssa_prune "160-marker-active-keep" "$WTM"                          kept
```

- [x] **Step 3: Run to verify RED** (156 write + 159 prune fail; 157/158/160 pass as guards).

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | tail -20`
Expected: failures listing `session-start-audit/156-marker-write (want=written got=absent)` and `session-start-audit/159-marker-stale-prune (want=pruned got=kept)`; reconciliation OK (`146 declared == 146 run`).

- [x] **Step 4: Implement WRITE + prune.** Insert in `session-start-audit.sh` immediately after the cwd-resolution line (`CWD=$(echo "$INPUT" | resolve_cwd) || CWD=""`):

```bash
# --- WORKTREE MARKER (SessionEnd teardown fallback, cycle-39): cwd 가 링크 워크트리면 session_id-키 마커에 WT_ROOT 기록 ---
# cwd-keyed teardown 은 세션이 워크트리 밖으로 cd 하면 정리 불가 → SessionStart 가 마커를 남겨 SessionEnd 가 SID 로 소비.
# strictly non-blocking(fail-open): 모든 마커 연산 best-effort. SID 기본값은 || 형(set -e 안전; && 형은 비-빈 SID 에서 exit).
SID=$(echo "$INPUT" | json_get 'session_id'); [ -n "$SID" ] || SID="unknown"
WT_MARK_DIR="$HOME/.claude/worktrees-marker"
if [ "$SID" != "unknown" ]; then          # C1: 빈 SID → write skip ('unknown' 마커 공유 금지)
  case "$CWD" in
    */.claude/worktrees/*)
      _wt_repo="${CWD%%/.claude/worktrees/*}"
      _wt_rest="${CWD#*/.claude/worktrees/}"
      _wt_name="${_wt_rest%%/*}"
      if [ -n "$_wt_repo" ] && [ -n "$_wt_name" ]; then
        mkdir -p "$WT_MARK_DIR" 2>/dev/null || true
        printf '%s\n' "$_wt_repo/.claude/worktrees/$_wt_name" > "$(wt_marker_path "$SID")" 2>/dev/null || true
      fi
      ;;
  esac
fi
# 스테일 마커 prune: 기록된 WT_ROOT 가 더는 없으면(크래시로 SessionEnd 미발화) 마커파일만 제거(디렉터리/타세션 활성 워크트리 절대 미삭제).
if [ -d "$WT_MARK_DIR" ]; then
  for _mk in "$WT_MARK_DIR"/*; do
    [ -f "$_mk" ] || continue
    _mv=$(head -1 "$_mk" 2>/dev/null)
    if [ -n "$_mv" ] && [ ! -d "$_mv" ]; then rm -f "$_mk" 2>/dev/null || true; fi
  done
fi
```

- [x] **Step 5: Run to verify GREEN** + verify session-start-audit parses.

Run: `bash -n "$HOME/.claude/hooks/session-start-audit.sh" && bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | tail -6`
Expected: `Hook tests: 146 / 146 passed`, reconciliation `146 declared == 146 run`, `Pass rate 100% — OK`.

- [x] **Step 6: Commit**

```bash
git add hooks/session-start-audit.sh hooks/tests/run-all.sh hooks/tests/cases.tsv
git commit -m "feat(hooks): SessionStart writes session_id worktree marker + stale prune (cycle-39)"
```

---

### Task 4: README cases-count sync + full acceptance gate

**Files:**
- Modify: `C:\Users\12132\.claude\README.md` (lines ~275, ~511: `141`→`146`)

**Interfaces:**
- Consumes: cases.tsv now 146 declared (Task 3). verify-setup #20 asserts README mention == actual.

- [x] **Step 1: Update README cases count** — both mentions.

Line ~275: `│       ├── cases.tsv                     141 case (run-all과 1:1 정합, 100% 구현)` → `146 case`
Line ~511: `- Hook 단위 테스트: ... (141 케이스, run-all과 1:1 정합, 100% 통과). ...` → `146 케이스`

- [x] **Step 2: Run verify-setup #20 (cases-count seal)**

Run: `bash "$HOME/.claude/setup/verify-setup.sh" 2>&1 | grep -i cases`
Expected: `✓ README cases 카운트 == 실측(146)`

- [x] **Step 3: Full acceptance gate (verify-all STAGE 0-4) + standalone E2E**

Run: `bash "$HOME/.claude/setup/verify-all.sh" 2>&1 | tail -5`
Expected: `ALL PASS — system meets §6.6 acceptance gate.`
Run: `bash "$HOME/.claude/hooks/tests/worktree-teardown.test.sh"; echo "exit=$?"`
Expected: `worktree-teardown.test: PASS=13 FAIL=0`, `exit=0`.

- [x] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): hook test cases 141->146 (SessionStart marker cases, cycle-39)"
```

---

## Self-Review

**Spec coverage** (spec §9 + goal deliverables):
- §9.2 WRITE → Task 3. CONSUME → Task 2. prune → Task 3. ✓
- §9.3 C1 empty-SID → Task 2 (consume skip) + Task 3 (write skip, cases 157). ✓
- §9.3 C2 GUARD2/3 on marker path → Task 2 (GUARD 2/3 unchanged, run after derivation). ✓
- §9.3 C3 #61 reparse-safe rm / no `--force` → untouched (STEP B/C/D below the modified region). ✓
- §9.3 C4 fail-open + set -e SID idiom → Task 3 Step 4 (`|| ` form). ✓
- Goal tests (a) cd-out cleaned → Ta; (b) normal cleaned → existing T1; (c) #61 main intact → T1 + Ta target check; (d) T1-T6 pass → Task 2 Step 4; (e) empty-SID no write/consume → Te + cases 157. ✓
- "SessionStart marker via run-all ssap" → Task 3 cases 156-160. ✓

**Placeholder scan:** none — every code step shows full content.

**Type/name consistency:** `wt_marker_path` (Task 1) used verbatim in Task 2 (`MK=$(wt_marker_path "$SID")`) and Task 3 (`wt_marker_path "$SID"` + test helper). `WT_MARK_DIR`, `SRCPATH`, `SID` consistent. Case counts: 141 baseline + 5 = 146 used uniformly in Tasks 3-4.

**Execution:** Inline TDD in the main session (per start-rpi-cycle Phase I; small, tightly-coupled, data-loss-critical change — direct main-session implementation over subagent fan-out). Gate P (review-strict) runs before implementation.
