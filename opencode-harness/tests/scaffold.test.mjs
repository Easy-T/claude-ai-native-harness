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
