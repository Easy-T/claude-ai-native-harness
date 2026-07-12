# 01 — 하네스 구조맵 (2026-07-13 fresh 실측)

> 원천: 인벤토리 에이전트 4축(I-1 hooks / I-2 skills·agents / I-3 검증 인프라 / I-4 거버넌스)이 README·기억이 아닌 **실물 코드**를 읽고 산출. 모든 주장에 file:line 증거. 경로는 `~/.claude/` 기준.
> 이 문서는 재감사 시점의 스냅샷 기록이다 — 이후 사이클이 하네스를 바꾸면 여기가 아니라 04-gap-backlog의 항목 상태와 03-rubric 재채점이 갱신된다(genesis-record 모델).

## 0. 하네스 자체 프레이밍 (설계 철학)

- `SECURITY.md:7-8` — "거버넌스는 tool 경계의 결정론적 hook으로 강제… 프롬프트(CLAUDE.md)는 권고일 뿐 — 강제력 없음." 즉 헌법 대부분이 **의도적으로 advisory**이고, 물리 강제는 4개 차단 hook + drift seal에 집중.
- 강제 수준 서열(CONTEXT.md '자가-표면화' 정의): **차단(blocking) > advisory(알림) > 자가-표면화(누락이 구조적으로 드러남) > 미강제**.
- trust model = 단일 운영자(`SECURITY.md:6`), `permissions.defaultMode: bypassPermissions`(settings.json — 격리 환경 아님, SECURITY.md:11-19가 트레이드오프 명시).

## 1. 강제 계층 — hooks 10종 + _common.sh + lib 파서 4종

배선: `settings.json` hooks 블록 (PreToolUse W/E/N 5개 + Bash 2개, PostToolUse 1, SessionStart 1, Stop 1, SessionEnd 1 = 11 command entries, 스크립트 10종).

| Hook | 이벤트/매처 | 모드 | 우회 | fail-open 표면화 | 테스트 | 이식성(opencode) |
|---|---|---|---|---|---|---|
| `enforce-orchestrator.sh` | PreToolUse W/E/N | **차단**(exit 2) | frontmatter `orchestrator_skill: true` 제거 | ⚠️ `SKEL="ERR"/"EMPTY"` → exit 0 **무로깅 침묵**(L17-18) — 유일한 미표면 fail-open | run-all eo 9케이스 + lib 72-74 | mirrored(orchestrator-gate.js) |
| `enforce-rpi-cycle.sh` | PreToolUse W/E/N | **차단** | `RPI_SKIP`(L74-79) · trivial ≤5줄(L61-71) · 비코드 확장자(L37) | no-cwd → PASS 로깅(`no-cwd-failopen`, L16) | run-all erc ~30케이스 | mirrored(rpi-gate.js, plan-status.js, code-exts.js) |
| `enforce-rpi-bash.sh` | PreToolUse Bash | **차단** | `RPI_SKIP`(L30-34). **trivial 우회 없음**(rpi-cycle과 의도적 비대칭 — 1줄 `echo x > fix.sh`도 차단) | ✅ 파서 크래시 → FAILOPEN 로그+stderr(L42-48, cycle-32) | run-all erb ~20케이스 + failopen-surface.test.sh ① | mirrored(redirect-targets.js verbatim) |
| `enforce-secret-scan.sh` | PreToolUse W/E/N **및** Bash (2배선) | **차단** | `SECRET_SCAN_SKIP`(L28-32) | 빈 payload/JSON 파싱 실패 → exit 0 침묵(L26) | run-all ess 6케이스 — **7패턴 중 5개(GitHub/GitLab/Slack/Google/PEM) 미테스트** | mirrored(secret-gate.js) |
| `stable-claude-md.sh` | PreToolUse W/E/N | 알림 | 없음(알림뿐) | 빈 cwd 침묵 계속(L8) | run-all scm 4케이스 — **exit 코드만 단언, ALERT 발화 자체는 미단언**(회귀 시 침묵 통과) | claude-only |
| `surface-constitution.sh` | PreToolUse W/E/N | 알림(additionalContext) | n/a | marker touch 실패 `\|\| true` 침묵(L22) | run-all sc 4케이스 | mirrored(advisories.js) |
| `auto-compact-watch.sh` | PostToolUse Read/Bash/Agent | 알림 | `CONTEXT_LIMIT`/`COMPACT_WARN_PCT` env | transcript 부재/읽기 실패 침묵(L9, transcript-usage.js:23) | run-all acw 7케이스 — WARN_PCT clamp 분기 미테스트 | claude-only |
| `session-start-audit.sh` | SessionStart | 알림+정리 | n/a | ✅ **이 hook이 fail-open 표면화 장치 자체**: node 부재·`bash -n` 문법·비실행권한(L49-58)·lib 런타임 스모크(L64-74) ALERT — 단 `syntax:`/`nonexec:` 분기 자체는 미테스트 | run-all ssa 11케이스 + failopen-surface ② | 부분(worktree prune 유사물만) |
| `verify-loop-watch.sh` | Stop | 알림 | n/a | 전 전제조건 미충족 침묵 exit 0 | run-all vlw 6케이스(전 분기) | claude-only |
| `worktree-teardown.sh` | SessionEnd(`prompt_input_exit\|logout\|other`) | 정리(best-effort) | reason 자기게이트(L19-22) | ✅ powershell 부재/reparse 잔존 → rm 중단+ALERT(L124-132) — 단 두 abort 경로 미시뮬 | worktree-teardown.test.sh 25단언(T1-T6·Ta-Te) | 부분(prune만 포팅) |

**공유 기반**: `_common.sh` — json 파서(침묵 catch), `hook_log`, `plan_status`(bold+펜스 인지), `resolve_project_root`(git 경계 상위탐색), `CODE_EXTS` SSOT, `wt_root_from_path`, `surface_bypass`(세션당 1회 additionalContext), `resolve_cwd`. lib 파서 4종(`skeleton-scan.js`·`redirect-targets.js`·`transcript-usage.js`·`model-window.js`)은 run-all 단위테스트 + SessionStart 런타임 스모크 이중 커버.

**취약 지점 (실측)**:
- `/tmp` 세션 마커 누적(_common.sh:168) — MSYS 설치별 `/tmp`, OS 정리 의존.
- `model-window.js:10-16` 하드코딩 모델→창 매핑 — `opus-4-(7|8)|fable|1m` 미매치 신규 1M 모델은 침묵 200K(경보 조기발화라 안전 방향이나 분모 오류).
- `redirect-targets.js:15` — `CODE_EXT_REGEX` env 부재 시 fallback이 `.(sh|py|js)$`로 34-확장자 SSOT보다 침묵 축소.
- 전 hook이 `$HOME/.claude/hooks/_common.sh` 절대 source(각 L2) — 재배치 시 전멸, selfcheck는 문법만 검사.
- run-all이 실제 `$HOME/.claude/worktrees-marker`를 변이(고유 SID로 안전하나 완전 격리 아님).

## 2. Skill·Agent 계층

**Skill 10종** (glob 가시 9 + `ccs-delegation` 정션 1): orchestrator 마커(`orchestrator_skill: true`) 7종 전원 골격 적합(Phase ≥3 · Agent() ≥1 · Communication Protocol — enforce-orchestrator가 쓰기 시점 강제).

| Skill | Phase 구조 | 위임 | 특이점 |
|---|---|---|---|
| `start-rpi-cycle` (252줄) | R→P→I→Closeout + Gate R/P + C-0/C-1(sub 8) | explore-strict 1 + review-strict 3 | 고유 필수 3필드(next-cycle-goal/harness-verify/phase-skills) = 자가-표면화의 원형. seal 4개(#17/18/19/22)가 본문 토큰 봉인 |
| `closeout-pr-cycle` (200줄) | Preflight+6 Phase | review-strict 1 (senior) | merge 사용자 승인 하드게이트(L150) — auto-merge는 사용자 명시 위임 시만 override |
| `init-ai-ready-project` (113줄) | 0-4 (5) | explore+execute+review | 13 .tpl 결정론 생성, 자유기술 금지(L112) |
| `improve-codebase-architecture` (174줄) | Preflight+4 | explore+execute | ⚠️ Phase 4(README 생성)는 review-strict 검증 없이 메인 직접(L94-158) |
| `create-orchestrator-skill` (62줄) | 1-4 | review-strict 1 | 권위 checker=`hooks/lib/skeleton-scan.js` 명시(L36-37) |
| `ui-design` (81줄) | 1-3 | review-strict 1 | ⚠️ "작은 변경 검증 생략 가능"(L71) 자가 재량. design.md(440줄) 별도 |
| `statusline` (75줄) | 1-3 | review-strict 1 | 비강제 on-demand(README 각주) |
| `common-agent-contract` (52줄) | n/a | 0 | wrapper 3종에 주입되는 Output 계약의 SSOT |
| `grill-with-docs` (89줄) | n/a | 0 | 벤더링(doctor 자동설치, gitignored) — 검증 단계 없음(수용) |
| `ccs-delegation` (196줄) | n/a | 0 (Bash로 ccs CLI) | ⚠️ **README 전무 + result/evidence/unknowns 계약 무연결 + 위임 결과 검증 단계 없음** |

**Wrapper agent 3종** (전원 `model: inherit` + common-agent-contract 주입): `explore-strict`(Read/Grep/Glob/WebFetch — 읽기 전용), `review-strict`(+ read-only Bash — 1기준 실패=전체 FAIL, PASS/FAIL만), `execute-strict`(Read/Write/Edit/Bash — scope 외 = 변경 않고 FAIL+unknowns). **비고: 전원 실행자와 동일 모델 패밀리 — 교차모델 검증자 분리 없음.**

**Commands 2종**: `init-ai-ready.md`·`improve-architecture.md` (skill 명시 호출 래퍼).

## 3. 검증 인프라

**verify-setup.sh — 실측 70체크** (item 1-16=53 + seal #17-#25=9 + #27-#30=4 + #31-#34=4; #26 소각). 전부 [결정론-신호]. seal 목록: #17 §3↔Phase R 어휘 / #18 next-cycle-goal 3라벨 parity / #19 harness-verify 토큰 / #20 cases.tsv 카운트↔README / #21 E2E 카운트↔README / #22 phase-skills parity / #23 settings↔example hook parity / #24 doctor⊇hooks / #25 verify-integration mktemp 격리(부정 단언) / #27 plan Status lifecycle(전 plan 명시 Status+active≤1) / #28 전 스크립트 `bash -n` / #29 install⊇skills / #30 state.json↔schema / #31 cwd-drift 앵커 / #32 서브디렉터리 게이트 E2E / #33 teardown E2E 배선 / #34 동시-세션 규약 존재.

**verify-all.sh 스테이지**: STAGE 0(superpowers 트리오 전제 — 부재 시 "ALL PASS" 문자열 자체 차단) → 1 doctor / 1b doctor.test → 2 verify-setup / 2b seal-regression(변이 주입 → seal이 실제 RED 됨을 메타검증) / 2c failopen-surface / 2d rpi-prereq-gate → 3 run-all(156케이스, cases.tsv 양방향 정합 게이트 + 95% 플로어) / 3b worktree-teardown(**비-Windows skip** — 플랫폼 공백) → 4 verify-integration(E2E 8).

**doctor.sh**: 24항목+서브(~40 체크 라인), WSL namespace FATAL, audit 마커 보존(갱신은 closeout 권한), 자동설치(jq·grill). **install.sh**: 파괴적 rm 없음, REQUIRED 29파일 전수, 백업 선행, 하네스 hook만 교체(사용자 hook 보존).

**opencode 미러** (`opencode-harness/`): plugin(governance.js+gates 3+lib 11) + skill 21 + tests 19파일(≥85 단위) + `_oracle/` — diff-parsers.mjs(**canonical 파서를 서브프로세스 실행해 byte-일치 차등검증**), verify-all.sh(플로어 ≥80+fail==0), acceptance.sh(zip 라운드트립+제외집합 4선언 byte-일치), install.sh(백업 hard-gate + `cd && rm 상대경로`만).

**[모델-판단] 표면 (verify-all 밖)**: review-strict drift 검사(6기준)·Gate R/P·senior/적대 리뷰·§4 5-Whys — LLM이 PASS 판정. advisory hook의 *발화*는 결정론 테스트되나 *효과*는 모델 순응 의존.

## 4. 거버넌스 문서 계층

**CLAUDE.md 헌법 → 강제 매핑** (I-4 전수):

| 규칙 | 장치 | 등급 |
|---|---|---|
| §1 Cache Stability | stable-claude-md(프로젝트만·글로벌 제외) + verify-setup #1(≤200줄) + 30일 audit | 알림+seal |
| §2 Orchestrator Meta | enforce-orchestrator + #7 marker triple | **차단** |
| §3 RPI Mandate | enforce-rpi-cycle + enforce-rpi-bash + seal #17/#27/#31/#32 + STAGE 0 + verify-loop-watch | **차단+seal 다중** |
| §4 Non-Obvious 절차 | 없음 — skill 절차 내 단계뿐 | [advisory-only] |
| §5 ADR Auto-Trigger | surface-constitution(additionalContext, 1세션 1회) | 자가-표면화 |
| §6 Domain Glossary | 없음 — grill-with-docs 절차뿐 | [advisory-only] |
| §7 Response Language | **어떤 장치도 없음** | [미강제] |
| §8 UI Design Mandate | surface-constitution | 자가-표면화 |
| Think Before Coding | 없음 | [미강제] |
| Simplicity First | 없음 — **그리고 아키텍처 열화의 알리바이로 오독 가능(Best-Direction Mandate의 대상, goal §4)** | [미강제] |
| Surgical Changes | execute-strict scope-lock(해당 agent 사용 시만) | [advisory 조건부] |
| Goal-Driven Execution | verify-loop-watch(1세션 1회 환기) | 자가-표면화 |

**기타**: CONTEXT.md 용어 21종(grill이 갱신) · SECURITY.md(신뢰모델·fail-open 신뢰베이스·teardown 안전모델·동시-세션 규약) · state.json(cycle.count=47, seal #30) · specs 20 + plans 52, 최근 5 plan Status 규율 5/5(seal #27) · `_goal/`=goal-loop 프롬프트 스크래치(gitignored `/_*/`).

## 5. 서술↔실물 불일치 (실측 — 그 자체가 갭 후보)

| # | 불일치 | 증거 |
|---|---|---|
| M1 | README "현재 66 PASS" vs 실측 70 — #31-#34 미반영, **이 숫자를 봉인하는 seal 없음**(#20/#21은 다른 카운트) | README.md:283 vs verify-setup.sh 전수 |
| M2 | README 창 매핑 "opus-4-7/4-8→1M, 그 외 200K" — `fable`·`[1m]` 매핑 누락(실사용 경로인데) | README.md:38 vs model-window.js:11-13 |
| M3 | `ccs-delegation` skill이 README skill 테이블·트리에 전무 | README.md:47-59, 288-301 |
| M4 | `grill-with-docs`가 README 디렉터리 트리에 미기재(디스크 실재, gitignored 설치 산물 — 의도 가능) | README.md:288-301 |
| M5 | verify-setup.sh:85 주석 "…=9" 열거 vs 실제 11 command entries (`>=9` 체크라 PASS 유지, 주석만 낡음) | settings.json:50-72 |
| M6 | worktree-teardown.sh:27 주석 "SessionStart가 남긴 마커" — cycle-40 이후 주 기록자는 PreToolUse(stale 주석, 테스트 L79도 동일) | enforce-rpi-cycle.sh:11-14 |
| M7 | auto-compact-watch.sh:25 "기본 95" — 레거시 수치(실제 CLI 기본 ~83.5%), env 부재 시 메시지 산술만 오기 | settings.json이 55 핀이라 무해 |
| M8 | teardown GUARD 번호 4 건너뜀(3→5) — cosmetic | worktree-teardown.sh:65,80 |
| M9 | README 표 "6개 orchestrator skill" vs 마커 보유 7(statusline 포함) — L59 각주로 의미상 정합, 프레임만 상이 | README.md:47,59 |
| M10 | state.json count=47(06-27) vs 07-13 completed plan 2건(gpt56-swap·ui-design C1는 브랜치) — ops-config 비계상 의도 여부 기록 없음 | state.json vs plans/ |

## 6. 미강제·미커버 표면 (갭 후보 원천)

1. **헌법 §7·Think Before Coding·Simplicity First = 완전 미강제** (§4·§6은 skill-절차 의존 — skill 미발동 시 침묵).
2. **테스트 공백**: secret-scan 패턴 5/7 미테스트 · stable-claude-md ALERT 미단언 · session-start-audit selfcheck 분기 미테스트 · teardown abort 2경로 미시뮬 · model-window `/1m/` 행 미테스트 · 비-Windows STAGE 3b skip.
3. **enforce-orchestrator ERR-센티넬 무로깅** — 하네스 유일의 미표면 fail-open.
4. **skill 본문 seal 부재**: start-rpi-cycle 외 6 skill(+design.md) 본문은 존재+마커만 검사 — 내용 드리프트 무봉인. agents/*.md 프롬프트 드리프트 무검사.
5. **opencode skill 본문 parity 오라클 부재**(discovery는 개수+frontmatter만; 파서만 차등검증).
6. **[모델-판단] 게이트의 자기채점 구조**: review-strict가 실행자와 동일 모델 패밀리 — 교차모델 분리 없음(R-C 공통패턴 #8 "cross-vendor validators" 대비).
7. **런타임 관측 부재**: hook_log(로컬 파일)뿐 — 세션/사이클 단위 run-log·게이트 발화 통계·비용 집계 없음(정적 self-check만).
8. **비용·반복 예산 governor 부재**: goal-loop에 per-tool 반복 상한·토큰/비용 ceiling 없음 — 프롬프트-레벨 지시뿐(외부 강제 없음).
9. **메모리 수명주기 정책 부재**: MEMORY.md는 축적만 — consolidation/decay/프루닝 규약 없음, 쓰기 시 리뷰 없음(포이즈닝 표면).
10. **dead-scaffold pruning 트리거 부재**: 모델 개선으로 무용해진 가드 제거 메커니즘 없음(누적 단방향).
11. **OS-레벨 sandbox 층 부재**: bypassPermissions + hook 토크나이저가 전부 — deny-by-default egress/write 없음(단일 운영자 수용이나 무인 goal-loop 확대와 긴장).
