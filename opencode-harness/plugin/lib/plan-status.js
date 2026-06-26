// opencode-harness/plugin/lib/plan-status.js
// plan_status / has_active_plan twins from ~/.claude/hooks/_common.sh.
// Only BOLD `**Status:**` in the head-20 lines counts; code fences are skipped
// (cycle-26 seal: prose 'Status: active' must NOT open the gate). First word, lowercased.
export function planStatus(text) {
  const lines = String(text ?? "").split(/\r?\n/).slice(0, 20);
  let fence = false;
  for (const line of lines) {
    if (/^\s*(```|~~~)/.test(line)) { fence = !fence; continue; }
    if (fence) continue;
    const m = line.match(/^\*\*[Ss]tatus:\**\s*(.*)$/);
    if (m) {
      const first = m[1].replace(/\*/g, "").trim().split(/\s+/)[0] || "";
      return first.toLowerCase();
    }
  }
  return "";
}

// has_active_plan twin: scan <cwd>/docs/superpowers/plans/*.md for the first plan whose
// status is active|in_progress. fsLike = {readdirSync, readFileSync}. Returns path or null.
// Fail-safe: any fs error (missing dir, unreadable file) → treated as "no active plan".
export function hasActivePlan(cwd, fsLike) {
  const dir = `${cwd}/docs/superpowers/plans`;
  let entries;
  try { entries = fsLike.readdirSync(dir); } catch { return null; }
  for (const name of entries) {
    if (!name.endsWith(".md")) continue;
    const path = `${dir}/${name}`;
    let body = "";
    try { body = fsLike.readFileSync(path, "utf8"); } catch { continue; }
    const st = planStatus(body);
    if (st === "active" || st === "in_progress") return path;
  }
  return null;
}
