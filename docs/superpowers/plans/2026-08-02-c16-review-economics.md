# C16 — 리뷰 경제성 재설계 Implementation Plan

**Status:** active
**RPI-Cycle:** 67
**Started:** 2026-08-02

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** stage2 검증자 floor를 임무-분리로 개정(Rule C2=작업자 티어+세션 폴백, Rule B=max 유지)하고, layer-yield 계량 필드·델타 재심 규약·교차패밀리 2-슬롯·senior 적대 임무 전환을 착륙시키며, C15 잔여 하우스키핑을 닫는다. 설계 SSOT = durable spec §15 (Gate R PASS).

**Architecture:** L2 hook(Rule C2)은 `WORKER_TIER` 초기값 0 + 세션 폴백 1줄 산식으로 개정. canonical carrier stage2는 `model:'opus'` 명시(작업자 티어). L1 문서 7파일 동기. L3 seal #49(layer-yield parity) 신설. 순서 제약: T1(hook floor) → T2(carrier) 는 (c) 직접 위임 — T2 이전에 T1이 착륙해야 새 carrier가 구 hook의 자기고발(ALERT)을 만나지 않는다. T3~T7은 수정 후 새 carrier(d)로 — 새 설계의 라이브 fitness를 겸함.

**Tech Stack:** bash(hook·seal·픽스처)·node(파서 헤더)·run-all.sh 픽스처 체계(test_smp)·markdown 문서 동기

## Global Constraints

- **goal §5 전면 승계**: settings.json git add·값 출력 금지 / seal·드리프트 검사는 bash 파일옵스만 / verify-setup·run-all·seal-regression 최종 게이트는 메인 포그라운드(600s 초과 자동 백그라운드 강등 허용, 완주 확인) / wrapper agent에 schema 금지 / 글로벌 CLAUDE.md 수정 없음 / GPT `service_tier` 복원 금지 / 검증자 < 작업자 금지(§5-12) / 검증 횟수 축소 금지(§5-13)
- 커밋은 task 종료 시 메인이 그룹 커밋(Workflow 스크립트는 커밋 금지)
- 기존 259 케이스 무회귀. 신규 케이스는 cases.tsv 등재 + README 카운트 동기(#20/#21). 최종 산술: run-all 259→262(T1)→266(T2)→267(슬롯2 F4) · verify-setup 86→87(#49) · seal-regression 15→16(Mutator 4)
- C16-C(블라인드 A/B)는 Phase R에서 실행·판정 완료(7/13 — spec §15.2) — §5-11 순서 의존 충족
- 교차패밀리 슬롯 1은 Gate P 직후 실행·트리아지 완료(spec §15.7 — REAL 26 정정 반영·수용잔여/기각 11 판정 기록). 슬롯 2는 T9(Closeout).

**Best-Direction Check:** 최선안 = spec §15 확정 설계 그대로 — floor 임무-분리(Rule C2=작업자 티어, 실행자 부재 시 세션 폴백으로 보수 유지; Rule B 불변), carrier stage2 명시로 "탈출구 부재" 잔여까지 해소, senior review 임무 전환(패스 수 불변으로 발견력 추가), 2-슬롯 교차리뷰(발견을 설계 층으로 전진), layer-yield 최소 계약+별도 대장 / 채택안 = 동일. **DOWNGRADE-DECLARED: 없음**. (floor 완화 자체는 C13 결정의 의식적 supersede이며 spec §15.1이 "새로 침묵" 전수 표로 정당성을 항목별 판정 — silent downgrade 아님.)

---

### Task 1: Rule C2 floor 개정 + 픽스처 + 편승 주석 정정 — 경로 (c) execute-strict(model:'opus')

**Files:**
- Modify: `hooks/surface-model-policy.sh` (2패스 floor 산정 :93-107 + 1패스 초기값·주석 :59-60 + 헤더 :4 + C2 메시지 :132 + C3 주석 블록 :78-79)
- Modify: `hooks/lib/workflow-spawns.js` (헤더 자인 1줄 — MAX_SPAWNS×`*` 상호작용)
- Test: `hooks/tests/run-all.sh` (신규 smp 41·42·43), `hooks/tests/cases.tsv`, `README.md` (259→262 카운트 2곳 :292·:530)

**Interfaces:**
- Produces: Rule C2 신규 판정식 `FLOOR = WORKER_TIER>0 ? WORKER_TIER : WF_TIER` — Task 2(carrier)가 이 hook 하에서 stage2 `model:'opus'`를 명시해도 무발화임에 의존.

- [x] **Step 1: RED — 신규 픽스처 2개 먼저 추가**

`hooks/tests/run-all.sh`의 smp 39 블록 뒤에 추가:

```bash
# C16 §15.1: floor 임무-분리 — Workflow(준수-확인) floor = 작업자 티어. 검증자==작업자면 세션이 위여도 무발화.
WF_WORKER_FLOOR="await agent('impl', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'opus'})"
test_smp "41-rule-c2-worker-floor-ok" 0 0 "$(mk_wf_event script "$WF_WORKER_FLOOR" "$SMP_FABLE_T" "smp41-$$")"
WF_WORKER_FLOOR_S="await agent('impl', {agentType: 'execute-strict', model: 'sonnet'})
await agent('v', {agentType: 'review-strict', model: 'sonnet'})"
test_smp "42-rule-c2-worker-floor-sonnet" 0 0 "$(mk_wf_event script "$WF_WORKER_FLOOR_S" "$SMP_FABLE_T" "smp42-$$")"
```

※ Gate P 지적 반영: 번호는 41·42 — 기존 `40-c3-hedge-content`(run-all :1248)와의 번호 중복 회피.

추가 RED 픽스처 1개 — 혼합 실행자(상속+하위 리터럴)의 보수 유지 (슬롯1 S1/S2 앵커):

```bash
# C16 슬롯1 S1/S2: 상속·동적 실행자는 세션 티어로 평가 — 하위 리터럴 실행자가 floor 를 끌어내리지 못함.
# opus 세션 사용 — fable 세션이면 Rule C(무선언 실행자)가 함께 발화해 C2 회귀를 가린다(판정 격리).
SMP_OPUS_T=$(mktemp "$SCRATCH/smp-opus-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-opus-5","content":[]}}\n' > "$SMP_OPUS_T"
WF_MIXED_EXEC="await agent('a', {agentType: 'execute-strict'})
await agent('b', {agentType: 'execute-strict', model: 'sonnet'})
await agent('v', {agentType: 'review-strict', model: 'sonnet'})"
test_smp "43-rule-c2-mixed-inherit-exec" 0 1 "$(mk_wf_event script "$WF_MIXED_EXEC" "$SMP_OPUS_T" "smp43-$$")"
```

(opus 세션(3): 상속 실행자=3(세션 평가)·리터럴 sonnet=2 → WORKER_TIER=3 → 검증자 sonnet 2<3 ALERT —
S1의 원 시나리오 그대로. Rule C는 fable 한정이라 미발화(ALERT의 유일 원천=C2, 판정 격리). 초안 구현
(`tier_of` 단독)이었다면 WORKER_TIER=2로 SILENT — 이 픽스처가 그 회귀를 봉인. SMP_OPUS_T는 기존 픽스처
블록의 FABLE/SONNET transcript 선언(:1062-1065) 뒤에 추가.)

`hooks/tests/cases.tsv`에 등재(col4는 인접 smp 행과 동형 `mk_wf_event` — 슬롯1 S16 정정):

```
surface-model-policy	41-rule-c2-worker-floor-ok	0	mk_wf_event
surface-model-policy	42-rule-c2-worker-floor-sonnet	0	mk_wf_event
surface-model-policy	43-rule-c2-mixed-inherit-exec	0	mk_wf_event
```

- [x] **Step 2: RED 확인**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -12`
Expected: **요약 라인 기준** FAIL 2건 (41·42 — 구 코드는 fable 세션 floor=4로 ALERT, got 1 vs want 0; 43은 구 코드에서도 ALERT라 이미 GREEN). ※슬롯1 S13: run-all은 pass-rate ≥95%면 exit 0 — RED 판정은 종료코드가 아니라 요약의 `got/want` FAIL 라인으로 한다. 실패 출력 원문 인용.

- [x] **Step 3: GREEN — hook 개정 (4곳)**

`hooks/surface-model-policy.sh` 2패스(:93-107)를 다음으로 교체:

```bash
  # 2패스: 검증자 floor — 임무-분리 (C16 spec §15.1, C13 §12.1 supersede).
  # Workflow 경로(준수-확인 임무) floor = **작업자 티어** (실행자 부재/전량-동적 스크립트는 세션 티어 폴백 — 보수 유지).
  # 무지정('-')·inherit 는 **세션 티어로 평가**한다(C13 Closeout 정정 불변 — 폐기 아님).
  # 하한 불변식: 검증자 < 작업자 는 어떤 임무에서도 위반(goal §5-12). 판단-게이트(Agent 경로 Rule B)는 max(세션,작업자) 유지.
  FLOOR_TIER="$WORKER_TIER"; [ "$FLOOR_TIER" -gt 0 ] 2>/dev/null || FLOOR_TIER="$WF_TIER"
  while IFS="$(printf '\t')" read -r SP_TYPE SP_MODEL; do
    [ "$SP_TYPE" = "review-strict" ] || continue
    case "$SP_MODEL" in
      '*')       continue ;;   # C15: 동적 선언 — floor 미달 단언 불가(tier 0 오평가 방지, spec §14.1)
      -|inherit) SP_T="$WF_TIER"; SP_LABEL="상속(세션=$WF_SESSION_MODEL)" ;;
      *)         SP_T=$(tier_of "$SP_MODEL"); SP_LABEL="$SP_MODEL" ;;
    esac
    [ "$SP_T" -lt "$FLOOR_TIER" ] 2>/dev/null && C2_HIT="$SP_LABEL"
  done <<EOF
$SPAWNS
EOF
```

전제 변경 (슬롯1 S1/S2 정정 반영): 1패스의 `WORKER_TIER="$WF_TIER"`(:60) → `WORKER_TIER=0`, 그리고 실행자 티어 평가(:64)를 3분기로:

```bash
      case "$SP_MODEL" in
        -|inherit|'*') SP_T="$WF_TIER" ;;   # C16 S1/S2: 상속=세션 평가(검증자와 동일 규칙)·동적=세션 상계(보수)
        *)             SP_T=$(tier_of "$SP_MODEL") ;;
      esac
```

(기존 `SP_T=$(tier_of "$SP_MODEL")` 단독을 위 case로 교체 — 상속·동적 실행자가 있으면 floor≥세션이 유지되어 완화는 전-리터럴 스크립트에만 적용된다. Rule C의 fable 판정 case는 별도로 기존 그대로 유지 — SP_T 재사용 지점(:71 `[ "$SP_T" = "4" ]`)은 상속 시 세션 티어가 되는데, fable 세션에서 상속=4는 C_HIT 판정(:69 `-|inherit`)이 이미 선행 매치하므로 행동 불변.)
C2 메시지(:132)의 `필요 티어=$WORKER_TIER` → `필요 티어=$FLOOR_TIER`, 문구를 "기준선은 작업자 티어(실행자 부재 시 세션 티어)입니다(spec §15.1 임무-분리 — Agent 경로 게이트는 max(세션,작업자) 유지)"로 교체(§12.1 인용 제거).
헤더 주석(:4)의 "Rule B(검증자가 기준선 max(세션,작업자) 미만, 전 세션)" 서술은 유지하되 "Rule C2(Workflow 검증자가 작업자 티어 미만 — 임무-분리 floor, spec §15.1)"로 C2 부분만 갱신.
1패스 주석(:59)의 "WORKER_TIER = 실행자 최고 티어(검증자 floor 산정용 — spec §12.1)" → "WORKER_TIER = 실행자 최고 티어의 순수 관측(0=실행자 부재 — 검증자 floor 산정용, spec §15.1)" (Gate P 미커버 ② 해소).
C3 주석 블록(:78-79)의 "…(builtin general-purpose/Explore/ Plan 등 — agents/*.md 파일 자체가 없다)도 동일하게 상속한다" → "…도 **통상** 상속한다(예외: 일부 builtin 은 CC 자체 바인딩 — Explore=opus·claude-code-guide=haiku, spec §14.2 실측)" (B-X10 주석층 정정 — X15 완결).

`hooks/lib/workflow-spawns.js` 헤더의 MAX_SPAWNS 자인 주석(:37-40 부근)에 1줄 추가:

```
//     ★C16(B-X4): 3값 계약에서는 면제(`*`) 행도 상한을 소비한다 — 면제 스폰 200개 뒤의 진짜 위반이
//     절단되면 완전 침묵(2값 시대엔 동적 행 자체가 ALERT 였음). 수용 잔여(spec §15.2).
```

- [x] **Step 4: GREEN 확인 + 기존 무회귀**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -8`
Expected: `262 / 262 passed` (259+3). 특히 smp 14(실행자無+sonnet검증자=ALERT 폴백)·26·27·28(sonnet 세션+opus 실행자=ALERT)·29(fable inherit=SILENT)·03/04(Rule B 불변) 무회귀. 통과 출력 원문 인용.

- [x] **Step 5: README 카운트 259→262 (2곳 :292·:530) 갱신 + cases.tsv ssa 08/09 col4 정정 (§15.6-5 편승)**

`hooks/tests/cases.tsv` :34-35의 col4 `gen_ssa_resume` → `test_ssa_resume` 2행 (col4는 비소비 정보 컬럼 — run-all :1260이 col1/col2만 소비, 기능 무영향. 실제 실행 함수 `test_ssa_resume`와 표기 통일).

### Task 2: canonical carrier stage2 model 명시 + spec §12.1 행 인용 갱신 — 경로 (c) execute-strict(model:'opus')

**Files:**
- Modify: `workflows/rpi-implement.js` (stage2 opts에 `model: 'opus',` 삽입 + meta detail :6 + 헤더 주석 :15·:20-23)
- Modify: `docs/superpowers/specs/2026-07-25-model-policy-design.md` (§12.1 행 인용 4곳 재실측 갱신 — C14 규약 :451 블록)
- Test: `hooks/tests/run-all.sh` (신규 smp 44·45·46·47 — canonical 실물 4세션 E2E, 슬롯1 S12), `hooks/tests/cases.tsv`, `README.md` (262→266)

**Interfaces:**
- Consumes: Task 1의 신규 Rule C2 (fable 세션에서 stage2 `model:'opus'` 리터럴이 자기고발 ALERT를 내지 않음).
- Produces: 새 canonical carrier — Task 3~7이 이 carrier로 (d) 경로 실행.

- [x] **Step 1: RED — canonical 실물 E2E 픽스처 2개 추가**

```bash
# C16 §15.1: canonical carrier 실물 4세션 E2E — stage2 model:'opus' 명시 후 전 세션 무발화
# (구 carrier: sonnet/haiku 세션 ALERT — §12.1 표의 위반 칸이 §15.1 로 소멸함을 실물로 봉인. 슬롯1 S12)
SMP_HAIKU_T=$(mktemp "$SCRATCH/smp-haiku-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-haiku-4-5","content":[]}}\n' > "$SMP_HAIKU_T"
WF_CANON="$(cat "$HOME/.claude/workflows/rpi-implement.js")"
test_smp "44-canonical-fable-silent" 0 0 "$(mk_wf_event script "$WF_CANON" "$SMP_FABLE_T" "smp44-$$")"
test_smp "45-canonical-opus-silent" 0 0 "$(mk_wf_event script "$WF_CANON" "$SMP_OPUS_T" "smp45-$$")"
test_smp "46-canonical-sonnet-silent" 0 0 "$(mk_wf_event script "$WF_CANON" "$SMP_SONNET_T" "smp46-$$")"
test_smp "47-canonical-haiku-silent" 0 0 "$(mk_wf_event script "$WF_CANON" "$SMP_HAIKU_T" "smp47-$$")"
```

※ 델타 재심+슬롯1 S12 반영: 4세션 전부(fable/opus/sonnet/haiku) — 번호·sid 44~47은 T1 신규(41~43)와 유일.

cases.tsv 4행 등재 (`44-canonical-fable-silent`·`45-canonical-opus-silent`·`46-canonical-sonnet-silent`·`47-canonical-haiku-silent`, col4 `mk_wf_event`).
※ WF_CANON 은 **실물 파일을 읽는다** — 합성 재현 금지 원칙(cycle-40)의 픽스처판. carrier 를 고치면 픽스처가 자동 추종.

- [x] **Step 2: RED 확인**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -12`
Expected: **요약 라인 기준** 46·47 FAIL (수정 전 carrier = stage2 무지정 → sonnet 상속 2 / haiku 상속 1 < 작업자 3 → ALERT, got 1 vs want 0). 44·45는 이미 PASS(fable 4·opus 3 ≥ 3). 실패 출력 원문 인용. (S13 — 종료코드 아닌 요약 판정.)

- [x] **Step 3: GREEN — carrier stage2 model 명시 + 주석 동기**

`workflows/rpi-implement.js` stage2 opts를:

```js
  {
    agentType: 'review-strict',
    model: 'opus',
    label: `verify:${t.title}`,
    phase: 'Verify',
  }
```

meta detail(:6) `'task별 review-strict (모델 무지정=세션 상속 — 검증자 기준선 max(세션,작업자) 유지)'` → `'task별 review-strict (model opus 명시 = 작업자 티어 — 준수-확인 floor, spec §15.1)'`.
헤더 불변식(:15) `stage2 model·effort 무지정(상속)` → `stage2 model 'opus' 명시(작업자 티어 — §15.1 임무-분리 floor)·effort 무지정(상속)`.
적용 범위 주석(:20-23)의 "모드 (A) 전용 … sonnet/haiku 세션에서 쓰면 … 탈출구가 없다 … 그 세션에선 이 캐리어를 쓰지 말 것" → "주 사용 모드는 (A) fable+ultracode 이나, stage2=opus(작업자 티어)라 어느 세션에서도 준수-확인 floor 를 충족한다(§12.1 '탈출구 부재' 잔여 소멸 — spec §15.1). 판단-게이트가 아닌 준수-확인 경로 전용."
description(:3) `execute(opus) → review(inherit)` → `execute(opus) → review(opus)`.

- [x] **Step 4: GREEN 확인 + 파서 계약 확인**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -8`
Expected: `266 / 266 passed` (262+4).
Run: `node hooks/lib/workflow-spawns.js < workflows/rpi-implement.js`
Expected: `execute-strict	opus` + `review-strict	opus` 2행 — 보고에 원문 인용.

- [x] **Step 5: spec §12.1 행 인용 재실측 갱신 + §3 매트릭스 포인터 + README 카운트**

spec :451 인용-갱신 블록 규약대로 — carrier 편집 후 `grep -n "model: 'opus'\|agentType: 'review-strict'\|args.forEach\|const EFFORTS" workflows/rpi-implement.js`로 신규 행 번호 실측, §12.1 본문의 `:42`/`:57`/`:56-60`/`:25-35` 인용을 신값으로 치환하고 갱신 블록에 "C16 재실측" 1줄 추가.
spec §3 매트릭스(:105 검증 행·:108 하향 불릿)의 `⚠**§12.1이 supersede**` 2곳을 `⚠**§12.1→§15.1이 supersede**(현행: 임무-분리 — 준수-확인=작업자 티어/판단-게이트=max(세션,작업자))`로 갱신 (Gate P 미커버 ① 해소).
README 카운트 262→266 (2곳).

### Task 3: L1 문서 동기 — floor 임무-분리 전파 (경로 (d) 새 carrier; 슬롯1 S5·S7~S11·S32·S33 흡수)

**Files:**
- Modify: `docs/ai-context/model-policy.md` (:19 검증 행 · :22 하향 규칙 · :27 모드(A) stage2 서술 · :35 L2 Rule C2 서술)
- Modify: `docs/ai-context/cross-family-review.md` (:50 §3 첫 불릿)
- Modify: `skills/start-rpi-cycle/SKILL.md` (:131 (d) stage2 서술 · :132 인라인 규약 [S8] · :148 fable 위임 노트)
- Modify: `CONTEXT.md` (:85 「실행자 하향 위임」·:89 「역할×모델 매트릭스」의 구 floor 서술 [S9])
- Modify: `setup/verify-setup.sh` (#45 주석 ③ 기준선 서술 + ⑨ conjunct stage1-앵커 강화 [S5])
- Modify: `docs/superpowers/specs/2026-07-25-model-policy-design.md` (§3 :115 · §10 :250·:267 · §12.5 :576 · §12.6 :642 에 §15.1 supersede 포인터 [S10/S32/S33])
- Modify: `docs/ai-context/scaffold-registry.md` (:24 hook 행·:48 carrier 행 서술 [S7])
- Modify: `hooks/tests/run-all.sh` (픽스처 26 주석 `max(2,3)` → 작업자-floor 표기 [S11] — 주석만, 기대값 불변)
- Modify: `README.md` (:39 surface-model-policy 행 · :56 부근 검증자 서술 — 실측 후 해당 줄만)

**Interfaces:**
- Consumes: spec §15.1 확정 문안(동반 갱신 전수 목록 — 슬롯1 보강판).
- Produces: L1 전 계층이 "임무-분리 floor" 단일 서술 — Gate/Closeout drift 검사가 이 정합에 의존.

- [x] **Step 1: 각 파일의 현재 문구를 grep으로 실측 인용 후, 아래 요지로 치환 (기계적 편집 — 요지 밖 변경 금지)**

공통 치환 요지: "검증자 기준선 = max(세션, 작업자)" 단일 서술 → "검증자 기준선 = 임무-분리(C16 spec §15.1): 준수-확인(Workflow/Rule C2) = 작업자 티어(상속·동적 실행자는 세션 티어로 평가·실행자 전무 시 세션 폴백) / 판단-게이트(Agent/Rule B) = max(세션, 작업자) 유지. 하한: 어떤 임무에서도 검증자 < 작업자 금지".
- model-policy.md :19 검증 행: "상속 — 기준선 미만 금지" 유지하되 기준선 정의를 임무-분리로, 비고에 "Workflow stage2는 model:'opus' 명시(작업자 티어)가 새 기본 — 무지정(상속)도 fable/opus 세션에선 여전히 충족".
- model-policy.md :27 모드(A): `stage2 'review-strict' model/effort 무지정(상속)` → `stage2 'review-strict' model:'opus' 명시(작업자 티어 — spec §15.1)·effort 무지정(상속)`.
- model-policy.md :35 L2: Rule C2 정의를 "Workflow 검증자가 floor 미만 — floor = 리터럴 실행자 최고 티어(상속·동적 실행자는 세션 티어로 평가, 실행자 전무 시 세션 폴백) — 임무-분리(C16)"로. "무지정=상속도 세션 티어로 평가" 문장은 유지(불변 사실).
- cross-family-review.md :50: 기준선 서술을 임무-분리로 개정 + "C13 정밀화" 문구 뒤에 "(C16 §15.1이 임무-분리로 재정의 — Workflow 준수-확인 경로는 작업자 티어)" 추가.
- SKILL.md :131: `stage2 'review-strict' **model/effort 무지정**(상속 — 검증자 기준선 max(세션, 작업자) 유지)` → `stage2 'review-strict' **model:'opus' 명시**(작업자 티어 — 준수-확인 floor, spec §15.1)·effort 무지정(상속)`.
- SKILL.md :132 [S8]: `인라인 스크립트 작성 시에도 동일 규약(stage1 opus·stage2 무지정) 준수 (spec §10)` → `인라인 스크립트 작성 시에도 동일 규약(stage1 opus·stage2 opus 명시) 준수 (spec §10·§15.1)`.
- SKILL.md :148: "검증자(review-strict)는 model 무지정(상속)이 기본 — 기준선은 max(세션, 작업자)…" → "검증자(review-strict)의 Agent 경로(게이트) 기준선은 max(세션, 작업자) — 무지정(상속)이 세션 축을 보장하고, 실행자를 세션 위로 상향했으면 검증자도 동반 상향. Workflow 준수-확인 경로는 §15.1 임무-분리(작업자 티어)".
- CONTEXT.md :85 [S9]: `[[검증자 기준선]] \`max(세션, 작업자)\`가 별도 규율(상속 유지가 기본)` → `[[검증자 기준선]](임무-분리 — C16)이 별도 규율`. :89: `하향은 검증자가 [[검증자 기준선]](max(세션,작업자)) 미만 금지` → `하향은 검증자가 [[검증자 기준선]](임무별 floor — C16) 미만 금지`.
- verify-setup #45 주석 ③: "기준선 자체는 max(세션, 작업자)이며 inherit 은 그중 세션 축만 보장, spec §12.1" → "기준선은 임무-분리(spec §15.1) — inherit 유지는 wrapper frontmatter 기본값 앵커(Agent 경로 세션 축 보장)". **⑨ conjunct [S5]**: `grep -qE "model: 'opus'" …rpi-implement.js` → `grep -qE "agentType: 'execute-strict',\$" …` 다음 줄 `model: 'opus'` 존재를 앵커하도록 **2줄-문맥 grep으로 교체**: `grep -A2 "agentType: 'execute-strict'," "$HOME/.claude/workflows/rpi-implement.js" | grep -qE "model: 'opus'"` (stage1 스코프 앵커 — stage2 리터럴 추가로 무스코프 grep이 vacuous해지는 것 방지) + stage2용 동형 conjunct 1개 추가(`grep -A2 "agentType: 'review-strict',"` … `model: 'opus'`).
- spec §3 :115·§10 :250 [S10]: 해당 stage2 무지정 서술 줄 끝에 `(⚠§15.1이 supersede — stage2 는 model:'opus' 명시)` 부기. §10 :267 [S10]: Rule C2 서술에 `(⚠§15.1이 supersede — floor 임무-분리)` 부기. §12.5 :576 [S32]: 용어 정의에 `(⚠§15.1이 supersede — 임무-분리)` 부기. §12.6 :642 [S33]: "탈출구 부재라는 사실 자체는 유지(수용 잔여)" 끝에 `(⚠§15.1이 소멸 — stage2 opus 명시로 전 세션 floor 충족)` 부기.
- scaffold-registry :24 [S7]: `검증자 기준선 max(세션,작업자) 미달` → `검증자 기준선(임무-분리 floor, §15.1) 미달`. :48: `stage2 review(상속)` → `stage2 review(opus 명시 — 작업자 티어)`.
- run-all.sh 픽스처 26 주석 [S11]: `max(2,3)=3 > 2 위반 ALERT` → `작업자 floor 3 > 2 위반 ALERT (C16 임무-분리 — 산식 결과 동일)`.
- README :39·:56 부근: 실측 후 기준선 문구만 동기.

- [x] **Step 2: 검증 — 문서 정합 grep + 스위트**

Run: `grep -rn "max(세션" docs/ai-context/model-policy.md docs/ai-context/cross-family-review.md skills/start-rpi-cycle/SKILL.md CONTEXT.md README.md | grep -v "임무-분리\|판단-게이트\|Agent 경로\|max(세션, 작업자) 유지" || true`
Expected: 출력 0행 (임무-분리 문맥 없는 단독 max 서술 잔존 없음 — 슬롯1 S15: 0행이면 grep exit 1이 정상이라 `|| true`로 판정은 출력 기준). 출력 원문 인용.
Run: `bash setup/verify-setup.sh 2>&1 | tail -3` → #45 개정 conjunct 포함 `FAIL=0` 확인.

### Task 4: C16-A layer-yield 필드 + 대장 + seal #49 (경로 (d))

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md` (Step C-1 sub-step 9 신설 + Communication Protocol `layer-yield:` 필드)
- Create: `docs/ai-context/review-yield.md` (축적 대장 — C15 행 1호)
- Modify: `setup/verify-setup.sh` (seal #49), `setup/tests/seal-regression.test.sh` (Mutator 4 — #49 변이 [S6, §13.13 규약]), `docs/ai-context/scaffold-registry.md` (Docs 표 1행 + Drift Seals 헤딩 #17~#48→#49·표에 #49 행 [S7]), `README.md` (verify-setup 카운트 86→87 :300)

**Interfaces:**
- Produces: Closeout 고유 필수 필드 `layer-yield:` — 이번 사이클 Closeout 보고가 첫 소비자(자기 적용).

- [x] **Step 1: RED — seal #49를 먼저 추가**

`setup/verify-setup.sh` seal #48 뒤에:

```bash
# 49. layer-yield 필드 parity + 대장 존재 (C16 spec §15.3, #19 동형): Step C-1 절차와 Communication
#     Protocol 출력 계약이 같은 'layer-yield' 토큰을 갖고, 축적 대장 review-yield.md 가 실재해야.
#     누락 시 per-layer 수율이 복합 evidence 에 접혀 축적이 죽는다. bash grep only.
SK49="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
C1_49=$(awk '/^## Step C-1/{f=1;next} /^## Sub-cycle states/{f=0} f' "$SK49" 2>/dev/null)
CP_49=$(awk '/^## Communication Protocol/{f=1} f' "$SK49" 2>/dev/null)
if printf '%s' "$C1_49" | grep -q 'layer-yield' && printf '%s' "$CP_49" | grep -q 'layer-yield' \
   && [ -f "$HOME/.claude/docs/ai-context/review-yield.md" ] \
   && grep -q 'C15' "$HOME/.claude/docs/ai-context/review-yield.md"; then
  ok "layer-yield 필드 parity + review-yield.md 대장 (C16 §15.3)"
else
  fail "layer-yield drift (C16): SKILL.md 양구간 토큰 또는 review-yield.md 대장/C15 행 결손 — spec §15.3"
fi
```

- [x] **Step 2: RED 확인**

Run: `bash setup/verify-setup.sh 2>&1 | grep -E "layer-yield|카운트 seal|PASS="`
Expected: `PASS=85 FAIL=2` — #49 fail(SKILL.md 토큰·대장 부재) + #36 count-seal 연쇄 fail(총계 87 vs README 86 — 슬롯1 S14: #36은 PASS+FAIL+1 산식이라 #49 추가 즉시 README 미갱신 상태에서 함께 FAIL하는 것이 정상 RED). #49의 fail 메시지를 grep으로 직접 확인(tail은 #36에 가려짐). 출력 원문 인용.

- [x] **Step 3: GREEN — SKILL.md 필드 + 대장 신설**

SKILL.md Step C-1에 sub-step 9 추가(8 뒤):

```
9. layer-yield 계량 (Communication Protocol `layer-yield:` 필드로 출력 — C16 spec §15.3):
   - 이번 사이클 검문 층별 1줄: `<층명>: <상태> · 실발견 <N>건 · <발견|확인>` — `<상태>` ∈ {PASS, FAIL→정정,
     `k PASS/m FAIL` 집계, SKIP(사유), 실행(비판정 층)}. 층 = Gate R/P·stage2·senior·drift·교차패밀리·기타 실행분.
     다회 호출 층은 호출 수 병기(`stage2 ×6` — 1호출과 6호출의 발견 0은 다른 증거 강도).
   - 실발견 = REAL 판정된 내용 결함(정정/수용잔여 처분 무관 — 판정이 기준). 토큰 수치는 세션 아티팩트 가용 시
     부기(필수 아님 — 최소 계약은 발견 카운트).
   - 같은 행을 **글로벌 대장** `~/.claude/docs/ai-context/review-yield.md` 에 append(대상-프로젝트 사이클도 —
     리뷰 배분 재심은 하네스 거버넌스 결정. 3사이클 축적 후 floor·배분 재심이 소비처). append 는 Closeout
     **최종 커밋**에 포함(말미 층의 행이 실측이 되도록 — spec §15.3 S19).
   - 누락 = 구조적 불완전 (harness-verify·phase-skills 선례 — seal #49 가 필드 존재를 봉인).
```

Communication Protocol에 필드 추가(phase-skills 뒤):

```
- layer-yield: **고유 필수 필드** (모든 사이클). 검문 층별 `<층명>: <상태> · 실발견 <N>건 · <발견|확인>` 1줄씩
  (상태 enum·호출 수 병기·실발견 정의는 Step C-1 sub-step 9). 동일 행을 글로벌 review-yield.md 대장에 축적.
  생략 = 구조적 불완전. [C16 spec §15.3]
```

`docs/ai-context/review-yield.md` 신설:

```markdown
# review-yield.md — per-layer 리뷰 수율 축적 대장 (C16 spec §15.3)

> 사이클마다 Closeout `layer-yield:` 필드와 같은 행을 append. 소비처: 3사이클 축적 후 floor·리뷰 배분 재심.
> 실발견 = 내용 결함(산출물을 바꾼 발견). 토큰 수치는 가용 시 부기(필수는 발견 카운트).

## C15 (cycle 66, 2026-08-01 — 축적 1호, spec §15.0 실측)

- Gate R: PASS · 실발견 0건 · 확인 (71k)
- Gate P #1: FAIL→정정 · 실발견 3건 · 발견 (84k — 코드 전 차단)
- Gate P #2 재심: PASS · 실발견 0건 · 확인 (83k — 전체 재리뷰 낭비, C16-B의 근거)
- stage2 ×6: 5 PASS/1 FAIL · 실발견 0건 · 준수 확인 (273k — FAIL 1 = TDD RED 증거 강제)
- senior: PASS · 실발견 0건 · 확인 (80k, Minor 3)
- drift: PASS · 실발견 0건 · 확인 (47k)
- 교차패밀리(GPT, 말미): 실발견 13건 · 발견 (REAL 13/15)
```

대장 헤더의 실발견 정의는 sub-step 9와 동일 문구("REAL 판정된 내용 결함 — 처분 무관")로 통일. 교차패밀리 행에는 상태를 `실행`으로 부기(비판정 층 — S17 enum).
scaffold-registry.md Docs 표에 1행: `| docs/ai-context/review-yield.md | per-layer 리뷰 수율 축적 대장 — floor·배분 결정의 데이터 재심 | **C16 (2026-08-02)**; seal #49 |` + Drift Seals 절 헤딩 `#17~#48, −#26 소각 = 31` → `#17~#49, −#26 소각 = 32` + 표에 #49 행 추가 [S7].
README :300 `현재 86 PASS` → `현재 87 PASS`.

- [x] **Step 4: GREEN 확인**

Run: `bash setup/verify-setup.sh 2>&1 | tail -3`
Expected: `PASS=87 FAIL=0`. 출력 원문 인용.

- [x] **Step 5: seal-regression #49 변이 추가 (S6, §13.13 "seal 신설 사이클은 그 seal 의 마스킹을 같은 사이클에서 검사")** ※ 재심 3회차 관측: 실물에는 Mutator 1~13이 이미 존재 — 신규는 **Mutator 14 (seal #49)** 로 명명(아래 "Mutator 4" 표기는 오기, 실물 넘버링 따를 것)

`setup/tests/seal-regression.test.sh`의 Mutator 3 블록 뒤에 동형 추가 — 격리 복제본($HOME 스테이징)에서 `docs/ai-context/review-yield.md`를 삭제하는 변이를 주입하고 verify-setup이 non-zero exit + `layer-yield drift` FAIL 메시지를 내는지 단언:

```bash
# Mutator 4 — seal #49 (layer-yield parity + ledger): delete the ledger file.
run_mutation "seal49-ledger-missing" \
  "rm -f \"\$STAGE_HOME/.claude/docs/ai-context/review-yield.md\"" \
  "layer-yield drift"
```

(정확한 helper 함수명·인자 형태는 기존 Mutator 1~3 실물(:76-80 부근)을 읽고 동형으로 맞출 것 — 기존 3개 변이가 쓰는 스테이징·단언 패턴 재사용. 기존 15 PASS → 16 PASS.)

Run: `bash setup/tests/seal-regression.test.sh 2>&1 | tail -3`
Expected: `PASS=16 FAIL=0` (기존 15 + #49 변이 1). 출력 원문 인용.

### Task 5: C16-B 델타 재심 규약 명문화 (경로 (d))

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md` (Gate R FAIL 경로 :71 · Gate P FAIL 경로 :116-121 · (d) 경로 stage2 재실행 노트)

**Interfaces:**
- Produces: 재심 스코프 규약 — 이번 사이클에서 Gate P/stage2 FAIL 재심이 발생하면 즉시 적용.

- [x] **Step 1: 3곳 명문화 (기계적 편집)**

Gate R `FAIL 시:` 줄 뒤에:

```
   ※ 델타 재심 (C16 spec §15.4): 재실행 review-strict 의 success_criteria 는 "직전 FAIL 이 지목한
     항목 각각의 해소 + 그 정정이 새로 깨뜨린 것 없음"으로 한정 — 전체 기준 재검은 첫 회만.
```

Gate P `FAIL 시:` 블록 말미(override 줄 앞)에 동일 문구 1줄(spec §15.4 인용 포함).
(d) 경로의 "검증 기준 명시" 노트 뒤에:

```
      ※ **델타 재심 (C16 §15.4):** stage2 FAIL 후 재실행 시 successCriteria 를 "FAIL 지목 항목 해소 + 신규 파손 없음"으로
        좁혀 새 호출로 전달(canonical carrier 코드 무변경 — 프롬프트 규약).
```

- [x] **Step 2: 검증**

Run: `grep -c "델타 재심" skills/start-rpi-cycle/SKILL.md`
Expected: 3. seal #17(Phase R 3토큰)·#19(harness-verify)·#49(layer-yield) 무회귀: `bash setup/verify-setup.sh 2>&1 | tail -3` → `PASS=87 FAIL=0`.

### Task 6: C16-E 2-슬롯 + C16-C senior 적대 임무 전환 (경로 (d))

**Files:**
- Modify: `docs/ai-context/cross-family-review.md` (§2 빈도 상한 :44 → 2-슬롯 절 신설 · §관계 명시)
- Modify: `docs/ai-context/model-policy.md` (:20 교차 검증 행 "사이클당 1회" → "슬롯 2회")
- Modify: `skills/closeout-pr-cycle/SKILL.md` (Phase 4 senior 프롬프트 적대 전환 :96-126 + 교차 분기 :135-139 슬롯 2 표기)
- Modify: `skills/start-rpi-cycle/SKILL.md` (:200 교차 리뷰 옵션 → 2-슬롯 포인터, Gate P 직후 슬롯 1 명시)
- Modify: `README.md` (:57 부근 — 실측 후 해당 줄), `opencode-harness/skill/closeout-pr-cycle/SKILL.md` (:143)·`opencode-harness/skill/start-rpi-cycle/SKILL.md` (:194) 미러 동기

**Interfaces:**
- Consumes: spec §15.2 채택(senior 임무 전환 — 티어 세션 상속 불변)·§15.5 2-슬롯.
- Produces: 슬롯 1 규약 — 이번 사이클 Gate P 직후 실행이 첫 소비(이미 Phase P에서 실행 예정이므로 문서는 그 사후 착륙).

- [x] **Step 1: cross-family-review.md 개정**

:44 빈도 불릿을 교체:

```
- **빈도 상한: 사이클당 2슬롯(슬롯당 1회) — C16 §15.5**: 슬롯 1 = Gate P 직후, spec delta + plan 대상
  (설계-층 비대칭·계약 구멍을 코드 전에 — C15 X6 클래스 표적. 발견의 말미-도착이 만드는 재작업 꼬리 교정).
  슬롯 2 = Closeout, 코드 diff 대상(구현-층 결함은 코드가 있어야 잡힘 — 슬롯 1로 대체 불가).
  C11 의 "stage별 GPT 기각"과 별개 결정 — 그 기각은 N회(스테이지 수 비례), 이건 고정 2회. 저-스테이크
  사이클은 슬롯 1 생략 가능(고-스테이크 판정 기준은 기존 호출 지점 규정). quota 소비 최대 2회 — sol+ultra+
  verbosity high 조합 유지, `priority`(fast) 철회 불변. 불가 시 슬롯별 SKIP+사유(fail-open).
```

:44 뒤(또는 §2 말미)에 출력 파일·probe 규약 2줄 추가 [S30/S31]: "`-o` 출력은 **슬롯별 고유 경로**(`…-slot1-…`/`…-slot2-…`) — '호출 전 rm -f' 규율이 슬롯 2에서 슬롯 1 증거를 지우지 않게. '슬롯당 1회'는 본호출 기준 — probe 스모크는 별도이며 같은 사이클에서 슬롯 1 probe 성공 시 슬롯 2 probe 생략 가능."
슬롯 1 발견 처리 규약 1줄 추가 [S28]: "슬롯 1 발견은 메인 트리아지 후 REAL 이면 spec/plan 정정 → **Gate P 델타 재심**(§15.4)을 Phase I 착수 전에 통과해야 한다 — Gate P PASS 는 슬롯 1 REAL 정정에 의해 잠정화된다." + 슬롯 1 프롬프트 계약 1줄 [S27]: "슬롯 1 프롬프트 = refute-by-default 공통 규율 + 검사 범주 최소 세트{floor/판정식 건전성·소비자 동반-갱신 완결성·plan 내부 정합·신설 규약 우회 가능성·기존 문서 모순·근거 과잉 주장} — C16 첫 실행 프롬프트가 준거 템플릿."
:3 리드 문구 [S25]: `비-Claude 패밀리(GPT) 1회 리뷰` → `비-Claude 패밀리(GPT) 2-슬롯 리뷰(설계층·구현층)`.
§3 말미에 1문단: "**내부 적대 패스 (C16 §15.2)**: senior review(closeout-pr-cycle Phase 4)는 refute-by-default 적대 임무로 운용한다 — C16 블라인드 A/B(재발견 7/13, n=1 방향 신호)가 임무 프레이밍 전환의 충분성을 보임. 티어=세션 상속(판단-게이트 floor)·PASS/FAIL 출력 계약 불변(프레이밍만 교체). GPT-전속 발견 6건의 실측 1례처럼 교차패밀리 층의 대체가 아니라 보완이다."

- [x] **Step 2: closeout-pr-cycle Phase 4 프롬프트 적대 전환**

success_criteria의 검사 항목·PASS/FAIL 계약·Critical/Important/Minor/Suggestions 보고 형식은 **전부 유지**(S29 — 출력 계약 불변, 프레이밍만 교체). task를 `"pre-merge adversarial senior review — refute-by-default"`로, success_criteria 앞부분에 다음 추가:

```
        임무: 준수 확인이 아니라 결함 발견이다 (C16 spec §15.2 — 내부 적대 패스).
        refute-by-default: 각 검사 범주에서 결함을 찾으려 시도하고, 없으면 범주별 'none found' 명시.
        검사 범주(C15 교차리뷰 동형): A 계약 정합성(출력 계약·판정식·소비자 동반) · B 소비 로직(경계·폴백·마스킹)
        · C 픽스처 vacuity(구현 되돌려도 GREEN 인 픽스처) · D 문서-실물 드리프트 · E 무회귀(기존 의미 침묵 변경).
        발견은 파일:행 + 원문 인용 필수 — 인용 없는 발견은 무효.
        발견의 처분: 각 발견을 기존 보고 형식(Critical/Important/Minor)으로 분류해 합류 — PASS/FAIL 판정
        기준(FAIL if any Critical)은 불변.
```

교차패밀리 분기(:135-139)의 "**사이클당 1회** 실행" → "**슬롯 2**(Closeout, 코드 diff — 사이클당 2슬롯 상한의 둘째; 슬롯 1은 Gate P 직후 spec delta+plan 대상, cross-family-review.md §2)".

- [x] **Step 3: 나머지 동기 — model-policy :20 · start-rpi-cycle :200 · README · opencode 미러 2파일**

start-rpi-cycle :200: "…(GAP-006 규약, 가용 시 사이클당 1회·불가 시 SKIP+사유)" → "…(GAP-006+C16 §15.5 2-슬롯 규약 — 슬롯 1: Gate P 직후 spec delta+plan / 슬롯 2: Closeout 코드 diff. 가용 시 슬롯당 1회·불가 시 SKIP+사유)". Gate P 절 말미에도 1줄: "고-스테이크 사이클은 Gate P PASS 직후 교차패밀리 슬롯 1(spec delta+plan 적대 리뷰) 시도 — cross-family-review.md §2."
opencode 미러 2파일의 해당 줄(:143·:194)을 정본과 같은 요지로 동기.

- [x] **Step 4: 검증**

Run: `grep -rn "사이클당 1회" docs/ai-context/ skills/ opencode-harness/skill/ README.md | grep -v "슬롯당 1회\|슬롯\|priority\|철회\|명시 호출"`
Expected: 0행(문맥 없는 구 빈도 서술 잔존 없음). ※ Gate P+델타 재심 지적 반영 — `cross-family-review.md:35`(priority 철회 이력, 토큰 `철회`)·`:53`(codex-plugin-cc 기각 ② "사이클당 1회·명시 호출" 인용, 토큰 `명시 호출`)은 **판정-이력 기록이라 편집하지 않고 필터로 제외**한다(재논의-방지 기록의 원문 보존 — genesis-record 동형 원칙). :35의 "사이클당 1회 상한과 상충" 문구는 2-슬롯 후에도 논리 유효(슬롯당 1회 상한과 상충)이므로 잔존이 드리프트가 아님을 보고에 명시. 출력 인용.

### Task 7: C16-F plugin-pins 갱신 (경로 (d))

**Files:**
- Modify: `docs/ai-context/plugin-pins.md` (핀 표·skill-cksum·skill-count·갱신 이력 주석)

- [x] **Step 1: 재실측 + 갱신**

Run: `find "$HOME/.claude/plugins/cache/claude-plugins-official" -name SKILL.md | sort | xargs cat | cksum` 및 `... | wc -l`
Expected: 1583290756 / 37 (착수 실측치 — 변했으면 신값 사용 + 변동 사유 재확인).
표 갱신: superpowers 6.2.0(gitCommitSha 불변 6efe32c9…)·context7/skill-creator/playwright version `ba53b2ab03ad`(sha ba53b2ab03add41f…)·claude-md-management 불변. `skill-cksum:`·`skill-count:` 신값. 갱신 이력 주석 1개 추가:

```
<!-- 핀 갱신 이력: 2026-08-02 (C16-F-1) — 절차 ② 정당 업데이트 판정: superpowers 6.1.1→6.2.0(lastUpdated
  07-25) + context7/skill-creator/playwright 캐시 버전 디렉터리 추가(디렉터리명=하네스 repo sha — C10 명명
  특성 재확인). 콘텐츠 diff: superpowers SKILL.md 14종 중 7종 문구 정련 — 위임 agent명/게이트/권한 변경 0,
  rug-pull 아님. skill-creator 8버전 dir byte-동일. 구버전 6.1.1 캐시 잔존은 cksum 전량 해시에 포함(결정론). -->
```

- [x] **Step 2: 검증**

Run: `bash setup/verify-setup.sh 2>&1 | grep -E "plugin|#40" ; grep "skill-cksum" docs/ai-context/plugin-pins.md`
Expected: seal #40 green + 신값 기재.

### Task 8: 메모리 프루닝 [P2][P3][P4] — 메인 세션 직접 (repo 밖)

**Files:**
- Delete: `projects/C--Users-12132--claude/memory/feedback_response_language.md` ([P2])
- Create: `projects/C--Users-12132--claude/memory/project_ccs_routing.md` (5파일 통합 + [P4] 값 정정)
- Delete: 통합 원본 5파일 (project_ccs_codex_pending_fix·project_ccs_gemini_exclusion·project_ccs_codex_token_family_revocation·reference_ccs_routing_guide·project_fable5_enabled)
- Modify: `projects/C--Users-12132--claude/memory/MEMORY.md` (인덱스 6줄 제거 + 1줄 추가)

- [x] **Step 1: 통합 파일 작성** — 현행 사실 우선(핀 7.2.62-5·GPT 슬롯 sol/luna·게이트웨이 디스커버리·gemini 제외·토큰 패밀리 격리·바이너리 설치 금지 경고), 낡은 값(gpt-5.5/5.4-mini 시대·구 백업 파일명)은 1줄 이력으로 압축. cases: 각 원본의 Why/How-to-apply 보존.
- [x] **Step 2: 원본 5파일 + [P2] 1파일 삭제, MEMORY.md 인덱스 동기** (기존 링크 라벨 [[...]] 잔존 검사: `grep -rn "ccs-codex-pending-fix\|ccs-gemini-exclusion\|ccs-routing-guide-doc\|fable5-enabled" projects/C--Users-12132--claude/memory/`로 잔존 참조를 신규 파일명으로 정정).
- [x] **Step 3: 검증** — MEMORY.md 23,493B(24,519→) + 삭제 파일 0개 잔존 + 잔존 링크 2파일([[ccs-routing]]으로 재지향) 확인. ※ repo-밖 메모리 작업이라 Gate P 직후(슬롯 1 대기 중) 선실행 — goal §7 승인분.

### Task 9 (Closeout 게이트): 전 스위트 + 커밋/PR + GPT 슬롯 2

- [ ] 메인 포그라운드: `bash setup/verify-setup.sh`(87/0) · `bash hooks/tests/run-all.sh`(267/267 — 슬롯2 F4 포함) · `bash setup/tests/seal-regression.test.sh`(16/0 — Mutator 4 포함)
- [ ] 브랜치 커밋 → PR 생성(MERGE_POLICY wait — 머지는 사용자 승인)
- [ ] Closeout: drift review + GPT 슬롯 2(코드 diff) + goal §4 항목별 대조 + layer-yield 필드 자기 적용(첫 소비) + review-yield.md C16 행 append
