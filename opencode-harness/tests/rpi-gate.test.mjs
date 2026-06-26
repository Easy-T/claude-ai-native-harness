// opencode-harness/tests/rpi-gate.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { rpiGate } from "../plugin/gates/rpi-gate.js";
import { BlockError } from "../plugin/lib/fail-open.js";

const activeFs = { readdirSync: () => ["p.md"], readFileSync: () => "**Status:** active\n" };
const noPlanFs = { readdirSync: () => ["p.md"], readFileSync: () => "**Status:** completed\n" };
const base = { cwd: "/proj", env: {}, fs: activeFs };
const blocks = (fn) => assert.throws(fn, BlockError);
const allows = (fn) => assert.doesNotThrow(fn);

test("write code with active plan allows; without plan blocks", () => {
  allows(() => rpiGate({ ...base, tool: "write", args: { filePath: "/proj/x.py", content: "a\nb\nc\nd\ne\nf\n" } }));
  blocks(() => rpiGate({ ...base, fs: noPlanFs, tool: "write", args: { filePath: "/proj/x.py", content: "a\nb\nc\nd\ne\nf\n" } }));
});

test("docs and trivial edits allow even without a plan", () => {
  allows(() => rpiGate({ ...base, fs: noPlanFs, tool: "write", args: { filePath: "/proj/notes.md", content: "x" } }));
  allows(() => rpiGate({ ...base, fs: noPlanFs, tool: "edit", args: { filePath: "/proj/x.py", oldString: "a", newString: "b" } }));
});

test("bash redirect to code without plan blocks; with plan allows; md allows", () => {
  blocks(() => rpiGate({ ...base, fs: noPlanFs, tool: "bash", args: { command: "echo x > y.py" } }));
  allows(() => rpiGate({ ...base, tool: "bash", args: { command: "echo x > y.py" } }));
  allows(() => rpiGate({ ...base, fs: noPlanFs, tool: "bash", args: { command: "echo x > y.md" } }));
});

test("RPI_SKIP and spec-before-plan", () => {
  allows(() => rpiGate({ ...base, fs: noPlanFs, env: { RPI_SKIP: "hotfix" }, tool: "write", args: { filePath: "/proj/x.py", content: "a\nb\nc\nd\ne\nf\n" } }));
  const noSpecFs = { readdirSync: (d) => d.endsWith("specs") ? [] : ["q.md"], readFileSync: () => "**Status:** completed\n" };
  blocks(() => rpiGate({ ...base, fs: noSpecFs, tool: "write", args: { filePath: "/proj/docs/superpowers/plans/new.md", content: "x" } }));
});
