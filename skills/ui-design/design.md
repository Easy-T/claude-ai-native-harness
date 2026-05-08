# UI Design Reference

> 이 파일은 `ui-design` skill이 자동 주입한다. 웹/앱 UI 작업의 모든 시각 결정은 여기 토큰을 따른다.

# 0. Tone Manifesto
여백 중심, 절제된 색, 명확한 위계. 화려함이 아닌 정확함으로 만족시킨다. 장식적인 요소는 배제하고 콘텐츠 자체가 UI의 형태를 띠도록 구성한다. 시스템이 예측 가능하며 단단한 느낌을 주어, 사용자가 이질감을 느끼지 않도록 한다.

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

**사용 규칙:** // from: 몽타주 공통
- **한도 명시**: 한 화면에 Primary 1개, Neutral 2~3개 사용. Semantic 컬러는 오류/성공 등 꼭 필요한 경우에만 사용.
- **Saturation 상한**: 모든 컬러의 채도는 최대 80%를 넘지 않아야 합니다.
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

**사용 규칙:**
- **기본값**: 전체 텍스트 `letter-spacing: -0.02em`, 본문 `line-height: 1.5`, 헤딩 `line-height: 1.3`
- **금지**: Inter 폰트 사용 ❌, 헤딩이나 숫자에 그라데이션 텍스트 적용 ❌, 영문 폰트(Roboto 등)와 한글 폰트 혼용 ❌.

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

### Installation & CSS CDN
```html
<!-- Coolicons CSS -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/krystonschwarze/coolicons@v4.1/coolicons.css">
```

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

# 6. Anti-AI-Slop Checklist
코드 작성 후 자가 검수용. 이 체크리스트를 모두 통과해야 "한국어 프로덕트"로서의 품질을 보장합니다.

- [ ] indigo/보라→파랑 그라데이션 없는가 (기본 테일윈드 AI 스타일 방지)
- [ ] 헤딩이나 숫자에 그라데이션 텍스트 없는가 (가독성 저하 및 AI 템플릿 느낌 방지)
- [ ] 헤딩 위 둥근 사각형 아이콘 타일 없는가 (Vercel/Stripe 템플릿 복붙 느낌 방지)
- [ ] 한 화면 색이 3개(neutral 제외) 이하인가 (시각적 복잡도 감소)
- [ ] 채도 80% 이하인가 (눈이 편안한 색상 사용 — §1 "최대 80%" 상한과 동일)
- [ ] hero 외 섹션이 모두 중앙정렬은 아닌가 (레이아웃 변주 부족 방지)
- [ ] 한 페이지 "text left, image right" 패턴 2회 이하인가 (지루한 레이아웃 방지)
- [ ] Inter 폰트가 아니라 Pretendard인가 (한글 가독성 최적화)
- [ ] letter-spacing -0.02em 적용했는가 (Pretendard 최적 자간)
- [ ] body line-height 1.5인가 (본문 가독성)
- [ ] 아이콘이 Coolicons 단일 family인가, 이모지는 없는가 (일관성 확보)
- [ ] `h-screen` 대신 `min-h-[100dvh]` 사용했는가 (모바일 브라우저 버그 방지)
- [ ] 모달에 close 아이콘 1개만 있는가 (혼란스러운 UX 방지)
- [ ] glassmorphism / neon glow / blurred orb 안 썼는가 (과도한 장식 배제)

# 7. Allowed Gradients
그라데이션은 무조건 금지되는 것이 아니며, "전형적인 AI 슬롭(AI slop) 그라데이션"이 금지됩니다.

- ✅ **허용**: 같은 hue의 저채도 톤 그라데이션 (예: ink → graphite, cream → sand)
- ✅ **허용**: 단일 hue atmospheric 그라데이션 (예: 사진 뒤 미세한 vignette)
- ✅ **허용**: noise texture가 들어간 미세한 그라데이션
- ❌ **금지**: indigo → violet, blue → purple, cyan → pink (AI 티가 나는 쨍한 색상)

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
