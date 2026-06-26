// opencode-harness/plugin/lib/worktree.js
// spec §16.B — worktree teardown SUBSTITUTE: `git worktree prune` ONLY (de-registers
// worktrees whose directory is gone). It NEVER deletes a branch, NEVER removes a live
// worktree, NEVER uses --force. opencode's superpowers flow creates `.worktrees/<arbitrary
// branch>` with no fixed branch convention (and `finishing-a-development-branch` self-cleans),
// so the CC cycle-41 orphan-branch sweep (which relied on a `worktree-*` convention) does NOT
// port safely; pruning dir-gone registrations is the one unconditionally-safe universal op.
// Fully fail-open: never throws; every git call is best-effort. exec(cmd, args) is injected
// (governance.js passes an execFileSync wrapper) so this is unit-testable without spawning git.
export function pruneWorktrees(repo, exec) {
  try {
    if (!repo || typeof exec !== "function") return { ran: false, reason: "no-repo" };
    try {
      exec("git", ["-C", repo, "rev-parse", "--is-inside-work-tree"]);
    } catch {
      return { ran: false, reason: "not-a-repo" }; // also covers git-absent (ENOENT)
    }
    try {
      exec("git", ["-C", repo, "worktree", "prune"]);
      return { ran: true, pruned: true };
    } catch {
      return { ran: true, pruned: false, reason: "prune-failed" };
    }
  } catch {
    return { ran: false, reason: "error" };
  }
}
