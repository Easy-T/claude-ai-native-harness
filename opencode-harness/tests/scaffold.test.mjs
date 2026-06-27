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

test("package.json is load-critical, ships, and keeps plugin types as devDependency only", () => {
  // LOAD-CRITICAL (spec §15): opencode HANGS at plugin load when no package.json exists
  // in the config dir, so this file MUST ship (NOT be stripped by _stage.sh / the zip).
  // `type: module` is the load-critical field. @opencode-ai/plugin stays a devDependency
  // (types only): the runtime plugin imports only node: builtins + relative files, and
  // opencode's background dep-install is fail-open offline, so it is never a runtime need.
  const pkg = JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8"));
  assert.equal(pkg.type, "module", "type:module is required for opencode to load plugin/*.js as ESM");
  assert.ok(pkg.devDependencies?.["@opencode-ai/plugin"], "plugin types must be a devDependency");
  assert.ok(!pkg.dependencies || !pkg.dependencies["@opencode-ai/plugin"], "must not be a runtime dependency");
  assert.ok(!pkg.engines, "no engines lock (would exclude 1.17.9)");
});

test("plan 5 ship + build-box assets exist", () => {
  // ship assets (must be in the zip) + build-box verification entrypoints
  for (const f of ["install.sh", "PREREQUISITES.md"]) {
    assert.ok(existsSync(join(ROOT, f)), `ship asset missing: ${f}`);
  }
  for (const f of ["_oracle/verify-all.sh", "_oracle/acceptance.sh"]) {
    assert.ok(existsSync(join(ROOT, f)), `build-box tool missing: ${f}`);
  }
});

test("plan 3b: init-ai-ready-project skill ships with opencode templates", () => {
  // native bundle skill that scaffolds an opencode-TARGET project (AGENTS.md + opencode.json deny-gate).
  const SK = join(ROOT, "skill", "init-ai-ready-project");
  assert.ok(existsSync(join(SK, "SKILL.md")), "init skill SKILL.md missing");
  for (const t of ["AGENTS.md.tpl", "project-opencode.json.tpl", "deny-patterns.md.tpl", "CONTEXT.md.tpl", "state.json.tpl"]) {
    assert.ok(existsSync(join(SK, "templates", t)), `template missing: ${t}`);
  }
  // CC-only artifacts must NOT have been copied into the opencode skill
  assert.ok(!existsSync(join(SK, "templates", "CLAUDE.md.tpl")), "CLAUDE.md.tpl must not ship (opencode uses AGENTS.md.tpl)");
  assert.ok(!existsSync(join(SK, "templates", "pre-commit-deny.sh.tpl")), "pre-commit-deny.sh.tpl must not ship (opencode uses permission.bash deny)");
  assert.ok(existsSync(join(SK, "references", "placeholder-spec.md")), "placeholder-spec.md missing");
  assert.ok(existsSync(join(ROOT, "_oracle", "init-emission.mjs")), "init-emission oracle missing");
  const fm = readFileSync(join(SK, "SKILL.md"), "utf8");
  assert.match(fm, /name:\s*init-ai-ready-project/, "SKILL.md name must be init-ai-ready-project (folder==name)");
  assert.match(fm, /description:/, "SKILL.md needs a description (else opencode silently drops it)");
});
