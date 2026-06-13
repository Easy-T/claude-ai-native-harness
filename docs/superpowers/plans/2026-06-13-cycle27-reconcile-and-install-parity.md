# cycle-27: 정합 seal 강화 + install/verify skill parity (강화 rank 4) Implementation Plan

> **For agentic workers:** 경량 사이클 — 메인이 executing-plans 절차로 직접 수행.

**Status:** completed
**RPI-Cycle:** 27
**Started:** 2026-06-13

**Goal:** "게이트가 자신이 광고한 무결성을 강제 못함" 결함 봉인 — (A) run-all 정합을 단방향 bare-substring → **TOTAL==선언 카운트 + 비주석 실재**로 강화(G2-b), (B) install.sh REQUIRED가 verify-setup item-6의 7 skill 중 3개(closeout-pr-cycle·improve·ui-design) 누락 → 추가 + parity seal(NEW-install-required-skills). **성공: run-all 129/129 + 강화 정합이 주입 phantom 검출, verify-setup PASS=64 FAIL=0(신규 #29), verify-integration 8/8.**

**Subsystem spec:** 테스트 정합은 run-all.sh + spec §6.2(원안). install parity는 install.sh↔verify-setup. **spec delta = NO** — 기존 "1:1 정합" 의도(README:274)의 *강제 강화*이지 새 결정 아님. drift seal 개념(CONTEXT.md:28-30) 그대로.

**근거(R):** audit-reverification §3(NEW-install-required-skills)·§2(G2-b). 실측: cases.tsv ID는 hook-scoped 중복(01-no-marker×2), bare-substring 정합은 주석-온리/역방향 drift 미검출. 단, 현재 실제 drift 0(TOTAL 129==선언 129) — 강화는 회귀 봉인용. install.sh REQUIRED=4 skill, verify-setup item6=7 skill(누락 3 실측).

---

### Task 1: install.sh REQUIRED에 3 skill 추가 + verify-setup seal #29 (RED→GREEN)

**Files:** `setup/verify-setup.sh`(seal #29 추가), `setup/install.sh:50-77`(3 skill)

- [x] **Step 1 (RED):** verify-setup에 seal #29 추가 — install.sh REQUIRED가 7 tracked skill의 `skills/<s>/SKILL.md`를 전부 참조하는지. 현 install.sh(closeout/improve/ui-design 누락)에 실행 → **#29 FAIL** 실측(RED).
- [x] **Step 2 (GREEN):** install.sh REQUIRED 배열에 `skills/closeout-pr-cycle/SKILL.md`, `skills/improve-codebase-architecture/SKILL.md`, `skills/ui-design/SKILL.md` 추가 → #29 PASS.

### Task 2: run-all 정합 강화 (G2-b)

**Files:** `hooks/tests/run-all.sh:654-665`(정합 블록)

- [x] **Step 1 (GREEN 구현):** 정합 블록 교체 — (1) 각 선언 id가 run-all **비주석** 라인에 실재(`grep -F "$rid" | grep -qvE '^[[:space:]]*#'`) → 주석-온리 phantom 차단, (2) `TOTAL == 선언수(grep -cvE '^[[:space:]]*(#|$)' cases.tsv)` 단언 → 역방향 drift + 미실행 phantom 차단. 두 테스트 형식(test_* 헬퍼·인라인 블록) 모두 커버, fragile hook→fn 매핑 불요.
- [x] **Step 2 (RED 시연):** /tmp 사본에 phantom cases 행(테스트 없는 id) 주입 → 강화 정합이 FAIL, 구 bare-substring은 PASS임을 실측 기록(영구 케이스 아님 — rank 9 메타테스트가 영구화).
- [x] **Step 3 (GREEN):** 원본 run-all → 129/129 + "TOTAL==선언(129)" + 정합 OK.

### Task 3: README 카운트 정합

**Files:** `README.md:282`

- [x] **Step 1:** README "현재 63 PASS" → "현재 64 PASS"(seal #29 추가분).

### Task 4: 전체 검증

- [x] **Step 1:** `bash hooks/tests/run-all.sh` → 129/129, 정합 OK, 100%.
- [x] **Step 2:** `bash setup/verify-setup.sh` → PASS=64 FAIL=0 (#29 green).
- [x] **Step 3:** `bash setup/verify-integration.sh` → 8/8.

---

## Closeout 체크
- plan Status → completed, state.json 26→27, reverification §4 rank 4 ✅
- harness-verify: verify-setup PASS=64 보고
- 다음: rank 5(doctor 자가치유 은폐)
