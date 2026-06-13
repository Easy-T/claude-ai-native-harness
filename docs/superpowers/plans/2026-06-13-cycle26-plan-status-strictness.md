# cycle-26: plan_status 엄격화 (강화 rank 3) Implementation Plan

> **For agentic workers:** 경량 사이클 — 메인이 executing-plans 절차로 직접 수행. TDD: RED 실측 → GREEN.

**Status:** completed
**RPI-Cycle:** 26
**Started:** 2026-06-13

**Goal:** `_common.sh` plan_status가 head-20의 prose/펜스 `Status: active`를 게이트 개방 신호로 오인하는 버그(NEW-planstatus-prose, 재검증 §3) 봉인. **성공 기준: bold `**Status:**` 형식만 인정 + 코드펜스 스킵 → run-all 100%(125+4), verify-setup PASS FAIL=0, 기존 plan 27개 회귀 0(전부 bold 형식 실측 확인됨).**

**Subsystem spec:** plan_status/has_active_plan는 _common.sh 공유 로직(전용 durable spec 없음; 의미는 CONTEXT.md "active plan"·"explicit-Status 의미론" + README:342). **spec delta = NO(no-op)** — cycle-23이 이미 "명시 Status 헤더만 신뢰" 결정을 확정했고, 본 변경은 그 결정의 *정확한 구현*(loose 정규식이 prose-오염에 취약했던 구현 버그 수정). CONTEXT.md "explicit-Status 의미론" 어휘 그대로 유효.

**근거(R):** docs/superpowers/specs/2026-06-13-audit-reverification.md §3(NEW-planstatus-prose). 실측: 27 plan 전부 `**Status:**` bold(26 completed+1 paused), non-bold 0 → bold 요구 무회귀.

**버그:** `_common.sh:89` `grep -m1 -iE '^\*?\*?status:?\*?\*?'` — 콜론 선택적·bold 선택적·word-boundary 없음·코드펜스 무시. head-20 컬럼0의 prose `Status: active`(예시/인용) 또는 펜스 내 `**Status:** active`가 첫 매칭이면 cwd 전체 RPI 게이트 개방.

**Fix:** plan_status를 awk로 재작성 — (1) 코드펜스(``` ```) 라인 스킵, (2) `^\*\*[Ss]tatus:` (bold+콜론) 만 매칭, (3) 첫 매칭 값 첫 단어 소문자 출력. has_active_plan/session-start-audit 3소비자 자동 동기화(공유 함수).

---

### Task 1: RED 케이스 추가 (cases.tsv + run-all.sh)

**Files:** `hooks/tests/cases.tsv`, `hooks/tests/run-all.sh`

- [x] **Step 1:** cases.tsv에 4행 추가:
  - `hooks-lib  136-planstatus-prose-skip  output  gen_lib_136`
  - `hooks-lib  137-planstatus-fence-skip  output  gen_lib_137`
  - `hooks-lib  138-planstatus-real-active  output  gen_lib_138`
  - `enforce-rpi-cycle  139-prose-status-noplan  2  gen_erc_139`
- [x] **Step 2:** run-all.sh lib 섹션에 plan_status 직접 테스트(shell 함수 호출):
  - 136: prose `Status: active` + `**Status:** completed` → expect `completed`
  - 137: 펜스 내 `**Status:** active` + `**Status:** completed` → expect `completed`
  - 138: `**Status:** active` → expect `active` (회귀 가드)
- [x] **Step 3:** run-all.sh erc 섹션에 139: prose-status plan dir + 코드 Write → expect exit 2.
- [x] **Step 4 (RED 실측):** run-all → 136/137/139 FAIL(현재 'active' 오인), 138 PASS. RED 기록.

### Task 2: plan_status awk 재작성 — GREEN

**Files:** `hooks/_common.sh:88-91`

- [x] **Step 1:** plan_status 본문을 awk로 교체: 펜스 토글 스킵 + `^\*\*[Ss]tatus:` 매칭 + 값 추출(첫 단어 소문자, `*` 제거). 주석에 "bold `**Status:**` 만 인정, 펜스 스킵 (cycle-26: prose-오염 봉인)" 명시.
- [x] **Step 2 (GREEN 실측):** run-all → 136/137/138/139 통과 + 기존 plan 게이트 테스트(35/104/105/119/107/108 등) 회귀 0.

### Task 3: README 카운트 + 회귀 확인

**Files:** `README.md`

- [x] **Step 1:** README cases 카운트 125→**129** (274·510).
- [x] **Step 2:** `bash setup/verify-setup.sh` → PASS FAIL=0 (#20 정합 + #27 plan-Status seal green — 27 plan 전부 bold라 #27 영향 없음).
- [x] **Step 3:** `bash setup/verify-integration.sh` → 8/8.

### Task 4: rank 2 KEEP 기록 (사용자 결정 반영)

**Files:** `docs/superpowers/specs/2026-06-13-audit-reverification.md`

- [x] **Step 1:** §4 rank 2 행에 "**KEEP (by-design 경계, 사용자 결정 2026-06-13)**: 바이트 예산은 짧은 위험 one-liner 미해결 + 정당 편집에 friction; RPI는 보안경계 아닌 자기규율(SECURITY.md 단일운영자)" 주석 추가.

---

## Closeout 체크
- plan Status → completed, state.json 25→26
- harness-verify: verify-setup PASS 보고
- 다음: rank 4(정합 seal 강화)
