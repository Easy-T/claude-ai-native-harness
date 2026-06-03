**Status:** completed
**RPI-Cycle:** 15
**Started:** 2026-06-04

# P3 — ultracode Workflow 구동 Phase I 옵션 (d) 구현 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline).

**Goal:** start-rpi-cycle Phase I에 옵션 (d)(ultracode Workflow 구동)를 추가한다. ultracode ON일 때만 표면화하고(OFF면 비활성 — 항상-on 권유 없음), canonical 2-stage(execute-strict→review-strict, schema 금지) 파이프라인을 명시하며, 기존 plan-존재·spec-before-plan 게이트를 우회하지 못함을 못박는다.

**Architecture:** Phase I는 이미 (a)/(b)/(c) 옵션 + 권장 매트릭스 구조. (d)를 같은 리스트에 추가하고 권장 줄에 "ultracode ON이면 (d)"를 더한다. R/Closeout 병렬화는 ceremony라 제외(Phase I 한정). 새 hook 0, CLAUDE.md 무변경(§3 Implement 줄은 옵션 미열거 — (a)/(c)도 §3에 없음 → (d) 추가도 모순 없음), #17/#18 무관(Phase I는 검사 대상 아님).

**Spec:** `docs/superpowers/specs/2026-06-04-cycle-handoff-and-orchestration-design.md` (D-P3 — durable spec 재사용, delta 없음(no-op); P3 섹션 상태만 미구현→구현됨으로 갱신)

**Tech Stack:** Markdown (skill prose). SKILL.md 단일 파일.

---

## Task 1: Phase I 옵션 (d) 추가

**Files:** Modify `skills/start-rpi-cycle/SKILL.md` (Phase I 구현 방식 선택 리스트)

- [x] **Step 1:** (c) 다음에 옵션 (d) 추가:
  - ultracode ON일 때만 표면 — OFF면 비활성(항상-on 권유 없음).
  - Phase I 한정(R/Closeout 병렬화 제외).
  - canonical 2-stage: stage1 `agentType='execute-strict'` → stage2 `agentType='review-strict'`.
  - 두 스테이지 schema 금지(제약 wrapper + StructuredOutput 부재 → 실패; `[[feedback_workflow_agenttype_schema]]`).
  - wrapper self-spawn 불가 → execute→verify 반드시 별도 2 스테이지.
  - 같은 파일 동시수정 task ≥2면 `isolation:'worktree'`.
  - plan-존재·spec-before-plan 게이트는 메인 세션의 Workflow 디스패치 *전*에 작동 → (d) 우회 불가.

## Task 2: 권장 매트릭스 갱신

**Files:** Modify `skills/start-rpi-cycle/SKILL.md` (Phase I 권장)

- [x] **Step 1:** `큰 사이클 (≥5 task) → (a)` 줄에 "또는 ultracode ON이면 (d)" 추가. (≥5 task 권장 조건 = spec D-P3.)

## Task 3: spec P3 섹션 상태 갱신

**Files:** Modify `docs/superpowers/specs/2026-06-04-cycle-handoff-and-orchestration-design.md`

- [x] **Step 1:** "P3 — 후속 사이클 Acceptance (미구현, 참고)" 헤더를 "P3 — 구현됨 (cycle-15)"로 갱신(설계 delta 아님, 상태만).

## Task 4: 검증 (adversarial + gates)

- [x] **Step 1:** ultracode Workflow — 적대 검증: (d)가 ultracode-gated인가(OFF면 비활성, 항상-on 표면 없음) / schema-금지·2-stage·self-spawn 제약이 명시돼 미래 오용 차단 / plan-존재·spec-before-plan 우회 불가 / enforce-orchestrator 골격 보존 / 새 always-on 권유 표면 미생성.
- [x] **Step 2:** `bash hooks/tests/run-all.sh` → 82/82(hook 무변경).
- [x] **Step 3:** `bash setup/verify-setup.sh` → 53/0, #17·#18 green(Phase I 무관이라 불변).
- [x] **Step 4:** `bash setup/verify-all.sh` → ALL PASS.

## Task 5: Closeout

- [x] **Step 1:** state.json cycle.count 14→15, last_completed_at/last_drift_check 2026-06-04.
- [x] **Step 2:** plan Status active→completed.
- [x] **Step 3:** 메모리 `project_p2p3_cycle_handoff_design`(P3 구현 완료) + MEMORY.md 포인터 동기화.
- [x] **Step 4:** Closeout next-cycle-goal 산출(cycle 15 ≥ 1 — dogfood). master-direct commit + push.
