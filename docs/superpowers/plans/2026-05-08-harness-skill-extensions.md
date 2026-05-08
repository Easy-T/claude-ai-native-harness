# Harness Skill Extensions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 3
**Started:** 2026-05-08

**Goal:** Gate P에 spec-plan alignment review 추가, `improve-codebase-architecture` 신규 스킬 생성 (mattpocock 기반 + README Phase), slash command 및 verify 스크립트 갱신.

**Architecture:** start-rpi-cycle Gate P에 review-strict subagent 삽입. 신규 오케스트레이터 스킬은 explore-strict → candidate 선택 → execute-strict → README 생성 4단계 구조. verify-setup.sh에 새 스킬 검증 추가.

**Tech Stack:** Bash, Markdown skill files, Claude Code skill system

**Reference Spec:** `docs/superpowers/specs/2026-05-08-harness-skill-extensions-design.md`

---

## Task 1: start-rpi-cycle Gate P 강화

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md` (Gate P 섹션, 현재 line 45-46)

- [x] **Step 1: Gate P 섹션 교체**

`## Gate P` 섹션을 다음으로 교체:

```markdown
## Gate P

1. active plan 파일 존재 확인 (enforce-rpi-cycle hook이 의존)

2. Agent(subagent_type="review-strict",
         task="spec vs plan alignment verification",
         context_paths=[
           "<현재 spec 경로: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md>",
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
   - plan 수정 후 Gate P 재실행 또는 사용자가 이유 명시하고 override
   - override 문구 예시: "Gate P override: <이유>" 명시 시 Phase I 진행 허용
```

- [x] **Step 2: 파일 변경 확인**

```bash
grep -n "Gate P" ~/.claude/skills/start-rpi-cycle/SKILL.md
grep -n "review-strict" ~/.claude/skills/start-rpi-cycle/SKILL.md
```

예상 출력: Gate P 헤더 + review-strict 참조 2개 이상 (Gate P + C-1 Drift Check)

- [x] **Step 3: Commit**

```bash
git -C ~/.claude add skills/start-rpi-cycle/SKILL.md
git -C ~/.claude commit -m "feat(gate-p): add spec vs plan alignment review-strict check"
```

---

## Task 2: improve-codebase-architecture SKILL.md 생성

**Files:**
- Create: `skills/improve-codebase-architecture/SKILL.md`

- [x] **Step 1: 디렉터리 생성**

```bash
mkdir -p ~/.claude/skills/improve-codebase-architecture
```

- [x] **Step 2: SKILL.md 파일 생성**

아래 내용으로 `skills/improve-codebase-architecture/SKILL.md` 생성:

```markdown
---
name: improve-codebase-architecture
description: |
  여러 RPIC 이후 누적된 도메인 문서 기반 코드베이스 구조 개선 + 일반 사용자용 README 생성.
  "아키텍처 개선해줘", "리팩토링 검토해줘", "코드 구조 점검", "improve-architecture",
  "README 만들어줘", "사용자 가이드 만들어줘" 등을 말하면 사용.
  여러 RPIC 완료 후 주기적으로 실행 권장 (state.json cycle.count 5 배수 시 자동 제안).
orchestrator_skill: true
generated_by: built-in
orchestrator_version: 1.0
---

# improve-codebase-architecture

여러 RPIC를 통해 쌓인 도메인 문서(architecture.md, domain-glossary.md, non-obvious.md)를
기반으로 코드베이스 구조적 마찰을 탐지하고 개선한다.
최종 단계에서 일반 사용자 관점의 README.md를 생성한다.

※ 이 스킬은 별도 RPI 사이클로 취급한다 — start-rpi-cycle을 거치지 않는다.
※ 탐색은 explore-strict, 실행은 execute-strict에 위임한다.

# Preflight

실행 전 확인:
- docs/ai-context/architecture.md 존재
- docs/ai-context/domain-glossary.md 존재
- 하나 이상의 완료된 RPI 사이클 존재 (.claude/state.json cycle.count > 0)

없으면: "도메인 문서가 부족합니다. RPIC를 최소 1회 완료 후 실행하세요." 보고 후 중단.

# Phase 1 — Exploration

```
Agent(subagent_type="explore-strict",
      task="codebase architecture friction analysis",
      context_paths=[
        "docs/ai-context/architecture.md",
        "docs/ai-context/domain-glossary.md",
        "docs/ai-context/non-obvious.md"
      ],
      success_criteria="
        다음 항목별 발견 목록 작성:
        1. Shallow modules: interface complexity ≈ implementation complexity인 모듈
        2. Scattered concepts: 도메인 개념 하나가 여러 모듈에 분산된 경우
        3. Naming drift: domain-glossary 용어와 코드 식별자 불일치
        4. Hard-to-test paths: 테스트 불가 또는 테스트 어려운 코드 경로
        5. Tight coupling: 과도한 의존성 또는 순환 참조
      ")
```

# Phase 2 — Candidate Presentation

explore-strict 결과를 기반으로 번호 매긴 "deepening opportunity" 목록 제시:

```
[1] 파일: <경로>
    문제: <한 줄 — shallow interface / scattered concept / naming drift 등>
    해결: <한 줄 — 구체적 변경>
    효과: <locality 또는 leverage 개선 설명>

[2] ...
```

사용자에게 선택 요청:
- 번호 선택 (예: "1, 3") 또는 "all" → Phase 3 실행
- "none" 또는 "skip" → Phase 3 건너뛰고 Phase 4로

# Phase 3 — Execution

선택된 각 candidate에 대해 순서대로:

```
Agent(subagent_type="execute-strict",
      task="<candidate [N] 설명>",
      context_paths=[<관련 파일 경로>],
      success_criteria="
        - 리팩토링 완료
        - 기존 테스트 통과 (bash scripts/check.sh)
        - 변경 파일만 수정 (scope creep 없음)
      ")
```

각 candidate 완료 후:
- architecture.md 갱신 필요 여부 확인 (모듈 변경 시 append ADR)
- domain-glossary.md 갱신 필요 여부 확인 (식별자 변경 시)

모든 candidate 완료 후 커밋:
```bash
git add -p
git commit -m "refactor: improve codebase architecture — <요약>"
```

# Phase 4 — README Generation

Phase 3 실행 여부와 무관하게 항상 실행.

입력 파일 로드:
- docs/ai-context/architecture.md (아키텍처 다이어그램, 모듈 설명)
- docs/ai-context/domain-glossary.md (도메인 용어)
- docs/ai-context/runbook.md (설치, 실행, 운영 절차)
- 코드베이스 진입점 (main.py / index.ts / Cargo.toml / README 힌트 등)

README.md 생성 기준:
- **독자**: 개발자가 아닌 일반 최종 사용자
- **언어**: 전문 용어 최소화, 쉬운 문장
- **코드 블록**: 설치/실행 커맨드만 허용 (내부 코드 노출 금지)

README.md 구조:

```markdown
# <프로젝트 이름>

> <한 줄 설명 — 이게 뭘 해주는 도구인가>

## 무엇을 해주나

<비기술적 설명. 사용자가 이 도구로 해결할 수 있는 문제를 중심으로.>

## 시작하기

### 필요한 것
- <최소 요구사항 목록>

### 설치
<단계별 설치 커맨드>

### 첫 실행
<가장 기본적인 사용 예시>

## 주요 사용 시나리오

### 시나리오 1: <이름>
1. ...
2. ...
3. ...

### 시나리오 2: <이름>
...

## 어떻게 동작하나

<아키텍처 다이어그램 (architecture.md에서 추출)>

<모듈별 한 줄 역할 설명 — 기술적이지 않게>

## 기여하기

개발자 문서: `docs/ai-context/`
이슈 및 PR은 [GitHub 저장소](<URL>)에서.
```

생성 후:
```bash
git add README.md
git commit -m "docs: generate user-facing README via improve-codebase-architecture"
```

## Communication Protocol

- result: COMPLETE / PARTIAL (Phase 3 일부 실패) / FAIL (Preflight 미통과)
- evidence:
  - Phase 1: friction 발견 목록
  - Phase 2: candidate 목록 + 사용자 선택
  - Phase 3: 완료된 candidate 목록 + 커밋 해시
  - Phase 4: README.md 경로 + 주요 섹션 요약
- unknowns: 사용자에게 결정 권고 항목 (Important candidate 수정 여부 등)

## cycle.count 마일스톤 제안

start-rpi-cycle Closeout Step C-1 완료 후:
- cycle.count가 5의 배수이면: "improve-codebase-architecture 실행 권장 시점입니다. 실행할까요?" 제안
```

- [x] **Step 3: 파일 내용 확인**

```bash
grep -n "orchestrator_skill\|Phase 1\|Phase 2\|Phase 3\|Phase 4\|README" \
  ~/.claude/skills/improve-codebase-architecture/SKILL.md
```

예상 출력: orchestrator_skill: true + 4개 Phase 헤더 + README 언급

- [x] **Step 4: Commit**

```bash
git -C ~/.claude add skills/improve-codebase-architecture/SKILL.md
git -C ~/.claude commit -m "feat(skill): add improve-codebase-architecture orchestrator skill"
```

---

## Task 3: slash command 생성

**Files:**
- Create: `commands/improve-architecture.md`

- [x] **Step 1: 파일 생성**

```markdown
improve-codebase-architecture skill을 호출 (Skill 도구 사용):
대상 프로젝트의 누적 도메인 문서 기반 구조 개선 + README 생성.
```

- [x] **Step 2: 확인**

```bash
cat ~/.claude/commands/improve-architecture.md
```

- [x] **Step 3: Commit**

```bash
git -C ~/.claude add commands/improve-architecture.md
git -C ~/.claude commit -m "feat(command): add /improve-architecture slash command"
```

---

## Task 4: verify-setup.sh 갱신

**Files:**
- Modify: `setup/verify-setup.sh` (line 32 — skill 검증 루프)

- [x] **Step 1: 스킬 목록에 improve-codebase-architecture 추가**

line 32의 skill 목록:
```bash
for s in common-agent-contract create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle; do
```
→ 다음으로 교체:
```bash
for s in common-agent-contract create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle improve-codebase-architecture; do
```

- [x] **Step 2: orchestrator marker 검증 루프도 갱신**

line 37의 marker triple 검증 루프:
```bash
for s in create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle; do
```
→ 다음으로 교체:
```bash
for s in create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle improve-codebase-architecture; do
```

- [x] **Step 3: verify-setup.sh 실행 확인**

```bash
bash ~/.claude/setup/verify-setup.sh 2>&1 | grep -E "skill:|improve"
```

예상 출력: `✓ skill: improve-codebase-architecture` + `✓ improve-codebase-architecture marker triple`

- [x] **Step 4: Commit**

```bash
git -C ~/.claude add setup/verify-setup.sh
git -C ~/.claude commit -m "fix(verify): add improve-codebase-architecture to skill checks"
```

---

## 완료 기준

- [x] Gate P에 review-strict 포함 (`grep "review-strict" skills/start-rpi-cycle/SKILL.md` → 2개 이상)
- [x] `skills/improve-codebase-architecture/SKILL.md` 존재 + orchestrator_skill: true
- [x] Phase 1~4 + README 구조 포함
- [x] `commands/improve-architecture.md` 존재
- [x] `verify-setup.sh` 통과 (FAIL=0)
