# C13 역할별 모델 디스패치 거버넌스 Implementation Plan

**Status:** completed
**RPI-Cycle:** 64
**Started:** 2026-07-27

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Workflow 스크립트의 서브에이전트 스폰을 **스폰 단위로** 평가해 fable 세션의 모델 역류를 관측하고, 탐색자에 WebSearch·xhigh를 부여하며, 검증자 기준선을 `max(세션, 작업자)`로 문서 정합화한다.

**Architecture:** bash ERE는 per-call 파싱이 구조적으로 불가(§12.3 실증 — `EX_HAS_MODEL`이 스크립트 전역 boolean OR)하므로, 파싱을 `hooks/lib/*.js` node 파서로 분리한다(기존 선례 `redirect-targets.js`·`skeleton-scan.js`·`model-window.js` 동형). hook은 파서 출력을 소비해 판정만 하고, advisory·fail-open 불변식(항상 exit 0)은 유지한다.

**Tech Stack:** bash(MSYS) · node(파서, 의존성 0) · hooks/tests/run-all.sh(TAP형 자체 하네스) · setup/verify-setup.sh(seal)

## Global Constraints

- **advisory 불변식**: hook은 어떤 경우에도 비-0 종료 금지(`trap 'exit 0' ERR EXIT` 유지). 차단 승격은 이번 범위 밖.
- **버전-무관 alias 원칙**: 디스패치 계층은 bare alias(fable/opus/sonnet/haiku)와 glob(`claude-opus-*`)만. 구체 버전 ID 금지.
- **seal 검사는 bash 파일옵스만** (node 보간형 금지 — MSYS 미독 이력).
- **`verify-setup`·`run-all`·`seal-regression`은 포그라운드만** (명시적 백그라운드 시작 금지).
- **`settings.json`은 gitignored + 토큰 보유 — `git add` 절대 금지**(`-f` 포함). 추적본은 `settings.example.json`.
- **검증자 기준선** = `max(세션 티어, 작업자 티어)`. tier: fable=4, opus=3, sonnet=2, haiku=1, 그 외=0(미판정).
- **카운트 SSOT 연쇄**: `cases.tsv` 비주석 행 수 == run-all `TOTAL` (양방향 단언, run-all:1043-1046) → `README.md:276,514` 표기. seal 추가 시 `README.md:284` "현재 81 PASS"(seal #36 런타임 자기카운트).
- 근거 SSOT: `docs/superpowers/specs/2026-07-25-model-policy-design.md` §12 (§12.1 floor · §12.2 도구배선 · §12.3 결함 4종 · §12.4 선재결함 6건).

**Best-Direction Check:** 최선안 = Workflow 스크립트를 **실제 JS 파서로 AST 수준 분석**해 스폰 객체별 model/agentType을 정확히 추출 / 채택안 = **node 정규식 파서로 스폰 객체를 개별 분리**해 per-spawn 평가.
→ `DOWNGRADE-DECLARED(정직 공개 유지)`: AST 파싱은 ①hook이 임의 사용자 스크립트를 파싱하게 되어 파서 자체가 공격면이 되고 ②동적 조립(`'execute'+'-strict'`)은 AST로도 미해결이라 **잔여가 동일하게 남으며** ③advisory hook의 복잡도·지연 상한을 넘는다. 채택안은 "스크립트당 1회 판정 → 스폰당 1회 판정"으로 **탐지 입도를 한 단계 올리는 것**이 목표이고, 텍스트 휴리스틱이라는 성질은 §10·§12.3에 이미 정직 공개된 채로 **유지**된다(은폐 아님). 난이도 회피가 아니라 위협 모델(적대 우회가 아닌 망각) 대비 적정선 판단.

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `hooks/lib/workflow-spawns.js` | Workflow 스크립트 텍스트 → 스폰 객체 배열(agentType·model) 추출 | **신규** |
| `hooks/surface-model-policy.sh` | 파서 소비 + Rule C/C2/C3 판정 (per-spawn) | 수정 |
| `agents/explore-strict.md` | 탐색자 frontmatter(effort·tools) + 본문 정합 | 수정 |
| `docs/ai-context/model-policy.md` | 런타임 규범 SSOT — floor·탐색 행 | 수정 |
| `docs/ai-context/cross-family-review.md` | §3 검증자 문면 floor 정합 | 수정 |
| `CONTEXT.md` | 용어 2건 floor 정합 | 수정 |
| `skills/start-rpi-cycle/SKILL.md` | Phase R 웹 근거 조달 + 검증자 문면 | 수정 |
| `setup/verify-setup.sh` | seal #45 conjunct 갱신 | 수정 |
| `hooks/tests/{run-all.sh,cases.tsv}` | RED→GREEN 픽스처 | 수정 |
| `setup/install.sh` · `docs/ai-context/scaffold-registry.md` · `skills/ccs-delegation/SKILL.md` · `settings.example.json` | 선재 결함 | 수정 |

---

### Task 1: per-spawn 파서 `workflow-spawns.js` (TDD)

**Files:**
- Create: `hooks/lib/workflow-spawns.js`
- Modify: `hooks/tests/run-all.sh` (lib 섹션 — `test_lib` 사용), `hooks/tests/cases.tsv`

**Interfaces:**
- Consumes: 없음(신규).
- Produces: CLI 계약 — **stdin = 스크립트 텍스트**, **stdout = 스폰당 1행 `<agentType>\t<model>`**.
  `agentType` 미상 = `?`, `model` 미선언 = `-`. 파싱 실패/빈 입력 = 빈 출력 + exit 0(fail-open).
  Task 2가 이 출력을 읽는다.

- [x] **Step 1: 실패하는 테스트 작성**

`hooks/tests/run-all.sh`의 `# redirect-targets.js:` 케이스 블록 **뒤**(SURFACE-MODEL-POLICY 섹션 시작 전)에 추가:

```bash
# workflow-spawns.js: agent() 스폰당 "<agentType>\t<model>" (미선언 model = '-', 미상 agentType = '?')
WS="$LIB/workflow-spawns.js"
test_lib "171-ws-single-bare"   "$(printf 'execute-strict\t-')" \
  "$(printf "await agent('a', {agentType: 'execute-strict'})" | node "$WS")"
test_lib "172-ws-single-model"  "$(printf 'execute-strict\topus')" \
  "$(printf "await agent('a', {agentType: 'execute-strict', model: 'opus'})" | node "$WS")"
test_lib "173-ws-masking"       "$(printf 'execute-strict\topus\nexecute-strict\t-')" \
  "$(printf "await agent('a', {agentType: 'execute-strict', model: 'opus'})\nawait agent('b', {agentType: 'execute-strict'})" | node "$WS")"
test_lib "174-ws-model-first"   "$(printf 'review-strict\tsonnet')" \
  "$(printf "await agent('v', {model: 'sonnet', agentType: 'review-strict'})" | node "$WS")"
test_lib "175-ws-quoted-keys"   "$(printf 'execute-strict\topus')" \
  "$(printf 'await agent("a", {"agentType": "execute-strict", "model": "opus"})' | node "$WS")"
test_lib "176-ws-agentless"     "$(printf '?\t-')" \
  "$(printf "await agent('research', {label: 'r'})" | node "$WS")"
test_lib "177-ws-prompt-noise"  "$(printf 'execute-strict\t-')" \
  "$(printf "const P = \`policy: model: 'opus' required\`\nawait agent(P, {agentType: 'execute-strict'})" | node "$WS")"
test_lib "178-ws-empty"         "" "$(printf '' | node "$WS")"
```

`hooks/tests/cases.tsv` 말미(`surface-model-policy 19-spaced-model-key` 행 **뒤**)에 추가:

```
hooks-lib	171-ws-single-bare	0	test_lib
hooks-lib	172-ws-single-model	0	test_lib
hooks-lib	173-ws-masking	0	test_lib
hooks-lib	174-ws-model-first	0	test_lib
hooks-lib	175-ws-quoted-keys	0	test_lib
hooks-lib	176-ws-agentless	0	test_lib
hooks-lib	177-ws-prompt-noise	0	test_lib
hooks-lib	178-ws-empty	0	test_lib
```

- [x] **Step 2: 테스트 실패 확인 (RED)**

Run: `cd ~/.claude && bash hooks/tests/run-all.sh 2>&1 | grep -E "171-ws|172-ws|173-ws|Hook tests:"`
Expected: FAIL — `hooks-lib/171-ws-single-bare (exp=[execute-strict	-] got=[])` 등 8건 실패(파일 부재로 node가 stderr 후 빈 출력).

- [x] **Step 3: 최소 구현**

Create `hooks/lib/workflow-spawns.js`:

```javascript
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
```

- [x] **Step 4: 테스트 통과 확인 (GREEN)**

Run: `cd ~/.claude && bash hooks/tests/run-all.sh 2>&1 | tail -6`
Expected: `Hook tests: 205 / 205 passed` + `cases.tsv <-> run-all 정합 OK (205 declared == 205 run, 비주석 실재)`

※ 197 + 8 = 205. 이 수는 Task 2가 다시 늘린다.

- [x] **Step 5: 커밋**

```bash
cd ~/.claude
git add hooks/lib/workflow-spawns.js hooks/tests/run-all.sh hooks/tests/cases.tsv
git commit -m "feat(c13): per-spawn Workflow 파서 — bash 전역 OR 마스킹 해소 (spec §12.3)"
```

---

### Task 2: hook per-spawn 판정 + Rule C3(리서치 fan-out) (TDD)

**Files:**
- Modify: `hooks/surface-model-policy.sh:39-101` (Workflow 분기 전체)
- Modify: `hooks/tests/run-all.sh` (SMP 섹션), `hooks/tests/cases.tsv`

**Interfaces:**
- Consumes: Task 1의 `hooks/lib/workflow-spawns.js` — stdout `<agentType>\t<model>` 행들.
- Produces: hook 규칙 3종. **Rule C**(fable 세션 execute-strict 무선언/fable) · **Rule C2**(검증자 하향, floor=`max(세션,작업자)`) · **Rule C3**(fable 세션에서 agentType-less 스폰 = 세션 모델 상속 역류 — 신규, U1 표적).

- [x] **Step 1: 실패하는 테스트 작성**

`hooks/tests/run-all.sh`의 `test_smp "19-spaced-model-key"` 행 **뒤**에 추가:

```bash
# --- C13: per-spawn 판정 + Rule C3 (spec §12.3) ---
WF_MASK="export const meta = {name: 'x', description: 'x'}
await agent('a', {agentType: 'execute-strict', model: 'opus'})
await agent('b', {agentType: 'execute-strict'})"
WF_PROMPT_NOISE="export const meta = {name: 'x', description: 'x'}
const P = \`policy: model: 'opus' required\`
await agent(P, {agentType: 'execute-strict'})"
WF_COMMENT_ONLY="export const meta = {name: 'x', description: 'x'}
// 배경: execute-strict 는 구현용이다
await agent('research', {label: 'r', model: 'sonnet'})"
WF_FANOUT="export const meta = {name: 'x', description: 'x'}
await agent('research this', {label: 'r'})"
WF_FANOUT_OK="export const meta = {name: 'x', description: 'x'}
await agent('research this', {label: 'r', model: 'sonnet'})"
WF_EX_UP="export const meta = {name: 'x', description: 'x'}
await agent('a', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'sonnet'})"

# 20: 마스킹 — 준수 스폰이 무선언 스폰을 가리지 못함 (per-spawn 판정)
test_smp "20-rule-c-masking-detected" 0 1 "$(mk_wf_event script "$WF_MASK" "$SMP_FABLE_T" "smp20-$$")"
# 21: 프롬프트 문자열의 model: 리터럴은 선언으로 오인되지 않음 (미탐 해소)
test_smp "21-rule-c-prompt-noise" 0 1 "$(mk_wf_event script "$WF_PROMPT_NOISE" "$SMP_FABLE_T" "smp21-$$")"
# 22: 주석에만 execute-strict 언급 + 실제 스폰은 model 선언 → 무발화 (오탐 해소)
test_smp "22-rule-c-comment-no-fp" 0 0 "$(mk_wf_event script "$WF_COMMENT_ONLY" "$SMP_FABLE_T" "smp22-$$")"
# 23: Rule C3 — fable 세션 + agentType-less 무선언 스폰 → ALERT (사각 해소, U1 표적)
test_smp "23-rule-c3-fanout-inherit" 0 1 "$(mk_wf_event script "$WF_FANOUT" "$SMP_FABLE_T" "smp23-$$")"
# 24: 같은 fan-out 이 model 선언 → 무발화
test_smp "24-rule-c3-fanout-declared" 0 0 "$(mk_wf_event script "$WF_FANOUT_OK" "$SMP_FABLE_T" "smp24-$$")"
# 25: 비-fable 세션의 fan-out → Rule C3 비대상
test_smp "25-rule-c3-nonfable-ok" 0 0 "$(mk_wf_event script "$WF_FANOUT" "$SMP_SONNET_T" "smp25-$$")"
# 26: floor — sonnet 세션 + 실행자 opus 상향 + 검증자 sonnet → max(2,3)=3 > 2 위반 ALERT
test_smp "26-rule-c2-floor-worker" 0 1 "$(mk_wf_event script "$WF_EX_UP" "$SMP_SONNET_T" "smp26-$$")"
```

`hooks/tests/cases.tsv` 말미에 추가:

```
surface-model-policy	20-rule-c-masking-detected	0	mk_wf_event
surface-model-policy	21-rule-c-prompt-noise	0	mk_wf_event
surface-model-policy	22-rule-c-comment-no-fp	0	mk_wf_event
surface-model-policy	23-rule-c3-fanout-inherit	0	mk_wf_event
surface-model-policy	24-rule-c3-fanout-declared	0	mk_wf_event
surface-model-policy	25-rule-c3-nonfable-ok	0	mk_wf_event
surface-model-policy	26-rule-c2-floor-worker	0	mk_wf_event
```

또한 `run-all.sh`의 stale-marker 청소 행(`rm -f /tmp/model-policy-a-smp*` …)에 `c3` 마커를 추가:

```bash
rm -f /tmp/model-policy-a-smp* /tmp/model-policy-b-smp* /tmp/model-policy-c-smp* /tmp/model-policy-c2-smp* /tmp/model-policy-c3-smp* 2>/dev/null
```

- [x] **Step 2: 테스트 실패 확인 (RED)**

Run: `cd ~/.claude && bash hooks/tests/run-all.sh 2>&1 | grep -E "2[0-6]-rule|Hook tests:"`
Expected: FAIL — 최소 `20-rule-c-masking-detected (exit=0 ctx=0)`(마스킹 미탐)·`22-rule-c-comment-no-fp (exit=0 ctx=1)`(오탐)·`23-rule-c3-fanout-inherit (exit=0 ctx=0)`(사각)·`26-rule-c2-floor-worker (exit=0 ctx=0)`(floor 미구현) 4건.

- [x] **Step 3: 최소 구현**

`hooks/surface-model-policy.sh`의 39-101행(`if [ "$TOOL" = "Workflow" ]; then` ~ 대응 `fi`)을 **통째로** 아래로 교체:

```bash
# Rule C/C2/C3 — Workflow 경로 (C12 spec §10, C13 spec §12.3 per-spawn 전환). 정직 공개:
# 스폰 추출은 hooks/lib/workflow-spawns.js (node) — 스크립트 전역 boolean OR 로 인한 마스킹을
# 해소하고 프롬프트 문자열 내부를 마스킹해 오탐/미탐을 함께 줄인다. 동적 조립('execute'+'-strict')은
# 여전히 미검출(텍스트 휴리스틱 상한 — canonical workflows/rpi-implement.js 가 1차 방어).
# scriptPath 는 선두 256KiB 만 검사(초과분 미검사 — 수용 잔여).
if [ "$TOOL" = "Workflow" ]; then
  WF_TEXT=$(echo "$INPUT" | json_get 'tool_input.script')
  if [ -z "$WF_TEXT" ]; then
    WF_SP=$(echo "$INPUT" | json_get 'tool_input.scriptPath')
    case "$WF_SP" in "~/"*) WF_SP="$HOME/${WF_SP#\~/}" ;; esac   # 방어적 — 도구 자체는 ~ 미확장(절대경로 권장)
    { [ -n "$WF_SP" ] && [ -f "$WF_SP" ]; } && WF_TEXT=$(head -c 262144 "$WF_SP" 2>/dev/null) || WF_TEXT=""
  fi
  [ -n "$WF_TEXT" ] || exit 0
  TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
  SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"
  { [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0
  WF_SESSION_MODEL=$(session_model_of "$TRANSCRIPT")
  [ -n "$WF_SESSION_MODEL" ] || exit 0
  WF_TIER=$(tier_of "$WF_SESSION_MODEL")
  [ "$WF_TIER" = "0" ] && exit 0

  SPAWNS=$(printf '%s' "$WF_TEXT" | node "$HOME/.claude/hooks/lib/workflow-spawns.js" 2>/dev/null)
  [ -n "$SPAWNS" ] || exit 0

  # 1패스: 위반 수집. WORKER_TIER = 실행자 최고 티어(검증자 floor 산정용 — spec §12.1).
  C_HIT=0; C3_HIT=0; C2_HIT=""; WORKER_TIER="$WF_TIER"
  while IFS="$(printf '\t')" read -r SP_TYPE SP_MODEL; do
    [ -n "$SP_TYPE" ] || continue
    if [ "$SP_TYPE" = "execute-strict" ]; then
      SP_T=$(tier_of "$SP_MODEL")
      [ "$SP_T" -gt "$WORKER_TIER" ] 2>/dev/null && WORKER_TIER="$SP_T"
      # Rule C: fable 세션의 실행자가 무선언(-) 또는 inherit/fable 명시 = 하향 미적용
      if [ "$WF_TIER" = "4" ]; then
        case "$SP_MODEL" in
          -|inherit) C_HIT=1 ;;
          *) [ "$SP_T" = "4" ] && C_HIT=1 ;;
        esac
      fi
    elif [ "$SP_TYPE" = "?" ]; then
      # Rule C3: agentType-less 스폰은 세션 모델을 상속한다(spec §11.3) — fable 세션이면 역류
      [ "$WF_TIER" = "4" ] && [ "$SP_MODEL" = "-" ] && C3_HIT=1
    fi
  done <<EOF
$SPAWNS
EOF

  # 2패스: 검증자 floor = max(세션, 작업자) — spec §12.1
  while IFS="$(printf '\t')" read -r SP_TYPE SP_MODEL; do
    [ "$SP_TYPE" = "review-strict" ] || continue
    [ "$SP_MODEL" = "-" ] && continue          # 무지정 = 상속 = 세션 티어 (frontmatter model: inherit)
    SP_T=$(tier_of "$SP_MODEL")
    [ "$SP_T" = "0" ] && continue
    [ "$SP_T" -lt "$WORKER_TIER" ] 2>/dev/null && C2_HIT="$SP_MODEL"
  done <<EOF
$SPAWNS
EOF

  if [ "$C_HIT" = "1" ]; then
    MARKER="$(session_marker model-policy-c "$SESSION_ID")"
    if [ ! -f "$MARKER" ]; then
      touch "$MARKER" 2>/dev/null || true
      hook_log "surface-model-policy" "workflow:execute-strict-nomodel" "ALERT" "rule-c-workflow-downshift-missing"
      emit_additional_context "[model-policy] Workflow 스크립트가 execute-strict 스테이지를 model 지정 없이(또는 fable 로) 스폰합니다 — fable 세션의 구현 스테이지는 model:'opus' 고정이 정책. canonical: \$HOME/.claude/workflows/rpi-implement.js 를 절대경로 scriptPath 로 사용 권장(도구는 ~ 미확장). SSOT: docs/ai-context/model-policy.md §2 모드(A)·spec §10 (advisory · 1세션 1회 · 차단 아님)"
      exit 0
    fi
  fi
  if [ "$C3_HIT" = "1" ]; then
    MARKER="$(session_marker model-policy-c3 "$SESSION_ID")"
    if [ ! -f "$MARKER" ]; then
      touch "$MARKER" 2>/dev/null || true
      hook_log "surface-model-policy" "workflow:agentless-inherit" "ALERT" "rule-c3-workflow-fanout-inherit"
      emit_additional_context "[model-policy] Workflow 스크립트가 agentType 없는 서브에이전트를 model 지정 없이 스폰합니다 — 이 경로는 **세션 모델을 상속**하므로(spec §11.3) fable 세션에선 리서치 fan-out 전체가 플래그십으로 역류합니다. 역할에 맞는 하위 모델을 opts.model 로 명시하십시오(탐색=sonnet). SSOT: docs/ai-context/model-policy.md (advisory · 1세션 1회 · 차단 아님)"
      exit 0
    fi
  fi
  if [ -n "$C2_HIT" ]; then
    MARKER="$(session_marker model-policy-c2 "$SESSION_ID")"
    if [ ! -f "$MARKER" ]; then
      touch "$MARKER" 2>/dev/null || true
      hook_log "surface-model-policy" "workflow:review-strict:$C2_HIT" "ALERT" "rule-c2-workflow-verifier-downshift"
      emit_additional_context "[model-policy] Workflow 스크립트가 검증자(review-strict)를 하향 model('$C2_HIT')로 스폰합니다 — 검증자 기준선은 max(세션 티어, 작업자 티어)이며 그 아래로 내려갈 수 없습니다(spec §12.1). 무지정(상속)이 기본이고, 의도 하향이면 DOWNGRADE-DECLARED(사유) 선언이 필요합니다. (advisory · 1세션 1회 · 차단 아님)"
      exit 0
    fi
  fi
  exit 0
fi
```

- [x] **Step 4: 테스트 통과 확인 (GREEN)**

Run: `cd ~/.claude && bash hooks/tests/run-all.sh 2>&1 | tail -6`
Expected: `Hook tests: 212 / 212 passed` + 정합 OK (205 + 7 = 212). 기존 09~19 케이스 **무회귀** 필수.

- [x] **Step 5: 커밋**

```bash
cd ~/.claude
git add hooks/surface-model-policy.sh hooks/tests/run-all.sh hooks/tests/cases.tsv
git commit -m "feat(c13): Rule C/C2/C3 per-spawn 판정 + 검증자 floor max(세션,작업자)"
```

---

### Task 3: 탐색자 강화 — WebSearch + effort xhigh (spec §12.2·U4)

**Files:**
- Modify: `agents/explore-strict.md:15` (effort), `:16` (tools), `:22` (Rule-of-Two 본문), `:24` (기본값 본문)
- Modify: `setup/verify-setup.sh:453` (seal #45 effort 앵커)
- Modify: `SECURITY.md:71,73` (reader 도구 목록)

**Interfaces:**
- Consumes: 없음.
- Produces: explore-strict = `model: sonnet` + `effort: xhigh` + `tools: Read, Grep, Glob, WebFetch, WebSearch`.

- [x] **Step 1: seal 이 현재 값을 잠그고 있음을 확인 (RED 유도)**

Run: `cd ~/.claude && grep -n "effort:" agents/explore-strict.md && grep -n "effort:\[\[:space:\]\]\*medium" setup/verify-setup.sh`
Expected: `15:effort: medium` + `453:grep -qE '^effort:[[:space:]]*medium' …` — 둘이 쌍이므로 한쪽만 고치면 seal FAIL.

- [x] **Step 2: frontmatter 3줄 수정**

`agents/explore-strict.md:15`:
```
effort: xhigh
```

`agents/explore-strict.md:16`:
```
tools: Read, Grep, Glob, WebFetch, WebSearch
```

`agents/explore-strict.md:22` (Rule-of-Two 인용문) — 도구 목록과 근거 갱신:
```
> ★Rule-of-Two (SECURITY.md): 이 reader의 쓰기도구 미부여(`tools: Read, Grep, Glob, WebFetch, WebSearch`)는 *의도된 lethal-trifecta 방어*다 — untrusted 웹(WebFetch/WebSearch)+읽기는 하되, 행동은 오케스트레이터 검증 후 `execute-strict`가 수행한다. verify-setup #41이 이 제약을 봉인(Write/Edit/Bash 추가 시 FAIL). ※WebSearch 추가(C13)는 새 위험 축이 아니다 — WebFetch(임의 URL)가 이미 더 넓은 인입 표면이고, WebSearch는 Anthropic 백엔드 질의로 한정된다(spec §12.2).
```

`agents/explore-strict.md:24` (기본값 본문):
```
> 모델 기본값 sonnet+effort xhigh(frontmatter — 역할×모델 매트릭스, docs/ai-context/model-policy.md). xhigh 근거: 공식 effort 가이드가 "extended exploration, such as repeated tool calling and detailed search"에 xhigh를 권고하고, Sonnet 5 기본값이 high이므로 종전 medium은 기본값 아래 하향이었다(spec §11.6). 판단-heavy 탐색은 호출 인자 `model` 상향 또는 메인 직접이 탈출구. ※WebSearch 는 세션당 200회 상한을 메인·전 서브에이전트가 공유한다(공식) — fan-out 설계 시 고려.
```

- [x] **Step 3: seal #45 앵커를 새 값으로 갱신**

`setup/verify-setup.sh:453`:
```bash
grep -qE '^effort:[[:space:]]*xhigh' "$HOME/.claude/agents/explore-strict.md" 2>/dev/null || MP_OK=0
```

`setup/verify-setup.sh:444` 주석의 `sonnet+medium` → `sonnet+xhigh`, `:26` 주석도 동일 치환.

`setup/verify-setup.sh:445` 주석 — floor 하에서 "상속=티어 보장"이 더 이상 참이 아니므로 정정:
```
#     ③ execute/review `model: inherit` 유지 + review-strict effort 키 부재(무지정=세션 상속의 물리 앵커
#        — 기준선 자체는 max(세션, 작업자)이며 inherit 은 그중 세션 축만 보장, spec §12.1)
```

- [x] **Step 4: SECURITY.md reader 서술 갱신**

`SECURITY.md:71,73`의 explore-strict 도구 목록에 `WebSearch`를 추가(문장 구조는 유지, 목록만 갱신).

- [x] **Step 5: 검증**

Run: `cd ~/.claude && bash setup/verify-setup.sh 2>&1 | tail -3 && bash setup/tests/seal-regression.test.sh 2>&1 | tail -3`
Expected: `PASS=81 FAIL=0` (카운트 불변 — 값 교체이므로) + seal-regression 전건 통과.

- [x] **Step 6: 커밋**

```bash
cd ~/.claude
git add agents/explore-strict.md setup/verify-setup.sh SECURITY.md
git commit -m "feat(c13): explore-strict = sonnet+xhigh+WebSearch (spec §12.2, U2·U4)"
```

---

### Task 4: 문서 floor 정합 + Phase R 웹 근거 조달 경로

**Files:**
- Modify: `docs/ai-context/model-policy.md:19,22` · `docs/ai-context/cross-family-review.md:51` · `CONTEXT.md:85,89` · `skills/start-rpi-cycle/SKILL.md:48,122,139` + Phase R step C
- Modify: `docs/ai-context/model-policy.md:18,29` (탐색 행 medium→xhigh)

**Interfaces:**
- Consumes: Task 2의 floor 정의, Task 3의 frontmatter 값.
- Produces: 문서 전 계층이 `max(세션, 작업자)` 단일 표현으로 수렴.

- [x] **Step 1: model-policy.md 매트릭스 갱신**

`:18` 탐색 행의 effort 셀 `**medium** (frontmatter 기본)` → `**xhigh** (frontmatter 기본)`, 비고에 WebSearch 보유 추가.
`:19` 검증 행 비고: `검증자 티어 ≥ **세션** 보장 (cross-family-review.md §3)` → `검증자 티어 ≥ **max(세션, 작업자)** = 검증자 기준선(spec §12.1). 실행자를 세션 위로 상향하면 검증자도 그 티어 이상이어야 한다`.
`:22` 하향 규칙: `**하향**: 검증자 금지` → `**하향**: 검증자는 기준선 max(세션, 작업자) 미만 금지`.
`:29` 모드 (C)의 `(sonnet+medium)` → `(sonnet+xhigh+WebSearch)`.

- [x] **Step 2: cross-family-review.md §3 갱신**

`:51` 첫 문장: `"검증자 티어 ≥ 작업자 티어"를 공짜로 보장한다` → `"검증자 티어 ≥ **max(세션, 작업자)**"(= 검증자 기준선, spec §12.1)를 공짜로 보장한다 — 무지정 상속이 세션 티어를 주고, 작업자가 세션 위로 상향된 경우엔 검증자도 동반 상향이 필요하다`.

- [x] **Step 3: CONTEXT.md 2곳 갱신**

`:85` 말미 `검증자(review-strict)는 대상 아님 — 상속 유지+하향 금지(cross-family §3)` → `검증자(review-strict)는 대상 아님 — [[검증자 기준선]] max(세션, 작업자)가 별도 규율`.
`:89` `하향은 검증자 금지` → `하향은 검증자 기준선(max(세션,작업자)) 미만 금지`.

- [x] **Step 4: start-rpi-cycle SKILL.md 갱신**

`:48` `sonnet+medium` → `sonnet+xhigh+WebSearch`.
`:122` `**model/effort 무지정**(상속 — 검증자 하향 금지)` → `**model/effort 무지정**(상속 — 검증자 기준선 max(세션,작업자) 유지)`.
`:139` `검증자(review-strict)는 항상 model 무지정(상속).` → `검증자(review-strict)는 model 무지정(상속)이 기본 — 기준선은 max(세션, 작업자)이며 실행자를 세션 위로 상향했으면 검증자도 동반 상향.`

Phase R step C 블록(`※ explore-strict 는 frontmatter 기본 sonnet+medium …` 줄)을 아래로 교체:

```
   ※ explore-strict 는 frontmatter 기본 sonnet+xhigh+WebSearch — 판단-heavy 탐색만 호출 인자 model 상향 (SSOT: docs/ai-context/model-policy.md)
   ※ **웹 근거 조달**: 외부 공식 문서·벤치·릴리스노트가 필요한 R 은 explore-strict 에 WebSearch/WebFetch 를 명시 위임한다
     (builtin claude-code-guide 등 규약 밖 경로로 새지 않게 — 그 경로는 티어 무관리, spec §11.7).
     프롬프트에 "URL + verbatim 인용 필수, 없으면 '공식 근거 없음' 명시"를 넣을 것(무근거 단언 차단).
     ※WebSearch 는 세션당 200회를 메인·전 서브에이전트가 공유한다(공식) — fan-out 폭 설계 시 고려.
```

- [x] **Step 5: canonical 캐리어에 모드-A 전용 + floor 잔여 명시 (spec §12.1 "채택 해소" ①②)**

`workflows/rpi-implement.js` 헤더 주석부(파일 선두 `//` 블록의 마지막 줄 뒤)에 아래 4줄 추가:

```javascript
// 적용 범위: **모드 (A) fable + ultracode 전용**(docs/ai-context/model-policy.md §2). stage1 은 opus 고정이고
//   stage2 는 무지정(상속)이라, fable/opus 세션에선 검증자 기준선 max(세션, 작업자)를 충족한다.
//   ※sonnet/haiku 세션에서 쓰면 검증자(=세션 티어) < 실행자(opus) 로 기준선 미달이며 **탈출구가 없다**
//     (stage2 model 을 넘길 args 필드 부재) — 수용 잔여, spec §12.1. 그 세션에선 이 캐리어를 쓰지 말 것.
```

- [x] **Step 6: 검증**

Run: `cd ~/.claude && bash setup/verify-setup.sh 2>&1 | tail -3`
Expected: `PASS=81 FAIL=0` (#17 cross-doc drift·#22 phase-skills parity 포함 green). seal #45가 `rpi-implement.js`의 `model: 'opus'`·effort 분기 토큰을 검사하므로 주석 추가는 무영향.

- [x] **Step 7: 커밋**

```bash
cd ~/.claude
git add docs/ai-context/model-policy.md docs/ai-context/cross-family-review.md CONTEXT.md skills/start-rpi-cycle/SKILL.md workflows/rpi-implement.js
git commit -m "docs(c13): 검증자 기준선 max(세션,작업자) 전 계층 정합 + Phase R 웹 근거 조달 경로"
```

---

### Task 5: 선재 결함 정정 (spec §12.4 — 6건)

**Files:**
- Modify: `setup/install.sh:61-75` (REQUIRED) · `docs/ai-context/scaffold-registry.md:50` + Seals 표 · `skills/ccs-delegation/SKILL.md:5,24,52` · `settings.example.json`
- Modify: `docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md:89` (포인터 주석만)

**Interfaces:**
- Consumes: 없음(독립).
- Produces: 없음(정정만).

- [x] **Step 1: install.sh 누락 hook 2건 추가**

`setup/install.sh`의 REQUIRED 배열에서 `"$TARGET/hooks/surface-constitution.sh"` 행 **뒤**에 2줄 추가:

```bash
  "$TARGET/hooks/surface-model-policy.sh"
  "$TARGET/hooks/worktree-teardown.sh"
```

- [x] **Step 2: scaffold-registry seal #45 등재**

`docs/ai-context/scaffold-registry.md:50` 제목: `## Drift Seals (verify-setup.sh #17~#44, −#26 소각 = 27)` → `## Drift Seals (verify-setup.sh #17~#45, −#26 소각 = 28)`
Seals 표 말미(#44 행 뒤)에 1행 추가. **표는 3열**(`| Seal | 봉인 대상 | 추적 |`)이므로 그대로 맞춘다:

```
| #45 | 역할×모델 매트릭스 물화 (model-policy.md 앵커·explore frontmatter·execute/review inherit·`Agent\|Workflow` 매처·rpi-implement.js 토큰·skill 토큰) | C11/C12/C13 |
```

※ 셀 안의 `|`는 `\|`로 이스케이프해야 표가 깨지지 않는다(매처 문자열 `Agent|Workflow`).

- [x] **Step 3: ccs-delegation 경로 정정**

`skills/ccs-delegation/SKILL.md`의 `~/.ccs/config.json` → `~/.ccs/config.yaml` 치환.
**실측 4곳**: `:5`, `:24`, `:52`, 그리고 `:55`(`"No profiles in config.json"` — 에러 문구 안).
Run으로 잔여 확인: `grep -c "config\.json" skills/ccs-delegation/SKILL.md` → `0`이어야 한다.

- [x] **Step 4: settings.example.json 에 모델 바인딩 env 주석 추가**

`settings.example.json`의 `env` 블록에 3키 추가(값은 alias 자리표시 — 실제 바인딩은 각 머신 settings.json):

```json
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5-20251001",
```

※ `settings.example.json`은 **추적본**이므로 커밋 대상. `settings.json`(live)은 **절대 add 금지**.
※ 이 값들은 "버전 바인딩 SSOT = settings.json env"(model-policy.md 헤더)의 신규-PC 폴백을 실재화한다.

- [x] **Step 5: 구 spec 중복 기술에 포인터 주석**

`docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md:89` 행 **앞**에 1줄 삽입(본문 편집 금지 — genesis-record):

```
> ※ (C13, 2026-07-27) 아래 cross-family 프로토콜 기술은 **작성 시점 기록**이다. 현행 SSOT는 `docs/ai-context/cross-family-review.md` §2 — 버전 리터럴 포함 실행 규약은 그쪽을 따를 것.
```

- [x] **Step 6: 검증 + 커밋**

Run: `cd ~/.claude && bash setup/verify-setup.sh 2>&1 | tail -3 && node -e "JSON.parse(require('fs').readFileSync('settings.example.json','utf8')); console.log('settings.example.json JSON OK')"`
Expected: `PASS=81 FAIL=0` + `settings.example.json JSON OK`

```bash
cd ~/.claude
git add setup/install.sh docs/ai-context/scaffold-registry.md skills/ccs-delegation/SKILL.md settings.example.json docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md
git commit -m "fix(c13): 선재 결함 6건 — install REQUIRED·seal #45 등재·ccs 경로·example env·구 spec 포인터"
```

---

### Task 6: 전체 검증 + README 카운트 동기

**Files:**
- Modify: `README.md:276,514` (케이스 수 197 → 212)

**Interfaces:**
- Consumes: Task 1·2의 최종 케이스 수.
- Produces: 없음(최종 게이트).

- [x] **Step 1: 실제 케이스 수 확인**

Run: `cd ~/.claude && grep -cvE '^[[:space:]]*(#|$)' hooks/tests/cases.tsv`
Expected: `212`

- [x] **Step 2: README 2곳 동기**

`README.md:276`: `197 case (run-all과 1:1 정합, 100% 구현)` → `212 case (run-all과 1:1 정합, 100% 구현)`
`README.md:514`: `(197 케이스, run-all과 1:1 정합, 100% 통과)` → `(212 케이스, run-all과 1:1 정합, 100% 통과)`

- [x] **Step 3: 3대 검증 포그라운드 실행**

```bash
cd ~/.claude
bash hooks/tests/run-all.sh 2>&1 | tail -6
bash setup/verify-setup.sh 2>&1 | tail -4
bash setup/tests/seal-regression.test.sh 2>&1 | tail -4
```
Expected: `212 / 212 passed` + 정합 OK · `PASS=81 FAIL=0` · seal-regression 전건 통과.

- [x] **Step 4: 라이브 실증 (Rule C3 발화 확인)**

fable transcript 픽스처 + 순수 fan-out 스크립트를 실물 hook에 파이프해 ALERT를 캡처한다:

```bash
cd ~/.claude
T=$(mktemp /tmp/c13-fable-XXXXXX.jsonl)
printf '{"type":"assistant","message":{"model":"claude-fable-5","content":[]}}\n' > "$T"
S="export const meta = {name: 'x', description: 'x'}
await agent('research this', {label: 'r'})"
S="$S" TP="$T" SID="c13-live-$RANDOM" node -e '
const o={session_id:process.env.SID,transcript_path:process.env.TP,cwd:"",permission_mode:"bypassPermissions",
effort:{level:"xhigh"},hook_event_name:"PreToolUse",tool_name:"Workflow",
tool_input:{script:process.env.S},tool_use_id:"t"};console.log(JSON.stringify(o));' \
  | bash hooks/surface-model-policy.sh
rm -f "$T"
```
Expected: `additionalContext`에 `rule-c3` 취지 메시지(agentType 없는 스폰 = 세션 모델 상속) 출력.

- [x] **Step 5: 커밋**

```bash
cd ~/.claude
git add README.md
git commit -m "chore(c13): README 케이스 카운트 197→212 동기"
```

---

## Self-Review

**1. Spec coverage** — §12.1 floor → Task 2(코드)+Task 4(문서) · §12.2 도구배선 → Task 3 · §12.3 결함 4종(미탐·오탐·사각·마스킹) → Task 1·2 픽스처 20~25 · §12.4 선재결함 6건 → Task 5(5건) + structure-map은 genesis 판정이라 무변경(spec 기록됨) · U4 xhigh → Task 3 · U2 웹 근거 → Task 3+4. 미커버 0.

**2. Placeholder scan** — TBD/TODO/"적절히" 0건. 모든 코드 스텝에 실제 코드 블록 포함.

**3. Type consistency** — 파서 계약 `<agentType>\t<model>`(미선언 `-`, 미상 `?`)이 Task 1 정의 → Task 2 소비에서 동일. 마커 이름 `model-policy-c3`가 hook·run-all 청소 행에서 일치. 케이스 수 197→205(Task 1)→212(Task 2)→README(Task 6) 연쇄 일치.

---

### Task 7: GPT 교차패밀리 리뷰 REAL 결함 정정 (파서 렉서 전환)

**Files:**
- Modify: `hooks/lib/workflow-spawns.js` (전면 재작성 — 정규식 휴리스틱 → 렉서 + 프로퍼티 워크)
- Modify: `hooks/surface-model-policy.sh:47-124` (2패스 floor 판정 + 규칙 우선순위 유실 + `*` agentType)
- Modify: `hooks/tests/run-all.sh`, `hooks/tests/cases.tsv` (회귀 픽스처)
- Modify: `docs/superpowers/specs/2026-07-25-model-policy-design.md` (§12.6 신설 — 트리아지 기록)

**근거:** Closeout Step C-1 교차패밀리(GPT-5.6 Sol) 적대 리뷰가 19건 제기 → 메인 트리아지에서 REAL 판정분.
`cross-family-review.md` §2 "GPT는 추가 발견자이지 판정자가 아니다" 규약대로 발견마다 원문 실측 대조 후 편입.

**Interfaces:**
- Produces: 파서 출력 계약 확장 — agentType 3-값(`<리터럴>` / `?`=키 부재 / `*`=키 존재·비리터럴).
  model 은 2-값 유지(`<리터럴>` / `-`=부재 또는 비리터럴).

- [x] **Step 1: RED — GPT 재현 케이스가 현 파서에서 실패함을 확인**

```bash
cd ~/.claude && P=hooks/lib/workflow-spawns.js
printf 'const s = "agent('p', {agentType:'execute-strict', model:'opus'})";' | node $P   # A1 기대 "" 실제 execute-strict/opus
printf "agent('p', {agentType:'review-strict', meta:{model:'haiku'}, model:'opus'})" | node $P                    # A6 기대 review-strict/opus
printf "agent('p', {myagentType:'execute-strict', fallback_model:'opus'})" | node $P                              # A7 기대 ""
```

- [x] **Step 2: 파서를 렉서 기반으로 재작성**

주석·문자열·템플릿(`${}` 중첩)·정규식 본문을 인덱스 보존 마스킹 → `(?<![\w$.])agent\s*\(` 로 스폰 탐색 →
호출 인자 깊이 0 의 첫 `{` 를 opts 로 확정 → 깊이 0 프로퍼티 워크(last-write-wins) → 값은 단일 리터럴만 채택 + escape 디코드.
정지성: 입력 512KiB · 스폰 200개 상한.

- [x] **Step 3: hook 판정 3건 정정**

(a) 2패스 floor: `SP_MODEL = "-"`(상속=세션 티어)를 폐기하지 않고 `WF_TIER` 로 평가 — GPT [C]1/[C]3/[D]1/[D]2.
(b) tier 0(기타 모델) 검증자를 면제하지 않음 — GPT [C]2.
(c) 규칙 우선순위 유실 제거: C/C3/C2 를 각각 독립 마커로 발화(첫 규칙이 나머지를 삼키지 않음) — GPT [C]5.
(d) `*`(동적 agentType)는 Rule C3 상속 단언에서 제외 — GPT [C]4.

- [x] **Step 4: 회귀 픽스처 추가 후 GREEN 확인**

```bash
cd ~/.claude && bash hooks/tests/run-all.sh 2>&1 | tail -3
```

- [x] **Step 5: spec §12.6 트리아지 기록 + 커밋**

