# 글로벌 Agent 행동 규약 (opencode 버전)

> 이 파일(`AGENTS.md`)은 opencode 매 세션에 자동 로드됩니다 (first-match-wins). 로드 확인 sentinel: `HARNESS-CONSTITUTION-LOADED`. ≤200줄.
> 변경은 의식적으로 — 변경 시 캐시 무효화 (다음 세션 비용 ~20배).

---

## §1. Cache Stability
루트 `AGENTS.md`(글로벌·프로젝트 모두) 수정은 세션 종료 직전에만.
중간 수정 = prefix 캐시 미스 = 비용 약 20배.
사용자가 세션 중 수정 요청 → 한 번 환기 후 진행 가능.

## §2. Orchestrator Meta Rule
새 커스텀 skill 생성 요청은 항상 `create-orchestrator-skill` 사용.
단순 텍스트 변환 skill은 사용자가 명시할 때만 일반 skill-creator 사용.
이유: 모든 skill이 sub-agent에 위임하는 일관 패턴 유지.

> **opencode tool mapping:** `Skill` 도구 → opencode `skill` 도구; `Agent(subagent_type=X)`/`Task` → opencode 서브에이전트(`@X` 또는 task 위임); `TodoWrite` → `todowrite`. RPI 강제는 `~/.config/opencode/plugin/governance.js`(tool.execute.before)가 수행하며, 서브에이전트 쓰기는 `permission` deny 맵이 바닥을 친다.

## §3. RPI Cycle Mandate
변경 작업(기능 추가·버그 수정·리팩토링)은 항상 R→P→I→Closeout.
- Research: brainstorming → grill-with-docs → explore-strict
- Plan: writing-plans
- Implement: executing-plans 또는 execute-strict
- Closeout: review-strict drift 검사 + 자산 갱신
예외: ≤5라인 trivial change. 또는 사용자가 `RPI_SKIP=<reason>` 명시.

## §4. Non-Obvious 등록 절차
AI 실패 감지 시:
1. 등록 가치 있는지 사용자에게 확인
2. review-strict로 5 Whys 진행
3. 사람/AI는 root cause 불가 (시스템·프로세스만)
4. SMART action item 명시
5. 통과 시에만 `docs/ai-context/non-obvious.md` 추가

## §5. ADR Auto-Trigger
아키텍처 영향 변경 (모듈 추가/삭제, 의존성 추가, 데이터 흐름 변경, 인증/저장소/통신 패턴 변경):
- 변경 전 또는 직후 ADR 작성
- `docs/ai-context/architecture.md`는 append-only
- 결정 변경 시 새 ADR로 supersede (이전 항목 수정 X)

## §6. Domain Glossary 의미 확인
사용자가 도메인 용어 사용 시:
- 의미 confidence < 80% → 즉시 확인 질문
- 확인된 용어 → CONTEXT.md 갱신 → domain-glossary.md 메타데이터 sync
- 같은 단어 다른 컨텍스트 → CONTEXT.md "Flagged ambiguities"에

## §7. Response Language
오케스트레이션 최종 보고(요약·선택 요구·완료 알림)는 한국어로 작성.
내부 사고(thinking) 및 중간 과정은 영어 권장 (효율). 코드·커맨드·파일 경로는 언어 무관.

## §8. UI Design Mandate
웹/앱 UI/UX 작업(컴포넌트·페이지·레이아웃·색상·타이포·아이콘 결정)은 항상 `ui-design` skill 사용.
- skill이 `~/.claude/skills/ui-design/design.md`를 컨텍스트에 주입하고 Anti-Slop Checklist로 검증
- 예외: 텍스트/로직만 수정, 시각 결정 없음
- RPIC 사이클과 독립 — 어느 단계에서든 시각 결정 시 호출

---

## Think Before Coding
Don't assume. Don't hide confusion. Surface tradeoffs.
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## Simplicity First
Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.

## Surgical Changes
Touch only what you must. Clean up only your own mess.
- Don't "improve" adjacent code, comments, formatting.
- Don't refactor things that aren't broken.
- Match existing style.
- Test: every changed line traces directly to the user's request.

## Goal-Driven Execution
Define success criteria. Loop until verified.
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"
