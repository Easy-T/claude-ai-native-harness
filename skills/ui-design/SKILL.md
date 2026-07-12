---
name: ui-design
description: 웹/앱 UI/UX 디자인 작업 시 무조건 사용. 컴포넌트, 레이아웃, 색상, 타이포, 페이지 디자인, 랜딩페이지, 대시보드, 모바일 화면, hero 섹션, 카드 디자인, 버튼 스타일, Tailwind/Pretendard/Coolicons 결정 포함. 사용자가 "디자인 만들어줘", "UI 짜줘", "페이지 만들어줘", "컴포넌트 스타일", "랜딩페이지", "hero 섹션", "CSS", "예쁘게", "깔끔하게" 등을 말하거나 React/Vue/Tailwind/HTML 컴포넌트를 작성·수정할 때 반드시 호출. design.md를 컨텍스트에 주입하고 Anti-Slop floor + Craft Ceiling으로 검증.
orchestrator_skill: true
generated_by: create-orchestrator-skill
orchestrator_version: 2.0
---

# ui-design

웹/앱 UI/UX 결정을 `design.md`(같은 디렉터리)의 단일 reference에 정렬시키는 skill.
RPIC 사이클 어디서든 시각적 결정이 발생하면 호출되어, 디자인 일관성·AI 슬롭 회피(floor)·크래프트 상한(ceiling)을 보장한다.

## Why this skill exists
LLM은 학습 데이터의 통계적 중앙(indigo 그라데이션, 중앙정렬 hero, 이모지 아이콘, 균질 밀도)으로 수렴하는 경향이 있다 (distributional convergence). `design.md`는 이 기본값을 차단하는 negative constraint(§6 floor) + positive token(§1–§5) + 표현 상한 레시피(§9–§15 ceiling)를 제공하며, 이 skill은 그 적용과 검증을 강제한다. v2: 실사이트 3장르 랩(브랜드 랜딩·에디토리얼·대시보드)의 FRICTION 채록만을 근거로 §9–§15가 추가됨 — 문서의 모든 신규 규칙은 `// evidence: F-*` 인용을 가진다.

# Phase 1 — Load Reference

같은 디렉터리의 `design.md`를 읽어 확보한다:
- §0 Tone Manifesto + **Craft Manifesto** (서열 5축·signature move 규칙)
- §1 Color, §2 Typography(+자간 함수·tabular-nums·measure), §3 Spacing & Layout(+앱 셸 무결성), §4 Components, §5 Icons(+currentColor 보정)
- §6 Anti-Slop floor / §7 Gradients / §8 Snippets
- §9 Motion / §10 Expressive(잉크·페이퍼·fluid) / §11 Depth / §12 States / §13 A11y / §14 Rhythm / §15 Craft Ceiling

```
Read("./design.md")  # SKILL.md 옆 파일 — relative path
```

이미 호출 세션에서 읽었다면 재호출 생략. 단, 결정마다 토큰을 직접 참조해야 함 (기억에 의존 X).
장르 힌트: UI 셸/대시보드 → §3·§4·§11·§12 중심. 브랜드/에디토리얼 표면 → §10·§14 추가 로드. 모션 결정 → §9.

# Phase 2 — Concept (브리프 강제)

**페이지 단위 작업은 코드 전에 아트 디렉션 브리프를 쓴다** (컴포넌트 단위·기존 페이지 소수정은 생략 가능 — 단 signature move 유무 판단은 항상):
- 컨셉 1줄 / 무드 3키워드
- **signature move 정확히 1개** (§0 규칙 — 무엇이 이 페이지의 기억점인가; 반복 사용 화면이면 "진입 1회 외 무모션"이 답일 수 있다)
- 색·타입 전략 (새 hue 금지 — 명도축·§10 티어 안에서)
- 섹션 아웃라인 + **밀도 완급 설계** (§14 숨→밀도 교차)
- 성공 기준 (floor 18 + ceiling 항목 중 해당분)

브리프 없는 페이지 코딩 금지 — 브리프가 Phase 4·5의 채점 기준이 된다.

# Phase 3 — Apply

UI 코드/결정 생성 시:
1. 색은 §1 CSS 변수/Tailwind 토큰만. ad-hoc hex 금지. 다크는 변수 재매핑(§1) — `dark:` variant 페어 금지.
2. 타이포: Pretendard, §2 표 + **자간은 크기의 함수**(마이크로 라벨 +0.06~0.12em·장문 -0.01em). 데이터 숫자는 tabular-nums. 한국어 장문 measure 32–38em.
3. 레이아웃: §3 composition 다양성 + 앱 셸이면 §3①~④ 골격 verbatim. 페이지 리듬은 §14 (완급 교차·대형 여백 앵커·bleed는 lg+).
4. 컴포넌트: §4 base + §8 스니펫에서 시작. 상태(hover/focus-visible/loading/empty)는 §12 스펙.
5. 아이콘: Coolicons 단일 + §5 currentColor 보정 1줄 필수. 이모지 UI 금지.
6. 모션: §9 토큰·레시피만 — reduced-motion 분기 필수, 반복 화면 무모션, transform/opacity만.
7. 표현 상한이 필요한 표면(브랜드/에디토리얼)만 §10 (fluid display·잉크 섹션·grain — UI 표면 적용 금지).

생성 전 §6 금지 패턴을 멘탈 모델로 차단.

# Phase 4 — Verify (floor + ceiling)

UI 코드 생성 직후, 자가 검증 (컴포넌트/페이지 단위 생성·수정에서 강제 — 색 1개·패딩 조정은 생략 가능):

```
Agent(subagent_type="review-strict",
      task="생성한 UI 코드를 design.md §6 Anti-Slop floor 18항목 + §15 Craft Ceiling으로 검증",
      context_paths=["./design.md", "<생성한 코드 파일 경로 전부>", "<브리프 경로(있으면)>"],
      success_criteria="
        PASS only if ALL:
        [floor §6 — 18항목 각각 PASS/N-A 판정, FAIL 0]
        - indigo/보라→파랑 그라데이션·그라데이션 텍스트·아이콘 타일 헤딩 없음
        - 색 3개 이하(neutral 제외)·채도 ≤80%
        - 중앙정렬 50% 이하·'text left, image right' ≤2회
        - Pretendard·letter-spacing 기본 -0.02em(§2 자간 함수 예외는 위반 아님)·body 1.5
        - Coolicons 단일·이모지 없음·min-h-[100dvh]
        - (앱 셸) dvh root 1곳·모바일 접힘·실측 오버플로우 0
        - 모달 close 1개·glassmorphism/neon/orb 없음
        [ceiling §15 — 해당 항목 각각 판정]
        - 위계 점프 ≥3단계 / signature move 정확히 1개 / 밀도 완급 존재
        - hover 보상·focus-visible 스펙(§12) / reduced-motion 분기(§9)
        - (해당 시) tabular-nums·잉크/페이퍼 리듬·다크 무결
        FAIL with: 항목 번호 + 파일:라인 + 수정 지시")
```

FAIL 시: 위반 항목 수정 후 재검증. 두 번 FAIL이면 사용자에게 보고 후 결정 위임.

# Phase 5 — Visual QA (Playwright 실측 — 메인 세션 수행)

페이지 단위 산출물은 코드 검증(Phase 4)만으로 완료 선언 금지 — **실브라우저 실측**으로 마감한다.
review-strict는 브라우저를 못 쓰므로 이 Phase는 **메인 세션이 Playwright(MCP) 도구로 직접** 수행한다:

1. **캡처**: 1440/768/390 × light/dark 스크린샷 → 브리프(Phase 2) 대비 육안 비평. 풀페이지 캡처는 스크롤-스텝 선행(IntersectionObserver 리빌 발화) 후 촬영.
2. **오버플로우**: `scrollWidth − clientWidth == 0` — root **및** 내부 overflow 컨테이너(§3④ v2) × 각 뷰포트.
3. **다크 스왑**: `data-theme` 토글만으로 전 화면 무결 (하드코딩 색 grep 0).
4. **reduced-motion**: emulateMedia로 기능 동등 (모션 요소 opacity 전부 1·전 콘텐츠 도달).
5. **CLS**: PerformanceObserver layout-shift < 0.02 (진입 모션 중).
6. **focus**: Tab 순회로 focus-visible 가시 확인 (§12).

FAIL 항목은 수정 → 해당 항목만 재실측. 전부 PASS면 완료 보고.

# Communication Protocol

- **result**: COMPLETE / FAIL_VERIFY / DEFER_USER
- **evidence**:
  - 적용한 design.md 토큰 목록 (예: `--color-primary`, `H2 24px/700`, `motion-base 550ms`)
  - 브리프 경로(페이지 단위) + signature move 1줄
  - Phase 4 review-strict 보고 (floor 18 판정 + ceiling 판정)
  - Phase 5 실측 결과 (오버플로우/다크/reduced-motion/CLS/focus — 수치)
  - 수정한 파일 경로
- **unknowns**: design.md에 명시 없는 결정(비표준 컴포넌트·신규 관용구)은 사용자 확인 요청 — 임의 규칙 발명 금지 (필요하면 FRICTION으로 채록해 차기 v3 후보로)
