# opencode Harness — Plan 3b: init-ai-ready opencode-emission (native bundle skill)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:verification-before-completion. Steps use checkbox (`- [ ]`).

**Status:** completed
**RPI-Cycle:** 47 (opencode-harness migration — plan 3b, the final deferred item)
**Started:** 2026-06-27
**Completed:** 2026-06-27 — units 85/85, init-emission 0 viol, skill-discovery 21/21, verify-all 8/0, acceptance 34/0, verify-setup 66/0. Adversarial 3-lens review FAIL (deny-gate honesty/coverage) → fixed (honest 3-layer disclosure + hardened deny set + oracle disclosure-marker seal). Migration FULLY COMPLETE (Plans 1-5 + 3b). See spec §18.

**Goal:** Give the opencode bundle a NATIVE `skill/init-ai-ready-project/` that scaffolds an **opencode-target** project — the opencode analog of the CC `~/.claude/skills/init-ai-ready-project`. The company runs opencode, so this bootstraps opencode projects (AGENTS.md compass + a per-project `opencode.json` permission deny-gate + the model-agnostic ai-context docs). Decision (user, 2026-06-27): **bundle-native skill** (NOT a dual-target rewrite of the CC skill; CC skill stays CC-only).

**Architecture / mapping (CC → opencode-target):**
| CC artifact | opencode-target analog |
|---|---|
| `CLAUDE.md` (project compass) | **`AGENTS.md`** (opencode reads project-root AGENTS.md, merged into the system prompt — proven in Plan 1 for the global one) |
| `.claude/settings.json` (`permissions.deny` + PreToolUse hook) | **`opencode.json`** at project root with `permission.bash` **deny** map (native L3 — stronger than a parse-hook) |
| `.claude/hooks/pre-commit-deny.sh` (parses deny-patterns.md, exit 2) | **DROPPED** — replaced by static `permission.bash` deny. Honest substitute: dynamic per-project custom denies must be added to BOTH `deny-patterns.md` (doc) AND `opencode.json` `permission.bash` (enforcement). The GLOBAL harness plugin already enforces RPI/secret/orchestrator gates for every project, so the project gate's only job is project-specific dangerous-command denial. Recorded, not silently dropped. |
| `.claude/state.json` | `state.json` at project root (RPI cycle state; read by harness, not opencode) |
| `docs/ai-context/*`, `.gitignore`, `scripts/check.sh`, `.github/workflows/ci.yml`, `CONTEXT.md` | reused ~verbatim (model-agnostic; CONTEXT/AGENTS pointers adjusted CLAUDE→AGENTS) |

**Emitted file set (12 files):** `AGENTS.md` · `docs/ai-context/{architecture,runbook,deny-patterns,non-obvious,domain-glossary}.md` · `opencode.json` · `.gitignore` · `state.json` · `scripts/check.sh` · `.github/workflows/ci.yml` · `CONTEXT.md`. Dirs: `docs/ai-context/`, `docs/superpowers/{specs,plans}/` (.gitkeep), `scripts/`, `.github/workflows/`. (CC had 13; we drop the hook file and fold deny into opencode.json.)

## Global Constraints
- **Offline + non-destructive**: the skill + templates ship in the zip (under `skill/init-ai-ready-project/`); the verification oracle is build-box-only (`_oracle/`). No network. Rendering an opencode project does not touch `~/.config/opencode`.
- **Skill must be discoverable**: adding this skill makes the bundle **21** SKILL.md (was 20 = 14 superpowers + 6 custom). Bump every skill-count SSOT: `skill-discovery.mjs` MIN_SKILLS 20→21, `verify-all.sh`/`acceptance.sh`/`install.sh`-sandbox skill-count, README/spec/memory. (CC lesson: counts are scattered — find them all.)
- **No install-trigger leak**: templates are inert `.tpl`/`.gitkeep`; no `package.json`/lockfile under the new skill dir (skill-discovery flags those).
- **Honest substitute recorded**: the dropped dynamic deny-hook → documented in AGENTS.md.tpl + deny-patterns.md.tpl + spec §18.
- Branch `opencode-harness-plan-3b` (created). Commit per task; Co-Authored-By trailer. Build-box PATH: `export PATH="/c/Program Files/Git/cmd:/c/Program Files/Git/usr/bin:/c/Program Files/nodejs:$PATH"`; keep bash cwd at repo root for code-file Edit/Write.

## Tasks

### Task 1: opencode-target template set
- [x] Create `opencode-harness/skill/init-ai-ready-project/templates/`:
  - `AGENTS.md.tpl` (from CLAUDE.md.tpl: project compass; `{{PROJECT_NAME}}`/`{{CREATED_AT}}`/`{{STACK_DESCRIPTION}}`/`{{MODULES_INDEX}}`; pointers to docs/ai-context/*; a one-line note that this is the project AGENTS.md merged with the global harness constitution).
  - `project-opencode.json.tpl` → emits project `opencode.json`: `{"$schema":"https://opencode.ai/config.json","permission":{"edit":"allow","bash":{"*":"allow","rm -rf *":"deny","git push --force*":"deny","git push -f*":"deny","npm publish*":"deny"},"webfetch":"allow"}}` + a `{{STACK_ALLOW_LIST}}`-driven section if needed (keep minimal/valid JSON).
  - `deny-patterns.md.tpl` (reuse; ≥8 `- ❌ ` markers; add a header note: custom denies must also be added to `opencode.json` `permission.bash`).
  - `architecture.md.tpl`, `runbook.md.tpl` (keep 'Local Quality Gate' + 'Merge Policy'), `non-obvious.md.tpl` (keep '아직 비어 있음'), `domain-glossary.md.tpl`, `CONTEXT.md.tpl` (CLAUDE→AGENTS refs), `.gitignore.tpl`, `state.json.tpl` (schema_version=1, cycle.count=0), `scripts-check.sh.tpl`, `github-ci.yml.tpl` — reused from CC with the swaps above.
- [x] `references/placeholder-spec.md` + `references/stack-presets.md` (copy/adapt from CC; opencode allow-list note).
- [x] No `package.json`/lockfile anywhere under the skill dir.

### Task 2: SKILL.md (opencode-native, discoverable)
- [x] `opencode-harness/skill/init-ai-ready-project/SKILL.md` with frontmatter `name: init-ai-ready-project` + a `description:` (required — silent-drop otherwise). 4 phases adapted to opencode: Phase 0 self-audit checks **global `~/.config/opencode/AGENTS.md` §-markers + `opencode --version` ≥ floor** (not doctor.sh); Phase 1 discover (explore-strict, stack detect); Phase 2 generate the **12** files from templates; Phase 3 verify (opencode-target asserts); Phase 4 closing. Folder name == `init-ai-ready-project` (discovery rule). description in lowercase-alnum-hyphen NAME rule is for `name` only.

### Task 3: build-box template oracle (TDD)
- [x] `opencode-harness/_oracle/init-emission.mjs` (build-box only): render every `.tpl` with sample placeholder values into a temp dir, then assert the opencode-target project is valid:
  - `AGENTS.md` present, ≤200 lines, pointers to docs/ai-context/*.
  - `opencode.json` parses as JSON, has `permission.bash` with `rm -rf *`/`git push --force*`/`npm publish*` → `deny`, `$schema` set.
  - `deny-patterns.md` ≥8 `- ❌ ` markers.
  - `state.json` parses, schema_version=1, cycle.count=0.
  - no placeholder leakage (`{{...}}`) after render.
  - `runbook.md` has 'Local Quality Gate' + 'Merge Policy'; `non-obvious.md` has the empty-marker text.
  - the 12-file set + dirs all rendered.
  - print `OK init-emission` / exit nonzero on any fail.
- [x] Write the RED first (oracle before templates complete where practical), then make GREEN.

### Task 4: wire counts + verify-all + acceptance + scaffold test
- [x] `skill-discovery.mjs`: `MIN_SKILLS` 20 → 21.
- [x] `verify-all.sh`: add an init-emission oracle step; bump any `>=20` skill assertion to 21.
- [x] `acceptance.sh`: skill-count assertion 20 → 21; assert `skill/init-ai-ready-project/SKILL.md` + a couple templates ship.
- [x] `install.sh`: skill-count echo is dynamic (no hardcode) — confirm; sandbox expects 21.
- [x] `scaffold.test.mjs`: assert the new skill dir + SKILL.md + templates exist.
- [x] Run full: `node --test tests/*.test.mjs`, `verify-all.sh`, `acceptance.sh` — all GREEN.

### Task 5: docs + closeout
- [x] README: note the init skill (21 skills; bootstraps opencode-target projects).
- [x] spec **§18**: Plan 3b design + the honest deny-gate substitute + verification record.
- [x] Adversarial review (template-injection / placeholder-leak / deny-gate-bypass / count-drift / discovery).
- [x] `setup/verify-setup.sh` PASS (66/0) + full suite; review-strict drift.
- [x] state cycle 46→47; plan Status→completed; memory update (migration FULLY COMPLETE incl. 3b).
- [x] PR from `opencode-harness-plan-3b` + auto-merge.

## Self-Review
- Project deny-gate is static `permission.bash` deny (L3) — confirm it is honestly weaker on dynamic per-project denies than the CC parse-hook, and that this is recorded (not silently dropped).
- Confirm opencode reads PROJECT-root `AGENTS.md` + `opencode.json` (design assumption from opencode's documented config model + Plan 1 global-AGENTS.md proof). If a live opencode is available, smoke-test project-level read; else record as design-grounded.
- All skill-count SSOTs bumped 20→21 (no masking).
