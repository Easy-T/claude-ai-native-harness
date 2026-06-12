# External Standards Audit — 8차원 루브릭 채점 (2026-06-13)

> **성격**: 감사 전용 spec (코드/설정 변경 0). 대상 = Easy-T/claude-ai-native-harness, HEAD `cfe8b61` (cycle-24 마감 상태).
> **방법**: 외부 공개 표준 조사(A) → 루브릭 선확정(B) → repo 실측(C) → 채점(D) → 백로그(E). 순서 고정 — 자체 spec/plan은 Phase C부터 의도 파악용으로만 열람, 자기평가 문구는 점수 근거에서 배제.
> **채점 원칙**: 보수 채점. 4점 이상은 해당 seal/test 인용 필수. 차원마다 갭 ≥1 또는 반증 시도 기록.

**Status:** completed (감사 보고서 — plan 아님)

---

## 0. Baseline 실측 + 무변이 증명

| 게이트 | 결과 | 비고 |
|---|---|---|
| `hooks/tests/run-all.sh` | **114 / 114 passed**, cases.tsv↔run-all 정합 OK, pass rate 100% | exit 0 |
| `setup/verify-setup.sh` | **PASS=63 FAIL=0** | exit 0 |
| `setup/verify-integration.sh` | **PASS=8 FAIL=0** (E2E.A–H) | exit 0 |
| `setup/verify-all.sh` | 의도적 제외 — doctor(변이) 선행 단계가 감사 무변이 원칙과 충돌 | — |

**git status (감사 시작, HEAD cfe8b61)**: `nothing to commit, working tree clean`
**git status (게이트 3종 실행 직후)**: `working tree clean` — 게이트 실행으로 인한 변이 0 확인.
**git status (감사 종료)**: 본 보고서 1파일만 신규 (§7에 커밋 기록).

---

## 1. Phase A — 외부 표준 출처 (9 URL)

| # | 출처 | 본 감사에서의 역할 |
|---|---|---|
| S1 | [Anthropic — Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) | "hooks are deterministic and guarantee the action happens / CLAUDE.md instructions are advisory" — 강제 아키텍처(D1)·컨텍스트 관리(D8)·검증 루프(D2) 기준 |
| S2 | [Anthropic — Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) | ground-truth 검증 루프, guardrails at intermediate steps, 단순성 우선 — D2·D5 기준 |
| S3 | [Anthropic — Writing Tools for Agents](https://www.anthropic.com/engineering/writing-tools-for-agents) | 토큰 효율, 의미 있는 에러 반환, 평가 기반 반복 — D6·D8 기준 |
| S4 | [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/) | LLM01 Prompt Injection / LLM02 Sensitive Info Disclosure / LLM05 Improper Output Handling / LLM06 Excessive Agency — D3 매핑 프레임 |
| S5 | [OWASP Agentic Security Initiative](https://genai.owasp.org/initiatives/agentic-security-initiative/) | agentic 위협·완화 분류, MCP 보안 가이드 — D3 보조 |
| S6 | [Google SAIF — Secure AI Framework risk map](https://saif.google/secure-ai-framework/saif-map) | "restrict tool permissions, observability and policy enforcement, user confirmation before sensitive actions" — D1·D3·D6 기준 |
| S7 | [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework) | Govern/Map/Measure/Manage — D4(Measure)·D7(Govern) 기준 |
| S8 | [Google SRE — Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) | blameless, 시스템·프로세스 root cause, 구체 action item — D5(§4 non-obvious 절차)·D6 기준 |
| S9 | [DORA — Four Keys metrics](https://dora.dev/guides/dora-metrics-four-keys/) + [Continuous Delivery capability](https://dora.dev/capabilities/continuous-delivery/) | 자동화된 release-on-demand 파이프라인, change failure rate — D2(CI)·D7 기준 |

"메타/구글 내부 하네스"는 비공개 — 공개 프록시(S6, S8, S9)만 인용. 추측 인용 0건.

---

## 2. Phase B — 루브릭 (채점 전 확정)

**5점 성숙도 (전 차원 공통):**
1 = 부재 / 2 = prose 권고만 / 3 = 부분 강제·검증 / 4 = 강제 + 검증 + 고장 표면화 / 5 = 4 + 회귀봉인 + 외부표준 명시 충족

**차원별 측정식 (증거 수집 전 고정):**

| 차원 | 측정식 |
|---|---|
| ① 강제 아키텍처 | 쓰기 표면(Write/Edit/NotebookEdit/Bash/MCP) 중 결정론적 게이트가 커버하는 비율 + 우회 경로의 명시성(로깅·표면화) + fail-open의 표면화 여부 |
| ② 검증 파이프라인 | 검증 계층 수(unit/structure/E2E/acceptance) + false-green 방지 장치의 실재(parity·부정 단언·격리) + CI 자동 실행 여부 |
| ③ 보안 | 문서화된 위협모델 ↔ 구현 일치율 + OWASP LLM Top 10 항목별 완화/수락/방치 구분의 정직성 + 우회 경로의 인젝션 내성 |
| ④ 드리프트 방어 | 중복된 거버넌스 사실 중 seal로 봉인된 비율 + seal 유형의 강도(content-parity > count > 존재) + seal 자체의 회귀 검증 |
| ⑤ 수명주기 | R→P→I→Closeout 각 단계가 결정론 강제/자가-표면화/prose 중 어디에 있는가 + 핸드오프 구조의 기계 검증 여부 + postmortem 절차의 강제 수준 |
| ⑥ 관측가능성 | verdict 로깅 커버리지(전 판정 경로 중 로깅되는 비율) + 고장(fail-open)의 자가-표면화 + 로그의 소비(분석·집계) 여부 |
| ⑦ 재현성 | 신선-클론 → 동작까지의 자동화율 + acceptance 게이트가 실제 동작 가능성을 증명하는가(의존성 검증 포함) + 이식성(OS·사용자 독립) |
| ⑧ 컨텍스트 경제 | 캐시 무효화 방지의 강제 수준 + 컨텍스트 사용량 모니터링의 정확성(모델-인지) + 컨텍스트 격리 구조(subagent) + 주장의 측정 근거 |

---

## 3. Phase C — 증거 수집 방법

- explore-strict 8개 팬아웃(차원당 1) — 전부 file:line 인용 강제, spec/plan 열람 금지 조건 부여.
- 게이트 3종 직접 실행(§0) + 핵심 인용 10건 메인 세션에서 직접 spot-check 재확인(`_common.sh:63-68`, `session-start-audit.sh:25-34`, `settings.example.json:26`, `verify-setup.sh:202-211`, `verify-setup.sh:8-10/149-159`, `run-all.sh:654-672`, `doctor.sh:13/251-260`, `redirect-targets.js:45`, `enforce-rpi-cycle.sh:55-64/89-102`, run-all/verify-setup/verify-integration output).
- 자체 spec/plan은 cycle-24 plan 1건만 의도 파악용으로 열람(수락 잔여 판정 ①~⑥의 존재 확인) — 점수 근거로 불사용.

---

## 4. Phase D — 차원별 채점

### ① 강제 아키텍처 — **4 / 5**

**근거 (실측):**
- 차단 4종이 tool 경계에 배선: matcher `Write|Edit|NotebookEdit` = `settings.example.json:36`(orchestrator :40, rpi-cycle :48, secret-scan :52), matcher `Bash` = `settings.example.json:61`(rpi-bash :65, secret-scan :69). exit-2 차단 지점: `enforce-rpi-cycle.sh:24,85,102` / `enforce-rpi-bash.sh:50,60` / `enforce-orchestrator.sh:47` / `enforce-secret-scan.sh:58`.
- 우회는 전부 로깅됨: `RPI_SKIP`(`enforce-rpi-cycle.sh:68-72`, `enforce-rpi-bash.sh:25-28`), `SECRET_SCAN_SKIP`(`enforce-secret-scan.sh:28-31`), trivial ≤5라인(`enforce-rpi-cycle.sh:55-64`, 직접 확인).
- 고장 표면화(부분): 세션 시작 selfcheck가 node-missing/syntax/nonexec를 ALERT 로깅 + stderr 경고(`session-start-audit.sh:25-34`, 직접 확인).

**4점 근거 seal/test (필수 인용):** E2E.A(차단)·E2E.C(RPI_SKIP)·E2E.D(plan 개방)·E2E.E(orchestrator)·E2E.F(bash 사이드도어)·E2E.G(secret) — `verify-integration.sh` 8/8 실측. 단위 114 케이스 + cases.tsv↔run-all 정합(`run-all.sh:654-665`, 직접 확인). matcher drift는 seal #23(isHarness 트리플 parity, `verify-setup.sh:173-193`)이 봉인.

**외부표준 매핑:** S1 "hooks are deterministic… CLAUDE.md instructions are advisory" — 본 하네스는 이 권고를 구조 원칙으로 구현(SECURITY.md:7-8의 자세와 코드 일치). S6 "restrict tool permissions / policy enforcement".

**갭 (5점 불가 사유):**
- **G1-a**: 미커버 쓰기 경로 — `curl -o x.py`, `wget -O`, `perl -i`, `node -e fs.writeFile`, 변수 파일명(`> $F`), 무확장자 파일(Bash `cat > Dockerfile`은 통과, Write 도구의 Dockerfile은 차단 — 비대칭, `_common.sh:118-128` vs `redirect-targets.js:14-15`). 탐지 목록은 `redirect-targets.js:27-66`이 전부이며 `:45` 주석이 변수/f-string 미탐지를 Non-Goal로 명시(의식된 상한, 직접 확인).
- **G1-b**: MCP 도구(`mcp__*`)는 두 matcher 어디에도 안 걸림(`settings.example.json:36,61`이 전부) — MCP 경유 파일 쓰기는 무게이트.
- **G1-c**: lib 파서 런타임 크래시는 침묵 fail-open(`enforce-rpi-bash.sh:32` `2>/dev/null || true` → :35 exit 0) — selfcheck는 syntax/exec만 잡고 런타임 실패는 못 잡음.
- **G1-d**: ≤5라인 Edit 연쇄로 코드 파일 전체 재작성 가능(호출 단위 판정, 누적 추적 없음 — `enforce-rpi-cycle.sh:55-64`).

### ② 검증 파이프라인 — **4 / 5**

**근거 (실측):**
- 4계층: unit 114(러너가 런타임 카운트, `run-all.sh:649,667-672`) / structure 63(`verify-setup.sh`, exit $FAIL :239) / E2E 8(mktemp 격리 `verify-integration.sh:4-5` + trap) / acceptance 5단계(`verify-all.sh:4-16`).
- false-green 방지 실재: cases.tsv↔run-all 정합 검사(`run-all.sh:654-665` — phantom 케이스 = exit 1, 직접 확인), 부정 단언 seal #25(`verify-setup.sh:206-211` — 고정 $HOME 경로 재출현 시 FAIL, 직접 확인), count-parity #20/#21(`verify-setup.sh:149-159` — README 숫자 ≠ 실측 시 FAIL, 직접 확인).

**4점 근거 seal/test:** #25는 "금지 패턴이 있으면 FAIL"인 유일한 부정 단언 seal — 격리 회귀(cycle-18 클래스)를 봉인. #20/#21은 문서-실측 카운트 드리프트 봉인. 정합 검사는 선언-미구현 케이스를 차단.

**외부표준 매핑:** S2 "require ground truth and verification loops", S1 "give Claude a check it can run". S9 DORA CD — "release on demand quickly, safely" 기준.

**갭:**
- **G2-a**: **CI 부재** — repo 루트에 `.github/` 없음(Glob 실측 0건; `github-ci.yml.tpl`은 생성-프로젝트용 템플릿일 뿐, `verify-setup.sh:66-67`). 게이트 실행이 전적으로 로컬·수동 — S9(CD 자동화) 명시 미충족.
- **G2-b**: 정합 검사가 단방향·텍스트 매칭(`grep -qF "$rid"`, `run-all.sh:659`) — ID가 주석에만 있어도 통과. 역방향(run-all에만 있는 테스트)은 수동 reconcile.
- **G2-c**: #20/#21은 README가 카운트 언급 자체를 지우면 공허 통과(vacuous pass).
- **G2-d**: run-all은 pass rate ≥95%면 통과(`run-all.sh:667-671`) — 개별 실패 ≤5건이 스테이지를 green으로 만들 수 있음.
- **G2-e**: statusline 테스트(`tests/statusline/run-tests.sh`)는 verify-all 미포함 — acceptance 게이트 밖.

### ③ 보안 — **3 / 5** ⟵ 최약 차원 (min)

**근거 (실측):**
- 위협모델↔구현 정직 일치: SECURITY.md의 주장 6건 전건이 구현 또는 "의도적 부재"로 대응됨(hook 4종 배선 `settings.example.json:40,48,52,65,69`; credentials gitignore `.gitignore:2`; doctor 권한 검사 `doctor.sh:324-340`; 임의 Bash 미차단은 SECURITY.md:15가 스스로 잔여로 명시).
- secret-scan: 패턴 7계열(`enforce-secret-scan.sh:36-42` — Anthropic/AWS/GitHub/GitLab/Slack/Google/PEM), placeholder 허용(:44), 값 비로깅 확인(:52 — $PAYLOAD 미전달, `_common.sh:52-59` 인자 4개만 기록). E2E.G + 단위 케이스로 검증됨.

**OWASP LLM Top 10 2025 매핑 (S4):**
| 항목 | 상태 |
|---|---|
| LLM01 Prompt Injection | **무완화** — hooks/ 전체에서 입력 새니타이즈·instruction-source 분리 0건(grep 실측). SECURITY.md:13이 표면을 인정하나 완화는 출력측뿐 |
| LLM02 Sensitive Info Disclosure | 부분 완화 — secret-scan(시그니처 기반, SECURITY.md:31이 한계 명시) + credentials gitignore + chmod |
| LLM05 Improper Output Handling | 부분 — 모델 출력(코드 쓰기)이 RPI/secret 게이트를 통과해야 함. 단 게이트 미커버 표면(G1-a/b)은 그대로 |
| LLM06 Excessive Agency | **의식적 수락** — live `settings.json:36` bypassPermissions + `:133` skipDangerousModePermissionPrompt. 배포 템플릿은 `settings.example.json:26` `"default"`(보수 기본값, 직접 확인) |

**3점 사유 (부분 강제·검증에 머무는 이유 / 4점 불가):** secret-scan(E2E.G)·rpi-bash(E2E.F)는 실제 강제+검증된 통제라 level 2(prose only)를 넘지만, OWASP 최고-임팩트 표면(LLM01 무완화 + LLM06 bypassPermissions)은 prose 인정뿐 → 부분 커버 = level 3. 4점(고장 표면화)은 G3-a의 실시간 무표면이 막음.

**갭:**
- **G3-a (최중대)**: 우회 knob이 **인젝션 내성 없음** — 프롬프트 인젝션이 Bash 한 줄(`RPI_SKIP=x ...` 전치 또는 `export SECRET_SCAN_SKIP=y`)로 게이트를 무력화 가능. bypassPermissions 자세에서 Bash는 무프롬프트 실행되므로, LLM01(무완화) × env-knob 우회 = 게이트 전체의 실효 상한. 우회는 로그에 남지만(§D1) **세션 내 실시간 표면화 없음** — 사용자가 로그를 읽지 않으면(G6-c: 로그 무소비) 인지 불가.
- **G3-b**: fail-open 경로(require_node 침묵 `_common.sh:63-68`, 파서 크래시)가 SECURITY.md 잔여 위험 목록에 **미기재** — 문서화 갭.
- **G3-c**: Edit new_string 단편만 스캔(`enforce-secret-scan.sh:22`) — 시크릿을 2회 Edit으로 분할 기입하면 비탐지.
- **G3-d**: live `settings.json`(bypassPermissions) vs `settings.example.json`(default)의 자세 분기가 SECURITY.md에 명시 없음 — 배포본을 그대로 쓰는 사용자와 live 운영자의 보안 자세가 다른데 문서가 이를 구분 안 함(drift인지 의도인지 불명).

### ④ 드리프트 방어 — **4 / 5**

**근거 (실측):**
- 11개 seal 실재(#17~#28, #26은 의도적 소각): `verify-setup.sh:102-235`. 유형 — content-parity(#17/#18/#19/#22/#23), count-parity(#20/#21 `:149-159`), set-coverage(#24 doctor⊇disk), 부정 단언(#25 `:206-211` — 유일), 구조 불변식(#27 `:213-228` — plan Status), validity(#28 `:230-235` — `bash -n`). 전건 PASS(63/0).
- drift-seal 개념 문서화: `CONTEXT.md:28-30`("특정-인스턴스 체크 … generalized 프레임워크 아님").

**4점 근거 seal/test:** #25 부정 단언(cycle-18 격리 회귀 봉인), #23 isHarness 트리플 parity(matcher drift 감지, `verify-setup.sh:173-193`), #27 plan Status 봉인. 모두 verify-setup 63/0에 포함.

**외부표준 매핑:** S7 NIST "Measure"(지속 측정으로 리스크 추적) — seal = 거버넌스 사실의 회귀 측정. SSOT 원칙.

**갭:**
- **G4-a**: seal 자체가 회귀 테스트 안 됨 — seal을 의도적으로 깨고 FAIL을 기대하는 자동 테스트 부재(`setup/tests/`엔 doctor.test.sh만; `hooks/tests/`에 seal-RED 케이스 grep 0건). 깨진 seal이 침묵으로 단언을 중단해도(예: #17이 Phase R 도구 드롭 시 short-circuit) 미감지.
- **G4-b**: 미봉인 중복 — README "9개 hook" 숫자(`README.md:28` ↔ `verify-setup.sh:48-51` ↔ doctor REQUIRED_HOOKS; #24는 doctor⊇disk만 봉인, README 숫자는 무봉인); env-knob 표(`README.md:448-454` ↔ 코드); "63 PASS"(`README.md:282`) 하드코딩; "24개 doctor"(`README.md:26,231`).
- **반증 시도**: 미봉인이 "방치"가 아닌 "의식적 보류"인지 확인 → #26이 안정 앵커 부재로 의도적 소각(`CONTEXT.md:29` 기록). 즉 G4-b의 일부는 인지된 갭(genesis-vs-current 경계). 그러나 README 숫자류는 안정 앵커(실측 카운트)가 있으므로 #20/#21 패턴으로 봉인 가능 — 미봉인 여지 실재.

### ⑤ 수명주기 — **4 / 5**

**근거 (실측):**
- 두 enforced 링크: spec-before-plan(`enforce-rpi-cycle.sh:15-27` exit 2) + plan-before-code(`:89-102` exit 2, bash-side parity `enforce-rpi-bash.sh:38-42`). has_active_plan = head-20 + 명시 Status regex(`_common.sh:89-90,98-110`; checkbox-fallback 제거 cycle-23).
- plan Status 봉인: #27(`verify-setup.sh:213-228` — 전 plan 명시 Status + active ≤1, 직접 확인). state.json cycle counter(`state.json:3` count=24, `:7` last_drift_check 2026-06-12).
- handoff 3-label(`goal:`/`read-before:`/`autonomy:`): `skills/start-rpi-cycle/SKILL.md:207-215`, #18이 skill 텍스트의 라벨 존재를 봉인.

**4점 근거 seal/test:** E2E.A(plan 없으면 차단)·E2E.D(active plan 개방) — verify-integration 실측. #27이 closeout의 Status-flip 누락(stale-active)을 봉인. 세션 시작 stale-active 1줄 표면화(`session-start-audit.sh:15-16`).

**외부표준 매핑:** S2 "set stopping conditions / human review at checkpoints"(closeout user-approval gate, SKILL.md). S8 SRE postmortem(§4 non-obvious 5 Whys 절차, `CLAUDE.md:28-34`).

**갭:**
- **G5-a**: non-obvious 등록 절차(`CLAUDE.md:28-34`)는 **prose only** — hook/check 0건(hooks/·verify-setup grep `non-obvious` 0건). S8 postmortem의 "구체 action item 강제"에 미달(자가-규율 의존).
- **G5-b**: phase 내부 순서(R: brainstorming→grill→explore)·closeout 단계(drift check 실행)·handoff **내용** 완전성은 advisory/self-surfaced — 물리 강제 불가(PreToolUse가 workflow 프롬프트 검사 불가, F12 ceiling). #18은 skill **문서**만 봉인, 런타임 보고의 라벨 내용은 미검증.
- **G5-c**: 단일 stale-active plan은 verify-setup 실행 전까지 게이트를 개방 유지(#27이 seal이나 실시간 hook 아님) — 사이클 간 마감 누락 시 다음 verify-setup까지 무방비.

### ⑥ 관측가능성 — **3 / 5** ⟵ 최약 동률

**근거 (실측):**
- 로그: `~/.claude/hooks/.log/YYYY-MM.log`(월별, `_common.sh:54-59` — TSV `ts/hook/target/verdict/reason`), 28 call sites, 2개 월별 파일 실재. verdict 어휘 PASS/BLOCK/ALERT.
- 자가-표면화: `emit_system_message`(`_common.sh:134`; auto-compact-watch:36, verify-loop-watch:38), `emit_additional_context`(`_common.sh:136-139`; surface-constitution:24,36), 세션 시작 selfcheck(`session-start-audit.sh:25-34`, 직접 확인), statusline 5줄(`statusline.sh:154-215`).
- 진단: doctor.sh ~56 `check` 호출 + 자동 치료(jq `:146-166`, audit marker `:177-189`, 로그 rotation `:262-274`).

**3점 사유 (4점 불가):** 표면화·로깅·진단이 실재하고 일부는 검증됨(session-start selfcheck, statusline 테스트). 그러나 가장 안전-임계 경로(블록 hook의 fail-open)가 **즉시 침묵** + 로그가 write-only → "고장 표면화"(level 4) 미충족, 부분 = level 3.

**외부표준 매핑:** S6 SAIF "observability and policy enforcement", S8 SRE(incident history 기반 학습), S3 "meaningful errors".

**갭:**
- **G6-a**: 침묵 fail-open — `require_node` exit 0 무로깅·무표면(`_common.sh:63-68`). selfcheck(`session-start-audit.sh:25-34`)는 **차기 세션**에서 node-missing/syntax/nonexec만 잡고 lib 파서 **런타임** 실패는 못 잡음(`doctor.sh:306-309`는 존재만 확인).
- **G6-b**: verdict 로깅 불완전 — whitelist exit(`enforce-rpi-cycle.sh:31,43`), clean-payload allow(`enforce-secret-scan.sh:26,50`), 파서 ERR/EMPTY(`enforce-orchestrator.sh:17-18`)는 무로깅 exit 0.
- **G6-c**: 로그 **무소비** — `.log`를 읽거나 집계하는 코드 0건(doctor rotation만 참조). BLOCK/ALERT 이력이 기록되나 분석·표면화 안 됨 → S8 postmortem(이력 기반 학습·재발 방지)의 핵심 미달.

### ⑦ 재현성 — **3 / 5** ⟵ 최약 동률

**근거 (실측):**
- install.sh: node/bash/git 하드페일(`:26-35`), 27-file 검사(`:50-86`), chmod +x(`:90-92`), settings 병합(hooks idempotent `:108-115`), doctor 호출(`:131-134`).
- 이식성: `normalize_path`(`_common.sh:80-83`) backslash→slash + 각 hook 적용(enforce-rpi-cycle:9, enforce-orchestrator:7 등) + Windows-backslash 단위 테스트(`run-all.sh:572`). verify-integration mktemp 격리.

**외부표준 매핑:** S7 NIST "Govern"(재현 가능한 셋업 거버넌스), S9 DORA(배포 신뢰성).

**3점 사유 (4점 불가):** 핵심 install은 강제+검증(prereq 하드페일, normalize_path 테스트)지만 신선-클론 동작 보증에 구멍 — 의존성 미충족이 FAIL 아닌 WARN으로 숨어(고장 표면화 미달) 부분 = level 3.

**갭:**
- **G7-a**: **하드코딩 사용자 경로** `WINDOWS_CLAUDE_HOME_CANDIDATE="/mnt/c/Users/12132/.claude"`(`doctor.sh:13`, 직접 확인) — 커밋된 스크립트라 타 사용자 WSL에서 비이식.
- **G7-b**: **플러그인 의존성 false-green** — "ALL PASS"가 의존성을 증명 못 함: superpowers=WARN(`doctor.sh:251-260`, 직접 확인), skill-creator/claude-md-management=무검증 → 신선 클론이 verify-all 통과해도 RPI 사이클 비작동. ②의 G2-a(CI 부재)와 결합 시 회귀 미감지.
- **G7-c**: README/install.sh 불일치 — claude-md-management `README.md:87`(선택) vs `install.sh:147-151`(필수); `README.md:122` "4개 plugin" vs STEP 4 3개 커맨드(mattpocock는 doctor-설치 skill).
- **G7-d**: 멀티-HOME(Windows/WSL settings 독립)은 README prose only(`README.md:44,454`) — WSL namespace FAIL gate(`doctor.sh:105-119`) 외 settings sync 코드 없음.

### ⑧ 컨텍스트 경제 — **4 / 5**

**근거 (실측):**
- 모델-인지 창: `lib/model-window.js:10-16`(fable/opus-4-7/4-8/1m→1,000,000, 기본 200,000, `CONTEXT_LIMIT` override `:6-8`), 사용량 `lib/transcript-usage.js:16-17`(input+cache_read+cache_creation 최댓값), 임계 공식 `auto-compact-watch.sh:26-30`(override 55→경고 45%), 1세션 1회 마커 `:13-14,34`.
- 표시·격리: statusline context 바(`statusline.sh:140-191`). CLAUDE.md ≤200 seal(`verify-setup.sh:8-10`, 실측 93줄). 3 isolation agents(explore/review/execute-strict, `agents/*.md:15` tool-restricted + `:16` ≤500단어 contract).

**4점 근거 seal/test:** lib 단위 테스트(`run-all.sh` output L1-2: `lib: transcript-usage ✓`, `lib: model-window ✓`, 직접 확인) + #1 CLAUDE.md size seal. fable→1M 회귀 수정(HEAD `cfe8b61`) = 미등록 1M 모델 조기 오경고를 표면화 후 교정한 증거.

**외부표준 매핑:** S1 "context window is the most important resource to manage / use subagents to keep main conversation clean", S3 토큰 효율.

**갭:**
- **G8-a**: 실제 cache hit/miss **측정 없음** — "비용 ~20배"(`CLAUDE.md:4,12`)는 측정 근거 없는 prose. transcript-usage는 cache 토큰을 점유 합산에만 사용, 적중률 미측정.
- **G8-b**: stable-claude-md 경고는 stderr(`stable-claude-md.sh:23`) — PreToolUse exit 0의 stderr는 모델 미도달(`_common.sh:137-139` 주석) → 사용자-표시용, 모델 행동 교정 효과 없음.
- **G8-c**: 글로벌 `~/.claude/CLAUDE.md` 수정은 stable-claude-md 미커버(`:11` — "별도 audit hook이 관리"). 캐시 비용 동일 발생하나 세션-중 경고 없음.
- **G8-d**: unknown 모델 fallback 비대칭 — model-window 200K(보수) vs statusline CW=0(보고값 신뢰, `statusline.sh:147`).

---

## 5. Phase D — 종합 점수표

| 차원 | 점수 | 4점↑ seal/test 근거 | 헤드라인 갭 |
|---|:---:|---|---|
| ① 강제 아키텍처 | **4** | E2E.A–G(8/8) + 114 단위 + #23 matcher seal | MCP 무게이트, 미커버 bash 벡터 (G1-a/b) |
| ② 검증 파이프라인 | **4** | #25 부정 단언 + #20/#21 카운트 seal + 정합 검사 | **CI 부재** (G2-a) |
| ③ 보안 | **3** | (4 미달 — secret-scan E2E.G는 부분 슬라이스만) | **인젝션×env-knob 우회 + 실시간 무표면** (G3-a) |
| ④ 드리프트 방어 | **4** | #25/#23/#27 (verify-setup 63/0) | seal 자체 무회귀테스트 (G4-a) |
| ⑤ 수명주기 | **4** | E2E.A/D + #27 plan-Status seal | non-obvious prose-only (G5-a) |
| ⑥ 관측가능성 | **3** | (4 미달 — 즉시 fail-open 침묵) | 침묵 fail-open + 로그 무소비 (G6-a/c) |
| ⑦ 재현성 | **3** | (4 미달 — 의존성 미충족이 WARN으로 숨음) | 하드코딩 경로 + plugin false-green (G7-a/b) |
| ⑧ 컨텍스트 경제 | **4** | lib 단위 테스트 + #1 size seal + fable→1M 교정 | 캐시 비용 미측정 (G8-a) |

**총평 (min 기준, 평균 아님):** **최약 차원 = ③ 보안 (3)**, 동률 ⑥ 관측가능성·⑦ 재현성 (3). 평균(3.625)은 무의미 — 게이트 사슬은 **가장 약한 고리**로 결정된다. 본 하네스는 자신이 설계 목표로 삼은 결정론적 강제·드리프트·컨텍스트(①②④⑤⑧=4)는 외부표준에 부합하나, **agentic 보안 표면(③)·고장 관측(⑥)·신선-클론 이식(⑦)**은 단일-운영자 가정에 기대 부분 구현에 머문다. 세 3점은 서로 결합한다: 보안 우회가 로그에만 남고(③ G3-a) → 로그가 소비 안 되며(⑥ G6-c) → CI가 없어(② G2-a) 신선-클론 회귀가 미감지(⑦ G7-b).

---

## 6. Phase E — 우선순위 백로그 (impact × effort) + 차기 사이클 goal 초안

세 3점 차원을 결합 갭으로 묶어 impact×effort 상위 3건 산출. 각 항목은 차기 `/goal` 3라벨(goal / read-before / autonomy) 완비.

### 백로그 #1 — 게이트 우회·fail-open의 실시간 표면화 + 로그 소비 (③⑥ 교차, **최우선**)
- **impact: 매우 높음** (min 차원 ③의 실효 상한 G3-a + ⑥의 핵심 G6-a/c를 동시 해소; 전 게이트의 신뢰도가 여기에 걸림)
- **effort: 낮음~중간** (fail-open 경로에 이미 deferred selfcheck 존재 — 즉시 `hook_log` 추가 + 우회 사용 시 세션-가시 표면 1줄 + doctor에 당월 BLOCK/ALERT 집계 sub-check 추가)

> **goal:** `enforce-*` hook의 fail-open(require_node 침묵 `_common.sh:63-68`, 파서 크래시 `enforce-rpi-bash.sh:32`)을 즉시 `hook_log` ALERT + 세션-가시 표면화로 전환하고, `RPI_SKIP`/`SECRET_SCAN_SKIP` 우회 사용을 세션 내 실시간으로 1줄 표면화한다. doctor.sh에 당월 `.log` BLOCK/ALERT 집계 read-only sub-check를 추가해 로그를 소비(S8 postmortem 이력)로 만든다. SECURITY.md 잔여 위험에 fail-open 경로를 명시 추가(G3-b). 산출물 = 코드 변경(hooks + doctor) + SECURITY.md 갱신 + 신규 단위 케이스(fail-open이 로그를 남기는지 RED→GREEN) + verify-setup seal 후보. RPI 사이클 필수(코드 변경).
> **read-before:** 1. `docs/superpowers/specs/2026-06-13-external-standards-audit.md` §D③·§D⑥ (본 감사) 2. `hooks/_common.sh`(require_node·hook_log·emit_*) 3. `SECURITY.md`(잔여 위험 절) 4. `hooks/tests/cases.tsv`+`run-all.sh`(케이스 추가 패턴) 5. `hooks/session-start-audit.sh:25-34`(기존 deferred selfcheck)
> **autonomy:** fail-open을 차단으로 바꾸지 말 것 — 표면화만(fail-open은 의도된 트레이드오프, CONTEXT.md "fail-open"). 우회 표면화는 차단 아닌 advisory. 로그 집계는 read-only(값 비로깅 불변식 유지 — secret 값 절대 미표시). 분기는 best-practice로 진행. 새 seal은 안정 앵커 있을 때만(generalized 금지).

### 백로그 #2 — 하네스 repo 자체 CI 파이프라인 (②⑦ + S9 DORA)
- **impact: 높음** (게이트가 전부 로컬·수동 G2-a → push마다 자동 실행 시 회귀·신선-클론·plugin-dep 결함을 지속 감지; DORA CD 명시 충족)
- **effort: 중간** (게이트는 이미 exit-coded — `.github/workflows/ci.yml`로 run-all + verify-setup + verify-integration를 묶고 fresh-checkout에서 실행)

> **goal:** 하네스 repo 루트에 GitHub Actions CI(`.github/workflows/ci.yml`)를 추가해 push/PR마다 `hooks/tests/run-all.sh` + `setup/verify-setup.sh` + `setup/verify-integration.sh`를 fresh-checkout(ubuntu + node)에서 실행하고 실패 시 빨강. doctor(변이)는 제외하거나 별도 비-게이팅 job으로. 신선-clone에서 실제 통과하는지 검증(G7-b의 plugin-dep는 CI에서 의존성 부재로 드러나므로 WARN→명시 문서화). 산출물 = workflow yaml + README 배지/검증 절 갱신 + (선택) verify-all에서 doctor 선행 자가치유 순서 문서화. `.github/`는 비코드라 RPI 게이트 무관하나 yaml은 신중히.
> **read-before:** 1. 본 감사 §D②·§D⑦ 2. `setup/verify-all.sh`(스테이지 순서·doctor 선행 이슈) 3. `setup/verify-integration.sh`(mktemp 격리 — CI에서 HOME 처리) 4. `skills/init-ai-ready-project/templates/github-ci.yml.tpl`(생성-프로젝트용 기존 패턴 재사용) 5. `README.md:114-122`(검증 절)
> **autonomy:** CI는 게이트를 **복제**할 뿐 새 강제 로직 추가 금지(드리프트 방지). doctor를 CI 게이팅에 넣지 말 것(변이·환경 의존 — 감사 §0이 verify-all 제외한 이유와 동일). HOME/경로는 normalize_path가 이미 처리하므로 ubuntu에서 그대로 동작 기대; 실패 시 best-practice로 환경 변수 조정. plugin 부재로 일부 E2E가 깨지면 그 사실을 표면화(숨기지 말 것).

### 백로그 #3 — 신선-클론 이식성 + 플러그인 의존성 게이트 (⑦)
- **impact: 높음** (하드코딩 경로 G7-a = 타 사용자에서 즉시 깨짐; "ALL PASS=ready"가 RPI 핵심 의존성에 false-green G7-b)
- **effort: 낮음** (하드코딩 경로를 `$HOME` 유도로 치환; superpowers 체크를 WARN→명확한 acceptance 게이트 또는 문서화된 비-PASS 의존성으로 승격; README/install.sh 불일치 정정)

> **goal:** `doctor.sh:13`의 하드코딩 `/mnt/c/Users/12132/.claude`를 `$HOME`/환경 유도 경로로 치환(타 사용자 WSL 이식). 플러그인 의존성(superpowers/skill-creator)을 verify-all의 명시 게이트 또는 doctor의 분명한 비-PASS 상태로 승격해 "ALL PASS"가 RPI 작동을 거짓 보증하지 않게 한다(G7-b). README/install.sh 불일치(claude-md-management 선택/필수, "4개 plugin" vs 3 커맨드) 정정. 산출물 = doctor.sh + install.sh 코드 변경 + README 정정 + 신규/갱신 단위 케이스(이식 경로 RED→GREEN). RPI 사이클 필수.
> **read-before:** 1. 본 감사 §D⑦ 2. `setup/doctor.sh:13,105-119,251-260`(하드코딩·WSL gate·plugin 체크) 3. `setup/install.sh:147-152`(plugin 안내) 4. `README.md:81-122`(plugin 표·검증) 5. `setup/verify-setup.sh:31`(grill-with-docs 제외 패턴 — plugin 검증 경계 참고)
> **autonomy:** 경로 치환은 기존 normalize_path/resolve_cwd 규약과 일관되게. plugin을 verify-setup의 PASS 조건으로 넣을지 doctor WARN 강화로 둘지는 "신선-클론이 거짓 green 안 됨"을 만족하는 선에서 best-practice 선택(과한 게이트 = init 마찰 주의). README는 비코드라 자유 편집, 단 카운트류는 #20/#21 seal 패턴과 충돌 없게.

---

## 7. 무변이 증명 + 커밋 기록

- **시작 git status** (HEAD cfe8b61): `working tree clean`.
- **게이트 3종(run-all/verify-setup/verify-integration) 실행 직후**: `working tree clean` — 게이트가 워킹트리를 변형하지 않음 확인. verify-all은 doctor(변이) 선행 때문에 의도적 미실행.
- **종료 git status**: 본 보고서 1파일(`docs/superpowers/specs/2026-06-13-external-standards-audit.md`)만 신규(untracked). 코드/설정 변경 0.
- **커밋**: 보고서 1파일만 명시 staging(`git add <보고서경로>`, `git add -A` 미사용) → 단일 커밋 → push → `ahead 0`.

> 비고(감사 중 발견, 되돌리지 않음): 본 파일의 125줄 truncated 선행 초안이 타깃 경로에 이미 존재(미커밋). 동일 goal의 이전 턴이 dimension ③에서 중단된 산출물로 판단 — 모든 file:line 인용을 독립 재검증한 뒤 완성본으로 확정함.
