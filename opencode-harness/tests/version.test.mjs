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
