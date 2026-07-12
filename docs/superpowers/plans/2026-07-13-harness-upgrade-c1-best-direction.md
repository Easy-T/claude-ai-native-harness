# Harness Upgrade C1 — Best-Direction Mandate + 정합 seal Implementation Plan

**Status:** completed
**RPI-Cycle:** 50
**Started:** 2026-07-13
**Completed:** 2026-07-13

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (메인 직접 — 2항목 소사이클). spec delta 없음(durable spec §4가 설계 SSOT — 재확인 완료, no-op).

**Goal:** GAP-001(Best-Direction Mandate 4층: 헌법 정련·plan 필수 필드·closeout 검출·seal #35) + GAP-009(문서↔실물 정합 M1-M8 + 카운트 seal #36)를 TDD(RED-first)로 구현·머지한다.

**Architecture:** seal 먼저 추가해 RED 실측 → 토큰/문서 수정으로 GREEN → staged-HOME(워크트리 rsync 복제 + HOME override) 전건 검증 → auto-merge. verify-setup은 $HOME 절대경로 검사이므로 워크트리 검증은 반드시 staged-HOME 패턴.

**Best-Direction Check:** 최선안 = 04 GAP-001/009의 "Best-direction 근거" 그대로(4층 자가-표면화+seal; prose-only 대안 기각, 카운트는 seal 동반). 채택안 = 동일. DOWNGRADE-DECLARED: 없음.

## Global Constraints

- 04 수용 기준이 성공 기준의 SSOT: `grep -c 'Best-Direction Check'` ≥2 · `DOWNGRADE-DECLARED` ≥1 (SKILL.md) · 신규 seal RED→GREEN 실증 · verify-setup 전건(72/0 예상) · run-all 156/156.
- SKILL.md 편집은 enforce-orchestrator 골격(Phase ≥3·Agent() ≥1·Communication Protocol) 유지. opencode 미러 skill 본문 동기.
- CLAUDE.md는 워크트리 사본 편집(라이브 세션 캐시 무영향 — 라이브 반영은 머지 후 pull 시점=세션 경계, §1 충족) + **diff를 사이클 보고에 포함**(GAP-001 무인-모드 조항).
- 타 세션 파일 무수정(동시-세션 격리): ui-design c1 plan(master상 stale-active, 실제는 그쪽 브랜치서 completed)은 건드리지 않는다 — staged 검증은 내 plan flip 후(active ≤1 성립) 수행.
- M7은 서술/주석만(트리거 % 행동 변경은 GAP-018 소관). M8은 결번 주석(재번호는 C5 용어 고정 탓 기각).

### Task 1: seal #35(BD 토큰)·#36(카운트 parity) 추가 + RED 실측

**Files:** Modify: `setup/verify-setup.sh` (tail, #34 뒤)

- [x] #35: start-rpi-cycle SKILL.md에 `Best-Direction Check` ≥2 && `DOWNGRADE-DECLARED` ≥1 (#17 동형 토큰 parity)
- [x] #36: 스크립트 말미에서 `EXPECTED=$((PASS+FAIL+1))` vs README 선언 숫자(`verify-setup.*([0-9]+) PASS` 앵커) 비교 — 런타임 자기-카운트라 향후 체크 추가 시 README 미동기가 자동 FAIL
- [x] RED 실측: `rsync worktree→$TMP/h/.claude; HOME=$TMP/h bash verify-setup.sh` → #35 FAIL(토큰 부재)·#36 FAIL(README=66≠실측) 확인 후 커밋

### Task 2: start-rpi-cycle SKILL.md — Phase P 필드·Gate P·C-1 기준 + 미러 동기

**Files:** Modify: `skills/start-rpi-cycle/SKILL.md`, `opencode-harness/skill/start-rpi-cycle/SKILL.md`

- [x] Phase P plan 헤더 규약에 `**Best-Direction Check:**` 필수 필드(최선안/채택안/다르면 DOWNGRADE-DECLARED(사유)+사용자 승인) 추가
- [x] Gate P success_criteria에 "Best-Direction Check 필드 부재 = FAIL" 추가
- [x] Step C-1 drift success_criteria에 "silent-downgrade 검출: spec 목표 설계 vs 구현 실물 대조 — 미신고 열화 FAIL" 추가
- [x] 미러 SKILL.md 동일 편집 · #35 GREEN 확인 · 커밋

### Task 3: CLAUDE.md Simplicity First 정련

**Files:** Modify: `CLAUDE.md` (Simplicity First 절, ≤200줄 유지)

- [x] 스코프 최소주의(유지) vs 아키텍처 품질(신설: 채택 설계는 알려진 최선, 열화는 DOWNGRADE-DECLARED 없이 불가) 구분 삽입 — diff 보고 의무 · 커밋

### Task 4: GAP-009 M1·M2·M3·M5·M6·M7·M8 정정

**Files:** Modify: `README.md`, `hooks/worktree-teardown.sh`, `hooks/tests/worktree-teardown.test.sh`, `hooks/auto-compact-watch.sh`

- [x] M1: README verify-setup 카운트 66→72(신규 2 포함) → #36 GREEN
- [x] M2: README 창 매핑에 fable·`[1m]` 반영 / M3: ccs-delegation 비추적-skill 각주 / M5: verify-setup.sh:85 주석 =11 / M6: teardown "SessionStart 마커" stale 주석 2곳 정정 / M7: acw "기본 95" 서술 정정(행동 무변경) / M8: GUARD 4 결번 주석 · 커밋

### Task 5: 전건 검증 (staged-HOME)

- [x] 내 plan Status→completed flip(active ≤1 성립) → fresh staged-HOME에서 `verify-setup` **72/0 실측** + 워크트리 `run-all` **156/156** + `worktree-teardown.test` **25/25**
- [x] verify-all은 staged-HOME 재실행으로 확증(아래 Task 5b) — 1차 staged 실행의 doctor FAIL 2건은 `.gitconfig` 미복사 스테이징 아티팩트(git identity), 실환경 무관
- [x] FAIL 시 flip 되돌려 수정 후 재실행 — 발생: drift 검사가 체크박스 미갱신 2건 적발(신규 silent-downgrade 기준의 첫 자기적용이 자기 사이클 기록 누락을 포착) → 본 갱신으로 시정

### Task 6: Closeout

- [x] 03 D10 재채점(1→4, 사유+증거) · 04 GAP-001/009 DONE + GAP-017 처분 판정(신규 seal 대표 변이 여부) · README 상태(C1 완료, 다음 C2=GAP-003) — 같은 커밋
- [x] PR 생성→auto-merge → state.json 50 → 드리프트 검사(신규 C-1 기준 포함 — silent-downgrade 자기적용) → 한국어 보고(+CLAUDE.md diff) + next-cycle-goal(C2=GAP-003)
