# UI-Design Craft C3 — Verify + Closeout Implementation Plan

**Status:** completed
**RPI-Cycle:** 51
**Started:** 2026-07-13

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline — cold-agent 디스패치와 Playwright 실측은 메인 세션 소관).
> **오라클:** cold-agent fitness(spec §7)가 이 이니셔티브의 최종 수용 기준 — 사이트가 아니라 **문서**를 판정한다.

**Goal:** design.md v2의 재현성을 cold-agent fitness로 적대 검증하고, opencode 미러·README 하네스 정합을 마감해 3-cycle 이니셔티브를 종결한다.

**Architecture:** fitness는 "새 execute-strict subagent에 design.md v2 **본문만** 제공(SKILL.md·FRICTION·랩 코드 비제공) → 제4 장르(프라이싱) 1페이지 → 메인 세션이 §4.4 게이트 실측 + review-strict floor/ceiling 채점"의 ≤2 이터레이션. FAIL 원인은 문서 결함으로 회귀 수정.

**Tech Stack:** 기존 lab 앱(라우트 `/l4` 추가), Playwright MCP, ccs CLI(교차 리뷰, 가능 시).

## Global Constraints

- **cold-agent 격리** (spec §7): fitness 대상 에이전트에는 design.md v2 파일 경로 하나만 컨텍스트로 — SKILL.md·FRICTION·briefs·기존 L1~L3 코드 경로 제공 금지. 프롬프트에 디자인 힌트(잉크·fluid 같은 용어) 넣지 않기 — 요구사항은 기능 명세로만.
- **판정**: ≤2 이터레이션 내 anti-slop 18/18(floor) + §15 craft ceiling 전항 PASS + §4.4 실측 게이트. FAIL 지점은 **문서의 결함**으로 회귀 수정 후 재시도, 이력 기록 (spec §7).
- **미러 규약** (spec §8): design.md = byte-sync(verbatim 사본), SKILL.md = 구조-sync + 의도적 분기 보존(오프라인 CDN 노트·task-도구 디스패치) — 맹목 byte-copy 금지.
- **README**: :56 skill 테이블 Phase 표기 + :299-301 디렉터리 트리 — seal #22는 start-rpi-cycle 전용이라 발화 안 하나, 문서 정합은 동일 기준으로.
- **검증 트리플**: verify-setup 70/0 · run-all 156/156 · verify-all ALL PASS (하네스 수정 사이클).
- **동시세션 규약** 유지 (ephemeral 포트·자기 PID만).

---

### Task 1: cold-agent fitness — iter 1

**Files:**
- Create: `_design-lab/lab/src/pages/L4.jsx` (cold agent 산출물 — 메인이 파일로 안착)
- Modify: `_design-lab/lab/src/App.jsx` (라우트 `/l4` — 메인이 수행, 디자인 결정 아님)
- Create: `_design-lab/FITNESS-L4.md` (판정 기록)

- [x] **Step 1: cold agent 디스패치** — execute-strict에 정확히 이 프롬프트(디자인 힌트 0):

```
task: 스튜디오 온도(디지털 크래프트 스튜디오)의 서비스 「온도 옵스」 프라이싱 페이지를 React 단일 파일 컴포넌트로 제작하라.
파일: C:/Users/12132/.claude/_design-lab/lab/src/pages/L4.jsx (default export L4)
기능 요구: (a) 요금제 3종 — 스타터(월 ₩290,000)/스튜디오(월 ₩890,000, 추천)/엔터프라이즈(문의) 비교, 각 플랜당 기능 목록 ≥5행 (b) 상세 기능 비교 표(≥8행 × 3플랜, 포함 여부 표시) (c) FAQ 4문항 (d) 최종 CTA. 콘텐츠는 실물급 한국어 카피(lorem 금지).
기술 제약: 이 프로젝트에는 tailwind.config.js에 design 문서의 색·타이포 토큰이 이미 등록되어 있고(문서의 클래스명 그대로 사용 가능), react-coolicons가 설치돼 있다. 외부 라이브러리 추가 금지. 라우팅·테마 토글은 앱 셸이 처리하므로 페이지 컴포넌트만.
디자인 기준: C:/Users/12132/.claude/skills/ui-design/design.md 를 읽고 그 문서의 규칙·토큰·레시피만으로 모든 시각 결정을 하라. 문서가 요구하는 검증 항목(§6·§15)을 스스로 점검한 뒤 산출하라.
success_criteria: L4.jsx 단일 파일 생성, design.md 토큰·클래스만 사용(ad-hoc hex 0), 문서의 floor·ceiling 자가점검 결과를 파일 하단 주석으로 보고.
context_paths: ["C:/Users/12132/.claude/skills/ui-design/design.md"]
```
※ CSS 신규 클래스가 필요하면(모션·잉크 등) L4.jsx 내 `<style>` 또는 인라인로 자족시키게 두기 — index.css 접근권 없음이 곧 "문서만으로 재현" 시험.

- [x] **Step 2: 라우트 배선 + 렌더 스모크** — App.jsx에 `/l4` 추가, dev 서버(ephemeral 포트) 기동, 콘솔 에러 0.
- [x] **Step 3: 실측 게이트 (§4.4)** — 오버플로우(390/768/1440×light/dark, root+내부)=0 · 다크 무결 · reduced-motion 동등 · CLS<0.02. 결과를 FITNESS-L4.md에 표로.
- [x] **Step 4: floor+ceiling 채점** — review-strict: §6 18항목 + §15 ceiling 전항(위계 점프·signature move 정확히 1·완급·hover 보상·focus-visible·reduced-motion·tabular-nums(해당)·다크 무결). context: design.md + L4.jsx. 판정을 FITNESS-L4.md에.
- [x] **Step 5: 판정 분기** — ALL PASS → Task 2 skip, Task 3으로. FAIL → 각 FAIL 항목을 "문서의 어느 §가 침묵/모호해서 cold agent가 틀렸나"로 역추적해 FITNESS-L4.md에 기록 + design.md 회귀 수정(additive, evidence는 `F-FIT-<seq>`로 FRICTION.md에 채록) → Task 2.

### Task 2: cold-agent fitness — iter 2 (조건부: iter 1 FAIL 시만)

- [x] **Step 1: 새 cold agent** (iter 1과 무관한 fresh 컨텍스트, 같은 프롬프트+수정된 design.md) → L4.jsx 재생성.
- [x] **Step 2: 게이트+채점 재실행** (Task 1 Step 3–4 동일).
- [x] **Step 3: 최종 판정** — PASS → 문서 합격. FAIL → **이니셔티브 수용 기준 미달**: FITNESS-L4.md에 잔여 결함 목록 명기, 사용자 보고 항목으로 승격 (goal §4 — fitness는 핵심 수용 기준이므로 자체판단 종결 불가).

### Task 3: 교차패밀리 적대 리뷰 (best-effort)

- [x] **Step 1: ccs 가용 확인** — `ccs --version` + 프로필 목록에 gpt 계열 존재 확인. 불가 시: FITNESS-L4.md에 "교차 리뷰 SKIP: <사유>" 기록 후 Task 4 (spec §7 "가능 시").
- [x] **Step 2: 가용 시** — `ccs <gpt-profile> -p "design.md v2를 refute-by-default로 리뷰: 규칙 간 모순·재현 불가능한 모호 규칙·한국어 프로덕트 관점 결함을 각각 §번호와 함께. 칭찬 금지, 결함만."` 결과를 FITNESS-L4.md에 요약, 실결함만 design.md 수정(무증거 제안은 차기 후보로).

### Task 4: opencode 미러 sync

**Files:**
- Modify: `opencode-harness/skill/ui-design/design.md` (byte-sync), `opencode-harness/skill/ui-design/SKILL.md` (구조-sync)

- [x] **Step 1: design.md byte-copy** — `cp skills/ui-design/design.md opencode-harness/skill/ui-design/design.md` 후 `cmp` 0 확인.
- [x] **Step 2: SKILL.md 구조-sync** — 미러의 기존 분기 2건(오프라인 CDN 노트·task-도구 디스패치) 위치 확인 후, v2 5-Phase 본문으로 갱신하되 그 분기를 보존 재적용. frontmatter에 http(s):// 금지 확인.
- [x] **Step 3: opencode 오라클** — `node opencode-harness/_oracle/skill-discovery.mjs` PASS (MIN_SKILLS≥21·frontmatter 규칙).

### Task 5: README + 하네스 검증 트리플 + 커밋

**Files:**
- Modify: `README.md` (:56 ui-design Phase 표기 → `1(Load) → 2(Concept) → 3(Apply) → 4(Verify) → 5(Visual QA)`, :299-301 트리 설명 갱신)

- [x] **Step 1: README 갱신** — 위 2곳. 다른 행 비접촉 (Surgical).
- [x] **Step 2: 검증 트리플** — `bash setup/verify-setup.sh`(70/0) · `bash hooks/tests/run-all.sh`(156/156) · `bash setup/verify-all.sh`(ALL PASS). FAIL 시 수정 후 재실행.
- [x] **Step 3: 커밋** —
```bash
cd ~/.claude && git add _design-lab 2>/dev/null; git add skills/ui-design/ opencode-harness/skill/ui-design/ README.md \
  docs/superpowers/plans/2026-07-13-ui-design-craft-c3-verify-closeout.md
git commit -m "feat(ui-design): C3 — cold-agent fitness + opencode 미러 sync + README 정합

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
(`git add _design-lab`는 gitignore로 no-op — 명시적 확인용. design.md가 fitness 회귀로 수정됐으면 그 diff도 포함됨.)

→ 이후 start-rpi-cycle Phase Closeout: closeout-pr-cycle(auto-merge) + drift check + state bump + **최종 보고**(산출물 목록·fitness 결과·차기 개선 후보 — goal 요구). cycle 51 도달로 %5 아님(50이 C2에서 소비됨 — improve-architecture 항목은 C2 closeout이 아니라 이번 최종 보고의 차기 후보에 편입).

## Self-Review (writing-plans)

- Spec coverage: §7 fitness(≤2 iter·문서 회귀·교차 리뷰)=T1–T3, §8 정합 표(README·미러·verify 트리플·차기 후보)=T4–T5+Closeout. §9 산출물 중 메모리 갱신·차기 후보=Closeout 단계(plan 밖, skill 절차). ✓
- Placeholder: cold-agent 프롬프트 verbatim 포함, 분기 조건 명시. ✓
- Type consistency: L4.jsx 경로·FITNESS-L4.md·라우트명 일관. ✓
