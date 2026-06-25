// opencode-harness/plugin/governance.js
// v1 Promise plugin (function export = most portable load shape). deny = throw BlockError.
// Runs unchanged on opencode 1.17.9 (primary-agent only) and >=1.17.10 (also subagent calls).
import { failOpen, BlockError } from "./lib/fail-open.js";
import { ARG_KEYS, assertArgKeys, pathArg } from "./lib/arg-keys.js";
import { enforcementFor } from "./lib/version.js";

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
      // Plan 1: no gates yet — resolve the path/command for later gates and allow.
      void pathArg(input.tool, output?.args ?? {});
      void ARG_KEYS; void BlockError; // referenced; real gates land in plan 2
    }),
  };
};
