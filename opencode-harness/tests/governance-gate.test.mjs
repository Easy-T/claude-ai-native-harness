// opencode-harness/tests/governance-gate.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Governance } from "../plugin/governance.js";

async function gateFor(cwd) {
  const hooks = await Governance({ client: {}, directory: cwd });
  return hooks["tool.execute.before"];
}
function mkProj(active) {
  const dir = mkdtempSync(join(tmpdir(), "ogov-"));
  mkdirSync(join(dir, "docs/superpowers/plans"), { recursive: true });
  mkdirSync(join(dir, "docs/superpowers/specs"), { recursive: true });
  writeFileSync(join(dir, "docs/superpowers/specs/s.md"), "# spec\n");
  writeFileSync(join(dir, "docs/superpowers/plans/p.md"), active ? "**Status:** active\n" : "**Status:** completed\n");
  return dir;
}

test("composed gate: no-plan code write rejects; secret rejects; clean allows", async () => {
  const noplan = mkProj(false);
  const gate = await gateFor(noplan);
  await assert.rejects(() => gate({ tool: "write" }, { args: { filePath: join(noplan, "x.py"), content: "a\nb\nc\nd\ne\nf\n" } }));
  await assert.rejects(() => gate({ tool: "write" }, { args: { filePath: join(noplan, "ok.md"), content: "key=" + "AKIA" + "ABCDEFGHIJKLMNOP" } }));
  await assert.doesNotReject(() => gate({ tool: "write" }, { args: { filePath: join(noplan, "ok.md"), content: "hello" } }));
  rmSync(noplan, { recursive: true, force: true });
});

test("composed gate: active plan permits code write", async () => {
  const ok = mkProj(true);
  const gate = await gateFor(ok);
  await assert.doesNotReject(() => gate({ tool: "write" }, { args: { filePath: join(ok, "x.py"), content: "a\nb\nc\nd\ne\nf\n" } }));
  rmSync(ok, { recursive: true, force: true });
});
