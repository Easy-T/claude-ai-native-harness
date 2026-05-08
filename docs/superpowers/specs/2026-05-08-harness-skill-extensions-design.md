# Harness Skill Extensions Design

**Status:** Approved
**Created:** 2026-05-08

---

## 목적

3가지 harness 기능 확장:
1. Gate P 강화 — plan 작성 후 spec vs plan alignment review-strict 검증
2. 신규 스킬 `improve-codebase-architecture` — 누적 도메인 문서 기반 코드 구조 개선
3. `improve-codebase-architecture` 최종 Phase로 일반 사용자용 README 생성

---

## #1 Gate P Enhancement

### 현재 상태
Gate P = "active plan 파일 존재 확인"만 수행.

### 변경 내용
plan 파일 존재 확인 후 review-strict subagent 추가:

```
Agent(subagent_type="review-strict",
      task="spec vs plan alignment verification",
      context_paths=[
        "<spec 경로: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md>",
        "<plan 경로: docs/superpowers/plans/YYYY-MM-DD-<topic>.md>"
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
```

FAIL 시: 갭 목록 사용자에게 제시 → plan 수정 후 Gate P 재실행 OR 사용자 명시 override.

### 경로 결정 방법
메인이 Phase P에서 spec/plan 경로를 모두 알고 있으므로 context_paths에 직접 명시.
자동 탐색 fallback: `ls -t docs/superpowers/specs/*.md | head -1`

---

## #2 improve-codebase-architecture Skill

### 기반
mattpocock/skills `engineering/improve-codebase-architecture` — 도메인 문서 기반 코드 마찰 탐지 + 모듈 심도 개선.

### 우리 harness 적용 변경점
- explore-strict subagent로 탐색 위임 (mattpocock은 메인이 직접 탐색)
- execute-strict subagent로 리팩토링 위임 (RPI_SKIP 불필요 — 이 스킬 자체가 별도 사이클)
- Phase 4 추가: 일반 사용자용 README 생성

### 4-Phase 구조

**Phase 1 — Exploration**
```
Agent(subagent_type="explore-strict",
      task="codebase architecture friction analysis",
      context_paths=[
        "docs/ai-context/architecture.md",
        "docs/ai-context/domain-glossary.md",
        "docs/ai-context/non-obvious.md"
      ],
      success_criteria="
        - shallow module 목록 (interface ≈ implementation complexity)
        - 도메인 개념이 여러 모듈에 산재한 경우
        - 명명 drift (glossary 용어 vs 코드 식별자 불일치)
        - 테스트 불가 경로 (untested + hard to test)
        - 순환 의존 또는 과도한 coupling
      ")
```

**Phase 2 — Candidate Presentation**
numbered list로 "deepening opportunity" 제시:
```
[N] 파일: <경로>
    문제: <한 줄>
    해결: <한 줄>
    효과: <locality/leverage 개선>
```
사용자 선택: 번호, "all", "none" (Phase 4만 실행)

**Phase 3 — Execution**
선택된 각 candidate:
```
Agent(subagent_type="execute-strict",
      task="<candidate 설명>",
      context_paths=[...관련 파일...],
      success_criteria="리팩토링 완료 + 기존 테스트 통과")
```
각 후 architecture.md / domain-glossary.md 갱신 확인.

**Phase 4 — README Generation** (항상 실행)
inputs: architecture.md, domain-glossary.md, runbook.md, 코드베이스 진입점
output: README.md (프로젝트 루트)

README 구조:
1. 프로젝트 이름 + 한 줄 설명 (일반인 언어)
2. 무엇을 해주나 (비기술적)
3. 시작하기 (설치 → 첫 실행까지)
4. 주요 사용 시나리오 (use-case 플로우, 단계별 서술)
5. 어떻게 동작하나 (아키텍처 다이어그램 포함)
6. 기여하기 (최소, 개발자 섹션)

**원칙**: 개발자가 아닌 최종 사용자가 읽는다. 코드 없음. 전문 용어 최소화.

---

## #3 Slash Command

파일: `commands/improve-architecture.md`
내용: `improve-codebase-architecture` skill 호출

---

## 영향 범위

| 파일 | 변경 유형 |
|---|---|
| `skills/start-rpi-cycle/SKILL.md` | 수정 (Gate P 섹션) |
| `skills/improve-codebase-architecture/SKILL.md` | 신규 생성 |
| `commands/improve-architecture.md` | 신규 생성 |
| `setup/verify-setup.sh` | 수정 (새 스킬 검증 추가) |
