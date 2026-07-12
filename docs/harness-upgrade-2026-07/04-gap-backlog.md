# 04 — 갭 백로그 (2026-07-13)

> 순위 산식: **레버리지(다른 차원·갭을 몇 개 unblock하는가) × 루브릭 델타(03)**; **동률(tie) 시에만 severity/긴급도로 세분**. **구현 난이도는 순위에 불반영** — 난이도는 "사이클 분할" 필드에만 반영한다(goal §4 Best-Direction 정신; 어렵다고 뒤로 밀지 않는다). GAP-001의 1순위만 예외적으로 산식이 아닌 **spec §4 사용자 고정**이 1차 근거다.
> 각 항목은 self-contained: 이 문서 + 01/02/03 + 05-playbook만으로 착수 가능해야 한다. 증거 표기는 01/02/03 문서 섹션 참조(원 file:line은 01에 보존).
> 상태: `PENDING` → `IN-CYCLE(Cn)` → `DONE(Cn, commit)` / `DEFERRED(사유)` / `REJECTED(사유)`. 구현 사이클마다 이 파일의 상태·03 재채점·README 상태를 같은 PR에서 갱신(spec §2 갱신 계약).
> **C0 적대 리뷰(2026-07-13) 반영**: 순위 스왑(구 5↔6), 산식 tie-break 재선언, GAP-018·019 신설, GAP-005/006/008/010 수용 기준·서술 정정 — 각 항목 블록에 개별 표기.

## 우선순위 요약

| 순위 | ID | 제목 | 차원(델타) | 레버리지 | 상태 |
|---|---|---|---|---|---|
| 1 | GAP-001 | Best-Direction Mandate | D10(3→0) | 전 후속 사이클의 plan 품질에 작용 | **DONE(C1, 2026-07-13)** — 4층 전부: CLAUDE.md 정련·Phase P 필드+Gate P·C-1 silent-downgrade·seal #35(RED→GREEN) |
| 2 | GAP-003 | 사이클 run-log (관측 기반) | D4(1→0) | D5 예산 측정·D7 인사이트·D12 사용통계·GAP-002/005/012를 unblock — 최대 레버리지 | **DONE(C2, 2026-07-13)** — run_log_event JSONL(gen_ai.*)+runlog_summary+doctor 20e; G6-b/G3-a 흡수(아래) |
| 3 | GAP-002 | 자율성 예산 governor | D5(2) | 무인 goal-loop 전체의 안전 상한 — 이 이니셔티브 자신이 무인 | PENDING |
| 4 | GAP-005 | 스캐폴드 노화 관리 | D12(2) | 전 skill/hook/seal 표면에 작용; Δ2 동률 내 tie-break=긴급도(Fable 5 가이드 직접 충돌) | PENDING |
| 5 | GAP-004 | 메모리 수명주기 정책 | D6(2) | 포이즈닝 방어+rot 방지 — 메모리 소비 전 세션에 작용 (Δ2 — 적대 리뷰로 구 5위 GAP-006과 스왑) | PENDING |
| 6 | GAP-018 | autocompact 트리거 재캘리브레이션 | D3(2)의 주 레버 | 전 장기 세션의 rot 노출 — 550K→rot-이전(≤400K)으로; D3 L4 anchor의 직접 요건 | PENDING — **신설(적대 리뷰 발견 1)** |
| 7 | GAP-006 | 교차모델 검증자 분리 | D2(1)+D10 L5 | 자기채점 편향의 구조 해소 — 전 [모델-판단] 게이트 신뢰도에 작용 | PENDING |
| 8 | GAP-011 | skill/플러그인 공급망 규약 | D11(1)의 절반 | 신뢰 경계 — superpowers 등 20+ 외부 skill 전체 | PENDING |
| 9 | GAP-013 | Rule-of-Two 세션 분리 | D11(1)의 절반+D5 | 인젝션 표면 구조 분리; GAP-012와 레버리지 동률로 판정, tie-break=severity(심도) | PENDING |
| 10 | GAP-012 | 실패→회귀픽스처 루프 | D7(1) | eval 인프라의 마지막 층 — 발생 빈도 의존 | PENDING |
| 11 | GAP-019 | skill/agent 본문 drift seal + ccs-delegation 계약 연결 | D1·D2 보조 | 드리프트 방어의 자기적용(하네스 정체성) — GAP-006이 의존하는 ccs-delegation의 무계약 해소 포함 | PENDING — **신설(적대 리뷰 발견 7)** |
| 12 | GAP-009 | 문서↔실물 정합 일괄 + 카운트 seal | D2(1)의 일부 | quick-win — 어느 사이클에나 부수 가능 | **DONE(C1, 2026-07-13)** — M1-M8 정정(M4/M9/M10 의도기록 유지) + seal #36(런타임 자기-카운트 parity, RED 66≠72→GREEN 72==72) |
| 13 | GAP-010 | 미테스트 표면 커버 | D1(1)의 일부 | 알려진 공백의 봉인(커버 목록은 항목 블록 — "전수" 주장 정정) | PENDING |
| 14 | GAP-015 | MCP 쓰기 게이트 | D1(1)의 일부 | 6월 G1-a 계승 — MCP 사용 빈도가 낮아 레버리지 중간 | PENDING |
| 15 | GAP-014 | MEMORY.md 인덱스 예산 seal | D3(1)의 일부 | 저비용 — GAP-004에 병합 가능 | PENDING |
| 16 | GAP-016 | 사이클 proof-artifact 규약 | D7 보조 | 6월 defer 계승 — GAP-003 run-log가 사실상 대체 가능(재평가) | PENDING |
| 17 | GAP-007 | OS-레벨 sandbox 층 | D5 L5·D11 L5 | 상한 확장 — GAP-002가 D5=4를 먼저 달성하므로 후순위(레버리지 순서이지 난이도 아님) | PENDING |
| 18 | GAP-017 | seal-regression Part B (rank9B) | D2 보조 | 6월 defer — 대표 변이 3종 커버로 한계효용 낮음 | PENDING(재평가) — **C1 판정: 대표 변이 미추가.** 사유: #35=토큰-존재형(기존 #17류와 동형 — 대표 변이가 이미 count/parity/schema 3유형 커버), #36=런타임 자기-카운트형(신유형이나 RED가 staged-HOME에서 직접 실증됨 — seal-regression 우회 불필요). 차기 신유형 seal 등장 시 재평가 유지 |
| — | GAP-008 | 핸드오프 복원력 완성 | D9(2) | — | **IN-CYCLE(C0/C-final)** — 이 이니셔티브 자체가 해소 |

**D8(이식성) 처분 명시** (적대 리뷰 발견 5 — 03이 "04에서 재평가 가능"으로 위임한 잔여): 전-플랫폼 CI는 **REJECTED(개인 규모 ROI — 03 D8 스코프 판단 승인)**. 단 D8 잔여 중 실결함 2건은 기존 항목에 편입: 비-Windows STAGE 3b skip → GAP-010 커버 목록, opencode skill 본문 parity → GAP-019. `/tmp`·절대 $HOME source 가정은 관찰 기록만(발화 조건이 "하네스 재배치"뿐이라 백로그 미승격 — 재배치 시 GAP-009류 정합 작업에 동반).

6월 defer 잔여 매핑(전수): goal-loop 예산→GAP-002 · observability/run-log→GAP-003 · dead-scaffold pruning→GAP-005 · sandbox/권한 티어→GAP-007 · proof-artifact→GAP-016 · G6-b(fail-open 표면화 3번째 조각, 정의는 `docs/superpowers/specs/2026-06-13-external-standards-audit.md` §D⑥)→GAP-003에 흡수 재평가 · G3-a 잔여(우회 실시간 표면 — rev2 #3이 additionalContext 표면화로 부분 해소)→GAP-003에 흡수 · rank9B→GAP-017.

## GAP-018 — autocompact 트리거 재캘리브레이션 ★신설(C0 적대 리뷰)

- **차원**: D3(3→5의 주 레버, Δ2) · **severity**: MED-HIGH · **상태**: PENDING
- **증거**: 03 D3 교정 기록 — 현행 트리거 55%×1M=550K vs rot 실증 시작 ~300-400K(02 §5 Chroma·커뮤니티 실측)·dumb-zone 40%=400K(02 §4 Horthy). 무인 장기 세션이 rot 구간(400-550K)에서 150K어치를 열화 상태로 작업.
- **목표 상태**: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`를 rot-이전(≤40%, 1M 기준 ≤400K)으로 하향 + auto-compact-watch 경고 임계 동기 + 하향이 무인 goal-loop의 compact 빈도·연속성(read-before 재주입)에 주는 영향 실측 1세션.
- **Best-direction 근거**: 더 쉬운 대안 = "55% 유지(과거 죽음의-나선 트라우마 회피)" — 그 나선의 원인은 창 오인식(1M→200K 붕괴)이지 트리거 %가 아니었다(settings 이력). 수치를 외부 실증(rot 곡선)에 정렬하는 것이 최선이며, RPI 하네스의 post-compact 연속성(spec·plan 재주입)이 이미 compact 비용을 흡수한다.
- **구현 스케치**: settings.json PCT 55→40 + settings.example parity(#23 주의 — 단 env 값은 hook parity 대상 아님을 확인) + auto-compact-watch 기본값 서술 정정(M7 겸) + 1세션 관찰 기록.
- **수용 기준**: settings 값 40 확인 && `/context` 트리거 표시 ~400K && 관찰 세션에서 compact 후 작업 연속성 유지 기록.
- **테스트 계획(RED)**: 현행 55%에서 auto-compact-watch 경고가 400K+에서만 발화함을 확인(rot 구간 무경고 = RED 상태 그 자체) → 하향 후 조기 발화 확인.
- **복잡도**: 저 · **의존성**: 없음 · **Opus-실행성**: 높음. 함정: WINDOW=1M 인식이 전제(플레이북 §5-5 `[1m]` suffix) — 창이 200K로 붕괴한 상태에서 40%를 적용하면 80K 트리거로 과빈발.

## GAP-019 — skill/agent 본문 drift seal + ccs-delegation 계약 연결 ★신설(C0 적대 리뷰)

- **차원**: D1·D2 보조 · **severity**: MED · **상태**: PENDING
- **증거**: 01 §6-4(start-rpi-cycle 외 skill 6종+design.md 본문 무봉인·agents/*.md 프롬프트 무검사)·§6-5(opencode skill 본문 parity 부재)·01 §2 표(ccs-delegation: README 부재+계약 무연결+위임 결과 무검증 — GAP-006의 교차모델 리뷰가 이 무계약 컴포넌트에 의존하는 모순).
- **목표 상태**: (a) 각 skill 본문의 load-bearing 토큰(위임 대상 agent명·필수 필드명·게이트 문구)에 #17-동형 content seal — 전문 봉인이 아닌 앵커 토큰만(전문 봉인은 편집 마찰 과대) (b) agents/*.md의 계약 문구 parity (c) ccs-delegation에 result/evidence/unknowns 계약 연결(M3의 README 등재는 GAP-009와 공동) (d) opencode 미러 skill의 대응 토큰 동기 검사.
- **Best-direction 근거**: 더 쉬운 대안 = "skill은 자주 안 바뀌니 방치" — #17이 존재하는 이유(§3↔skill 드리프트 실사고)가 그대로 반증. 하네스의 핵심 정체성(drift seal)이 자기 skill에 미적용인 상태는 self-consistency 결함.
- **수용 기준**: 신규 seal이 skill 6종 각각의 앵커 토큰 검사 && seal-regression 패턴으로 토큰 제거 변이 시 FAIL 증명 && ccs-delegation SKILL.md에 Communication Protocol 섹션 grep.
- **테스트 계획(RED)**: 변이 복제본(앵커 토큰 제거)에서 신규 seal FAIL → 원본 PASS.
- **복잡도**: 중 · **의존성**: GAP-009(README 정합)와 같은 사이클 권장 · **Opus-실행성**: 높음 — #17 구현이 템플릿. 함정: ccs-delegation SKILL.md 편집은 enforce-orchestrator 게이트 비대상(orchestrator 마커 없음)이나 새로 Communication Protocol을 넣어도 마커를 추가하지 않는 한 골격 요구 미발동 — 마커 추가 여부는 skill 성격(위임형 아님)상 불필요로 판정.

---

## GAP-001 — Best-Direction Mandate ★C1 고정

- **차원**: D10(1→4, Δ3) · **severity**: HIGH · **상태**: PENDING
- **증거**: 03 D10(현행 1 — 01 §4 매핑표: Simplicity First 등 미강제, plan 템플릿·closeout에 최선안 대조 없음); 사용자 관찰 원문 = spec §4 canonical.
- **목표 상태**: (i) CLAUDE.md에 스코프 최소주의↔아키텍처 품질 구분 명문화 (ii) start-rpi-cycle plan 템플릿에 `Best-Direction Check` 필수 필드(최선안 + 채택안 + 다르면 `DOWNGRADE-DECLARED(사유)`+사용자 승인) (iii) closeout drift 기준에 silent-downgrade 항목 (iv) 필드 존재 seal.
- **Best-direction 근거**: 더 쉬운 대안 = "CLAUDE.md에 한 줄 추가"(prose-only) — 01 §0의 하네스 자체 교리("프롬프트는 권고일 뿐")가 그 대안을 기각한다. 자가-표면화(필수 필드)+drift 검출+seal의 4층이 이 하네스에서 물리 강제 불가 지점의 검증된 상한 패턴(harness-verify·next-cycle-goal 선례).
- **구현 스케치**: ① CLAUDE.md 헌법 수정은 **§1 캐시 규칙 준수 — 세션 종료 직전에만** + 사용자 diff 보고(무인 모드에서는 diff를 사이클 보고에 포함하고 다음 세션 시작 전 반영). Simplicity First 절에 "스코프를 깎는 것이지 채택한 설계의 품질을 깎는 것이 아니다; 알려진 최선안과 다른 채택은 DOWNGRADE-DECLARED 필수" 삽입. ② `skills/start-rpi-cycle/SKILL.md` Phase P에 Best-Direction Check 필드 규약 추가(Gate P success_criteria에 "필드 부재=FAIL" 추가). ⚠️ enforce-orchestrator가 SKILL.md 쓰기를 게이트 — 골격(Phase ≥3·Agent() ≥1·Communication Protocol) 유지. ③ Step C-1 drift review success_criteria에 "spec 목표 설계 vs 구현 실물 대조 — 미신고 열화 FAIL" 추가. ④ verify-setup에 seal 신설(#35 예상): start-rpi-cycle 본문에 `Best-Direction Check`·`DOWNGRADE-DECLARED` 토큰 존재 parity(#17 동형).
- **수용 기준**: `grep -c 'Best-Direction Check' skills/start-rpi-cycle/SKILL.md` ≥2(Phase P+Gate P) && `grep -c 'DOWNGRADE-DECLARED' skills/start-rpi-cycle/SKILL.md` ≥1 && verify-setup 신규 seal PASS && `bash setup/verify-setup.sh` 전건 PASS && run-all 156+ 전건.
- **테스트 계획(RED)**: seal 추가 전 `bash setup/verify-setup.sh`가 71번째 체크 부재 확인 → seal 구현 → SKILL.md에서 토큰 제거한 복제본으로 seal이 FAIL함을 seal-regression 패턴으로 증명(임시 $HOME 복제 변이).
- **복잡도**: 중 (4파일: CLAUDE.md·SKILL.md·verify-setup.sh·README) · **의존성**: 없음 · **사이클 분할**: 단일 C1.
- **Opus-실행성**: 높음 — 4층 전부 기존 패턴(#17 seal·필수 필드) 복제. 함정: enforce-orchestrator 골격, CLAUDE.md 수정 타이밍(§1), README hook/skill 표 갱신 시 seal #17-#22 연쇄 확인.

## GAP-002 — 자율성 예산 governor

- **차원**: D5(2→4, Δ2) · **severity**: HIGH · **상태**: PENDING
- **증거**: 03 D5(외부 강제 0 — 01 §6-8); 02 §5(Uber 캡·DN42·$47K — "강제는 에이전트 밖", 프롬프트-레벨 한도는 "과제 동기가 생기면 무시됨"); 02 §4 METR(80%-horizon=50%의 1/5 → 무감독 구간 1-3h 슬라이스).
- **목표 상태**: goal-loop/무인 세션에 **에이전트 밖 결정론 ceiling**: (a) 세션당 tool-call 카운터(PreToolUse hook이 증분, 임계 초과 시 exit 2 차단 + `GOAL_BUDGET_SKIP` 명시 우회) (b) 사이클당 반복 상한(동일 커맨드 N회 실패 시 표면화) (c) goal 문서에 체크포인트 슬라이싱 규약(METR 80%-horizon 근거).
- **Best-direction 근거**: 더 쉬운 대안 = goal 프롬프트에 "토큰 아껴" 지시(현행) — 02 §5가 실증 기각(프롬프트-레벨 실패 사례 3건). PreToolUse 차단이 이 하네스의 검증된 강제 프리미티브이고, 카운터는 `/tmp` 세션 마커 패턴(_common.sh) 재사용으로 아키텍처 일관.
- **구현 스케치**: 신규 hook `enforce-session-budget.sh`(PreToolUse, matcher 전체) — 세션 마커 파일에 카운터, 기본 OFF(`SESSION_TOOL_BUDGET` env 설정 시만 활성 — goal-loop 킥오프가 설정). 임계 80%에서 additionalContext 경고, 100%에서 차단+우회 안내. settings.json 배선 + settings.example parity(#23 발화 주의) + cases.tsv 케이스 추가(#20 발화) + README hook 표 11종째(M-系 갱신).
- **수용 기준**: `SESSION_TOOL_BUDGET=5`로 6번째 도구 호출이 exit 2 + 메시지에 `GOAL_BUDGET_SKIP` 안내 && 미설정 세션 무영향(전 기존 케이스 GREEN) && run-all 신규 케이스 ≥4(미설정/경고/차단/우회) && verify-setup #23 PASS.
- **테스트 계획(RED)**: hook 부재 상태에서 신규 케이스 4종이 FAIL(기대 차단 미발생) → 구현 → GREEN. run-all 카운트 SSOT(cases.tsv·README·#20) 동기.
- **복잡도**: 중 · **의존성**: GAP-003과 마커 포맷 공유하면 시너지(선행 불필요) · **사이클 분할**: 단일.
- **Opus-실행성**: 높음 — enforce-rpi-bash가 구조 템플릿. 함정: PostToolUse가 아닌 PreToolUse여야 차단 가능; matcher 광역이라 성능(파일 touch 1회/호출) 주의; 동시-세션 격리(SID-키 마커, CONTEXT.md 규약).

## GAP-003 — 사이클 run-log (관측 기반)

- **차원**: D4(3→4, Δ1) · **severity**: MED(레버리지 HIGH) · **상태**: PENDING
- **증거**: 03 D4(hook_log 로컬뿐 — 01 §6-7); 02 §5(OTel gen_ai 속성 코어 안정·"사고 대부분 도구 실패·컨텍스트 절단·폭주"·트레이스→회귀픽스처 루프); 6월 G6-b·G3-a 잔여의 흡수처.
- **목표 상태**: 사이클/세션 단위 구조화 run-log(JSONL): 게이트 발화·차단·우회(RPI_SKIP 등) 사용·FAILOPEN — 필드명 `gen_ai.*` 정렬(tool.name, operation.name 등) + closeout Step C-1이 요약 소비(사이클 보고에 통계 1줄) + doctor가 이상 패턴(우회 급증 등) ALERT.
- **Best-direction 근거**: 더 쉬운 대안 = hook_log 텍스트 grep(현행 log_summary) — 세션 경계·집계·이식(OTel 백엔드)이 불가. JSONL+표준 필드는 02 §5 "[INFERENCE] 지금 정렬해두면 백엔드 이식 무료"의 직접 이행이며 GAP-002(예산 측정)·GAP-005(사용 통계)·GAP-012(픽스처 원천)의 기반.
- **구현 스케치**: `_common.sh`에 `run_log_event()` 추가(hook_log 병행, `hooks/.runlog/<date>.jsonl` append, gitignored) → 각 hook의 판정 지점에 1줄 삽입(차단/우회/FAILOPEN — 기존 hook_log 호출부와 동일 지점) → `log_summary` 확장(사이클 통계) → closeout 규약에 소비 단계. 스키마 문서화(SECURITY.md 또는 신규 `hooks/RUNLOG.md`).
- **수용 기준**: 격리 $HOME에서 차단·우회·통과 각 1회 유발 후 `jq -s 'length' hooks/.runlog/*.jsonl` ≥3 && 각 이벤트에 `gen_ai.tool.name`·`verdict` 필드 && run-all 기존 전건 GREEN(로깅이 판정 무영향) && log_summary가 카운트 출력.
- **테스트 계획(RED)**: run-all에 runlog 단언 케이스 추가 — 구현 전 파일 부재로 FAIL → 구현 후 GREEN. FAILOPEN 경로는 failopen-surface.test.sh 확장.
- **복잡도**: 중 · **의존성**: 없음(GAP-002·005·012가 이것에 의존) · **사이클 분할**: 단일.
- **Opus-실행성**: 높음. 함정: hook은 성능 민감(PreToolUse 매 호출) — append-only 1줄 write로 제한; JSON 조립은 node 아닌 printf(파서 의존 최소화, fail-open 원칙 — 로깅 실패가 판정을 막으면 안 됨 `|| true`).
- **DONE(C2, 2026-07-13)**: `_common.sh` `run_log_event`(printf JSONL, `_json_escape`, `RUNLOG_DIR` override)를 `hook_log` 초크포인트에 피기백 → 4 차단 hook `RL_SID`/`RL_TOOL` export(rpi-cycle/rpi-bash/orchestrator 스폰 0, secret-scan +1). `runlog_summary` 소비(doctor 20e: 로테이션+FAILOPEN>0 WARN, start-rpi-cycle Step C-1 사이클 보고). `hooks/RUNLOG.md` 스키마. RED(run-all rl-171/172/173 FAIL, functions 부재)→GREEN(159/159, doctor "run-log 당월 집계"). **RED 실제 구현 = 3 대표 케이스**(04 초안의 failopen-surface 확장 대신 — FAILOPEN은 피기백으로 자동 포착, 별도 확장 불요). **doctor 이상탐지 포함**(초안 SKILL.md-only에서 04 목표 완주로 확장 — Best-Direction). **opencode 미러 미터치**(claude-hooks 전용 기능, 별도 이니셔티브).
  - **G6-b 흡수(6월 defer, fail-open 표면화 3번째 조각)**: FAILOPEN verdict가 이제 JSONL로도 구조화 기록 + doctor 20e가 FAILOPEN>0을 WARN으로 능동 표면화(session-start-audit 런타임 ALERT에 더해 집계 레벨 표면 완성). **DONE**.
  - **G3-a 흡수(우회 실시간 표면 잔여)**: RPI_SKIP/SECRET_SCAN_SKIP 우회가 이제 `reason:"skip:..."`로 JSONL 기록 + runlog_summary SKIP 카운트 + doctor 집계 노출(rev2 #3 additionalContext 실시간 표면에 더해 사후 집계 표면 완성). **DONE**.
  - **GAP-016(proof-artifact) 처분 카운트다운 개시**: run-log 착륙 → 사이클 보고 게이트 통계 고정 포맷이 사실상 proof-artifact. C3 closeout까지 GAP-016 DONE(흡수)/REJECTED 판정 기록 필요.

## GAP-004 — 메모리 수명주기 정책

- **차원**: D6(2→4, Δ2) · **severity**: MED · **상태**: PENDING
- **증거**: 03 D6(축적 단방향 — 01 §6-9); 02 §5("통합 정책 침묵이 프로덕션 실패가 사는 곳"·Mem0 OSS TTL 없음=수명주기는 사용자 책임·ASI06 포이즈닝·MEMORY.md 첫 200줄/25KB만 로드).
- **목표 상태**: (a) 명문 규약: 통합(중복 병합)·프루닝(비참조 N사이클 후 archive)·검증(참조 파일/커밋 실재 확인) 주기 = improve-codebase-architecture 5-사이클 리듬에 편승 (b) 쓰기 검증: 메모리 파일 신규/수정 시 출처(세션·사이클) 명기 규약 (c) stale 표면화: session-start-audit이 MEMORY.md 크기/줄수 예산 초과 ALERT.
- **Best-direction 근거**: 더 쉬운 대안 = "가끔 수동 정리"(현행 암묵) — 02 §5가 실패 모드로 명명. 반대 극단(벡터DB·Letta 이식)은 개인 파일-메모리 규모에 과잉(YAGNI — 스코프 판단이지 품질 열화 아님). 파일-기반 유지 + 수명주기 규약 명문화가 Anthropic memory-tool 패턴(02 §5)과 정렬된 최선.
- **구현 스케치**: CLAUDE.md 메모리 절 또는 별도 `memory-policy.md`(글로벌 시스템 프롬프트가 메모리 규약을 이미 주입하므로 하네스 문서로) + session-start-audit에 예산 체크 추가(200줄/25KB 임계 ALERT) + run-all 케이스.
- **수용 기준**: 격리 $HOME에서 201줄 MEMORY.md로 session-start-audit ALERT 발화 && 정책 문서에 통합/프루닝/검증 3규약 grep && run-all 신규 케이스 GREEN.
- **테스트 계획(RED)**: ALERT 케이스가 구현 전 FAIL. · **복잡도**: 저-중 · **의존성**: GAP-014 병합 가능 · **Opus-실행성**: 높음.

## GAP-005 — 스캐폴드 노화 관리 (dead-scaffold pruning)

- **차원**: D12(1→3, Δ2) · **severity**: HIGH(긴급 — 02 §1 Fable 5 가이드 직접 충돌) · **상태**: PENDING
- **증거**: 03 D12; 01 §6-10(제거 메커니즘 없음); 02 §1(Fable 5 공식: "과처방 skill이 출력 열화 — 리뷰·제거"; managed-agents "하네스 가정은 낡는다"); 02 §3(Anthropic strip-and-measure).
- **목표 상태**: (a) 각 hook/skill/seal에 "존재 이유" 메타(어느 실패·사이클에 추적되는가 — 대부분 이미 커밋 메시지·spec에 있음: 인덱스만) (b) 모델 업그레이드 트리거 체크리스트(신모델 도입 시 과처방 후보 리뷰 — 05-playbook에 절차) (c) improve-codebase-architecture 5-사이클 감사에 프루닝 후보 보고 단계.
- **Best-direction 근거**: 더 쉬운 대안 = "언젠가 수동 대청소" — 트리거가 없어 실행되지 않음(01 실측: 한 번도 없었음). 자동 A/B strip-and-measure(L4)는 run-log(GAP-003) 없이 측정 불가 — L3까지를 이번 목표로 하는 것은 의존성 순서이지 열화 아님. **1차 실행을 이니셔티브 내 수행**: Fable 5 가이드 기준으로 현행 skill 7종의 과처방 텍스트 1회 감사(즉효).
- **구현 스케치**: `docs/ai-context/scaffold-registry.md`(구성요소→존재 이유→추적 커밋/spec 인덱스, 01 구조맵에서 생성) + improve-codebase-architecture SKILL.md에 프루닝 단계 추가(enforce-orchestrator 골격 유지) + 05-playbook에 모델-업그레이드 체크리스트 + 1차 과처방 감사 실행(별도 plan task — 삭제는 사용자 diff 보고 후).
- **수용 기준**(적대 리뷰 정정: seal 수 18→**17**(9+4+4, #26 소각 — 01 §3 실측; 착수 시점 재실측 우선), 공허-통과 차단): registry에 hook 10+skill 10+seal 17(착수 시점 실측치) 전 항목 && SKILL.md에 프루닝 단계 grep && 1차 감사 보고서 — **skill 7종 각각에 유지/트림 판정+근거 1줄 의무**(후보 0건이어도 skill별 판정 근거가 있어야 유효; 근거 없는 빈 보고서는 FAIL).
- **테스트 계획(RED)**: verify-setup에 registry 존재+카운트 seal — 구현 전 FAIL. · **복잡도**: 중 · **의존성**: L4는 GAP-003 후속 · **Opus-실행성**: 중(과처방 판단은 모델-판단 — Fable 가이드 기준을 playbook에 인용 필수).

## GAP-006 — 교차모델 검증자 분리

- **차원**: D2(4→5 일부)+D10 L5 · **severity**: MED · **상태**: PENDING
- **증거**: 03 D2 잔여(wrapper 전원 동일 패밀리 — 01 §2); 02 §3(Factory 교차-프로바이더 검증 "자기 학습편향 회피"); 02 §1(fresh-context 검증자 교리); ccs 멀티모델 라우팅 실재(01 §2 ccs-delegation).
- **목표 상태**: 고-스테이크 판정(senior review·적대 리뷰·루브릭 재채점)에 교차패밀리(gpt 프로필) 라우팅 옵션을 closeout-pr-cycle Phase 4·start-rpi-cycle에 명문 옵션으로 + 실패 시(프록시 다운) 동일-패밀리 fallback 기록 규약.
- **Best-direction 근거**: 더 쉬운 대안 = "review-strict 프롬프트에 '비판적으로' 추가" — agreement bias는 지시로 안 풀림(6월 감사 §③ 기각 근거 계승). 교차모델이 구조 해소이며 인프라(ccs)가 이미 있어 순수 규약 작업.
- **구현 스케치**: closeout-pr-cycle Phase 4에 "교차패밀리 시도→불가 시 사유 기록" 분기 + 인라인-프롬프트 래퍼. C0 실측 함정 3건 인라인: `ccs glm`=프로필 부재(가용 프로필은 `ccs --help` 실측 — codex/gemini/kimi 등), `ccs codex`=400 "reasoning: Extra inputs are not permitted"(프록시↔모델 파라미터 비호환 — 프록시 설정 조정 필요), `ccs kimi`=대화형 디바이스-코드 인증(무인 불가; 사전 `ccs kimi --auth` 필요).
- **수용 기준**(적대 리뷰 강화 — fallback 기록만으로 전 기준 통과 가능하던 결함 차단): SKILL.md 분기 grep && **교차패밀리 실행 최소 1회 성공 증빙(응답에 비-Claude 모델 ID/프로필명 명시)** — 인프라 실패로 1회도 불가하면 이 GAP은 DONE이 아닌 **DEFERRED(인프라 사유)**로만 처분 가능.
- **테스트 계획(RED)**: 본문 토큰 seal(#22 동형) — 구현 전 부재. · **복잡도**: 저-중 · **의존성**: 없음 · **Opus-실행성**: 높음.

## GAP-007 — OS-레벨 sandbox 층

- **차원**: D5 L5·D11 L5 · **severity**: MED · **상태**: PENDING
- **증거**: 01 §0(bypassPermissions)·§6-11; 02 §4(srt Windows 지원·deny-by-default·권한 프롬프트 84% 감소; deny 규칙은 bypass에서도 유효).
- **목표 상태**: 단계적: (a) settings deny 규칙을 최후방어선으로 정의(자격증명 경로·파괴 명령 패턴 — bypass에서도 유효한 층) (b) srt 평가 스파이크(Windows research preview 성숙도 실측) → 채택/거부 판정 기록.
- **Best-direction 근거**: 최선 = full sandbox이나 srt Windows가 research preview — **성숙도 실측 후 판정이 최선 방향의 정직한 실행**이지 회피가 아님(스파이크 결과가 REJECTED면 사유 기록 = DOWNGRADE-DECLARED 아님, 외부 제약). deny 층은 지금 즉시 가능.
- **구현 스케치**: (a) settings.json permissions.deny에 자격증명 read·`rm -rf ~` 패턴(#23 parity 주의) (b) srt 스파이크: 격리 디렉터리에서 bash 래핑 실측 — 하네스 hook과의 상호작용(이중 차단·경로) 검증.
- **수용 기준**: (a) deny 규칙이 bypassPermissions 하에서 실차단(수동 검증 1회 기록) (b) 스파이크 보고서(채택/거부+근거).
- **테스트 계획(RED)**: deny 부재 상태에서 자격증명 read 통과 확인 → 규칙 후 차단. · **복잡도**: (a)저 (b)고 · **의존성**: 없음 · **Opus-실행성**: (a)높음 (b)중 — 스파이크는 탐색적.

## GAP-009 — 문서↔실물 정합 일괄 + 카운트 seal

- **차원**: D2 보조 · **severity**: LOW(quick-win) · **상태**: PENDING
- **증거**: 01 §5 M1-M10 전수.
- **목표 상태**: M1(README 66→70 + **seal 신설**: verify-setup ok/fail 발화 수↔README 선언 parity, #20 동형)·M2(창 매핑 서술)·M3(ccs-delegation 등재)·M5-M8(주석 정정) 일괄. M4(gitignored 산물)·M9(프레임)·M10(ops 비계상)은 의도 기록만.
- **Best-direction 근거**: 카운트를 seal 없이 고치면 재드리프트(M1이 그 증거 — 66도 한때 정확했다). seal 동반이 이 하네스의 검증된 종결 패턴.
- **수용 기준**: 신규 seal PASS && M1-M8 각 정정 커밋 && verify-setup 전건.
- **테스트 계획(RED)**: seal 구현 후 README 숫자 변이 복제본에서 FAIL 증명(seal-regression 패턴). · **복잡도**: 저 · **Opus-실행성**: 높음.

## GAP-010 — 미테스트 표면 커버

- **차원**: D1 보조 · **severity**: MED · **상태**: PENDING
- **증거**: 01 §6-2·§6-3에서 선별한 커버 목록(적대 리뷰 정정 — "전수" 아님): ① secret-scan 5/7 패턴 ② stable-claude-md ALERT 미단언 ③ session-start selfcheck syntax:/nonexec: 분기 ④ teardown abort 2경로 ⑤ model-window `/1m/` 행 ⑥ enforce-orchestrator ERR-센티넬 무로깅(§6-3) ⑦ 비-Windows STAGE 3b skip(01 §6-2 6번째 — D8 잔여 편입) ⑧ orchestrator 마커-제거 우회 표면화(03 D1 잔여 — surface_bypass 커버 검토).
- **목표 상태**: ①-⑥ 각각 run-all/전용 테스트 케이스 + ⑥ ERR-센티넬 hook_log 추가(무로깅 fail-open 0화 — D1 L5 요건) + ⑦ 비-Windows에서 실행 가능한 teardown 서브셋 분리 또는 명시 skip-사유 게이트 + ⑧ 마커-제거가 게이트 소멸임을 README/SECURITY 위협모델에 명기(표면화는 감시 비용 대비 판정 기록).
- **Best-direction 근거**: 더 쉬운 대안 = "작동 중이니 방치" — cycle-37 교훈(vacuous RED: 가드 변경이 기존 차단을 무효화해도 침묵)이 기각. 커버리지가 회귀의 유일한 감지선.
- **수용 기준**: run-all 카운트 +6 이상(cases.tsv·README·#20 동기) && ERR-센티넬 경로 hook_log 단언.
- **테스트 계획(RED)**: 각 케이스가 현행 미커버 확인(기존 스위트에서 부재 grep) → 추가. · **복잡도**: 중 · **Opus-실행성**: 높음 — 기존 케이스 패턴 복제.

## GAP-011 — skill/플러그인 공급망 규약

- **차원**: D11 L4 절반 · **severity**: MED · **상태**: PENDING
- **증거**: 02 §4(ToxicSkills 13.4%·rug-pull·approve-once; NSA 서명/핀/드리프트 경보); 01 §3(플러그인 버전 캐시만 존재).
- **목표 상태**: superpowers 등 외부 플러그인 버전 핀 기록 + 업데이트 시 SKILL.md diff 리뷰 절차(05-playbook) + 플러그인 캐시 해시 드리프트 ALERT(session-start-audit).
- **Best-direction 근거**: 더 쉬운 대안 = "공식 마켓플레이스 신뢰" — 02 §4 rug-pull이 기각(승인 후 변경). 해시 스냅샷+드리프트 표면화가 개인 규모에서 서명 인프라 없이 도달 가능한 최선.
- **수용 기준**: 핀 파일 존재 && 격리 환경에서 캐시 변이 시 ALERT 발화 케이스 GREEN.
- **테스트 계획(RED)**: 변이 케이스가 구현 전 무경보 확인. · **복잡도**: 중 · **Opus-실행성**: 높음.

## GAP-012 — 실패→회귀픽스처 루프

- **차원**: D7(3→4 일부) · **severity**: LOW-MED · **상태**: PENDING
- **증거**: 03 D7 잔여; 02 §5(LangSmith "문제 trace→회귀 데이터셋" 루프); 02 §4(Anthropic "Read the transcripts!"·20-50 과제).
- **목표 상태**: non-obvious 등록 절차(§4)에 "재현 픽스처 동반" 규약 — AI 실패가 5 Whys 통과 시 run-all 케이스 또는 전용 테스트로 고정(가능한 경우). 20-50 과제 스위트는 개인 규모 재해석: 기존 156 케이스+E2E가 이미 그 역할 — 신규는 실패-유래만 추가.
- **Best-direction 근거**: 처음부터 50-과제 스위트 구축은 실패-추적성 없는 투기(02 §6 ETH·HumanLayer 역풍) — 실패-유래 케이스만 추가가 5-Whys 절차와 정합인 최선.
- **수용 기준**: CLAUDE.md §4 또는 non-obvious.md 헤더에 픽스처 규약 grep && 차기 등록 1건에 실적용.
- **테스트 계획(RED)**: 규약 추가 전 — 최근 non-obvious 등록 이력에 픽스처 동반 0건임을 grep으로 확인(RED 상태의 실증) → 규약 추가 후 차기 등록 1건에서 픽스처 파일 실재 확인(GREEN).
- **복잡도**: 저 · **의존성**: GAP-003(transcript 원천) 시너지 · **Opus-실행성**: 높음.

## GAP-013 — Rule-of-Two 세션 분리

- **차원**: D11 L4 절반·D5 보조 · **severity**: MED · **상태**: PENDING
- **증거**: 02 §4(lethal trifecta·Meta Rule-of-Two·reader/doer 분리); deep-research skill 실재(untrusted 웹 + 쓰기 도구 + 시크릿 접근이 한 세션에 공존 가능 — 01 §0 bypassPermissions).
- **목표 상태**: 웹-읽기 중심 작업(deep-research 등)의 reader 서브에이전트에 쓰기 도구 미부여 규약 명문화 + 본체는 검증 후 행동 — skill/playbook 레벨 규약(도구 allowlist는 wrapper agent 패턴 재사용).
- **Best-direction 근거**: 더 쉬운 대안 = "인젝션 조심" 프롬프트 — 02 §4 "영구 속성" 평가가 기각. 구조 분리(도구 박탈)가 유일하게 작동하는 방어이고 wrapper-agent 인프라로 저비용.
- **수용 기준**: 해당 skill 본문에 도구 제약 grep && wrapper 정의에 반영.
- **테스트 계획(RED)**: 현행 deep-research류 실행 경로에서 웹-읽기 단계가 쓰기 도구 보유 상태임을 skill 본문/agent 정의 grep으로 확인(RED) → 규약 반영 후 reader 단계 도구 목록에 Write/Edit/Bash 부재 grep(GREEN) + seal-regression 패턴으로 제약 문구 제거 변이 시 검사 FAIL 증명.
- **복잡도**: 저-중 · **Opus-실행성**: 높음.

## GAP-014 — MEMORY.md 인덱스 예산 seal

- **차원**: D3 보조 · **severity**: LOW · **상태**: PENDING (GAP-004에 병합 권장)
- **증거**: 02 §1(첫 200줄/25KB만 시작-로드 — 공식); 현행 MEMORY.md 줄당 길이 비대(01 §4).
- **목표/수용**: session-start-audit 예산 체크(GAP-004 (c)와 동일 구현) — 병합 실행.
- **Best-direction 근거**: 독립 항목 유지보다 GAP-004 병합이 SSOT — 동일 구현 지점(session-start-audit)의 중복 규약을 피한다(병합은 열화가 아니라 중복 제거).
- **테스트 계획(RED)**: N/A(병합 처분) — RED는 GAP-004의 "201줄 MEMORY.md ALERT" 케이스가 커버(중복 계획 작성은 SSOT 위반). GAP-004 착수 시 이 항목을 DONE(병합)으로 동시 처분.

## GAP-015 — MCP 쓰기 게이트

- **차원**: D1 L5 요건 · **severity**: LOW-MED · **상태**: PENDING
- **증거**: 6월 G1-a 계승(01 §1 — hook matcher가 Write/Edit/NotebookEdit/Bash만); MCP 도구(예: playwright browser_run_code_unsafe)가 파일 쓰기 가능.
- **목표 상태**: PreToolUse matcher에 위험 MCP 도구 패턴 추가(파라미터-인지 규칙 활용 — 02 §1 `Tool(param:value)` v2.1.178) 또는 deny 규칙(GAP-007a와 통합).
- **Best-direction 근거**: 전 MCP 범용 게이트는 도구 스키마 다양성으로 불가(6월 판정 유지) — 알려진 위험 도구 열거+파라미터 규칙이 현실 최선(전부-아니면-전무 오류 회피).
- **수용 기준**: 대상 도구 호출이 게이트 발화(격리 검증) && 기존 케이스 무회귀.
- **테스트 계획(RED)**: 격리 설정에서 대상 MCP 도구(예: 파일-쓰기 가능 browser_run_code) 호출이 현행 무게이트 통과함을 확인(RED) → 규칙 추가 후 동일 호출 차단/프롬프트 확인(GREEN) + settings parity(#23) 무회귀.
- **복잡도**: 중 · **Opus-실행성**: 중(matcher 문법 검증 필요).

## GAP-016 — 사이클 proof-artifact 규약

- **차원**: D7 보조 · **severity**: LOW · **상태**: PENDING(재평가 — GAP-003이 대체 가능)
- **증거**: 6월 defer(proof-artifact); 02 §2(Antigravity Artifacts — 로그 아닌 리뷰 가능 증거물); 현행 plan 체크박스+검증 출력이 부분 대체(02 §7 P14 ◐).
- **목표 상태**: GAP-003 run-log가 착륙하면 사이클 보고에 게이트 통계+검증 커맨드 출력 고정 포맷 — 별도 artifact 규약이 불필요한지 재평가 후 DONE/REJECTED 판정.
- **Best-direction 근거**: 중복 규약 신설은 SSOT 위반 위험 — 재평가가 정직한 처리.
- **수용 기준**: 재평가-처분형 — GAP-003 DONE 후 1사이클 내 이 항목의 DONE(흡수)/REJECTED(사유) 판정이 04에 기록되면 충족. **테스트 계획(RED)**: N/A(처분 판정 항목 — 구현물 없음; 판정 미기록 상태가 RED에 상당).

## GAP-017 — seal-regression Part B (rank9B)

- **차원**: D2 보조 · **severity**: LOW · **상태**: PENDING(재평가)
- **증거**: 6월 rank9 Part A 봉인(대표 변이 3종: schema #30·parity #23·count #20), Part B(전 seal 변이 커버) defer — `docs/superpowers/specs/2026-06-13-external-standards-audit.md` 참조.
- **목표 상태**: 신규 seal(GAP-001 #35·GAP-009 카운트)이 추가되는 시점에 대표 변이 세트 확장 여부 재평가 — 전수 커버는 한계효용 낮음(Part A가 메커니즘 증명 완료).
- **Best-direction 근거**: 전수 변이는 유지비>효용(6월 판정 유지가 최선 — 신규 seal 유형 추가 시에만 대표 변이 1종 추가).
- **수용 기준**: 재평가-처분형 — GAP-001/009의 신규 seal 착륙 사이클에서 "대표 변이 추가(구현) / 불요(사유)" 판정이 04에 기록되면 충족. 구현 선택 시 seal-regression.test.sh에 신규 seal 대상 변이 1종 추가가 그 사이클의 수용 기준에 편입. **테스트 계획(RED)**: N/A(처분 판정 항목) — 구현 선택 시 RED는 "신규 seal이 변이 주입에도 GREEN인 상태"의 실증으로 정의.

## GAP-008 — 핸드오프 복원력 완성 (IN-CYCLE)

- **차원**: D9(3→5, Δ2) · **severity**: HIGH(이 이니셔티브의 존재 이유 — deadline invariant) · **상태**: **IN-CYCLE(C0=문서 세트로 L4, C-final=cold-agent fitness로 L5)**
- **증거**: 03 D9. 이 문서 세트 자체가 구현체 — 별도 백로그 작업 없음. C-final에서 fitness FAIL 시 문서 결함으로 회귀 수정(spec §6).
- **Best-direction 근거**: 더 쉬운 대안 = "auto-memory에 요약 남기기" — 머신-로컬이라 핸드오프 실패(D9 앵커 3의 정의 그 자체). self-contained 문서 세트+fitness 실증이 goal deadline invariant의 유일 충족 경로.
- **수용 기준**(적대 리뷰 정정 — "착수 성공" 무정의·보장-통과 루프 차단): C-final cold-agent fitness에서 fresh subagent(이 문서 세트 외 컨텍스트 0)가 05+04의 1항목만 받아 **(i) 유효 plan 초안(Status 헤더+해당 GAP 수용 기준 전사) (ii) 그 GAP의 RED 재현 커맨드를 무도움(추가 질문 0회)으로 산출** — 둘 중 하나라도 실패하면 문서 수정 후 재시도하되, **재시도 이력(몇 회·무엇을 고쳤나)을 C-final 보고에 전수 기록**(무한 fail→fix→pass를 통과로 위장 불가; ≤2회 내 통과가 목표선, 초과 시 D9=5 미달로 채점).
