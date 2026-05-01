---
name: create-orchestrator-skill
description: |
  새 커스텀 skill을 orchestrator 패턴으로 생성. 사용자가 "이거 자주 쓸 것 같아 skill로",
  "orchestrator로 자동화해줘", "<X> skill 만들어줘" 등을 말하면 무조건 사용.
  단순 텍스트 변환 skill은 예외 (사용자가 명시하면 일반 skill-creator 호출).
orchestrator_skill: true
generated_by: built-in
orchestrator_version: 1.0
---

# create-orchestrator-skill

새 커스텀 skill을 orchestrator 패턴으로 강제 생성한다.

# Phase 1 — Capture Intent
사용자에게 묻기:
1. 무엇을 자동화하고 싶은가? (목적)
2. 트리거 조건? (사용자 발화 예시)
3. 입력·출력 형식?
4. 사이클이 필요한가, 단발성 작업인가?

# Phase 2 — Follow skill-creator procedure (메인 세션이 직접)
※ skill-creator는 메인 세션의 skill (플러그인 제공). sub-agent에 위임 X — 메인이 절차를 따름.
1. 메인이 skill-creator skill의 절차 호출 (Skill 도구로 명시 invoke)
2. Phase 1에서 캡처한 의도를 입력으로 skill-creator의 SOP 진행:
   - description 작성 (트리거 정확도)
   - body 골격
   - test cases 작성 (선택)
3. skill-creator가 draft SKILL.md 생성

→ 결과: skill-creator의 표준 산출물 (frontmatter + body)
→ 메인이 이 draft를 받아 Phase 3에서 후처리

# Phase 3 — Inject Orchestrator Skeleton
draft에 다음을 자동 주입:
1. frontmatter에 마커 3줄: `orchestrator_skill: true`, `generated_by: create-orchestrator-skill`, `orchestrator_version: 1.0`
2. body에 Phase 1 / Phase 2 / Phase 3 섹션 (없으면 추가)
3. 각 Phase에 최소 1개 Agent(subagent_type=...) 호출 (없으면 권유)
4. body 끝에 Communication Protocol 섹션

# Phase 4 — Verify
Agent(subagent_type="review-strict",
      task="orchestrator 골격 검증",
      context_paths=["<생성된 skill 파일 경로>"],
      success_criteria="
        - frontmatter에 orchestrator_skill: true, generated_by, orchestrator_version 3줄 모두 존재
        - body에 # Phase 마커 ≥ 3
        - body에 Agent(subagent_type=) 호출 ≥ 1
        - body에 Communication Protocol 섹션 존재
        - enforce-orchestrator hook 통과 조건 만족
      ")

통과 시에만 파일 생성 (Phase 4 통과 못 하면 draft 보존, 사용자에게 보고).

## Communication Protocol
- result: COMPLETE / FAIL
- evidence: 생성된 skill 경로 + 골격 마커 보고서
- unknowns: 사용자 추가 입력 권고
