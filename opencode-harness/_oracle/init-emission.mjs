// opencode-harness/_oracle/init-emission.mjs
// BUILD-BOX ONLY. Renders the init-ai-ready-project templates with sample placeholder values and
// asserts the emitted opencode-TARGET project is valid (AGENTS.md compass + opencode.json deny-gate
// + ai-context docs). Mirrors what the skill's Phase 2/3 produces, so a broken template is caught
// before ship. Offline, non-destructive (renders into a temp dir, removed at exit).
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { tmpdir } from "node:os";

const SKILL = join(import.meta.dirname, "..", "skill", "init-ai-ready-project");
const TPL = join(SKILL, "templates");
let fails = 0;
const fail = (m) => { fails++; console.error("FAIL " + m); };

// tpl filename -> output path (relative to project root). 12 files (spec §18).
const FILES = {
  "AGENTS.md.tpl": "AGENTS.md",
  "architecture.md.tpl": "docs/ai-context/architecture.md",
  "runbook.md.tpl": "docs/ai-context/runbook.md",
  "deny-patterns.md.tpl": "docs/ai-context/deny-patterns.md",
  "non-obvious.md.tpl": "docs/ai-context/non-obvious.md",
  "domain-glossary.md.tpl": "docs/ai-context/domain-glossary.md",
  "project-opencode.json.tpl": "opencode.json",
  ".gitignore.tpl": ".gitignore",
  "state.json.tpl": "state.json",
  "scripts-check.sh.tpl": "scripts/check.sh",
  "github-ci.yml.tpl": ".github/workflows/ci.yml",
  "CONTEXT.md.tpl": "CONTEXT.md",
};

// sample substitution map (mirrors references/placeholder-spec.md bootstrap defaults).
const VARS = {
  PROJECT_NAME: "sample-proj",
  CREATED_AT: "2026-06-27",
  STACK_DESCRIPTION: "Node.js + npm",
  STACK_GITIGNORE: "coverage/",
  MODULES_INDEX: "(아직 모듈 없음)",
  DEPENDENCY_DIAGRAM: '_initial_["empty"]',
  DATA_FLOW_DESCRIPTION: "(미정의)",
  DEPLOY_PROCEDURE: "(아직 정의되지 않음)",
  ROLLBACK_PROCEDURE: "(아직 정의되지 않음)",
  INCIDENT_RESPONSE: "(아직 정의되지 않음)",
  DASHBOARDS: "(아직 정의되지 않음)",
  CHECK_COMMANDS: 'echo "No checks configured."',
  LOCAL_CHECK_COMMAND: "bash scripts/check.sh",
};

// minimal mustache render: strip {{#list}}...{{/list}} blocks (empty, name-matched via backref),
// then substitute {{VAR}}. Unknown {{VAR}} are left intact so the leak check fails-closed.
function render(src) {
  let out = src.replace(/\{\{#([A-Z_]+)\}\}[\s\S]*?\{\{\/\1\}\}\r?\n?/g, "");
  out = out.replace(/\{\{([A-Z_]+)\}\}/g, (m, k) =>
    Object.prototype.hasOwnProperty.call(VARS, k) ? VARS[k] : m);
  return out;
}

const tpls = readdirSync(TPL).filter((f) => f.endsWith(".tpl"));
// every template must be mapped to an output (no orphan template ships unused).
for (const t of tpls) if (!FILES[t]) fail(`unmapped template (renders to nothing): ${t}`);
for (const t of Object.keys(FILES)) if (!existsSync(join(TPL, t))) fail(`missing template: ${t}`);

const root = join(tmpdir(), "init-emit-" + process.pid);
rmSync(root, { recursive: true, force: true });
try {
  for (const [t, rel] of Object.entries(FILES)) {
    if (!existsSync(join(TPL, t))) continue;
    const rendered = render(readFileSync(join(TPL, t), "utf8"));
    const dest = join(root, rel);
    mkdirSync(dirname(dest), { recursive: true });
    writeFileSync(dest, rendered);
    if (/\{\{[^}]*\}\}/.test(rendered)) fail(`placeholder leakage in ${rel}: ${rendered.match(/\{\{[^}]*\}\}/)[0]}`);
  }

  // --- assertions on the emitted opencode-target project ---
  const read = (rel) => readFileSync(join(root, rel), "utf8");

  // AGENTS.md: present, <=200 lines, pointers to ai-context.
  const agents = read("AGENTS.md");
  if (agents.split(/\r?\n/).length > 200) fail("AGENTS.md > 200 lines");
  for (const p of ["deny-patterns.md", "architecture.md", "runbook.md", "domain-glossary.md"])
    if (!agents.includes(p)) fail(`AGENTS.md missing pointer to ${p}`);

  // opencode.json: parses, $schema, permission.bash deny entries.
  let cfg;
  try { cfg = JSON.parse(read("opencode.json")); } catch (e) { fail("opencode.json not valid JSON: " + e.message); cfg = {}; }
  if (cfg["$schema"] !== "https://opencode.ai/config.json") fail("opencode.json missing/wrong $schema");
  const bash = cfg.permission && cfg.permission.bash;
  if (!bash || typeof bash !== "object") fail("opencode.json permission.bash is not a deny map");
  else {
    // hard-blocked bash-shaped universal commands (the enforceable subset; spec §18 honest-substitute).
    for (const k of ["rm -rf *", "rm -fr *", "rm -rf ~*", "git push --force *", "npm publish*", "yarn publish*", "pnpm publish*"])
      if (bash[k] !== "deny") fail(`opencode.json permission.bash["${k}"] != deny (got ${JSON.stringify(bash[k])})`);
    if (bash["*"] !== "allow") fail('opencode.json permission.bash["*"] != allow (default)');
    // the SAFE force variant must NOT be denied (--force-with-lease is the recommended one).
    if (bash["git push --force-with-lease*"] === "deny") fail("opencode.json denies the safe --force-with-lease (should be allowed)");
  }

  // deny-patterns.md: >=8 "- ❌ " markers.
  const denyMarks = (read("docs/ai-context/deny-patterns.md").match(/^- ❌ /gm) || []).length;
  if (denyMarks < 8) fail(`deny-patterns.md has only ${denyMarks} ❌ markers (< 8)`);

  // state.json: schema_version=1, cycle.count=0.
  let st;
  try { st = JSON.parse(read("state.json")); } catch (e) { fail("state.json not valid JSON: " + e.message); st = {}; }
  if (st.schema_version !== 1) fail(`state.json schema_version != 1 (got ${JSON.stringify(st.schema_version)})`);
  if (!st.cycle || st.cycle.count !== 0) fail(`state.json cycle.count != 0 (got ${JSON.stringify(st.cycle)})`);

  // non-obvious marker + runbook sections + gitignore length.
  if (!read("docs/ai-context/non-obvious.md").includes("아직 비어 있음")) fail("non-obvious.md missing empty-marker text");
  const rb = read("docs/ai-context/runbook.md");
  if (!rb.includes("Local Quality Gate")) fail("runbook.md missing 'Local Quality Gate'");
  if (!rb.includes("Merge Policy")) fail("runbook.md missing 'Merge Policy'");
  if (read(".gitignore").split(/\r?\n/).length < 15) fail(".gitignore < 15 lines");

  // no CC-specific .claude/ path in ANY emitted opencode file (opencode uses .opencode/ + opencode.json).
  for (const rel of Object.values(FILES))
    if (read(rel).includes(".claude/")) fail(`CC-specific ".claude/" path leaked into emitted ${rel} (opencode-target must use .opencode/ or opencode.json)`);

  // honest-substitute disclosure must be present (spec §18): the static gate is a best-effort SUBSET,
  // the broader deny-patterns policy is advisory. Lock it so the honesty can't be silently dropped.
  const dp = read("docs/ai-context/deny-patterns.md");
  if (!/best-effort/.test(dp) || !/advisory/.test(dp))
    fail("deny-patterns.md missing honest enforcement-scope disclosure (must state the gate is best-effort + broader policy is advisory)");
  if (!/advisory|best-effort/.test(agents))
    fail("AGENTS.md missing the deny-gate scope qualifier (must not imply the full deny list is enforced)");
} finally {
  rmSync(root, { recursive: true, force: true });
}

console.log(fails === 0 ? `OK init-emission (${Object.keys(FILES).length} files rendered, 0 violations)` : `FAIL init-emission ${fails} violation(s)`);
process.exit(fails === 0 ? 0 : 1);
