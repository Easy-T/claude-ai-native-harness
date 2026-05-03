# PR Closeout Harness — Implementation Plan

**Status:** completed
**RPI-Cycle:** 2
**Started:** 2026-05-02

**Goal:** RPI Cycle의 Closeout을 GitHub PR lifecycle까지 확장. AI는 merge 전 review + 증거 제시 + 승인 요청까지만 수행하며, merge는 사용자 명시 승인 후에만 진행.

**Reference Spec:** `~/.claude/docs/superpowers/specs/2026-05-02-pr-closeout-harness-design.md` (Status: Approved)

---

## Task A: runbook.md.tpl 확장

파일: `~/.claude/skills/init-ai-ready-project/templates/runbook.md.tpl`

변경 내용:
- [x] "Local Quality Gate" 섹션 추가 (bash scripts/check.sh + 통과 기준)
- [x] "CI Gate" 섹션 추가 (gh pr checks --watch + 실패 대응)
- [x] "PR Creation" 섹션 추가 (push + gh pr create + PR body 기준)
- [x] "Pre-Merge Review" 섹션 추가 (review-strict 역할 설명)
- [x] "Merge Policy" 섹션 추가 (AI merge 결정 금지 + 4가지 조건 + 기본 명령)
- [x] 기존 섹션(Deploy/Rollback/...) 위치 유지

검증 기준:
- "Local Quality Gate" 헤더 존재
- "Merge Policy" 헤더 존재
- "AI는 merge를 결정하지 않는다" 문장 존재
- placeholder {{PROJECT_NAME}}, {{LOCAL_CHECK_COMMAND}} 존재

---

## Task B: scripts-check.sh.tpl 추가

파일: `~/.claude/skills/init-ai-ready-project/templates/scripts-check.sh.tpl`

내용:
- [x] shebang + set -euo pipefail
- [x] {{PROJECT_NAME}} echo 출력
- [x] {{CHECK_COMMANDS}} placeholder (stack별로 치환)
- [x] "check complete" echo 출력

검증 기준:
- 파일 존재
- shebang 라인 존재
- {{CHECK_COMMANDS}} placeholder 존재
- {{PROJECT_NAME}} placeholder 존재

---

## Task C: github-ci.yml.tpl 추가

파일: `~/.claude/skills/init-ai-ready-project/templates/github-ci.yml.tpl`

내용:
- [x] name: CI
- [x] on: pull_request + push (main/master)
- [x] multi-stack conditional setup (Python/Node/Rust)
- [x] `bash scripts/check.sh` 실행 step

검증 기준:
- 파일 존재
- "bash scripts/check.sh" 포함
- "on: pull_request" 포함

---

## Task D: stack-presets.md 갱신

파일: `~/.claude/skills/init-ai-ready-project/references/stack-presets.md`

변경 내용:
- [x] CHECK_COMMANDS 열 추가
- [x] SMOKE_COMMAND 열 추가
- [x] 각 stack별 값 입력

검증 기준:
- "CHECK_COMMANDS" 헤더 존재
- Python uv / Node / Rust / None 행 모두 존재

---

## Task E: init-ai-ready-project SKILL.md 갱신

파일: `~/.claude/skills/init-ai-ready-project/SKILL.md`

변경 내용:
- [x] Phase 2 생성 파일 목록에 #11 (scripts/check.sh), #12 (.github/workflows/ci.yml) 추가
- [x] 생성 디렉터리에 scripts/, .github/workflows/ 추가
- [x] Phase 3 검증 기준에 check.sh + ci.yml + runbook 섹션 검증 추가
- [x] 파일 수 설명 업데이트 (10 → 12개)

검증 기준:
- "#11" 또는 "scripts/check.sh" 포함
- "#12" 또는 "ci.yml" 포함
- Phase 3 success_criteria에 "scripts/check.sh" 포함

---

## Task F: closeout-pr-cycle/SKILL.md 생성

파일: `~/.claude/skills/closeout-pr-cycle/SKILL.md`

구조:
- [x] frontmatter: name, description, orchestrator_skill, generated_by, orchestrator_version
- [x] Phase 1 — Local Gate
- [x] Phase 2 — PR Gate
- [x] Phase 3 — CI Gate
- [x] Phase 4 — Senior Review (review-strict subagent)
- [x] Phase 5 — User Approval Gate
- [x] Phase 6 — Merge/Cleanup
- [x] Fallback: gh 미설치 / remote 없음 / main 브랜치 처리
- [x] Communication Protocol

검증 기준:
- orchestrator_skill: true 존재
- Phase 1~6 모두 존재
- "사용자 명시 승인" 또는 "User Approval" 포함
- Agent(subagent_type="review-strict") 포함
- "gh pr merge" 포함

---

## Task G: start-rpi-cycle Closeout 수정

파일: `~/.claude/skills/start-rpi-cycle/SKILL.md`

변경 내용:
- [x] Phase Closeout 시작에 조건부 closeout-pr-cycle 호출 로직 추가
- [x] 기존 review-strict, state/plan 갱신 로직은 유지
- [x] 조건: remote 존재 + gh 인증 + branch ≠ main/master

검증 기준:
- "closeout-pr-cycle" 참조 포함
- 기존 state.json, plan 갱신 로직 유지

---

## Task H: verify 스크립트 갱신

파일: `~/.claude/setup/verify-setup.sh` (존재 시)
파일: `~/.claude/setup/verify-integration.sh` (존재 시)

변경 내용:
- [x] closeout-pr-cycle/SKILL.md 존재 검증 추가
- [x] templates/scripts-check.sh.tpl 존재 검증 추가
- [x] templates/github-ci.yml.tpl 존재 검증 추가

---

## 완료 기준 (Closeout Gate)

- [ ] 12개 파일 생성 + 4개 디렉터리 (init-ai-ready-project)
- [ ] closeout-pr-cycle SKILL.md 존재 + Phase 1~6
- [ ] start-rpi-cycle에 closeout-pr-cycle 참조
- [ ] runbook.md.tpl에 "Local Quality Gate" + "Merge Policy"
- [ ] scripts-check.sh.tpl + github-ci.yml.tpl 존재
- [ ] verify scripts 통과
- [ ] git commit (feat(harness): add PR closeout cycle v1)
