# Harness Upgrade 2026-07 — C0 문서 사이클 Plan

**Status:** active
**RPI-Cycle:** 49
**Started:** 2026-07-13

> **For agentic workers:** 이 plan은 문서-전용 사이클 — Phase I는 메인 세션이 직접 실행(executing-plans). 리서치 6축(R-A~R-F)·인벤토리 4축(I-1~I-4) 결과는 메인 세션 컨텍스트에 이미 수집됨 — subagent 위임 시 이 원료가 소실되므로 문서 작성은 위임 금지.

**Goal:** `docs/harness-upgrade-2026-07/` 문서 6종(README, 01-structure-map, 02-standards-digest, 03-rubric, 04-gap-backlog, 05-playbook)을 spec §2 계약대로 작성·검증·머지해 deadline invariant를 충족한다.

**Architecture:** 수집된 리서치·인벤토리를 메인 세션이 문서로 증류 → 문서별 결정론 계약 체크(grep 앵커) → 교차패밀리 적대 리뷰 시도 → review-strict 계약 검증 → closeout-pr-cycle(auto-merge).

**Tech Stack:** markdown only (코드 변경 0 — 비-목표: spec §8).

## Global Constraints

- spec: `docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md` — 문서 계약의 SSOT.
- goal: `_goal/harness-upgrade-2026-07-goal.md` — MERGE_POLICY: auto (사용자 지시 2026-07-13).
- 02의 모든 주장에 출처 URL+게시일 + [FACT]/[INFERENCE] 구분. 03의 모든 채점에 file:line 증거. 04의 모든 항목에 best-direction 근거. (spec §7)
- 04 순위 = 레버리지 × 루브릭 델타 — 구현 난이도로 순위 강등 금지. (spec §2)
- 05는 auto-memory 참조 금지 — 필요 사실 인라인 재서술. (spec §5)
- 갱신 계약(Gate R unknown 해소): 구현 사이클마다 04(상태)·03(재채점)·README(이니셔티브 상태) 필수 갱신 + 05는 운영 규약이 바뀐 경우 갱신. goal §6과 spec §2를 합집합으로 채택.
- seal 참조는 #17~#34(#26 소각) — goal 문서의 "#17~#30" 표기는 stale(Gate R 확인), 문서에는 실측값 사용.
- verify-setup 기준선 70/0 (README "66"은 stale — 04 갭 후보로 등재).

---

### Task 1: 01-structure-map.md 작성

**Files:**
- Create: `docs/harness-upgrade-2026-07/01-structure-map.md`

**Interfaces:**
- Consumes: I-1(hooks)·I-2(skills/agents)·I-3(검증 인프라)·I-4(거버넌스) 인벤토리 결과 (메인 컨텍스트).
- Produces: 4계층 구조맵 + "서술↔실물 불일치" 목록 + "미강제 규칙" 목록 — Task 4(백로그)의 증거 원천.

- [ ] **Step 1: 작성** — spec §2 계약: 4계층 × 구성요소별 역할/강제수준(차단>advisory>자가-표면화>미강제)/우회경로/fail-open 표면화/테스트 커버리지/이식성, file:line 증거, 불일치 목록 포함. I-1~I-4의 발견을 종합하되 각 주장에 원 인벤토리의 file:line을 보존한다.
- [ ] **Step 2: 결정론 계약 체크** — Run: `grep -c ':[0-9]' 01-structure-map.md` ≥ 40 (file:line 증거 밀도) && 섹션 헤더에 "불일치"·"미강제" 존재.
- [ ] **Step 3: Commit** — `git add docs/harness-upgrade-2026-07/01-structure-map.md && git commit -m "docs(harness-upgrade): 01 구조맵 — 4계층 전수 인벤토리"`

### Task 2: 02-standards-digest.md 작성

**Files:**
- Create: `docs/harness-upgrade-2026-07/02-standards-digest.md`

**Interfaces:**
- Consumes: R-A(Anthropic)·R-B(타벤더)·R-C(프론티어 관행)·R-D(방법론·안전)·R-E(관측·메모리·컨텍스트)·R-F(최신 스윕) 결과 (메인 컨텍스트).
- Produces: "빅테크 공통 하네스 패턴" 표(패턴 × 우리 보유/부재) — Task 3(루브릭 차원 도출)·Task 4(갭 도출)의 외부 기준.

- [ ] **Step 1: 작성** — 주장마다 (출처 URL, 게시일) + [FACT]/[INFERENCE]. 6월 감사 기매핑 소스는 델타만. 말미 공통 패턴 표에 우리 하네스 보유/부재를 01의 실측으로 병기. 리서치 에이전트 간 상충(예: Kiro GA 날짜)은 명시 조정.
- [ ] **Step 2: 결정론 계약 체크** — Run: `grep -c '\[FACT\]\|\[INFERENCE\]' 02-standards-digest.md` ≥ 60 && `grep -c 'http' ` ≥ 50 && 패턴 표에 "보유"/"부재" 열 존재.
- [ ] **Step 3: Commit** — `"docs(harness-upgrade): 02 표준 다이제스트 — 2026.07 6축 + 공통패턴 표"`

### Task 3: 03-rubric.md 작성

**Files:**
- Create: `docs/harness-upgrade-2026-07/03-rubric.md`

**Interfaces:**
- Consumes: 01(현행 실측) + 02(외부 기준).
- Produces: ≥10차원 × (1-5 앵커 + 현행 점수 + 증거 file:line + 목표 + 델타) — Task 4의 순위 산식 입력. 6월 8차원 매핑표.

- [ ] **Step 1: 작성** — spec §3 최소 10차원. 각 레벨 앵커는 관찰 가능 기준(결정론 신호로 판정 가능하게). 채점 증거는 01/02의 실측 인용 — 산출물 자기서술("all pass" 문자열) 금지. 재채점 절차(구현 사이클마다) 명시.
- [ ] **Step 2: 결정론 계약 체크** — 차원 수 ≥10 && 각 차원에 "현행"·"목표"·앵커 5레벨 && 6월 매핑표 존재.
- [ ] **Step 3: Commit** — `"docs(harness-upgrade): 03 루브릭 v2 — 12차원 앵커+채점"`

### Task 4: 04-gap-backlog.md 작성

**Files:**
- Create: `docs/harness-upgrade-2026-07/04-gap-backlog.md`

**Interfaces:**
- Consumes: 01 불일치·미강제 목록 + 02 부재 패턴 + 03 델타 + 6월 defer 잔여(goal §5 목록) + Best-Direction Mandate(spec §4).
- Produces: self-contained 백로그 — C1..Cn 구현 사이클의 작업 원천. GAP-001 = Best-Direction Mandate(무조건 1순위, spec §4).

- [ ] **Step 1: 작성** — 항목 스키마 전 필드(ID/차원/severity/증거/목표/best-direction 근거/구현 스케치/수용 기준(결정론 커맨드)/테스트 계획(RED 재현자)/복잡도/의존성/Opus-실행성 주석). 순위 = 레버리지×델타, 난이도 강등 금지. 6월 defer 잔여(goal-loop 예산·observability·dead-scaffold pruning·sandbox 티어·G6-b·G3-a·rank9B) 자동 편입 재평가.
- [ ] **Step 2: 결정론 계약 체크** — 모든 항목에 "Best-direction:"·"수용 기준"·"RED" 필드 존재(grep) && GAP-001이 Best-Direction Mandate.
- [ ] **Step 3: Commit** — `"docs(harness-upgrade): 04 갭 백로그 — N항목 + 순위 산식"`

### Task 5: 05-playbook.md + README.md 작성

**Files:**
- Create: `docs/harness-upgrade-2026-07/05-playbook.md`
- Create: `docs/harness-upgrade-2026-07/README.md`

**Interfaces:**
- Consumes: 01~04 전부 + 하네스 운영 규약(start-rpi-cycle·closeout-pr-cycle·검증 커맨드).
- Produces: Opus가 문서만으로 착수 가능한 플레이북 + 진입점 README(읽기 순서·이니셔티브 상태).

- [ ] **Step 1: 05 작성** — 사이클 운영 규약(spec/plan 경로·게이트·검증 커맨드 전문: verify-setup/run-all/verify-all/드리프트), 항목 착수 절차, 재채점 절차, 롤백 규약, 하네스 함정(캐시 §1·seal 발화·opencode 미러 sync·enforce-orchestrator 골격·worktree 규약·[1m] suffix 등) 인라인. auto-memory 참조 0 (grep 'MEMORY.md\|projects.*memory' 매치는 "참조 금지" 선언부만 허용).
- [ ] **Step 2: README 작성** — 문서 지도·읽기 순서·상태 테이블(C0 완료, C1.. 대기)·Opus 첫 착수 포인터(GAP-001).
- [ ] **Step 3: Commit** — `"docs(harness-upgrade): 05 플레이북 + README 진입점"`

### Task 6: 교차패밀리 적대 리뷰 + 반영

**Files:**
- Modify: `docs/harness-upgrade-2026-07/*.md` (지적 반영분만)

- [ ] **Step 1: ccs gpt 프로필로 03·04 핵심 판정 refute-by-default 리뷰 시도** — Run: `ccs` CLI 가용 확인 후 03 채점·04 순위에 대한 반증 요청. 불가 시(프록시/인증) 사유를 README 상태 절에 기록하고 진행(spec §5).
- [ ] **Step 2: 반영 커밋** — 유효 지적만 수정. `"docs(harness-upgrade): 적대 리뷰 반영"`. 지적 0건이면 커밋 생략하고 README에 결과 기록.

### Task 7: 계약 검증 + Closeout

- [ ] **Step 1: review-strict 계약 검증** — spec §2 표의 6문서 계약 항목별 PASS/FAIL + spec §7 수용 기준. FAIL 시 수정 후 재실행.
- [ ] **Step 2: 하네스 검증 3종** — Run: `bash setup/verify-setup.sh`(70/0) && `bash hooks/tests/run-all.sh`(156/156) && `bash setup/verify-all.sh`(ALL PASS). 문서 전용이므로 기준선 무변동이어야 정상.
- [ ] **Step 3: Closeout** — closeout-pr-cycle(PR 생성→검증→auto-merge, MERGE_POLICY: auto) → plan Status: completed → state.json bump(49) → 드리프트 검사 → 한국어 사이클 보고 + next-cycle-goal(C1=GAP-001).
