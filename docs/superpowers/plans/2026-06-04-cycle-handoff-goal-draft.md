**Status:** completed
**RPI-Cycle:** 14
**Started:** 2026-06-04

# P2 — 사이클 간 goal 핸드오프 구현 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline).

**Goal:** start-rpi-cycle SKILL.md Closeout에 다음 사이클 goal 초안(advisory)을 추가해, 사용자가 다음 사이클을 goal로 제어하고 `/compact` 후에도 컨텍스트를 재구성할 수 있게 한다. 새 hook 0개, #17 green 유지, README/CLAUDE 무변경.

**Architecture:** goal 초안을 **필수 Communication Protocol `unknowns`에 접어넣어** advisory이면서도 보고 누락으로 자가-표면화. cycle%5 improve-architecture 제안과 하나의 "다음 액션" 블록으로 병합. P2 사실은 SKILL.md 단일 소스라 drift guard 불요.

**Spec:** `docs/superpowers/specs/2026-06-04-cycle-handoff-and-orchestration-design.md` (D-P2; P3는 후속 사이클)

**Tech Stack:** Markdown (skill prose). SKILL.md 단일 파일.

---

## Task 1: item 4 cycle%5 → sub-step 7 위임

**Files:** Modify `skills/start-rpi-cycle/SKILL.md` (Step C-1 item 4 마지막 bullet)

- [x] **Step 1:** `cycle.count % 5 == 0 ... improve-codebase-architecture 실행 권장... 제안` bullet을, "sub-step 7 goal 초안의 주제를 improve-codebase-architecture 실행으로 설정(별도 묻기 대신 병합)"으로 재작성. v2/v3 알림 bullet은 보존.

## Task 2: sub-step 7 (goal 핸드오프) 추가

**Files:** Modify `skills/start-rpi-cycle/SKILL.md` (Step C-1, item 6 다음)

- [x] **Step 1:** sub-step 7 추가:
  - advisory, `cycle.count ≥ 1`일 때 emit; 0이면 "다음 사이클 제안 없음 (열린 항목 0)".
  - 열린 항목 수집: 미완료 plan task / drift review 후속 / non-obvious action item / R·Closeout이 남긴 unknowns. cycle%5면 주제=improve-codebase-architecture.
  - goal 초안 3요소: ① 상세 목표(관찰가능 success criteria) ② post-compact 필수 읽기 문서(존재하는 것만 절대경로: subsystem durable spec+§, CONTEXT.md, architecture.md+ADR, 직전 plan, non-obvious.md, 관련 CLAUDE.md §) ③ 자율 best-practice 진행 directive.
  - 출력 위치 = Communication Protocol `unknowns`(Task 3와 연결).

## Task 3: Communication Protocol에 next-cycle-goal 고유 필수 필드 추가

**Files:** Modify `skills/start-rpi-cycle/SKILL.md` (Communication Protocol)

- [x] **Step 1:** goal 초안을 unknowns에 접지 말고 **고유 필수 필드 `next-cycle-goal`**로 추가(cycle≥1). 값은 {3요소 goal 초안 / 수집근거 동반 "제안 없음" / cycle0 생략} 중 하나. 생략 = 구조적 불완전(대체 불가).
  > verify 단계 적대 리뷰(Lens 1) 교정: unknowns 접기는 복합 필드라 다른 절반으로 누락을 가리는 누출 → 고유 필드로 분리. zero-open은 수집 근거 의무화, cycle%5는 zero-open이어도 적용.
  > 2차(재검증 Lens 1): 3요소 자체가 필드 안쪽 복합-마스킹 누출 → `goal:`/`read-before:`/`autonomy:` 라벨 하위줄로 구조화. 각 라벨 내용 완전성은 수락된 advisory 잔여(정지점). item 4는 토픽 무명명 순수 위임.

## Task 3c: verify-setup #18 — 라벨 parity 가드 추가

> 적대 리뷰가 짚은 필연적 파일-내 중복(3 라벨이 sub-step 7 + Communication Protocol 양쪽 필수) 봉인.

- [x] **Step 1:** `setup/verify-setup.sh`에 check #18: `goal:`/`read-before:`/`autonomy:` 3 라벨이 Step C-1 영역과 Communication Protocol 영역 양쪽에 존재(#17 패턴 미러). PASS 52→53.
- [x] **Step 2:** RED-path 정상성: 라벨 한쪽 제거 시 #18이 fail함을 임시 복제로 실측(원본 무수정).

## Task 4: 검증 (adversarial + gates)

- [x] **Step 1:** ultracode Workflow — 3 렌즈 적대 검증(silent-skip / 일관성 / requirements). flagged 수정 후 재검증(누출 닫힐 때까지).
- [x] **Step 2:** `bash hooks/tests/run-all.sh` → 82/82 정합 OK(hook 무변경).
- [x] **Step 3:** `bash setup/verify-setup.sh` → FAIL=0, PASS=53, #17·#18 green.
- [x] **Step 4:** `bash setup/verify-all.sh` → ALL PASS.

## Task 5: Closeout

- [x] **Step 1:** state.json cycle.count 13→14, last_completed_at/last_drift_check 2026-06-04.
- [x] **Step 2:** plan Status active→completed. spec에 P2 done 표기는 불요(Status active 유지 — P3 미구현).
- [x] **Step 3:** 메모리 `project_p2p3_cycle_handoff_design` 갱신(P2 구현 완료, P3 남음) + MEMORY.md 포인터 동기화.
- [x] **Step 4:** master-direct commit + push.
