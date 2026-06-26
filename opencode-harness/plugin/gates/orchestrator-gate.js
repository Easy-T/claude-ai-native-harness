// opencode-harness/plugin/gates/orchestrator-gate.js
import { BlockError } from "../lib/fail-open.js";
import { scanSkeleton } from "../lib/skeleton-scan.js";
import { normalizePath } from "../lib/code-exts.js";

// opencode scans BOTH `skill/` (singular — the bundle convention per spec §5) and `skills/`
// (plural), so the dir segment is `skills?`. Parity with bash glob `*/skills/*/skill.md`: the
// shell `*` spans `/`, so the middle segment uses `.+` (not `[^/]+`) to also match nested
// skills/foo/bar/skill.md. Gate is opt-in (only fires when the orchestrator marker is present),
// so the broadened match cannot false-positive on a non-orchestrator skill.
const SKILL_PATH = /\/skills?\/.+\/skill\.md$/i;

export function orchestratorGate({ tool, args, fs }) {
  args = args || {};
  const fp = normalizePath(args.filePath || "");
  if (!SKILL_PATH.test(fp)) return;

  let content;
  const t = String(tool || "").toLowerCase();
  if (t === "edit") {
    let cur = "";
    try { cur = fs.readFileSync(fp, "utf8"); } catch { cur = ""; }
    const oldS = args.oldString || "", newS = args.newString || "";
    content = cur ? (oldS && cur.indexOf(oldS) >= 0 ? cur.replace(oldS, newS) : cur) : newS;
  } else {
    content = (typeof args.content === "string" && args.content) ? args.content : (args.newString || "");
  }
  if (!content) return;

  const { hasMarker, phase, agent, contract } = scanSkeleton(content);
  if (hasMarker !== 1) return; // opt-out

  let reason = "";
  if (phase < 3) reason = `phase=${phase}<3`;
  else if (agent < 1) reason = "agent_calls=0";
  else if (contract < 1) reason = "no-protocol-section";
  if (reason) {
    throw new BlockError(`[orchestrator] FAIL: ${reason}. Phase≥3 / Agent(subagent_type=)≥1 / Communication Protocol≥1. create-orchestrator-skill 사용 또는 frontmatter에서 orchestrator_skill 제거.`);
  }
}
