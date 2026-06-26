---
name: create-orchestrator-skill
description: |
  새 커스텀 skill을 orchestrator 패턴으로 생성. 사용자가 "이거 자주 쓸 것 같아 skill로",
  "orchestrator로 자동화해줘", "<X> skill 만들어줘" 등을 말하면 무조건 사용.
  단순 텍스트 변환 skill은 예외 (사용자가 명시하면 일반 writing-skills 호출).
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

# Phase 2 — Follow writing-skills procedure (메인 세션이 직접)
※ 생성 절차는 vendored `writing-skills` 스킬을 따른다 (skill-creator는 별도 플러그인이라 vendored 되지 않음 — 대체로 `writing-skills` 사용). sub-agent에 위임 X — 메인이 절차를 따름.
1. 메인이 `writing-skills` 스킬을 `skill` 도구로 호출
2. Phase 1에서 캡처한 의도를 입력으로 `writing-skills`의 SOP 진행:
   - description 작성 (트리거 정확도)
   - body 골격
   - test cases 작성 (선택)
3. `writing-skills`가 draft SKILL.md 생성

→ 결과: `writing-skills`의 표준 산출물 (frontmatter + body)
→ 메인이 이 draft를 받아 Phase 3에서 후처리

# Phase 3 — Inject Orchestrator Skeleton
※ 골격 계약의 **권위 정의 = `plugin/lib/skeleton-scan.js`** (the orchestrator gate (plugin/gates/orchestrator-gate.js) 이 그대로 사용).
  아래는 그 checker를 통과시키기 위한 최소 주입이며, 수치의 진짜 기준은 checker다 (여기서 재정의하지 말 것).
draft에 다음을 자동 주입 (marker + ≥3 `# Phase ` 헤더 + ≥1 real `Agent(subagent_type=` + Communication Protocol):
1. frontmatter에 마커 3줄: `orchestrator_skill: true`, `generated_by: create-orchestrator-skill`, `orchestrator_version: 1.0`
2. body에 `# Phase ` 헤더 ≥ 3개 (예: Phase 1 / Phase 2 / Phase 3)
3. body에 **실제** `Agent(subagent_type=...)` 호출 ≥ 1개 (HTML 주석 안의 호출은 checker가 무시하므로 실제 호출로)
4. body 끝에 `Communication Protocol` 섹션

# Phase 4 — Verify
Dispatch the **review-strict** subagent via the `task` tool — task: "orchestrator 골격 검증"; read: ["<생성된 skill 파일 경로>"]; success:
        권위 검증(재정의 금지) — 생성된 skill 파일 내용을 plugin/lib/skeleton-scan.js 로 직접 통과시킨다:
        Write 이벤트 JSON(content=파일 내용)을 stdin 으로 주면 skeleton-scan.js 가
        '<hasMarker> <phase> <agent> <contract>' 를 출력 → hasMarker=1 && phase>=3 && agent>=1 && contract>=1 이면 통과.
        이 4개 수치의 정의는 skeleton-scan.js 단일 소스이며 the orchestrator gate (plugin/gates/orchestrator-gate.js) 과 동일하다.
        보조: frontmatter 마커 3줄 존재 + 의미 타당성.

위 dispatch의 원형 (opencode: dispatch the review-strict subagent via the task tool):

```
Agent(subagent_type="review-strict",
      task="orchestrator 골격 검증",
      context_paths=["<생성된 skill 파일 경로>"],
      success_criteria="skeleton-scan.js 통과")
```

통과 시에만 파일 생성 (Phase 4 통과 못 하면 draft 보존, 사용자에게 보고).

## Communication Protocol
- result: COMPLETE / FAIL
- evidence: 생성된 skill 경로 + 골격 마커 보고서
- unknowns: 사용자 추가 입력 권고
