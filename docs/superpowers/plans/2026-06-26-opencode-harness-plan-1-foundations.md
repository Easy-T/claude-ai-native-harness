# opencode Harness — Plan 1: Foundations & Plugin First-Light Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active
**RPI-Cycle:** 42 (opencode-harness migration — plan 1 of N)
**Started:** 2026-06-26

**Live Verification (2026-06-26, opencode 1.17.11 installed):** all 4 integration checks **PASS** — ① plugin loads offline (single clean load) · ② arg-keys match live shapes (R2) · ③ AGENTS.md constitution injected into the main agent request (§1–§8 markers 8/8, via outbound-request capture) · ④ L3 floor: 3 strict subagents loaded `mode=subagent` with exact permission maps, and `deny` enforced at runtime. Fix-forward this cycle: version `enforcementFor()` floor-fallback (runtime SDK probe unreliable), `package.json` excluded from the zip (opencode auto-installs config-dir package.json → offline network risk). Full record + build-box test methodology in spec §13. NOTE: constraint below ("via `OPENCODE_CONFIG_DIR`") is corrected by §13 — `OPENCODE_CONFIG_DIR` does NOT isolate from the global `~/.config/opencode` (plugins union); test against a clean real deploy or emptied global.

**Goal:** Stand up the offline opencode-harness staging bundle with a loading v1 plugin substrate (fail-open + frozen arg-keys + version probe), the L1 AGENTS.md constitution, and the L3 permission subagent floor — verified in live opencode 1.17.9.

**Architecture:** A git-tracked staging dir `~/.claude/opencode-harness/` is the zip root that unpacks to `~/.config/opencode/`. The plugin is authored in **plain ESM `.js`** (zero transpile; runs identically under `node` for unit tests and under opencode's Bun at runtime) as a **v1 Promise plugin** (function export, deny = `throw`). This plan builds only the substrate + L1 + L3; the L2 dynamic gates, node-parser reuse, skills vendoring, worktree teardown, and the differential conformance oracle are later plans.

**Tech Stack:** opencode v1.17.9 (local) / target v1.17.11 · Bun (opencode runtime) · Node v24 `node --test` (unit tests) · `@opencode-ai/plugin@1.17.11` (devDependency, JSDoc types only).

## Global Constraints

- **Plugin API = v1 Promise-style** (flat hooks object, function export). deny = `throw`. **Never `import` `@opencode-ai/plugin/v2/*`** anywhere reachable on 1.17.9 (subpath absent there → import-time throw, Bun caches the failed resolution).
- **Pure ESM `.js`** for all plugin code (no `.ts`, no transpile, no runtime node_modules). `@opencode-ai/plugin@1.17.11` is a **devDependency only** (types). No `engines`/peer version lock (would exclude 1.17.9).
- **Ship as local files** under `~/.config/opencode/plugin/`. **Never** via the `opencode.json` `"plugin":[]` array (that path Bun-installs = needs network).
- **Target runtime ≥1.17.10** (recommend pin 1.17.11) to close R1 (subagent content enforcement via the centralized tool wrapper); the **same plugin must also load and run on 1.17.9** (degraded: primary-agent only).
- **fail-open posture:** every hook body wrapped so only a `BlockError` denies (its `throw` propagates); any other thrown error is swallowed → ALLOW. `BlockError` + the wrapper must exist before any gate is written.
- **env/path are GLOBAL** (`~/.config/opencode`), not session-scoped: `arg-keys` are frozen globally and re-validated by a startup self-test in every environment (incl. the company box).
- **No CCS proxy / internal models only:** `opencode.json` `provider`/`model` point at the company-provided internal model endpoint. No routing layer; `[1m]`/tier-remap/`small_model` dropped.
- **Staging layout:** build under `~/.claude/opencode-harness/`; `_oracle/` (build-box only) is excluded from the shipped zip. Integration tests run live opencode against the staging dir via `OPENCODE_CONFIG_DIR` (never clobber the user's real `~/.config/opencode`).
- Commit after every task. Conventional-commit messages. End commit bodies with the Co-Authored-By trailer.

---

### Task 1: Staging bundle scaffold + package.json + opencode.json skeleton

**Files:**
- Create: `opencode-harness/package.json`
- Create: `opencode-harness/opencode.json`
- Create: `opencode-harness/.gitignore`
- Create: `opencode-harness/README.md`
- Create: `opencode-harness/plugin/lib/.gitkeep`, `opencode-harness/plugin/gates/.gitkeep`, `opencode-harness/agent/.gitkeep`, `opencode-harness/skill/.gitkeep`, `opencode-harness/command/.gitkeep`, `opencode-harness/docs/ai-context/.gitkeep`, `opencode-harness/_oracle/.gitkeep`
- Test: `opencode-harness/tests/scaffold.test.mjs`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the staging directory tree; `opencode.json` with a `$schema`, `permission` stub, `instructions:[]`, `compaction.auto`, and **no** `plugin` array. Later tasks add files under `plugin/`, `agent/`, and the `AGENTS.md` at the bundle root.

- [ ] **Step 1: Write the failing test**

```javascript
// opencode-harness/tests/scaffold.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

test("required directories exist", () => {
  for (const d of ["plugin", "plugin/lib", "plugin/gates", "agent", "skill", "command", "docs/ai-context", "_oracle"]) {
    assert.ok(existsSync(join(ROOT, d)), `missing dir: ${d}`);
  }
});

test("opencode.json is valid JSON with no network plugin array", () => {
  const cfg = JSON.parse(readFileSync(join(ROOT, "opencode.json"), "utf8"));
  assert.equal(cfg["$schema"], "https://opencode.ai/config.json");
  assert.ok(!("plugin" in cfg), "must NOT declare a network 'plugin' array");
  assert.ok(Array.isArray(cfg.instructions), "instructions must be an array");
  assert.ok(cfg.permission && typeof cfg.permission === "object", "permission block required");
});

test("package.json keeps the plugin types as a devDependency only", () => {
  const pkg = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8"));
  assert.equal(pkg.type, "module");
  assert.ok(pkg.devDependencies?.["@opencode-ai/plugin"], "plugin types must be a devDependency");
  assert.ok(!pkg.dependencies || !pkg.dependencies["@opencode-ai/plugin"], "must not be a runtime dependency");
  assert.ok(!pkg.engines, "no engines lock (would exclude 1.17.9)");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/.claude/opencode-harness && node --test tests/scaffold.test.mjs`
Expected: FAIL — files/dirs do not exist yet (ENOENT).

- [ ] **Step 3: Create the scaffold**

```bash
cd ~/.claude/opencode-harness
mkdir -p plugin/lib plugin/gates agent skill command docs/ai-context _oracle tests
for d in plugin/lib plugin/gates agent skill command docs/ai-context _oracle; do : > "$d/.gitkeep"; done
```

`opencode-harness/package.json`:
```json
{
  "name": "opencode-harness",
  "private": true,
  "type": "module",
  "description": "Offline opencode governance harness (ported from ~/.claude). Unpacks to ~/.config/opencode/.",
  "devDependencies": {
    "@opencode-ai/plugin": "1.17.11"
  }
}
```

`opencode-harness/opencode.json` (skeleton — `provider`/`model` and full permission map filled by later tasks):
```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [],
  "permission": {
    "edit": "allow",
    "bash": "allow"
  },
  "compaction": { "auto": true }
}
```

`opencode-harness/.gitignore`:
```gitignore
node_modules/
```

`opencode-harness/README.md`:
```markdown
# opencode-harness (offline bundle)

Unpacks to `~/.config/opencode/`. Build/staging dir is git-tracked under `~/.claude/`.

- `plugin/` — v1 ESM governance plugin (loaded offline by opencode).
- `agent/` — constrained subagents (mode:subagent + permission floor).
- `skill/`, `command/`, `docs/ai-context/`, `AGENTS.md` — governance assets.
- `_oracle/` — BUILD-BOX ONLY differential conformance oracle. **Excluded from the shipped zip.**

## Local testing (do not clobber real config)
    OPENCODE_CONFIG_DIR="$PWD" opencode run "..."

## Ship
    # from ~/.claude/opencode-harness, excluding _oracle and node_modules
    zip -r ../opencode-harness.zip . -x '_oracle/*' 'node_modules/*' 'tests/*'
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/.claude/opencode-harness && node --test tests/scaffold.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/.claude
git add opencode-harness
git commit -m "feat(opencode-harness): staging scaffold + opencode.json skeleton (plan 1 T1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Fail-open envelope + BlockError (invariant 39)

**Files:**
- Create: `opencode-harness/plugin/lib/fail-open.js`
- Test: `opencode-harness/tests/fail-open.test.mjs`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class BlockError extends Error` — the ONLY error type that denies a tool call.
  - `failOpen(fn) => (input, output) => Promise<void>` — wraps a hook body; re-throws `BlockError` (deny propagates), swallows any other error (returns normally = ALLOW), logging the swallowed error to stderr with a `FAILOPEN` marker.

- [ ] **Step 1: Write the failing test**

```javascript
// opencode-harness/tests/fail-open.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { BlockError, failOpen } from "../plugin/lib/fail-open.js";

test("BlockError propagates (deny)", async () => {
  const wrapped = failOpen(async () => { throw new BlockError("nope"); });
  await assert.rejects(() => wrapped({ tool: "edit" }, { args: {} }), /nope/);
});

test("non-BlockError is swallowed (fail-open allow)", async () => {
  const wrapped = failOpen(async () => { throw new TypeError("boom"); });
  await assert.doesNotReject(() => wrapped({ tool: "edit" }, { args: {} }));
});

test("clean hook returns normally", async () => {
  let ran = false;
  const wrapped = failOpen(async () => { ran = true; });
  await wrapped({ tool: "edit" }, { args: {} });
  assert.ok(ran);
});

test("BlockError is an Error subclass with a name", () => {
  const e = new BlockError("x");
  assert.ok(e instanceof Error);
  assert.equal(e.name, "BlockError");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/.claude/opencode-harness && node --test tests/fail-open.test.mjs`
Expected: FAIL — `Cannot find module '../plugin/lib/fail-open.js'`.

- [ ] **Step 3: Write minimal implementation**

```javascript
// opencode-harness/plugin/lib/fail-open.js
export class BlockError extends Error {
  constructor(message) {
    super(message);
    this.name = "BlockError";
  }
}

// Wrap a hook body so ONLY a BlockError denies. Any other failure of the
// governance code itself must never block the user's work (invariant 39).
export function failOpen(fn) {
  return async (input, output) => {
    try {
      await fn(input, output);
    } catch (err) {
      if (err instanceof BlockError) throw err; // deny propagates
      // fail-open: swallow our own malfunction, surface it, allow the tool
      try { console.error(`[harness] FAILOPEN ${input?.tool ?? "?"}: ${err?.message ?? err}`); } catch {}
    }
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/.claude/opencode-harness && node --test tests/fail-open.test.mjs`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/.claude
git add opencode-harness/plugin/lib/fail-open.js opencode-harness/tests/fail-open.test.mjs
git commit -m "feat(opencode-harness): fail-open envelope + BlockError (plan 1 T2, inv 39)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: arg-keys freeze + startup self-test + live-probe script (R2 / Phase-0)

**Files:**
- Create: `opencode-harness/plugin/lib/arg-keys.js`
- Create: `opencode-harness/plugin/lib/_probe-arg-keys.js`
- Test: `opencode-harness/tests/arg-keys.test.mjs`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `ARG_KEYS` — frozen map of opencode tool → the `output.args` key holding the path/command: `{ edit:"filePath", write:"filePath", apply_patch:"filePath", bash:"command" }` (plus secondary content keys `content`,`oldString`,`newString`).
  - `assertArgKeys(samples) => string[]` — given synthetic `{tool, args}` samples, returns the list of tools whose expected key is **absent** (empty = OK). Used by the plugin at startup to fail-LOUD (ALERT) if opencode's arg shape drifted — the one place we deviate from fail-open because a wrong key silently disables every gate (R2).
  - `pathArg(tool, args) => string | undefined` — resolve the path/command for a tool from its args using `ARG_KEYS`.

- [ ] **Step 1: Write the failing test**

```javascript
// opencode-harness/tests/arg-keys.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { ARG_KEYS, assertArgKeys, pathArg } from "../plugin/lib/arg-keys.js";

test("frozen keys cover the gated tools", () => {
  for (const t of ["edit", "write", "apply_patch", "bash"]) assert.ok(ARG_KEYS[t], `no key for ${t}`);
});

test("pathArg resolves path tools and bash command", () => {
  assert.equal(pathArg("edit", { filePath: "/x/a.py" }), "/x/a.py");
  assert.equal(pathArg("bash", { command: "echo hi" }), "echo hi");
});

test("assertArgKeys returns empty when shapes match", () => {
  const samples = [
    { tool: "edit", args: { filePath: "/a", oldString: "x", newString: "y" } },
    { tool: "write", args: { filePath: "/a", content: "z" } },
    { tool: "bash", args: { command: "ls" } },
  ];
  assert.deepEqual(assertArgKeys(samples), []);
});

test("assertArgKeys flags a drifted shape (R2)", () => {
  const samples = [{ tool: "edit", args: { path: "/a" } }]; // wrong key name
  assert.deepEqual(assertArgKeys(samples), ["edit"]);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/.claude/opencode-harness && node --test tests/arg-keys.test.mjs`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```javascript
// opencode-harness/plugin/lib/arg-keys.js
// Frozen result of the live arg-key probe against opencode 1.17.9 (see _probe-arg-keys.js).
// Re-validated at plugin startup by assertArgKeys (R2: a wrong key silently disables a gate).
export const ARG_KEYS = Object.freeze({
  edit: "filePath",
  write: "filePath",
  apply_patch: "filePath",
  bash: "command",
});

// Secondary keys carrying mutable content (for content-scan gates in later plans).
export const CONTENT_KEYS = Object.freeze(["content", "oldString", "newString"]);

export function pathArg(tool, args) {
  const key = ARG_KEYS[tool];
  return key ? args?.[key] : undefined;
}

// Returns the list of tools whose expected primary key is absent in the sample.
// Empty array = shapes match. Non-empty = ALERT (fail-loud) at startup.
export function assertArgKeys(samples) {
  const missing = [];
  for (const { tool, args } of samples) {
    const key = ARG_KEYS[tool];
    if (key && !(args && key in args)) missing.push(tool);
  }
  return missing;
}
```

```javascript
// opencode-harness/plugin/lib/_probe-arg-keys.js
// LIVE PROBE (run once per environment, incl. the company box — R2).
// Drop-in plugin that logs the real output.args keys, then remove it.
// Usage: copy to plugin/, run `OPENCODE_CONFIG_DIR=. opencode run "edit any file; run a bash echo"`,
// read the stderr lines, confirm they match ARG_KEYS, then delete this file from plugin/.
export const ArgKeyProbe = async () => ({
  "tool.execute.before": async (input, output) => {
    try {
      console.error(`[probe] ${input.tool} args=${JSON.stringify(Object.keys(output?.args ?? {}))}`);
    } catch {}
  },
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/.claude/opencode-harness && node --test tests/arg-keys.test.mjs`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/.claude
git add opencode-harness/plugin/lib/arg-keys.js opencode-harness/plugin/lib/_probe-arg-keys.js opencode-harness/tests/arg-keys.test.mjs
git commit -m "feat(opencode-harness): frozen arg-keys + startup self-test + live probe (plan 1 T3, R2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Version probe + degraded-mode flag

**Files:**
- Create: `opencode-harness/plugin/lib/version.js`
- Test: `opencode-harness/tests/version.test.mjs`

**Interfaces:**
- Consumes: nothing (the SDK `client` is injected by opencode at runtime; here we only need the pure comparison logic).
- Produces:
  - `cmpGte(a, b) => boolean` — semver-ish "a >= b" over dotted numeric versions.
  - `subagentEnforced(version) => boolean` — true iff `version >= 1.17.10` (the runtime floor where `tool.execute.before` fires for subagent calls).

- [ ] **Step 1: Write the failing test**

```javascript
// opencode-harness/tests/version.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { cmpGte, subagentEnforced } from "../plugin/lib/version.js";

test("cmpGte compares dotted numeric versions", () => {
  assert.equal(cmpGte("1.17.11", "1.17.10"), true);
  assert.equal(cmpGte("1.17.9", "1.17.10"), false);
  assert.equal(cmpGte("1.18.0", "1.17.10"), true);
  assert.equal(cmpGte("1.17.10", "1.17.10"), true);
});

test("subagentEnforced is true only at >=1.17.10", () => {
  assert.equal(subagentEnforced("1.17.9"), false);
  assert.equal(subagentEnforced("1.17.10"), true);
  assert.equal(subagentEnforced("1.17.11"), true);
  assert.equal(subagentEnforced("unknown"), false);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/.claude/opencode-harness && node --test tests/version.test.mjs`
Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

```javascript
// opencode-harness/plugin/lib/version.js
function parts(v) {
  return String(v).split(".").map((n) => parseInt(n, 10));
}

export function cmpGte(a, b) {
  const pa = parts(a), pb = parts(b);
  if (pa.some(Number.isNaN) || pb.some(Number.isNaN)) return false;
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const x = pa[i] ?? 0, y = pb[i] ?? 0;
    if (x !== y) return x > y;
  }
  return true; // equal
}

// >=1.17.10: the centralized tool wrapper fires tool.execute.before for subagent
// (task-spawned) calls, enabling content-based subagent enforcement (closes R1).
export function subagentEnforced(version) {
  return cmpGte(version, "1.17.10");
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/.claude/opencode-harness && node --test tests/version.test.mjs`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/.claude
git add opencode-harness/plugin/lib/version.js opencode-harness/tests/version.test.mjs
git commit -m "feat(opencode-harness): version probe + subagentEnforced flag (plan 1 T4)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Minimal governance plugin — loads in live opencode 1.17.9 (offline)

**Files:**
- Create: `opencode-harness/plugin/governance.js`
- Test: manual integration check (documented below) + `opencode-harness/tests/plugin-shape.test.mjs`

**Interfaces:**
- Consumes: `failOpen`, `BlockError` (T2); `ARG_KEYS`, `assertArgKeys`, `pathArg` (T3); `cmpGte`, `subagentEnforced` (T4).
- Produces: the v1 Promise plugin function export `Governance` returning a hooks object with a single `tool.execute.before` that (this plan) only runs the startup arg-key self-test once, logs degraded/enforced mode, and is a no-op gate (allows). Later plans add real gates inside this same hook.

- [ ] **Step 1: Write the failing test (plugin shape, runnable under node)**

```javascript
// opencode-harness/tests/plugin-shape.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { Governance } from "../plugin/governance.js";

function fakeClient(version) {
  return { app: { get: async () => ({ version }) } };
}

test("Governance is a v1 function plugin exposing tool.execute.before", async () => {
  const hooks = await Governance({ client: fakeClient("1.17.11"), directory: "/proj" });
  assert.equal(typeof hooks["tool.execute.before"], "function");
});

test("no-op gate allows a normal edit (no throw)", async () => {
  const hooks = await Governance({ client: fakeClient("1.17.9"), directory: "/proj" });
  await assert.doesNotReject(() =>
    hooks["tool.execute.before"]({ tool: "edit", sessionID: "s", callID: "c" }, { args: { filePath: "/proj/a.py" } })
  );
});

test("does not import any v2 subpath", async () => {
  const src = await import("node:fs").then((m) => m.readFileSync(new URL("../plugin/governance.js", import.meta.url), "utf8"));
  assert.ok(!/@opencode-ai\/plugin\/v2/.test(src), "must not import a v2 subpath (absent on 1.17.9)");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/.claude/opencode-harness && node --test tests/plugin-shape.test.mjs`
Expected: FAIL — `Cannot find module '../plugin/governance.js'`.

- [ ] **Step 3: Write minimal implementation**

```javascript
// opencode-harness/plugin/governance.js
// v1 Promise plugin (function export = most portable load shape). deny = throw BlockError.
// Runs unchanged on opencode 1.17.9 (primary-agent only) and >=1.17.10 (also subagent calls).
import { failOpen, BlockError } from "./lib/fail-open.js";
import { ARG_KEYS, assertArgKeys, pathArg } from "./lib/arg-keys.js";
import { subagentEnforced } from "./lib/version.js";

export const Governance = async ({ client, directory }) => {
  // One-time version + arg-key self-test (R2: fail LOUD if arg shape drifted).
  let version = "unknown";
  try { version = (await client?.app?.get())?.version ?? "unknown"; } catch {}
  const enforced = subagentEnforced(version);
  console.error(`[harness] loaded — opencode ${version}; subagent-enforced=${enforced}; cwd=${directory ?? "?"}`);

  let selfTested = false;
  const selfTest = (input, output) => {
    if (selfTested) return;
    selfTested = true;
    const missing = assertArgKeys([{ tool: input.tool, args: output?.args ?? {} }]);
    if (missing.length) {
      console.error(`[harness] ALERT arg-key drift for ${missing.join(",")} — gates may be disabled (R2). Re-run the arg-key probe.`);
    }
  };

  return {
    "tool.execute.before": failOpen(async (input, output) => {
      selfTest(input, output);
      // Plan 1: no gates yet — resolve the path/command for later gates and allow.
      void pathArg(input.tool, output?.args ?? {});
      void ARG_KEYS; void BlockError; // referenced; real gates land in plan 2
    }),
  };
};
```

- [ ] **Step 4: Run unit test to verify it passes**

Run: `cd ~/.claude/opencode-harness && node --test tests/plugin-shape.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Verify it LOADS in live opencode 1.17.9 (offline integration milestone)**

```bash
cd ~/.claude/opencode-harness
OPENCODE_CONFIG_DIR="$PWD" opencode run --print-logs "say hello and stop" 2>&1 | grep -i "\[harness\] loaded"
```
Expected: a line like `[harness] loaded — opencode 1.17.9; subagent-enforced=false; cwd=...` — proves the plugin auto-loads from the staging dir **with no network** and the version probe works. (If `opencode` is not on PATH, document the user's launch command instead and have them paste the log line.)

- [ ] **Step 6: Run the live arg-key probe (R2, one-time)**

```bash
cd ~/.claude/opencode-harness
cp plugin/lib/_probe-arg-keys.js plugin/_probe.js
OPENCODE_CONFIG_DIR="$PWD" opencode run --print-logs "edit README.md to add a blank line, then run: echo hi" 2>&1 | grep "\[probe\]"
rm plugin/_probe.js
```
Expected: `[probe] edit args=["filePath",...]`, `[probe] bash args=["command"]` — confirms `ARG_KEYS` matches reality. If keys differ, update `plugin/lib/arg-keys.js` and re-run Task 3 tests. **This step MUST be repeated in the company environment before trusting the gates.**

- [ ] **Step 7: Commit**

```bash
cd ~/.claude
git add opencode-harness/plugin/governance.js opencode-harness/tests/plugin-shape.test.mjs
git commit -m "feat(opencode-harness): minimal v1 governance plugin loads in opencode (plan 1 T5)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: L1 — global AGENTS.md constitution

**Files:**
- Create: `opencode-harness/AGENTS.md`
- Test: `opencode-harness/tests/agents-md.test.mjs`

**Interfaces:**
- Consumes: the existing `~/.claude/CLAUDE.md` (source of the 8 §-rules, verbatim).
- Produces: `AGENTS.md` at the bundle root — auto-loaded by opencode every session (first-match-wins). Holds the 8 §-rules + the 4 principles + an opencode tool-mapping note + new standing rules placed **under existing §-headers** (no new `## §N.` markers, preserving the invariant-41 marker count).

- [ ] **Step 1: Write the failing test (the invariant-41 seal, retargeted to AGENTS.md)**

```javascript
// opencode-harness/tests/agents-md.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const md = () => readFileSync(join(ROOT, "AGENTS.md"), "utf8");

test("AGENTS.md is <= 200 lines (inv 41 / §1 cache discipline)", () => {
  assert.ok(md().split("\n").length <= 200);
});

test("AGENTS.md has exactly 8 top-level section markers", () => {
  const markers = md().match(/^## §[1-8]\./gm) ?? [];
  assert.equal(markers.length, 8);
});

test("AGENTS.md carries the opencode tool-mapping note + sentinel", () => {
  const t = md();
  assert.match(t, /Task.*@mention|subagent/i);
  assert.match(t, /HARNESS-CONSTITUTION-LOADED/); // sentinel for the live-load integration check
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/.claude/opencode-harness && node --test tests/agents-md.test.mjs`
Expected: FAIL — `AGENTS.md` does not exist.

- [ ] **Step 3: Author AGENTS.md**

Build `opencode-harness/AGENTS.md` as follows (concrete transformation of an existing source — not a placeholder):
1. Copy the eight `## §1.`–`## §8.` sections and the "Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution" principles **verbatim** from `~/.claude/CLAUDE.md`.
2. Replace the opening line about "모든 Claude 세션의 prefix에 자동 로드" with an opencode-accurate header that includes the literal sentinel token `HARNESS-CONSTITUTION-LOADED` (used by the live-load check in Step 5).
3. Append, **under the existing `## §2. Orchestrator Meta Rule` header** (no new `## §` marker), an opencode tool-mapping note:

```markdown
> **opencode tool mapping:** `Skill` 도구 → opencode `skill` 도구; `Agent(subagent_type=X)`/`Task` → opencode 서브에이전트(`@X` 또는 task 위임); `TodoWrite` → `todowrite`. RPI 강제는 `~/.config/opencode/plugin/governance.js`(tool.execute.before)가 수행하며, 서브에이전트 쓰기는 `permission` deny 맵이 바닥을 친다.
```

4. Place any other new standing rules (e.g. closeout no-auto-merge, three-field subagent contract) under the most relevant existing § header — **never** add a `## §9.` etc.
5. Keep total length ≤ 200 lines (move overflow detail into `docs/ai-context/` referenced via `instructions:[]`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/.claude/opencode-harness && node --test tests/agents-md.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Verify live auto-load (integration)**

```bash
cd ~/.claude/opencode-harness
OPENCODE_CONFIG_DIR="$PWD" opencode run "Print the single word that is your constitution's load sentinel, nothing else."
```
Expected: the model outputs `HARNESS-CONSTITUTION-LOADED`, proving the global `AGENTS.md` is auto-loaded into the session.

- [ ] **Step 6: Commit**

```bash
cd ~/.claude
git add opencode-harness/AGENTS.md opencode-harness/tests/agents-md.test.mjs
git commit -m "feat(opencode-harness): L1 AGENTS.md constitution (plan 1 T6, inv 41)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: L3 — permission floor + constrained subagents

**Files:**
- Modify: `opencode-harness/opencode.json` (fill the `permission` block)
- Create: `opencode-harness/agent/explore-strict.md`, `opencode-harness/agent/execute-strict.md`, `opencode-harness/agent/review-strict.md`
- Test: `opencode-harness/tests/permission-floor.test.mjs`

**Interfaces:**
- Consumes: the existing `~/.claude/agents/{explore,execute,review}-strict.md` (system-prompt bodies) and `~/.claude/skills/common-agent-contract/SKILL.md` (contract to inline).
- Produces: three `mode: subagent` agents whose `permission` frontmatter is the real subagent-write floor (gated even when the plugin hook does not fire — 1.17.9), and a global `permission` block. **Golden permission table** (asserted by the test):
  - `explore-strict`: edit/write/apply_patch/bash/task → `deny`; read/grep/glob/list/webfetch → `allow`.
  - `review-strict`: edit/write/apply_patch/task → `deny`; bash → `{ "*":"ask", "rm *":"deny", "* > *":"deny", "grep *":"allow", "git status*":"allow" }`.
  - `execute-strict`: read/edit/write/apply_patch/bash → `allow`; task → `deny`.

- [ ] **Step 1: Write the failing test (golden permission table)**

```javascript
// opencode-harness/tests/permission-floor.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

// minimal YAML-frontmatter permission extractor (avoids a yaml dep)
function frontmatterPermission(file) {
  const t = readFileSync(join(ROOT, "agent", file), "utf8");
  const fm = t.match(/^---\n([\s\S]*?)\n---/);
  assert.ok(fm, `no frontmatter in ${file}`);
  return fm[1];
}

test("explore-strict denies all mutation + task, allows read tools", () => {
  const p = frontmatterPermission("explore-strict.md");
  assert.match(p, /mode:\s*subagent/);
  for (const k of ["edit", "write", "apply_patch", "bash", "task"]) assert.match(p, new RegExp(`${k}:\\s*deny`));
});

test("execute-strict allows mutation but denies task (no self-spawn, inv 21)", () => {
  const p = frontmatterPermission("execute-strict.md");
  assert.match(p, /task:\s*deny/);
  for (const k of ["edit", "write", "bash"]) assert.match(p, new RegExp(`${k}:\\s*allow`));
});

test("review-strict denies edits, gates bash (ask) with rm/redirect denied", () => {
  const p = frontmatterPermission("review-strict.md");
  for (const k of ["edit", "write", "apply_patch", "task"]) assert.match(p, new RegExp(`${k}:\\s*deny`));
  assert.match(p, /"rm \*":\s*deny/);
  assert.match(p, /"\* > \*":\s*deny/);
});

test("global opencode.json permission block exists (last-match-wins ordering)", () => {
  const cfg = JSON.parse(readFileSync(join(ROOT, "opencode.json"), "utf8"));
  assert.ok(cfg.permission.edit, "global edit permission must be explicit");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/.claude/opencode-harness && node --test tests/permission-floor.test.mjs`
Expected: FAIL — agent files do not exist.

- [ ] **Step 3: Write the three agent files + fill opencode.json permission**

For each agent: copy the **system-prompt body verbatim** from the matching `~/.claude/agents/<name>-strict.md`, inline the contract from `~/.claude/skills/common-agent-contract/SKILL.md` (3-field input task/context_paths/success_criteria; PASS|FAIL|COMPLETE output; no self-spawn), and write the opencode frontmatter:

`opencode-harness/agent/explore-strict.md`:
```markdown
---
description: Read-only exploration/research wrapper (Phase R / Discover). Returns findings only.
mode: subagent
permission:
  edit: deny
  write: deny
  apply_patch: deny
  bash: deny
  task: deny
  read: allow
  grep: allow
  glob: allow
  list: allow
  webfetch: allow
---
<verbatim system prompt body from ~/.claude/agents/explore-strict.md + inlined common-agent-contract>
```

`opencode-harness/agent/execute-strict.md`:
```markdown
---
description: The ONLY code-modifying wrapper. Hard scope-lock, self-verify. Returns COMPLETE/FAIL.
mode: subagent
permission:
  read: allow
  edit: allow
  write: allow
  apply_patch: allow
  bash: allow
  task: deny
---
<verbatim system prompt body from ~/.claude/agents/execute-strict.md + inlined common-agent-contract>
```

`opencode-harness/agent/review-strict.md`:
```markdown
---
description: Read-only verification wrapper. PASS only if ALL criteria met; any single failure → FAIL.
mode: subagent
permission:
  edit: deny
  write: deny
  apply_patch: deny
  task: deny
  read: allow
  grep: allow
  glob: allow
  bash:
    "*": ask
    "rm *": deny
    "* > *": deny
    "grep *": allow
    "git status*": allow
---
<verbatim system prompt body from ~/.claude/agents/review-strict.md + inlined common-agent-contract>
```

Fill the global `permission` block in `opencode-harness/opencode.json` (last-match-wins; `*` first, specifics after):
```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [],
  "permission": {
    "edit": "allow",
    "bash": { "*": "allow", "rm -rf *": "ask", "git push *": "ask" },
    "webfetch": "allow"
  },
  "compaction": { "auto": true }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/.claude/opencode-harness && node --test tests/permission-floor.test.mjs`
Expected: PASS (4 tests).

- [ ] **Step 5: Verify the subagent floor in live opencode (integration — proves the boundary the hook cannot guarantee on 1.17.9)**

```bash
cd ~/.claude/opencode-harness
OPENCODE_CONFIG_DIR="$PWD" opencode run "Delegate to the explore-strict subagent: ask it to create a file /tmp/should_not_exist.txt with content 'x'."
test ! -f /tmp/should_not_exist.txt && echo "PASS: explore-strict edit denied by permission floor"
```
Expected: `PASS: explore-strict edit denied by permission floor` (the read-only subagent's write is refused by its `permission` map).

- [ ] **Step 6: Commit**

```bash
cd ~/.claude
git add opencode-harness/agent opencode-harness/opencode.json opencode-harness/tests/permission-floor.test.mjs
git commit -m "feat(opencode-harness): L3 permission floor + 3 constrained subagents (plan 1 T7, inv 20-25)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Plan 1 — Definition of Done

- All unit suites pass: `cd ~/.claude/opencode-harness && node --test tests/*.test.mjs`.
- Live opencode 1.17.9: plugin auto-loads offline (T5/5), arg-keys probe matches `ARG_KEYS` (T5/6), AGENTS.md sentinel recited (T6/5), explore-strict write denied by permission floor (T7/5).
- Bundle is git-tracked under `~/.claude/opencode-harness/`; `_oracle/` empty placeholder present and zip-excluded.

## Deferred to later plans (explicitly NOT in Plan 1)
- **Plan 2:** L2 dynamic gates — RPI plan-gate (reuse `redirect-targets.js`) + secret-scan (extract `lib/secret-scan.js` SSOT) + orchestrator skeleton (reuse `skeleton-scan.js`), all inside `governance.js` `tool.execute.before`; + the differential conformance oracle (`cases.tsv` + `run-all.sh` vs `run-all-ts.mjs`, `diff==∅`).
- **Plan 3:** skills — vendor superpowers offline + port the 8 custom skills + `create-orchestrator-skill` template lockstep; commands (`/status`, `/verify`, init-ai-ready opencode-flavored emission).
- **Plan 4:** worktree teardown (pure-TS, `session.deleted/dispose` + `session.created` sweep) + `tool.execute.after` advisories (stable-claude-md, surface-constitution) + verify-loop.
- **Plan 5:** verification harness — retargeted drift seals, `verify-integration-opencode.mjs` (E2E A–G + I subagent-floor + J apply_patch), acceptance test, install/ship scripts, PREREQUISITES.md.
