# Harness Upgrade C3 — GAP-002 자율성 예산 governor Implementation Plan

**Status:** active
**RPI-Cycle:** 53
**Started:** 2026-07-13

**Best-Direction Check:** 최선안 = 에이전트 **밖** 결정론 상한 = 신규 PreToolUse `*`(catch-all, claude-code-guide 확인) hook이 세션당 도구호출 카운터를 증분·임계 차단(exit 2). 프롬프트-레벨 "토큰 아껴"는 02 §5가 실증 기각(과제 동기 생기면 무시). 기본 OFF(SESSION_TOOL_BUDGET 미설정 시 source 전 즉시 exit 0=비용 최소) → goal-loop만 opt-in. 카운터=세션-키 파일(worktrees-marker 선례), run-log 피기백(C2)로 BLOCK 자동 관측, `BUDGET_DIR` override(C2 RUNLOG_DIR 선례)로 hermetic 테스트. 채택안 = 동일. 토큰-기반(직접 비용) 대신 도구호출-count 채택은 04 스펙 명시+결정론·transcript 무의존 판단(열화 아닌 스펙 준수; 토큰-기반은 D5 L5/향후).
**스코프 명시(Gate P FLAG B — 무선언 회피)**: 04 GAP-002 목표 (a)(b)(c) 중 **(a) tool-call 카운터+임계차단만 이 사이클에서 구현**. (b) 사이클당 반복 상한(동일 커맨드 N회 실패 표면화)·(c) goal-doc 체크포인트 슬라이싱 규약은 **DEFERRED**: (b)는 verify-loop-watch/실패-반복 검출과 별개 메커니즘(GAP-010/별도 소관), (c)는 hook이 아닌 goal-작성 규약(문서 노트). 둘 다 (a)의 열화가 아니라 별 축이라 (a)를 온전히 구현하고 나머지는 04에 후속으로 명시. DOWNGRADE-DECLARED: 없음(방향 열화 아님 — 스코프 분할 선언).

**Goal:** 무인 세션이 `SESSION_TOOL_BUDGET=N` 설정 시 N번째 초과 도구호출을 exit 2로 차단(+`GOAL_BUDGET_SKIP` 우회), 80% 경고, 미설정 세션 무영향. 04 GAP-002 수용 기준이 SSOT.

## Global Constraints
- 04 수용: `SESSION_TOOL_BUDGET=5`→6번째 exit 2 + `GOAL_BUDGET_SKIP` 안내 · 미설정 무영향(전 기존 GREEN) · run-all 신규 ≥4 · #23 parity.
- fail-open: 카운터 읽기/쓰기 실패·SID 부재 → exit 0 통과(판정보다 안전 우선; 예산은 back-pressure이지 하드 보안 아님).
- **새 hook=11번째**: 5 seal 접점 동기 필수 — README `10개 hook`→11+행, doctor REQUIRED_HOOKS, verify-setup #8 목록+주석, install.sh REQUIRED, settings.json(라이브)+settings.example.json(#23 parity 양쪽).
- **★재시작 한계(정직 선언)**: 새 PreToolUse matcher는 세션 재시작 후 발화(README 경고). 이 세션에선 hook **로직**만 run-all로 검증 가능, **라이브 발화**는 재시작 후. PR/보고에 명시 — silent 아님.
- opencode 미러 미터치: budget은 claude-hooks 신규 표면, opencode는 자체 governance 모델(별도 이니셔티브). run-log(C2)와 동일 판단.

### Task 1: enforce-session-budget.sh (hook 로직)
**Files:** Create: `hooks/enforce-session-budget.sh`
- [ ] `[ -z "${SESSION_TOOL_BUDGET:-}" ] && exit 0`(source 전, 최소 off-비용) → source _common.sh → 숫자검증(비숫자/≤0→exit 0) → require_node → json_get_many session_id tool_name → SID 부재 exit 0
- [ ] 카운터 `${BUDGET_DIR:-$HOME/.claude/hooks/.budget}/<sid>` 증분(비숫자→0 리셋) · export RL_SID/RL_TOOL(run-log)
- [ ] GOAL_BUDGET_SKIP→hook_log PASS skip:+surface_bypass+exit 0 / CNT>budget→hook_log BLOCK+stderr(GOAL_BUDGET_SKIP·상향 안내)+exit 2 / CNT==ceil(budget*0.8) 최초→hook_log ALERT budget-80pct+emit_additional_context(session_marker 1회)+exit 0 / else exit 0(silent 증분)

### Task 2: settings 배선(라이브+example) + 5 seal 접점 동기
**Files:** Modify: `C:\Users\12132\.claude\settings.json`(라이브·gitignored), `settings.example.json`, `README.md`, `setup/doctor.sh`, `setup/verify-setup.sh`, `setup/install.sh`
- [ ] settings.json+example: PreToolUse `{"matcher":"*","hooks":[{"type":"command","command":"$HOME/.claude/hooks/enforce-session-budget.sh"}]}` (양쪽 동일 — #23 parity)
- [ ] doctor REQUIRED_HOOKS+enforce-session-budget.sh · verify-setup #8 loop+주석 10→11 · install.sh REQUIRED · README `10개 hook`→11+표행 · verify-setup #14 주석 정정(새 `*` matcher는 W|E|N/Bash 분해 밖 — cosmetic, FLAG NOTE)

### Task 3: session-start-audit .budget prune + RED 테스트 + 카운트
**Files:** Modify: `hooks/session-start-audit.sh`, `hooks/tests/run-all.sh`, `hooks/tests/cases.tsv`, `README.md`
- [ ] session-start-audit: stale `.budget/*`·`.budget/.warned-*` prune(7일+, 기존 marker prune 인접)
- [ ] run-all: sb-180(unset→exit 0)·sb-181(under→exit 0)·sb-182(over→exit 2, 카운터 프리시드)·sb-183(GOAL_BUDGET_SKIP+over→exit 0)·**sb-184(80% 경고 방출 단언 — additionalContext 출력 검사, FLAG A: 경고 브랜치 미테스트 방지)** — BUDGET_DIR override hermetic, 구현 전 RED
- [ ] cases.tsv 5행 + README 159→164

### Task 4: 검증 + Closeout
- [ ] staged run-all 163/163 · verify-setup(#8=11·#23 parity·#24 doctor⊇hooks) 신규수/0 · verify-all ALL PASS · 라이브 settings.json 배선(재시작 후 발화 확인은 사용자 몫—보고 명시)
- [ ] 03 D5 재채점(2→3: 결정론 iteration 감시 착륙; L4=OS sandbox는 GAP-007) · 04 GAP-002 DONE · README 상태 · PR→auto-merge→state bump(53)→드리프트→보고+next-goal(C4)
