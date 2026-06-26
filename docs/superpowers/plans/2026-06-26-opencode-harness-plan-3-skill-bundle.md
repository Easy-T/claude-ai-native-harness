# opencode Harness — Plan 3: Skill Bundle (superpowers vendoring + custom skill ports) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active
**RPI-Cycle:** 44 (opencode-harness migration — plan 3 of 5)
**Started:** 2026-06-26

**Goal:** Make the harness's RPI methodology available to the opencode model on-demand by vendoring the pinned superpowers v6.0.3 skill set and porting the 6 invocable custom skills into opencode's **native** `skills/<name>/SKILL.md` mechanism — fully offline, discoverable with zero network.

**Architecture:** Plan-3 research (workflow `wf_64f88e51`) established that **opencode v1.17.11 has native Agent Skills** (`src/skill/{index,discovery}.ts`): it scans `~/.config/opencode/{skill,skills}/**/SKILL.md`, surfaces each skill's `name`+`description` lazily via the `skill` tool, and injects the SKILL.md body on demand. This **overturns the Plan-1 assumption that "skills aren't a thing"** — no AGENTS.md-prose or command substitute is needed. Skills therefore drop into `skill/<name>/SKILL.md` and "just work". The only network surface in skill discovery is the opt-in `skills.urls` config key + URL entries in `instructions[]` — both omitted from the offline bundle.

**Tech Stack:** opencode v1.17.11 native skills (SKILL.md, `skill` tool, `permission.skill`) · superpowers v6.0.3 (vendored, pinned) · the 3 wrapper subagents already ported in Plan 1 (`agent/{explore,review,execute}-strict.md`) · the orchestrator-gate from Plan 2 (`plugin/gates/orchestrator-gate.js`).

## Global Constraints

- **Native SKILL.md, offline.** Skills live at `opencode-harness/skill/<name>/SKILL.md` (zip → `~/.config/opencode/skill/...`). opencode scans BOTH `skill/` (singular) and `skills/` (plural); use `skill/` to match spec §5.
- **Frontmatter minimum = `name` + `description`.** The folder name MUST equal `name` (lowercase alphanumeric + single hyphens, 1–64 chars). **A skill with no `description` is silently dropped** from the surfaced list — every ported SKILL.md needs one.
- **No network at load.** Never add `skills.urls` to opencode.json; keep `instructions[]` entries to LOCAL paths/globs only. Do NOT ship any `package.json`/`package-lock.json`/`bun.lock*` inside the skill tree (opencode auto-installs a config-dir package.json → network).
- **Do NOT edit vendored superpowers skill BODIES.** Upstream rule (94% PR-rejection for tool-name edits); they "speak in actions, not tools" and are portable as-is. Tool-name mapping belongs in a separate `references/opencode-tools.md`, never in the skill bodies. Vendor verbatim, pinned to 6.0.3.
- **Custom-skill dispatch retargeting (the port).** The 6 custom skills were authored for Claude Code. Apply the token map (defined in Task 4) to translate CC dispatch into opencode mechanisms: `Agent(subagent_type="X", ...)` → "dispatch the `X` subagent via the task tool"; "use the Y skill (Skill tool)" → "invoke the `Y` skill (skill tool)"; hook references → the plugin gates. Preserve the orchestrator skeleton (the `orchestrator_skill: true` marker + ≥3 `# Phase` + ≥1 `Agent(subagent_type=` literal + `Communication Protocol`) so `orchestrator-gate.js` still recognizes them.
- **common-agent-contract is NOT a standalone skill** in opencode — it is already inlined into `agent/*.md`. Do not port it as a skill.
- **init-ai-ready-project opencode-emission is OUT OF SCOPE here** (deferred to Plan 3b — it is a separate template set + project deny-gate + dual-target skill, large enough to warrant its own plan). This plan ports the other 6 invocable skills.
- Commit after every task. Conventional-commit messages. End commit bodies with the Co-Authored-By trailer.
- **Build-box PATH note:** this PC's Bash tool PATH is broken; prefix `export PATH="/usr/bin:/bin:/c/Program Files/nodejs:/c/Program Files/Git/cmd:/c/Program Files/GitHub CLI:$PATH"` for git/node/gh.

## File Structure

```
opencode-harness/
├── skill/
│   ├── superpowers/                 # NEW — pinned vendored v6.0.3 (14 skills, bodies verbatim)
│   │   ├── using-superpowers/SKILL.md (+references/)
│   │   ├── brainstorming/SKILL.md  ·  writing-plans/SKILL.md  ·  executing-plans/SKILL.md
│   │   ├── subagent-driven-development/ · systematic-debugging/ · test-driven-development/
│   │   ├── using-git-worktrees/ · verification-before-completion/ · dispatching-parallel-agents/
│   │   ├── requesting-code-review/ · receiving-code-review/ · finishing-a-development-branch/
│   │   ├── writing-skills/
│   │   └── references/opencode-tools.md   # NEW — the missing opencode tool mapping
│   ├── start-rpi-cycle/SKILL.md     # NEW — ported (orchestrator)
│   ├── closeout-pr-cycle/SKILL.md   # NEW — ported (orchestrator)
│   ├── grill-with-docs/SKILL.md (+CONTEXT-FORMAT.md +ADR-FORMAT.md)  # NEW — ported (non-orch)
│   ├── create-orchestrator-skill/SKILL.md  # NEW — ported (orchestrator)
│   ├── improve-codebase-architecture/SKILL.md  # NEW — ported (orchestrator)
│   └── ui-design/SKILL.md (+design.md)  # NEW — ported (orchestrator)
├── opencode.json                    # MODIFY — add permission.skill; confirm no skills.urls
└── _oracle/
    └── skill-discovery.mjs          # NEW — offline discovery + frontmatter validator (build-box)
```

**Source paths (read-only references):**
- superpowers: `C:/Users/12132/.claude/plugins/cache/claude-plugins-official/superpowers/6.0.3/skills/`
- custom skills: `C:/Users/12132/.claude/skills/<name>/SKILL.md` (+ siblings)
- ported wrapper agents (dispatch targets): `opencode-harness/agent/{explore,review,execute}-strict.md`

---

### Task 1: Vendor superpowers v6.0.3 (verbatim, pinned)

**Files:**
- Create: `opencode-harness/skill/superpowers/**` (copied from the 6.0.3 cache)
- Create: `opencode-harness/skill/superpowers/VERSION` (pin record)

**Interfaces:**
- Produces: 14 discoverable superpowers skills under `skill/superpowers/`. Consumed by the model's `skill` tool + the custom orchestrators that reference `superpowers:<name>`.

- [ ] **Step 1: Copy the skills tree verbatim (exclude non-skill payload that triggers install)**

```bash
export PATH="/usr/bin:/bin:/c/Program Files/Git/cmd:$PATH"
SRC="/c/Users/12132/.claude/plugins/cache/claude-plugins-official/superpowers/6.0.3/skills"
DST="/c/Users/12132/.claude/opencode-harness/skill/superpowers"
mkdir -p "$DST"
cp -r "$SRC"/. "$DST"/
# remove anything that would trigger opencode's config-dir package.json auto-install or is non-skill
find "$DST" -name package.json -o -name package-lock.json -o -name 'bun.lock*' -o -name node_modules -prune | xargs -r rm -rf
printf 'superpowers vendored pin: 6.0.3\nsource: github.com/obra/superpowers @ v6.0.3\n' > "$DST/VERSION"
```

- [ ] **Step 2: Verify 14 skills present + every SKILL.md has name+description**

Run: `node opencode-harness/_oracle/skill-discovery.mjs` (created in Task 3) — but for an immediate check:
```bash
export PATH="/usr/bin:/bin:/c/Program Files/nodejs:$PATH"
ls opencode-harness/skill/superpowers/*/SKILL.md | wc -l   # expect >= 14
```
Expected: ≥14 SKILL.md files; no `package.json` anywhere under `skill/superpowers/`.

- [ ] **Step 3: Add `references/opencode-tools.md`** (the mapping upstream only inlines)

```markdown
# opencode tool mapping (for superpowers skills)

Skills speak in actions; here is how each action maps to opencode:

| Action (skill prose) | opencode mechanism |
|---|---|
| "invoke / use the `X` skill" | the `skill` tool: `skill({ name: "X" })` |
| "dispatch a subagent" / `Agent(subagent_type="X")` | the `task` tool targeting subagent `X` (e.g. `@X`); subagents are `agent/*.md` with `mode: subagent` |
| "create a todo list" / `TodoWrite` | `todowrite` |
| "read / search / edit / write a file" | `read` / `grep`+`glob` / `edit` / `write` |
| instruction files | `AGENTS.md` (auto-loaded) + `instructions[]` (local paths) in `opencode.json` |

Constraints: the harness denies the `task` tool *inside* subagents (1-level limit). cwd is not persistent across dispatched bash. No network at load.
```

- [ ] **Step 4: Commit**

```bash
git add opencode-harness/skill/superpowers
git commit -m "feat(opencode-harness): vendor superpowers v6.0.3 skills (plan 3 T1)"
```

---

### Task 2: opencode.json skill config (permission + no-network)

**Files:**
- Modify: `opencode-harness/opencode.json`
- Test: `opencode-harness/tests/opencode-json-skill.test.mjs`

**Interfaces:**
- Produces: `permission.skill` map enabling skill use; the existing `instructions`/`permission`/`compaction` keys unchanged; asserts NO `skills.urls`.

- [ ] **Step 1: Write the failing test**

```js
// opencode-harness/tests/opencode-json-skill.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

test("opencode.json enables skills and declares no network skill source", () => {
  const cfg = JSON.parse(readFileSync(join(ROOT, "opencode.json"), "utf8"));
  assert.ok(cfg.permission && cfg.permission.skill, "permission.skill map required");
  assert.equal(cfg.permission.skill["*"], "allow");
  assert.ok(!("skills" in cfg) || !cfg.skills.urls, "must NOT declare network skills.urls");
  // instructions stay local (no http) — defensive
  for (const i of (cfg.instructions || [])) assert.ok(!/^https?:/.test(i), `instructions must be local: ${i}`);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/opencode-json-skill.test.mjs`
Expected: FAIL (no permission.skill yet).

- [ ] **Step 3: Edit `opencode.json`** — add the `skill` permission entry:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [],
  "permission": {
    "edit": "allow",
    "bash": { "*": "allow", "rm -rf *": "ask", "git push *": "ask" },
    "webfetch": "allow",
    "skill": { "*": "allow" }
  },
  "compaction": { "auto": true }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/opencode-json-skill.test.mjs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/opencode.json opencode-harness/tests/opencode-json-skill.test.mjs
git commit -m "feat(opencode-harness): enable native skills in opencode.json, no network (plan 3 T2)"
```

---

### Task 3: Offline skill-discovery validator (build-box oracle)

**Files:**
- Create: `opencode-harness/_oracle/skill-discovery.mjs`

**Interfaces:**
- Consumes: the `skill/` tree. Produces: a pass/fail report — every `SKILL.md` has `name`+`description`, folder name == `name`, name charset valid, no duplicate names, no `package.json` in the tree, no `http(s)://` in any frontmatter. Exit 1 on any violation.

- [ ] **Step 1: Write the validator**

```js
// opencode-harness/_oracle/skill-discovery.mjs
// BUILD-BOX ONLY. Mirrors opencode's skill discovery rules (src/skill/index.ts) so we catch
// a non-discoverable skill (missing description, name/folder mismatch, bad charset) before ship.
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, basename } from "node:path";

const ROOT = join(import.meta.dirname, "..", "skill");
const NAME_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/; // lowercase alnum + single hyphens
let fails = 0, count = 0;
const names = new Map();
const fail = (m) => { fails++; console.error("FAIL " + m); };

function walk(dir) {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    const st = statSync(p);
    if (st.isDirectory()) { walk(p); continue; }
    if (e === "package.json" || e === "package-lock.json" || e.startsWith("bun.lock")) fail(`shippable install trigger: ${p}`);
    if (e !== "SKILL.md") continue;
    count++;
    const body = readFileSync(p, "utf8");
    const fm = body.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    if (!fm) { fail(`no frontmatter: ${p}`); continue; }
    const name = (fm[1].match(/^name:\s*(.+)$/m) || [])[1]?.trim();
    const desc = (fm[1].match(/^description:\s*(.+)$/m) || [])[1]?.trim();
    if (!name) fail(`no name: ${p}`);
    if (!desc) fail(`no description (skill is silently dropped): ${p}`);
    if (name && !NAME_RE.test(name)) fail(`bad name charset '${name}': ${p}`);
    if (name && basename(dir) !== name) fail(`folder!=name ('${basename(dir)}' vs '${name}'): ${p}`);
    if (/https?:\/\//.test(fm[1])) fail(`http(s) in frontmatter (network): ${p}`);
    if (name) { if (names.has(name)) fail(`duplicate name '${name}'`); names.set(name, p); }
  }
}

if (!existsSync(ROOT)) { console.error("no skill/ dir"); process.exit(1); }
walk(ROOT);
console.log(fails === 0 ? `OK ${count} skills discoverable, 0 violations` : `FAIL ${fails} violation(s) across ${count} skills`);
process.exit(fails === 0 ? 0 : 1);
```

- [ ] **Step 2: Run it (after Task 1 vendoring)**

Run: `cd opencode-harness && node _oracle/skill-discovery.mjs`
Expected: `OK <N> skills discoverable, 0 violations` (N≥14 from superpowers). Fix any flagged skill (e.g. a vendored skill whose folder name differs from `name`, or a missing description).

- [ ] **Step 3: Commit**

```bash
git add opencode-harness/_oracle/skill-discovery.mjs
git commit -m "test(opencode-harness): offline skill-discovery validator (plan 3 T3)"
```

---

### Task 4: Port the 6 custom skills to native SKILL.md

**Files:**
- Create: `opencode-harness/skill/start-rpi-cycle/SKILL.md`
- Create: `opencode-harness/skill/closeout-pr-cycle/SKILL.md`
- Create: `opencode-harness/skill/grill-with-docs/SKILL.md` (+ `CONTEXT-FORMAT.md`, `ADR-FORMAT.md`)
- Create: `opencode-harness/skill/create-orchestrator-skill/SKILL.md`
- Create: `opencode-harness/skill/improve-codebase-architecture/SKILL.md`
- Create: `opencode-harness/skill/ui-design/SKILL.md` (+ `design.md`)

**Interfaces:**
- Consumes: the source `~/.claude/skills/<name>/` + the dispatch targets `agent/{explore,review,execute}-strict.md`. Produces: 6 discoverable opencode skills whose dispatch instructions reference opencode mechanisms, with orchestrator skeletons preserved for `orchestrator-gate.js`.

**Transformation map (apply to every ported body; the SOURCE body otherwise copied verbatim):**

| Source (Claude Code) | opencode replacement |
|---|---|
| `Agent(subagent_type="explore-strict", task=T, context_paths=P, success_criteria=S)` | "Dispatch the **explore-strict** subagent via the `task` tool — task: T; read: P; success: S." (KEEP one literal `Agent(subagent_type=` token in an example so the orchestrator skeleton still counts ≥1; see note.) |
| same for `review-strict` / `execute-strict` | task-tool dispatch to that subagent |
| "use the `X` skill" / "Skill tool" / `superpowers:X` | "invoke the `X` skill (the `skill` tool)" |
| `~/.claude/state.json` | `state.json` (harness-relative; ships at bundle root) |
| `enforce-rpi-cycle` / `enforce-orchestrator` / hook references | "the governance plugin's RPI / orchestrator gate (`plugin/gates/*.js`)" |
| `~/.claude/CLAUDE.md` | `AGENTS.md` |
| `ExitWorktree` / `EnterWorktree` tool (closeout Phase 6) | `git worktree remove` / the worktree-teardown logic (Plan 4) |
| `gh` CLI usage (closeout) | keep `gh` (with the preflight skip when `gh`/remote absent — preserve PARTIAL/WARN degrade) |

**Orchestrator-skeleton preservation (load-bearing):** the 5 orchestrator skills (all but grill-with-docs) MUST keep `orchestrator_skill: true` in frontmatter + ≥3 `# Phase ` headers + ≥1 literal `Agent(subagent_type=` occurrence + a `Communication Protocol` section, or `orchestrator-gate.js` will block a future re-write of that SKILL.md. Verify each with `scanSkeleton` semantics. NOTE: opencode frontmatter only requires `name`+`description`; the `orchestrator_skill` field is harmless extra metadata that opencode ignores but the gate reads.

**Per-skill specifics:**
- **start-rpi-cycle** (orchestrator): keep the R→P→I→Closeout phases; Phase-I option (d) ultracode = opencode is the `workflow` analog — reword to "sequential execute-strict→review-strict per task" (the harness already uses this). Dispatch tokens → task tool. Skill refs (brainstorming/writing-plans/executing-plans/subagent-driven-development/finishing-a-development-branch/grill-with-docs/closeout-pr-cycle) → `skill` tool by name.
- **closeout-pr-cycle** (orchestrator): preserve "never merge without explicit user approval" (note: the user has standing auto-merge authorization for THIS migration only — keep the skill's default as approval-required). `gh` preflight skip preserved. ExitWorktree → git worktree CLI.
- **grill-with-docs** (NON-orchestrator): pure main-session procedure; copy body, ship `CONTEXT-FORMAT.md` + `ADR-FORMAT.md` siblings; retarget `docs/adr/` per start-rpi-cycle override to `docs/ai-context/architecture.md §5`.
- **create-orchestrator-skill** (orchestrator): the skeleton it injects is defined by `plugin/lib/skeleton-scan.js` (already vendored). Reword "enforce-orchestrator hook" → "orchestrator-gate". skill-creator dependency → reference the vendored `superpowers:writing-skills` skill as the creation procedure (skill-creator is a separate plugin not vendored; writing-skills covers it).
- **improve-codebase-architecture** (orchestrator): treats itself as its own cycle; dispatch explore-strict/execute-strict via task tool; doctor/check.sh references kept as bash.
- **ui-design** (orchestrator): ship `design.md` sibling verbatim (≈440 lines); Phase-3 review-strict dispatch → task tool; design.md CDN URLs kept as reference text (offline UI verification can't fetch — note in body).

- [ ] **Step 1: Port each skill** (read source, apply the map, write to `skill/<name>/SKILL.md`; copy siblings verbatim). Recommended: one ultracode subagent per skill (6 parallel ports) each given this transformation map + the source path + the agent target names, then a review pass.

- [ ] **Step 2: Validate discovery + skeletons**

Run:
```bash
export PATH="/usr/bin:/bin:/c/Program Files/nodejs:$PATH"
cd opencode-harness
node _oracle/skill-discovery.mjs    # all skills incl. the 6 ports: 0 violations
# orchestrator skeleton check for the 5 orchestrators:
for s in start-rpi-cycle closeout-pr-cycle create-orchestrator-skill improve-codebase-architecture ui-design; do
  node -e "import('./plugin/lib/skeleton-scan.js').then(m=>{const c=require('fs').readFileSync('skill/'+process.argv[1]+'/SKILL.md','utf8');const r=m.scanSkeleton(c);console.log(process.argv[1], JSON.stringify(r));process.exit(r.hasMarker===1&&r.phase>=3&&r.agent>=1&&r.contract>=1?0:1)})" "$s" || echo "SKELETON FAIL: $s"
done
```
Expected: discovery OK; each orchestrator prints `hasMarker:1, phase>=3, agent>=1, contract:>=1`.

- [ ] **Step 3: Commit**

```bash
git add opencode-harness/skill/start-rpi-cycle opencode-harness/skill/closeout-pr-cycle \
        opencode-harness/skill/grill-with-docs opencode-harness/skill/create-orchestrator-skill \
        opencode-harness/skill/improve-codebase-architecture opencode-harness/skill/ui-design
git commit -m "feat(opencode-harness): port 6 custom skills to native SKILL.md (plan 3 T4)"
```

---

### Task 5: Live offline discovery verification (opencode 1.17.11)

**Files:** none (verification only; uses the deployed bundle).

- [ ] **Step 1: Deploy the skill tree + run opencode skill listing**

Deploy `skill/` into `~/.config/opencode/skill/` (selective copy, no node_modules/package.json), then confirm opencode discovers the skills offline. Because the `skill` tool surfaces names lazily, verify via the server config or a prompt that asks the model to list available skills.

```bash
export PATH="/usr/bin:/bin:/c/Program Files/nodejs:/c/Program Files/Git/cmd:$PATH"
DEST="C:/Users/12132/.config/opencode"; SRC="/c/Users/12132/.claude/opencode-harness"
rm -rf "$DEST/skill"; cp -r "$SRC/skill" "$DEST/"
find "$DEST/skill" -name package.json -o -name 'bun.lock*' | xargs -r rm -f
# start a server and read resolved skills (build-box; proxy backend not required for discovery)
( cd "$(mktemp -d)" && timeout 25 opencode serve --port 4099 >/tmp/_sk.log 2>&1 & )
sleep 6
# the skill tool's available list is derived from discovery; confirm count via the config/skill route if exposed,
# else run a headless prompt asking the model to call skill list.
```

- [ ] **Step 2: Verify a representative skill loads + orchestrator-gate still gates a SKILL.md write**

Confirm: (a) opencode surfaces ≥20 skills (14 superpowers + 6 custom) with descriptions; (b) writing a malformed orchestrator SKILL.md (marker but <3 phases) into a no-plan project is blocked by `orchestrator-gate.js` (live, same mechanism proven in Plan 2). Record results.

- [ ] **Step 3:** (no commit — verification record goes into the closeout doc/spec §15)

---

## Self-Review (run after drafting)

- **Spec coverage:** §5 `skill/` tree (superpowers vendored + 8 custom) → T1/T4; native-skill discovery (research) → T2/T3/T5; offline (no `skills.urls`/package.json) → T1/T2/T3 constraints. Deviation from spec §5: `common-agent-contract` is inlined (not a skill); `init-ai-ready-project` opencode-emission split to **Plan 3b** (documented above) — these are scope refinements driven by the research, surfaced here, not silent drops.
- **No placeholders:** the 6 ports are transformations of existing source bodies under an exhaustive token map (Task 4) — the source + map fully specify each output.
- **Verbatim fidelity:** superpowers bodies copied unedited (upstream rule); only the added `references/opencode-tools.md` is new.
- **Out of scope (later plans):** worktree teardown (Plan 4, referenced by closeout-pr-cycle), init-ai-ready opencode emission (Plan 3b), the verification harness + zip acceptance (Plan 5).

## Execution Handoff

Plan complete. Execution: T1 (vendoring) + T2/T3 (config + validator) inline; **T4 via ultracode workflow** (6 parallel skill-port subagents under the Task-4 transformation map → adversarial review), then T5 live verification — consistent with the harness RPI mandate.
