// opencode-harness/tests/permission-floor.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

// minimal YAML-frontmatter permission extractor (avoids a yaml dep)
function frontmatterPermission(file) {
  const t = readFileSync(join(ROOT, "agent", file), "utf8");
  const fm = t.match(/^---\n([\s\S]*?)\n---/);
  assert.ok(fm, `no frontmatter in ${file}`);
  return fm[1];
}

test("explore-strict denies all mutation + task, allows read tools", () => {
  const p = frontmatterPermission("explore-strict.md");
  assert.match(p, /mode:\s*subagent/);
  for (const k of ["edit", "write", "apply_patch", "bash", "task"]) assert.match(p, new RegExp(`${k}:\\s*deny`));
});

test("execute-strict allows mutation but denies task (no self-spawn, inv 21)", () => {
  const p = frontmatterPermission("execute-strict.md");
  assert.match(p, /task:\s*deny/);
  for (const k of ["edit", "write", "bash"]) assert.match(p, new RegExp(`${k}:\\s*allow`));
});

test("review-strict denies edits, gates bash (ask) with rm/redirect denied", () => {
  const p = frontmatterPermission("review-strict.md");
  for (const k of ["edit", "write", "apply_patch", "task"]) assert.match(p, new RegExp(`${k}:\\s*deny`));
  assert.match(p, /"rm \*":\s*deny/);
  assert.match(p, /"\* > \*":\s*deny/);
});

test("global opencode.json permission block exists (last-match-wins ordering)", () => {
  const cfg = JSON.parse(readFileSync(join(ROOT, "opencode.json"), "utf8"));
  assert.ok(cfg.permission.edit, "global edit permission must be explicit");
});
