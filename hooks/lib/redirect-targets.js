// hooks/lib/redirect-targets.js
// 셸로 '코드 파일'을 쓰는 패턴 탐지 (enforce-rpi-bash 가 사용).
// 입력: env CMD = 셸 명령 문자열, env CODE_EXT_REGEX = 코드 확장자 JS 정규식 source (_common.sh code_ext_regex).
// 출력: 첫 '코드 확장자' 쓰기 대상 (/dev/null 제외). 없으면 빈 문자열.
// 탐지 경로:
//   1) 리다이렉션 >/>>/>| 와 tee [-a] — 따옴표-인지 토크나이저 (인용 내부 '>' 및 '->'/'=>' 화살표 오탐 방지, 단일/이중 인용 타깃)
//   2) sed -i[SUFFIX] … FILE  (in-place 편집)
//   3) cp/mv SRC DST          (DST = 마지막 비옵션 인자, 명령 내 전부 — matchAll)
//   4) python[3] -c '…open("FILE","w"|"a"|…)…'  (보수적 best-effort: 리터럴 파일명+write 모드만)
//   4b) node/perl/ruby -e 로 리터럴 파일명에 쓰기 (python -c 와 대칭; 변수/동적 파일명=Non-Goal)
//   5) dd of=FILE / install SRC DST / rsync SRC DST
//   6) git apply·patch → __PATCH_APPLY__ sentinel (보수차단 — 타깃이 패치 내용에 있어 추출 불가;
//      read-only 변형 --check/--stat/--numstat/--summary 는 제외, cycle-23 D-SIDEDOOR-2)
const cmd = process.env.CMD || "";
const codeExt = new RegExp(process.env.CODE_EXT_REGEX || "\\.(sh|py|js)$", "i");
const isCode = (p) => p && codeExt.test(p) && !/^\/dev\/null$/.test(p);
const targets = [];

// 0) git apply / patch — 쓰기 대상이 패치 '내용'에 있어 명령행 추출 불가 → 보수차단 sentinel.
//    docs 전용 패치 오탐은 RPI_SKIP 탈출구로 수용 (cycle-23 D-SIDEDOOR-2).
if (/(^\s*|[;&|()]\s*)git\s+apply\b/.test(cmd) && !/--(check|stat|numstat|summary)\b/.test(cmd)) {
  process.stdout.write("__PATCH_APPLY__"); process.exit(0);
}
if (/(^\s*|[;&|()]\s*)patch\b/.test(cmd)) {
  process.stdout.write("__PATCH_APPLY__"); process.exit(0);
}

// 1) 리다이렉션 / tee — 따옴표-인지 토크나이저 (cycle-25 rank1).
//    인용 내부 '>' 오탐 + '->'/'=>' 화살표 오탐 방지, 단일/이중 인용 타깃 + '>|' noclobber 지원.
{
  const N = cmd.length;
  const toks = []; // {v, op, sep, quoted}
  let i = 0;
  while (i < N) {
    const c = cmd[i];
    if (c === " " || c === "\t" || c === "\n" || c === "\r") { i++; continue; }
    // 리다이렉션 연산자: > >> >|  ('->'/'=>' 화살표는 제외)
    if (c === ">" && cmd[i - 1] !== "-" && cmd[i - 1] !== "=") {
      let j = i + 1;
      if (cmd[j] === ">") j++;
      if (cmd[j] === "|") j++;
      toks.push({ v: cmd.slice(i, j), op: true });
      i = j; continue;
    }
    // 셸 분리자 / 비타깃
    if (c === "<" || c === "|" || c === ";" || c === "&" || c === "(" || c === ")") {
      toks.push({ v: c, sep: true }); i++; continue;
    }
    // 단어 (따옴표 인지) — 공백/분리자/리다이렉션 전까지, 인용은 언쿼트해서 값에 포함
    let v = "", quoted = false;
    while (i < N) {
      const ch = cmd[i];
      if (ch === " " || ch === "\t" || ch === "\n" || ch === "\r") break;
      if (ch === "<" || ch === "|" || ch === ";" || ch === "&" || ch === "(" || ch === ")") break;
      if (ch === ">" && cmd[i - 1] !== "-" && cmd[i - 1] !== "=") break;
      if (ch === '"' || ch === "'") {
        quoted = true; const q = ch; i++;
        while (i < N && cmd[i] !== q) { v += cmd[i]; i++; }
        if (i < N) i++; // 닫는 따옴표
        continue;
      }
      v += ch; i++;
    }
    toks.push({ v, quoted });
  }
  // 타깃 도출: 리다이렉션 연산자 뒤 토큰, 또는 tee [-옵션...] 뒤 토큰
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

// 2) sed -i[SUFFIX] … FILE : -i 플래그가 있으면 비옵션 인자 중 코드-ext
if (/\bsed\b/.test(cmd) && /\s-i\b|\s-i\S+|--in-place/.test(cmd)) {
  for (const t of cmd.split(/\s+/).filter(t => t && !t.startsWith("-"))) targets.push(t.replace(/^["']|["']$/g, ""));
}

// 3) cp / mv SRC DST : 마지막 비옵션 인자(목적지) — 명령 내 모든 cp/mv 검사 (matchAll, cycle-23)
{
  for (const mcp of cmd.matchAll(/\b(?:cp|mv)\b([^|;&]*)/g)) {
    const args = mcp[1].split(/\s+/).filter(t => t && !t.startsWith("-"));
    if (args.length >= 1) targets.push(args[args.length - 1].replace(/^["']|["']$/g, ""));
  }
}

// 4) python -c open("FILE", "w"|"a"|...) — 리터럴 파일명 + write 모드만 (보수적; f-string/변수/exec/multiline 미탐지=Non-Goal)
{
  const mpy = cmd.match(/python[0-9.]*\s+-c\b/);
  if (mpy) {
    const reOpen = /open\s*\(\s*["']([^"']+)["']\s*,\s*["'][^"']*[wa][^"']*["']/g;
    let om;
    while ((om = reOpen.exec(cmd)) !== null) targets.push(om[1]);
  }
}

// 4b) node -e / perl -e / ruby -e 로 '리터럴 파일명'에 쓰기 (cycle-25 rank1; python -c 와 대칭).
//     보수적 — 리터럴 문자열 파일명만. 변수/동적 파일명·exec 는 Non-Goal(SECURITY.md).
{
  if (/\bnode\s+(?:-e|--eval)\b/.test(cmd)) {
    const reNode = /\b(?:fs\.)?(?:writeFileSync|appendFileSync|createWriteStream)\s*\(\s*["']([^"']+)["']/g;
    let nm; while ((nm = reNode.exec(cmd)) !== null) targets.push(nm[1]);
  }
  if (/\bperl\s+-e\b/.test(cmd)) {
    const rePerlQ = /open\s*\([^,]*,\s*["']>>?["']\s*,\s*["']([^"']+)["']/g; // open(FH,">","FILE")
    const rePerlI = /open\s*\([^,]*,\s*["']>>?\s*([^"'\s)]+)["']/g;          // open(FH,">FILE")
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
// 6) install / rsync SRC DST : 마지막 비옵션 인자 (디렉터리 타깃은 코드-ext 비매칭으로 자연 통과)
{
  for (const mi of cmd.matchAll(/\b(?:install|rsync)\b([^|;&]*)/g)) {
    const args = mi[1].split(/\s+/).filter(t => t && !t.startsWith("-"));
    if (args.length >= 2) targets.push(args[args.length - 1].replace(/^["']|["']$/g, ""));
  }
}

const hit = targets.find(isCode);
if (hit) process.stdout.write(hit);
