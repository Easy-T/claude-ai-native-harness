# UI-Design Craft C1 — Lab L1 브랜드 랜딩 Implementation Plan

**Status:** active
**RPI-Cycle:** 48
**Started:** 2026-07-13

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline, 메인 세션).
> 서브에이전트 위임 불가 사유: Playwright는 메인 세션 MCP 도구(spec §10)이고, 자기비평 루프는 스크린샷 시각 판단의 연속성이 필요하다.
> **Lab-adapted TDD:** 랩 task의 test cycle = 시각 게이트(RED=브리프 미충족/게이트 FAIL → GREEN=게이트 PASS). 단위테스트 없음 — 실측 게이트(spec §4.4)가 오라클.

**Goal:** `_design-lab/`에 Vite+React+Tailwind 단일 앱을 스캐폴드하고, L1(브랜드/포트폴리오 랜딩)을 현행 design.md v1만으로 제작 → 스크린샷-자기비평 루프(≤6라운드) → 실측 게이트 ALL PASS → FRICTION 채록.

**Architecture:** 단일 Vite 앱 + react-router(`/l1`,`/l2`,`/l3` — 이번 사이클은 `/l1`만 구현). tokens.css=design.md §1 verbatim, 다크=data-theme 변수 재매핑. 모션=CSS-first(라이브러리 금지). 산출물은 gitignored(`/_*/`) — repo 커밋 대상은 spec/plan/CONTEXT.md뿐.

**Tech Stack:** Vite 5 + React 18(JSX, TS 아님) + tailwindcss@3.4 pin + react-router-dom@6 + react-coolicons. Playwright(세션 MCP)로 캡처·실측.

## Global Constraints

- **v1-strict + 편차 프로토콜**: 적용 규칙은 design.md v1만. v1을 벗어나는 시도는 **FRICTION-로깅된 실험**으로만 허용 — `F-L1-<seq>` 항목 + 가능하면 before/after 스크린샷 페어. 무기록 편차 금지 (spec §4.3).
- **FRICTION 채록 의무**: v1이 침묵/부족/과광역/틀림/충돌인 지점 발견 즉시 `_design-lab/FRICTION.md`에 기록. 이 로그가 v2의 유일한 원료.
- **라운드 상한 6**, 연속 2라운드 비평 0건이면 조기 종료. 수확 체감 시 중단·기록 (spec §4.3).
- **동시세션 규약**: dev 서버는 ephemeral 포트(5300–5999 난수), 이 세션이 시작한 PID만 종료. 타 세션 프로세스 kill 금지 (spec §4.5).
- **실물급 한국어 카피** — lorem 금지 (spec §4.4).
- 모션은 transform/opacity만, `transition: all` 금지, `prefers-reduced-motion` 분기 필수(게이트) — v1 침묵이므로 이 필요 자체를 FRICTION으로 채록.
- anti-slop 18항목 준수(§6) — 채도 ≤80%, Pretendard, Coolicons 단일, min-h-[100dvh], 금지 그라데이션 없음.

**브랜드 픽션 (전 태스크 공통 카피 소스):** 스튜디오 온도(STUDIO ONDO) — 서울의 디지털 크래프트 스튜디오. 태그라인 "정확함이 만드는 온도".

---

### Task 1: Lab 스캐폴드 (Vite + tokens + 라우터 + 테마)

**Files:**
- Create: `_design-lab/lab/package.json`, `vite.config.js`, `postcss.config.js`, `tailwind.config.js`, `index.html`, `src/main.jsx`, `src/index.css`, `src/tokens.css`, `src/App.jsx`, `src/pages/Home.jsx`, `src/pages/L1.jsx`(셸)
- Create: `_design-lab/.port` (ephemeral 포트 기록)

**Interfaces:**
- Produces: `http://localhost:<PORT>/l1` 라우트, Tailwind 토큰 클래스(`bg-neutral-0`·`text-H2`·`text-body-md`…), `data-theme` 다크 스왑, `window.__toggleTheme()`.

- [x] **Step 1: 파일 작성** — 핵심 파일 내용:

`package.json`:
```json
{
  "name": "design-lab", "private": true, "version": "0.0.0", "type": "module",
  "scripts": { "dev": "vite", "build": "vite build" },
  "dependencies": {
    "react": "^18.3.1", "react-dom": "^18.3.1",
    "react-router-dom": "^6.30.0", "react-coolicons": "^1.0.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4", "vite": "^5.4.11",
    "tailwindcss": "3.4.17", "postcss": "^8.4.49", "autoprefixer": "^10.4.20"
  }
}
```

`src/tokens.css` — design.md §1 라이트+다크+scrim verbatim. **알려진 v1 결함 2건은 기능 필수 보정 + FRICTION 로깅**:
(a) §1 다크 블록이 `--color-primary`만 재매핑하는데 Tailwind DEFAULT는 `--color-primary-base`를 읽음 → 다크에서 primary 무효. 보정: 다크 블록에 `--color-primary-base/hover/active` 재매핑(65%/72%/78%). → `F-L1-01 (틀림)`
(b) §1 Tailwind config를 verbatim 쓰면 `colors` 루트 오버라이드로 `transparent`/`current` 소실 → §4 ghost 버튼(`bg-transparent`) 무효. 보정: `transparent`/`current` 추가. → `F-L1-02 (부족)`

`tailwind.config.js` — §1 색 토큰 + §2 타이포 표를 fontSize 토큰으로:
```js
module.exports = {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    colors: {
      transparent: 'transparent', current: 'currentColor',
      primary: { DEFAULT: 'var(--color-primary-base)', hover: 'var(--color-primary-hover)', active: 'var(--color-primary-active)' },
      neutral: { 900:'var(--color-neutral-900)', 700:'var(--color-neutral-700)', 500:'var(--color-neutral-500)', 300:'var(--color-neutral-300)', 100:'var(--color-neutral-100)', 0:'var(--color-neutral-0)' },
      danger: 'var(--color-danger)', success: 'var(--color-success)', scrim: 'var(--color-scrim)'
    },
    fontFamily: { sans: ['Pretendard','-apple-system','BlinkMacSystemFont','system-ui','Roboto','Helvetica Neue','Segoe UI','Apple SD Gothic Neo','Noto Sans KR','Malgun Gothic','sans-serif'] },
    fontSize: {
      'display-xl':['64px',{lineHeight:'1.15',letterSpacing:'-0.03em',fontWeight:'700'}],
      'display-lg':['48px',{lineHeight:'1.2',letterSpacing:'-0.03em',fontWeight:'700'}],
      'display-md':['40px',{lineHeight:'1.2',letterSpacing:'-0.025em',fontWeight:'700'}],
      'H1':['32px',{lineHeight:'1.3',letterSpacing:'-0.02em',fontWeight:'700'}],
      'H2':['24px',{lineHeight:'1.3',letterSpacing:'-0.02em',fontWeight:'700'}],
      'H3':['20px',{lineHeight:'1.3',letterSpacing:'-0.02em',fontWeight:'600'}],
      'H4':['18px',{lineHeight:'1.3',letterSpacing:'-0.02em',fontWeight:'600'}],
      'body-lg':['16px',{lineHeight:'1.5',letterSpacing:'-0.02em'}],
      'body-md':['14px',{lineHeight:'1.5',letterSpacing:'-0.02em'}],
      'body-sm':['13px',{lineHeight:'1.5',letterSpacing:'-0.02em'}],
      'caption':['12px',{lineHeight:'1.5',letterSpacing:'-0.02em'}]
    },
    extend: {}
  }, plugins: []
}
```
→ §4 스니펫이 `text-H4`·`text-body-md`를 쓰는데 §1 config에 fontSize 정의가 없어 스캐폴드마다 재발명 필요: `F-L1-03 (부족)`.

`index.html` — §2 CDN link + FOUC 차단 인라인 스크립트(§1 영속화 규칙 verbatim: localStorage 화이트리스트 + prefers-color-scheme 초기값) + `<div id="root">`.
`src/index.css` — `@tailwind` 3줄 + §2 body 규칙(letter-spacing -0.02em) + tokens.css import.
`src/App.jsx` — BrowserRouter + 라우트(`/`,`/l1`) + 우상단 고정 테마 토글(ghost 버튼, react-coolicons Sun/Moon — 정확한 export명은 설치 후 d.ts 확인).
`src/pages/L1.jsx` — 셸(`<main className="min-h-[100dvh] bg-neutral-0">L1</main>`).

- [x] **Step 2: 설치 + ephemeral 포트로 dev 서버 기동**

```bash
cd ~/.claude/_design-lab/lab && npm install
PORT=$((5300 + RANDOM % 700)); echo $PORT > ../.port
(npm run dev -- --port $PORT --strictPort & echo $! > ../.devpid)
```
Expected: `VITE ready`, `Local: http://localhost:<PORT>/`

- [x] **Step 3: 스모크 검증 (RED→GREEN)**

Playwright: `browser_navigate http://localhost:<PORT>/l1` → snapshot에 "L1" 텍스트 + `browser_evaluate`로 `getComputedStyle(document.body).fontFamily`가 Pretendard 포함, `document.documentElement.dataset.theme` 토글 시 `--color-neutral-0` 값 스왑 확인.
`git -C ~/.claude status --porcelain`에 `_design-lab` 부재 확인(gitignore 검증).

- [x] **Step 4: FRICTION.md 초기화** — `_design-lab/FRICTION.md` 생성, 헤더 + F-L1-01~03 기록(증거: tokens.css/tailwind.config.js 라인).

### Task 2: L1 아트 디렉션 브리프 (코드 전 필수 — spec §4.3)

**Files:**
- Create: `_design-lab/briefs/L1.md`, `_design-lab/LOG-L1.md`(라운드 로그 헤더)

- [x] **Step 1: 브리프 verbatim 작성** (`_design-lab/briefs/L1.md`):

```markdown
# L1 브리프 — 스튜디오 온도 (STUDIO ONDO)

## 컨셉 (1줄)
서울의 디지털 크래프트 스튜디오 — "정확함이 만드는 온도". 정밀도가 곧 감정이 되는 포트폴리오 랜딩.

## 무드 3키워드
잉크와 종이 / 조판실의 긴장 / 새벽의 차분한 열기

## Signature move (정확히 1개)
**오프닝 타입 안무**: hero 헤드라인 3행("정확함이" / "온도가" / "된다")이 클립 마스크에서 translateY 100%→0으로 행당 120ms stagger, 700ms, ease-out 계열 커스텀 곡선. 마이크로 라벨·서브카피·CTA는 400ms 지연 fade-up. 로드당 1회. reduced-motion 시 즉시 표시.
나머지 전부(스크롤 리빌·hover)는 조용히 이 순간을 떠받든다 — 연속 고novelty 금지.

## 색·타입 전략
- 페이퍼(라이트 뉴트럴 배경) ↔ 잉크(neutral-900 배경 인버전 섹션) 명암 리듬. 새 hue 추가 없음 — primary 1개, 포인트로만.
- 타이포 드라마: 캡션/라벨(12px) ↔ display(64px+) 위계 점프 ≥3단계. 본문은 §2 표 준수.
- 마이크로 라벨: 라틴 대문자("SELECTED WORK") — v1 전역 -0.02em로 먼저 시도, 갑갑하면 FRICTION 채록 후 트래킹 실험(G10 검증).

## 섹션 아웃라인 (밀도 완급 설계)
1. **Hero** (페이퍼, 숨) — 좌상단 워드마크·우상단 테마토글, 중앙-좌 정렬 대형 헤드라인 3행 + 서브 1문장 + CTA 페어. 여백 최대.
2. **Selected Work** (페이퍼, 밀도) — 에디토리얼 목록 6행: 인덱스(01~06)·프로젝트명·설명·연도·태그. hover 보상: 인덱스 primary화+행 배경 미세 상승+화살표 슬라이드.
   (01) 결 — 금융 슈퍼앱 리브랜딩 · 2026 · 브랜드/프로덕트
   (02) 파도 — 여행 커머스 디자인 시스템 · 2025 · 시스템
   (03) 서리 — 미술관 디지털 아이덴티티 · 2025 · 브랜드/웹
   (04) 등고 — 아웃도어 커뮤니티 앱 · 2024 · 프로덕트
   (05) 활자 — 독립 서점 이커머스 · 2024 · 웹/커머스
   (06) 백야 — 수면 케어 서비스 · 2023 · 프로덕트/브랜드
3. **Philosophy** (잉크, 숨) — 인버전 섹션. 대형 인용 "장식은 덜어내고, 정밀도는 끝까지." + 3원칙: 여백은 구조다 / 위계는 배려다 / 모션은 물리다 (각 2줄).
4. **Capabilities** (페이퍼, 밀도) — 비대칭 그리드 4항목: 브랜드 아이덴티티 / 프로덕트 디자인 / 디자인 시스템 / 인터랙션 (각 1줄 소개 + 캡션).
5. **Contact Footer** (잉크, 대형 마침) — 초대형 워드마크 "ONDO", hello@ondo.studio, 서울 성동구 성수이로 26, © 2026 스튜디오 온도.

## 성공 기준
- 1440 첫 캡처에서 "템플릿"이 아니라 "스튜디오"로 읽힌다 (고유 조판).
- 위계 점프(12px 라벨 ↔ 64px+ display)가 즉시 인지된다.
- 잉크/페이퍼 교차 리듬이 스크롤에서 3회 이상 느껴진다.
- hover가 Work 목록에서 주의를 보상한다.
- anti-slop 18/18 + spec §4.4 실측 게이트 전부 PASS.
```

- [x] **Step 2: LOG-L1.md 헤더 생성** — 라운드별 `## r<N> — 비평 항목 <k>건` 형식 선언.

### Task 3: L1 라운드 0 구현 (v1-strict 1차)

**Files:**
- Modify: `_design-lab/lab/src/pages/L1.jsx` (전면 구현), `src/index.css`(모션 keyframes+reduced-motion 분기)

**Interfaces:**
- Consumes: Task 1 토큰 클래스, Task 2 브리프.
- Produces: 브리프 5섹션 전부 렌더되는 `/l1`.

- [x] **Step 1: 브리프 → JSX 구현.** 구속 조건: 브리프 섹션 아웃라인 + design.md v1 전 규칙(display-xl 64px 상한 준수 — clamp 미사용이 v1-strict; 커지고 싶은 압력을 FRICTION으로 채록: G2 검증). 모션은 CSS 클래스(`@keyframes rise`·`fade-up`, transform/opacity만, 명시 property 리스트) + `@media (prefers-reduced-motion: reduce)`에서 animation 소거(→ `F-L1-04 (침묵/G1·G8)` 채록). 잉크 섹션은 로컬 클래스로 neutral 변수 스코프 재매핑(다크모드와 독립 — G11 검증, FRICTION 채록).
- [x] **Step 2: 렌더 확인 (RED→GREEN)** — Playwright navigate, 5섹션 존재 + 콘솔 에러 0.
- [x] **Step 3: LOG-L1.md에 r0 기록.**

### Task 4: 자기비평 루프 (r1~r6, 조기종료 규칙)

**라운드 프로토콜 (매 라운드 동일):**
- [x] **Step 1: 캡처** — Playwright `browser_run_code_unsafe`로 `_design-lab/shots/L1/r<N>/`에 저장:
  - 통상 라운드: light-1440, dark-1440, light-390 (3샷)
  - r3·최종 라운드: light/dark × 1440/768/390 (6샷)
```js
async (page) => { const P=<PORT>, R='r1', B='C:/Users/12132/.claude/_design-lab/shots/L1/'+R+'/';
  await page.goto(`http://localhost:${P}/l1`);
  for (const t of ['light','dark']) { await page.evaluate(v=>localStorage.setItem('theme',v), t);
    for (const w of [1440,390]) { if(t==='dark'&&w===390) continue;
      await page.setViewportSize({width:w,height:900}); await page.reload();
      await page.waitForTimeout(1400); await page.screenshot({path:`${B}${t}-${w}.png`,fullPage:true}); } }
  return 'ok'; }
```
- [x] **Step 2: 자기비평** — 스크린샷 Read 후 브리프 성공기준 + manifesto 5축(타이포 대비/여백·밀도 완급/모션 절제/단일 hue 깊이/1px 디테일) 축별 판정. 출력: 구체 수정 지시 목록(파일:라인). LOG-L1.md에 라운드·항목수·내용 기록.
- [x] **Step 3: 수정 적용** — 지시 목록 반영. v1 벗어나는 실험은 FRICTION 항목번호를 코드 주석에 남김.
- [x] **Step 4: FRICTION 채록** — 이번 라운드 발견분 추가 (증거=shots 경로+코드 라인).
- [x] **Step 5 — 종료 판정**: 연속 2라운드 비평 0건 → 조기 종료. r6 도달 또는 수확 체감 → 중단 사유를 LOG-L1.md에 기록.

### Task 5: 실측 게이트 (spec §4.4 — 전부 PASS까지 fix-and-rerun)

- [x] **Step 1: 가로 오버플로우** — 390/768/1440 × light/dark:
```js
async (page) => { const P=<PORT>; const out=[];
  for (const t of ['light','dark']) { for (const w of [390,768,1440]) {
    await page.goto(`http://localhost:${P}/l1`); await page.evaluate(v=>localStorage.setItem('theme',v),t);
    await page.setViewportSize({width:w,height:900}); await page.reload(); await page.waitForTimeout(800);
    out.push([t,w,await page.evaluate(()=>document.documentElement.scrollWidth-document.documentElement.clientWidth)]); } }
  return out; }
```
Expected: 전 조합 diff ≤ 0.
- [x] **Step 2: 다크 스왑 무결** — (a) grep: `src/` 내 `hsl(`·`#`색·`rgb(` 직접 사용이 tokens.css·§4 그림자 레시피·잉크 섹션 변수 재매핑 외 0건. (b) dark-1440 스크린샷 육안: 역전·저대비 0. 잉크 섹션이 다크모드에서도 위계 유지.
- [x] **Step 3: reduced-motion 기능 동등** — `page.emulateMedia({reducedMotion:'reduce'})` 후 reload: hero 3행 computed opacity==1·transform 무잔존, 전 섹션 스크롤 도달 가능.
Expected: 콘텐츠 손실 0.
- [x] **Step 4: CLS < 0.02** — addInitScript로 PerformanceObserver(layout-shift, hadRecentInput 제외) 주입 → reload → 3.5s 대기 → 누적값.
```js
async (page) => { await page.addInitScript(() => { window.__cls=0;
  new PerformanceObserver(l=>l.getEntries().forEach(e=>{if(!e.hadRecentInput) window.__cls+=e.value;}))
    .observe({type:'layout-shift',buffered:true}); });
  const P=<PORT>; await page.goto(`http://localhost:${P}/l1`); await page.waitForTimeout(3500);
  return await page.evaluate(()=>window.__cls); }
```
Expected: < 0.02.
- [x] **Step 5: anti-slop 18/18** — `Agent(subagent_type="review-strict", context_paths=[design.md, L1.jsx, index.css, tokens.css, tailwind.config.js, App.jsx], success_criteria="§6 18항목 각각 PASS/N-A(스코프 명시 항목만 N-A 허용) — FAIL 항목은 파일:라인과 함께")`.
Expected: PASS (FAIL 시 수정 후 재실행).
- [x] **Step 6: 게이트 결과를 LOG-L1.md에 표로 기록.**

### Task 6: C1 문서 마감 (FRICTION 정리 + 커밋)

**Files:**
- Modify: `_design-lab/FRICTION.md`(중복 병합·유형 라벨 정비), 본 plan(체크박스), `docs/superpowers/specs/2026-07-12-ui-design-craft-upgrade-design.md`(§3 갭 표에 실증 결과 주석 — 조건부)
- Commit: spec + plan + CONTEXT.md (랩 산출물은 gitignored — 커밋 안 됨, by design)

- [x] **Step 1: FRICTION 정리** — 항목별 `F-L1-NN / 유형 / v1 근거(§·라인) / 증거(샷·코드) / v2 방향` 완결성 확인. L1에서 검증 예상 갭: G1·G2·G4(시도 시)·G6·G10·G11 + 신규.
- [x] **Step 2: 커밋**
```bash
cd ~/.claude && git add docs/superpowers/specs/2026-07-12-ui-design-craft-upgrade-design.md \
  docs/superpowers/plans/2026-07-13-ui-design-craft-c1-lab-l1.md CONTEXT.md
git commit -m "feat(ui-design): C1 — craft upgrade durable spec + Lab L1 plan + 용어 6종

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
- [x] **Step 3: dev 서버 종료(자기 PID만)** — `kill $(cat ~/.claude/_design-lab/.devpid)` (다음 사이클에서 재기동).

→ 이후 start-rpi-cycle Phase Closeout(C-0 PR + C-1 drift)이 이어받는다 (plan 밖 — skill 절차).

## Self-Review (writing-plans)

- Spec coverage: §4.1 스캐폴드=T1, §4.3 절차 1(브리프)=T2 / 2(v1 구현)=T3 / 3(루프)=T4 / 4(FRICTION)=T1·T4·T6, §4.4 게이트=T5, §4.5 동시세션=T1·T6. L2/L3·Distill·Verify는 C2/C3 plan 소관(spec Cycles 헤더) — 본 plan 범위 아님. ✓
- Placeholder: 없음 (L1.jsx 본문은 Lab-adapted TDD 선언대로 브리프+게이트가 계약 — 사전 확정 코드가 오히려 랩 목적 위배). ✓
- Type consistency: 토큰명 T1↔T3↔T5 일치(`text-H2`·`bg-neutral-0`·`data-theme`). ✓
