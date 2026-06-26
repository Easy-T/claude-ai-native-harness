// opencode-harness/plugin/gates/rpi-gate.js
import { BlockError } from "../lib/fail-open.js";
import { isCodePath, codeExtRegexSource } from "../lib/code-exts.js";
import { hasActivePlan } from "../lib/plan-status.js";
import { extractRedirectTarget } from "../lib/redirect-targets.js";

const NONCODE_WHITELIST = /(\.(md|txt|gitignore)|\/CLAUDE\.md|\/README(\.(rst|adoc|markdown|org))?|\/\.gitkeep)$/i;
const CONFIG_DIR = /\/(\.claude|docs|\.github)\//;
const lineCount = (s) => (s ? String(s).split(/\r?\n/).length : 0);

// fs = {readdirSync, readFileSync} ; injected for testability.
export function rpiGate({ tool, args, cwd, env, fs }) {
  args = args || {};
  env = env || {};
  const t = String(tool || "").toLowerCase();

  if (t === "bash") {
    const cmd = args.command || "";
    if (!cmd) return;
    if (env.RPI_SKIP) return;
    // fail-open: a parser exception must surface upstream (failOpen logs FAILOPEN), not silently allow here.
    const target = extractRedirectTarget(cmd, codeExtRegexSource());
    if (!target) return;
    if (hasActivePlan(cwd, fs)) return;
    throw new BlockError(
      target === "__PATCH_APPLY__"
        ? "[rpi] 차단: git apply/patch 로 코드 변경 — 활성 plan 없음 (보수 차단). RPI_SKIP 로 우회."
        : `[rpi] 차단: 셸로 코드 파일 쓰기(${target}) — 활성 plan 없음. start-rpi-cycle 로 R→P 완료 또는 RPI_SKIP.`,
    );
  }

  // path tools (edit/write/apply_patch/notebook)
  const fp = args.filePath || args.notebookPath || "";
  if (!fp) return;

  // (a) spec-before-plan
  if (/\/docs\/superpowers\/plans\/.*\.md$/.test(fp) && !env.RPI_SKIP) {
    let specs = [];
    try { specs = fs.readdirSync(`${cwd}/docs/superpowers/specs`).filter((f) => f.endsWith(".md")); } catch { specs = []; }
    if (specs.length === 0) {
      throw new BlockError("[rpi] 차단: plan 작성 전 design spec 없음 (docs/superpowers/specs/*.md). Phase R 먼저.");
    }
  }

  // (b) non-code artifact whitelist
  if (NONCODE_WHITELIST.test(fp)) return;

  // (c) code-ext gets no dir exemption; non-code config/doc dirs pass
  if (!isCodePath(fp)) {
    if (CONFIG_DIR.test(fp)) return;
  }

  // (d) trivial ≤5 lines (MAX of old/new or content)
  const changed = Math.max(lineCount(args.oldString), lineCount(args.newString), lineCount(args.content));
  if (changed > 0 && changed <= 5) return;

  // (e) explicit skip
  if (env.RPI_SKIP) return;

  // (f) active-plan check
  let plansExist = true;
  try { fs.readdirSync(`${cwd}/docs/superpowers/plans`); } catch { plansExist = false; }
  if (!plansExist) throw new BlockError("[rpi] 차단: docs/superpowers/plans/ 디렉터리 없음. start-rpi-cycle 로 시작.");
  if (hasActivePlan(cwd, fs)) return;
  throw new BlockError("[rpi] 차단: 활성 plan 없음 (**Status:** active). start-rpi-cycle 로 R→P 완료. trivial(≤5) 또는 docs 변경은 허용.");
}
