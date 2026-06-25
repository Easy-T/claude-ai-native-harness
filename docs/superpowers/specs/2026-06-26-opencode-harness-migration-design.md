# opencode 하네스 마이그레이션 설계 (Claude Code ~/.claude → opencode)

**Date:** 2026-06-26
**Status:** Design — awaiting user spec review → writing-plans
**Subsystem:** opencode-harness (신규 durable subsystem)
**Version anchor:** opencode **v1.17.11** 타깃 (런타임 바닥 **≥1.17.10**), 현재 설치 **v1.17.9** 호환. 플러그인 API = **v1 Promise-style** (V2 네임스페이스 API는 도구 가로채기 표면이 없어 미사용).

> 본 spec은 4개 리서치 워크플로(① 일반 opencode 확장표면 ② 1.17.9 소스 핀 ③ ~/.claude 하네스 전수 인벤토리=46 불변식 ④ 마이그레이션 매트릭스+적대적 최적성 ⑤ V2 플러그인 API)의 소스-검증 결과를 종합한 것이다. 모든 버전 주장은 `sst/opencode` 태그 + `@opencode-ai/plugin` tarball 직접 확인에 근거한다.

---

## 1. 목표 & 제약

**목표:** 사용자의 Claude Code 전역 거버넌스 하네스(`~/.claude`)를 opencode로 이식해, opencode에서 동일한 RPI 강제·제약 서브에이전트·거버넌스·검증 체계를 재현한다.

**제약 (확정):**
- **C-1 배포:** 로컬 Windows PC(Git Bash+node 존재)에서 개인-우선 구축 → **zip 한 벌로 말아** (likely offline/restricted) 회사 환경에 반입 → `~/.config/opencode/`에 언집 → **런타임 인터넷 0**(git/npm 페치 없음) → **전 기능 검증** 필수.
- **C-2 스코프:** 최대 이식. 불가능한 것은 **최선의 대체 수단**으로 처리하며 **기능을 조용히 누락하지 않는다**(no silent drops).
- **C-3 플러그인 API:** v1 Promise-style (1.17.9 및 이후 공통). V2/네임스페이스 훅(1.17.10+)은 도구/권한/이벤트 가로채기가 없어 **미사용**.

---

## 2. 핵심 설계 결정 (ADR-style)

- **DEC-1 (아키텍처 = C′):** 런타임 플러그인은 **순수 Bun/TS**로 작성하되, 검증된 **순수 node 파서를 Bun에서 그대로 재사용**(`redirect-targets.js`, `skeleton-scan.js`, `model-window.js`)하고, 단순 게이트 글루(`has_active_plan`/`is_code_path`/`plan_status`/secret 패턴)만 TS로 재표현한다. 기존 bash 훅 + `cases.tsv`(156) + verify-setup은 **차등 등가성 오라클(differential conformance oracle)** 로 보존하여 빌드박스에서 양엔진 `diff==∅`로 동치를 증명한다.
  - *근거:* A(bash 어댑터)는 오프라인 회사 박스의 런타임 bash/coreutils/powershell 의존으로 탈락. B(순수 재작성)는 검증된 212줄 파서+156케이스 코퍼스를 폐기하면서 C′ 대비 이식성 이득 0. C′만이 런타임 오프라인 안전 + 검증 코드 재사용 + 테스트 투자 보존을 동시 달성.
- **DEC-2 (플러그인 한 벌, v1):** 함수-export 형태의 v1 Promise 플러그인 1개. deny = `throw`. **버전 분기 없음.** v1 플러그인은 1.17.10/1.17.11에서 하위호환 그대로 로드. **로컬 `~/.config/opencode/plugin/*.ts`** 로 배치(오프라인 자동 로드, compat 게이트 우회). `plugin:[...]` 배열은 Bun-install=네트워크라 **미사용**.
- **DEC-3 (타깃 1.17.11, 바닥 1.17.10):** R1(자율-서브에이전트 내용 강제)은 **런타임 ≥1.17.10**의 중앙집중 도구 래퍼(`session/tools.ts:102`)가 닫는다 — 동일 v1 훅이 서브에이전트 호출에도 발화. 1.17.11은 1.17.10과 플러그인 API 바이트 동일(데스크톱 UI만 차이) → 권장 핀. **1.17.9에 남아도 동일 플러그인이 degraded(프라이머리만)로 무중단 동작.**
- **DEC-4 (3층 defense-in-depth):** 단일 차단점 의존 금지.
  - **L1 헌법(항상 로드):** 전역 `~/.config/opencode/AGENTS.md` + `instructions[]`.
  - **L2 동적 게이트(플러그인):** `tool.execute.before` `throw` — 프라이머리 + (≥1.17.10) 서브에이전트의 `write/edit/apply_patch/bash`를 **내용 검사**하고 차단. MCP 도구도 발화(#2319 fixed).
  - **L3 선언 바닥(권한):** `permission` deny 맵(`opencode.json` + agent frontmatter) — 서브에이전트 도구호출을 **패턴**으로 게이트(PR#23290로 자식 세션에 deny 상속). deprecated `tools:` 대신 `permission` 사용.
- **DEC-5 (정직한 충실도 헤드라인):** 프라이머리 에이전트(대화형) 경로 = **Full**. 자율-서브에이전트 *내용 검사*·*모델 주입* 경로 = 1.17.9에서 **Substitute~Absent** → ≥1.17.10에서 **near-Full**(내용 강제 회복, 단 에이전트 신원/셸 불투명성 잔여).

---

## 3. opencode 1.17.9/1.17.11 역량 (소스 검증)

| 역량 | 상태 | 비고 |
|---|---|---|
| `opencode.json` + `instructions[]` | 확정 | `~/` 확장·원격 URL 지원. `reference`→`references` 키 개명(v1.17.1, 구키 deprecated alias). |
| 전역 `~/.config/opencode/AGENTS.md` 자동로드 | 확정 | **first-match-wins**(조상 비-스택) → 횡단 규칙은 전역 파일에. `~/.claude/CLAUDE.md`는 `disableClaudeCodePrompt` 게이트 fallback. |
| 네이티브 skills | 확정 | `{skill,skills}/**/SKILL.md`(단·복수 모두), `skill` 도구. `~/.claude/skills`는 plural-only + `disableClaudeCodeSkills`(기본 ON=꺼짐) → **의존 금지, 번들에 직접 동봉**. |
| markdown agents | 확정 | `{agent,agents}/**/*.md`, frontmatter `mode:primary\|subagent\|all` + `permission`. `tools:` deprecated(정규화는 됨). |
| `permission` 맵 | 확정 | `allow\|ask\|deny`; `bash/edit/read/...` `Record<pattern,action>`(글롭), **last-match-wins**(`findLast`). **서브에이전트 게이트함**(PR#23290). |
| 로컬-dir 플러그인 | 확정 | `~/.config/opencode/plugin/` 디스크 자동로드, **네트워크 0**. `plugin:[]` 배열=Bun-install=네트워크. 로컬 파일은 compat 게이트 우회. |
| `tool.execute.before` throw-deny | 확정 | `(input:{tool,sessionID,callID}, output:{args})=>Promise<void>`. **throw=차단**(`prompt.ts`/`session/tools.ts` Effect 체인, rejection 전파·미-swallow). `output.args` 변형=rewrite. **입력에 file_path·cwd 없음** → 경로는 `args`(edit/write→`filePath`; bash→`command`), cwd는 플러그인 init 컨텍스트 `{directory,worktree}`. |
| 서브에이전트 발화 | **≥1.17.10** | 중앙집중 래퍼(`session/tools.ts:102`)가 task 자식에도 동일 훅 발화. 1.17.9엔 없음. |
| `tool.execute.after` | 확정 | observe-only. |
| `event` catch-all | 확정 | `session.created/idle/deleted/compacted`, `file.edited` 등. **SessionEnd 없음**(idle/deleted/dispose), **Stop 없음**(idle 근사). **event 훅 에러 swallow** → load-bearing 차단 금지. |
| `permission.ask` 훅 | 확정 | `output.status` 강제. |
| `experimental.chat.system.transform` / `…session.compacting` | 존재·**불안정** | 모델-주입 가능하나 patch마다 시그니처 변동 → load-bearing 금지. |
| V2 네임스페이스 API | 1.17.10+ | `agent/aisdk/catalog/command/...` *설정·레지스트리 변환*만. **도구/권한/이벤트 가로채기 없음** → R1 무관, 미사용. |
| 최신 안정 | **1.17.11**(2026-06-25) | 1.17.10과 플러그인 API 바이트 동일. |

**이슈 상태:** #2319(MCP 무훅) CLOSED 2025-08-30(fixed). #5894(서브에이전트 우회) CLOSED — 중앙집중 래퍼는 ≥1.17.10. #13521(중앙집중) CLOSED 2026-02-27. **#15403(hook 입력에 agent 신원) OPEN** → 서브에이전트 *식별*은 `sessionID→agent` SDK 역해석 필요. PR#23290(자식 세션 deny/external_dir 상속) MERGED 2026-04-30.

---

## 4. 마이그레이션 매트릭스 (서브시스템별)

| 서브시스템 | opencode 메커니즘 | 충실도 | 잔여 위험 | 테스트 |
|---|---|---|---|---|
| RPI plan-gate (불변식 1-12, 프라이머리) | `tool.execute.before`(write/edit/apply_patch/bash) throw; `redirect-targets.js` 재사용; `has_active_plan`/`is_code_path`/`plan_status` TS 포팅; cwd=init `{directory,worktree}` | **Full** | arg-key drift→silent allow (R2) | 오라클 30행 diff + E2E A/D/F |
| RPI plan-gate (서브에이전트) | ≥1.17.10 동일 훅 발화 → 내용 검사 차단; 1.17.9는 `permission.bash` 바닥 | **≥1.17.10 near-Full / 1.17.9 Substitute** | 1.17.9 내용검사 불가 (R1) | E2E.I 서브에이전트 throw + permission deny |
| RPI inv-12 `plan_status` (awk→TS) | fence-aware bold-only head-20 TS 포팅 | Full-conditional | awk↔JS dialect drift (R6) | 오라클 + **신규** fence/whitespace fixtures |
| Secret-scan (13, 프라이머리+MCP+(≥1.17.10)서브에이전트) | `lib/secret-scan.js` SSOT 추출(양 런타임 require); `tool.execute.before` throw | **≥1.17.10 Full / 1.17.9 프라이머리만** | 추출이 bash 리팩터보다 선행해야 오라클 유효 | 오라클 40-44행 + live AKIA deny |
| Secret-scan 15c (once/session surface) | `client` toast + log, `sessionID` dedup | Substitute | 모델 미통지(유저만) (R4) | sessionID dedup |
| Orchestrator skeleton (16-19) | `skeleton-scan.js` 재사용; 위임 토큰 `Agent(subagent_type=`→`subagent_type=`; `create-orchestrator-skill` 템플릿 동시 이전 | 16 Partial/17,19 Full/18 Full(edit)Partial(apply_patch) | 템플릿 lockstep 미준수 시 생성 스킬 false-block | 오라클 orchestrator행 + E2E.E |
| 제약 서브에이전트 (20-25) | `agent/*.md` `mode:subagent`+`permission` 바닥; `common-agent-contract` 인라인 | 20 Full(expl/exec)/Partial(review bash); 21,24,25 Full; 22,23 Substitute | OPEN 기본 위 last-match-wins → 누락 키=GRANT | golden perm-table 정적 검사 + dispatch deny |
| 오케스트레이션 게이트 (26-31) | 네이티브 skills + review-strict + RPI 게이트(프라이머리) | 26,27,29,30 Full; 28,31 Substitute | inv-28 merge-guard=모델이 자기승인 토큰 작성(R3); inv-31 prompt-구조만 | throw 테스트 + skill-text 단언 + state schema |
| Worktree teardown (32-38) | 순수-TS(B; 재사용 파서 없음); `event` `session.deleted/dispose`(파괴) + `session.idle/created`(sweep만); 마커 `~/.config/opencode/worktrees-marker/` | 32,33,35,36,37 Full; 34 Full(Win)/Substitute(Linux); 38 Substitute | resume-race(이벤트 순서 무보장)→GUARD5 마커는 race; Linux lstat 미검증(R5) | table 테스트 + resume-race sim + **Linux 오라클 런** |
| Universal fail-open (39) | `failOpen` 엔벨로프 + `BlockError`만 deny throw, 그 외 swallow→allow | Full(중앙화로 더 강함) | `BlockError` 규율=관례; bare throw=allow(순서: 먼저 정의) | T39 fault-injection |
| Context 채널 (40) | AGENTS.md(모델·정적) + `client`/log(유저); `BlockError` 메시지=유일 mid-turn 모델 주입 | Full(분리)/Substitute(JIT 조건부) | 정적규칙=낮은 salience; 무인루프서 유저채널 안 보임(R4) | T40 + zero-additionalContext grep |
| stable-claude-md | `tool.execute.after` observe-only, 루트 AGENTS.md/CLAUDE.md 매치 advisory | Substitute/**retarget** | CC ~20× 캐시 근거는 opencode 무관 → advisory 공지로 retarget | 오라클 채널-치환 행 |
| verify-loop-watch | `session.idle` observer(best-effort, swallow) | Partial→Substitute | idle≠end, `stop_hook_active` 소실 | advisory 채널 행 |
| 검증/드리프트 seals (41-46) | bash 스택=빌드박스; `run-all-ts` + per-case `diff==∅`; #23→hook-manifest+permission parity로 retarget | 41,42(대부분),43,44,45①,46A-G Full; 42#23,45②,46H Substitute/Partial | #43 empty-diff은 exemption 집합 명시 필요 (§8.2); AGENTS.md seal 충돌(§6.2) | 이중엔진 런 + retarget seals |
| CC-only: statusline | on-demand `/status` (`command/status.md`+`status.sh`) | Substitute | 네이티브 셸 statusline 없음; L4/L5 rate-bar 오프라인 死 | 5-line 렌더 + degrade-not-crash |
| CC-only: auto-compact | 네이티브 `compaction.auto`(Full) + `session.idle` early-warn(`model-window.js` 재사용) | 2a Full/2b Substitute | `transcript-usage.js` un-portable; warn swallow | model-window node↔bun diff |
| CC-only: 모델 routing | `provider`/`model`(opencode.json) = **회사 제공 내부 모델 엔드포인트**. CCS 프록시·`~/.ccs/`·`[1m]`·티어 remap·`small_model` 전부 **drop**(회사는 별도 라우팅 미사용) | **Substitute(단순)** | 내부 모델 엔드포인트가 회사 env에 존재해야 첫 실행 가능; context7 MCP는 오프라인 불가(R7) | opencode.json 파스 0 에러 + 내부 모델 1-shot 응답 확인(in-target) |
| CC-only: settings wiring | 플러그인(hooks)+`permission`(바닥)+provider; CC-only 키 drop | Partial | `SessionEnd timeout:30` 차단보장 소실 | config 파스 0 에러 |
| CC-only: plugin/marketplace | `plugin:[]` drop; **superpowers 번들 동봉**; MCP(context7/playwright) 오프라인 degrade | Substitute(superpowers 내용 Full)/Partial(MCP) | 번들=버전 스냅샷; context7 오프라인 대체 없음 | 오프라인 skill discovery + 전이 체인 |

---

## 5. 번들 레이아웃 (zip → `~/.config/opencode/`)

```
~/.config/opencode/
├── AGENTS.md                         # GLOBAL 헌법(자동로드·first-match-wins). CLAUDE.md 8개 §-규칙 VERBATIM,
│                                     #   ≤200줄·정확히 8개 `## §N.` 마커. 신규 규칙(no-merge/3필드/ADR·UI)은
│                                     #   기존 §-헤더 *아래*에 — 새 `## §N.` 마커 금지(불변식 41 seal 보존).
├── opencode.json                     # provider/model = 회사 제공 내부 모델 엔드포인트(별도 라우팅 레이어 없음);
│                                     #   permission 바닥; instructions:[AGENTS.md, docs/ai-context/*.md];
│                                     #   compaction.auto:true; "plugin":[] 배열 없음(네트워크)
├── opencode.example.json             # retarget seal #23′ permission-parity 파트너
├── PREREQUISITES.md                  # 회사 env: opencode.json provider/model을 내부 모델로 설정; context7 MCP는 오프라인 불가(연구 보조) [R7]
│
├── plugin/                           # 오프라인 자동로드
│   ├── governance.ts                 # 단일 엔트리: tool.execute.before(write/edit/apply_patch/bash),
│   │                                 #   tool.execute.after(stable-claude-md, surface-constitution), event(session.*)
│   ├── fail-open.ts                  # 불변식 39 엔벨로프 + BlockError (모든 게이트보다 먼저 존재 — 순서)
│   ├── arg-keys.ts                   # Phase-0 arg-key 프로브 동결 결과(filePath/content/oldString/newString/command)
│   ├── version.ts                    # client.app.get() → degraded-mode 로깅 / sessionID→agent 역해석(#15403)
│   ├── gates/  rpi-gate.ts · secret-gate.ts · orchestrator-gate.ts · stable-claude-md.ts
│   │           · surface-constitution.ts · verify-loop.ts · worktree.ts
│   └── lib/                          # Bun-native 재사용(C′ keystone, 무번역)
│       ├── redirect-targets.js       # 불변식 8/9/10 — quote-aware tokenizer
│       ├── skeleton-scan.js          # 불변식 16-19 — scanSkeleton() export 추가
│       ├── secret-scan.js            # NEW — enforce-secret-scan.sh에서 추출한 SSOT
│       └── model-window.js           # 불변식 2 — window-size 맵
│
├── agent/                            # 네이티브 서브에이전트(mode:subagent + permission = 실제 L3 바닥)
│   ├── explore-strict.md             # permission: edit/write/apply_patch/bash/task: deny; read/grep/glob/webfetch: allow
│   ├── review-strict.md              # edit/write/apply_patch/task: deny; bash:{"*":"ask","rm *":"deny","* > *":"deny","grep *":"allow","git status*":"allow"}
│   └── execute-strict.md             # read/edit/write/apply_patch/bash: allow; task: deny  (⚠ 1.17.9서 secret 무방비; ≥1.17.10서 L2가 커버 — R1)
│
├── skill/                            # {skill,skills}/**/SKILL.md
│   ├── start-rpi-cycle/ · closeout-pr-cycle/ · grill-with-docs/ · create-orchestrator-skill/
│   ├── improve-codebase-architecture/ · ui-design/(+design.md) · init-ai-ready-project/ · common-agent-contract/
│   └── superpowers/**                # VENDORED(핀 커밋) — brainstorming, writing-plans, executing-plans, …
│
├── command/  status.md + status.sh   # 불변식 1 statusline 대체(on-demand 5-line)
├── docs/ai-context/                  # architecture.md(ADR append-only)·non-obvious.md·domain-glossary.md·CONTEXT.md
├── state.json + state.schema.json    # 도구-무관, 그대로
└── _oracle/                          # 빌드박스 전용. 런타임 의존 아님 · 오프라인 zip서 제외
    ├── cases.tsv (156) · run-all.sh(bash 레퍼런스) · run-all-ts.mjs(TS 포트, 동일 케이스)
    ├── verify-setup.sh · verify-all.sh · verify-integration-opencode.mjs(A-G+I+J)
    └── hooks/*.sh (원본 bash = 오라클 레퍼런스)
```

---

## 6. 강제 아키텍처 (3층)

### 6.1 단일 v1 플러그인 (DEC-2)
함수-export, flat hooks, deny=`throw`. 동일 코드가 1.17.9(프라이머리만)·≥1.17.10(서브에이전트 포함) 자동 적응. V2 import 금지(1.17.9에 subpath 부재→import-time throw). 버전은 `client.app.get()`로 **로깅/신원역해석에만** 조회(강제 분기 아님).

### 6.2 충돌 해소(설계 내장)
- **AGENTS.md seal 충돌:** 신규 규칙은 기존 8개 §-헤더 *아래* → 마커 8개 유지·≤200줄. 초과 시 `docs/ai-context/`로 이동(`instructions:[]` 참조), AGENTS.md엔 금지.
- **#43 count-seal vs apply_patch:** `apply_patch`/E2E.J/oracle-only 행은 **TS-side 별도 total**(bash 양방향 카운트서 제외). empty-diff 게이트는 **공유 부분집합**만.

---

## 7. 불변식 ↔ 테스트 매핑 (전수)

46개 load-bearing 불변식(인벤토리 §2)을 그룹별로 최소 1 테스트에 매핑:
- **RPI(1-12):** 오라클 diff(프라이머리) + E2E.A(plan 없는 write throw)·E2E.D/F·E2E.I(서브에이전트, ≥1.17.10) + inv-12 신규 fence/whitespace fixtures.
- **Secret(13-15):** 오라클 40-44 + live AKIA deny(프라이머리+MCP+(≥1.17.10)서브) + placeholder allow + sessionID dedup.
- **Orchestrator(16-19):** 오라클 + E2E.E(skeleton 미달 차단) + apply_patch 재구성.
- **서브에이전트(20-25):** golden perm-table 정적 + dispatch deny + 3-필드 누락 FAIL + review-PASS-all.
- **게이트(26-31):** throw 테스트 + skill-text 단언 + state.json schema + closeout 분기(branch=main FAIL-stop, 사용자 "1" 필수=절차).
- **Worktree(32-38):** table 테스트 + resume-race sim + Linux 오라클 런(R5).
- **Fail-open/Context(39-40):** fault-injection(파서 throw→allow+FAILOPEN 로그) + 채널 분리(모델은 AGENTS.md/BlockError만, 유저는 client/log).
- **Seals(41-46):** 이중엔진 `diff==∅` + retarget seals(#41 AGENTS.md, #23 hook-manifest+permission parity) + seal-regression mutators(`permission_weaken` 포함).

---

## 8. 단계별 테스트 계획

### Phase 0 — 전역 전제 (BLOCKING)
- **P0.1 arg-key 프로브 (R2):** live 1.17.9 세션에서 `write/edit/apply_patch/bash`의 `output.args` 로깅 → `plugin/arg-keys.ts` 동결. **회사 env에서 재실행**(키 다르면 전 게이트 silent fail-open). 시작 self-test가 합성 호출로 기대 키 존재 단언, 부재 시 ALERT(유일하게 fail-loud로 편향).
- **P0.2 superpowers 번들** → `skill/`(모든 RPI/closeout 스킬 전제).
- **P0.3 `BlockError`+`failOpen` 엔벨로프** 먼저 존재(없으면 게이트의 bare throw→swallow→ALLOW=강제 silent off).
- **P0.4 `lib/secret-scan.js` 추출** → bash 훅을 require로 리팩터 → TS import (순서 엄수, 아니면 오라클 무효).

### Phase (i) — 차등 등가성 오라클 (빌드박스, bash+node)
- `bash run-all.sh --emit-per-case` ↔ `bun run-all-ts.mjs --emit-per-case`, 공유 부분집합 **`diff==∅`** 단언.
- **§8.2 exemption 집합**(명시): auto-compact{13-17,60,61,72,73}·bypass-surface{150-152}·verify-loop{40-45}·surface-constitution{90-93}·apply_patch/E2E.J=TS-only → `CHANNEL=advisory/ts-only`로 치환 채널 단언, empty-diff서 제외.
- inv-12 신규 적대 fixtures; `model-window.js` node↔bun 0 drift; **Linux 오라클 런(R5)**.

### Phase (ii) — opencode 통합 (in-target, 오프라인)
플러그인 오프라인 로드 / 프라이머리 plan-없는 write throw / **서브에이전트 edit permission deny + (≥1.17.10) 내용 throw** / AKIA deny·placeholder allow / skill 목록(superpowers 전이체인) / AGENTS.md 8규칙 암송·client 텍스트 모델 미노출 / MCP 훅 발화 / apply_patch deny / 파서 throw→FAILOPEN / worktree resume-race / golden perm-table.

### Phase (iii) — 수용
클린 세션 "X 기능 추가" → active plan(+sibling spec) 전 코드편집 차단 → `**Status:** active`로 해제. closeout: master→FAIL-stop, feature→`gh pr merge`에 사용자 "1" 필요(절차, GAP-C 문서화).

---

## 9. 리스크 레지스터

| # | 잔여 | 심각도 | 수용 완화 |
|---|---|---|---|
| **R1** | 서브에이전트 내용 강제: 1.17.9서 Absent | (타깃서 해소) | **타깃 1.17.11** = 중앙집중 래퍼가 동일 v1 훅을 서브에이전트에 발화 → near-Full. 1.17.9 잔류 시 permission 바닥만. |
| **R1′** | (≥1.17.10에도) 에이전트 신원 부재(#15403 OPEN) + 셸 불투명성 | Medium | 차단은 됨; 신원은 `sessionID→agent` SDK 역해석. bash 본문은 `redirect-targets.js`가 스캔. |
| **R2** | fail-open × 미검증 arg-key = silent 전역우회 | **CRITICAL** | Phase-0 프로브 + 회사 env 재실행 + 시작 self-test(부재 시 ALERT). **env/path·`arg-keys.ts`는 글로벌(`~/.config/opencode`) 적용**(세션-스코프 아님) → install이 전역 동결, 첫 in-target 실행 시 시작 self-test가 전역 재검증. |
| **R3** | inv-28 merge-guard = 모델이 자기 승인 토큰 작성 | High | Substitute로 강등; 절차 prompt + AGENTS.md 규범 + `permission:{"gh pr merge*":"ask"}`(유저 prompt). "원본보다 강함" 주장 제거. |
| **R4** | 모델-주입 `additionalContext` 부재 | High | AGENTS.md 정적(내용 보존·타이밍 손실); experimental 훅 의도적 배제(불안정). 안정화 시 1-파일 업그레이드 경로. |
| **R5** | worktree Linux 분기 미검증 + resume-race | High | Linux/WSL 오라클 런; 파괴는 `deleted`만(`idle` 아님); 시작 sweep으로 eventually-consistent(cycle-41 식별-무관 설계 계승). |
| **R6** | inv-12 `plan_status` awk→TS dialect drift | Medium | 적대 fence/whitespace/empty-field fixtures 추가. |
| **R7** | 모델 routing: 회사는 **CCS 프록시 미사용 + 내부 LLM 모델만**(별도 라우팅 없음) → `opencode.json` `provider`/`model`을 **회사 제공 내부 모델 엔드포인트**로 설정하면 해소. statusline rate-bar(L4/L5)·`[1m]`·티어 remap은 의미 소멸→drop. | **Medium** | 내부 모델 엔드포인트가 회사 env에 존재·도달 가능해야 첫 실행 가능(PREREQUISITES.md 1줄). **잔여: context7 MCP는 오프라인 대체 없음**(라이브러리 문서 연구 보조 — non-load-bearing, 거버넌스 강제와 무관). playwright MCP는 로컬이라 브라우저 존재 시 동작 가능. |
| R8 | 오라클 비결정성(CCS 확률적 백엔드) | Low | vibe check로 취급; golden FAIL fixtures가 실신호. |
| R9 | `session.idle`/event swallow → verify-loop·inv-45②·inv-31 scanner load-bearing 불가 | Low | advisory 수용(CC 원본도 exit-0/stderr). |

---

## 10. 마이그레이션 순서 (의존-정합)

1. `BlockError` + `failOpen` 엔벨로프 (§39) — 없으면 게이트 silent off.
2. arg-key 프로브 → `arg-keys.ts` 동결 (R2). in-target 재증명.
3. **superpowers 번들** → `skill/`.
4. `lib/secret-scan.js` 추출 → bash 훅 require 리팩터 → TS import (순서 엄수).
5. 전역 `AGENTS.md`(8 §-규칙 + 신규는 기존 헤더 아래) + `permission` 바닥(opencode.json + agent frontmatter).
6. 재사용 파서(`redirect-targets.js`/`skeleton-scan.js`/`model-window.js`) → `plugin/lib/`.
7. TS 게이트: rpi → secret → orchestrator → stable-claude-md → surface-constitution → verify-loop (각 `failOpen` 래핑, deny=`BlockError`).
8. `agent/*.md`(golden perm-table) + `skill/*.md`; `create-orchestrator-skill` 템플릿 lockstep.
9. worktree 플러그인(`session.deleted/dispose` 파괴 + `idle/created` sweep; 마커 dir 재배치).
10. 이중엔진 오라클(`run-all.sh`+`run-all-ts.mjs`, 공유 `diff==∅`, §8.2 exemption).
11. seal retarget(#41 AGENTS.md, #23 hook-manifest+permission parity, #43 count split) + seal-regression.
12. opencode E2E(`verify-integration-opencode.mjs`: A-G + I 서브에이전트 + J apply_patch).

**Pre-ship 게이트:** Phase-0 green + 오라클 `diff==∅` + Linux 오라클 런(R5) + arg-key 재프로브 계획 문서화 → `~/.config/opencode/`를 **`_oracle/` 제외** zip → 반입 → 언집 → in-target Phase-0 + Phase(ii) 재실행.

---

## 11. 도메인 용어 (CONTEXT.md 후보)

- **C′ 아키텍처:** 런타임은 순수 Bun/TS + node 파서 재사용, bash 스위트는 차등 등가성 오라클로 보존.
- **차등 등가성 오라클(differential conformance oracle):** 동일 `cases.tsv`를 bash 레퍼런스와 TS 포트에 먹여 per-case `diff==∅`로 동치를 증명하는 빌드박스 게이트.
- **3층 강제(L1/L2/L3):** AGENTS.md 헌법 / `tool.execute.before` throw / `permission` deny 바닥.
- **degraded 모드:** 1.17.9서 동일 플러그인이 서브에이전트 미가로채기로 동작하는 상태.
- **arg-key 프로브:** opencode hook `output.args`의 실제 키를 런타임에서 확정·동결하는 Phase-0 전제(R2).

---

## 12. 정직한 헤드라인 (Bottom line)

**C′가 최적 아키텍처**다(오프라인 런타임 안전 + 검증 파서 verbatim 재사용 + 156-케이스 오라클 보존; A/B 대비). 충실도는 **프라이머리 대화형 경로 Full, 자율-서브에이전트 내용/주입 경로는 1.17.9 Substitute~Absent → 타깃 1.17.11에서 near-Full**. R1을 닫는 레버는 **V2 훅이 아니라 런타임 ≥1.17.10 업그레이드**(동일 v1 훅이 서브에이전트에 발화). 반드시-선결 2건: **arg-key 프로브 in-target 재실행(R2)**, **#43 오라클 exemption 집합 명시(§8.2)**. merge-guard는 Substitute로 정직하게 강등(R3). 모델 routing은 회사 내부 모델만 쓰므로 `opencode.json` `provider`/`model` 설정으로 해소(CCS 프록시 미사용); 유일 잔여는 context7 MCP 오프라인 불가(연구 보조, 거버넌스 무관)로 `PREREQUISITES.md`에 표면화(R7).

---

## 13. 검증 결과 — Plan 1 live-verify (2026-06-26, opencode 1.17.11 실측)

설치된 opencode 1.17.11에 대해 Plan 1 foundations의 4개 통합 체크를 실측. **4/4 PASS**. 방법론·결함·설계 영향:

**확정(LANDED):**
- **① 플러그인 오프라인 로드:** 단일 깨끗한 로드. `[harness] loaded — opencode 1.17.11 (assumed; floor verified at install); subagent-enforced=true`.
- **② arg-key (R2):** live 키 `edit:[filePath,oldString,newString]`·`bash:[command]`·`read:[filePath]` = 동결 `ARG_KEYS`와 일치. (회사 env 재프로브 의무는 유효.)
- **③ L1 AGENTS.md 주입 (DEC-4 L1 확정):** opencode가 글로벌 `~/.config/opencode/AGENTS.md`를 **빌드-에이전트 시스템 프롬프트에 append**. 캡처-서버로 아웃바운드 요청 실측 → 메인 에이전트 요청(16,755자)에 센티넬 + `## §1.`~`## §8.` 마커 8/8 존재. (cwd AGENTS.md 없는 격리 실행 = 글로벌 로드 경로 충실 검증.)
- **④ L3 권한 바닥:** `/config` 실측 — 3개 strict 에이전트가 `mode=subagent` + 정확한 permission 맵으로 로드. **런타임 deny 실강제 확인**: `write:deny`→write 도구 미제공; write+edit+bash 전부 deny→파일 생성 불가.

**결함→fix-forward(이번 사이클 반영):**
- **버전 탐지 신뢰불가:** 런타임 SDK `client.app.get()`=undefined, `client.config.get()`/`client.path.get()`=**행(hang)**. 서버 `/app`은 웹UI HTML, `/doc` openapi version=API버전(1.0.0). 신뢰원천은 **CLI `opencode --version`(=1.17.11)뿐**. → `version.js` `enforcementFor(detected)`가 탐지 실패 시 **설치-검증 플로어(`VERSION_FLOOR=1.17.11`)로 폴백** + 로그에 `assumed` 표기(정직). 권위적 버전 게이트는 **설치/검증 시점 `opencode --version` ≥ 플로어**로 이동(R2 fail-loud 철학). governance.js probe는 1.5s timeout-guard.
- **★offline-safety (번들 레이아웃 보정):** opencode는 config-dir의 `package.json`을 발견하면 **자동 install**(devDeps→deps 재작성 + lockfile 생성 + 오프라인 env서 **네트워크 시도**). 런타임 플러그인은 순수 ESM(상대 import만)이라 `@opencode-ai/plugin`(빌드타임 타입) 불필요. → **zip에서 `package.json`·`package-lock.json`·`bun.lock*` 제외**(§5 트리는 이미 미포함; 빌드 dir 한정 보유). README ship 명령에 반영.

**테스트 방법론(빌드박스 교훈, _oracle):**
- **OPENCODE_CONFIG_DIR은 격리하지 않음:** opencode가 글로벌 `~/.config/opencode` 플러그인을 **union 로드** → 스테일 글로벌 배포와 이중 로드. 충실 검증은 **실배포(글로벌 ~/.config/opencode, CONFIG_DIR 없음)** 또는 글로벌 비운 뒤 staged temp. 빌드 dir을 CONFIG_DIR로 가리키면 package.json 오염.
- **캡처는 멀티-요청:** opencode는 run당 ≥2요청(메인 에이전트 + 제목/요약). 마지막-요청만 보면 헌법 없는 짧은 제목요청(~2k자)에 속음 → 캡처-서버는 **전 요청 JSONL 누적**.
- **헤드리스 종료:** `opencode run`은 stdin 대기 → `</dev/null` 필수(없으면 작업 완료해도 미종료).
- **CCS 프록시 = L1 테스트 불가:** 프록시가 시스템 프롬프트를 **Claude Code 것으로 하이재킹**(커스텀 system="TESTBOT"에도 "Claude Code"로 응답) → opencode 시스템프롬프트 미관찰. L1은 캡처로만.

**설계 검증(spec 보강):**
- **bash-리다이렉트 우회 실증 → L2 필요성 확정:** write/edit만 deny 시 모델이 `echo > file`(bash)로 우회. review-strict의 `* > *` deny + L2 `redirect-targets.js` 게이트(Plan 2)가 정확히 이 구멍을 봉인 — 설계 타당성 실측 확인.
- **구현 노트:** plugin 파일은 §5의 `*.ts` 표기와 달리 **순수 `.js`로 구현**(zero-transpile 오프라인 로드 = C′ 키스톤에 더 부합). 후속 plan의 게이트도 `.js`.

**잔여(차기 plan):** L2 throw 게이트 실강제 E2E(Plan 2) — 서브에이전트가 mutation 시도→deny까지의 런타임 시나리오는 게이트 + 스크립트 시나리오와 함께(Plan 2/5 acceptance). 이번엔 config-shape + deny 메커니즘까지 확정.
