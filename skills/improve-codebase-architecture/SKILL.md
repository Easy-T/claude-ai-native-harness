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
        "CONTEXT.md",
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

### 스캐폴드 프루닝 후보 (하네스 대상일 때 — GAP-005)

대상 코드베이스가 **스캐폴드 registry를 가진 경우**(`docs/ai-context/scaffold-registry.md` — 예: `~/.claude` 하네스 자신), Candidate 목록에 **노화 스캐폴드 프루닝 후보**도 포함한다:
- registry의 각 구성요소(hook/skill/seal)를 순회하며 "존재 이유"가 **여전히 유효한지** 점검 — 특히 모델 업그레이드로 무용해진 가드(예: 특정 구모델 행동 방어), 중복 봉인, 한 번도 발화 안 한 케이스.
- 후보는 `[P<n>] 프루닝: <구성요소> — 존재 이유 <추적>가 <사유>로 무용 의심 — 제거 시 영향 <검증 커맨드>` 형식.
- ⚠️ **삭제는 절대 이 skill이 자동 실행하지 않는다** — 후보 *보고*만. 실제 제거는 사용자 diff 승인 후 별도 RPIC 사이클(seal·테스트 동반 제거).
- 근거: 스캐폴드는 누적만 하고 제거 트리거가 없으면 노화한다(GAP-005). registry + 이 단계가 그 트리거.

### 메모리 수명주기 감사 (auto-memory 대상일 때 — GAP-004)

대상이 **auto-memory를 가진 경우**(`~/.claude/projects/<slug>/memory/` — 예: `~/.claude` 하네스 자신), Candidate 목록에 **메모리 수명주기 감사 후보**도 포함한다(`docs/ai-context/memory-policy.md` 규약대로):
- **통합**: 인덱스(MEMORY.md)에서 같은 subsystem을 다루는 인접 토픽 파일이 각기 짧으면 병합 후보.
- **프루닝**: 인덱스 미링크·supersede된 토픽 파일이 N사이클 재참조 0이면 archive 후보; 코드/현실과 모순되는(틀린) 메모리는 삭제 후보.
- **참조 정정**: session-start-audit이 표면화한 dangling 인덱스 링크·인덱스 예산(200줄/25KB) 초과를 정정 후보.
- 후보는 `[P<n>] 메모리: <통합|프루닝|정정> <파일/인덱스> — <사유>` 형식.
- ⚠️ **삭제·병합은 이 skill이 자동 실행하지 않는다** — 후보 *보고*만. 실제 변경은 사용자 확인 후.
- 근거: 메모리는 축적 단방향이라 트리거가 없으면 노화·오염된다(GAP-004·ASI06). memory-policy.md + 이 단계가 그 트리거.

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
- CONTEXT.md (canonical 용어 — README에서 일관된 vocabulary 사용)
- docs/ai-context/architecture.md (아키텍처 다이어그램, 모듈 설명)
- docs/ai-context/domain-glossary.md (도메인 용어 메타데이터)
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
