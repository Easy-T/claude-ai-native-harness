# opencode Harness — Plan 2: L2 Enforcement Gates + Differential Oracle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed (offline-verified + adversarial-review-fixed + live-verified, 2026-06-26)
**RPI-Cycle:** 43 (opencode-harness migration — plan 2 of 5)
**Started:** 2026-06-26

**Verification (2026-06-26):** unit **63/63**, differential oracle **diff==0 (20 cases)**. A 5-agent adversarial review (442k tok) confirmed 4 real gate-parity gaps → all fixed (commit 221ccca): backslash `normalizePath` (Windows spec-before-plan bypass, MAJOR), `lineCount` awk-NR parity (trailing-newline ≤5 window), orchestrator `SKILL_PATH` `.+` (bash `*` spans `/`), secret-gate added-content-only (drop oldString). Stray Plan-1 `_probe-arg-keys.js` removed. **Live opencode 1.17.11** (4 checks): A2 no-plan 8-line code write → **BLOCKED**; C2 active-plan write → **ALLOWED**; B `echo > evil.py` bash-redirect no-plan → **BLOCKED** (the plan-1 §13 bypass, sealed live); trivial 1-line write → allowed (exemption works). Full record in spec §14.

**Goal:** Port the `~/.claude` L2 dynamic enforcement (the actual `tool.execute.before` throw gate) into the opencode plugin: the RPI plan-gate (Edit/Write/NotebookEdit + Bash side-door), the secret-scan gate, and the orchestrator-skeleton gate — each backed by Bun-native parser libs refactored byte-for-byte from the harness's node parsers — plus a differential conformance oracle proving the refactored parsers match the bash reference per-case (`diff == ∅`).

**Architecture:** Five pure-function libs under `plugin/lib/` (CODE_EXTS SSOT, plan-status, redirect-targets, skeleton-scan, secret-scan) are reused **verbatim in logic** from `~/.claude/hooks/` (only the I/O envelope changes: env+stdout/stdin → params+return). Three gate modules under `plugin/gates/` compose those libs into deny/allow decisions. `governance.js` dispatches every `tool.execute.before` call by tool name through the gates, wrapped in the Plan-1 `failOpen` envelope (deny = `throw BlockError`). The differential oracle (`_oracle/diff-parsers.mjs`, build-box only) feeds a shared fixture corpus to BOTH the source node CLI parsers and the refactored lib functions, asserting identical output.

**Tech Stack:** opencode v1.17.11 (target) · pure ESM `.js` (zero transpile; runs under opencode's Bun and `node --test`) · Node v24 `node --test` (unit tests) · the existing bash `hooks/tests/run-all.sh` + `hooks/lib/*.js` as the differential reference (build-box only).

## Global Constraints

- **Plugin API = v1 Promise-style** (flat hooks object, function export). deny = `throw BlockError`. **Never `import` `@opencode-ai/plugin/v2/*`**.
- **Pure ESM `.js`** for all plugin + lib code. No transpile, no runtime `node_modules`, no network.
- **Parser logic is VERBATIM from the source** — every regex, tokenizer branch, threshold, and ordering in `redirect-targets.js` / `skeleton-scan.js` / `secret-scan` / `plan_status` / `CODE_EXTS` must be byte-identical to `~/.claude/hooks/lib/*.js` and `_common.sh`. Only the I/O envelope (env/stdin/stdout → function params/return) may change. The differential oracle is the proof.
- **fail-open posture (Plan-1 envelope):** every gate body runs inside `failOpen(...)`; only `BlockError` denies. A parser exception → swallowed → ALLOW, but the crash MUST be surfaced (not silent) per the no-silent-fail-open rule.
- **arg-keys are the frozen SSOT** (`plugin/lib/arg-keys.js` from Plan 1): path tools → `filePath`, bash → `command`, content fields → `["content","oldString","newString"]`. Gates read fields via these keys; the startup self-test catches drift.
- **cwd comes from the plugin context** (`{directory, worktree}`), NOT from input — there is no stdin JSON in opencode.
- **Decision-equivalence, not exit codes:** opencode has no exit-2/stderr-to-model channel. `block` ⇔ `throw BlockError` (deny); `allow` ⇔ return normally. Advisory/`additionalContext` surfacing is Plan 4 — Plan 2 gates only deny or allow.
- **Escape hatches via env:** `RPI_SKIP` and `SECRET_SCAN_SKIP` are read from `process.env` in-plugin (same semantics as the bash hooks).
- **Test fixtures build secrets at RUNTIME** (string concatenation) so no test file holds a literal secret that self-trips the scanner (also: the harness's own secret-scan hook blocks writing such literals).
- Commit after every task. Conventional-commit messages. End commit bodies with the Co-Authored-By trailer.

## File Structure

```
opencode-harness/plugin/
├── lib/
│   ├── code-exts.js        # NEW — CODE_EXTS SSOT + isCodePath(p) + codeExtRegexSource()
│   ├── plan-status.js      # NEW — planStatus(text) + hasActivePlan(cwd, {readdirSync,readFileSync})
│   ├── redirect-targets.js # NEW — extractRedirectTarget(cmd, codeExtRegexSource) [verbatim logic]
│   ├── skeleton-scan.js    # NEW — scanSkeleton(content) → {hasMarker,phase,agent,contract}
│   ├── secret-scan.js      # NEW — scanSecret(text) → kindString | null
│   ├── fail-open.js        # (Plan 1) BlockError + failOpen
│   ├── arg-keys.js         # (Plan 1) ARG_KEYS + CONTENT_KEYS + pathArg
│   └── version.js          # (Plan 1) enforcementFor
├── gates/
│   ├── rpi-gate.js         # NEW — rpiGate({tool,args,cwd,env,fs}) Edit/Write/NotebookEdit + Bash
│   ├── secret-gate.js      # NEW — secretGate({tool,args,env})
│   └── orchestrator-gate.js# NEW — orchestratorGate({tool,args,fs})
└── governance.js           # MODIFY — dispatch tool.execute.before through the 3 gates

opencode-harness/tests/
├── code-exts.test.mjs · plan-status.test.mjs · redirect-targets.test.mjs
├── skeleton-scan.test.mjs · secret-scan.test.mjs
├── rpi-gate.test.mjs · secret-gate.test.mjs · orchestrator-gate.test.mjs
└── governance-gate.test.mjs

opencode-harness/_oracle/
└── diff-parsers.mjs        # NEW — differential oracle: lib fn output === source node CLI output
```

**Interfaces (consumed across tasks):**
- `code-exts.js`: `export const CODE_EXTS` (array); `export function isCodePath(p): boolean`; `export function codeExtRegexSource(): string` (e.g. `"\\.(sh|bash|...|ipynb)$"`).
- `plan-status.js`: `export function planStatus(text): string` (lowercased first word or `""`); `export function hasActivePlan(cwd, fsLike): string|null` (plan path or null). `fsLike = {readdirSync, readFileSync}`.
- `redirect-targets.js`: `export function extractRedirectTarget(cmd, codeExtRegexSource): string` (target | `"__PATCH_APPLY__"` | `""`).
- `skeleton-scan.js`: `export function scanSkeleton(content): {hasMarker:0|1, phase:number, agent:number, contract:number}`.
- `secret-scan.js`: `export function scanSecret(text): string|null` (kind name or null).
- `gates/*`: each exports a function that throws `BlockError` to deny or returns `undefined` to allow.

---

### Task 1: `code-exts.js` — CODE_EXTS SSOT

**Files:**
- Create: `opencode-harness/plugin/lib/code-exts.js`
- Test: `opencode-harness/tests/code-exts.test.mjs`

**Interfaces:**
- Produces: `CODE_EXTS` (array), `isCodePath(p)`, `codeExtRegexSource()` — consumed by `redirect-targets.js`, `rpi-gate.js`.

- [ ] **Step 1: Write the failing test**

```js
// opencode-harness/tests/code-exts.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { CODE_EXTS, isCodePath, codeExtRegexSource } from "../plugin/lib/code-exts.js";

test("CODE_EXTS matches the _common.sh SSOT verbatim", () => {
  assert.equal(CODE_EXTS.join(" "),
    "sh bash zsh py rb js mjs cjs ts tsx jsx go rs php pl ps1 psm1 c cc cpp h hpp java kt swift scala lua sql ipynb");
});

test("isCodePath flags code extensions + Dockerfile, not docs", () => {
  assert.equal(isCodePath("hooks/foo.py"), true);
  assert.equal(isCodePath("a/b/Dockerfile"), true);
  assert.equal(isCodePath("Dockerfile"), true);
  assert.equal(isCodePath("notes.md"), false);
  assert.equal(isCodePath("README"), false);
  assert.equal(isCodePath(""), false);
});

test("codeExtRegexSource builds the JS regex source", () => {
  const re = new RegExp(codeExtRegexSource(), "i");
  assert.equal(re.test("x.py"), true);
  assert.equal(re.test("x.ipynb"), true);
  assert.equal(re.test("x.md"), false);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/code-exts.test.mjs`
Expected: FAIL (module not found).

- [ ] **Step 3: Write the implementation**

```js
// opencode-harness/plugin/lib/code-exts.js
// CODE_EXTS SSOT — byte-identical to ~/.claude/hooks/_common.sh (Write-gate / Bash-gate symmetry).
// Add a language here and BOTH the file-path gate and the shell-redirect gate stay in sync.
export const CODE_EXTS = [
  "sh","bash","zsh","py","rb","js","mjs","cjs","ts","tsx","jsx","go","rs","php",
  "pl","ps1","psm1","c","cc","cpp","h","hpp","java","kt","swift","scala","lua","sql","ipynb",
];

// is_code_path twin: Dockerfile or any CODE_EXTS suffix.
export function isCodePath(p) {
  if (!p) return false;
  if (/(?:^|\/)Dockerfile$/.test(p)) return true;
  return CODE_EXTS.some((ext) => p.endsWith("." + ext));
}

// code_ext_regex twin: `\.(ext1|ext2|...)$` source string (consumed by redirect-targets).
export function codeExtRegexSource() {
  return "\\.(" + CODE_EXTS.join("|") + ")$";
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/code-exts.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/plugin/lib/code-exts.js opencode-harness/tests/code-exts.test.mjs
git commit -m "feat(opencode-harness): code-exts SSOT lib (plan 2 T1)"
```

---

### Task 2: `plan-status.js` — active-plan detection

**Files:**
- Create: `opencode-harness/plugin/lib/plan-status.js`
- Test: `opencode-harness/tests/plan-status.test.mjs`

**Interfaces:**
- Produces: `planStatus(text)`, `hasActivePlan(cwd, fsLike)` — consumed by `rpi-gate.js`.

- [ ] **Step 1: Write the failing test**

```js
// opencode-harness/tests/plan-status.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { planStatus, hasActivePlan } from "../plugin/lib/plan-status.js";

test("planStatus reads bold **Status:** first word, lowercased", () => {
  assert.equal(planStatus("# Plan\n**Status:** Active\n"), "active");
  assert.equal(planStatus("**Status:** completed - cleanup pending"), "completed");
});

test("planStatus ignores prose and fenced examples (cycle-26 seal)", () => {
  assert.equal(planStatus("Status: active\n"), "");          // not bold
  assert.equal(planStatus("```\n**Status:** active\n```\n"), ""); // fenced
  assert.equal(planStatus("~~~\n**Status:** active\n~~~\n"), "");
});

test("hasActivePlan finds an active plan via injected fs", () => {
  const fsLike = {
    readdirSync: () => ["a.md", "b.md"],
    readFileSync: (p) => p.endsWith("b.md") ? "**Status:** active\n" : "**Status:** completed\n",
  };
  const hit = hasActivePlan("/proj", fsLike);
  assert.ok(hit && hit.endsWith("b.md"));
});

test("hasActivePlan returns null when no plan is active / dir missing", () => {
  assert.equal(hasActivePlan("/proj", { readdirSync: () => ["a.md"], readFileSync: () => "**Status:** done\n" }), null);
  assert.equal(hasActivePlan("/proj", { readdirSync: () => { throw new Error("ENOENT"); }, readFileSync: () => "" }), null);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/plan-status.test.mjs`
Expected: FAIL (module not found).

- [ ] **Step 3: Write the implementation**

```js
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/plan-status.test.mjs`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/plugin/lib/plan-status.js opencode-harness/tests/plan-status.test.mjs
git commit -m "feat(opencode-harness): plan-status active-plan detection (plan 2 T2)"
```

---

### Task 3: `redirect-targets.js` — quote-aware shell-write extractor (verbatim refactor)

**Files:**
- Create: `opencode-harness/plugin/lib/redirect-targets.js`
- Test: `opencode-harness/tests/redirect-targets.test.mjs`

**Interfaces:**
- Produces: `extractRedirectTarget(cmd, codeExtRegexSource)` — consumed by `rpi-gate.js` (Bash path) + the differential oracle.
- Consumes: `codeExtRegexSource()` from `code-exts.js`.

**Source of truth:** `~/.claude/hooks/lib/redirect-targets.js`. Copy the body VERBATIM; replace `process.env.CMD` → param `cmd`, `process.env.CODE_EXT_REGEX` → param `codeExtRegexSource`, and the two `process.stdout.write(...); process.exit(0)` early-returns → `return "..."`, and the final `process.stdout.write(hit)` → `return hit || ""`.

- [ ] **Step 1: Write the failing test** (cases mirror the bash oracle: tests 75-77/96-101/110-117/140-142/154-155)

```js
// opencode-harness/tests/redirect-targets.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { extractRedirectTarget } from "../plugin/lib/redirect-targets.js";
import { codeExtRegexSource } from "../plugin/lib/code-exts.js";
const RE = codeExtRegexSource();
const t = (cmd) => extractRedirectTarget(cmd, RE);

test("redirection / tee / heredoc target a code file", () => {
  assert.equal(t("echo x > out.py"), "out.py");
  assert.equal(t("echo x >> a.sh"), "a.sh");
  assert.equal(t("cat > foo.js <<EOF"), "foo.js");
  assert.equal(t("echo x | tee -a bar.rb"), "bar.rb");
});

test("quote-aware + arrow + fd-number guards", () => {
  assert.equal(t("echo 'a > b.py'"), "");      // quoted '>' is not a redirect
  assert.equal(t("x=$(f -> g.py)"), "");        // '->' arrow, not redirect
  assert.equal(t("ls 2>&1"), "");                // fd number, no code ext
  assert.equal(t("echo x >& evil.py"), "evil.py");
});

test("sed -i / cp / mv / dd / install command-position", () => {
  assert.equal(t("sed -i 's/a/b/' z.go"), "z.go");
  assert.equal(t("cp src dst.py"), "dst.py");
  assert.equal(t("cat setup/install.sh other"), "");  // 'install' as path substring, NOT a command
  assert.equal(t("install -m 0755 a.sh /usr/bin/a.sh"), "/usr/bin/a.sh");
});

test("git apply / patch return the conservative sentinel", () => {
  assert.equal(t("git apply patch.diff"), "__PATCH_APPLY__");
  assert.equal(t("git apply --check patch.diff"), "");  // read-only variant excluded
});

test("no code-write intent returns empty", () => {
  assert.equal(t("ls -la"), "");
  assert.equal(t("echo hi > notes.md"), "");
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/redirect-targets.test.mjs`
Expected: FAIL (module not found).

- [ ] **Step 3: Write the implementation** (verbatim logic; only I/O envelope changed)

```js
// opencode-harness/plugin/lib/redirect-targets.js
// VERBATIM logic port of ~/.claude/hooks/lib/redirect-targets.js (env+stdout → params+return).
// Detects shell commands that WRITE a code-extension file so the RPI gate can require a plan.
// PRESERVE every regex/tokenizer branch byte-for-byte (cycle-25/33/34/37 seals). The
// differential oracle asserts this matches the bash reference.
export function extractRedirectTarget(cmd, codeExtRegexSource) {
  cmd = cmd || "";
  const codeExt = new RegExp(codeExtRegexSource || "\\.(sh|py|js)$", "i");
  const isCode = (p) => p && codeExt.test(p) && !/^\/dev\/null$/.test(p);
  const targets = [];

  // 0) git apply / patch — target lives inside the patch body → conservative sentinel.
  if (/(^\s*|[;&|()]\s*)git\s+apply\b/.test(cmd) && !/--(check|stat|numstat|summary)\b/.test(cmd)) {
    return "__PATCH_APPLY__";
  }
  if (/(^\s*|[;&|()]\s*)patch\b/.test(cmd)) {
    return "__PATCH_APPLY__";
  }

  // 1) redirection / tee — quote-aware tokenizer.
  {
    const N = cmd.length;
    const toks = [];
    let i = 0;
    while (i < N) {
      const c = cmd[i];
      if (c === " " || c === "\t" || c === "\n" || c === "\r") { i++; continue; }
      if (c === ">" && cmd[i - 1] !== "-" && cmd[i - 1] !== "=") {
        let j = i + 1;
        if (cmd[j] === ">") j++;
        if (cmd[j] === "|") j++;
        else if (cmd[j] === "&") j++;
        toks.push({ v: cmd.slice(i, j), op: true });
        i = j; continue;
      }
      if (c === "<" || c === "|" || c === ";" || c === "&" || c === "(" || c === ")") {
        toks.push({ v: c, sep: true }); i++; continue;
      }
      let v = "", quoted = false;
      while (i < N) {
        const ch = cmd[i];
        if (ch === " " || ch === "\t" || ch === "\n" || ch === "\r") break;
        if (ch === "<" || ch === "|" || ch === ";" || ch === "&" || ch === "(" || ch === ")") break;
        if (ch === ">" && cmd[i - 1] !== "-" && cmd[i - 1] !== "=") break;
        if (ch === '"' || ch === "'") {
          quoted = true; const q = ch; i++;
          while (i < N && cmd[i] !== q) { v += cmd[i]; i++; }
          if (i < N) i++;
          continue;
        }
        v += ch; i++;
      }
      toks.push({ v, quoted });
    }
    for (let k = 0; k < toks.length; k++) {
      const t = toks[k];
      if (t.op) {
        const nx = toks[k + 1];
        if (nx && !nx.op && !nx.sep && nx.v) targets.push(nx.v);
      } else if (!t.quoted && (t.v === "tee" || t.v.endsWith("/tee"))) {
        let k2 = k + 1;
        while (toks[k2] && !toks[k2].op && !toks[k2].sep && toks[k2].v.startsWith("-")) k2++;
        if (toks[k2] && !toks[k2].op && !toks[k2].sep && toks[k2].v) targets.push(toks[k2].v);
      }
    }
  }

  // 2) sed -i[SUFFIX] … FILE
  if (/\bsed\b/.test(cmd) && /\s-i\b|\s-i\S+|--in-place/.test(cmd)) {
    for (const t of cmd.split(/\s+/).filter((t) => t && !t.startsWith("-"))) targets.push(t.replace(/^["']|["']$/g, ""));
  }

  // 3) cp / mv SRC DST (every occurrence)
  for (const mcp of cmd.matchAll(/\b(?:cp|mv)\b([^|;&]*)/g)) {
    const args = mcp[1].split(/\s+/).filter((t) => t && !t.startsWith("-"));
    if (args.length >= 1) targets.push(args[args.length - 1].replace(/^["']|["']$/g, ""));
  }

  // 4) python -c open("FILE","w"|"a")
  {
    const mpy = cmd.match(/python[0-9.]*\s+-c\b/);
    if (mpy) {
      const reOpen = /open\s*\(\s*["']([^"']+)["']\s*,\s*["'][^"']*[wa][^"']*["']/g;
      let om;
      while ((om = reOpen.exec(cmd)) !== null) targets.push(om[1]);
    }
  }

  // 4b) node -e / perl -e / ruby -e literal-filename writes
  {
    if (/\bnode\s+(?:-e|--eval)\b/.test(cmd)) {
      const reNode = /\b(?:fs\.)?(?:writeFileSync|appendFileSync|createWriteStream)\s*\(\s*["']([^"']+)["']/g;
      let nm; while ((nm = reNode.exec(cmd)) !== null) targets.push(nm[1]);
    }
    if (/\bperl\s+-e\b/.test(cmd)) {
      const rePerlQ = /open\s*\([^,]*,\s*["']>>?["']\s*,\s*["']([^"']+)["']/g;
      const rePerlI = /open\s*\([^,]*,\s*["']>>?\s*([^"'\s)]+)["']/g;
      let pm;
      while ((pm = rePerlQ.exec(cmd)) !== null) targets.push(pm[1]);
      while ((pm = rePerlI.exec(cmd)) !== null) targets.push(pm[1]);
    }
    if (/\bruby\s+-e\b/.test(cmd)) {
      const reRuby = /\bFile\.(?:write|open)\s*\(\s*["']([^"']+)["']/g;
      let rm; while ((rm = reRuby.exec(cmd)) !== null) targets.push(rm[1]);
    }
  }

  // 5) dd of=FILE
  {
    const mdd = cmd.match(/\bdd\b[^|;&]*\bof=("?)([^\s">|;&()]+)\1/);
    if (mdd) targets.push(mdd[2]);
  }

  // 6) install / rsync SRC DST (command-position anchored, >=2 non-option args)
  for (const mi of cmd.matchAll(/(?:^|[;&|()])\s*(?:install|rsync)\s+([^|;&]*)/g)) {
    const args = mi[1].split(/\s+/).filter((t) => t && !t.startsWith("-"));
    if (args.length >= 2) targets.push(args[args.length - 1].replace(/^["']|["']$/g, ""));
  }

  const hit = targets.find(isCode);
  return hit || "";
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/redirect-targets.test.mjs`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/plugin/lib/redirect-targets.js opencode-harness/tests/redirect-targets.test.mjs
git commit -m "feat(opencode-harness): redirect-targets verbatim refactor to fn (plan 2 T3, inv 8-10)"
```

---

### Task 4: `skeleton-scan.js` — orchestrator skeleton counts (verbatim refactor)

**Files:**
- Create: `opencode-harness/plugin/lib/skeleton-scan.js`
- Test: `opencode-harness/tests/skeleton-scan.test.mjs`

**Interfaces:**
- Produces: `scanSkeleton(content)` → `{hasMarker, phase, agent, contract}` — consumed by `orchestrator-gate.js`.

**Source of truth:** `~/.claude/hooks/lib/skeleton-scan.js` lines 27-32 (the content-scanning core). The Edit on-disk-apply + stdin/env envelope moves into the gate (Task 8); the lib is the pure content→counts function.

- [ ] **Step 1: Write the failing test**

```js
// opencode-harness/tests/skeleton-scan.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { scanSkeleton } from "../plugin/lib/skeleton-scan.js";

test("scanSkeleton counts marker, phases, agent calls, protocol", () => {
  const c = [
    "orchestrator_skill: true",
    "# Phase 1", "# Phase 2", "# Phase 3",
    "Agent(subagent_type=explore-strict)",
    "## Communication Protocol",
  ].join("\n");
  assert.deepEqual(scanSkeleton(c), { hasMarker: 1, phase: 3, agent: 1, contract: 1 });
});

test("HTML-commented Agent() calls do NOT count (S4)", () => {
  const c = "orchestrator_skill: true\n<!-- Agent(subagent_type=x) -->\n# Phase 1";
  assert.equal(scanSkeleton(c).agent, 0);
});

test("no marker → hasMarker 0", () => {
  assert.equal(scanSkeleton("# Phase 1\n").hasMarker, 0);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/skeleton-scan.test.mjs`
Expected: FAIL (module not found).

- [ ] **Step 3: Write the implementation**

```js
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/skeleton-scan.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/plugin/lib/skeleton-scan.js opencode-harness/tests/skeleton-scan.test.mjs
git commit -m "feat(opencode-harness): skeleton-scan content→counts fn (plan 2 T4, inv 16-19)"
```

---

### Task 5: `secret-scan.js` — secret detection SSOT (verbatim refactor)

**Files:**
- Create: `opencode-harness/plugin/lib/secret-scan.js`
- Test: `opencode-harness/tests/secret-scan.test.mjs`

**Interfaces:**
- Produces: `scanSecret(text)` → kind name string | null — consumed by `secret-gate.js`.

**Source of truth:** `~/.claude/hooks/enforce-secret-scan.sh` lines 36-49. Copy the 7 patterns + placeholder regex + first-match-wins-with-break VERBATIM. Length floors are calibrated — do NOT change. **Inv 15 (highest stakes): never include the matched value anywhere — return only the kind name.** Build test secrets at runtime (concatenation) so this test file holds no literal secret that would self-trip a scan of the repo (and so the harness's own secret-scan hook does not block writing this file).

- [ ] **Step 1: Write the failing test**

```js
// opencode-harness/tests/secret-scan.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { scanSecret } from "../plugin/lib/secret-scan.js";

test("detects real-shaped keys and returns ONLY the kind", () => {
  const akia = "AKIA" + "ABCDEFGHIJKLMNOP";      // built at runtime; 16 [A-Z0-9]
  assert.equal(scanSecret("id=" + akia), "AWS access key id");
  const aiza = "AIza" + "0123456789012345678901234567890ABCD"; // 35 trailing
  assert.equal(scanSecret(aiza), "Google API key");
  const pk = "-----BEGIN " + "OPENSSH PRIVATE KEY" + "-----"; // runtime-built; no literal in file
  assert.equal(scanSecret(pk), "Private key block");
});

test("placeholders are ignored", () => {
  const ph = "AKIA" + "EXAMPLE".padEnd(16, "X"); // 16 chars incl. EXAMPLE placeholder marker
  assert.equal(scanSecret(ph), null);
  assert.equal(scanSecret("your-key-here"), null);
});

test("clean text returns null", () => {
  assert.equal(scanSecret("just a normal sentence with no secrets"), null);
  assert.equal(scanSecret(""), null);
});
```

> Step-4 note: confirm the placeholder string's matched span actually contains a `placeholder`-regex marker (`EXAMPLE`); if `padEnd` produces a non-`[0-9A-Z]{16}` body that fails the AKIA pattern outright, adjust the runtime-built string so it matches the AKIA shape *and* contains `EXAMPLE`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/secret-scan.test.mjs`
Expected: FAIL (module not found).

- [ ] **Step 3: Write the implementation**

```js
// opencode-harness/plugin/lib/secret-scan.js
// VERBATIM patterns from ~/.claude/hooks/enforce-secret-scan.sh. High-specificity only
// (length floors calibrated to minimize false positives — do NOT tighten/loosen).
// First-match-wins (break). Inv 15: return ONLY the kind name; never the matched value.
const PATTERNS = [
  ["Anthropic key",     /sk-ant-(?:oat01|ort01|api03)-[A-Za-z0-9_\-]{40,}/],
  ["AWS access key id", /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/],
  ["GitHub token",      /\bgh[pousr]_[A-Za-z0-9]{36,}\b/],
  ["GitLab PAT",        /\bglpat-[A-Za-z0-9_\-]{20,}\b/],
  ["Slack token",       /\bxox[baprs]-[A-Za-z0-9-]{10,}/],
  ["Google API key",    /\bAIza[0-9A-Za-z_\-]{35}\b/],
  ["Private key block", /-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----/],
];
const PLACEHOLDER = /XXXX|REDACTED|EXAMPLE|PLACEHOLDER|your[_-]?(?:key|token|secret)|DUMMY|FAKE/i;

export function scanSecret(text) {
  const s = text || "";
  for (const [name, re] of PATTERNS) {
    const m = s.match(re);
    if (m && !PLACEHOLDER.test(m[0])) return name;
  }
  return null;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/secret-scan.test.mjs`
Expected: PASS (3 tests). If the placeholder case fails, fix the test's runtime-built string (not the lib) so the matched span both matches a pattern and contains a placeholder marker.

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/plugin/lib/secret-scan.js opencode-harness/tests/secret-scan.test.mjs
git commit -m "feat(opencode-harness): secret-scan SSOT (plan 2 T5, inv 13-15)"
```

---

### Task 6: `rpi-gate.js` — RPI plan-gate (Edit/Write/NotebookEdit + Bash)

**Files:**
- Create: `opencode-harness/plugin/gates/rpi-gate.js`
- Test: `opencode-harness/tests/rpi-gate.test.mjs`

**Interfaces:**
- Consumes: `isCodePath` (code-exts), `hasActivePlan` (plan-status), `extractRedirectTarget` (redirect-targets), `codeExtRegexSource` (code-exts), `BlockError` (fail-open).
- Produces: `rpiGate({tool, args, cwd, env, fs})` — throws `BlockError` to deny, returns to allow.

**Behavior (top-down, first match wins), faithful to enforce-rpi-cycle.sh + enforce-rpi-bash.sh:**
- **Path tools (edit/write/apply_patch + notebook):** resolve `filePath`. (a) spec-before-plan: if path matches `*/docs/superpowers/plans/*.md` and no `RPI_SKIP` and no spec file in `<cwd>/docs/superpowers/specs/*.md` → BLOCK. (b) non-code-ext whitelist (`.md/.txt/.gitignore/CLAUDE.md/README*/.gitkeep`) → allow. (c) if `isCodePath` → fall through; else if path matches `*/.claude/*|*/docs/*|*/.github/*` → allow. (d) trivial ≤5 lines (MAX of oldString/newString or content line counts) → allow. (e) `RPI_SKIP` → allow. (f) plans dir missing → BLOCK; `hasActivePlan` → allow; else BLOCK.
- **Bash tool:** resolve `command`. (a) empty → allow. (b) `RPI_SKIP` → allow. (c) `extractRedirectTarget`; empty → allow. (d) `hasActivePlan` → allow. (e) `__PATCH_APPLY__` or any target → BLOCK.

- [ ] **Step 1: Write the failing test**

```js
// opencode-harness/tests/rpi-gate.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { rpiGate } from "../plugin/gates/rpi-gate.js";
import { BlockError } from "../plugin/lib/fail-open.js";

const activeFs = { readdirSync: () => ["p.md"], readFileSync: () => "**Status:** active\n" };
const noPlanFs = { readdirSync: () => ["p.md"], readFileSync: () => "**Status:** completed\n" };
const base = { cwd: "/proj", env: {}, fs: activeFs };
const blocks = (fn) => assert.throws(fn, BlockError);
const allows = (fn) => assert.doesNotThrow(fn);

test("write code with active plan allows; without plan blocks", () => {
  allows(() => rpiGate({ ...base, tool: "write", args: { filePath: "/proj/x.py", content: "a\nb\nc\nd\ne\nf\n" } }));
  blocks(() => rpiGate({ ...base, fs: noPlanFs, tool: "write", args: { filePath: "/proj/x.py", content: "a\nb\nc\nd\ne\nf\n" } }));
});

test("docs and trivial edits allow even without a plan", () => {
  allows(() => rpiGate({ ...base, fs: noPlanFs, tool: "write", args: { filePath: "/proj/notes.md", content: "x" } }));
  allows(() => rpiGate({ ...base, fs: noPlanFs, tool: "edit", args: { filePath: "/proj/x.py", oldString: "a", newString: "b" } }));
});

test("bash redirect to code without plan blocks; with plan allows; md allows", () => {
  blocks(() => rpiGate({ ...base, fs: noPlanFs, tool: "bash", args: { command: "echo x > y.py" } }));
  allows(() => rpiGate({ ...base, tool: "bash", args: { command: "echo x > y.py" } }));
  allows(() => rpiGate({ ...base, fs: noPlanFs, tool: "bash", args: { command: "echo x > y.md" } }));
});

test("RPI_SKIP and spec-before-plan", () => {
  allows(() => rpiGate({ ...base, fs: noPlanFs, env: { RPI_SKIP: "hotfix" }, tool: "write", args: { filePath: "/proj/x.py", content: "a\nb\nc\nd\ne\nf\n" } }));
  const noSpecFs = { readdirSync: (d) => d.endsWith("specs") ? [] : ["q.md"], readFileSync: () => "**Status:** completed\n" };
  blocks(() => rpiGate({ ...base, fs: noSpecFs, tool: "write", args: { filePath: "/proj/docs/superpowers/plans/new.md", content: "x" } }));
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/rpi-gate.test.mjs`
Expected: FAIL (module not found).

- [ ] **Step 3: Write the implementation**

```js
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/rpi-gate.test.mjs`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/plugin/gates/rpi-gate.js opencode-harness/tests/rpi-gate.test.mjs
git commit -m "feat(opencode-harness): RPI plan-gate edit/write/bash (plan 2 T6, inv 1-12)"
```

---

### Task 7: `secret-gate.js` — secret-scan gate

**Files:**
- Create: `opencode-harness/plugin/gates/secret-gate.js`
- Test: `opencode-harness/tests/secret-gate.test.mjs`

**Interfaces:**
- Consumes: `scanSecret` (secret-scan), `CONTENT_KEYS` (arg-keys), `BlockError` (fail-open).
- Produces: `secretGate({tool, args, env})` — throws `BlockError` (kind only, never the value) or returns.

**Behavior:** gather candidate text from `args.content`, `args.oldString`/`args.newString` (CONTENT_KEYS), and `args.command`; if `SECRET_SCAN_SKIP` env → allow; if `scanSecret(joined)` returns a kind → BLOCK with the KIND only.

- [ ] **Step 1: Write the failing test**

```js
// opencode-harness/tests/secret-gate.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { secretGate } from "../plugin/gates/secret-gate.js";
import { BlockError } from "../plugin/lib/fail-open.js";

test("blocks a secret in content; message carries kind, not value", () => {
  const akia = "AKIA" + "ABCDEFGHIJKLMNOP";
  try {
    secretGate({ tool: "write", args: { content: "key=" + akia }, env: {} });
    assert.fail("should have thrown");
  } catch (e) {
    assert.ok(e instanceof BlockError);
    assert.ok(e.message.includes("AWS access key id"));
    assert.ok(!e.message.includes(akia), "value must NOT appear");
  }
});

test("blocks a secret in a bash command", () => {
  const tok = "ghp_" + "A".repeat(36);
  assert.throws(() => secretGate({ tool: "bash", args: { command: "export T=" + tok }, env: {} }), BlockError);
});

test("SECRET_SCAN_SKIP and clean payloads allow", () => {
  const akia = "AKIA" + "ABCDEFGHIJKLMNOP";
  assert.doesNotThrow(() => secretGate({ tool: "write", args: { content: "key=" + akia }, env: { SECRET_SCAN_SKIP: "approved" } }));
  assert.doesNotThrow(() => secretGate({ tool: "write", args: { content: "nothing secret" }, env: {} }));
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/secret-gate.test.mjs`
Expected: FAIL (module not found).

- [ ] **Step 3: Write the implementation**

```js
// opencode-harness/plugin/gates/secret-gate.js
import { BlockError } from "../lib/fail-open.js";
import { CONTENT_KEYS } from "../lib/arg-keys.js";
import { scanSecret } from "../lib/secret-scan.js";

// Gathers content/oldString/newString (CONTENT_KEYS) + command, scans for a secret.
// Inv 15: deny message carries ONLY the kind, never the matched value.
export function secretGate({ tool, args, env }) {
  args = args || {};
  env = env || {};
  if (env.SECRET_SCAN_SKIP) return;
  const parts = [];
  for (const k of CONTENT_KEYS) if (typeof args[k] === "string") parts.push(args[k]);
  if (typeof args.command === "string") parts.push(args.command);
  const payload = parts.join("\n");
  if (!payload) return;
  const kind = scanSecret(payload);
  if (kind) {
    throw new BlockError(`[secret-scan] 차단: 시크릿으로 보이는 값 감지 → ${kind}. 환경변수/시크릿매니저 사용. 우회: SECRET_SCAN_SKIP.`);
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/secret-gate.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/plugin/gates/secret-gate.js opencode-harness/tests/secret-gate.test.mjs
git commit -m "feat(opencode-harness): secret-scan gate (plan 2 T7, inv 13-15)"
```

---

### Task 8: `orchestrator-gate.js` — skeleton gate

**Files:**
- Create: `opencode-harness/plugin/gates/orchestrator-gate.js`
- Test: `opencode-harness/tests/orchestrator-gate.test.mjs`

**Interfaces:**
- Consumes: `scanSkeleton` (skeleton-scan), `BlockError` (fail-open).
- Produces: `orchestratorGate({tool, args, fs})` — throws `BlockError` or returns.

**Behavior (faithful to enforce-orchestrator.sh):** only applies to path tools whose `filePath` matches `*/skills/*/skill.md` (case-insensitive). Derive content: for `edit`, read on-disk file via `fs.readFileSync(filePath)` and apply `oldString→newString` (replace first occurrence; if oldString absent, keep current; if file unreadable, use newString); for `write`, use `content || newString`. If no content → allow. Run `scanSkeleton`; if `hasMarker !== 1` → allow (opt-out). Else require `phase >= 3 && agent >= 1 && contract >= 1`, else BLOCK.

- [ ] **Step 1: Write the failing test**

```js
// opencode-harness/tests/orchestrator-gate.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { orchestratorGate } from "../plugin/gates/orchestrator-gate.js";
import { BlockError } from "../plugin/lib/fail-open.js";

const fs = { readFileSync: () => { throw new Error("no file"); } };
const full = ["orchestrator_skill: true","# Phase 1","# Phase 2","# Phase 3","Agent(subagent_type=x)","Communication Protocol"].join("\n");

test("non-skill paths are ignored", () => {
  assert.doesNotThrow(() => orchestratorGate({ tool: "write", args: { filePath: "/a/notes.md", content: "x" }, fs }));
});

test("marked skill missing skeleton blocks; complete skeleton allows", () => {
  assert.throws(() => orchestratorGate({ tool: "write", args: { filePath: "/s/skills/foo/SKILL.md", content: "orchestrator_skill: true\n# Phase 1" }, fs }), BlockError);
  assert.doesNotThrow(() => orchestratorGate({ tool: "write", args: { filePath: "/s/skills/foo/SKILL.md", content: full }, fs }));
});

test("no orchestrator marker = opt-out allow", () => {
  assert.doesNotThrow(() => orchestratorGate({ tool: "write", args: { filePath: "/s/skills/foo/SKILL.md", content: "# Phase 1\njust a simple skill" }, fs }));
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/orchestrator-gate.test.mjs`
Expected: FAIL (module not found).

- [ ] **Step 3: Write the implementation**

```js
// opencode-harness/plugin/gates/orchestrator-gate.js
import { BlockError } from "../lib/fail-open.js";
import { scanSkeleton } from "../lib/skeleton-scan.js";

const SKILL_PATH = /\/skills\/[^/]+\/skill\.md$/i;

export function orchestratorGate({ tool, args, fs }) {
  args = args || {};
  const fp = args.filePath || "";
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/orchestrator-gate.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/plugin/gates/orchestrator-gate.js opencode-harness/tests/orchestrator-gate.test.mjs
git commit -m "feat(opencode-harness): orchestrator skeleton gate (plan 2 T8, inv 16-19)"
```

---

### Task 9: Wire gates into `governance.js`

**Files:**
- Modify: `opencode-harness/plugin/governance.js`
- Test: `opencode-harness/tests/governance-gate.test.mjs`

**Interfaces:**
- Consumes: all three gates + `failOpen`/`BlockError` + plugin ctx `{directory}`.
- The `tool.execute.before` envelope: `(input, output)` where `input.tool` is the tool name and `output.args` holds the args (Plan 1 shape). cwd = `directory` from plugin init. `fs` = real `node:fs` (lazy import). env = `process.env`.

**Behavior:** inside the existing `failOpen(...)` wrapper, run `secretGate` → `rpiGate` → `orchestratorGate` in order; the first to `throw BlockError` denies. Each gate is invoked with the resolved `{tool, args, cwd, env, fs}`. A non-BlockError thrown by a gate (e.g. a parser bug) is swallowed by `failOpen` → ALLOW, and surfaced via a `[harness] FAILOPEN` log (Plan 1 envelope already logs this).

- [ ] **Step 1: Write the failing test** (exercise the composed gate via the returned hook)

```js
// opencode-harness/tests/governance-gate.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Governance } from "../plugin/governance.js";

async function gateFor(cwd) {
  const hooks = await Governance({ client: {}, directory: cwd });
  return hooks["tool.execute.before"];
}
function mkProj(active) {
  const dir = mkdtempSync(join(tmpdir(), "ogov-"));
  mkdirSync(join(dir, "docs/superpowers/plans"), { recursive: true });
  mkdirSync(join(dir, "docs/superpowers/specs"), { recursive: true });
  writeFileSync(join(dir, "docs/superpowers/specs/s.md"), "# spec\n");
  writeFileSync(join(dir, "docs/superpowers/plans/p.md"), active ? "**Status:** active\n" : "**Status:** completed\n");
  return dir;
}

test("composed gate: no-plan code write rejects; secret rejects; clean allows", async () => {
  const noplan = mkProj(false);
  const gate = await gateFor(noplan);
  await assert.rejects(() => gate({ tool: "write" }, { args: { filePath: join(noplan, "x.py"), content: "a\nb\nc\nd\ne\nf\n" } }));
  await assert.rejects(() => gate({ tool: "write" }, { args: { filePath: join(noplan, "ok.md"), content: "key=" + "AKIA" + "ABCDEFGHIJKLMNOP" } }));
  await assert.doesNotReject(() => gate({ tool: "write" }, { args: { filePath: join(noplan, "ok.md"), content: "hello" } }));
  rmSync(noplan, { recursive: true, force: true });
});

test("composed gate: active plan permits code write", async () => {
  const ok = mkProj(true);
  const gate = await gateFor(ok);
  await assert.doesNotReject(() => gate({ tool: "write" }, { args: { filePath: join(ok, "x.py"), content: "a\nb\nc\nd\ne\nf\n" } }));
  rmSync(ok, { recursive: true, force: true });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd opencode-harness && node --test tests/governance-gate.test.mjs`
Expected: FAIL (gate is still the Plan-1 no-op; assertions about rejection fail).

- [ ] **Step 3: Modify `governance.js`** — replace the Plan-1 no-op gate body with the composed gates.

Add imports near the top:
```js
import { rpiGate } from "./gates/rpi-gate.js";
import { secretGate } from "./gates/secret-gate.js";
import { orchestratorGate } from "./gates/orchestrator-gate.js";
import * as nodeFs from "node:fs";
```

Replace the returned hook body (the Plan-1 `void pathArg(...)` no-op) with:
```js
  return {
    "tool.execute.before": failOpen(async (input, output) => {
      selfTest(input, output);
      const tool = input?.tool;
      const args = output?.args ?? {};
      const ctx = { tool, args, cwd: directory ?? ".", env: process.env, fs: nodeFs };
      // order: secret (content) → rpi (plan-gate) → orchestrator (skeleton). First BlockError denies.
      secretGate(ctx);
      rpiGate(ctx);
      orchestratorGate(ctx);
    }),
  };
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd opencode-harness && node --test tests/governance-gate.test.mjs`
Expected: PASS (2 tests). Then run the FULL suite: `node --test tests/*.test.mjs` — all prior + new pass.

- [ ] **Step 5: Commit**

```bash
git add opencode-harness/plugin/governance.js opencode-harness/tests/governance-gate.test.mjs
git commit -m "feat(opencode-harness): wire L2 gates into tool.execute.before (plan 2 T9)"
```

---

### Task 10: Differential conformance oracle (build-box)

**Files:**
- Create: `opencode-harness/_oracle/diff-parsers.mjs`
- (No shipped test; this is a build-box script run manually + in Plan 5's verify-all.)

**Interfaces:**
- Consumes: the refactored libs (`extractRedirectTarget`, `scanSkeleton`) AND the SOURCE node CLI parsers (`~/.claude/hooks/lib/redirect-targets.js` via `CMD`/`CODE_EXT_REGEX` env; `~/.claude/hooks/lib/skeleton-scan.js` via stdin/`FP`).
- Produces: per-fixture `diff == ∅` assertion between lib-function output and source-CLI output; non-zero exit on any mismatch.

**Behavior:** for a shared fixture corpus (a representative subset of the bash `cases.tsv` redirect/skeleton inputs), run BOTH engines and assert string-equal. This is the C′ keystone proof that the verbatim refactor preserved behavior. The secret-scan + plan-status libs have no separate source CLI (they were embedded in bash `node -e`), so they are covered by their own unit tests, not this differential oracle.

- [ ] **Step 1: Write the oracle script**

```js
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
```

- [ ] **Step 2: Run the oracle**

Run: `cd opencode-harness && node _oracle/diff-parsers.mjs`
Expected: `OK diff==0 (20 cases)`, exit 0. If any `DIFF` line prints, the refactor drifted from source — fix the lib to match the source byte-for-byte (the source is authoritative), never the other way.

- [ ] **Step 3: Commit**

```bash
git add opencode-harness/_oracle/diff-parsers.mjs
git commit -m "test(opencode-harness): differential parser oracle vs source node CLIs (plan 2 T10)"
```

---

## Self-Review (run after drafting)

- **Spec coverage:** §6 L2 (`tool.execute.before` throw) → T6/T7/T8/T9; §10.4 secret-scan extraction → T5; §5 `plugin/lib` + `plugin/gates` → T1-T9; §7 inv 1-19 → gate tasks; differential oracle (§8 Phase i, C′ keystone) → T10. The bash-redirect bypass that Plan 1 §13 flagged is sealed by T6 (Bash path) + T3.
- **Verbatim fidelity:** T3/T4/T5 copy regexes/tokenizer/patterns byte-for-byte; T10 proves it against the source CLIs.
- **Out of scope (later plans):** advisory `additionalContext` surfacing (`surface_bypass`, `stable-claude-md`, `surface-constitution`) → Plan 4; the full 156-case run-all reconciliation port → Plan 5 verify harness; node-parser reuse for `model-window`/`transcript-usage` (statusline, dropped per R7) → not ported.
- **arg-key dependency:** gates read `filePath`/`command`/`CONTENT_KEYS`; if the company runtime's keys differ, the Plan-1 startup self-test ALERTs (R2). The differential oracle does NOT cover arg-key shape — that is the live probe's job.

## Execution Handoff

Plan complete. Execution via **ultracode workflow** (Phase-I option d): sequential per-task `execute-strict` → `review-strict`, data-dependent, worktree-scoped, no schema on constrained agents — consistent with the harness RPI mandate and Plan 1's approach.
