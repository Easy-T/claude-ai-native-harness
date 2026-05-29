# Harness Hardening — Patch (A): Self-Protection + Bash Sealing + Matcher/Path Alignment

**Status:** completed
**RPI-Cycle:** 4
**Started:** 2026-05-29
**Completed:** 2026-05-29
**Result:** verify-all.sh ALL PASS (setup 44/0, unit 48/48, integration 5/5); review-strict PASS (no scope creep)

## Provenance (Phase R)
Research artifact = the 2026-05-29 harness audit (62 findings / 37 adversarially verified,
0 refuted / 16 executed scenarios, 15 confirming gaps / 3 live-verified industry sources incl.
RFC anthropics/claude-code#45427 "hooks are necessary but insufficient"). This patch implements
§7 recommendations **1 (Critical: self-protection + Bash sealing)** and **3 (High: matcher/path
alignment)** only. Items 2 (token protection), 4 (Stop-hook verification loop), 5 (1M-aware
auto-compact), and the orchestrator Edit-hunk / comment-grep gaps are explicitly OUT OF SCOPE.

## Problem (verified by direct hook execution)
1. `enforce-rpi-cycle.sh` whitelist (lines 14-20) unconditionally `exit 0` for `*/.claude/*`,
   `*/docs/*`, `*/.github/*`, `*/superpowers/*` regardless of file extension → arbitrary
   executable code (.py/.sh) smuggled through; the model can edit its own governing hooks
   (self-modification soundness bug). [scenarios S5, S11, S16]
2. PreToolUse matcher is `Write|Edit` only → `NotebookEdit` writes code with no gate. [S2]
   (Bash side-door [S1] handled by a new dedicated hook, since a Bash command is not a file write.)
3. `enforce-orchestrator.sh` gates only files literally named `SKILL.md` (case-sensitive). [S13]

## Acceptance criteria (Phase Closeout gate)
- All EXISTING `hooks/tests/run-all.sh` cases still pass (no regression).
- New regression cases for every behavior this patch changes, all passing.
- `bash ~/.claude/hooks/tests/run-all.sh` pass-rate ≥ 95% (spec §6.6).
- New `enforce-rpi-bash.sh` is executable and registered in `doctor.sh` REQUIRED_HOOKS.
- `settings.json` + `settings.example.json` both reflect the new wiring (parity).
- `node -e JSON.parse(settings.json)` valid.
- Every changed line traces to item 1 or 3 (Surgical Changes); no scope creep.

## Tasks

- [x] T1. `hooks/_common.sh`: add `has_active_plan <cwd>` helper (replicates current
      enforce-rpi-cycle plan-detection semantics exactly; printf plan path, return 0/1).
- [x] T2. `hooks/enforce-rpi-cycle.sh`: (a) resolve path from `tool_input.file_path` OR
      `tool_input.notebook_path`; (b) two-stage whitelist — non-executable artifacts always pass;
      code/executable extensions are NEVER directory-exempted; remove `*/superpowers/*` dir
      bypass; (c) use `has_active_plan` (preserve no-plans-dir vs no-active-plan messages).
- [x] T3. `hooks/enforce-rpi-bash.sh`: NEW. Parse `tool_input.command`; detect redirection
      (`>`/`>>`) or `tee` whose target ends in a code extension (excl. /dev/null); if found AND
      no active plan AND no RPI_SKIP → BLOCK (exit 2) with escape-hatch message; else exit 0.
      Fail-safe (exit 0) on empty/unparseable command. `chmod +x`.
- [x] T4. `hooks/enforce-orchestrator.sh`: case-insensitive `*/skills/*/SKILL.md` match
      (`shopt -s nocasematch`).
- [x] T5. `settings.json` + `settings.example.json`: PreToolUse matcher → `Write|Edit|NotebookEdit`;
      add a second PreToolUse group matcher `Bash` → `enforce-rpi-bash.sh`.
- [x] T6. `setup/doctor.sh`: add `enforce-rpi-bash.sh` to REQUIRED_HOOKS. `setup/install.sh`:
      add it to REQUIRED list + update file count.
- [x] T7. `hooks/tests/run-all.sh`: add regression cases (Bash redirect→code BLOCK / →.md PASS /
      RPI_SKIP PASS / active-plan PASS; .py under docs/ BLOCK; .sh under .claude/ BLOCK;
      vendor/superpowers/.py BLOCK; settings.json under .claude/ PASS; NotebookEdit code BLOCK &
      w/ plan PASS; lowercase skill.md bad-skeleton BLOCK). Also add cases.tsv rows.
- [x] T8. Closeout: run run-all.sh until green; update this plan to completed; offer state.json bump.

## Non-goals (explicit)
- No change to trivial line-count semantics (S7), Status-trailing-text parse (S14), empty-cwd
  fallback (S12), orchestrator Edit-hunk/comment grep (S3/S4), auto-compact limit (S8/S15),
  credentials/permission posture (items 2), or a Stop hook (item 4).
