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
   sub-agent에 위임 X — 메인이 **Skill 도구로 호출**해 절차를 따름("절차 체화"가 아니라 실제 호출 — Closeout `phase-skills:` 로 선언).
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
- (d) **ultracode Workflow 구동** (ultracode ON일 때만 표면 — OFF면 이 옵션 비활성, 항상-on 권유 없음) —
      Phase I 한정(R/Closeout 병렬화는 ceremony라 제외). plan task를 canonical 2-stage 파이프라인으로:
      stage1 `agentType='execute-strict'`(구현) → stage2 `agentType='review-strict'`(검증).
      ※ 두 스테이지 모두 **schema 금지** — 제약된 wrapper agentType은 StructuredOutput 부재로 schema와 함께 실패 ([[feedback_workflow_agenttype_schema]] 교훈; schema 복원 유혹 금지).
      ※ wrapper는 self-spawn 불가 → execute→verify는 반드시 별도 2 스테이지(한 에이전트가 둘 다 못 함).
      ※ **데이터 의존(load-bearing):** stage2(review-strict는 읽기전용)는 stage1이 산출한 변경(diff/수정 파일)을 context_paths로 **반드시 받아** 검증. 순서만 맞고 stage1 산출을 안 먹이면 stale·빈 상태를 검증해 false PASS — pipeline의 prevResult + 수정 파일 경로를 stage2 context_paths에 명시 전달.
      ※ **검증 기준 명시:** stage2에 plan task별 success_criteria를 `PASS only if ALL ...` 형태로 전달(Gate R/P/Closeout과 동형). 빈/모호 기준이면 올바른 diff를 읽고도 vacuous PASS 가능.
      ※ 같은 파일을 동시 수정하는 task ≥2면 각 스테이지에 `isolation:'worktree'`. 이 경우 stage2는 **짝지은 stage1과 같은 worktree에서** 리뷰해야 함(base/다른 컨텍스트에서 읽으면 미변경 파일을 봐 false PASS/FAIL).
      ※ 우회 불가: plan-존재·spec-before-plan 게이트(enforce-rpi-cycle = PreToolUse `Write|Edit|NotebookEdit` 매처)는 **Workflow 서브에이전트의 execute-strict 쓰기에도 동일 발화**하고, 메인 세션이 R→P를 통과해 plan·spec이 디스크에 존재하는 상태로만 디스패치되므로 (d)가 게이트를 건너뛸 수 없음.

권장:
- 큰 사이클 (≥5 task) → (a) — 또는 ultracode ON이면 (d)
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
   ※ 전체 스키마: `state.schema.json` (state.json 과 같은 디렉터리 — 프로젝트는 `.claude/`, 전역 하네스는 루트)
   - cycle.count +1 (abandoned 시 +0)
   - cycle.last_completed_at: today
   - audit.last_drift_check: today (**단, Step C-1 drift review(sub-step 1)가 실제 수행된 경우에만** — abandoned/미수행 사이클은 미갱신. 하네스 사이클은 sub-step 6 harness-verify 결과와 의미적 연동: 점검 안 한 사이클이 "오늘 점검함"으로 위장 불가.)

4. 사용자 승인형 v2/v3 알림:
   - cycle.count == 5 && !v2_enabled && !v2_skipped_permanently → "v2 도입 가능" 묻기
   - cycle.count == 20 && !v3_enabled && !v3_skipped_permanently → "v3 도입 가능" 묻기
   - 사용자: 활성화 / 건너뛰기 / 영구 건너뛰기 (3택)
   - cycle.count % 5 == 0 (단, cycle.count > 0) → 별도 묻지 않음. sub-step 7이 처리(아래 단일 소스 — 중복 제거, 하나의 "다음 액션" 블록으로 병합)

5. Non-obvious archive 검사:
   - active ≥ 30 항목 또는 ≥ 100줄 → 가장 오래된 비재발(카운터=0) 5개 archive로 이동
   - archive ≥ 500줄 → "archive 정리할까요?" 묻기
   - v2 활성 시: archive 항목이 다시 매칭되면 active로 복귀 + High Priority 즉시 승격

6. 전역 하네스(~/.claude) 자체를 수정한 사이클이면: `bash ~/.claude/setup/verify-setup.sh` 실행 →
   PASS 확인 (cross-doc drift 게이트 #17: §3↔Phase R, #18: next-cycle-goal, #19: harness-verify 포함). FAIL이면 문서 불일치 수정 후 재실행.
   → 결과는 Communication Protocol `harness-verify:` **전용 필드**로 보고(복합 evidence에 접지 않음 — 누락 시 구조적 불완전).

7. 다음 사이클 goal 초안 (advisory — cycle.count ≥ 1일 때 필수; 출력 = Communication Protocol `next-cycle-goal` **고유 필수 필드**):
   ※ 목적: 1단계처럼 길게 한 사이클을 돈 뒤, 사용자가 다음 사이클을 큰 흐름(goal)으로 제어하고,
     사이클 사이 `/compact`를 끼워도 컨텍스트를 재구성할 수 있게, 직전 사이클이 다음 작업을 goal 프롬프트로 초안화.
   ※ advisory인 이유: 다음 사이클 시작 시점엔 검증할 plan/spec 아티팩트가 없어 하드 게이트가 friction만 됨.
     대신 보고의 *고유 필수 필드*로 두어, 생략하면 명명된 필수 필드가 빠져 보고가 구조적으로 불완전 → 자가-표면화.
     (unknowns에 접지 않음 — 복합 필드는 다른 절반만 채워 누락을 가릴 수 있으므로 반드시 별도 필드.)
   - cycle.count == 0 → 이 필드 생략 (첫 사이클 마감엔 핸드오프 대상 없음).
   - 열린 항목 수집: 미완료/유예된 plan task · Step C-1 drift review가 남긴 후속 · non-obvious action item ·
     Phase R/Closeout이 남긴 unknowns. **4개 소스를 실제로 점검**하고, 모두 0일 때만 "제안 없음"을 *수집 근거와 함께* 출력
     (근거 없는 빈 "제안 없음" 금지 — under-collection 위장 방지).
   - cycle.count % 5 == 0 (item 4에서 위임) → "improve-codebase-architecture 실행"이 **항상 열린 항목에 포함**된다
     (∴ cycle%5에선 zero-open 경로로 빠지지 않음). goal 주제 = improve-codebase-architecture.
   goal 초안은 `next-cycle-goal` 필드에 **3개 라벨 하위줄로** 출력 (라벨 누락 = 구조적 불완전 → 필드 누락과 동급으로 표면화; 셋 다 있어야 유효):
   ① `goal:` 상세 목표 — 한 줄 금지. 관찰가능 success criteria(무엇이 PASS/완료인지) 명시.
   ② `read-before:` post-compact 필수 읽기 문서 — `/compact` 가정. 다음 사이클 진입 전 반드시 읽을 문서를 *존재하는 것만* 절대경로로 나열:
      작업 대상 subsystem durable spec(+관련 §) · CONTEXT.md · docs/ai-context/architecture.md(+관련 ADR) ·
      직전 plan · docs/ai-context/non-obvious.md · 관련 CLAUDE.md §섹션.
   ③ `autonomy:` 자율 best-practice 진행 directive —
      "goal 실행 중 선택 분기는 멈추지 말고 best-practice로 판단해 진행(scope 내). 멈춤은 진짜 사용자 결정이 필요할 때만."
   ※ 정지점: 구조는 세 라벨의 *존재*를 표면화(요소 누락 = conspicuous). 각 라벨 *내용*의 완전성(필수 문서 빠짐없음 등)은
     hook 없이 구조로 강제 불가 → 수락된 advisory 잔여(필드-레벨 잔여와 동급).

8. phase-skills 선언 (Communication Protocol `phase-skills:` 필드로 출력):
   - 이번 사이클 각 Phase(R/P/I/Gate/Closeout)에서 **실제 Skill 도구로 호출한** skill을 `invoked`, 호출 안 한 필수 skill은 `skipped: <이유>` 로 명시.
   - 목적: RPI phase 실행(어느 skill을 실제 호출했나)은 plan-FILE proxy로 증명 불가(enforce-rpi-cycle은 plan 존재만 검사) → 보고의 *고유 필수 필드*로 자가-표면. 누락/무사유 skip = 구조적 불완전.
   - 정지점: 자가-표면은 skip을 *눈에 띄는 선언*으로 바꿀 뿐 호출을 물리 강제하진 않음(수락된 advisory 잔여).

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
- next-cycle-goal: **고유 필수 필드** (cycle.count ≥ 1). 정확히 아래 중 하나 — 생략하면 보고가 구조적으로 불완전
  (고유 필드라 unknowns 등 다른 필드 내용으로 대체 불가 → 누락이 표면화).
  · 열린 항목 0 → "다음 사이클 제안 없음 (열린 항목 0 — 수집 근거: 미완료 plan task 0 · drift 후속 0 · non-obvious action 0 · R/Closeout unknowns 0)"
  · 그 외 → Step C-1 sub-step 7의 goal 초안. **3개 라벨 하위줄 모두** 포함(라벨 누락 = 구조적 불완전, 필드 누락과 동급):
      - `goal:` 상세 목표 + 관찰가능 success criteria (한 줄 금지)
      - `read-before:` post-compact 필수 읽기 문서 (존재하는 것만 절대경로)
      - `autonomy:` 자율 best-practice 진행 directive
  · (cycle.count == 0이면 이 필드 생략 — 핸드오프 대상 없음)
  ※ 라벨 *존재*는 구조로 표면화; 각 라벨 내용 완전성은 수락된 advisory 잔여(hook 없이 강제 불가).
- harness-verify: **고유 필수 필드** (모든 사이클). verify-setup PASS를 복합 evidence에 접지 않고 별도 표면화 — 정확히 아래 중 하나:
  · 이번 사이클이 ~/.claude(전역 하네스)를 수정 → `PASS=<N> FAIL=0 (#17·#18·#19 green)` (Step C-1 sub-step 6 실행 결과).
  · 비-하네스 사이클 → "N/A — 이번 사이클은 ~/.claude를 수정하지 않음".
  · 생략 = 명명된 필수 필드 누락 = 보고 구조적 불완전(복합 evidence로 대체 불가 → 자가-표면화). [cycle-14 마스킹 클래스 재발 방지 — F1/#19]
- phase-skills: **고유 필수 필드** (모든 사이클). 각 Phase에서 호출한 skill을 능동 선언 — 복합/암묵 필드에 접지 않음(누락=구조적 불완전, harness-verify·next-cycle-goal 선례). 형식:
  · `R: brainstorming=<invoked|skipped:이유>, grill-with-docs=<…>, explore-strict=<…>`
  · `P: writing-plans=<…>`
  · `I: <executing-plans|execute-strict|subagent-driven|workflow(d)>=<…>`
  · `Closeout: review-strict=<…>`
  무사유 skip 또는 필드 생략 = 자가-표면화(silent-skip 불가). ※ hook 물리 강제는 불가(PreToolUse는 Skill 호출 히스토리·skill명 미제공·`/skill` bypass — claude-code-guide 공식 docs) → advisory 상한 수락. [F12]
