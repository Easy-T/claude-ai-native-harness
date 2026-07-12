# UI Design Reference

> 이 파일은 `ui-design` skill이 자동 주입한다. 웹/앱 UI 작업의 모든 시각 결정은 여기 토큰을 따른다.

# 0. Tone Manifesto
여백 중심, 절제된 색, 명확한 위계. 화려함이 아닌 정확함으로 만족시킨다. 장식적인 요소는 배제하고 콘텐츠 자체가 UI의 형태를 띠도록 구성한다. 시스템이 예측 가능하며 단단한 느낌을 주어, 사용자가 이질감을 느끼지 않도록 한다.

### Craft Manifesto (v2 — design lab 3장르 실증)
절제는 뼈대, **화려함은 정밀도다**. 표현의 상한을 올릴 때 투자 순서는 아래 서열을 따른다 (v2 신규 규칙의 출처는 랩 FRICTION 항목 — `// evidence:` 주석):
1. **타이포그래피** — 스케일 대비·리듬·정렬의 긴장. 한 페이지의 위계 점프는 **≥3단계**(예: 12px 라벨 ↔ 14px 본문 ↔ 24px 섹션 ↔ 88px+ display). 중간 크기의 균질한 위계가 슬롭을 만든다. // evidence: F-ALL-01
2. **여백과 밀도의 완급** — 조밀한 섹션 뒤 숨 쉬는 섹션(§14). 균질 밀도는 리듬의 부재다.
3. **물리 기반 절제 모션** — enter는 ease-out·<400ms·transform/opacity만(§9). 모션은 장식이 아니라 인과다.
4. **단일 hue의 깊이** — 새 hue를 추가하지 않고 명도축(잉크↔페이퍼)으로 드라마를 만든다(§10).
5. **1px 디테일** — border 단차·focus ring·tabular-nums·grain. 크래프트는 보이지 않을 때 작동한다.

**Signature move 규칙**: 페이지당 기억에 남는 표현 순간은 **정확히 1개**(오프닝 타입 안무·스크롤 전환·예상 밖 그리드 중 하나). 나머지 전부는 조용히 그 순간을 떠받든다. 0개 = ceiling 미달(§15), 2개+ = 완급 붕괴. 반복 사용 화면(대시보드 등)은 진입 1회 외 무모션이 그 자체로 signature다. // evidence: F-L3-04

### Global Setup (필수 가정)
이 시스템을 사용하는 모든 화면은 다음이 layout root에 등록되어 있다고 가정한다:
1. **Pretendard Variable** CSS import (§2의 CDN URL)
2. **Tailwind config** — §1의 `primary` / `neutral` 컬러 토큰 + §2의 `fontFamily.sans = ['Pretendard Variable', ...]`
3. **Coolicons** CSS import (§5의 CDN URL)

이 3개가 누락되면 `bg-primary`, `text-neutral-900`, `font-sans`, `ci-*` 클래스가 모두 무효. 컴포넌트 단위 작업 시 먼저 확인.

# 1. Color Tokens
색상 사용을 최소화하여 인지 부하를 줄이고, 브랜드 컬러를 포인트로 활용합니다. // from: 몽타주 web

### Color System (CSS & Tailwind)
```css
:root {
  /* Primary - Saturation 최대 80% */
  --color-primary: #176BFF; /* HSL 218, 100%, 54% -> Saturation 조정 필요 (80% 이하) */
  --color-primary-base: hsl(218, 80%, 55%);
  --color-primary-hover: hsl(218, 80%, 45%);
  --color-primary-active: hsl(218, 80%, 35%);

  /* Neutral */
  --color-neutral-900: hsl(220, 10%, 10%); /* text-primary */
  --color-neutral-700: hsl(220, 10%, 30%); /* text-secondary */
  --color-neutral-500: hsl(220, 10%, 50%); /* text-tertiary */
  --color-neutral-300: hsl(220, 10%, 80%); /* border */
  --color-neutral-100: hsl(220, 10%, 96%); /* background-subtle */
  --color-neutral-0: #FFFFFF;              /* background-base */

  /* Semantic (필요시에만) */
  --color-danger: hsl(0, 75%, 55%);
  --color-success: hsl(140, 70%, 45%);
}
```

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    colors: {
      transparent: 'transparent',  // v2: colors 루트 오버라이드가 기본 팔레트를 지우므로 필수 —
      current: 'currentColor',     // 없으면 §4 ghost 버튼(bg-transparent)이 무효. // evidence: F-L1-02
      primary: {
        DEFAULT: 'var(--color-primary-base)',
        hover: 'var(--color-primary-hover)',
        active: 'var(--color-primary-active)',
      },
      neutral: {
        900: 'var(--color-neutral-900)',
        700: 'var(--color-neutral-700)',
        500: 'var(--color-neutral-500)',
        300: 'var(--color-neutral-300)',
        100: 'var(--color-neutral-100)',
        0: 'var(--color-neutral-0)',
      },
      danger: 'var(--color-danger)',
      success: 'var(--color-success)',
    }
  }
}
```

### Dark Theme (변수 재매핑) // from: NICE Second Brain ADR-029 (2026-06-13, Playwright 실측 검증)
다크모드는 **클래스 분기가 아닌 변수 재매핑**으로 구현한다 — `html[data-theme="dark"]`(명시도 0,1,1 > `:root`)에서 같은 토큰의 값만 반전 대칭으로 스왑하면, `bg-neutral-0`/`text-neutral-900` 같은 기존 클래스가 전부 자동 전환된다 (`dark:` variant 페어·`bg-[hsl(...)]` arbitrary 분기 금지 — 컴포넌트 수에 비례해 부채 증가).

```css
html { color-scheme: light; }
html[data-theme="dark"] {
  color-scheme: dark;
  --color-neutral-0: hsl(220, 12%, 11%);   /* surface (라이트 #fff의 반전) */
  --color-neutral-100: hsl(220, 10%, 17%); /* background-subtle */
  --color-neutral-300: hsl(220, 10%, 28%); /* border */
  --color-neutral-500: hsl(220, 10%, 58%); /* text-tertiary */
  --color-neutral-700: hsl(220, 10%, 75%); /* text-secondary */
  --color-neutral-900: hsl(220, 10%, 94%); /* text-primary */
  --color-primary: hsl(218, 80%, 65%);     /* 다크 배경 대비 보정 */
  /* v2 정정: Tailwind config가 읽는 것은 --color-primary-base — 아래 3줄이 없으면
     다크에서 bg-primary가 라이트 값 그대로다 (before: 주석으로만 "hover 72%, active 78%" 언급).
     // evidence: F-L1-01 */
  --color-primary-base: hsl(218, 80%, 65%);
  --color-primary-hover: hsl(218, 80%, 72%);   /* 라이트와 방향 반전 */
  --color-primary-active: hsl(218, 80%, 78%);
  --color-danger: hsl(0, 65%, 65%);
  --color-success: hsl(140, 55%, 55%);
}
```

- **반전 대칭 원칙**: 라이트의 모든 `--color-*` 키가 다크 블록에도 존재해야 한다 (누락 = "어두운 배경 어두운 글자" 버그). 스케일이 대칭이면 `bg-primary text-neutral-0` 버튼도 자동으로 "밝은 파랑 + 어두운 텍스트"가 된다.
- **scrim 예외**: 모달 오버레이는 `bg-neutral-900/40`을 쓰면 다크에서 "흰 스크림"으로 역전 → 의미 토큰 `--color-scrim`(라이트 `hsl(220,10%,10%)` / 다크 `hsl(220,14%,4%)`)을 분리해 `bg-scrim/40`으로 사용.
- **영속화**: localStorage + 초기값 `prefers-color-scheme`. React 마운트 전 `<head>` 인라인 스크립트로 `document.documentElement.dataset.theme`을 설정해 FOUC 차단 (저장값은 "light"/"dark" 화이트리스트 검사).
- **canvas 예외**: CSS 변수를 못 읽는 캔버스 라이브러리(force-graph·차트)만 theme prop으로 JS 색 상수 분기 유지.
- **전환 애니메이션 없음**: 캔버스는 CSS transition 불가라 패널/캔버스 엇박자 발생 — 즉시 전환이 §0 톤("예측 가능하고 단단한")에 부합.

**사용 규칙:** // from: 몽타주 공통
- **한도 명시**: 한 화면에 Primary 1개, Neutral 2~3개 사용. Semantic 컬러는 오류/성공 등 꼭 필요한 경우에만 사용.
- **Saturation 상한**: 모든 컬러의 채도는 최대 80%를 넘지 않아야 합니다 (다크 팔레트 포함).
- **금지 색상**: `indigo-500` 계열, 보라→파랑 그라데이션 ❌ (전형적인 AI 생성물 느낌 방지).

# 2. Typography
한글과 영문 모두 자연스럽게 어우러지는 **Pretendard Variable** 단일 폰트를 사용합니다. // from: Pretendard 가이드

### Import & Font-Face
```css
@import url('https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard-dynamic-subset.min.css');

body {
  font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, system-ui, Roboto, 'Helvetica Neue', 'Segoe UI', 'Apple SD Gothic Neo', 'Noto Sans KR', 'Malgun Gothic', 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', sans-serif;
  letter-spacing: -0.02em;
}
```

### Typography Hierarchy

| 토큰 | px | weight | line-height | letter-spacing | 용도 |
| --- | --- | --- | --- | --- | --- |
| display-xl | 64px | Bold (700) | 1.15 | -0.03em | hero, 강력한 임팩트 |
| display-lg | 48px | Bold (700) | 1.2 | -0.03em | hero (모바일/sub-hero) |
| display-md | 40px | Bold (700) | 1.2 | -0.025em | feature 섹션 강조 |
| H1 | 32px | Bold (700) | 1.3 | -0.02em | 페이지 제목 |
| H2 | 24px | Bold (700) | 1.3 | -0.02em | 섹션 제목 |
| H3 | 20px | SemiBold (600) | 1.3 | -0.02em | 서브섹션 |
| H4 | 18px | SemiBold (600) | 1.3 | -0.02em | 카드 제목 |
| body-lg | 16px | Regular (400) / Medium (500) | 1.5 | -0.02em | 본문 강조 |
| body-md | 14px | Regular (400) / Medium (500) | 1.5 | -0.02em | 본문 |
| body-sm | 13px | Regular (400) | 1.5 | -0.02em | 보조 |
| caption | 12px | Regular (400) | 1.5 | -0.02em | 캡션, 라벨 |

**Display 토큰 사용 규칙:**
- display-* 는 hero·feature 강조 영역에서만. 일반 페이지 제목에는 H1 사용.
- 모바일 뷰(`< 768px`)에서는 display-xl → display-lg, display-lg → display-md 로 한 단계 다운.
- display-* 텍스트도 절대 그라데이션 적용 금지 (§6).
- 브랜드 hero·에디토리얼 표제는 64px 위로 확장 가능 — **§10 Fluid Display** 티어 사용 (fixed 96px 같은 하드코딩 금지, clamp 레시피만).

### Tailwind fontSize config (v2 — 표를 그대로 실체화; 스캐폴드마다 재발명 금지) // evidence: F-L1-03
```javascript
// tailwind.config.js theme.fontSize — §2 표의 1:1 변환
fontSize: {
  'display-xl': ['64px', { lineHeight: '1.15', letterSpacing: '-0.03em', fontWeight: '700' }],
  'display-lg': ['48px', { lineHeight: '1.2', letterSpacing: '-0.03em', fontWeight: '700' }],
  'display-md': ['40px', { lineHeight: '1.2', letterSpacing: '-0.025em', fontWeight: '700' }],
  'H1': ['32px', { lineHeight: '1.3', letterSpacing: '-0.02em', fontWeight: '700' }],
  'H2': ['24px', { lineHeight: '1.3', letterSpacing: '-0.02em', fontWeight: '700' }],
  'H3': ['20px', { lineHeight: '1.3', letterSpacing: '-0.02em', fontWeight: '600' }],
  'H4': ['18px', { lineHeight: '1.3', letterSpacing: '-0.02em', fontWeight: '600' }],
  'body-lg': ['16px', { lineHeight: '1.5', letterSpacing: '-0.02em' }],
  'body-md': ['14px', { lineHeight: '1.5', letterSpacing: '-0.02em' }],
  'body-sm': ['13px', { lineHeight: '1.5', letterSpacing: '-0.02em' }],
  'caption': ['12px', { lineHeight: '1.5', letterSpacing: '-0.02em' }],
}
```

**사용 규칙:**
- **기본값**: 전체 텍스트 `letter-spacing: -0.02em`, 본문 `line-height: 1.5`, 헤딩 `line-height: 1.3`
- **금지**: Inter 폰트 사용 ❌, 헤딩이나 숫자에 그라데이션 텍스트 적용 ❌, 영문 폰트(Roboto 등)와 한글 폰트 혼용 ❌.

**자간은 크기의 함수다 (v2 — 기본값 -0.02em의 스코프 예외):** // evidence: F-L1-07, F-L2-05
| 스케일 | letter-spacing | 근거 |
| --- | --- | --- |
| display/fluid (≥40px) | -0.025 ~ -0.035em | 큰 글자는 조여야 단단해진다 |
| 헤딩·UI 본문 (13–32px) | -0.02em (기본값 유지) | Pretendard 최적 자간 |
| 장문 본문 17–18px (§10 long-form) | -0.01em | 장문에서 -0.02em은 조밀 |
| 마이크로 라벨 (11–12px 라틴 대문자) | **+0.06 ~ +0.12em**, weight 500, 색 tertiary | 와이드 트래킹 라벨 관용구 — 기본값이 이를 봉쇄했음 |

```css
.micro-label { font-size: 12px; line-height: 1.5; letter-spacing: 0.08em; font-weight: 500; }
```

**데이터 숫자는 tabular-nums (v2):** KPI·표·타임스탬프 등 정렬되는 숫자는 `font-variant-numeric: tabular-nums` — 가변폭 숫자는 열이 흔들린다. // evidence: F-L3-01
```css
.num { font-variant-numeric: tabular-nums; }
```

**한국어 장문 measure (v2):** 아티클 본문 폭은 **32–38em** (17px 기준 한글 30자대 중반). 라틴 관용값 66ch를 한글에 옮기면 과폭 — 한글 음절은 정사각 밀도라 같은 자수에서 행이 훨씬 길다. long-form 본문은 17–18px / line-height 1.7–1.9 티어 사용 (§2 표의 body-*는 UI 문장용). // evidence: F-L2-03, F-L2-04

# 3. Spacing & Layout
4px / 8px 단위의 그리드 시스템을 사용하여 여백의 위계를 명확히 합니다. // from: 몽타주 iOS/Android

- **Grid Unit**: 4px, 8px, 12px, 16px, 20px, 24px, 32px, 40px, 48px, 64px, 80px, ...
- **Breakpoint**: Mobile `< 768px`, Tablet `768px ~ 1024px`, Desktop `> 1024px`
- **Container Max-Width**: `1200px` (또는 화면 성격에 따라 `1024px`, `800px` 사용)

**Composition 다양성 규칙:** (필수)
- 한 페이지 내 "text left, image right" 패턴 2회 초과 금지 ❌.
- Hero 섹션 외 중앙정렬 섹션은 전체의 50% 이하로 구성.
- Split-screen, asymmetric(비대칭), top-right/bottom-left 등 레이아웃의 변주를 권장합니다.

**iOS 호환 규칙:** // from: 몽타주 iOS
- 모바일 화면 대응 시 뷰포트 높이에 `h-screen` (100vh) 절대 금지 ❌. (Safari 브라우저 하단 바 이슈)
- 반드시 `min-h-[100dvh]`를 사용해야 합니다.

**App Shell & 풀높이 레이아웃 무결성:** // from: NICE Second Brain P7 (반응형 재정렬, Playwright 실측 회귀)
풀스크린 **앱 셸**(사이드바·메인·우측패널 등 다중 패널이 한 화면을 채우는 레이아웃)에서 반복되는 3가지 오버플로우 버그를 방지한다. 이 버그들은 **실브라우저에서만 발현**하고 jsdom 단위테스트·빌드는 통과(false-green)하므로 ④로 검증한다. (단일 풀높이 *섹션*인 랜딩 hero(§8)는 해당 없음 — 중첩 셸에서만.)

**① 중첩 뷰포트 높이 금지** — `h-[100dvh]`/`min-h-[100dvh]`는 **layout root 단 한 곳**에만 두고 `overflow-hidden`을 함께 준다. 내부 컬럼·패널은 `h-full min-h-0`, **스크롤이 필요한 영역만** `overflow-y-auto`. root와 자식에 동시에 dvh를 주면 자식이 부모를 넘어 세로 오버플로우(예: 입력창이 fold 아래로 밀려 사라짐).
```tsx
<div className="h-[100dvh] flex flex-col overflow-hidden">     {/* root만 dvh */}
  <header className="h-14 shrink-0" />
  <div className="flex flex-1 min-h-0">                         {/* min-h-0 = flex 자식 축소 허용(오버플로우 핵심) */}
    <aside className="hidden lg:block lg:w-64 shrink-0 h-full" />
    <main className="flex-1 min-w-0 flex flex-col">
      <div className="flex-1 overflow-y-auto" />                {/* 스크롤은 여기만 */}
      <footer className="shrink-0" />                           {/* 입력창 등 하단 고정 */}
    </main>
  </div>
</div>
```

**② canvas/측정-사이즈 컴포넌트는 컨테이너로 사이징** — `<canvas>`나 픽셀 고정 surface로 그리는 라이브러리(`react-force-graph`·차트·지도 등)는 width/height 기본값이 **window 크기**라, 더 작은 패널 안에 넣으면 패널 밖으로 가로 오버플로우를 만든다. 컨테이너 `ref`+`ResizeObserver`로 실측해 `width`/`height`를 **명시 전달**한다.
```tsx
const ref = useRef<HTMLDivElement>(null);
const [size, setSize] = useState({ w: 0, h: 0 });
useEffect(() => {
  if (!ref.current) return;
  const ro = new ResizeObserver(([e]) => setSize({ w: e.contentRect.width, h: e.contentRect.height }));
  ro.observe(ref.current);
  return () => ro.disconnect();
}, []);
return (
  <div ref={ref} className="relative h-full w-full overflow-hidden">
    <ForceGraph2D width={size.w} height={size.h} /* ... */ />   {/* 기본 window 크기 금지 → 명시 */}
  </div>
);
```

**③ 다중 패널 → 모바일 단일 컬럼** — 데스크톱 다중 패널은 태블릿/모바일에서 반드시 접는다. 고정폭 컬럼(`w-64`+`w-[34rem]` 등)을 그대로 두면 모바일에서 주 콘텐츠가 화면 밖으로 밀린다. 패턴: 사이드 패널 = `hidden lg:block` + 모바일 **드로어**(햄버거 토글), 보조 패널 = 모바일 **세그먼트 탭**으로 주 콘텐츠와 전환, 주 콘텐츠 = 모바일 `flex-1` 풀폭. 모바일 우선(single column)으로 짜고 `lg:`에서 다중 패널로 확장. §3 Breakpoint(`<768` 모바일 / `768~1024` 태블릿 / `>1024` 데스크톱) 기준.

**④ 레이아웃은 실측 검증** — ①②③ 버그는 jsdom(캔버스 모킹·레이아웃 미실행)·`vite build`에서 안 잡힌다(false-green). 실브라우저(예: Playwright)로 `document.documentElement.scrollWidth > clientWidth`(가로)·세로 오버플로우가 **0**인지 + 모바일 폭(예: 390px)에서 주 콘텐츠가 풀폭 가시인지 측정한 뒤 "레이아웃 완료"로 판정한다.
v2 보강: 앱 셸은 main이 자체 스크롤 컨테이너라 **root 측정만으로는 내부 가로 오버플로우를 놓친다**(root=0인데 main.scrollWidth 초과인 false-green 실측) — root와 함께 각 `overflow-*` 컨테이너의 `scrollWidth − clientWidth`도 측정한다. // evidence: F-L3-07

# 4. Components
가장 자주 사용하는 UI 요소들의 기준 형태입니다. 모바일과 웹에서 공통으로 호환됩니다. // from: 몽타주 web

### Button
```html
<!-- Primary -->
<button class="inline-flex items-center justify-center px-4 py-2.5 bg-primary text-neutral-0 text-body-md font-medium rounded-lg hover:bg-primary-hover transition-colors">
  확인
</button>

<!-- Secondary -->
<button class="inline-flex items-center justify-center px-4 py-2.5 bg-neutral-100 text-neutral-900 text-body-md font-medium rounded-lg hover:bg-neutral-300 transition-colors">
  취소
</button>

<!-- Ghost -->
<button class="inline-flex items-center justify-center px-4 py-2.5 bg-transparent text-neutral-700 text-body-md font-medium rounded-lg hover:bg-neutral-100 transition-colors">
  더보기
</button>
```

### Button Pair (Modal · Form footer)
같은 layer의 두 액션(예: 이전/다음, 취소/확인)은 **동일 너비**로 배치합니다. 위계는 **color 1축**으로만 표현 — 사이즈로 위계를 추가하면 신호가 중복되고 보조 액션이 평가절하된 인상을 줍니다.

```html
<!-- ✅ 권장: 동일 너비 + secondary/primary 색 대비 -->
<div class="flex gap-2">
  <button class="flex-1 px-5 py-3 bg-neutral-100 text-neutral-900 rounded-lg">이전</button>
  <button class="flex-1 px-5 py-3 bg-primary text-neutral-0 rounded-lg">다음</button>
</div>
```

**금지:** `flex-1` + `flex-[2]` 같은 비대칭 너비 (color와 위계 신호 중복).
**예외:** 단일 primary CTA만 있을 때는 `w-full` 사용 (페어 아님).

### Input & Textarea
```html
<!-- Input -->
<div class="flex flex-col gap-1.5">
  <label class="text-body-sm font-medium text-neutral-700">이메일</label>
  <input type="email" class="px-4 py-2.5 bg-neutral-0 border border-neutral-300 rounded-lg text-body-md text-neutral-900 focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all placeholder:text-neutral-500" placeholder="user@example.com" />
</div>
```

### Card
그림자는 매우 미세하게 주거나(border로 대체 가능) 테두리 반경은 단일 토큰(예: 12px)을 사용합니다.
```html
<div class="p-5 bg-neutral-0 border border-neutral-300 rounded-xl shadow-[0_2px_8px_rgba(0,0,0,0.04)]">
  <h3 class="text-H4 text-neutral-900 mb-2">카드 제목</h3>
  <p class="text-body-md text-neutral-500">카드의 내용이 들어갑니다.</p>
</div>
```

### Modal
닫기 버튼은 오직 1개만 배치합니다.
```html
<div class="fixed inset-0 z-50 flex items-center justify-center bg-neutral-900/40 p-4">
  <div class="w-full max-w-sm bg-neutral-0 rounded-2xl p-6 shadow-lg">
    <div class="flex justify-between items-center mb-4">
      <h2 class="text-H3 text-neutral-900">모달 제목</h2>
      <!-- Close Button: 1개만 -->
      <button class="text-neutral-500 hover:text-neutral-900"><i class="ci-close_big"></i></button>
    </div>
    <p class="text-body-md text-neutral-700 mb-6">모달의 본문 내용입니다.</p>
    <div class="flex gap-2 justify-end">
      <button class="px-4 py-2 bg-neutral-100 text-neutral-900 rounded-lg font-medium">취소</button>
      <button class="px-4 py-2 bg-primary text-neutral-0 rounded-lg font-medium">확인</button>
    </div>
  </div>
</div>
```

### Badge / Tag
```html
<span class="inline-flex items-center px-2 py-1 rounded bg-neutral-100 text-neutral-700 text-caption font-medium">
  태그
</span>
```

**금지 패턴:**
- 헤딩 위 둥근 사각형 아이콘 타일 ❌
- 동일한 3-column feature grid ❌ (정보 위계로 차별화 필요)
- 모든 카드에 그림자 + 큰 radius + 이모지 콤보 ❌
- 흰 배경에 흰 글자 ❌

# 5. Icons
아이콘은 **Coolicons** 단일 라이브러리를 사용합니다. // from: Coolicons

### Installation

> ⚠️ **웹폰트 CDN 부재**(2026-06-06 확인, P6): coolicons는 `coolicons.css` 웹폰트를 jsdelivr CDN으로 제공하지 **않는다** — `@v4.1`/`@4.1`/`@master` 어느 태그에도 CSS·폰트 파일이 없다(PNG만 또는 404). 따라서 기존 `<link href=".../coolicons.css">`·`@import` 방식은 **작동하지 않으며 아이콘이 미렌더된다**. 아래 방식을 사용한다.

**React 프로젝트 (권장)** — `react-coolicons`(coolicons 4.1 기반 React 컴포넌트):
```bash
npm install react-coolicons
```
```tsx
import { SearchMagnifyingGlass, ChevronRight, User01, Sun, Moon } from "react-coolicons";
// 색은 SVG currentColor 상속 — 부모 요소의 text-* 클래스로 제어. 크기는 width/height.
<SearchMagnifyingGlass width={20} height={20} />
```
정확한 export명은 `node_modules/react-coolicons/esm/` 디렉터리로 확인. v2 정정 — 실물 export명 (before: `SearchMagnifyingGlass`·`CloseLg`로 안내했으나 **존재하지 않는 export라 첫 렌더부터 크래시**): `ci-search`→`Search`, `ci-close_big`→`CloseBig`, `ci-hamburger`→`Hamburger`, `ci-user`→`User01`, `ci-warning`→`Warning`, 테마→`Sun`/`Moon`, 화살→`LongRight`/`LongDown`, `ci-chevron_*`→`ChevronBig*`. 아래 §Semantic Icon Mapping의 `ci-*`명은 *의미 참조*이며, React에선 대응 컴포넌트로 매핑한다. // evidence: F-L3-05

**currentColor 보정 (v2 필수)**: react-coolicons SVG는 `path fill="black"` 하드코딩이라 §5의 "currentColor 상속" 서술과 달리 **다크/잉크 표면에서 아이콘이 소실된다**. 전역 CSS 1줄로 보정 — Global Setup 4번째 항목으로 취급: // evidence: F-L1-11
```css
svg path[fill="black"] { fill: currentColor; }
```

**비-React / 정적 HTML** — coolicons.cool에서 webfont zip을 받아 `coolicons.css` + `/fonts`를 **자가호스팅**(로컬 `@font-face`). CDN `@import` 의존 금지.

### Icon Rules
- **사이즈 토큰**: 16px, 20px, 24px
- **Family 통일 규칙**: 한 화면 내에서 무조건 Coolicons 단일 family만 사용합니다.
- **금지**: UI 아이콘의 목적으로 이모지(Emoji) 사용 ❌ (본문 텍스트 내에서만 허용).

### Semantic Icon Mapping

| 의미 | Coolicons Class Name | 사이즈 예시 |
| --- | --- | --- |
| 검색 | `ci-search` | 20px |
| 닫기 | `ci-close_big` | 24px |
| 메뉴 | `ci-hamburger` | 24px |
| 알림 | `ci-notification` | 24px |
| 사용자 | `ci-user` | 24px |
| 설정 | `ci-settings` | 24px |
| 뒤로가기 | `ci-chevron_left` | 24px |
| 앞으로가기 | `ci-chevron_right` | 24px |
| 더보기 (수직) | `ci-more_vertical` | 20px |
| 외부 링크 | `ci-external_link` | 16px |
| 성공 (체크) | `ci-check` | 20px |
| 정보 | `ci-info` | 20px |
| 경고 | `ci-warning` | 20px |

# 6. Anti-AI-Slop Checklist (floor — 나쁨의 부재)
코드 작성 후 자가 검수용. 이 체크리스트를 모두 통과해야 "한국어 프로덕트"로서의 품질을 보장합니다. 18항목은 **바닥(floor)** — 좋음의 존재는 §15 Craft Ceiling이 별도로 검사합니다. 항목의 스코프 예외는 각 §에 명시된 것만 유효(예: letter-spacing 기본값의 §2 자간 함수 표).

- [ ] indigo/보라→파랑 그라데이션 없는가 (기본 테일윈드 AI 스타일 방지)
- [ ] 헤딩이나 숫자에 그라데이션 텍스트 없는가 (가독성 저하 및 AI 템플릿 느낌 방지)
- [ ] 헤딩 위 둥근 사각형 아이콘 타일 없는가 (Vercel/Stripe 템플릿 복붙 느낌 방지)
- [ ] 한 화면 색이 3개(neutral 제외) 이하인가 (시각적 복잡도 감소)
- [ ] 채도 80% 이하인가 (눈이 편안한 색상 사용 — §1 "최대 80%" 상한과 동일)
- [ ] hero 외 섹션이 모두 중앙정렬은 아닌가 (레이아웃 변주 부족 방지)
- [ ] 한 페이지 "text left, image right" 패턴 2회 이하인가 (지루한 레이아웃 방지)
- [ ] Inter 폰트가 아니라 Pretendard인가 (한글 가독성 최적화)
- [ ] letter-spacing -0.02em 적용했는가 (Pretendard 최적 자간 — §2 "자간은 크기의 함수" 표의 스코프 예외(마이크로 라벨 +트래킹·장문 -0.01em·display -0.03em대)는 위반 아님)
- [ ] body line-height 1.5인가 (본문 가독성)
- [ ] 아이콘이 Coolicons 단일 family인가, 이모지는 없는가 (일관성 확보)
- [ ] `h-screen` 대신 `min-h-[100dvh]` 사용했는가 (모바일 브라우저 버그 방지)
- [ ] (앱 셸) `h-[100dvh]`/`min-h-[100dvh]`가 layout root 1곳만인가, 중첩 dvh 없는가 (§3① 세로 오버플로우 방지)
- [ ] (canvas/그래프/차트) 컨테이너 ResizeObserver로 width/height 명시 사이징했는가 (§3② window-기본값 가로 오버플로우 방지)
- [ ] 다중 패널이 모바일(<768)에서 단일 컬럼(드로어/세그먼트)으로 접히는가 (§3③ 주 콘텐츠 화면밖 방지)
- [ ] (앱 셸) 실브라우저 실측으로 가로/세로 오버플로우 0 확인했는가 (§3④ jsdom false-green 방지)
- [ ] 모달에 close 아이콘 1개만 있는가 (혼란스러운 UX 방지)
- [ ] glassmorphism / neon glow / blurred orb 안 썼는가 (과도한 장식 배제)

# 7. Allowed Gradients
그라데이션은 무조건 금지되는 것이 아니며, "전형적인 AI 슬롭(AI slop) 그라데이션"이 금지됩니다.

- ✅ **허용**: 같은 hue의 저채도 톤 그라데이션 (예: ink → graphite, cream → sand)
- ✅ **허용**: 단일 hue atmospheric 그라데이션 (예: 사진 뒤 미세한 vignette)
- ✅ **허용**: noise texture가 들어간 미세한 그라데이션
- ❌ **금지**: indigo → violet, blue → purple, cyan → pink (AI 티가 나는 쨍한 색상)

허용 항목의 **실전 레시피(복붙 코드)는 §10** — 판별 기준: 그라데이션 양 끝의 hue가 같으면(Δhue=0) 허용 축, hue가 이동하면 금지 축이다. // evidence: F-L2-08

# 8. Quick Reference Snippets

### Landing Page Hero (Split-screen)
```tsx
<section className="min-h-[100dvh] w-full flex flex-col md:flex-row items-center bg-neutral-0">
  <div className="flex-1 w-full flex flex-col justify-center px-6 md:px-12 py-16 md:py-0">
    <h1 className="text-H1 text-neutral-900 mb-4 tracking-[-0.02em] leading-[1.3]">
      새로운 경험의<br />기준을 만듭니다
    </h1>
    <p className="text-body-lg text-neutral-500 mb-8 max-w-md leading-[1.5]">
      불필요한 요소를 모두 덜어내고, 오직 당신의 목표에만 집중할 수 있는 완벽한 환경을 제공합니다.
    </p>
    <div className="flex gap-3">
      <button className="px-5 py-3 bg-primary text-neutral-0 rounded-lg text-body-md font-medium">시작하기</button>
      <button className="px-5 py-3 bg-neutral-100 text-neutral-900 rounded-lg text-body-md font-medium">알아보기</button>
    </div>
  </div>
  <div className="flex-1 w-full h-full bg-neutral-100 min-h-[300px] md:min-h-full">
    {/* 우측 자산 (이미지 또는 추상적 형태) */}
  </div>
</section>
```

### Dashboard Card Grid (위계 차별화)
```tsx
<div className="grid grid-cols-1 md:grid-cols-3 gap-4 p-6 bg-neutral-100 min-h-[100dvh]">
  <div className="md:col-span-2 p-6 bg-neutral-0 rounded-xl border border-neutral-300">
    <h2 className="text-H4 text-neutral-900 mb-1">메인 지표</h2>
    <p className="text-body-sm text-neutral-500 mb-6">최근 7일간의 핵심 데이터입니다.</p>
    <div className="h-48 bg-neutral-100 rounded-lg"></div>
  </div>
  <div className="flex flex-col gap-4">
    <div className="p-5 bg-neutral-0 rounded-xl border border-neutral-300">
      <div className="text-body-sm text-neutral-500 mb-1">신규 가입자</div>
      <div className="text-H2 text-neutral-900">1,240</div>
    </div>
    <div className="p-5 bg-neutral-0 rounded-xl border border-neutral-300 flex-1">
      <div className="text-body-sm text-neutral-500 mb-3">최근 활동</div>
      <ul className="flex flex-col gap-3">
        <li className="text-body-sm text-neutral-700">사용자 A 님이 로그인했습니다.</li>
        <li className="text-body-sm text-neutral-700">새로운 프로젝트가 생성되었습니다.</li>
      </ul>
    </div>
  </div>
</div>
```

### Mobile List Item (Montage iOS 기반)
```tsx
<li className="flex items-center px-4 py-3 bg-neutral-0 active:bg-neutral-100 transition-colors">
  <div className="w-10 h-10 rounded-full bg-neutral-100 flex items-center justify-center text-neutral-500 mr-3">
    <i className="ci-user text-[20px]"></i>
  </div>
  <div className="flex-1 min-w-0">
    <div className="text-body-md font-medium text-neutral-900 truncate">홍길동</div>
    <div className="text-body-sm text-neutral-500 truncate">hong@example.com</div>
  </div>
  <i className="ci-chevron_right text-neutral-300 text-[20px] ml-2"></i>
</li>
```

### Form View
```tsx
<form className="w-full max-w-sm mx-auto p-6 bg-neutral-0 rounded-xl border border-neutral-300 shadow-[0_2px_8px_rgba(0,0,0,0.04)]">
  <h2 className="text-H3 text-neutral-900 mb-6">로그인</h2>
  <div className="flex flex-col gap-4 mb-6">
    <div className="flex flex-col gap-1.5">
      <label className="text-body-sm font-medium text-neutral-700">이메일</label>
      <input type="email" className="px-4 py-2.5 bg-neutral-0 border border-neutral-300 rounded-lg text-body-md focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all placeholder:text-neutral-500" placeholder="이메일을 입력하세요" />
    </div>
    <div className="flex flex-col gap-1.5">
      <label className="text-body-sm font-medium text-neutral-700">비밀번호</label>
      <input type="password" className="px-4 py-2.5 bg-neutral-0 border border-neutral-300 rounded-lg text-body-md focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all placeholder:text-neutral-500" placeholder="비밀번호를 입력하세요" />
    </div>
  </div>
  <button type="submit" className="w-full py-3 bg-primary text-neutral-0 rounded-lg text-body-md font-medium hover:bg-primary-hover transition-colors">
    로그인
  </button>
</form>
```

### Empty State
```tsx
<div className="flex flex-col items-center justify-center p-12 text-center bg-neutral-0 rounded-xl border border-neutral-300 border-dashed">
  <div className="w-12 h-12 rounded-full bg-neutral-100 flex items-center justify-center text-neutral-500 mb-4">
    <i className="ci-search text-[24px]"></i>
  </div>
  <h3 className="text-H4 text-neutral-900 mb-1">검색 결과가 없습니다</h3>
  <p className="text-body-md text-neutral-500 mb-5">다른 검색어로 다시 시도해 보세요.</p>
  <button className="px-4 py-2 bg-neutral-100 text-neutral-900 rounded-lg text-body-sm font-medium hover:bg-neutral-300 transition-colors">
    초기화
  </button>
</div>
```

### KPI Stat Grid (v2 정정) // evidence: F-L3-06
통화·큰 수치 카드는 모바일에서 **1열** — `grid-cols-2`는 긴 값(₩84,200,000)이 카드 폭을 넘어 내부 가로 오버플로우를 만든다.
```tsx
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 md:gap-4">
  <div className="p-5 bg-neutral-0 border border-neutral-300 rounded-xl">
    <div className="text-body-sm text-neutral-500 mb-1">이번 달 청구액</div>
    <div className="flex items-baseline gap-2">
      <span className="text-H2 text-neutral-900 num">₩84,200,000</span>
      <span className="text-body-sm num text-success">+12%</span>{/* delta에만 시맨틱 */}
    </div>
  </div>
</div>
```

# 9. Motion System // evidence: F-L1-04, F-L3-04
모션은 장식이 아니라 인과다. 원인 없는 애니메이션은 소음으로 친다.

### Duration & Easing 토큰
| 토큰 | 값 | 용도 |
| --- | --- | --- |
| motion-fast | 150–200ms | hover·색 전환 (`transition-colors`) |
| motion-base | 300–450ms | fade-up 리빌, 상태 전환 |
| motion-hero | 550–700ms | 오프닝 안무 (페이지당 1회) |
| ease-out-soft | `cubic-bezier(0.22, 1, 0.36, 1)` | enter/리빌 표준 곡선 (감속 — 즉답 인상) |

- **enter/exit = ease-out 계열**, 화면 내 이동 = ease-in-out. `transition: all` 금지 — 애니메이트할 property를 명시.
- **transform/opacity만** 애니메이트 (layout property(width/height/top) 금지 — CLS·jank). 진입 모션 중 layout shift 0이어야 한다 (실측: PerformanceObserver CLS < 0.02).
- **stagger**: 순차 등장은 60–120ms 간격 (KPI 카드 60ms·hero 행 120ms 실측). 총 안무 <700ms.
- **반복 사용 화면은 무모션**: 대시보드·목록 등 매일 여러 번 보는 화면은 진입 스태거 1회 외 전부 `transition-colors`만. 반복 키보드 액션은 절대 애니메이트하지 않는다.
- **연속 고novelty 금지**: 큰 모션 섹션 뒤에는 조용한 섹션 (§14 완급).

### 표준 레시피
```css
/* 오프닝 fade-up (hero·표제) */
@media (prefers-reduced-motion: no-preference) {
  .fade-up { opacity: 0; animation: rise-in 550ms cubic-bezier(0.22, 1, 0.36, 1) forwards; }
  .fade-up:nth-child(2) { animation-delay: 90ms; }   /* stagger */
  .fade-up:nth-child(3) { animation-delay: 180ms; }
}
@keyframes rise-in { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }

/* 클립 마스크 rise (타입 안무 — signature move용) */
.line-mask { display: block; overflow: hidden; }
@media (prefers-reduced-motion: no-preference) {
  .line-mask > span { display: block; transform: translateY(110%); animation: line-rise 700ms cubic-bezier(0.22, 1, 0.36, 1) forwards; }
}
@keyframes line-rise { to { transform: translateY(0); } }
```

```tsx
// 스크롤 리빌 — IntersectionObserver + .reveal (라이브러리 불필요)
useEffect(() => {
  const io = new IntersectionObserver(
    (es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in-view'); io.unobserve(e.target) } }),
    { threshold: 0.15 },
  )
  root.querySelectorAll('.reveal').forEach((el) => io.observe(el))
  return () => io.disconnect()
}, [])
```
```css
@media (prefers-reduced-motion: no-preference) {
  .reveal { opacity: 0; transform: translateY(14px); transition: opacity 550ms ease-out, transform 550ms cubic-bezier(0.22, 1, 0.36, 1); }
  .reveal.in-view { opacity: 1; transform: translateY(0); }
}
```

### Reduced-motion 필수 분기
모든 모션은 `@media (prefers-reduced-motion: no-preference)` **안에만** 선언한다 — reduce 환경에서 베이스 상태가 "완성된 화면"(opacity 1·transform none)이 되도록. 콘텐츠·내비게이션 기능은 모션 없이 동등해야 한다 (실측: emulateMedia로 opacity 전부 1 확인).

# 10. Expressive Tier — 잉크·페이퍼·Fluid // evidence: F-L1-05, F-L1-06, F-L1-08, F-L2-01, F-L2-02, F-L2-06, F-L2-07, F-L2-08
표현 상한이 필요한 표면(브랜드 hero·에디토리얼·풋터 마침)의 레시피. **UI 표면(§4)에는 적용하지 않는다.**

### Fluid Display (clamp 스케일)
| 티어 | 레시피 | 스코프 |
| --- | --- | --- |
| 브랜드 hero | `font-size: clamp(64px, 7.5vw, 112px); line-height: 1.05; letter-spacing: -0.035em; font-weight: 700;` | 랜딩 hero·풋터 대형 마침 |
| 에디토리얼 표제 | `font-size: clamp(48px, 6vw, 88px); line-height: 1.04; letter-spacing: -0.035em; font-weight: 700;` | 아티클 표제부 |

display-xl(64px)이 상한이던 v1과 달리, 브랜드 표면은 뷰포트 비례로 96–112px까지 확장한다. 페어링 필수: leading 1.0–1.1 + tracking -0.03em대 (커지면 조인다 — §2 자간 함수).

### 잉크 섹션 (라이트 페이지 안의 다크 섹션 — 다크모드와 독립)
인버전은 하드코딩(`bg-neutral-900`+`text-white`)이 아니라 **변수 스코프 재매핑** — 기존 토큰 클래스가 스코프 안에서 자동 반전되고, 다크모드에서도 무결하다.
```css
.ink {
  --color-neutral-0: hsl(220, 13%, 9%);
  --color-neutral-100: hsl(220, 11%, 14%);
  --color-neutral-300: hsl(220, 9%, 26%);
  --color-neutral-500: hsl(220, 8%, 56%);
  --color-neutral-700: hsl(220, 9%, 74%);
  --color-neutral-900: hsl(220, 12%, 95%);
}
/* 다크 테마에선 잉크가 표면(11%)보다 한 단계 더 깊게 — 명암 리듬 보존 */
html[data-theme="dark"] .ink {
  --color-neutral-0: hsl(220, 15%, 6%);
  --color-neutral-100: hsl(220, 13%, 11%);
  --color-neutral-300: hsl(220, 10%, 22%);
}
```
```tsx
<section className="ink bg-neutral-0 text-neutral-900">{/* 같은 클래스, 반전된 값 */}</section>
```

### 페이퍼 뉘앙스 (warm 표면 — opt-in)
"잉크와 종이" 무드의 warm paper. 경계: hue 30–40 · S ≤ 25% · 표면(neutral-0 대체) L ≥ 96%. **스코프는 html data-attr(최상위)** — 페이지 로컬 클래스는 fixed 컨트롤을 놓쳐 순백 칩이 뜬다. 기존 neutral 토큰 값 자체는 불변(opt-in 재매핑).
```css
html[data-surface="paper"]:not([data-theme="dark"]) {
  --color-neutral-0: hsl(35, 22%, 97%);
  --color-neutral-100: hsl(35, 16%, 92%);
  --color-neutral-300: hsl(35, 10%, 78%);
}
```

### Grain & 허용 그라데이션 실코드 (§7의 레시피)
```css
/* 같은 hue 저채도 톤 그라데이션 (Δhue=0) — 잉크/페이퍼 도판·추상 표면 */
.fig-ink   { background: linear-gradient(135deg, hsl(220, 14%, 22%) 0%, hsl(220, 10%, 42%) 100%); }
.fig-paper { background: linear-gradient(160deg, hsl(35, 18%, 88%) 0%, hsl(35, 12%, 72%) 100%); }
/* grain — SVG feTurbulence data-URI (의존성 0) */
.grain { position: relative; }
.grain::after {
  content: ''; position: absolute; inset: 0; pointer-events: none; opacity: 0.5;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/%3E%3CfeColorMatrix values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.10 0'/%3E%3C/filter%3E%3Crect width='120' height='120' filter='url(%23n)'/%3E%3C/svg%3E");
}
```

### 에디토리얼 관용구
```css
/* 드롭캡 — 아티클 첫 문단 */
.dropcap::first-letter { float: left; font-size: 3.6em; line-height: 0.85; font-weight: 700; padding: 0.06em 0.16em 0 0; }
/* 각주 마커 + 미주는 §2 위계(11px super primary / border-t + caption 헤더) */
.fn { font-size: 11px; vertical-align: super; line-height: 0; color: var(--color-primary-base); font-weight: 500; }
```
풀 인용(pull quote)은 display-md/lg + `border-l-2` + 좌 패딩. **bleed**(본문 폭 밖 확장)는 §14 규칙을 따른다.

# 11. Depth & Elevation // evidence: F-L3-09
그림자는 위계가 아니라 **분리**의 신호 — 기본은 border 단차·배경 단차로 깊이를 만들고, 그림자는 떠 있는 것(드로어·모달·팝오버)에만. (레벨 0·1·3은 v1 §4 값의 통합 재서술 — 신규는 0.5·2와 이중 단차.)
| 레벨 | 레시피 | 용도 |
| --- | --- | --- |
| 0 | `border border-neutral-300` | 카드·표·인풋 (기본) |
| 0.5 | 배경 단차 (`bg-neutral-100` 안 `bg-neutral-0` 카드) | 섹션 안 표면 구분 |
| 1 | `shadow-[0_2px_8px_rgba(0,0,0,0.04)]` + border | 강조 카드 (§4) |
| 2 | `shadow-[0_2px_8px_rgba(0,0,0,0.08)]` | 드로어·팝오버 (떠 있음) |
| 3 | `shadow-lg` + scrim | 모달 (§4) |

행 구분은 이중 단차: 굵은 경계(`border-neutral-300`)는 섹션·헤더에, 얇은 경계(`border-neutral-100`)는 행 사이에 — 표가 조밀해도 시끄럽지 않다. // evidence: F-L3-09

# 12. Interaction States // evidence: F-L1-09, F-L2-09, F-L3-02, F-L3-03, F-L3-08
### Hover — 주의를 보상한다
- 목록 행: 배경 1단차 (`hover:bg-neutral-100`, 서브틀 배경 위에선 `hover:bg-neutral-0` 반전) + 보조 신호 1개(인덱스 primary화·화살표 슬라이드 등 transform ≤8px).
- 버튼·링크: §4 색 전환만 (`transition-colors`). bouncy·scale 금지.

### Focus-visible — 키보드 순회가 눈으로 따라가져야 한다
모든 인터랙티브 요소(버튼·링크·탭·셀렉트)에 필수:
```css
.focusable:focus-visible { outline: 2px solid var(--color-primary-base); outline-offset: 2px; border-radius: 6px; }
```
`:focus`가 아니라 `:focus-visible` — 마우스 클릭에는 링이 뜨지 않는다. (§4 input의 `focus:ring`은 인풋 전용 관례로 유지.)

### Loading — skeleton
```css
.skeleton { background: var(--color-neutral-100); border-radius: 6px; }
@media (prefers-reduced-motion: no-preference) { .skeleton { animation: pulse 1.6s ease-in-out infinite; } }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.55; } }
```
- shimmer(이동 하이라이트) 금지 — pulse가 §0 절제에 부합. 최종 콘텐츠와 같은 자리·같은 크기(레이아웃 안정).
- 깜빡임 방지: 표시 지연 ~150–300ms, 최소 표시 ~300–500ms.

### 부동(fixed) 컨트롤 — 자기 표면 필수
명암이 다른 섹션들 위를 지나는 fixed 요소(테마 토글 등)는 **자기 배경+border**를 가져야 잉크 섹션 위에서 소실되지 않는다: `bg-neutral-0 border border-neutral-300`.
**장르 규칙**: fixed 오버레이는 콘텐츠-스크롤 장르(랜딩·아티클) 전용 — 밀도 높은 앱 셸에서는 헤더 행 안에 통합하거나 헤더가 그 자리를 예약한다(390에서 헤더 컨트롤과 충돌 실측).

# 13. A11y Floor // evidence: F-L3-02, F-L3-10
- `prefers-reduced-motion` 분기 필수 (§9) — 기능 동등 실측.
- 키보드: 전 인터랙티브 요소 focus-visible(§12) + Tab 순서가 시각 순서와 일치. // evidence: F-L3-02
- 색만으로 상태를 전하지 않는다 — Badge·delta에 텍스트 병기 (§8 KPI delta처럼 "+12%"). // evidence: F-L3-10
- 아이콘 단독 버튼은 `aria-label` 필수. 이미지형 도판은 `role="img"` + `aria-label`. // evidence: F-L3-10
- 통용 플로어 (외부 표준 준용 — WCAG·플랫폼 관례, 랩 밖 근거): hit target ≥24px(모바일 주 액션 44px) · 모바일 input 텍스트 ≥16px(iOS 자동 줌 방지) · 본문 대비 ≥4.5:1(neutral-500 이하는 보조 정보에만).

# 14. Page Rhythm — 완급의 문법 // evidence: F-L1-10, F-L2-10
- **숨→밀도 교차**: 페이지는 조밀한 섹션과 숨 쉬는 섹션의 교차로 리듬을 만든다 (예: hero(숨)→목록(밀도)→인용(숨)→그리드(밀도)→마침(숨)). 균질 밀도 = 리듬 부재 = 슬롭.
- **대형 여백에는 앵커**: 와이드 뷰포트(≥1440)에서 빈 사분면이 2개 이상이면 "여백"이 아니라 "부재"로 읽힌다. 대각 앵커(좌상 워드마크 ↔ 우하 메타 라벨)·스크롤 큐·인덱스 등 조용한 요소로 의도를 표시한다.
- **bleed 규칙**: 본문 폭 밖 확장(인용·피겨)은 확장 후에도 뷰포트 가장자리와 컨테이너 패딩 이상의 여백이 남는 브레이크포인트에서만 (통상 `lg:` 이상 — md에서 bleed하면 가장자리 밀착으로 숨이 사라진다).
- **명암 리듬**: 잉크 섹션(§10)은 페이지당 1–2회의 명암 전환점으로 — 연속 잉크는 리듬이 아니라 다크 페이지다.

# 15. Craft Ceiling Checklist (좋음의 존재 — §6 floor 통과 후)
- [ ] 위계 점프가 ≥3단계인가 (12px 라벨 ↔ 본문 ↔ 섹션 헤딩 ↔ display — §0 서열 1)
- [ ] signature move가 **정확히 1개** 있는가 (0=밋밋, 2+=완급 붕괴 — §0)
- [ ] 밀도에 완급이 있는가 — 숨 섹션과 밀도 섹션이 교차하는가 (§14)
- [ ] hover가 주의를 보상하는가 — 목록/카드에 배경+보조 신호 (§12)
- [ ] focus-visible이 실제로 보이는가 — Tab 순회 실측 (§12·§13)
- [ ] 진입 모션이 reduced-motion에서 기능 동등인가 (§9)
- [ ] 데이터 숫자가 tabular-nums인가 (§2 — 해당 시)
- [ ] (표현 표면) 잉크/페이퍼 명암 리듬 또는 fluid display를 활용했는가 (§10 — 브랜드/에디토리얼 한정)
- [ ] 다크 모드에서도 위 전부가 성립하는가 (변수 재매핑 실측)
