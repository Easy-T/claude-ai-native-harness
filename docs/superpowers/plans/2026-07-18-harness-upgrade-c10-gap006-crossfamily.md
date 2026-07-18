# Harness Upgrade C10 — GAP-006 교차패밀리 검증자 분리 착륙 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Status:** active
**RPI-Cycle:** 60
**Started:** 2026-07-18

**Best-Direction Check:** 최선안 = **탐지(capability probe) 기반 2경로 규약**(A codex CLI 직접 호출 우선·B CCS 라우팅 폴백·둘 다 불가 시 SKIP+사유) + 고-스테이크 지점 한정·사이클당 1회·메인 세션 트리아지. 채택안 = 동일. **대안 비교(spec §10-2 — goal §2 판정 봉인)**: ①"codex-plugin-cc 플러그인 도입" 기각 — 컨텍스트 공유=fresh-context 독립성 오염(교차 검증의 존재 이유 훼손), 자율 발동=사이클당 1회 상한 우회+쓰기 전제(Rule-of-Two 충돌), 표면 3배(C7 공급망 핀 대상 확장), 스레드 기능은 raw CLI 동등(`codex exec resume --last` 실측) ②"교차 검증 필수 게이트화" 기각 — GPT 경로 없는 PC에서 하네스 정지(이식성 위반; advisory fail-open 교리) ③"오케스트레이터 동적 모델 선택" 기각 — 가장 신뢰하지 않는 계층(모델 판단)에 재량 부여+검증자 self-pass 우회로(2026-07-18 사용자 대화 확정). **DOWNGRADE-DECLARED: 없음.** 스코프 제외 선언(열화 아닌 분할): runbook 토큰 seal(#45+)=GAP-019 편승 · 본 리뷰 실전 실행=차기 사이클(quota 규율 — 이 사이클은 규약 등재+probe 스모크만). opencode 미러: closeout/start-rpi SKILL.md 미러 실재 → 대응 부분 동기(05 §5-4).

**Goal:** GAP-006 DONE — 교차패밀리 적대 리뷰를 "불가"에서 "탐지→가능하면 실행"으로 전환하는 규약을 durable 등재. success: (1) `docs/ai-context/cross-family-review.md` 실재(탐지 A/B·프로토콜·plugin-cc 기각·모델 정책 4블록) (2) closeout-pr-cycle Phase 4 분기+start-rpi-cycle 앵커 grep(+미러 동기) (3) spec §5·05 §5-6·README 방법론 앵커 교체 (4) 04 GAP-006 DONE·03 D2/D10 무bump 노트 (5) probe A·B 실측 로그(이 머신 둘 다 가용) (6) verify-setup 81/0·run-all 178·verify-all ALL PASS(전부 불변 — 문서+SKILL 텍스트만).

**Tech Stack:** docs/ai-context/·skills/closeout-pr-cycle·skills/start-rpi-cycle(+opencode 미러)·docs/harness-upgrade-2026-07/{03,04,README}·spec §10(작성됨).

## Global Constraints
- **착수 실측(2026-07-18)**: verify-setup **81**/0 · run-all **178** · live state **59** → RPI-Cycle **60**(클로즈아웃 시 라이브 재확인 조정) · seal 최고 #44(신규 seal 없음). 브랜치 `harness-upgrade-c10`(origin/master `11bd0a0` 기점).
- 신규 seal/hook/케이스 **없음** — 카운트 전 불변이 GREEN 조건. SKILL.md 편집=orchestrator 골격 유지.
- **설치·로그인·인증 시도 절대 금지**(probe는 read-only 확인만). probe 스모크 = "Reply: OK" 최소 프롬프트 각 1회(quota).
- **MERGE_POLICY: wait(이 사이클 한정)** — PR 후 merge 승인 요청·대기.

---

### Task 1: runbook `docs/ai-context/cross-family-review.md` 신설
**Files:** Create: `docs/ai-context/cross-family-review.md` / Modify: `docs/ai-context/scaffold-registry.md`(거버넌스 문서 표에 1행)

- [ ] **Step 1: runbook 작성** — 4블록: ①탐지(A: `command -v codex`+`codex login status`+스모크 → B: `claude --model gpt-5.6-sol -p "Reply: OK" --output-format json`의 `modelUsage`에 `gpt-*`[모델명 머신별 상이 주의·자가보고 불인정] → SKIP+사유 1줄; **설치/로그인 금지** 명문) ②실행 프로토콜(stdin 파이프 필수[E2BIG]·A는 `--sandbox read-only`+`--skip-git-repo-check` 필수·refute-by-default 프롬프트[결함만·범주 명시·원문 인용 강제·none found 명시·제안 금지]·**메인 세션 트리아지 필수**[14건 중 4건 오독 실증]·**사이클당 1회**·호출 지점=고-스테이크만[senior review·재채점·적대 리뷰]·GPT=추가 발견자≠판정자) ③검증자 모델 정책(서브에이전트 model 미지정=세션 상속 기본=검증자 티어≥작업자 티어 공짜 보장·하향 오버라이드=사유 선언 필수[DOWNGRADE-DECLARED 동형]) ④codex-plugin-cc 기각 판정(spec §10-2 압축)+재검토 트리거(구현-위임 용도 GAP 신설 시). 실증 사실(2026-07-18 2경로 검증+결함 10건)은 §1에 인라인 재서술(goal은 gitignored — 영구화).
- [ ] **Step 2: scaffold-registry 등재** — 거버넌스 문서 표에 `cross-family-review.md — 교차패밀리 검증 규약(탐지·트리아지·quota) — C10 (GAP-006)` 1행.

### Task 2: 소비처 배선 (closeout Phase 4 분기 + start-rpi 앵커 + 기존 문구 교체)
**Files:** Modify: `skills/closeout-pr-cycle/SKILL.md`(+`opencode-harness/skill/closeout-pr-cycle/SKILL.md`), `skills/start-rpi-cycle/SKILL.md`(+미러), `docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md` §5, `docs/harness-upgrade-2026-07/05-playbook.md` §5-6, `docs/harness-upgrade-2026-07/README.md` 방법론

- [ ] **Step 1: closeout Phase 4 분기** — senior review Agent() 블록 뒤에 "교차패밀리 probe(runbook 앵커)→가용 시 사이클당 1회 실행+트리아지→불가 시 SKIP+사유 기록" 소절 추가(골격 불변: Phase 수·Agent() 호출·Communication Protocol 유지). 미러 SKILL.md 대응 부분 동기.
- [ ] **Step 2: start-rpi 앵커 1줄** — 적대 리뷰 언급 지점에 "교차패밀리 리뷰 가용 시 옵션 — `docs/ai-context/cross-family-review.md` 탐지 절차" 1줄(골격 불변). 미러 동기.
- [ ] **Step 3: 기존 문구 앵커 교체** — spec §5 "(ccs gpt) 적대 리뷰 1회 시도"→runbook 참조로 갱신 주석 · 05 §5-6 ccs 함정 노트에 "stdin 파이프 검증됨·2경로 규약=runbook" 앵커 append(원문 이력 보존) · README 방법론 "GAP-006에 위임" 문장에 "→ C10 착륙(runbook)" 갱신.

### Task 3: 04/03 갱신 + probe 실측 + Closeout
**Files:** Modify: `docs/harness-upgrade-2026-07/04-gap-backlog.md`, `03-rubric.md`, `README.md`(상태 행), `state.json`, 메모리

- [ ] **Step 1: 04 GAP-006 DONE** — 요약표+본문 블록: 수용 기준 충족 증빙(SKILL.md 분기 grep + 교차패밀리 실행 1회 성공=design.md v4 리뷰 `modelUsage: gpt-5.6-sol` 실측[2026-07-18] + probe A/B 로그). DEFERRED 규정("인프라 사유로 1회도 불가 시") 비적용 명기.
- [ ] **Step 2: 03 재채점 무bump** — D2 블록에 C10 부분-진척 노트(L5 3 conjunct 중 교차검증자 1착륙·CI/자동봉인 잔여→4 유지), D10 블록에 노트(L5 "정기 반증"=실사용 누적 후→4 유지), 종합표 비고 2행 갱신.
- [ ] **Step 3: probe A·B 실측** — A: `command -v codex && codex login status` + 스모크 1회 · B: `claude --model gpt-5.6-sol -p "Reply: OK" --output-format json | grep -o 'gpt-[^"]*'` 1회. 로그를 이 plan 하단+PR 본문에 기록(이 머신 둘 다 가용이어야 정상 — 아니면 탐지 로직 결함으로 회귀 수정).
- [ ] **Step 4: 검증 전건** — verify-setup 81/0(불변)·run-all 178(불변)·verify-all ALL PASS(포그라운드) + README 상태 행(C10)+다음 착수 갱신(GAP-012+doctor #23 유지·C10이 GAP-006 선소화 명기).
- [ ] **Step 5: drift review-strict + PR + merge 대기** — drift 검사(체크박스·미신고 열화·갱신 계약·미러 동기) → state bump(59→60, 라이브 재확인) → 메모리 append+MEMORY.md 동기(예산 주의) → PR 생성(검증 로그 본문) → **merge 승인 요청 후 대기**(auto 금지) → 승인 시 머지·plan completed → 한국어 최종 보고.
