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
