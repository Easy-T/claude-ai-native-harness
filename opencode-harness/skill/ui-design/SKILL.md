---
name: ui-design
description: 웹/앱 UI/UX 디자인 작업 시 무조건 사용. 컴포넌트, 레이아웃, 색상, 타이포, 페이지 디자인, 랜딩페이지, 대시보드, 모바일 화면, hero 섹션, 카드 디자인, 버튼 스타일, Tailwind/Pretendard/Coolicons 결정 포함. 사용자가 "디자인 만들어줘", "UI 짜줘", "페이지 만들어줘", "컴포넌트 스타일", "랜딩페이지", "hero 섹션", "CSS", "예쁘게", "깔끔하게" 등을 말하거나 React/Vue/Tailwind/HTML 컴포넌트를 작성·수정할 때 반드시 호출. design.md를 컨텍스트에 주입하고 Anti-Slop Checklist로 검증.
orchestrator_skill: true
generated_by: create-orchestrator-skill
orchestrator_version: 1.0
---

# ui-design

웹/앱 UI/UX 결정을 `design.md`(같은 디렉터리)의 단일 reference에 정렬시키는 skill.
RPIC 사이클 어디서든 시각적 결정이 발생하면 호출되어, 디자인 일관성과 AI 슬롭 회피를 보장한다.

## Why this skill exists
LLM은 학습 데이터의 통계적 중앙(indigo 그라데이션, 중앙정렬 hero, 이모지 아이콘 등)으로 수렴하는 경향이 있다 (distributional convergence). `design.md`는 이 기본값을 차단하는 negative constraint + positive token을 제공하며, 이 skill은 그 적용과 검증을 강제한다.

# Phase 1 — Load Reference

같은 디렉터리의 `design.md`를 읽어 다음 섹션을 컨텍스트에 확보한다:
- §0 Tone Manifesto (디자인 정체성)
- §1 Color Tokens, §2 Typography, §3 Spacing & Layout
- §4 Components, §5 Icons
- §6 Anti-AI-Slop Checklist (검증 기준)
- §7 Allowed Gradients, §8 Quick Reference Snippets

```
Read("./design.md")  # SKILL.md 옆 파일 — relative path
```

이미 호출 세션에서 읽었다면 재호출 생략. 단, 결정마다 §1-§5의 토큰을 직접 참조해야 함 (기억에 의존 X).

참고: `design.md`는 Pretendard / Coolicons / Tailwind 등에 대한 CDN·URL 레퍼런스를 포함한다. 이들은 참조 텍스트로 유지하되, 오프라인 UI 검증에서는 해당 CDN/URL을 가져올(fetch) 수 없으므로 토큰·클래스 정의는 `design.md` 본문에 기재된 값으로 판단한다.

# Phase 2 — Apply

UI 코드/결정을 생성할 때:
1. 색상은 `design.md` §1의 CSS 변수 또는 Tailwind 토큰만 사용. ad-hoc hex 금지.
2. 폰트는 Pretendard Variable, `letter-spacing: -0.02em`, body `line-height: 1.5`, heading `1.3` 기본.
3. 레이아웃은 §3의 composition 다양성 규칙 준수 — "text left, image right" 2회 초과 금지, hero 외 중앙정렬 50% 이하.
4. 컴포넌트는 §4의 base 클래스에서 시작. 헤딩 위 둥근 사각형 아이콘 타일 금지.
5. 아이콘은 Coolicons 단일 family. 이모지로 UI 아이콘 대체 금지.
6. iOS 호환: `h-screen` 대신 `min-h-[100dvh]`.

생성 전에 §6 Anti-Slop Checklist의 금지 패턴(indigo→violet, 그라데이션 텍스트, glassmorphism, 모든 카드 shadow+radius+이모지 콤보 등)을 멘탈 모델로 차단.

# Phase 3 — Verify

UI 코드 생성 직후, 자가 검증한다. **review-strict** 서브에이전트를 `task` 도구로 디스패치한다 — task: 생성한 UI 코드를 design.md §6 Anti-AI-Slop Checklist로 검증; read: `./design.md`, `<생성한 코드 파일 경로>`; success: 아래 §6 Anti-Slop Checklist의 모든 항목 PASS.

```
Agent(subagent_type="review-strict",
      task="생성한 UI 코드를 design.md §6 Anti-AI-Slop Checklist로 검증",
      context_paths=["./design.md", "<생성한 코드 파일 경로>"],
      success_criteria="
        design.md §6 Anti-Slop Checklist의 모든 항목 PASS:
        - indigo/보라→파랑 그라데이션 없음
        - 헤딩/숫자에 그라데이션 텍스트 없음
        - 헤딩 위 둥근 사각형 아이콘 타일 없음
        - 한 화면 색 3개 이하 (neutral 제외), 채도 80% 미만
        - hero 외 섹션 중앙정렬 50% 이하
        - 'text left, image right' 2회 이하
        - Pretendard 사용, Inter 미사용
        - letter-spacing -0.02em, body line-height 1.5
        - Coolicons 단일 family, 이모지 UI 아이콘 없음
        - h-screen 미사용 (min-h-[100dvh])
        - 모달 close 아이콘 1개
        - glassmorphism / neon glow / blurred orb 없음
      ")
```
(opencode: dispatch the review-strict subagent via the task tool — 위 블록은 디스패치 task·read·success 의 리터럴 예시이며, 실제 호출은 `task` 도구로 review-strict 서브에이전트에 전달한다.)

FAIL 시: 위반 항목을 수정하고 재검증. 두 번 FAIL이면 사용자에게 보고 후 결정 위임.

작은 변경(색 한 개, 패딩 조정 등)은 검증 생략 가능 — 컴포넌트/페이지 단위 생성·수정에서만 강제.

# Communication Protocol

- **result**: COMPLETE / FAIL_VERIFY / DEFER_USER
- **evidence**:
  - 적용한 design.md 토큰 목록 (예: `--color-primary`, `H2 32px/600`, `radius-md`)
  - review-strict PASS 보고서
  - 수정한 파일 경로
- **unknowns**: design.md에 명시 없는 결정(예: 비표준 컴포넌트)은 사용자 확인 요청
