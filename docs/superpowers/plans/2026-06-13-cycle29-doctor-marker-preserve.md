# cycle-29: doctor audit 마커 자가치유 은폐 제거 (강화 rank 5) Implementation Plan

> **For agentic workers:** 경량 사이클 — 메인이 executing-plans 절차로 직접 수행.

**Status:** completed
**RPI-Cycle:** 29
**Started:** 2026-06-13

**Goal:** doctor.sh:177-182가 기존 audit 마커를 매 실행마다 무조건 today로 sed → (a) §3 30일 staleness 게이트 영구 무력화(NEW-doctor-marker-unconditional), (b) CLAUDE.md 수정으로 §1 prefix 캐시 무효화, (c) doctor.test가 라이브 SSOT 변형(NEW-doctor-test-mutates-live). **Bug 1 fix(append-only-if-absent)가 세 결함 동시 완화.** 성공: doctor가 기존 마커 보존, doctor.test Test 3이 no-overwrite 불변식 검증(비-tautological), verify-setup 65/0·run-all 129/129·verify-integration 8/8.

**Subsystem spec:** doctor.sh(spec §2.7 diagnose-treat) + §3 audit 마커(CLAUDE.md 하단 주석) + §1 캐시(CLAUDE.md:10-13). **spec delta = NO** — "audit 갱신은 실제 점검에만"은 closeout C-1 last_drift_check 설계 원칙(SKILL.md:178)과 이미 일관; doctor의 무조건 갱신이 그 원칙 위반이었음. 본 fix가 정합화. 신규 용어 없음.

**근거(R):** audit-reverification §3(NEW-doctor-marker-unconditional·NEW-doctor-test-mutates-live). 실측: 마커=2026-06-12(어제, 오늘 doctor 미실행), doctor.sh:180 무조건 sed, doctor.test:11 라이브 doctor 실행 + Test3 tautological.

**설계 결정:** Bug 1만 핵심 — Bug 2(doctor.test 변형)는 Bug 1로 마커 변형이 사라지고(append-only no-op) git-managed 홈은 백업 스킵이라 잔여 변형이 .installed rm/recreate(benign)뿐 → 별도 mktemp 격리(full doctor가 mktemp서 다수 FAIL/early-exit 위험)는 과투자로 제외. doctor.test Test 3을 no-overwrite 불변식으로 재작성해 의미 부여.

---

### Task 1: doctor.sh 마커 append-only-if-absent

**Files:** `setup/doctor.sh:177-186`

- [x] **Step 1 (GREEN 구현):** 기존 마커 존재 시 무조건 sed-overwrite 제거 → "보존(갱신 안 함)" PASS. 부재 시에만 append. 주석에 §3 게이트·§1 캐시 사유 명시.

### Task 2: doctor.test.sh Test 3 no-overwrite 불변식

**Files:** `setup/tests/doctor.test.sh:15-20`

- [x] **Step 1:** Test 3을 tautological("마커 존재") → 불변식("doctor 실행 후 기존 마커 date 불변")으로 재작성. BEFORE/AFTER 마커 비교, 다르면 FAIL.

### Task 3: RED/GREEN 시연 + 검증

- [x] **Step 1 (RED 시연):** /tmp 사본 CLAUDE.md(마커 2026-06-12)에 구 로직(무조건 sed)→2026-06-13 덮어씀 vs 신 로직→보존 실측 기록.
- [x] **Step 2 (GREEN):** `bash setup/tests/doctor.test.sh` → PASS(Test 3 no-overwrite green). 실행 후 `grep audit CLAUDE.md`가 2026-06-12 불변 확인(라이브 비변형).
- [x] **Step 3:** `bash setup/verify-setup.sh` 65/0, `bash hooks/tests/run-all.sh` 129/129, `bash setup/verify-integration.sh` 8/8.

---

## Closeout 체크
- plan Status → completed, state.json 28→29, reverification §4 rank 5 ✅
- harness-verify: verify-setup PASS=65 보고
- 다음: rank 9(메타테스트) → rank 8(문서, 세션종료 직전)
