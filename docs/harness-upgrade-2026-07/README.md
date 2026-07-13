# harness-upgrade-2026-07 — 이니셔티브 문서 세트

Fable 5 가용 종료 전 수행한 **하네스 전수 재감사 + 2026.07 외부표준 업그레이드 로드맵**. 이 디렉터리는 self-contained — 이후 모델(Opus 등)은 이 문서만으로 작업을 이어받는다 (이 머신의 auto-memory 불필요).

## 읽기 순서

| 순서 | 문서 | 무엇 | 언제 읽나 |
|---|---|---|---|
| 1 | **[05-playbook.md](05-playbook.md)** | 운영 규약·착수 절차·함정·롤백 | **항상 먼저** — 작업 재개의 진입점 |
| 2 | **[04-gap-backlog.md](04-gap-backlog.md)** | 갭 19항목(순위·증거·수용 기준·RED) | 착수 항목 선택 시 해당 블록 |
| 3 | [03-rubric.md](03-rubric.md) | 루브릭 12차원(앵커·채점·재채점 절차) | 사이클 closeout 재채점 시 |
| 4 | [01-structure-map.md](01-structure-map.md) | 하네스 전수 실측(4계층·불일치·미강제) | GAP의 증거 원천 확인 시 발췌 |
| 5 | [02-standards-digest.md](02-standards-digest.md) | 2026.07 외부표준(인용 전수·공통패턴 표) | 설계 판단의 외부 근거 확인 시 발췌 |

durable spec: [`docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md`](../superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md)

## 이니셔티브 상태

| 사이클 | 내용 | 상태 |
|---|---|---|
| **C0** | 문서 세트 6종(재감사+로드맵+플레이북) | **완료 (2026-07-13, RPI-Cycle 49 — 동시 세션 ui-design C1=48 선점 반영)** |
| **C1** | GAP-001 Best-Direction Mandate(4층) + GAP-009 정합·seal #35/#36 | **완료 (2026-07-13, RPI-Cycle 50)** — D10 1→4, verify-setup 70→72 |
| **C2** | GAP-003 사이클 run-log (JSONL gen_ai.*·runlog_summary·doctor 20e; G6-b/G3-a 흡수) | **완료 (2026-07-13, RPI-Cycle 52)** — D4 3→4, run-all 156→159 |
| **C3** | GAP-002 자율성 예산 governor (enforce-session-budget hook, tool-call ceiling) | **완료 (2026-07-13, RPI-Cycle 53)** — D5 2→3, hook 10→11, verify-setup 72→73. (b)(c) DEFERRED |
| **C-final** | 핸드오프 봉인 — cold-agent fitness + 문서 결함 6건 회귀 수정 + 루브릭 before/after | **완료 (2026-07-13)** — fitness COULD_START(질문 0회) |
| **C4** | GAP-005 스캐폴드 노화 (registry + verify-setup #37 parity seal + 프루닝 단계 + 과처방 감사) | **완료 (2026-07-13, RPI-Cycle 55)** — D12 1→3, **마지막 min=1 해소**, verify-setup 73→74 |
| **C5** | GAP-004 메모리 수명주기 (memory-policy + 인덱스 예산/dangling ALERT + #38 seal + improve-arch 감사 단계) | **완료 (2026-07-14, RPI-Cycle 53)** — D6 2→4, **전 차원 진짜 ≥3 실현**, verify-setup 74→75, run-all 164→168. GAP-014 병합 |
| **C6** | GAP-018 autocompact 트리거 재캘리브 (settings.example 40 + doctor rot-정렬 + #39 seal + auto-compact-watch rot-timing) | **완료 (2026-07-14, RPI-Cycle 54)** — D3 3→4(L4 트리거 rot 이전), verify-setup 75→76, run-all 168→170. 라이브 PCT=per-machine 지연 |
| C7.. | 04 순위순 (GAP-006 교차모델 → GAP-011/013 보안 → GAP-010 커버리지 → …) | 대기 — **다음 착수 = GAP-006**(D2/D10 L5 교차모델 검증자, ccs 인프라 해소 후) 또는 GAP-010/011(보안·커버리지) |

**루브릭 현황 (C6 재채점)**: **min=3 — 전 12차원 진짜 ≥3** (C1 D10·C2 D4·C3 D5·C4 D12·C5 D6·**C6 D3** 개선). C5가 마지막 <3 차원(D6) 해소로 '전 차원 ≥3' 실현, C6가 D3 3→4(L4). 현행 min-3 차원: D5·D7·D9·D11. 상세는 03 종합표. 잔여 델타(목표까지): D5·D7·D9·D11 + D3/D9의 L5.
**라이브 배선 주의(C3)**: `enforce-session-budget`는 `settings.example.json`에 배선됨(tracked). 각 머신의 라이브 `settings.json`은 hook 파일 도착 후 동기 필요(install.sh 병합 또는 수동) — 새 PreToolUse `*` matcher는 세션 재시작 후 발화. `SESSION_TOOL_BUDGET` 미설정 시 무영향(기본 OFF).

## 방법론 기록 (정직성)

- 리서치 6축·인벤토리 4축은 2026-07-13 fresh 실측(README·기억 불신뢰 원칙). 상충·검증 실패는 02 §9에 전수 기록.
- **교차패밀리 적대 리뷰**: C0에서 3프로필 시도·전부 실패 — `ccs glm`(프로필 부재), `ccs codex`(400 "reasoning: Extra inputs are not permitted" — 프록시↔gpt-5.6 파라미터 비호환), `ccs kimi`(대화형 디바이스-코드 인증 필요, 무인 모드 불가). spec §5 규약대로 사유 기록 후 **fresh-context 적대 리뷰(동일 패밀리·별도 컨텍스트·refute-by-default)로 대체** — 02 §1의 "fresh-context 외부 평가가 자기리뷰를 이김" 근거로 부분 완화이지 동등물 아님(agreement bias 잔존을 인정). 교차패밀리 재시도는 GAP-006에 위임(프록시 파라미터 이슈 해소 후).
- **fresh-context 적대 리뷰 결과(C0)**: 7건 발견·전부 반영 — 점수 교정 1(D3 4→3: 트리거 550K↔rot 300-400K 산술 모순), 잔여 명시 1(D1 마커-제거 우회), 반박-기각 1(D10=1 유지), 순위 정정(산식 tie-break 재선언+스왑), 수용 기준 강화 4건(GAP-005/006/008/010), 신규 갭 2(GAP-018 트리거 재캘리브레이션·GAP-019 skill 본문 seal). 상세는 03 방법론 노트·04 각 블록.
- 이 문서 세트의 계약 검증: review-strict가 spec §2 표 기준 항목별 PASS 판정(C0 closeout 기록).
- **cold-agent fitness 결과(C-final, GAP-008 수용)**: 컨텍스트 0인 fresh 에이전트에 05+04만 주고 GAP-005 startup packet(사이클 규약·plan 초안·RED 커맨드·함정) 생산 지시 → **COULD_START**(두 필수 산출물을 후속질문 0회로 생산 = fitness 바 ≤2 통과). 동시에 문서 결함 6건 포착(사이클번호 규약 부재·기준선 stale·GAP-005 카운트 불일치·브랜치명 미규정·참조정책 모호·GAP-005 L4-blocker stale) → **C-final에서 전부 회귀 수정**(playbook §1/§3/§5+상단, 04 GAP-005). 이것이 fitness 루프의 설계 목적(사이트가 아닌 문서의 결함 검출).

## 다음 착수 지정 (C7+)

C0~C6 완료로 **전 차원 진짜 ≥3**(C5 D6 2→4·C6 D3 3→4). 이제 **목표(≥4~5) 도달 사이클**로 진입. 다음 착수 = **GAP-006 (교차모델 검증자)** — D2/D10 L5(고-스테이크 판정 교차패밀리 라우팅; ccs 인프라 해소 필요 — 미해소 시 DEFERRED 처분) 또는 **GAP-011/013 (공급망·세션 분리 보안)** — D11 3→4. 착수 = `05-playbook.md` §2 절차 → 브랜치 `harness-upgrade-c7` → 04 해당 GAP 블록. 이후: GAP-010(커버리지)·GAP-012(회귀픽스처)·GAP-019(skill 본문 seal)·GAP-007(OS sandbox)·D3/D9 L5(창-매핑 auto-safe·캐시 hit-rate·핸드오프).
