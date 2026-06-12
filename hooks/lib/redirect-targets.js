// hooks/lib/redirect-targets.js
// 셸로 '코드 파일'을 쓰는 패턴 탐지 (enforce-rpi-bash 가 사용).
// 입력: env CMD = 셸 명령 문자열, env CODE_EXT_REGEX = 코드 확장자 JS 정규식 source (_common.sh code_ext_regex).
// 출력: 첫 '코드 확장자' 쓰기 대상 (/dev/null 제외). 없으면 빈 문자열.
// 탐지 경로:
//   1) 리다이렉션 >/>> 와 tee [-a]
//   2) sed -i[SUFFIX] … FILE  (in-place 편집)
//   3) cp/mv SRC DST          (DST = 마지막 비옵션 인자, 명령 내 전부 — matchAll)
//   4) python[3] -c '…open("FILE","w"|"a"|…)…'  (보수적 best-effort: 리터럴 파일명+write 모드만)
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

// 1) 리다이렉션 / tee
const reRedir = /(?:>>?|\btee\s+(?:-a\s+)?)\s*("?)([^\s">|;&()]+)\1/g;
let m;
while ((m = reRedir.exec(cmd)) !== null) targets.push(m[2]);

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
