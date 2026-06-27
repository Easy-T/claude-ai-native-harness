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

---

## 14. 검증 결과 — Plan 2 L2 게이트 (2026-06-26, opencode 1.17.11 실측)

L2 동적 강제(RPI plan-gate + secret + orchestrator)를 5개 lib(verbatim 리팩터) + 3 gate + governance 배선 + 차등 오라클로 구현. **검증 전부 통과 + 라이브 확정.**

**검증 다층:** 단위 **63/63** · 차등 오라클 **diff==0(20 케이스, 리팩터된 lib ↔ 소스 node CLI 동치)** · **5-에이전트 적대적 리뷰(442k tok, 4차원)** · **라이브 opencode**(아래).

**라이브 L2 (실배포 `~/.config/opencode`, CCS프록시 백엔드):**
- A2: 활성 plan 없는 cwd서 8줄 `.py` write → **BLOCKED**(rpiGate throw→opencode deny).
- C2: 활성 plan(`**Status:** active`) cwd서 동일 write → **ALLOWED**(파일 생성).
- B: 활성 plan 없는 cwd서 `printf ... > evil.py`(bash) → **BLOCKED** — **Plan 1 §13 bash-redirect 우회가 L2 bash 경로로 라이브 봉인됨**.
- trivial(1줄) write → ALLOWED(≤5 면제 작동). → write-tool도 plan-gate가 동일 적용 실증.

**★적대적 리뷰가 잡은 실제 parity 버그 4건(차기 plan/회사반입 재사용 교훈):**
- **backslash 경로 정규화 필수(MAJOR, unsafe):** opencode는 Windows서 `args.filePath`를 backslash로 전달 → `/`-리터럴 경로 정규식이 silent 미스 → spec-before-plan 게이트 우회. **모든 경로 게이트는 입력 즉시 `normalizePath`(=`_common.sh` `${p//\\//}`)** 적용 필수. `code-exts.isCodePath`/`rpi-gate.fp`/`orchestrator-gate.fp`에 반영. → **Plans 3-5의 경로 처리 전부 동일 원칙.**
- **awk NR vs split 라인카운트:** `s.split(/\n/).length`는 trailing-newline에서 +1 과다(5줄→6) → ≤5 trivial 창이 ≤4로 축소. **awk `END{print NR}` 등가 = `\n`개수 + (마지막이 `\n`아니면 1)**. (safe 방향이나 parity 깨짐.)
- **bash glob `*`는 `/`를 가로지른다:** `[[ x == */skills/*/skill.md ]]`의 `*`는 중첩 세그먼트 매칭 → JS는 `[^/]+`아닌 **`.+`**. (셸 `[[ ]]` 패턴 ≠ 파일 글로빙.)
- **secret 스캔은 *추가* 콘텐츠만:** bash는 `[content,new_string,command,new_source]`만 스캔(old_string 제외) → JS도 `oldString` 제외(content/newString/command). 시크릿 *삭제* 편집을 false-positive 차단하지 않도록.
- 제거: Plan-1 잔재 `_probe-arg-keys.js`(plugin/lib서 dormant 적재). PASS 차원: verbatim-fidelity(regex byte-identical)·fail-open-wiring(BlockError만 deny·기타 swallow+surface)·spec-drift.
- 잔여(R2): opencode NotebookEdit content key 미프로브 → secret-gate `new_source` 등가 미배선(회사 env서 notebook 사용 시 재프로브). 비-load-bearing(주 경로 content/newString/command 커버).

## 15. 검증 결과 — Plan 3 스킬 번들 + ★오프라인 플러그인-로드 (2026-06-26, opencode 1.17.11 실측)

superpowers v6.0.3(14) vendoring + 커스텀 6 스킬을 **opencode 네이티브 SKILL.md**로 포팅. **검증 전부 통과 + 라이브 확정.** 단위 **66/66** · skill-discovery 오라클 **20/20 0위반** · 5 오케스트레이터 스켈레톤 **5/5 PASS** · 6-에이전트 포팅 워크플로 + 스킬별 적대적 검증 · **라이브 opencode**(아래). 이 단계의 라이브 검증이 **Plan 1 오프라인 설계를 뒤집는 ship-blocker 1건 + 게이트 버그 2건**을 표면화 — 회사반입 전 필수 발견.

**라이브 T5(a) — 스킬 발견(capture-server로 outbound 요청 ground-truth):** opencode가 시스템 프롬프트에 `<available_skills>` 블록(각 `<name>/<description>/<location>`) 주입 → `skill` 도구 def는 제네릭(`name` 파라미터만; "match one of the skills listed in your system prompt"). 우리 번들 `~/.config/opencode/skill/`서 **정확히 20개**(superpowers 14 + 커스텀 6) 전부 description 동반 발견. (opencode는 `~/.claude/skills`·`~/.agents/skills`도 스캔 → 빌드박스선 25개; 회사 env엔 `~/.claude` 부재라 우리 20만.) **L1(AGENTS.md constitution)도 동일 요청서 §RPI/orchestrator 마커 재확인.**

**라이브 T5(b) — orchestrator-gate 라이브 deny(실배포 + CCS프록시 실모델):** 모델에 `skill/badorch/SKILL.md`(marker + `# Phase 1`만) 작성 유도 → `✗ Write ... failed — [orchestrator] FAIL: phase=1<3` deny + 파일 미생성. **단, 최초 시도는 통과(FAIL)했고 수정 후 PASS** — 아래 ★버그2.

**★헤드라인 ship-blocker — `package.json` 부재 시 플러그인-로드 HANG(치명, 회사 env 거버넌스 사망 위험):**
- 증상: clean 배포(`package.json` 제외, Plan 1 오프라인 설계)서 `opencode run`이 config-로드 직후 **무한 행**(모델 요청 0건). `--pure`(외부 플러그인 없이)면 정상 → **플러그인 로딩이 행 원인**.
- 격리: plain node `import()`로 플러그인 자체는 31ms 로드 + init 1ms(`[harness] loaded`) → **opencode의 플러그인-로딩 방식** 문제. 빈 config여도 글로벌 `~/.config/opencode`가 항상 추가 로드(double-load).
- 근본원인: opencode 플러그인 로더는 config-dir에 **`package.json` 존재**를 요구(`.js`를 ESM으로 인식). 부재 시 행.
- ★의존성 설치는 **백그라운드·fail-OPEN**: `package.json` 있으면 opencode가 `@opencode-ai/plugin`을 주입+설치 시도하나, **오프라인이면 `WARN background dependency install failed` 로깅 후 로컬 플러그인을 그대로 로드**(node_modules 불필요 — 플러그인은 `node:` builtin + 상대 import만). dead-registry+node_modules 제거로 실증(graceful).
- **해결(최소·오프라인 완결):** **`package.json`만 ship**(node_modules·lockfile·setup-install·플랫폼별 네이티브 바이너리 전부 불필요). `_stage.sh`서 strip 제거·README/zip-exclude 정정·`scaffold.test`에 load-critical 명문화. `@opencode-ai/plugin`은 types-only devDependency 유지(런타임 불필요). → **Plan 1 "package.json MUST NOT ship" 결정 폐기·역전.**
- 재사용 교훈: **Plan 1 라이브검증은 L1(AGENTS.md)·L3(permission)만 커버, L2 플러그인의 clean-deploy 로드는 미검증이었음** — 폴루션 잔재(이전 install의 node_modules)가 행을 가렸다. clean 배포(generated 전부 제거)로 테스트해야 ship-blocker가 드러남.

**★게이트 버그 2건(라이브에서만 드러난 경로 매칭; 단위테스트는 절대경로라 통과):**
- **상대경로 미스(T5b 최초 FAIL):** opencode write 도구는 **모델이 쓴 경로 그대로**(상대, 예 `skill/badorch/SKILL.md`) 전달 → `orchestrator-gate` `SKILL_PATH`가 **선행 `/` 요구**(`/skills?/`)해 상대경로 silent 통과. **`(?:^|\/)skills?\/`**(start-OR-slash 앵커)로 수정. (write arg-key는 `content`/`filePath` 확인 — drift 아님.)
- **단수 `skill/` 미스:** opencode는 `skill/`(단수, 번들 컨벤션 spec §5)·`skills/`(복수) 양쪽 스캔하나 게이트는 복수만 매칭 → 단수 트리 새 orchestrator가 스켈레톤 불변식 회피(§2 mandate 무력화). `skills?`로 확장. CC 복수-only bash hook과 **의도적 분기**(플랫폼 적응; 게이트는 opt-in이라 false-positive 0).
- 교훈: **경로 게이트는 opencode가 전달하는 실제 arg shape(상대/단수/backslash)로 라이브 검증해야 함** — 단위테스트 절대경로 가정은 live-only 버그를 마스킹. (§14 backslash-normalize와 동류 = "경로는 런타임 실측".)

**범위 정합(spec §5 대비):** `common-agent-contract`은 `agent/*.md`에 인라인(스킬 미포팅). `init-ai-ready` opencode-emission은 **Plan 3b**로 분리(별도 템플릿셋+project deny-gate). superpowers 본문 verbatim(상류 규칙) + `references/opencode-tools.md`만 신규. start-rpi-cycle Closeout 자기검증을 `~/.claude/setup/*.sh`→opencode 하네스 검증(`node --test`+오라클)으로 retarget.

**잔여(수용):** (1) 네트워크 있는 회사 박스 첫 실행 시 `package.json` devDeps→deps 변조 + node_modules 생성(우리 repo 무관·코스메틱; 오프라인이면 무변조). (2) node_modules 미-ship → 첫 실행 install-WARN 1회(무해, fail-open). (3) Plan 5 verify 하네스가 통합 검증 엔트리포인트 제공 예정.

## 16. 설계 — Plan 4: worktree teardown substitute + tool.execute.after 어드바이저리 (research wf_34d8b979)

opencode 1.17.11 v1 Hooks 표면(설치 `@opencode-ai/plugin/dist/index.d.ts` 실측): `dispose?()`·`event?({event})`·`tool.execute.after?(input,output:{title,output,metadata})` 전부 존재. 4-각도 research로 설계 확정.

**A. tool.execute.after 어드바이저리 (substantive):**
- **★ADR(R4 상향) — 네이티브 도구 after-output은 *모델-주입 채널*이다.** opencode `session/tools.ts`는 네이티브 도구(bash/edit/write/apply_patch)에서 `tool.execute.after`를 **모델에 반환되는 바로 그 `output` 객체**에 발화 후 `return output` → `output.output` append가 모델에 도달. (MCP 경로는 별도 객체라 미도달 → **네이티브 도구 한정**.) 이는 spec §6 R4("model-injected additionalContext 부재, AGENTS.md만") + §본문 "BlockError가 유일 mid-turn 주입"을 **상향**: CC PreToolUse `additionalContext`(=`emit_additional_context`)의 등가 비차단 모델 채널이 opencode에 존재(오히려 PostToolUse 타이밍과 정확 일치). **이전 결정 supersede, append-only 기록**(global §5).
- 포팅 어드바이저리 2종(+1 옵션), 전부 fail-open·세션당1회 dedup(`Set<sessionID:kind>` in Governance closure)·`output.output += "\n\n[harness] "+msg`:
  - **(A1) RPI-bypass 표면화** — `process.env.RPI_SKIP` 설정 + 도구∈{bash,edit,write,apply_patch}(네이티브 mutation 집합; apply_patch는 before-gate mutation 집합과 parity로 포함) → CC `surface_bypass`(`_common.sh`) 경고 환기. rpi-gate가 RPI_SKIP early-return 시 *삼키는* surfacing을 복원(CONTEXT "fail-open/우회는 표면화, silent 금지" 준수).
  - **(A2) surface-constitution §5/§8** — `args.filePath`가 의존성 매니페스트셋(package.json/go.mod/requirements.txt/pyproject.toml/Cargo.toml/pom.xml/build.gradle(.kts)/Gemfile/composer.json/*.csproj/pubspec.yaml) 매칭 → §5 ADR 환기; UI 확장자셋(.tsx/.jsx/.vue/.svelte/.css/.scss/.sass/.less/.styl) 매칭 → §8 ui-design 환기. CC `surface-constitution.sh`(cycle-16) 텍스트 포팅.
  - (A3 옵션) 루트 AGENTS.md/CLAUDE.md 편집 시 거버넌스-변경 환기(CC `stable-claude-md` 캐시논리는 opencode 무관 → 평범 advisory로 retarget).
- **미포팅(차단은 before에):** RPI/secret/orchestrator 차단은 `tool.execute.before`(BlockError) 유지 — after는 side-effect 이후라 throw 무의미. MCP 결과 advisory(output-mutation 미도달)·verify-loop/auto-compact(event 영역).
- **리스크:** after-mutation 채널은 sst/opencode dev 소스로 확인(핀 1.17.11 태그 아님) → **빌드박스 라이브 E2E 필수**(RPI_SKIP 발화→assistant-visible 도구결과에 advisory 텍스트 출현 단언). 미도달이어도 advisory라 fail-open(no-op, 비-실패).

**B. worktree teardown substitute (정직한 축소):**
- **범위 = (c) 식별-무관 방어적 정리.** opencode는 세션/서브에이전트당 워크트리 **자동생성 안 함**(project는 launch dir를 worktree로 사용); 네이티브 워크트리 서브시스템은 `OPENCODE_EXPERIMENTAL_WORKSPACES=true` 게이트+명시-사용자-only+`opencode/` 접두사+remove() 자가정리. 하네스는 EnterWorktree 미노출 → 모델이 superpowers `using-git-worktrees`로 `.worktrees/<BRANCH>`에 **임의 브랜치명** `git worktree add` (bash). `finishing-a-development-branch`가 `git worktree remove`+`branch -d/-D`로 **자가정리**.
- **결정: `git worktree prune`만 포팅**(등록-only 정리=dir-사라진 등록 제거, **브랜치 절대 미터치·live 워크트리 미터치=무조건 안전**). CC cycle-41 sweep의 브랜치-D(`worktree-*` 컨벤션)는 **미포팅** — opencode superpowers는 고정 브랜치 접두사가 없어 안전 타깃 부재(임의 브랜치 -D=데이터손실 위험); `opencode/` 접두사는 네이티브 소유라 명시 제외. = 정직한 substitute(무단축소 아님, 여기 기록).
- **트리거:** `PluginInput.worktree`(repo 루트; `directory`는 서브디렉터리 가능) 대상. **plugin init(=session-start 아날로그, 이전 크래시 잔재 정리=신뢰 backstop)** + **`dispose()`(인스턴스 종료=SessionEnd 아날로그, 동일세션 정리)** 양쪽 배선. 둘 다 inside-git-repo 가드+fail-open(throw 금지, 항상 void). `event`/`session.idle`(매 턴 발화) backstop은 불채택(init+dispose로 양방향 커버, git-spawn 최소화).
- **리스크/검증:** SDK가 `dispose()` 발화 타이밍 미문서화 → **라이브 smoke-test 필수**(dispose서 로그 기록→실발화 관찰); 미발화여도 init-prune이 차기 실행서 정리(설계는 dispose 비의존). `worktree`≠`directory`(서브디렉터리 launch 시) → git cwd는 `worktree` 사용. git PATH 부재 시 fail-open.

**검증 결과 — Plan 4 (2026-06-27, opencode 1.17.11 실측). 전부 PASS.** 단위 **83/83**·오라클 diff==0(20)+discovery 20/20·3-렌즈 적대적리뷰(206k, fail-open/dedup/spec-offline 전부 PASS, critical/major 0 → minor 5 반영: 비-string output 가드·sessionID→callID fallback·dispose no-throw 테스트·매니페스트 regex 보강·apply_patch 노트). **라이브 3종:**
- **T4-A ★모델-채널 확정(spec §16.A 리스크 해소):** CCS프록시 실모델+`RPI_SKIP` set+bash `echo` → bash 도구결과에 `[harness] ⚠ RPI 게이트 우회…` 어드바이저리가 **모델-가시 출력에 append되어 렌더링됨**. `tool.execute.after` output-mutation이 핀 1.17.11 네이티브 도구서 실제 모델에 도달 확정(R4 상향 실증).
- **T4-B dispose 발화 확정:** 배포 dir에 dispose-probe 플러그인 추가 → headless `opencode run` 완료 시 `[DISPOSEPROBE] dispose fired` 관찰. dispose-prune 실행 보장.
- **T4-C prune 안전성 확정:** 실 git repo에 워크트리 등록 → dir `rm` → `pruneWorktrees(win-path)` → `{ran:true,pruned:true}`, 고아 등록 제거됨·브랜치 `feature-foo` 보존(브랜치 미삭제 불변식 실증). ★빌드박스 함정: MSYS `/tmp` 경로를 Windows-git(node-spawn)에 넘기면 `not-a-repo`(실 플러그인은 opencode가 Windows 경로 전달이라 무관) → 테스트는 `cygpath -m` Windows 경로 사용.

## 17. 설계 — Plan 5: 검증 하네스 + install + PREREQUISITES + zip acceptance (capstone)

회사 반입 패키징을 완결: 빌드박스 검증 단일 엔트리·타깃 배포·전제조건 문서·zip 수용 테스트. (CC `setup/{verify-all,verify-setup,install,doctor}.sh` 미러.)

- **`_oracle/verify-all.sh`** (빌드박스 단일 검증 엔트리, zip 제외): PASS/FAIL 집계로 ① `node --test tests/*.test.mjs`(전 단위) ② `node _oracle/diff-parsers.mjs`(차등 오라클) ③ `node _oracle/skill-discovery.mjs`(≥20 스킬 0위반) ④ **clean-stage 게이트**(`_stage.sh`로 스테이징 → `package.json` 존재+`type:module`·`node_modules`/lockfile **부재**·`plugin/governance.js` node `import()` 로드 OK(오프라인)·skill 수 ≥20·`opencode.json` `skills.urls` 부재). git/node 부재 시 명확한 실패. **false-green 봉인**: 단위 단계는 종료코드뿐 아니라 **테스트 수 플로어(≥80, 현재 84)+fail==0**을 강제(빈 글롭/0-테스트가 exit0으로 green 위장 차단; spec/tap 두 리포터 형식 모두 파싱); skill-discovery도 `MIN_SKILLS=20` 플로어 강제. ~~CC verify-all의 STAGE-0 active-plan 게이트~~는 **미포팅(N/A, 정직한 descope)**: 그것은 CC 개발 RPI 사이클을 게이트하는 dev-루프 장치인 반면, 여기 verify-all은 RPI 플랜과 독립인 빌드박스 번들 검증기라 active-plan 전제가 무의미 — false-green 위험은 위 테스트-수/스킬-수 플로어로 봉인(Plan 5 review-fix).
- **`install.sh`** (번들 ship, 타깃 배포 헬퍼; CC install.sh 미러): ⓐ 사전 도구 점검(`opencode --version`≥1.17.11 = R2 권위 게이트·`git`)·ⓑ 기존 `~/.config/opencode` 백업(`.pre-harness-<date>`)·ⓒ 번들을 `~/.config/opencode`로 복사(**`package.json` 유지**·`node_modules`/lockfile/`_oracle`/`tests` strip = spec §15)·ⓓ 다음 단계 안내(내부 모델 provider 설정·재시작·`verify-all`). 멱등. **offline-safe**(네트워크 0; 첫 실행 background dep-install WARN은 무해).
- **`PREREQUISITES.md`** (번들 ship): opencode **≥1.17.11**(R1 닫는 중앙 도구 래퍼; 1.17.9는 degraded)·opencode 내장 bun 런타임·`git`(worktree prune·closeout)·**내부 LLM provider** `opencode.json`에 설정(CCS 미사용)·**런타임 인터넷 0** 보장(스킬·플러그인·AGENTS.md 전부 로컬; 첫 실행 background dep-install 실패는 fail-open WARN)·글로벌 `~/.config/opencode` union-load 주의(격리 시도 말 것).
- **`_oracle/acceptance.sh`** (빌드박스, zip 제외): README ship 명령으로 zip 빌드 → fresh temp에 unzip → **정적 수용 단언**(글로벌 무변이·멱등): `package.json` 존재+depless-runtime·`node_modules`/lockfile/`_oracle`/`tests`/`.git` **부재**·`AGENTS.md`+`opencode.json`(no `skills.urls`)+3 agent+plugin 전 파일 존재·unzip된 `skill/`에 skill-discovery 오라클 0위반(≥20)·`plugin/governance.js` unzip본 node `import()` 로드 OK(오프라인). **= "이 zip은 자기완결적·오프라인 로드가능"의 결정적 증명**(글로벌 배포 없이). 전체 라이브-from-zip(opencode 실로드)은 글로벌 union-load 때문에 별도 1회 수동 E2E로 기록(spec §17 검증).
- README에 Install·Prerequisites·acceptance 섹션 + 파일트리 갱신. scaffold 테스트에 신규 ship 자산(PREREQUISITES.md·install.sh) 존재 단언.
- **범위:** `init-ai-ready` opencode-emission은 여전히 **Plan 3b**(별도). verify-all/acceptance/oc-*는 `_oracle/`=zip 제외(빌드박스 전용); install.sh·PREREQUISITES.md는 ship.

**검증 결과 — Plan 5 (2026-06-27, cycle 46). 전부 PASS.** 산출물: `_oracle/verify-all.sh`·`install.sh`·`PREREQUISITES.md`·`_oracle/acceptance.sh`·`_oracle/_stage.sh`·README 4섹션·scaffold 테스트. **실측 GREEN:** verify-all **7/7**(단위 84/84·diff==0·discovery 20/20 0위반·clean-stage 4종)·acceptance **33/33**(zip 빌드+무결성+unzip+ship-leak 8+ship-files 17+offline-import)·전역 `verify-setup.sh` **66/0**(SSOT drift 0·active-plan=1). **install.sh 샌드박스**(임시 XDG, 실 `~/.config` 무접촉): 신규설치(package.json 유지·canonical strip·20 skills)·재설치 백업(`.pre-harness-<stamp>` 1개·노트 출력)·unsafe-TARGET 가드(`""`/`/`/`$HOME` 거부, 정상경로 허용) 전부 PASS.
- **적대적 3-렌즈 재검증 PASS**(167k, data-loss/false-green/canonical-consistency; critical 0·major 0). 이전 리뷰 FAIL의 결함 전부 폐쇄 확인 + 신규 결함 0. nit 2: ①verify-all `skills.urls` 체크가 파일 *부재* 시 green(도달불가—stage가 항상 opencode.json 복사+acceptance 독립 require; 그래도 `[ -f ]` 선행 fail-closed 하드닝 **적용**) ②acceptance `bun.lock*` 분리체크=구조적 차이일 뿐 누락 아님(무조치).
- **Plan 5 review-fix(이전 리뷰 FAIL→폐쇄):** install.sh 데이터손실 3종(백업-실패-fall-through→hard-gate·무경계 `rm -rf`→`cd "$TARGET" && rm <relative>`·동시-초 백업 nesting→`-$$` 충돌방지)+unsafe-TARGET case 가드+cp 실패 체크; verify-all 단위 false-green(빈 글롭/0-테스트 exit0)→**테스트 수 플로어 ≥80(현재 84)+fail==0**(spec/tap 두 리포터 파싱); skill-discovery **MIN_SKILLS=20**; acceptance 무-아카이버→hard-fail(exit1)+`unzip -t` 무결성(PowerShell 백슬래시 exit1은 "No errors detected" fallback 허용); **canonical 제외집합** `{_oracle,tests,node_modules,.git,.gitignore,package-lock.json,bun.lock*,_skills_capture.jsonl}` 4선언(install.sh·_stage.sh·README zip -x·acceptance leak-loop) byte-일치(README `.git/*` 누락 M9 정정).
- **m8 정정:** §17의 verify-all "STAGE-0 active-plan 게이트" 주장은 **미포팅(N/A descope)** — CC의 그것은 dev RPI 사이클 게이트, 여기 verify-all은 RPI-독립 빌드박스 검증기; false-green은 테스트-수/스킬-수 플로어로 봉인.
- **doctor 2 FAIL**(`claude`/`jq` not found)은 **Claude Bash 도구의 Windows-style PATH 미파싱 아티팩트**(jq-1.8.1·claude 실재; git diff상 Plan 5는 hook/setup/doctor 무접촉) — Plan 5 회귀 아님. 비자명 교훈: 빌드박스 셸은 POSIX 도구를 정상 해석하므로 실 타깃에선 무관.

## 18. 설계 — Plan 3b: init-ai-ready opencode-emission (번들 네이티브 init 스킬)

마이그레이션의 마지막 분리-항목. 사용자 결정(2026-06-27): **opencode 번들에 네이티브 init 스킬**(CC 스킬의 dual-target 재작성 아님; CC 스킬은 CC 전용 유지). 회사가 opencode를 돌리므로 opencode-타깃 프로젝트를 스캐폴드.

- **위치/구성:** `opencode-harness/skill/init-ai-ready-project/`(SKILL.md + `templates/*.tpl` + `references/{placeholder-spec,stack-presets}.md`). opencode 네이티브 스킬 발견 메커니즘으로 자동 노출(시스템 프롬프트 `<available_skills>`).
- **CC→opencode-타깃 매핑:** `CLAUDE.md`→**`AGENTS.md`**(opencode가 프로젝트 루트 AGENTS.md를 전역 헌법과 병합; Plan 1서 전역 주입 실증); `.claude/settings.json` deny + `.claude/hooks/pre-commit-deny.sh`(deny-patterns.md 동적 파싱 exit2) → **프로젝트 `opencode.json`의 `permission.bash` 정적 deny 맵**(네이티브 L3); `.claude/state.json`→루트 `state.json`; `docs/ai-context/*`·`.gitignore`·`scripts/check.sh`·`.github/workflows/ci.yml`·`CONTEXT.md`=타깃무관 재사용.
- **방출 파일셋 12개**(CC 13에서 훅 파일 드롭, deny를 opencode.json에 흡수): `AGENTS.md`·`docs/ai-context/{architecture,runbook,deny-patterns,non-obvious,domain-glossary}.md`·`opencode.json`·`.gitignore`·`state.json`·`scripts/check.sh`·`.github/workflows/ci.yml`·`CONTEXT.md`. 디렉터리: `docs/ai-context/`·`docs/superpowers/{specs,plans}/`(.gitkeep)·`scripts/`·`.github/workflows/`.
- **★정직한 deny-gate 대체(무단축소 아님 — 적대적 검토가 초기 과대주장 포착, 아래 review-fix):** CC 동적 deny-gate(deny-patterns.md `- ❌ ` 줄을 훅이 파싱→매칭 차단)는 opencode에서 **정적 `permission.bash` deny**로 대체. **정직한 강제 범위(3-계층):** ⓐ**하드 차단(L3, bash-형태 보편 파괴 명령만)**=`rm -rf`/`rm -fr`(+`~`·`/`·`-rfv`·`-r -f` 변종)·`npm/yarn/pnpm publish`·`git push --force `(인자형). 단 **best-effort 가드(speed-bump)이지 샌드박스 아님**: opencode glob은 셸-비인지→플래그순서·env프리픽스(`git -c x push --force`)·이색 띄어쓰기 변종 우회 가능; 안전한 `--force-with-lease`는 미차단(공백 패턴). ⓑ**advisory(자동강제 X)**=SQL(`DROP TABLE`…)·prod 직접접근(`ssh prod`·`kubectl exec`·`psql -h prod-`)·컨텍스트 git(`reset --hard`·`--no-verify`)·머지된 마이그레이션 수정 — bash-패턴 환원 불가→정적 게이트 사정거리 밖, 리뷰·규율 + 전역 하네스 게이트로 적용. ⓒ deny-patterns.md=**전체 정책 SSOT**(16 ❌), permission.bash=그 중 강제가능 bash-부분집합. 동적 프로젝트-플러그인 대안은 프로젝트마다 package.json+type:module 강제(비-JS 침습)라 기각. AGENTS.md.tpl·deny-patterns.md.tpl 헤더·SKILL.md에 범위 명시 + 오라클이 disclosure 마커(`best-effort`+`advisory`) 단언으로 봉인.
- **검증(빌드박스):** `_oracle/init-emission.mjs`(템플릿을 샘플 placeholder로 렌더→12파일+디렉터리·AGENTS.md ≤200줄+포인터·opencode.json JSON유효+`permission.bash` deny **하드세트**(`rm -rf *`·`rm -fr *`·`rm -rf ~*`·`git push --force *`·`npm/yarn/pnpm publish`)=deny + 안전 `--force-with-lease` 미차단·deny-patterns ≥8 ❌·**정직성 disclosure 마커**(`best-effort`+`advisory`)·**전 방출파일 `.claude/` 잔재 부재**·state.json schema=1/cycle=0·placeholder 잔존0(빈괄호 포함)·runbook 섹션·non-obvious 마커 단언). render는 block backref(이름매칭)·미사용 VARS 제거. 스킬 수 SSOT **20→21**(skill-discovery `MIN_SKILLS`·acceptance `-ge 21`·verify-all 주석·README).

**검증 결과 — Plan 3b (2026-06-27, cycle 47). PASS(적대적 검토 FAIL→폐쇄 후).** 단위 **85/85**(+1 scaffold)·`init-emission` 12파일 0위반·skill-discovery **21/21** 0위반·verify-all **8/0**(init-emission 스텝 추가)·acceptance **34/0**(21 SKILL.md+init 스킬/템플릿 ship 단언)·verify-setup **66/0**. install.sh는 동적 스킬 카운트라 무변경(21 자동). CC-전용 자산(`CLAUDE.md.tpl`·`pre-commit-deny.sh.tpl`)은 opencode 스킬에 **미복사**(scaffold 부재 단언).
- **★적대적 3-렌즈 검토(189k) = FAIL→fix(정직성 위반 포착, 사용자 "무단축소 금지" 핵심):** ①**MAJOR deny-gate 과대주장**=deny-patterns.md 16 ❌ 문서화 vs permission.bash 5 강제, 그런데 AGENTS.md가 "강제=permission.bash deny 맵"으로 **전체 강제 함축** → **3-계층 정직 공개로 수정**(하드/advisory/SSOT, 위 deny-gate 항목)+오라클 disclosure 마커 단언으로 봉인. ②**MAJOR 커버리지/우회**=`rm -rf *`가 `rm -fr`·`-rfv`·`-r -f`·`~`로 우회·`npm publish`만(yarn/pnpm 누락)·`--force*`가 안전 `--force-with-lease` 오차단 → **하드세트 확장**(rm 변종+yarn/pnpm)+`--force ` 공백패턴(안전변종 보존)+**best-effort 비-샌드박스 명시**(glob 셸-비인지 우회는 구조적 한계로 공개). ③**minor `.gitignore.tpl` `.claude/` CC-잔재** → `.opencode/`로 수정 + 오라클 전-파일 `.claude/` 검사로 일반화. ④nit(빈괄호 누수·block backref·미사용 VARS) 반영. 템플릿-누수 렌즈는 처음부터 PASS(오라클 fail-closed 확인).
- **잔여 설계가정**(라이브 미검증, 설계-근거): opencode가 프로젝트-루트 `AGENTS.md`+`opencode.json`을 읽는다는 것은 opencode 문서화된 config 모델 + Plan 1 전역-AGENTS.md 주입 실증에 근거; 라이브 opencode 가용 시 프로젝트-레벨 읽기 스모크 권장. → **opencode-harness 마이그레이션 전체 COMPLETE(Plans 1-5 + 3b).**
