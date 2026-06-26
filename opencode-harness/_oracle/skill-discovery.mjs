// opencode-harness/_oracle/skill-discovery.mjs
// BUILD-BOX ONLY. Mirrors opencode's skill discovery rules (src/skill/index.ts) so we catch
// a non-discoverable skill (missing description, name/folder mismatch, bad charset) before ship.
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, basename } from "node:path";

const ROOT = join(import.meta.dirname, "..", "skill");
const NAME_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/; // lowercase alnum + single hyphens
let fails = 0, count = 0;
const names = new Map();
const fail = (m) => { fails++; console.error("FAIL " + m); };

function walk(dir) {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    const st = statSync(p);
    if (st.isDirectory()) { walk(p); continue; }
    if (e === "package.json" || e === "package-lock.json" || e.startsWith("bun.lock")) fail(`shippable install trigger: ${p}`);
    if (e !== "SKILL.md") continue;
    count++;
    const body = readFileSync(p, "utf8");
    const fm = body.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    if (!fm) { fail(`no frontmatter: ${p}`); continue; }
    const name = (fm[1].match(/^name:\s*(.+)$/m) || [])[1]?.trim();
    const desc = (fm[1].match(/^description:\s*(.+)$/m) || [])[1]?.trim();
    if (!name) fail(`no name: ${p}`);
    if (!desc) fail(`no description (skill is silently dropped): ${p}`);
    if (name && !NAME_RE.test(name)) fail(`bad name charset '${name}': ${p}`);
    if (name && basename(dir) !== name) fail(`folder!=name ('${basename(dir)}' vs '${name}'): ${p}`);
    if (/https?:\/\//.test(fm[1])) fail(`http(s) in frontmatter (network): ${p}`);
    if (name) { if (names.has(name)) fail(`duplicate name '${name}'`); names.set(name, p); }
  }
}

const MIN_SKILLS = 20; // ship floor: 14 superpowers + 6 custom (spec §17). Fewer = broken/incomplete tree.
if (!existsSync(ROOT)) { console.error("no skill/ dir"); process.exit(1); }
walk(ROOT);
if (count < MIN_SKILLS) fail(`only ${count} skills discoverable (< ${MIN_SKILLS} floor) — skill tree incomplete`);
console.log(fails === 0 ? `OK ${count} skills discoverable, 0 violations` : `FAIL ${fails} violation(s) across ${count} skills`);
process.exit(fails === 0 ? 0 : 1);
