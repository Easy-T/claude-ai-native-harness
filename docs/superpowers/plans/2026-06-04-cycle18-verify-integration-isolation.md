# verify-integration.sh Per-Run Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 18
**Started:** 2026-06-04

**Goal:** Eliminate `verify-integration.sh`'s fixed shared `TEST_DIR="$HOME/Documents/test-ai-ready"` (+`rm -rf`) so concurrent runs never collide and `rm -rf` never touches the user's real `~/Documents`.

**Architecture:** Replace the fixed shared path with a per-run `TEST_DIR=$(mktemp -d)` and an `EXIT` trap that cleans it up — mirroring the established in-repo SSOT pattern in `hooks/tests/run-all.sh:8-9`. The reset block (`rm -rf`/`mkdir -p`) is removed because `mktemp -d` already yields a fresh empty 0700 directory. No other file changes (see Non-Goals).

**Tech Stack:** Bash, `mktemp -d`, `trap ... EXIT`.

**Gate R:** PASS 6/6 (review-strict `ab67b3a6a8d1da74f`). spec delta = no-op (§6.0 norm is "격리/재현", §6.8 already "임시 디렉터리"; path is illustrative, not normative — mktemp strengthens, not contradicts).

---

## Non-Goals (deliberately deferred — surfaced as findings, NOT changed this cycle)

- **README counts:** all 5 verified accurate against disk (5 진입점, 9 hook, 6 orchestrator skill, 3 wrapper, 13 파일 = 13 `.tpl` in `skills/init-ai-ready-project/templates/`). No change.
- **#25 verify-setup safety guard** (assert verify-integration uses mktemp / no fixed `$HOME` TEST_DIR): NOT adopted. Surgical-Changes ("every changed line traces to the request") + user seal-skepticism (goal stop-point c) + cycle-17 "generalized framework 기각". The fix itself satisfies the safety criterion; a guard is regression-prevention (outside the goal's success criteria). Surfaced as next-cycle candidate for user approval.
- **Spec §6.3/§6.5 stale init-ai-ready counts** ("8 .tpl + 2 references" / "10개 파일"; actual 13 `.tpl`): a *different subsystem* (init-ai-ready) drift. Non-blocking per Gate R C5. Surfaced as next-cycle candidate.
- **Sub-fixture `/tmp` leaks** (E2E.E `BAD_SKILL`, E2E.F `FRESH_F`, E2E.H `VL` each `mktemp -d` without cleanup): already unique-per-run (no collision) and never touch `~/Documents` — no impact on any success criterion. Left as-is (Surgical).

---

### Task 1: Per-run isolation for verify-integration.sh

**Files:**
- Modify: `setup/verify-integration.sh:2,4,10-13`

- [x] **Step 1: Baseline — remove any stale shared dir from prior runs, record absence**

Run:
```bash
rm -rf "$HOME/Documents/test-ai-ready"
ls -d "$HOME/Documents/test-ai-ready" 2>&1 || echo "BASELINE: shared dir absent"
```
Expected: `BASELINE: shared dir absent`

- [x] **Step 2: Apply the isolation edit**

Replace the current header/reset region of `setup/verify-integration.sh`:

```bash
#!/usr/bin/env bash
# End-to-end integration verification using ~/Documents/test-ai-ready/
set -uo pipefail
TEST_DIR="$HOME/Documents/test-ai-ready"
PASS=0
FAIL=0
ok()   { echo "✓ $1"; PASS=$((PASS+1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# Reset
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
git init -q
```

with:

```bash
#!/usr/bin/env bash
# End-to-end integration verification in a per-run isolated temp dir (mktemp -d).
set -uo pipefail
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
PASS=0
FAIL=0
ok()   { echo "✓ $1"; PASS=$((PASS+1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# Fresh isolated dir from mktemp -d above — no shared-path reset needed.
cd "$TEST_DIR"
git init -q
```

Rationale per edited line:
- Line 2 comment: updated to reflect the new isolation mechanism (honesty).
- Line 4: `mktemp -d` → per-run unique 0700 dir; eliminates concurrent collision.
- New `trap ... EXIT`: guarantees cleanup on any exit path (the old code only `rm`'d at start, leaking the dir after a run). EXIT trap that does not call `exit` preserves the script's `exit $FAIL` status (proven by `run-all.sh`).
- Removed `# Reset` / `rm -rf` / `mkdir -p`: redundant — `mktemp -d` already created a fresh empty dir; and the old `rm -rf` on a `$HOME`-based path was the hazard being removed.

- [x] **Step 3: Sequential run — verify still 8/8**

Run:
```bash
bash "$HOME/.claude/setup/verify-integration.sh"; echo "rc=$?"
```
Expected: last two lines
```
verify-integration: PASS=8 FAIL=0
rc=0
```

- [x] **Step 4: Concurrent run — verify determinism (the core success criterion)**

Run:
```bash
( bash "$HOME/.claude/setup/verify-integration.sh" >/tmp/vi-a.log 2>&1; echo "A:rc=$?" ) &
( bash "$HOME/.claude/setup/verify-integration.sh" >/tmp/vi-b.log 2>&1; echo "B:rc=$?" ) &
wait
echo "--- A ---"; tail -1 /tmp/vi-a.log
echo "--- B ---"; tail -1 /tmp/vi-b.log
```
Expected: both `A:rc=0` and `B:rc=0`, and both logs end with `verify-integration: PASS=8 FAIL=0`. (On the OLD code this was flaky — E2E.D rc=2 from shared-dir collision.)

- [x] **Step 5: Safety — confirm `~/Documents` was never touched**

Run:
```bash
ls -d "$HOME/Documents/test-ai-ready" 2>&1 || echo "GOOD: shared dir never (re)created"
```
Expected: `GOOD: shared dir never (re)created`

- [x] **Step 6: Cleanup leftover logs**

Run:
```bash
rm -f /tmp/vi-a.log /tmp/vi-b.log
```
Expected: (no output)

---

### Task 2: Full acceptance gate

**Files:** none (verification only)

- [x] **Step 1: Run the full gate**

Run:
```bash
bash "$HOME/.claude/setup/verify-all.sh"; echo "rc=$?"
```
Expected: ends with
```
ALL PASS — system meets §6.6 acceptance gate.
rc=0
```
(doctor + verify-setup + run-all 96/96 + verify-integration 8/8 all green, unchanged from cycle-17 except verify-integration now isolated.)

- [x] **Step 2: Commit (master-direct + push, established workflow)**

Run:
```bash
cd "$HOME/.claude"
git add setup/verify-integration.sh docs/superpowers/plans/2026-06-04-cycle18-verify-integration-isolation.md
git commit -m "fix(rpi): cycle-18 — per-run mktemp isolation for verify-integration.sh"
git push
```
Expected: clean commit + push to `master`.

---

## Self-Review

1. **Spec coverage:** Goal = isolate verify-integration TEST_DIR. Task 1 implements it; Steps 3-5 verify all 3 success criteria (determinism, verify-all unchanged via Task 2, no `~/Documents` touch). ✓
2. **Placeholder scan:** No TBD/TODO; every code step shows exact before/after and exact commands + expected output. ✓
3. **Consistency:** Single var `TEST_DIR`, single mechanism (`mktemp -d` + `trap EXIT`); matches `run-all.sh` SSOT naming idiom. ✓
