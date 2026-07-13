# Harness Upgrade C4 — GAP-005 스캐폴드 노화 관리 Implementation Plan

**Status:** completed
**RPI-Cycle:** 55
**Started:** 2026-07-13
**Completed:** 2026-07-13

**Best-Direction Check:** 최선안 = (L3) 스캐폴드 registry(구성요소→존재 이유→추적 커밋/spec) + registry⊇live 결정론 parity seal(신규 hook/skill이 registry 미등재 시 FAIL = 노화 방지 트리거) + improve-codebase-architecture 프루닝 단계 + playbook 모델-업그레이드 체크리스트 + Fable 5 가이드 기준 1차 과처방 감사 보고(삭제는 사용자 diff 후). 채택안 = 동일. **L4(자동 A/B strip-and-measure) 스코프 제외 선언**: 원 blocker(run-log 부재)는 C2에서 해소됐으나(04 정정), 측정 방법론(구성요소 제거 후 eval 델타 측정) 설계는 별 축·별 사이클의 실질 작업 — L3(트리거+registry+수동감사)이 "제거 메커니즘 부재"라는 핵심 결함을 해소하며, L4는 그 위의 자동화. 이는 방향 열화가 아니라 스코프 분할(D12 목표=3=L3). DOWNGRADE-DECLARED: 없음(L4는 목표 레벨 밖).

**Goal:** 하네스 구성요소(hook 11·skill 8·seal ~17)에 "존재 이유" registry + 노화 감지 seal + 모델-업그레이드 시 과처방 리뷰 트리거를 두어, 스캐폴드가 무한 누적만 하던 결함(01 §6-10)을 해소. 04 GAP-005 수용 기준 SSOT.

## Global Constraints
- **착수 실측(cold-agent fitness 교훈)**: hook 11(`ls hooks/*.sh`−_common)·skill 8(`ls skills/*/SKILL.md`)·seal은 verify-setup #17~#34(−#26). 04 초안의 10/10/7은 stale — 무시.
- registry 위치 = `docs/ai-context/scaffold-registry.md`(04 지정; dir 신규 생성 — 하네스 자신의 AI-context).
- improve-codebase-architecture SKILL.md 편집은 enforce-orchestrator 골격(Phase≥3·Agent()≥1·Communication Protocol) 유지 + **opencode 미러 `opencode-harness/skill/improve-codebase-architecture/SKILL.md` 동기**(05 §5-4).
- 신규 seal → verify-setup 총수 +1 → README `현재 N PASS` 동기(#36). run-all 신규 케이스면 cases/README 동기(#20).
- 삭제 없음(감사는 보고만 — 삭제는 사용자 diff 후, 별 사이클).

### Task 1: scaffold-registry.md 생성 (구성요소→존재 이유→추적)
**Files:** Create: `docs/ai-context/scaffold-registry.md`
- [x] hook 11 전부(존재 이유 1줄 + 추적 커밋/cycle/spec 인덱스) — 01 구조맵 §1 + 커밋 유래
- [x] skill 8 전부(orchestrator 7 + statusline; 존재 이유 + 트리거) — 01 §2
- [x] seal #17~#34(−#26) 각 봉인 대상 1줄 — 01 §3 + verify-setup 주석
- [x] 헤더에 "노화 리뷰 규약": 이 registry는 verify-setup seal이 live⊇registry 강제; 모델 업그레이드 시 §과처방 리뷰(playbook) 트리거

### Task 2: verify-setup registry parity seal (RED→GREEN)
**Files:** Modify: `setup/verify-setup.sh`
- [x] seal #35→ 아, #35/#36 이미 존재 → **신규 = #37**: registry 존재 + 모든 live hook basename(−_common)이 registry에 등재 + 모든 live skill dir 등재 (live⊇registry 역은 과등재 허용). RED: registry 부재 시 FAIL 실측(staged) → GREEN
- [x] README `현재 73 PASS`→`74`(#36 동기)

### Task 3: improve-arch 프루닝 단계 + playbook 모델-업그레이드 체크리스트
**Files:** Modify: `skills/improve-codebase-architecture/SKILL.md`, `opencode-harness/skill/improve-codebase-architecture/SKILL.md`, `docs/harness-upgrade-2026-07/05-playbook.md`
- [x] improve-arch에 "스캐폴드 프루닝 후보 보고" 단계(registry 참조 + 미추적/무용 구성요소 후보 — 삭제 아닌 보고). 골격 유지 + 미러 동기
- [x] playbook에 "모델 업그레이드 체크리스트"(신모델 도입 시: skill 과처방 리뷰 = 02 §1 Fable 5 기준·registry 재확인·strip-and-measure 후보)

### Task 4: 1차 과처방 감사 보고
**Files:** Create: `docs/harness-upgrade-2026-07/c4-overprescription-audit.md`
- [x] skill 8종 각각: 유지/트림 판정 + 근거 1줄(Fable 5 기준 02 §1 "이전 모델용 과처방이 출력 열화" 대비). 후보 0이어도 skill별 근거 필수. 삭제 실행 없음(사용자 diff 후)

### Task 5: 검증 + Closeout
- [x] staged: registry seal RED→GREEN · verify-setup 74/0 · run-all 무회귀 · verify-all ALL PASS
- [x] 03 D12 재채점(1→3) · 04 GAP-005 DONE(L4 스코프 제외 선언) · README 상태 · PR→auto-merge→state bump→드리프트→보고+next-goal(C5)
