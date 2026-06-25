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
