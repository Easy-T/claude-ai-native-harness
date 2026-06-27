# opencode-harness — Migration Re-Verification Handoff

> **You (a fresh Claude session) are the independent re-verifier.** Your job is to decide, *adversarially
> and from scratch*, whether the port of the user's `~/.claude` Claude Code (CC) governance harness to
> **opencode** actually meets the original goal. **Do not trust the records below as proof** — they tell
> you *what was claimed* and *where to look*. Re-run the oracles yourself, re-derive the conclusions, and
> hunt for silent feature-drops, over-claims, and unverified assumptions. Report what you independently
> confirm, what you refute, and what remains unverifiable here (vs. only in the company env).
>
> Migration status at handoff: **Plans 1–5 + 3b COMPLETE & merged** (state cycle 47). Everything is
> build-box-GREEN and per-plan live-checked, but several things are **NOT live-verified** (see §5). Treat
> §5 (Open Gaps) as your primary target.

---

## 1. The Goal (what "success" means)

Port the CC global governance harness (`~/.claude`: RPI enforcement, constrained subagents,
secret/orchestrator gates, worktree teardown, verification/drift seals) to **opencode** with **maximal
fidelity**. Anything opencode cannot do *exactly* is replaced with the **best honest substitute and
explicitly recorded — NO silent feature drops**. The result must:
- ship as a **single offline zip** carried into a **network-restricted company env** (unzip to
  `~/.config/opencode/`, **zero runtime internet**),
- use **only company-internal LLM models** (no CCS proxy, no `[1m]`/tier-remap),
- have **every feature verified** (build-box differential oracle + in-target live opencode ≥1.17.11).

**Success criteria** (the bar you are judging against):
1. Plugin loads **offline** from `~/.config/opencode/plugin/*.js`, zero network (package.json present; no node_modules needed).
2. **L1**: global `AGENTS.md` (8 verbatim CC `§N` rules, ≤200 lines, exactly 8 `## §N.` markers) auto-appended to the agent system prompt.
3. **L2**: `tool.execute.before` throw-deny blocks plan-less write/edit/apply_patch/bash on **primary AND (≥1.17.10) subagent** paths.
4. **L3**: permission deny map (opencode.json + agent frontmatter) statically gates subagent tool calls.
5. RPI plan-gate invariants enforced; ≤5-line trivial exempt; spec-before-plan + plan-status parity with the bash oracle.
6. Secret scan denies on **added content only**; placeholders allowed.
7. Orchestrator skeleton gate blocks under-skeletoned delegation skills.
8. `explore/review/execute-strict` load with golden permission tables.
9. Worktree teardown: **prune-only**, branches/live-worktrees never touched.
10. Universal **fail-open**: only `BlockError` denies; all else swallow→allow; bypass surfaced.
11. `tool.execute.after` advisory reaches the **model** on native tools.
12. **21 skills** (14 superpowers + 7 custom) discovered via `<available_skills>`, offline.
13. Differential oracle: refactored libs vs CC source parsers `diff==0` on shared subset.
14. Model routing = company internal endpoint (CCS/`[1m]`/tiers dropped).
15. Build-box `verify-all` GREEN + `acceptance.sh` proves the zip is self-contained & offline-loadable.
16. `init-ai-ready` emits an opencode-native project scaffold (12 files; AGENTS.md + opencode.json deny-gate) with **honest 3-tier deny-gate disclosure**.
17. Pre-ship: oracle `diff==0` + **arg-key re-probe in company env** + zip carried in and re-verified in-target.

---

## 2. The CC harness (source of truth being ported) — `~/.claude/`

- `CLAUDE.md` — global constitution, ≤200 lines, **8 `## §N.` markers** (§1 Cache, §2 Orchestrator, §3 RPI, §4 Non-Obvious, §5 ADR, §6 Glossary, §7 Language, §8 UI) + coda.
- `settings.json` (gitignored) ↔ `settings.example.json` (tracked SSOT) — wires **11 hooks**.
- **Hooks** (`hooks/*.sh`, prologue `_common.sh` = SSOT helpers): blocking gates `enforce-rpi-cycle.sh` (Write|Edit|NotebookEdit), `enforce-rpi-bash.sh` (Bash side-door via `lib/redirect-targets.js`), `enforce-orchestrator.sh` (via `lib/skeleton-scan.js`), `enforce-secret-scan.sh`; advisory `stable-claude-md.sh`, `surface-constitution.sh` (additionalContext), `auto-compact-watch.sh`, `verify-loop-watch.sh` (Stop), `session-start-audit.sh` (SessionStart), `worktree-teardown.sh` (SessionEnd).
- **Verification stack** (`setup/`): `verify-all.sh` (top gate: STAGE0 RPI-prereq → doctor → verify-setup → seal-regression/failopen/rpi-prereq meta-tests → `hooks/tests/run-all.sh` **170 cases** → `verify-integration.sh` **8 E2E**), `verify-setup.sh` (**30 numbered SSOT drift guards**), `doctor.sh`.
- **3 wrapper agents** (`agents/*-strict.md`), **skills** (`start-rpi-cycle` = RPI engine, `closeout-pr-cycle`, `init-ai-ready-project`, `create-orchestrator-skill`, `common-agent-contract`, …), `state.json` (cycle ledger, schema-validated by #30).
- **RPI enforcement** = 3 layers: (1) hard gates (hooks, exit 2, require active plan + spec-before-plan), (2) orchestration (`start-rpi-cycle` R→P→I→Closeout), (3) self-surfacing report fields (`harness-verify`, `next-cycle-goal`, `phase-skills`). Hard guarantee = plan/spec existence on disk.

**Run the full CC suite** (Windows Git Bash: prefix `export PATH="/c/Program Files/Git/usr/bin:/c/Program Files/Git/cmd:/c/Program Files/nodejs:$PATH"` — the Claude Bash tool ships a Windows-style PATH that breaks coreutils/node until a clean POSIX PATH is prepended):
```
bash ~/.claude/setup/verify-all.sh          # expect: "ALL PASS — system meets §6.6 acceptance gate."
bash ~/.claude/setup/verify-setup.sh        # 30 guards; exit == FAIL count (expect 0)
```
(doctor may report 2 FAIL for `claude`/`jq` "not found" — that is the **Bash-tool PATH artifact**, both are installed; not a regression.)

---

## 3. The opencode bundle (the port) — `~/.claude/opencode-harness/` → deploys to `~/.config/opencode/`

**3-layer enforcement** (mirror of CC):
- **L1 (compass)**: `AGENTS.md` auto-loaded into the opencode system prompt (sentinel `HARNESS-CONSTITUTION-LOADED`, ≤200 lines, 8 `§N` rules). Reaches the model as instructions. Verified via the build-box `capture-server` (ground truth), **NOT** the CCS proxy (which rewrites the system prompt).
- **L2 (active gates)**: `plugin/governance.js` (pure-ESM v1 plugin) `tool.execute.before` runs **secret→rpi→orchestrator** gates; each `throw BlockError` to DENY; `lib/fail-open.js` ensures **only** BlockError denies (else swallow+log FAILOPEN). `tool.execute.after` appends advisories to native-tool output (reaches the model). Subagent (`task`) calls gated at opencode **≥1.17.10** (closes R1). Libs `redirect-targets.js`/`skeleton-scan.js`/`secret-scan.js` are **verbatim ports** of the CC parsers (differential-oracle-locked).
- **L3 (permission floor)**: global `opencode.json` baseline + per-subagent `agent/*-strict.md` frontmatter deny maps (explore=all writes deny; review=writes/task deny + bash `'* > *':deny`; execute=only writer, task deny). The `init-ai-ready`-emitted project `opencode.json` adds static `permission.bash` denies.

**Skills**: **21** SKILL.md (14 superpowers + 7 custom incl. `init-ai-ready-project`) → opencode `<available_skills>`. **Ship invariants**: `package.json` **MUST ship** (type:module; opencode HANGS at plugin load without it) but `node_modules`/lockfiles **MUST NOT** (regenerated; plugin is node:-builtins + relative only); `@opencode-ai/plugin` is a **types-only devDependency**; offline-safe (first-run "WARN background dependency install failed" is harmless); no `skills.urls`.

**Build-box-only** (`_oracle/`, zip-excluded): `verify-all.sh`, `acceptance.sh`, `_stage.sh`, `diff-parsers.mjs` (the C′ keystone — refactored libs vs CC source parsers, `diff==0`), `skill-discovery.mjs` (MIN_SKILLS=21), `init-emission.mjs`, and the **live** tools `capture-server.mjs` + `oc-capture.sh` (L1 ground-truth) + `oc-test.sh` (CCS proxy backend). Ship assets: `install.sh`, `PREREQUISITES.md`, `README.md`.

**Run the build-box suite** (offline, non-destructive — never mutates `~/.config/opencode`):
```
cd ~/.claude/opencode-harness
bash _oracle/verify-all.sh     # expect: verify-all: PASS=8 FAIL=0
bash _oracle/acceptance.sh     # expect: acceptance: PASS=34 FAIL=0   (needs zip OR PowerShell; node+unzip)
```

---

## 4. CC → opencode honest-substitute ledger (the heart — audit for silent drops / over-claims)

| Feature | opencode mechanism | Fidelity | Honest note (what you must confirm is recorded, not hidden) |
|---|---|---|---|
| **R1** subagent-content enforcement | same `tool.execute.before`, closed by **runtime ≥1.17.10** tool wrapper firing the hook on task-children (NOT V2 API; pin 1.17.11) | near-full | On 1.17.9 = **Absent/degraded** (L3 floor only). Lever is the runtime upgrade. |
| R1' subagent **identity** in hook input | `sessionID→agent` reverse-resolution; bash body scanned regardless of identity | near-full | `#15403` OPEN — identity not in payload. Blocking works without it. |
| **Worktree teardown** | `git worktree prune` **only** | substitute | Branch `-D` **deliberately not ported** (opencode worktrees use arbitrary branch names → no safe target). Recorded spec §16.B. |
| **Project deny-gate** (dynamic) | project `opencode.json` static `permission.bash` deny | substitute | **3-tier honesty**: (a) hard-block = bash-shape universal destroyers only; (b) advisory = SQL/prod/contextual git (NOT auto-enforced); (c) deny-patterns.md = full SSOT. glob is **best-effort speed-bump, NOT a sandbox** (flag-reorder/env-prefix bypass). An adversarial review caught an initial **over-claim** → fixed + oracle asserts the `best-effort`/`advisory` markers. |
| **merge-guard** (no self-approval) | procedural + `permission {'gh pr merge*':'ask'}` | substitute | Model still writes its own approval token. "Stronger than original" claim **removed**. GAP-C. |
| additionalContext / JIT mid-turn | `tool.execute.after` mutates the model-visible `output` (R4 **UPGRADE**) | near-full | Native tools only (MCP is a separate object). LIVE-confirmed (T4-A). |
| version detection | `version.js` **floor-fallback** to 1.17.11, logs `assumed`; authority moved to `opencode --version` at install | near-full | Runtime SDK `app.get()`=undefined, `config/path.get()`=HANG; only CLI is trustworthy. |
| offline plugin packaging | **package.json MUST ship** (Plan 1 "exclude" REVERSED) | full | Absent package.json → infinite HANG (spec §15 headline). |
| statusline | pull-based `/status` | substitute | No native shell statusline; rate-bar API offline-dead. |
| auto-compact | native `compaction.auto` (full) + `session.idle` early-warn (sub) | near-full | early-warn swallowed via event. |
| model routing | `opencode.json` provider/model = internal endpoint | substitute | CCS/`[1m]`/tiers/small_model **dropped**. context7 MCP = offline-absent (research aid, non-load-bearing). |
| secret once/session surface | client toast + log (user-only) | substitute | Model not notified; **blocking** itself is full at ≥1.17.10. |
| verify-loop/idle scanners | `session.idle` observer (swallowed) | substitute | idle≠end; advisory only (CC original also advisory). |
| drift seals | build-box bash stack as **differential oracle** + per-case `diff==0` | near-full | Exemption set declared (advisory/ts-only channels excluded from empty-diff). |
| native skills | vendored into bundle `skill/` | full | `disableClaudeCodeSkills` default-ON → bundled directly. Verbatim. |

---

## 5. ★ OPEN GAPS — what is NOT live-verified (your primary re-verification target)

These are honestly recorded in spec §13–18 as deferred / design-assumption. **Confirm each is real, decide if it is acceptable or ship-blocking, and close what you can locally:**

1. **Project-level read of project-root `AGENTS.md` + `opencode.json`** (the `init-ai-ready` 3b emission target) is a **DESIGN ASSUMPTION, not live-verified.** Grounded in opencode's documented config model + Plan 1 *global*-AGENTS.md proof, but the project-level read smoke was only *recommended*. **This is the single largest unverified assumption.** → Closeable locally (scaffold a temp project via the skill, run opencode pointed at it, capture whether the project AGENTS.md is injected + whether project `opencode.json` `permission.bash` actually blocks `rm -rf x`).
2. **Consolidated single-session E2E** (one human-style session: "add feature X" → active-plan blocks all code edits → `**Status:** active` unblocks → closeout). Live checks were **per-plan slices**, never one continuous run.
3. **Full live-from-zip run** (opencode actually loading the *unzipped* bundle). Spec §17 notes global `~/.config/opencode` union-load prevents clean isolation, so `acceptance.sh` proves **static** self-containment + offline-import only. The real "opencode loads the zip" E2E is deferred to a one-time manual run.
4. **E2E.I** — subagent issues a mutation → deny (the actual R1 ≥1.17.10 scenario) is **not** called out as a standalone live observation (covered by gate/script scenarios + primary-path live deny).
5. **Company-env arg-key RE-PROBE** (R2 CRITICAL) — only the personal-PC probe matched frozen `ARG_KEYS`. The plugin start self-test ALERTs fail-loud if keys differ (the mitigation), but company values are unconfirmed. NotebookEdit `new_source` un-probed (secret-gate not wired for notebooks; non-load-bearing).
6. **Linux/WSL oracle run** (R5) — listed as a pre-ship item, not recorded as executed. prune-only teardown removes the destructive path, lowering risk.
7. **1.17.9 degraded mode** — reasoned/designed, not live-tested (all live runs were 1.17.11). If company ships <1.17.10, subagent content-enforcement degrades to permission-floor-only.
8. **Company internal-model endpoint reachability** (R7) — external dependency; unverifiable outside the company env (PREREQUISITES.md surfaces it).
9. **context7 MCP offline** — accepted absent (research aid, governance-irrelevant).

---

## 6. How to re-verify (do these, in order)

**A. Build-box, offline (no model backend needed) — re-run everything and read the asserts, don't trust the numbers:**
```
# opencode bundle
cd ~/.claude/opencode-harness
node --test tests/*.test.mjs            # expect 85/85 (floor enforced by verify-all)
node _oracle/diff-parsers.mjs           # expect "OK diff==0" (verbatim-port proof)
node _oracle/skill-discovery.mjs        # expect "OK 21 skills ... 0 violations"
node _oracle/init-emission.mjs          # expect "OK init-emission (12 files ... 0 violations)"
bash  _oracle/verify-all.sh             # expect PASS=8 FAIL=0
bash  _oracle/acceptance.sh             # expect PASS=34 FAIL=0  (zip round-trip → offline plugin import)
# CC harness (the source being ported — confirm it still passes)
bash ~/.claude/setup/verify-all.sh      # expect "ALL PASS"
bash ~/.claude/setup/verify-setup.sh    # expect FAIL=0
```
Adversarially: open `_oracle/diff-parsers.mjs` and confirm it really diffs the refactored libs against the CC `hooks/lib/*` parsers (not a stub). Open `acceptance.sh` and confirm it builds a REAL archive and imports the plugin from the UNZIPPED tree offline. Confirm the canonical exclusion set is byte-identical in `install.sh` + `_oracle/_stage.sh` + `README.md` zip -x.

**B. Live, in-target (needs opencode ≥1.17.11 + a model backend):** the build-box live tools stage the bundle into a temp config dir so they never touch the global install.
```
cd ~/.claude/opencode-harness
node _oracle/capture-server.mjs /tmp/cap.jsonl 8319 &     # ground-truth outbound capture
bash _oracle/oc-capture.sh 8319 "say OK"                  # L1: is AGENTS.md (8 §N markers) in the system prompt?
bash _oracle/oc-test.sh "write a file foo.py without a plan"   # L2: is the plan-less write DENIED?  (CCS proxy backend, locally)
```
Headless `opencode run` waits on stdin → the scripts pass `</dev/null`. **L1 must use capture, NOT the proxy** (the proxy rewrites the system prompt to Claude Code's).

**C. Close the gaps you can (§5.1 is highest value):**
- §5.1 project-level read: use the `init-ai-ready-project` skill to scaffold a temp project, run opencode from inside it, capture (a) whether the project `AGENTS.md` is injected and (b) whether the project `opencode.json` `permission.bash` denies `rm -rf x`.
- §5.2 consolidated E2E: drive one continuous session through plan-gate → unblock → closeout and record it.
- §5.5 (company): the arg-key re-probe MUST be run in the company env on first install (the plugin ALERTs if keys differ).

---

## 7. The acceptance question (what you are reporting on)

Answer these, with independent evidence:
1. **Does it meet the goal?** (offline zip, internal models, maximal port, ALL features.)
2. **Are the substitutes HONEST?** Re-read §4 + spec §13–18. Is any feature **silently dropped** or **over-claimed** (the Plan 3b deny-gate over-claim was caught in review — are there others)?
3. **Is it genuinely offline-safe & company-ready?** (no runtime internet, no CCS, package.json ships, no node_modules/lockfiles, no skills.urls.)
4. **Which open gaps (§5) are acceptable vs ship-blocking?** Close what you can locally; flag what genuinely needs the company env.
5. Final verdict: **ship-ready / ship-with-caveats / blocked**, with the evidence behind it.

---

## 8. Pointers (read for detail / cross-check)

- **Design + per-plan verification records**: `docs/superpowers/specs/2026-06-26-opencode-harness-migration-design.md` — **§13** (Plan 1 foundations), **§14** (Plan 2 L2 gates), **§15** (Plan 3 skills + package.json ship-blocker), **§16** (Plan 4 advisories + worktree prune, R4 ADR), **§17** (Plan 5 verify/install/acceptance), **§18** (Plan 3b init-emission + deny-gate honesty). Earlier §1–§12 = the original design (invariants, migration matrix, risks R1–R9, port order, §8.2 oracle exemption set).
- **Plans**: `docs/superpowers/plans/2026-06-2*-opencode-harness-*` (Plan 1, 2, 3, 4, 5, 3b).
- **Memory** (gitignored, persists across sessions): `~/.claude/projects/C--Users-12132--claude/memory/project_opencode_harness_migration.md` — the dense per-plan record + reuse-lessons.
- This bundle's own `README.md` (ship/local-testing/verify/accept) + `PREREQUISITES.md` (opencode ≥1.17.11 rationale, internal-model setup, offline guarantees).

> **Bias**: be the skeptic, not the cheerleader. The migration is *claimed* complete; your value is finding
> where the claim and the reality diverge. A clean "I re-ran everything and it holds, gaps §5.1/5.2 remain"
> is a valid result — but only if you actually re-ran it.
