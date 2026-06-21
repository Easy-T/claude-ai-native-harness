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
