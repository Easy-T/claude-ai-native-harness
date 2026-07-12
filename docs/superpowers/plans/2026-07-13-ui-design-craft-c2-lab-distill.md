# UI-Design Craft C2 — Lab L2·L3 + Distill Implementation Plan

**Status:** completed
**RPI-Cycle:** 49
**Started:** 2026-07-13

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline, 메인 세션 — Playwright MCP + 시각 판단 연속성).
> **Lab-adapted TDD:** 랩 task의 오라클 = 실측 게이트(spec §4.4) + 브리프. Distill task의 오라클 = FRICTION-인용 의무 + 줄수 상한 + enforce-orchestrator/verify-setup 게이트 + review-strict.

**Goal:** L2(에디토리얼)·L3(대시보드)를 v1-strict로 제작해 FRICTION을 마저 채록하고, 전체 FRICTION만을 근거로 design.md v2(§9–§15 신설, ≤880줄)와 SKILL.md v2(5-Phase)를 작성한다.

**Architecture:** C1의 `_design-lab/lab` 단일 Vite 앱에 `/l2` `/l3` 라우트 추가(공유 tokens/스캐폴드 재사용). Distill은 `skills/ui-design/` 2파일의 additive 개정 — 토큰명·클래스 시그니처·파일명 불변.

**Tech Stack:** C1과 동일 (Vite 5·React 18·tailwindcss 3.4.17·react-router 6·react-coolicons·Playwright MCP).

## Global Constraints

- **v1-strict + FRICTION-로깅 편차** (spec §4.3): 랩 적용 규칙은 design.md v1만, 편차는 `F-L<n>-<seq>` 채록 필수.
- **라운드 상한 6 / 연속 2라운드 0건 조기 종료 / 수확 체감 시 중단·기록** (spec §4.3).
- **실측 게이트** (spec §4.4): 가로 오버플로우 0(390·768·1440) · 다크 스왑 무결 · reduced-motion 기능 동등 · CLS<0.02 · anti-slop 18/18 · 한국어 실카피.
- **동시세션 규약** (spec §4.5): ephemeral 포트(5300–5999), 자기 PID만 종료.
- **Distill 증거 의무** (spec §5.1): 모든 신규 규칙에 `// evidence: F-…` ≥1 인용. 무증거 규칙 금지.
- **design.md ≤880줄** (spec §5.1). 초과 시 aux 분리 + SKILL.md 라우팅.
- **하위호환** (spec §6): 기존 토큰명·컴포넌트 클래스·파일명 불변. Anti-Slop 18항목 삭제 금지(문구 정련·스코프 예외만).
- **SKILL.md 골격** (spec §5.2): `# Phase ` h1 ≥3 · `Agent(subagent_type=` ≥1 · `Communication Protocol` 존재 · frontmatter 3마커(orchestrator_skill/generated_by/orchestrator_version) 유지 · frontmatter http(s):// 금지.
- **캡처 방법론** (C1 확립): 풀페이지 캡처 전 뷰포트-스텝 스크롤 + 잔여 reveal 강제완료(스티치 아티팩트 회피); 라이브 IO 메커니즘은 사이트당 1회 느린 스크롤로 별도 검증.

## FRICTION Digest — L1 (v2의 근거; 원본 `_design-lab/FRICTION.md`는 gitignored)

| ID | 유형 | 요지 | v2 타깃 |
|---|---|---|---|
| F-L1-01 | 틀림 | §1 다크 블록이 Tailwind가 읽는 `--color-primary-base/hover/active` 미재매핑 → 다크 primary 무효 | §1 수정 |
| F-L1-02 | 부족 | §1 config가 `transparent`/`current` 소실 → §4 ghost 버튼 자기모순 | §1 수정 |
| F-L1-03 | 부족 | §2 타이포 표가 Tailwind fontSize 토큰으로 미실체화 → 스캐폴드마다 재발명 | §2 추가 |
| F-L1-04 | 침묵 | 모션 시스템 전무(duration·easing·stagger·리빌·reduced-motion) | §9 신설 |
| F-L1-05 | 침묵 | 잉크 섹션(라이트 내 다크 섹션) 레시피 부재 — 다크모드와 독립 | §10 |
| F-L1-06 | 부족 | display 상한 64px가 브랜드 hero에서 부족 — fluid clamp 부재 | §10 |
| F-L1-07 | 과광역 | 전역 -0.02em가 12px 대문자 마이크로 라벨 봉쇄 (+0.06~0.12em 필요) | §2 예외 |
| F-L1-08 | 부족 | 페이퍼 뉘앙스(warm paper) 수단 부재 — §7 허용-무방법 | §10 |
| F-L1-09 | 침묵 | 인터랙션 상태 스펙 부재 — 부동 컨트롤 자기 표면·focus-visible | §12 |
| F-L1-10 | 침묵 | 와이드(≥1920) hero 공간 문법 부재 — 빈 사분면=부재로 읽힘 | §14 |
| F-L1-11 | 틀림 | §5 "currentColor 상속"이 react-coolicons `fill="black"` 실물과 불일치 | §5 수정 |

*L2·L3 채록분은 Task 3·6 완료 시 이 표 아래 추가된다 (Distill 착수 전 완결).*

| ID | 유형 | 요지 | v2 타깃 |
|---|---|---|---|
| F-L2-01 | 부족 | 페이퍼 뉘앙스 레시피 검증: 라이트 전용 조건부 재매핑(35°·S≤22%·L≥97%) 성립 | §10 |
| F-L2-02 | 부족 | 에디토리얼 표제 fluid: clamp(48,6vw,88)/1.04 — 브랜드 hero와 다른 최적점 → 장르 2단 티어 | §10 |
| F-L2-03 | 침묵 | 한국어 장문 measure 부재 — 36em(한글 ~34자/행) 실증, 라틴 66ch는 과폭 | §2 |
| F-L2-04 | 부족 | 장문 본문 17px/1.8 — §2 body-lg 16px/1.5는 장문에서 조밀 → long-form 티어 | §2 |
| F-L2-05 | 과광역 | 자간은 크기의 함수: display -0.035 ~ 장문 -0.01 ~ 라벨 +0.08 스케일 실증 | §2 |
| F-L2-06 | 침묵 | 드롭캡 ::first-letter 레시피 (3.6em/0.85/700) 성립 | §10 |
| F-L2-07 | 침묵 | 각주 마커(11px super primary)+미주 블록 위계 성립 | §10 |
| F-L2-08 | §7실증 | 허용 그라데이션(Δhue=0 저채도)+grain(feTurbulence data-URI, alpha 0.10) 실코드 확보 — G4 해소 | §10+§7 |
| F-L2-09 | 침묵 | 표면 뉘앙스 스코프는 html data-attr(최상위) — 페이지 로컬 클래스는 fixed 컨트롤을 놓침 | §10·§12 |
| F-L2-10 | 침묵 | bleed는 확장 후에도 가장자리 여백이 남는 브레이크포인트(통상 lg+)에서만 | §14 |
| F-L3-01 | 침묵 | 데이터 숫자(KPI·표·시간열)는 tabular-nums — 가변폭 숫자는 열이 흔들림 | §2 |
| F-L3-02 | 침묵 | focus-visible ring 스펙 부재 — outline 2px primary/offset 2px 실증, Tab 순회 가시 | §12·§13 |
| F-L3-03 | 침묵 | skeleton 레시피: neutral-100 + pulse(1.6s), shimmer 금지, reduced-motion 정지 | §12 |
| F-L3-04 | G1실증 | 반복 화면 무모션 원칙: 진입 스태거 1회(60ms 간격, <400ms) 외 색 전환만 | §9 |
| F-L3-05 | 틀림 | §5 매핑표 React export명 부정확(CloseLg·SearchMagnifyingGlass → 실물 CloseBig·Search) — 첫 렌더 크래시 | §5 |
| F-L3-06 | 부족 | §8 KPI 그리드: 긴 통화값은 모바일 2col에서 내부 오버플로우 — grid-cols-1 sm:2 lg:4 정정 | §8 |
| F-L3-07 | 부족 | §3④ 실측이 root만 재면 앱셸 내부 스크롤 컨테이너 오버플로우를 놓침(false-green) — main도 측정 | §3 |
| F-L3-08 | 침묵 | 앱 셸에선 부동 컨트롤을 헤더에 통합/자리 예약 — fixed 오버레이는 콘텐츠-스크롤 장르 전용 | §12 |
| F-L3-09 | 침묵 | elevation 단차 체계: 배경 단차·행 이중 단차·부유 그림자 0.08 3단 실증 (G3) | §11 |
| F-L3-10 | 침묵 | a11y 어포던스: 아이콘 버튼 aria-label·도판 role=img·색-단독 금지(텍스트 병기) — 랩 실증분 (G8) | §13 |
| F-ALL-01 | 부족 | 위계 점프 ≥3단계 — 3장르 교차 실증 (L1 r1 FAIL→r2 PASS가 직접 증거) (G9) | §0·§15 |

---

### Task 1: L2 브리프 + 라우트 스캐폴드

**Files:**
- Create: `_design-lab/briefs/L2.md`, `_design-lab/LOG-L2.md`, `_design-lab/lab/src/pages/L2.jsx`(셸)
- Modify: `_design-lab/lab/src/App.jsx`(라우트+인덱스 링크)

- [x] **Step 1: 브리프 verbatim 작성** (`_design-lab/briefs/L2.md`):

```markdown
# L2 브리프 — 온도 저널: 「화면 위의 조판」

## 컨셉 (1줄)
스튜디오 온도가 발행하는 에디토리얼 저널의 대표 아티클 — 장문 한국어 에세이가 그 자체로 조판 견본이 되는 페이지.

## 무드 3키워드
문예지의 밀도 / 활판의 질감 / 차분한 학구열

## Signature move (정확히 1개)
**오프닝 표제 조판**: kicker(마이크로 라벨) → 초대형 fluid 표제("화면 위의 조판") → 스탠드퍼스트(리드 문단) → 필자·날짜 메타가 4단 위계로 순차 fade-up(stagger 90ms). 본문 진입 후에는 리빌 없음 — 장문 독서를 방해하지 않는다 (모션은 표제 1회가 전부).

## 색·타입 전략
- 순백이 아닌 종이: 본문 표면을 페이퍼 뉘앙스로 (F-L1-08 후속 실험 — warm hue 30~40 저채도).
- 본문 measure 실험: 한국어 장문 최적 폭(자수) — v1 침묵 검증.
- 위계: kicker 12px ↔ 표제 clamp ~88px ↔ 본문 17~18px(장문 가독 실험 — §2 body-lg 16px 상한 검증) ↔ 캡션 12px.
- 인용(pull quote)·드롭캡·각주·캡션 — 에디토리얼 관용구 전면 실험 (전부 v1 침묵).

## 섹션 아웃라인
1. **표제부** (페이퍼, 숨) — kicker "ONDO JOURNAL — TYPOGRAPHY", 표제, 스탠드퍼스트, 메타(필자 김온도·2026.07·12분 읽기).
2. **본문 I** (밀도) — 드롭캡 문단으로 시작. 소제목 2개. 한국어 실에세이 (조판의 역사→화면 조판의 문제).
3. **풀 인용** (숨) — 본문 폭 밖으로 확장(bleed)되는 대형 인용 1개.
4. **피겨** (밀도) — 추상 도판 2점(같은 hue 저채도 CSS 구성 — §7 허용 그라데이션 실험) + 번호 캡션.
5. **본문 II** (밀도) — 소제목 2개(리듬·자간 논의), 인라인 각주 마커 + 미주 목록.
6. **마침부** (숨) — 필자 바이오 라인 + "다음 글" 2건 목록(연도·제목).

## 성공 기준
- 1440에서 "블로그"가 아니라 "문예지"로 읽힌다 (measure·리듬·인용의 조판 밀도).
- 본문이 12분 스크롤 내내 균질하지 않다 — 인용/피겨가 숨을 만든다.
- 드롭캡·인용·캡션·각주가 전부 토큰만으로 성립.
- anti-slop 18/18 + 실측 게이트 ALL PASS.
```

- [x] **Step 2: LOG-L2.md 헤더 생성** (LOG-L1 형식 동일 — 5축 표).
- [x] **Step 3: 라우트 스캐폴드** — `L2.jsx` 셸(`<main className="min-h-[100dvh] bg-neutral-0"><p>L2</p></main>`), App.jsx에 `/l2` 라우트 + Home 인덱스에 링크 추가.
- [x] **Step 4: dev 서버 기동(ephemeral 포트) + 렌더 스모크** — `PORT=$((5300+RANDOM%700))`, `.port`/`.devpid` 갱신, Playwright navigate `/l2` 콘솔 에러 0.

### Task 2: L2 라운드 0 구현 (v1-strict)

**Files:**
- Modify: `_design-lab/lab/src/pages/L2.jsx`(전면), `_design-lab/lab/src/index.css`(L2 실험 블록 — `.l2-*` 스코프)

- [x] **Step 1: 브리프 → JSX.** 본문은 실에세이(한국어, 소제목 4·문단 ≥14·인용 1·피겨 2·각주 3·미주 3). 실험은 전부 FRICTION 주석: 페이퍼 표면(`.l2-paper` 로컬 변수 실험 → F-L2 채록), fluid 표제(`.l2-headline` clamp), measure(`.l2-measure` — max-width ch 실험), 드롭캡(`.l2-dropcap::first-letter`), 풀 인용 bleed, 피겨 그라데이션(§7 허용 범위), 본문 17px(§2 표 밖 — 채록).
- [x] **Step 2: 렌더 확인** — 6섹션 존재, 콘솔 에러 0.
- [x] **Step 3: LOG-L2 r0 기록.**

### Task 3: L2 자기비평 루프 + 실측 게이트 + FRICTION

- [x] **Step 1: 루프 r1~r6** (C1 프로토콜: 통상 3샷 light-1440/dark-1440/light-390, r3·최종 6매트릭스; 5축 비평; 조기종료 규칙). 라이브 IO 검증 1회(느린 스크롤 missing 0 — L2는 표제 fade-up뿐이므로 진입 모션 가시성 확인).
- [x] **Step 2: 실측 게이트 6항목** (C1 스크립트 재사용 — URL만 `/l2`): 오버플로우 8조합 0 · jsx 하드코딩 색 0(grep — `.l2-*` 실험 블록은 index.css) · reduced-motion 동등 · CLS<0.02 · **review-strict anti-slop 18/18**(context: design.md+L2.jsx+index.css+tokens.css+config) · 실카피.
- [x] **Step 3: FRICTION 채록 완결** — L2 예상 검증축: G2(fluid 본문 스케일)·G4(grain/질감)·G5(이미지/피겨)·G6(장문 리듬)·F-L1-08 후속(페이퍼)·본문 measure(신규)·드롭캡/인용/각주 관용구(신규). 각 항목 증거(샷·라인) + v2 방향.
- [x] **Step 4: 본 plan의 FRICTION Digest 표에 L2 행 추가.**

### Task 4: L3 브리프 + 스캐폴드

**Files:**
- Create: `_design-lab/briefs/L3.md`, `_design-lab/LOG-L3.md`, `_design-lab/lab/src/pages/L3.jsx`(셸)
- Modify: `_design-lab/lab/src/App.jsx`(라우트+링크)

- [x] **Step 1: 브리프 verbatim 작성** (`_design-lab/briefs/L3.md`):

```markdown
# L3 브리프 — 온도 옵스: 스튜디오 운영 대시보드

## 컨셉 (1줄)
스튜디오 온도의 프로젝트 운영 콘솔 — 절제가 밀도를 이기는 게 아니라 밀도를 "정돈"한다는 것을 증명하는 앱 셸.

## 무드 3키워드
관제실의 고요 / 표의 리듬 / 즉답하는 표면

## Signature move (정확히 1개)
**첫 로드 스태거**: KPI 스탯 4장이 60ms 간격 fade-up으로 정착 (총 <400ms, 1회). 이후 앱은 무모션 — 반복 사용 화면은 색 전환만 (Emil 원리 검증: "매일 100번 보는 것은 움직이지 않는다").

## 색·타입 전략
- §3 셸 무결성 준수: root 1곳만 dvh+overflow-hidden, 내부 min-h-0, 스크롤은 main 영역만.
- 숫자 밀도: KPI·표 숫자 tabular-nums 실험 (v1 침묵 — 채록).
- 상태 전면 실험: hover(행 배경)·focus-visible(키보드 순회 가시)·loading(skeleton)·empty(빈 프로젝트) — 전부 v1 침묵/부족.
- 색: primary 1 + 상태 시맨틱(success/danger) 최소. 잉크 섹션 없음(앱 셸은 균질 표면 + 위계는 border/배경 단차).

## 레이아웃
- 데스크톱: 사이드바(w-60, 내비 6항목) + 메인(헤더: 검색·기간 셀렉트·프로필 / KPI 4 / 프로젝트 표 8행 / 우측 활동 피드 8건).
- 모바일(<768): 사이드바=드로어(햄버거), 활동 피드=세그먼트 탭. §3③ 검증.
- 표 컬럼: 프로젝트/클라이언트/상태 Badge/진행률/마감/담당. 진행률은 얇은 bar(2px, primary).

## 상태 데모 (랩 전용 어포던스)
헤더에 "상태" 셀렉트(정상/로딩/빈) — loading=skeleton 8행(§12 증거), empty=§8 Empty State 스니펫 준수 + 등록 CTA.

## 성공 기준
- 1440에서 "관리자 템플릿"이 아니라 "프로덕트"로 읽힌다 (표의 조판·상태의 정밀도).
- 밀도가 높은데 시끄럽지 않다 — 위계가 border 1px·배경 단차·타이포 3단으로만 성립.
- 키보드 Tab 순회가 눈으로 따라가진다 (focus-visible).
- §3 셸 무결성 + anti-slop 18/18 + 실측 게이트 ALL PASS (앱 셸이므로 §3①~④ 항목이 이번엔 전부 실판정).
```

- [x] **Step 2: LOG-L3.md 헤더 + L3.jsx 셸 + 라우트/링크 + 렌더 스모크.**

### Task 5: L3 라운드 0 구현 (v1-strict)

**Files:**
- Modify: `_design-lab/lab/src/pages/L3.jsx`(전면), `_design-lab/lab/src/index.css`(`.l3-*` 실험 블록)

- [x] **Step 1: 브리프 → JSX.** §3① 골격 verbatim(root dvh+overflow-hidden·min-h-0·main만 overflow-y-auto), §3③ 모바일 접힘(드로어+세그먼트), §4 컴포넌트 base(버튼·인풋·Badge·카드), §8 Empty State. 상태 데모 셀렉트로 normal/loading/empty 전환. 실험 FRICTION 주석: tabular-nums, skeleton 레시피, focus-visible ring, 진행률 bar, KPI 스태거.
- [x] **Step 2: 렌더 확인 + LOG-L3 r0.**

### Task 6: L3 자기비평 루프 + 실측 게이트 + FRICTION

- [x] **Step 1: 루프 r1~r6** (프로토콜 동일 + 앱 셸 특화: 모바일 드로어 열림/닫힘 샷, loading/empty 상태 샷, Tab 순회 focus 샷).
- [x] **Step 2: 실측 게이트** — 기본 6항목 + **§3④ 앱 셸 실측**: 세로 오버플로우(내부 스크롤 영역 외 body 스크롤 0), 390에서 주 콘텐츠 풀폭, 드로어/탭 작동. reduced-motion에서 KPI 스태거 소거·기능 동등.
- [x] **Step 3: FRICTION 채록 완결** — L3 예상 검증축: G1(스태거·무모션 규칙)·G3(elevation)·G7(상태 스펙: skeleton show-delay/min-visible·focus ring 값·hover 보상)·G9(ceiling: 밀도 정돈)·tabular-nums(신규)·Badge 상태색 사용법(신규).
- [x] **Step 4: digest 표에 L3 행 추가 + dev 서버 종료(자기 PID).**

### Task 7: Distill — design.md v2

**Files:**
- Modify: `skills/ui-design/design.md` (additive: §0 하위 Manifesto·§1/§2/§5 수정·§9~§15 신설·§6 문구 정련·§7 상호참조)

**Interfaces:**
- Consumes: FRICTION Digest 전체(L1+L2+L3), 랩 실험 코드(검증된 값만).
- Produces: ≤880줄 design.md v2 — C3 cold-agent fitness의 유일한 입력.

- [x] **Step 1: 신설 섹션 작성** — 각 규칙에 `// evidence: F-…` 인용:
  - **§0 하위 "Craft Manifesto (v2)"**: 검증된 서열(타이포→완급→모션→단일 hue→1px)·signature move 1개 규칙·대비의 드라마 — spec §2 가설 중 랩이 실증한 것만.
  - **§1 수정**: 다크 블록 primary-base/hover/active 3줄 실코드(F-L1-01) + config에 transparent/current(F-L1-02) + scrim 기존 유지. before/after 주석.
  - **§2 추가**: fontSize config 블록(F-L1-03) + 마이크로 라벨 트래킹 예외(F-L1-07) + 본문 measure 규칙(L2 증거).
  - **§5 수정**: coolicons fill 보정 레시피(F-L1-11) — Global Setup 4항목 추가.
  - **§9 Motion System**: duration 티어·표준 곡선(`cubic-bezier(0.22,1,0.36,1)` 등 실측값)·stagger 60~120ms·스크롤 리빌 레시피(IO+.reveal)·reduced-motion 필수 분기 실코드·"반복 UI 무모션" 규칙 (F-L1-04+L3).
  - **§10 Expressive Tier**: fluid display clamp 레시피+스코프(F-L1-06)·잉크 섹션 `.ink` 레시피(F-L1-05)·페이퍼 뉘앙스(F-L1-08+L2)·grain/피겨(§7 연동, L2 증거)·드롭캡/인용/캡션(L2).
  - **§11 Depth & Elevation**: L3 증거 기반 (그림자/border 단차 스케일).
  - **§12 Interaction States**: 부동 컨트롤 자기 표면(F-L1-09)·hover 보상·focus-visible ring 스펙·skeleton(show-delay 150–300ms/min-visible, L3 실측)·empty.
  - **§13 A11y Floor**: reduced-motion 분기 의무·hit target·모바일 input 16px·대비 — 랩 실측 항목만.
  - **§14 Page Rhythm**: 완급 문법(숨/밀도 교차)·와이드 앵커 규칙(F-L1-10)·"빈 사분면 2+=부재".
  - **§15 Craft Ceiling Checklist**: 위계 점프 ≥3단계·signature move 정확히 1·hover 보상·밀도 완급·focus-visible 가시·(장르별 해당 시) 잉크/페이퍼 리듬 — 랩 3장르가 실제 통과한 항목만.
- [x] **Step 2: §6 floor 문구 정련** — 삭제 0, 스코프 명시만 (예: letter-spacing 항목에 "§2 마이크로 라벨 예외 제외"). §7에 §10 상호참조 1줄.
- [x] **Step 3: 줄수 게이트** — `wc -l` ≤880. 초과 시: §9·§10 실코드를 `craft-recipes.md`(aux)로 이관하고 본문엔 규칙+참조만, SKILL.md Phase 1에 장르별 라우팅 추가.
- [x] **Step 4: 검증** — (a) `grep -c "evidence: F-" design.md` ≥ 신설 규칙 수 확인, (b) 기존 토큰명 전수 불변 diff 확인(`--color-*` 키·fontSize 토큰명·§4 클래스), (c) review-strict: "v2 신규 규칙 전부에 FRICTION 인용 존재·§6 18항목 존치·토큰명 불변·§0 정체성 유지" PASS.

### Task 8: Distill — SKILL.md v2 + 커밋

**Files:**
- Modify: `skills/ui-design/SKILL.md`

- [x] **Step 1: 5-Phase 재구성** (frontmatter 3마커 불변·설명만 갱신):
  - `# Phase 1 — Load` (기존+aux 라우팅 조건부), `# Phase 2 — Concept`(브리프 강제: 컨셉 1줄·무드·signature move 1·색타입 전략 — 페이지/컴포넌트 규모별 경량화 규칙), `# Phase 3 — Apply`(§1~§14 적용 순서), `# Phase 4 — Verify`(anti-slop floor + §15 ceiling — review-strict Agent() 호출 유지), `# Phase 5 — Visual QA`(Playwright 실측 — 메인 세션; 게이트 6항목; review-strict는 브라우저 불가 명시).
  - Communication Protocol 갱신(ceiling 결과 필드 추가).
- [x] **Step 2: 게이트 검증** — Write가 enforce-orchestrator 통과(차단 시 골격 미달 — 수정), `bash setup/verify-setup.sh` 70/0 (#6·#7 SKILL.md 마커).
- [x] **Step 3: 커밋** (plan digest 갱신분 포함):
```bash
cd ~/.claude && git add skills/ui-design/design.md skills/ui-design/SKILL.md \
  docs/superpowers/plans/2026-07-13-ui-design-craft-c2-lab-distill.md
git commit -m "feat(ui-design): C2 — design.md v2 (§9–§15) + SKILL.md v2 (5-Phase) — FRICTION 전거 기반

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
(aux 파일 생성 시 add에 포함. opencode 미러·README는 C3 소관 — 이 커밋에 포함 금지.)

→ 이후 start-rpi-cycle Phase Closeout (C-0 PR auto-merge + C-1 drift)로.

## Self-Review (writing-plans)

- Spec coverage: §4.2 L2·L3=T1–T6, §4.3 절차=각 브리프/루프/FRICTION task, §4.4 게이트=T3·T6, §5.1 design.md v2=T7(증거 인용·줄수·§9~§15·§6 정련), §5.2 SKILL.md v2=T8(5-Phase·골격 게이트). §7 cold-agent·§8 하네스 정합=C3 plan 소관(spec Cycles). ✓
- Placeholder: v2 섹션 내용은 "FRICTION이 확정한다"가 설계 원리(무증거 규칙 금지) — task가 구조·검증 기준을 완결 명시. L2/L3 브리프는 verbatim. ✓
- Type consistency: `.l2-*`/`.l3-*` 스코프·라우트명·게이트 스크립트 재사용 URL 일치. ✓
