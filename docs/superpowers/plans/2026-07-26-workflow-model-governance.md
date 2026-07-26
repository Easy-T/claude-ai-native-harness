# Workflow Model Governance (ultracode 경로 opus 고정) Implementation Plan

**Status:** active
**RPI-Cycle:** 63
**Started:** 2026-07-26

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ultracode Workflow 경로의 동적 서브에이전트를 canonical 파일+L2 Rule C+L3 seal로 opus 고정 — spec §10 (C12).

**Architecture:** `workflows/rpi-implement.js`(git-추적)가 (d) 경로 2-stage 파이프라인을 코드로 고정. surface-model-policy.sh에 Rule C(Workflow 매처) 확장, settings 양쪽 배선, seal #45 conjunct 확장(카운트 불변). 실측 shape는 spec §10 probe 기록.

**Tech Stack:** Workflow script(JS, meta 리터럴), bash hook 확장, run-all 픽스처 5케이스, verify-setup grep seal.

**Best-Direction Check:** 최선안 = canonical 파일(코드 고정)+L2 텍스트 휴리스틱(오탐 0 설계)+L3 conjunct — spec §10에서 "hook이 스크립트 AST 파싱" 대안은 bash 계층에서 비현실(파서 표면 증가)이라 텍스트 토큰 검사가 실질 최선, 회피는 망각-위협-모델 한정으로 수용 선언 / 채택안 = 동일. **DOWNGRADE-DECLARED: 없음.**

## Global Constraints

- C11 plan의 Global Constraints 전부 승계 (bash-only seal·포그라운드 검증·CLAUDE.md 무변경·#23 parity·advisory exit 0·schema 금지).
- **Phase I는 (d) Workflow dogfood** — 이 plan의 task들을 rpi-implement.js가 아닌 인라인 Workflow(동일 규약)로 실행: canonical 파일이 아직 없는 부트스트랩 사이클이므로 인라인 스크립트가 §10 규약(stage1 opus·stage2 상속)을 따른다.
- run-all 전체는 ~14분 — 최종 검증 1회만 전체 실행, task별 GREEN은 SMP 섹션 단독 추출 실행으로 확인.
- seal #45는 conjunct **확장**(신규 번호 아님) — 카운트 81 불변, README 무변경. run-all은 191(186+5)로 README 2곳 갱신.

---

### Task 1: `workflows/rpi-implement.js` canonical 파이프라인 신설

**Files:**
- Create: `workflows/rpi-implement.js`

**Interfaces:**
- Produces: (d) 경로가 `Workflow({scriptPath: '~/.claude/workflows/rpi-implement.js', args: [...]})`로 호출할 파일. seal 앵커 토큰 `model: 'opus'`·`effort: t.heavy ? 'high' : 'medium'`.
- args 계약: `[{title, promptVerbatim, files, successCriteria, heavy, worktree}]` (spec §10.1).

- [x] **Step 1: 파일 생성 (아래 내용 verbatim)**

```javascript
export const meta = {
  name: 'rpi-implement',
  description: 'RPIC Phase I (d) canonical 2-stage pipeline — execute(opus) → review(inherit)',
  phases: [
    { title: 'Implement', detail: 'plan task별 execute-strict (opus, heavy→high/light→medium)' },
    { title: 'Verify', detail: 'task별 review-strict (모델 무지정=세션 상속 — 검증자 하향 금지)' },
  ],
}
// 역할×모델 매트릭스 canonical 캐리어 (spec 2026-07-25 §10, SSOT: docs/ai-context/model-policy.md).
// args = [{title, promptVerbatim, files[], successCriteria, heavy, worktree}]
// - promptVerbatim: plan task 본문 원문 (TDD-verbatim — 요약 금지, RED/GREEN 증거 포함 강제)
// - heavy: 코드/TDD/다파일=true(effort high), 순수 문서·기계 편집=false(medium)
// - worktree: 같은 파일을 동시 수정하는 task ≥2일 때 true (stage2는 같은 worktree에서 리뷰)
// 불변식: stage1 model 고정 opus / stage2 model·effort 무지정(상속) / schema 금지(wrapper StructuredOutput 부재)
// / 커밋은 여기서 하지 않는다(병렬 index.lock 경합 — 메인이 그룹 커밋).
if (!Array.isArray(args) || args.length === 0) {
  throw new Error('rpi-implement: args must be a non-empty task array — [{title, promptVerbatim, files, successCriteria, heavy, worktree}]')
}
const results = await pipeline(
  args,
  (t, _o, i) => agent(
    `plan task 본문 verbatim — 이대로 수행 (요약·재서술 금지, RED/GREEN 증거를 보고에 원문 인용):\n\n${t.promptVerbatim}\n\n` +
    `scope: 명시 파일만 수정 — ${JSON.stringify(t.files)}. 커밋하지 말 것(메인이 그룹 커밋).`,
    {
      agentType: 'execute-strict',
      model: 'opus',
      effort: t.heavy ? 'high' : 'medium',
      label: `implement:${t.title}`,
      phase: 'Implement',
      ...(t.worktree ? { isolation: 'worktree' } : {}),
    }
  ),
  (stage1Report, t) => agent(
    `task: "${t.title}" 구현 검증 (stage1 산출 대조 — 아래 보고와 실파일 diff를 모두 읽고 판정).\n\n` +
    `stage1 보고 원문:\n${String(stage1Report).slice(0, 30000)}\n\n검증 대상 파일: ${JSON.stringify(t.files)}\n\n` +
    `success_criteria: PASS only if ALL:\n${t.successCriteria}\n` +
    `- stage1 보고에 RED 증거(실패 출력)와 GREEN 증거(통과 출력)가 모두 있음 (없으면 FAIL — TDD-verbatim 규약)\n` +
    `- 수정 파일이 명시 목록 ${JSON.stringify(t.files)} 밖으로 나가지 않음`,
    {
      agentType: 'review-strict',
      label: `verify:${t.title}`,
      phase: 'Verify',
      ...(t.worktree ? { isolation: 'worktree' } : {}),
    }
  )
)
const flat = results.filter(Boolean)
log(`rpi-implement: ${flat.length}/${args.length} task 파이프라인 완료`)
return { tasks: args.map((t, i) => ({ title: t.title, verdict: results[i] ? String(results[i]).slice(0, 2000) : 'DROPPED(stage 오류)' })) }
```

- [x] **Step 2: 검증 — seal 앵커 grep + meta 리터럴 파스**

Run: `grep -E "model: 'opus'" workflows/rpi-implement.js && grep -E "effort: t.heavy" workflows/rpi-implement.js && node --input-type=module -e "$(sed -n '1,8p' workflows/rpi-implement.js); console.log('META-OK', meta.name)"`
Expected: 앵커 2줄 + `META-OK rpi-implement` (Gate P 정정: sed 1,10p는 주석 라인이 console.log를 흡수 — 1,8p(meta 블록만)로 실측 재현 확인됨)

### Task 2: RED — Rule C 픽스처 5케이스 (run-all + cases.tsv)

**Files:**
- Modify: `hooks/tests/run-all.sh` (SMP 섹션 끝에 이어서)
- Modify: `hooks/tests/cases.tsv` (5행 추가)

**Interfaces:**
- Consumes: spec §10 실측 Workflow stdin shape verbatim.
- Produces: 케이스 09~13 — Task 3의 Rule C가 GREEN 대상.

- [x] **Step 1: run-all.sh SMP 섹션 끝(`test_smp "08-…"` 라인 뒤)에 추가**

```bash
# --- Rule C (Workflow 매처, C12 spec §10): 실측 shape verbatim ---
mk_wf_event() {
  local body_kind="$1"; local body_val="$2"; local transcript="$3"; local sid="$4"
  KIND="$body_kind" VAL="$body_val" TP="$transcript" SID="$sid" node -e '
    const ti = {};
    ti[process.env.KIND] = process.env.VAL;
    const o = {session_id:process.env.SID, transcript_path:process.env.TP, cwd:"", permission_mode:"bypassPermissions",
               effort:{level:"xhigh"}, hook_event_name:"PreToolUse", tool_name:"Workflow", tool_input:ti, tool_use_id:"toolu_x"};
    console.log(JSON.stringify(o));
  '
}
WF_BAD_SCRIPT="export const meta = {name: 'x', description: 'x'}
await agent('do it', {agentType: 'execute-strict'})"
WF_OK_SCRIPT="export const meta = {name: 'x', description: 'x'}
await agent('do it', {agentType: 'execute-strict', model: 'opus'})"
WF_SP_BAD=$(mktemp "$SCRATCH/wf-sp-bad-XXXXXX.js"); printf '%s\n' "$WF_BAD_SCRIPT" > "$WF_SP_BAD"

# 09: fable + 인라인 script + execute-strict + model 부재 → Rule C ALERT
test_smp "09-rule-c-inline-nomodel" 0 1 "$(mk_wf_event script "$WF_BAD_SCRIPT" "$SMP_FABLE_T" "smp09-$$")"
# 10: fable + 인라인 + model:'opus' 존재 → 무출력
test_smp "10-rule-c-inline-opus-ok" 0 0 "$(mk_wf_event script "$WF_OK_SCRIPT" "$SMP_FABLE_T" "smp10-$$")"
# 11: fable + scriptPath 파일에 execute-strict+무model → ALERT
test_smp "11-rule-c-scriptpath-nomodel" 0 1 "$(mk_wf_event scriptPath "$WF_SP_BAD" "$SMP_FABLE_T" "smp11-$$")"
# 12: sonnet 세션 → Rule C 비대상 (무출력)
test_smp "12-rule-c-nonfable-ok" 0 0 "$(mk_wf_event script "$WF_BAD_SCRIPT" "$SMP_SONNET_T" "smp12-$$")"
# 13: scriptPath 파일 부재 → fail-open 무출력
test_smp "13-rule-c-scriptpath-missing" 0 0 "$(mk_wf_event scriptPath "$SCRATCH/wf-none.js" "$SMP_FABLE_T" "smp13-$$")"
```

- [x] **Step 2: cases.tsv 5행 추가 (탭 구분)**

```
surface-model-policy	09-rule-c-inline-nomodel	0	mk_wf_event
surface-model-policy	10-rule-c-inline-opus-ok	0	mk_wf_event
surface-model-policy	11-rule-c-scriptpath-nomodel	0	mk_wf_event
surface-model-policy	12-rule-c-nonfable-ok	0	mk_wf_event
surface-model-policy	13-rule-c-scriptpath-missing	0	mk_wf_event
```

- [x] **Step 3: RED 확인 — SMP 섹션 단독 추출 실행** (전체 스위트는 Task 5에서 1회)

Run: run-all.sh에서 SMP 섹션만 추출한 임시 러너(mktemp)로 13케이스 실행
Expected: 01~08 PASS 유지, 09·11이 FAIL(현 hook은 tool_name Agent 게이트라 Workflow 입력에 exit 0·무출력 — ctx=1 기대가 깨져 RED), 10·12·13은 통과(기대가 무출력이라 vacuous — 09/11이 RED의 본체). **RED 출력 verbatim 인용.**

### Task 3: GREEN — surface-model-policy.sh Rule C 확장

**Files:**
- Modify: `hooks/surface-model-policy.sh`

**Interfaces:**
- Consumes: Task 2 픽스처. 기존 Rule A/B 무변경(01~08 무회귀).
- Produces: 09~13 GREEN.

- [x] **Step 1: hook 수정** — `[ "$TOOL" = "Agent" ] || exit 0` 게이트를 Agent|Workflow 분기로 교체:

기존:

```bash
TOOL=$(echo "$INPUT" | json_get 'tool_name')
[ "$TOOL" = "Agent" ] || exit 0

SUB=$(echo "$INPUT" | json_get 'tool_input.subagent_type')
```

을 아래로 교체 (Rule C를 Agent 분기 앞에 삽입 — 이후 Rule A/B 본문 무변경):

```bash
TOOL=$(echo "$INPUT" | json_get 'tool_name')
case "$TOOL" in Agent|Workflow) ;; *) exit 0 ;; esac

# Rule C — Workflow 경로 (C12 spec §10): fable 세션의 인라인/scriptPath 스크립트가
# execute-strict 스테이지를 model 토큰 없이 스폰하려는 순간 환기. 텍스트 휴리스틱(정직 공개:
# 변수 조립·주석 회피는 미검출 — 망각이 위협 모델). execute-strict 부재 스크립트는 무발화(오탐 0).
if [ "$TOOL" = "Workflow" ]; then
  WF_TEXT=$(echo "$INPUT" | json_get 'tool_input.script')
  if [ -z "$WF_TEXT" ]; then
    WF_SP=$(echo "$INPUT" | json_get 'tool_input.scriptPath')
    { [ -n "$WF_SP" ] && [ -f "$WF_SP" ]; } && WF_TEXT=$(head -c 262144 "$WF_SP" 2>/dev/null) || WF_TEXT=""
  fi
  [ -n "$WF_TEXT" ] || exit 0
  printf '%s' "$WF_TEXT" | grep -q "execute-strict" || exit 0
  printf '%s' "$WF_TEXT" | grep -qE "model[[:space:]]*:" && exit 0
  TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
  SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"
  { [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0
  WF_SESSION_MODEL=$(tail -c 200000 "$TRANSCRIPT" 2>/dev/null | awk '
    /"type":"assistant"/ && match($0, /"model":"claude-[a-z0-9.-]+"/) { m = substr($0, RSTART+9, RLENGTH-10) }
    END { if (m != "") print m }')
  case "$WF_SESSION_MODEL" in claude-fable-*) ;; *) exit 0 ;; esac
  MARKER="$(session_marker model-policy-c "$SESSION_ID")"
  [ -f "$MARKER" ] && exit 0
  touch "$MARKER" 2>/dev/null || true
  hook_log "surface-model-policy" "workflow:execute-strict-nomodel" "ALERT" "rule-c-workflow-downshift-missing"
  emit_additional_context "[model-policy] Workflow 스크립트가 execute-strict 스테이지를 model 지정 없이 스폰합니다 — fable 세션의 구현 스테이지는 model:'opus' 고정이 정책(canonical: workflows/rpi-implement.js를 scriptPath로 사용 권장). SSOT: docs/ai-context/model-policy.md §10 (advisory · 1세션 1회 · 차단 아님)"
  exit 0
fi

SUB=$(echo "$INPUT" | json_get 'tool_input.subagent_type')
```

- [x] **Step 2: GREEN 확인 — SMP 단독 추출 13케이스** → 13/13 PASS verbatim 인용.

### Task 4: 배선(#23 parity) + seal #45 conjunct 확장 + README + model-policy.md/skill 동기

**Files:**
- Modify: `settings.json` + `settings.example.json` (PreToolUse Agent 매처를 `Agent|Workflow`로)
- Modify: `setup/verify-setup.sh` (#45 conjunct 추가 — 카운트 불변)
- Modify: `README.md` (run-all 186→191, 2곳)
- Modify: `docs/ai-context/model-policy.md` (§3 L2 서술을 Rule C 포함으로 갱신 — Gate R advisory 2 반영)
- Modify: `skills/start-rpi-cycle/SKILL.md` ((d) 절에 canonical scriptPath 1줄)
- Modify: `docs/ai-context/scaffold-registry.md` (workflows/rpi-implement.js 등재 — Hooks 아닌 신규 Workflows 소절 1행)

**Steps:**
- [x] settings 양쪽: `"matcher": "Agent"` → `"matcher": "Agent|Workflow"` (동형).
- [x] verify-setup #45 블록에 conjunct 추가 (MP_OK 체인 — 검사 수 불변):

```bash
grep -qE "model: 'opus'" "$HOME/.claude/workflows/rpi-implement.js" 2>/dev/null || MP_OK=0
grep -qE "effort: t\.heavy" "$HOME/.claude/workflows/rpi-implement.js" 2>/dev/null || MP_OK=0
grep -qE '"matcher":[[:space:]]*"Agent\|Workflow"' "$HOME/.claude/settings.example.json" 2>/dev/null || MP_OK=0
```

(주석에 "C12: canonical workflow+Workflow 매처 conjunct 확장" 1줄 추가. 기존 `"matcher": "Agent"` 단독 grep 라인은 `Agent|Workflow` grep으로 교체.)
- [x] README run-all `186` → `191` (2곳). verify-setup "현재 81 PASS" 무변경.
- [x] model-policy.md §3 L2 행: "Rule A/B" → "Rule A/B/C(Workflow 스크립트 — execute-strict 무model 감지)"로 갱신, "Workflow 미커버" 정직 공개 문구를 "Rule C가 텍스트-휴리스틱 커버(변수 조립 회피는 미검출 — canonical 파일이 1차 방어)"로 교체. §2 (A) 행에 canonical scriptPath 언급 1줄.
- [x] start-rpi-cycle (d) 절 첫 줄에: canonical `Workflow({scriptPath: '~/.claude/workflows/rpi-implement.js', args: [...]})` 사용 권장 + 인라인 시 동일 규약 문구.
- [x] scaffold-registry에 `## Workflows (1 — ls workflows/*.js)` 소절 신설 + rpi-implement.js 1행.
- [x] 검증: `bash setup/verify-setup.sh` → `PASS=81 FAIL=0`.

### Task 5: 전체 검증 + 라이브 실증 (메인 직접)

- [x] run-all **전체 포그라운드** 1회 (191/191·정합 OK·100% 실측) → 191/191·reconcile OK·100% verbatim 인용.
- [x] seal-regression → 9/0 (replica에 workflows/ 복제 — 구현-중-정정 4).
- [x] 라이브 probe: 신규 headless fable 세션에서 Workflow 도구를 execute-strict+무model 인라인 스크립트로 호출 → hook 로그 `rule-c-workflow-downshift-missing` ALERT 캡처.
- [x] canonical 파일 스모크: `Workflow({scriptPath, args:[문서 1줄 수정 task]})` 실행이 아니라 — YAGNI: meta 파스+앵커 grep(Task 1 Step 2)으로 갈음(실전 첫 사용이 (d) 다음 사이클). 사유 기록.

**수용 잔여 (Gate P unknowns 판단)**: seal #45 conjunct 확장에 seal-regression 변이 케이스 미추가 — C11의 #45 신설 때와 동일 판단(대표-변이 3종 체제 유지, #45는 conjunctive grep이라 vacuous-PASS 위험이 낮음). 필요 시 후속 사이클.

**[구현 중 정정 — 사용자 지시 2026-07-26 (T4 실행 중 수신): effort 품질-우선 상향]**
- 구현 stage effort: heavy `high`→**`xhigh`**, light `medium`→**`high`** + canonical args에 per-task `effort` 선언 필드(max 포함 양방향 override). 근거=spec §0 신규 항목(Opus 5 공식 docs: 에이전트 코딩 xhigh 권장·기본 high; 종전 값은 비-ultracode 상속(xhigh/max)보다 낮아지는 역전 결함). 적용 지점: rpi-implement.js(effort 분기+주석) · model-policy.md 매트릭스 2행+§2(A) · SKILL.md (d) 절 · **seal #45 앵커 `effort: t\.heavy` 정규식은 형태 불변**(분기 표현식만 교체라 `effort: t.heavy ?` 유지 — conjunct 무변경) · 픽스처 무변경(Rule C는 model 토큰만 검사 — effort 비검사라 5케이스 그대로). T5 검증 전 delta 커밋으로 적용(워크플로 T4 완주 후 — stage2 read 경합 회피).

**[구현 중 정정 — GPT 교차리뷰(xhigh) 트리아지 반영, 2026-07-26]**
GPT 발견 28건 트리아지: **REAL 반영 25 · 설계-의도 기각 3**([B]4·[B]6·[B]9 — 기각도 한계 절
문서화는 보강) (발견별 표는 PR #33 코멘트). 반영 delta:
- hook: `~` 방어 확장([C]1) · Rule C2 신설=Workflow 검증자 하향([B]3) · 따옴표 model 키 인정([C]7) ·
  model:'fable'/'inherit'도 ALERT([B]1/[B]8) · transcript 공백 키 허용+tail 1MB([B]5/부분) ·
  ERR+EXIT trap fail-open 불변식([C]6) · [[ =~ ]]로 파이프 제거 · 같은-중괄호 근사 스코프.
- rpi-implement.js: worktree 옵션 제거→파일 겹침 자동 순차([C]3 — Workflow worktree는 에이전트별
  독립 사본이라 "같은 worktree 리뷰" 불성립) · args 필드 검증(heavy boolean 필수 — [C]2) ·
  stage2 첫 줄 PASS/FAIL 강제([C]5) · stage1 보고 구분자+데이터-비지시 지시+diff 직접 실행 대조
  ([B]10/[C]4) · null 전파 가드.
- 문서: spec §3/§5/§10 실물 동기([A]1/[A]2/[A]4) · "오탐 0"→저-오탐 정정([B]2) · L3 존재-감지
  한정 명시([B]7) · [D]1/[D]2 과주장 정직화 · 버전-무관 문구 2건(Opus 5→실행 모델 기본; [A]8) ·
  Rule C 메시지 SSOT 포인터 실존 §로 정정([A]5) · Rule B 문구 "티어≥세션"([A]7) · SKILL.md (d)
  worktree 절 교체.
- 테스트: SMP 13→19케이스(+C2 3·따옴표 키·fable 명시·공백 키), cases.tsv 197, README 동기.
- 기각 3 요지(전부 문서화는 보강): [B]4 scriptPath 256KiB 상한 — 실사용 스크립트 대비 3자릿수 여유,
  한계 절 명문화로 충분 / [B]6 규칙별 1세션 1회 dedup — C11 spec §5의 선언된 트레이드오프(환기 목적,
  전수 관측은 runlog 몫) / [B]9 t.effort 하향에 사유 필드 없음 — 명시=선언 원칙(하향 선언의 승인
  규율은 plan Best-Direction Check 계층 몫, args 스키마 아님).

## Closeout 체크리스트

- [x] 브랜치 `workflow-model-governance` → PR #33 (MERGE_POLICY: wait — 머지는 사용자 승인)
- [x] GPT 교차리뷰 1회(spec §10+hook diff+rpi-implement.js, effort xhigh) → 28건 트리아지 반영(위 delta) — 재검증 verify-setup 81/0 · run-all 197/197 · seal-regression 9/0
- [ ] drift review + plan completed + state 63 + 메모리 project_tri_model_policy 갱신
