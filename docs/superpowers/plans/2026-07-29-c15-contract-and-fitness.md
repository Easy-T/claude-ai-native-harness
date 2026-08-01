# C15 — 파서 계약 3값 확장 · builtin 실측 반영 · 재개 주입 · fitness Implementation Plan

**Status:** completed
**RPI-Cycle:** 66
**Started:** 2026-07-29

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** model 축 출력 계약을 3값(리터럴/`-`/`*`)으로 확장해 Rule C/C2/C3의 동적-model 오탐을 제거하고, C15-E 재개 주입 1줄을 착륙시키며, 소비자 전부(계약 서술·픽스처)를 동반 갱신한다.

**Architecture:** 계약 방출은 `workflow-spawns.js` 방출부 1곳(`parseProps`가 이미 undefined/null을 구분해 옴 — 파서 내부 무변경). hook은 Rule C/C2에 `'*'` arm 신설 + C3 메시지 hedge. 재개는 `session-start-audit.sh`의 기존 active-plan 블록에서 stdout 1줄(라이브 실증된 SessionStart stdout→컨텍스트 채널). 설계 근거 SSOT = durable spec §14 (Gate R PASS 완료).

**Tech Stack:** node(파서)·bash(hook·픽스처)·run-all.sh 픽스처 체계(test_lib/test_smp/test_ssa)

## Global Constraints

- **goal §5 준수**: settings.json git add 금지·값 출력 금지 / seal·드리프트 검사는 bash 파일옵스만 / verify-setup·run-all·seal-regression은 메인 세션 포그라운드만 / wrapper agent 호출에 schema 금지 / 글로벌 CLAUDE.md 루트 수정 없음(이번 사이클 대상 아님)
- 커밋은 각 task 종료 시 메인이 수행(Workflow 경로 사용 시 스크립트는 커밋 금지 — 메인이 그룹 커밋)
- 기존 244 케이스 무회귀. 신규 케이스는 cases.tsv에도 등재(#21 count-seal이 README 카운트와 정합 강제 — README 갱신 동반)
- 계약 기호: model 축 = 리터럴 / `-`(키 부재) / `*`(키 존재·동적) — spec §14.1 확정

**Best-Direction Check:** 최선안 = model 축을 agentType 축과 동형의 3값으로 확장하고 동적 선언을 Rule C/C2/C3 전부에서 "판정 불가" 면제(안전 인증 아님을 문서화), 재개는 신설 마커 없이 기존 active-plan 자산 + 라이브 실증된 stdout 채널 재사용 / 채택안 = 동일. **DOWNGRADE-DECLARED: 없음**. (AST 파서 전환은 종전 사이클에서 기각된 대안 유지 — spec §12.3 Best-Direction 선례, 이번 변경은 방출부 기호 확장이라 그 판정에 영향 없음.)

---

### Task 1: 파서 방출부 3값 확장 + 단위 픽스처

**Files:**
- Modify: `hooks/lib/workflow-spawns.js` (방출부 :172 + 헤더 계약 서술 :6·:24-25)
- Test: `hooks/tests/run-all.sh` (픽스처 186 기대값 변경 + 신규 204·205 + 계약 주석 :664), `hooks/tests/cases.tsv`

**Interfaces:**
- Produces: stdout TSV 계약 — model 축 3값. Task 2(hook)가 `*`를 소비.

- [x] **Step 1: RED — 신규 픽스처 2개 + 186 기대값 변경을 먼저 적용**

`hooks/tests/run-all.sh`의 `test_lib "186-ws-dynamic-model"` 기대값을 `-`→`*`로 바꾸고, 그 아래 신규 2건 추가:

```bash
# C15: model 축 3값 — 동적 선언(키 존재·비-리터럴)은 '-'(키 부재)와 구분해 '*' 로 방출 (spec §14.1)
test_lib "204-ws-dynamic-model-call" "$(printf 'execute-strict\t*')" \
  "$(printf "%s" "agent('p', {agentType:'execute-strict', model: chooseModel()})" | node "$WS")"
test_lib "205-ws-dynamic-model-vs-absent" "$(printf 'general-purpose\t*\ngeneral-purpose\t-')" \
  "$(printf "agent('a', {agentType:'general-purpose', model: M})\nagent('b', {agentType:'general-purpose'})" | node "$WS")"
```

※ Gate P F1 정정: 205 입력은 **포맷 문자열 직접 사용**(173 선례) — `%s` 경유는 `\n`이 리터럴 2문자로 남아 두 번째 `agent(`가 lookbehind에 걸려 1행만 방출된다(실측).

```bash
```

186은 기대값만 변경: `"$(printf 'execute-strict\t-')"` → `"$(printf 'execute-strict\t*')"` (주석도 "동적은 `*`"로).

- [x] **Step 2: RED 확인**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -6`
Expected: FAIL 3건 (186·204·205 — got `-` vs exp `*`) + cases.tsv 정합 오류(신규 2건 미등재). 실패 출력을 보고에 원문 인용.

- [x] **Step 3: GREEN — 방출부 1곳 + 헤더 계약 서술 갱신**

`hooks/lib/workflow-spawns.js` `scan()` 방출부(:172 부근):

```js
      out.push({
        agentType: at === undefined ? "?" : at === null ? "*" : at,
        model: mo === undefined ? "-" : mo === null ? "*" : mo,
      });
```

헤더 :6 계약 줄을 다음으로 교체(3값 명시):

```
//   model:     리터럴 값 / 키 부재='-' / 키는 있으나 비-리터럴='*'  (C15 3값 — 동적 선언을 "무선언"과
//              구분한다. 종전 2값은 Rule C3 가 model:f() 를 "선언하지 않음"이라 오탐하는 원인이었다)
```

한계 절 :24-25의 `agentType='*' / model='-' 로 보고된다`를 `agentType='*' / model='*' 로 보고된다(동적 표기 — C15)`로 갱신.
cases.tsv에 `hooks-lib	204-ws-dynamic-model-call	0	test_lib`·`hooks-lib	205-ws-dynamic-model-vs-absent	0	test_lib` 추가.
run-all.sh :664 계약 주석을 `model: 리터럴 / 키 부재 = '-' / 키 존재·동적 = '*'  (C15 3값 계약)`으로.

- [x] **Step 4: GREEN 확인 (hook E2E는 Task 2에서 — 이 시점 smp 픽스처는 기존 그대로 통과해야 함: C3는 `-`/`inherit`만 매치라 `*` 무영향)**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -4`
Expected: `246 / 246 passed` (244+2), cases.tsv 정합 OK. 통과 출력 원문 인용.

- [x] **Step 5: README 카운트 갱신 + 커밋**

README.md의 cases.tsv 카운트 2곳(`:292` `244 case`·`:530` `244 케이스`)을 246으로 (seal #20/#21).

```bash
git add hooks/lib/workflow-spawns.js hooks/tests/run-all.sh hooks/tests/cases.tsv README.md
git commit -m "feat(c15): workflow-spawns model 축 3값 계약 — 동적 선언 '*' 를 키 부재 '-' 와 분리 (spec §14.1)"
```

### Task 2: hook Rule C/C2 `'*'` arm + C3 메시지 hedge + E2E 픽스처

**Files:**
- Modify: `hooks/surface-model-policy.sh` (Rule C case :68-71 · Rule C2 case :98-101 · C3 메시지 :126)
- Test: `hooks/tests/run-all.sh` (신규 smp 37·38·39), `hooks/tests/cases.tsv`, `README.md` (카운트)

**Interfaces:**
- Consumes: Task 1의 `*` 방출.
- Produces: Rule C/C2가 `*`를 면제(ALERT 없음), C3는 코드 무변경 자동 면제, C3 메시지에 builtin hedge.

- [x] **Step 1: RED — E2E 픽스처 3건 먼저**

run-all.sh의 test_smp 36 아래에 추가:

```bash
# C15 (37): 동적 model 선언(execute-strict) — 선언은 존재·값만 런타임 → Rule C 면제 (spec §14.1 매트릭스)
WF_DYN_MODEL="export const meta = {name: 'x', description: 'x'}
await agent('impl', {agentType: 'execute-strict', model: pickModel()})"
test_smp "37-rule-c-dynamic-model-exempt" 0 0 "$(mk_wf_event script "$WF_DYN_MODEL" "$SMP_FABLE_T" "smp37-$$")"
# C15 (38): 동적 model 검증자 — floor 미달 단언 불가 → Rule C2 면제 (tier 0 오평가 방지, spec §14.1)
WF_DYN_REVIEW="export const meta = {name: 'x', description: 'x'}
await agent('impl', {agentType: 'execute-strict', model: 'opus'})
await agent('verify', {agentType: 'review-strict', model: chooseVerifier()})"
test_smp "38-rule-c2-dynamic-model-exempt" 0 0 "$(mk_wf_event script "$WF_DYN_REVIEW" "$SMP_SONNET_T" "smp38-$$")"
# C15 (39): 동적 model fan-out — "무선언"이 아니므로 Rule C3 면제 (파서가 '*' 로 방출, C3 는 '-'/'inherit' 만 매치)
WF_DYN_FANOUT="export const meta = {name: 'x', description: 'x'}
await agent('research', {agentType: 'general-purpose', model: modelFor(i)})"
test_smp "39-rule-c3-dynamic-model-exempt" 0 0 "$(mk_wf_event script "$WF_DYN_FANOUT" "$SMP_FABLE_T" "smp39-$$")"
```

- [x] **Step 2: RED 확인**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -6`
Expected: 37 FAIL(현행 Rule C가 `*`를 default arm에서 `SP_T=0≠4`로… **주의**: 37은 현행 코드에서도 `case`의 `-|inherit` 미매치+`SP_T=0`이라 우연 통과할 수 있다 — 그 경우 37은 "이미 GREEN"으로 기록하고 회귀 앵커로 유지). 38 FAIL 확정(sonnet 세션 + opus 실행자 + 동적 검증자 → 현행은 `*`가 case 미매치로 `tier_of("*")=0 < 3` → C2_HIT — 오탐 재현). 39는 Task 1 착륙 후 자동 GREEN 예상(파서가 `*` 방출 → C3 `-`/`inherit` 미매치). 각각의 실제 RED/GREEN 상태를 관측 그대로 보고에 인용 — 예상과 다르면 그 자체가 발견.

- [x] **Step 3: GREEN — hook 정정**

Rule C case(:68-71)에 `'*'` 면제 arm:

```bash
        case "$SP_MODEL" in
          -|inherit) C_HIT=1 ;;
          '*') ;;   # C15: 동적 선언 — 하향 미적용을 단언 불가(agentType '*' 면제와 동일 원리, spec §14.1)
          *) [ "$SP_T" = "4" ] && C_HIT=1 ;;
        esac
```

Rule C2 case(:98-101)에 `'*'` skip:

```bash
    case "$SP_MODEL" in
      '*')       continue ;;   # C15: 동적 선언 — floor 미달 단언 불가(tier 0 오평가 방지, spec §14.1)
      -|inherit) SP_T="$WF_TIER"; SP_LABEL="상속(세션=$WF_SESSION_MODEL)" ;;
      *)         SP_T=$(tier_of "$SP_MODEL"); SP_LABEL="$SP_MODEL" ;;
    esac
```

C3 메시지(:126)의 `역류합니다` 문장 뒤에 hedge 추가: `(일부 builtin 은 CC 자체 바인딩으로 하위 티어에 돌 수 있음 — spec §14.2 실측; Explore·claude-code-guide)`.
WORKER_TIER 산정(:64)은 무변경 — `tier_of("*")=0`으로 현행과 동일(spec §14.1 매트릭스 4행).

- [x] **Step 4: GREEN 확인 + 무회귀**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -4`
Expected: `249 / 249 passed` (246+3). 특히 기존 14(rule-c2-review-downshift)·26·27·28(inherit/tier0 floor 케이스) 무회귀 확인 — `'*'` arm이 리터럴 경로를 건드리지 않음의 증거.

- [x] **Step 5: cases.tsv 3건 + README 카운트(249) + 커밋**

cases.tsv: `surface-model-policy	37-rule-c-dynamic-model-exempt	0	mk_wf_event` 외 2건. README 2곳 249로.

```bash
git add hooks/surface-model-policy.sh hooks/tests/run-all.sh hooks/tests/cases.tsv README.md
git commit -m "feat(c15): Rule C/C2 동적-model '*' 면제 + C3 builtin hedge — 오탐 제거 (spec §14.1/§14.2)"
```

### Task 3: 계약 서술 SSOT 동반 갱신 (model-policy.md)

**Files:**
- Modify: `docs/ai-context/model-policy.md` (:35 L2 절의 계약 서술)

**Interfaces:**
- Consumes: Task 1·2 확정 계약.

- [x] **Step 1: :35의 계약 문장 교체**

`출력 계약은 스폰당 <agentType>\t<model> — model은 리터럴 또는 -(부재·동적), agentType은 리터럴 / ?(키 부재) / *(키 존재·동적)의 **3값**` 부분을:

```
출력 계약은 스폰당 `<agentType>\t<model>` — **두 축 모두 3값**(C15): 리터럴 / `-`(키 부재) / `*`(키 존재·동적). 동적 선언(`model: f()`)은 "무선언"이 아니므로 Rule C/C2/C3 전부 면제된다 — 면제는 안전 인증이 아니라 판정 불가의 정직 표기(L1 규범은 여전히 적용). 동적 조립(`MODELS[i]`)은 `*` 로 보고되며, agentType `*` 는 상속을 단언할 수 없어 Rule C3 대상이 아니다.
```

로 교체(주변 문장 보존). "동적 조립… 안전 방향으로 보고되며" 구절은 위 문장으로 흡수되므로 중복 제거.

- [x] **Step 2: 검증 — 문서 self-consistency grep**

Run: `grep -n '부재·동적' docs/ai-context/model-policy.md hooks/lib/workflow-spawns.js hooks/tests/run-all.sh`
Expected: 0건 (2값 시대 표현 소멸). `grep -rn "모델[- ]무선언" docs/ai-context/model-policy.md` 결과에 동적 포함 함의 없음 확인.

- [x] **Step 3: 커밋**

```bash
git add docs/ai-context/model-policy.md
git commit -m "docs(c15): model-policy L2 계약 서술 3값 동기화"
```

### Task 4: C15-E 재개 주입 — session-start-audit stdout `[resume]` 1줄 + 픽스처

**Files:**
- Modify: `hooks/session-start-audit.sh` (active-plan 블록 :38-53)
- Test: `hooks/tests/run-all.sh` (신규 ssa 픽스처 2건), `hooks/tests/cases.tsv`, `README.md` (카운트 251)

**Interfaces:**
- Consumes: 기존 `plan_status`(_common.sh)·active plan 자산 (신설 마커 없음 — spec §14.3 판정).
- Produces: SessionStart stdout 1줄 `[resume] active plan: <파일명> (미체크 N) — 이전 세션 중단 작업일 수 있음. plan 을 열어 재개 여부를 판단하십시오.`

- [x] **Step 1: RED — ssa stdout 픽스처 2건**

run-all.sh의 test_ssa 계열 아래 추가 (기존 test_ssa는 exit code만 봄 — stdout 단언 헬퍼 신규):

```bash
# C15-E (spec §14.3): active plan 존재 시 stdout [resume] 1줄 (SessionStart stdout→컨텍스트 채널), 부재 시 무출력
test_ssa_resume() {
  local name="$1"; local expect_resume="$2"; local plan_body="$3"
  TOTAL=$((TOTAL+1))
  local D="$SCRATCH/ssa-resume-$name"; mkdir -p "$D/docs/superpowers/plans"
  [ -n "$plan_body" ] && printf '%s\n' "$plan_body" > "$D/docs/superpowers/plans/p.md"
  local out; out=$(printf '{"cwd":"%s","session_id":"ssa-res-%s"}' "$D" "$$" | bash "$HOOKS/session-start-audit.sh" 2>/dev/null)
  local got=0; printf '%s' "$out" | grep -q '^\[resume\]' && got=1
  [ "$got" = "$expect_resume" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$name (resume-line got=$got exp=$expect_resume)")
}
```

※ Gate P F2 정정: **HOME override 금지** — `session-start-audit.sh:2`가 `$HOME/.claude/hooks/_common.sh`를 source하므로 override 시 `resolve_cwd` 미정의 → `CWD=""` → plan 블록 미진입(픽스처 구조적 GREEN 불가, 실측). stdin cwd 전달 + 실 HOME은 기존 `test_ssa_mark`(:156-158) 선례와 동형이며, 실 HOME의 audit/메모리/plugin 블록은 전부 stderr라 stdout 단언을 오염하지 않는다.

```bash
test_ssa_resume "08-resume-active-plan" 1 $'**Status:** active\n- [ ] Task 1\n- [x] Task 0'
test_ssa_resume "09-resume-no-active" 0 $'**Status:** completed\n- [x] Task 1'
```

- [x] **Step 2: RED 확인**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -6`
Expected: 08 FAIL (현행은 stderr만 — stdout에 `[resume]` 없음), 09 PASS(무출력이 기대라 vacuous 아님 — 08이 발화 축, 09는 오탐 방지 축). RED 출력 인용.

- [x] **Step 3: GREEN — active-plan 블록에 stdout 1줄**

`session-start-audit.sh`의 `elif (( ACT_N == 1 )); then` 분기와 `ACT_N > 1` 분기 각각에서, 기존 stderr 줄은 유지하고 다음 추가 (ACT_N ≥ 1 공통 — stderr 블록 뒤에):

```bash
  # C15-E (spec §14.3): 재개 신호를 모델 컨텍스트에 주입 — SessionStart stdout 은 컨텍스트로 전달된다
  # (superpowers SessionStart 블록으로 라이브 실증). stderr [plan] 줄은 사용자용 — 이중 채널, 목적이 다름.
  if (( ACT_N >= 1 )); then
    FIRST_PLAN=$(printf '%s' "$ACT_NAMES" | awk '{print $1}')
    UNCHECKED=0
    for p in "$CWD/docs/superpowers/plans"/*.md; do
      [ -f "$p" ] || continue
      case "$(plan_status "$p")" in active|in_progress) UNCHECKED=$((UNCHECKED + $(grep -c '^\- \[ \]' "$p" 2>/dev/null || true))) ;; esac
    done
    echo "[resume] active plan: $FIRST_PLAN (미체크 $UNCHECKED) — 이전 세션 중단 작업일 수 있음. plan 을 열어 재개 여부를 판단하십시오. (advisory — 자동 재실행 아님)"
  fi
```

주의: `grep -c`는 매치 0이면 exit 1 — `|| true`로 set-e 안전(이 파일은 set -e 아님이나 _common.sh 상속 방어 — cycle-39 `||`형 교훈). 산술 `$((… + $(…)))`에서 빈 문자열 방지를 위해 `${VAR:-0}` 불필요(grep -c는 항상 숫자 출력, 단 `|| true` 시 빈 값 가능하므로 `UNCHECKED=$((UNCHECKED + ${N:-0}))` 형태로 변수 경유):

```bash
      N=$(grep -c '^\- \[ \]' "$p" 2>/dev/null || true)
      UNCHECKED=$((UNCHECKED + ${N:-0}))
```

- [x] **Step 4: GREEN 확인 + 무회귀 (기존 ssa 01-07 케이스 그대로)**

Run: `bash hooks/tests/run-all.sh 2>&1 | tail -4`
Expected: `251 / 251 passed`.

- [x] **Step 5: cases.tsv 2건 + README 카운트(251) + 커밋**

```bash
git add hooks/session-start-audit.sh hooks/tests/run-all.sh hooks/tests/cases.tsv README.md
git commit -m "feat(c15): 재개 주입 — active plan 시 SessionStart stdout [resume] 1줄 (spec §14.3, 신설 마커 없음)"
```

### Task 5: improve-codebase-architecture 실행 (C15-D — cycle%5 규약)

**Files:**
- 실행만 (skill 호출 + 후보 보고 산출). 삭제/리팩토링 실행 없음 — 후보 식별까지.

**Interfaces:**
- Consumes: scaffold-registry.md·CONTEXT.md·durable spec(하네스 대체 입력 — skill Preflight 조건부).
- Produces: 프루닝 후보 `[P<n>]` + 메모리 감사 후보 목록 → Closeout 보고에 diff 형태 제시, 사용자 승인 대기 항목.

- [x] **Step 1: Skill 도구로 `improve-codebase-architecture` 호출** (메인 세션 — phase-skills invoked 선언 대상)
- [x] **Step 2: Phase 1 탐색은 explore-strict 위임(skill 절차), Phase 2 후보 목록(스캐폴드 프루닝 + 메모리 수명주기 포함) 산출**
- [x] **Step 3: 후보 보고를 Closeout 보고에 포함. Phase 3(실행)은 사용자 승인 후 별도 사이클 — 이번엔 미실행. Phase 4(README)는 하네스 README가 이미 존재·현행이므로 "갱신 불필요" 판정 기록(신규 생성 아님)**

### Task 6: fitness 대차 + 전 스위트 + GPT 교차리뷰 (Closeout 전 마감 검증)

**Files:**
- Modify: `docs/superpowers/specs/2026-07-25-model-policy-design.md` (§14.4에 fitness 최종 대차 기록)

- [x] **Step 1: runlog 대차 — 오프셋 6881 이후 `surface-model-policy` ALERT 전수 추출 + 규칙별 발화/무발화 표 작성 (goal §3-C 요구 3항: advisory가 행동을 바꿨는지 정직 기록 · 요구 4항: canonical carrier 사용 여부 명시 — 미탐·오탐 판정 포함)**
- [x] **Step 2: 전 스위트 포그라운드 — `bash setup/verify-setup.sh`(기대 86/0 — seal 신설 없음) · `bash hooks/tests/run-all.sh`(기대 251/251) · `bash setup/tests/seal-regression.test.sh`(기대 15/0)** ※ seal-regression 600s 초과 자동 백그라운드 강등은 허용(완주 확인)
- [x] **Step 3: GPT 교차리뷰 1회 — cross-family-review.md §2 규약(sol·ultra·verbosity high·read-only·fast 금지). 대상: 이번 사이클 diff + spec §14. `${…}` 리터럴은 파일 경유. 발견은 트리아지 후 REAL만 정정 편입**
- [x] **Step 4: §14.4 대차 기록 커밋**

```bash
git add docs/superpowers/specs/2026-07-25-model-policy-design.md
git commit -m "docs(c15): §14.4 fitness 대차 — fable+ultracode 라이브 관측 기록"
```

- [x] **Step 5: ★goal §4 메타 대조 (goal §4-8, C14 교훈 #2)** — Closeout 보고 작성 시 `_goal/c15-contract-and-fitness-goal.md` §4를 **직접 열어** 8항 각각에 증거를 붙인 대조 표를 보고에 포함. 항목별 증거 없이 "COMPLETE" 선언 금지.
