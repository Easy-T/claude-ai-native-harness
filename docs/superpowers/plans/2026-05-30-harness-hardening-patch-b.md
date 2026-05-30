# Harness Hardening — Patch (B): Verification-loop reminder (advisory Stop hook)

**Status:** completed
**RPI-Cycle:** 6
**Started:** 2026-05-30
**Completed:** 2026-05-30
**Result:** verify-all.sh ALL PASS (setup 46/0, unit 60/60, integration 5/5); review-strict PASS (advisory-only, non-goals intact)

## Provenance (Phase R)
Audit §7 item 4 ("give Claude a way to verify its work" — Anthropic headline rec).
User decision (this cycle): **Advisory**, not hard-gate. Stop hooks apply to ALL sessions
globally, so we close the awareness gap without blocking turn-end or risking loops.

## Design (locked)
New advisory hook `hooks/verify-loop-watch.sh` on the `Stop` event. Emits a once-per-session
`systemMessage` reminder to run `scripts/check.sh` + closeout, ONLY when all hold (else silent):
1. `stop_hook_active` is not true (don't re-fire inside a continuation)
2. a per-session marker `/tmp/verify-reminded-<session_id>` does NOT yet exist (1×/session)
3. `has_active_plan(cwd)` (reuse _common.sh helper)
4. `scripts/check.sh` exists in cwd (the harness's local quality gate)
5. git shows uncommitted CODE changes (non-.md) in cwd
Fail-safe: exit 0 on any parse error / missing git / no cwd. Never blocks (no decision:block).

## Non-goals (explicit)
- NOT a hard gate (no turn-end blocking). No `decision:block`.
- Does NOT run scripts/check.sh itself (just reminds) — avoids per-turn cost/side-effects.
- Closeout knowledge-capture determinism stays in the skill Closeout (review-strict gate);
  a Stop hook cannot reliably detect "RPI cycle completed", so it is out of scope here.

## Acceptance criteria (Closeout gate)
- `verify-loop-watch.sh` executable; wired to `Stop` in settings.json + settings.example.json.
- Registered in doctor REQUIRED_HOOKS (8 hooks) + install.sh (20 files) + verify-setup (8 hooks).
- New regression cases assert OUTPUT (systemMessage emitted vs silent), not just exit code:
  alert when all conditions hold; silent when no plan / no check.sh / no code change /
  stop_hook_active / marker already set. All green.
- `verify-all.sh` ALL PASS; no regression to Patch A/C.
- settings.json valid JSON; defaultMode/auth env untouched.

## Tasks
- [x] B1. `hooks/verify-loop-watch.sh` (new, chmod +x): advisory Stop hook per design above.
- [x] B2. `settings.json` + `settings.example.json`: add `Stop` group → verify-loop-watch.sh.
- [x] B3. `setup/doctor.sh` REQUIRED_HOOKS + `setup/install.sh` REQUIRED list & count(→20) +
      `setup/verify-setup.sh` hook list(→8) & settings hook-count threshold.
- [x] B4. `hooks/tests/run-all.sh` + `cases.tsv`: verify-loop-watch regression cases (output-based).
- [x] B5. Closeout: verify-all green; plan→completed; state.json cycle 5→6; commit + push.
