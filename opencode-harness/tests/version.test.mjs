// opencode-harness/tests/version.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { cmpGte, subagentEnforced, enforcementFor, VERSION_FLOOR } from "../plugin/lib/version.js";

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

test("VERSION_FLOOR is the shipped target floor and enforces subagents", () => {
  assert.equal(VERSION_FLOOR, "1.17.11");
  assert.equal(subagentEnforced(VERSION_FLOOR), true);
});

test("enforcementFor uses a detected version verbatim", () => {
  assert.deepEqual(enforcementFor("1.17.11"), { version: "1.17.11", assumed: false, enforced: true });
  assert.deepEqual(enforcementFor("1.17.9"), { version: "1.17.9", assumed: false, enforced: false });
  assert.deepEqual(enforcementFor("1.18.0"), { version: "1.18.0", assumed: false, enforced: true });
});

test("enforcementFor falls back to the verified floor when detection fails", () => {
  for (const miss of [null, undefined, "", "unknown"]) {
    const r = enforcementFor(miss);
    assert.equal(r.version, VERSION_FLOOR, `miss=${miss}`);
    assert.equal(r.assumed, true, `miss=${miss}`);
    assert.equal(r.enforced, true, `miss=${miss}`);
  }
});
