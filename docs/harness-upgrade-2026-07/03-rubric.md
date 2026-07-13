# 03 — 루브릭 v2 (12차원, 2026-07-13 채점)

> 채점 규율: 증거는 01-structure-map(실측 file:line)·02-standards-digest(외부 기준)만 — 산출물의 자기서술("all pass" 문자열)은 증거 불인정. **min 기준**(게이트 사슬은 최약 고리로 결정, 6월 감사 §총평 계승). 평균은 참고치도 산출하지 않는다.
> 6월 루브릭과의 관계: 8차원을 계승하되 2026.07 외부표준(02 §7 P4·P5·P7·P11·P12)과 사용자 관찰(goal §4)이 요구하는 4개 신규 축을 추가. **외부 바가 오른 차원은 6월 점수에서 하향 재채점될 수 있다 — 회귀가 아니라 기준 상승이며, 해당 차원에 명시한다.**

## 재채점 절차 (구현 사이클마다)

1. 사이클이 터치한 차원만 재채점 — 앵커 대비 관찰 가능 증거(결정론 커맨드 출력·file:line)를 새로 수집.
2. 점수 변경은 이 파일의 해당 차원 "현행" 갱신 + 하단 종합표 갱신 + 변경 사유 1줄(증거 포함)을 차원 블록에 append.
3. 04-gap-backlog의 해당 GAP 상태를 같은 커밋에서 갱신 (spec §2 갱신 계약).
4. 앵커 자체의 수정은 금지 — 앵커를 바꾸면 사이클 간 비교가 무효. 앵커 결함 발견 시 새 버전 섹션을 append하고 구버전을 [retired] 표기.

## D1. 강제력 (enforcement)

| 레벨 | 앵커 (관찰 가능 기준) |
|---|---|
| 1 | 규칙이 프롬프트(CLAUDE.md)에만 존재 |
| 2 | 일부 쓰기 표면에 advisory hook |
| 3 | 주요 쓰기 표면(Write/Edit)에 차단 hook, 사이드도어(Bash 등) 미커버 |
| 4 | 전 주요 표면 차단 + 우회는 명시 env로만 + 우회 사용이 표면화됨. 잔여: 미커버 표면(MCP 등)·무로깅 fail-open 존재 |
| 5 | 4 + 전 표면(MCP 포함) 게이트 + 모든 fail-open이 로깅·표면화 + OS-레벨 백스톱(deny 규칙/sandbox) |

**현행 4** — 증거: 차단 hook 4종+Bash 사이드도어(01 §1 표), RPI_SKIP/SECRET_SCAN_SKIP 표면화(`_common.sh surface_bypass`), 잔여=enforce-orchestrator ERR-센티넬 무로깅(01 §6-3, `enforce-orchestrator.sh:17-18`)·MCP 무게이트(6월 G1-a 계승)·secret-scan 패턴 5/7 미테스트(01 §6-2)·**orchestrator 마커-제거 우회(frontmatter 자가-편집, env-외·무표면 — C0 적대 리뷰 지적으로 잔여 집합에 명시 편입, GAP-010이 표면화 커버)**. **목표 5. 델타 1.**

## D2. 검증 정직성 (anti self-pass)

| 레벨 | 앵커 |
|---|---|
| 1 | 검증 없음 또는 자기서술 신뢰 |
| 2 | 단위 테스트 존재, 카운트·parity 무검증 |
| 3 | 결정론 검증 + 카운트 양방향 정합, false-green 방지 부분 |
| 4 | 3 + seal 회귀 메타검증(seal이 실제 RED 됨을 증명) + 부정 단언 + 전제 게이트(STAGE 0). 잔여: [모델-판단] 게이트가 동일 모델 패밀리·거버넌스 숫자 일부 무봉인 |
| 5 | 4 + 교차모델 검증자 분리 + 스케줄된 자동 실행(CI 등가) + 신규 거버넌스 카운트 자동 봉인 규약 |

**현행 4** — 증거: seal-regression.test.sh(변이 주입 메타검증)+failopen-surface+rpi-prereq(01 §3), cases.tsv 양방향 정합+95% 플로어, #25 부정 단언 — 02 §6이 "이 패턴 공개한 개인 하네스 미발견"으로 업계-희귀 확인. 잔여: review-strict=실행자 동일 패밀리(01 §6-6), README "66 PASS" 무봉인 드리프트(01 M1), CI 부재(6월 G2-a 계승). **목표 5. 델타 1.**

## D3. 컨텍스트 경제

| 레벨 | 앵커 |
|---|---|
| 1 | 캐시·창 무인지, 무제한 프리로드 |
| 2 | 캐시 규칙 프롬프트만, 창 모니터링 없음 |
| 3 | 캐시 규칙 + 수동 compact, 모델-창 부정확 |
| 4 | 모델-인지 창 감시 + 캐시 seal + 서브에이전트 격리 + compact 트리거가 rot 실증(~300-400K) 이전. 잔여: 창 매핑 하드코딩·인덱스 비대 위험 |
| 5 | 4 + 창 매핑이 신규 모델에 자동 안전(실측 검증) + MEMORY.md 인덱스 예산(200줄/25KB) seal + 캐시 적중률 측정 |

**현행 3** — 증거: auto-compact-watch 모델-인지(model-window.js)·서브에이전트 요약-반환 계약(common-agent-contract ≤500단어)·#1 size seal은 충족하나, **앵커 L4의 conjunct "compact 트리거가 rot 실증(~300-400K) 이전" 위반**: 현행 트리거 55%×1M=**550K**는 rot 시작점(02 §5)·dumb-zone 40%=400K(02 §4)를 모두 지난 뒤다. 기타 잔여: model-window.js:10-16 하드코딩, `/1m/` 행 미테스트, MEMORY.md 인덱스 무예산(02 §1 "첫 200줄/25KB" 제약). **목표 5. 델타 2.**
**C0 적대 리뷰 반영(2026-07-13)**: 초기 채점 4는 "550K가 rot과 정합"이라는 산술적으로 거짓인 서술에 기반 — 4→3 교정(기준 상승 아닌 오채점 교정). 트리거 재캘리브레이션은 04 GAP-018 신설.

## D4. 관측가능성 (런타임 run-log) — ⚠️ 기준 상승 차원

| 레벨 | 앵커 |
|---|---|
| 1 | 로그 없음 |
| 2 | 산발 로그, 고장 침묵 |
| 3 | 게이트 판정 로깅 + fail-open 표면화 + 로그 소비(요약) 존재. 세션/사이클 단위 run-log·통계·비용 집계 없음 |
| 4 | 3 + 사이클당 게이트 발화/우회/토큰 통계가 구조화 기록(gen_ai.* 정렬 필드) + closeout이 소비 |
| 5 | 4 + 트레이스 재생(문제 세션→회귀 픽스처) + 대시보드/질의 가능 |

**현행 4** — 증거: hook_log+FAILOPEN 표면화(`enforce-rpi-bash.sh:42-48`)+doctor log_summary 소비(01 §1)는 6월 ⑥=4의 근거였으나, 2026.07 외부 바(02 §5: OTel gen_ai 표준화·스팬별 토큰/비용·"사고 대부분은 도구 실패·컨텍스트 절단·폭주 루프"·LangSmith 재생 루프; 02 §7 P5 부재 판정)가 세션/사이클 run-log를 요구 — 6월 4 → C0 신기준 3(기준 상승). **목표 4. 델타 0 (C2 도달).**
**C2 재채점(2026-07-13, 3→4)**: GAP-003 착륙 — `run_log_event`(hook_log 초크포인트 피기백)가 사이클당 게이트 발화·차단·우회·FAILOPEN을 구조화 JSONL(`hooks/.runlog/`, **gen_ai.* 정렬 필드**: tool.name/operation.name)로 기록 + `runlog_summary` 소비(doctor 20e 이상탐지 FAILOPEN>0 WARN + start-rpi-cycle Step C-1 사이클 보고 1줄). L5(트레이스 재생·대시보드)는 GAP-012/향후 소관 — 목표 4 충족. 실측: run-all rl-171/172/173 GREEN, doctor "run-log 당월 집계 EVENTS=n". `RUNLOG_DIR` override로 hermetic 테스트.

## D5. 자율성 안전 (예산·back-pressure·sandbox)

| 레벨 | 앵커 |
|---|---|
| 1 | 무인 루프에 어떤 외부 강제도 없음 (프롬프트-레벨 지시뿐) |
| 2 | goal 문서에 back-pressure 규약(반복 상한·조기 종료) 존재하나 준수가 모델 재량 |
| 3 | 2 + 결정론 iteration/비용 감시(초과 시 표면화) 또는 파괴 명령 OS-백스톱 중 하나 |
| 4 | 토큰/비용/반복 ceiling이 에이전트 밖에서 강제(초과 시 차단) + 자율 구간이 체크포인트로 슬라이스 |
| 5 | 4 + OS sandbox(write/egress deny-by-default) + 위험 표면(deep-research 등) Rule-of-Two 분리 |

**현행 3** — 증거: goal 문서 back-pressure(랩 6라운드 캡·수확체감 중단)와 merge 하드게이트는 존재하나 모델 순응 의존; bypassPermissions(01 §0)로 OS 백스톱 없음. 외부 바: 02 §5 "강제는 에이전트 밖"(Uber·DN42·$47K), 02 §4 METR 80%-horizon 슬라이싱, srt Windows 지원. **목표 4. 델타 1.**
**C3 재채점(2026-07-13, 2→3)**: GAP-002 착륙 — `enforce-session-budget.sh`(PreToolUse `*` catch-all)가 세션당 도구호출 카운터를 **에이전트 밖에서 결정론적으로 감시·초과 시 차단(exit 2)** = Level 3 "결정론 iteration 감시(초과 시 표면화)"를 차단으로 초과 충족. 기본 OFF(SESSION_TOOL_BUDGET opt-in)·80% 경고·GOAL_BUDGET_SKIP 우회·`.budget/<sid>` 카운터·run-log 피기백. Level 4 미달 사유: (c) 자율 구간 체크포인트 슬라이싱 규약이 이 사이클에서 DEFERRED(04 GAP-002 스코프 분할 선언) — ceiling-강제는 있으나 슬라이싱 규약 미완. L5(OS sandbox)는 GAP-007. **실측: run-all sb-180~184 GREEN·verify-setup 73/0·#23 parity. ★라이브 발화는 세션 재시작 후(새 PreToolUse matcher, README 경고) — 로직은 test-proven, 배선은 재시작 의존(정직 선언).**

## D6. 메모리 수명주기

| 레벨 | 앵커 |
|---|---|
| 1 | 메모리 없음 또는 무구조 덤프 |
| 2 | 큐레이션된 파일 메모리(인덱스+토픽), 수명주기 정책 없음(축적 단방향) |
| 3 | 2 + 명문화된 통합/프루닝 규약(주기·기준) + 인덱스 예산 준수 |
| 4 | 3 + 쓰기 검증(포이즈닝·정확성 리뷰) + stale 자동 표면화(참조 검증) |
| 5 | 4 + 백그라운드 통합(sleep-time 등가) + 메모리 회귀 테스트 |

**현행 2** — 증거: MEMORYmd 인덱스+토픽 파일 구조는 Anthropic memory-tool 패턴과 동형(02 §5)이나 통합/decay/프루닝 규약 부재(01 §6-9), 쓰기 리뷰 없음 — 02 §5 "통합 정책 침묵이 프로덕션 실패가 사는 곳"+ASI06 포이즈닝 표면. **목표 4. 델타 2.**

## D7. eval/fitness 인프라

| 레벨 | 앵커 |
|---|---|
| 1 | 테스트 없음 |
| 2 | 단위 테스트만 |
| 3 | 하네스 자체의 메타검증(seal 회귀·fail-open 표면화·전제 게이트) + E2E. 행동 회귀 스위트·transcript 분석 없음 |
| 4 | 3 + 에이전트 행동 회귀 스위트(20-50 과제 or 실패→픽스처 전환 루프) + 세션 인사이트 주기 추출 |
| 5 | 4 + pass^k 신뢰성 지표 + judge 캘리브레이션(인간 라벨 TPR/TNR) |

**현행 3** — 증거: seal-regression·failopen-surface·rpi-prereq·verify-integration E2E 8(01 §3) — 업계-희귀(02 §6). 잔여: 20-50 과제 행동 스위트 없음, 실패 세션→회귀 픽스처 루프 없음(02 §5 LangSmith 패턴), /insights 미사용(02 §1). **목표 4. 델타 1.**

## D8. 이식성 (멀티모델·멀티하네스·신선-클론)

| 레벨 | 앵커 |
|---|---|
| 1 | 단일 머신 전용, 하드코딩 |
| 2 | 설치 스크립트 존재, 검증 없음 |
| 3 | install 전수 게이트 + doctor 진단, 플랫폼 공백 존재 |
| 4 | 3 + 미러 하네스(opencode) 차등 오라클 + acceptance 라운드트립. 잔여: 플랫폼-조건 skip·환경 가정 |
| 5 | 4 + 전 플랫폼 E2E + skill 본문 parity 오라클 + 신선-클론 CI |
 
**현행 4** — 증거: install 29파일 전수+백업 hard-gate, opencode _oracle 차등검증(canonical 파서 서브프로세스 byte-일치)+acceptance zip 라운드트립(01 §3) — 6월 ⑦ 3→4 유지. 잔여: STAGE 3b 비-Windows skip(01 §6-2), `/tmp` MSYS·절대 $HOME source 가정(01 §1 취약), opencode skill 본문 parity 부재(01 §6-5). **목표 4 유지(5는 개인 하네스 ROI 밖 — DOWNGRADE-DECLARED 아님, 스코프 판단: 전 플랫폼 CI는 단일 운영자 가치 대비 유지비 과대. 04에서 재평가 가능). 델타 0.**

## D9. 핸드오프 복원력

| 레벨 | 앵커 |
|---|---|
| 1 | 세션 기억에만 의존 |
| 2 | spec/plan 내구 문서 + read-before 규약 (post-compact 연속성) |
| 3 | 2 + next-cycle-goal 구조화 핸드오프(3라벨 자가-표면화) — 단 이니셔티브-레벨 컨텍스트는 auto-memory(머신-로컬) 의존 |
| 4 | 3 + 이니셔티브 self-contained 플레이북(auto-memory 무참조) + 갱신 계약(사이클마다 상태 동기) |
| 5 | 4 + cold-agent fitness 실증(새 에이전트가 문서만으로 착수 성공) |

**현행 3** — 증거: durable spec/plan+#27 seal+next-cycle-goal 3라벨+#18(01 §3·§4)은 견고하나, 이니셔티브 컨텍스트가 auto-memory 의존(01 §4 기타 — MEMORY.md는 이 머신 로컬). **이 이니셔티브(C0 문서 세트+05 플레이북)가 직접 4로 올리는 중, C-final cold-agent fitness가 5 검증. 목표 5. 델타 2.**

## D10. Best-Direction 충실도 — 신규 (사용자 관찰, goal §4)

| 레벨 | 앵커 |
|---|---|
| 1 | 열화-회피를 막는 어떤 장치도 없음 — Simplicity First가 알리바이로 오독 가능 |
| 2 | 헌법에 스코프 최소주의↔아키텍처 품질 구분 명문화 (프롬프트-레벨) |
| 3 | 2 + plan 템플릿 필수 필드 `Best-Direction Check`(최선안 명시 + DOWNGRADE-DECLARED) — 자가-표면화 |
| 4 | 3 + closeout drift 기준에 silent-downgrade 검출(spec 목표 설계 vs 구현 실물 대조) + 필드 존재 seal |
| 5 | 4 + 교차모델 적대 리뷰가 열화 판정을 정기 반증 |

**현행 4** — 증거: 01 §4 매핑표 — Simplicity First·Think Before Coding 완전 미강제, plan 템플릿·closeout 기준 어디에도 최선안 대조 없음. 사용자 관찰(goal §4 canonical)이 실증 사례. **목표 4. 델타 0 (C1 도달).**
**C0 적대 리뷰 반박 검토**: "Think Before Coding의 'If a simpler approach exists, say so / Surface tradeoffs'가 L1의 '어떤 장치도 없음'을 반증한다"는 공격 — **기각**: 해당 문구는 열화-회피 장치가 아니라 단순-방향 압력이며 스코프/품질을 구분하지 않아 오히려 관찰된 실패의 일부다. L1 유지. 단 GAP-001의 1순위 **1차 근거는 산식이 아닌 spec §4 사용자 고정**임을 명시(델타 3은 부차 근거).
**C1 재채점(2026-07-13, 1→4)**: L2=CLAUDE.md Simplicity First에 "Scope minimalism ≠ architecture downgrade" 구분 명문화 · L3=start-rpi-cycle Phase P 필수 필드 Best-Direction Check(+DOWNGRADE-DECLARED 규약, canonical+opencode 미러) + Gate P "필드 부재=FAIL" · L4=Step C-1 silent-downgrade 실물 대조 기준 + seal #35(토큰 parity, staged-HOME RED x0→GREEN x5/x4 실증). L5(교차모델 정기 반증)는 GAP-006 소관 — 목표 4 충족.

## D11. 보안 (인젝션·공급망·시크릿) — ⚠️ 기준 상승 차원

| 레벨 | 앵커 |
|---|---|
| 1 | 위협모델 없음 |
| 2 | 시크릿 스캔 + 문서화된 위협모델 |
| 3 | 2 + 우회 사용 표면화 + fail-open 신뢰베이스 명시. 잔여: 공급망(skill/플러그인) 무검증·인젝션 표면(웹 읽기 세션) 무분리·OS 백스톱 없음 |
| 4 | 3 + 플러그인/skill 업데이트 diff 리뷰·핀 규약 + 위험 세션 Rule-of-Two 분리 + deny 최후방어선 |
| 5 | 4 + egress 화이트리스트(vault 등가) + 패턴 커버리지 테스트 전수 |

**현행 3** — 증거: enforce-secret-scan+SECURITY.md 신뢰모델+bypass 표면화(01 §1·§4)는 6월 ③=4 근거였으나, 2026.07 외부 바(02 §4: ToxicSkills 13.4% critical·rug-pull·approve-once-trust-forever·NSA 서명/핀 권고; lethal trifecta 상시화)가 공급망·세션 분리를 요구 — **6월 4 → 신기준 3 (기준 상승)**. secret-scan 5/7 패턴 미테스트(01 §6-2)도 잔여. **목표 4. 델타 1.**

## D12. 스캐폴드 노화 관리 — 신규 (02 P12)

| 레벨 | 앵커 |
|---|---|
| 1 | 누적 단방향 — 제거 트리거 없음 |
| 2 | 모델 업그레이드 시 하네스 가정 재점검 체크리스트 존재 (수동) |
| 3 | 2 + skill/가드별 "존재 이유"(어느 실패에 추적되는가) 메타데이터 + 주기 감사에 프루닝 후보 보고 |
| 4 | 3 + 구성요소 단위 A/B 벗겨보기 절차(Anthropic strip-and-measure) 문서화·실행 이력 |
| 5 | 4 + 자동화된 사용/발화 통계 기반 프루닝 제안 (D4 run-log 의존) |

**현행 1** — 증거: 01 §6-10 "제거 메커니즘 없음(누적 단방향)"; 6월 감사 defer 항목(goal §5 dead-scaffold pruning)이 그대로 미해소. 외부 바: 02 §1 Fable 5 공식 가이드 "과처방 skill이 출력 열화 — 리뷰·제거하라" + managed-agents "하네스 가정은 낡는다" — **현행 skill 텍스트가 현 모델 출력을 열화 중일 수 있어 긴급**. **목표 3. 델타 2.**

## 6월 8차원 ↔ v2 12차원 매핑

| 6월 차원 (최종 점수, cycle-37 시점) | v2 차원 | 이월/재채점 |
|---|---|---|
| ① 강제 아키텍처 (4) | D1 | 이월 4 — 잔여 갭 동일(MCP·ERR-센티넬), 신규 증거 없음 |
| ② 검증 파이프라인 (4) | D2·D7 | D2=4 이월(G2-a CI 부재 동일) · D7=3 (②의 메타검증 슬라이스 분리, 행동 스위트 부재로 3) |
| ③ 보안 (4) | D11 (+D5 일부) | **재채점 3 — 기준 상승**(공급망·세션 분리 축 신설, 02 §4 근거) |
| ④ 드리프트 방어 (5) | D2에 흡수 | D2 앵커 4레벨에 seal-회귀 포함 — ④5의 근거(seal-regression)는 D2=4의 핵심 증거로 이월, M1(무봉인 카운트)로 5 미달 |
| ⑤ 수명주기 (4) | D9 (+D1) | D9=3 — ⑤의 RPIC 강제는 유지되나 v2는 이니셔티브-레벨 핸드오프까지 요구(auto-memory 의존이 감점) |
| ⑥ 관측가능성 (4) | D4 | **재채점 3 — 기준 상승**(세션/사이클 run-log 축 신설, 02 §5 근거) |
| ⑦ 재현성 (4) | D8 | 이월 4 — 잔여 갭 동일(플랫폼 skip·환경 가정) |
| ⑧ 컨텍스트 경제 (4) | D3 | **재채점 3 — 오채점 교정**: C0 적대 리뷰가 트리거(550K)↔rot(300-400K) 산술 모순 적발 (기준 상승 아님) |
| — | D5 자율성 안전 | 신규 2 (6월 ④축엔 없던 무인-루프 외부강제 축) |
| — | D6 메모리 수명주기 | 신규 2 |
| — | D10 Best-Direction | 신규 1 (사용자 관찰) |
| — | D12 스캐폴드 노화 | 신규 1 (6월 defer의 승격) |

## 종합표 (2026-07-13 C0 채점)

| 차원 | 현행 | 목표 | 델타 | 비고 |
|---|---|---|---|---|
| D1 강제력 | 4 | 5 | 1 | |
| D2 검증 정직성 | 4 | 5 | 1 | |
| D3 컨텍스트 경제 | 3 | 5 | 2 | 적대 리뷰 교정(트리거↔rot 모순) |
| D4 관측가능성 | 4 | 4 | 0 | **C2 도달** (GAP-003 run-log) |
| D5 자율성 안전 | 3 | 4 | 1 | **C3** (GAP-002 예산 governor); L4=체크포인트 슬라이싱 잔여 |
| D6 메모리 수명주기 | 2 | 4 | 2 | |
| D7 eval/fitness | 3 | 4 | 1 | |
| D8 이식성 | 4 | 4 | 0 | 목표-충족(스코프 판단) |
| D9 핸드오프 복원력 | 3 | 5 | 2 | 이 이니셔티브가 직접 상승 중 |
| **D10 Best-Direction** | **4** | **4** | **0** | **C1 도달(2026-07-13)** — L5는 GAP-006 소관 |
| D11 보안 | 3 | 4 | 1 | 기준 상승(6월 4) |
| **D12 스캐폴드 노화** | **1** | **3** | **2** | Fable 5 가이드 직접 충돌 |

**min = 1 (D12)** (C1 D10 1→4, C2 D4 3→4, C3 D5 2→3 해소). C0 시점 min=1(D10·D12)은 축 확장(신규 4축)·기준 상승(D4·D11)·오채점 교정(D3)의 결과였다. 잔여 우선 델타: D3·D6·D9·D12(2) > D1·D2·D5·D7·D11(1) > D4·D8·D10(0). 다음 착수(C4) 후보: 델타 2 중 레버리지 = **GAP-005 스캐폴드 노화**(D12, 유일 min=1 해소·Fable 5 가이드 충돌 긴급) 또는 GAP-004 메모리 수명주기(D6).
**채점 방법론 노트**: C0 채점은 fresh-context 적대 리뷰(refute-by-default, 동일 패밀리·별도 컨텍스트)를 1회 통과 — 7건 발견 중 점수 교정 1(D3 4→3), 잔여 명시 1(D1), 반박-기각 1(D10), 순위·기준 정정은 04에 반영. 교차패밀리 리뷰는 인프라 실패로 GAP-006에 위임(README 방법론 기록).
