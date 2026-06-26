// opencode-harness/plugin/governance.js
// v1 Promise plugin (function export = most portable load shape). deny = throw BlockError.
// Runs unchanged on opencode 1.17.9 (primary-agent only) and >=1.17.10 (also subagent calls).
import { failOpen } from "./lib/fail-open.js";
import { assertArgKeys } from "./lib/arg-keys.js";
import { enforcementFor } from "./lib/version.js";
import { rpiGate } from "./gates/rpi-gate.js";
import { secretGate } from "./gates/secret-gate.js";
import { orchestratorGate } from "./gates/orchestrator-gate.js";
import { advisoriesFor, NATIVE_TOOLS } from "./lib/advisories.js";
import { pruneWorktrees } from "./lib/worktree.js";
import * as nodeFs from "node:fs";
import { execFileSync } from "node:child_process";

export const Governance = async ({ client, directory, worktree }) => {
  // One-time version + arg-key self-test (R2: fail LOUD if arg shape drifted).
  // Best-effort runtime version probe, timeout-guarded: the SDK app getter returns
  // undefined in headless mode and some sibling getters hang. On a miss,
  // enforcementFor() falls back to the install-verified floor (honest `assumed`).
  let detected = null;
  try {
    const appInfo = await Promise.race([
      Promise.resolve().then(() => client?.app?.get?.()),
      new Promise((res) => setTimeout(() => res(undefined), 1500)),
    ]);
    detected = appInfo?.version ?? null;
  } catch {}
  const { version, assumed, enforced } = enforcementFor(detected);
  console.error(`[harness] loaded — opencode ${version}${assumed ? " (assumed; floor verified at install)" : ""}; subagent-enforced=${enforced}; cwd=${directory ?? "?"}`);

  // Worktree teardown substitute (spec §16.B): prune dir-gone worktree registrations. The git
  // wrapper is best-effort; pruneWorktrees never throws. Runs at init (session-start analog —
  // cleans a prior crashed run) and again on dispose (end-of-instance analog). worktree = repo
  // root (directory may be a subdir); fall back to directory.
  const repoRoot = worktree ?? directory;
  const exec = (cmd, args) => execFileSync(cmd, args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
  try { pruneWorktrees(repoRoot, exec); } catch {}

  const seenAdvisory = new Set(); // `${sessionID}:${kind}` — once-per-session advisory dedup
  let selfTested = false;
  const selfTest = (input, output) => {
    if (selfTested) return;
    selfTested = true;
    const missing = assertArgKeys([{ tool: input.tool, args: output?.args ?? {} }]);
    if (missing.length) {
      console.error(`[harness] ALERT arg-key drift for ${missing.join(",")} — gates may be disabled (R2). Re-run the arg-key probe.`);
    }
  };

  return {
    "tool.execute.before": failOpen(async (input, output) => {
      selfTest(input, output);
      const tool = input?.tool;
      const args = output?.args ?? {};
      const ctx = { tool, args, cwd: directory ?? ".", env: process.env, fs: nodeFs };
      // order: secret (content) → rpi (plan-gate) → orchestrator (skeleton). First BlockError denies.
      secretGate(ctx);
      rpiGate(ctx);
      orchestratorGate(ctx);
    }),
    // Non-blocking advisories appended to the model-visible native-tool result (spec §16.A).
    // Mutating output.output reaches the model only for NATIVE tools (MCP uses a separate object).
    "tool.execute.after": failOpen(async (input, output) => {
      const tool = String(input?.tool ?? "").toLowerCase();
      if (!NATIVE_TOOLS.has(tool)) return;
      // Append only to a string result — never coerce a structured `output` field (the `+`
      // would stringify it). Only native-tool string output reaches the model (spec §16.A).
      if (output.output != null && typeof output.output !== "string") return;
      // Once-per-session dedup. If sessionID is absent (not in the documented after-shape),
      // fall back to callID so the advisory RE-FIRES per call rather than collapsing every
      // session into one "unknown" bucket that would silently suppress it (review fix).
      const sid = input?.sessionID || input?.callID || "anon";
      for (const a of advisoriesFor({ tool, args: input?.args ?? {}, env: process.env })) {
        const key = `${sid}:${a.kind}`;
        if (seenAdvisory.has(key)) continue;
        seenAdvisory.add(key);
        output.output = (output.output ?? "") + "\n\n[harness] " + a.text;
      }
    }),
    // End-of-instance teardown analog (spec §16.B). Fail-open; never blocks shutdown.
    dispose: async () => { try { pruneWorktrees(repoRoot, exec); } catch {} },
  };
};
