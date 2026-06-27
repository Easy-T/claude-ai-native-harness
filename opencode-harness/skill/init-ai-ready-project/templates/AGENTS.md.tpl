# {{PROJECT_NAME}}

> AI-Ready 코드베이스 (opencode). 이 프로젝트 `AGENTS.md`는 opencode가
> 시스템 프롬프트에 로드합니다 — 전역 하네스 헌법(`~/.config/opencode/AGENTS.md`)과
> **병합**되어 적용됩니다(전역=거버넌스 §1~§8, 이 파일=프로젝트 나침반).
> 변경은 세션 종료 직전에만 (프롬프트 캐시 미스 비용 ↑). ≤200줄 유지 — 백과사전이 아닌 나침반.

Created: {{CREATED_AT}}

## Stack
{{STACK_DESCRIPTION}}

## Modules
{{MODULES_INDEX}}

## Top 5 Non-Obvious Patterns
참조: [docs/ai-context/non-obvious.md](docs/ai-context/non-obvious.md)

(아직 누적되지 않음)

## Pointers
- 절대 금지(전체 정책): [docs/ai-context/deny-patterns.md](docs/ai-context/deny-patterns.md)
  — 이 중 **bash-명령 형태의 보편 파괴 명령만** 프로젝트 `opencode.json` `permission.bash`가 하드 차단(best-effort 가드,
  샌드박스 아님). SQL·prod 접근·컨텍스트 git 등은 advisory(리뷰·규율 + 전역 하네스 게이트). 강제 범위는 deny-patterns.md 헤더 참조.
- 아키텍처: [docs/ai-context/architecture.md](docs/ai-context/architecture.md)
- 운영·배포: [docs/ai-context/runbook.md](docs/ai-context/runbook.md)
- 도메인 용어: [docs/ai-context/domain-glossary.md](docs/ai-context/domain-glossary.md)
