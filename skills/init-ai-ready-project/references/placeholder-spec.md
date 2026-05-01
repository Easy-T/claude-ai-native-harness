# Placeholder Specification

Templates use Mustache-style `{{VAR}}` for simple variables and `{{#list}}...{{/list}}` for repeating blocks.

## Simple variables

| Variable | Type | Source | Bootstrap default |
|---|---|---|---|
| `PROJECT_NAME` | string | command argument (`/init-ai-ready <name>`) | required |
| `CREATED_AT` | ISO date | system time | today |
| `STACK_DESCRIPTION` | string | Phase 1 explore-strict detection | `(미감지 — 빈 디렉터리)` |
| `STACK_ALLOW_LIST` | JSON fragment | stack-presets mapping | `[]` (empty array; no trailing comma when list non-empty) |
| `STACK_GITIGNORE` | text lines | stack-presets mapping | empty line |
| `DEPENDENCY_DIAGRAM` | mermaid nodes | empty node | `_initial_["empty"]` |
| `DATA_FLOW_DESCRIPTION` | text | free | `(미정의)` |
| `DEPLOY_PROCEDURE` | text | free | `(아직 정의되지 않음)` |
| `ROLLBACK_PROCEDURE` | text | free | `(아직 정의되지 않음)` |
| `INCIDENT_RESPONSE` | text | free | `(아직 정의되지 않음)` |
| `DASHBOARDS` | text | free | `(아직 정의되지 않음)` |
| `MODULES_INDEX` | bullet list | Phase 1 detection | `(아직 모듈 없음)` |

## Repeating blocks

| Block | Item fields | Bootstrap default |
|---|---|---|
| `INCIDENTS` | `date`, `description`, `rule` | empty list |
| `TERMS` | `domain_term`, `code_identifier`, `note` | empty list |
| `AMBIGUITIES` | `term`, `context_a`, `meaning_a`, `context_b`, `meaning_b` | empty list |

## STACK_ALLOW_LIST formatting rule

When non-empty, items are JSON strings separated by commas (no trailing comma):
`"Bash(npm run *)", "Bash(npm test*)"`

When empty, the placeholder is replaced by an empty string (the surrounding JSON `"allow": [  ]` remains valid).
