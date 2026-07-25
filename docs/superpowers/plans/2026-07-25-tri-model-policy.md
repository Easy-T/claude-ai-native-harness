# Tri-Model Policy (역할×모델 매트릭스 물화) Implementation Plan

**Status:** active
**RPI-Cycle:** 62
**Started:** 2026-07-25

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** fable 세션의 서브에이전트 위임을 역할×모델 매트릭스(구현=opus·탐색=sonnet+medium·검증=상속)로 디스패치하는 정책을 L1(문서/skill)·L2(advisory hook)·L3(seal)로 물화한다.

**Architecture:** SSOT는 `docs/ai-context/model-policy.md`(신규). L2는 PreToolUse `Agent` 매처의 advisory hook `surface-model-policy.sh`(항상 exit 0, additionalContext만). L3는 verify-setup 신규 seal(#번호는 closeout 직전 origin/master 실측) + #39 확장(autocompact PCT+WIN 세트). 근거·실측·기각 대안 = durable spec `docs/superpowers/specs/2026-07-25-model-policy-design.md`.

**Tech Stack:** bash hook(`_common.sh` 소비), run-all.sh 픽스처 TDD, verify-setup bash grep seal.

**Best-Direction Check:** 최선안 = explorer frontmatter 기본값 + executor 호출-인자 규칙(L1)+advisory hook(L2)+seal(L3), 검증자 무변경 (spec §2 — variant agent 증설·frontmatter opus 고정·동적 재량·tool_input 변조 4대안 기각 근거 포함) / 채택안 = 동일. **DOWNGRADE-DECLARED: 없음.** (L2가 차단이 아닌 advisory인 것은 goal 명시 지시 "오탐 0 우선, advisory 후퇴"의 이행 — 열화 아님, spec §5에 선언.)

## Global Constraints

- seal·드리프트 검사는 **bash grep/파일옵스만** (staged-safe — node readFileSync 금지, doctor #23 결함 교훈).
- verify-setup·seal-regression·run-all은 **포그라운드 실행만** (백그라운드=MSYS hang).
- `CLAUDE.md`(글로벌 루트)는 이번 사이클 **무변경** (§1 cache stability — 정책 문서는 model-policy.md가 담당).
- settings.json과 settings.example.json의 hooks는 **동시 동형 갱신** (seal #23 parity).
- hook은 **항상 exit 0** (advisory — 차단 없음). 고장 시 조용히 exit 0 (fail-open, 표면화는 run-all 픽스처가 담당).
- wrapper agent 호출에 **schema 금지** (StructuredOutput 부재 교훈) — 이 plan의 위임은 전부 텍스트 보고.
- 이 세션=fable: 각 구현 task는 `Agent(subagent_type="execute-strict", model="opus")` 로 위임(정책 dogfood). 검증은 review-strict **model 무지정**(상속).
- 신규 seal 번호는 **Task 5 시점에 origin/master의 verify-setup.sh 최고 번호+1 실측** (동시세션 선점 교훈). 아래에서 `#NN`으로 표기 — 현 워킹트리 기준 예상 #45.
- README 카운트 사이트: verify-setup "현재 N PASS"(1곳, #36 런타임 대조) · run-all 케이스 수 "178"(2곳: README.md:276·:514, #20 대조) — 수치 변경 시 전 사이트 동기.

**[구현 중 정정 — Task 2 executor 발견 2건]**
- 기존 #5(`agents model:inherit` 3종 루프)가 explore-strict 변경과 충돌 → Task 5에서 #5 루프를 `review-strict execute-strict` 2종으로 축소(주석 갱신 포함). 카운트 산술: #5 −1, 신규 seal +1 → **총 81 유지, README "현재 81 PASS" 무변경**. Task 5 Step 6 Expected = `PASS=81 FAIL=0`.
- scaffold-registry.md L9 `## Hooks (11 …)` 헤더 → hook 실물이 생기는 **Task 4에서 12로 bump** (Task 4 파일 스코프에 추가).

---

### Task 1: `docs/ai-context/model-policy.md` 신설 (SSOT)

**Files:**
- Create: `docs/ai-context/model-policy.md`

**Interfaces:**
- Produces: seal이 grep할 앵커 — `execute-strict` 표 행에 `opus` 동일 라인, `explore-strict` 표 행에 `sonnet` 동일 라인. Task 2·5가 이 파일 경로를 포인터로 참조.

- [x] **Step 1: 파일 생성 (아래 내용 verbatim)**

```markdown
# model-policy.md — 역할×모델 매트릭스 (런타임 규범 SSOT)

> 설계 근거·실측·기각 대안: `docs/superpowers/specs/2026-07-25-model-policy-design.md` (durable spec).
> 이 문서는 세션이 소비하는 규범만 담는다. 정책 키 = **(세션 모델, ultracode 여부)**.

## 1. 역할×모델×effort 매트릭스

| 역할 | agent | 모델 | effort | 비고 |
|---|---|---|---|---|
| 오케스트레이션·판단·종합·게이트 해석 | 메인 세션 | 세션 모델 | 세션 effort | 위임 금지 — 플래그십의 존재 이유 |
| 구현 heavy (코드/TDD/다파일) | execute-strict | **opus** (호출 인자 명시) | ultracode: **high** / 그 외: 상속 | 사용자 확정: 구현은 opus (sonnet/GPT 대비) |
| 구현 light (기계적 편집·문서 생성) | execute-strict | **opus** (동일) | ultracode: **medium** / 그 외: 상속 | sonnet 구현은 per-task 선언적 override만 |
| 탐색 (읽기 전용 발견·전수조사) | explore-strict | **sonnet** (frontmatter 기본) | **medium** (frontmatter 기본) | model 상향은 호출 인자로 자유. 판단-heavy 탐색은 builtin Explore(상속) 또는 메인 직접 |
| 검증 (게이트·드리프트·적대) | review-strict | **상속 — 변경 금지** | **상속 — 하향 금지** | 검증자 티어 ≥ 작업자 (cross-family-review.md §3) |
| 교차 검증 (고-스테이크 closeout) | GPT | cross-family-review.md 규약 그대로 | — | 사이클당 1회 quota — stage별 GPT 검증 기각 |

- **상향은 항상 허용**(사유 불요). **하향**: 검증자 금지 / 실행자·탐색자는 이 표 자체가 선언 — 표 밖 하향(예: 구현을 haiku로)은 DOWNGRADE-DECLARED(사유) 필요.
- GPT quota 주의: 일상 경량 Claude 작업에 luna 남발 금지 — 경량은 sonnet 우선.

## 2. 모드 분기

- **(A) fable + ultracode**: start-rpi-cycle Phase I (d) Workflow — stage1 `agentType:'execute-strict', model:'opus', effort:'high'`(heavy) 또는 `effort:'medium'`(light; plan task가 코드/TDD 포함이면 heavy, 순수 문서·기계 편집이면 light). stage2 `agentType:'review-strict'` **model/effort 무지정**(상속).
- **(B) fable 비-ultracode** (max 이하 effort 포함): (a)/(b)/(c) 경로에서 execute-strict 위임 시 `model:'opus'` 명시. per-call effort는 플랫폼상 불가(Agent 도구 인자에 effort 없음) — 상속 수용.
- **(C) 비-fable 세션 (opus 등)**: 현행 상속 유지. 단 explore-strict frontmatter 기본(sonnet+medium)과 검증자 하향 감지(hook Rule B)는 전 세션 공유 이득.
- haiku/custom(GPT) 세션에서의 RPIC 사이클은 비권장 — 검증자 상속이 GPT가 되어 교차패밀리 전제가 뒤집힌다.

## 3. 강제 계층 (상보적 커버 — reload/upgrade 내성)

- **L1** = 이 문서 + start-rpi-cycle/SKILL.md 규칙(포인터만, 중복 서술 금지).
- **L2** = `hooks/surface-model-policy.sh` (PreToolUse `Agent` 매처, advisory·항상 exit 0): Rule A(fable 세션 실행자 하향 미적용)·Rule B(검증자 하향, 전 세션). **Workflow `agent()` 내부 스폰은 Agent 도구가 아니라 미커버** — ultracode 경로는 L1+L3가 담당(정직 공개).
- **L3** = verify-setup seal: 이 문서 존재+토큰, explore-strict frontmatter, execute/review `model: inherit` 유지+review effort 키 부재, settings.example Agent 매처 배선, start-rpi-cycle 토큰 parity(skill 재생성 소실 표면화).
- skill/plugin 재생성·업그레이드 내성: 강제는 git-추적 층(hook 배선·frontmatter·seal)에 있고, skill 텍스트 소실은 L3 토큰 parity가 FAIL로 표면화. plugins/cache는 정책 캐리어 금지.
```

- [x] **Step 2: 검증 — seal 앵커 grep**

Run: `grep -E 'execute-strict.*opus' docs/ai-context/model-policy.md && grep -E 'explore-strict.*sonnet' docs/ai-context/model-policy.md && echo ANCHOR-OK`
Expected: 표 행 2줄 + `ANCHOR-OK`

- [x] **Step 3: Commit**

```bash
git add docs/ai-context/model-policy.md && git commit -m "feat(model-policy): 역할×모델 매트릭스 SSOT 신설 (tri-model C11)"
```

### Task 2: frontmatter·skill·규약 문서 개정 (L1)

**Files:**
- Modify: `agents/explore-strict.md` (frontmatter만)
- Modify: `skills/start-rpi-cycle/SKILL.md` (3지점)
- Modify: `docs/ai-context/cross-family-review.md` (§3 1문장 정밀화)
- Modify: `docs/ai-context/scaffold-registry.md` (Hooks 표 1행 — Task 4의 hook 선등재)

**Interfaces:**
- Consumes: Task 1의 `docs/ai-context/model-policy.md` 경로.
- Produces: seal 앵커 — explore-strict frontmatter `model: sonnet`+`effort: medium`, start-rpi-cycle 내 `model-policy` 토큰.

- [x] **Step 1: `agents/explore-strict.md` frontmatter 교체**

`model: inherit` 라인(14행)을 아래 2줄로 교체 (다른 라인 무변경):

```yaml
model: sonnet
effort: medium
```

본문 Rule-of-Two 블록 아래에 1줄 추가:

```markdown
> 모델 기본값 sonnet+effort medium(frontmatter — 역할×모델 매트릭스, docs/ai-context/model-policy.md). 판단-heavy 탐색은 호출 인자 `model` 상향 또는 메인 직접이 탈출구.
```

- [x] **Step 2: `skills/start-rpi-cycle/SKILL.md` 3지점 수정**

(i) Phase I (d) 절의 stage1/stage2 서술 라인:

```
      stage1 `agentType='execute-strict'`(구현) → stage2 `agentType='review-strict'`(검증).
```

을 아래로 교체:

```
      stage1 `agentType='execute-strict', model:'opus', effort:'high'`(heavy: 코드/TDD) 또는 `effort:'medium'`(light: 순수 문서·기계 편집) → stage2 `agentType='review-strict'` **model/effort 무지정**(상속 — 검증자 하향 금지). (역할×모델 매트릭스 SSOT: docs/ai-context/model-policy.md)
```

(ii) "권장:" 블록 바로 아래에 1줄 추가:

```
※ **fable 세션의 execute-strict 위임은 (a)/(c) 어느 경로든 `model:'opus'` 명시** — 역할×모델 매트릭스(docs/ai-context/model-policy.md). 검증자(review-strict)는 항상 model 무지정(상속).
```

(iii) Phase R의 C. explore-strict 호출 블록 아래 `※` 줄들에 1줄 추가:

```
   ※ explore-strict 는 frontmatter 기본 sonnet+medium — 판단-heavy 탐색만 호출 인자 model 상향 (SSOT: docs/ai-context/model-policy.md)
```

- [x] **Step 3: `docs/ai-context/cross-family-review.md` §3 첫 불릿 정밀화 (spec §4.8b — Gate R 발견)**

기존 첫 문장:

```
- **서브에이전트 model 미지정 = 세션 모델 상속이 기본**(wrapper 3종 frontmatter에 model 필드 없음 — 의도). 이것이 "검증자 티어 ≥ 작업자 티어"를 공짜로 보장한다.
```

을 아래로 교체 (이후 문장들 무변경):

```
- **검증자(review-strict)는 `model: inherit` 유지가 "검증자 티어 ≥ 작업자 티어"를 공짜로 보장한다**(frontmatter 실물 명시 `inherit` — 2026-07-25 정밀화; 실행자·탐색자 기본값은 `docs/ai-context/model-policy.md` 매트릭스가 별도 규정, 검증자 원칙과 독립).
```

- [x] **Step 4: `docs/ai-context/scaffold-registry.md` Hooks 표에 1행 추가** (`worktree-teardown.sh` 행 아래):

```markdown
| `surface-model-policy.sh` | fable 실행자 하향 미적용·검증자 하향을 advisory 환기(역할×모델 매트릭스 L2) | tri-model C11 (2026-07-25) |
```

- [x] **Step 5: 검증 + Commit**

Run: `grep -c 'model-policy' skills/start-rpi-cycle/SKILL.md && grep -E '^model: sonnet|^effort: medium' agents/explore-strict.md`
Expected: 카운트 ≥3, frontmatter 2줄 출력

```bash
git add agents/explore-strict.md skills/start-rpi-cycle/SKILL.md docs/ai-context/cross-family-review.md docs/ai-context/scaffold-registry.md && git commit -m "feat(model-policy): L1 — explorer frontmatter 기본값 + skill 규칙 + §3 정밀화 (C11)"
```

### Task 3: RED — run-all.sh 픽스처 8케이스 + cases.tsv 선언

**Files:**
- Modify: `hooks/tests/run-all.sh` (AUTO-COMPACT-WATCH 섹션 뒤, Summary 앞에 신규 섹션)
- Modify: `hooks/tests/cases.tsv` (8행 추가)

**Interfaces:**
- Consumes: 실측 stdin shape (spec §1.2 verbatim — 합성-shape 마스킹 금지 교훈).
- Produces: `test_smp` 케이스 8개 — Task 4의 hook이 GREEN 대상. 케이스 ID는 cases.tsv와 문자 일치.

- [x] **Step 1: run-all.sh에 신규 섹션 삽입** (`# ==================== Summary` 직전):

```bash
# ==================== SURFACE-MODEL-POLICY (tri-model C11) ====================
# stdin 은 2026-07-25 실측 캡처 shape verbatim (spec §1.2) — 합성 shape 금지 (cycle-40 교훈).
mk_agent_event() {
  local sub="$1"; local model="$2"; local transcript="$3"; local sid="$4"
  SUB="$sub" MODEL="$model" TP="$transcript" SID="$sid" node -e '
    const ti = {description:"x", prompt:"x", subagent_type:process.env.SUB, run_in_background:false};
    if (process.env.MODEL) ti.model = process.env.MODEL;
    const o = {session_id:process.env.SID, transcript_path:process.env.TP, cwd:"", permission_mode:"bypassPermissions",
               effort:{level:"xhigh"}, hook_event_name:"PreToolUse", tool_name:"Agent", tool_input:ti, tool_use_id:"toolu_x"};
    console.log(JSON.stringify(o));
  '
}
test_smp() {
  local name="$1"; local expected_exit="$2"; local expect_ctx="$3"; local input="$4"
  TOTAL=$((TOTAL+1))
  local out actual ctx=0
  out=$(printf '%s' "$input" | "$HOOKS/surface-model-policy.sh" 2>/dev/null); actual=$?
  printf '%s' "$out" | grep -q 'additionalContext' && ctx=1
  if [ "$actual" = "$expected_exit" ] && [ "$ctx" = "$expect_ctx" ]; then PASSED=$((PASSED+1))
  else FAILED_LIST+=("surface-model-policy/$name (exit=$actual ctx=$ctx)"); fi
}
SMP_FABLE_T=$(mktemp "$SCRATCH/smp-fable-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-fable-5","content":[]}}\n' > "$SMP_FABLE_T"
SMP_SONNET_T=$(mktemp "$SCRATCH/smp-sonnet-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-sonnet-5","content":[]}}\n' > "$SMP_SONNET_T"
SMP_QUOTE_T=$(mktemp "$SCRATCH/smp-quote-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-fable-5","content":[{"type":"text","text":"claude-opus-5[1m] 언급 텍스트"}]}}\n' > "$SMP_QUOTE_T"

# 01: fable 세션 + execute-strict + model 부재 → Rule A ALERT (ctx=1)
test_smp "01-rule-a-fable-nomodel" 0 1 "$(mk_agent_event execute-strict "" "$SMP_FABLE_T" "smp01-$$")"
# 02: fable 세션 + execute-strict + model:'opus' → 정책 준수 (ctx=0)
test_smp "02-rule-a-opus-ok" 0 0 "$(mk_agent_event execute-strict opus "$SMP_FABLE_T" "smp02-$$")"
# 03: fable 세션 + review-strict + model:'sonnet' → Rule B 하향 ALERT (ctx=1)
test_smp "03-rule-b-verifier-downshift" 0 1 "$(mk_agent_event review-strict sonnet "$SMP_FABLE_T" "smp03-$$")"
# 04: review-strict + model 무지정(상속) → 무출력 (ctx=0)
test_smp "04-rule-b-inherit-ok" 0 0 "$(mk_agent_event review-strict "" "$SMP_FABLE_T" "smp04-$$")"
# 05: sonnet 세션 + execute-strict + model 부재 → Rule A 비대상 (ctx=0)
test_smp "05-nonfable-execute-ok" 0 0 "$(mk_agent_event execute-strict "" "$SMP_SONNET_T" "smp05-$$")"
# 06: 깨진 stdin → fail-open exit 0 무출력
test_smp "06-broken-stdin" 0 0 "not-json"
# 07: transcript 부재 → fail-open exit 0 무출력
test_smp "07-no-transcript" 0 0 "$(mk_agent_event execute-strict "" "$SCRATCH/smp-none.jsonl" "smp07-$$")"
# 08: assistant 라인 content 가 타 모델 id 를 인용해도 message.model(첫 매치)로 판정 → Rule A ALERT
test_smp "08-quoted-id-immune" 0 1 "$(mk_agent_event execute-strict "" "$SMP_QUOTE_T" "smp08-$$")"
```

- [x] **Step 2: cases.tsv에 8행 추가** (탭 구분, 파일 끝):

```
surface-model-policy	01-rule-a-fable-nomodel	0	mk_agent_event
surface-model-policy	02-rule-a-opus-ok	0	mk_agent_event
surface-model-policy	03-rule-b-verifier-downshift	0	mk_agent_event
surface-model-policy	04-rule-b-inherit-ok	0	mk_agent_event
surface-model-policy	05-nonfable-execute-ok	0	mk_agent_event
surface-model-policy	06-broken-stdin	0	mk_agent_event
surface-model-policy	07-no-transcript	0	mk_agent_event
surface-model-policy	08-quoted-id-immune	0	mk_agent_event
```

- [x] **Step 3: RED 확인 — 포그라운드 실행**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -15`
Expected: `Hook tests: 178 / 186 passed` + FAILED_LIST에 `surface-model-policy/01…08` 8건 (hook 부재 exit 127). reconcile은 OK(선언==실행). **RED 출력을 보고에 verbatim 인용.**

- [x] **Step 4: Commit (RED)**

```bash
git add hooks/tests/run-all.sh hooks/tests/cases.tsv && git commit -m "test(model-policy): surface-model-policy 8케이스 RED (C11 TDD)"
```

### Task 4: GREEN — `hooks/surface-model-policy.sh` 구현

**Files:**
- Create: `hooks/surface-model-policy.sh` (실행권한 +x)

**Interfaces:**
- Consumes: `_common.sh`의 `read_input`/`json_get`/`session_marker`/`hook_log`/`emit_additional_context`/`require_node` (surface-constitution.sh 동형).
- Produces: Task 3의 8케이스 GREEN. Task 5의 settings 배선 대상.

- [x] **Step 1: hook 작성 (아래 verbatim)**

```bash
#!/usr/bin/env bash
# surface-model-policy.sh — advisory PreToolUse hook (Agent 매처; tri-model C11, spec 2026-07-25 §5).
# 역할×모델 매트릭스(docs/ai-context/model-policy.md)의 L2: Rule A(fable 세션 실행자 하향 미적용)·
# Rule B(검증자 하향, 전 세션)를 additionalContext 로 환기. 차단하지 않는다(항상 exit 0, fail-open).
# 세션 모델은 hook stdin 에 없어 transcript 의 assistant 라인 message.model 로 판별(실측 shape).
# 라인 내 첫 매치만 취해 content 의 모델 id 인용에 면역(assistant JSON 은 model 이 content 앞).
# reload/upgrade 내성: settings.json 배선 + 라이브 tool_input 관측 — skill 텍스트와 무관 (spec §5).
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
TOOL=$(echo "$INPUT" | json_get 'tool_name')
[ "$TOOL" = "Agent" ] || exit 0

SUB=$(echo "$INPUT" | json_get 'tool_input.subagent_type')
case "$SUB" in execute-strict|review-strict) ;; *) exit 0 ;; esac

REQ_MODEL=$(echo "$INPUT" | json_get 'tool_input.model')
TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"
{ [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0

SESSION_MODEL=$(tail -c 200000 "$TRANSCRIPT" 2>/dev/null | awk '
  /"type":"assistant"/ && match($0, /"model":"claude-[a-z0-9.-]+"/) { m = substr($0, RSTART+9, RLENGTH-10) }
  END { if (m != "") print m }')
[ -n "$SESSION_MODEL" ] || exit 0

tier_of() {
  case "$1" in
    fable|claude-fable-*)   echo 4 ;;
    opus|claude-opus-*)     echo 3 ;;
    sonnet|claude-sonnet-*) echo 2 ;;
    haiku|claude-haiku-*)   echo 1 ;;
    *)                      echo 0 ;;
  esac
}
SESSION_TIER=$(tier_of "$SESSION_MODEL")

# Rule A — fable 세션의 실행자가 하향 미적용(model 부재 또는 fable 명시)
if [ "$SUB" = "execute-strict" ] && [ "$SESSION_TIER" = "4" ]; then
  if [ -z "$REQ_MODEL" ] || [ "$REQ_MODEL" = "fable" ]; then
    MARKER="$(session_marker model-policy-a "$SESSION_ID")"
    [ -f "$MARKER" ] && exit 0
    touch "$MARKER" 2>/dev/null || true
    hook_log "surface-model-policy" "execute-strict:${REQ_MODEL:-inherit}" "ALERT" "rule-a-downshift-missing"
    emit_additional_context "[model-policy] fable 세션의 실행자(execute-strict) 위임은 model:'opus' 명시가 정책 기본(구현=opus — 역할×모델 매트릭스). SSOT: docs/ai-context/model-policy.md (advisory · 1세션 1회 · 차단 아님)"
    exit 0
  fi
fi

# Rule B — 검증자 하향 감지(전 세션): 명시 model 티어 < 세션 티어
if [ "$SUB" = "review-strict" ] && [ -n "$REQ_MODEL" ] && [ "$SESSION_TIER" != "0" ]; then
  REQ_TIER=$(tier_of "$REQ_MODEL")
  if [ "$REQ_TIER" != "0" ] && [ "$REQ_TIER" -lt "$SESSION_TIER" ]; then
    MARKER="$(session_marker model-policy-b "$SESSION_ID")"
    [ -f "$MARKER" ] && exit 0
    touch "$MARKER" 2>/dev/null || true
    hook_log "surface-model-policy" "review-strict:$REQ_MODEL" "ALERT" "rule-b-verifier-downshift"
    emit_additional_context "[model-policy] 검증자(review-strict) 하향 감지(세션=$SESSION_MODEL > 요청=$REQ_MODEL) — 검증자 티어 ≥ 작업자가 원칙(cross-family-review.md §3). 의도된 하향이면 DOWNGRADE-DECLARED(사유) 선언 필요. (advisory · 1세션 1회 · 차단 아님)"
    exit 0
  fi
fi

exit 0
```

- [x] **Step 2: 실행권한 + GREEN 확인 (포그라운드)**

Run: `chmod +x hooks/surface-model-policy.sh && bash hooks/tests/run-all.sh 2>&1 | tail -6`
Expected: `Hook tests: 186 / 186 passed` + `cases.tsv <-> run-all 정합 OK (186 declared == 186 run…)` + `Pass rate 100%`. **GREEN 출력을 보고에 verbatim 인용.**

- [x] **Step 3: Commit (GREEN)**

```bash
git add hooks/surface-model-policy.sh && git commit -m "feat(model-policy): surface-model-policy advisory hook GREEN 8/8 (C11 L2)"
```

### Task 5: settings 배선(#23 parity) + seal 신설 + #39 확장 + README 카운트

**Files:**
- Modify: `settings.json` + `settings.example.json` (PreToolUse에 Agent 매처 블록 — 동형)
- Modify: `setup/verify-setup.sh` (#39 블록 확장 + 신규 seal #NN)
- Modify: `README.md` (verify-setup "현재 81 PASS"→+1 · run-all "178"→"186" 2곳)

**Interfaces:**
- Consumes: Task 1 앵커 토큰, Task 2 frontmatter, Task 4 hook 파일명.
- Produces: verify-setup ALL PASS 상태 (Task 6이 실측).

- [x] **Step 1: settings.json·settings.example.json 양쪽 PreToolUse 배열에 블록 추가** (`"matcher": "Bash"` 블록 뒤, 동일 위치·동형):

```json
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/surface-model-policy.sh"
          }
        ]
      }
```

- [x] **Step 2: seal 번호 실측**

Run: `git fetch origin master --quiet 2>/dev/null; git show origin/master:setup/verify-setup.sh | grep -oE '^# [0-9]+\.' | grep -oE '[0-9]+' | sort -n | tail -1`
Expected: 최고 번호(예상 44) → 신규 seal = 그 +1 (아래 `#NN`에 치환).

- [x] **Step 3: verify-setup.sh #39 블록 확장** — 기존 #39의 `EX_PCT` 검사 `elif [ "$EX_PCT" -le 40 ]` 분기를 WIN 세트 검사로 교체. 기존 블록의 ok/fail 1회 구조 유지(카운트 불변):

기존 (L373-380 근방):

```bash
EX_PCT=$(grep -oE '"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"[[:space:]]*:[[:space:]]*"?[0-9]+"?' "$HOME/.claude/settings.example.json" 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [ -z "$EX_PCT" ]; then
  fail "settings.example CLAUDE_AUTOCOMPACT_PCT_OVERRIDE 부재 (GAP-018)"
elif [ "$EX_PCT" -le 40 ] 2>/dev/null; then
```

의 `elif` 판정을 아래로 교체 (fail 메시지도 세트 언급으로 갱신; 2026-07-25 회귀 근본원인 = WIN 라인 소실 시 PCT 단독 완전 inert):

```bash
EX_WIN=$(grep -cE '"CLAUDE_CODE_AUTO_COMPACT_WINDOW"[[:space:]]*:[[:space:]]*"1000000"' "$HOME/.claude/settings.example.json" 2>/dev/null)
```

를 `EX_PCT=` 라인 다음에 추가하고, 판정을:

```bash
elif [ "$EX_PCT" -le 40 ] 2>/dev/null && [ "$EX_WIN" -ge 1 ]; then
  ok "settings.example autocompact PCT(${EX_PCT})≤40 + WINDOW=1000000 세트 (GAP-018+C11: PCT 단독은 침묵 무효)"
else
  fail "settings.example autocompact 세트 붕괴 (GAP-018+C11): PCT≤40 AND WINDOW=1000000 필요 (PCT=${EX_PCT:-부재} WIN라인=${EX_WIN:-0}) — 한쪽만은 완전 inert"
fi
```

(기존 ok/fail 메시지 라인은 이 교체본으로 대체 — 검사 수 불변.)

- [x] **Step 4: 신규 seal #NN 추가** (#44 블록 뒤, #36 self-count 블록 **앞** — #36은 반드시 파일 마지막 검사 유지):

```bash
# NN. 역할×모델 매트릭스 물화 봉인 (tri-model C11, spec 2026-07-25 §6): conjunctive —
#     ① model-policy.md 존재+행 앵커(execute→opus·explore→sonnet) ② explore-strict frontmatter sonnet+medium
#     ③ execute/review `model: inherit` 유지 + review-strict effort 키 부재(검증자 상속 물리 앵커)
#     ④ settings.example 에 Agent 매처+hook 배선(#23 이 live 와 parity) ⑤ start-rpi-cycle 토큰(재생성 소실 표면화).
#     bash grep only (staged-safe).
MP_DOC="$HOME/.claude/docs/ai-context/model-policy.md"
MP_OK=1
{ [ -f "$MP_DOC" ] && grep -qE 'execute-strict.*opus' "$MP_DOC" && grep -qE 'explore-strict.*sonnet' "$MP_DOC"; } || MP_OK=0
grep -qE '^model:[[:space:]]*sonnet' "$HOME/.claude/agents/explore-strict.md" 2>/dev/null || MP_OK=0
grep -qE '^effort:[[:space:]]*medium' "$HOME/.claude/agents/explore-strict.md" 2>/dev/null || MP_OK=0
grep -qE '^model:[[:space:]]*inherit' "$HOME/.claude/agents/execute-strict.md" 2>/dev/null || MP_OK=0
grep -qE '^model:[[:space:]]*inherit' "$HOME/.claude/agents/review-strict.md" 2>/dev/null || MP_OK=0
if grep -qE '^effort:' "$HOME/.claude/agents/review-strict.md" 2>/dev/null; then MP_OK=0; fi
grep -q 'surface-model-policy' "$HOME/.claude/settings.example.json" 2>/dev/null || MP_OK=0
grep -qE '"matcher":[[:space:]]*"Agent"' "$HOME/.claude/settings.example.json" 2>/dev/null || MP_OK=0
grep -q 'model-policy' "$HOME/.claude/skills/start-rpi-cycle/SKILL.md" 2>/dev/null || MP_OK=0
if [ "$MP_OK" -eq 1 ]; then
  ok "역할×모델 매트릭스 물화 (model-policy.md·frontmatter·Agent 매처·skill 토큰)"
else
  fail "역할×모델 매트릭스 봉인 붕괴 (C11): model-policy.md 앵커/explore frontmatter/inherit 유지/review effort 부재/Agent 매처/skill 토큰 중 결손 — spec §6"
fi
```

- [x] **Step 5: README 카운트 동기** — `현재 81 PASS` → `현재 82 PASS`(1곳), run-all `178` 케이스 선언 → `186`(2곳: 약 L276·L514).

- [x] **Step 6: 검증 (포그라운드) + Commit**

Run: `bash setup/verify-setup.sh 2>&1 | tail -3`
Expected: `verify-setup: PASS=82 FAIL=0`

```bash
git add settings.json settings.example.json setup/verify-setup.sh README.md && git commit -m "feat(model-policy): Agent 매처 배선 + seal #NN + #39 PCT+WIN 세트 확장 (C11 L3)"
```

### Task 6: 라이브 실증 + 전체 검증 (메인 세션 직접 — 위임 아님)

**Files:** 없음 (실행·캡처만)

- [x] **Step 1: 라이브 probe — 위반 호출 → hook 발화 캡처** (goal §3 요구. 신규 headless 세션은 갱신된 settings.json을 로드):

```bash
claude --model fable --max-turns 3 -p "First run the Bash tool with command: echo warmup. Then call the Agent tool exactly once with subagent_type='execute-strict', prompt='Reply exactly OK. Do not modify any files.' — do NOT pass a model parameter. Then reply exactly: DONE" --output-format json | tail -1 | grep -oE '"result":"[^"]*"'
grep 'surface-model-policy' "$HOME/.claude/hooks/.log/$(date +%Y-%m).log" | tail -3
```

Expected: probe 결과 `DONE` + 로그에 `surface-model-policy … ALERT rule-a-downshift-missing` ≥1건. (turn-1 Bash가 transcript에 fable assistant 라인을 선기록 — 첫-턴 flush 경합 회피. 실패 시 1회 재시도 후, 그래도 미발화면 원인 조사 결과를 보고에 기록하고 진행 — advisory 층이므로 비차단이나 **미발화 자체는 보고 필수**.)

- [x] **Step 2: 전체 검증 스위트 (포그라운드 순차)**

```bash
bash setup/verify-setup.sh 2>&1 | tail -2
bash setup/tests/seal-regression.test.sh 2>&1 | tail -2
bash hooks/tests/run-all.sh 2>&1 | tail -4
```

Expected: PASS=82 FAIL=0 / seal-regression PASS / 186/186·정합 OK·rate 100%.

- [x] **Step 3: 교차패밀리 GPT 리뷰 1회** (고-스테이크 거버넌스 — cross-family-review.md 규약): probe A(codex CLI)→B(CCS) 순서, 가용 시 spec+model-policy.md를 stdin 파이프로 refute-by-default 리뷰 → 메인 트리아지(REAL만 반영), 불가 시 SKIP+사유 1줄. 설치/로그인 시도 절대 금지.

- [x] **Step 4: 발견 결함 수정 시 해당 Task로 회귀 후 재검증. 전부 green이면 Closeout으로.**

---

## Closeout 체크리스트 (start-rpi-cycle Phase Closeout 준수)

- [ ] 브랜치 `tri-model-policy` → PR 생성 (closeout-pr-cycle; **MERGE_POLICY: wait — 머지는 사용자 승인 필수, 유일 정지점**)
- [ ] Step C-1 drift review-strict (model 무지정 상속) + plan Status→completed + state.json 62/today
- [ ] 메모리 `project_tri_model_policy` 신설(goal 파일은 gitignored — 실측·정책 요약 영구화) + MEMORY.md 인덱스
- [ ] 보고: harness-verify(`PASS=82 FAIL=0`)·phase-skills·next-cycle-goal 3라벨
