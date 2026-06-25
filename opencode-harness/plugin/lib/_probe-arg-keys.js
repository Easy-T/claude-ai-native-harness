// opencode-harness/plugin/lib/_probe-arg-keys.js
// LIVE PROBE (run once per environment, incl. the company box — R2).
// Drop-in plugin that logs the real output.args keys, then remove it.
// Usage: copy to plugin/, run `OPENCODE_CONFIG_DIR=. opencode run "edit any file; run a bash echo"`,
// read the stderr lines, confirm they match ARG_KEYS, then delete this file from plugin/.
export const ArgKeyProbe = async () => ({
  "tool.execute.before": async (input, output) => {
    try {
      console.error(`[probe] ${input.tool} args=${JSON.stringify(Object.keys(output?.args ?? {}))}`);
    } catch {}
  },
});
