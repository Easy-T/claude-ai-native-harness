// opencode-harness/plugin/lib/skeleton-scan.js
// VERBATIM scanning logic from ~/.claude/hooks/lib/skeleton-scan.js (content → counts).
// Strips HTML comments before counting Agent() calls (S4: commented calls don't satisfy the skeleton).
export function scanSkeleton(content) {
  content = content || "";
  const hasMarker = /^orchestrator_skill: true\s*$/m.test(content) ? 1 : 0;
  const scan = content.replace(/<!--[\s\S]*?-->/g, "");
  const phase = (scan.match(/^# Phase /gm) || []).length;
  const agent = (scan.match(/Agent\(subagent_type=/g) || []).length;
  const contract = (scan.match(/Communication Protocol/g) || []).length;
  return { hasMarker, phase, agent, contract };
}
