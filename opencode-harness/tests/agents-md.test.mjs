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
