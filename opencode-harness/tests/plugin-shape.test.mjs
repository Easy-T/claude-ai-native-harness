// opencode-harness/tests/plugin-shape.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { Governance } from "../plugin/governance.js";

function fakeClient(version) {
  return { app: { get: async () => ({ version }) } };
}

test("Governance is a v1 function plugin exposing tool.execute.before", async () => {
  const hooks = await Governance({ client: fakeClient("1.17.11"), directory: "/proj" });
  assert.equal(typeof hooks["tool.execute.before"], "function");
});

test("no-op gate allows a normal edit (no throw)", async () => {
  const hooks = await Governance({ client: fakeClient("1.17.9"), directory: "/proj" });
  await assert.doesNotReject(() =>
    hooks["tool.execute.before"]({ tool: "edit", sessionID: "s", callID: "c" }, { args: { filePath: "/proj/a.py" } })
  );
});

test("does not import any v2 subpath", async () => {
  const src = await import("node:fs").then((m) => m.readFileSync(new URL("../plugin/governance.js", import.meta.url), "utf8"));
  assert.ok(!/@opencode-ai\/plugin\/v2/.test(src), "must not import a v2 subpath (absent on 1.17.9)");
});
