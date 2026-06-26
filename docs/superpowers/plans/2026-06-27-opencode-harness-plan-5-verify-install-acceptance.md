# opencode Harness — Plan 5: verification harness + install + PREREQUISITES + zip acceptance (capstone)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:verification-before-completion. Steps use checkbox (`- [ ]`).

**Status:** active
**RPI-Cycle:** 46 (opencode-harness migration — plan 5 of 5)
**Started:** 2026-06-27

**Goal:** Package the harness for company carry-in (spec §17): a single build-box verification entrypoint, a target install helper, a PREREQUISITES doc, and a zip acceptance test that proves the shipped zip is self-contained + offline-loadable. Success = `verify-all.sh` green (all units + oracles + clean-stage gate), `acceptance.sh` green (zip → unzip → static self-containment + offline node-import of the plugin + ≥20 skills discoverable), a final live opencode-from-clean-deploy E2E recorded, no regression.

**Architecture (spec §17):** mirror CC `setup/{verify-all,install}.sh`. Build-box-only tooling lives in `_oracle/` (zip-excluded); `install.sh` + `PREREQUISITES.md` ship. The package.json-ships / node_modules-don't invariant (spec §15) and the offline + global-union-load caveats (spec §13) are encoded in install + acceptance.

## Global Constraints
- **Offline + non-destructive**: verify-all + acceptance must not need network and must not mutate the global `~/.config/opencode` (static + node-import only). install.sh backs up before deploying.
- **package.json ships; node_modules/lockfiles/_oracle/tests do NOT** (spec §15) — install + acceptance + _stage all enforce this.
- **Build-box PATH**: prefix `export PATH="/usr/bin:/bin:/c/Program Files/nodejs:/c/Program Files/Git/cmd:/c/Users/12132/AppData/Roaming/npm:$PATH"`. Keep bash cwd at repo root for code-file Edit/Write.
- Branch `opencode-harness-plan-5` (created). Commit per task; Co-Authored-By trailer.

## File Structure
```
opencode-harness/
├── install.sh            # NEW (SHIPS) — target deploy + prereq check (mirror CC install.sh)
├── PREREQUISITES.md      # NEW (SHIPS) — opencode >=1.17.11, bun, git, internal model, offline notes
├── README.md             # MODIFY — Install + Prerequisites + acceptance sections + file tree
├── _oracle/
│   ├── verify-all.sh     # NEW (build-box) — single verification entrypoint, PASS/FAIL summary
│   └── acceptance.sh     # NEW (build-box) — zip → unzip → static + offline-import acceptance
└── tests/scaffold.test.mjs  # MODIFY — assert install.sh + PREREQUISITES.md ship; verify-all/acceptance exist
```

---

### Task 1: `_oracle/verify-all.sh` (build-box verification entrypoint)
**Files:** Create `opencode-harness/_oracle/verify-all.sh`.
- [ ] PASS/FAIL counter harness (CC style: `ok`/`fail`). Runs from the bundle root.
- [ ] ① `node --test tests/*.test.mjs` (all units pass). ② `node _oracle/diff-parsers.mjs` (OK diff==0). ③ `node _oracle/skill-discovery.mjs` (≥20, 0 violations).
- [ ] ④ clean-stage gate: source `_stage.sh`, `stage_bundle`, assert in the stage: `package.json` exists + `"type":"module"`; NO `node_modules`/`package-lock.json`/`bun.lock*`; `opencode.json` has no `skills.urls`; skill-discovery passes against the staged `skill/`; `node -e import('<stage>/plugin/governance.js')` loads offline. rm the stage.
- [ ] Guard: git + node on PATH (fail clearly if absent). Final line `verify-all: PASS=<n> FAIL=<m>`; exit 1 if any FAIL.
- [ ] Run it → all PASS. Commit.

### Task 2: `install.sh` + `PREREQUISITES.md` (ship)
**Files:** Create `opencode-harness/install.sh`, `opencode-harness/PREREQUISITES.md`.
- [ ] `install.sh` (mirror CC): (1) tool check `opencode --version` ≥ 1.17.11 (authority gate, R2) + `git`; (2) backup existing `~/.config/opencode` → `.pre-harness-<date>`; (3) copy bundle → `~/.config/opencode` keeping `package.json`, stripping `node_modules`/lockfiles/`_oracle`/`tests`/`.git`; (4) print next steps (set internal model provider in opencode.json, restart, run verify-all). Idempotent; offline-safe; never deletes without backup.
- [ ] `PREREQUISITES.md`: opencode ≥1.17.11 (why: R1 central tool wrapper; 1.17.9 degraded) · opencode's bundled bun runtime · git · internal LLM provider config in opencode.json (no CCS) · NO runtime internet (skills/plugin/AGENTS.md all local; first-run background dep-install WARN is harmless/fail-open) · global config union-load caveat.
- [ ] `bash -n install.sh` clean. Commit.

### Task 3: `_oracle/acceptance.sh` (zip acceptance)
**Files:** Create `opencode-harness/_oracle/acceptance.sh`.
- [ ] Build the zip via the README ship command into a temp; unzip to a fresh temp dir.
- [ ] STATIC assertions on the unzipped tree (PASS/FAIL): `package.json` present + `type:module` + no runtime `@opencode-ai/plugin` dependency; NO `node_modules`/`package-lock.json`/`bun.lock*`/`_oracle/`/`tests/`/`.git`; `AGENTS.md`, `opencode.json` (no `skills.urls`, has `permission.skill`), 3 `agent/*-strict.md`, `plugin/governance.js` + `plugin/lib/*` + `plugin/gates/*`, `install.sh`, `PREREQUISITES.md` present.
- [ ] OFFLINE node-import smoke: `node -e import('<unzip>/plugin/governance.js').then(m=>m.Governance({client:{},directory:'.'}))` loads + init resolves (prints `[harness] loaded`), no network.
- [ ] skill-discovery against the unzipped `skill/`: ≥20, 0 violations.
- [ ] Final `acceptance: PASS=<n> FAIL=<m>`; exit 1 on FAIL. Requires `zip`/`unzip` (guard). Run → PASS. Commit.

### Task 4: README + scaffold test
**Files:** Modify `opencode-harness/README.md`, `opencode-harness/tests/scaffold.test.mjs`.
- [ ] README: add **Prerequisites** (point to PREREQUISITES.md) + **Install** (`bash install.sh` flow) + **Acceptance** (`bash _oracle/acceptance.sh`) + **Verify** (`bash _oracle/verify-all.sh`); refresh the file tree.
- [ ] scaffold.test: assert `install.sh` + `PREREQUISITES.md` exist at bundle root; `_oracle/verify-all.sh` + `_oracle/acceptance.sh` exist. Full suite green. Commit.

### Task 5: Final verification + closeout
- [ ] `bash _oracle/verify-all.sh` → PASS. `bash _oracle/acceptance.sh` → PASS.
- [ ] **Final live E2E (record, manual)**: clean-deploy the bundle to `~/.config/opencode` (backup), run opencode OFFLINE-ish via capture/CCS asserting: `[harness] loaded`, ≥20 skills in `<available_skills>`, a malformed orchestrator SKILL.md write is denied, an advisory appears — the consolidated proof of the whole migration. Restore.
- [ ] Adversarial review workflow (install safety = backup-before-destroy + no data loss; acceptance completeness; offline; verify-all false-green resistance).
- [ ] review-strict drift + `bash setup/verify-setup.sh` PASS + full suite.
- [ ] spec §17 verification record; state cycle 45→46; plan Status→completed; memory update (migration COMPLETE, Plans 1-5 done; 3b remains).
- [ ] PR (from `opencode-harness-plan-5`) + auto-merge.

## Self-Review
- Spec coverage: §17 verify-all → T1; install + PREREQUISITES → T2; acceptance → T3; README/scaffold → T4; live E2E + closeout → T5. init-ai-ready stays Plan 3b (out of scope).
- Non-destructive: verify-all/acceptance never mutate the global; install backs up first. Offline throughout. The acceptance proves self-containment from the actual zip.
