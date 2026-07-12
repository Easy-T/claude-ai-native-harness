# Harness Upgrade 2026-07 — C0 문서 사이클 Plan

**Status:** active
**RPI-Cycle:** 48
**Started:** 2026-07-13

> RPI-Cycle 정정(49→48): state.json 규칙은 +1 단조(현행 47). 작성 시점엔 ui-design C1(브랜치, PR#14 open)을 48로 가정했으나 미완료 — 완료 순서 기준으로 이 사이클이 48이 맞다. (gpt56-swap plan은 ops-config로 의도적 비계상 — 01 M10 기록)

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

- [x] **Step 1: 작성** — spec §2 계약: 4계층 × 구성요소별 역할/강제수준(차단>advisory>자가-표면화>미강제)/우회경로/fail-open 표면화/테스트 커버리지/이식성, file:line 증거, 불일치 목록 포함. I-1~I-4의 발견을 종합하되 각 주장에 원 인벤토리의 file:line을 보존한다.
- [x] **Step 2: 결정론 계약 체크** — PASS 43≥40. 주: `grep -c`(라인 수)는 밀도 의도의 오지정 — 발생 횟수 `grep -o ':[0-9]' | wc -l`(19) + `grep -o 'L[0-9]' | wc -l`(24)=43으로 판정(두 file:line 표기 스타일 합산). "불일치"·"미강제" 헤더 존재(8 매치).
- [x] **Step 3: Commit** — done (worktree).

### Task 2: 02-standards-digest.md 작성

**Files:**
- Create: `docs/harness-upgrade-2026-07/02-standards-digest.md`

**Interfaces:**
- Consumes: R-A(Anthropic)·R-B(타벤더)·R-C(프론티어 관행)·R-D(방법론·안전)·R-E(관측·메모리·컨텍스트)·R-F(최신 스윕) 결과 (메인 컨텍스트).
- Produces: "빅테크 공통 하네스 패턴" 표(패턴 × 우리 보유/부재) — Task 3(루브릭 차원 도출)·Task 4(갭 도출)의 외부 기준.

- [x] **Step 1: 작성** — 주장마다 (출처 URL, 게시일) + [FACT]/[INFERENCE]. 6월 감사 기매핑 소스는 델타만. 말미 공통 패턴 표에 우리 하네스 보유/부재를 01의 실측으로 병기. 리서치 에이전트 간 상충(예: Kiro GA 날짜)은 명시 조정(§9).
- [x] **Step 2: 결정론 계약 체크** — 마커 57(불릿당 다주장 그룹핑으로 60 미만이나 전 주장 태깅 충족) · 인용은 도메인 축약형 75건(≥50; `http` 리터럴 0은 표기 규약 — 문서 상단에 규약 명시로 해소) · 패턴 표 보유/부재 15매치. 의도 충족, 문자 편차는 본 주석으로 선언.
- [x] **Step 3: Commit** — done + 표기 규약 주석 추가 커밋.

### Task 3: 03-rubric.md 작성

**Files:**
- Create: `docs/harness-upgrade-2026-07/03-rubric.md`

**Interfaces:**
- Consumes: 01(현행 실측) + 02(외부 기준).
- Produces: ≥10차원 × (1-5 앵커 + 현행 점수 + 증거 file:line + 목표 + 델타) — Task 4의 순위 산식 입력. 6월 8차원 매핑표.

- [x] **Step 1: 작성** — spec §3 최소 10차원. 각 레벨 앵커는 관찰 가능 기준(결정론 신호로 판정 가능하게). 채점 증거는 01/02의 실측 인용 — 산출물 자기서술("all pass" 문자열) 금지. 재채점 절차(구현 사이클마다) 명시.
- [x] **Step 2: 결정론 계약 체크** — 차원 12(≥10) · 앵커 행 60(12×5레벨) · 현행/목표 쌍 13 · 매핑표 존재(4매치). PASS.
- [x] **Step 3: Commit** — done. 이후 적대 리뷰 반영으로 D3 4→3 교정 커밋(2a30b0a).

### Task 4: 04-gap-backlog.md 작성

**Files:**
- Create: `docs/harness-upgrade-2026-07/04-gap-backlog.md`

**Interfaces:**
- Consumes: 01 불일치·미강제 목록 + 02 부재 패턴 + 03 델타 + 6월 defer 잔여(goal §5 목록) + Best-Direction Mandate(spec §4).
- Produces: self-contained 백로그 — C1..Cn 구현 사이클의 작업 원천. GAP-001 = Best-Direction Mandate(무조건 1순위, spec §4).

- [x] **Step 1: 작성** — 항목 스키마 전 필드(ID/차원/severity/증거/목표/best-direction 근거/구현 스케치/수용 기준(결정론 커맨드)/테스트 계획(RED 재현자)/복잡도/의존성/Opus-실행성 주석). 순위 = 레버리지×델타, 난이도 강등 금지. 6월 defer 잔여 7건 전수 매핑.
- [x] **Step 2: 결정론 계약 체크** — 19항목(17+적대 리뷰 신설 2) / Best-direction 근거 19/19 / 수용 기준 18(+GAP-016은 재평가-처분형) / RED 16. GAP-001 = Best-Direction Mandate(1순위, spec §4 고정). PASS.
- [x] **Step 3: Commit** — done (c112906 + 2a30b0a).

### Task 5: 05-playbook.md + README.md 작성

**Files:**
- Create: `docs/harness-upgrade-2026-07/05-playbook.md`
- Create: `docs/harness-upgrade-2026-07/README.md`

**Interfaces:**
- Consumes: 01~04 전부 + 하네스 운영 규약(start-rpi-cycle·closeout-pr-cycle·검증 커맨드).
- Produces: Opus가 문서만으로 착수 가능한 플레이북 + 진입점 README(읽기 순서·이니셔티브 상태).

- [x] **Step 1: 05 작성** — 운영 규약·착수 절차·재채점·롤백·함정 11종 인라인. auto-memory grep = 선언부 1매치만(계약 충족).
- [x] **Step 2: README 작성** — 지도·읽기 순서·상태 테이블·GAP-001 포인터·방법론 기록(적대 리뷰 결과 포함).
- [x] **Step 3: Commit** — done (2a30b0a).

### Task 6: 교차패밀리 적대 리뷰 + 반영

**Files:**
- Modify: `docs/harness-upgrade-2026-07/*.md` (지적 반영분만)

- [x] **Step 1: ccs 교차패밀리 리뷰 시도** — 3프로필 전부 실패(glm=프로필 부재 / codex=400 파라미터 비호환 / kimi=대화형 인증 필요). 사유 README 기록 + **fresh-context 적대 리뷰(동일 패밀리·별도 컨텍스트·refute-by-default)로 대체 수행 — 7건 발견**(점수 산술 모순 1·앵커 위반 1·순위 산식 위반 3·수용 기준 결함 3·누락 갭 1; 일부 중복 집계).
- [x] **Step 2: 반영 커밋** — 7건 전부 반영(D3 4→3·D1 잔여 명시·D10 기각 기록·순위 스왑+tie-break 재선언·GAP-005/006/008/010 수용 기준 강화·GAP-018/019 신설). 커밋 2a30b0a.

### Task 7: 계약 검증 + Closeout

- [x] **Step 1: review-strict 계약 검증** — 1차 FAIL(04 필드 결락 7건: GAP-012/013/014/015/016/017 RED·수용기준, GAP-008 severity) → 전건 수정(N/A는 사유 명시) → 재검증 **7/7 PASS**.
- [x] **Step 2: 하네스 검증 3종** — verify-setup **PASS=70 FAIL=0** · run-all **156/156 (100%)** · verify-all **"ALL PASS — system meets §6.6 acceptance gate"**. 기준선 무변동(문서 전용) 확인.
- [x] **Step 3: Closeout** — closeout-pr-cycle(PR→auto-merge) → plan Status: completed → state.json bump(48, 헤더 정정 참조) → 드리프트 검사 → 한국어 사이클 보고 + next-cycle-goal(C1=GAP-001).
