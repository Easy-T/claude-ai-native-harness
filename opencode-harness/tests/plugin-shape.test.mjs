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

test("Governance also exposes tool.execute.after + dispose (plan 4)", async () => {
  const hooks = await Governance({ client: fakeClient("1.17.11"), directory: "/proj", worktree: "/proj" });
  assert.equal(typeof hooks["tool.execute.after"], "function");
  assert.equal(typeof hooks.dispose, "function");
});

test("tool.execute.after appends a §5 advisory once per session, native-only", async () => {
  const hooks = await Governance({ client: fakeClient("1.17.11"), directory: "/proj", worktree: "/proj" });
  const after = hooks["tool.execute.after"];
  const out1 = { title: "", output: "ok", metadata: {} };
  await after({ tool: "edit", sessionID: "s1", callID: "c1", args: { filePath: "/proj/package.json" } }, out1);
  assert.ok(out1.output.includes("[harness]") && out1.output.includes("§5"), "advisory appended to model-visible output");
  // dedup: another manifest edit in the SAME session → no second §5 append
  const out2 = { title: "", output: "ok", metadata: {} };
  await after({ tool: "edit", sessionID: "s1", callID: "c2", args: { filePath: "/proj/go.mod" } }, out2);
  assert.ok(!out2.output.includes("§5"), "deduped within session");
  // non-native (MCP) tool → output untouched (mutation would not reach the model)
  const out3 = { title: "", output: "ok", metadata: {} };
  await after({ tool: "some_mcp_tool", sessionID: "s2", callID: "c3", args: { filePath: "/proj/package.json" } }, out3);
  assert.equal(out3.output, "ok", "non-native tool result left untouched");
});

test("wired gate allows a whitelisted docs edit (no plan needed)", async () => {
  // Plan 2 wired the real L2 gates; a code edit with no active plan now blocks,
  // but a whitelisted .md edit is always allowed (composed behavior covered in governance-gate.test).
  const hooks = await Governance({ client: fakeClient("1.17.9"), directory: "/proj" });
  await assert.doesNotReject(() =>
    hooks["tool.execute.before"]({ tool: "edit", sessionID: "s", callID: "c" }, { args: { filePath: "/proj/notes.md", newString: "hi" } })
  );
});

test("does not import any v2 subpath", async () => {
  const src = await import("node:fs").then((m) => m.readFileSync(new URL("../plugin/governance.js", import.meta.url), "utf8"));
  assert.ok(!/@opencode-ai\/plugin\/v2/.test(src), "must not import a v2 subpath (absent on 1.17.9)");
});
