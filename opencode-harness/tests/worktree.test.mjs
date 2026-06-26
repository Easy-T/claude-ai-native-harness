// opencode-harness/tests/worktree.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { pruneWorktrees } from "../plugin/lib/worktree.js";

// fake exec(cmd, args): records calls; `fail` set chooses which subcommand throws.
function mkExec(failOn) {
  const calls = [];
  const exec = (cmd, args) => {
    calls.push([cmd, ...args]);
    const sub = args.join(" ");
    if (failOn && sub.includes(failOn)) throw new Error(`boom: ${failOn}`);
    return "";
  };
  return { exec, calls };
}
const flat = (calls) => calls.map((c) => c.join(" "));

test("empty repo → no-op, no exec calls", () => {
  const { exec, calls } = mkExec();
  const r = pruneWorktrees("", exec);
  assert.equal(r.ran, false);
  assert.equal(calls.length, 0);
});

test("non-repo (rev-parse throws) → ran:false, prune NOT attempted", () => {
  const { exec, calls } = mkExec("rev-parse");
  const r = pruneWorktrees("/some/dir", exec);
  assert.equal(r.ran, false);
  assert.ok(!flat(calls).some((c) => c.includes("worktree prune")), "must not prune a non-repo");
});

test("real repo → runs `git -C <repo> worktree prune`, ran:true pruned:true", () => {
  const { exec, calls } = mkExec();
  const r = pruneWorktrees("/repo", exec);
  assert.equal(r.ran, true);
  assert.equal(r.pruned, true);
  assert.ok(flat(calls).includes("git -C /repo rev-parse --is-inside-work-tree"));
  assert.ok(flat(calls).includes("git -C /repo worktree prune"));
});

test("prune failure is swallowed (fail-open): ran:true pruned:false, no throw", () => {
  const { exec } = mkExec("worktree prune");
  let r;
  assert.doesNotThrow(() => { r = pruneWorktrees("/repo", exec); });
  assert.equal(r.ran, true);
  assert.equal(r.pruned, false);
});

test("SAFETY: never deletes a branch or removes a worktree — only prune", () => {
  const { exec, calls } = mkExec();
  pruneWorktrees("/repo", exec);
  const all = flat(calls).join(" | ");
  assert.ok(!/branch\s+-[dD]/.test(all), "must never call git branch -d/-D");
  assert.ok(!/worktree\s+remove/.test(all), "must never call git worktree remove");
  assert.ok(!/--force/.test(all), "must never use --force");
});

test("exec missing entirely (git absent) → fail-open, no throw", () => {
  let r;
  assert.doesNotThrow(() => { r = pruneWorktrees("/repo", () => { throw new Error("ENOENT git"); }); });
  assert.equal(r.ran, false);
});
