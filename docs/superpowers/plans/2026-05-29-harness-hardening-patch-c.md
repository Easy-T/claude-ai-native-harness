# Harness Hardening — Patch (C): Security Posture (secrets + threat model)

**Status:** completed
**RPI-Cycle:** 5
**Started:** 2026-05-29
**Completed:** 2026-05-30
**Result:** verify-all.sh ALL PASS (setup 45/0, unit 54/54, integration 5/5); review-strict PASS (non-goals intact — defaultMode/CCS auth untouched)

## Provenance (Phase R)
Research = 2026-05-29 harness audit, §7 item 2 (Critical: token protection) + critic
additional findings (plaintext OAuth tokens in .credentials.json; bypassPermissions +
unconditional Bash → prompt-injection-to-shell; no content guardrails). This patch
implements the LOW-RISK, ADDITIVE subset only.

## Scope (locked — user-approved "Patch C")
1. `.credentials.json` permission hardening (chmod 600) + a doctor.sh informational check.
2. NEW `enforce-secret-scan.sh` — PreToolUse guard on Write/Edit/NotebookEdit content AND
   Bash command: block when a HIGH-SPECIFICITY secret pattern (Anthropic/AWS/GitHub/GitLab/
   Slack/Google key, PEM private-key block) is about to be written; `SECRET_SCAN_SKIP` escape;
   placeholder-aware; fail-safe (exit 0 on parse failure / no payload).
3. `SECURITY.md` — document the threat model: single-operator trust, bypassPermissions posture,
   CCS proxy dependency, credential handling, the secret-scan guard + its limits.

## Non-goals (explicit — NOT in this patch)
- Do NOT change `permissions.defaultMode` (bypassPermissions stays — that's the user's call).
- Do NOT touch the CCS proxy / ANTHROPIC_* auth env in settings.json.
- No egress/network filtering, no PII scanning, no SAST. (Out of scope for a solo harness.)

## Acceptance criteria (Closeout gate)
- `enforce-secret-scan.sh` executable; registered in settings(.example).json on BOTH the
  Write|Edit|NotebookEdit group and the Bash group; in doctor REQUIRED_HOOKS + install.sh.
- New regression cases (real-looking key → BLOCK on Write and on Bash; placeholder → PASS;
  clean → PASS; SECRET_SCAN_SKIP → PASS), all green. Test fixtures must build fake keys at
  RUNTIME (string concat) so the test file itself contains no literal secret that would later
  self-trip the scanner.
- `verify-all.sh` ALL PASS (verify-setup updated to 7 hooks); no regression to Patch A.
- `settings.json` valid JSON. `.credentials.json` mode tightened (POSIX) / noted (win32).
- Every changed line traces to scope item 1/2/3.

## Tasks
- [x] C1. `SECURITY.md` threat-model doc at harness root.
- [x] C2. `hooks/enforce-secret-scan.sh` (new, chmod +x): high-specificity patterns, placeholder
      filter, SECRET_SCAN_SKIP escape, fail-safe. Reports secret TYPE, never the value.
- [x] C3. `settings.json` + `settings.example.json`: add enforce-secret-scan to both PreToolUse
      groups (Write|Edit|NotebookEdit and Bash).
- [x] C4. `.credentials.json` chmod 600 (one-time) + `doctor.sh` perm check + REQUIRED_HOOKS entry;
      `install.sh` REQUIRED list + count.
- [x] C5. `hooks/tests/run-all.sh` + `cases.tsv`: secret-scan regression cases (runtime-built
      fixtures). `verify-setup.sh`: hook list/count → 7.
- [x] C6. Closeout: verify-all green; plan → completed; state.json cycle 4→5 (handle v2/v5 prompts).
