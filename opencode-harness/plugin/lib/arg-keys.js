// opencode-harness/plugin/lib/arg-keys.js
// Frozen result of the live arg-key probe against opencode 1.17.9 (see _probe-arg-keys.js).
// Re-validated at plugin startup by assertArgKeys (R2: a wrong key silently disables a gate).
export const ARG_KEYS = Object.freeze({
  edit: "filePath",
  write: "filePath",
  apply_patch: "filePath",
  bash: "command",
});

// Secondary keys carrying mutable content (for content-scan gates in later plans).
export const CONTENT_KEYS = Object.freeze(["content", "oldString", "newString"]);

export function pathArg(tool, args) {
  const key = ARG_KEYS[tool];
  return key ? args?.[key] : undefined;
}

// Returns the list of tools whose expected primary key is absent in the sample.
// Empty array = shapes match. Non-empty = ALERT (fail-loud) at startup.
export function assertArgKeys(samples) {
  const missing = [];
  for (const { tool, args } of samples) {
    const key = ARG_KEYS[tool];
    if (key && !(args && key in args)) missing.push(tool);
  }
  return missing;
}
