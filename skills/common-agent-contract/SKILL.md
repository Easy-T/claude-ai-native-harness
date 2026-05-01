---
name: common-agent-contract
description: |
  모든 wrapper agent에 자동 주입되는 Input/Output 표준. agent의 skills 필드로만 호출됨.
  사용자가 직접 호출하지 않음.
---

# Common Agent Contract

이 skill은 wrapper agent (`explore-strict`, `review-strict`, `execute-strict`)가 시작될 때 system prompt에 자동 주입된다.

## Input Contract

호출자(orchestrator skill)는 다음 3개 필드를 항상 명시한다:

| 필드 | 타입 | 설명 |
|---|---|---|
| `task` | string | 한 문장 작업 명세. 동사로 시작. |
| `context_paths` | list[path] | 명시적으로 읽을 파일 경로. 빈 리스트 가능. |
| `success_criteria` | string | 검증 기준. 측정 가능해야 함. |

위 3개 중 하나라도 누락 → agent는 `result: FAIL`로 즉시 종료.

## Output Contract

agent는 다음 형식으로만 반환한다:

```
result: PASS | FAIL | COMPLETE
evidence: |
  <자유 형식 ≤500 단어. 파일 인용·diff·발견사항>
unknowns: |
  <추측·scope 우회·미해결 항목>
```

- `PASS` — review-strict 전용. 모든 criterion 만족.
- `FAIL` — 미충족 또는 입력 누락.
- `COMPLETE` — explore-strict / execute-strict 전용. 작업 종료.

## Scope Lock

1. `success_criteria` 외 행동 금지.
2. 추가 sub-agent spawn 금지 (Anthropic 제약).
3. evidence는 ≤500 단어. 초과 시 핵심만 요약.
4. 메인 conversation의 cwd 공유 — `cd` 명령은 sub-agent 안에서 persist 안 됨.

## Refusal Examples

- "task가 명시되지 않음" → result: FAIL, unknowns에 보고
- "사용자가 추가 작업 의도를 암시" → 그래도 task에 적힌 것만 수행
- "다른 sub-agent 호출이 효율적이라 판단" → 거부, unknowns에 권고
