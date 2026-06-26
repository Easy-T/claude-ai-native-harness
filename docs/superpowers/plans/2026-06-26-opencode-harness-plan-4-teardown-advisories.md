# opencode Harness — Plan 4: worktree-teardown substitute + tool.execute.after advisories

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:test-driven-development for each task (RED→GREEN). Steps use checkbox (`- [ ]`).

**Status:** completed
**RPI-Cycle:** 45 (opencode-harness migration — plan 4 of 5)
**Started:** 2026-06-26
**Completed:** 2026-06-27

> **Verification record (spec §16):** T1–T5 ALL PASS. Unit **83/83** · oracles diff==0(20) + discovery 20/20 · 3-lens adversarial review PASS (0 critical/major; 5 minors applied). **Live (opencode 1.17.11):** T4-A advisory text reaches the model-visible bash result (`tool.execute.after` output-mutation IS a model channel on the pinned version — spec §16.A risk resolved); T4-B `dispose()` fires on headless run completion; T4-C `pruneWorktrees` removes an orphan worktree registration and preserves the branch (branch-D never called).

**Goal:** Add the two remaining runtime behaviours from spec §16: (A) `tool.execute.after` advisories that surface RPI bypass + §5/§8 constitution reminders into the model-visible tool output (native tools only, once-per-session, fail-open), and (B) a `git worktree prune` teardown substitute wired to plugin init + `dispose()` (the honest scoped-down worktree cleanup — branch-D is NOT ported, see spec §16.B). Success = unit tests green + live E2E: an RPI_SKIP'd bash call's tool result carries the advisory text the model reads; `dispose()` fires; prune removes a dir-gone worktree registration; no regression (full suite + verify-setup).

**Architecture (spec §16):** v1 plugin `tool.execute.after` mutates the same `output` object opencode returns to the model for native tools (bash/edit/write/apply_patch) → an additionalContext-equivalent model channel (R4 upgraded). MCP path uses a separate object → excluded. Worktree: opencode auto-creates no per-session worktree; the model uses superpowers `git worktree add .worktrees/<arbitrary-branch>`; `finishing-a-development-branch` self-cleans. So the only safe universal op is `git worktree prune` (de-registers dir-gone worktrees; never touches branches or live worktrees).

## Global Constraints
- **Fail-open everywhere.** Advisories + teardown NEVER throw, NEVER block, NEVER corrupt a real tool result. Wrap in `failOpen` / try-catch returning void. BlockError must NOT be thrown from `after` (post-side-effect).
- **Native tools only for advisories** (output-mutation reaches the model only for native tools; MCP is a silent no-op). Gate on a NATIVE_TOOLS set.
- **Once-per-session dedup**: `Set<`${sessionID}:${kind}`>` held in the `Governance()` closure (mirrors CC `session_marker`). Fall back to `"unknown"` sessionID.
- **Offline**: pure string/regex over `args` + `process.env` for advisories (no fs/network). `git worktree prune` is local git; guard `command -v git` / catch ENOENT.
- **Verbatim fidelity**: advisory path sets + texts ported from CC `surface-constitution.sh`; prune command verbatim from CC `sweep_orphan_worktrees` (the prune line only).
- **Build-box PATH**: prefix `export PATH="/usr/bin:/bin:/c/Program Files/nodejs:/c/Program Files/Git/cmd:/c/Users/12132/AppData/Roaming/npm:$PATH"`. Keep bash cwd at repo root `/c/Users/12132/.claude` for code-file Edit/Write (enforce-rpi finds active Plan 4).
- Commit after every task; Co-Authored-By trailer.

## File Structure
```
opencode-harness/
├── plugin/
│   ├── lib/advisories.js     # NEW — advisoriesFor({tool,args,env}) + MANIFEST_RE/UI_RE + NATIVE_TOOLS
│   ├── lib/worktree.js       # NEW — pruneWorktrees(repo, exec) fail-open
│   └── governance.js         # MODIFY — wire tool.execute.after (advisories) + dispose/init (prune); destructure worktree
└── tests/
    ├── advisories.test.mjs   # NEW
    └── worktree.test.mjs     # NEW
```

---

### Task 1: `plugin/lib/advisories.js` (pure advisory selector)
**Files:** Create `plugin/lib/advisories.js`, `tests/advisories.test.mjs`.
**Interfaces:** `NATIVE_TOOLS` (Set: bash, edit, write, apply_patch, read), `MANIFEST_RE`, `UI_RE`, `advisoriesFor({tool, args, env}) → Array<{kind, text}>` (pure; kinds: `rpi-bypass`, `adr`, `ui`).

- [ ] **RED** tests:
  - RPI_SKIP set + tool `bash` → includes `{kind:"rpi-bypass"}`; RPI_SKIP unset → none.
  - filePath `package.json` / `go.mod` / `requirements.txt` / `pom.xml` → `{kind:"adr"}`; `src/x.tsx` / `app.css` → `{kind:"ui"}`; `notes.md` → none.
  - normalizePath applied (Windows `C:\\proj\\package.json` → adr).
  - rpi-bypass only for bash/edit/write (not read).
- [ ] **GREEN** implement. Reuse `normalizePath` from `code-exts.js`. Texts ported from `surface-constitution.sh` (§5 ADR / §8 ui-design) + a `surface_bypass`-style RPI warning.
- [ ] Commit.

### Task 2: `plugin/lib/worktree.js` (prune substitute, fail-open)
**Files:** Create `plugin/lib/worktree.js`, `tests/worktree.test.mjs`.
**Interfaces:** `pruneWorktrees(repo, exec) → {ran:boolean, pruned:boolean, reason}`. `exec(cmd, args)` injected (returns stdout string; throws on failure). Logic: if `!repo` → `{ran:false}`; `exec("git",["-C",repo,"rev-parse","--is-inside-work-tree"])` guard (catch → `{ran:false,reason:"not-a-repo"}`); then `exec("git",["-C",repo,"worktree","prune"])`. NEVER throws.

- [ ] **RED** tests (injected fake exec):
  - non-repo (rev-parse throws) → `{ran:false}`, no prune call.
  - repo → calls `git -C <repo> worktree prune`, returns `{ran:true,pruned:true}`.
  - exec throws on prune → caught, `{ran:true,pruned:false}` (fail-open, no throw).
  - empty repo arg → `{ran:false}`.
  - asserts NEVER `git worktree remove` / `branch -D` is called (safety: only `prune`).
- [ ] **GREEN** implement (try/catch, never throw).
- [ ] Commit.

### Task 3: wire into `governance.js`
**Files:** Modify `plugin/governance.js`; update `tests/plugin-shape.test.mjs`.
- [ ] Destructure `worktree` from PluginInput. Import `advisoriesFor` + `NATIVE_TOOLS` + `pruneWorktrees` + `node:child_process` (execFileSync wrapper).
- [ ] Init: after the version probe, `try { pruneWorktrees(worktree ?? directory, exec); } catch {}` (fail-open, never blocks load).
- [ ] Add `dispose: async () => { try { pruneWorktrees(worktree ?? directory, exec); } catch {} }`.
- [ ] Add `"tool.execute.after": failOpen(async (input, output) => {...})`: skip if `!NATIVE_TOOLS.has(tool)`; for each advisory in `advisoriesFor({tool, args: input.args, env: process.env})` whose `${sessionID}:${kind}` not in the closure Set → append `output.output = (output.output ?? "") + "\n\n[harness] " + text` + mark seen.
- [ ] Update `plugin-shape.test.mjs`: assert the returned hooks object now has `tool.execute.before`, `tool.execute.after`, `dispose` keys.
- [ ] Full suite green. Commit.

### Task 4: Live verification (opencode 1.17.11, build box)
**Files:** none (verification only).
- [ ] Deploy current bundle to `~/.config/opencode` (keep package.json; strip node_modules/lockfiles per spec §15). Redeploy plugin/.
- [ ] **A — advisory reaches model**: via capture-server, run a session that edits `package.json` (or sets RPI_SKIP + a bash call). Inspect the NEXT outbound request's tool-result message part → assert `[harness]` advisory text present. (Confirms after-output is a model channel on the pinned 1.17.11.) If not present, record as fail-open no-op + note SDK divergence.
- [ ] **B — dispose fires**: temporary log-on-dispose; run `opencode run ... "hi"`; confirm the dispose log line appears.
- [ ] **C — prune works**: create a throwaway repo + `git worktree add` a dir, `rm -rf` the dir (leave registration), confirm `pruneWorktrees` removes the registration (`git worktree list` no longer shows it) and NO branch is deleted.
- [ ] Record results (spec §16 verification record).

### Task 5: Closeout
- [ ] Adversarial review workflow (multi-agent red-team: fail-open completeness, dedup correctness, native-tool gate, prune safety = no branch/live-worktree touch, offline).
- [ ] review-strict drift + `bash setup/verify-setup.sh` PASS + full suite.
- [ ] spec §16 verification record; state cycle 44→45; plan Status→completed; memory update.
- [ ] PR + auto-merge (per migration authorization, verification PASS).

## Self-Review
- Spec coverage: §16.A advisories → T1/T3/T4-A; §16.B prune substitute → T2/T3/T4-B/C. R4 model-channel ADR recorded in spec §16. Honest scope-down (branch-D not ported) documented.
- No placeholders. Fail-open + native-only + dedup + offline are explicit invariants. Live E2E proves the model-channel on the pinned version (the spec §16 risk).
