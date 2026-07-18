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
- **verify-setup #43** — opencode 미러 byte-sync: `opencode-harness/skill/ui-design/design.md` ≡ `skills/ui-design/design.md` (`cmp -s` 동일). 미러 부재 시 vacuous-PASS(설치본·fresh-clone 카운트 결정성 보존), 존재+상이 시 FAIL. §8 "미러 byte-sync" 원칙을 이제 강제 — 향후 design.md 편집은 **양 미러 동시 갱신** 필수(편도 편집은 #43로 차단). #23 two-file parity 선례 계열.
- **verify-setup #44** — §6 anti-slop floor 카운트: §6 스코프(`# 6.`~`# 7.`) `- [ ]` 체크박스 == **18** (§6.2 "삭제 절대 금지" 강제). 향후 floor 가감은 seal 동반 갱신 = 의도적 governance 이벤트(tripwire).
- seal-regression.test.sh: 각 seal에 대표 변이 케이스(미러 편도 변경→#43 RED · §6 체크박스 삭제→#44 RED). #43 TDD 위해 `make_replica`가 미러 파일도 복제하도록 확장(additive; 기존 케이스·control·witness 무영향).
- README:284 count 79→81, verify-setup self-count(#36) 동기. **병합 정합(2026-07-14)**: 동시 harness-upgrade **C4(#37)·C5(#38)·C6(#39)·C7(#40)·C8(#41·#42)가 연속 선점** → 본 seal은 최종 **#43(미러)·#44(floor)**로 배정(3회 재번호: #37/#38→#38/#39→#39/#40→#43/#44), origin/master **3회 병합**으로 정합(seal 라벨은 위치 아닌 식별자 — needle 기반 seal-regression 무영향; verify-setup 73→…→81). **★교훈: seal 번호는 분기 시점 아닌 클로즈아웃 직전 origin/master로 재확인**(동시 이니셔티브가 사이클 중 master를 C4~C8 5사이클 대량 전진시킴 — 회복력 인코딩이 차기 후보).

**정련 (무증거 금지 준수 — FITNESS-L4 비채점 관찰 → FRICTION 승격)**:
- **F-FIT-02 (충돌)** — §9 "총 안무 <700ms"가 700ms line-rise 표준 레시피와 내적 모순(개별 지속 vs 시퀀스 spread 미분리). 정련: **2축 분리** — 개별 요소 지속 ≤700ms(motion-hero) + 마지막 요소 시작 지연 ≤300ms → 체감 총 ≤~1000ms. design.md §9 stagger 규칙 대체.
- **F-FIT-03 (과광역)** — §12 hover "목록 행" 스코프가 인터랙티브/비인터랙티브 미분리(읽기전용 표/정보 행에 화살표 슬라이드 = 거짓 어포던스). 정련: **인터랙티브 행**(배경+보조 신호) vs **비인터랙티브 행**(배경 1단차만·방향 신호 금지) 분기. design.md §12 Hover 절 대체.

**회귀 게이트**: 정련 후 design.md v3**만** 받은 새 cold agent가 **제5 장르(설정 화면 — L4 프라이싱과 다른 것)**를 ≤2 iter에 floor 18/18 + craft ceiling PASS 재현. 정련이 재현성을 깨지 않았음 실증(§7 fitness 회귀). 설정 화면은 정련한 §12(인터랙티브 설정 행 ↔ 읽기전용 정보 행)를 직접 자극하도록 선택.

**불변**: §1–§10 구조·토큰·§6 floor 18·§15 ceiling 9 불변. seal은 additive(기존 verify-setup 항목·소비 프로젝트 클래스 비접촉). 교차패밀리 리뷰는 §7 "가능 시" 유지(best-effort, 인프라 의존 — 메모리 codex 취약성 경고).

## §12. Fable 재감사 Delta — Opus-구간 적대 재감사 (2026-07-17, 재진입 사이클)

goal: `~/.claude/_goal/ui-design-v3-fable-reaudit-goal.md` (MERGE_POLICY: **wait**). 대상 = Opus 수행 구간 커밋 2개(`d372b2c` v2 C3·`9acf649` v3) + v3 goal 스코프 적정성. 방법 = 3축(A 계획 충족·B 품질 실측 재채점·C 엔지니어링) refute-by-default, 재작업은 구체 결함 증거 필수("Opus라 미숙" 가정 금지). Gate R = 독립 explore-strict 커밋 스윕 + 메인 실측 + review-strict 적대 검증 2패스(1차 FAIL→정정 2건 재제출→PASS).

### 감사 결과 총괄
**품질(B축) 재채점 — Opus 채점 관대함 없음.** L4(프라이싱)·L5(설정)를 Playwright로 재실측: 오버플로우 0(1440/768/390×light/dark, root+내부 컨테이너), CLS 0(fresh load, L4 1440/390·L5 1440/390), reduced-motion stuck 0·기능 동등, focus-visible 2px solid 전수, 다크 스왑 무결(하드코딩 색 누출 0 — 유일 후보 fixed 토글은 토큰 재매핑 정상). L5 §12 3-way 재현 실증(navChevrons=4·infoChevrons=0·infoRows=4)·§9 2축(개별 550ms ≤700·마지막 지연 280ms ≤300). FITNESS-L4 iter2·FITNESS-L5 iter1 기록과 일치. seal-regression 9/0·verify-setup 81/0·run-all 172/172·opencode 오라클 21/0 — Opus 산출 세트 현행 그대로 ALL PASS.

**계획 충족(A축)** — v2 Phase4~5·v3 goal §0~§5 전 항목 이행 확인. L4 fitness 프로토콜(iter1 FAIL→F-FIT-01 §3①-b 회귀) 정당(FITNESS-L4 역추적+relative 부여 0 실증). 교차패밀리 SKIP 사유 3건 타당 — 오늘 재프로브로 재확인(Agent model=Claude 티어만 실물 일치·`ccs kimi` 인증 필요 상태·glm 프로필 부재; 이 Fable 재감사 자체가 교차-모델 적대 검증을 소급 제공). v2 차기 후보 4건 전부 처리(seal/§9/§12=v3, cycle%5 improve-arch=harness C4·C5가 improve-arch 확장 실수행으로 소비 — 24b7c93·c08fe82).

### 발견 및 판정 (심각도·증거·처분)
**REWORK (이번 사이클 수행, plan: `docs/superpowers/plans/2026-07-17-ui-design-fable-reaudit-rework.md`)**
- **R1 [MED] §0-3 "<400ms" 모션 상한 모순 잔존** — design.md:12 vs §9 토큰(base 300–450·hero 550–700)·레시피(fade-up 550·line-rise 700). F-FIT-02 동형(서머리-vs-스펙 수치 drift)이 §0에 잔존; v3는 §9 내부만 정합. L4/L5 실물 550·700ms가 게이트 전부 PASS — "<400ms"가 사문. 수정: (a) §0-3을 순수 티어-위임 문구로(수치 0개, drift 원천 제거) (b) §9 motion-base 300–450→**300–550** — 같은 §9의 fade-up/.reveal 레시피 550ms가 표의 자기 티어(용도란 "fade-up 리빌")를 초과하는 긴장 동시 해소. 방향=레시피-우선(레시피는 F-L1-04/F-L3-04 evidence+cold-agent 2회 실측 재현, 표 범위는 독립 evidence 없음 — 무증거 쪽을 유증거 쪽에 정렬). 보강: 양 SKILL.md가 이미 "motion-base 550ms"를 예시로 명기(정본:101·미러:106) — v2 저작 의도의 방증, (b)로 정합. `// evidence: F-AUD-01`.
- **R2 [LOW] §9 v3 정련 문구 산술 코너** — :535 "60–120ms 간격"×"~5개"는 상한에서 마지막 지연 480ms>같은 문장 "≤300ms"(5요소는 ≤75ms에서만 성립; L5 실증 70ms). 수정: 개수↑시 간격 하향 1구. `// evidence: F-AUD-02`.
- **R3 [LOW] §8 Mobile List Item ↔ §12 분기 모순 유도** — :462-471 스니펫 chevron 포함·인터랙티브 전제 미표기 → 읽기전용 목록 복붙 시 §12 위반. 수정: 전제 주석 1줄.
- **R4 [MED] seal-regression witness 갭(v3 귀책)** — :9-10 "every file any mutator could touch" 주장 vs :18 witness에 미러 design.md 부재(mut_mirror_drift 유일 접촉 파일). 수정: witness에 미러 추가(TDD). C8 귀책분(explore-strict.md·settings.example.json 부재)은 범위 외 → next-cycle 이월.
- **R5 [TRIV] 미러 SKILL.md 무신고 단어 드리프트** — 정본:66 "PASS/N-A 판정" vs 미러:68 "PASS/N-A"(의도 분기 목록 외 소실; SKILL.md는 seal 미보호). 수정: "판정" 복원.
- **R6 [기록] L5 fitness 격리 약점** — L5.jsx가 `.reveal` CSS를 자체 `<style>` 없이 랩 공유 index.css(L1-era)에서 상속 — L4 프로토콜("index.css 접근권 없음")보다 약한 격리. §9 재현 평가 중 "개별 550ms" 몫은 상속, 에이전트 기여는 inline delay 축. 결론(정련이 재현성 유지) 유효하나 증거 사슬을 FITNESS-L5에 명시. L6 프롬프트에 자족 노트 재사용.
- **R7 fitness L6 회귀** — R1-R3이 design.md를 수정하므로 goal §0.4에 따라 제6 장르(온보딩/가입 폼) cold-agent ≤2 iter 필수(R6 교훈 반영 프롬프트).

**ACCEPT (기록만 — 재작업 없음)**
- A1 [LOW] `9acf649` 커밋 제목 "#39/#40"·본문 "#37/#38" vs 실물 #43/#44 — 3회 재번호 중 제목 동결. 머지된 히스토리(수정 불가)·durable SSOT(spec §11)는 정확.
- A2 [LOW] 미러 SKILL.md 분기 집계 "2건" 부정확 — 실물 제3 분기 존재(미러:98 Playwright 부재 시 SKIP 정직 공개 + :109 "또는 SKIP 사유" 파생). 콘텐츠는 정당(정직 공개 원칙) — 열거만 누락. **정정 기록: 의도 분기 = 3건**(오프라인 CDN 노트·task-도구 디스패치·Playwright-부재 SKIP 공개).
- A3 [TRIV] v3 plan 헤더 "RPI-Cycle: 54" vs 실착륙 57 — 같은 파일 병합 정합 노트가 57 명시(노트가 정정 담당). 완료 plan 재수정은 churn.
- A4 [기록] seal-regression :4-5 "run-all stays 129 / verify-setup 65" 화석 주석(cycle-31 값, 현행 172/81) — 감사 대상 커밋 귀책 아님(선행 존재). next-cycle 후보.
- A5 v3 goal 스코프 적정성 — seal 2종+정련 2건+fitness 회귀+SKIP 기록으로 goal §0~§5 충족, 스코프 과부족 없음.

### 판정의 한계 (정직 공개)
독립 스윕 explore-strict는 Bash 부재로 d372b2c diff 본문 미열람(9acf649=HEAD 워킹트리로 대체) — 그 몫은 메인 세션이 `git show d372b2c` 전수로 보완. B축 재채점의 ceiling 9항목은 코드 채점이 아닌 실측+스크린샷 시각 확인으로 재검증(별도 review-strict 재채점 생략 — FITNESS 기록과 실측 일치가 근거).

### 실행 결과 (2026-07-17~18, 재작업 사이클 완료 — §12)
R1-R5 수행: `2a167eb`(R1-R3 §0/§9/§8 정련 F-AUD-01/02 + R5 미러 SKILL.md 복원 + byte-sync) · witness 커밋(R4 seal-regression 미러 추가, RED grep-부재→GREEN 9/0). **R7 fitness L6(온보딩/가입, 제6 장르) iter1 ALL PASS** — floor 16P/2N-A/0F·ceiling 9/9·오버플로우 6조합 0·CLS 0·reduced-motion 동등·focus-visible 전수(sr-only 체크박스 위임 링 포함)·**R2 재현(마지막 지연 260ms≤300 지배 축 준수)·R1(b) 정합(550=motion-base 티어 내)·R6 자족 격리 달성(l6-* 14종 파일 내 <style>, index.css 상속 0)**. L4(iter2)→L5(iter1, 격리 약점)→L6(iter1, 자족 격리) 단조 상승. 최종 검증: verify-setup 81/0·seal-regression 9/0·run-all 172/172·verify-integration 8/0·doctor+doctor.test+failopen 5/0+rpi-prereq 3/0+worktree-teardown 25/0·opencode 오라클 21/0 (verify-all 단일 실행은 10분 타임아웃 — 구성 스테이지 개별 실행 전부 PASS로 대체, v3 선례). evidence 26→29.

## §13. v5 Delta — 교차패밀리 발견 정정 + 테스트 위생 (2026-07-18, 재진입 사이클)

goal: `~/.claude/_goal/ui-design-v5-crossfix-goal.md` (MERGE_POLICY: **wait**). 단일 사이클. 동시 세션 규약: 다른 글로벌 세션이 교차 리뷰 capability 등재(별도 goal)를 병행 중 — 이 사이클은 design.md v5 + 랩 + seal-regression 위생만 접촉, 클로즈아웃 직전 origin/master 재확인(v3·v4 연속 실현 교훈).

**원천 — 첫 교차패밀리 적대 리뷰 (spec §7 "가능 시"의 첫 성공 실행, 2026-07-18)**: `cat design.md | claude --model gpt-5.6-sol -p "<refute-by-default 프롬프트>"` (stdin 파이프=E2BIG 회피·CLIProxy 핀 7.2.62-5에서 v2의 400 비호환 소멸·판별=modelUsage 키). GPT-5.6 Sol이 design.md v4에서 **Claude 검증 패스 4회(v2 Distill·v3 Gate R/P·v4 Fable 재감사)가 전부 놓친 진짜 결함 10건** 적발 + 오독 4건(메인 Fable 트리아지로 기각 — §1 `#176BFF` 자인 legacy·§9↔§12 transition-colors 스코프 오독·결정론 부족 5건은 fitness 3회가 경험적 반증·-0.02em/lg 경계 현학). 상세 판정표: `_design-lab/CROSS-REVIEW-GPT56-SOL-2026-07-18.md`(gitignored) — 이 §13이 리포 영구 앵커. **교차 리뷰 가치 실증**: 동일-패밀리 반복 검증의 사각(자기 어휘로 쓴 규칙은 자기 눈에 정합해 보임)을 타 패밀리 1회가 뚫음; 발견 중 2건(X7·X8)은 v4 Fable 자신의 수정분 문구 결함.

**정정 명세 (X1~X10 — FRICTION `## XR` F-XR-01~10로 채록 후 `// evidence:` 인용)**:
- **X1 [MED] §0 GS-3 ↔ §5 Coolicons 충돌**: GS-3 "Coolicons CSS import (§5의 CDN URL)"이 §5 P6 정정("CDN 미제공·@import 미작동·아이콘 미렌더")과 정면 모순(v1-era stale) → GS-3을 §5 실물 방식으로 교체(React=react-coolicons npm / 비-React=자가호스팅) + §5가 "Global Setup 4번째 항목으로 취급"이라 자기 선언한 currentColor 보정 CSS를 **GS-4로 실체화**(F-L1-11 연동).
- **X2 [MED] 폰트 family명 오기**: §0 GS-2·§2 소개문 "Pretendard Variable" ↔ §2 CDN(static dynamic-subset)이 선언하는 실물 family `'Pretendard'`(§2 body CSS·랩 config 실물 동일 — 'Pretendard Variable' family는 미선언이라 silent 폴백) → 표기 정합. variable CDN 전환은 스코프 밖(소비 프로젝트 실물 기준).
- **X3 [LOW] scrim 토큰 미실체화 + 예제 자기위반**: §1 scrim 규칙("`--color-scrim` 분리→`bg-scrim/40`")이 서술만 존재(:root/다크/config 미등록) + §4 Modal 예제가 금지 패턴 `bg-neutral-900/40` 사용 → 토큰 3곳 실체화(라이트 `hsl(220,10%,10%)`·다크 `hsl(220,14%,4%)`·config `scrim` 키) + 예제 `bg-scrim/40`. F-L1-01 "주석→실코드" 선례 — additive.
- **X4 [LOW] §4 Button Pair 규칙 ↔ Modal 예제 불일치**: "(Modal·Form footer) 동일 너비" 규칙인데 Modal 푸터가 `justify-end` 비대칭 → flex-1 페어로 정합.
- **X5 [LOW] §4 Input 14px ↔ §13 모바일 ≥16px**: `text-body-md` 인풋이 iOS 자동 줌 유발 → `text-body-lg md:text-body-md` + §13 상호참조(§4 Input·§8 Form View 동형 2곳).
- **X6 [LOW] 버튼 41px ↔ §13 44px 타깃**: py-2.5 실높이 41px — "모바일 주 액션은 py-3(§13 hit target)" 스코프 주석(기본 클래스 불변·하위호환).
- **X7 [TRIV] §9 산식 오독 유발**: v4-R2 "120ms×5요소=480ms"(480=간격4×120이지 5×120 아님) → "마지막 지연=간격×(N−1)" 산식 명시 재서술.
- **X8 [TRIV] §9 60ms 하한 ↔ ≤300ms 지배 축 충돌(7+요소)**: 6간격×60=360>300 → "≤300ms 축이 60ms 하한보다 우선(요소 많으면 60ms 미만 허용)" 1구.
- **X9 [TRIV] §2 measure 근거문 ch 오독**: "66ch"를 자수로 서술(ch='0' 글리프 폭) → 근거만 재서술("라틴 조판 관용 60–70자/행…"), 결론 32–38em은 랩 실증 불변.
- **X10 [TRIV] §8 Mobile List Item 시맨틱**: v4-R3 주석("인터랙티브 행 전제")과 달리 마크업이 plain `<li>` → 행 콘텐츠를 button으로 감싼 시맨틱 정합(클래스명 불변·§12 focus-visible 연동).

**테스트 위생 (이월분)**:
- **H1**: seal-regression.test.sh :4-5 화석 주석("run-all stays 129·verify-setup stays 65"=cycle-31 값) → 카운트 숫자 제거+SSOT 위임 서술(수치 재기술 금지 계급 — v4 R1(a) 동일 해법: 숫자가 없으면 화석화 불가).
- **H2**: witness 목록에 `agents/explore-strict.md`·`settings.example.json` 추가(mut_explore_write·mut_strip_deny 접촉인데 부재 — C8 귀책 잔여; v4 R4는 미러만 처리) → ":9-10 'every file' 주장 완결". RED(부재 grep)→GREEN(seal-regression 전수+live witness stable).

**회귀 게이트**: fitness **L7 = 알림 인박스 화면(모바일 우선) + 항목 삭제 확인 모달** — X3(scrim 모달)·X4(모달 버튼 페어)·X5(인풋)·X10(행 시맨틱)·§12 3-way를 직접 자극하는 제7 장르. cold agent ≤2 iter·자족 격리(L6 프로토콜)·디자인 힌트 0.

**불변**: §6 floor 18·§15 ceiling 9·기존 토큰명·§4 클래스명 불변(X3 scrim은 §1 기존 규정의 실체화=additive·X10은 클래스 비접촉). 기각 4건 재소송 금지.

### 실행 결과 (2026-07-18, v5 사이클 완료 — §13)
X1~X10 정정 + H1/H2 위생 수행. **fitness L7(알림 인박스+삭제 모달, 제7 장르·모바일 우선) iter1 ALL PASS** — 오버플로우 6조합 0(truncate 11건은 의도적 클리핑 제외)·CLS 0·reduced-motion 동등·focus-visible 전수·**X3 재현(모달 scrim=토큰 rgb(23,25,28)·opacity 0.4)·X4 재현(취소/삭제 143px==143px flex-1)·X10 재현(9행 전부 button, plain li 0)·§9 산식 재현(90×2=180≤300)**·자족 격리(index.css 상속 0)·모달 aria-modal+포커스 트랩+Escape. **부수익 — fitness가 F-XR-11 신규 적발**: X3가 도입한 `bg-scrim/40`이 §1 var()-config에서 알파 수정자 조용한 컴파일 탈락(cold agent+채점자 双프로브 확정) → §1/§4를 별도 백드롭 레이어(`bg-scrim opacity-40`)로 즉시 회귀(cold agent의 통과 경로 성문화, evidence 40). "FAIL은 문서 결함으로 회귀"의 5번째 실증. 최종 검증: verify-setup 81/0·seal-regression 9/0(H2 witness 9파일)·run-all 178/178·opencode 오라클 21/0. 차기 관찰 2건(비채점): 모달 등장 duration 티어 미명명·모달 닫힘 후 포커스 복귀 규정 부재(FITNESS-L7).
