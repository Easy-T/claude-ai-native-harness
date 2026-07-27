// hooks/lib/workflow-spawns.js
// Workflow 스크립트 텍스트에서 agent() 스폰을 **개별로** 추출 (surface-model-policy.sh 가 사용).
// 입력: stdin = 스크립트 전문. 출력: 스폰당 1행 "<agentType>\t<model>".
//   agentType: 리터럴 값 / 키 부재='?' / 키는 있으나 비-리터럴='*'  (C13 GPT 교차리뷰 [C]4 — '?' 가
//              "부재"와 "동적"을 뭉뚱그리면 Rule C3(상속 단언)이 거짓 안내가 된다)
//   model:     리터럴 값 / 부재·비-리터럴='-' (동적 값은 정적으로 알 수 없으므로 **미선언 취급** = 안전 방향)
// 존재 이유 (spec §12.3): bash ERE 는 스크립트 전역 boolean OR 로만 판정 가능해
//   "준수 스폰 1개가 나머지 무선언 스폰을 침묵시키는" 마스킹이 구조적으로 발생한다(실물 E2E 확정).
//   per-call 파싱을 node 로 분리해 탐지 입도를 스폰 단위로 올린다.
//
// 구조 (C13 closeout, GPT 교차리뷰 [A]1~[A]10 반영): 정규식 휴리스틱 → **렉서 + 프로퍼티 워크**.
//   1) lex(): 주석 / 문자열 / 템플릿(${} 중첩 포함) / 정규식 리터럴 본문을 같은 길이 공백으로 마스킹
//      (인덱스 보존). 이로써 주석·문자열 안의 agent( · 괄호 · 따옴표 · "model:'opus'" 가 구조 판정과
//      값 판정 양쪽에서 사라진다.
//   2) 스폰 탐색: /(?<![\w$.])agent\s*\(/ + `function agent(` 제외 → obj.agent()·my$agent()·선언 오탐 차단.
//   3) opts 객체 = 호출 인자 깊이 0 의 첫 '{' — 첫 인자 안의 중첩 객체(makePrompt({model:'opus'}))를 배제.
//   4) opts 를 **깊이 0 프로퍼티로 워크**(콤마 분할 → 첫 ':' 로 key/value) — 중첩 객체의 model,
//      접미사 키(fallback_model), 삼항 피연산자 "model" 오탐이 모두 구조적으로 불가능. 중복 키는
//      JavaScript 의미대로 **last-write-wins**.
//   5) 값은 렉서가 기록한 문자열 스팬에서만 취하고 escape 를 디코드(\uXXXX·\xNN·\'). 템플릿에 ${} 가
//      있으면 동적으로 판정.
//
// 한계 (정직 공개 — §10/§12.3 유지):
//   · **동적 조립** ('execute'+'-strict', MODELS[i], f.model ?? 'sonnet')은 값이 단일 리터럴이 아니므로
//     agentType='*' / model='-' 로 보고된다(미탐이 아니라 "정적으로 알 수 없음"의 안전 방향 보고).
//   · opts 를 변수로 넘기면(agent('p', OPTS)) 깊이 0 에 '{' 가 없어 키 부재로 보인다 → '?'/'-'.
//     스프레드(...base)로 들어온 키도 마찬가지로 부재 취급.
//   · **인자 경계를 나누지 않는다**(C14 정직 공개): 깊이 0 의 '{...}' 를 **전부** opts 후보로 보고
//     각각을 1스폰으로 방출한다. 삼항 opts 의 모든 분기가 관측되는 대신, 첫 인자가 객체 리터럴이면
//     (agent({t:1},{opts})) 그 객체도 1스폰으로 방출된다 — 대개 agentType/model 키가 없어 '?'/'-' 가
//     되므로 fable 세션에서 Rule C3 **오탐**이 될 수 있다(안전 방향: 미탐보다 오탐 선택).
//     정확한 판정은 "마지막 인자" 의미론(깊이-0 콤마 분할)이 필요하며 1-인자 호출·트레일링 콤마 등
//     경계 케이스를 새로 연다 — 채택하지 않았다(spec §13.7).
//   · Object.assign({},{...}) 처럼 opts 가 호출로 감싸이면 깊이 0 '{' 가 없어 '?'/'-'(미탐 잔여).
//   · 계산 키는 정적 문자열(['model'])만 해소하고, 동적 계산 키([k])는 미해소.
//   · 정규식-vs-나눗셈 판별은 직전 유의 문자/키워드 휴리스틱(완전한 JS 문법 분석 아님).
//   · 입력은 선두 512KiB, 스폰은 200개까지만 처리(정지성 보장 — GPT [A]10 의 O(N²) 경로 봉인).
//   AST 파싱 미채택 근거는 plan 의 Best-Direction Check 참조.

const MAX_SRC = 524288;
const MAX_SPAWNS = 200;
// 후보 **시도** 상한 — 성공 스폰만 세면 "닫히지 않는 agent( 반복"이 매 후보마다 입력 끝까지 재스캔해
// O(N²) 가 된다(GPT [A]10 실측: 코드 경로 N=20000 에서 ~14s). 시도 자체를 봉인해야 정지성이 보장된다.
const MAX_ATTEMPTS = 400;
const KEYWORDS = new Set([
  "return", "typeof", "instanceof", "in", "of", "new", "delete", "void",
  "case", "do", "else", "yield", "await", "throw",
]);

let src = "";
process.stdin.on("data", (c) => (src += c));
process.stdin.on("end", () => {
  try {
    src = src.slice(0, MAX_SRC);
    const rows = scan(src).map((s) => `${clean(s.agentType)}\t${clean(s.model)}`);
    process.stdout.write(rows.join("\n"));
  } catch {
    /* fail-open: 무출력 */
  }
});

// 값에 탭/개행이 들어가면 "스폰당 1행" 계약이 깨진다(GPT [A]9) — 단일 공백으로 접는다.
function clean(v) {
  return String(v).replace(/[\t\r\n]+/g, " ").trim() || "-";
}

// --- 1) 렉서: 주석/문자열/템플릿/정규식 본문을 공백으로 마스킹하고 문자열 스팬을 기록 ---
function lex(text) {
  const n = text.length;
  const mask = text.split("");
  const strings = new Map(); // 여는 delimiter 인덱스 -> {bodyStart, bodyEnd, end, dynamic}
  const stack = [{ k: "code", d: 0 }];
  let i = 0, prevSig = "", word = "";
  const blank = (a, b) => { for (let j = a; j < b && j < n; j++) mask[j] = " "; };

  while (i < n) {
    const top = stack[stack.length - 1];
    const ch = text[i];

    if (top.k === "tmpl") {
      if (ch === "\\") { blank(i, i + 2); i += 2; continue; }
      if (ch === "$" && text[i + 1] === "{") {
        top.dynamic = true; blank(i, i + 2);
        stack.push({ k: "code", d: 0, fromTmpl: true }); i += 2; continue;
      }
      if (ch === "`") {
        strings.set(top.start, { bodyStart: top.start + 1, bodyEnd: i, end: i, dynamic: !!top.dynamic });
        mask[i] = "`"; stack.pop(); prevSig = "`"; word = ""; i++; continue;
      }
      mask[i] = " "; i++; continue;
    }

    // 주석
    if (ch === "/" && text[i + 1] === "/") {
      let j = i; while (j < n && text[j] !== "\n") j++;
      blank(i, j); i = j; continue;
    }
    if (ch === "/" && text[i + 1] === "*") {
      const e = text.indexOf("*/", i + 2);
      const stop = e === -1 ? n : e + 2;
      blank(i, stop); i = stop; continue;
    }
    // 문자열
    if (ch === "'" || ch === '"') {
      let j = i + 1;
      while (j < n && text[j] !== ch) { if (text[j] === "\\") j++; j++; }
      const end = j < n ? j : n - 1;
      blank(i + 1, end);
      strings.set(i, { bodyStart: i + 1, bodyEnd: end, end, dynamic: false });
      prevSig = ch; word = ""; i = end + 1; continue;
    }
    // 템플릿 진입
    if (ch === "`") { stack.push({ k: "tmpl", start: i, d: 0 }); i++; continue; }
    // 정규식 리터럴 (직전 유의 문맥이 값이 아니면 정규식)
    if (ch === "/" && regexAllowed(prevSig, word)) {
      let j = i + 1, cls = false, ok = false;
      while (j < n) {
        const c = text[j];
        if (c === "\\") { j += 2; continue; }
        if (c === "\n") break;
        if (cls) { if (c === "]") cls = false; }
        else if (c === "[") cls = true;
        else if (c === "/") { ok = true; break; }
        j++;
      }
      if (ok) { blank(i, j + 1); prevSig = "/"; word = ""; i = j + 1; continue; }
    }
    // 코드
    if (ch === "{") top.d++;
    else if (ch === "}") {
      if (top.d === 0 && top.fromTmpl) { stack.pop(); i++; continue; }
      top.d--;
    }
    if (!/\s/.test(ch)) {
      prevSig = ch;
      word = /[\w$]/.test(ch) ? word + ch : "";
    }
    i++;
  }
  return { mask: mask.join(""), strings };
}

function regexAllowed(prevSig, word) {
  if (prevSig === "") return true;
  if (KEYWORDS.has(word)) return true;
  return !/[\w$)\]]/.test(prevSig);
}

// --- 2~5) 스폰 추출 ---
function scan(text) {
  const { mask, strings } = lex(text);
  const out = [];
  const re = /(?<![\w$.])agent\s*\(/g;
  let m, attempts = 0;
  while ((m = re.exec(mask)) !== null && out.length < MAX_SPAWNS && ++attempts <= MAX_ATTEMPTS) {
    if (/\bfunction\s+$/.test(mask.slice(Math.max(0, m.index - 16), m.index))) continue;
    const open = m.index + m[0].length - 1;
    const close = matchPair(mask, open, "(", ")");
    if (close === -1) continue;
    const cands = findOptsCandidates(mask, open, close);
    const propsList = cands.length ? cands.map((c) => parseProps(mask, strings, c[0], c[1])) : [{}];
    for (const props of propsList) {
      if (out.length >= MAX_SPAWNS) break;
      const at = props.agentType, mo = props.model;
      out.push({
        agentType: at === undefined ? "?" : at === null ? "*" : at,
        model: mo === undefined || mo === null ? "-" : mo,
      });
    }
  }
  return out;
}

function matchPair(mask, idx, open, close) {
  let d = 0;
  for (let i = idx; i < mask.length; i++) {
    if (mask[i] === open) d++;
    else if (mask[i] === close) { d--; if (d === 0) return i; }
  }
  return -1;
}

// 호출 인자 깊이 0 의 '{...}' 를 **전부** 수집한다 (C14, spec §13.7).
// 단일 '첫 {' 만 취하면 ①삼항 opts 의 둘째 분기가 소실되고(준수 리터럴이 무선언을 가리는 마스킹)
// ②첫 인자의 객체/화살표 본문을 opts 로 오식별한다. 후보를 모두 방출하면 둘 다 안전 방향으로 해소된다.
function findOptsCandidates(mask, open, close) {
  const out = [];
  let p = 0, b = 0;
  for (let i = open + 1; i < close; i++) {
    const c = mask[i];
    if (c === "(") p++;
    else if (c === ")") p--;
    else if (c === "[") b++;
    else if (c === "]") b--;
    else if (c === "{" && p === 0 && b === 0) {
      const e = matchPair(mask, i, "{", "}");
      if (e === -1 || e > close) break;
      out.push([i, e]);
      i = e;                    // 이 후보 내부는 건너뛴다(중첩 객체는 프로퍼티 워크가 처리)
    }
  }
  return out;
}

// opts 를 깊이 0 프로퍼티로 워크. 값: 단일 문자열 리터럴이면 그 값, 아니면 null(동적).
function parseProps(mask, strings, s, e) {
  const props = {};
  let segStart = s + 1, colon = -1, d = 0;
  const flush = (end) => {
    if (colon !== -1) {
      const key = readKey(mask, strings, segStart, colon);
      if (key === "agentType" || key === "model") props[key] = readValue(mask, strings, colon + 1, end);
    }
    segStart = end + 1; colon = -1;
  };
  for (let i = s + 1; i < e; i++) {
    const c = mask[i];
    if (c === "(" || c === "[" || c === "{") d++;
    else if (c === ")" || c === "]" || c === "}") d--;
    else if (d === 0 && c === ":" && colon === -1) colon = i;
    else if (d === 0 && c === ",") flush(i);
  }
  flush(e);
  return props;
}

// key: 식별자 / 문자열 리터럴 / 정적 계산 키 ['model']
function readKey(mask, strings, a, b) {
  let s = a, e = b;
  while (s < e && /\s/.test(mask[s])) s++;
  while (e > s && /\s/.test(mask[e - 1])) e--;
  if (mask[s] === "[" && mask[e - 1] === "]") {
    let t = s + 1; while (t < e && /\s/.test(mask[t])) t++;
    const span = strings.get(t);
    return span && !span.dynamic ? decode(strings, t) : null;
  }
  const span = strings.get(s);
  if (span) return span.end === e - 1 && !span.dynamic ? decode(strings, s) : null;
  return mask.slice(s, e);
}

// value: 트림한 범위가 정확히 하나의 (비-동적) 문자열 리터럴일 때만 정적
function readValue(mask, strings, a, b) {
  let s = a, e = b;
  while (s < e && /\s/.test(mask[s])) s++;
  while (e > s && /\s/.test(mask[e - 1])) e--;
  const span = strings.get(s);
  if (!span || span.end !== e - 1 || span.dynamic) return null;
  return decode(strings, s);
}

// 원문 본문에서 값을 복원 + 정적으로 확정되는 escape 디코드 (GPT [A]8)
function decode(strings, start) {
  const sp = strings.get(start);
  const body = src.slice(sp.bodyStart, sp.bodyEnd);
  if (body.indexOf("\\") === -1) return body;
  return body.replace(
    /\\u\{([0-9a-fA-F]{1,6})\}|\\u([0-9a-fA-F]{4})|\\x([0-9a-fA-F]{2})|\\(\r?\n)|\\([\s\S])/g,
    (_m, u1, u2, x, nl, other) => {
      if (u1 !== undefined) return safeChar(parseInt(u1, 16));
      if (u2 !== undefined) return safeChar(parseInt(u2, 16));
      if (x !== undefined) return safeChar(parseInt(x, 16));
      if (nl !== undefined) return "";                       // line continuation
      const map = { n: "\n", t: "\t", r: "\r", b: "", f: "", v: "", 0: "" };
      return Object.prototype.hasOwnProperty.call(map, other) ? map[other] : other;
    }
  );
}

function safeChar(cp) {
  try { return String.fromCodePoint(cp); } catch { return ""; }
}
