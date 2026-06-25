// opencode-harness/plugin/lib/version.js
function parts(v) {
  return String(v).split(".").map((n) => parseInt(n, 10));
}

export function cmpGte(a, b) {
  const pa = parts(a), pb = parts(b);
  if (pa.some(Number.isNaN) || pb.some(Number.isNaN)) return false;
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const x = pa[i] ?? 0, y = pb[i] ?? 0;
    if (x !== y) return x > y;
  }
  return true; // equal
}

// >=1.17.10: the centralized tool wrapper fires tool.execute.before for subagent
// (task-spawned) calls, enabling content-based subagent enforcement (closes R1).
export function subagentEnforced(version) {
  return cmpGte(version, "1.17.10");
}

// The shipped target floor. The bundle's install/verify step asserts the live
// `opencode --version` meets this floor (reliable), so when the runtime SDK
// version probe is unavailable the plugin may assume it (see enforcementFor).
export const VERSION_FLOOR = "1.17.11";

// Resolve the enforcement decision from a best-effort runtime version probe.
// Runtime SDK introspection (client.app.get()) is unreliable in headless mode
// (returns undefined; some sibling getters hang), so on a miss we fall back to
// the install-verified floor and flag `assumed` so the load line stays honest.
export function enforcementFor(detected) {
  const ok = typeof detected === "string" && detected && detected !== "unknown";
  const version = ok ? detected : VERSION_FLOOR;
  return { version, assumed: !ok, enforced: subagentEnforced(version) };
}
