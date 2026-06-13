# cycle-28: state.json↔schema 검증 (강화 rank 7) Implementation Plan

> **For agentic workers:** 경량 사이클 — 메인이 executing-plans 절차로 직접 수행.

**Status:** completed
**RPI-Cycle:** 28
**Started:** 2026-06-13

**Goal:** state.schema.json이 SSOT로 존재하나 소비자(검증기) 0인 dead-spec 봉인(NEW-state-schema-unverified). verify-setup에 **스키마-구동** 검증 #30 추가 — 스키마를 읽어 그 required/type/format:date/minimum 제약으로 state.json 검사. closeout이 cycle.count만 올리고 날짜 누락·타입 오염해도 검출. **성공: verify-setup PASS=65 FAIL=0, RED 시연(손상 state 검출), run-all 129/129·verify-integration 8/8.**

**Subsystem spec:** state.schema.json(draft-07) + 관리자 closeout C-1(start-rpi-cycle SKILL.md:174-178). **spec delta = NO** — 스키마는 이미 SSOT 선언(state.schema.json:4), 본 변경은 그 스키마에 *소비자를 부여*(dead→live). 신규 용어 없음.

**근거(R):** audit-reverification §3(NEW-state-schema-unverified). 실측: state.schema.json 소비자 grep 0건; closeout이 schema 검증 안 함; verify-setup/all 어디에도 state↔schema 검사 없음.

**설계:** verify-setup #30이 node(무의존)로 스키마를 읽어 사용된 draft-07 부분집합(object/integer/string/boolean·required·properties·minimum·format:date)을 재귀 검사. 스키마-구동이라 스키마 변경 시 자동 추종(하드코딩 중복 없음). SKILL.md 'closeout 후 검증' 노트는 rank 8 문서 배치로 분리(harness 사이클은 sub-step 6이 이미 verify-setup 실행 → #30 자동 적용).

---

### Task 1: verify-setup #30 스키마-구동 검증 추가

**Files:** `setup/verify-setup.sh`(#29 뒤, summary 앞)

- [x] **Step 1:** #30 추가 — 스키마+state 파싱 후 required 누락·type 불일치·minimum 위반·date 형식 위반을 재귀 검사. parse 실패도 fail. (구현 후 채움)
- [x] **Step 2 (GREEN):** 실 state.json(count 27, 날짜 2개)으로 `bash setup/verify-setup.sh` → #30 ok, PASS=65.
- [x] **Step 3 (RED 시연):** /tmp 손상 state(① count 문자열화 ② cycle 키 제거 ③ 날짜 "2026-6-1")로 #30 로직 단독 실행 → 각각 위반 검출 실측 기록.

### Task 2: README 카운트 정합

**Files:** `README.md:282`

- [x] **Step 1:** "현재 64 PASS" → "현재 65 PASS".

### Task 3: 전체 검증

- [x] **Step 1:** `bash setup/verify-setup.sh` → PASS=65 FAIL=0.
- [x] **Step 2:** `bash hooks/tests/run-all.sh` → 129/129(정합 영향 없음).
- [x] **Step 3:** `bash setup/verify-integration.sh` → 8/8.

---

## Closeout 체크
- plan Status → completed, state.json 27→28, reverification §4 rank 7 ✅
- harness-verify: verify-setup PASS=65 보고
- 다음: rank 5(doctor 자가치유 은폐)
