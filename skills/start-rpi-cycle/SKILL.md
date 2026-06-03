---
name: start-rpi-cycle
description: |
  새 작업/기능/버그 수정 시작 시 RPI 사이클을 강제. 사용자가 "기능 추가", "이거 고쳐줘",
  "구현해줘", "리팩토링" 등을 말하면 무조건 사용. 직접 코드 작성 금지.
  trivial 변경(≤5라인 수정)은 예외 — enforce-rpi-cycle hook이 자동 통과시킴.
orchestrator_skill: true
generated_by: built-in
orchestrator_version: 1.0
---

# start-rpi-cycle

※ superpowers의 brainstorming / writing-plans / executing-plans는 모두 **메인 세션의 skill**.
   sub-agent에 위임 X — 메인이 절차를 따름.
   sub-agent 위임은 explore-strict / review-strict / execute-strict (우리 wrapper)만.

# Phase R — Research

A. brainstorming skill 절차 (메인이 직접 따름) — 외향적 (요구·접근법·디자인)
   ※ spec은 서브시스템당 durable 진실원천 (사이클당 아님 — 사이클당인 건 plan).
     · 신규 subsystem → 새 spec 생성: docs/superpowers/specs/YYYY-MM-DD-<subsystem>-design.md
     · 기존 subsystem 재진입 → 해당 durable spec 재사용(읽기), 새로 쓰지 않음.
       (여러 독립 subsystem이면 brainstorming이 sub-project spec으로 분할 — superpowers 규약)
   ※ 누적 CONTEXT.md가 있으면 그 어휘를 기반으로 사용

B. grill-with-docs skill 절차 (메인이 직접 따름) — A의 design을 도메인 모델·코드에 비춰 stress-test
   ※ 미설치 시: `bash ~/.claude/setup/doctor.sh` 로 자동 설치
   → 산출물: CONTEXT.md 갱신(용어집), ADR(조건부)
   ※ ADR은 docs/ai-context/architecture.md (append-only, §5 SSOT)에 기록 — grill 기본 docs/adr/ 대신 하네스 SSOT 사용
   → grill 종료 후 메인이 직접: domain-glossary.md 메타데이터 테이블에 신규 용어 기록
   ★ spec delta 결정 (이진, 필수 — 재진입 사이클의 핵심):
     이번 R(grill 포함)이 durable spec에 없던 design 결정·교정된 의미·새 제약을 드러냈는가?
     · YES → writing-plans 전에 durable spec에 in-place 개정(개정일+근거 ADR) 또는 §5 ADR 추가.
     · NO  → "spec 재확인, delta 없음(no-op)" 명시 후 진행 (재진입 사이클의 정상 경로).
     (grill은 spec을 안 건드리므로, delta가 있는데 이 역류를 빠뜨리면 writing-plans가 낡은 spec을 읽는다.)

C. Agent(subagent_type="explore-strict",
        task="<요청 분석>",
        context_paths=["CONTEXT.md",
                       "docs/ai-context/architecture.md",
                       "docs/ai-context/domain-glossary.md",
                       "docs/ai-context/non-obvious.md",
                       "docs/ai-context/deny-patterns.md"],
        success_criteria="발견사항·영향 모듈·신규 도메인 용어·deny pattern 충돌 식별")
   ※ CLAUDE.md는 메인이 자동 로드하므로 context_paths에 미포함 (중복 회피)
   ※ C는 B와 병렬·교차 가능 (A 완료 후)

## Gate R (차단형 — review-strict)
1. Agent(subagent_type="review-strict",
        task="spec ↔ 도메인 어휘/grill 결과 일관성 검증",
        context_paths=["CONTEXT.md",
                       "<재사용 중인 subsystem spec: docs/superpowers/specs/YYYY-MM-DD-<subsystem>-design.md>"],
        success_criteria="
          PASS only if ALL:
          - design spec 파일 존재
          - spec 도메인 용어가 CONTEXT.md canonical과 일치 (_Avoid_ 별칭 누출 0)
          - spec delta가 있으면 durable spec/ADR에 반영됨; 없으면 "delta 없음(no-op)" 명시
          - CONTEXT.md 갱신됨 또는 신규 용어 없음(no-op) 명시
          FAIL with: 누락 용어·미반영 결정·spec 부재 목록")
   FAIL 시: spec 역류/CONTEXT.md 보강 후 재실행 (또는 사용자가 \"Gate R override: <이유>\" 명시)
2. 신규 도메인 용어 confidence < 80% → 사용자 확인 → domain-glossary.md 메타데이터 추가
3. 아키텍처 영향 → ADR을 architecture.md(append-only)에 작성 권유

# Phase P — Plan

writing-plans skill 절차 (메인이 직접) → docs/superpowers/plans/YYYY-MM-DD-<topic>.md
plan 상단 헤더 주입 (writing-plans 표준 헤더 위에):
  **Status:** active
  **RPI-Cycle:** N
  **Started:** YYYY-MM-DD

## Gate P

1. active plan 파일 존재 확인 (enforce-rpi-cycle hook이 의존)

2. Agent(subagent_type="review-strict",
        task="spec vs plan alignment verification",
        context_paths=[
          "<재사용 중인 subsystem spec: docs/superpowers/specs/YYYY-MM-DD-<subsystem>-design.md>",
          "<현재 plan 경로: docs/superpowers/plans/YYYY-MM-DD-<topic>.md>"
        ],
        success_criteria="
          PASS only if ALL:
          - spec의 모든 핵심 요구사항이 plan task로 커버됨
          - plan에 spec 범위 밖 scope creep 없음
          - 각 task의 검증 기준이 명확함
          - task 간 의존 순서가 논리적

          FAIL with:
          - 미커버 spec 요구사항 목록
          - scope creep 의심 task 목록
          - 불명확한 검증 기준 목록
        ")

   FAIL 시:
   - 갭 목록을 사용자에게 제시
   - scope creep이 정당하지 않으면 → plan을 spec 범위로 축소
   - R이 발견한 정당한 신규 design이면 → plan을 깎지 말고 durable spec에 in-place 개정 또는 §5 ADR 추가 후 Gate P 재실행
   - 미커버 spec 요구사항 → plan 보강 후 재실행
   - override 문구 예시: "Gate P override: <이유>" 명시 시 Phase I 진행 허용

# Phase I — Implement

구현 방식 선택:
- (a) **subagent-driven-development** (superpowers 권장) — 메인이 절차 따라 task별로 execute-strict 위임
- (b) **executing-plans** skill — 메인이 절차 따름 (단일 세션 내). 끝나면 superpowers의 finishing-a-development-branch가 자동 호출됨.
- (c) execute-strict 직접 위임 — 단순 task에 한해

권장:
- 큰 사이클 (≥5 task) → (a)
- 중간 사이클 (2~5 task) → (b)
- 작은 사이클 (≤2 task) → (c)

worktree 사용:
- 같은 파일을 동시 수정 / 격리된 검증 필요 시 → 호출 시 isolation: worktree 명시
- 부트스트랩처럼 다른 파일 병렬 → worktree 불필요

# Phase Closeout

※ Phase I에서 executing-plans (b)를 선택했다면, superpowers가 자동으로
   finishing-a-development-branch skill을 호출. 그 결과를 받아 우리 Closeout이 보강 검증.
   (a)/(c)를 선택했다면 우리 Closeout이 단독으로 실행.

## Step C-0: PR Closeout Gate (조건부)

다음 조건을 모두 충족하면 closeout-pr-cycle skill 호출:
- `git remote get-url origin` 성공 (원격 repo 존재)
- `gh auth status` 성공 (gh 인증됨)
- 현재 branch ≠ main/master

조건 미충족 시:
- local check만 실행 (`bash scripts/check.sh` 존재 시)
- WARN: "PR lifecycle 미수행 — [이유: remote 없음/gh 미인증/main 브랜치]"
- Step C-1 (drift check)로 계속

closeout-pr-cycle 결과를 받아:
- COMPLETE: merge 완료. Step C-1 진행.
- ABANDONED: 사용자가 PR 닫기 선택. abandoned 기록.
- PARTIAL: gh 없음 등. WARN 기록 후 계속.
- FAIL: 오류 내용 사용자 보고 후 재시도 여부 확인.

## Step C-1: Drift Check

1. Agent(subagent_type="review-strict",
        task="사이클 마감 점검 (drift + 자산 갱신 검증)",
        context_paths=["CONTEXT.md",
                       "docs/ai-context/architecture.md",
                       "docs/ai-context/domain-glossary.md",
                       "docs/ai-context/non-obvious.md"],
        success_criteria="
          - CONTEXT.md 갱신 (신규 용어 추가됨) 또는 변경 없음 확인
          - architecture.md 갱신 (모듈/의존성 변경 반영) 또는 변경 없음 확인
          - domain-glossary.md 갱신 또는 변경 없음 확인
          - 사이클 중 발생한 실패가 5 Whys 통과 후 non-obvious.md 누적 (또는 명시 면제)
          - plan 모든 체크박스 [x] 또는 명시적 미완료 사유 기록
          - finishing-a-development-branch 산출물(브랜치/PR)이 존재 시 일관성 (선택)
        ")

2. plan 헤더 갱신: **Status:** active → completed (또는 abandoned 시 abandoned) (메인이 직접 Edit)

3. .claude/state.json 갱신 (메인이 jq 또는 node로 read-modify-write):
   ※ 전체 스키마: `.claude/state.schema.json` (v2/v3 optional 필드 포함)
   - cycle.count +1 (abandoned 시 +0)
   - cycle.last_completed_at: today
   - audit.last_drift_check: today

4. 사용자 승인형 v2/v3 알림 + 아키텍처 개선 제안:
   - cycle.count == 5 && !v2_enabled && !v2_skipped_permanently → "v2 도입 가능" 묻기
   - cycle.count == 20 && !v3_enabled && !v3_skipped_permanently → "v3 도입 가능" 묻기
   - 사용자: 활성화 / 건너뛰기 / 영구 건너뛰기 (3택)
   - cycle.count % 5 == 0 (단, cycle.count > 0) → "improve-codebase-architecture 실행 권장 시점입니다. 실행할까요?" 제안

5. Non-obvious archive 검사:
   - active ≥ 30 항목 또는 ≥ 100줄 → 가장 오래된 비재발(카운터=0) 5개 archive로 이동
   - archive ≥ 500줄 → "archive 정리할까요?" 묻기
   - v2 활성 시: archive 항목이 다시 매칭되면 active로 복귀 + High Priority 즉시 승격

6. 전역 하네스(~/.claude) 자체를 수정한 사이클이면: `bash ~/.claude/setup/verify-setup.sh` 실행 →
   PASS 확인 (cross-doc drift 게이트 #17: §3↔Phase R 포함). FAIL이면 문서 불일치 수정 후 재실행.

## Sub-cycle states
- active / in_progress: 진행 중
- completed: 완료
- abandoned: 중단 (cycle.count 증가 없음)
- paused: 일시 중지 (enforce-rpi-cycle이 active로 인식 안 함)
  재개: plan **Status:** paused → active 로 직접 수정

## Communication Protocol
- result: COMPLETE / FAIL
- evidence: Phase별 산출물 경로 + Closeout review-strict 결과
- unknowns: 사용자에게 추가 결정 권고
