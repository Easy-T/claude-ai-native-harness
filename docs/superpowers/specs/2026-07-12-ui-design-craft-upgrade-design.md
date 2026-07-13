# UI-Design 「최대 미학」 Craft Upgrade — Design Spec

**Status:** durable (subsystem: `skills/ui-design/`)
**Date:** 2026-07-12
**Goal source:** `~/.claude/_goal/ui-design-maximal-craft-goal.md` (MERGE_POLICY: wait → **auto로 사용자 override**, 2026-07-12 세션 중 지시 "사이클 다 끝나면 머지까지 진행해줘" — 검증 ALL PASS 전제 머지 자동 진행)
**Cycles:** C1(R+Lab L1) → C2(Lab L2·L3+Distill) → C3(Verify+Closeout) — 사이클당 plan 별도

---

## §1. 미션과 판정 기준

**문서가 제품이고, 사이트는 증거다.** 실제 웹사이트 3종(_design-lab_)을 현행 design.md v1만으로 제작해 미학 상한을 실증하고, 그 과정에서 채록한 마찰(FRICTION)만을 근거로 `skills/ui-design/`(design.md+SKILL.md)을 v2로 업그레이드한다. 최종 판정은 사이트의 아름다움이 아니라 **cold-agent fitness**(§7): v2 문서만 받은 새 에이전트가 같은 품질을 ≤2 이터레이션에 재현하는가.

판정 기준의 이원화 (v2의 구조 원리):
- **Anti-slop floor** — 나쁨의 부재. 기존 18항목, 삭제 절대 금지(문구 정련·스코프 명시만 허용).
- **Craft ceiling** — 좋음의 존재. v2가 신설(위계 점프 ≥3단계·signature move 1개·hover 보상·밀도 완급·focus-visible 가시 등). 랩 증거로만 항목화.

## §2. Fable's Craft Manifesto — 후보 가설 (랩이 검증; 그대로 수용 금지)

「최대 미학」의 조작적 정의: **화려함 = 채도·글로우 추가가 아니라 정밀도의 축적.** 절제(§0 Tone)는 뼈대로 유지하고, 그 위에 다음 서열로 아름다움을 얹는다.

**H1. 아름다움의 서열** (투자 우선순위):
① 타이포그래피 — 스케일 대비·리듬·정렬의 긴장. 위계 점프 ≥3단계(예: 12px 라벨 ↔ clamp 96px+ display).
② 여백과 밀도의 완급 — 조밀한 섹션 뒤 숨 쉬는 섹션. 균질 밀도는 슬롭의 신호.
③ 물리 기반 절제 모션 — enter/exit ease-out <300ms, transform/opacity만, 반복 액션(100+회/일) 무모션. CSS-first(`linear()` 스프링 근사 허용).
④ 단일 hue의 깊이 — 잉크·페이퍼 뉘앙스 뉴트럴(순흑·순백 회피, 근흑 ~hsl(220,15%,4%)·warm paper 등), 새 hue 추가 없이 명도축으로 드라마.
⑤ 1px 디테일 — border·focus ring·grain·optical alignment·tabular-nums·curly quotes.

**H2. Signature move** — 페이지당 기억에 남는 순간 정확히 1개(오프닝 타입 안무, 스크롤 전환, 예상 밖 그리드). 나머지 전부는 조용히 그 순간을 떠받든다. 연속 고novelty 모션 금지(완급 배치).

**H3. 대비의 드라마** — 큰 것은 더 크게(fluid display, clamp() 기반, 상한 ≥96px) ↔ 작은 것은 더 작게(11–12px 와이드트래킹 대문자 마이크로 라벨). 중간 크기의 균질 위계가 슬롭을 만든다.

**H4. 절제의 신뢰** (레퍼런스 원리 추출 — 클론 금지):
- Linear/Vercel 계열: 모노크롬 기반+1 accent, 보이지 않는 크래프트(구조가 읽히면 성공), grid 가이드는 subliminal(≤15–20% opacity), hover 이동 ≤8px, bouncy 금지.
- Emil Kowalski 모션 원리: enter/exit=ease-out, on-screen 이동=ease-in-out, <300ms, 인터럽트 가능, `transition: all` 금지, prefers-reduced-motion 필수 분기.
- Vercel Web Interface Guidelines: focus-visible 전수, hit target ≥24px(모바일 44px), 모바일 input ≥16px, skeleton show-delay 150–300ms + min-visible 300–500ms, tabular numbers, `…` 문자.
- 토스: 인터랙션은 스펙으로 전달 가능해야 한다(모션 = 곡선+지속시간+트리거의 명세; "느낌"만으론 재현 불가). 한국어 프로덕트 감각 = 숫자·기호의 시각 균형.

참고 원천: emilkowal.ski/ui/great-animations · vercel.com/design/guidelines · rauno.me/craft/vercel · toss.tech(TDS)·animations.dev. 원리만 추출, 값은 랩에서 실측 후 채택.

## §3. 현행 design.md v1 갭 인벤토리 (가설 — 랩 실증 후에만 규칙화)

| # | 갭 | 유형 |
|---|---|---|
| G1 | 모션 시스템 부재 (duration·easing·stagger·스크롤 트리거·reduced-motion) | 침묵 |
| G2 | expressive 타이포 티어 부재 — display-xl 64px가 상한, fluid type(clamp) 없음 | 부족 |
| G3 | elevation(깊이) 스케일 부재 — 그림자 1레시피뿐 | 부족 |
| G4 | grain·texture 레시피 부재 — §7이 허용만 하고 방법 없음 | 부족 |
| G5 | 이미지 아트 디렉션 부재 (duotone·vignette·비율·배치) | 침묵 |
| G6 | 페이지 리듬 문법 부재 — 금지(중앙정렬 50%↓)만 있고 처방 없음 | 부족 |
| G7 | 인터랙션 상태 스펙 부재 — focus-visible·skeleton·loading·empty 진행 상태 | 침묵 |
| G8 | a11y 플로어 부재 — 대비율·타깃 크기·reduced-motion 미명시 | 침묵 |
| G9 | craft ceiling 부재 — §6이 나쁨의 부재만 검사, 좋음의 존재 미검사 | 부족 |
| G10 | 전역 `letter-spacing -0.02em` 과광역 — 와이드 트래킹 마이크로 라벨 원천 봉쇄 | 과광역 |
| G11 | 잉크 섹션(다크 섹션 인버전) 레시피 부재 — 다크모드≠다크섹션 | 침묵 |
| G12 | Tailwind 버전 침묵 — §1 config는 v3 형식, 2026 기본 설치는 v4(CSS-first) | 틀림/부족 |

**L1 실증 결과 (C1, 2026-07-13)**: G1·G2·G6·G7·G10·G11 확인 + 신규 5건 — F-L1-01(다크 primary-base 재매핑 누락=틀림)·F-L1-02(config transparent/current 소실)·F-L1-03(§2 표 fontSize 미실체화)·F-L1-08(페이퍼 뉘앙스 수단 부재, §7 허용-무방법 G4 동형)·F-L1-11(§5 currentColor 서술 vs react-coolicons fill="black" 실물 불일치=틀림). 전체 FRICTION digest는 C2 plan에 전재 (원본: `_design-lab/FRICTION.md`, gitignored).

## §4. Phase Lab — 실증 설계

### 4.1 스택·구조 (결정)
- 위치 `~/.claude/_design-lab/` — `.gitignore:59 /_*/`로 자동 ignore (검증됨). 산출물은 repo 히스토리에 안 남으므로, FRICTION digest를 C2 plan에 복사해 추적성 확보.
- **단일 Vite 앱 + react-router-dom v6** — 라우트 `/l1` `/l2` `/l3` (+ `/` 인덱스). 공유 인프라 1개, dev 서버 1개, Playwright 루프 1개.
- **Tailwind v3.4 pin** (design.md §1 config 형식 그대로 소비 — 마찰 신호를 미학에 집중). v4 기본설치 불일치는 G12로 채록만.
- tokens.css = design.md §1 verbatim (+다크 블록). 폰트/아이콘 = §2·§5 그대로(react-coolicons).
- 모션은 CSS-first (transitions/keyframes/`linear()` 스프링 근사 + IntersectionObserver). framer-motion 등 모션 라이브러리 도입 금지 — "design.md 침묵 하에 CSS로 어디까지 가능한가"가 실험 대상.

### 4.2 3개 장르
| # | 장르 | 검증 축 | 사이클 |
|---|---|---|---|
| L1 | 브랜드/포트폴리오 랜딩 | 표현 상한: 오프닝 안무·signature move·잉크/페이퍼 명암 리듬 | C1 |
| L2 | 에디토리얼 장문 아티클 | 타이포: fluid scale·본문 리듬·인용/캡션/이미지 | C2 |
| L3 | 프로덕트 앱 셸(대시보드) | 절제+밀도: §3 셸 무결성·데이터 밀도·상태(hover/focus/loading/empty) | C2 |

### 4.3 사이트당 절차
1. **아트 디렉션 브리프** (`_design-lab/briefs/L<n>.md`) — 코드 전 필수. 형식: 컨셉 1줄 / 무드 3키워드 / signature move 정확히 1개 / 색·타입 전략 / 섹션 아웃라인 / 성공 기준. 브리프의 *시도*는 manifesto가 이끌되, 적용 *규칙*은 design.md v1만 (v2 아이디어 선적용 금지 — 마찰이 데이터다).
2. 구현 (현행 design.md만 준수).
3. **스크린샷-자기비평 루프**: Playwright로 1440/768/390 × light/dark 캡처(`_design-lab/shots/L<n>/r<round>/`) → 브리프+manifesto 서열 5축 대비 자기비평(축별 판정+구체 수정 지시) → 수정 → 반복. **상한 6라운드**, 연속 2라운드 비평 항목 0이면 조기 종료, 수확 체감 시 중단·기록.
4. **FRICTION 채록** (`_design-lab/FRICTION.md`): 규칙 단위 항목 `F-L<n>-<seq>` — 유형(침묵/부족/과광역/틀림/충돌) · 증거(스크린샷 파일 경로·코드 파일:라인) · v2 제안 방향. **이 로그가 v2의 유일한 원료.**

### 4.4 실측 게이트 (사이트당 — 전부 PASS해야 랩 완료)
- `document.documentElement.scrollWidth <= clientWidth` (가로 오버플로우 0) — 390·768·1440.
- 다크 스왑 무결 — `data-theme="dark"` 토글만으로 전 화면 정상(변수 재매핑 원칙, 하드코딩 색 잔존 0).
- `prefers-reduced-motion: reduce` 에뮬레이션에서 기능 동등(콘텐츠·내비 전부 접근 가능, 모션만 소거).
- 진입 모션 중 가시적 layout shift 없음 — PerformanceObserver CLS < 0.02 (모션은 transform/opacity만이므로 달성 가능해야 함).
- anti-slop 18/18 (review-strict 판정).
- 콘텐츠는 실물급 한국어 카피 (lorem 금지 — 타이포 리듬은 실제 언어에서만 측정된다).

### 4.5 동시세션 규약 (CONTEXT.md 동시-세션 격리 준수)
dev 서버는 세션별 ephemeral 포트(5300–5999 난수, strictPort=false)로 기동, 이 세션이 시작한 프로세스만 종료. 타 세션 dev 서버/브라우저 kill 금지.

## §5. Phase Distill — v2 문서화 규약 (C2)

### 5.1 design.md v2
- **FRICTION 항목 번호 인용 의무** — 모든 신규 규칙은 `// evidence: F-L1-03` 형태로 최소 1개 인용. 무증거 규칙 금지(Simplicity First). 기존 규칙 수정은 rationale + before/after 명기.
- 신규 후보 섹션(랩이 확정): **§9 Motion System**(duration 토큰·easing 곡선·stagger·스크롤 트리거·reduced-motion 필수 분기) / **§10 Expressive Tier**(fluid type clamp 스케일·마이크로 라벨 트래킹 예외(G10 스코프 수정)·잉크 섹션 레시피(G11)·grain 실전 코드(G4)·이미지 처리(G5)) / **§11 Depth & Elevation** / **§12 Interaction States**(hover·focus-visible·loading/skeleton·empty) / **§13 A11y Floor** / **§14 Page Rhythm**(처방) / **§15 Craft Ceiling Checklist**.
- 기존 §0–§8 앞부분은 additive 수정만: §0 하위에 Craft Manifesto(검증판) 삽입, §2 표에 expressive 티어 참조 추가, §6 floor 문구 정련(스코프 명시), §7에 §10 grain 상호참조. 토큰명·클래스 시그니처 불변(§6 하위호환).
- **컨텍스트 경제: ≤880줄** (현 440의 2배). 초과 시 aux 파일 분리(`craft-motion.md` 등) + SKILL.md Phase 1 장르별 라우팅.

### 5.2 SKILL.md v2
Phase 구조: `1 Load → 2 Concept(브리프 강제) → 3 Apply → 4 Verify(anti-slop floor + craft ceiling) → 5 Visual QA(Playwright 실측 — 메인 세션 수행; review-strict는 브라우저 불가)`.
**enforce-orchestrator 제약 (hooks/lib/skeleton-scan.js)**: `# Phase ` h1 헤더 ≥3 · `Agent(subagent_type=` ≥1 · `Communication Protocol` 존재 유지 필수 — 위반 시 Write 자체가 차단됨. frontmatter의 `orchestrator_skill: true`·`generated_by:`·`orchestrator_version:` 3마커 유지(verify-setup #7). frontmatter에 `http(s)://` URL 금지(opencode skill-discovery 오라클).

## §6. 하위호환 & 불변 제약

1. 기존 토큰명(`--color-*`, neutral 스케일, 타이포 토큰명)·컴포넌트 클래스 시그니처 유지 — 소비 프로젝트(NICE Second Brain 등) 존재. breaking 필요 시 마이그레이션 노트 필수(기본은 회피).
2. Anti-Slop 18항목 삭제 금지. 새 표현 규칙과 충돌 시: 금지 존치 + 랩 증거 기반 **스코프 예외**만 추가 (예: G10 — 전역 -0.02em 존치 + "11–12px 대문자 마이크로 라벨은 +0.06~0.12em" 예외).
3. §0 Tone Manifesto 정체성(여백·절제·위계·예측 가능성) 유지 — wholesale 재작성 금지.
4. 파일명·경로 불변: `skills/ui-design/design.md`·`SKILL.md` (CLAUDE.md:54 경로 하드코딩·SKILL.md `Read("./design.md")`·run-all 테스트 91이 의존).
5. RPIC: 이 spec이 durable SSOT, 사이클당 plan. 코드 쓰기는 active plan 필수(enforce-rpi-cycle).

## §7. Phase Verify — 적대적 수용 검증 (C3)

**Cold-agent fitness (핵심 수용 기준)**:
- 새 subagent에 design.md v2**만** 제공(SKILL.md·FRICTION·랩 코드 미제공), 제4 장르 1페이지 지시: **프라이싱 페이지** (표·비교 밀도 + 마케팅 표현의 이중 성격이 floor/ceiling 동시 검증).
- 판정: ≤2 이터레이션 내 anti-slop 18/18 + craft ceiling 전항 PASS (review-strict 채점 + 메인 세션 Playwright 실측 게이트 §4.4 동일 적용).
- FAIL 지점은 사이트가 아니라 **문서의 결함**으로 회귀 수정 (규칙 모호→명세화, 누락→추가) 후 재시도. 재시도 이력 기록.
- 교차패밀리 적대 리뷰 1회 (가능 시 ccs gpt 프로필, refute-by-default) — 자기채점 편향 중화. 불가 시 사유 기록.

## §8. 하네스 정합 체크리스트 (C3 — explore 실측 기반)

| 접점 | 내용 |
|---|---|
| README.md :56 | skill 테이블 ui-design Phase 표기 → v2 Phase 구조로 갱신 |
| README.md :299-301 | 디렉터리 트리 — aux 파일 추가 시 갱신 |
| opencode 미러 | `opencode-harness/skill/ui-design/design.md` = **byte-sync**(verbatim 사본). `SKILL.md` = **구조-sync + 의도적 분기 보존**(오프라인 CDN 노트·task-도구 디스패치) — 맹목 byte-copy는 opencode 포트를 파괴한다 (goal의 "byte-sync"를 증거로 정련: design.md만 byte, SKILL.md는 분기 보존) |
| verify-setup #6/#7/#29 | SKILL.md 존재·orchestrator 3마커·install.sh 경로 — v2에서 자동 유지 확인 |
| `bash setup/verify-setup.sh` | 66/0 (전 항목) |
| `bash hooks/tests/run-all.sh` + `bash setup/verify-all.sh` | ALL PASS |
| 차기 개선 후보 기록 | design.md 콘텐츠 seal 신설 검토 (현재 design.md는 어떤 seal도 없음 — #22는 start-rpi-cycle 전용) |

ADR: 이 repo는 `docs/ai-context/architecture.md` 부재 — durable 설계 기록은 specs/가 SSOT (기존 18개 spec 선례). 본 spec이 그 기록이며 별도 ADR 파일 없음.

## §9. 산출물 총목록

durable spec 1(본 문서) · 사이클별 plan 3 · `_design-lab/` 3사이트+shots+FRICTION.md(gitignored; digest는 C2 plan에) · design.md v2 + SKILL.md v2 (+aux 조건부) · opencode 미러 sync · Craft Manifesto 검증판(design.md §0 하위) · cold-agent fitness 결과(C3 plan closeout) · 차기 개선 후보 목록 · 프로젝트 메모리 갱신.

## §10. 결정 기록 (grill 요약 — 자체판단 항목)

| 결정 | 근거 |
|---|---|
| 랩=단일 Vite 앱+라우터 3 | 인프라 중복 제거, 루프 속도. 장르 격리는 라우트 트리로 충분 |
| Tailwind v3 pin | design.md v1 verbatim 소비가 실험 전제. v4 불일치는 G12 채록 |
| 모션 CSS-first, 라이브러리 금지 | 침묵 갭(G1)의 상한을 순정 CSS로 측정해야 v2 레시피가 의존성 없이 이식 가능 |
| cold-agent 장르=프라이싱 | 표 밀도+마케팅 표현 이중성이 floor·ceiling 동시 자극 |
| FRICTION digest를 C2 plan에 복사 | gitignored 증거의 추적성 보완 |
| SKILL.md 미러는 byte-sync 아님 | explore 실측: 미러가 이미 의도적 분기 보유. goal 문구를 증거로 정련 |
| 브리프 시도=manifesto, 규칙=v1 | "마찰이 데이터" 원칙과 표현 상한 실증의 양립 조건 |
| ADR 파일 없음 | repo에 architecture.md 부재, specs/가 설계 기록 SSOT (선례 18) |
| Playwright=세션 MCP 도구 | 랩에 playwright npm 미설치 — 실측(resize·screenshot·evaluate·reduced-motion 에뮬)은 메인 세션 플러그인 도구로. review-strict는 브라우저 불가(§5.2 Visual QA 배치 근거) |
| 랩 쓰기는 active plan 하에서만 | `_design-lab/`은 gitignored여도 git 작업트리 내부 — enforce-rpi-cycle 게이트 대상. Phase I 전 plan 필수 (grill 실측) |
| C3 = cycle-50 | 47+3 = 50 → C3 closeout next-cycle-goal에 improve-codebase-architecture 항목 필수 포함 (%5 규약 선인지) |

## §11. v3 Delta — 콘텐츠 봉인 + 정련 (2026-07-14, 재진입 사이클)

v2(§1–§10)는 durable SSOT로 불변. 이 델타는 §8이 "차기 개선 후보"로 flagged한 **design.md 콘텐츠 seal 신설**을 해소하고, cold-agent fitness(§7·FITNESS-L4)가 남긴 2개 내적 긴장을 정련한다. goal: `~/.claude/_goal/ui-design-v3-seal-refine-goal.md` (MERGE_POLICY: **wait** — v2의 auto override 미이월). 단일 사이클.

**신규 불변식 (봉인)** — design.md 콘텐츠가 이제 verify-setup drift seal로 보호된다 (v2까지는 #6/#7이 SKILL.md 존재·마커만 검사, design.md *내용*은 무검사였음):
- **verify-setup #38** — opencode 미러 byte-sync: `opencode-harness/skill/ui-design/design.md` ≡ `skills/ui-design/design.md` (`cmp -s` 동일). 미러 부재 시 vacuous-PASS(설치본·fresh-clone 카운트 결정성 보존), 존재+상이 시 FAIL. §8 "미러 byte-sync" 원칙을 이제 강제 — 향후 design.md 편집은 **양 미러 동시 갱신** 필수(편도 편집은 #38로 차단). #23 two-file parity 선례 계열.
- **verify-setup #39** — §6 anti-slop floor 카운트: §6 스코프(`# 6.`~`# 7.`) `- [ ]` 체크박스 == **18** (§6.2 "삭제 절대 금지" 강제). 향후 floor 가감은 seal 동반 갱신 = 의도적 governance 이벤트(tripwire).
- seal-regression.test.sh: 각 seal에 대표 변이 케이스(미러 편도 변경→#38 RED · §6 체크박스 삭제→#39 RED). #38 TDD 위해 `make_replica`가 미러 파일도 복제하도록 확장(additive; 기존 3케이스·control·witness 무영향).
- README:284 count 74→76, verify-setup self-count(#36) 동기. **병합 정합(2026-07-14)**: 동시 harness-upgrade C4가 #37(scaffold-registry parity)을 선점 → 본 seal은 **#38(미러)·#39(floor)**로 배정, origin/master 병합으로 정합(seal 라벨은 위치 아닌 식별자 — needle 기반 seal-regression 무영향; verify-setup 73→74→76).

**정련 (무증거 금지 준수 — FITNESS-L4 비채점 관찰 → FRICTION 승격)**:
- **F-FIT-02 (충돌)** — §9 "총 안무 <700ms"가 700ms line-rise 표준 레시피와 내적 모순(개별 지속 vs 시퀀스 spread 미분리). 정련: **2축 분리** — 개별 요소 지속 ≤700ms(motion-hero) + 마지막 요소 시작 지연 ≤300ms → 체감 총 ≤~1000ms. design.md §9 stagger 규칙 대체.
- **F-FIT-03 (과광역)** — §12 hover "목록 행" 스코프가 인터랙티브/비인터랙티브 미분리(읽기전용 표/정보 행에 화살표 슬라이드 = 거짓 어포던스). 정련: **인터랙티브 행**(배경+보조 신호) vs **비인터랙티브 행**(배경 1단차만·방향 신호 금지) 분기. design.md §12 Hover 절 대체.

**회귀 게이트**: 정련 후 design.md v3**만** 받은 새 cold agent가 **제5 장르(설정 화면 — L4 프라이싱과 다른 것)**를 ≤2 iter에 floor 18/18 + craft ceiling PASS 재현. 정련이 재현성을 깨지 않았음 실증(§7 fitness 회귀). 설정 화면은 정련한 §12(인터랙티브 설정 행 ↔ 읽기전용 정보 행)를 직접 자극하도록 선택.

**불변**: §1–§10 구조·토큰·§6 floor 18·§15 ceiling 9 불변. seal은 additive(기존 verify-setup 항목·소비 프로젝트 클래스 비접촉). 교차패밀리 리뷰는 §7 "가능 시" 유지(best-effort, 인프라 의존 — 메모리 codex 취약성 경고).
