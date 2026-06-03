**Status:** completed
**RPI-Cycle:** 13
**Started:** 2026-06-04

# spec 라이프사이클 모델 교정 구현 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline).

**Goal:** start-rpi-cycle SKILL.md의 Phase R/Gate R/Gate P 문구를 검증된 durable-spec 모델(spec=서브시스템당 durable, plan=사이클당)로 교정한다. 새 hook 0개, verify-setup #17 green 유지.

**Architecture:** cycle-12가 spec을 "매 사이클 새로 씀"으로 mis-frame한 것을 조건부化. Case A(새 design이 plan에)는 기존 Gate P scope-creep이 이미 잡으므로 처방 문구만 교정; Case B(이해 변경이 plan 밖)는 Phase R ★의 이진 단언으로만 닫음(기계 추적 불가).

**Spec:** `docs/superpowers/specs/2026-06-02-grill-placement-and-drift-guard-design.md` (개정 2026-06-04 § 참조 — 같은 거버넌스 subsystem 재진입, in-place 개정 = 교정 모델 dogfood)

**Tech Stack:** Markdown (skill prose). SKILL.md 단일 파일.

---

## Task 1: Phase R.A 조건부化 + <subsystem> 토큰

**Files:** Modify `skills/start-rpi-cycle/SKILL.md` (lines 20-22)

- [ ] **Step 1:** brainstorming 산출 문구를 조건부(신규 subsystem→새 spec / 재진입→durable 재사용)로 교체. `<topic>`→`<subsystem>`. (grill-with-docs/brainstorming/explore-strict 토큰은 Phase R에 유지 → #17 green.)

## Task 2: Phase R.B ★ 이진 spec-delta 단언

**Files:** Modify `skills/start-rpi-cycle/SKILL.md` (lines 29-30)

- [ ] **Step 1:** `★ spec 역류` 문구를 이진 단언으로 교체: R이 durable spec에 없던 design/의미/제약을 드러냈으면 plan 전에 spec in-place 개정 또는 §5 ADR; 아니면 "spec 재확인, delta 없음(no-op)" 명시.

## Task 3: Gate R no-op-aware + <subsystem> 토큰

**Files:** Modify `skills/start-rpi-cycle/SKILL.md` (lines 47, 52)

- [ ] **Step 1:** Gate R spec 토큰 `<현재 spec ...<topic>...>` → `<재사용 중인 subsystem spec ...<subsystem>...>`.
- [ ] **Step 2:** `- grill에서 확정된 design 결정이 spec에 반영됨 (spec 역류 완료)` → `- spec delta가 있으면 durable spec/ADR에 반영됨; 없으면 "delta 없음(no-op)" 명시`.

## Task 4: Gate P FAIL 처방 교정 + <subsystem> 토큰

**Files:** Modify `skills/start-rpi-cycle/SKILL.md` (lines 74, 90-93)

- [ ] **Step 1:** Gate P spec 경로 토큰 `<topic>` → `<subsystem>`.
- [ ] **Step 2:** FAIL 처방을 분기化: 정당하지 않은 scope creep→plan 축소 / R이 발견한 정당한 신규 design→plan 깎지 말고 durable spec 개정 또는 §5 ADR 후 재실행 / 미커버 요구사항→plan 보강.

## Task 5: 검증 + Closeout

- [ ] **Step 1:** `bash hooks/tests/run-all.sh` → 82/82, 정합 OK (hook 무변경이라 동일 기대).
- [ ] **Step 2:** `bash setup/verify-setup.sh` → FAIL=0, "§3 ↔ start-rpi-cycle Phase R tools agree" 유지(#17 green).
- [ ] **Step 3:** `bash setup/verify-all.sh` → ALL PASS.
- [ ] **Step 4:** state.json cycle.count 12→13, 날짜 2026-06-04.
- [ ] **Step 5:** P2 enriched 설계(상세 goal + post-compact 필수 읽기 문서 + 자율 best-practice 진행) 메모리 등록.
- [ ] **Step 6:** plan Status active→completed. 커밋.
