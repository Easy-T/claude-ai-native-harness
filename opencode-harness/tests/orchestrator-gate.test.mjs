// opencode-harness/tests/orchestrator-gate.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { orchestratorGate } from "../plugin/gates/orchestrator-gate.js";
import { BlockError } from "../plugin/lib/fail-open.js";

const fs = { readFileSync: () => { throw new Error("no file"); } };
const full = ["orchestrator_skill: true","# Phase 1","# Phase 2","# Phase 3","Agent(subagent_type=x)","Communication Protocol"].join("\n");

test("non-skill paths are ignored", () => {
  assert.doesNotThrow(() => orchestratorGate({ tool: "write", args: { filePath: "/a/notes.md", content: "x" }, fs }));
});

test("marked skill missing skeleton blocks; complete skeleton allows", () => {
  assert.throws(() => orchestratorGate({ tool: "write", args: { filePath: "/s/skills/foo/SKILL.md", content: "orchestrator_skill: true\n# Phase 1" }, fs }), BlockError);
  assert.doesNotThrow(() => orchestratorGate({ tool: "write", args: { filePath: "/s/skills/foo/SKILL.md", content: full }, fs }));
});

test("no orchestrator marker = opt-out allow", () => {
  assert.doesNotThrow(() => orchestratorGate({ tool: "write", args: { filePath: "/s/skills/foo/SKILL.md", content: "# Phase 1\njust a simple skill" }, fs }));
});

test("nested skill path is gated (parity with bash */skills/*/skill.md)", () => {
  // bash glob `*` spans `/`, so a nested middle segment must still be gated.
  assert.throws(() => orchestratorGate({ tool: "write", args: { filePath: "/s/skills/foo/bar/SKILL.md", content: "orchestrator_skill: true\n# Phase 1" }, fs }), BlockError);
});

test("Windows backslash skill path is normalized and gated", () => {
  assert.throws(() => orchestratorGate({ tool: "write", args: { filePath: "C:\\s\\skills\\foo\\SKILL.md", content: "orchestrator_skill: true\n# Phase 1" }, fs }), BlockError);
});
