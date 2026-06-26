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
