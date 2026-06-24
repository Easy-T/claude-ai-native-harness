# Worktree Teardown SessionEnd Hook — Design Record (ADR-equivalent)

> Durable design/ADR for a harness *behavior* change (§5 ADR-trigger). Genesis-record model:
> v1 numbers/decisions preserved; current-value SSOT = README + verify-setup seals.
> Status of this document: **design accepted, activation user-gated** (see §Activation Gate).

**Date:** 2026-06-21
**Scope:** Global `~/.claude` harness. Adds the harness's first `SessionEnd` hook.
**Decision class:** Architecture-impacting (new hook event type + a *data-deleting* automation) → ADR mandated by global CLAUDE.md §5.

---

## 1. Context / Problem

The target repo (`C:\Users\12132\Documents\second_brain_project`, AI-Ready RPIC workflow) runs **parallel worktree sessions** under `<repo>/.claude/worktrees/cycle-*` (manual `git worktree add`, branch `worktree-cycle-*`). Each cycle session launches its own uvicorn + Vite (node/esbuild) dev servers on its own ports.

After a cycle is merged, cleanup of the worktree fails because the **creating session is still alive**:
- its dev servers (node/esbuild/uvicorn/python) still hold `app/frontend/node_modules`,
- its persistent shell is still `cd`'d into the worktree, locking the directory,

so `rm -rf <worktree>` fails with **"Device or resource busy"** and the operator must manually kill PIDs and retry every time. Root cause: cleanup is attempted *while the creating session lives*.

**Goal:** a deterministic, agent-independent cleanup that runs **at session end** — kill the worktree's processes, delete the worktree directory (junction-safe), and prune git's bookkeeping.

## 2. The hard invariant: data-loss = 0

This automation deletes directories. The repo carries a documented **data-loss disaster** (`docs/ai-context/non-obvious.md`, entry "2026-06-17 node_modules 정션"):

> A Windows **directory junction** at `app/frontend/node_modules` (target = the *main* repo's node_modules) was created to skip `npm install`. Cleanup ran `git worktree remove --force <worktree>` and **the recursive delete followed the junction and wiped the main repo's node_modules**. The note groups `git worktree remove --force`, Git Bash `rm -rf`, and PowerShell `Remove-Item -Recurse` as recursive deleters that *may* follow reparse points, and prescribes: **pre-detect reparse points → remove the link only (Windows `rmdir`) → verify target intact → then delete the dir.** Bare `rm -rf` / `git worktree remove --force` on a junction-holding worktree is **forbidden.**

This directly contradicts a naive "just use `rm -rf`, it unlinks junctions" assumption. We resolved it **empirically** (§3) and designed for safety regardless of the answer (§4).

## 3. Empirical findings (Research, 2026-06-21)

All tests in an isolated scratch dir (`C:\Users\12132\Documents\_wtjtest`, no real node_modules involved), Windows 11, Git Bash MSYS2 coreutils.

| # | Test | Result |
|---|------|--------|
| E1 | `rm -rf` on a dir containing a `mklink /J` junction (target has sentinels) | **Target survived** (junction unlinked, not followed). rm exit 0. So *in this env* MSYS2 `rm -rf` is junction-safe — contradicting #61's grouping of `rm -rf` with the follower set. |
| E2 | PowerShell `Get-ChildItem -Recurse -Force` filtered to `ReparsePoint` | Lists the junction, **does not recurse into it** — reliable detection. |
| E3 | PowerShell `[System.IO.Directory]::Delete($path,$false)` (non-recursive) on a junction | **Unlinks the junction, target intact.** Chosen link-only primitive. |
| E4 | `cmd /c rmdir` via Git Bash | **Fails** (MSYS arg/path conversion mangling) — rejected. PowerShell handles Windows paths natively. |
| E5 | Full sequence on a **nested** junction `wt/app/frontend/node_modules` (real-scenario): detect → `Delete($false)` each → assert 0 remain → POSIX `rm -rf` | Junction removed, **0 reparse remaining**, rm exit 0, **target (main) 3/3 files survived.** |
| E6 | RPI bash gate inspects *agent* Bash tool calls | Writing `App.tsx` via `>` was **blocked** (no active plan) → confirms the gate guards agent Bash, NOT hook-internal commands. So the teardown hook's `rm` is not intercepted by PreToolUse. |

**Test-driven catch (T6, Implement phase):** the first GUARD-3 implementation compared `--git-dir` vs `--git-common-dir` as strings; git prints the former absolute and the latter relative (`../../../.git`), so a non-worktree subdir of the main repo mis-classified as a linked worktree and was **deleted** by the test. Re-hardened to `--absolute-git-dir` + `/worktrees/` segment + `basename==NAME` (E-confirmed: main/decoy → `.../.git`, linked → `.../.git/worktrees/<name>`). This is exactly why the handoff mandated empirical verification over trusting plausible-looking guards.

**Conclusion:** `rm -rf` happens to be junction-safe here, but on a data-loss path we do **not** rely on that. We make **reparse pre-removal a hard precondition of `rm`** (defense-in-depth): no junction ever reaches the `rm` step, so following-a-junction is *impossible* regardless of MSYS version / reparse tag.

## 4. Decision (design)

A new `SessionEnd` hook `~/.claude/hooks/worktree-teardown.sh`, wired matcher-less-but-reason-scoped in `settings.json`. Flow:

1. **reason self-gate (best-effort):** if stdin carries a `reason` field and it is `clear` / `resume` / `bypass_permissions_disabled` → **no-op** (session continues; deleting cwd would break it). (`reason` is **not guaranteed** in SessionEnd stdin — the matcher is the primary control; this is belt-and-suspenders for when it *is* present.)
2. **GUARD 1 — worktree marker:** act only if `cwd` matches `*/.claude/worktrees/<name>`; else no-op. Handles cwd-drift to subdirs by deriving the worktree root from any path under the marker.
3. **Derive** `REPO_ROOT = cwd up to /.claude/worktrees`, `NAME = first segment after`, `WT_ROOT = REPO_ROOT/.claude/worktrees/NAME`.
4. **GUARD 2 — path sanity:** reject empty `NAME`/`REPO_ROOT`, `NAME` ∈ {`.`,`..`}, `WT_ROOT` ∈ {`/`,`$HOME`}, or missing marker → no-op.
5. **GUARD 3 — linked-worktree proof:** `git -C WT_ROOT rev-parse --absolute-git-dir` must contain a `/worktrees/` segment **and** its basename must equal `NAME` (i.e. it is `<repo>/.git/worktrees/<NAME>`). The main checkout and any non-worktree subdir resolve to `.../.git` (no `/worktrees/`) → **no-op**; git absent/empty → **no-op**. This is the structural guarantee the main repo is never a target. *(The earlier `--git-dir` ≠ `--git-common-dir` string compare was rejected — git prints `--git-dir` **absolute** but `--git-common-dir` **relative** (`../../../.git`), so the main repo mis-compared as "different" and a non-worktree subdir would have been deleted. Caught by test T6; see §3.)*
6. Capture `BRANCH = git -C WT_ROOT rev-parse --abbrev-ref HEAD` (before deletion).
7. `cd REPO_ROOT` — release the hook's own cwd from the worktree.
8. **STEP A — process kill (best-effort, secondary):** PowerShell `Get-CimInstance Win32_Process`; kill PIDs whose `Name` ∈ {node,esbuild,vite,python,python3,py,uvicorn,npm} **and** whose `CommandLine`+`ExecutablePath` (lowercased) **contains the exact worktree path**. Exact-path match avoids killing other worktrees'/sessions' processes. (Limitation: a process that references the worktree only via *cwd* — not in argv/exe path — is not matched; Win32_Process exposes no cwd. Accepted: kill is secondary; `rm` retries handle transient locks.)
9. **STEP B — reparse pre-removal (mandatory precondition of rm):** PowerShell enumerate reparse points under `WT_ROOT`, `[IO.Directory]::Delete($_,$false)` each, then re-scan and emit the remaining count. `rm` proceeds **only if remaining == 0**. If PowerShell is absent or any reparse point remains → **skip rm**, `hook_log ALERT`, stderr surface, leave the worktree (acceptable leftover). This makes junction-following impossible.
10. **STEP C — POSIX `rm -rf WT_ROOT`** with bounded retry (5 × 1s) to ride out a transient cwd/lock release race. `git worktree remove --force` is **never** used.
11. **STEP D — bookkeeping:** `git -C REPO_ROOT worktree prune`; then `branch -D BRANCH` **only if** `rm` succeeded **and** `BRANCH` matches the convention `worktree-*` (never `master`/`main`/`HEAD`/non-convention — those are kept).
12. **Always `exit 0`** (SessionEnd cannot block termination; exit code is ignored; stderr surfaces to the operator).

### Matcher

`matcher: "prompt_input_exit|logout|other"` — fires on genuine terminations (normal quit ≈ `prompt_input_exit`, explicit `logout`, catch-all `other`). **Excludes** `clear` and `resume` (session continues in the same cwd — deleting it would break the live session) and `bypass_permissions_disabled` (ambiguous; conservative exclusion costs only a rare leftover). `timeout: 30` bounds the hook.

### Failure modes (all acceptable, none worsen the status quo)

- **crash / SIGKILL** → SessionEnd not fired → worktree left (same as today).
- **session still holds cwd lock** (parent process exiting concurrently) → `rm` retries; if still busy → leftover (today's manual state).
- **PowerShell absent / reparse remains** → `rm` skipped → leftover + ALERT (never a data-loss).
- **already cleaned** → idempotent no-op.
- **non-worktree / main-repo / general session** → no-op by GUARD 1/3.

## 5. Activation Gate (success criterion ⑥)

Because the hook deletes data, the **guard logic + rm path computation are reviewed by the operator before the `settings.json` `SessionEnd` entry is added**. Sequence:
- Pre-review: create the (inert) script on disk + add to `doctor.sh REQUIRED_HOOKS` (so verify-setup #24 stays green) + measured simulation tests. The script does nothing until wired.
- **Operator review** of guards + path math.
- Post-approval: add the identical `SessionEnd` block to `settings.json` **and** `settings.example.json` (#23 parity), update README/SECURITY/CONTEXT.

## 6. Alternatives considered

- **`git worktree remove --force`** — rejected (the #61 1st-cause; follows junctions; also fails when cwd is inside).
- **`rm -rf` alone, trusting MSYS junction-safety (E1)** — rejected as sole mechanism (single data point on a catastrophic path; version-fragile). Kept only *after* reparse pre-removal guarantees no junctions remain.
- **`cmd /c rmdir` for link removal (the #61 prescription verbatim)** — rejected (E4: MSYS path mangling). PowerShell `Delete($false)` is the robust equivalent.
- **Stop hook** — rejected (fires every turn, not at session end).
- **In-hook reason as the sole gate** — rejected (`reason` not guaranteed in stdin); matcher is primary, reason self-gate is additive.
- **Matcher includes `clear`/`resume`** — rejected (would delete an active worktree).

## 7. Consequences

- First `SessionEnd` hook → touches count/parity SSOTs: `doctor.sh REQUIRED_HOOKS` (#24, mandatory), `settings.json` + `settings.example.json` parity (#23, mandatory), README "9개 hook"→"10개" + table row, SECURITY.md (data-deletion safety section), CONTEXT.md term.
- New session requires restart to load a new hook/matcher (README §ML note).
- Belt-and-suspenders (optional): `closeout-pr-cycle` final clause to `cd` repo-root + kill dev servers before ending, so even a still-alive session's first manual `rm` succeeds.

## 8. References

- Target repo `docs/ai-context/non-obvious.md` — "2026-06-17 node_modules 정션" (data-loss disaster).
- Official Claude Code hooks reference (SessionEnd: side-effect only, cannot block; reasons; per-hook `timeout`; matcher regex).
- Empirical scratch tests E1–E6 (this session).

---

## 9. Robustness revision — cd-out cleanup via `session_id` marker (2026-06-22)

> In-place dated revision (genesis-record model: §1–8 v1 design preserved; this section is the additive
> design delta). Decision class: same subsystem, adds a **fallback path** to GUARD 1 — not a new hook.
>
> **⚠ CORRECTED by §10 (cycle-40, 2026-06-22):** §9.1's root cause ("closeout `cd`'s back to the repo root")
> is a *partial misdiagnosis*, and §9.2-step-1's `SessionStart`-cwd marker WRITE is **structurally inert in
> real sessions** (hook `cwd` is the CLI launch dir = main root, never the worktree). The CONSUME side (§9.2
> step 2) and the C1–C4 invariants stand; only the WRITE trigger moves to `PreToolUse`. Read §10 before relying
> on this section.

### 9.1 Problem the v1 design missed

v1 GUARD 1 keys teardown on **`cwd`** (`*/.claude/worktrees/<name>`). But the target repo's RPI **closeout
`cd`'s back to the repo root** before the session ends (to run `verify-all`, git ops, etc.). So at
`SessionEnd` the `cwd` is the **main root**, GUARD 1 misses (`noop:not-worktree`), and the worktree is
**never cleaned** — it accumulates (observed: `cycle-qa-d-layout` left behind). **A cwd-keyed teardown
structurally cannot clean a worktree the session has already left.**

### 9.2 Decision — additive `session_id`-keyed marker (write at start, consume at end)

`session_id` is present and **stable** across `SessionStart`→`SessionEnd` of one session (official hooks
schema, verified 2026-06-22: SessionStart `{session_id,cwd,source,…}`, SessionEnd `{session_id,cwd,reason}`).
Exploit that to remember the worktree independent of end-time cwd:

1. **`SessionStart` (`session-start-audit.sh`) — WRITE.** If `cwd` matches `*/.claude/worktrees/<name>`,
   record the derived **`WT_ROOT`** to `$HOME/.claude/worktrees-marker/<session_id>` (one line, absolute path).
   Idempotent across `source ∈ {startup,resume,clear,compact}` (same SID + same cwd → same content).
2. **`SessionEnd` (`worktree-teardown.sh`) — CONSUME.** Determine the teardown target as:
   **`cwd` (authoritative, v1 GUARD 1) → else the session's own marker (fallback)**. Then **unlink the own
   marker** (consumed). The marker is read **only for the hook's own `session_id`** — never another session's.
3. **Stale-marker prune (`SessionStart`).** A crash (no `SessionEnd`) leaves a marker. On each start, scan
   `worktrees-marker/`; if a marker's recorded path **no longer exists**, delete the **marker file only**
   (never a directory; never another session's *live* worktree). Bounds the marker dir in this global config.

### 9.3 Hard constraints (carried from v1 #61 + new)

- **C1 — empty/`unknown` `session_id` ⇒ skip marker WRITE *and* CONSUME entirely** (cwd GUARD 1 only).
  Rationale: concurrent sessions with an absent `session_id` would share one `unknown` marker; a consume
  could then tear down **another session's *active* worktree**. The empty-SID case must never use the marker.
- **C2 — the marker-derived path is *not trusted*:** it passes the **same GUARD 2 (sanity) + GUARD 3
  (linked-worktree `--absolute-git-dir` proof)** as the cwd path before any `rm`. A marker can only ever
  point teardown at a genuine linked worktree of its repo; a stale/forged path resolves to non-worktree → no-op.
- **C3 — #61 defenses unchanged:** reparse pre-removal → `remaining==0` assert → POSIX `rm -rf`;
  **`git worktree remove --force` still forbidden**; branch delete only for `worktree-*`/never `master|main`.
- **C4 — marker WRITE/CONSUME/prune are strictly non-blocking (fail-open):** every marker op is best-effort
  (`|| true`, `2>/dev/null`); a marker failure must never block session start/end. Under `session-start-audit`'s
  active `set -euo pipefail`, the SID default uses the `|| ` form (`[ -n "$SID" ] || SID=unknown`) — the v1
  teardown idiom `[ -z "$SID" ] && SID=unknown` would *exit* the hook on a non-empty SID and is rejected here.

### 9.4 Interaction with the matcher / reason gate (no double-free, no active-worktree loss)

- `clear`/`resume`: matcher excludes them and the reason self-gate no-ops **before** consume → the marker is
  **kept**; the subsequent `SessionStart` (`source=clear`/after-compact) re-writes it. The live worktree is
  never deleted while the session continues.
- Same-session both-present: if end-cwd is still inside the worktree, the **cwd** path is used (authoritative)
  and the own marker is also unlinked — no leftover.

### 9.5 Failure modes (all acceptable; none worsen v1)

| Mode | Outcome |
|------|---------|
| cd-out before end (the bug) | **Now cleaned** via marker. |
| crash / SIGKILL | No `SessionEnd` → worktree + marker left; next start prunes the marker if WT_ROOT is gone (worktree leak unchanged from v1). |
| empty `session_id` + cd-out | No marker path → no-op (conservative; a leftover, never a mis-delete). |
| forged/stale marker path | GUARD 2/3 reject → no-op. |
| marker dir unwritable | WRITE fails silently; teardown falls back to cwd-only (v1 behavior). |

### 9.6 Surfaces touched (delta only)

`_common.sh` (+`wt_marker_path` SSOT), `session-start-audit.sh` (+WRITE +prune), `worktree-teardown.sh`
(+CONSUME fallback). Tests: `worktree-teardown.test.sh` (+cd-out, +empty-SID — standalone), `run-all.sh`
+`cases.tsv` (+5 SessionStart marker cases → README cases count 141→146, verify-setup #20). **No new hook
file, no `settings.json`/`settings.example.json` change** (both SessionStart & SessionEnd already wired) →
#8/#14/#23/#24 untouched.

---

## 10. Root-cause correction + PreToolUse marker WRITE (2026-06-22, cycle-40)

> In-place dated revision (genesis-record model). **Corrects §9.1's partial misdiagnosis** and relocates the
> marker WRITE from `SessionStart` (structurally inert) to `PreToolUse`. Same subsystem: moves the WRITE
> trigger — CONSUME (§9.2 step 2) + invariants C1–C4 unchanged; adds concurrency guard C5.

### 10.1 What §9 got wrong (empirically corrected)

§9.1 attributed the missed teardown to the RPI closeout **`cd`-ing back to the repo root** before end. That is
a *partial* misdiagnosis. Decisive fact: **the `cwd` delivered to `SessionStart`/`SessionEnd` hooks is the
`claude` CLI process's working directory = the directory `claude` was launched from = the *main repo root* — it
is *never* the worktree, regardless of any `cd`.** Implementation sessions launch `claude` at the main root and
touch the worktree only through Edit/Bash tool *absolute-path arguments*; Bash `cd` runs in a per-command
subshell and never mutates the parent CLI process cwd. So the §9.2-step-1 `SessionStart` WRITE
(`case "$cwd" in */.claude/worktrees/*`) **never fires in a real session** — the marker dir stays permanently
empty — and CONSUME has nothing to read. The cycle-39 WRITE and CONSUME code are both correct but were keyed to
a signal (`SessionStart` cwd) that is structurally always the main root.

Evidence (observed): ① `worktrees-marker/` permanently empty; ② every `SessionEnd` log `noop:not-worktree`,
`cwd`=main root; ③ a session that never `cd`'d to the main root still logged `cwd`=main root (refutes the
cd-out story); ④ the **`PreToolUse`** gate `enforce-rpi-cycle` *does* receive the worktree absolute path
(`.../.claude/worktrees/<name>/...`) in `tool_input.file_path` — the worktree identity reaches `PreToolUse`,
not `SessionStart`/`SessionEnd` cwd. (Process lesson → §10.6.)

### 10.2 Decision — record the marker from PreToolUse (where the worktree path actually arrives)

`session_id` is present in `PreToolUse` stdin (verified 2026-06-22: `surface-constitution.sh` reads it; a live
event injection returns it; the bypass-surfacing cases feed it). The worktree absolute path arrives in
`tool_input.file_path`/`tool_input.notebook_path` (Write/Edit/NotebookEdit) and `tool_input.command` (Bash). So:

1. **`_common.sh` (SSOT helpers):** `wt_root_from_path <path-or-command>` extracts the first
   `<repo>/.claude/worktrees/<name>` from any path or command string (ERE: maximal non-delimiter run before
   `/.claude/worktrees/`, single segment after — empirically validated on clean path, `cd` command, quoted
   path, Windows backslash, nested `.claude/.claude` harness-self, non-worktree, and the `worktrees-marker/`
   dir which must *not* match). `record_worktree_marker <session_id> <path-or-command>` = C1-skip on
   empty/`unknown` sid → `wt_root_from_path` → write `WT_ROOT` to `wt_marker_path(sid)`. Both are pure-bash
   (no node), strictly fail-open (`|| true`, `2>/dev/null`), always `return 0` (set-e safe under the gates'
   `set -euo pipefail` — verified). The 3 derivation sites (teardown, session-start, new write) share them.
2. **`enforce-rpi-cycle.sh` (Write|Edit|NotebookEdit) + `enforce-rpi-bash.sh` (Bash):** call
   `record_worktree_marker "$SID" "$FILE_PATH"` / `"$CMD"` **at the top, before any block/exit** — so the marker
   is recorded whenever the session is observed working in a worktree, even if *that* tool call is gated.
   Strictly side-effect; never changes the gate's exit code or block decision.
3. **`session-start-audit.sh` WRITE → secondary.** Kept (now via `record_worktree_marker "$SID" "$CWD"`) only
   for the rare "launched *from* a worktree" case; the primary path is `PreToolUse`. Stale-prune unchanged.
4. **`worktree-teardown.sh` CONSUME unchanged** (§9.2 step 2): cwd → else own marker → GUARD 2/3 → rm.
   The #61 data-loss invariants stay verbatim: reparse pre-removal → `remaining==0` assert → POSIX `rm -rf`;
   **`git worktree remove --force` forbidden**; C1 empty/`unknown` sid skips marker WRITE *and* CONSUME; the
   hook always `exit 0`. cycle-40 adds only the WRITE trigger (§10.2 steps 1–2) + guard C5 (§10.3) — it removes
   no guard.

### 10.3 New hard constraint C5 — concurrent same-worktree must not delete an active worktree

Now that the WRITE actually fires, two concurrent sessions in the *same* worktree (against the worktree=session
1:1 convention) become a real risk: the first to end would consume its own marker and tear down a worktree the
second is still using. **C5 — before any destructive step (after GUARD 3), `worktree-teardown.sh` scans
`worktrees-marker/`; if *another* session's marker (own already consumed at CONSUME) points at the same
`WT_ROOT` → no-op (`noop:concurrent-owner`).** This trades a rare leftover (a stale marker from a crashed peer
blocks cleanup until its `WT_ROOT` is gone and the stale-prune removes it) for never deleting a live peer's
worktree — the correct bias on a data-deletion path. The 1:1 convention remains the assumption; C5 is the
safety net when it is violated. Leftover ≠ data loss.

**Residual window C5 does NOT close (accepted, bounded — adversarial review 2026-06-23):** because the WRITE
now actually fires, a session A whose `tool_input` references *another* session B's worktree path (a Bash
command or Edit touching `.../.claude/worktrees/<B>/...`, including a single command naming two worktrees —
`wt_root_from_path` greedily takes the *first* match) records A's own-SID marker pointing at B's worktree; at
A's `SessionEnd` A would target B's worktree. C5 protects B **iff B has already written its own marker** (i.e.
B has triggered any PreToolUse gate). The unclosed window is: B is *active but has not yet triggered a single
Write/Edit/Bash gate* (only at B's very start) → no B marker → C5 finds nothing → A can `rm -rf` B's active
worktree. This is **bounded to a genuine linked worktree of the same repo** (GUARD 2/3 still prove it; the main
repo / `$HOME` / outside are never reachable), requires violating the worktree=session 1:1 convention, and the
timing window is narrow (a real impl session triggers a gate within its first tool call). It is the #61
*disruption* class (lose an active peer worktree's uncommitted work), never the #61 *main-repo* data-loss
class. Accepted as best-effort under the 1:1 convention; a hard cross-session lock is out of scope for cycle-40.

### 10.4 Failure modes (delta)

| Mode | Outcome |
|------|---------|
| launched at main root, work in worktree (the real flow) | **Now cleaned** — PreToolUse writes the marker; SessionEnd (cwd=main root) consumes it. |
| empty `session_id` PreToolUse | no marker (C1) → cwd-only teardown (leftover if cd-out; never a mis-delete). |
| two concurrent sessions, same worktree | first end → C5 no-op (peer's worktree preserved); last end → cleaned. |
| non-worktree path in tool_input | `wt_root_from_path` no-match → no marker (no-op). |
| node absent | gates exit early (require_node); no marker → cwd-only (leftover, fail-open). |

### 10.5 Surfaces touched (delta only)

`_common.sh` (+`wt_root_from_path`, +`record_worktree_marker`), `enforce-rpi-cycle.sh` (+marker call, +`session_id`
in the existing `json_get_many`, reuse at the bypass line), `enforce-rpi-bash.sh` (+marker call, +hoisted
`session_id`), `session-start-audit.sh` (WRITE → `record_worktree_marker`; comment corrected),
`worktree-teardown.sh` (+C5 concurrency guard). Tests: `worktree-teardown.test.sh` (+Tb real-signal E2E, +Tc
concurrency → 13→20), `run-all.sh`+`cases.tsv` (+161–166: four PreToolUse gate-E2E marker-WRITE cases in the
**real-input shape — cwd=main root, worktree path in `tool_input`** — plus two `wt_root_from_path` unit cases
incl. the `worktrees-marker/` no-self-match safety property → 146→152; README cases count + verify-setup #20).
**No new hook file, no `settings.json`/`settings.example.json` change** → #8/#14/#23/#24 untouched.

### 10.6 Process lesson (5-Whys → §10.6; harness has no `non-obvious.md` — spec+memory are SSOT)

**Why did cycle-39 ship a fix keyed to a structurally-inert signal *and pass its own tests*?**
1. Why did the marker never get written? — The WRITE was keyed to `SessionStart` cwd, which is always the main
   root, never the worktree.
2. Why was it keyed to a signal that's always the main root? — The design *assumed* `SessionStart` cwd equals
   the worktree when the session works there, without verifying what `cwd` actually contains at runtime.
3. Why wasn't the wrong assumption caught in testing? — The cycle-39 tests fed a **synthetic `cwd`=worktree**
   directly (`test_ssa_mark` passes the worktree as cwd), confirming the code *given that input* — but the real
   hook input is `cwd`=main root with the worktree path only in `tool_input`. The test assumed the conclusion.
4. Why did the test feed synthetic input matching the assumption? — There was no requirement that a hook test
   reproduce the **real runtime shape** of the stdin field whose *semantics* the fix depends on.
5. Root cause (system/process): **a hook test that depends on the meaning of a stdin field (which field carries
   what at runtime) must first establish that meaning empirically and feed input in that real shape — not
   synthetic input shaped to the desired conclusion.** A code-given-input test cannot validate a
   field-semantics assumption.

**SMART action (landed this cycle):** the new real-input-shape cases (161–164) feed `cwd`=main root + worktree
path in `tool_input` (the production shape), and a RED-first step fixes that the *current* code writes no marker
for that shape. Recorded here (§10.6) + in the project memory; the global harness has no `non-obvious.md`, so
spec §10.6 + memory are the SSOT for this lesson.

---

## 11. Identification-independent self-healing sweep + instrumentation (2026-06-23, cycle-41)

> In-place dated revision. Adds an **identification-independent backstop** (a `git worktree prune` +
> orphan-branch sweep) because even §10's PreToolUse marker leaves a residue class the marker cannot reach.
> Same subsystem; adds a SessionStart sweep + record/consume instrumentation. CONSUME delete path + all #61/C1–C5
> invariants unchanged.

### 11.1 Residue the marker mechanism does NOT clean (observed in a real project, 3+ recurrences)

In the target project `second_brain_project`, after RPI worktree cycles, the worktree *directory* disappears but:
- `git worktree list` keeps the entry as **prunable** (gitdir → non-existent) → manual `git worktree prune`
  needed every time;
- the `worktree-*` convention branches are **never deleted** → they accumulate (observed: 8).

Data-loss = 0, but deterministic accumulation = the cleanup mechanism is not running. The hook log shows real
`SessionEnd` consistently `noop:not-worktree`, `cwd=<main project root>` — and crucially **still `noop`
after the §10 PreToolUse-marker cycle landed**: the marker dir is empty at `SessionEnd`.

### 11.2 Why §10's marker also misses this (hypotheses; instrumentation to confirm)

The §10 mechanism is wired + unit-tested, yet in the real project the marker is not found at `SessionEnd`.
Candidate causes (to be confirmed by §11.4 instrumentation in the real project — they are not resolvable from the
harness repo alone):
- **(a) SID mismatch** — the `session_id` seen by the `PreToolUse` record differs from the one at `SessionEnd`
  (e.g. the harness issues per-event ids, or a sub-session id) → marker written under one key, consumed under
  another → never found.
- **(b) WT path never reaches the gate** — if the session enters the worktree via the harness `EnterWorktree`
  tool (cwd-pinned/sandboxed), the `tool_input.file_path`/`command` delivered to the *global* `PreToolUse` may
  not carry the worktree-absolute path → `record_worktree_marker` extracts no `WT_ROOT` → no marker.
- **(c) the directory is removed by the harness, not the hook (most likely)** — `EnterWorktree`/the harness
  removes the worktree *directory* on exit (leaving git's registration prunable + the branch), so the global
  `SessionEnd` hook legitimately finds nothing to delete (`noop`) and only the git bookkeeping + branch remain.
  Under (c) the hook's *delete* role is moot; its useful role becomes **the bookkeeping the harness leaves
  behind**, which is exactly §11.3.

### 11.3 Decision — a `git worktree prune` + orphan-branch sweep, keyed on nothing (so it can't miss)

Regardless of which of (a)/(b)/(c) holds, a sweep that derives its work from **git's own state** (not from a
session-id marker or cwd) closes the residue class deterministically:

1. **`git worktree prune`** — removes only registrations whose worktree directory is **gone**. Never touches a
   live worktree. Idempotent, safe.
2. **Delete orphan convention branches** — for each local `worktree-*` branch, delete it **iff no live worktree
   currently has it checked out** (compared against `git worktree list --porcelain` `branch` lines). A branch
   occupied by *any* live worktree (this or another session) is in the list → **protected**. (`git branch -D`
   *also* independently refuses to delete a checked-out branch — double safety.)

**Where:** `session-start-audit.sh` (`SessionStart`, already fires with `cwd` = main project root). Running at
start cleans residue from *previous* cycles, including sessions that crashed without `SessionEnd`. **Gated** on
`$CWD/.claude/worktrees` existing (harness-worktree projects only) so it never touches `worktree-*` branches in
unrelated repos. Pure-bash, fail-open, `set -e` safe (all git ops `|| true`, always returns 0).

**Safety invariant (same principle as C5):** the sweep can only remove a registration whose directory is gone or
a branch no live worktree holds — it can never remove an *active* worktree or a branch in use by another session.
Empirically validated (2026-06-23): a scratch repo with a prunable worktree (dir removed), a live worktree, an
orphan branch, and a non-convention branch → after sweep: prunable→0, orphan + dir-removed branches deleted, the
live worktree + its branch + the non-convention branch all intact.

### 11.4 Instrumentation (resolve (a)/(b) in the real project)

`record_worktree_marker` logs `hook_log "record-wt-marker" "$WT_ROOT" "PASS" "sid=$sid"` **when it actually
writes a marker** (bounded to worktree-touching tool calls — no per-call spam). `worktree-teardown`'s
`noop:not-worktree` branch logs `sid=$SID mk_exists=<0|1>`. Then in a real session: a `record-wt-marker` line
with sid=X but a `SessionEnd` `mk_exists=0 sid=Y` (X≠Y) ⇒ (a); **no** `record-wt-marker` line for the session ⇒
(b); the sweep ((11.3)) makes the cleanup correct under either. This is diagnostic only — the sweep is the fix.

### 11.5 Surfaces touched (delta only)

`_common.sh` (+`sweep_orphan_worktrees`, +record-marker instrumentation log), `session-start-audit.sh` (+sweep
call, gated), `worktree-teardown.sh` (+`sid`/`mk_exists` in the `noop:not-worktree` log line). Tests:
`worktree-teardown.test.sh` (+sweep E2E: prunable + orphan-branch cleaned, live worktree/branch + non-convention
branch protected) and `run-all.sh`+`cases.tsv` (+a gated sweep unit case on a scratch git repo). **No new hook
file, no `settings.json` change** (`SessionStart` already wired) → seals #8/#14/#23/#24 untouched. CONSUME delete
path + #61/C1–C5 invariants **unchanged**.

### 11.6 Fitness function (regression guard)

After N real cycles: `git worktree list` prunable = 0 **and** `git branch --list 'worktree-*'` orphan = 0. The
test suite pins the "marker-not-found + dir-already-removed" scenario (the harness-removed-dir case) so the sweep
is proven to clean registration + branch while protecting active state.
