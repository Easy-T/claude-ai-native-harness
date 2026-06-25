// opencode-harness/plugin/lib/fail-open.js
export class BlockError extends Error {
  constructor(message) {
    super(message);
    this.name = "BlockError";
  }
}

// Wrap a hook body so ONLY a BlockError denies. Any other failure of the
// governance code itself must never block the user's work (invariant 39).
export function failOpen(fn) {
  return async (input, output) => {
    try {
      await fn(input, output);
    } catch (err) {
      if (err instanceof BlockError) throw err; // deny propagates
      // fail-open: swallow our own malfunction, surface it, allow the tool
      try { console.error(`[harness] FAILOPEN ${input?.tool ?? "?"}: ${err?.message ?? err}`); } catch {}
    }
  };
}
