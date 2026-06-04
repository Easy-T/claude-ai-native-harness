# verify-integration Isolation Seal (#25) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active

**Goal:** Add verify-setup check #25 that seals the cycle-18 per-run-isolation invariant of `verify-integration.sh` (main `TEST_DIR` must be `mktemp -d`, never a fixed `$HOME` path), and keep the README PASS count honest (60→61).

**Architecture:** A content-drift seal in the same family as #17/#19/#22 (grep-presence guards) but adding a *negative* assertion. Two greps on `verify-integration.sh`: positive `^TEST_DIR=$(mktemp -d)` present + negative `^TEST_DIR=…$HOME` absent. The `^TEST_DIR=` anchor excludes sub-fixtures (`BAD_SKILL=`/`FRESH_F=`/`VL=`), so only the main isolation is asserted. The seal is self-verifying (runs as part of verify-setup); verified RED by a transient regression then reverted.

**Tech Stack:** bash, grep -E, the existing `ok`/`fail` harness in `setup/verify-setup.sh`.

**RPI-Cycle:** 20. Gate R PASS (review-strict, all C1–C5). cycle.count 19→20.

---

## Non-Goals (explicitly deferred — stop-point (b) hit)

**Global-count drift correction in `docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md` is DEFERRED.** The cycle-20 goal listed correcting spec counts hook 5→9, skill 4→6+1, meta-rule 6→8, §2.9 "9개 파일". A ground-truth sweep (4-agent ultracode workflow) showed this is NOT 4 point-fixes but ~40+ sites of genesis-vs-current staleness, and that the spec **bodies do not exist** for the newer components:
- §2.5 "Hook 5개 등록" settings.json body registers only 5 hooks; §4 "Hook 5개 상세" has subsections for only 5 (no body for enforce-rpi-bash / enforce-secret-scan / verify-loop-watch / surface-constitution).
- §2.6's embedded CLAUDE.md body enumerates only §1–§6 (no §7 Response Language / §8 UI Design Mandate).
- §2.3 "Skill 4개 명세" has only 4 subsections (no improve-codebase-architecture / ui-design body).
- §2.9 "9개 파일" / §6.3 "14개 항목" describe a design-time verify-setup; the live script emits 60 PASS (#1–#24).

Changing counts alone would recreate the "advertised count vs missing body" contradiction class cycle-19's Gate R fought. cycle-19's init-ai-ready reconcile was clean ONLY because the bodies (templates/ = 13) already existed — that property does not hold here, so the precedent does not transfer. There is **no clean safe subset**. The live SSOT is already correct and independently sealed (`verify-setup.sh` #2 `meta -eq 8`, #6 lists 6+1 skills, #8 lists 9 hooks; README states 9 hooks / 6+1 skills / 8 meta), so the genesis-spec counts are historical, not a correctness bug — deferring is NOT a silent skip of a mandatory rule. The genesis-record-vs-living-SSOT model decision is surfaced as the cycle-21 question.

**Also out of scope:** any hook edit, any `hooks/tests/cases.tsv` edit (#25 is a verify-setup check, not a hook — it is self-verifying; cases.tsv tests hooks only, so README cases=96 / E2E=8 and drift-guards #20/#21 are unaffected).

---

## File Structure

- Modify: `setup/verify-setup.sh` — insert check #25 between current line 196 (`[ -z "$MISS24" ] && ok …`) and current line 198 (`echo`). One new `ok` path → PASS 60→61.
- Modify: `README.md:278` — `(현재 60 PASS)` → `(현재 61 PASS)`.
- Verify-only (no edit): `setup/verify-integration.sh` (the seal's target), `setup/verify-all.sh` (no hardcoded PASS count → no cascade), `hooks/tests/cases.tsv` (unaffected).

---

## Task A: Add #25 seal + README bump

**Files:**
- Modify: `C:\Users\12132\.claude\setup\verify-setup.sh:196-198`
- Modify: `C:\Users\12132\.claude\README.md:278`
- Test (transient RED): `C:\Users\12132\.claude\setup\verify-integration.sh:4`

- [ ] **Step 1: Confirm baseline PASS=60**

Run:
```bash
bash ~/.claude/setup/verify-setup.sh | tail -1
```
Expected: `verify-setup: PASS=60 FAIL=0`

- [ ] **Step 2: Insert check #25 into verify-setup.sh**

In `setup/verify-setup.sh`, the current tail is:
```bash
MISS24=$(comm -23 <(printf '%s\n' "$DISK_H") <(printf '%s\n' "$DOC_H"))
[ -z "$MISS24" ] && ok "doctor REQUIRED_HOOKS ⊇ hooks/*.sh" || fail "doctor REQUIRED_HOOKS omits:$(printf ' %s' $MISS24)"

echo
echo "verify-setup: PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

Insert the #25 block on the blank line BEFORE `echo` (i.e., after the #24 `[ -z "$MISS24" ] …` line, before the trailing `echo`). The block, verbatim (regex literals must survive exactly as written):

```bash
# 25. verify-integration.sh per-run 격리 봉인 (cycle-18 회귀 방지): 메인 TEST_DIR이
#     mktemp -d로 할당 + 고정 $HOME 경로 미사용. 서브픽스처(BAD_SKILL=/FRESH_F=/VL=)는
#     ^TEST_DIR= 앵커로 비매칭 → 메인 격리만 단언. (#17/#19/#22 content-drift 패턴 + 부정 단언.)
VI="$HOME/.claude/setup/verify-integration.sh"
if grep -qE '^TEST_DIR=\$\(mktemp -d\)' "$VI" 2>/dev/null \
   && ! grep -qE '^TEST_DIR=.*\$HOME' "$VI" 2>/dev/null; then
  ok "verify-integration TEST_DIR mktemp-isolated (고정 \$HOME 없음)"
else
  fail "verify-integration TEST_DIR 격리 drift (mktemp 부재 또는 고정 \$HOME 복원 — cycle-18 회귀)"
fi
```

- [ ] **Step 3: Run verify-setup, confirm GREEN at 61**

Run:
```bash
bash ~/.claude/setup/verify-setup.sh | tail -1
```
Expected: `verify-setup: PASS=61 FAIL=0`

Also confirm the new line appears:
```bash
bash ~/.claude/setup/verify-setup.sh | grep 'mktemp-isolated'
```
Expected: `✓ verify-integration TEST_DIR mktemp-isolated (고정 $HOME 없음)`

- [ ] **Step 4: RED-test — temporarily regress verify-integration.sh and confirm #25 FAILs**

Temporarily change `setup/verify-integration.sh` line 4 from `TEST_DIR=$(mktemp -d)` to a fixed `$HOME` path:
```bash
cp ~/.claude/setup/verify-integration.sh /tmp/vi.bak
sed -i 's#^TEST_DIR=\$(mktemp -d)#TEST_DIR=$HOME/Documents/test-ai-ready#' ~/.claude/setup/verify-integration.sh
bash ~/.claude/setup/verify-setup.sh | grep -E 'TEST_DIR|PASS='
```
Expected: a `✗ verify-integration TEST_DIR 격리 drift …` line AND `verify-setup: PASS=60 FAIL=1` (the seal goes RED).

> Note: editing verify-integration.sh (a `.sh`, code) may itself be gated by enforce-rpi-cycle. This plan IS the active plan, so the edit is permitted; if a stray block occurs, use `RPI_SKIP="cycle20-red-test"` for the transient edit only.

- [ ] **Step 5: Revert the RED-test, confirm GREEN restored**

Run:
```bash
cp /tmp/vi.bak ~/.claude/setup/verify-integration.sh && rm /tmp/vi.bak
bash ~/.claude/setup/verify-setup.sh | tail -1
```
Expected: `verify-setup: PASS=61 FAIL=0`. Confirm `git diff --stat setup/verify-integration.sh` shows NO change (clean revert).

- [ ] **Step 6: Bump README PASS count**

In `README.md` line 278, change:
```
│   ├── verify-setup.sh                   §6.3 file/structure 체크 (현재 60 PASS)
```
to:
```
│   ├── verify-setup.sh                   §6.3 file/structure 체크 (현재 61 PASS)
```

- [ ] **Step 7: Run full acceptance gate**

Run:
```bash
bash ~/.claude/setup/verify-all.sh; echo "rc=$?"
```
Expected: doctor PASS (2 pre-existing WARN ok), `verify-setup: PASS=61 FAIL=0`, hook tests ≥95% (96/96), `verify-integration: PASS=8 FAIL=0`, final `ALL PASS — system meets §6.6 acceptance gate.`, `rc=0`.

- [ ] **Step 8: Update state.json (cycle 19→20)**

Write `state.json`:
```json
{
  "cycle": {
    "count": 20,
    "last_completed_at": "2026-06-05"
  },
  "audit": {
    "last_drift_check": "2026-06-05"
  }
}
```

- [ ] **Step 9: Commit + push**

```bash
cd ~/.claude
git add setup/verify-setup.sh README.md state.json docs/superpowers/plans/2026-06-05-cycle20-verify-integration-seal.md
git commit -m "feat(rpi): cycle-20 #25 verify-integration isolation seal (60→61)"
git push
```
> If `doctor.sh` bumped the CLAUDE.md audit marker during verify-all (a known side-effect), `git diff CLAUDE.md` will show ONLY the `<!-- audit: … -->` line — include it in the commit (accurate freshness stamp, keeps tree clean, §1 non-violation: automated marker ≠ conscious content edit). Confirm the diff is marker-only before adding.

---

## Self-Review

**1. Goal coverage:** Primary deliverable (#25 seal + README 60→61) = Task A Steps 2/6. Success criterion "seal catches fixed-$HOME restore as RED" = Step 4. "verify-all ALL PASS (61/0)" = Step 7. Optional global-count = Non-Goals (deferred with rationale + cycle-21 surface). Covered.

**2. Placeholder scan:** No TBD/TODO. Every step has exact commands + expected output + verbatim code. The seal block is byte-exact (regex literals preserved).

**3. Consistency:** Seal var `VI`, regexes `^TEST_DIR=\$\(mktemp -d\)` / `^TEST_DIR=.*\$HOME`, and message strings match Gate R's verified literals exactly. README target line 278 matches the read. PASS bump 60→61 matches the empirical baseline (review-strict ran the script: PASS=60).
