# C17 fable-minimization Implementation Plan (rev2 — 슬롯1 A1~F4 + Gate P BLOCKER 2 반영)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 68
**Started:** 2026-08-02

**Goal:** 역할×모델 매트릭스 v2 — 검증자 floor 세션 축 전면 제거(U4 공리) + frontmatter opus 물리 기본값(Option 1) + hook Rule A/B/C/C2 재정의(fable-누출 arm 전 세션 — A6) + 리뷰 통합(Gate R 조건부·drift/senior 합본·light-배칭) + 하우스키핑. SSOT: spec `docs/superpowers/specs/2026-07-25-model-policy-design.md` **§16**(Gate R PASS + 슬롯1/Gate P 트리아지 §16.8 반영판).

**Architecture:** L1+L2+L3 3층 동시 개정. **task 순서 = frontmatter(T1) → hook(T2)** — 역순이면 "hook 침묵 + frontmatter inherit" 커밋 창이 생긴다(§16.8 C3; 이 순서의 중간 창은 구 hook 소음-안전). 픽스처 양방향 반전 + 판별력 보존(트리거-교체 8건) + 신설 18건.

**Tech Stack:** bash(hook·seal)·node(파서 불변)·markdown(L1).

**Best-Direction Check:** 최선안 = Option 1(frontmatter 물리 기본값 — 실측 ①② 성립) / 채택안 = Option 1. **DOWNGRADE-DECLARED: 없음**.
**DOWNGRADE-DECLARED(U4 선적용 — goal §0 이 사용자 승인)**: §16 착륙 전의 opus 검증 위임(Gate R/P·stage2·통합 리뷰·델타 재심 전부 `model:'opus'` 명시)은 현행 라이브 규범 `max(세션,작업자)` 문면 위반 — 일괄 선언. 구 arm ALERT(`rule-b-verifier-downshift` 등)는 예상 소음으로 기록만. V3 선언: 실측 ①② 중 fable 스폰 4건 = `FABLE-ESCALATION(V3 — goal §C17-E 사전 지정 실측)`.

## Global Constraints

- 세 검증 스위트는 **메인 포그라운드만**(600s 초과 자동 백그라운드 강등 허용) — goal §4.
- seal/드리프트 검사는 **bash 파일옵스만**(staged-safe).
- carrier `workflows/rpi-implement.js` 무수정(goal B-5) — seal #45 ⑦⑧⑨ 앵커 보호.
- settings.json 라이브 수정 금지·설치/로그인 금지·schema 금지·GPT `-o` 파일 규약.
- CRLF 파일(README.md)은 sed 금지 — perl -pi.
- 예상 최종 카운트: verify-setup **87/0 (δ=0)** · run-all **286/286 (β=+18)** · seal-regression **기존 전 변이 + 신규 4 assert 전부 ✓ (γ=+4)**.
- Workflow (d): stage1 `model:'opus'`(heavy=xhigh/light=high) · stage2 `model:'opus'` 명시 · schema 금지 · TDD-verbatim.
- T2↔T3 이 README.md 공유, T3↔T4 인접 — carrier 가 파일 겹침 감지 시 자동 순차(의도됨).

---

### Task 1: frontmatter opus 전환 + seal #5/#45 개정 + seal-regression 변이 (heavy)

**Files:**
- Modify: `agents/execute-strict.md:14` (`model: inherit` → `model: opus`)
- Modify: `agents/review-strict.md:14` (동일)
- Modify: `setup/verify-setup.sh` (seal #5 :26-30 · seal #45 conjunct ③ 및 주석)
- Modify: `setup/tests/seal-regression.test.sh` (변이 M15/M16 — 각 2 assert)

**Interfaces:**
- Produces: frontmatter `model: opus` 실물(무지정 위임의 물리 기본값 — T2 hook "무지정=opus" 평가의 전제). `^model: opus$` frontmatter-스코프 앵커(#5)·라인 앵커 2건(#45 ③).
- Consumes: 없음. ※T1 커밋 후 T2 전 창은 "frontmatter opus + 구 hook" — 구 hook 이 무지정에 ALERT 하는 소음-안전 창(§16.8 C3 순서 근거).

- [x] **Step 1: RED — seal 앵커를 먼저 opus 로 개정하고 현행 frontmatter(inherit)에서 FAIL 관측**

`setup/verify-setup.sh` seal #5 (:26-30) 교체 — **frontmatter 블록-스코프**(§16.8 C6: 본문 라인 오매치 차단; `---` 구분자 사이만):
```bash
# 5. agents model:opus — 실행자·검증자 frontmatter 물리 기본값 (C17 Option 1, spec §16.1 — 무지정 위임의
#    안전 기본. 회귀 시 hook 의 "무지정=opus" 평가(§16.2)가 거짓이 된다. frontmatter 블록-스코프 판별
#    (C17 §16.8 C6 — 본문 코드블록의 model: 라인 오매치 차단). explore-strict 는 #45 가 별도 봉인)
for a in review-strict execute-strict; do
  FM5=$(awk '/^---$/{n++; next} n==1' "$HOME/.claude/agents/$a.md" 2>/dev/null)
  printf '%s\n' "$FM5" | grep -q '^model: opus$' && ok "$a model:opus" || fail "$a model"
done
```
seal #45 conjunct ③: 두 grep 을
```bash
grep -qE '^model:[[:space:]]*opus' "$HOME/.claude/agents/execute-strict.md" 2>/dev/null || MP_OK=0
grep -qE '^model:[[:space:]]*opus' "$HOME/.claude/agents/review-strict.md" 2>/dev/null || MP_OK=0
```
로 교체(review effort 키 부재 검사 불변). #45 주석 ③ 을 "execute/review `model: opus`(C17 Option 1 물리 기본값) + review-strict effort 키 부재"로, fail 메시지 "inherit 유지" → "opus 기본값". #45 는 토큰-존재 상한 수용(§16.4-3 — 블록-스코프는 #5 가 담당).

Run: `bash setup/verify-setup.sh 2>&1 | tail -2`
Expected: `PASS=84 FAIL=3` — `✗ review-strict model`·`✗ execute-strict model`·`✗ 역할×모델 매트릭스 봉인 붕괴`(frontmatter 아직 inherit — RED. #36 총계 seal 은 PASS+FAIL 합산이라 87 유지).

- [x] **Step 2: GREEN — frontmatter 전환**

`agents/execute-strict.md:14`·`agents/review-strict.md:14`: `model: inherit` → `model: opus`.

Run: `bash setup/verify-setup.sh 2>&1 | tail -2`
Expected: `verify-setup: PASS=87 FAIL=0` (δ=0. #47 은 execute/review 가 처음 루프 진입하나 hook case arm 에 매치해 green — Gate P 실측 확인).

- [x] **Step 3: seal-regression 변이 M15/M16 (각 2 assert — §16.8 C5: 단일 부분문자열은 #5 만 증명)**

`setup/tests/seal-regression.test.sh` 에 M9/M10 패턴 동형으로 추가 — **같은 변이를 #5·#45 각각의 FAIL 라인으로 2회 단언**(assert_seal_fires 는 substring 1개를 받으므로 label 을 나눠 2회 호출):
```bash
# Mutator 15/16 — seal #5·#45 conjunct ③ (C17 frontmatter opus): 실행자/검증자 frontmatter 를 inherit 로
# 되돌리면(Option 1 회귀 = hook "무지정=opus" 평가의 물리 전제 붕괴) #5 와 #45 가 각각 발화해야 한다.
# 기존 변이에 model 축 커버 0건 실측(C17 Phase R) — 이 변이들이 그 공백의 해소. 단언은 seal 별 분리
# (§16.8 C5 — "execute-strict model" 은 #5 만의 문자열이라 #45 결손을 못 잡는다).
mut_exec_model() { perl -pi -e 's/^model: opus$/model: inherit/' "<replica-root>/agents/execute-strict.md"; }
assert_seal_fires "exec_fm_model_s5" mut_exec_model "execute-strict model"
assert_seal_fires "exec_fm_model_s45" mut_exec_model "역할×모델 매트릭스 봉인 붕괴"
mut_review_model() { perl -pi -e 's/^model: opus$/model: inherit/' "<replica-root>/agents/review-strict.md"; }
assert_seal_fires "review_fm_model_s5" mut_review_model "review-strict model"
assert_seal_fires "review_fm_model_s45" mut_review_model "역할×모델 매트릭스 봉인 붕괴"
```
(★`<replica-root>` 는 스케치 — 파일에 `R` 변수는 **없다**(set -u, 뮤테이터는 `$1`=replica `.claude` 경로 수신). 정확한 replica 변수·시그니처는 파일 내 M9/M10 실물이 SSOT — **동형으로 맞출 것**(델타 재심 unknowns-2). `agents/execute-strict.md`·`agents/review-strict.md` 는 witness cksum 목록에 없으므로 **추가 필수**.)

Run: `bash setup/tests/seal-regression.test.sh 2>&1 | tail -25`
Expected: 기존 전 변이 + 신규 4 assert 전부 `✓`(non-zero exit + 해당 FAIL substring). 종료코드 0.

- [x] **Step 4: 커밋**

```bash
git add agents/execute-strict.md agents/review-strict.md setup/verify-setup.sh setup/tests/seal-regression.test.sh
git commit -m "feat(c17): frontmatter opus 물리 기본값(Option 1) + seal #5 블록-스코프/#45 개정 + 변이 M15/M16 (spec §16.1·§16.8 C5/C6)"
```

### Task 2: hook Rule A/B v2 + Rule C/C2 재계산 + 픽스처 전수 (heavy)

**Files:**
- Modify: `hooks/surface-model-policy.sh` (Rule A/B 전면 교체 · Rule C 1패스 · Rule C2 2패스+C2-leak · 헤더 주석)
- Modify: `hooks/tests/run-all.sh` (반전 4·트리거 교체 8·rename 6·신설 18·주석 갱신)
- Modify: `hooks/tests/cases.tsv` (rename 8행 + 신규 18행)
- Modify: `README.md` (:292 `268 case`·:530 `268 케이스` → **양쪽** 286 — perl -pi; §16.8 BLOCKER-2)

**Interfaces:**
- Consumes: T1 frontmatter opus 실물(무지정=opus 평가의 물리 전제). hook 은 agents/*.md 를 런타임에 읽지 않으므로(Gate P #6 실측) 픽스처 판정은 frontmatter 와 독립.
- Produces: 신 슬러그 `rule-a-fable-leak`·`rule-b-fable-leak`·`rule-b-verifier-below-opus-floor`·`rule-c-workflow-fable-leak`·`rule-c2-fable-verifier`(신설 arm). 구 슬러그 `rule-a-downshift-missing`·`rule-b-verifier-downshift`·`rule-c-workflow-downshift-missing` 소멸. `OPUS_FLOOR=3`.

- [x] **Step 1: RED — 픽스처를 신 기대값으로 먼저 전환**

run-all.sh surface-model-policy 구간 편집:

(a) **반전 4건** (입력 불변·기대만 교체) + **rename 6건**(이름만 — 03/04/15/29 는 의미-정확화(§16.8 C7/B2), 16/27 은 반전 반영):
```bash
# 01: fable + exec 무지정 → C17 무지정=frontmatter opus(§16.1 실측) — 침묵 전환 (구 ALERT)
test_smp "01-rule-a-fable-nomodel" 0 0 "$(mk_agent_event execute-strict "" "$SMP_FABLE_T" "smp01-$$")"
# 09: fable + 인라인 wf exec 무선언 → 침묵 전환 (구 ALERT)
test_smp "09-rule-c-inline-nomodel" 0 0 "$(mk_wf_event script "$WF_BAD_SCRIPT" "$SMP_FABLE_T" "smp09-$$")"
# 16: sonnet + 검증-전용(실행자 전무) + review sonnet → 폴백=opus 상수 3 > 2 — 새로 발화 (구 SILENT)
test_smp "16-rule-c2-fallback-opus-floor" 0 1 "$(mk_wf_event script "$WF_C2_BAD" "$SMP_SONNET_T" "smp16-$$")"
# 27: sonnet + exec opus + review 무지정 → 무지정=frontmatter opus 3 ≥ floor 3 — 침묵 반전 (구 ALERT;
#     구 "model 지우면 경고만 사라지는 거짓 복구" 서사는 신 의미론(무지정=실제 opus)에서 소멸 — §16.2)
test_smp "27-rule-c2-nomodel-above-floor" 0 0 "$(mk_wf_event script "$WF_EX_UP_INHERIT" "$SMP_SONNET_T" "smp27-$$")"
```
rename(기대 불변): `03-rule-b-verifier-downshift`→`03-rule-b-below-opus-floor`(신 슬러그 반영 — fable+sonnet 검증자는 floor arm 으로 여전히 ALERT) · `04-rule-b-inherit-ok`→`04-rule-b-nomodel-ok` · `15-rule-c2-review-inherit-ok`→`15-rule-c2-review-nomodel-ok` · `29-rule-c2-inherit-above-floor`→`29-rule-c2-nomodel-floor-met`(무지정/명시-inherit 의미 분리 후 구명이 오독 유발 — §16.8 C7). cases.tsv 8행(03/04/15/16/27/29 + 아래 11/49) 동기.

(b) **판별력 보존 트리거 교체 8건**(§16.2 말미 — 검사 주제가 무선언 arm 이 아닌 픽스처는 위반 트리거를 명시 `inherit`(또는 49 는 opus)로 교체해 원 성질 봉인 유지):
```bash
# 08/19: (주제: content 인용 면역 / 공백 model 키 세션 판별) 트리거를 명시 inherit 로
test_smp "08-quoted-id-immune" 0 1 "$(mk_agent_event execute-strict inherit "$SMP_QUOTE_T" "smp08-$$")"
test_smp "19-spaced-model-key" 0 1 "$(mk_agent_event execute-strict inherit "$SMP_SPACED_T" "smp19-$$")"
# 11: (주제: scriptPath 파일 읽기) 파일 내용을 명시 inherit 스폰으로 + rename
WF_SP_BAD_CONTENT="export const meta = {name: 'x', description: 'x'}
await agent('do it', {agentType: 'execute-strict', model: 'inherit'})"
WF_SP_BAD=$(mktemp "$SCRATCH/wf-sp-bad-XXXXXX.js"); printf '%s\n' "$WF_SP_BAD_CONTENT" > "$WF_SP_BAD"
test_smp "11-rule-c-scriptpath-explicit-inherit" 0 1 "$(mk_wf_event scriptPath "$WF_SP_BAD" "$SMP_FABLE_T" "smp11-$$")"
# 20: (주제: per-spawn 마스킹 해소) 둘째 스폰을 명시 inherit 로
WF_MASK="export const meta = {name: 'x', description: 'x'}
await agent('a', {agentType: 'execute-strict', model: 'opus'})
await agent('b', {agentType: 'execute-strict', model: 'inherit'})"
# 21: (주제: 프롬프트-노이즈 오인 방지) 스폰에 명시 inherit
WF_PROMPT_NOISE="export const meta = {name: 'x', description: 'x'}
const P = \`policy: model: 'opus' required\`
await agent(P, {agentType: 'execute-strict', model: 'inherit'})"
# 30: (주제: 3규칙 동시-emit 무손실 — §16.8 C1/Gate P BLOCKER-1) 무선언 exec 를 명시 inherit 로
WF_MULTI="export const meta = {name: 'x', description: 'x'}
await agent('implement', {agentType: 'execute-strict', model: 'inherit'})
await agent('research', {})
await agent('review', {agentType: 'review-strict', model: 'haiku'})"
# 35: (주제: 삼항 마스킹 해소) else 분기를 명시 inherit 로
WF_TERNARY="export const meta = {name: 'x', description: 'x'}
await agent('impl', heavy ? {agentType: 'execute-strict', model: 'opus'} : {agentType: 'execute-strict', model: 'inherit'})"
# 49: (주제: Rule C 미지-리터럴 원시-티어 비발화 + A5 미지→opus floor 평가 겸용) review 를 fable→opus 로
#     — 구 코드: 미지 실행자=세션 상계 4 → review opus 3<4 C2 ALERT / 신: 미지=opus 3 → 3≥3 SILENT (반전)
WF_UNKNOWN_ONLY="await agent('a', {agentType: 'execute-strict', model: 'gpt-custom'})
await agent('v', {agentType: 'review-strict', model: 'opus'})"
test_smp "49-rule-c-unknown-literal-exempt" 0 0 "$(mk_wf_event script "$WF_UNKNOWN_ONLY" "$SMP_FABLE_T" "smp49-$$")"
```
(변수 재정의는 원 정의 위치에서 수정.)

(c) **신설 18건** (50~67; cases.tsv 동기 — col3=0, col4 는 생성기명):
```bash
# C17 (50): Rule A 유지 arm — fable 세션 명시 inherit 실행자 = fable 누출 → ALERT
test_smp "50-rule-a-explicit-inherit" 0 1 "$(mk_agent_event execute-strict inherit "$SMP_FABLE_T" "smp50-$$")"
# C17 (51): Rule A — fable 세션 명시 fable 실행자 → ALERT
test_smp "51-rule-a-explicit-fable" 0 1 "$(mk_agent_event execute-strict fable "$SMP_FABLE_T" "smp51-$$")"
# C17 (52): Rule B 누출 arm — fable 세션 검증자 명시 inherit → ALERT (구: tier0 guard 침묵 — 새로 발화)
test_smp "52-rule-b-fable-explicit-inherit" 0 1 "$(mk_agent_event review-strict inherit "$SMP_FABLE_T" "smp52-$$")"
# C17 (53): Rule B floor — sonnet 세션 검증자 명시 inherit = 세션 평가 2<3 → ALERT (새로 발화)
test_smp "53-rule-b-sonnet-explicit-inherit" 0 1 "$(mk_agent_event review-strict inherit "$SMP_SONNET_T" "smp53-$$")"
# C17 (54): 구 하향 arm 제거 앵커 — fable 세션 검증자 opus → SILENT (구 ALERT 소음 — T7 라이브 재현)
test_smp "54-rule-b-fable-opus-silent" 0 0 "$(mk_agent_event review-strict opus "$SMP_FABLE_T" "smp54-$$")"
# C17 (55): Rule B 미지-리터럴 비면제 → ALERT (구: != 0 guard 침묵 — 새로 발화)
test_smp "55-rule-b-unknown-literal" 0 1 "$(mk_agent_event review-strict gpt-custom "$SMP_FABLE_T" "smp55-$$")"
# C17 (56): Rule C2 — 명시 inherit 검증자 세션 평가 유지(C13 존속) — sonnet 세션 2<3 → ALERT
WF_EX_UP_EXPL_INH="export const meta = {name: 'x', description: 'x'}
await agent('a', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'inherit'})"
test_smp "56-rule-c2-explicit-inherit-below-floor" 0 1 "$(mk_wf_event script "$WF_EX_UP_EXPL_INH" "$SMP_SONNET_T" "smp56-$$")"
# C17 (57): Rule B floor 전-세션 가드 — opus 세션 검증자 sonnet 2<3 → ALERT (구 세션-하향과 동일 발화·사유 교체)
test_smp "57-rule-b-opus-session-sonnet" 0 1 "$(mk_agent_event review-strict sonnet "$SMP_OPUS_T" "smp57-$$")"
# C17 (58): Rule C2 폴백 opus 상수 — fable 검증-전용 + review opus → SILENT (구: 세션 폴백 4>3 ALERT —
#     2026-08-02 검증-전용 Workflow 라이브 오발화의 재현·해소 앵커)
WF_REVIEWONLY_OPUS="export const meta = {name: 'x', description: 'x'}
await agent('verify it', {agentType: 'review-strict', model: 'opus'})"
test_smp "58-rule-c2-reviewonly-opus-silent" 0 0 "$(mk_wf_event script "$WF_REVIEWONLY_OPUS" "$SMP_FABLE_T" "smp58-$$")"
# C17 (59/60): Rule B floor — 동일-티어 구멍 소멸 (§16.8 A4; 구 하향식 2<2·1<1 거짓 침묵 → 새로 발화)
test_smp "59-rule-b-sonnet-session-sonnet" 0 1 "$(mk_agent_event review-strict sonnet "$SMP_SONNET_T" "smp59-$$")"
test_smp "60-rule-b-haiku-session-haiku" 0 1 "$(mk_agent_event review-strict haiku "$SMP_HAIKU_T" "smp60-$$")"
# C17 (61/62): fable-리터럴 누출 arm 전 세션 (§16.8 A6 — U4 금지는 세션 무관; 구: 상향 허용 침묵)
test_smp "61-rule-b-nonfable-fable-leak" 0 1 "$(mk_agent_event review-strict fable "$SMP_SONNET_T" "smp61-$$")"
test_smp "62-rule-a-nonfable-fable-leak" 0 1 "$(mk_agent_event execute-strict fable "$SMP_SONNET_T" "smp62-$$")"
# C17 (63): Rule C fable-리터럴 전 세션 (A6) — sonnet 세션 wf exec fable → ALERT
WF_FABLE_NONFABLE="export const meta = {name: 'x', description: 'x'}
await agent('do it', {agentType: 'execute-strict', model: 'fable'})"
test_smp "63-rule-c-nonfable-fable-leak" 0 1 "$(mk_wf_event script "$WF_FABLE_NONFABLE" "$SMP_SONNET_T" "smp63-$$")"
# C17 (64): C2-leak 신설 arm — 검증자 fable-리터럴 전 세션 (A6; 구: floor 충족 침묵 → 새로 발화)
WF_C2_FABLE_VERIFIER="await agent('impl', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'fable'})"
test_smp "64-rule-c2-fable-verifier" 0 1 "$(mk_wf_event script "$WF_C2_FABLE_VERIFIER" "$SMP_OPUS_T" "smp64-$$")"
# C17 (65): Rule B floor 미지-세션 수행 (§16.8 A1 — 리터럴 평가는 세션 불요; 구: SESSION_TIER=0 전체 skip)
SMP_UNKNOWN_T=$(mktemp "$SCRATCH/smp-unknown-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-quasar-1","content":[]}}\n' > "$SMP_UNKNOWN_T"
test_smp "65-rule-b-unknown-session-literal" 0 1 "$(mk_agent_event review-strict sonnet "$SMP_UNKNOWN_T" "smp65-$$")"
# C17 (66): Rule B 신 메시지 내용 봉인 (§16.8 B2 — ctx 존재만 보면 구 메시지 잔존 미탐; hedge 동형)
test_smp_b_msg() {
  TOTAL=$((TOTAL+1))
  local out; out=$(printf '%s' "$1" | "$HOOKS/surface-model-policy.sh" 2>/dev/null)
  if printf '%s' "$out" | grep -q 'max(작업자'; then PASSED=$((PASSED+1))
  else FAILED_LIST+=("surface-model-policy/66-rule-b-message-floor-token"); fi
}
test_smp_b_msg "$(mk_agent_event review-strict sonnet "$SMP_FABLE_T" "smp66-$$")"
# C17 (67): C2-leak — fable 세션 검증자 명시 inherit (=fable 상속) → ALERT (구: 4≥floor 침묵 — 새로 발화)
WF_C2_INH_FABLE="await agent('impl', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'inherit'})"
test_smp "67-rule-c2-fable-inherit-verifier" 0 1 "$(mk_wf_event script "$WF_C2_INH_FABLE" "$SMP_FABLE_T" "smp67-$$")"
```
cases.tsv 에 18행 추가(50~67; col4 는 66=`test_smp_b_msg`, 나머지 `mk_agent_event`/`mk_wf_event`). rm -f 스테일 마커 라인에 `/tmp/model-policy-c2l-smp*` 추가(C2-leak 마커).

README 카운트 — **양쪽**(§16.8 BLOCKER-2; seal #20 이 cases.tsv 언급 라인 전수 대조):
```bash
perl -pi -e 's/268 case/286 case/; s/268 케이스/286 케이스/' "$HOME/.claude/README.md"
```

- [x] **Step 2: RED 실측 — 구 hook 코드에서 run-all 실행**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -25`
Expected: 요약 `Hook tests: 267 / 286 passed` — **정확히 19 FAIL**: `01·09·16·27·49·52·53·54·55·58·59·60·61·62·63·64·65·66·67`(종료코드가 아니라 요약 텍스트 판정 — pass-rate 게이트 95%. 267/286=93.4% 라 exit 도 non-zero 이나 판정은 텍스트). 트리거-교체 8건 중 49 를 제외한 7건(08/11/19/20/21/30/35)과 신설 가드 4건(50/51/56/57)은 구 코드에서도 PASS — 이 19개 외 FAIL 발생 시 픽스처 편집 오류.

- [x] **Step 3: hook 재정의 구현**

`hooks/surface-model-policy.sh` 편집:

(a) **헤더 주석 :2-10**: "Rule A(실행자 fable-누출 — 명시 fable 전 세션·명시 inherit fable 세션)·Rule B(검증자 opus-floor 전 세션 + fable-누출 — 구 세션-대비-하향 arm 은 C17 제거)·Rule C/C2(무선언=frontmatter opus 추종(C17 실측)·C2 폴백=opus 상수·C2-leak 신설)·Rule C3(불변)" + spec §16 포인터.

(b) **Rule C 1패스** — execute-strict 평가 교체:
```bash
    if [ "$SP_TYPE" = "execute-strict" ]; then
      case "$SP_MODEL" in
        -)       SP_T=3; SP_T_RAW="$SP_T" ;;   # C17 §16.2: 무선언=frontmatter opus (실측 §16.1 ②)
        inherit) SP_T="$WF_TIER"; SP_T_RAW="$SP_T" ;;   # 명시 inherit=세션 상속 (C13 의미론 존속)
        '*')     SP_T="$WF_TIER"; SP_T_RAW="$SP_T" ;;   # 동적=세션 평가 (휴리스틱 — 상계 아님, §16.4-4)
        *)       SP_T_RAW=$(tier_of "$SP_MODEL"); SP_T="$SP_T_RAW"
                 # C17: 미지-티어 리터럴은 opus 평가 (구: 세션 — fable 세션에서 opus 검증자 오고발.
                 # 상계 아님(§16.4-4 정직) — floor 를 0 으로 끌어내리지 않게 하는 F4 원리만 유지)
                 [ "$SP_T" -gt 0 ] 2>/dev/null || SP_T=3 ;;
      esac
      [ "$SP_T" -gt "$WORKER_TIER" ] 2>/dev/null && WORKER_TIER="$SP_T"
      # Rule C v2: 실행자 fable-누출 — 명시 fable 리터럴은 전 세션(A6·U4 세션 무관), 명시 inherit 은
      # fable 세션 한정(=fable 상속). 무선언(-)은 frontmatter opus 추종이라 침묵 전환(C17 §16.2).
      case "$SP_MODEL" in
        -|'*') ;;
        inherit) [ "$WF_TIER" = "4" ] && C_HIT=1 ;;
        *) [ "$SP_T_RAW" = "4" ] && C_HIT=1 ;;   # 원시 티어 — F4 평가 누출 차단(senior I1) + A6 전 세션
      esac
    fi
```
(기존 `if [ "$WF_TIER" = "4" ]` 외곽 게이트 제거 — inherit arm 내부 조건으로 이동.)

(c) **Rule C2 2패스** — 주석·판정식 교체 + C2-leak 신설:
```bash
  # 2패스: 검증자 floor — 임무-분리 v2 (C17 spec §16.2·§16.8, §15.1 판단-게이트 절반 재-supersede).
  # floor = 작업자 티어. 실행자-전무 폴백 = opus 정책 상수 3 (구: 세션 — 검증-전용 Workflow 에서 opus
  # 검증자를 오고발하던 소음원, 2026-08-02 라이브). 검증자 평가: 무선언(-)=frontmatter opus / 명시
  # inherit=세션(C13 존속) / '*'=면제 / 리터럴=tier_of.
  # 기타 모델(tier 0)도 면제하지 않는다 — "기타=0" 은 tier 계약이지 판정 면제가 아니다 (GPT [C]2 REAL, C13 — C17 복원).
  # C2-leak (§16.8 A6): 검증자 fable-리터럴=전 세션 / 명시 inherit=fable 세션 — U4 금지는 floor 와 독립.
  # 하한 불변식: 검증자 < 작업자 금지. 판단-게이트(Agent 경로 Rule B)는 max(작업자, opus) — §16.
  FLOOR_TIER="$WORKER_TIER"; [ "$FLOOR_TIER" -gt 0 ] 2>/dev/null || FLOOR_TIER=3
  C2L_HIT=""
  while IFS="$(printf '\t')" read -r SP_TYPE SP_MODEL; do
    [ "$SP_TYPE" = "review-strict" ] || continue
    case "$SP_MODEL" in
      '*')     continue ;;   # C15: 동적 선언 — floor 미달 단언 불가(spec §14.1)
      -)       SP_T=3; SP_LABEL="무지정(frontmatter opus)" ;;   # C17 §16.2
      inherit) SP_T="$WF_TIER"; SP_LABEL="inherit(세션=$WF_SESSION_MODEL)"
               [ "$WF_TIER" = "4" ] && C2L_HIT="$SP_LABEL" ;;
      *)       SP_T=$(tier_of "$SP_MODEL"); SP_LABEL="$SP_MODEL"
               [ "$SP_T" = "4" ] && C2L_HIT="$SP_LABEL" ;;
    esac
    [ "$SP_T" -lt "$FLOOR_TIER" ] 2>/dev/null && C2_HIT="$SP_LABEL"
  done <<EOF
$SPAWNS
EOF
```
emit 블록에 C2-leak 추가(기존 C2 emit 뒤, 동형):
```bash
  if [ -n "$C2L_HIT" ] && fire_once model-policy-c2l; then
    hook_log "surface-model-policy" "workflow:review-strict:$C2L_HIT" "ALERT" "rule-c2-fable-verifier"
    add_msg "[model-policy] Workflow 검증자(review-strict)가 fable 을 소비합니다(관측='$C2L_HIT') — fable 위임은 기본 금지(밸브 V1/V2/V3 + FABLE-ESCALATION 선언만 예외, spec §16.5; 밸브 동반-상향 케이스면 이 환기는 무시 가능). (advisory · 1세션 1회 · 차단 아님)"
  fi
```
기존 C2 메시지 교체(§16.8 C4 — "model 을 지우는 것(상속)만으로는 해소되지 않습니다"는 신 의미론에서 거짓): "[model-policy] Workflow 스크립트의 검증자(review-strict)가 기준선 미만입니다(관측='$C2_HIT', 필요 티어=$FLOOR_TIER). 기준선은 작업자 티어(실행자 부재 시 opus 정책 상수)입니다(spec §16 임무-분리 v2 — Agent 경로 게이트는 max(작업자, opus)) — 무지정은 frontmatter opus 라 안전하나 **명시 inherit 로는 해소되지 않습니다**(명시 inherit=세션 티어). 실행자 티어 이상을 명시하십시오. 의도 하향이면 DOWNGRADE-DECLARED(사유) 선언 필요. (advisory · 1세션 1회 · 차단 아님)"
Rule C 슬러그·메시지 교체(§16.8 B1): `hook_log` 를 `"workflow:execute-strict:leak" "ALERT" "rule-c-workflow-fable-leak"` 로, 메시지를 "[model-policy] Workflow 스크립트가 execute-strict 스테이지에 fable 을 소비시킵니다(명시 inherit=세션 상속 또는 fable 리터럴) — 구현 스테이지는 model:'opus' 고정이 정책이며 무선언은 frontmatter opus 라 안전 기본(C17). canonical: \$HOME/.claude/workflows/rpi-implement.js 절대경로 scriptPath 권장. SSOT: docs/ai-context/model-policy.md §2·spec §16 (advisory · 1세션 1회 · 차단 아님)" 로.

(d) **Rule A/B 전면 교체**(Agent 경로):
```bash
# Rule A v2 — 실행자 fable-누출 (C17 spec §16.2·§16.8 A6): 명시 fable 리터럴=전 세션 · 명시 inherit=
# fable 세션 한정. 무지정은 frontmatter `model: opus`(Option 1, 실측 §16.1) 추종이라 침묵 — 구 무지정 arm 제거.
if [ "$SUB" = "execute-strict" ] && [ -n "$REQ_MODEL" ]; then
  A_HIT=0
  if [ "$(tier_of "$REQ_MODEL")" = "4" ]; then A_HIT=1
  elif [ "$REQ_MODEL" = "inherit" ] && [ "$SESSION_TIER" = "4" ]; then A_HIT=1
  fi
  if [ "$A_HIT" = "1" ]; then
    MARKER="$(session_marker model-policy-a "$SESSION_ID")"
    [ -f "$MARKER" ] && exit 0
    touch "$MARKER" 2>/dev/null || true
    hook_log "surface-model-policy" "execute-strict:$REQ_MODEL" "ALERT" "rule-a-fable-leak"
    emit_additional_context "[model-policy] 실행자(execute-strict)가 fable 을 소비합니다(명시 inherit/fable) — fable 위임은 기본 금지(밸브 V1/V2/V3 + FABLE-ESCALATION 선언만 예외, spec §16.5). 구현은 opus 가 정책이며 무지정이 안전 기본(frontmatter opus — C17 Option 1). SSOT: docs/ai-context/model-policy.md (advisory · 1세션 1회 · 차단 아님)"
    exit 0
  fi
fi

# Rule B v2 — 검증자 opus-floor(전 세션 — 미지-티어 세션 포함, §16.8 A1) + fable-누출 (C17 spec §16.2).
# 구 "세션 대비 하향" arm 제거 — fable 세션 opus 검증자(신 정책 정상 패턴)를 ALERT 하던 소음원.
# 평가: 무지정=frontmatter opus(침묵·게이트의 -n 이 처리) · 명시 inherit=세션 티어(미지 세션은 skip —
# 단언 불가) · 리터럴=tier_of(미지 0 비면제 — ≥opus 단언 불가; 세션 티어 불요라 미지 세션에서도 수행).
OPUS_FLOOR=3
if [ "$SUB" = "review-strict" ] && [ -n "$REQ_MODEL" ]; then
  B_SLUG=""; B_MSG=""
  if [ "$REQ_MODEL" = "inherit" ]; then
    if [ "$SESSION_TIER" = "4" ]; then
      B_SLUG="rule-b-fable-leak"
      B_MSG="[model-policy] 검증자(review-strict)가 명시 inherit 로 위임됩니다 — fable 세션에선 선언 없는 fable 소비(누출). 판단-게이트 기준선은 max(작업자 티어, opus)(spec §16 — U4 세션 축 제거): opus 명시 또는 무지정(frontmatter opus)을 쓰십시오. (advisory · 1세션 1회 · 차단 아님)"
    elif [ "$SESSION_TIER" != "0" ] && [ "$SESSION_TIER" -lt "$OPUS_FLOOR" ] 2>/dev/null; then
      B_SLUG="rule-b-verifier-below-opus-floor"
      B_MSG="[model-policy] 검증자(review-strict) 기준선 미달 — 명시 inherit 는 세션($SESSION_MODEL) 평가이고 그 티어가 opus 미만입니다. 판단-게이트 기준선은 max(작업자 티어, opus)(spec §16). 의도 하향이면 DOWNGRADE-DECLARED(사유) 선언 필요. (advisory · 1세션 1회 · 차단 아님)"
    fi
  else
    REQ_TIER=$(tier_of "$REQ_MODEL")
    if [ "$REQ_TIER" = "4" ]; then
      B_SLUG="rule-b-fable-leak"
      B_MSG="[model-policy] 검증자(review-strict)가 명시 fable 로 위임됩니다 — fable 위임은 기본 금지(밸브 V1/V2/V3 + FABLE-ESCALATION 선언만 예외, spec §16.5; 밸브 동반-상향이면 이 환기는 무시 가능). (advisory · 1세션 1회 · 차단 아님)"
    elif [ "$REQ_TIER" -lt "$OPUS_FLOOR" ] 2>/dev/null; then
      B_SLUG="rule-b-verifier-below-opus-floor"
      B_MSG="[model-policy] 검증자(review-strict) 기준선 미달(관측='$REQ_MODEL' — 미지 티어 포함 비면제) — 판단-게이트 기준선은 max(작업자 티어, opus)(spec §16, SSOT: docs/ai-context/model-policy.md). 의도 하향이면 DOWNGRADE-DECLARED(사유) 선언 필요. (advisory · 1세션 1회 · 차단 아님)"
    fi
  fi
  if [ -n "$B_SLUG" ]; then
    MARKER="$(session_marker model-policy-b "$SESSION_ID")"
    [ -f "$MARKER" ] && exit 0
    touch "$MARKER" 2>/dev/null || true
    hook_log "surface-model-policy" "review-strict:$REQ_MODEL" "ALERT" "$B_SLUG"
    emit_additional_context "$B_MSG"
    exit 0
  fi
fi
```
(구 Rule B 의 `[ "$SESSION_TIER" != "0" ]` 외곽 게이트 제거 — inherit-floor 분기 내부에만 존속. Workflow 의 `WF_TIER=0` 조기 exit 은 유지 — §16.4-5 비대칭 수용.)

(e) 기존 픽스처 주석의 구 산식 표기(15/29 "상속=세션"·43·48 "세션 상계") 신 산식으로 동반 갱신(S11 선례).

- [x] **Step 4: GREEN — run-all 전량 통과**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -6`
Expected: `Hook tests: 286 / 286 passed` + `cases.tsv <-> run-all 정합 OK (286 declared == 286 run…)` + `Pass rate 100%`.

- [x] **Step 5: 커밋**

```bash
git add hooks/surface-model-policy.sh hooks/tests/run-all.sh hooks/tests/cases.tsv README.md
git commit -m "feat(c17): hook Rule A/B v2 + C/C2 재계산 — opus-floor 전세션·fable-누출 arm(A6)·C2-leak·무선언=frontmatter opus (spec §16.2·§16.8)"
```

### Task 3: L1 문서 배치 — 정책·용어·포인터·대장 (light, §16.3-3 병합 규약 첫 적용)

**Files:**
- Modify: `docs/ai-context/model-policy.md` · `docs/ai-context/cross-family-review.md` (§3 첫 단락 + :67) · `CONTEXT.md` (:85·:89) · `README.md` (:39·:56·:59 + :69·:185·:234 — perl) · `docs/ai-context/scaffold-registry.md` (:24·:32·:48·:83) · `hooks/verify-loop-watch.sh` (:38 문구 1곳) · `docs/superpowers/specs/2026-07-25-model-policy-design.md` (포인터·정오) · `docs/ai-context/review-yield.md` (정정 행)

**Interfaces:**
- Consumes: T1/T2 실물(hook v2·frontmatter opus) — 서술이 실물을 정확히 반영(드리프트 0).
- Produces: 구 산식 `max(세션` 현행-규범 서술 잔존 0 (genesis·이력 인용 제외) + 구 2-리뷰 토폴로지 서술 잔존 0.

- [x] **Step 1: model-policy.md 매트릭스 v2**

- :16-17 구현 행: "**opus** (fable 세션 한정 호출 인자 명시…)" → "**opus** (frontmatter 기본 — C17 Option 1. 명시는 선택 보강; 무지정도 안전 기본)". 모드 (B) 문구 동기.
- :19 검증 행: "기준선 = **임무-분리 v2**(C17, spec §16): **준수-확인**(Workflow·Rule C2) = **작업자 티어**(실행자-전무 폴백 = **opus 정책 상수**) / **판단-게이트**(Agent 경로·Rule B) = **`max(작업자 티어, opus)`** — 세션 축 제거(U4). 평가: 무지정=frontmatter opus·명시 inherit=세션 티어·미지-리터럴 비면제. frontmatter opus 가 보장하는 것은 **opus-상수 절반뿐**(작업자 절반은 L1 — §16.4-1). 하한: 검증자 < 작업자 금지."
- :22 하향 규칙 뒤 신규 문: "**fable 서브에이전트 위임 기본 금지**(U4). 예외 = 밸브 V1(사용자 요청)/V2(판정충돌 tie-break ≤1회)/V3(goal 명시 실험) + `FABLE-ESCALATION(사유)` 선언 + 검증자 동반 상향(spec §16.5). hook 은 명시 fable/inherit 를 전·조건 세션에서 환기(Rule A/B/C/C2-leak — 밸브-정당 호출에도 발화, advisory 오탐 수용)."
- §2 모드 (C): "execute/review-strict 는 frontmatter opus 고정(전 세션 — sonnet 세션에선 상향이며 항상 허용). explore-strict sonnet 불변."
- §3 L2 서술(:35): Rule A/B v2(fable-누출 전 세션·opus-floor·구 하향 arm 제거·신 슬러그)·Rule C(무선언 침묵·fable-리터럴 전 세션)·C2(폴백 opus 상수·C2-leak) 재서술 + spec §16 포인터.
- **:36 L3 서술**(델타 재심 unknowns-1 — B3/B4/B5 동일 클래스): "execute/review `model: inherit` 유지+review effort 키 부재" → "execute/review `model: opus`(C17 Option 1 물리 기본값)+review effort 키 부재" (seal #5/#45 서술 동기).

- [x] **Step 2: cross-family-review.md §3 — 두 곳(§16.8 E1)**

첫 단락 재서술: "검증자(review-strict)의 기준선은 임무-분리 v2 다(C17, spec §16) — 준수-확인(Workflow·Rule C2) = 작업자 티어(실행자-전무 폴백=opus 상수) / 판단-게이트(Agent 경로·Rule B) = `max(작업자 티어, opus)` — 세션 축은 U4 공리로 제거(C13 `max(세션,작업자)`→C16 임무-분리→C17 재-supersede). 하한: 어떤 임무에서도 검증자 < 작업자 금지. frontmatter `model: opus`(C17 Option 1)가 무지정 위임에서 floor 의 opus-상수 절반을 물리 보장한다(작업자 절반은 L1 — 실행자를 opus 위로 상향(밸브 fable 작업자)했다면 검증자도 동반 상향). 기준선 미만 하향은 DOWNGRADE-DECLARED 필수. 오케스트레이터의 동적 모델 선택은 여전히 불채택 — 기준이 **정적 opus 상수**로 바뀌었을 뿐, 가장 신뢰하지 않는 계층에 검증자 선택 재량을 주지 않는 논거는 그대로다."
:67 내부 적대 패스 단락: "티어=세션 상속(판단-게이트 floor)" → "티어=opus(판단-게이트 floor `max(작업자,opus)` — C17; frontmatter opus 가 무지정을 커버)".

- [x] **Step 3: CONTEXT.md·README·scaffold-registry·verify-loop-watch**

- CONTEXT.md :85 「실행자 하향 위임」: "(임무-분리 — C16)" → "(임무-분리 v2 — C17, 세션 축 제거)". :89 「역할×모델 매트릭스」: "(임무별 floor — C16)" → "(임무-분리 v2 `max(작업자,opus)` — C17)".
- README(perl -pi, CRLF): :39 hook 행 Rule 설명 v2 재서술. :56 검증 행 "**상속** — 기준선(…max(세션 티어, 작업자 티어)…)" → "**opus** (frontmatter 기본) — 기준선(임무-분리 v2, spec §16: 준수-확인=작업자 티어/판단-게이트=max(작업자,opus) — 세션 축 제거) 미만 금지". :59 인접 구 산식 동기. **:69·:185·:234 의 2-리뷰 토폴로지**(§16.8 B3): "senior review" 단독 서술 → "통합 리뷰(senior+drift 합본 — C17)", ":185 이후 review-strict drift 검사" 문장 → "drift 는 통합 리뷰가 겸함(C-0 미충족/Phase 4 미수행 시 단독 drift 폴백)".
- scaffold-registry: :24 hook 행 "(임무-분리 floor, §15.1)" → "(임무-분리 v2, §16)" + 진화 열 "C17 v2". :32 Closeout 요약 "PR→CI→senior review→승인→merge" → "PR→CI→통합 리뷰(senior+drift)→승인→merge"(B3). :48 carrier 행 불변. :83 #45 행 "execute/review inherit" → "execute/review opus(C17)".
- verify-loop-watch.sh :38(§16.8 B4): "closeout(review-strict drift + state.json 갱신)" → "closeout(통합 리뷰[senior+drift] + state.json 갱신)".

- [x] **Step 4: spec 포인터·정오 append**

- §3 :105·:108 기존 ⚠ 문구에 "→ §16(C17)이 재-supersede(판단-게이트 max(작업자,opus) — 세션 축 제거)" 추가.
- §12.1 헤더 blockquote 에 "§16(C17)이 판단-게이트 절반을 재-supersede — max(세션,작업자) → max(작업자,opus)" 1줄. §12.1 말미 C16 재실측 blockquote 에 "※C17 정밀화(§16.7-1): 위 인용 `:56` 은 'stage2 model 명시 라인' — C16 이 stage2 를 opus 명시로 바꾼 뒤라 '무지정' 서술은 그 시점에 이미 실물과 어긋났다" 1줄.
- §15.1 서두에 "> ⚠§16(C17)이 판단-게이트 절반을 재-supersede — 준수-확인(작업자 티어)은 존속, 폴백만 세션→opus 상수." 1줄.
- §15.2 표 인접에 "※ 정오(C17 §16.7-3): PR#37 body 의 'X1~X13' 라벨은 오기 — GT 는 X1~X15." 1줄.

- [x] **Step 5: review-yield.md C16 정정 행 append**

C16 절 말미에:
```markdown
- (정정 — C17 §16.7-4, 원행 보존): 위 stage2 행 `×8`·`5 PASS/3 FAIL` 은 오기 — 실측 `×9`(1차 7 + 델타 재심 2)·`7 PASS/2 FAIL`(재심 2 PASS 산입).
```

- [x] **Step 6: 검증 + 커밋**

Run: `grep -rn "max(세션" --include="*.md" "$HOME/.claude/docs/ai-context/" "$HOME/.claude/CONTEXT.md" "$HOME/.claude/README.md" | grep -v "supersede\|구 \|이력\|genesis\|C13\|C16" || true` → 잔존 각 행이 이력 문맥임을 개별 확인.
Run: `bash setup/verify-setup.sh 2>&1 | tail -2` → `PASS=87 FAIL=0`.

```bash
git add docs/ai-context/model-policy.md docs/ai-context/cross-family-review.md CONTEXT.md README.md docs/ai-context/scaffold-registry.md hooks/verify-loop-watch.sh docs/superpowers/specs/2026-07-25-model-policy-design.md docs/ai-context/review-yield.md
git commit -m "docs(c17): L1 매트릭스 v2 전파 — 세션 축 제거·frontmatter opus·2-리뷰 토폴로지 서술 동기·수율 대장 정정 (spec §16.6/§16.7/§16.8 B3/B4/E1)"
```

### Task 4: skill 2종 + opencode 미러 — 리뷰 통합 규약 (light, 병합)

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md` · `skills/closeout-pr-cycle/SKILL.md`
- Modify: `opencode-harness/skill/start-rpi-cycle/SKILL.md` · `opencode-harness/skill/closeout-pr-cycle/SKILL.md`

**Interfaces:**
- Consumes: spec §16.3(보강판 — D1 diff 판별자·D2 미수행 술어·D3 입력·D4 5 Whys·D5 말미 창·E2 층 분류·E3 최소 Important)·§16.1 매트릭스.
- Produces: seal #17/#18/#19/#22/#49 토큰 불변 — verify-setup 이 증인.

- [x] **Step 1: start-rpi-cycle SKILL.md**

(a) **Gate R 절 서두**: "★Gate R 조건부(C17 spec §16.3-1): **spec delta 없는 재진입 사이클**만 서브에이전트 게이트를 생략하고 메인 자기점검 1줄로 대체 — 단 생략 선언은 자기증언이 아니라 **기계 판별**: `git diff <직전 사이클 머지 커밋>..HEAD -- docs/superpowers/specs/` 의 **0-diff 출력을 증거로 동반**해야 하며, diff 가 비어 있지 않으면 no-op 선언 무효(Gate R 필수). **delta 사이클(신설 포함)은 Gate R 필수.** 잔여: 미반영-delta(spec 에 넣었어야 할 것을 안 넣음)는 diff 로 못 잡는다 — 기존 Gate R 과 동일 상한, 수용(§16.3-1)."
(b) Gate R/P Agent 호출 인접에 각 1줄: "※ 게이트 review-strict 는 판단-게이트 — frontmatter opus 기본(무지정=opus, C17 Option 1)이라 model 인자 없이도 기준선(`max(작업자,opus)`) 충족. 상향 명시 허용."
(c) :156 (a)/(c) 규약 문단 교체: "fable 세션의 execute-strict 위임은 (a)/(c) 어느 경로든 frontmatter opus 기본(C17 Option 1 — `model:'opus'` 명시는 선택 보강). 검증자(review-strict) Agent 경로(판단-게이트) 기준선 = `max(작업자, opus)`(spec §16 — 세션 축 제거·U4). 실행자를 opus 위로 상향(밸브 fable 작업자)했으면 검증자도 동반 상향(L1). **fable 서브에이전트 위임 기본 금지** — 밸브 V1/V2/V3 + `FABLE-ESCALATION(사유)` 선언만 예외(spec §16.5). Workflow 준수-확인 경로는 작업자 티어(§15.1·§16 폴백 opus)."
(d) (d) 절 "spec §15.1" 인용 2곳 → "spec §15.1·§16".
(e) Phase P 절에 light-병합 규약: "※ light-병합(C17 spec §16.3-3): 인접 light task(순수 문서·기계 편집)는 plan 단계에서 하나의 task 로 병합(files 합집합·successCriteria conjunct). 합본 stage1 보고 30k 초과 예상 시 분할 유지(slice 절단=후미 diff 소실=false PASS). heavy(코드/TDD)는 per-task 유지."
(f) Step C-1 sub-step 1 교체: "1. **통합 리뷰 소비(포인터 — C17 spec §16.3-2)**: drift 검사는 closeout-pr-cycle Phase 4 의 **단일 opus 적대 통합 리뷰**(senior A~E + drift 체크리스트 합본)가 겸한다 — 이 sub-step 은 그 결과(Critical/Important/Minor + **drift 항목별 판정 절**)를 소비·기록한다. **폴백(사유 불문): Closeout 이 이 지점에 도달했을 때 Phase 4 통합 리뷰가 수행되지 않았으면**(C-0 미충족·local check FAIL·PR/CI 실패·PARTIAL·abandoned 등 원인 무관 — §16.8 D2) **아래 단독 drift 검사를 실행**(리뷰 0회 사이클 방지)." — 기존 Agent 호출 블록은 "폴백 전용"으로 라벨 유지(success_criteria 의 5 Whys 기준 포함 원문 보존).
(g) sub-step 3: "audit.last_drift_check: today (**단, Phase 4 통합 리뷰(drift 체크리스트 포함 — drift 절 판정이 전항 명시된 보고, §16.8 E3) 또는 폴백 단독 drift 검사가 실제 수행된 경우에만** — abandoned/미수행 사이클은 미갱신 …)".
(h) sub-step 9: 층 분류 "층 = Gate R/P·stage2·senior·drift·교차패밀리·기타 실행분" → "층 = Gate R/P·stage2·**통합(senior+drift — 폴백 시 drift 단독)**·교차패밀리·기타 실행분"(§16.8 E2 — 통합 리뷰는 1층 1행, 2행 분리 기재 금지). 말미에 "하네스 사이클은 **모델별 산출 토큰 분포**(세션 `subagents/*.jsonl` usage 합산 + 헤드리스 probe 별도 병기)를 함께 보고(C17-D-2). fable 위임 토큰은 밸브 선언분 외 0 실측 병기." 추가.

- [x] **Step 2: closeout-pr-cycle SKILL.md Phase 4 통합**

frontmatter description "merge 전 senior review" → "merge 전 통합 리뷰(senior+drift)"(§16.8 B3) + 본문 요약 문장 동기. Phase 4 헤더 → "Phase 4 — 통합 리뷰 (senior + drift 합본, C17 spec §16.3-2)". Agent 호출 context_paths 에 추가(§16.8 D3): `"CONTEXT.md"`, `"docs/superpowers/plans/<active plan>"`, `"docs/ai-context/non-obvious.md"`(실재하는 것만 규약 불변). success_criteria 에 A~E 뒤 추가:
```
        F drift 체크리스트 (start-rpi-cycle Step C-1 합본 — 이 리뷰가 그 sub-step 1 을 겸한다.
          ★F 항목의 미충족은 최소 Important 로 분류하고, 보고에 "drift 절"을 분리해 항목별 판정을
          전항 명시할 것 — 분류 강등으로 PASS 를 얻는 우회 차단(§16.8 E3)):
        - CONTEXT.md 갱신(신규 용어) 또는 변경 없음 확인
        - plan 모든 체크박스 [x] 또는 명시적 미완료 사유 기록
        - 사이클 중 발생한 실패가 5 Whys 통과 후 non-obvious.md 누적 (또는 명시 면제) — §16.8 D4
        - 사이클 자산(architecture/glossary — 실재하는 것만) 갱신 또는 변경 없음 확인
        - silent-downgrade 검출: spec/plan 선언 설계 vs 구현 실물 대조 — 미신고 열화 발견 시 FAIL
          (plan 의 DOWNGRADE-DECLARED 범위는 선언된 결정)
```
호출 인접에: "※ 판단-게이트 — frontmatter opus 기본(C17). 이 통합 리뷰 수행이 `audit.last_drift_check` 스탬프의 근거(start-rpi-cycle sub-step 3). **통합 리뷰 이후 브랜치 말미 커밋은 plan 최종 task 가 사전 명시한 선언적 기계 편집(CLAUDE.md §3·layer-yield append)에 한정** — 그 외 변경은 통합 리뷰 재실행 대상(§16.3-2 D5). layer-yield 대장에는 `통합(senior+drift)` 1층 1행으로 기재(§16.8 E2); auto-merge 사이클은 통합 리뷰 완료 직후·merge 명령 이전에 append(§16.3-4 E4)."

- [x] **Step 3: opencode 미러 2파일 동기**

model 축 문구 제외(§16.6 no-op — 미러에 frontmatter model 키 부재), **절차 변경만**: Gate R 조건부+diff 판별자(a)·sub-step 1 포인터+미수행-술어 폴백(f)·sub-step 3 재바인딩(g)·sub-step 9 층 분류(h)·Phase 4 합본(Step 2 동형)·light-병합(e). 절 헤더로 위치 특정해 의미-동형 편집.

- [x] **Step 4: 검증 + 커밋**

Run: `bash setup/verify-setup.sh 2>&1 | tail -2` → `PASS=87 FAIL=0` (#17·#18·#19·#22·#49 green).
Run: `grep -c "통합 리뷰" skills/start-rpi-cycle/SKILL.md skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md` → 4파일 전부 ≥1.

```bash
git add skills/start-rpi-cycle/SKILL.md skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
git commit -m "feat(c17): 리뷰 통합 — Gate R diff-판별자·Phase 4 통합 리뷰(D2~D4/E2/E3)·light-병합 + 미러 동기 (spec §16.3·§16.8)"
```

### Task 5: CLAUDE.md §3 + opencode AGENTS.md :25 (메인 직접 — 세션 종료 직전, §16.3-2 D5 창 한정 편집)

**Files:**
- Modify: `CLAUDE.md` §3 1줄 · `opencode-harness/AGENTS.md` :25 동형 1줄(§16.8 B5)

메인이 Closeout 말미(layer-yield 대장 append 커밋 직전)에 직접 수행 — §1 캐시 제약의 유일 허용 시점이자 §16.3-2 D5 가 한정한 "선언적 기계 편집" 2건. 편집: 양쪽의 "Closeout: review-strict drift 검사 + 자산 갱신" → "Closeout: 통합 리뷰(senior+drift 합본 — Phase 4 미수행 시 단독 drift 폴백) + 자산 갱신". seal #17 은 Phase R 도구만 검사 — 영향 없음.

- [x] 편집 + verify-setup 87/0 재확인 + layer-yield append 와 함께 최종 커밋

---

## Self-Review (rev2)

1. **Spec coverage**: §16.1=T1·§16.2(+§16.8 A/B/C 정정)=T2·§16.3(+D/E 정정)=T4·§16.4=T3(문구 F2-안전)·§16.5=T3 Step1·§16.6 전수(B3/B4/B5 포함)=T3/T4/T5·§16.7=T2 Step3(c 주석)·T3 Step4~5·§16.8=이 rev2 자체. 갭 0.
2. **Placeholder scan**: 0. T1 Step 3 의 "M9/M10 동형" 은 의도 명세+패턴 참조 동반.
3. **Type consistency**: 슬러그 5종·OPUS_FLOOR·픽스처명 T2 내부와 spec §16.2/§16.8 정합. RED 19 = 반전 4(01/09/16/27)+트리거-교체 중 구-거동 상이 1(49)+신설 중 구-거동 상이 14(52~55/58~67) — 50/51/56/57 + 08/11/19/20/21/30/35 는 구 코드 PASS.
