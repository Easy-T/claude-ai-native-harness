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
