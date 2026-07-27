// hooks/lib/workflow-spawns.js
// Workflow 스크립트 텍스트에서 agent() 스폰을 **개별로** 추출 (surface-model-policy.sh 가 사용).
// 입력: stdin = 스크립트 전문. 출력: 스폰당 1행 "<agentType>\t<model>" (model 미선언='-', agentType 미상='?').
// 존재 이유 (spec §12.3): bash ERE 는 스크립트 전역 boolean OR 로만 판정 가능해
//   "준수 스폰 1개가 나머지 무선언 스폰을 침묵시키는" 마스킹이 구조적으로 발생한다(실물 E2E 확정).
//   per-call 파싱을 node 로 분리해 탐지 입도를 스폰 단위로 올린다.
// 한계 (정직 공개 — §10/§12.3 유지): 텍스트 휴리스틱이므로 동적 조립('execute'+'-strict')은 미검출,
//   주석 안의 agent() 는 오탐 가능. **값이 리터럴이 아닌 표현식**(model: f.model ?? 'sonnet',
//   model: MODELS[i])도 '-'(미선언)로 보고돼 오탐 가능 — 런타임 값을 정적으로 알 수 없기 때문이다.
//   이 오탐은 advisory 환기 1회로 끝나므로(차단 아님) 수용하되, 리터럴 표기를 권장한다.
//   AST 파싱 미채택 근거는 plan 의 Best-Direction Check 참조.
let src = "";
process.stdin.on("data", (c) => (src += c));
process.stdin.on("end", () => {
  try {
    process.stdout.write(scan(src).map((s) => `${s.agentType}\t${s.model}`).join("\n"));
  } catch {
    /* fail-open: 무출력 */
  }
});

// agent( 호출마다 opts 객체(2번째 인자)를 괄호/중괄호 깊이로 스캔해 잘라낸다.
function scan(text) {
  const out = [];
  const re = /\bagent\s*\(/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    const seg = sliceCall(text, m.index + m[0].length - 1); // '(' 위치
    if (seg === null) continue;
    out.push({ agentType: pick(seg, "agentType") || "?", model: pick(seg, "model") || "-" });
  }
  return out;
}

// 여는 '(' 에서 짝이 맞는 ')' 까지. 문자열/템플릿 리터럴 안의 괄호는 건너뛴다.
function sliceCall(text, open) {
  let depth = 0, quote = null;
  for (let i = open; i < text.length; i++) {
    const ch = text[i];
    if (quote) {
      if (ch === "\\") { i++; continue; }
      if (ch === quote) quote = null;
      continue;
    }
    if (ch === "'" || ch === '"' || ch === "`") { quote = ch; continue; }
    if (ch === "(") depth++;
    else if (ch === ")") { depth--; if (depth === 0) return text.slice(open, i + 1); }
  }
  return null;
}

// seg 안에서 key: 'value' 를 찾되, **문자열 리터럴 내부는 제외**(프롬프트가 정책 문구를 인용해도 오판 금지).
function pick(seg, key) {
  const masked = maskStrings(seg);
  const re = new RegExp(`['"]?${key}['"]?\\s*:\\s*(['"\`])`, "g");
  const m = re.exec(masked);
  if (!m) return null;
  const q = m[1];
  const start = m.index + m[0].length;
  const end = seg.indexOf(q, start);
  return end === -1 ? null : seg.slice(start, end).trim();
}

// 문자열/템플릿 리터럴 **본문**을 같은 길이의 공백으로 치환(인덱스 보존) — 따옴표는 남긴다.
// 단 **키 리터럴**(닫는 따옴표 뒤 공백 건너뛰고 ':' 이 오는 경우 = {"model": …})은 보존한다 —
// 그렇지 않으면 따옴표 키가 지워져 pick() 이 매치하지 못한다(Gate P 실측 회귀 — 기존 케이스 17).
function maskStrings(s) {
  const a = s.split("");
  const spans = [];
  let quote = null, start = -1;
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (quote) {
      if (ch === "\\") { i++; continue; }
      if (ch === quote) { spans.push([start, i]); quote = null; }
      continue;
    }
    if (ch === "'" || ch === '"' || ch === "`") { quote = ch; start = i; }
  }
  for (const [open, close] of spans) {
    let j = close + 1;
    while (j < s.length && /\s/.test(s[j])) j++;
    if (s[j] === ":") continue;                       // 키 리터럴 — 보존
    for (let k = open + 1; k < close; k++) a[k] = " ";  // 값/프롬프트 본문 — 마스킹
  }
  return a.join("");
}
