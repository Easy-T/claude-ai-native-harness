# Harness Architecture — Patch (G): remaining cycle-8 candidates [4]-[10] + final doc sweep

**Status:** completed
**RPI-Cycle:** 10
**Started:** 2026-05-30
**Completed:** 2026-05-31
**Result:** verify-all ALL PASS (verify-setup 51/0, unit 79/79, cases↔run-all 정합 OK, integration 8/8); behavior-preserving (caught+fixed IFS-whitespace bug in [10]); [4]-[10] + doc sweep done

## Provenance
cycle-8 analysis remaining candidates. Behavior-preserving structural work. Safety net:
76 unit + 8 E2E must stay green (each change verified by smoke + final verify-all).

## Tasks
- [x] G1 [5] verify-setup.sh: fix stale skill-validator comments/counts; include all 9 skills,
      documenting the orchestrator opt-out boundary (grill-with-docs, common-agent-contract, ccs-delegation).
- [x] G2 [8] init-ai-ready-project/SKILL.md: drop the self-contradictory "12개" frontmatter count.
- [x] G3 [6] _common.sh: once_per_session() + emit_system_message() helpers; rewire auto-compact-watch
      + verify-loop-watch to use them (TMPDIR-aware marker, single JSON-escape emitter).
- [x] G4 [9] _common.sh: resolve_cwd() (json_get cwd + normalize, return non-zero when empty);
      rewire enforce-rpi-cycle, enforce-rpi-bash, stable-claude-md, verify-loop-watch to uniform empty-cwd posture.
- [x] G5 [7] hooks/lib/model-window.js (new): model->context-window map as a testable module
      (CONTEXT_LIMIT override inside); rewire auto-compact-watch. Register in install/verify-setup. +unit tests.
- [x] G6 [10] _common.sh: json_get_many() (one node spawn, TAB-separated); rewire enforce-rpi-cycle's
      multi-field extraction. Keep json_get for single-field callers.
- [x] G7 [4] cases.tsv truthfulness + reconciliation: prune spec-only orphan rows so cases.tsv == the
      implemented test set; add a run-all reconciliation assert (declared IDs == run IDs) so future drift fails CI.
- [x] G8 tests: lib unit tests for model-window; full verify-all ALL PASS after the set.
- [x] G9 FINAL doc-consistency sweep: re-sync README / doctor.sh / install.sh / verify-setup.sh / CLAUDE.md
      counts (hooks, lib, files, tests, checks) to post-G reality; confirm no omissions.
- [x] G10 Closeout: plan completed; state 9->10; commit + push to GitHub.

## Acceptance
- bash -n clean; verify-all ALL PASS; behavior preserved (smoke per change). Every changed line traces
  to a candidate. settings/auth untouched. Working tree clean after push.
