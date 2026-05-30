# Harness Architecture — Patch (F): single-source-of-truth + testable extraction (cycle-8 [1][2][3])

**Status:** completed
**RPI-Cycle:** 9
**Started:** 2026-05-30
**Completed:** 2026-05-30
**Result:** verify-all ALL PASS (unit 76/76 incl. 8 new lib unit tests, integration 8/8); behavior byte-identical (smoke + argv[2] bug found+fixed); [1][2][3] done

## Provenance
cycle-8 architecture analysis (6-component workflow). Top theme: single-source-of-truth for
cross-artifact contracts. User selected candidates [1][2][3]. Security posture is sound — this is
pure STRUCTURE/maintainability work. Safety net: 68 unit + 8 E2E tests must stay green (behavior
must be byte-identical after each refactor).

## Scope ([1][2][3] only)
- **[1]** 'what is code' extension set → single source in `_common.sh` (shell `case` glob in
  enforce-rpi-cycle + JS regex in enforce-rpi-bash → one `CODE_EXTS`/`CODE_EXT_REGEX` + `is_code_path()`).
- **[3]** Extract the 3 load-bearing inline node sub-programs into committed `hooks/lib/`:
  skeleton-scan.js (enforce-orchestrator), redirect-targets.js (enforce-rpi-bash),
  transcript-usage.js (auto-compact-watch). Hooks shrink to orchestration; lib gets direct unit tests.
- **[2]** Unify the orchestrator-skeleton contract: make the extracted `skeleton-scan.js` the
  authoritative checker; align `create-orchestrator-skill` to inject exactly what the hook enforces
  + point to the authoritative source (no restated numbers that drift).

## Non-goals (NOT in this patch)
- [4] cases.tsv↔run-all CI assert; [5] verify-setup skill validator counts; [6] once_per_session/emit
  helpers; [7] model-window externalize; [8] init-ai-ready count; [9] cwd unify; [10] json_get_many.
  (Available as follow-on micro-cycles.)

## Acceptance (each step: targeted smoke; final: full gate)
- After EVERY change, the relevant hook's behavior is unchanged (verified by smoke + final verify-all).
- New `hooks/lib/*.js` are committed, executable-by-node, and have direct unit tests in run-all.sh.
- Full suite: verify-all ALL PASS (68+ unit incl. new lib tests, 8 E2E). bash -n clean.
- install.sh REQUIRED + doctor register hooks/lib (they are now load-bearing). No behavior change.
- Every changed line traces to [1]/[2]/[3]. settings/auth untouched.

## Tasks
- [x] F1 `_common.sh`: CODE_EXTS + CODE_EXT_REGEX + is_code_path(). [1]
- [x] F2 `enforce-rpi-cycle.sh`: use is_code_path() for the code-ext branch. [1] + smoke.
- [x] F3 `hooks/lib/redirect-targets.js` (new) + `enforce-rpi-bash.sh` rewire (uses CODE_EXT_REGEX). [1][3] + smoke.
- [x] F4 `hooks/lib/skeleton-scan.js` (new) + `enforce-orchestrator.sh` rewire. [3] + smoke.
- [x] F5 `hooks/lib/transcript-usage.js` (new) + `auto-compact-watch.sh` rewire. [3] + smoke.
- [x] F6 `create-orchestrator-skill/SKILL.md`: align injected skeleton + authoritative pointer. [2]
- [x] F7 tests: hooks/lib unit tests in run-all.sh; install/doctor register hooks/lib; full verify-all.
- [x] F8 Closeout: plan completed; state 8→9; commit+push.
