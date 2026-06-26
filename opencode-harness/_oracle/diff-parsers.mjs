// opencode-harness/_oracle/diff-parsers.mjs
// BUILD-BOX ONLY. Differential conformance: refactored plugin libs must produce identical
// output to the SOURCE ~/.claude/hooks node parsers (C′ keystone). Exit 1 on any mismatch.
import { execFileSync } from "node:child_process";
import { extractRedirectTarget } from "../plugin/lib/redirect-targets.js";
import { scanSkeleton } from "../plugin/lib/skeleton-scan.js";
import { codeExtRegexSource } from "../plugin/lib/code-exts.js";

const HOME = process.env.HOME || process.env.USERPROFILE;
const SRC_REDIR = `${HOME}/.claude/hooks/lib/redirect-targets.js`;
const SRC_SKEL = `${HOME}/.claude/hooks/lib/skeleton-scan.js`;
const RE = codeExtRegexSource();
let fails = 0;
const eq = (label, a, b) => { if (a !== b) { fails++; console.error(`DIFF ${label}: lib=${JSON.stringify(a)} src=${JSON.stringify(b)}`); } };

// --- redirect-targets: lib fn vs source CLI (env CMD + CODE_EXT_REGEX) ---
const REDIR_CASES = [
  "echo x > out.py", "echo x >> a.sh", "cat > foo.js <<EOF", "echo x | tee -a bar.rb",
  "echo 'a > b.py'", "x=$(f -> g.py)", "ls 2>&1", "echo x >& evil.py",
  "sed -i 's/a/b/' z.go", "cp src dst.py", "cat setup/install.sh other",
  "install -m 0755 a.sh /usr/bin/a.sh", "git apply patch.diff", "git apply --check p.diff",
  "ls -la", "echo hi > notes.md", "dd if=x of=y.py",
];
for (const cmd of REDIR_CASES) {
  const lib = extractRedirectTarget(cmd, RE);
  let src = "";
  try { src = execFileSync("node", [SRC_REDIR], { env: { ...process.env, CMD: cmd, CODE_EXT_REGEX: RE }, encoding: "utf8" }); } catch (e) { src = `ERR:${e.status}`; }
  eq(`redir ${JSON.stringify(cmd)}`, lib, src);
}

// --- skeleton-scan: lib fn vs source CLI (stdin INPUT + FP) for the Write content path ---
const SKEL_CASES = [
  "orchestrator_skill: true\n# Phase 1\n# Phase 2\n# Phase 3\nAgent(subagent_type=x)\nCommunication Protocol",
  "orchestrator_skill: true\n<!-- Agent(subagent_type=x) -->\n# Phase 1",
  "# Phase 1\njust a simple skill",
];
for (const content of SKEL_CASES) {
  const s = scanSkeleton(content);
  const lib = `${s.hasMarker} ${s.phase} ${s.agent} ${s.contract}`;
  const input = JSON.stringify({ tool_name: "Write", tool_input: { content } });
  let src = "";
  try { src = execFileSync("node", [SRC_SKEL], { input, env: { ...process.env, FP: "/x/skills/foo/SKILL.md" }, encoding: "utf8" }); } catch (e) { src = `ERR:${e.status}`; }
  eq(`skel ${JSON.stringify(content.slice(0, 24))}`, lib, src);
}

console.log(fails === 0 ? `OK diff==0 (${REDIR_CASES.length + SKEL_CASES.length} cases)` : `FAIL ${fails} mismatch(es)`);
process.exit(fails === 0 ? 0 : 1);
