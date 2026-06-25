// opencode-harness/plugin/governance.js
// v1 Promise plugin (function export = most portable load shape). deny = throw BlockError.
// Runs unchanged on opencode 1.17.9 (primary-agent only) and >=1.17.10 (also subagent calls).
import { failOpen, BlockError } from "./lib/fail-open.js";
import { ARG_KEYS, assertArgKeys, pathArg } from "./lib/arg-keys.js";
import { subagentEnforced } from "./lib/version.js";

export const Governance = async ({ client, directory }) => {
  // One-time version + arg-key self-test (R2: fail LOUD if arg shape drifted).
  let version = "unknown";
  try { version = (await client?.app?.get())?.version ?? "unknown"; } catch {}
  const enforced = subagentEnforced(version);
  console.error(`[harness] loaded — opencode ${version}; subagent-enforced=${enforced}; cwd=${directory ?? "?"}`);

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
