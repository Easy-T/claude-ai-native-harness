# Harness Upgrade 2026-07 — Durable Design Spec

> **Subsystem**: harness-upgrade-2026-07 (재감사 문서 세트 + Best-Direction Mandate)
> **Status**: durable spec — 이 이니셔티브의 모든 사이클(C0..C-final)이 재사용
> **Goal SSOT**: `_goal/harness-upgrade-2026-07-goal.md` (요구사항 canonical; 이 spec은 그 요구를 설계로 구체화)
> **승인 근거**: 사용자 /goal 킥오프(2026-07-13) — "그대로 수행해줘 · 자율 best-practice · MERGE_POLICY auto". 무인 모드이므로 goal 문서가 clarifying question의 canonical 답변이다.
> **작성**: 2026-07-13 (Fable 5, cycle C0 Phase R)

## 1. 문제 정의

Fable 5 가용 종료가 임박했다. Fable급 판단이 필요한 작업(전수 구조 파악 · 2026.07 외부표준 리서치 · 정밀 갭 판정 · 업그레이드 설계)을 지금 완료하고, 이후 Opus가 **산출 문서만으로** 나머지 강화 작업을 손실 없이 이어받아야 한다. 동시에 사용자가 관찰한 구조 결함 — "구현이 복잡하면 최선 방향 대신 열화 대안을 '최적'이라며 선택" — 을 하네스 수준에서 교정해야 한다.

**Deadline invariant (최상위)**: 문서가 구현보다 먼저다. 구조맵→표준 다이제스트→루브릭→갭 백로그→플레이북이 커밋·머지되기 전에는 구현 사이클을 시작하지 않는다. 어느 시점에 세션이 끊겨도 그때까지의 머지 산출물로 다른 모델이 재개 가능해야 한다.

## 2. 아키텍처 — 문서 세트 (C0 산출물)

디렉터리: `docs/harness-upgrade-2026-07/` (git 추적 — 반드시 머지).

| 파일 | 계약 (무엇이 있어야 완성인가) |
|---|---|
| `README.md` | 진입점. 문서 세트 지도 + 읽기 순서 + 이니셔티브 상태(어느 사이클까지 완료) + Opus 첫 착수 지시 포인터 |
| `01-structure-map.md` | 하네스 전수 인벤토리. 4계층(강제/skill·agent/검증/거버넌스) × 구성요소별: 역할 · 강제 수준(차단>advisory>자가-표면화>미강제) · 우회 경로 · fail-open 표면화 여부 · 테스트 커버리지 · 이식성(claude-only/mirrored). **file:line 증거 필수.** 서술↔실물 불일치 목록 포함 (그 자체가 갭 후보) |
| `02-standards-digest.md` | 2026.07 외부표준 다이제스트. 6축 리서치(Anthropic/타벤더/프론티어 관행/방법론·안전/관측·메모리/최신 스윕) 종합. **주장마다 출처 URL+게시일, [FACT]/[INFERENCE] 구분.** 말미에 "빅테크 공통 하네스 패턴" 표 — 패턴별 우리 하네스 보유/부재 병기. 6월 감사 기매핑 소스는 델타만 |
| `03-rubric.md` | 루브릭 v2. ≥10차원, 차원별 1-5 앵커 서술(레벨마다 관찰 가능 기준) + 현행 점수(증거 file:line) + 목표 레벨 + 델타. 6월 8차원 루브릭과의 매핑표(이월 점수는 근거 명시). 채점은 결정론 증거 기반 — 산출물 자기서술 금지 |
| `04-gap-backlog.md` | 갭 백로그. 항목 스키마: ID / 루브릭 차원 / severity / 증거(file:line) / 목표 상태 / **best-direction 근거(왜 더 쉬운 대안이 아닌가)** / 구현 스케치 / 수용 기준(결정론 커맨드) / 테스트 계획(RED 재현자) / 복잡도 / 의존성 / Opus-실행성 주석. **순위 = 레버리지 × 루브릭 델타 — 구현 난이도로 순위 강등 금지**(난이도는 사이클 분할에만 반영). 6월 defer 잔여 자동 편입 재평가 |
| `05-playbook.md` | Opus 운영 플레이북. 사이클 운영 규약(spec/plan 경로·게이트·검증 커맨드 전문) · 항목별 착수 절차 · 재채점 절차 · 롤백 규약 · 하네스 고유 함정 인라인 재서술. **auto-memory 참조 금지** — 필요한 사실은 전부 인라인 (전제 = git repo + Claude Code + 문서 자신) |

**갱신 계약**: 구현 사이클(C1..)마다 04(항목 상태)·03(재채점)·README(이니셔티브 상태)를 같은 PR에서 갱신 — 핸드오프 불변식은 머지 시점마다 성립한다.

## 3. 루브릭 v2 차원 (최소 커버 — Phase 1 리서치가 추가 도출 가능)

강제력(blocking>advisory) · 검증 정직성(anti self-pass) · 컨텍스트 경제 · 관측가능성(런타임 run-log) · 자율성 안전(iteration/cost 예산·back-pressure·sandbox) · 메모리 수명주기 · eval/fitness 인프라 · 이식성(멀티모델·opencode) · 핸드오프 복원력 · **best-direction 충실도**.

## 4. Best-Direction Mandate (구현 사이클 1순위 — C1)

사용자 관찰 (canonical, goal §4에서 전사): *"RPIC로 구현할 때 가장 기능적으로 좋고 확장 가능한 방향(구현이 어렵고 복잡하더라도)으로 가지 않고, 구현이 복잡하면 대안을 '최적'이라며 선택하는 경우를 종종 봤다. 구현이 어렵더라도 최선의 방향으로 계속 구현돼야 한다."*

구조 결함으로 취급 — 하네스에 열화-회피(silent downgrade)를 막는 장치가 없다. 설계 (4개 층, 자가-표면화 원리 재사용):

1. **CLAUDE.md 헌법 정련**: "Simplicity First"를 *스코프 최소주의*(요청 밖 기능 금지 — 유지)와 *아키텍처 품질*(채택한 설계는 알려진 최선이어야 하며, 열화는 선언 없이 불가 — 신설)로 명시 분리. §1 캐시 규칙 준수(세션 종료 직전 수정) + 사용자 diff 보고.
2. **Phase P 게이트**: start-rpi-cycle plan 템플릿에 고유 필수 필드 `Best-Direction Check` — (i) 알려진 최선안 명시 (ii) 채택안 ≠ 최선안이면 `DOWNGRADE-DECLARED(사유)` + 사용자 승인 요구. next-cycle-goal 필드 선례(누락 = 구조적 불완전 = 자가-표면화) 동형.
3. **Closeout 검출**: Step C-1 drift 기준에 silent-downgrade 항목 — spec 목표 설계 vs 구현 실물 대조, 미신고 열화 FAIL.
4. **결정론 seal (가능 시)**: verify-setup에 plan 템플릿 필드 존재 parity 검사. 물리 강제 불가 지점은 advisory 상한으로 수락하고 그 한계를 문서화(기존 F12 선례).

이 mandate는 이 이니셔티브 자신에게 선적용된다 (goal §0-5): 열화가 불가피하면 plan에 `DOWNGRADE-DECLARED(사유)` 표면화.

## 5. 방법론 제약

- **자기채점 편향 회피**: 핵심 판정은 결정론 신호(exit code·diff·실측) grounding. 루브릭 채점·갭 목록에 교차패밀리(ccs gpt) 적대 리뷰 1회 시도(refute-by-default) — 불가 시 사유 기록 후 진행.
- **2026-06 감사 재소송 금지**: specs `2026-06-13-external-standards-audit.md` + `2026-06-14-audit-reverification-2.md`의 종결 항목은 기준선. 이번 확장 3축 = (a) 당시 defer 잔여(goal §5 목록) (b) 2026.07 신규 표준 (c) Best-Direction 관찰.
- **인벤토리는 fresh 실측**: README 서술을 신뢰하지 않고 실물 코드를 읽는다. 불일치 자체가 산출물.
- **문서 self-containment**: 산출 문서는 이 머신의 auto-memory에 의존 금지.

## 6. 사이클 계획

**C0** = Phase R(이 spec+grill) → P(plan) → I(리서치·인벤토리 수집 + 문서 6종 작성) → Closeout(검증·PR·auto-merge·state bump). **C1** = Best-Direction Mandate 구현(§4). **C2..Cn** = 백로그 순위순 1~3항목/사이클. **C-final** = 핸드오프 봉인(최종 재채점 before/after · cold-agent fitness: 새 subagent에 플레이북+백로그 1항목만 주고 착수 가능 검증 · 메모리 갱신 · 한국어 최종 보고 + Opus 첫 착수 항목 지정).

Fable 잔여 가용·수확 체감 시 어느 사이클 경계에서든 C-final로 전환 가능 (전환 판단 보고 명시).

## 7. 수용 기준 (C0)

- 문서 6종 존재 + 각 계약(§2 표) 충족 — review-strict가 계약 항목별 PASS/FAIL.
- 02의 모든 주장에 출처+날짜, 03의 모든 채점에 file:line 증거, 04의 모든 항목에 best-direction 근거 — 표본 검사로 확인.
- verify-setup PASS(baseline 70)=FAIL 0 · run-all 전건 · verify-all ALL PASS (문서 전용 사이클이라 회귀 없어야 정상).
- PR 생성 → 검증 ALL PASS 전제 auto-merge (MERGE_POLICY: auto, 사용자 지시 2026-07-13).

## 8. 비-목표 (C0)

하네스 코드 변경 없음(문서만) · CLAUDE.md 본문 수정 없음(C1에서, §1 캐시 규칙 준수) · opencode 미러 변경 없음 · 6월 종결 항목 재감사 없음.

## 9. Spec Delta — Fable 재감사 (2026-07-17, C9 사이클에 편승)

배경: 이 이니셔티브는 Fable 5 계획이었으나 사용량 소진으로 **C2 완료부터 전부 Opus 4.8이 수행**(C2·C3·cfinal·C4~C8+C9 Task 1). 사용자 지시(`_goal/harness-upgrade-2026-07-fable-reaudit-goal.md`)로 Fable 5가 Opus 구간을 3축 적대 재감사했다. **설계 변경은 없다** — 아래는 판정 기록(spec §5 방법론의 사후 감사 이행)이다.

### 3축 판정 요약 (전수 표는 최종 보고·04 갱신에)

**축A 계획 충족 — 결함 0 (코드 사이클 7건)**: C2~C8 plan 전부 Status completed·BD-Check 실재·미완 박스 0·DOWNGRADE 0. PR #19/20/22/23/25/26/27 본문에 검증 숫자 실재, verify-setup 수열 72→73→74→75→76→77→79 정합. Gate 기록은 형식 아닌 실질(C3 "Gate P FLAG B"→(b)(c) DEFERRED 유도, C7 "Gate P set-e 조기종료 포착", C8 1차 Gate P FAIL[over-claim]→GAP-007a 동사이클 추가→2차 PASS). cfinal 중간 수행은 PR#21에 off-ramp 판단 명기(4사이클 완료·머신 불안정·수확 체감)로 spec §6 규정 충족. **기록 공백 2건(수용, 재작업 불요)**: ① cfinal plan 파일 부재(문서-전용이라 hook 게이트 비대상; PR 본문이 기록 대체) ② cold-agent fitness "재시도 이력 전수 기록"(04 GAP-008 수용기준) 미명시 — "COULD_START(질문 0회)"만 있고 재시도 0회임을 명시한 문장 부재. 처분: D9=5 주장은 유지하되 이 공백을 여기 명기(증거 보강 불가 — 세션 소실).

**축B 정직성/품질 — 재작업 0**: D3·D6·D11=4 주장 전 conjunct 실물 재검 PASS — D3(model-window 1M 인지+`[1m]` suffix 커버·#39 ≤40 봉인·서브에이전트 격리·트리거 40%=rot 이전), D6(memory-policy 3규약·예산 200줄/25KB[23줄/20953B 실측, byte-바인딩]·dangling ALERT 라이브 발화 로그 실증·provenance 20/20), D11(핀 #40+Rule-of-Two #41+deny #42, SECURITY.md § 실재). seal #37~#42 전부 non-vacuous — seal-regression 7 mutant(+control) staged 9/0으로 실FAIL 증명, #37은 라이브 registry가 실제 stale일 때 FAIL함(아래 축C 참조 — 검사가 작동한다는 실증이기도). 191/192(공급망)·185~188(메모리) 케이스 hermetic 격리 정상.

**축C 실배포 정합 — 발견 3건 전부 이 세션에서 해소**:
- **C-1 plugin-pins 드리프트 = 정당 업데이트로 판정, 핀 갱신 완료**: 핀(1099091361·46) vs 라이브(1781304936·33) 불일치의 원인은 rug-pull이 아니라 **마켓플레이스 정상 갱신**(2026-07-17 06:44 `lastUpdated`, context7/skill-creator/playwright가 version `9acf649a292f`로 갱신 — 캐시 버전 디렉터리 교체로 SKILL.md 46→33). 콘텐츠 검증: superpowers 6.1.0↔6.1.1 SKILL.md 14/14 byte-동일, skill-creator 신·구버전 diff 0 — 악성 변경 무관. C7의 핀 기록 자체는 그 시점(07-14) 정확했음(07-14 로그의 999999999는 테스트 노이즈). plugin-pins.md 절차 ②(정당 업데이트→재실측 갱신)로 처리: cksum 1781304936·count 33·버전 표 갱신(이 사이클 커밋).
- **C-2 per-machine 지연분 라이브 배선 완료**: 라이브 settings.json PCT 55→**40**(C6 목표)·**deny 블록 추가**(C8 example과 동일 7규칙). gitignored라 커밋 대상 아님, 세션 재시작 후 발화. **신규 결함 발견**: doctor #23이 node `readFileSync('$SETTINGS_JSON')` **bash-보간형**이라 MSYS 경로(`/c/...`)를 Windows node가 못 읽어 **설정돼 있어도 "미설정" WARN 오보**(C6 교훈의 미적용 사이트 — C6는 verify-setup #39만 bash grep으로 고침). 처분: GAP-019류 후속 사이클에 편입(README 차기 착수에 명기; 이 사이클은 C9 스코프 유지).
- **C-3 scaffold-registry stale**: C5~C8+v3의 신규 산출물(seal #38~#44·memory-policy·plugin-pins) 미등재 — #37 seal은 hook/skill만 검사해 seal/문서 추가는 침묵. 처분: 이 사이클에서 registry 갱신(간단 append — Surgical). 구조 개선(seal 검사 확장)은 후속.

### 재작업 백로그 판정
실증 결함 중 **재작업 필요 = 0건** (C-1/C-3는 이 세션 내 해소, C-2 doctor 결함은 차기 사이클 명기, 기록 공백 2건은 증거 소실로 보강 불가·명기로 종결). "Opus라서 미숙" 가설은 **기각** — 오히려 Gate P가 over-claim을 잡은 기록(C8)과 conjunctive 정직 선례(C7·C9)가 실재한다.
