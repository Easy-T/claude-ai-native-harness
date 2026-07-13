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
| C3.. | 04 순위순 (GAP-002 예산 governor → GAP-005 스캐폴드 노화 → GAP-004 메모리 → GAP-018 트리거 → …) | 대기 — **다음 착수 = GAP-002**(run-log 기반 마련됨) |
| C-final | 핸드오프 봉인(최종 재채점·cold-agent fitness·최종 보고) | 대기 |

**루브릭 현황 (C2 재채점)**: min=1 (D12 스캐폴드 노화 — D10·D4는 C1·C2에서 4 도달). 상세는 03 종합표. 6월 감사 대비 축 4개 신설 + 기준 상승 2건(D4·D11)이며 6월 종결 항목의 회귀는 없음.

## 방법론 기록 (정직성)

- 리서치 6축·인벤토리 4축은 2026-07-13 fresh 실측(README·기억 불신뢰 원칙). 상충·검증 실패는 02 §9에 전수 기록.
- **교차패밀리 적대 리뷰**: C0에서 3프로필 시도·전부 실패 — `ccs glm`(프로필 부재), `ccs codex`(400 "reasoning: Extra inputs are not permitted" — 프록시↔gpt-5.6 파라미터 비호환), `ccs kimi`(대화형 디바이스-코드 인증 필요, 무인 모드 불가). spec §5 규약대로 사유 기록 후 **fresh-context 적대 리뷰(동일 패밀리·별도 컨텍스트·refute-by-default)로 대체** — 02 §1의 "fresh-context 외부 평가가 자기리뷰를 이김" 근거로 부분 완화이지 동등물 아님(agreement bias 잔존을 인정). 교차패밀리 재시도는 GAP-006에 위임(프록시 파라미터 이슈 해소 후).
- **fresh-context 적대 리뷰 결과(C0)**: 7건 발견·전부 반영 — 점수 교정 1(D3 4→3: 트리거 550K↔rot 300-400K 산술 모순), 잔여 명시 1(D1 마커-제거 우회), 반박-기각 1(D10=1 유지), 순위 정정(산식 tie-break 재선언+스왑), 수용 기준 강화 4건(GAP-005/006/008/010), 신규 갭 2(GAP-018 트리거 재캘리브레이션·GAP-019 skill 본문 seal). 상세는 03 방법론 노트·04 각 블록.
- 이 문서 세트의 계약 검증: review-strict가 spec §2 표 기준 항목별 PASS 판정(C0 closeout 기록).
