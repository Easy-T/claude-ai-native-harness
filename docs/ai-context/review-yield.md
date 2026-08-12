# review-yield.md — per-layer 리뷰 수율 축적 대장 (C16 spec §15.3)

> 사이클마다 Closeout `layer-yield:` 필드와 같은 행을 append(필수 불변). 소비 = 트리거 기반 재심(spec §18.1 판정 3, C19 supersede). 소비-이력: C19 §18 이 C15~C18 4행 소비(1호).
> 실발견 = REAL 판정된 내용 결함(정정/수용잔여 처분 무관 — 판정이 기준). 토큰 수치는 가용 시 부기(필수는 발견 카운트).

## C15 (cycle 66, 2026-08-01 — 축적 1호, spec §15.0 실측)

- Gate R: PASS · 실발견 0건 · 확인 (71k)
- Gate P #1: FAIL→정정 · 실발견 3건 · 발견 (84k — 코드 전 차단)
- Gate P #2 재심: PASS · 실발견 0건 · 확인 (83k — 전체 재리뷰 낭비, C16-B의 근거)
- stage2 ×6: 5 PASS/1 FAIL · 실발견 0건 · 준수 확인 (273k — FAIL 1 = TDD RED 증거 강제)
- senior: PASS · 실발견 0건 · 확인 (80k, Minor 3)
- drift: PASS · 실발견 0건 · 확인 (47k)
- 교차패밀리(GPT, 말미): 실행 · 실발견 13건 · 발견 (REAL 13/15)

## C16 (cycle 67, 2026-08-02 — 축적 2호)

- Gate R: PASS · 실발견 0건 · 확인
- Gate P #1: FAIL→정정 · 실발견 4건 · 발견 (spec §3 포인터·hook :59 주석·T6 grep 불능·픽스처 번호 충돌 — 코드 전 차단)
- Gate P 델타 재심 ×3: 1 FAIL/2 PASS · 실발견 3건 · 발견 (#1: :53 필터·stale 카운트·sid 충돌 → #2 PASS · #3 관측 1건[Mutator 14 번호] — §15.4 첫 적용, 재심당 ~효율 개선 실측)
- 교차패밀리 슬롯 1(GPT, Gate P 직후): 실행 · 실발견 26건 · 발견 (REAL 26/37 — S1/S2 floor 붕괴 클래스 코드 전 차단, 첫 실행)
- stage2 ×8 (T1~T7 + 재심 2): 5 PASS/3 FAIL→정정 · 실발견 3건 · 발견 (T3 CONTEXT:93 표기·T7 주석 오기재+증거 규약 — 준수-확인이 사실 오류 2건 차단)
- drift: FAIL→정정 · 실발견 1건 · 발견 (plan 체크박스 미반영 — 경미)
- 교차패밀리 슬롯 2(GPT, Closeout 코드 diff): 실행 · 실발견 8건 · 발견 (REAL 8/9 — F4 미지-티어 floor 구멍 코드 층 차단, F3 수용 잔여 부기)
- senior(적대 전환 첫 적용): PASS · 실발견 2건 · 발견 (I1=F4 상계의 Rule C 누출 오발화[라이브 재현→원시-티어 분리 정정+픽스처 49]·I2=MEMORY.md 스테일 인덱스 — Critical 0, 적대 전환이 첫 회에 코드 결함 1건 산출)
- 블라인드 A/B(C16-C, 1회성 실험): 실행 · 재발견 7/13 · senior 임무 전환 채택 근거
- (정정 — C17 §16.7-4, 원행 보존): 위 stage2 행 `×8`·`5 PASS/3 FAIL` 은 오기 — 실측 `×9`(1차 7 + 델타 재심 2)·`7 PASS/2 FAIL`(재심 2 PASS 산입).

## C17 (cycle 68, 2026-08-02~08 — fable 최소화·매트릭스 v2·리뷰 통합 첫 적용)
- Gate R: PASS · 실발견 0건 · 확인 (delta 사이클 필수 실행 — §16 구조·supersede 계보·실측 근거 전건)
- Gate P ×2: 1 FAIL→정정/재심 1 PASS · 실발견 5건 · 발견 (BLOCKER-1 smp30 판별 증발·BLOCKER-2 README 카운트 2곳·deviation smp11 이중분류·재심 unknowns 2[model-policy :36 미열거·M15/16 $R 변수 부재] — opus 게이트가 산술 결함을 샌드박스 재현으로 코드 전 차단)
- 교차패밀리 슬롯 1(GPT, Gate P 직후): 실행 · 실발견 24건 · 발견 (REAL 24/26·기각 0 — A6 U4 세션-축 구멍·C3 task 순서 false-GREEN 창 등 전건 설계-층 도착)
- stage2 ×5 (T1~T4 + T3/T4 합본 재심): 2 PASS/2 FAIL→정정/재심 1 PASS · 실발견 2건 · 발견 (T3/T4 RED 증거 부재 — TDD-verbatim 규약이 증거 결손을 차단, 내용 결함 0)
- 통합(senior+drift — C17 §16.3-2 첫 적용): PASS(Critical 0/Important 2/Minor 1) · 실발견 3건 · 발견 (I1 model-policy SSOT 역전[슬롯2 D1 교차 일치]·I2 plan 체크박스·M1 CONTEXT F1-기각 표현 재발; drift 절 5항 분리 출력 — 합본이 drift 결손 1건을 Important 로 유지)
- 통합 델타 재심 ×1: PASS · 실발견 0건 · 확인 (+관측 1: seal #5 CRLF 거짓-FAIL 은 플랫폼 조건부[MSYS gawk 자동 CR 제거] — 신 코드 양 플랫폼 정상)
- 교차패밀리 슬롯 2(GPT, Closeout 코드 diff): 실행 · 실발견 9건 · 발견 (REAL 9/9·기각 0 — 6건이 판별력 공백[비판별 픽스처 43·seal #5/#45 위양성]: 내부 리뷰가 "문면 충족"을 본 자리에서 검사 자체의 회귀-포착력 결손을 적발. D1 교차 일치 1건)

## C18 (cycle 69, 2026-08-08~09 — fable 판단-전용화·집필-위임 4레버 선적용·2단계 트리아지 첫 실측)
- Gate R: FAIL→정정/재심 1 PASS · 실발견 1건 · 발견 (§17.3 예외 4건을 D5 2건 창에 귀속한 축 충돌 — 골격 정정 후 opus 재집필, 코드 전 차단)
- Gate P ×3: 1 FAIL→정정 / 재심 #2 FAIL→정정 / #3 PASS · 실발견 2건 · 발견 (T4 잔여-드리프트 grep 의 docs/ 스냅샷 오염 · 슬롯1 S5 정정의 plan 착륙 블록 스테일 — 위임-집필 plan 의 게이트 첫-회 FAIL 1회 = C17 동률)
- 교차패밀리 슬롯 1(GPT, Gate P 직후): 실행 · 실발견 19건 · 발견 (REAL 19/기각 6 — Critical 2: FABLE-TAKEOVER floor 미규정·seal-regression 조건부의 입력 집합 누락. 2단계 트리아지 첫 적용: 증거 수집 opus ×2 병렬 → 판정 fable)
- 미니-사이클 검증(슬롯1 정정, opus): 보완 1 · 실발견 1건 · 발견 (fable 정정 목록의 #4 누락을 step3 전건 대응 대조가 적발 — 대조 의무의 실효 실증)
- stage2 ×4 (T1~T4, Workflow d 순차): 4 PASS · 실발견 0건 · 준수 확인
- 통합(senior+drift 합본): PASS(Critical 0/Important 3/Minor 5) · 실발견 3건 · 발견 (I1 누락-0 조항 L1 전파 공백·I2 registry #50 미등재·I3 branch-flip ×2 = 명시 면제[read-only 리뷰 창, 원인 미상·데이터 손실 0·5 Whys/픽스처 불가])
- 통합 델타 재심 ×3: 3 PASS · 실발견 1건 · 발견 (#2 가 신설 M18 표적의 witness 미등재를 적발 → 정정 후 #3 확인)
- 교차패밀리 슬롯 2(GPT, Closeout 코드 diff): 실행 · 실발견 18건 · 발견 (REAL 18/기각 0[부분 기각 3] — ★#12 C18 신규 토큰이 기존 seal #49 를 vacuous 화[실험 확정, C15 X6 마스킹 클래스 자기-재발 → 앵커 구체화+M19]·정정-전파 공백 단일 클래스 5건[슬롯1 정정이 spec 본문에만 착륙]; 정정 15/수용 잔여 3)
- 미니-사이클 검증(슬롯2 정정, opus): PASS · 실발견 0건 · 준수 확인 (15/15 전건 대응 대조)
- seal-regression: full 실행 21→23 (M18·M19 신설 — setup/+입력 집합 diff 있음 = SKIP 불가 창; §17.5 ③ 첫 적용 사이클)
- (부기) FABLE-TAKEOVER·FABLE-ESCALATION 발동 0회 · 수용 잔여: seal #50 부정-단언 conjunct 변이 미커버 존속 · 슬롯2 #13(state.schema 오라클)/#14(#45 vacuity)/#16(번들 self-containment) 차기 후보

## C19 (cycle 70, 2026-08-09~10 — 배분 재심 1호 소비·seal 판별력 경화·§18 착륙)
- Gate R: FAIL→정정/델타 재심 1 PASS · 실발견 5건 · 발견 (§18.5 착륙물 2건 누락[전파-공백 자기-재발]·M21 표적 witness 미등재[C18 #2 동일 클래스]·교차참조·귀속·순서 제약 — 코드 전 차단)
- Gate P ×3: 1 FAIL→정정 / 델타 재심 #1 발견 1 / #2 PASS · 실발견 3건 · 발견 (BLOCKER 2[골격 계약 GREEN 기대 :1 거짓·CONTEXT grep 부분문자열 불성립] + 재심이 stale ordinal 모순 1건 적발)
- 교차패밀리 슬롯 1(GPT, Gate P 직후): 실행 · 실발견 11건 · 발견 (REAL 9+부분 2/전면 기각 0, 제기 11 — BLOCKER 2 = G1 비용 conjunct 판정-불가·G2 어휘 불일치: 특화 축 "재심 판정이 탐지 거버넌스를 깎는 방향" 적중. G4/G5 = 판별력-공백 계보 4연속[C15 X6·C17·C18 #12])
- 미니-사이클 검증(슬롯1 정정, opus): FAIL→정정 라운드2 · 실발견 4건 · 발견 (F1 개행-기준선 스테일 ×5사이트·F2 행-선두 미전파 ×5·F3 사전-실측 스테일·D① G2 cross-family 전파 누락 — 전파-완결성 대조 첫 적용이 공백 즉시 적발)
- Gate P 델타 재심(라운드2 결합): PASS · 실발견 0건 · 확인
- stage2 ×3 (T1~T3, Workflow d 순차): 3 PASS · 실발견 0건 · 준수 확인
- 통합(senior+drift 합본): FAIL→정정 · 실발견 4건 · 발견 (I1 F3 non-obvious 미등록/면제 부재[Important — drift 게이트 실효]·m1 #30 비-crash 잔여·m2 §18.6-3 수치 자기-스테일·m3 Status enum)
- 교차패밀리 슬롯 2(GPT, Closeout 코드 diff): 실행 · 실발견 4건 · 발견 (REAL 4/기각 1, 제기 5 — M1 #30 validator crash false-green[기존-클래스 cycle-28, rc-캡처로 봉인]·M2 미러 [ -f ] fail-open 3사이트[§18.6-6 수용]·M3 §15.1 :1229 supersede 전파 누락[정정-전파 공백 2호]·m1 registry 긍정-conjunct 누락)
- 미니-사이클 검증(Closeout 정정, opus): FAIL→정정 라운드2 · 실발견 3건 · 발견 (R1 트리거 귀속 오류[(c)→(b) — fable 지시문 자체 결함을 독립 검증이 차단]·R2 수치 26→27 재검산·R3/R4 rc-캡처 기재 누락)
- seal-regression: full 실행 23→26 (M20~M22 — setup/+입력 집합 diff 있음 = SKIP 불가 창; RED 실측 PASS=24 FAIL=2[M21/M22 구 seal 미탐 실증] → GREEN 26/0)
- **트리거 대조(§18.1 판정 3 — 1호)**: (a) 불성립 · **(b) 성립**[C18 슬롯1 Critical 2 + C19 슬롯1 BLOCKER 2 = 2사이클 연속] → **차기 사이클 floor 한정 재심 1회 예약**(§16.0-2 역-supersede 경로) · (c) 불성립 · (d) N/A
- (부기) FABLE-TAKEOVER 0회 · 토큰: fable 메인 out 1,208k/352턴(C18 288k 대비 — 셧다운 재개 재독·슬롯1 11건 2라운드 정정 포함이라 방법론 비교 불가, 관찰만) · opus 위임 out 1,877k/2,122턴 · sonnet 47k · GPT 헤드리스 out 1,278k · **I1 처분: Edit 혼합-개행 파괴 = non-obvious 등록 후보(재현 픽스처 제작 가능 — C18-형 "5 Whys 불가" 면제 불성립) → §4 1단계 사용자 확인 완료(2026-08-10 머지 정지점 승인) — 차기 사이클 초입 review-strict 5 Whys+재현 픽스처 등록 확정** · 수용 잔여: §18.6-5(#30 비-crash 축)·§18.6-6(미러 fail-open 3사이트)·§18.6-1(arm 7 재계수)

## C20 (cycle 71, 2026-08-11) — ADE 적합화 + 브리지 실행 자산화

- Gate R: FAIL→정정/델타 재심 1 PASS · 실발견 4건 · 발견 (**Critical 1 = §19.3 초안이 "모델-정책 매처 사각"을 "훅 일반의 구조적 도달-불가"로 과잉 일반화 → 훅 로그 13건·BLOCK 포함 실측으로 반증**[§19.5 가 지목한 "자기 산출물 전제 미실측" 클래스의 자기-재발을 게이트가 포착] · 파생 1 = 같은 오류의 CONTEXT.md canonical 오염 · Important 2 = §19.6 N2 검증 지시문 기대값 오류[구 패턴 실측 1건]·CONTEXT.md 금지4 위반["사멸" 프레이밍])
- 집필-위임 정정 루프(execute-strict opus, spec 절 1개): 2회 · 실발견 2건 · 발견 (전파 표가 `closeout-pr-cycle/SKILL.md:161` 을 N/A 오분류 → 메인 grep 반증 · 2회차에 위임자가 **미러 :166 자기-표면화**[정정-전파 공백 자기 적발] — TAKEOVER 0회)
- Gate P: PASS(메인 직접 실측 — 서브에이전트 게이트 대체) · 실발견 3건 · 발견 (**BLOCKER 1 = 오라클 정규식 문자 클래스에 `${}` 부재 → `--model $VAR` 가 매칭 실패로 absent 판정, 동적 판정 줄이 죽은 코드**[3값 계약 붕괴] · 숨은 의존 T2→T4 미선언[T4 앵커 count=0 실측] · 눈-판정 2건 → 기계 판정 교체). ※ 방식 전환 기록: Workflow 6차원 적대 검증(xhigh×6)을 먼저 시도했으나 47분간 Audit 단계 미완료(에이전트당 72~114턴)라 중단 → 메인 직접 실측 6분 완료. **MSYS 환경에서 "명령 몇 개로 판정되는 검사"의 fan-out 은 역효과** (판단-분기 없는 계측은 직접 수행이 정합).
- stage1 위임 ×6 (T1·T2·T4·T3·T5+T6·T7, execute-strict opus): 5 COMPLETE / 1 FAIL(정직 보고) · 실발견 3건 · 발견 (**작업자 자기-표면화 3건**: ①T1 검증 정규식 `[0-9]+k/` 가 Opus `1M` 표기 미포착 → 침묵-통과 위험 ②T4 개행 판정 이관[삽입 절 LF 29 → 순수 CRLF 파일이 혼합화 = I1 트리거 조건 신설] ③T6 MSYS `/tmp` 함정이 **조용한 거짓-GREEN** 유발[픽스처 생성 실패 → 오라클이 빈 디렉터리에 VIOLATION=0 exit=0])
- T7 FAIL→정정: 실발견 1건 · 발견 (**seal-regression control 25/1** — 작업자가 A/B 로 자기 귀책 실증 후 근본 원인 적발: replica 빌더 `:33` 이 `modes/` 미복제[파일 전체 참조 0건] → seal #51 vacuous-방지 arm 이 **정상 발화**. seal 결함 아님 · 완화 대안은 §19.3 설계 훼손이라 기각, replica 측 보정)
- 메인 검증 ×6 (각 stage1 산출 직후 독립 실측): 6 PASS · 실발견 0건 · 확인 (T2 단언 3종[포트 10100·healthz 200·**fail-closed exit 1**] 실측 확증 · T3 이관 후 `modelUsage: gpt-5.6-sol` 실측 = 문서-실물 일치 · T6 RED/동적계수 독립 재현)
- 통합(senior+drift 합본, opus): FAIL→정정 · 실발견 5건 · 발견 (**I1 = 오라클 `--model` 첫-매치 채택 vs CLI last-wins → `--model opus --model haiku` 가 opus 로 판정돼 review-only 워커가 haiku 로 도는데 seal GREEN** [면제(*)가 아니라 *틀린 양성*이라 3값 계약 미방어 · 메인이 `TOTAL=2 LITERAL=2 VIOLATION=0 exit=0` 우회 재현 → matchAll 정정 → `VIOLATION=1 exit=1` RED→GREEN, 체이닝 3형태 동반 해소] · **I5 = 같은 last-wins 근원의 브리지 인자 축**[`exec claude --model "$OCX_MODEL" "$@"` 에서 사용자 `--model` 이 뒤라 OCX_MODEL 무력화 = env 축만 막은 반쪽 계약 → 인자 거부 exit 2] · **I6 = `ANTHROPIC_API_KEY` unset 누락**[BASE_URL 이 로컬 프록시인 상태에서 진짜 키가 서드파티 프로세스로 전송 가능 — 현 환경 미설정이라 라이브 노출 0] · I2 워커 키 오타 침묵-skip · I3 오라클 stderr `2>/dev/null` 폐기[I2·I3·I4·M1~M6 = §19.7 수용 잔여 이월]. drift 체크리스트 5 PASS/1 Important[본 5 Whys 등록 항목])
- 5 Whys 검증(review-strict, MSYS 경로 등록): FAIL ×2 → rev2 델타 재심 PASS · 실발견 3건 · 발견 (①rev1 이 "이 클래스는 처음"이라 단언했으나 spec §13.10 C14-G·`doctor.sh:361` 에 **선행 기록 실재** → root cause 가 "규약 부재"에서 **"실측 환경 제약을 강제 표면으로 승격시키는 경로 부재"**로 교체 ②rev1 처방 `mktemp -d` 가 **틀림** — 판별자는 디렉터리가 아니라 *경로 전달 방식*[실측 interp=False/argv=True] ③rev2 측정자 `grep -c 'TOTAL=0'` 이 **vacuous**[with=4/without=2 — 조기-반환 리터럴 상주] → 판별 앵커 `'반드시 처분'`[with=1/without=0] 교체. **등록하려는 결함 클래스를 rev1·측정자가 각각 자기-재발**)
- 교차패밀리 슬롯 1·2(GPT): **SKIP** (사유: 이 사이클은 문서 정정·자산 추적 축이 주축이고 신규 코드는 오라클 1개(64줄)뿐 — 고-스테이크 기준 미달. 경로 A 가용[codex-cli 0.145.0 로그인]이나 사이클당 1회 상한 아래 미소비)
- seal-regression: full 실행 ×2, 26→26 (setup/ diff 있음 = SKIP 불가 창. 1회차 25/1[control FAIL] → replica 보정 후 **26/0**. 통합 리뷰 I1 정정이 `setup/lib/` 를 다시 건드려 **2회차 재실행 필수 창 재개방** → **26/0** 재확인, 변이 24 전건 발화[신규 `mp_model_flip` 포함]·live witness cksum 불변)
- 최종 3-스위트(정정 후): verify-setup **89/0** · seal-regression **26/0** · run-all **291/291** · run-log EVENTS=7578 BLOCK=2060 SKIP=306 **FAILOPEN=0**
- **트리거 대조(§18.1 판정 3)**: (a) 불성립 · (b) **불성립**[슬롯 SKIP → BLOCKER 0, 2사이클 연속 조건 끊김 — C19 예약분은 §19.5 에서 소비 완료] · (c) 불성립 · (d) N/A
- (부기) FABLE-TAKEOVER 0회 · **C19 예약 3건 처분**: ①floor 재심 → §19.5 **floor 축 무변경** 판정(결함 클래스가 티어 축 아닌 게이트 *지시문* 축 · 반증 조건 명시 · 처분 문안은 차기 이월) ②I1(Edit 혼합-개행) non-obvious 등록 → **미수행, 차기 이월**(이번 사이클이 I1 트리거 조건을 오히려 1건 신설·제거[T4 README]했으므로 픽스처 재료 축적) ③ledger 부기 = 본 행
- (부기 2) **non-obvious #3 등록 완료**(§4 5단계 전수 — 사용자 승인 2026-08-12): "bash 가 만든 경로를 네이티브 인터프리터에 **소스 보간**하면 조용히 다른 위치를 가리킨다". root cause = 시스템(승격 경로 부재) · SMART 2건[①경로-전달 seal RED→GREEN = **C21 초입** ②오라클 TOTAL=0 처분 의무 = **C20 내 착륙 완료**] · 재현 픽스처 2건(기전·증상) 실행 확인. spec §13.10(C14-G)의 **일반화·승격**이지 중복 아님 · 수용 잔여: spec §19.7 7항(신규 세션 런타임 미검증·dangling symlink 3건 예정·스키마 추종 불가·오라클 상한·Orca 훅 지연·판정 강도·I1 방향 역전) + 통합 리뷰 이월 I2/I3/I4·M1~M6
