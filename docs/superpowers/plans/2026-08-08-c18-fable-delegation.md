# C18 fable-delegation Implementation Plan (spec §17 착륙)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 69
**Started:** 2026-08-08

**Goal:** spec §17(C18 4레버 + 검증-계층 중복 감사 판정)의 규약을 skill·L1 문서·seal 로 착륙.

**Architecture:** L1 문서 3층 개정(start-rpi-cycle·closeout-pr-cycle·cross-family-review/model-policy) + opencode 미러 동형 + L3 신설 seal #50(문서-토큰 드리프트 봉인) + 변이 M17. **task 순서 = 문서 착륙(T1~T3) → seal(T4)** — 역순이면 seal #50 이 아직 없는 토큰을 요구해 verify-setup 이 사이클 내내 RED 로 남는다(중간 창이 FAIL 인 순서는 금지).

**Tech Stack:** markdown(L1) · bash(seal·변이) · perl -pi(CRLF 파일).

**Best-Direction Check:** 최선안 = §17 전체 착륙 + 신설 seal 봉인. 채택안 = 동일.
`DOWNGRADE-DECLARED(집필-위임 선적용 — 현행 SKILL.md 문면("메인이 직접")과 충돌하는 R/P/Closeout 절차를 C18 goal §1 사용자 승인 하에 사이클 내 선적용; C17 U4 선적용 동형)`.

## Global Constraints

- 세 검증 스위트는 **메인 포그라운드만** 실행.
- seal/드리프트 검사는 **bash 파일옵스만**(staged-safe).
- **CRLF 파일은 `sed -i` 금지 — `perl -pi`**. 실측 CRLF: `README.md`(547/547 라인 CR) · `docs/ai-context/model-policy.md`(38/38 라인 CR). 나머지 편집 대상(`skills/**/SKILL.md` · `opencode-harness/skill/**/SKILL.md` · `docs/ai-context/cross-family-review.md` · `setup/verify-setup.sh` · `setup/tests/seal-regression.test.sh`)은 CR=0(LF) — Edit 도구 사용 가능.
- `settings.json` 라이브 수정 금지 · schema 금지 · carrier `workflows/rpi-implement.js` **무수정** · spec `docs/superpowers/specs/2026-07-25-model-policy-design.md` **§0~§17 무수정**(§17 은 이미 착륙 — plan 은 소비만).
- `CONTEXT.md` 무터치(Phase R 완료분) · `hooks/` 무터치 · `skills/create-orchestrator-skill/SKILL.md` 무터치(§17.7 수용 잔여 1).
- 규범 원문(§17.1 서두 · §17.2 §2 문안)은 spec blockquote 를 **verbatim 전사** — 재서술·재줄바꿈 금지.
- 검증자 floor 매트릭스 v2 준수: 판단-게이트 `max(작업자, opus)` · 준수-확인 작업자 티어.
- Workflow (d) task 본문의 스위트 실행 라인은 **메인이 대행 실행 후 결과를 stage1 보고에 주입**(C17 운용 선례 명문화 — 서브에이전트 포그라운드 제약과 충돌 없음).
- Workflow (d) canonical carrier: stage1 `agentType:'execute-strict', model:'opus', effort:'high'`(T1~T3 = light 순수 문서) / `effort:'xhigh'`(T4 = heavy, setup/ 터치) · stage2 `agentType:'review-strict', model:'opus'` 명시 · schema 금지 · TDD-verbatim.
- **기준선 실측(2026-08-08, 착수 시점)**: verify-setup **87/0** · seal-regression **20/0** · run-all **291/291**.
- **예상 최종 카운트**: verify-setup **88/0**(δ=+1, seal #50) · seal-regression **21/0**(γ=+1, M17) · run-all **291/291**(δ=0 — 훅 무변경, 무회귀 확인용 1회).
- T1↔T4 가 `skills/start-rpi-cycle/SKILL.md` 를 공유(T4 는 카운트 리터럴 1건만) — carrier 가 파일 겹침 감지 시 자동 순차(의도됨).

---

### Task 1: start-rpi-cycle SKILL.md 3개소 + opencode 미러 (light)

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md` (①:14-15 서두 · ②:239-242 Step C-1 sub-step 6 · ③:315-317 Communication Protocol 말미)
- Modify: `opencode-harness/skill/start-rpi-cycle/SKILL.md` (①:14-15 서두 — 도구 표기 `` **`skill` 도구로 호출** `` 유지 · ②:233-235 sub-step 6 · ③:302-304 Communication Protocol 말미)

**Interfaces:**
- Produces: `집필-위임` · `FABLE-TAKEOVER` · `골격 계약` 토큰(정본 서두) + 미러 `FABLE-TAKEOVER` 토큰 — T4 seal #50 conjunct ①③의 앵커.
- Consumes: 없음.

- [x] **Step 1: RED — 신 토큰 부재 + 구 단정 실재 확인**

```bash
cd ~/.claude
grep -c '집필-위임' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -c 'FABLE-TAKEOVER' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -c '골격 계약' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -n '위임 X' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -c 'seal-regression' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
```

Expected (RED):
```
skills/start-rpi-cycle/SKILL.md:0
opencode-harness/skill/start-rpi-cycle/SKILL.md:0
```
(위 세 토큰 grep 전부 동일 — 6줄 모두 `:0`), 그리고
```
skills/start-rpi-cycle/SKILL.md:15:   sub-agent에 위임 X — 메인이 **Skill 도구로 호출**해 절차를 따름("절차 체화"가 아니라 실제 호출 — Closeout `phase-skills:` 로 선언).
opencode-harness/skill/start-rpi-cycle/SKILL.md:15:   sub-agent에 위임 X — 메인이 **`skill` 도구로 호출**해 절차를 따름("절차 체화"가 아니라 실제 호출 — Closeout `phase-skills:` 로 선언).
```
마지막 `seal-regression` grep 은 두 파일 모두 `:0`.

- [x] **Step 2: ① 정본 서두 개정 — §17.1 규범 원문 verbatim 전사**

`skills/start-rpi-cycle/SKILL.md` — old (:14-15, 2줄):
```
※ superpowers의 brainstorming / writing-plans / executing-plans는 모두 **메인 세션의 skill**.
   sub-agent에 위임 X — 메인이 **Skill 도구로 호출**해 절차를 따름("절차 체화"가 아니라 실제 호출 — Closeout `phase-skills:` 로 선언).
```
new (5줄 — spec :1909-1913 blockquote 에서 `  > ` 접두만 제거한 **byte-verbatim**, 들여쓰기 추가 금지):
```
※ superpowers의 brainstorming / writing-plans / executing-plans는 모두 **메인 세션의 skill** —
메인이 **Skill 도구로 호출**해 **절차를 따르고 결정(골격)을 소유**한다("절차 체화"가 아니라 실제
호출 — Closeout `phase-skills:` 로 선언). **전문(prose) 집필은 opus 집필-위임 가능**(골격 계약
필수 · 재작성 ≤2회 · 초과 시 FABLE-TAKEOVER 폴백 — spec §17.1). 위임되는 것은 집필이지 절차
준수·결정·판정이 아니다.
```
:16(`   sub-agent 위임은 explore-strict / review-strict / execute-strict (우리 wrapper)만.`)는 **불변**(편집 후 :19 로 행번호만 이동).

`opencode-harness/skill/start-rpi-cycle/SKILL.md` — old (:14-15):
```
※ superpowers의 brainstorming / writing-plans / executing-plans는 모두 **메인 세션의 skill**.
   sub-agent에 위임 X — 메인이 **`skill` 도구로 호출**해 절차를 따름("절차 체화"가 아니라 실제 호출 — Closeout `phase-skills:` 로 선언).
```
new (동일 5줄, **1행의 도구 표기만** `` **`skill` 도구로 호출** `` 로 치환 — 그 외 문안 byte-동일):
```
※ superpowers의 brainstorming / writing-plans / executing-plans는 모두 **메인 세션의 skill** —
메인이 **`skill` 도구로 호출**해 **절차를 따르고 결정(골격)을 소유**한다("절차 체화"가 아니라 실제
호출 — Closeout `phase-skills:` 로 선언). **전문(prose) 집필은 opus 집필-위임 가능**(골격 계약
필수 · 재작성 ≤2회 · 초과 시 FABLE-TAKEOVER 폴백 — spec §17.1). 위임되는 것은 집필이지 절차
준수·결정·판정이 아니다.
```
미러 :16 도 불변.

- [x] **Step 3: ② sub-step 6 조건부 규약 + ③ Communication Protocol 1줄**

`skills/start-rpi-cycle/SKILL.md` sub-step 6 — 현행 마지막 줄(`   → 하네스 수정 사이클이면 **run-log 요약도 소비**(GAP-003): … 파일 부재 시 생략.`) **바로 뒤에** 1줄 추가:
```
   → **seal-regression 조건부 실행(C18 spec §17.5 ③)**: `setup/verify-setup.sh`·`setup/tests/` **및 seal-regression 입력 집합(witness/뮤테이터 앵커 — SSOT 는 그 스크립트 자신)**이 이번 사이클 diff 에 있으면 `bash ~/.claude/setup/tests/seal-regression.test.sh` **full 실행 필수**, 없으면 `SKIP(사유: setup/+입력 집합 diff 0 — 직전 20/0 유효)` 허용(탐지력 불변은 **입력 집합 전체** 무변경일 때만 성립 — 앵커 파일 다수가 비-setup 이라 setup/-한정 판단은 vacuous 창을 연다. 의심스러우면 full 실행이 기본). **SKIP 시 그 사유를 `layer-yield:` 필드에 기재**.
```

같은 파일 `## Communication Protocol` 절 **말미**(`  생략 = 구조적 불완전. [C16 spec §15.3]` 뒤)에 1줄 추가:
```
※ **집필-위임 (C18 spec §17.4)**: Closeout 한국어 보고·PR body 는 구조화 데이터(검증 수치·layer-yield 행·토큰 집계·goal 대조표)를 넘겨 **opus 가 초안을 작성하고 메인이 감수·개정한 뒤 발화**할 수 있다 — 초안은 자재이지 판정이 아니며, 사용자 커뮤니케이션 책임·발화는 메인에서 이전되지 않는다(CLAUDE.md §7 한국어 규약 포함).
```

같은 파일 `layer-yield:` **필드 정의**(:315-317 — `  생략 = 구조적 불완전. [C16 spec §15.3]` 직전 줄)에 1구절 추가 — 정의 마지막 줄(`  (상태 enum·호출 수 병기·실발견 정의는 Step C-1 sub-step 9). 동일 행을 글로벌 review-yield.md 대장에 축적.`) 뒤에 삽입:
```
  **FABLE-TAKEOVER·FABLE-ESCALATION 발동은 layer-yield 1행 부기 + 보고 표면화 의무**(TAKEOVER 2산출물 연속 = 사용자 보고 — spec §17.1).
```
미러(`opencode-harness/skill/start-rpi-cycle/SKILL.md` :302-304)도 동형 1구절(같은 문안 — 토큰명 동일).

`opencode-harness/skill/start-rpi-cycle/SKILL.md` sub-step 6 — 현행 마지막 줄(`   → 결과는 Communication Protocol \`harness-verify:\` **전용 필드**로 보고(복합 evidence에 접지 않음 — 누락 시 구조적 불완전).`) 뒤에 1줄 추가(**정본과 규약 내용이 다른 이유를 명시** — opencode 번들에는 verify-setup seal 과 그 변이 메타-테스트가 부재해 조건부 스킵의 대상 자체가 없다):
```
   → **seal-regression 조건부 스킵(C18 spec §17.5 ③)은 정본 하네스(`~/.claude`) 전용** — opencode 번들에는 verify-setup seal 도, 그 변이 메타-테스트(seal-regression)도 대응물이 없다. 위 스위트는 1차 검증이라 조건부 스킵 대상이 아니며 하네스 수정 사이클이면 항상 full 실행.
```

미러 `## Communication Protocol` 말미(`  생략 = 구조적 불완전. [C16 spec §15.3]` 뒤)에 정본과 동일 1줄 추가(단 `CLAUDE.md §7` → `AGENTS.md §7` — 미러 전반의 명칭 규약):
```
※ **집필-위임 (C18 spec §17.4)**: Closeout 한국어 보고·PR body 는 구조화 데이터(검증 수치·layer-yield 행·토큰 집계·goal 대조표)를 넘겨 **opus 가 초안을 작성하고 메인이 감수·개정한 뒤 발화**할 수 있다 — 초안은 자재이지 판정이 아니며, 사용자 커뮤니케이션 책임·발화는 메인에서 이전되지 않는다(AGENTS.md §7 한국어 규약 포함).
```

- [x] **Step 4: GREEN — 토큰 존재 + verbatim diff + 스위트**

```bash
cd ~/.claude
grep -c '집필-위임' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -c 'FABLE-TAKEOVER' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -c '골격 계약' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -c '위임 X' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -c 'seal-regression' skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
```
Expected (GREEN): 앞 세 grep 은 두 파일 모두 `:1` 이상(`집필-위임` 은 정본 `:2` — 서두 + Communication Protocol, 미러도 `:2`), `위임 X` 는 **두 파일 모두 `:0`**(구 단정 소멸), `seal-regression` 은 두 파일 모두 `:1`.

verbatim 전사 검증(정본만 — 미러는 도구 표기 차이로 그대로는 diff 불성립). **앵커-기반 추출**을 쓴다 — spec §17 은 정정 사이클마다 행이 밀리므로 `sed -n 'N,Mp'` 행번호 하드코딩은 즉시 스테일이 된다:
```bash
diff <(awk '/^  > ※ superpowers의/,/^  > 준수·결정·판정이 아니다/' docs/superpowers/specs/2026-07-25-model-policy-design.md | sed 's/^  > //') \
     <(awk '/^※ superpowers의/,/^준수·결정·판정이 아니다/' skills/start-rpi-cycle/SKILL.md) && echo "VERBATIM-OK"
```
Expected: `VERBATIM-OK` (diff 출력 0줄 — 양쪽 5줄).

미러 문안 검증(**도구 표기 정규화 후 5줄 전체 diff** — 구 "1개 hunk" 서술은 삭제. 1행을 포함한 전 구간을 대조하므로 판별력이 더 높다):
```bash
diff <(awk '/^  > ※ superpowers의/,/^  > 준수·결정·판정이 아니다/' docs/superpowers/specs/2026-07-25-model-policy-design.md | sed -e 's/^  > //' -e 's/\*\*Skill 도구로 호출\*\*/**`skill` 도구로 호출**/') \
     <(awk '/^※ superpowers의/,/^준수·결정·판정이 아니다/' opencode-harness/skill/start-rpi-cycle/SKILL.md) && echo "MIRROR-VERBATIM-OK"
```
Expected: `MIRROR-VERBATIM-OK` (diff 출력 0줄).

seal 무회귀(#17 §3↔Phase R 도구 어휘 — Phase R 도구 목록 무변경이므로 green 유지; #18·#19·#22·#35·#45·#48·#49 도 편집 구간 밖):
```bash
bash setup/verify-setup.sh 2>&1 | tail -2
```
Expected: `verify-setup: PASS=87 FAIL=0` (δ=0 — seal #50 은 T4 에서 신설).

- [x] **Step 5: 커밋**

```bash
cd ~/.claude
git add skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
git commit -m "$(cat <<'EOF'
feat(c18): start-rpi-cycle 서두 §17.1 규범 착륙 + seal-regression 조건부 + 초안-위임 1줄 (미러 동형)

- :14-15 위임-금지 단정 → §17.1 규범 원문 verbatim(골격 계약·≤2회·FABLE-TAKEOVER), :16 wrapper 목록 불변
- Step C-1 sub-step 6: seal-regression 조건부 실행 규약(spec §17.5 ③) + SKIP 사유 layer-yield 기재
- Communication Protocol: 보고·PR body 집필-위임 1줄(spec §17.4 — 책임·발화는 메인)
- opencode 미러 동형(도구 표기 `skill` 유지 · seal-regression 은 대응물 부재로 N/A 명시)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: closeout-pr-cycle SKILL.md + opencode 미러 (light)

**Files:**
- Modify: `skills/closeout-pr-cycle/SKILL.md` (Phase 4 교차패밀리 분기 뒤 :159 다음 · **트리아지 문안 :158** · Phase 1 Local Gate :39 다음 · **Phase 2 PR body :78 다음**)
- Modify: `opencode-harness/skill/closeout-pr-cycle/SKILL.md` (Phase 4 :163 다음 · **트리아지 문안 :162** · Phase 1 :39 다음 · **Phase 2 PR body :78 다음**)

**Interfaces:**
- Produces: `정정-위임 미니-사이클` 규약 문안(§17.3) + Phase 1 스위트 조건부 주석(§17.5 ③) + **`2단계 트리아지` 토큰(§17.2 — Phase 4 트리아지 문안)** + **PR body 집필-위임 1줄(§17.4)**.
- Consumes: T1 이 sub-step 6 에 세운 조건부 규약(Phase 1 주석이 그 SSOT 를 참조). T3 이 착륙시킬 `cross-family-review.md` §2 규범(트리아지 문안이 그 SSOT 를 참조 — 문서 참조이지 실행 의존은 아님).

- [x] **Step 1: RED — 신 토큰 부재 확인**

```bash
cd ~/.claude
grep -c '정정-위임' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c '미니-사이클' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c '편집-주체' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c 'seal-regression' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c '2단계 트리아지' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c 'plan Status 헤더' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c '메인 세션이 원문 실측 대조' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -n 'advisory fail-open' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
```

Expected (RED): `정정-위임`·`미니-사이클`·`편집-주체`·`seal-regression`·`2단계 트리아지`·`plan Status 헤더` 여섯 grep 이 두 파일 모두 `:0` (총 12줄 `:0`), `메인 세션이 원문 실측 대조`(구 문안)는 두 파일 모두 **`:1`**, 마지막 grep 은 삽입 앵커 실재 확인:
```
skills/closeout-pr-cycle/SKILL.md:159:3. **불가 시**: SKIP + 사유 1줄 기록(비차단 — advisory fail-open).
opencode-harness/skill/closeout-pr-cycle/SKILL.md:163:3. **불가 시**: SKIP + 사유 1줄 기록(비차단 — advisory fail-open).
```

- [x] **Step 2: Phase 4 — 트리아지 문안 2단계화 + 정정-위임 미니-사이클 규약 삽입**

**⑴ 트리아지 문안 2단계화 (spec §17.2 — SKILL.md 가 구 1단계 문면을 그대로 들고 있으면 cross-family-review.md 개정과 SSOT 역전)**. `skills/closeout-pr-cycle/SKILL.md` :158 의 부분 문자열만 치환:
```
발견은 **메인 세션이 원문 실측 대조 후 REAL/기각 트리아지**
```
→
```
발견은 **2단계 트리아지**(증거 수집 opus 위임 가능·최종 판정 메인 — cross-family-review.md §2, spec §17.2)
```
`opencode-harness/skill/closeout-pr-cycle/SKILL.md` :162 도 **동형 치환**(두 파일의 해당 문장은 byte-동일).

**⑵ 미니-사이클 블록 삽입.** `skills/closeout-pr-cycle/SKILL.md` — 교차패밀리 분기 마지막 줄(`3. **불가 시**: SKIP + 사유 1줄 기록(비차단 — advisory fail-open).`)과 `# Phase 5 — User Approval Gate` **사이**에 아래 블록 삽입(앞뒤 빈 줄 1개씩):

```
**정정-위임 미니-사이클 (C18 spec §17.3)**:
트리아지(내부 발견·교차패밀리 REAL 판정)가 확정된 뒤의 정정은 메인이 직접 편집하지 않고 미니-사이클로 수행한다:
1. **task 목록화 — 메인**: 발견별 정정 대상 파일·절·수용 기준을 열거(판정은 이미 확정된 상태로 넘긴다).
2. **execute-strict(opus) 실행**: 목록 단위 위임 — plan task 본문 TDD-verbatim 전달 규약 동일.
3. **review-strict(opus) 검증**: 정정 diff + **관련 스위트 재실행 결과**를 근거로 판정.
4. **메인 승인**: 판정 주권은 이전되지 않는다.

- **델타 재심(§15.4) 스코프 불변**: 미니-사이클은 정정 *실행 주체*의 교체이지 재심 스코프의 변경이 아니다 — 재심은 여전히 "정정이 편집한 파일/절에 한정해 원 기준 재적용".
- **예외 — 메인 직접 편집 허용 (편집-주체 축, 시점 무관)**: 위임 왕복 비용이 편집 자체보다 비싼 **선언적 기계 편집** 4건 — ⓐ`CLAUDE.md` §3 ⓑlayer-yield append ⓒplan 체크박스·plan Status 헤더 ⓓ`state.json`(spec §17.3). **D5(머지-전 창) 허용 집합은 ⓐⓑ 2건으로 불변** — ⓒⓓ를 그 창의 허용 편집으로 읽는 것은 오독이며, 그 창의 판정은 §16.3-2 D5 가 계속 지배한다.
```

`opencode-harness/skill/closeout-pr-cycle/SKILL.md` — 동일 위치(:163 뒤, `# Phase 5` 앞)에 동일 블록 삽입, 단 ⓐ의 명칭만 미러 규약대로 `AGENTS.md` §3(같은 파일 :153 이 이미 `AGENTS.md §3` 표기):

```
**정정-위임 미니-사이클 (C18 spec §17.3)**:
트리아지(내부 발견·교차패밀리 REAL 판정)가 확정된 뒤의 정정은 메인이 직접 편집하지 않고 미니-사이클로 수행한다:
1. **task 목록화 — 메인**: 발견별 정정 대상 파일·절·수용 기준을 열거(판정은 이미 확정된 상태로 넘긴다).
2. **execute-strict(opus) 실행**: 목록 단위 위임 — plan task 본문 TDD-verbatim 전달 규약 동일.
3. **review-strict(opus) 검증**: 정정 diff + **관련 스위트 재실행 결과**를 근거로 판정.
4. **메인 승인**: 판정 주권은 이전되지 않는다.

- **델타 재심(§15.4) 스코프 불변**: 미니-사이클은 정정 *실행 주체*의 교체이지 재심 스코프의 변경이 아니다 — 재심은 여전히 "정정이 편집한 파일/절에 한정해 원 기준 재적용".
- **예외 — 메인 직접 편집 허용 (편집-주체 축, 시점 무관)**: 위임 왕복 비용이 편집 자체보다 비싼 **선언적 기계 편집** 4건 — ⓐ`AGENTS.md` §3 ⓑlayer-yield append ⓒplan 체크박스·plan Status 헤더 ⓓ`state.json`(spec §17.3). **D5(머지-전 창) 허용 집합은 ⓐⓑ 2건으로 불변** — ⓒⓓ를 그 창의 허용 편집으로 읽는 것은 오독이며, 그 창의 판정은 §16.3-2 D5 가 계속 지배한다.
```

- [x] **Step 3: Phase 1 Local Gate — 스위트 조건부 주석 1줄**

`skills/closeout-pr-cycle/SKILL.md` — runbook 로드 불릿 마지막 줄(`- 없으면: 사용자에게 "local check 명령을 알려주세요" 확인`) **바로 뒤에** 1줄 추가(빈 줄 앞에):
```
※ **하네스 사이클 스위트 규약 (C18 spec §17.5 ③)**: `setup/tests/seal-regression.test.sh` 는 조건부 — `setup/verify-setup.sh`·`setup/tests/` **및 seal-regression 입력 집합(witness/뮤테이터 앵커 — SSOT 는 그 스크립트 자신)**이 사이클 diff 에 있으면 full 실행 필수, 없으면 SKIP 허용(SKIP 사유는 `layer-yield:` 기재 — "setup/+입력 집합 diff 0"). 규약 본문 SSOT = start-rpi-cycle Step C-1 sub-step 6.
```

`opencode-harness/skill/closeout-pr-cycle/SKILL.md` — 동일 위치에 미러 사실 반영 1줄:
```
※ **하네스 사이클 스위트 규약 (C18 spec §17.5 ③)**: seal-regression 조건부 스킵은 정본 하네스(`~/.claude`) 전용 — opencode 번들에는 verify-setup seal 도 그 변이 메타-테스트도 대응물이 없어 조건부 스킵 대상이 아니다. 번들 스위트(`node --test tests/*.test.mjs` + `_oracle/`)는 하네스 수정 사이클이면 항상 full 실행.
```

- [x] **Step 3b: Phase 2 — PR body 집필-위임 1줄 (spec §17.4)**

`skills/closeout-pr-cycle/SKILL.md` :78(`PR body가 자동 생성(`--fill`)으로 부족하면 보완 제안 후 사용자 확인.`) **바로 뒤에** 1줄 추가:
```
※ PR body 는 집필-위임 가능(구조화 데이터→opus 초안→메인 감수 — spec §17.4; fable 세션 기본 경로).
```
`opencode-harness/skill/closeout-pr-cycle/SKILL.md` :78 도 동형 1줄(문안 동일 — 이 문장에는 CLAUDE/AGENTS 명칭이 없어 미러 치환 불요).

- [x] **Step 4: GREEN — 토큰 존재 + 스위트**

```bash
cd ~/.claude
grep -c '정정-위임' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c '미니-사이클' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c '편집-주체' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c 'seal-regression' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c '2단계 트리아지' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c 'plan Status 헤더' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c '메인 세션이 원문 실측 대조' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c '집필-위임 가능' skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
grep -c 'AGENTS.md' skills/closeout-pr-cycle/SKILL.md
grep -c 'CLAUDE.md' opencode-harness/skill/closeout-pr-cycle/SKILL.md
```
Expected (GREEN):
- `정정-위임` = 두 파일 `:1`
- `미니-사이클` = 두 파일 `:3`(제목 1 + 도입문 1 + 델타 재심 불릿 1 — 삽입 블록 실측)
- `편집-주체` = 두 파일 `:1`
- `seal-regression` = 정본 `:1` · 미러 `:1`
- `2단계 트리아지` = 두 파일 `:1`(Phase 4 트리아지 문안) · `메인 세션이 원문 실측 대조` = 두 파일 **`:0`**(구 1단계 문면 소멸)
- `plan Status 헤더` = 두 파일 `:1`(ⓒ 확장 — spec §17.3 S5 와 동기. 이 판별자가 없으면 ⓒ를 구 "plan 체크박스" 단독으로 착륙시켜도 GREEN 이 통과한다)
- `집필-위임 가능` = 두 파일 `:1`(Phase 2 PR body 1줄)
- `AGENTS.md` in 정본 = `0`(미러 명칭 누출 없음) · `CLAUDE.md` in 미러 = `0`(정본 명칭 누출 없음)

```bash
bash setup/verify-setup.sh 2>&1 | tail -2
```
Expected: `verify-setup: PASS=87 FAIL=0` (#48 `실재하는` 선언·#29 skill 목록 등 무회귀).

- [x] **Step 5: 커밋**

```bash
cd ~/.claude
git add skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
git commit -m "$(cat <<'EOF'
feat(c18): closeout Phase 4 2단계 트리아지+정정-위임 미니-사이클 + Phase 1/2 규약 1줄 (미러 동형)

- Phase 4 트리아지 문안: 구 1단계 "메인이 원문 실측 대조" → 2단계 트리아지(증거 수집 위임 가능·판정 메인, spec §17.2)
- Phase 2 PR body: 집필-위임 가능 1줄(spec §17.4 — fable 세션 기본 경로)
- Phase 4 교차패밀리 분기 뒤: 목록화(메인)→execute-strict(opus)→review-strict(opus)→메인 승인 (spec §17.3)
- 델타 재심 §15.4 스코프 불변 명시 + 편집-주체 예외 4건(ⓐⓑⓒⓓ) vs D5 머지-전 창 2건 분리
- Phase 1 Local Gate: seal-regression 조건부 주석(SSOT = start-rpi-cycle sub-step 6, spec §17.5 ③)
- opencode 미러 동형(AGENTS.md 명칭 · 대응 스위트 부재 사실 반영)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: cross-family-review.md §2 + model-policy.md §1 (light)

**Files:**
- Modify: `docs/ai-context/cross-family-review.md` (§2 트리아지 규범 :43 · **슬롯 1 발견 처리 :52** — LF 파일, Edit 가능)
- Modify: `docs/ai-context/model-policy.md` (§1 매트릭스 :20 뒤 1행 추가 — **CRLF 파일, `perl -pi` 필수**)

**Interfaces:**
- Produces: `판정은 메인` · `증거 수집` 토큰(cross-family-review) — T4 seal #50 conjunct ②의 앵커. **`미니-사이클` 포인터(:52 슬롯 1 발견 처리 — §17.3 정정-주체)**. `집필·대조·정정` 행(model-policy §1).
- Consumes: 없음.

- [x] **Step 1: RED — 신 토큰 부재 + 구 문안 실재 확인**

```bash
cd ~/.claude
grep -c '판정은 메인' docs/ai-context/cross-family-review.md
grep -c '증거 수집' docs/ai-context/cross-family-review.md
grep -c '2단계 트리아지' docs/ai-context/cross-family-review.md
grep -c '미니-사이클' docs/ai-context/cross-family-review.md
grep -c '집필·대조·정정' docs/ai-context/model-policy.md
grep -n '★메인 세션 트리아지 필수' docs/ai-context/cross-family-review.md
grep -n 'REAL 이면 spec/plan 정정' docs/ai-context/cross-family-review.md
```
Expected (RED): 앞 다섯 grep 전부 `0`. 마지막 두 grep 은 삽입 앵커 실재 확인:
```
43:- **★메인 세션 트리아지 필수**: 타 패밀리 발견은 그대로 편입 금지 — 발견마다 원문 실측 대조 후 REAL/기각 판정(첫 실행 14건 중 4건이 스코프 오독). 편입 기준은 Claude 발견과 동일(인용+실측). **GPT는 추가 발견자이지 판정자가 아니다.**
```
```
52:- **슬롯 1 발견 처리**: 슬롯 1 발견은 메인 트리아지 후 REAL 이면 spec/plan 정정 → **Gate P 델타 재심**(§15.4)을 Phase I 착수 전에 통과해야 한다 — Gate P PASS 는 슬롯 1 REAL 정정에 의해 잠정화된다.
```

- [x] **Step 2: cross-family-review.md :43 → §17.2 규범 원문 verbatim 전사**

old (:43, 1줄 — 선행 `- ` 불릿 마커 포함):
```
- **★메인 세션 트리아지 필수**: 타 패밀리 발견은 그대로 편입 금지 — 발견마다 원문 실측 대조 후 REAL/기각 판정(첫 실행 14건 중 4건이 스코프 오독). 편입 기준은 Claude 발견과 동일(인용+실측). **GPT는 추가 발견자이지 판정자가 아니다.**
```
new (6줄 — spec :1937-1942 blockquote 에서 `  > ` 접두만 제거한 **byte-verbatim** 본문에, 이 파일의 불릿 규약대로 1행에만 `- ` 마커를 붙이고 2~6행은 `  `(2칸) 연속 들여쓰기 — 파일 내 :44-46 불릿의 기존 연속행 스타일과 동일):
```
- **★트리아지 필수 — 판정은 메인, 증거 수집은 위임 가능**: 타 패밀리 발견은 그대로 편입 금지 —
  발견마다 원문 실측 대조 후 REAL/기각 판정(첫 실행 14건 중 4건이 스코프 오독). **1단계 증거
  수집(원문 인용 실재·코드/문서 실측 대조·REAL/기각 권고+근거)은 opus review-strict 위임 가능**
  (발견 묶음 단위 병렬 허용), **2단계 최종 판정은 메인** — 권고 뒤집기 자유(2단계 트리아지,
  spec §17.2). 편입 기준은 Claude 발견과 동일(인용+실측). **GPT는 추가 발견자이지 판정자가
  아니다(불변).**
```

- [x] **Step 2b: cross-family-review.md :52 — 슬롯 1 발견 처리에 정정-주체 포인터**

§17.3 이 정정의 *실행 주체* 를 교체했는데 :52 는 "spec/plan 정정"의 주체를 여전히 무언(=메인 직접 함축)으로 둔다 — 슬롯 1 경로에서 미니-사이클이 우회되는 문면 공백. **부분 문자열만** 치환한다(문장 나머지·`Gate P 델타 재심` 규약 불변):

old 앵커(:52 내부):
```
REAL 이면 spec/plan 정정 → **Gate P 델타 재심**
```
new:
```
REAL 이면 spec/plan 정정(**§17.3 정정-위임 미니-사이클로** — 목록화 메인·실행 opus·검증 opus·승인 메인) → **Gate P 델타 재심**
```

- [x] **Step 3: model-policy.md §1 매트릭스 1행 추가 (CRLF — perl -pi)**

`| 교차 검증 (고-스테이크 closeout) | …` 행(:20) **바로 뒤**에 새 행 삽입. `sed -i` 금지(CRLF 38/38):
```bash
cd ~/.claude
perl -pi -e 'BEGIN{ $row = "| 집필·대조·정정 (판단-전용화 3종 — 문서 전문/교차패밀리 증거 수집/리뷰 발견 편집) | execute-strict·review-strict | **opus** (frontmatter 기본) | 상속 | C18 spec §17.1~17.3 — 골격 계약·재작성 ≤2회·FABLE-TAKEOVER 폴백·판정은 메인 불이전 |\r\n" } $_ .= $row if /^\| 교차 검증 \(고-스테이크 closeout\)/;' docs/ai-context/model-policy.md
```

- [x] **Step 4: GREEN — 토큰 존재 + verbatim diff + CRLF 보존 + 스위트**

```bash
cd ~/.claude
grep -c '판정은 메인' docs/ai-context/cross-family-review.md
grep -c '증거 수집' docs/ai-context/cross-family-review.md
grep -c '2단계 트리아지' docs/ai-context/cross-family-review.md
grep -c '판정자가' docs/ai-context/cross-family-review.md
grep -c '미니-사이클' docs/ai-context/cross-family-review.md
grep -c 'Gate P 델타 재심' docs/ai-context/cross-family-review.md
grep -c '집필·대조·정정' docs/ai-context/model-policy.md
grep -c 'FABLE-TAKEOVER' docs/ai-context/model-policy.md
```
Expected (GREEN): `판정은 메인`=**2** · `증거 수집`=1 · `2단계 트리아지`=1 · `판정자가`=1 · `미니-사이클`=**1**(:52 포인터 — Step 2b) · `Gate P 델타 재심`=**1 불변**(부분 치환이라 재심 규약 무손) · `집필·대조·정정`=1 · `FABLE-TAKEOVER`=1.
※ `판정은 메인`=2 인 이유(실측): 규범 원문이 그 문자열을 **두 번** 포함한다 — 1행 `판정은 메인, 증거 수집은 위임 가능` + 4행 `**2단계 최종 판정은 메인**`. 1 을 기대하면 GREEN 이 거짓 FAIL 난다.
※ 검색어가 `판정자가 아니다`(구 문안)가 **아니라** `판정자가` 인 이유(실측): 신 문안은 spec 의 줄바꿈을 verbatim 유지하므로 `판정자가` / `아니다(불변).` 가 서로 다른 행에 걸린다 — 행-지향 grep 은 `판정자가 아니다` 를 **0** 으로 센다. seal #50 이 이 문자열을 앵커로 쓰지 않음은 실측 확인됨(`grep -rn '판정자' setup/ hooks/` → 출력 0줄).

verbatim 전사 검증(2칸 연속 들여쓰기·불릿 마커를 되돌린 뒤 spec 원문과 대조). **앵커-기반 추출**(P6 과 동일 이유 — spec 행번호 하드코딩 금지):
```bash
diff <(awk '/^  > \*\*★트리아지 필수/,/^  > 아니다\(불변\)/' docs/superpowers/specs/2026-07-25-model-policy-design.md | sed 's/^  > //') \
     <(awk '/^- \*\*★트리아지 필수/,/^  아니다\(불변\)/' docs/ai-context/cross-family-review.md | sed -e '1s/^- //' -e '2,$s/^  //') && echo "VERBATIM-OK"
```
Expected: `VERBATIM-OK` (diff 출력 0줄 — 양쪽 6줄).

CRLF 보존 검증(라인 수 == CR 바이트 수 — 혼합 개행 유입 차단):
```bash
printf 'lines=%s cr=%s\n' "$(grep -c '' docs/ai-context/model-policy.md)" "$(tr -cd '\r' < docs/ai-context/model-policy.md | wc -c)"
```
Expected: `lines=39 cr=39` (착수 기준선 38/38 → +1행).

```bash
bash setup/verify-setup.sh 2>&1 | tail -2
```
Expected: `verify-setup: PASS=87 FAIL=0` (#45 conjunct ①이 `model-policy.md` 의 `execute-strict.*opus`/`explore-strict.*sonnet` 앵커를 계속 찾음 — 신규 행은 기존 행 뒤 추가라 무회귀).

- [x] **Step 5: 커밋**

```bash
cd ~/.claude
git add docs/ai-context/cross-family-review.md docs/ai-context/model-policy.md
git commit -m "$(cat <<'EOF'
feat(c18): cross-family-review §2 2단계 트리아지 + model-policy §1 판단-전용화 행

- cross-family-review:43 → §17.2 규범 원문 verbatim (1단계 증거 수집=opus review-strict 위임 가능·
  묶음 단위 병렬 / 2단계 최종 판정=메인·권고 뒤집기 자유; GPT는 판정자가 아니다(불변))
- model-policy §1 매트릭스: 집필·대조·정정 3종 행 추가(execute/review-strict · opus frontmatter 기본 · 상속)
- model-policy.md 는 CRLF — perl -pi 로 편집(개행 혼입 0 검증)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: seal #50 신설 + 변이 M17 + 카운트 동기 (heavy — T1~T3 완료 후, setup/ 터치)

**Phase P 판단(§17.6 마지막 행) 확정: 신설 seal 채택.** 근거: §17.7-2 가 hook 강제 불가를 수용한 규약이라 **문서-토큰 드리프트 seal 이 유일한 물리 봉인**이다(seal #49 layer-yield 선례 동형 — skill 재생성·문서 재작성으로 규약 문면이 소실되면 그 자리에서 표면화).

**Files:**
- Modify: `setup/verify-setup.sh` (seal #50 신설 — 현행 seal #49 블록 끝 :550 과 seal #36 총계 블록 :552 **사이**. #36 이 `EXPECTED_TOTAL=$((PASS + FAIL + 1))` 로 자기-카운트하므로 #50 은 반드시 #36 **앞**에 배치 — seal #37 주석 "(#36 앞에 배치 = 총계 포함.)" 선례)
- Modify: `setup/tests/seal-regression.test.sh` (M17 변이 + `make_replica` 미러 복제 1블록)
- Modify: `README.md:300` (`현재 87 PASS` → `현재 88 PASS` — **CRLF 파일, `perl -pi` 필수**)
- Modify: `skills/start-rpi-cycle/SKILL.md` (T1 이 착륙시킨 `직전 20/0 유효` 리터럴 → `직전 21/0 유효` — 카운트 동기)

**Interfaces:**
- Produces: seal #50(conjunctive 4항 — ①정본 토큰 3종 ②cross-family 토큰 2종 ③미러 parity ④구 '위임 X' 부정-단언) · 변이 M17 · 카운트 87→88 / 20→21.
- Consumes: T1 이 세운 `집필-위임`·`FABLE-TAKEOVER` 토큰(정본+미러), T3 이 세운 `판정은 메인`·`증거 수집` 토큰.

- [x] **Step 1: RED — 변이 M17 을 seal 보다 먼저 넣어 "현재 미탐지"를 실측**

RED 재현자는 라이브 파일 변이가 아니라 **seal-regression 의 격리 replica**(`mktemp -d` + `HOME=<replica>`)를 쓴다 — 라이브 `~/.claude` 는 witness cksum 으로 불변 증명됨.

`setup/tests/seal-regression.test.sh` — ① `make_replica` 안, ui-design 미러 복제 블록(`  # v3: replicate opencode mirror …` ~ `  fi`) **바로 뒤**에 삽입:
```bash
  # C18: seal #50 conjunct ③(미러 parity)이 비교하는 파일 — 미복제 시 그 conjunct 가 replica 에서
  # vacuous 가 된다(#43 design.md 복제와 동형 이유).
  if [ -f "$SRC/opencode-harness/skill/start-rpi-cycle/SKILL.md" ]; then
    mkdir -p "$C/opencode-harness/skill/start-rpi-cycle"
    cp -p "$SRC/opencode-harness/skill/start-rpi-cycle/SKILL.md" "$C/opencode-harness/skill/start-rpi-cycle/SKILL.md"
  fi
```
② Mutator 15/16 정의(`mut_review_model() { … }`) **바로 뒤**에 M17 정의 삽입(M15/M16 과 동형 — `perl -pi`, `$1` = replica `.claude` 경로):
```bash
# Mutator 17 — seal #50 (C18 spec §17.1): start-rpi-cycle 의 FABLE-TAKEOVER 토큰이 소실되면(skill
# 재생성·문면 재작성 클래스) 발화해야 한다. §17.7-2 가 재작성 상한·골격 계약의 hook 강제를 수용
# 잔여로 둔 자리라 이 seal 이 유일한 물리 봉인 — 변이 커버가 없으면 그 봉인이 헛돈다(#49/M14 동형).
# 토큰만 치환해 conjunct ①을 단독 격리한다(다른 conjunct 는 건드리지 않음).
mut_drafting_token_drop() { perl -pi -e 's/FABLE-TAKEOVER/FABLE-HANDOVER/g' "$1/skills/start-rpi-cycle/SKILL.md"; }
```
③ 마지막 `assert_seal_fires "review_fm_model_s45" …` 줄 **바로 뒤**에 단언 추가:
```bash
assert_seal_fires "drafting_delegation_token" mut_drafting_token_drop "집필-위임 규약 토큰 drift"
```
※ witness 목록 변경 **불요** — M17 이 건드리는 `skills/start-rpi-cycle/SKILL.md` 는 witness() :19 에 이미 등재(C17 M15/M16 이 `agents/*.md` 를 추가해야 했던 것과 대비).
※ **정직 부기(수용 잔여)**: seal #50 의 부정-단언 conjunct(`위임 X` 부활 검출)는 **변이 미커버** — M17 은 ① 토큰 치환만 수행한다. 즉 그 conjunct 자체의 회귀-탐지력은 이 사이클에서 실증되지 않는다. 수용 잔여로 layer-yield/보고에 부기한다(§17.7-2 동형).

```bash
cd ~/.claude
bash setup/tests/seal-regression.test.sh 2>&1 | tail -4
```
Expected (RED):
```
✗ mutant[drafting_delegation_token]: rc=0, missing «집필-위임 규약 토큰 drift». tail: …
✓ live ~/.claude untouched (witness cksum stable across run)

seal-regression: PASS=20 FAIL=1
```
판별자는 **위 문자열 Expected** 다 — 이 Step 의 재현자가 `… | tail -4` 파이프라인이라 스위트의 종료코드는 `tail` 이 흡수한다(rc 단언 금지). `rc=0` 이 핵심 — 토큰을 지워도 현행 verify-setup 이 **통과**한다(= 봉인 부재의 실측 증거).

- [x] **Step 2: GREEN(seal) + RED(카운트) — seal #50 신설**

`setup/verify-setup.sh` — seal #49 블록 마지막 줄(`fi`, :550)과 seal #36 주석(`# 36. verify-setup 총 체크수 …`, :552) 사이에 삽입(기존 `ok`/`fail` 함수 · `MP_OK` 형 누산 플래그 · `SK49`/`MIR43` 형 경로 변수 명명 준수):
```bash
# 50. 집필-위임 규약 토큰 봉인 (C18 spec §17.1~§17.3, #49 동형): §17.7-2 가 재작성 상한·골격 계약의
#     hook 강제를 수용 잔여로 뒀으므로, 문서-토큰 드리프트 seal 이 이 규약의 **유일한 물리 봉인**이다
#     (skill 재생성·문면 재작성으로 규약이 소실되면 여기서 표면화 — #45 skill 토큰 parity 선례).
#     conjunctive: ①정본 start-rpi-cycle 서두 '집필-위임'+'FABLE-TAKEOVER'+'골격 계약' ②cross-family-review §2
#     '판정은 메인'+'증거 수집' ③opencode 미러 start-rpi-cycle 'FABLE-TAKEOVER'(미러 parity — 미러
#     부재(설치본/신선-클론) 시 vacuous 로 카운트 결정성 보존, #43 선례) ④**부정-단언**: 구 위임-금지
#     단정 '위임 X' 가 정본·미러 어디에도 되살아나지 않을 것(#25 선례 — 긍정 토큰만 세면 신·구 문면이
#     공존하는 half-landing/롤백-혼입을 통과시킨다). bash grep only.
C18_OK=1
SK50="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
CF50="$HOME/.claude/docs/ai-context/cross-family-review.md"
MIR50="$HOME/.claude/opencode-harness/skill/start-rpi-cycle/SKILL.md"
grep -q '집필-위임' "$SK50" 2>/dev/null || C18_OK=0
grep -q 'FABLE-TAKEOVER' "$SK50" 2>/dev/null || C18_OK=0
grep -q '골격 계약' "$SK50" 2>/dev/null || C18_OK=0
if grep -q '위임 X' "$SK50" 2>/dev/null; then C18_OK=0; fi
grep -q '판정은 메인' "$CF50" 2>/dev/null || C18_OK=0
grep -q '증거 수집' "$CF50" 2>/dev/null || C18_OK=0
if [ -f "$MIR50" ]; then
  grep -q 'FABLE-TAKEOVER' "$MIR50" 2>/dev/null || C18_OK=0
  if grep -q '위임 X' "$MIR50" 2>/dev/null; then C18_OK=0; fi
fi
if [ "$C18_OK" -eq 1 ]; then
  ok "집필-위임 규약 토큰 봉인 (start-rpi-cycle 집필-위임/FABLE-TAKEOVER/골격 계약 · cross-family 판정은-메인/증거-수집 · 미러 parity · 구 '위임 X' 부활 없음)"
else
  fail "집필-위임 규약 토큰 drift (C18): start-rpi-cycle '집필-위임'·'FABLE-TAKEOVER'·'골격 계약' / cross-family-review '판정은 메인'·'증거 수집' / opencode 미러 'FABLE-TAKEOVER' 중 결손, 또는 구 단정 '위임 X' 부활 — spec §17.1~§17.3"
fi

```

```bash
cd ~/.claude
bash setup/verify-setup.sh 2>&1 | tail -3
```
Expected (seal #50 GREEN + #36 RED — README 미동기):
```
✗ verify-setup 카운트 drift (GAP-009 M1): README 선언(87) != 런타임 실측(88) — README.md '현재 N PASS' 동기 필요

verify-setup: PASS=87 FAIL=1
```
(`✓ 집필-위임 규약 토큰 봉인 …` 라인이 그 위에 실재해야 한다 — `bash setup/verify-setup.sh 2>&1 | grep '집필-위임'` 로 별도 확인.) 여기서도 판별자는 위 문자열 Expected — `| tail -3` 파이프라인이 스위트 종료코드를 흡수한다.

- [x] **Step 3: GREEN — 카운트 동기 (README 87→88 · SKILL.md 20/0→21/0)**

`README.md` 는 CRLF(547/547) — `sed -i` 금지:
```bash
cd ~/.claude
perl -pi -e 's/현재 87 PASS/현재 88 PASS/' README.md
perl -pi -e 's/직전 20\/0 유효/직전 21\/0 유효/' skills/start-rpi-cycle/SKILL.md
```
※ `README.md` 의 seal-regression 카운트 앵커는 **실측상 존재하지 않는다**(README 에는 `현재 N PASS`(verify-setup) · `N 케이스`(cases.tsv 291) · `N개 E2E`(8) 세 선언뿐). 따라서 "seal-regression 20→21 동기"의 유일한 실물 앵커는 T1 이 sub-step 6 에 착륙시킨 SKIP 예시 문자열이며, 위 두 번째 `perl -pi` 가 그 동기다. **라이브 규약 파일에는 그 외 20→21 사이트 없음**(아래 Step 4 가 `skills/`·`opencode-harness/skill/`·`README.md` 스코프로 전수 확인 — spec·plan 본문의 `20/0` 은 스냅샷 기록이라 스코프 밖).

```bash
cd ~/.claude
bash setup/verify-setup.sh 2>&1 | tail -3
```
Expected:
```
✓ verify-setup 카운트 seal: README 선언(88) == 런타임 실측(88)

verify-setup: PASS=88 FAIL=0
```

- [x] **Step 4: 세 스위트 + 잔여 카운트 전수 확인**

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
seal-regression: PASS=21 FAIL=0
```
```
Hook tests: 291 / 291 passed
cases.tsv <-> run-all 정합 OK (291 declared == 291 run, 비주석 실재)
Pass rate 100% — OK
```

잔여 카운트 드리프트 전수(스테일 `20/0` 잔존 0 · `현재 87` 잔존 0). **스코프는 라이브 규약 파일 한정** — `docs/` 는 제외한다: spec §17.5 ③(:2000)의 SKIP 예시와 이 plan 본문(:103·:395)의 `20/0` 은 **착륙 시점 스냅샷 기록**이라 동기 대상이 아니며(spec 은 무수정 대상이기도 하다), 동기 대상은 라이브 규약 리터럴뿐이다:
```bash
grep -rn '직전 20/0' skills/ opencode-harness/skill/ README.md ; echo "rc=$?"
grep -rn '현재 87 PASS' README.md ; echo "rc=$?"
```
Expected: 두 grep 모두 출력 0줄 + `rc=1`.

CRLF 보존(README 혼합 개행 유입 0):
```bash
printf 'lines=%s cr=%s\n' "$(grep -c '' README.md)" "$(tr -cd '\r' < README.md | wc -c)"
```
Expected: `lines=547 cr=547`.

- [x] **Step 5: 커밋**

```bash
cd ~/.claude
git add setup/verify-setup.sh setup/tests/seal-regression.test.sh README.md skills/start-rpi-cycle/SKILL.md
git commit -m "$(cat <<'EOF'
feat(c18): seal #50 집필-위임 토큰 봉인 + 변이 M17 + 카운트 동기 87→88 / 20→21

- seal #50(conjunctive 4항): start-rpi-cycle '집필-위임'+'FABLE-TAKEOVER'+'골격 계약' · cross-family-review
  '판정은 메인'+'증거 수집' · opencode 미러 'FABLE-TAKEOVER'(미러 부재 시 vacuous — #43 선례) ·
  구 단정 '위임 X' 부정-단언(정본+미러, #25 선례 — half-landing 통과 차단).
  #36 총계 seal 앞에 배치(#37 선례) — spec §17.7-2 가 hook 강제를 수용 잔여로 둔 자리의 유일 물리 봉인
- 변이 M17: FABLE-TAKEOVER 토큰 치환 → seal #50 RED 단언(RED 실측 rc=0 = 봉인 부재 증거)
- make_replica 가 opencode 미러 start-rpi-cycle 을 복제 — conjunct ③의 replica-vacuity 차단
- README 87→88(CRLF, perl -pi) · sub-step 6 SKIP 예시 20/0→21/0

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

## 커밋 규율

- **브랜치**: `c18-fable-delegation`. task 당 1커밋(총 4). 메시지 = `feat(c18): …` + `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- 스위트가 GREEN 이 아닌 상태로 커밋 금지(각 task Step 4 의 Expected 가 커밋 전제).

## 금지

- spec `docs/superpowers/specs/2026-07-25-model-policy-design.md` **§0~§17 수정 금지**(§17 은 이미 착륙 — plan 은 소비만).
- `workflows/rpi-implement.js` · `hooks/**` · `settings.json` 무터치.
- `CONTEXT.md` 무터치(Phase R 완료분).
- `skills/create-orchestrator-skill/SKILL.md:24` 동형 문구 무터치(§17.7 수용 잔여 1 — 다음 사용 시 개정).
- 규범 원문 2건(§17.1 서두 · §17.2 §2)의 재서술·요약·재줄바꿈 금지 — Step 4 의 `VERBATIM-OK` diff 가 이 금지의 기계 판별자.
