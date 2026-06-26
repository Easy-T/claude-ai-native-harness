// opencode-harness/plugin/governance.js
// v1 Promise plugin (function export = most portable load shape). deny = throw BlockError.
// Runs unchanged on opencode 1.17.9 (primary-agent only) and >=1.17.10 (also subagent calls).
import { failOpen } from "./lib/fail-open.js";
import { assertArgKeys } from "./lib/arg-keys.js";
import { enforcementFor } from "./lib/version.js";
import { rpiGate } from "./gates/rpi-gate.js";
import { secretGate } from "./gates/secret-gate.js";
import { orchestratorGate } from "./gates/orchestrator-gate.js";
import * as nodeFs from "node:fs";

export const Governance = async ({ client, directory }) => {
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
  };
};
