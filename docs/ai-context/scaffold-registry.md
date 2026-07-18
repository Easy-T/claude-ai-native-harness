# Scaffold Registry — 하네스 구성요소 존재-이유 대장 (GAP-005)

> 이 하네스(`~/.claude`)의 모든 강제/검증 스캐폴드에 **"왜 존재하는가"**를 기록한다. 목적: 스캐폴드가 무한 누적만 하고 제거 트리거가 없던 결함(01-structure-map §6-10) 해소 — 각 구성요소가 어느 실패·사이클·spec에 추적되는지 인덱싱해, 모델 업그레이드 등으로 무용해진 가드를 **의도적으로 리뷰·제거**할 수 있게 한다.
>
> **노화 리뷰 규약**: ① `verify-setup.sh`의 registry seal이 **live 구성요소 ⊇ registry 등재**를 강제한다 — 새 hook/skill을 추가하고 registry에 안 적으면 verify-setup이 FAIL(노화 방지 트리거). ② **모델 업그레이드 시** `05-playbook.md`의 "모델-업그레이드 체크리스트"가 이 registry + 과처방 감사(02 §1 Fable 5 가이드)를 재검토하게 한다. ③ 실측이 SSOT — 아래 카운트는 작성 시점(C4, 2026-07-13)이며, 갱신 시 `ls hooks/*.sh`·`ls skills/*/SKILL.md`로 재확인.
>
> 형식: `구성요소 — 존재 이유(무엇을 막는가) — 추적(cycle/spec/커밋)`. 삭제는 이 대장으로 후보를 식별하되 **사용자 diff 보고 후에만** 실행.

## Hooks (11 — `ls hooks/*.sh` 중 `_common.sh` 제외)

| Hook | 존재 이유 (무엇을 막는가) | 추적 |
|---|---|---|
| `enforce-orchestrator.sh` | SKILL.md가 orchestrator 골격(Phase≥3·Agent()≥1·Protocol) 없이 작성되는 것 차단 — 위임 일관성(§2 헌법) | 초기; `hooks/lib/skeleton-scan.js` 권위 |
| `stable-claude-md.sh` | 프로젝트 루트 CLAUDE.md 수정 시 캐시 비용(~20배) 환기(§1) | 초기 |
| `enforce-rpi-cycle.sh` | Write/Edit로 코드파일을 active-plan 없이 쓰는 것 차단 — RPI 강제 핵심(§3) | 초기; cycle-23 explicit-Status·cycle-40 워크트리 마커·cycle-31/32 cwd 앵커 |
| `enforce-rpi-bash.sh` | Bash 리다이렉트·tee·sed -i·cp/mv·install/rsync·heredoc로 코드파일 쓰는 사이드도어 차단(§3) | cycle-25~37 토크나이저 진화(`>&`·`~~~`·install 앵커) |
| `enforce-secret-scan.sh` | 고-특이도 시크릿(API키/PEM)이 파일·명령에 박히는 것 차단(종류만 보고) | 6월 감사 item2 |
| `enforce-session-budget.sh` | 무인 goal-loop 폭주 — 세션당 도구호출 ceiling 초과 차단(기본 OFF) | **C3 (GAP-002)** |
| `auto-compact-watch.sh` | 컨텍스트 창 임계 도달 무인지 — 모델-인지 창(fable/[1m]→1M) 기준 /compact 권장 | fable→1M 교정 |
| `verify-loop-watch.sh` | Stop 시 미검증 코드변경이 closeout 없이 남는 것 — check.sh+closeout 환기 | 초기 |
| `session-start-audit.sh` | 30일 audit 마커 stale + 스테일 워크트리 마커/고아 브랜치 잔여 + 손상 파서 침묵 — 알림·sweep·fail-open 표면화 | cycle-32(lib 스모크)·cycle-41(self-healing sweep)·**C3(.budget prune)** |
| `surface-constitution.sh` | 의존성 매니페스트(§5)·UI 확장자(§8) 수정 시 헌법 조항 미인지 — additionalContext 환기 | cycle-16 |
| `worktree-teardown.sh` | 종료 세션의 링크 워크트리 잔존 — 정션-안전 삭제(데이터손실0) | cycle-38~41 |
| (`_common.sh`) | 위 전 hook의 공유 함수(json 파서·hook_log·plan_status·resolve_project_root·run_log_event·surface_bypass 등) | 지속 진화; **C2 run_log_event 추가** |

## Skills (8 — `ls skills/*/SKILL.md`)

| Skill | 존재 이유 | 추적 |
|---|---|---|
| `start-rpi-cycle` | 변경 작업에 R→P→I→Closeout 강제(직접 코딩 금지) — 하네스 중추 | 초기; **C1 Best-Direction Check 필드 추가** |
| `closeout-pr-cycle` | 구현 완료 브랜치를 PR→CI→senior review→승인→merge로 닫음(AI 머지 결정 금지) | 초기 |
| `create-orchestrator-skill` | 새 커스텀 skill을 orchestrator 패턴으로 생성(§2) | 초기 |
| `improve-codebase-architecture` | 누적 RPIC 후 구조 개선 + README + **스캐폴드 프루닝 후보 보고(C4)** | 초기; **C4 프루닝 단계 추가** |
| `init-ai-ready-project` | 빈 디렉터리에 AI-Ready 프로젝트 13파일 결정론 부트스트랩 | 초기 |
| `ui-design` | 웹/앱 UI 결정을 design.md 토큰에 정렬 + Anti-Slop floor + Craft ceiling | ui-design v2 이니셔티브(cycle 49-51) |
| `common-agent-contract` | wrapper agent 3종(explore/execute/review-strict)에 Input/Output 계약 자동 주입 | 초기 |
| `statusline` | 커스텀 상태줄 유지보수(비강제 on-demand) | statusline v2 |
| (grill-with-docs) | 도메인 어휘 stress-test — doctor.sh 자동설치(gitignored), 벤더링 | 미추적(설치 산물) |
| (ccs-delegation) | CCS CLI 위임(로컬 정션, 비추적) — 하네스 게이트 무관 | 미추적 |

## Drift Seals (verify-setup.sh #17~#44, −#26 소각 = 27)

거버넌스 사실의 재드리프트를 막는 특정-인스턴스 봉인(안정 앵커 있는 것만; generalized 프레임워크 아님).

| Seal | 봉인 대상 | 추적 |
|---|---|---|
| #17 | CLAUDE.md §3 ⊇ start-rpi-cycle Phase R 도구명 | cycle-16 |
| #18 | next-cycle-goal 3라벨 parity | cycle-14 |
| #19 | harness-verify 토큰 parity (마스킹 재발 방지) | cycle-14/16 |
| #20 | cases.tsv 카운트 ↔ README | cycle-17 |
| #21 | verify-integration E2E 카운트 ↔ README | cycle-17 |
| #22 | phase-skills 필드 parity | cycle-17 |
| #23 | settings.json ↔ example 하네스 hook (phase/matcher/basename) parity | cycle-17/24 |
| #24 | doctor REQUIRED_HOOKS ⊇ 디스크 hooks | cycle-17 |
| #25 | verify-integration mktemp 격리(부정 단언) | cycle-20 |
| #27 | 전 plan 명시 Status + active≤1 (stale-active 봉인) | cycle-23 |
| #28 | 전 스크립트 `bash -n` 문법 | 초기 |
| #29 | install.sh REQUIRED ⊇ skills | 초기 |
| #30 | state.json ↔ schema draft-07 부분집합 | cycle-28 |
| #31 | cwd-drift 앵커(rev-parse+resolve_project_root) | cycle-31 |
| #32 | 서브디렉터리 게이트 E2E(exit 0/2/2/0) | cycle-31 |
| #33 | worktree-teardown E2E 배선 + 핵심 단언 | cycle-33 |
| #34 | 동시-세션 격리 규약 SECURITY.md 실재 | cycle-33 |
| #35 | Best-Direction Mandate 토큰(start-rpi-cycle) parity | **C1 (GAP-001)** |
| #36 | verify-setup 총수 ↔ README `현재 N PASS` 런타임 자기-카운트 | **C1 (GAP-009)** |
| #37 | (C4 신설) scaffold-registry ⊇ live hook/skill parity | **C4 (GAP-005)** |
| #38 | memory-policy.md 존재 + 통합/프루닝/검증 3규약 | **C5 (GAP-004)** |
| #39 | settings.example autocompact PCT ≤40 (rot-정렬) | **C6 (GAP-018)** |
| #40 | plugin-pins.md 존재 + SKILL.md cksum 핀 (공급망) | **C7 (GAP-011)** |
| #41 | explore-strict reader 쓰기도구 미부여 (Rule-of-Two) | **C8 (GAP-013)** |
| #42 | settings.example deny 최후방어선 (자격증명·파괴명령) | **C8 (GAP-007a)** |
| #43 | opencode 미러 design.md byte-sync | ui-design v3 |
| #44 | design.md §6 anti-slop floor = 18 항목 | ui-design v3 |

### 거버넌스 문서 (seal이 지키는 대상 — hook/skill 아님)

| 문서 | 존재 이유 | 추적 |
|---|---|---|
| `docs/ai-context/memory-policy.md` | 메모리 수명주기(통합/프루닝/검증) 규약 — 축적 단방향 방지 | **C5 (GAP-004)**; seal #38 |
| `docs/ai-context/plugin-pins.md` | 플러그인 공급망 핀(cksum) — rug-pull 표면화 | **C7 (GAP-011)**; seal #40·D-SUPPLY-CHAIN |
| `docs/ai-context/cross-family-review.md` | 교차패밀리 검증 규약(2경로 탐지·트리아지·quota·plugin-cc 기각) — agreement bias 중화 | **C10 (GAP-006)**; seal은 GAP-019 편승 예정 |

※ 검사 항목 1~16(파일/구조/템플릿/hook 실행권한 등)은 seal이 아닌 기본 구조 검증. verify-setup 총 ok/fail 수(81, C9/재감사 시점)는 #8 hook 루프 등이 항목당 다중 발화하므로 검사 번호 수와 다르다. **#38~#44 등재는 2026-07-17 Fable 재감사 C-3 백필** — #37 seal은 hook/skill만 검사하므로 seal/문서 신설은 registry에 수동 등재해야 한다(자동 봉인 확장은 후속 검토).

## 메타검증·오라클 (seal 아님, 별도 스테이지)

| 장치 | 존재 이유 | 추적 |
|---|---|---|
| `setup/tests/seal-regression.test.sh` | seal이 실제 드리프트에 FAIL함을 대표 변이(schema/parity/count)로 증명(seal이 헛돌지 않음) | cycle-31 |
| `setup/tests/failopen-surface.test.sh` | fail-open이 침묵 아닌 FAILOPEN 표면화임을 크래시 스텁으로 증명 | cycle-32 |
| `setup/tests/rpi-prereq-gate.test.sh` | 트리오 부재 시 verify-all이 "ALL PASS" 미출력(플러그인 false-green 봉인) | rev2 #1 |
| `hooks/.runlog` + `runlog_summary` | 게이트 발화·차단·우회 구조화 관측(gen_ai.* 정렬) | **C2 (GAP-003)** |
| `opencode-harness/_oracle/diff-parsers.mjs` | 미러 lib 파서가 canonical과 byte-일치 차등검증 | opencode 마이그레이션 |
