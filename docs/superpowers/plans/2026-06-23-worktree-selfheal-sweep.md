# Worktree Self-Healing Sweep + Instrumentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Steps use checkbox syntax.

**Status:** completed
**RPI-Cycle:** 41
**Started:** 2026-06-23
**Completed:** 2026-06-24

**Goal:** Stop the deterministic accumulation of `prunable` worktree registrations + orphan `worktree-*` branches
after RPI worktree cycles, via an **identification-independent** SessionStart sweep (`git worktree prune` +
orphan-branch delete) that derives its work from git's own state — so it cannot miss regardless of why the §10
marker is empty at SessionEnd. Add record/consume instrumentation so the real project can confirm the marker
cause. Success = after N real cycles: `git worktree list` prunable = 0 AND `git branch --list 'worktree-*'`
orphan = 0; active worktrees + their branches + non-convention branches always preserved.

**Architecture:** A pure-bash `sweep_orphan_worktrees <repo>` in `_common.sh` (prune dir-less registrations;
delete each `worktree-*` branch NOT held by a live worktree per `git worktree list --porcelain`). Wired into
`session-start-audit.sh` (SessionStart, cwd=main root), gated on `$CWD/.claude/worktrees` existing. Instrumentation:
`record_worktree_marker` logs `sid` on write; `worktree-teardown` logs `sid`/`mk_exists` on `noop:not-worktree`.

**Tech Stack:** Bash (MSYS2 Git Bash on Win11), git, Claude Code hooks.

## Global Constraints (verbatim from spec §11.3 + §2)

- **Sweep safety (= C5 principle):** prune removes ONLY dir-less registrations; branch delete touches ONLY a
  `worktree-*` branch that NO live worktree has checked out (compared to `git worktree list --porcelain` `branch`
  lines). Active worktree / another session's branch always protected. (`git branch -D` also refuses a
  checked-out branch — double safety.)
- **Gated** to harness-worktree projects: only run when `$CWD/.claude/worktrees` exists → never touches
  `worktree-*` branches in unrelated repos.
- **Branch convention = `worktree-*`** (identical to worktree-teardown STEP D; superset of worktree-cycle-*).
- **set-e safe / fail-open:** session-start-audit inherits `set -euo pipefail`; the sweep + the instrumentation
  log MUST be all-best-effort (`|| true`, `2>/dev/null`) and always `return 0` — never block session start.
- **CONSUME delete path + #61/C1–C5 invariants UNCHANGED.** No new hook file, no `settings.json` change →
  seals #8/#14/#23/#24 untouched.
- Surgical; match existing hook style.

## File Structure

- `hooks/_common.sh` — Modify: add `sweep_orphan_worktrees` (after `record_worktree_marker`); add the
  `record-wt-marker` hook_log line inside `record_worktree_marker`.
- `hooks/session-start-audit.sh` — Modify: call `sweep_orphan_worktrees "$CWD"` (gated on `.claude/worktrees`),
  after the stale-prune block (~line 33), before the plan display (~line 35).
- `hooks/worktree-teardown.sh` — Modify: capture `_MK_EXISTS` before consume; add `sid`/`mk_exists` to the
  `noop:not-worktree` log line.
- `hooks/tests/run-all.sh` + `cases.tsv` — Modify: add gated sweep unit cases 167-170 → DECLARED 152→156.
- `hooks/tests/worktree-teardown.test.sh` — Modify: add Td (sweep wiring E2E) → 20→25.
- `README.md` — Modify: cases 152→156; session-start-audit + worktree-teardown hook-table rows.
- `CONTEXT.md` — Modify: worktree-teardown term += self-healing sweep.
- `state.json` — Modify: cycle.count 40→41, dates (Closeout).

**Run tests with clean POSIX PATH prefix** (Bash-tool PATH is Windows-mangled):
`export PATH="/usr/bin:/mingw64/bin:/c/WINDOWS/System32:/c/WINDOWS:/c/WINDOWS/System32/WindowsPowerShell/v1.0:/c/Program Files/Git/cmd:/c/Program Files/nodejs:/c/Users/12132/AppData/Roaming/npm:/c/Users/12132/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"`

---

### Task 1: `_common.sh` — `sweep_orphan_worktrees` + record-marker instrumentation + gated unit cases

**Files:**
- Modify: `hooks/_common.sh` (after `record_worktree_marker`, ~line 175)
- Modify: `hooks/tests/run-all.sh` (sweep unit cases, near the cycle-40 block before Summary) + `cases.tsv`

**Interfaces — Produces:** `sweep_orphan_worktrees <repo>` → prune + orphan `worktree-*` branch delete; always returns 0.

- [x] **Step 1: Write the failing gated unit cases** in `run-all.sh` (after the cycle-40 `166-wtroot-markerdir-nomatch` line):

```bash
# ==================== CYCLE-41: self-healing sweep (prunable+고아 worktree-* 청소, 활성/비-컨벤션 보호) ====================
SWREPO="$SCRATCH/swrepo"; mkdir -p "$SWREPO"
git -C "$SWREPO" init -q 2>/dev/null; git -C "$SWREPO" config user.email t@t 2>/dev/null; git -C "$SWREPO" config user.name t 2>/dev/null
git -C "$SWREPO" commit -q --allow-empty -m init 2>/dev/null
mkdir -p "$SWREPO/.claude/worktrees"
git -C "$SWREPO" worktree add -q -b worktree-cycle-a "$SWREPO/.claude/worktrees/a" 2>/dev/null; rm -rf "$SWREPO/.claude/worktrees/a"   # dir 제거 → prunable + 고아 브랜치
git -C "$SWREPO" worktree add -q -b worktree-cycle-b "$SWREPO/.claude/worktrees/b" 2>/dev/null                                         # 활성 → 보호
git -C "$SWREPO" branch keepme 2>/dev/null                                                                                             # 비-컨벤션 → 보호
bash -c 'source "$HOME/.claude/hooks/_common.sh"; sweep_orphan_worktrees "$1"' _ "$SWREPO"
test_lib "167-sweep-prunable-zero"  "0"                "$(git -C "$SWREPO" worktree list --porcelain 2>/dev/null | grep -c prunable)"
test_lib "168-sweep-orphan-deleted" ""                 "$(git -C "$SWREPO" branch --list worktree-cycle-a | tr -d ' ')"
test_lib "169-sweep-active-kept"    "worktree-cycle-b" "$(git -C "$SWREPO" branch --list worktree-cycle-b | tr -d ' +*')"
test_lib "170-sweep-nonconv-kept"   "keepme"           "$(git -C "$SWREPO" branch --list keepme | tr -d ' ')"
```

- [x] **Step 2: Add declarations to `cases.tsv`** (after `166-wtroot-markerdir-nomatch`):

```
# cycle-41 (2026-06-23) — self-healing sweep (식별-무관 backstop): prunable+고아 worktree-* 청소, 활성/비-컨벤션 보호
hooks-lib	167-sweep-prunable-zero	output	gen_sweep_167
hooks-lib	168-sweep-orphan-deleted	output	gen_sweep_168
hooks-lib	169-sweep-active-kept	output	gen_sweep_169
hooks-lib	170-sweep-nonconv-kept	output	gen_sweep_170
```

- [x] **Step 3: Run to verify RED.** sweep undefined → sweep doesn't run → 167 (prunable) got=1≠0 FAIL, 168 (swA) got=worktree-cycle-a≠"" FAIL.

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '16[7-9]|170'`
Expected: 167 & 168 in the failures list.

- [x] **Step 4: Implement** in `_common.sh` immediately after the `record_worktree_marker` function (and add the instrumentation log inside it). First the new function:

```bash
# --- sweep_orphan_worktrees <repo>: git 등록/고아 worktree-* 브랜치 잔여를 결정론적 청소 (식별-무관 backstop, cycle-41) ---
# 워크트리 dir가 (harness/외부에 의해) 제거됐는데 git 등록(prunable)+worktree-* 브랜치가 누적되는 잔여를 청소(spec §11).
# 안전(=C5 원리): (1) prune은 dir-없는 등록만 제거. (2) worktree-* 브랜치는 *live worktree가 점유 안 한* 고아만 -D
#   (worktree list --porcelain 의 branch 라인 대조; git -D 도 체크아웃 브랜치 거부=이중안전). 활성/타세션 브랜치 절대 보호.
# fail-open + set-e 안전: 모든 git op best-effort(|| true), 항상 return 0. 호출자가 harness-worktree 프로젝트로 게이트.
sweep_orphan_worktrees() {
  local repo="${1:-}"
  [ -n "$repo" ] || return 0
  command -v git >/dev/null 2>&1 || return 0
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git -C "$repo" worktree prune 2>/dev/null || true
  local live branches br
  live=$(git -C "$repo" worktree list --porcelain 2>/dev/null | awk '/^branch /{print $2}') || live=""
  branches=$(git -C "$repo" for-each-ref --format='%(refname:short)' 'refs/heads/worktree-*' 2>/dev/null) || branches=""
  for br in $branches; do
    printf '%s\n' "$live" | grep -qx "refs/heads/$br" || git -C "$repo" branch -D "$br" >/dev/null 2>&1 || true
  done
  return 0
}
```

Then add the instrumentation log inside `record_worktree_marker`, immediately after the `printf ... > "$(wt_marker_path "$sid")"` line and before `return 0`:

```bash
  hook_log "record-wt-marker" "$wt" "PASS" "sid=$sid" 2>/dev/null || true   # cycle-41 계측(마커 실기록 시점·SID)
```

- [x] **Step 5: Run to verify GREEN.** 167 prunable=0, 168 swA deleted, 169 swB kept, 170 keepme kept.

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '16[7-9]|170|정합|passed'`
Expected: 167-170 pass; reconciliation `156 declared == 156 run`.

- [x] **Step 6: Commit.**

```bash
git add hooks/_common.sh hooks/tests/run-all.sh hooks/tests/cases.tsv
git commit -m "feat(hooks): _common sweep_orphan_worktrees + record-marker instrumentation (cycle-41)"
```

---

### Task 2: Wire sweep into SessionStart (gated) + teardown noop instrumentation

**Files:**
- Modify: `hooks/session-start-audit.sh` (after stale-prune ~line 33)
- Modify: `hooks/worktree-teardown.sh` (capture `_MK_EXISTS` before consume; augment `noop:not-worktree` log)

- [x] **Step 1: Wire the sweep** in `session-start-audit.sh` — insert after the stale-prune block (the `fi` closing the `for _mk in "$WT_MARK_DIR"/*` loop), before the `if [ -n "$CWD" ] && [ -d "$CWD/docs/superpowers/plans" ]` block:

```bash
# --- self-healing sweep (cycle-41): harness-worktree 프로젝트의 git 등록(prunable)/고아 worktree-* 브랜치 잔여 청소 ---
#   dir 제거 주체가 harness/외부라 글로벌 SessionEnd 훅이 noop인 잔여를 식별-무관하게 청소(spec §11). cwd=메인루트서 발화.
#   게이트: .claude/worktrees 존재(harness-worktree 프로젝트만 — 무관 repo의 worktree-* 브랜치 비건드림). fail-open(항상 return 0).
if [ -n "$CWD" ] && [ -d "$CWD/.claude/worktrees" ]; then
  sweep_orphan_worktrees "$CWD"
fi
```

- [x] **Step 2: Add teardown noop instrumentation** in `worktree-teardown.sh`. Replace the consume block (the `if [ "$SID" != "unknown" ] && [ -n "$SID" ]; then ... rm -f "$MK" 2>/dev/null fi` region, lines ~33-42) to capture `_MK_EXISTS` before the rm:

```bash
_MK_EXISTS=0
if [ "$SID" != "unknown" ] && [ -n "$SID" ]; then
  MK=$(wt_marker_path "$SID")
  [ -f "$MK" ] && _MK_EXISTS=1   # cycle-41 계측: SessionEnd 시점 자기-SID 마커 존재 여부(소비 전)
  if [ -z "$SRCPATH" ] && [ -f "$MK" ]; then
    MVAL=$(head -1 "$MK" 2>/dev/null); MVAL=$(normalize_path "$MVAL")
    case "$MVAL" in
      */.claude/worktrees/*) SRCPATH="$MVAL" ;;   # fallback: 마커가 가리키는 WT_ROOT
    esac
  fi
  rm -f "$MK" 2>/dev/null   # 자기 마커 소비(있든 없든): 본 세션 종료이므로 더는 불필요
fi
```

Then augment the `noop:not-worktree` log line (the `if [ -z "$SRCPATH" ]; then` block):

```bash
if [ -z "$SRCPATH" ]; then
  hook_log "worktree-teardown" "$CWD" "PASS" "noop:not-worktree sid=$SID mk_exists=$_MK_EXISTS"; exit 0
fi
```

- [x] **Step 3: Syntax + behavior check.** Confirm bash -n + that the noop instrumentation doesn't change exit semantics (still exit 0) and existing teardown tests still pass (the log string change is invisible to assertions).

Run: `export PATH=...(clean); bash -n ~/.claude/hooks/session-start-audit.sh && bash -n ~/.claude/hooks/worktree-teardown.sh && echo "syntax OK"`

- [x] **Step 4: Commit.**

```bash
git add hooks/session-start-audit.sh hooks/worktree-teardown.sh
git commit -m "feat(hooks): wire self-healing sweep at SessionStart + teardown noop sid/mk_exists instrumentation (cycle-41)"
```

---

### Task 3: Standalone sweep wiring E2E (worktree-teardown.test.sh) 20→25

**Files:**
- Modify: `hooks/tests/worktree-teardown.test.sh` (add Td after Tc, before the final cleanup)

- [x] **Step 1: Write Td** — inserts after the Tc cleanup line (`printf '...wtjtest_cleanup2...'`), before the `# cleanup:` comment. Drives the REAL `session-start-audit.sh` (cwd=$REPO, `.claude/worktrees` exists → gated sweep fires):

```bash
echo "== Td: self-healing sweep (SessionStart 배선) — dir-제거 등록/고아 worktree-* 청소, 활성/비-컨벤션 보호 =="
git -C "$REPO" worktree add -q -b worktree-cycle-swA "$REPO/.claude/worktrees/swA" 2>/dev/null; rm -rf "$REPO/.claude/worktrees/swA"   # dir 제거 → prunable+고아
git -C "$REPO" worktree add -q -b worktree-cycle-swB "$REPO/.claude/worktrees/swB" 2>/dev/null                                         # 활성 → 보호
git -C "$REPO" worktree add -q -b worktree-cycle-swC "$REPO/.claude/worktrees/swC" 2>/dev/null; git -C "$REPO" worktree remove "$REPO/.claude/worktrees/swC" 2>/dev/null   # 고아 브랜치
FEAT="feature-keepme-$$"; git -C "$REPO" branch "$FEAT" 2>/dev/null
printf '{"session_id":"sw_%s","cwd":"%s"}' "$$" "$REPO" | bash "$HOME/.claude/hooks/session-start-audit.sh" >/dev/null 2>&1
[ "$(git -C "$REPO" worktree list --porcelain 2>/dev/null | grep -c prunable)" = "0" ] && ok "Td: prunable 등록 0(prune)" || no "Td: prunable 잔존"
[ -z "$(git -C "$REPO" branch --list worktree-cycle-swA)" ] && ok "Td: dir-제거 고아 브랜치 swA 삭제" || no "Td: swA 미삭제"
[ -z "$(git -C "$REPO" branch --list worktree-cycle-swC)" ] && ok "Td: 고아 브랜치 swC 삭제" || no "Td: swC 미삭제"
{ [ -d "$REPO/.claude/worktrees/swB" ] && [ -n "$(git -C "$REPO" branch --list worktree-cycle-swB)" ]; } && ok "Td: 활성 워크트리 swB+브랜치 보호" || no "Td: 활성 swB 손상"
[ -n "$(git -C "$REPO" branch --list "$FEAT")" ] && ok "Td: 비-컨벤션 브랜치 보호" || no "Td: feature 브랜치 손상"
git -C "$REPO" worktree remove "$REPO/.claude/worktrees/swB" 2>/dev/null; git -C "$REPO" branch -D worktree-cycle-swB "$FEAT" 2>/dev/null   # 정리
```

- [x] **Step 2: Run to verify GREEN (20→25).**

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/worktree-teardown.test.sh; echo "exit=$?"`
Expected: `worktree-teardown.test: PASS=25 FAIL=0`, exit 0. (T1-Tc unregressed; Td 5/5.)

- [x] **Step 3: Commit.**

```bash
git add hooks/tests/worktree-teardown.test.sh
git commit -m "test(hooks): worktree-teardown Td — self-healing sweep wiring E2E (cycle-41)"
```

---

### Task 4: Doc/SSOT sync (README cases 152→156 + hook rows, CONTEXT) + full gate + state

**Files:**
- Modify: `README.md` (cases count + session-start-audit/worktree-teardown rows), `CONTEXT.md`

- [x] **Step 1: Update README** cases count 152→156 (both sites: the tree line `cases.tsv 152 case` and the prose `152 케이스`). Add to the `session-start-audit` row: "+ harness-worktree 프로젝트면 self-healing sweep(prunable 등록 prune + 고아 `worktree-*` 브랜치 -D, 활성 보호)". Add to the `worktree-teardown` row a note that the git-bookkeeping cleanup also runs as a SessionStart sweep (spec §11).

- [x] **Step 2: Update CONTEXT.md** worktree-teardown term: append that, because the worktree *directory* may be removed by the harness (not the hook), a SessionStart **self-healing sweep** (`git worktree prune` + orphan `worktree-*` branch -D, active/non-convention protected) cleans the git bookkeeping residue identification-independently (spec §11).

- [x] **Step 3: Full reconciliation + acceptance gate.**

```bash
export PATH=...(clean)
bash ~/.claude/hooks/tests/run-all.sh; echo "run-all exit=$?"
bash ~/.claude/hooks/tests/worktree-teardown.test.sh; echo "teardown exit=$?"
bash ~/.claude/setup/verify-all.sh; echo "verify-all exit=$?"
```
Expected: run-all `156 declared == 156 run`, 100%, exit 0; teardown PASS=25 FAIL=0; verify-all ALL PASS (incl. README cases==156 #20).

- [x] **Step 4: Commit.**

```bash
git add README.md CONTEXT.md
git commit -m "docs(hooks): sync README cases 152->156 + CONTEXT self-healing sweep (cycle-41)"
```

---

## Self-Review (writing-plans checklist)

1. **Spec coverage:** §11.3 sweep → Task1+2; §11.4 instrumentation → Task1 (record log) + Task2 (teardown noop);
   §11.5 surfaces → all tasks + Task4; §11.6 fitness function → cases 167-170 + Td. Covered.
2. **Placeholder scan:** every code step is literal; the only deferred specifics are the exact README/CONTEXT
   prose strings — Task4 edits them in place against the located rows. No TBD.
3. **Type/name consistency:** `sweep_orphan_worktrees`, `_MK_EXISTS`, `worktree-*` pattern, `.claude/worktrees`
   gate used consistently. The sweep's `live`/`branches` derivation matches the empirically-validated logic.
4. **RED-first integrity:** Task1 (167/168) has a concrete RED before the implementing edit (sweep undefined →
   prunable stays 1, orphan branch stays). Task2 (instrumentation) + Task3 (Td) + Task4 (docs) are
   wiring/regression-preserving and framed as GREEN-confirming, not false RED.
