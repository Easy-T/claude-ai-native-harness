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
