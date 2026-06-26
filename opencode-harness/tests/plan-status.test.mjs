// opencode-harness/tests/plan-status.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { planStatus, hasActivePlan } from "../plugin/lib/plan-status.js";

test("planStatus reads bold **Status:** first word, lowercased", () => {
  assert.equal(planStatus("# Plan\n**Status:** Active\n"), "active");
  assert.equal(planStatus("**Status:** completed - cleanup pending"), "completed");
});

test("planStatus ignores prose and fenced examples (cycle-26 seal)", () => {
  assert.equal(planStatus("Status: active\n"), "");          // not bold
  assert.equal(planStatus("```\n**Status:** active\n```\n"), ""); // fenced
  assert.equal(planStatus("~~~\n**Status:** active\n~~~\n"), "");
});

test("hasActivePlan finds an active plan via injected fs", () => {
  const fsLike = {
    readdirSync: () => ["a.md", "b.md"],
    readFileSync: (p) => p.endsWith("b.md") ? "**Status:** active\n" : "**Status:** completed\n",
  };
  const hit = hasActivePlan("/proj", fsLike);
  assert.ok(hit && hit.endsWith("b.md"));
});

test("hasActivePlan returns null when no plan is active / dir missing", () => {
  assert.equal(hasActivePlan("/proj", { readdirSync: () => ["a.md"], readFileSync: () => "**Status:** done\n" }), null);
  assert.equal(hasActivePlan("/proj", { readdirSync: () => { throw new Error("ENOENT"); }, readFileSync: () => "" }), null);
});
