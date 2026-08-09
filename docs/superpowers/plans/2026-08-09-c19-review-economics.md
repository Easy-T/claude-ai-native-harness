# C19 review-economics Implementation Plan (spec §18 착륙)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active
**RPI-Cycle:** 70
**Started:** 2026-08-09

**Goal:** spec §18(C19 배분 재심 판정 3종 + 슬롯2 수용 잔여 3건 채택 + seal 판별력 경화 + §18.4 create-orchestrator:24 개정)의 규약을 L1 문서·skill·seal 로 착륙.

**Architecture:** 3-task — **T1(light) 규범 원문 착륙**(§18.4 정본·미러 :24 개정 + §18.3 전파-완결성 blockquote + §18.2 #16 번들 주 확장) → **T2(light) 소비-규약 supersede 전파**(§18.1 판정 3 포인터 5사이트) → **T3(heavy) seal 판별력 경화**(M20~M22 신설 + #45/#30/#50 in-place 경화 + 카운트·registry 동기).

**task 순서 = T1 → T2 → T3, 역순 금지.** 근거 3항:
1. **Phase I 순서 제약(§18.5 말미)**: §18.4(:24 개정 — 정본·미러의 `위임 X` 소멸)가 seal #50 확장 arm 착륙보다 **선행**해야 한다. 역순이면 확장 arm 이 현행 `위임 X` 실재에 즉시 FAIL 하여 사이클 중간 창이 `PASS=87 FAIL=1` 이 된다(스위트 non-GREEN 커밋 금지 규율 위반).
2. **RED/GREEN 원자성**: M21/M22 의 RED(구 seal 이 변이를 미탐 = rc 0)와 #45/#30 경화의 GREEN 은 **같은 task 안**에서 수행한다(C18 plan T4 선례 — 스위트 non-GREEN 커밋 금지와 양립하는 유일 형태). 따라서 T3 는 분할하지 않는다.
3. T2↔T3 가 `skills/start-rpi-cycle/SKILL.md` 를 공유한다(T2 = :288 소비 규약 · T3 = :252 카운트 리터럴) — carrier 가 파일 겹침을 감지해 자동 순차 배치(의도됨).

**§18.5 동반 갱신 표 → task 대응(전 행 커버 — 누락 = plan 결함):**

| §18.5 행 (파일) | 착륙 task | 스텝 |
|---|---|---|
| 본 spec `2026-07-25-model-policy-design.md` §15.3 포인터 | **T2** | Step 2 |
| `docs/ai-context/review-yield.md` 헤더 | **T2** | Step 3 |
| `skills/start-rpi-cycle/SKILL.md` :288 소비 규약 | **T2** | Step 4 |
| `skills/start-rpi-cycle/SKILL.md` :252 카운트 23→26 | **T3** | Step 3 |
| `CONTEXT.md` 「검증자 기준선」 사후-지지 | **T2** | Step 5 |
| `docs/ai-context/model-policy.md` 검증 행 비고 | **T2** | Step 6 |
| `skills/closeout-pr-cycle/SKILL.md` + 미러 (전파-완결성) | **T1** | Step 3 |
| `opencode-harness/skill/{start-rpi-cycle,closeout-pr-cycle}` 번들 주 | **T1** | Step 4 |
| `skills/create-orchestrator-skill/SKILL.md` + 미러 :24 | **T1** | Step 2 |
| `setup/verify-setup.sh` (#45·#30·#50) | **T3** | Step 2 |
| `setup/tests/seal-regression.test.sh` (M20~M22·witness·make_replica) | **T3** | Step 1 |
| `docs/ai-context/scaffold-registry.md` (#30·#45·#50 행) | **T3** | Step 3 |

**Tech Stack:** markdown(L1 문서·skill) · bash(seal·변이) · perl -pi(CRLF 파일 및 혼합-개행 spec).

**Best-Direction Check:** 최선안 = §18 전 판정의 물리 착륙(규범 원문 verbatim + in-place seal 경화 + 변이 3건). 채택안 = 동일. `DOWNGRADE-DECLARED` 없음.

## Global Constraints

- 세 검증 스위트(`setup/verify-setup.sh` · `setup/tests/seal-regression.test.sh` · `hooks/tests/run-all.sh`)는 **메인 포그라운드만** 실행. Workflow (d) task 본문의 스위트 실행 라인은 **메인이 대행 실행 후 결과를 stage1 보고에 주입**(C17·C18 운용 규율 승계).
- seal/드리프트 검사는 **bash 파일옵스만**(staged-safe) — node/python 우회 금지.
- `settings.json` **라이브 수정 금지** · `hooks/**` **무수정** · `workflows/rpi-implement.js` **무수정** · `hooks/tests/cases.tsv` **무수정**(run-all 291 불변).
- spec `docs/superpowers/specs/2026-07-25-model-policy-design.md` **§0~§17 본문 무수정** — **단 §15.3 헤딩 직후 supersede 포인터 1줄 삽입은 §18.5 표가 명시한 예외**(T2 Step 2). 그 외 어떤 절도 건드리지 않는다. §18 은 이미 착륙(R 산출물) — plan 은 소비만.
- **개행 규율(2026-08-09 실측)**:
  - **CRLF 파일 → `perl -pi` 필수, `sed -i`·Edit 금지**: `README.md`(547/547) · `docs/ai-context/model-policy.md`(39/39) · `docs/ai-context/scaffold-registry.md`(110/110).
  - **spec 파일은 혼합 개행**(`:1~1765` CRLF · `:1766` 이후 LF — 총 lines=2206 / cr=1821) → **Edit/Write 도구 금지, `perl` 만**. C19 Gate R 정정 세션에서 Edit 가 LF 꼬리를 CRLF 로 재작성해 §17 전체가 diff 오염된 실증이 있다.
  - **LF 파일(Edit 가능)**: `skills/**/SKILL.md`(start-rpi 329/0 · closeout 243/0 · create-orchestrator 61/0) · `opencode-harness/skill/**/SKILL.md`(미러 create-orchestrator 66/0) · `setup/verify-setup.sh` · `setup/tests/seal-regression.test.sh`(177/0) · `CONTEXT.md`(158/0) · `docs/ai-context/review-yield.md`(49/0).
  - **CR 검사는 `tr -cd '\r' | wc -c` 만 신뢰**. 이 환경의 MSYS gawk/grep 은 텍스트 모드로 CR 을 삼켜 `awk '/\r$/'`·`grep $'…\r'` 이 진짜 CRLF 행에도 거짓 음성을 낸다(실측: `printf 'aaa\r\nbbb\n'` → awk `LF-BAD` / grep `0` / perl `CRLF-OK`). **행 단위 CRLF 판별은 `perl -ne '/\r\n$/'`** 를 쓴다.
- **기준선(2026-08-09 실측)**: verify-setup **88/0** · seal-regression **23/0**(C18 종료 시점) · run-all **291/291**.
- **예상 최종 카운트**: verify-setup **88/0**(δ=0 — 전부 in-place 경화, **신규 seal 번호 발급 없음** · ok/fail 호출 수 67 불변) · seal-regression **26/0**(γ=+3, M20~M22) · run-all **291/291**(δ=0 — `hooks/**` 무터치, 무회귀 확인용 1회). **README.md 무변경**(`현재 88 PASS` 리터럴 불변이므로 #36 자기-카운트가 그대로 GREEN).
- Workflow (d) canonical carrier: stage1 `agentType:'execute-strict', model:'opus'` + `effort:'high'`(T1·T2 = light 문서) / `effort:'xhigh'`(T3 = heavy, `setup/` 터치) · stage2 `agentType:'review-strict', model:'opus'` 명시 · **schema 금지** · TDD-verbatim(task 본문 원문 전달).
- 검증자 floor 매트릭스 v2 준수: 판단-게이트 `max(작업자, opus)` · 준수-확인 작업자 티어.
- 규범 원문 3건(§18.4 정본 blockquote · §18.4 미러 blockquote · §18.3 전파-완결성 blockquote)은 spec blockquote 에서 `  > ` 접두만 제거한 **verbatim 전사** — 재서술·요약·재줄바꿈·들여쓰기 추가 금지.
- **과분류 방향-반전 전수 재감사(C15 교훈·goal §4) = N/A 선언**: 이번 계약 변경(#45 행-선두 앵커·#30 conjunct 추가·#50 arm 확장)은 전부 검사 표면의 **확대·구체화**(안전→더 엄격)이지 안전→면제 방향 반전이 없다 — 새로 침묵하게 되는 경로 0(M21/M22 가 그 증인).

---

### Task 1: 규범 원문 착륙 — create-orchestrator :24(정본+미러) · closeout 전파-완결성(정본+미러) · 번들 주 확장 2파일 (light)

**Files:**
- Modify: `skills/create-orchestrator-skill/SKILL.md` (:24 — 1줄 → 3줄, spec §18.4 **정본** blockquote verbatim)
- Modify: `opencode-harness/skill/create-orchestrator-skill/SKILL.md` (:24 — 1줄 → 4줄, spec §18.4 **미러** blockquote verbatim)
- Modify: `skills/closeout-pr-cycle/SKILL.md` (:170 = 미니-사이클 step 3 행 **바로 뒤**, :171 `4. **메인 승인**` 행 **앞** — §18.3 전파-완결성 3줄 삽입)
- Modify: `opencode-harness/skill/closeout-pr-cycle/SKILL.md` (:175 뒤, :176 `4. **메인 승인**` 앞 — 동일 3줄)
- Modify: `opencode-harness/skill/start-rpi-cycle/SKILL.md` (:19 번들 주 확장)
- Modify: `opencode-harness/skill/closeout-pr-cycle/SKILL.md` (:83 번들 주 확장 — 위 :175 삽입과 같은 파일)

**Interfaces:**
- Produces: create-orchestrator 정본·미러의 `집필-위임 가능`·`FABLE-TAKEOVER`·`골격 계약` 토큰 + **`위임 X` 소멸**(T3 의 seal #50 확장 arm 이 요구하는 전제 — 이 task 가 선행하지 않으면 T3 GREEN 이 성립 불가) · closeout 정본·미러의 `전파-완결성` 토큰 · 번들 주의 `spec §N` 구절.
- Consumes: 없음.

- [ ] **Step 1: RED — 구 단정 실재 + 신 토큰 부재 실측**

```bash
cd ~/.claude
grep -n '위임 X' skills/create-orchestrator-skill/SKILL.md opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -c '집필-위임 가능' skills/create-orchestrator-skill/SKILL.md opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -c 'FABLE-TAKEOVER' skills/create-orchestrator-skill/SKILL.md opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -c '골격 계약' skills/create-orchestrator-skill/SKILL.md opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -c '전파-완결성' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c 'spec §N' opencode-harness/skill/start-rpi-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -n '4. \*\*메인 승인\*\*' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
```

Expected (RED) — 1번 grep(구 단정 실재, 개정 앵커):
```
skills/create-orchestrator-skill/SKILL.md:24:※ skill-creator는 메인 세션의 skill (플러그인 제공). sub-agent에 위임 X — 메인이 절차를 따름.
opencode-harness/skill/create-orchestrator-skill/SKILL.md:24:※ 생성 절차는 vendored `writing-skills` 스킬을 따른다 (skill-creator는 별도 플러그인이라 vendored 되지 않음 — 대체로 `writing-skills` 사용). sub-agent에 위임 X — 메인이 절차를 따름.
```
나머지 4개 토큰 grep(`집필-위임 가능`·`FABLE-TAKEOVER`·`전파-완결성`·`spec §N`)은 **8줄 전부 `:0`**, `골격 계약` grep 은 **두 파일 모두 `:1`**(기존 :36 skeleton-scan 권위-정의 행 — 신 :24 가 1회 더 도입해 GREEN 에서 2 가 된다).
마지막 grep(삽입 하한 앵커 실재 — `4. **메인 승인**`):
```
skills/closeout-pr-cycle/SKILL.md:171:4. **메인 승인**: 판정 주권은 이전되지 않는다.
opencode-harness/skill/closeout-pr-cycle/SKILL.md:176:4. **메인 승인**: 판정 주권은 이전되지 않는다.
```

- [ ] **Step 2: create-orchestrator :24 개정 (정본 + 미러) — §18.4 규범 원문 verbatim 전사**

`skills/create-orchestrator-skill/SKILL.md` — old (:24, 1줄):
```
※ skill-creator는 메인 세션의 skill (플러그인 제공). sub-agent에 위임 X — 메인이 절차를 따름.
```
new (3줄 — spec §18.4 정본 blockquote 에서 `  > ` 접두만 제거한 **byte-verbatim**, 들여쓰기 추가 금지):
```
※ skill-creator는 메인 세션의 skill (플러그인 제공) — 메인이 **Skill 도구로 호출**해 절차를 따르고
결정(골격)을 소유한다. **전문(SKILL.md 본문) 집필은 opus 집필-위임 가능**(골격 계약 필수 ·
재작성 ≤2회 · 초과 시 FABLE-TAKEOVER 폴백 — spec §17.1). 위임되는 것은 집필이지 절차·결정이 아니다.
```
:23 헤딩(`# Phase 2 — Follow skill-creator procedure (메인 세션이 직접)`)과 :25(`1. 메인이 skill-creator skill의 절차 호출 (Skill 도구로 명시 invoke)`)는 **불변**(편집 후 :25 → :27 로 행번호만 이동).

`opencode-harness/skill/create-orchestrator-skill/SKILL.md` — old (:24, 1줄):
```
※ 생성 절차는 vendored `writing-skills` 스킬을 따른다 (skill-creator는 별도 플러그인이라 vendored 되지 않음 — 대체로 `writing-skills` 사용). sub-agent에 위임 X — 메인이 절차를 따름.
```
new (4줄 — spec §18.4 **미러** blockquote 에서 `  > ` 접두만 제거한 **byte-verbatim**. 1문장째가 미러 현행 문안을 유지하므로 정본과 줄 수·줄바꿈 위치가 다르다 — 정본 문안을 복사해 오지 말 것):
```
※ 생성 절차는 vendored `writing-skills` 스킬을 따른다 (skill-creator는 별도 플러그인이라 vendored 되지
않음 — 대체로 `writing-skills` 사용) — 메인이 **`skill` 도구로 호출**해 절차를 따르고 결정(골격)을
소유한다. **전문(SKILL.md 본문) 집필은 opus 집필-위임 가능**(골격 계약 필수 · 재작성 ≤2회 · 초과 시
FABLE-TAKEOVER 폴백 — spec §17.1). 위임되는 것은 집필이지 절차·결정이 아니다.
```
미러 :23 헤딩(`# Phase 2 — Follow writing-skills procedure (메인 세션이 직접)`)과 :25(`1. 메인이 \`writing-skills\` 스킬을 \`skill\` 도구로 호출`)도 **불변**.

- [ ] **Step 3: closeout 미니-사이클 step 3 뒤 — §18.3 전파-완결성 blockquote 3줄 삽입 (정본 + 미러)**

`skills/closeout-pr-cycle/SKILL.md` — :170(`3. **review-strict(opus) 검증**: … 근거로 판정.`)과 :171(`4. **메인 승인**: 판정 주권은 이전되지 않는다.`) **사이**에 아래 3줄을 삽입(앞뒤 빈 줄 **추가 없음** — 번호 목록의 연속성 유지, 삽입 3줄은 **열 0** 시작으로 spec blockquote 와 byte-동일):
```
※ **전파-완결성 대조 (C19 spec §18.3)**: step 3 검증은 원 발견 전건 대응에 더해, 각 정정의 착륙 사이트를
4범주(spec 본문 · spec 내 착륙-verbatim 블록 · L1 소비자 skill/문서 · opencode 미러)로 전수 대조한다 —
범주에 대응물이 없으면 N/A 를 명시(무언 통과 금지). C18 정정-전파 공백 클래스(슬롯2 5건)의 구조 대응.
```

`opencode-harness/skill/closeout-pr-cycle/SKILL.md` — :175(정본 :170 과 byte-동일한 step 3 행)과 :176(`4. **메인 승인**: …`) **사이**에 **위와 동일한 3줄**을 삽입(이 문안에는 `CLAUDE.md`/`AGENTS.md` 명칭이 없어 미러 치환 불요 — C18 T2 Step 3b 선례와 동형).

- [ ] **Step 4: 번들 주 확장 2곳 (§18.2 #16)**

`opencode-harness/skill/start-rpi-cycle/SKILL.md` :19 · `opencode-harness/skill/closeout-pr-cycle/SKILL.md` :83 — **두 곳의 old 는 byte-동일**(각 파일 내 유일 — 실측 `grep -c` 각 1):
```
※ (번들 주: 'opus' 등 모델 명칭은 CC 하네스 기준 — opencode 환경은 동급 내부 모델로 해석)
```
new (**두 곳 동일**):
```
※ (번들 주: 'opus' 등 모델 명칭은 CC 하네스 기준 — opencode 환경은 동급 내부 모델로 해석. 'spec §N' 참조도 정본 하네스 spec 기준 — 번들에는 해당 규범이 인라인 착륙돼 있어 참조 해소 없이 완결)
```
※ §18.6-3 대로 dangling `spec §` 참조 25건 **자체는 존속**한다 — 이 확장이 해소하는 것은 참조의 *의미*(주석 1구절)이지 참조 자체가 아니다. 참조 제거·spec 동봉은 **금지**(비용 > 실익으로 기각됨).

- [ ] **Step 5: GREEN — 토큰 + verbatim diff + 스위트**

```bash
cd ~/.claude
grep -c '위임 X' skills/create-orchestrator-skill/SKILL.md opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -c '집필-위임 가능' skills/create-orchestrator-skill/SKILL.md opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -c 'FABLE-TAKEOVER' skills/create-orchestrator-skill/SKILL.md opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -c '골격 계약' skills/create-orchestrator-skill/SKILL.md opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -c '전파-완결성' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c 'spec §N' opencode-harness/skill/start-rpi-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
```
Expected (GREEN):
- `위임 X` = **두 파일 모두 `:0`**(구 단정 소멸 — T3 seal #50 확장 arm 의 전제)
- `집필-위임 가능` · `FABLE-TAKEOVER` = 두 파일 모두 `:1`
- `골격 계약` = 두 파일 모두 `:2`(기존 :36 권위-정의 + 신 :24 — :36 삭제·정리 금지)
- `전파-완결성` = 두 파일 모두 `:1`
- `spec §N` = 두 파일 모두 `:1`

**verbatim 전사 검증 — 정본 create-orchestrator :24 만 awk 앵커-추출 diff**(C18 plan T1 Step 4 동형. spec 은 정정 사이클마다 행이 밀리므로 `sed -n 'N,Mp'` 행번호 하드코딩은 즉시 스테일이 된다 — 앵커 추출을 쓴다):
```bash
cd ~/.claude
diff <(awk '/^  > ※ skill-creator는/,/^  > .*절차·결정이 아니다/' docs/superpowers/specs/2026-07-25-model-policy-design.md | sed 's/^  > //') \
     <(awk '/^※ skill-creator는/,/^.*절차·결정이 아니다/' skills/create-orchestrator-skill/SKILL.md) && echo VERBATIM-OK
```
Expected: `VERBATIM-OK` (diff 출력 0줄 — 양쪽 3줄).

**미러 :24 와 전파-완결성 3줄은 토큰 grep 으로 판별한다 — diff 부적합 사유 명시**:
- 미러 create-orchestrator :24 는 **1문장째가 정본과 상이**(vendored `writing-skills` 문안 유지)하므로 정본 blockquote 와의 diff 가 원리적으로 불성립하고, 미러 blockquote 는 spec 안에서 별도 블록이라 정본 추출 앵커(`^  > ※ skill-creator는`)에 걸리지 않는다.
- closeout 전파-완결성 3줄은 삽입 위치가 **번호 목록 내부**라 파일별 들여쓰기 재배치 여지가 있어 행-단위 diff 가 부적합하다.
두 경우 모두 **행 전문(full-line) `grep -F`** 로 byte-일치를 확인한다:
```bash
cd ~/.claude
grep -cF '않음 — 대체로 `writing-skills` 사용) — 메인이 **`skill` 도구로 호출**해 절차를 따르고 결정(골격)을' opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -cF '소유한다. **전문(SKILL.md 본문) 집필은 opus 집필-위임 가능**(골격 계약 필수 · 재작성 ≤2회 · 초과 시' opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -cF 'FABLE-TAKEOVER 폴백 — spec §17.1). 위임되는 것은 집필이지 절차·결정이 아니다.' opencode-harness/skill/create-orchestrator-skill/SKILL.md
grep -cF '4범주(spec 본문 · spec 내 착륙-verbatim 블록 · L1 소비자 skill/문서 · opencode 미러)로 전수 대조한다 —' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -cF '범주에 대응물이 없으면 N/A 를 명시(무언 통과 금지). C18 정정-전파 공백 클래스(슬롯2 5건)의 구조 대응.' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
```
Expected: 앞 3개 grep 은 각 `1`, 뒤 2개 grep 은 두 파일 모두 `:1`(총 4줄).

스위트 무회귀:
```bash
cd ~/.claude
bash setup/verify-setup.sh 2>&1 | tail -2
```
Expected: `verify-setup: PASS=88 FAIL=0`.
※ **δ=0 인 이유(실측 근거)**: 현행 seal #50 은 `위임 X` 부정-단언을 `skills/start-rpi-cycle/SKILL.md`(:575)와 `opencode-harness/skill/start-rpi-cycle/SKILL.md`(:579) **두 파일에서만** 검사한다 — create-orchestrator 2파일은 아직 어떤 seal 의 검사 표면도 아니므로(`grep -rn 'create-orchestrator' setup/verify-setup.sh` → :41/:46/:250 의 skill **목록 존재** 검사뿐) 이 task 의 편집은 카운트에 무영향이다. 그 확장은 T3 Step 2 에서 착륙한다.

- [ ] **Step 6: 커밋**

```bash
cd ~/.claude
git add skills/create-orchestrator-skill/SKILL.md opencode-harness/skill/create-orchestrator-skill/SKILL.md skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
git commit -m "$(cat <<'EOF'
feat(c19): §18.4 create-orchestrator:24 개정 + §18.3 전파-완결성 착륙 + 번들 주 확장 (미러 동형)

- create-orchestrator :24 정본/미러 → §18.4 규범 원문 verbatim (위임-금지 단정 소멸 · 집필-위임 가능·
  골격 계약·재작성 ≤2회·FABLE-TAKEOVER). §17.7 수용 잔여 1 해소
- closeout Phase 4 미니-사이클 step 3 뒤: 전파-완결성 대조 3줄(§18.3 — 4범주 전수 대조·N/A 명시 의무)
  = C18 정정-전파 공백 클래스(슬롯2 5건)의 구조 대응. opencode 미러 동일 문안
- opencode 번들 주(start-rpi :19 · closeout :83): 'spec §N' 참조는 정본 spec 기준·번들 규범은
  인라인 착륙으로 완결임을 명시(§18.2 #16 — dangling 참조 25건 자체는 §18.6-3 대로 존속)
- verify-setup 88/0 불변(create-orchestrator 는 아직 #50 검사 표면 밖 — 확장은 T3)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: 소비-규약 supersede 전파 — spec §15.3 포인터 + 대장 헤더 + L1 3사이트 (light)

**Files:**
- Modify: `docs/superpowers/specs/2026-07-25-model-policy-design.md` (§15.3 헤딩 :1319 직후 1줄 삽입 — **혼합 개행, `perl` 필수 · Edit/Write 금지**)
- Modify: `docs/ai-context/review-yield.md` (:3 — LF)
- Modify: `skills/start-rpi-cycle/SKILL.md` (:288 부분 문자열 — LF)
- Modify: `CONTEXT.md` (:93 행 말미 1문장 append — LF)
- Modify: `docs/ai-context/model-policy.md` (:19 부분 문자열 — **CRLF, `perl -pi` 필수**)

**Interfaces:**
- Produces: `§18.1 판정 3` · `C19 §18` · `사후 지지` 토큰(5사이트) — §18.5 표의 소비-규약 supersede 전파 완결.
- Consumes: 없음(spec §18 은 R 단계 산출물로 이미 존재).

- [ ] **Step 1: RED — 신 토큰 부재 + old 앵커 실재·유일성 실측**

```bash
cd ~/.claude
grep -c '소비 주기를 supersede' docs/superpowers/specs/2026-07-25-model-policy-design.md
grep -c 'C19 §18' docs/ai-context/review-yield.md docs/ai-context/model-policy.md
grep -c '§18.1 판정 3' docs/ai-context/review-yield.md skills/start-rpi-cycle/SKILL.md
grep -c '사후 지지' CONTEXT.md docs/ai-context/model-policy.md
grep -n '^### §15\.3 C16-A' docs/superpowers/specs/2026-07-25-model-policy-design.md
grep -c '소비처: 3사이클 축적 후 floor·리뷰 배분 재심' docs/ai-context/review-yield.md
grep -c '3사이클 축적 후 floor·배분 재심이 소비처' skills/start-rpi-cycle/SKILL.md
grep -c '미지-티어 리터럴은 비면제' CONTEXT.md
grep -c '세션 축 제거(U4). 평가:' docs/ai-context/model-policy.md
printf 'spec lines=%s cr=%s\n' "$(grep -c '' docs/superpowers/specs/2026-07-25-model-policy-design.md)" "$(tr -cd '\r' < docs/superpowers/specs/2026-07-25-model-policy-design.md | wc -c)"
printf 'mp   lines=%s cr=%s\n' "$(grep -c '' docs/ai-context/model-policy.md)" "$(tr -cd '\r' < docs/ai-context/model-policy.md | wc -c)"
```

Expected (RED):
- `소비 주기를 supersede` = `0`
- `C19 §18` = 두 파일 모두 `:0`
- `§18.1 판정 3` = 두 파일 모두 `:0`
- `사후 지지` = 두 파일 모두 `:0`
- 삽입 앵커 실재: `1319:### §15.3 C16-A — per-layer 수율 계량 표준화 (\`layer-yield\`)`
- 나머지 4개 old 앵커 = **각 `1`**(치환 유일성 확보 — perl 전역 치환의 안전 전제)
- 개행 기준선: `spec lines=2206 cr=1821` · `mp   lines=39 cr=39`

- [ ] **Step 2: spec §15.3 — supersede 포인터 1줄 삽입 (혼합 개행 — perl 필수)**

`docs/superpowers/specs/2026-07-25-model-policy-design.md` — §15.3 헤딩 행(`### §15.3 C16-A …`) **바로 뒤**에 빈 CRLF 행 + 포인터 1줄을 삽입. **Edit/Write 도구 금지**(C19 Gate R 정정 세션 실증: Edit 가 :1766 이후 LF 꼬리를 CRLF 로 재작성해 §17 전체 diff 오염):
```bash
cd ~/.claude
perl -pi -e '$_ .= "\r\n> ⚠**§18.1 판정 3(C19)이 소비 주기를 supersede** — 정기(3사이클 축적 후)가 아니라 트리거 기반 3종. ledger append 필수는 불변. 아래 원문은 C16 시점 기록.\r\n" if /^### §15\.3 C16-A/'  docs/superpowers/specs/2026-07-25-model-policy-design.md
```
삽입되는 본문 1줄(원문):
```
> ⚠**§18.1 판정 3(C19)이 소비 주기를 supersede** — 정기(3사이클 축적 후)가 아니라 트리거 기반 3종. ledger append 필수는 불변. 아래 원문은 C16 시점 기록.
```
※ §15.3 **본문은 한 글자도 고치지 않는다** — 이 1줄이 Global Constraints 가 허용한 유일한 spec §0~§17 예외이며, "아래 원문은 C16 시점 기록"이 원문 보존을 선언한다.

- [ ] **Step 3: review-yield.md :3 — 소비 규약 갱신 + 소비-이력 (LF, Edit 가능)**

old (:3, 1줄 전문):
```
> 사이클마다 Closeout `layer-yield:` 필드와 같은 행을 append. 소비처: 3사이클 축적 후 floor·리뷰 배분 재심.
```
new (1줄):
```
> 사이클마다 Closeout `layer-yield:` 필드와 같은 행을 append(필수 불변). 소비 = 트리거 기반 재심(spec §18.1 판정 3, C19 supersede). 소비-이력: C19 §18 이 C15~C18 4행 소비(1호).
```
:4(`> 실발견 = REAL 판정된 내용 결함…`) 및 대장 표 전체는 **불변**.

- [ ] **Step 4: start-rpi-cycle :288 — 소비 규약 부분 문자열 치환 (LF, Edit 가능)**

`skills/start-rpi-cycle/SKILL.md` :288 의 **부분 문자열만** 치환한다(행 나머지·`layer-yield 계량`(:281)·CP 필드 정의행은 **비접촉** — seal #49 앵커 2종 보존).

old 앵커(:288 내부, 파일 내 유일):
```
3사이클 축적 후 floor·배분 재심이 소비처
```
new:
```
소비는 트리거 기반 재심(spec §18.1 판정 3 — C19 첫 소비, 정기 아님)
```
치환 후 :288 전문(확인용):
```
     리뷰 배분 재심은 하네스 거버넌스 결정. 소비는 트리거 기반 재심(spec §18.1 판정 3 — C19 첫 소비, 정기 아님)). append 시점 = Closeout
```
※ 위 전문의 닫는 괄호 2개는 **정상**이다 — 원문의 `…(대상-프로젝트 사이클도 — 리뷰 배분 재심은 … 소비처)` 괄호가 :287 에서 열려 :288 에서 닫히고, 신 문안이 자체 괄호를 하나 더 갖기 때문. 괄호 정리 목적의 추가 편집 **금지**(부분-문자열 치환 범위 밖).

- [ ] **Step 5: CONTEXT.md :93 — 사후-지지 1문장 append (LF, Edit 가능)**

`CONTEXT.md` :93(「검증자 기준선」 본문)의 **행 말미**에 1문장을 append 한다. :94 `_Avoid_:` 행 **앞에 새 행을 만들지 않는다** — :93 같은 행 끝에 이어 붙인다.

old 앵커(:93 말미):
```
미지-티어 리터럴은 비면제(≥opus 단언 불가 → 위반).
```
new:
```
미지-티어 리터럴은 비면제(≥opus 단언 불가 → 위반). **C19 사후 지지(§18.1 판정 2)**: 4사이클 ledger 에서 열화 신호 부재의 관측 — 열화의 반증 아님(자기보고 계량 한계·GPT 층이 계속 독립 대조군).
```
※ "열화의 반증 아님"은 §18.1 판정 2 의 **주장 강도 한정(필수)** 이자 §18.6-2 수용 잔여다 — 이 한정 표현을 빼고 "열화 없음"으로 요약하는 것은 **금지**.
※ `CONTEXT.md` 는 이 1문장 append 외 **무터치**(신규 용어 2건 「판별력 공백」·「정정-전파 공백」은 Phase R 에서 기등록 — 실측 각 `1`).

- [ ] **Step 6: model-policy.md :19 — 검증 행 비고에 사후-지지 구절 (CRLF — perl -pi 필수)**

`sed -i` · Edit 도구 **금지**(39/39 CRLF):
```bash
cd ~/.claude
perl -pi -e 's/세션 축 제거\(U4\)\. 평가:/세션 축 제거(U4 — C19 §18.1 판정 2 사후 지지: 열화 신호 부재의 관측). 평가:/' docs/ai-context/model-policy.md
```
※ old 앵커 `세션 축 제거(U4). 평가:` 는 파일 내 **유일**(Step 1 RED 에서 `1` 실측) — 전역 치환이 안전한 전제.

- [ ] **Step 7: GREEN — 토큰 + 개행 보존 + 스위트**

```bash
cd ~/.claude
grep -c '소비 주기를 supersede' docs/superpowers/specs/2026-07-25-model-policy-design.md
grep -c 'C19 §18' docs/ai-context/review-yield.md docs/ai-context/model-policy.md
grep -c '§18.1 판정 3' docs/ai-context/review-yield.md skills/start-rpi-cycle/SKILL.md
grep -c '사후 지지' CONTEXT.md docs/ai-context/model-policy.md
grep -c '소비처: 3사이클 축적 후 floor·리뷰 배분 재심' docs/ai-context/review-yield.md
grep -c '3사이클 축적 후 floor·배분 재심이 소비처' skills/start-rpi-cycle/SKILL.md
grep -c 'layer-yield 계량' skills/start-rpi-cycle/SKILL.md
grep -cF -- '- layer-yield: **고유 필수 필드**' skills/start-rpi-cycle/SKILL.md
```
Expected (GREEN):
- `소비 주기를 supersede` = `1`
- `C19 §18` = 두 파일 모두 `:1`(CONTEXT.md 는 append 문안이 `C19 사후 지지(§18.1 …)` 라 이 부분 문자열을 형성하지 않는다 — `사후 지지` grep 이 판별자)
- `§18.1 판정 3` = 두 파일 모두 `:1`
- `사후 지지` = 두 파일 모두 `:1`
- 구 문안 2종(`소비처: 3사이클 축적 후…` · `3사이클 축적 후 floor·배분 재심이 소비처`) = **`0`**(정기-소비 문면 소멸)
- seal #49 앵커 무손: `layer-yield 계량` = `1` · `- layer-yield: **고유 필수 필드**` = `1`

**개행 보존 검증 2건**(혼합-개행/CRLF 유입 차단):
```bash
cd ~/.claude
printf 'spec lines=%s cr=%s\n' "$(grep -c '' docs/superpowers/specs/2026-07-25-model-policy-design.md)" "$(tr -cd '\r' < docs/superpowers/specs/2026-07-25-model-policy-design.md | wc -c)"
printf 'mp   lines=%s cr=%s\n' "$(grep -c '' docs/ai-context/model-policy.md)" "$(tr -cd '\r' < docs/ai-context/model-policy.md | wc -c)"
perl -ne 'print(/\r\n$/ ? "CRLF-OK\n" : "LF-BAD\n") if /§18\.1 판정 3\(C19\)이 소비 주기/' docs/superpowers/specs/2026-07-25-model-policy-design.md
```
Expected:
```
spec lines=2208 cr=1823
mp   lines=39 cr=39
CRLF-OK
```
- spec: 편집 전 2206/1821 → 삽입 **2행**(빈 행 + 포인터 행, 둘 다 `\r\n`)이라 lines +2 · cr +2. **LF 꼬리(:1766 이후)는 불변** — 총 CR 증가분이 정확히 2 인 것이 그 증거다.
- model-policy: 행 추가 없는 in-place 치환이므로 39/39 **불변**.
- 마지막 판별자는 **`perl`** 이다. 골격이 제시한 `awk '/…/{print (/\r$/ ? "CRLF-OK" : "LF-BAD")}'` 형태는 이 환경에서 **쓰지 않는다** — MSYS gawk 가 텍스트 모드로 CR 을 삼켜 진짜 CRLF 행에도 `LF-BAD` 를 내는 것이 실측됐다(`printf 'aaa\r\nbbb\n'` 대조 실험). 값·기대(CRLF 보존)는 동일하고 도구만 CR-정확한 것으로 바꾼 것이다.

```bash
cd ~/.claude
bash setup/verify-setup.sh 2>&1 | tail -2
```
Expected: `verify-setup: PASS=88 FAIL=0`.
※ **무회귀 근거**: #45 의 현행 광역 앵커(`execute-strict.*opus` / `explore-strict.*sonnet`)는 :19 검증 행이 아니라 :16/:17/:21/:29/:30/:37 · :18/:31/:37 에 매칭하므로 :19 in-place 치환은 비접촉. #49 는 위 두 앵커 grep 으로 직접 확인했다. 그 밖의 seal 은 편집 구간 밖.

- [ ] **Step 8: 커밋**

```bash
cd ~/.claude
git add docs/superpowers/specs/2026-07-25-model-policy-design.md docs/ai-context/review-yield.md docs/ai-context/model-policy.md skills/start-rpi-cycle/SKILL.md CONTEXT.md
git commit -m "$(cat <<'EOF'
feat(c19): §18.1 판정 3 소비-규약 supersede 전파 + 판정 2 사후-지지 (5사이트)

- spec §15.3 헤딩 직후 supersede 포인터 1줄(정기 3사이클 → 트리거 기반 3종 · append 필수 불변 ·
  아래 원문은 C16 시점 기록) — §18.5 가 명시한 유일한 §0~§17 예외, 본문 무수정
- review-yield.md 헤더: 소비 = 트리거 기반 재심 + 소비-이력(C19 §18 이 C15~C18 4행 소비, 1호)
- start-rpi-cycle :288 부분 치환(정기 문면 소멸 — seal #49 앵커 2종 비접촉)
- CONTEXT.md 「검증자 기준선」 :93 말미: 사후 지지 1문장(열화 신호 부재의 관측 — 반증 아님, 한정 유지)
- model-policy.md :19 검증 행 비고에 동일 한정 구절 — CRLF 파일이라 perl -pi(39/39 불변)
- spec 은 혼합 개행(CRLF 1~1765 / LF 이후)이라 perl 만 사용(2206/1821 → 2208/1823)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: seal 판별력 경화 — M20~M22 신설 + #45/#30/#50 in-place 경화 + 카운트·registry 동기 (heavy — T1·T2 완료 후, `setup/` 터치)

**§18.2 판정 확정: 신규 seal 번호 발급 없음 — 전부 in-place 경화.** 근거: #14/#13 은 *기존 seal 의 판별력 공백*이고 #50 확장 arm 은 *기존 부정-단언의 표면 확대*라, 새 번호를 발급하면 같은 회귀를 두 seal 이 중복 검사하면서 verify-setup 카운트만 부풀린다(§18.5 카운트 계약: **88 불변**).

**Files:**
- Modify: `setup/tests/seal-regression.test.sh` (LF 177/0 — witness() :19 · make_replica · 뮤테이터 M20~M22 · 단언 3건)
- Modify: `setup/verify-setup.sh` (LF — #45 :460 · #30 :277 · #50 미러 arm 뒤 :580)
- Modify: `skills/start-rpi-cycle/SKILL.md` (:252 카운트 리터럴 `직전 23/0 유효` → `직전 26/0 유효` — LF)
- Modify: `docs/ai-context/scaffold-registry.md` (#30 :68 · #45 :83 · #50 :88 — **CRLF 110/110, `perl -pi` 필수**)

**Interfaces:**
- Produces: 변이 M20~M22 · #45 행-선두 앵커 · #30 스키마 골격 conjunct · #50 create-orchestrator 확장 arm · 카운트 23→26 동기 · registry 3행 갱신.
- Consumes: **T1 이 소멸시킨 create-orchestrator 2파일의 `위임 X`**(#50 확장 arm 의 전제 — T1 미완 상태에서 이 task 를 실행하면 verify-setup 이 즉시 `PASS=87 FAIL=1`). T2 가 착륙시킨 model-policy :19 치환(#45 경화 앵커와 비접촉임을 재확인).

- [ ] **Step 1: RED — witness·make_replica 선행 보강 후 변이 3건 추가, 구 seal 미탐 실측**

RED 재현자는 라이브 파일 변이가 아니라 **seal-regression 의 격리 replica**(`mktemp -d` + `HOME=<replica>`)를 쓴다 — 라이브 `~/.claude` 는 witness cksum 으로 불변 증명된다.

**⑴ `witness()` :19 목록 확장** — M21/M22 표적 2파일이 witness 에 없으면 "라이브 불변" 단언이 그 두 파일에 대해 vacuous 가 된다(C18 델타 재심 #2 와 동일 클래스의 예방).

old (:19, 목록 부분 — `for f in …` 이하 한 줄):
```
witness() { local f; for f in state.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv skills/ui-design/design.md opencode-harness/skill/ui-design/design.md agents/explore-strict.md agents/execute-strict.md agents/review-strict.md settings.example.json setup/doctor.sh skills/start-rpi-cycle/SKILL.md setup/verify-setup.sh hooks/surface-model-policy.sh docs/ai-context/review-yield.md docs/ai-context/cross-family-review.md; do
```
new (공백 구분 목록에 2항 추가 — `state.schema.json` 은 `state.json` 뒤, `docs/ai-context/model-policy.md` 는 기존 `docs/ai-context/*` 항목 뒤):
```
witness() { local f; for f in state.json state.schema.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv skills/ui-design/design.md opencode-harness/skill/ui-design/design.md agents/explore-strict.md agents/execute-strict.md agents/review-strict.md settings.example.json setup/doctor.sh skills/start-rpi-cycle/SKILL.md setup/verify-setup.sh hooks/surface-model-policy.sh docs/ai-context/review-yield.md docs/ai-context/cross-family-review.md docs/ai-context/model-policy.md; do
```

**⑵ `make_replica` — 미러 create-orchestrator 복제 블록 추가.** C18 미러 start-rpi 복제 블록(`  # C18: seal #50 conjunct ③(미러 parity)…` ~ `  fi`, :43-48) **바로 뒤**에 동형 블록 삽입:
```bash
  # C19: seal #50 확장 arm(§18.3)이 검사하는 미러 create-orchestrator — 미복제 시 그 arm 이 replica
  # 에서 vacuous 가 된다(#43 design.md · C18 미러 start-rpi 복제와 동형 이유).
  if [ -f "$SRC/opencode-harness/skill/create-orchestrator-skill/SKILL.md" ]; then
    mkdir -p "$C/opencode-harness/skill/create-orchestrator-skill"
    cp -p "$SRC/opencode-harness/skill/create-orchestrator-skill/SKILL.md" "$C/opencode-harness/skill/create-orchestrator-skill/SKILL.md"
  fi
```

**⑶ 뮤테이터 3건** — Mutator 19 정의(`mut_yield_cp_field_drop() { … }`, :143) **바로 뒤**에 삽입(기존 관례대로 각 2~4줄 사유 주석 동반):
```bash
# Mutator 20 — seal #50 **부정-단언 arm** 커버 (C19 spec §18.3): C18 은 이 arm 을 변이 미커버로 남겼다
# (C18 plan :484 정직 부기). replica 정본 start-rpi-cycle 에 구 단정 '위임 X' 를 주입해 half-landing
# /롤백-혼입 클래스를 재현한다 — 긍정 토큰은 전부 살아있으므로 부정-단언 arm 만이 이 변이를 잡는다.
mut_old_assertion_revival() { printf '\n   sub-agent에 위임 X — 메인이 직접.\n' >> "$1/skills/start-rpi-cycle/SKILL.md"; }
# Mutator 21 — seal #45 conjunct ① 앵커 경화의 RED (C19 spec §18.2 #14): 광역 grep 시절엔
# 'execute-strict.*opus' 가 model-policy.md 6행에 매칭해, 표적인 구현 heavy 행(:16)을 통째로 지워도
# seal 이 GREEN 을 유지했다(판별력 공백 실측). 행-선두 앵커로 경화된 뒤에만 이 변이가 RED 가 된다.
mut_mp_heavy_row_drop() { perl -ni -e 'print unless /^\| 구현 heavy /' "$1/docs/ai-context/model-policy.md"; }
# Mutator 22 — seal #30 스키마 골격 conjunct 의 RED (C19 spec §18.2 #13): #30 의 node 검사는
# **스키마-구동**이라 스키마가 비면 검사도 빈다 — 'required' 라인을 지우면 state.json 이 무엇이든
# 통과한다(오라클 침묵). 골격 앵커 conjunct 가 결합된 뒤에만 이 변이가 RED 가 된다.
mut_schema_required_drop() { perl -ni -e 'print unless /"required"/' "$1/state.schema.json"; }
```

**⑷ 단언 3건** — 기존 단언 목록 마지막 줄(`assert_seal_fires "yield_cp_field_drop" … "layer-yield drift"`, :165) **바로 뒤**에 추가:
```bash
assert_seal_fires "old_assertion_revival" mut_old_assertion_revival "집필-위임 규약 토큰 drift"
assert_seal_fires "mp_heavy_row_drop"     mut_mp_heavy_row_drop     "역할×모델 매트릭스 봉인 붕괴"
assert_seal_fires "schema_required_drop"  mut_schema_required_drop  "state.json schema 위반"
```

**RED 실측:**
```bash
cd ~/.claude
bash setup/tests/seal-regression.test.sh 2>&1 | tail -6
```
Expected (RED):
```
✓ mutant[old_assertion_revival]: exit=1 (non-zero) + seal FAIL «집필-위임 규약 토큰 drift»
✗ mutant[mp_heavy_row_drop]: rc=0, missing «역할×모델 매트릭스 봉인 붕괴». tail: …
✗ mutant[schema_required_drop]: rc=0, missing «state.json schema 위반». tail: …
✓ live ~/.claude untouched (witness cksum stable across run)

seal-regression: PASS=24 FAIL=2
```
- **M21·M22 의 `rc=0` 이 핵심 판별자** — 표적을 지워도 현행 verify-setup 이 **통과**한다(= 판별력 공백의 실측 증거). 격리 replica 단독 실행으로 사전 확인한 결과도 동일하다(`HOME=<replica> bash <replica>/.claude/setup/verify-setup.sh` → 두 변이 모두 `rc=0`, `verify-setup: PASS=88 FAIL=0`).
- **M20 은 RED 가 아니라 ✓ 다 — 커버 백필임을 여기 명시한다.** 기존 #50 의 부정-단언 arm(`verify-setup.sh:575` — `if grep -q '위임 X' "$SK50" …; then C18_OK=0; fi`)이 이미 이 변이를 검출하므로, M20 은 "미탐 → 탐지"의 RED→GREEN 전이를 만들 수 없다. M20 이 해소하는 것은 **탐지력 공백이 아니라 변이-커버 공백**(C18 plan :484 정직 부기: "그 conjunct 자체의 회귀-탐지력은 이 사이클에서 실증되지 않는다")이다. 따라서 이 Step 의 Expected 는 **M20 ✓ / M21 ✗ / M22 ✗ = `PASS=24 FAIL=2`** 이며, `FAIL=3` 을 기대하면 거짓 실패가 난다.
- 판별자는 **위 문자열 Expected** 다 — 재현자가 `… | tail -6` 파이프라인이라 스위트의 종료코드는 `tail` 이 흡수한다(rc 단언 금지).

- [ ] **Step 2: GREEN — verify-setup 경화 3건 (#45 · #30 · #50)**

**⑴ seal #45 conjunct ① 행-선두 경화** (`setup/verify-setup.sh` :460). old (1줄):
```
{ [ -f "$MP_DOC" ] && grep -qE 'execute-strict.*opus' "$MP_DOC" && grep -qE 'explore-strict.*sonnet' "$MP_DOC"; } || MP_OK=0
```
new (주석 1줄 + 경화된 판정 1줄):
```
#     C19 §18.2 #14: conjunct ① 앵커를 **행-선두**로 구체화 — 광역 grep 은 'execute-strict.*opus' 6행
#     (:16/:17/:21/:29/:30/:37)·'explore-strict.*sonnet' 3행(:18/:31/:37)에 매칭해, 표적인 구현-행·탐색-행을
#     삭제해도 잔여 행이 GREEN 을 유지했다(판별력 공백). 변이 M21 이 그 RED 를 실증한다.
{ [ -f "$MP_DOC" ] && grep -qE '^\| 구현 heavy .*execute-strict.*opus' "$MP_DOC" && grep -qE '^\| 탐색 .*explore-strict.*sonnet' "$MP_DOC"; } || MP_OK=0
```
※ 신 앵커의 현행 매칭 수는 **각 1행**(실측: `grep -cE '^\| 구현 heavy .*execute-strict.*opus' docs/ai-context/model-policy.md` → `1`, `^\| 탐색 .*explore-strict.*sonnet` → `1`) — T2 의 :19 검증 행 치환 후에도 불변이다.

**⑵ seal #30 스키마 골격 conjunct 결합** (`setup/verify-setup.sh` :277). old (1줄):
```
[ -z "$ERR30" ] && ok "state.json ↔ schema 검증" || fail "state.json schema 위반: $ERR30"
```
new (주석 1줄 + 6줄 — **같은 `ok`/`fail` 로 결합하므로 호출 수 불변 = 카운트 88 불변**):
```
#     C19 §18.2 #13: 이 검사는 **스키마-구동**이라 스키마가 비면 검사도 빈다 — 골격 앵커 conjunct 를
#     같은 ok/fail 에 결합해 오라클 침묵을 봉인한다(변이 M22). 새 ok/fail 을 만들지 않으므로 카운트 불변.
SCH30="$HOME/.claude/state.schema.json"
SCHEMA30_OK=1
grep -q '"required"' "$SCH30" 2>/dev/null || SCHEMA30_OK=0
grep -q '"cycle"' "$SCH30" 2>/dev/null || SCHEMA30_OK=0
grep -q '"count"' "$SCH30" 2>/dev/null || SCHEMA30_OK=0
if [ -z "$ERR30" ] && [ "$SCHEMA30_OK" -eq 1 ]; then ok "state.json ↔ schema 검증"; else fail "state.json schema 위반: ${ERR30:-스키마 골격 앵커 결손(required·cycle·count — C19 #13)}"; fi
```
※ `${ERR30:-…}` 폴백 문안이 필요한 이유: M22 처럼 스키마만 약화된 경우 `ERR30` 은 **빈 문자열**이라(state.json 자체는 여전히 유효) fail 메시지가 근거 없이 비게 된다.

**⑶ seal #50 부정-단언 arm 확장** (`setup/verify-setup.sh`). 미러 arm 블록(:577-580 — `if [ -f "$MIR50" ]` ~ 그 닫는 `fi` :580)의 **직후이자** 판정 블록 `if [ "$C18_OK" -eq 1 ]; then`(:581) **직전**에 삽입:
```bash
# C19 §18.3: §18.4 가 create-orchestrator :24 의 위임-금지 단정을 소멸시킨 이후로는, 그 2파일에서의
# '위임 X' 부활도 start-rpi 와 **동일한 회귀**다 — 부정-단언 arm 을 정본+미러로 확장한다.
CO50="$HOME/.claude/skills/create-orchestrator-skill/SKILL.md"
MCO50="$HOME/.claude/opencode-harness/skill/create-orchestrator-skill/SKILL.md"
if grep -q '위임 X' "$CO50" 2>/dev/null; then C18_OK=0; fi
if [ -f "$MCO50" ] && grep -q '위임 X' "$MCO50" 2>/dev/null; then C18_OK=0; fi
```
같은 seal 의 `fail` 문안(:584)에서 `구 단정 '위임 X' 부활` 구절만 갱신 — old 부분 문자열:
```
또는 구 단정 '위임 X' 부활 — spec §17.1~§17.3
```
new:
```
또는 구 단정 '위임 X' 부활(start-rpi·create-orchestrator 정본+미러) — spec §17.1~§17.3, §18.3
```
※ `ok` 문안(:582)은 **불변** — M20 단언의 needle 은 `fail` 쪽 문자열(`집필-위임 규약 토큰 drift`)이며 이 갱신 후에도 그대로 포함된다.
※ **순서 전제 재확인**: 이 arm 은 T1 이 create-orchestrator 2파일의 `위임 X` 를 소멸시킨 뒤에만 GREEN 이다. T1 미완 상태로 여기 도달했다면 즉시 중단하고 T1 부터 수행한다.

**GREEN 실측:**
```bash
cd ~/.claude
bash setup/tests/seal-regression.test.sh 2>&1 | tail -3
bash setup/verify-setup.sh 2>&1 | tail -2
```
Expected:
```
seal-regression: PASS=26 FAIL=0
```
```
verify-setup: PASS=88 FAIL=0
```
※ 88 불변 확인 보조(호출 수 회귀 방지): `grep -cE '^\s*(ok|fail) "' setup/verify-setup.sh` → `67`(착수 기준선과 동일).

- [ ] **Step 3: 카운트 리터럴 · scaffold-registry 3행 동기**

**⑴ start-rpi-cycle :252 SKIP 예시 카운트** (LF — 파일 내 유일, 실측 `1`):
```bash
cd ~/.claude
perl -pi -e 's/직전 23\/0 유효/직전 26\/0 유효/' skills/start-rpi-cycle/SKILL.md
```
※ `README.md` 에는 seal-regression 카운트 앵커가 **존재하지 않는다**(README 선언은 `현재 N PASS`(verify-setup 88) · `N 케이스`(cases.tsv 291) · `N개 E2E`(8) 셋뿐 — C18 plan Step 3 실측 승계). 따라서 23→26 의 유일한 라이브 앵커가 이 1건이며, **README 는 무변경**이다.

**⑵ `docs/ai-context/scaffold-registry.md` 3행 갱신** — **CRLF 110/110 이므로 `perl -pi` 필수**(`sed -i`·Edit 금지). 각 치환의 old 는 파일 내 **유일 부분 문자열**(실측 각 `1`):
```bash
cd ~/.claude
perl -pi -e 's/state\.json ↔ schema draft-07 부분집합/state.json ↔ schema draft-07 부분집합 + 스키마 골격 앵커(required·cycle·count — C19 #13)/; s/\| cycle-28 \|/| cycle-28; **C19** 변이 M22 |/' docs/ai-context/scaffold-registry.md
perl -pi -e 's/skill 토큰\)/skill 토큰·매트릭스 행-선두 앵커(C19 #14))/; s/C11\/C12\/C13, \*\*C17\*\*/C11\/C12\/C13, **C17**; **C19** 변이 M21/' docs/ai-context/scaffold-registry.md
perl -pi -e "s/부정-단언\)/부정-단언(C19 create-orchestrator 정본+미러 확장))/; s/변이 M17·M18/변이 M17·M18·M20/" docs/ai-context/scaffold-registry.md
```
치환 후 3행(확인용 — `sed -n '68p;83p;88p' docs/ai-context/scaffold-registry.md`):
```
| #30 | state.json ↔ schema draft-07 부분집합 + 스키마 골격 앵커(required·cycle·count — C19 #13) | cycle-28; **C19** 변이 M22 |
| #45 | 역할×모델 매트릭스 물화 (model-policy.md 앵커·explore frontmatter·execute/review opus(C17)·`Agent\|Workflow` 매처·rpi-implement.js 토큰·skill 토큰·매트릭스 행-선두 앵커(C19 #14)) | C11/C12/C13, **C17**; **C19** 변이 M21 |
| #50 | 집필-위임 규약 토큰 봉인 (start-rpi-cycle 토큰 4종 · cross-family-review 긍정-구절 · opencode 미러 토큰 · 구 단정 '위임 X' 부정-단언(C19 create-orchestrator 정본+미러 확장)) | **C18 (cycle 69)**; 변이 M17·M18·M20 |
```

- [ ] **Step 4: 전수 검증 — 세 스위트 + 잔여 카운트 + 개행 보존**

```bash
cd ~/.claude
bash setup/verify-setup.sh 2>&1 | tail -2
bash setup/tests/seal-regression.test.sh 2>&1 | tail -2
bash hooks/tests/run-all.sh 2>&1 | tail -3
```
Expected:
```
verify-setup: PASS=88 FAIL=0
```
```
seal-regression: PASS=26 FAIL=0
```
```
Hook tests: 291 / 291 passed
cases.tsv <-> run-all 정합 OK (291 declared == 291 run, 비주석 실재)
Pass rate 100% — OK
```

잔여 카운트 드리프트 전수(**스코프 = 라이브 규약 파일 한정** — `docs/superpowers/` 의 `23/0` 은 착륙 시점 스냅샷 기록이라 동기 대상이 아니다):
```bash
cd ~/.claude
grep -rn '직전 23/0' skills/ opencode-harness/skill/ README.md ; echo "rc=$?"
grep -c '현재 88 PASS' README.md
```
Expected: 첫 grep 출력 **0줄 + `rc=1`** · 둘째 grep `1`(README 무변경 확인 — 88 리터럴 그대로).

개행 보존(CRLF 파일 혼합 개행 유입 0):
```bash
cd ~/.claude
printf 'registry lines=%s cr=%s\n' "$(grep -c '' docs/ai-context/scaffold-registry.md)" "$(tr -cd '\r' < docs/ai-context/scaffold-registry.md | wc -c)"
printf 'readme   lines=%s cr=%s\n' "$(grep -c '' README.md)" "$(tr -cd '\r' < README.md | wc -c)"
printf 'seal     lines=%s cr=%s\n' "$(grep -c '' setup/tests/seal-regression.test.sh)" "$(tr -cd '\r' < setup/tests/seal-regression.test.sh | wc -c)"
```
Expected: `registry lines=110 cr=110`(행 추가 없는 in-place 치환) · `readme   lines=547 cr=547`(무변경) · `seal     lines=198 cr=0`(LF 유지 — 증가분은 witness 1줄 in-place(+0) + make_replica 블록 6줄 + 뮤테이터 12줄(주석 3×3 + 함수 3) + 단언 3줄 = 177+21). lines=198 은 뮤테이터 주석 줄 수(3×3) 가정에 결합된 참고치 — 실질 게이트는 cr=0(LF 유지)뿐이며 주석 줄 수 변경 시 산술만 갱신한다.

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude
git add setup/tests/seal-regression.test.sh setup/verify-setup.sh skills/start-rpi-cycle/SKILL.md docs/ai-context/scaffold-registry.md
git commit -m "$(cat <<'EOF'
feat(c19): seal 판별력 경화 — 변이 M20~M22 + #45/#30/#50 in-place 경화 + 카운트 23→26

- M20: #50 부정-단언 arm 커버 백필(replica 정본에 '위임 X' 주입) — C18 plan :484 정직 부기 해소.
  기존 arm 이 이미 검출하므로 RED 아님(탐지력 공백이 아니라 변이-커버 공백의 해소)
- M21: model-policy 구현 heavy 행 삭제 → #45 RED. 구 광역 grep 은 6행/3행 매칭이라 표적 삭제에도
  GREEN 이었다(§18.2 #14 판별력 공백) → 앵커를 '^| 구현 heavy …'·'^| 탐색 …' 행-선두로 경화
- M22: state.schema.json 'required' 라인 제거 → #30 RED. 스키마-구동 검사는 스키마가 비면 검사도
  빈다(§18.2 #13 오라클 침묵) → 골격 앵커 conjunct(required·cycle·count)를 같은 ok/fail 에 결합
- #50 부정-단언 arm 을 create-orchestrator 정본+미러로 확장(§18.3 — §18.4 개정 후 동일 회귀)
- witness += state.schema.json·model-policy.md · make_replica += 미러 create-orchestrator 복제
  (arm 의 replica-vacuity 차단 — #43 선례)
- 카운트: verify-setup 88 불변(신규 seal 번호 0·ok/fail 67 불변) · seal-regression 23→26 ·
  run-all 291 불변. start-rpi :252 SKIP 예시 23/0→26/0 · scaffold-registry #30/#45/#50 행 갱신(CRLF perl)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

## 커밋 규율

- **브랜치**: `c19-review-economics`. task 당 1커밋(총 3). 메시지 = `feat(c19): …` + `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **스위트가 GREEN 이 아닌 상태로 커밋 금지** — 각 task 의 마지막 검증 스텝(T1 Step 5 · T2 Step 7 · T3 Step 4) Expected 가 커밋 전제다. T3 Step 1 의 `PASS=24 FAIL=2` 는 **task 내부 RED 창**이며 커밋 지점이 아니다(Step 2 GREEN 과 같은 커밋에 들어간다 — C18 T4 선례).
- task 순서 고정: T1 → T2 → T3. T3 를 T1 앞으로 옮기면 #50 확장 arm 이 즉시 FAIL 한다.

## 금지

- spec `docs/superpowers/specs/2026-07-25-model-policy-design.md` **§0~§17 수정 금지** — 유일 예외는 T2 Step 2 의 §15.3 헤딩 직후 **1줄 삽입**(§18.5 표가 명시). §15.3 본문·§16·§17 본문은 한 글자도 건드리지 않는다. §18 은 R 산출물로 이미 착륙 — plan 은 소비만.
- `hooks/**` · `hooks/tests/cases.tsv` · `workflows/rpi-implement.js` · `settings.json` **무터치**(run-all 291 불변 계약).
- **신규 seal 번호 발급 금지 · `ok`/`fail` 호출 수 변경 금지**(현행 67) — verify-setup 88 불변이 §18.5 카운트 계약이다.
- 규범 원문 3건(§18.4 정본 blockquote · §18.4 미러 blockquote · §18.3 전파-완결성 blockquote)의 **재서술·요약·재줄바꿈 금지** — 정본 :24 는 T1 Step 5 의 `VERBATIM-OK` diff 가, 미러 :24 와 전파-완결성 3줄은 같은 스텝의 **행 전문 `grep -F`** 가 기계 판별자다.
- `CONTEXT.md` 는 T2 Step 5 의 **1문장 append 외 무터치**(Phase R 완료분 — 용어 2건 기등록).
- CRLF·혼합-개행 파일에 `sed -i`·Edit·Write 사용 금지(spec · model-policy.md · scaffold-registry.md · README.md) — `perl` 만.
- §18.6 수용 잔여를 이 사이클에서 해소하려 들지 말 것: #50 확장 arm 의 미러-parity 변이(잔여 1) 신설 금지 · 번들 dangling `spec §` 참조 25건 제거·spec 동봉 금지(잔여 3) · 판정 2 를 "열화 없음"으로 승격 금지(잔여 2).
