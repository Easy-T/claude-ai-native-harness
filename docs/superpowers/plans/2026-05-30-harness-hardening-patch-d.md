# Harness Hardening — Patch (D): audit-residual cleanup (item5 + S3/S4/S7/S14 + housekeeping)

**Status:** completed
**RPI-Cycle:** 7
**Started:** 2026-05-30
**Completed:** 2026-05-30
**Result:** smoke + 68/68 unit (8 new) PASS; verify-all ALL PASS; all 5 fixes (item5/S3/S4/S7/S14) + stray-plan housekeeping done

## Provenance (Phase R)
Final cleanup of all remaining 2026-05-29 audit residuals. Research confirmed: transcripts carry
NO context-window field, only `message.model` + usage tokens → model→window must be derived
(opus-4-* → 1M, else 200K) with `CONTEXT_LIMIT` env override. Effort levels (high/xhigh/max) do
NOT change the window; the window derives from the selected MODEL.

## Fixes (each maps to an audit finding)
- **item5** `auto-compact-watch.sh`: replace hardcoded LIMIT=200000 with a MODEL-AWARE window read
  from the transcript's last `message.model` (opus-4-7/4-8 → 1,000,000; else 200,000), still
  overridable by `CONTEXT_LIMIT`. Warn threshold derives from `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`
  (warn a margin before native compaction); message states the real model/window/native-%.
- **S3** `enforce-orchestrator.sh`: for an Edit, validate the RECONSTRUCTED post-edit file
  (read on-disk + apply old→new) instead of only `new_string`, so gutting a skill via Edit is caught.
- **S4** `enforce-orchestrator.sh`: strip HTML comments (`<!-- -->`) before counting `Agent(subagent_type=`
  so a commented-out Agent() no longer satisfies the >=1 check. (Fenced code is NOT stripped — real
  skills legitimately document calls in fences; stripping would false-block them.)
- **S7** `enforce-rpi-cycle.sh`: trivial check counts max(OLD_lines, NEW_lines) ("changed lines")
  instead of OLD+NEW combined, matching CLAUDE.md's "≤5 line change" policy (3↔3 edit is trivial).
- **S14** `_common.sh has_active_plan`: parse Status by FIRST WORD (lowercased) instead of stripping
  all spaces, so "completed - cleanup pending" is recognized as completed (not mis-fallback to active).
- **housekeeping**: mark the stray `2026-05-08-housing-benefits-app-phase-a1.md` (no Status, 124
  unchecked boxes) as `paused` so it stops holding the ~/.claude RPI gate open. Reversible.

## Acceptance criteria (Closeout gate)
- `bash -n` clean on every edited .sh; `_common.sh` sources without error.
- New regression cases: S14 trailing-status→block; S7 3↔3 edit→trivial PASS; S3 Edit-gut→BLOCK;
  S4 commented-Agent→BLOCK; item5 model-aware (output-based: opus→1M-based %, default→200K). All green.
- ALL existing cases still pass (no regression). `verify-all.sh` ALL PASS.
- settings/auth untouched. Every changed line traces to a listed fix.

## Tasks
- [x] D1 (S14) `_common.sh has_active_plan`: Status first-word parse.
- [x] D2 (S7) `enforce-rpi-cycle.sh`: trivial = max(old,new) lines.
- [x] D3 (S3+S4) `enforce-orchestrator.sh`: reconstruct post-Edit file + strip HTML comments before skeleton count.
- [x] D4 (item5) `auto-compact-watch.sh`: model-aware window + override-% aware message.
- [x] D5 tests: regression cases for S14/S7/S3/S4/item5 in run-all.sh + cases.tsv.
- [x] D6 housekeeping (stray plan → paused) + Closeout (verify-all, plan completed, state 6→7, commit+push).
