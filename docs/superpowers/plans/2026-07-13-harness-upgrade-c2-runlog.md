# Harness Upgrade C2 — GAP-003 사이클 run-log Implementation Plan

**Status:** active
**RPI-Cycle:** 52
**Started:** 2026-07-13

**Best-Direction Check:** 최선안 = hook_log 초크포인트에 JSONL 이미터를 피기백(전 판정 지점 100% 커버, 단일 편집점) + gen_ai.* 필드 정렬 + 4 차단 hook의 기존 json_get_many 호출 확장(node 스폰 0 추가) / 채택안 = 동일. log_summary는 TSV 포맷 유지 + 신규 runlog_summary 분리(기존 doctor 소비 계약 보존 — SSOT/호환 판단이지 열화 아님). DOWNGRADE-DECLARED: 없음.

**Goal:** 게이트 발화·차단·우회·FAILOPEN이 구조화 JSONL(`hooks/.runlog/YYYY-MM.jsonl`, gen_ai.* 필드)로 기록되고 closeout이 요약을 소비한다 (04 GAP-003 수용 기준이 SSOT).

## Global Constraints
- 04 수용 기준: 차단·우회·통과 각 1회 후 JSONL ≥3 이벤트 && 각 이벤트에 `gen_ai.tool.name`·`verdict` && run-all 기존 전건 GREEN && log_summary 카운트 출력 유지.
- 로깅 실패가 판정을 막으면 안 됨(`|| true`, fail-open 원칙). JSON 조립은 printf(노드 의존 금지).
- cases.tsv·README 케이스 카운트 156→159 동기(seal #20). verify-setup 72 불변(#36 무영향).

### Task 1: `run_log_event` + hook_log 피기백 + runlog_summary (_common.sh)
- [ ] JSONL 필드: ts, session_id(RL_SID env), gen_ai.tool.name(RL_TOOL env), gen_ai.operation.name(hook명), verdict, target, reason — \\·" 이스케이프, 개행 불가(printf 1줄)
- [ ] hook_log 말미에 run_log_event 호출(초크포인트) · runlog_summary(당월 총 이벤트+verdict 카운트) · .gitignore `hooks/.runlog/` · `hooks/RUNLOG.md` 스키마 문서(간결)

### Task 2: 4 차단 hook RL_SID/RL_TOOL 인리치
- [ ] enforce-rpi-cycle(이미 SID/TOOL 추출 line 7)·rpi-bash(SID line 21, TOOL="Bash")·orchestrator(json_get→json_get_many, 스폰 0 추가)·secret-scan(json_get_many 1회 추가, 저빈도라 수용): session_id·tool_name → export RL_SID/RL_TOOL
- [x] ~~active-plan PASS 로깅 추가~~ — **불필요: enforce-rpi-cycle.sh:97·rpi-bash.sh:55가 이미 active-plan PASS를 hook_log에 기록**(초크포인트 피기백으로 자동 커버). plan 작성 시 과대기술 — 실물 확인 후 정정.

### Task 3: RED 테스트 3케이스 + 카운트 동기
- [ ] run-all에 rl-171(BLOCK 기록+JSON 유효성 node 파스)·rl-172(RPI_SKIP 우회 기록)·rl-173(active-plan PASS 기록) — 고유 타깃명 grep, 구현 전 RED 확인
- [ ] cases.tsv 3행 + README "156 케이스"→159 (seal #20 GREEN)

### Task 4: closeout 소비 규약 (SKILL.md canonical+미러)
- [ ] start-rpi-cycle Step C-1에 "runlog_summary 출력을 사이클 보고에 포함" 서브라인 (골격·seal 토큰 불변)

### Task 5: 검증 + Closeout
- [ ] staged-HOME 수용 실측(차단·우회·통과→JSONL≥3+필드) · run-all 159/159 · verify-setup 72/0
- [ ] 03 D4 재채점(3→4) · 04 GAP-003 DONE(+G6-b/G3-a 흡수 판정·GAP-016 처분 1사이클 카운트다운 개시) · README 상태 · PR→auto-merge → state bump → 보고
