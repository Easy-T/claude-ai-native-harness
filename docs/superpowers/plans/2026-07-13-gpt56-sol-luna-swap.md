# GPT 슬롯 세대교체 (gpt-5.5→Sol, gpt-5.4-mini→Luna) Implementation Plan

**Status:** completed (2026-07-13 · run-tests 31/31 fail=0 · 464/1000 bytes · review-strict PASS · 헤드리스 E2E luna/sol/fable 실측)

**Goal:** settings.json GPT 슬롯 2개를 GPT-5.6 세대(gpt-5.6-sol/gpt-5.6-luna)로 교체하고, statusline 창 매핑을 실측 카탈로그 값(372K)으로 갱신한다.

**Authority:** 이 plan은 위임 goal 프롬프트가 R+P를 대체한다는 명시 하에 작성됨
(`C:/Users/12132/Documents/claude_routing_project/goal-prompt-gpt56-sol-luna-swap-2026-07-12.md`,
헤더의 `RPI_SKIP=ops-config-task-with-explicit-goal-prompt` 근거). 세션 env로 RPI_SKIP을 주입할 수 없어
(훅은 CLI 부모 프로세스 env 상속) 동등한 정식 경로인 활성 plan으로 게이트를 통과한다.

**실측 근거 (Phase A, 2026-07-12/13):**
- 프록시 `/v1/models`: `gpt-5.6-sol`·`gpt-5.6-terra`·`gpt-5.6-luna` 존재 확인
- luna는 핀 7.1.68-6에서 upstream 404 → CLIProxy Plus **7.2.62-5**로 핀 갱신(upstream fix 26d45fd, v7.2.58+) 후 정상
- codex 카탈로그(`/v1/models?client_version=codex`): 전 5.6 티어 `context_window: 372000`
- systemrole 회귀(2026-05-31 핀 사유) 재검증: 실 CLI full request `--model gpt-5.5`/`haiku` → pong, 400 없음

## Tasks

- [x] Task 1: settings.json haiku/custom 슬롯 6키 교체 (백업 .bak-20260712) — gitignored, repo 커밋 대상 아님
- [x] Task 2: spec v2.2 개정 (2026-05-31-statusline-balanced-design.md 창 매핑 표)
- [x] Task 3: statusline.sh FLOOR 테이블에 `*GPT-5.6*|*gpt-5.6*` → 372000 케이스 추가 (mini 케이스보다 위)
- [x] Task 4: tests/statusline/fixtures/gpt56-luna.json 신규
- [x] Task 5: run-tests.sh T7 추가 (372k floor + pct 재계산 + 1M 칩 부재)
- [x] Task 6: run-tests.sh 전체 green + 바이트 예산(≤1000) + review-strict 독립 검증
- [x] Task 7: Closeout — 결과 문서·README 배너·routing-state.json·커밋/PR/머지(사용자 지시)

## Verification

- `bash ~/.claude/tests/statusline/run-tests.sh` → fail=0
- 라이브 렌더 바이트 감사 ≤1000
- 헤드리스 실측: haiku→gpt-5.6-luna·custom→gpt-5.6-sol (modelUsage+트랜스크립트 message.model+resp_ prefix), fable 1M 무영향
