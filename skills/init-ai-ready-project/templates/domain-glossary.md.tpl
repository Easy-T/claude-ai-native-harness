# Domain Glossary — {{PROJECT_NAME}}

> 사내 용어 ↔ 코드 식별자 매핑. AI가 도메인 언어를 정확히 사용하도록.
> 새 용어 등장 시 메인이 confidence < 80%면 사용자에게 확인 후 자동 추가.

## Domain → Code

| 도메인 용어 | 코드 식별자 | 비고 |
|---|---|---|
{{#TERMS}}
| {{domain_term}} | `{{code_identifier}}` | {{note}} |
{{/TERMS}}

(부트스트랩 시 비어 있음. 모듈 추가 시 동시에 갱신)

## Identical-Looking, Different Meaning

(같은 단어인데 컨텍스트마다 의미가 다른 경우. 예: price vs amount)

{{#AMBIGUITIES}}
- **{{term}}**:
  - `{{context_a}}`: {{meaning_a}}
  - `{{context_b}}`: {{meaning_b}}
{{/AMBIGUITIES}}
