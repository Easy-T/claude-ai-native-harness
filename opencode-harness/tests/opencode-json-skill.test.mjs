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
  for (const i of (cfg.instructions || [])) assert.ok(!/^https?:/.test(i), `instructions must be local: ${i}`);
});
