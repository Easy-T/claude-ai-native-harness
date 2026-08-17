모든 검증이 끝났다. 최종 설계 문서를 작성한다.

# Orca 오케스트레이션 모드 — 최적 설계 (C21 착륙 대상)

> 본 문서의 모든 단정문에는 근거(파일:줄 / 실행 명령 + 출력)가 병기된다. 근거 없는 항목은 **"근거 없음 — 미확인"** 으로 표기한다.
> 본 조사는 읽기 전용 지시를 준수해 **`orca` 명령을 0회 실행**했다. Orca CLI 관련 사실은 전부 *스키마·가이드·앱 상태파일 상의 계약*이며 런타임 실측이 아니다(§8-A).

---

## 0. 판정 요약

### 0.1 안별 판정

| 안 | 렌즈① 실현가능성 | 렌즈② 하네스 시너지 | 렌즈③ 적대적 파괴 | 종합 | 판정 |
|---|---|---|---|---|---|
| **안 2 — 층 분리형 (Orca=DAG · 하네스=워커 내부)** | 6.5 | 8 | 6 | **6.8** | **채택 (기반)** |
| 안 1 — Orca=런처, `bin/orca-worker` 초크포인트 | 5 | 6 | 4.5 | 5.2 | 부분 이식 |
| 안 3 — 경계-분리형 (Orca=배치, 하네스=추론) | 4 | 5 | 5 | 4.7 | 부분 이식 |

**채택 사유 (안 2)**: 3안 중 유일하게 주어진 사료를 **반증**했고, 그 반증 2건을 본 문서 작성 중 독립 재현했다.

- **반증 1 — 글로벌 CLAUDE.md 는 프로세스 경계를 넘는다.** 축③ F4 「워커 세션에는 글로벌 CLAUDE.md 가 주입되지 않았다」는 **측정 아티팩트**다(트랜스크립트는 시스템 프롬프트를 기록하지 않는다).
  본 문서 독립 재현(Orca 워크스페이스 cwd, 로컬 `.claude` 부재):
  ```
  cwd=/c/Users/12132/orca/workspaces/orca-lab/impl-parse   (ls -a → . .. 뿐)
  absent  C:/Users/12132/CLAUDE.md · orca/CLAUDE.md · orca/workspaces/CLAUDE.md
  absent  orca/workspaces/orca-lab/CLAUDE.md · ./CLAUDE.md
  $ claude --model haiku -p "Quote VERBATIM ... '## §8.'"   → ## §8. UI Design Mandate
  $ claude --model haiku -p "... '## §9.' — If none, output NONE."  → NONE     ← 음성 대조군
  ```
  경쟁 CLAUDE.md 가 전 경로에 부재하므로 출처는 글로벌 `~/.claude/CLAUDE.md` 뿐이다. **규범(L1)도 훅(L2)과 함께 상속된다** → 안 1 의 `orca-worker spec` 규범-생성 서브시스템은 과잉 건설이므로 기각.

- **반증 2 — L2 매처의 사각은 "워커 기동 argv" 한 줄뿐이다.** 워커 *내부* Agent 호출은 정상 관측·발화한다.
  `hooks/.log/2026-08.log` verbatim: `2026-08-13T00:50:15+09:00 surface-model-policy review-strict:haiku ALERT rule-b-verifier-below-opus-floor`

### 0.2 승자 안의 치명 결함 — 해소

렌즈③이 「GPT 워커 세션에서 Rule B inherit arm 이 skip 된다」고 지적했다. **본 문서 실측 결과 사각은 그보다 넓다 — 규칙 일부가 아니라 훅 전체가 조기 종료한다.**

실행(합성 HOME 격리, `HOME=/tmp/smp-probe`):
```
[CONTROL] transcript model=claude-sonnet-5 + Agent{review-strict, model:haiku}
  → {"hookSpecificOutput":{...,"additionalContext":"[model-policy] 검증자(review-strict) 기준선 미달(관측='haiku' ...)"}}   [exit=0]
[PROBE]   transcript model=gpt-5.6-sol   + Agent{review-strict, model:haiku}   ← 동일 위반
  → (출력 없음)   [exit=0]

[CONTROL] Workflow{execute-strict:opus, review-strict:haiku}, session=claude-sonnet-5
  → ALERT "Workflow 스크립트의 검증자(review-strict)가 기준선 미만입니다(관측='haiku', 필요 티어=3)"   [exit=0]
[PROBE]   동일 Workflow, session=gpt-5.6-sol
  → (출력 없음)   [exit=0]
```
원인(코드 실측):
- `hooks/surface-model-policy.sh:30-35` `session_model_of()` 정규식 = `"model":[[:space:]]*"claude-[a-z0-9.-]+"` — **`claude-` 접두만 매치**
- `:169` `[ -n "$SESSION_MODEL" ] || exit 0` — Agent 경로 **전체** 조기 종료 (Rule A·B 둘 다)
- `:54` `[ -n "$WF_SESSION_MODEL" ] || exit 0`, `:56` `[ "$WF_TIER" = "0" ] && exit 0` — Workflow 경로 **전체** 조기 종료 (Rule C·C2·C3 전부)

즉 **비-Claude 세션(브리지 GPT 워커)에서는 모델-정책 5규칙이 전부 침묵한다.** 리터럴 선언조차 검사되지 않는다(렌즈③은 "리터럴은 복원된다"고 했으나 이는 과대평가 — 위 PROBE 는 리터럴 `haiku` 인데도 침묵).

그리고 이 사각은 **실물**이다: `projects/C--Users-12132-orca-workspaces-orca-lab-impl-parse/3a8731e6-….jsonl` 에 `"model":"gpt-5.6-sol"` **22건**, `036e8282….jsonl` 2건, `6af8730e….jsonl` 4건, `f50aaaf2….jsonl` 1건 — 이미 GPT 세션이 Orca 워크스페이스에서 돌았다.

→ **해소**: §6 의 GAP-A(훅 F1 수정: 비-Claude 세션에서 리터럴 축은 계속 검사) + §4 의 **워커 계약 "GPT 세션 내 `inherit` 위임 금지, 리터럴 강제"**. 상세 §6.2.

### 0.3 모드팩 JSON 폐기 근거 (실측)

| 근거 | 실측 |
|---|---|
| Orca CLI 에 mode 개념 0건 | 228 commands 전수 — `'mode' in c['command']` 매치 **0** |
| 가이드 2종에 0건 | `grep -i "mode pack\|modepack\|\.claude/modes"` → 출력 없음 |
| orchestration DB 스키마에 0건 | 테이블 20종(`coordinator_runs, decision_gates, deliveries, dispatch_contexts, federated_dispatches, federation_relay_items, legacy_*, messages, mutation_receipts, question_threads, remote_*, runs, tasks, worker_dispatches, worker_terminal_archives, worker_terminal_resources`) — mode 관련 0 |
| **이 머신에서 오케스트레이션 실행 전례 0** | `runs=1` (=`('run_legacy_local','Legacy orchestration state (inspect only)',…)` 툼스톤) · `tasks=0` · `worker_dispatches=0` · `decision_gates=0` · `messages=0` · `deliveries=0` |
| 그런데 seal #51 은 GREEN | `modepack_oracle_scan "$HOME/.claude/modes"` → `TOTAL=2 LITERAL=2 DYNAMIC=0 VIOLATION=0 rc=0` |

**결론**: seal #51 은 *Orca 가 읽지 않는 파일*을 검사해 GREEN 을 내고 있었다. vacuous 는 아니지만(TOTAL=2) **무의미(non-load-bearing)** 하다 — 검사 대상이 실행 경로에 없다. 이것이 "서드파티 스키마를 실물 검증 없이 채택"의 실제 피해이며, 재발 방지 장치가 §7 Phase 0(안 3 이식)이다.

---

## 1. 사용자 요구 → 설계 대응표

| # | 요구 | 어떻게 만족하는가 | 근거 |
|---|---|---|---|
| 1 | **워커 진입점 = 항상 claude** | 캐리어가 `worker-start --agent claude` 만 발행. `--agent` 값이 `claude` 아닌 인자를 **받지 않는다**(코드 거부, 문서 아님). L3 오라클이 캐리어 파일을 스캔해 위반 시 VIOLATION | 스키마 usage `(--agent <agent> \| --terminal <handle>)`; 가이드 `orca-cli.md:147` 알려진 id 에 `claude` 포함 |
| 2 | **claude 안에서 opus/gpt-5.6-sol 등 호출** | 3층 라우팅: 층1 Orca=모델 무선언 / 층2 Claude 패밀리=워커 내부 Agent·Workflow / 층3 비-Claude=워커의 Bash 서브프로세스(`OCX_MODEL=… claude-ocx`, `codex exec`). 세션 교체 아닌 **호출 단위 부분 위임** | §4. 브리지 1회 호출 실측 `modelUsage.gpt-5.6-sol / is_error:false / exit 0` |
| 3 | **가용 모델 = claude·antigravity·codex** | claude=`settings.json` env 별칭 SSOT(`ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5[1m]` 등 실측) · GPT/Gemini=프록시 런타임 카탈로그 조회(하드코딩 금지) | `curl -s --noproxy '*' http://127.0.0.1:10100/v1/models` → http=200, 10 모델. healthz `{"status":"ok","service":"opencodex","version":"2.11.0"}` |
| 4 | **서드파티 모드팩 스키마 폐기** | `modes/orca-rpi-implement.json` + `setup/lib/modepack-oracle.sh` 삭제. 캐리어를 실행 자산(`bin/orca-rpi.sh`)으로 교체하고 오라클 재조준. §0.3·§6 | 위 §0.3 표 |
| 5 | **기존 하네스와 시너지** | 훅(L2)·규범(L1) 모두 프로세스 경계를 넘는 것을 실측 확인 → 재구현 0. 하네스 판정(PASS/FAIL)을 Orca `--outcome` 으로 승격, `--files-modified` 를 델타 재심 입력으로 소비. §5 | §0.1 반증 1·2 |

---

## 2. 책임 경계 (누가 무엇을 소유하는가)

| 축 | 소유자 | 근거 | 경계 검사 지점 |
|---|---|---|---|
| Run / Task DAG / Dispatch / `worker_done` 증적 / decision gate | **Orca** | `orchestration.md:159` "A Run is the namespace/inbox, a Task is the work item, and a Dispatch assigns one Task attempt to a terminal" | 가이드 :29-34 provenance 검증(`task-list`/`dispatch-show`)을 캐리어가 자동 수행 |
| 워커 **터미널** 수명(생성·재사용·release) | **Orca** | 스키마 worker-release NOTE: "closes only the exact coordinator-owned agent terminal … Idempotent … An inspectable output archive is preserved" | 캐리어가 `worker-release` 발행, `terminal close` 대체 금지 |
| **모델 티어 · effort** | **하네스 전유** | L2 매처가 관측하는 축은 `Agent\|Workflow` 뿐 (`surface-model-policy.sh:18` `case "$TOOL" in Agent\|Workflow) ;; *) exit 0 ;; esac`) · `grep -rn -- "--model" hooks/*.sh` **매치 0** | L3 오라클 = 캐리어에 `--model`/`--effort` 리터럴 **부재** 단언(부정-단언 seal) |
| **git worktree 디렉터리 · 브랜치** | **하네스** — 단 Orca 워크스페이스에는 **애초에 걸리지 않음** | `worktree-teardown` 경로 게이트가 `.claude/worktrees` 한정. 실측 로그 4건 전부 `PASS noop:not-worktree` | §5.4 |
| 워커 **워크스페이스**(Orca 생성분) | **Orca** | `worktreeMeta` 실측: `…/lab-gpt3`·`…/impl-parse` 는 `orcaCreationSource: "runtime"`. 두 디렉터리 모두 현재 **디스크에서 사라졌거나 비어 있고**(`lab-gpt3` ABSENT, `impl-parse` entries=0, `.git` 없음), `git -C orca-lab worktree list --porcelain` 은 메인 1개뿐 | 하네스 sweep 은 이 축에 도달 불가 — **정리 책임은 Orca** (수용, §8-C4) |
| 규범(RPI 게이트·§1~§8) | **하네스** (자동 상속) | §0.1 반증 1 | 워커 계약 spec 은 **사이클 고유 계약만** 나른다(규범 재전송 금지 — 중복) |
| `settings.json` hooks 배열 | **공유(append)** | 실측: 총 24 엔트리 = 하네스 13 + Orca 11, 이벤트 12종(`PermissionRequest, PostToolUse, PostToolUseFailure, PreToolUse, SessionEnd, SessionStart, Stop, StopFailure, SubagentStart, SubagentStop, TeammateIdle, UserPromptSubmit`) | 캐리어 preflight 백업 + 종료 시 diff (안 1 이식) |
| **사용자 머지 승인** | **사람** | `orchestration.md:281` ask/gate 분리 + `feedback_merge_approval_sequencing` | `gate-resolve` 로 대체 **금지** — 캐리어에 머지 gate 발행 경로 없음 |

**경계 위반의 정직한 상한**: 사용자·코디네이터가 캐리어를 우회해 `orca.exe orchestration worker-start --model X` 를 손으로 치면 L3 오라클은 보지 못한다. spec §19.7-4 의 상한을 그대로 상속한다. **"봉인했다"고 쓰면 거짓이며, 정확한 표현은 "캐리어 경로를 봉인했고 손-호출은 `RPI_SKIP` 동형의 의식적 우회"** 다.

---

## 3. 실행 흐름 (실물 명령)

### 3.0 실행자 해소 (가장 먼저 — 두 함정)

```bash
# 함정 ①: orca 는 이 셸의 PATH 에 없다
#   실측: $ command -v orca → rc=1
#   설치본: C:/Users/12132/AppData/Local/Programs/orca/resources/bin/{orca.exe, orca.cmd}
# 함정 ②: orca.cmd 는 orchestration send/reply 를 거부한다 (worker_done 이 send 이므로 결정적)
#   orca.cmd:13-14 verbatim:
#     if /I "%~1"=="orchestration" if /I "%~2"=="send" goto :unsafe_body
#     if /I "%~1"=="orchestration" if /I "%~2"=="reply" goto :unsafe_body
#   :22-23  echo orca.cmd cannot safely forward orchestration message bodies. Use "%LAUNCHER%" instead. 1>&2
#           exit /b 2
ORCA="${ORCA_CLI_COMMAND:-C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe}"
```
`ORCA_CLI_COMMAND` 우선은 `orca-cli.md:29-30` verbatim: *"If the `ORCA_CLI_COMMAND` environment variable is set, use its value. Orca exports this for managed WSL sessions."*

### 3.1 STAGE 0 — Preflight (fail-closed)

```bash
cp "$HOME/.claude/settings.json" "$RUNDIR/settings.pre-orca.json"     # 안 1 이식: 사후 diff 기준선

"$ORCA" status --json                              # 런타임 가동 (orchestration.md:48)
"$ORCA" orchestration run-list --json              # ⚠️ orchestration RPC 도달 + experimental 프로브
"$ORCA" repo list --json                           # ~/.claude 등록 확인 (아래 ★)
WT_SEL=$("$ORCA" worktree current --json)          # ★ 반환 selector 를 verbatim 보존 — 경로 재조립 금지
"$ORCA" agent hooks status --json                  # 읽기 전용. on/off 는 절대 발행 안 함
"$ORCA" agent-context --json | cksum               # 계약 핀
"$ORCA" skills get orchestration --json | cksum    # 가이드 핀

# 하네스 전제 — plan 실재 단언 (워커가 BLOCK 을 만나 RPI_SKIP 을 학습하는 경로 원천 차단)
. "$HOME/.claude/hooks/_common.sh"
has_active_plan "$PWD" >/dev/null || { echo "no active plan — Orca 모드 진입 거부"; exit 3; }

# 어느 하나라도 실패 → rc=3 + 사유 출력 → 사이클은 기존 Phase I (a)/(d) 로 폴백 (하네스는 멈추지 않는다)
```

**★ `orca repo add` 선행 필수 (실측)**: `orca-data.json` `repos` = **1건**뿐 —
`{"id":"c513cb4f-…","path":"C:\\Users\\12132\\orca-lab"}`. `C:/Users/12132/.claude` 는 **미등록**이다. 등록 없이 `--worktree current` 가 무엇을 반환하는지는 **근거 없음 — 미확인**. 사용자 액션 §9-A.

**⚠️ experimental 플래그 상태**: `orca-data.json` `settings` 전수 스캔 결과 experimental 키 11개(`experimentalNativeChat, experimentalMobile, experimentalPet, experimentalActivity, experimentalActivityDefaultedOffForAllUsers, experimentalTerminalAttention, experimentalAgentHibernation, experimentalNewWorktreeCardStyle, experimentalEphemeralVms, experimentalAgentDashboardPopout, experimentalAgentDashboardMode`) 중 **orchestration 계열 0건**. 저장 위치 자체가 미확인 → `run-list` 프로브가 유일한 판별 수단이며, 그 **실패 출력 형태도 미확인**(§8-A2).

### 3.2 STAGE 1 — Run + RPI 4-Task DAG

```bash
RUN=$("$ORCA" orchestration run-create --objective "C21 <목표> — RPI 1사이클" --json)   # [P2] run id 경로
T_R=$("$ORCA" orchestration task-create --task-title "R: Research" --spec "$(cat "$SPEC/phase-R.txt")" --json)   # [P2]
T_P=$("$ORCA" orchestration task-create --task-title "P: Plan"      --spec "$(cat "$SPEC/phase-P.txt")" --deps "[\"$T_R\"]" --json)   # ⚠️ --deps 원소 스키마 미확인
T_I=$("$ORCA" orchestration task-create --task-title "I: Implement" --spec "$(cat "$SPEC/phase-I.txt")" --deps "[\"$T_P\"]" --json)
T_C=$("$ORCA" orchestration task-create --task-title "C: Closeout"  --spec "$(cat "$SPEC/phase-C.txt")" --deps "[\"$T_I\"]" --json)
"$ORCA" orchestration task-list --ready --brief --json     # 외부 메모리 (가이드 :390)
```

- 깊이 4 = 가이드 권고 상한. `orchestration.md:390` verbatim: *"avoid dependency chains deeper than 3-4 steps."*
- **Phase 내부 분해**(brainstorming→grill→explore)는 DAG 에 올리지 않는다 — 상한 초과이며 워커 내부 하네스 몫.
- `[P2]` = **프로브 전 하드코딩 금지 마커**(안 3 이식). 근거: `orca-schema.json` 최상위 키는 `['schemaVersion','commandCount','commands']` 뿐이고 각 command 는 usage/flags/notes/examples 만 담아 **응답 shape 가 스키마에 전혀 없다**.

### 3.3 STAGE 2 — 워커 기동 (모델 무선언이 불변식)

```bash
"$ORCA" orchestration worker-start --run "$RUN" --task "$T_R" --worktree current --agent claude --json
# exit 0 == ready 만 성공 (스키마 NOTE: "The call exits 0 only for ready. Failed or outcome_unknown exits 1
#   and JSON includes stage/failedStage, setup, effects, residualResources, and recovery commands")
# ★ 자동 재시도 금지 (orchestration.md:212) — 명시 재시도는 --retry-of <dispatch_id> 로만, 배치 재명시 필요
```
발행 금지 플래그: `--model` `--effort` `--on` `--worktree new-child|new-top-level` `--agent <claude 이외>`.

### 3.4 STAGE 3 — 감독 루프 (블로킹 롤링 윈도우)

```bash
# ★ stderr 분리 필수 — --wait 는 15초마다 stderr 로 JSON keepalive 를 낸다
#   스키마 usage verbatim: "Emits JSON keepalive lines to stderr every 15s … Filter with
#   `jq \"select(._keepalive|not)\"` when merging streams."
"$ORCA" orchestration check --run "$RUN" --wait --types worker_done,escalation,question \
        --timeout-ms 900000 --json 1>"$OUT" 2>>"$KEEPALIVE_LOG"
jq 'select(._keepalive|not)' <"$OUT"

# ★ 배치 전건 순회 후에만 ack
#   :139 "returns the bound Run's oldest FIFO Delivery (up to 50 messages) and replays that exact batch
#         until --ack <delivery_id>. Process every message before acknowledging"
#   :140 "Type filters decide when a waiter wakes; the returned actionable Delivery is still the oldest full batch."
"$ORCA" orchestration reply --id "<msg_id>" --body "<답>" --json      # question 처리
"$ORCA" orchestration check --run "$RUN" --ack "$DELIV" --wait --types worker_done,escalation,question \
        --timeout-ms 900000 --json 1>"$OUT" 2>>"$KEEPALIVE_LOG"
# timeout / {count:0} = 체크포인트이지 실패 아님 (:146) — 롤링 wait 계속
```

**핸들러 요건(오구현 시 증상이 "유실"이 아니라 "무한 재생/무한 대기")**: ⓐ 배치 전건 순회 ⓑ 미처리 건 존재 시 ack 금지 ⓒ 핸들러 멱등 ⓓ 타입 필터를 "반환 내용"으로 오해 금지.

### 3.5 STAGE 4 — Phase 연쇄 = 터미널 재사용

```bash
H=$("$ORCA" orchestration worker-show --dispatch "$D_R" --json)   # [P2] worker.agent_terminal_handle (:242 명시 필드)
"$ORCA" orchestration worker-start --task "$T_P" --terminal "$H" --json
```
`orchestration.md:242` verbatim: *"If the same exact agent has an immediate follow-up Task, read the `worker.agent_terminal_handle` field of `worker-show --dispatch <dispatch_id> --json`, then run `orca orchestration worker-start --task <next_task_id> --terminal <handle> --json` so Orca transfers cleanup ownership to the new Dispatch."*

**★ 이것이 `--model` 포기의 설계 배당금(안 1 이식)**: 스키마 NOTE verbatim — *"`--effort` requires `--model`. Neither can combine with `--terminal`."* 즉 모델 축을 Orca 에 태우는 순간 터미널 재사용을 **자동으로 잃는다**. 모델을 워커 내부로 미는 선택이 **정책 커버리지와 터미널 재사용을 동시에 얻는 유일한 배치**다. 이 문장을 spec §20 에 명시 기록해야 향후 "`--model` 한번 써보자"에 대한 방어가 선다.

**단, 지연 이득은 주장하지 않는다**(안 3 이식): `--terminal` 재사용이 실제로 세션 컨텍스트를 이어받는지는 **미확인**(§8-E19).

### 3.6 STAGE 5 — read-only 팬아웃 (유일한 병렬 축)

```bash
T_V1=$("$ORCA" orchestration task-create --task-title "V1: 설계층 적대리뷰(read-only)" --spec "$(cat "$SPEC/review-slot1.txt")" --deps "[\"$T_I\"]" --json)
T_V2=$("$ORCA" orchestration task-create --task-title "V2: 코드층 적대리뷰(read-only)" --spec "$(cat "$SPEC/review-slot2.txt")" --deps "[\"$T_I\"]" --json)
"$ORCA" orchestration worker-start --task "$T_V1" --worktree current --agent claude --json
"$ORCA" orchestration worker-start --task "$T_V2" --worktree current --agent claude --json
"$ORCA" orchestration check --run "$RUN" --wait --types worker_done,escalation,question --timeout-ms 1800000 --json 1>"$OUT" 2>>"$KEEPALIVE_LOG"
```
`orchestration.md:184` verbatim: *"Create the Run and every independent Task first, then start all independent workers before waiting."*

**★ 불변식 — 코드로 강제(안 1 이식)**: 캐리어의 `spawn` 은 `--readonly` 플래그 없는 Task 를 **동시 2개 이상 받으면 거부**한다.
근거: `orchestration.md:181` *"Orca does not schedule workers or infer conflicts."* / `:342` *"Independent tasks, parallel execution, convenience, or a preference for separate checkouts are not isolation requirements."*
→ 동시 편집 안전성은 **100% 우리 책임**이며, 방어는 문서가 아니라 스크립트 거부여야 한다.

### 3.7 STAGE 6 — 게이트 (두 채널 분리)

```bash
# 코디네이터-소유 DAG 판정 = gate
G=$("$ORCA" orchestration gate-create --task "$T_P" --question "Gate P: plan 이 spec delta 를 전건 커버하고 Best-Direction Check 를 통과하는가?" --options '["PASS","FAIL"]' --json)   # [P2]
"$ORCA" orchestration gate-resolve --id "$G" --resolution "FAIL: BLOCKER-1 … / 근거 원문 인용" --json
"$ORCA" orchestration gate-list --task "$T_P" --json

# 워커의 중간 질문 = ask → reply
# ★ 사용자 머지 승인 = AskUserQuestion (사람) — gate 로 대체 금지
```
`orchestration.md:281` verbatim: *"Use `ask` for worker-to-coordinator questions; it creates a `question` message that the coordinator answers with `reply`. Use `gate-create` only for coordinator-managed task DAG decisions, not for answering a worker's `ask`."*

### 3.8 STAGE 7 — 워커 종료 보고 (워커 claude 세션 *안*에서)

```bash
ORCA="C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe"   # ★ PATH 부재 + .cmd 는 send 거부
"$ORCA" orchestration send --type worker_done --subject "Phase I: PASS" \
  --body "<변경·발견·잔여 3문장>" --task-id "$TASK" --dispatch-id "$DISPATCH" \
  --outcome succeeded --files-modified "hooks/x.sh,setup/verify-setup.sh" \
  --report-path "docs/superpowers/plans/2026-08-xx-c21.md" --phase "I" --json
```
- stage2 첫 줄이 `FAIL:` 이면 `--outcome failed`. `orchestration.md:252` verbatim: *"On failure, use `--outcome failed`; never encode failure only in prose."*
- `worker_done` 뒤 `task-update --status completed` **금지**(:154).
- ⚠️ **`orca orchestration escalation` 은 존재하지 않는 명령이다**(안 3 의 치명 결함). orchestration 하위 29 명령 전수에 없음 — escalation 은 **메시지 타입**이며 정본은 `send --type escalation`. 워커 계약 문서에 이 정정을 명문화한다.

### 3.9 STAGE 8 — 정리 + 사후 검증

```bash
"$ORCA" orchestration worker-release --dispatch "$D" --json     # 멱등. 아카이브 보존
"$ORCA" orchestration worker-read --dispatch "$D" --limit 50 --json   # 릴리즈 후에도 읽힘
"$ORCA" orchestration worker-list --json                        # 잔여 워커 0 확인
diff "$RUNDIR/settings.pre-orca.json" "$HOME/.claude/settings.json"   # 훅 배선 무변경 단언
grep -P 'PASS\tskip:' "$HOME/.claude/hooks/.log/$(date +%Y-%m).log"   # RPI_SKIP 사후 탐지 (0건 단언)
bash "$HOME/.claude/setup/verify-setup.sh"
```
릴리즈 금지 사유(가이드 :246): timeout · TUI idle · heartbeat · status · question · escalation · rejected/stale `worker_done`.

### 3.10 절대 발행 금지 (캐리어에 문자열 자체가 없어야 하고 오라클이 검사)

| 금지 | 근거 |
|---|---|
| `orchestration reset` | `:285` *"Do not run it during active coordination unless explicitly abandoning that state."* 무인 루프 치명 |
| `coordinator-start` / `coordinator-stop` / `run` / `run-stop` | `:283` 은퇴 — 효과 0 |
| `agent hooks off` | 지우는 대상 미확인 (스키마 notes 0건, 두 가이드 `agent hooks` 언급 0건) |
| `skills install` | 하네스 `skills/` 오염 — 타깃 미지정 시 감지된 전 에이전트에 글로벌 설치 |
| `claude-teams` | 제2 멀티에이전트 축 — provenance 충돌 (`:27`) |
| `--model` / `--effort` | §2 경계 |
| `--worktree new-child\|new-top-level` | §5.4 plan 가시성 |
| `claude --model gpt-5.6-sol` 리터럴 | 신규 세션 404 (§4.4) |
| `dispatch --inject` 직접 호출 | worker-start 조합이 preferred (`:25`) |

---

## 4. 모델 라우팅 — claude 진입 후 다중 모델

**결론: 워커 세션 전체를 gpt 로 바꾸지 않는다. 세션은 항상 claude 이고, 모델은 세션 *안에서* 호출 단위로 갈아탄다.**

### 4.1 층 0 — Orca 축: 모델 무선언 (의도적 공백)

`worker-start --agent claude` 만. `--model`/`--effort` 미발행. 근거 3개(강도 순):

1. **[안 3 프레이밍 이식 — 최우선 근거] 공백을 오라클로 덮는 게 아니라, 공백이 성립하는 축을 안 쓴다.** argv 축의 티어 선언은 L2 매처가 **원리적으로** 못 본다(`surface-model-policy.sh:18` `Agent|Workflow` 한정; `grep -rn -- "--model" hooks/*.sh` 매치 0). 모델 축을 워커 내부로 옮기면 Rule A/B/C/C2/C3 가 **자동 복원**된다(단 §4.5 단서).
2. **[안 1 논거 이식] 채택하면 터미널 재사용을 잃는다.** 스키마 NOTE: `Neither can combine with --terminal.`
3. 값 집합이 opaque 이고 enum 부재. 유일 예시 `aws-bedrock-opus-5`(orchestration.md:198). 228 CLI 명령 중 모델 목록 조회 명령 **0개**. `claude-opus-5[1m]` 유효성 **근거 없음 — 미확인**.

**옵트인 경로(측정 후에만)**: 캐리어에 `ORCA_WORKER_MODEL`(기본 빈 값). 값이 있으면 receipt 의 `launch.requested` vs `launch.effective`(orchestration.md:195 명시 필드) 를 대조해 **불일치 시 abort**. 무측정 단언 금지 규율의 기계적 구현.

**워커 셸 티어**: `settings.json` env 상속 → `ANTHROPIC_MODEL = claude-sonnet-5[1m]`(실측). 워커 실측 트랜스크립트도 `"model":"claude-sonnet-5"` 38건(`d2b30c72….jsonl`)으로 일치. 셸은 *오케스트레이션 사무용*이고 실제 추론은 층1·2 — 따라서 Task spec 이 층1 호출을 **명령**한다(권유 아님).

### 4.2 층 1 — Claude 패밀리: 워커 내부 Agent / Workflow

| Phase | 호출 | 모델 축 |
|---|---|---|
| R (Research) | `Agent(explore-strict)` | frontmatter sonnet + xhigh |
| P (Plan) | `Agent(execute-strict)` | frontmatter opus (C17 Option 1) |
| Gate R/P | `Agent(review-strict)` | frontmatter opus, floor=max(작업자, opus) |
| I (Implement) | `Workflow({scriptPath:"C:/Users/12132/.claude/workflows/rpi-implement.js", args:[…]})` | stage1 `execute-strict/opus/xhigh\|high` → stage2 `review-strict/opus` |

canonical 파서 실측: `node hooks/lib/workflow-spawns.js < workflows/rpi-implement.js` → `execute-strict\topus` / `review-strict\topus`.

**별칭 해소 실측**: `claude --model opus` 가 `settings.json` env(`ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5[1m]`)를 타고 해소된다 → **버전-무관 불변식이 Orca 워커에서도 성립**. 정책층은 별칭(`opus/sonnet/haiku/fable`)만 쓴다.

**Agent 도구 `model` enum = {sonnet, opus, haiku, fable}** — GPT 직접 지정 불가. 과거 GPT 도달로였던 haiku 슬롯은 컷오버로 네이티브(`ANTHROPIC_DEFAULT_HAIKU_MODEL = claude-haiku-4-5-20251001` 실측; 워커 트랜스크립트 다수에 `"model":"claude-haiku-4-5-20251001"`). **`model-policy-design.md:71` 의 "luna 가 Agent 도구로 도달 가능"은 현재 거짓** — spec §20 에 정정 기록.

### 4.3 층 2 — 비-Claude: 워커의 Bash 서브프로세스

**경로 B — 브리지 (하네스 규율 *안*의 실행자·집필·대조)**
```bash
cat <대상문서> | OCX_MODEL=gpt-5.6-sol ~/.claude/bin/claude-ocx -p "<프롬프트>" --output-format json
```
- **env 주입 문제 소멸**: Orca 는 워커 env 를 못 준다(228 명령 플래그 유니온 238개 중 env 계열 0; `--environment` 는 원격 런타임 선택자 — `orca environment add --name <name> --pairing-code <code>`). 그러나 우리는 Orca 에게 부탁하지 않는다 — **워커 자기 프로세스**가 인라인 env 프리픽스를 붙인다. **요구 1(진입점=claude)이 이 제약을 구조적으로 해소한다.**
- 브리지 argv 봉인(코드 실측): `bin/claude-ocx:31-37` `--model`/`--model=*` 둘 다 exit 2 · `:20-22` 네이티브 별칭 6개 + `ANTHROPIC_API_KEY` unset · `:39` `exec claude --model "$OCX_MODEL" "$@"` · `:12-15` `/healthz` 미도달 시 exit 1 fail-closed.
- **하네스 규율 유지 실증**: 브리지 GPT 세션이 CLAUDE.md §3 을 인용했고, `enforce-rpi-bash` 가 그 세션을 차단했다 — `hooks/.log/2026-08.log`: `2026-08-13T00:48:22+09:00 enforce-rpi-bash git-apply/patch BLOCK no-active-plan-conservative`.
- **비용 자동 부기**: `--output-format json` 이 `total_cost_usd`·`input/outputTokens` 반환(실측 `0.13843` / `27596` / `18`). 래퍼가 `_goal/<cycle>-ocx-ledger.tsv` 에 append → C16 layer-yield 의 "가용 시 부기"를 신규 계측 인프라 0으로 충족.

**경로 A — codex CLI (하네스 *밖*의 독립 검증자)**
```bash
cat "$TARGET" | codex exec -m gpt-5.6-sol -c model_reasoning_effort=ultra \
  -c model_verbosity=high --sandbox read-only --skip-git-repo-check -o "$REVIEW_OUT" "<refute-by-default>"
```
가용 실측: `codex --version` → `codex-cli 0.145.0`. `ultra` effort 실재 확인 — 프록시 카탈로그에서 `gpt-5.6-sol` efforts 에 `ultra` 포함(`gpt-5.6-luna` 는 `max` 까지, ultra 없음).

**역할 분담 불변식**: GPT 를 **실행자**로 쓸 때 경로 B(규율 아래), **검증자**로 쓸 때 경로 A(제어 지점 + 독립성). 합치면 리뷰 품질 레버(ultra/verbosity)를 잃는다. 단 A·B 는 codex 인증을 공유하므로(`authMode=forward`) **폴백 관계가 아니다**(동시 사멸).

### 4.4 금지 리터럴 — 죽는 코드

| 금지 | 실측 근거 |
|---|---|
| `claude --model gpt-5.6-sol` | clean env(`env -u ANTHROPIC_BASE_URL …`)에서 `api_error_status: 404` · `"There's an issue with the selected model (gpt-5.6-sol)"` · RC=1. 현 세션에서 되는 건 세션-동결 CCS env 덕이고 그 3키는 settings.json 에 **없다**(`grep -c "gpt" settings.json` → 0; 본 문서 env 스캔에서도 `ANTHROPIC_BASE_URL`/`AUTH_TOKEN`/`CUSTOM_MODEL_OPTION` 부재 재확인) |
| `Agent(model:'gpt-*')` | enum {sonnet,opus,haiku,fable} 뿐 |
| Gemini 를 브리지로 | `OCX_MODEL=google-antigravity/gemini-3.6-flash` → RC=124(180s), stdout 0바이트. 프록시 직접 POST 만 성공하며 `max_tokens=32` 에서 `content:[]`+HTTP 200 **침묵 실패**. 이 설계는 Gemini 를 슬롯으로 쓰지 않는다 |

**카탈로그 조회 규약**: `curl -s --noproxy '*' http://127.0.0.1:10100/v1/models` — **`--noproxy '*'` 필수**(없으면 rc=28 타임아웃 → "프록시 죽음" 오판정). 본 문서 실측 http=200, 10 모델(GPT 7 + Gemini 3).

### 4.5 ★ 층 2 의 정책 사각 — 명시 (승자 안 치명 결함의 실체)

**"모델을 워커 내부로 밀면 L2 커버가 자동 복원된다"는 Claude 세션에 한정된다.** §0.2 실측대로, **비-Claude 세션에서는 5규칙 전부가 침묵**한다(리터럴 포함).

| 워커 세션 | Agent 경로 (Rule A·B) | Workflow 경로 (Rule C·C2·C3) |
|---|---|---|
| claude-* | **정상 발화** (CONTROL 실측) | **정상 발화** (CONTROL 실측) |
| gpt-5.6-sol 등 | **전면 침묵** (`:169` exit 0) | **전면 침묵** (`:54`/`:56` exit 0) |

**대응 2단(§6.2·§7-T4)**:
- **코드**: `session_model_of()` 를 `claude-` 접두 비의존으로 확장 + `WF_TIER=0` 조기종료를 **리터럴 축만 계속 검사**하도록 분기(상속 축은 단언 불가라 계속 skip — 정직).
- **계약**: 워커 계약에 **"GPT 세션 내 `model:'inherit'` 위임 금지 — 리터럴 강제"** 명문화. 상속 축은 코드로 판정 불가하므로 계약으로만 막는다(= advisory, 수용 잔여 §8-D14).

---

## 5. 하네스 시너지 — 훅·게이트 발화 지도

### 5.1 발화 지도 (전부 실측; 미관측은 미관측으로 표기)

| 워커 생명주기 | 훅(매처) | 실측 | 무엇을 하는가 |
|---|---|---|---|
| 세션 시작 | `session-start-audit` (SessionStart) | **발화** — `10:21:43 plugin-drift ALERT cksum 1583290756->2069313554` / `10:21:45 global-CLAUDE.md ALERT 60d` | 공급망·audit 표면화. **규범 채널 아님** — `grep -c emit_additional_context hooks/session-start-audit.sh` → **0** (stderr 전용). 안 1 의 "additionalContext 채널 살아 있음"은 **거짓**, 안 3 이 옳다 |
| Write/Edit | `enforce-rpi-cycle` (PreToolUse) | **발화 + 하드 차단 + 모델 도달** — BLOCK 3건 전부 `no-plans-dir`; 워커 트랜스크립트 LINE 44 `"PreToolUse:Write hook error: …", "is_error": true` | **주 강제선** |
| Bash | `enforce-rpi-bash` (PreToolUse) | **발화 + 차단 실증** — `2026-08-13T00:48:22 git-apply/patch BLOCK no-active-plan-conservative` (브리지 GPT 세션). 본 문서 작성 중에도 나를 차단함 | 사이드도어 봉인 |
| Agent/Workflow | `surface-model-policy` (PreToolUse) | **발화** — `00:50:15 review-strict:haiku ALERT rule-b-verifier-below-opus-floor` (워커 *내부* Agent 호출). **단 비-Claude 세션에서 전면 침묵** (§4.5) | 모델 정책 — 사각은 §6.2 로 대응 |
| 도구 호출 | `auto-compact-watch` (PostToolUse) | **발화** — `10:25:30 model=claude-sonnet-5 ALERT 35% (… win=200000)` | 창 관측. ⚠️ `win=200000` 은 **표시 아티팩트일 수 있다**: `node hooks/lib/model-window.js claude-opus-5` → **200000**, `claude-opus-5[1m]` → **1000000` (실측). 트랜스크립트는 wire-strip 된 canonical 이름을 기록하므로 실제 1M 세션도 200K 로 읽힌다 — **기존 결함, 이 모드가 노출 빈도를 늘린다** |
| 세션 종료 | `worktree-teardown` (SessionEnd) | 발화하되 4건 전부 `PASS noop:not-worktree` | §5.4 — 겹침 0이 정상 |
| 전 도구 | `enforce-session-budget` (PreToolUse `*`) | **구조적 미발화** | `hooks/enforce-session-budget.sh:9` `[ -z "${SESSION_TOOL_BUDGET:-}" ] && exit 0` + Orca env 주입 수단 부재 → **무인 루프 폭주 상한 소멸. 수용 잔여 §8-D13** |
| — | `enforce-orchestrator` · `enforce-secret-scan` · `stable-claude-md` · `surface-constitution` | 배선 확인, Orca 워커 차단 실적 로그 **0건** | 통과 시 무로깅 경로 존재 → "미발화"와 "발화 후 통과" 구분 불가. **미확인 §8-D15** |

**배선 출처 증명**: 워커 워크스페이스에 로컬 `.claude` 없음(`ls -a` → `.` `..`)인데 `$HOME/.claude/hooks/enforce-rpi-cycle.sh` hook error 가 워커 트랜스크립트에 실림 → 글로벌 `settings.json` 이 프로세스 경계를 넘는다.

### 5.2 규범 도달 — 비대칭 정정

| 계층 | 도달 | 근거 |
|---|---|---|
| L2 훅 (강제) | **자동 상속** | 위 배선 출처 증명 |
| L1 CLAUDE.md (규범) | **자동 상속** ← **정정** | §0.1 반증 1 (§8 verbatim + §9 음성 대조군) |
| SessionStart additionalContext | **미도달** | `session-start-audit` 은 `emit_additional_context` 호출 0 |

→ **Task spec 은 규범을 재전송하지 않는다**(중복). 대신 **사이클 고유 계약만** 나른다: `worker_done` 발행 커맨드(orca.exe 절대경로) · PASS/FAIL→`--outcome` 매핑 · read-only 팬아웃 규칙 · `RPI_SKIP` 금지 + 대안(`send --type escalation` / `ask`) · **GPT 세션 내 `inherit` 위임 금지**(§4.5).

### 5.3 ★ 워크트리 plan 가시성 문제 — 해법

**문제의 실체(실측)**: `hooks/_common.sh:141-151` `resolve_project_root` 는 상위탐색을 git-top 으로 bound 한다(주석 :143 "무관 부모 plan 오상속 차단"). 비-git 이면 상위탐색 없이 cwd 반환. `enforce-rpi-cycle.sh:83-84` 가 `$ROOT/docs/superpowers/plans` 부재 시 `exit 2`.
관측된 Orca 워크스페이스는 비-git(`ls -a` → `.` `..`, `.git` 없음) → BLOCK 3건 → 워커가 스스로 `export RPI_SKIP="…"` 를 발명(트랜스크립트 LINE 58-59: AskUserQuestion 옵션 "RPI_SKIP으로 건너뛰기 (권장)" 자가 제시·채택).

**해법 — 4중, 순서 고정**

1. **`--worktree current` 고정 (구조).** 워커가 코디네이터와 **같은 체크아웃**에서 뜨면 미커밋 plan 도 보인다. 커밋 여부에 의존하지 않는 유일한 해법(별도 체크아웃은 git worktree 든 독립 사본이든 미커밋 plan 을 못 본다). 그리고 이건 Orca 자신의 기본값과 정합 — `:334` *"`Fresh worker` means a fresh agent session, not a new git worktree."*
2. **selector 재조립 금지.** `worktree current --json` 반환값을 **verbatim** 전달. 근거: 본 문서 작성 중 동형 사고 재현 — bash `/tmp` = `C:/Users/12132/AppData/Local/Temp`(`pwd -W` 실측)인데 Write 도구는 `C:/tmp` 에 기록해 파서가 "No such file" 로 rc=0 침묵 통과. **MSYS 경로 보간은 이 머신의 알려진 실패 클래스다.**
3. **Preflight fail-closed.** `has_active_plan` 실패 시 **Task 를 만들지 않고** rc=3. 실패 모드의 발생 조건 자체를 제거.
4. **사후 탐지.** Closeout 에서 사이클 시간창의 `hook_log … PASS\tskip:` 카운트 0 단언. **예방 아니라 탐지**로 표기 — `RPI_SKIP` 은 워커 프로세스가 자기 env 를 소유하므로 차단 불가(§8-D14).

**탈출구(기본 아님, 안 1 이식)**: 격리가 진짜 필요하면 `orca.yaml` `worktree.sharedDirectories: [docs/superpowers]`. 소스 실독(`orca-yaml.ts:214-224` `normalizeSharedDirectories`)으로 repo-root-상대 경로를 워크트리에 링크하는 필드임을 확인했으나 **런타임 미검증** → 문서화만 하고 기본 경로에 넣지 않는다. `--worktree current` 가 실패할 때의 유일한 대안이므로 문서에 남긴다.

### 5.4 소유권 경계 — Orca 워크스페이스 정리

**실측으로 확정**: `worktreeMeta` 에 `orcaCreationSource: "runtime"` 인 워크스페이스 2건(`lab-gpt3`, `impl-parse`)이 등재돼 있는데,
- `lab-gpt3` → 디스크 **ABSENT**
- `impl-parse` → 존재하나 `entries=0`, `.git` 없음
- `git -C orca-lab worktree list --porcelain` → 메인 1개뿐, `.git/worktrees` 디렉터리 없음

즉 **Orca 가 워크스페이스 생성·정리를 자기 축에서 수행**하고, 하네스 sweep(cycle-41)은 `.claude/worktrees` 게이트 때문에 도달하지 않는다. `worktree-teardown` 이 전 4건 `noop:not-worktree` 인 것이 **정상 동작**이며 중복 0. 이 설계는 `--worktree current` 고정이라 워크트리를 만들지 않으므로 충돌 표면이 애초에 없다.

### 5.5 판정의 Orca 상태 승격 (양방향 시너지)

| 하네스 자산 | Orca 매핑 | 이득 |
|---|---|---|
| `workflows/rpi-implement.js` stage2 "보고 첫 줄은 반드시 PASS 또는 FAIL:" | `--outcome succeeded\|failed` | 유효한 `worker_done` 이 Task/Dispatch 를 자동 completed/failed 로 만든다(:154, :383) → **하네스 판정이 DAG 상태로 승격** |
| C16 델타 재심("편집 파일/절 한정") | `--files-modified <csv>` | 지금은 메인의 수기 추적 → 워커가 **구조적으로 반환** |
| RPI 단계 라벨 / plan 경로 인계 | `--phase` / `--report-path` | 메시지 레이어로 상승 |
| Gate R/P 판정 | `gate-create`/`gate-resolve` | 1급 블로킹 상태 + 감사 로그. **review-strict 를 대체하지 않는다** — review-strict 는 판정을 *생산*하고 gate 는 그 판정을 DAG 에 *구속*한다 |

### 5.6 가이드 금지조항 (:27, :36) 과의 해석 충돌 — 명시 해소

`orchestration.md:27` verbatim: *"Do not substitute non-Orca subagent tools, generic agent-spawn APIs, or chat-only parallel worker features."*

**해소 = 2층 분리를 문서에 명시**:
- **층 1 (Orca)** = Phase 경계의 Run/Task/Dispatch. 여기서만 "오케스트레이션"을 주장한다.
- **층 2 (하네스)** = Phase *내부* 위임(Agent/Workflow). Orca 에 오케스트레이션이라 주장하지 않는다.

이 경계를 문서에 명시하지 않으면 C18 fable 위임 구조가 (a) 위반으로 읽힌다. **이건 우리 해석이지 Orca 의 승인이 아니다** — spec §20 에 그렇게 기록한다. `:29-34` 의 provenance 검증(`task-list`/`dispatch-show` 실존 확인)은 캐리어가 자동 수행하므로 준수한다.

---

## 6. 정책 공백과 검사 지점 (L3 오라클 대체)

### 6.1 seal #51 — 폐기 아닌 **재조준**

| 항목 | AS-IS | TO-BE |
|---|---|---|
| 스캔 대상 | `$HOME/.claude/modes/*.json`(Orca 미소비) | `bin/orca-rpi.sh` + `skills/orca-rpi-cycle/SKILL.md` (실행 자산) |
| 오라클 | `setup/lib/modepack-oracle.sh` | `setup/lib/orca-carrier-oracle.sh` |
| 판정 방향 | review-only 워커가 floor 미만이면 VIOLATION | **경계 위반 토큰 발견 = VIOLATION** (부정-단언) |
| `TOTAL` 의미 | `m.workers[]` 수 | 발견한 `worker-start` 발행 사이트 수 |
| `TOTAL=0` 계약 | **FAIL** (vacuous 방지) | **FAIL 유지** ← 필수 보존 |
| 재사용 부품 | — | `tierOf()` **그대로 이식**: last-wins(`matchAll` 후 마지막) · `/[${}%]/` → dynamic · 리터럴/동적/부재 3값 계약 (`modepack-oracle.sh:64-67` — C20 claude CLI 실측 자산) |

**검사 항목(ⓐ~ⓕ)**:
ⓐ `--model` / `--effort` 출현 **0** ⓑ `--agent claude` 이외 값 **0** ⓒ `--worktree` 가 `current` 또는 `$WT_SEL` 이외 값 **0** ⓓ 금지 명령 리터럴(`orchestration reset`, `coordinator-start|stop`, `run-stop`, `agent hooks off`, `skills install`, `claude-teams`) **0** ⓔ `claude --model gpt-` 리터럴 **0** ⓕ `$ORCA` 해소가 `orca.exe`(또는 `ORCA_CLI_COMMAND`)이고 `orca.cmd` 리터럴 **0**.

**⚠️ TOTAL 정의의 약점(안 3 자기지적 승계)**: `TOTAL` 을 "worker-start 호출 사이트 수"로 두면 캐리어 리팩터로 호출을 함수로 감쌀 때 조용히 0 이 될 수 있다. → **완화**: `TOTAL` 을 `worker-start` 호출 사이트 수 **또는** 캐리어 파일에 필수 앵커(`--agent claude` 리터럴) 존재 수 중 **큰 값**으로 정의하고, 두 값 모두 0 이면 FAIL. 그리고 seal-regression M23 이 이 arm 을 검증한다.

### 6.2 ★ GAP-A — 비-Claude 세션 전면 침묵 (신규, 최우선)

§0.2·§4.5 의 사각. **이것은 Orca 모드가 만든 공백이 아니라 기존 훅의 결함이며, Orca 모드가 노출을 실물화한다**(GPT 워커 트랜스크립트 4개 파일 실재).

| 수단 | 내용 | 한계 |
|---|---|---|
| **코드 수정 (T4)** | `session_model_of()` 를 `"model":\s*"[A-Za-z0-9._/-]+"` 로 확장하고, 비-Claude 세션에서는 **리터럴 축만** 판정(Rule A 리터럴 fable / Rule B 리터럴 floor / Rule C·C2 리터럴). 상속 축(`inherit`, `'*'`, 무선언)은 **계속 skip** | 상속 축은 판정 불가 — **단언 불가를 단언하지 않는다**(정직) |
| **계약 (T3)** | 워커 계약: "GPT 세션에서 `model:'inherit'` 위임 금지 — 리터럴 명시 강제" | advisory. 강제 불가 |
| **픽스처 (T5)** | `cases.tsv` 에 GPT-세션 리터럴 위반 케이스 추가 → 현재는 **RED 아님(침묵)** → 수정 후 GREEN | — |

**정직 부기**: 수정 후에도 GPT 세션의 `inherit` 위임은 침묵한다. "Orca 워커에서 모델 정책이 완전 복원된다"고 쓰면 **거짓**이다. 정확한 표현: **"Claude 세션 = 5규칙 전부 / 비-Claude 세션 = 리터럴 축만 / 상속 축 = 계약(advisory)"**.

### 6.3 seal #52 신설 (conjunctive)

ⓐ `docs/ai-context/orca-pins.md` 에 `skills get orchestration --json` + `agent-context --json` cksum 핀 존재
ⓑ 워커 계약 문서의 필수 토큰 6종: `--outcome` · `--worktree current` · `read-only 팬아웃` · `RPI_SKIP 금지` · `orca.exe` · `inherit 위임 금지`
ⓒ 캐리어에 `new-child|new-top-level` 리터럴 **부재**(부정-단언 seal — #25 verify-integration 선례)

**핀이 필요한 이유**: 가이드가 **CLI 번들에서 나온다** — 스키마 `skills get` NOTE verbatim: *"Reads bundled guide content locally without contacting the Orca runtime."* Orca 업그레이드 시 계약이 조용히 바뀐다(설치본에 `orca-updater/pending/orca-windows-setup.exe` 대기 중). plugin-pins cksum 선례 동형.

### 6.4 seal-regression 동기 (승자 안이 포착, 안 1 이 누락한 항목)

`setup/tests/seal-regression.test.sh:33` 실측 verbatim:
```
for d in hooks setup skills agents commands workflows modes; do   # workflows: seal #45 … · modes: seal #51 C20 vacuous-방지 arm이 modes/*.json 검사
```
→ `modes` 제거 · **`bin` 추가** (+ 주석 근거 문장 교체).
**부수 이득**: `git ls-files bin/` → `bin/claude-ocx`, `bin/claude-ocx.cmd` 가 현재 replica 에 복제되지 않아 관련 검사가 vacuous 가 될 수 있는 구멍도 함께 닫힌다.

신규 Mutator 2종: **M23**(캐리어에서 `worker-start` 라인 제거 → TOTAL=0 → FAIL 기대) · **M24**(캐리어에 `--model opus` 주입 → VIOLATION 기대). 신규 M25(GAP-A 회귀: GPT 세션 리터럴 위반이 침묵 복귀하면 FAIL) 권장.

### 6.5 단위 픽스처 공백 해소

실측: `grep -c "" hooks/tests/cases.tsv` → **310**, `grep -ci "orca\|modepack\|--model" hooks/tests/cases.tsv` → **0**.
`model-policy.md` L3 절이 *"토큰 존재 감지이지 로직 무결성 검증 아님 — 로직 회귀는 run-all 픽스처가 담당"* 이라 선언했는데 **그 픽스처가 존재하지 않는다**. 승자 안은 이를 acceptance 티어 테스트에만 두었으므로 **양쪽 모두** 착륙한다(§7-T5).

---

## 7. 착륙 계획 (C21 task 분해)

### Phase 0 — 실측 프로브 (하드 게이트, 안 3 이식 — 코드 착륙 전 통과 필수)

| # | 작업 | 검증 기준 |
|---|---|---|
| **P0-1** | `orca status --json` / `orchestration run-list --json` / `worktree current --json` / `agent hooks status --json` / `orchestration dispatch --task <throwaway> --to <handle> --dry-run --return-preamble --json` 5건 실행 | 각 출력 verbatim 을 `_goal/c21-orca-probe-measured.md` 에 기록 |
| **P0-2** | JSON 응답 필드 경로 표 확정 (run id / task id / dispatch id / delivery id / gate id / `worker.agent_terminal_handle`) | `[P2]` 마커가 붙은 전 항목이 실측값으로 교체됨 |
| **P0-3** | `agent hooks status` 실행 **전후** `settings.json` cksum 대조 | 변경 0 |
| **P0-4** | preamble 원문 확보 → 워커 계약 문서와 상충 여부 평가 | 상충 항목 0 또는 문서에 조정 기록 |

**게이트 규칙**: P0 산출물이 없으면 T1~T3 코드 작성 **금지**. flow 의 미확인 경로에는 `# [P2]` 를 남겨 "여기는 추정"을 코드 표면에 명시. **이것이 모드팩 실패(서드파티 계약 무검증 채택)의 동형 재발을 막는 유일한 절차적 장치**다 — 근거: `orca-schema.json` 은 응답 shape 를 전혀 제공하지 않고, orchestration DB 가 tasks=0·dispatches=0 이라 **이 머신에서 응답 shape 를 아는 사람이 아무도 없다**.

### 신규 파일

| # | 파일 | 내용 | 검증 기준 (TDD) |
|---|---|---|---|
| **T1** | `bin/orca-rpi.sh` (실행권한, git 추적, install.sh REQUIRED 등재) | 유일 스폰 캐리어. 서브커맨드: `preflight`·`run`·`task`·`spawn`·`wait`·`handoff`·`release`·`gate`·`gpt`·`selfcheck`. 불변식: `$ORCA`=`${ORCA_CLI_COMMAND:-…/orca.exe}`(orca.cmd 금지 근거 주석 동반) · `--agent claude` 고정 · `--worktree` 는 `current`/`$WT_SEL` 만 · `--model`/`--effort`/`--on`/`new-child`/`new-top-level` 인자 **미수용** · 금지 명령 발행 불가 · non-readonly task 동시 2개 **거부** · `check` stdout/stderr 분리 + `_keepalive` 필터 + 전건 순회 후 ack · `worker-start` 비-0 시 자동 재시도 금지 · preflight 에서 settings 백업, 종료 시 diff | ⓐ `bash -n` 통과 ⓑ `--model` 인자 전달 시 rc≠0 + 사유 출력 ⓒ non-readonly 동시 2개 spawn 시 rc≠0 ⓓ 소스에 금지 리터럴 0건(오라클과 이중) |
| **T2** | `skills/orca-rpi-cycle/SKILL.md` | **`create-orchestrator-skill` 로 생성**(CLAUDE.md §2 강제). Task spec 템플릿 4종(R/P/I/C) + 리뷰 슬롯 2종 | `hooks/lib/skeleton-scan.js` 요건: `orchestrator_skill: true` + `generated_by:` + `orchestrator_version:` 마커 트리플 · `# Phase ` ≥3 · `Agent(` ≥1 · `Communication Protocol` 절 ≥1 |
| **T3** | `docs/ai-context/orca-worker-contract.md` | 워커 계약 SSOT. `worker_done` 정확 커맨드(orca.exe 절대경로) · PASS/FAIL→`--outcome` · `ask` vs `gate` vs `send --type escalation`(⚠️ `orchestration escalation` 명령 **부재** 정정) · `RPI_SKIP` 금지 · read-only 팬아웃 · **GPT 세션 `inherit` 금지** | seal #52-ⓑ 토큰 6종 존재 |
| **T4** | `hooks/surface-model-policy.sh` **개정** (GAP-A) | `session_model_of()` 접두 비의존화 + 비-Claude 세션 리터럴-축 판정 분기 | RED: 현재 GPT-세션 리터럴 위반 케이스 침묵 → GREEN: ALERT. Claude 세션 무회귀(run-all 310 불변 + 신규분) |
| **T5** | `hooks/tests/cases.tsv` + `hooks/tests/run-all.sh` 신규 ≥8 | last-wins(`--model opus --model haiku`→haiku) · 동적(`--model $VAR`→`*`) · 부재 · `--model` 출현→VIOLATION · `--agent codex`→VIOLATION · `new-top-level`→VIOLATION · 금지명령→VIOLATION · **GPT-세션 리터럴 위반→ALERT(T4 회귀)** | cases.tsv↔run-all 양방향 정합(run-all.sh:1374-1390)이 강제 → 두 파일 동시 편집 |
| **T6** | `setup/lib/orca-carrier-oracle.sh` | `modepack-oracle.sh` `tierOf()` 이식 + 입력·판정 방향 교체(§6.1) | `TOTAL/LITERAL/DYNAMIC/VIOLATION` 출력, TOTAL=0 → 호출자 FAIL |
| **T7** | `setup/tests/orca-carrier-oracle.test.sh` | last-wins·체이닝·동적·부재 4클래스 + 경계 위반 6종. `verify-all.sh` STAGE 2b 배선 | 전 케이스 PASS, RED-first 확인 |
| **T8** | `docs/ai-context/orca-pins.md` | `skills get orchestration --json` + `agent-context --json` cksum 핀(현 `commandCount=228`) | seal #52-ⓐ |
| **T9** | `docs/ai-context/orca-boundary.md` | §2 경계 소유권 표 + 금지 명령 + §5 발화 지도 + §8 미확인 목록. `model-policy.md` 동형 3층(L1/L2/L3) | scaffold-registry 등재 |

### 개정 파일

| # | 파일 | 작업 | 검증 |
|---|---|---|---|
| **T10** | `setup/verify-setup.sh:615-633` | seal #51 재조준(§6.1) + seal #52 신설(§6.3) | verify-setup FAIL 0 |
| **T11** | `setup/tests/seal-regression.test.sh:33` | `modes` → `bin` 교체 + 주석 근거 문장 교체. M23/M24/M25 추가 | control PASS + 신규 Mutator 전건 발화 |
| **T12** | `README.md:300` | `현재 89 PASS` 재동기 + 구조 트리에 `bin/orca-rpi.sh` | seal #36 런타임 self-count parity |
| **T13** | `docs/ai-context/model-policy.md` | L2 절 정정: **"매처 사각 = 워커 *기동 argv* 한정 · 워커 내부 호출은 커버 · 단 비-Claude 세션은 리터럴 축만"**(현 서술은 과잉 일반화). L3 오라클명 교체. **"모델 티어는 Orca argv 에 두지 않는다"** 불변식 1줄 | seal #17 content-drift 통과 |
| **T14** | `docs/superpowers/specs/2026-07-25-model-policy-design.md` **§20 신설** (in-place, CLAUDE.md §5) | ⓐ 축③ F4 반증 실측(verbatim + 음성 대조군) ⓑ F5 경계 정정 ⓒ **GAP-A 실측(CONTROL/PROBE 4건)** ⓓ 모드팩 폐기 사유(DB 실측) ⓔ 층0 `--model` 미사용 3근거(특히 `--terminal` 배타 배당금) + 옵트인 receipt 대조 절차 ⓕ `--worktree current` 불변식 ⓖ `model-policy-design.md:71` luna 서술 정정 ⓗ 수용 잔여(§8) ⓘ 가이드 :27 2층 해석(우리 해석임을 명시) | §19 무편집(정밀화이지 supersede 아님) |
| **T15** | `skills/start-rpi-cycle/SKILL.md` Phase I | 옵션 **(e) Orca 감독 사이클** 추가(포인터만) + 불성립 시 (a)/(d) 폴백 명시 + "Orca 사용 시에도 stage1/stage2 모델 축은 (d) 와 동일" | ⚠️ seal 토큰 parity 대상 — 토큰 결손 주의. **미러 `opencode-harness/skill/start-rpi-cycle/SKILL.md` 동반**(seal #50 conjunct ③) |
| **T16** | `docs/ai-context/cross-family-review.md` | 2슬롯 리뷰를 Orca read-only Task 로 팬아웃 가능함을 §2 에 부기(경로 A 는 하네스 밖 유지 — 독립성 불변) | seal 무영향 |
| **T17** | `setup/install.sh` REQUIRED 배열 | `$TARGET/bin/orca-rpi.sh` 추가 | install 샌드박스 통과 |
| **T18** | `docs/ai-context/scaffold-registry.md` | T1·T2·T3·T6·T7·T8·T9 등재(#37 은 hook/skill 만 봄) | seal #37 |
| **T19** | `settings.example.json` deny 후보 `orchestration reset` | ⚠️ **패턴 문법 미확인 → 실측 후에만**. 라이브 `settings.json` 직접 수정 금지 | 미확인 시 defer 로 기록 |

### 삭제 (★ T10·T11·T12 와 **같은 커밋**)

| # | 파일 | 이유 |
|---|---|---|
| **T20** | `modes/orca-rpi-implement.json` + `modes/` | 단독 삭제 시 `verify-setup.sh:620` `MP_TOTAL -eq 0 → fail` arm 즉시 발화 + seal-regression replica 목록 불일치 + README parity 붕괴 **동시 발생** |
| **T21** | `setup/lib/modepack-oracle.sh` | T6 로 대체(`tierOf` 이식 후) |

### 검증 수열 (착륙 후)

```
1. bash setup/verify-setup.sh                   # 89 → +n, FAIL 0, README 동기 확인
2. bash setup/tests/orca-carrier-oracle.test.sh # 신규 전건 PASS
3. bash setup/tests/seal-regression.test.sh     # control PASS + M23/M24/M25 발화
4. bash hooks/tests/run-all.sh                  # 310 → +8 이상, 기존 무회귀 0 (T4 가 hooks/ 를 만지므로 필수)
5. bash setup/verify-all.sh                     # ALL PASS
6. Orca 라이브 드라이런: Run 1 · Task 1(read-only) · worker-start 1 · worker_done 수령 · worker-release
7. orca orchestration task-list --json          # provenance 실존 확인 (가이드 :29 의무)
8. diff settings.pre-orca.json settings.json    # 훅 배선 무변경
```

---

## 8. 수용 잔여 · 미검증 가정

### A. Orca 런타임 축 — **본 조사 orca 실행 0회**

| # | 항목 | 상태 |
|---|---|---|
| A1 | `run-create`/`task-create`/`worker-start`/`check --wait`/`gate-create`/`send --type worker_done` 가 이 머신에서 성공하는지 | **미확인**. DB 실측 `runs=1`(legacy 툼스톤)·`tasks=0`·`worker_dispatches=0`·`decision_gates=0`·`messages=0`·`deliveries=0` → **성공 전례 0** |
| A2 | orchestration experimental 플래그 상태 | **미확인**. `orca-data.json` settings 의 experimental 키 11개 중 orchestration 계열 0. 저장 위치 자체 미상 |
| A3 | 전 명령의 `--json` 응답 필드 경로 | **미확인**. 스키마 최상위 `['schemaVersion','commandCount','commands']` — 응답 shape 부재. 문서화된 유일 경로: `worker.agent_terminal_handle`, `launch.requested`/`launch.effective`, `stage`/`failedStage`/`effects`/`residualResources`, `agentTerminalHandle`→`startupTerminal.handle` |
| A4 | `--deps` JSON 배열 원소 스키마 | **미확인**. 틀리면 DAG 가 조용히 평평해져 **병렬 편집 발생** = 최대 안전 불변식 붕괴 |
| A5 | `worker-start --timeout-ms` 측정 대상 · `check --wait --timeout-ms` 상한 | **미확인**(플래그만 존재) |
| A6 | `--spec`/`--body` 크기 상한, 개행·따옴표 층간 재해석 | **미확인**. Orca 터미널 기본 셸 = `terminalWindowsShell: "powershell.exe"`(실측) → 재해석 위험. `orca.cmd` 가 send/reply 를 거부하는 것 자체가 이 위험의 실증 |
| A7 | injected preamble 원문 | **미확인**(`dispatch --dry-run --return-preamble` 미실행). 우리 워커 계약과 상충 가능 → P0-4 |
| A8 | `orca` PATH 부재 | **확인**: `command -v orca` rc=1. Windows User PATH 에만 존재 → 절대경로 필수 |

### B. 모델 축

| # | 항목 | 상태 |
|---|---|---|
| B9 | `--model` 유효 값 집합 | **미확인**. 이 설계는 **쓰지 않으므로 의존하지 않는다**. 향후 도입 시 `launch.requested` vs `launch.effective` 대조가 유일 판별법 |
| B10 | `--effort` 허용 레벨 | **미확인**(유일 예시 `high`) |
| B11 | "connected worker server must advertise launch-preference support" 로컬 성립 | **미확인** |

### C. 워커 기동 · 워크스페이스 축

| # | 항목 | 상태 |
|---|---|---|
| C12 | `--agent claude` 의 정확한 argv·cwd | **부분 확인**: `agentDefaultArgs.claude = "--dangerously-skip-permissions"`(orca-data.json 실측 — **워커의 유일 게이트가 하네스 훅**이라는 필연성 근거). 그 외 인자 **미확인**. 단 하네스 도달은 별도 실증됨(§0.1) — "argv 상세 미확인"이지 "하네스 미적용"이 아니다 |
| C13 | `--worktree current` 가 `~/.claude` 에서 유효 selector 반환 | **미확인**. `repos` 에 미등록(실측 1건 = orca-lab) → §9-A 선행 필수. 실패 시 §5.3 탈출구 |
| C14 | Orca 워크스페이스가 git worktree 인지 | **관측: 아니었다**. `impl-parse` `.git` 없음·entries=0, `lab-gpt3` ABSENT, `orcaCreationSource: "runtime"`. `orca worktree create` 가 항상 이 형태인지는 미확인 — `--worktree current` 고정이 이 미확인을 우회 |
| C15 | 워커 컨텍스트 창 | **미판별**. `auto-compact-watch win=200000` 이 실제 창인지 `model-window.js` `[1m]` 미인식인지 `/context` 실측 없음. 단 오판정 가능성은 실증(`model-window.js claude-opus-5`→200000 / `claude-opus-5[1m]`→1000000) |

### D. 훅·정책 축 — **수용 잔여(설계상 미해소)**

| # | 항목 | 상태 |
|---|---|---|
| **D16** | **`enforce-session-budget` 는 Orca 워커에서 구조적으로 죽는다** | **미해소 — 수용 잔여**. `:9 [ -z "${SESSION_TOOL_BUDGET:-}" ] && exit 0` + Orca env 주입 수단 부재(플래그 유니온 238개 중 env 0). **무인 루프 폭주 상한 소멸.** 대체: 캐리어가 dispatch 수를 세는 상한 — **단 코디네이터 세션이 살아 있을 때만 유효** |
| **D17** | **`RPI_SKIP` 은 차단 불가** | **미해소 — 수용 잔여**. 워커가 자기 env 를 소유. 방어는 (a) preflight fail-closed (b) 계약 (c) 사후 로그 검출 — **전부 예방 아닌 탐지/회피**. 워커가 스스로 우회를 발명한 실측 사례 존재 |
| **D18** | **GPT 세션의 `inherit` 위임은 판정 불가** | **부분 해소**(§6.2). T4 후에도 상속 축은 침묵. 계약(advisory)만 남음 |
| **D19** | **캐리어 우회(손-호출)는 오라클 사각** | **미해소 — 수용 잔여**. spec §19.7-4 상한 상속 |
| **D20** | **고아 워커 회수 절차 부재** | **미해소 — 수용 잔여**(렌즈③ 지적, 3안 공통 공백). 코디네이터 사멸 시 워커가 `--dangerously-skip-permissions` + 예산 훅 사멸 상태로 계속 편집한다. 완화 후보: 캐리어가 Run id 를 `_goal/` 에 durable 기록 → 다음 세션이 `worker-list` 로 고아 탐지 → `worker-release`. **미설계** |
| D21 | `agent hooks off` 가 지우는 'local hook entries' 실체 | **미확인**(스키마 notes 0건, 가이드 언급 0건). 현재 `agentStatusHooksEnabled: true`. 정황: 안 1 의 소스 추적이 `createManagedCommandMatcher` 를 `claude-hook.cmd` 파일명 스코프로 지목했고 `applyManagedHooks` 가 비-관리 엔트리를 보존(`[...cleaned, definition]`)하나, **술어 본문은 minify 로 추출 실패 → 증명 아닌 정황**. 완화: 캐리어 백업+diff |
| D22 | Orca 재설치/업그레이드가 하네스 훅 13 엔트리를 보존하는지 | **미확인**. 현재 공존 실측(24 = 하네스 13 + Orca 11, 12 이벤트)이나 보존이 병합 로직 덕인지 우연인지 미상 |
| D23 | `enforce-orchestrator`·`enforce-secret-scan`·`stable-claude-md`·`surface-constitution` 의 Orca 워커 **차단** 여부 | **미확인**. 통과 시 무로깅 경로로 구분 불가. 차단 실증 훅은 `enforce-rpi-cycle`·`enforce-rpi-bash` **2종뿐** |
| D24 | `agentDefaultEnv` 에 claude 항목 추가 시 env 주입 성립 여부 | **미확인**(현재 `{"goose":{"GOOSE_MODE":"auto"}}` 실측). 되면 D16 을 닫을 수 있으나 앱 상태파일 직접 편집이라 CLI 계약 밖 + 업그레이드 내성 미상 → **이번 설계에 포함하지 않음** |

### E. 성능 축

| # | 항목 | 상태 |
|---|---|---|
| **E25** | **Orca 병렬/터미널 재사용의 순이득** | **미측정 — 따라서 주장하지 않는다**(안 3 원칙 이식). C19 지배항(직렬 대기 67.5%) 공략은 **구조적 논거이지 측정이 아니다**. Orca 훅이 워커 도구 호출마다 curl(최대 1.5s)을 더할 수 있고 워커 콜드스타트도 미측정 → **순이득 부호 미확인**. C21 성과에 지연 단축을 기입하려면 **먼저 측정** |
| E26 | `--terminal` 재사용이 세션 컨텍스트를 이어받는지 | **미확인**. 가이드는 "transfers cleanup ownership" 만 말하고 세션 연속성을 진술하지 않음. 판별: 두 task 의 session_id 동일 여부 |

### F. 기타

| # | 항목 | 상태 |
|---|---|---|
| F27 | `terminal create --command` 문자열의 해석 셸 | **미확인**(cmd/PowerShell/MSYS). `VAR=val cmd` 인라인 프리픽스 유효성 미상 → GPT 워커 직접 스폰 경로 **보류** |
| F28 | `dispatch --inject` 가 `claude-ocx` 를 'recognized agent CLI' 로 판정하는지 | **미확인**(판정 기준 문서 부재) → 기본 설계에서 배제 |
| F29 | `orca.yaml` `worktree.sharedDirectories` 런타임 동작 | **소스 실독이지 실행 검증 아님** → 기본 경로 미포함 |
| F30 | `skills install --global` 의 실제 설치 경로 | **미확인**. `--dry-run --json` 으로 확인 가능(설치 없이). 발행 금지 유지 |
| F31 | 신규 세션 검증 미수행 | 본 조사의 clean-env 실측은 `env -u` 인위 제거이지 실제 신규 세션이 아님 |
| F32 | 브리지 세션의 PreToolUse 훅 발화 범위 | **부분 확인**: `enforce-rpi-bash` BLOCK 실증(§5.1). 나머지 PreToolUse 는 미측정 |

### G. 본 조사에서 **새로 확정한 것** (미확인 아님)

1. 글로벌 CLAUDE.md 는 Orca 워크스페이스의 별도 claude 프로세스에 **도달한다** (§8 verbatim + §9 음성 대조군 NONE + 경쟁 CLAUDE.md 전 경로 부재).
2. **비-Claude 세션에서 `surface-model-policy` 는 Agent·Workflow 양 경로 전부 침묵한다** (CONTROL/PROBE 4건 실측) — 승자 안·렌즈③ 판정보다 넓은 사각.
3. GPT 워커 트랜스크립트가 Orca 워크스페이스에 **실재**한다(`"model":"gpt-5.6-sol"` 22+2+4+1건) → 2번 사각은 이론이 아니라 실물.
4. `orca-data.json` = `AppData/Roaming/orca/profiles/local-default/orca-data.json`(29,843 B). `agentDefaultArgs.claude = "--dangerously-skip-permissions"` · `repos` 1건(orca-lab, `~/.claude` **미등록**) · `agentStatusHooksEnabled: true` · `terminalWindowsShell: "powershell.exe"` · orchestration experimental 키 **0**.
5. `orchestration.db` = `AppData/Roaming/orca/orchestration.db`, 테이블 20종, `runs=1`(툼스톤) 외 전부 0.
6. Orca 워크스페이스는 `orcaCreationSource: "runtime"` 이며 git worktree 로 등록되지 않고 Orca 가 정리한다(`lab-gpt3` ABSENT / `impl-parse` entries=0).
7. `orca.cmd:13-14` 가 `orchestration send|reply` 를 `exit /b 2` 로 거부 — worker_done 이 send 이므로 **orca.exe 필수**.
8. `hooks/lib/model-window.js`: `claude-opus-5`→200000, `claude-opus-5[1m]`→1000000 (기존 오판정 결함).
9. `session-start-audit` 는 `emit_additional_context` 호출 **0** → 규범 채널 아님(안 1 서술 기각, 안 3 정정 채택).
10. 프록시 가동: healthz `{"status":"ok","service":"opencodex","version":"2.11.0"}`, `/v1/models` http=200 · 10 모델 · `ultra` 는 sol/terra 전용 · **`--noproxy '*'` 필수**.
11. `codex-cli 0.145.0` 가용.
12. seal #51 현재 GREEN(`TOTAL=2 LITERAL=2 VIOLATION=0`)이나 검사 대상이 실행 경로 밖 = **무의미**.
13. `cases.tsv` 310행 중 orca/modepack/`--model` 관련 **0건**.
14. `seal-regression.test.sh:33` replica 목록에 `bin` 부재, `modes` 존재.
15. MSYS `/tmp` = `C:/Users/12132/AppData/Local/Temp` — 본 문서 작성 중 경로 보간 사고를 실제로 재현(파서가 "No such file" 로 rc=0 침묵 통과).

---

## 9. 사용자 사용법 (실사용 시나리오)

### A. 최초 1회 설정 (AI 가 대신 못 함)

```
1. Orca 데스크톱 → 하네스 repo 등록
   orca repo add --path C:/Users/12132/.claude        ⚠️ 명령 형태 미확인 — 스키마 usage 확인 후 실행
   (현재 등록 repo = orca-lab 1건 실측. 없으면 --worktree current 불성립)
2. Settings > Experimental 에서 orchestration 활성 확인
   (orca-data.json 에 해당 키 부재 — 저장 위치 미확인. UI 에서 육안 확인 필요)
3. orca agent hooks status --json  실행 + settings.json 백업/diff
   (agent hooks off 가 지우는 대상이 문서화되어 있지 않음 — 착륙 전 1순위)
```

### 시나리오 1 — 표준 RPI 사이클을 Orca 로 (가장 흔한 경로)

```
사용자: "C22 사이클 시작해줘. Orca 로 돌려."
```
| 단계 | 실제로 일어나는 일 |
|---|---|
| 1 | `start-rpi-cycle` Phase I 옵션 **(e)** 선택 → `skills/orca-rpi-cycle` 호출 |
| 2 | `bin/orca-rpi.sh preflight` — orca 가동·orchestration 도달·`worktree current`·plan 실재·settings 백업. **실패 시 rc=3 + 사유 → 자동으로 (a)/(d) 폴백**(사이클은 멈추지 않는다) |
| 3 | Run 1개 + Task 4개(R→P→I→C, deps 체인) |
| 4 | `worker-start --agent claude --worktree current` — 워커는 CLAUDE.md·훅을 **자동 상속** |
| 5 | 워커가 Phase 내부에서 Agent/Workflow 로 opus 호출, 필요 시 Bash 로 `claude-ocx`(GPT) |
| 6 | 코디네이터는 `check --wait` 로 블로킹 대기(sleep 루프 없음) |
| 7 | `worker_done --outcome succeeded` → Task 자동 completed |
| 8 | Closeout: read-only 리뷰 2슬롯 **동시** 팬아웃 → 단일 wait 로 수확 |
| 9 | 머지 승인은 **사용자에게 AskUserQuestion**(gate 아님) |

**미검증 — 첫 실행에서 확인**: 2~8 전 단계(§8-A1). 특히 `worktree current` 반환값(C13)과 JSON 필드 경로(A3).

### 시나리오 2 — 워커 안에서 GPT 를 부른다 (요구 2의 실사용)

```
사용자: "Phase I 구현하고, 설계층은 GPT sol 로 교차검증해."
```
```bash
# 워커 claude 세션 안에서 (진입점은 claude 고정)
# ① Claude 축 — 구현
Workflow({ scriptPath: "C:/Users/12132/.claude/workflows/rpi-implement.js", args: [...] })
#   → stage1 execute-strict/opus/xhigh → stage2 review-strict/opus  (L2 훅 정상 발화)

# ② GPT 축 — 독립 검증자 (경로 A, 하네스 밖·제어 지점 있음)
cat docs/superpowers/plans/<plan>.md | codex exec -m gpt-5.6-sol \
  -c model_reasoning_effort=ultra -c model_verbosity=high \
  --sandbox read-only --skip-git-repo-check -o "$REVIEW_OUT" "<refute-by-default>"

# ③ GPT 축 — 규율 아래 실행자 (경로 B, 하네스 안)
cat <대상> | OCX_MODEL=gpt-5.6-sol ~/.claude/bin/claude-ocx -p "<프롬프트>" --output-format json
#   → total_cost_usd 를 _goal/<cycle>-ocx-ledger.tsv 에 append (비용 자동 부기)
```
**세션은 끝까지 claude 다.** GPT 는 서브프로세스 1회 호출로만 등장한다 — 실측 확인(`modelUsage.gpt-5.6-sol`, `is_error:false`, exit 0).

**⚠️ 주의**: ③ 경로에서 `model:'inherit'` 로 재위임하면 모델 정책이 **침묵**한다(§4.5). GPT 세션 안에서는 **리터럴 모델 명시**.

### 시나리오 3 — Orca 없이 (폴백)

```
사용자: "Orca 안 켜져 있는데 사이클 돌려줘"
```
`preflight` 가 rc=3 을 내고 사이클은 기존 Phase I 옵션 (a)/(d) 로 그대로 진행한다. **Orca 는 선택적 가속기이지 필수 경로가 아니다** — 이것이 fail-open 설계의 요점이며, 하네스는 Orca 없이 100% 동작한다(현재까지 전 사이클이 그랬다).

### 시나리오 4 — 사고 대응: 워커가 안 끝난다

```
사용자: "20분째 아무 소식 없어"
```
| 판별 | 조치 |
|---|---|
| `check --wait` timeout / `{count:0}` | **정상 체크포인트**(:146). 코딩 작업은 15-60분이 정상 — 계속 대기 |
| heartbeat 있음 | 살아 있음 ≠ 완료(:147) |
| ⚠️ **`worker_done` 미발행** | **무한 대기가 정상으로 위장된다**(§8-A7). `worker-read --dispatch <D> --limit 50 --json` 으로 워커 출력 직접 확인 |
| 터미널 소멸/exit | 실패 확정 — `worker-show` 의 `stage`/`residualResources` 확인, **자동 재시도 금지**(:212) |
| **금지** | timeout/idle/heartbeat/question/escalation 을 이유로 `worker-release`(:246). `terminal close` 대체(:246) |

### 시나리오 5 — 사고 대응: 훅이 워커를 막았다

```
워커: "PreToolUse:Write hook error: [rpi] 차단: docs/superpowers/plans/ 디렉터리 없음"
```
- **정상 설계라면 이 상황은 발생하지 않는다** — preflight 가 plan 실재를 선-단언하고 `--worktree current` 라 plan 이 보인다.
- 발생했다면 = `--worktree current` 가 예상과 다른 곳을 가리켰다는 신호(C13) → **`RPI_SKIP` 금지**. 워커는 `send --type escalation`(⚠️ `orchestration escalation` 명령은 **없다**) 로 코디네이터에 상신하고, 코디네이터가 사용자에게 올린다.
- Closeout 이 `hooks/.log` 의 `PASS\tskip:` 을 카운트해 0 이 아니면 보고한다(**사후 탐지**, §8-D17).

---

### 부록 — 문서 신뢰 등급 표기 규약

| 표기 | 의미 |
|---|---|
| (근거 없음) | 실행 명령 또는 파일:줄 인용 |
| ⚠️ | 스키마/가이드에서 확인 못 한 명령·플래그·형태 |
| `[P2]` | 프로브 전 하드코딩 금지 마커(코드 표면에 남김) |
| **미확인** | 근거 없음 — 추정 금지 |
| **미해소 — 수용 잔여** | 설계상 닫지 못했음을 명시 |

**핵심 자기고지 3건**:
1. 본 조사는 `orca` 를 **0회 실행**했다. §3 의 모든 명령은 문서상 계약이며 런타임 실측이 아니다.
2. C20 지연 최적화 이득은 **주장하지 않는다**(§8-E25). 구조적 논거이지 측정이 아니다.
3. "Orca 워커에서 모델 정책이 봉인된다"고 쓰지 않는다. 정확한 범위는 **Claude 세션=5규칙 / 비-Claude 세션=리터럴 축만(T4 후) / 상속 축=계약(advisory)** 이다.
---

## 부록 Z — Orca 버전 드리프트 (2026-08-13, 본 설계 작성 직후)

본 설계의 Orca 관련 사실은 **1.4.179 시점 캐시**에서 추출됐다. 작성 직후 사용자가 **1.4.181** 로
수동 업데이트했다(업데이트는 하네스 규약상 AI 금지 — `cross-family-review.md:15`).

| 항목 | 상태 |
|---|---|
| `Orca.exe` FileVersion | **1.4.181** (실측, 2026-08-13) |
| `AppData/Local/Temp/orca-schema.json` | 8/10 23:13 — **1.4.179 시점** |
| `AppData/Local/Temp/orca-guides/*.md` | 8/10 22:32 — **1.4.179 시점** |
| `resources/app.asar` | 8/13 07:35 — 신 번들 |

**함의**: §3 실행 흐름·§6 오라클 검사 항목이 인용하는 CLI 계약(228 명령·플래그·NOTE)은
**구버전 근거**다. asar 문자열 검색은 부분적이라(`worker-start` 6건 매치하나 `coordinator-start` 0건)
계약 생존 여부를 이것만으로 판정할 수 없다.

**조치**: §7 Phase 0 프로브를 **1.4.181 에서 재수행**하고, 그 산출을 `docs/ai-context/orca-pins.md`
핀의 기준선으로 삼는다. 설계에 이미 그 핀 장치(seal #52-ⓐ)를 넣어둔 이유가 정확히 이 드리프트다 —
가이드가 CLI 번들에서 나오므로(`skills get` NOTE: "Reads bundled guide content locally") **업그레이드가
계약을 조용히 바꾼다**.

**C21 주축은 이 드리프트의 영향을 받지 않는다** — GAP 정정(`surface-model-policy.sh`)은 하네스 내부
결함이라 Orca 버전과 독립이다.

---

## 11. 2026-08-17 실측 갱신 — §8 미확인 3건 해소 + 반증 2건

C21 머지 직후 사용자 질문("jmode 로 orca 에서 claude 부르면 동작하나")에 답하기 위해 4축 병렬 프로브 + 적대 검증을 돌렸고, 아래가 실측으로 확정됐다. **원문(§0~§10)은 수정하지 않는다** — 아래가 supersede 부기다.

### 11.1 해소 — orchestration 은 이미 도달 가능하다 (§8-A2 · §9-A2)

`orca-data.json` 에 experimental 키가 없어 "활성 여부 미확인"으로 남겼던 항목:

```
$ C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe orchestration run-list --json
{ "id":"a00c89df-…", "ok": true, "result": { "runs":[ { "id":"run_legacy_local", … } ] } }
```

**`ok: true`** — orchestration RPC 가 응답한다. §9-A 의 "Settings > Experimental 에서 육안 확인 필요"는 **불요**로 판정한다(런타임이 이미 받아들인다). 단 `runs` 는 여전히 툼스톤 1건이라 **실행 전례 0** 은 불변.

### 11.2 해소 — orca 는 PATH 에 등록돼 있다 (§3.0 함정① 정밀화)

§3.0 은 `command -v orca → rc=1` 을 근거로 "PATH 에 없다"고 적었다. **이는 이 bash 세션에 한정된 사실이다.**

```
$ powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('PATH','User')" | tr ';' '\n' | grep -i orca
C:\Users\12132\AppData\Local\Programs\orca\resources\bin
```

Windows *사용자* PATH 9번째 항목에 등록돼 있다. 현 셸 PATH 가 Orca 설치(2026-08-10) 이전 스냅샷이라 낡은 것뿐이다 — **새 셸에서는 `orca` 가 그냥 잡힌다.** 절대경로 폴백(`ORCA_CLI_COMMAND`)은 유지하되, 사유는 "미등록"이 아니라 **"세션 PATH 스냅샷 staleness + orca.cmd 의 send/reply 거부"** 로 정정한다.

### 11.3 해소 — `--worktree` 셀렉터 문법 확정 (§8-C13)

`worker-start --help` verbatim:

```
--worktree <selector>  Worktree selector such as id:<repo-id>::<path>, name:<displayName>,
                       branch:<branch>, issue:<number>, path:<path>, or active/current
```

`current` 는 유효한 리터럴이다. 다만 **`repo list` 는 여전히 `orca-lab` 1건뿐**이고 `C:/Users/12132/.claude` 는 미등록 — §9-A1(사용자 액션)은 **유효**하다. 등록 없이 `--worktree current` 가 하네스 repo 를 가리킬 근거는 없다.

### 11.4 ★반증 — "모드팩은 100% 네이티브 Claude 경로" 는 틀렸다

§0.3 계열 서술이 `claude` 를 "네이티브 Anthropic" 으로 전제했으나, **프로세스 env 가 이미 프록시를 가리킨다**:

```
$ env | grep -i anthropic
ANTHROPIC_BASE_URL=http://127.0.0.1:8317        ← CCS cliproxy
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5[1m]
ANTHROPIC_CUSTOM_MODEL_OPTION=gpt-5.6-sol
```

즉 `claude --model opus` 는 **CCS(8317) 경유**이고, `claude-ocx` 는 **opencodex(10100) 경유**다. 둘의 차이는 "네이티브 vs 프록시" 가 아니라 **"어느 프록시냐"** 다. 정정된 3층 라우팅:

| 층 | 진입 | 경유 | 도달 모델 |
|---|---|---|---|
| 기본 | `claude` | CCS `127.0.0.1:8317` | Claude 패밀리(별칭 SSOT = settings env) |
| 부분 위임 A | `codex exec` | codex CLI 직결 | GPT (하네스 밖·제어점 있음) |
| 부분 위임 B | `claude-ocx` | opencodex `127.0.0.1:10100` | GPT (하네스 안) |

### 11.5 프록시 healthz 의 거짓 음성 (운영 주의)

`curl --max-time 5 …/healthz` 1차 호출이 **rc=28(timeout)** 로 실패했다가 재시도에서 200 을 냈다. TCP 연결은 성립(`Connected to 127.0.0.1 port 10100`)하고 HTTP 바이트만 0이었다 — 즉 **프록시 사망이 아니라 일시 지연**이다(uptime 실측 557,163s ≈ 6.45일 무중단). `bin/claude-ocx:12` 의 healthz 가드가 이 창에서 **거짓 사망 판정**을 낼 수 있다. 재시도 1회를 두는 것이 옳으나, 이번 사이클 범위 밖 → **차기 후보**로 이월.

### 11.6 불변 — 미착륙 자산 (§9 시나리오의 전제)

| 자산 | 상태 |
|---|---|
| `skills/orca-rpi-cycle` | **부재** |
| `bin/orca-rpi.sh` (캐리어) | **부재** |
| `start-rpi-cycle` Phase I 옵션 (e) | **부재** (SKILL.md 내 orca 언급 0건) |
| `modes/orca-rpi-implement.json` + `setup/lib/modepack-oracle.sh` | 실재하나 **§4-4 폐기 대상** |

**결론: Orca 오케스트레이션은 "설계 완료 · 배선 미착륙"이다.** 런타임(11.1)과 문법(11.3)이 확인됐으므로 남은 것은 캐리어 구현 + repo 등록 1회다.

### 11.7 훅 상속의 정확한 경계 — "그대로 따라간다"는 과장이다 (§0.1 반증 1 정밀화)

§0.1 은 규범(L1)·훅(L2)이 프로세스 경계를 넘는다고 적었고 그 자체는 옳다. **그러나 "하네스가 그대로 적용된다"는 서술은 과장**이다 — 실측 판정은 **PARTIAL** 이며 경계가 셋 있다.

**⊕ 실제로 강제되는 것** (부모와 무관한 cwd·비-git·로컬 `.claude` 부재에서 실측):
- SessionStart·PostToolUse·SessionEnd 훅이 자식 `claude` 에서 **새 runlog 엔트리를 남긴다**
- PreToolUse RPI 게이트는 **발화만이 아니라 차단까지 한다** — active plan 없는 곳에서 코드파일 셸-쓰기 시도가 `enforce-rpi-bash.sh` exit 2 로 막혔고 파일은 생성되지 않았다
- 워크트리 per-worker 에서도 plan 경로 해석이 깨지지 않는다(`resolve_project_root` 가 `git rev-parse --show-toplevel` 로 워커 자신의 워크트리 루트에 앵커)

**⊖ 구조적으로 미발화하는 것**:
- `surface-model-policy.sh` 의 matcher 는 **`Agent|Workflow` 한정**(실측). Orca 가 자식 claude 에게 단발 `-p` 태스크만 던지고 그 자식이 서브에이전트를 스폰하지 않으면 **모델 정책은 한 번도 발화하지 않는다**. 프로브 2회(Bash 만 사용) 모두 이 훅 엔트리 0건.
  → 즉 **"Orca 워커에도 모델 정책이 적용된다"는 조건부**다: 워커가 Agent/Workflow 를 쓸 때만.

**⊘ 관측 불가**:
- **Orca 경유 세션을 runlog 에서 판별할 수단이 없다.** 하네스 훅 전수에 Orca 식별자(`ORCA_*`) 참조 **0건**, runlog 스키마에 실행-주체 필드 없음. Orca shim 은 자기 로컬 서버로 POST 할 뿐 하네스 runlog 에 태깅하지 않는다 — **두 관측 계통이 분리**돼 있다.
- 대체 판별자인 `session_id` 도 **채움률 8.6%**(9,617행 중 827) — `export RL_SID` 를 하는 훅이 `enforce-rpi-cycle`·`enforce-rpi-bash` 둘뿐이라 나머지는 빈 문자열이다.
  → §9 시나리오의 "Orca 로 돌린 사이클의 게이트 발화를 사후 확인" 은 **현 계측으로 불가**. 캐리어 착륙 시 SID 배선 통일이 선행돼야 한다.

**⚠ per-worker 워크트리의 함의(INFERRED)**: plan 은 git-tracked 라 워크트리 체크아웃에 따라오지만, **메인에서 갓 작성하고 커밋 안 한 plan 은 워커 워크트리에 부재**해 그 워커가 `no-active-plan` 으로 차단된다. **plan 커밋이 워커 스폰의 선행조건**이다.

### 11.8 CCS 티어 접힘 — 우려는 실측으로 반증됨

교차검증이 「CCS 별칭이 sonnet/haiku 를 전부 opus 로 접으므로 오라클의 티어 판정이 실 라우팅과 무관해진다」고 제기했다. 근거는 `~/.ccs/claude.settings.json` 선언이다:

```
"ANTHROPIC_DEFAULT_OPUS_MODEL":  "claude-opus-5[1m]"
"ANTHROPIC_DEFAULT_SONNET_MODEL":"claude-opus-5[1m]"    ← 접힘
"ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-opus-5[1m]"    ← 접힘
```

**그러나 실효값은 라이브 프로세스 env 이고, 거기서는 티어가 보존된다**:

```
$ env | grep ANTHROPIC_DEFAULT
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5[1m]
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5[1m]      ← 접히지 않음
ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5-20251001 ← 접히지 않음
ANTHROPIC_DEFAULT_FABLE_MODEL=claude-fable-5[1m]
```

E2E 실측(자식 프로세스):
```
$ claude --model haiku -p "Output ONLY your exact model id string" --output-format json
modelUsage: claude-haiku-4-5-20251001
result:     claude-haiku-4-5-20251001
```

→ **접힘 없음. 하네스 모델 정책의 티어 판정은 실 라우팅과 정합한다.** 단 이것은 *현 세션 env 가 실효*라는 조건 위에 서 있으므로, **CCS 파일 선언이 실효가 되는 경로(예: env 없이 새로 뜬 셸)에서는 접힘이 성립할 수 있다** — 미측정. 워커가 env 를 상속하지 않는 경로가 생기면 재측정 대상.

### 11.9 C22 재감사 spec delta (2026-08-17) — 교차패밀리 2슬롯 + 내부 통합 리뷰 산출

> T1~T3 착륙물을 실측 CLI `--help` · 가이드 · preamble 원문에 대조한 재감사에서 나온 **in-place 개정**
> (CLAUDE.md §5 — 하네스 자신의 아키텍처 결정은 durable spec in-place 개정으로 기록).
> 아래 항목은 §3·§5·§6·§7 의 해당 문장을 **supersede** 한다.

**① §6.1 검사항목 ⓐ·ⓒ·ⓕ 판정 기준 정정 — "리터럴 0" → "발행 0"**
AS-IS 는 `--model`/`--effort` **출현** 0 · `new-child|new-top-level` **리터럴 부재**(§6.3-ⓒ) · `orca.cmd` **리터럴** 0 을 요구한다.
그런데 이 불변식들을 *코드로 강제*하려면 거부 arm 이 자기가 거부하는 토큰을 이름으로 불러야 한다 —
AS-IS 기준은 **거부 코드 자신을 위반으로 만드는 자기반박 오라클**이다(캐리어의 `--model` 거부 arm ·
`assert_worktree_arg` 의 `new-child` arm · `.cmd` 금지 근거 주석이 전부 걸린다).
TO-BE: ⓐ `"$ORCA"` **호출 라인의 인자 벡터**에 `--model`/`--effort` 가 실리는 경로 **0**(거부 arm·주석 허용)
· ⓒ `--worktree` **값으로** `new-child|new-top-level` 이 전달되는 경로 **0** · ⓕ `$ORCA` 가 `.cmd` 로 해소된 채
발행되는 경로 **0**(런타임 assert 로 강제). §6.3-ⓒ 의 부정-단언도 "전달 경로 부재"로 같이 정정.
T6 오라클(`setup/lib/orca-carrier-oracle.sh`)은 이 기준으로 구현한다.

**② §3.4 `check --types` 에 `decision_gate` 추가 (BLOCKER 급 정정)**
AS-IS 의 `--types worker_done,escalation,question` 은 가이드의 canonical 예시를 그대로 베낀 것이다.
그러나 워커 preamble RULE#1 verbatim 이 `send --type decision_gate` 를 **허용 채널로 명시 지시**하고,
가이드 :151 이 `decision_gate` 를 유효 타입으로 열거한다 → wake 목록에서 빠지면 **워커 영구 hang**.
T3 가 막으려던 실패 모드가 T1 의 기본값에 그대로 남아 있었다. 기본값 = `worker_done,escalation,question,decision_gate`.

**③ §9-A1 stale 정정** — `.claude` repo **미등록**을 전제한 선행조건 문장은 무효.
P0 프로브 실측(`repo list` → `orca-lab` + `.claude` 2건)으로 **등록 완료**. §11.3 과 정합.

**④ P0-2 판정 정밀화 — 미측정 잔여는 3 이 아니라 4**
§7 의 "P0-2 필드 경로 표 확정" 합격 문구는 `check` 의 **delivery id** 를 가렸다.
미측정 = ⓐdispatch id ⓑgate id ⓒ**delivery id** ⓓ`worker.agent_terminal_handle`.
delivery id 는 `--ack` 규율의 핵심 식별자다(ack 전까지 같은 Delivery 무한 재생) → 캐리어의 `# [P2]` 는 이 **4곳**.
따라서 P0 게이트는 "확정 통과"가 아니라 **"4건 선언 잔여를 안고 통과"** 로 읽어야 정직하다.

**⑤ §5.3 `--worktree current` 의 브랜치 부작용 — 신규 불변식**
실측: `worktree.isMainWorktree = true` · `worktree.branch = refs/heads/master`.
즉 `current` 로 띄운 **non-readonly 워커는 머지 대상 브랜치에 직접 커밋**한다 → 사람의 머지 승인이
사후 무력화된다(거절해도 이미 착륙). plan 가시성을 위해 `current` 를 고정한 결정은 유지하되,
**추가 불변식**: non-readonly 워커 스폰 전 코디네이터는 현재 브랜치가 `master|main` 이 **아님**을 단언한다
(T2 Phase 0 브랜치 가드). read-only 팬아웃은 이 제약과 무관.

**⑥ §2 "규범 재전송 금지" 의 반대 방향 공백 — 계약 문서는 자동 상속되지 않는다**
`docs/ai-context/orca-worker-contract.md` 는 `CLAUDE.md` 같은 자동 로드 특수 파일이 **아니며**, 그것을
워커에 주입하는 단계가 설계 어디에도 없었다. Task spec 이 **명시적으로 읽기를 지시**하지 않으면 T3 전체가
사문이다. → T2 템플릿 4종의 **첫 지시**로 절대경로 읽기를 편입한다.

**⑦ §4.1 층1 호출은 Task spec 이 명령해야 한다 — T2 템플릿에 부재였다**
워커 셸은 오케스트레이션 사무용(sonnet 상속)이므로, 템플릿이 `Agent(explore-strict|execute-strict|review-strict)`
· `Workflow(rpi-implement.js)` 를 **명령**하지 않으면 실제 추론이 사무용 셸에서 일어나 역할×모델 매트릭스의
발화 지점을 통째로 우회한다. 4종 템플릿에 층1 호출을 명시한다.

**⑧ §3.6 `--readonly` 는 강제가 아니라 선언 (overclaim 정정)**
캐리어는 `--readonly` 를 Orca 에 전달하지 않고, Orca 는 read-only 샌드박스·권한 제한·task 내용 검증을
제공하지 않는다. `--readonly` 는 **캐리어 로컬 카운터를 우회하는 코디네이터의 자기-선언**이다.
"read-only 팬아웃만이 유일한 병렬 축"은 *강제된 사실*이 아니라 *지켜야 할 규율*이며, 안전은 Task spec 이
실제로 read-only 인지에 달려 있다(하네스 선례: opencode capstone 3-계층 정직공개).

**⑨ §7 T1 의 `install.sh REQUIRED 등재` — 선언적 이월**
사용자 goal 이 T1 을 서브커맨드·불변식·TDD ⓐ~ⓓ 로 한정했고 `install.sh`(T17)를 범위 밖으로 명시했다.
무선언 누락이 아니라 **선언된 잔여** — 차기 사이클에 T17 과 같은 커밋으로 착륙한다.
(이번 사이클은 `git update-index --chmod=+x` 로 **실행 비트 커밋**만 이행 — `core.filemode=false` 라
작업 트리 권한이 인덱스에 반영되지 않던 결함을 닫았다.)

**⑩ §11.7 근거 강도 정직 부기**
워커 트랜스크립트 기반 상속 결론은 **실제 dispatched worker 기동 0회** 위에 서 있다(P0-4 는 `--dry-run`).
`worker-start` 실 경로에서 env 상속·훅 발화가 동일하다는 보장은 아직 없다 — 실 워커 기동 후 재측정 대상.

### 11.10 C23 설계 결정 (2026-08-17 — 캐리어 자기-적용 · 부작용 경계의 코드화)

> C22 착륙물을 **C23 자신에게 처음 적용**하면서 나온 in-place 개정(CLAUDE.md §5).
> 아래는 §3·§4.3·§6·§7·§9(시나리오 2)·§11.9 의 해당 문장을 **supersede** 한다.
> 신뢰 등급 표기는 부록 규약을 따른다.
> **개정 이력 — 이 절의 게이트 회차·발견 수 SSOT**(다른 절은 이 목록을 *참조*만 하고 숫자를 재기술하지
> 않는다. 재기술이 곧 content-drift 라는 것을 ⑧ 서술이 실제로 재발시켰다 — 델타 재심 4):
> - 초안 → **Gate R** FAIL · 실발견 **10**
> - 1차 정정 → **델타 재심 1** FAIL · **7**(차단 3 · 인용 재현 실패 1 · 미표면 3)
> - 2차 정정 → **델타 재심 2** FAIL · **7**(미해소 1 · 신규 3 · 인용 재현 실패 3)
> - 3차 정정 → **델타 재심 3** FAIL · **2**(인용 재현 실패 1 · 신규 1)
> - 4차 정정 → **델타 재심 4** FAIL · **4**(절-내 계수 모순 1 · 픽스처 전제 미명시 3)
> - 5차 정정 → **델타 재심 5** PASS · **0** (Gate R 종결)
> - 6차 정정 → **교차패밀리 슬롯 1**(GPT `gpt-5.6-sol`·ultra, Gate P 델타 재심 PASS 직후) ·
>   제기 **33** → 트리아지 **채택 30 / 기각 3**
> - 7차 정정 → **정정문 자기-검증**(Phase I 착수 전) · **1** — ③의 `LIVE-INTENT` 창 보정이
>   슬롯 1 B5 의 *실제* 시나리오를 닫지 못했다(언급이 호출보다 **앞** 11줄이면 새 창도 통과한다).
>   판별식을 거리 축에서 **줄-형태** 축으로 옮긴다 → **이 판본**
> 게이트 5회가 잡은 것은 전부 *자기-전제 미실측* 클래스였고(⑧), 그중 **3건은 교정문 자신이 교정 중인
> 클래스를 재발**시킨 것이었다: 계수 오류 · 「rc=0 단언이 앞선 가드를 무시」 · **계수 SSOT 이중화**.
> ★**게이트 회차와 교차패밀리 슬롯은 다른 층이다** — 위 「게이트 5회」는 Gate R 축(1차 + 델타 재심 4)의
> *정정을 낳은* 회차 수이고, 델타 재심 5(0건 PASS)와 슬롯 1 은 그 계수에 들어가지 않는다. `review-yield.md`
> 표기 규약(PASS 수 + FAIL 수 = ×N, PASS 회차 산입)에 따르면 델타 재심 축은 **×5 · 1 PASS/4 FAIL** 이다.
> **슬롯 1 이 게이트 5회보다 많은 결함을 낸 것 자체가 이 사이클의 층-수율 관측**이며 §18.1 트리거 (a)의
> 입력이다(⑨ 참조).

**① 브랜치 가드 — 지시문에서 코드로 (§11.9 ⑤ supersede)**
§11.9 ⑤ 는 신규 불변식을 세우면서 그 강제를 **T2 SKILL.md 의 Phase 0 지시문**에 두었다.
실측(2026-08-17): `grep -icE 'branch|브랜치' bin/orca-rpi.sh` → **0건**. ★원 goal 문서와 초안이 쓴
`grep -i "branch|브랜치"` 는 `-E` 가 없어 리터럴 `branch|브랜치` 를 찾는 **vacuous 명령**이었다 —
결론(0건)은 `-E` 재실행으로 재현됐지만, 부작용-차단을 봉인하는 사이클이 vacuous 검사 기록을 남기는 것
자체가 같은 클래스라 여기 정정해 둔다.
따라서 캐리어에는 브랜치 축의 코드가 **한 줄도 없다**(실측). 「직접 호출하면 master 에서도 `spawn` 이
rc=0 을 낸다」는 **추론**이다(가드 부재에서 따라오는 예상 동작 — 라이브 스폰으로 확인한 바 없고,
확인하려면 되돌릴 수 없는 dispatch 를 만들어야 한다).
이 상태는 이 설계의 자기 원칙(「방어는 문서가 아니라 스크립트 거부여야 한다」 §3.6)과 정면 충돌하며,
C22 가 스스로 발견한 실패 클래스(**경고를 쓴 쪽이 경고 대상을 구현하지 않음** — `decision_gate` 누락)와
동형이다. TO-BE: `spawn`(non-readonly) **및 `handoff`** 가 워커가 실제로 뜨는 워크트리의 브랜치를 읽어
`master|main` 이면 rc≠0 + 사유로 거부한다.

- **`handoff` 포함이 필수인 이유**: `handoff` 는 `--readonly` 를 받지 않아 **정의상 non-readonly** 다
  (실측 — `bin/orca-rpi.sh:312-319` 의 인자 case 블록 아암이 `--task`(313) · `--dispatch`(314) ·
  `--prev-task`(316) · `--run`(317) · `*) die`(318) 뿐). 그리고 R→P→I→C 체인에서 **4개 Phase 중 3개**가
  이 경로로 뜬다(실측 — `skills/orca-rpi-cycle/SKILL.md:134` 이 Phase R 의 `spawn`,
  `:142`·`:143`·`:144` 가 Phase P/I/C 의 `handoff`). `spawn` 만 막으면 §11.9 의 BLOCKER 였던
  「`cmd_handoff` 가 원장을 읽지도 쓰지도 않아 실사이클 경로 3/4 에서 불변식 미발화」와 **같은 클래스**가 재발한다.
- **측정 대상**: 코디네이터의 `cwd` 가 아니라 **워커가 뜨는 워크트리**다. `--worktree` 값이 `current` 면
  `$WT_SEL` / `$RUNDIR/wt_sel`(preflight 가 실측 기록)에서, 셀렉터 리터럴이면 그 값에서 셀렉터의 path 부분을
  취해 `git -C <path> rev-parse --abbrev-ref HEAD` 로 읽는다. cwd 를 재면 코디네이터가 다른 디렉터리에서
  호출할 때 **오탐·미탐이 양방향으로** 난다. 셀렉터 미획득 시에만 `$PWD` 로 폴백한다(문서화된 폴백).
- **★환경 위생 — `GIT_DIR`/`GIT_WORK_TREE` 제거 후 판정(슬롯 1 B1, 실측)**: `git -C <path>` 는 cwd 만 바꾸고
  **저장소 결정은 ambient `GIT_DIR` 이 이긴다**. 임시 repo 2개로 실측: repoA(=`master`)를 가리켜도
  `GIT_DIR=<repoB>/.git git -C <repoA> rev-parse --abbrev-ref HEAD` → **`feature-x` rc=0**. 가드 함수를
  verbatim 추출해 end-to-end 로 돌린 결과도 같다 — 정상 경로는 `거부: …머지 대상 브랜치('master')` rc=1,
  `GIT_DIR` 주입 시 **무음 rc=0**(fail-open). 따라서 브랜치 판정 호출은 반드시
  `env -u GIT_DIR -u GIT_WORK_TREE git -C <path> rev-parse …` 형태로 한다(실측으로 `master` 복원 확인).
  이 하네스의 위협 모델은 적대적 사용자가 아니라 **우발 오염**이지만, 닫는 비용이 1줄이고 열어 두면
  「가드가 무음으로 통과」라 관측조차 안 된다.
- **판정 불가는 fail-closed**: 브랜치를 읽지 못하면 거부한다. 「사이클은 절대 멈추지 않는다」는 fail-open 약속은
  **Orca 가용성 축**(preflight rc=3)의 것이지 안전 가드의 것이 아니다 — 동시-1 상한·`--model` 거부와 동일 처분.
- **detached HEAD**(`HEAD`)는 허용 — 머지 대상 브랜치에 커밋할 수 없다.
- **정직한 상한(overclaim 금지)**: 코드가 막는 것은 *선언되지 않은* non-readonly 스폰이다. `--readonly` 는
  §11.9 ⑧ 대로 **자기-선언**이므로, read-only 로 오선언한 편집 Task 는 이 가드도 원장 상한도 통과한다.
  "브랜치를 봉인했다"는 서술은 거짓이며, 정확한 표현은 **"선언된 non-readonly 경로를 봉인했고 오선언은
  §11.9 ⑧ 의 상한을 상속한다"** 이다.
- **★선언된 잔여 — `handoff` 의 측정 객체 불일치(슬롯 1 A1)**: `handoff` 가 재사용하는 terminal 은
  **dispatch 소유**인데(실측 `bin/orca-rpi.sh:325` 가 `worker-show --dispatch` 로 얻은 handle 을 `:345` 에서
  재사용), 가드가 읽는 것은 `wt_sel` 이다. `spawn` 과 `handoff` 사이에 `wt_sel` 이 갈리면
  (`preflight` 가 매 실행 `:118` 에서 덮어쓴다) 가드는 **실제 워커가 뜰 워크트리가 아닌 곳**을 판정한다.
  이번 사이클에 닫지 못하는 이유는 dispatch→워크트리 바인딩이 `[P2]` 미측정(⑤)이기 때문이다 —
  **모르는 응답 경로를 추정으로 코드화하지 않는다.** Phase I 의 `jq paths` 전수 출력에 워크트리 필드가
  나오면 차기 사이클에 상향한다. 그 전까지 `handoff` 가드는 **`wt_sel` 축의 근사**임을 여기 명시한다.

**② `ORCA_RPI_DRYRUN` — 검증-전용 경로 (신규 불변식)**
`ORCA_RPI_DRYRUN=1` 이면 캐리어는 인자 검증·가드를 전부 수행한 뒤 **부작용 경계 직전에 정지**한다:
명령줄을 `DRYRUN: <argv>` 1줄로 stdout 에 내고 rc=0 으로 종료한다. 근거 = non-obvious #5 Why-2
(「이 캐리어에는 인자 검증만 하고 멈추는 모드가 없다 — 파싱과 부작용 발행이 한 프로세스에 직렬로 붙어 있어,
파싱을 검증하려면 부작용 경계까지 실행하는 것 외에 방법이 없다」). 처방을 "호출자가 매번 stub 을 주입하라"
한쪽으로만 두지 않는 **설계-층 대응**이다.

- **불변식 문면(정밀화)**: 「**외부 프로세스를 실제로 기동하는 서브커맨드**는 예외 없이 DRYRUN 을 존중한다.」
  초안의 「전 서브커맨드」는 실물과 양립 불가였다(델타 재심 1 B2) — `selfcheck` 는 `$ORCA` 를 **기동하지 않고**
  `case "$ORCA" in`(`:465`) · `[ -x "$ORCA" ]` / `command -v "$ORCA"`(`:469`) 로 *조회만* 하는 진단
  커맨드라 DRYRUN 정지 대상이 아니다. 이것은 예외 목록이 아니라 **성질에 의한 분할**이다.
- **★`DRYRUN: <argv>` 는 *완전한* argv 다(슬롯 1 B2·D1, 실측)**: 정지점보다 **뒤에서** 조립되는 선택 인자는
  출력에 영영 들어가지 못한다. 실물에서 그런 인자가 둘 있다 — `cmd_wait` 의 `--ack`(조립 `:264-265`)와
  ④가 신설할 `cmd_run` 의 `--retry-request`(조립 자리 `:149` 직전). 따라서 **선택 인자 배열 조립은
  정지점 앞으로 올리고 `dryrun_emit` 에 전달한다**(배열 조립은 부작용이 아니다 — `cmd_task`·`cmd_spawn` 이
  이미 그 형태다). 이 규정이 없으면 「인자 파싱을 검증한다」는 ②의 존재 이유가 바로 그 인자에서 무너진다.
  ★**「완전」은 리터럴 상수까지다(C23 Phase I 실측)**: 위 문면은 *후-조립 선택 인자*만 다루었는데, 실물에는
  **정지점 앞에 이미 리터럴로 존재하는데 emit 에서 빠진** 인자가 있었다 — `cmd_gpt verifier` 의
  `-c model_reasoning_effort=ultra -c model_verbosity=high`, `cmd_gpt executor` 의 `OCX_MODEL=` env 접두와
  `$HOME/.claude/bin/` 절대경로. 조립 순서 문제가 아니라 **emit 문자열을 손으로 적었기 때문**에 난 누락이라
  ②의 정지-지점 규정으로는 잡히지 않았고, ③의 검사자도 줄 수만 세므로 침묵했다. 계약을 「실호출 줄과
  **동일한 토큰열**」로 못 박는다 — 리뷰어가 DRYRUN 출력만 보고 「무엇이 돌 것인가」를
  판정할 수 있어야 하는데, 부분집합 argv 는 그 판정을 조용히 틀리게 한다.
  **예외는 `preflight` 하나**다 — 6-call 시퀀스라 단일 argv 가 원리적으로 성립하지 않는다. 그래서 그
  emit 은 문자열 안에 `(요약 — 단일 argv 불성립)` 을 박아 **완전-argv 계약의 대상이 아님을 자기-표시**한다
  (묵시적 예외 금지 — 표시가 없으면 다음 독자가 부분집합 argv 로 오해한다).
- **정지 지점의 순서**: `main()` 의 실행자 존재 단언(`assert_orca_exe` — 실측 `bin/orca-rpi.sh:486` 이
  `selfcheck|gpt` 외 전부에 건다) **보다 앞에** DRYRUN 판정이 온다 → 인자 파싱 → 금지 플래그 · 워크트리 ·
  브랜치 가드 → **DRYRUN 정지** → 원장/설정 쓰기 → 외부 호출.
  `assert_orca_exe` 를 건너뛰는 이유: 검증-전용 경로는 외부 프로세스를 **부르지 않으므로** 그 실행자의
  존재를 요구할 근거가 없고, Orca 미설치 머신에서도 인자·가드를 시험할 수 있어야 한다 — `:486` 이 `gpt` 를
  「Orca 미설치 머신에서도 가용해야 한다」는 같은 이유로 이미 면제하고 있다(선례 동형). 이 순서 선언이
  없으면 아래 검사 지점 ⓒ 가 rc=1 로 결정적으로 깨진다(델타 재심 2 신규 결함 1).
  이 순서의 귀결로 **로컬 원장도 오염시키지 않는다**. 근거 = 실측 — C22 의 stub 검증이 라이브
  `$HOME/.claude/.orca-rpi` 에 직접 써서 `active-nonreadonly.tasks` 에 `t1` 이 잔존했고(C23 Phase R 실측),
  그대로 두면 **C23 의 첫 실 spawn 이 상한 초과로 거부**된다.
- **이 불변식의 검사 지점**(§11.9 ① 이 세운 「불변식에는 코드 검사자를 배정한다」 선례 이행):
  신설 `setup/tests/orca-carrier.test.sh`(verify-all STAGE 2e — 2b/2c/2d 선례와 정합)가 다음을 **코드에서
  유도**한다.
  ⓐ 서브커맨드 목록 = `^cmd_[a-z]*()` 함수 정의 전수(실측 10개: `preflight run task spawn wait handoff
  release gate gpt selfcheck`). `main()` 의 `case "$cmd" in` 은 **2개**라(실측 `:486` 가드용 · `:487` 디스패치)
  앵커로 모호하므로 쓰지 않는다.
  ⓑ 각 함수 본문에서 `"$ORCA"` / `orca_t` / `claude-ocx` / `codex` 가 **커맨드 위치**에 등장하는지로
  「외부 기동 여부」를 판정한다(`command -v "$ORCA"` · `[ -x "$ORCA" ]` · `case "$ORCA" in` 은 첫 토큰이
  달라 기동이 아니다 — ③의 커맨드-위치 앵커와 같은 판별식). 현 실측 분할: **기동군 9**(preflight `orca_t`
  `:110` / run `:149` / task `:178` / spawn `:218` / wait `:271` / handoff `:325`·`:345` / release `:370` /
  gate `:407`·`:419`·`:423` / gpt `claude-ocx` `:446`·`codex` `:451`) · **비-기동 1**(selfcheck). 모호 0.
  ★**계수 단위는 함수가 아니라 기동 아암이다(슬롯 1 A2)**: 위 실측이 이미 보여 주듯 `gate` 는 3아암
  (`create`/`resolve`/`list`), `gpt` 는 2아암(`claude-ocx` executor · `codex` verifier)이고 DRYRUN 정지도
  **아암마다** 들어간다. 검사자가 서브커맨드당 1샘플만 돌리면 `gate resolve`·`gpt executor` 의 정지점을
  지워도 스위트가 GREEN 을 유지한다 — 이 하네스가 [[판별력 공백]]이라 부르는 바로 그 클래스다. 따라서
  검사 입력은 **아암 단위로 전수**(기동 아암 12: preflight 1 · run 1 · task 1 · spawn 1 · wait 1 ·
  handoff 2 · release 1 · gate 3 · gpt 2 — handoff 의 두 호출은 한 실행 경로라 1 입력으로 덮인다)여야 한다.
  ※ 이 절에서 「12」는 **기동 아암 수**이지 스위트 총 단언 수가 아니다 — 검사자에는 비-기동
  `selfcheck` 1 아암(ⓓ 분기) · ⓕ 가드-거부 · ⓖ 실패-분기 · ⓗ 원장 단언 · 픽스처 준비분이 더해진다.
  **총 단언 수의 SSOT 는 이 각주가 아니라 plan Task 5 의 계수표**다(현행 20) — 여기서 세지 않는다.
  ⓒ 기동군은 `ORCA_RPI_DRYRUN=1` + **존재하지 않는** `ORCA_CLI_COMMAND` 로 실행해 **rc=0 · stdout
  `DRYRUN:` 1줄 · 임시 `ORCA_RPI_RUNDIR` 아래 파일 생성 0건**(원장 무오염 — ②의 핵심 가치)을 단언한다.
  존재하지 않는 실행자에서도 rc=0 인 것은 위 「정지 지점의 순서」가 `assert_orca_exe` 를 DRYRUN 뒤로
  미루기 때문이며, **이 단언이 곧 그 순서의 회귀 탐지자**다.
  ★**총 출력 줄 수도 1 이어야 한다(슬롯 1 C1)**: `DRYRUN:` 접두 줄만 세면, 정지점보다 **앞에서** 외부
  프로세스를 부르는 오배치가 통과한다 — 캐리어에 `set -e` 가 없어(실측 `bin/orca-rpi.sh:9` 는 `set -u` 뿐)
  실패한 선행 명령의 rc 를 뒤의 `exit 0` 이 덮기 때문이다. 8/9 서브커맨드는 `ensure_rundir` 의
  `touch`(`:30`)가 rundir 델타를 만들어 *우연히* 걸리지만, **`cmd_gpt` 는 rundir 를 아예 참조하지 않아
  (실측 `:429-460` 에 `RUNDIR` 0건) 그 우연이 없다** — 거기서는 실 `codex`/`claude-ocx` 를 때리면서
  스위트가 GREEN 이 된다. 방어를 우연에 맡기지 않으려면 `2>&1` 로 합친 총 줄 수 == 1 을 함께 단언한다.
  ★**브랜치 축 고정(필수)**: `spawn`·`handoff` 는 ①의 브랜치 가드를 먼저 통과해야 rc=0 이 성립한다.
  따라서 테스트는 임시 `ORCA_RPI_RUNDIR` 안에 **비-머지-대상 브랜치의 임시 git repo** 를 가리키는
  `wt_sel` 을 심어 두고 실행한다(`handoff` 는 `--worktree` 인자를 아예 받지 않아 `wt_sel` 경로가 유일한
  입력이다 — 실측 `:312-319`). 이 고정이 없으면 **master 체크아웃에서 테스트가 rc=1 로 깨진다**(이 하네스는
  머지 후 master 재검증을 수행한다) — 위 `assert_orca_exe` 충돌과 **브랜치 축의 동형 결함**이며 델타 재심 3 이
  잡았다. 같은 클래스가 두 축에서 나온 것 자체가, 「rc=0 단언은 그 앞의 모든 가드를 통과 조건으로 삼는다」를
  검사 설계의 일반 규칙으로 세워야 한다는 근거다.
  이 픽스처의 **전제 4종을 명시**한다(델타 재심 4 + 슬롯 1 B6 — 미명시는 조용한 false PASS/FAIL 의 입구다):
  ⓘ **env 위생** — `$WT_SEL` 은 `wt_sel` 파일보다 우선하므로(①의 측정 대상 규정 · 실측
  `assert_worktree_arg` `:71` 의 `[ -n "${WT_SEL:-}" ]` 가 `:72` 의 파일 arm 보다 앞) 테스트는
  `env -u WT_SEL` 로 **변수를 제거한 채** 실행해 심어 둔 파일이 권위를 갖게 한다. 빈 값 대입이 아니라
  제거인 이유: 현 idiom(`-n`)에서는 둘이 같지만 미래 가드가 `${WT_SEL+x}` 식이면 빈 값이 이긴다
  (그 실패는 fail-closed 라 시끄럽지만, 애초에 만들지 않는다). 캐리어는 `WT_SEL` 을 `export` 하지 않으므로
  (실측 0건) 유입 경로는 바깥 세션뿐이다. ①의 `GIT_DIR`/`GIT_WORK_TREE` 제거도 같은 항목이다.
  ⓙ **「rundir 파일 생성 0건」은 절대량이 아니라 델타** — 픽스처가 `wt_sel` 을 rundir 안에 심으므로
  실행 *전후* 스냅샷 차이가 0 이어야 한다는 뜻이다(빈 rundir 에서는 두 해석이 일치해 지금까지 구분이
  불필요했다). **스냅샷은 경로 목록이 아니라 경로+내용 cksum** 이다 — 파일 *수*만 비교하면 제자리
  덮어쓰기를 놓친다(`preflight` 는 `wt_sel` 을 바로 그 자리에 쓴다). 심는 `wt_sel` 은 **비-공백 셀렉터**
  여야 한다(`:72` 가 `-s` 를 요구 — 빈 파일이면 파일 arm 이 탈락해 픽스처가 조용히 무력해진다).
  ⓚ **픽스처 자체를 먼저 단언** — 임시 repo 생성이 실패하면 `SKIP` 이 아니라 **FAIL**(전제 미성립을
  침묵시키지 않는다). 또 ①의 fail-closed 때문에 「가드가 거부함」과 「진짜 위반」이 rc 만으로는 구분되지
  않으므로, DRYRUN 단언 **전에** `git -C <임시repo> rev-parse --abbrev-ref HEAD` 가 `master|main` 이
  아님을 먼저 단언한다.
  ⓛ ★**픽스처 repo 는 커밋을 1건 가져야 한다(슬롯 1 B6, 실측)** — `git init` + `checkout -b` 만 한 repo 는
  **unborn branch** 이고, 거기서 `git rev-parse --abbrev-ref HEAD` 는 **stdout 에 `HEAD` 를 내면서 rc=128**
  이다. 귀결이 두 방향으로 나쁘다: ㉠ 전제 단언이 `""|master|main` 아암을 안 물어 **vacuous PASS** 하고
  ㉡ 정작 가드는 같은 명령이 rc≠0 이라 `판정 불가 → fail-closed` 로 거부해 **`spawn`·`handoff` 가 rc=1** 이
  된다(기동 아암 12건 전건 GREEN 도달 불가). 따라서 픽스처는 `commit --allow-empty` 1건을 만들고, 브랜치 판정에는
  `symbolic-ref --short HEAD` 를 쓴다(unborn 에서도 rc=0 으로 이름을 준다).
  ⓓ 비-기동군은 DRYRUN 을 면제하고 대신 **부작용 0**(임시 rundir 아래 생성 0건)만 단언한다.
  ⓔ 인자 표에 없는 신규 서브커맨드는 **FAIL**(fail-closed).
  ★ⓕ **가드의 *거부* 도 상설 단언 대상이다(슬롯 1 B7)**: 위 ⓒ~ⓔ 는 전부 「비-머지 브랜치에서 rc=0」만
  본다. 그러면 ①의 가드 호출을 통째로 지워도 세 단언(rc=0 · `DRYRUN:` 1줄 · 델타 0)이 불변이라
  **스위트가 기동 아암 12건을 전건 GREEN 으로 유지한다** — Task 2 의 RED→GREEN 은 1회성 수동 절차라 어떤 스위트에도 등재되지 않으므로,
  이대로면 불변식 ①만 상설 검사자가 없는 상태가 된다. 따라서 **`master` 브랜치 픽스처를 하나 더 만들어
  `spawn`(non-readonly)·`handoff` 가 rc≠0 + 사유 문자열을 내는지** 단언한다(양성 대조는 비-머지 픽스처가
  이미 담당). ★이 사각은 ⓛ 을 고친 *직후에* 정확히 성립한다 — ⓛ 미수정 상태에서는 테스트가 시끄럽게
  깨져 사각이 가려진다. 두 결함이 서로를 가리는 구조라 **함께** 처분한다.
  ★ⓖ **실패 응답 분기도 검사한다(슬롯 1 C2)**: ④가 신설할 「비-0 응답에서 요청 id 추출 → 정확 복구 명령
  출력 → id 부재 시 경고」 3분기는 DRYRUN 경로가 그 앞에서 `exit 0` 하므로 **한 번도 실행되지 않는다**.
  재료는 이미 있다 — 스위트가 쓰는 stub `$ORCA` 에 **비-0 종료 변형**을 하나 더 두면 된다. 없는 인프라를
  새로 만드는 것이 아니므로 스코프 확대가 아니다.
  ★ⓗ **원장 append 도 검사한다(슬롯 1 C3)**: ⑥의 `gpt` 원장은 DRYRUN 경로에서 함수 호출 전에 멈추므로
  형식(헤더·컬럼 순서·`n/a`)이 한 번도 실측되지 않는다. **비-DRYRUN + stub 실행자 + 임시
  `ORCA_RPI_LEDGER`** 로 1회 돌려 TSV 1행의 필드 수와 `n/a` 처리를 단언한다.
  목록과 분류를 둘 다 코드에서 뽑으므로, 외부 기동을 추가한 신규 서브커맨드는 자동으로 ⓒ 로 분류되어
  게이트를 놓칠 수 없다. 이 배정이 없으면 ① 이 규탄한 「경고를 쓴 쪽이 경고 대상을 구현하지 않음」과 동형이 된다.
- **정직한 상한**: DRYRUN 이 검증하는 것은 인자·금지 플래그·브랜치 가드까지다. **원장 뮤텍스(동시-1 상한)는
  본질적으로 쓰기라 dry 경로로 검증되지 않는다** — 그 축은 stub `$ORCA` + `ORCA_RPI_RUNDIR` 격리 경로가
  계속 담당한다. "DRYRUN 하나로 전부 검증된다"는 서술은 거짓이다. ★같은 이유로 **정지점보다 뒤에 있는
  상태 가드는 dry 경로가 검증하지 않는다** — 실측 예: `cmd_wait` 의 pending-ack 일치 가드(`:257-259`)는
  `require_jq; ensure_rundir`(`:251`) 뒤라 dry 로는 도달하지 않는다(슬롯 1 B2). 이것은 위 「argv 는
  완전해야 한다」와 다른 축이다 — 인자는 출력에 실리지만 상태 가드는 실리지 않는다.
- stdout 계약이 다르다 — 호출자가 `D=$(… spawn …)` 로 받아도 id 형식과 **형태적으로 구분**되어
  조용한 오진행이 나지 않는다.

**③ seal #53 — 부작용-차단 주입 명시 + `LIVE-INTENT` 밸브 (신규 L3 지점)**
non-obvious #5 SMART ①②의 착륙. **구현 지점 = `setup/verify-setup.sh`**, #52 블록(`:638-707`) 직후 ·
#36(README parity 최종 검사 `:709-716`) 앞. 스캐너는 awk 어휘 스캔(#52 선례).

- **코퍼스** = `docs/superpowers/plans/*.md` + `docs/ai-context/*.md`. `skills/` 는 제외한다 — 그쪽 캐리어
  호출은 *지시문*이라 라이브 실행이 목적이고, 증거 블록이 아니다.
- **탐지 범위 = 캐리어 호출 한정(선언된 상한)**. SMART ① 은 「`bin/orca-rpi.sh` 호출 **및 이후
  `docs/ai-context/` 에 등재되는 부작용-CLI 래퍼 목록**」이라 썼는데, 그 **래퍼 레지스트리는 아직 존재하지
  않는다**(실측). 따라서 현 스코프는 SMART ① 의 *현재* 문면과 정확히 일치하며, 레지스트리 신설이 확장
  트리거다. **선언된 미탐 잔여 2종**: ⓐ `"$ORCA" orchestration <변이 서브커맨드>` **직접** 호출
  (예: C22 plan `:660-666` 의 `worker_done` 템플릿 — 다만 그것은 *워커가 발행할* 템플릿이라 코디네이터
  증거 블록이 아니다) ⓑ `bin/claude-ocx` 직접 호출(§4.3 예시 블록). 둘을 덮으려면 orchestration 28개
  서브커맨드의 읽기/변이 분할을 먼저 실측해야 하며 이번 사이클에 그 실측이 없다 — **모르는 분할을 추정으로
  코드화하지 않는다.** 차기 goal 후보.
- **증거 단위 = 문단**(연속 비-공백 줄의 최대 런). 펜스 모델을 쓰지 않는 이유는 실측이다: C22 plan 은 펜스가
  48개인데 **중첩 펜스로 패리티가 깨져** 닫는 펜스를 여는 펜스로 오독했다(프로토타입 오탐 1건 — 그 plan `:666`).
  문단 모델은 패리티-무관이고, 코드블록 직후의 `Expected …` 줄이 같은 문단에 들어와 SMART ② 가 요구한
  `rc=` 탐지자가 **같은 단위 안에서** 성립한다.
- **근접 창 15줄(문단-세탁 차단)**: 문단만으로는 부족하다 — 실측으로 `docs/ai-context/non-obvious.md` 는
  `:216` 부터 **파일 끝(`:302`)까지 공백줄이 0**이라 그 87줄이 단일 문단이고, 그러면 격리 토큰 1개가
  절 전체를 세탁한다(③이 파일 스코프를 기각한 근거인 [[판별력 공백]]의 재발). 따라서 **격리 토큰은 호출 줄
  자신 또는 같은 단위 안에서 그 앞 15줄 이내**에 있어야 인정한다(호출 *뒤*의 토큰은 무효 — 셸 의미상으로도
  뒤에 붙은 env 는 그 호출을 격리하지 않는다).
  ★**`LIVE-INTENT` 는 거리가 아니라 *줄 형태*로 판별한다(슬롯 1 B5 → 7차 정정)**: 초안은 「파일 안
  앞뒤 15줄(단위 무관)」이었고, 6차 정정은 그것을 「같은 단위 또는 앞 15줄」로 좁혔다. **그 좁힘으로는
  부족하다** — 슬롯 1 이 실제로 든 시나리오는 언급이 호출보다 *앞* 11줄이라 새 창도 그대로 통과한다
  (awk 실행으로 `LIVE` 판정 재현, parity 도 1=1 로 통과). 거리로는 *언급*과 *선언*이 구분되지 않는다.
  구분되는 것은 **줄의 형태**다: 실제 선언은 언제나 **자기 줄 전체**를 차지하고(앞뒤 공백·백틱 제외),
  언급은 문장 속에 박힌다(「예시 문자열은 `LIVE-INTENT(…)` 이다」). 따라서 인정 조건은
  ⓐ 그 줄이 공백·백틱을 벗기면 `LIVE-INTENT(<6자 이상>)` **하나만** 남고 ⓑ 호출과 **같은 단위이거나
  그 앞 15줄 이내**다. 이 규칙에서 이 spec 자신의 밸브 *정의* 문장들은 산문 속에 있어 자동으로 0 으로
  세어진다(「사용이지 언급이 아니다」 규칙의 코드-층 이행이며, 그 규칙을 거리로 흉내 내던 것을 폐기한다).
- **호출 판별식**(커맨드-위치 앵커 — cycle-37 install/rsync 선례 동형): 선두 공백 제거 후 첫 문자가 `#` 또는
  백틱이면 실격(산문 인라인 코드 — 실측 오탐 그 plan `:699`) → 명령치환 여는 토큰을 구분자로 치환 →
  공백 및 `;` `&` `|` `(` `)` 로 토큰화 → `bash` / `sh` / `env` / `exec` / `time` 및 `VAR=` 형태를 건너뛴
  (★`env` 는 **자기 옵션까지** 건너뛰어야 한다 — `-u <VAR>` · `-i` · `--`. Phase P 실측에서
  `env -u WT_SEL … bash …/orca-rpi.sh spawn` 형태가 코퍼스에 다수인데 옵션을 안 건너뛰면 첫 실토큰이
  `-u` 가 되어 **호출 전체가 미탐**된다. 반대로 `-` 로 시작하는 토큰을 무조건 건너뛰면 마크다운
  리스트 항목(`- \`…orca-rpi.sh spawn\` 은 …`)이 거짓 FAIL 되므로, 건너뛰기는 `env` 뒤에서만 한다)
  **첫 실토큰**이 `…/orca-rpi.sh` 이고 **다음 토큰**이 부작용 서브커맨드
  (`run` `task` `spawn` `wait` `handoff` `release` `gate` `preflight` `gpt`)일 때만 호출로 판정한다.
  `selfcheck` 는 외부 기동이 없어 제외(②의 성질 분할과 같은 근거). 이 판별식이 실측으로 걸러낸 거짓 FAIL
  클래스 4종: 캐리어 **소스 리스팅 블록**(실측 252줄 — 그 plan `:233-484`, 펜스 포함. 초안의 "400여 줄"과
  1차 정정의 "251줄"은 둘 다 오계수였다 — 251 은 `484-233` 뺄셈값이고 내용만 세면 250 이다. 이 절이 교정
  중인 계수-오류 클래스가 교정문 자신에서 재발했다) · `chmod +x …` ·
  `bash -n …` 및 `grep -c …` · `git add …`.
  ★**따옴표는 토큰 *양끝*에서 벗긴다(슬롯 1 B4, 실측)**: 초안은 `gsub(/^["]+/, "", t)` 로 **선두만** 벗겼다.
  그래서 `bash "$HOME/.claude/bin/orca-rpi.sh" run --objective "[C23] live"` 는 토큰이
  `$HOME/.claude/bin/orca-rpi.sh"` 로 남아 경로 정규식이 탈락하고 **호출 자체가 스캔에 들어오지 않는다**
  (awk 를 추출해 실행 — 출력 0줄. 따옴표 없는 대조군은 정상 `NOISO` 1줄). 미탐 변형이 이것 하나가 아니다:
  `bash "bin/orca-rpi.sh" spawn` · `env -u WT_SEL bash "$HOME/…"` 도 같이 샌다(틸드 형태는 탐지됨).
  이건 고의 우회가 아니라 **관용적 표기**이고 — 이 plan 자신의 Task 5 테스트가 `bash "$CARRIER"` 형태다 —
  탐지자가 통째로 침묵하므로 **`^["'\'']+` 와 `["'\'']+$` 를 모두 제거**한다. 자기-시험 픽스처에도
  따옴표 형태를 1건 추가해 이 회귀를 봉인한다(현 픽스처는 따옴표 없는 1형태뿐이라 못 잡았다).
- **격리 요건**(토큰이 *무엇을* 격리하는지에서 도출 — 임의 개수가 아니다):
  ⓐ `ORCA_RPI_DRYRUN=` → **단독으로 충분**(②의 정지 순서상 외부 호출·원장 양쪽 앞에서 멈춘다).
  ★단 **비어 있지 않은 값**이어야 하고 **주석 줄은 격리원이 될 수 없다**(슬롯 1 A3, 실측). 캐리어의
  술어는 `is_dryrun() { [ -n "${ORCA_RPI_DRYRUN:-}" ]; }` 라 `ORCA_RPI_DRYRUN=`(빈 대입)은 **거짓 = 라이브
  실행**인데, 초안 스캐너는 문자열 존재만 봐 `ISO` 로 분류했다(awk 실행으로 재현). 대조 노동 중 **더 넓은
  세탁 경로**도 나왔다 — `# ORCA_RPI_DRYRUN=1` 처럼 **주석 한 줄**만 앞에 두어도 뒤 호출이 ISO 가 된다
  (토큰 스캔에 주석 필터가 없었다). 탐지자와 런타임 술어가 어긋나면 seal 은 「PASS 하는데 Run 이 생기는」
  최악의 방향으로 틀린다. 따라서 격리 토큰 인정 조건은 **①줄 선두가 `#` 가 아니고 ②`=` 뒤에 비-공백 값이
  1자 이상**이다.
  ★SMART ① 이 함께 적은 `--dry-run` 은 **토큰 집합에서 제외**한다: 당시 캐리어에 검증-전용 경로가 없어
  Orca 자신의 `dispatch --dry-run` 을 염두에 둔 표기였고, 착륙 형태는 env `ORCA_RPI_DRYRUN` 이지 캐리어
  플래그가 아니다(실측 — `grep -nE 'DRYRUN|dry-run' bin/orca-rpi.sh` → 0건). 남겨 두면 *다른 명령의*
  `--dry-run` 이 같은 단위에 있을 때 거짓 격리로 세탁된다. SMART ① 의 요건(차단 토큰 1종 이상)은 그대로
  충족되며 바뀐 것은 토큰의 *이름*뿐이다.
  ⓑ `ORCA_CLI_COMMAND=` → 외부 프로세스만 바꾸고 로컬 원장은 라이브에 쓰므로 **`ORCA_RPI_RUNDIR=` 동반 필수**
  ⓒ 둘 다 없으면 FAIL.
  SMART ① 의 최소 요건(차단 토큰 1종 이상)을 **상위집합으로** 만족하며, 초과분 ⓑ의 근거는 ②의 `t1` 실측이다
  (로컬 원장 오염이 관측된 실제 손해였다).
- **`LIVE-INTENT(<사유>)` 밸브**: 응답 shape 측정처럼 라이브가 **목적**인 단위는 이 선언으로 면제된다.
  판별자는 결과가 아니라 **선언의 존재**다(CONTEXT.md [[의도-라이브 / 사고-라이브]]) — 실패 모드였던 것은
  라이브 도달 자체가 아니라 **침묵**이다. 형식 요건: 괄호 안 사유가 6자 이상(공란 사유 불가).
- **`LIVE-INTENT` 비대칭 보정 — 코드로 *표면화*한다(강제가 아니다).** RPI_SKIP 은 *사용자*가 명시하고
  DOWNGRADE-DECLARED 는 Gate P 가 검토하는데 `LIVE-INTENT` 는 **검사 대상을 쓰는 동일 주체의 자기-면제**다.
  초안은 보정을 Closeout `layer-yield:` 와 Gate P 지시문에만 두었는데 그것은 ⑧ 이 실증한 **미착륙 클래스에
  그대로 노출**된다(델타 재심 1 부족 3). 따라서 **파일-내 총계 parity 를 seal 에 넣는다**: `LIVE-INTENT` 로
  **실제 면제받은 단위**가 k(≥1)개인 파일은 같은 파일 안에 `LIVE-INTENT-총계: k` 를 선언해야 하며
  불일치·부재는 FAIL(#17/#19 의 content-drift parity 선례 동형).
  - **계수 대상은 *사용*이지 *언급*이 아니다**: 캐리어 호출이 없는 단위에 등장하는 `LIVE-INTENT` 문자열
    (예: 이 spec 처럼 밸브를 *정의*하는 문서)은 면제로 쓰이지 않았으므로 0 으로 센다. 이 구분이 없으면
    규칙 착륙 즉시 정의 문서가 자기-FAIL 하고, 그것을 피하려 허위 총계를 적게 된다(델타 재심 2 신규 결함 2).
  - **정직한 상한**: 이 parity 는 **자기-정합 검사**라 같은 커밋에서 총계를 함께 올리면 통과한다.
    잡는 것은 *침묵의* 추가(선언 없이 한 개 더 붙이기)이지 의식적 확장이 아니며, RPI_SKIP 처럼 제2자
    승인을 강제하지는 **못한다**. 지시문 층 보정(Closeout `layer-yield:` 보고 · Gate P criteria)은 그 위에
    얹는 advisory 이고, 그것이 강제선이 아님을 여기 명시한다.
- **기존 코퍼스 처분 — 소급 편집 금지 + 단위 동일성 동결**: 규칙 적용 시 위반 단위 **6건**이 나오며 전부
  `docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md`(`:151` `:211` `:222` `:488` `:494` `:501`)다.
  이들은 **이미 실행된 기록**이라 ⓐ 토큰 소급 삽입 = 실행 내용 왜곡 ⓑ `LIVE-INTENT` 소급 부착 = 사고-라이브를
  의도-라이브로 **허위 재분류** 둘 다 규약 위반이다. 처분 = **1회성 예외 대장**: 그 파일 1개를 seal 안에
  명시 등재한다. **동결 대상은 개수가 아니라 단위 동일성이다** — 초안은 「개수 6 동결」이었는데 그러면 기존
  1건을 고치면서 새 위반 1건을 넣으면 6이 유지돼 **무발화**한다(델타 재심 1 B1 — 초안이 "7 이 되어 잡힌다"고
  사실로 단언한 것은 틀렸다). 따라서 그 파일의 위반 단위들에서 **캐리어 호출 줄**만 뽑아 공백 정규화 후
  정렬·연결한 문자열의 **cksum 을 동결**한다(줄 번호 이동에 불변, 치환에 민감). 그 파일에 새 위반이 생기거나
  기존 위반이 바뀌면 cksum 이 달라져 FAIL 하고, 다른 모든 파일은 자동으로 스코프 안이다(fail-closed 방향).
  - ★**동결값을 굳히기 전에 *줄 수*를 단언한다(슬롯 1 C4, 실측)**: 6단위에서 뽑히는 캐리어 호출 줄은
    **8줄**이다(스캐너 실행으로 확정 — 그 파일 `:154 :212 :213 :214 :225 :491 :496 :504`, cksum
    `3763352650710`). 위생 가드를 「빈 입력 cksum(`42949672950`)이 아닌가」로만 두면, 판별식 결함으로
    8줄 중 1줄이 빠져 7줄만 잡혀도 통과한다(7줄 cksum `310138723635` ≠ 빈 입력 — 실측). 그러면 **누락된
    호출이 신규 위반 검사와 대장 동일성 검사 양쪽에서 영구히 사라지면서** verify-setup 은 91/0 이 된다.
    따라서 가드는 `wc -l` == 8 을 함께 단언한다. 「빈 입력이 아님」은 필요조건일 뿐 충분조건이 아니다.
  - **선언된 잔여(좁음)**: 위반 1건을 격리하면서 **바이트 동일한 텍스트**의 새 위반을 다른 위치에 넣으면
    정렬·연결 결과가 같아 무발화한다. 「줄 번호 이동에 불변」의 직접 귀결이며, 그 불변성이 정상 편집
    (윗부분 줄 추가)에 대한 거짓 FAIL 을 막아 주므로 감수한다. (다만 정렬은 `sort` 이지 `sort -u` 가
    아니라 **다중집합**이 보존되므로, 바이트 동일 줄이 이미 2개 있는 현 코퍼스에서 그중 하나만 격리해도
    발화한다 — 실측 `:154` 와 `:212` 가 바이트 동일. 설계가 우연히 옳은 지점이라 명시해 둔다.)
  - 동시에 그 plan 의 실행 절 머리에 C23 부기 1줄을 넣어 「이 블록들은 seal #53 착륙 전 실행됐고 라이브
    원장에 도달했다(non-obvious #5) — 재실행 시 격리 접두 필수」를 남긴다(왜곡 없는 공개).
- **arm B 철회**(초안 정정): 「펜스 **밖**의 `Expected … rc=0` 줄 + 인라인 캐리어 호출」은
  `docs/superpowers/plans/*.md` 전수에서 **0건**이고, 느슨하게 넓히면 그 plan `:781`(비-부작용 구문검사)을
  거짓 FAIL 한다 — **판별력 0 + 거짓 양성 1**. SMART ② 는 대신 **증거 단위가 문단이라 `Expected … rc=` 줄이
  자동으로 같은 단위에 들어오는 것**으로 이행한다(SMART ② 의 「rc=0 통과-케이스에 주입 지점 없으면 FAIL」을
  rc 값 무관 전건 FAIL 로 **상위집합 흡수** — 요건 회피가 아니다). seal 은 위반 단위 중 `rc=` 를 가진
  **실행-주장 단위 수를 따로 계수·출력**한다(그 수가 0 이면 판별력 공백을 스스로 표면화한다).
- **vacuous 방지**: `TOTAL=0 → FAIL`(#51·#52 선례)은 **채택하지 않는다** — 캐리어 호출이 없는 미래 사이클을
  거짓 FAIL 하기 때문이다(#52 자신이 「양방향으로 부정확」 판정을 받은 seal 이라 그 관례를 무비판 인용하지
  않는다 — `docs/ai-context/c21-slot2-triage.md:35`). 대신 **런타임 조립 자기-시험 픽스처**(ISO 1 + NOISO 1
  **+ 따옴표 감싼 경로 1**)를 매 실행 스캔해 탐지자가 양방향으로 판별함을 증명하고, 실패 시 seal FAIL.
  조립을 런타임으로 하는 이유는 자기-오염 회피다(C21 F1 · seal-regression 뮤테이터 23 선례). 라이브 양성
  대조군도 실재한다(실측): `docs/ai-context/non-obvious.md` #5 의 재현 픽스처(`:276-289` — 그 문단의 시작은
  `:216`)가 **호출 줄 자신**(`:281`·`:283`)에 두 토큰을 다 갖춰 ISO 로 분류된다.
- **seal-regression 뮤테이터 2건 신설** — `assert_seal_fires` 계열 단언 **27 → 29**
  (**뮤테이터-기반 단언 25 → 27**, control 1 + live-immutability 1 은 불변): ⓐ 대장 **밖** plan 에 NOISO
  단위 주입 → RED ⓑ 대장 파일에서 기존 위반 1건에 격리 접두를 붙이고 **텍스트가 다른** 새 위반 1건을 추가
  (**개수 6 유지 = 치환**) → RED. ⓑ 가 「개수가 아니라 동일성」이 load-bearing 함을 실증한다.
  ★**용어 정밀화(슬롯 1 E4 — 발견 자체는 기각, 중의성만 채택)**: 위 「25 → 27」은 *단언 수*이지 뮤테이터
  **ID** 가 아니다. 실측 현행 최대 ID 는 **23**(`setup/tests/seal-regression.test.sh:163`)이고 고유 `mut_*`
  함수도 23개인데, 2개 함수가 각 2회 재사용돼 단언이 25가 된다. 따라서 신규 뮤테이터의 ID 는 **24·25** 가
  옳다. 이 문장이 없으면 다음 독자가 「기존 25개니까 신규는 26·27」로 읽는다(슬롯 1 이 실제로 그렇게 읽었다).
  ★**뮤테이터 ⓑ 는 치환 성공을 스스로 단언한다(슬롯 1 C5)**: 대상 줄의 공백·인자 순서가 미래에 바뀌면
  `perl` 치환이 0건이 되고, 그러면 append 만 남아 **6→7 순증**이 된다. cksum 은 어차피 바뀌므로 테스트는
  계속 PASS 하는데 「개수 유지 치환을 잡는다」는 선언만 조용히 거짓이 된다. 치환 후 결과 문자열을 `grep -q`
  로 확인하고 실패면 뮤테이터가 비-0 을 낸다. (실측 오늘 기준으로는 치환 1건 정상 발생 — NOISO 8줄 유지,
  cksum `3763352650710` → `2987402054692`.)

**④ `--retry-request` — 정확 복구 (§8 잔여 · help 실측 2건)**
`orchestration run-create --help` Notes **verbatim**(실측 2026-08-17): *"--retry-request is only for exact
recovery after an unknown mutation result."* · `worker-start` usage 에 `[--retry-request <id>]`(id 인자)
실재(실측). **`task-create`·`gate-create`·`check` 의 수용 여부는 미확인** — 초안은 "전부가 받는다"고 적었으나
인용 근거는 2개 명령뿐이었다(Gate R 실발견). ★위 2건의 help 원문은 **repo 안에 기록돼 있지 않다**(실측 —
`exact recovery` 문자열이 CONTEXT.md·이 spec 자신 외 0건). 따라서 Phase I 에서 `--help`(read-only · 부작용 0)
재실행분을 `docs/ai-context/c22-orca-probe-measured.md` 에 **원문 append** 해 재현 가능하게 만든다
(§11.10 ⑤ 의 기록 위치 규약).

- [[정확 복구]]는 [[재시도 스폰]](`--retry-of`)과 **다른 축**이다 — 저쪽은 실패한 dispatch 를 대체하는 *새* 시도라
  레코드가 늘고, 이쪽은 같은 mutation 의 멱등 재발행이라 레코드가 1개로 유지된다. `run-delete` / `task-delete` 가
  **부재**한 시스템에서 이 혼동은 곧 되돌릴 수 없는 중복이다.
- 캐리어 배선: ⓐ **실측으로 수용이 확인된 변이 서브커맨드**가 `--retry-request <id>` 를 수용한다(받지 않으면
  코디네이터가 손-호출로 캐리어를 우회해야 하고 그것이 §2 의 경계 상한을 넓힌다) ⓑ 비-0 응답 시 저장된
  응답에서 요청 id 를 뽑아 **정확 복구 명령을 그대로 출력**한다 — 자동 [[재시도 스폰]]은 여전히 금지(§3.3)이고
  출력은 안내일 뿐이다 ⓒ id 를 못 뽑으면 그렇게 **말한다**(중복 생성 위험을 감수한 재발행 금지).
- ★**「그대로 출력」의 정의(슬롯 1 A4)**: 안내 줄은 **복사해서 바로 실행 가능한 명령줄**이어야 한다 —
  `<같은 objective>` 같은 placeholder 를 넣으면 그 줄은 안내가 아니라 숙제다. 실제 `$objective` 를 보간하고,
  `$SELF`(= `basename "$0"` — 실측 `bin/orca-rpi.sh:15`)가 아니라 **호출 가능한 경로**를 쓴다. 캐리어는
  `PATH` 에 없고 T17 도 실행 비트만 주지 PATH 를 건드리지 않으므로, basename 만 적으면 붙여 넣는 순간
  command-not-found 다.
- 미확인 명령으로의 확대는 Phase I 의 `--help` 실측 뒤에만 한다. 확인 못 하면 **미확인으로 남긴다** —
  받는다고 가정하고 배선하지 않는다.
- ★**help 실측이 아예 수행되지 않은 경우의 처분(슬롯 1 A5·D2)**: 측정 task 는 preflight rc=3(Orca 미가동)
  에서 중단되도록 설계돼 있는데, `--help` 는 **로컬 CLI 만으로 실행 가능**하다(rc=3 트리거 8종 중 하나는
  `no active plan` 이라 Orca 가용성과 무관하기까지 하다 — 실측). 따라서 ⓐ help 프로브는 라이브 발행보다
  **먼저** 배치하고 ⓑ 그럼에도 미실행이면 `--retry-request` 배선은 **실측 확인된 2개 명령(`run-create`·
  `worker-start`)에 한정**한 채 나머지는 미확인으로 남긴다. 이 처분이 명시되지 않으면 실행자가 「확인된
  명령만」이라는 조건을 만족시킬 입력 없이 시작해 추정 배선을 하게 된다.

**⑤ `[P2]` 처분 — 측정 절차와 기록 위치 (§11.9 ④ supersede)**
§11.9 ④ 는 미측정 잔여를 4종으로 정정했다. C23 은 이를 **실 워커 1기동**(read-only, `[C23]` 표식)으로 해제한다.

- 측정 대상 = dispatch id(`spawn`·`handoff` 2사이트) · delivery id(`check`) · `worker.agent_terminal_handle`
  (`worker-show`) · gate id(`gate-create`) = **4종 / 10사이트**(실측 — `[P2]` 주석 10건, 위치
  232·234·296·298·323·326·352·353·411·413). 초안의 "5종"은 계수 오류였고 §11.9 ④ 의 4종 열거가 옳다.
  goal 문서(`_goal/c23-orca-live-goal.md:18`)의 "5종" 표기도 같은 오류이며 그 표(`:22-25`) 자체가 4행이다 —
  success criteria 「최소 3종」은 **4종 중 3종**으로 읽는다.
- ★**`handoff` 2사이트(`:352`·`:353`)는 이번 사이클에 측정되지 않는다(슬롯 1 A6)**. 측정 절차가
  `spawn`·`wait`·`worker-show`·`gate` 만 호출하고 `handoff` 는 호출하지 않기 때문이다(호출하려면 워커를
  한 기 더 띄워야 하고, 그것은 「read-only 1기동」이라는 이번 사이클의 라이브 예산을 넘는다).
  `handoff` 는 `worker-start --terminal` 이라 응답 shape 가 agent 기반 `worker-start` 와 **같다는 보장이
  없다**. 따라서 처분은 **비대칭**이다: `spawn` 2사이트(`:232`·`:234`)는 실측으로 해제하고, `handoff`
  2사이트는 **`[P2]` 를 유지**하되 주석을 「미해제 사유: handoff 응답 미측정(C23) — terminal 기반 응답이
  agent 기반과 동형인지 미확인」으로 바꾼다. 「전부 해제」를 목표로 두면 **틀린 jq 경로를 실측값으로
  승격**하게 되므로, 침묵 잔여 금지의 올바른 이행은 *마커 유지 + 사유 명시*다.
- `gate-create` 가 워커 기동 없이 측정 가능한지는 **미확인**(help 미인용). Phase I 에서 확인하되, Task 가
  이미 완료된 뒤 gate 를 만들 수 있는지도 함께 본다 — 스폰 전에 만들면 Task 를 blocking 해 워커가 못 뜰 위험이
  있으므로 **측정 순서는 워커 완료 후**로 두고, 거절되면 그 사실을 수확으로 기록한다.
- 기록 위치 = `docs/ai-context/c22-orca-probe-measured.md` **append**(새 파일 금지 — P0 실측 SSOT 단일화).
  코드에서는 `[P2]` 주석을 제거하고 실경로로 교체하되, **빗나간 경로가 나오면 그것을 최대 수확으로 기록**한다.
- 미해제분은 사유를 명시한다(침묵 잔여 금지). 이 측정 자체가 [[의도-라이브 / 사고-라이브]]의 *의도* 쪽이며,
  Run/Task 는 삭제 수단 부재로 영구 잔존한다 — objective/title 에 `[C23]` 를 박아 식별 가능하게 한다.
- ★**라이브 발행의 영구 잔존 예산과 실패 처분(슬롯 1 D6·D7)**: 이 측정이 만드는 영구 객체는 **4개**
  (run 1 · task 1 · dispatch/worker 1 · gate 1)이며 그것이 이 사이클의 `LIVE-INTENT` 단위 수와 일치한다.
  - **부분 실패 시 재실행 금지**: `run-create` 가 서버에서 커밋된 뒤 응답이 끊기거나 후속 `task-create` 가
    실패하면, 같은 Step 을 다시 돌리는 순간 **삭제 불가능한 `[C23]` Run 이 2개**가 된다. ④의 정확 복구
    (`--retry-request`)는 **이 측정 뒤에** 착륙하므로 측정 시점에는 멱등 재발행 수단이 없다 — 이 부트스트랩
    순환은 순서를 바꿔 풀 수 없다(배선의 입력이 이 측정의 산출물이다). 따라서 처분은 「재시도하지 말고
    **원문을 기록하고 멈춘다**」이며, 이것을 **선언된 잔여**로 명시한다.
  - **dispatch id 경로가 빗나갔을 때의 복구**: `worker-start` 는 실 워커를 만든 뒤 `jq` 추출이 실패하면
    `die` 하므로(실측 — 부작용이 이미 난 뒤의 죽음), 반환 변수는 비고 워커는 살아 있다. 그 상태로 `release`
    를 부르면 `--dispatch` 빈 값으로 즉사하고, `--readonly` 라 동시-1 슬롯도 잡히지 않아 **재실행이 워커를
    증식**시킨다. 복구 데이터는 이미 손에 있다 — 캐리어가 응답 전문을 `$RUNDIR/last-worker-start.json` 에
    저장하고 측정 절차가 `jq paths` 로 전수 출력한다. 따라서 「빗나가면 그 파일에서 **실제 경로로 id 를 뽑아
    release 한다**」를 절차에 명시한다. 이미 출력 중인 데이터의 사용 지시일 뿐이라 스코프 확대가 아니다.

**⑥ `gpt` 비용 원장 (§4.3 및 §9 시나리오 2 supersede — 경로 변경 선언)**
§4.3(`:317`)은 `--output-format json` 의 `total_cost_usd` 를 래퍼가 **`_goal/<cycle>-ocx-ledger.tsv`** 에
append 한다고 적었고 §9 시나리오 2(`:679`)가 **같은 구 경로**를 반복한다 — 초안은 §4.3 만 supersede 대상에
넣어 §9 에 구 경로가 잔존했다(델타 재심 2 신규 결함 3). 둘 다 supersede 한다.
실측: 캐리어에 `total_cost_usd` / `ledger` 토큰 **0건** — T1 에 미구현이었다(C22 선언 잔여 2).
TO-BE 와 **경로 변경의 근거**: 캐리어는 사이클 번호를 모르므로 `_goal/<cycle>-…` 을 스스로 구성할 수 없다.
따라서 기본 경로를 `$RUNDIR/gpt-ledger.tsv`(gitignored 런타임)로 두고 **`ORCA_RPI_LEDGER` 환경변수로
override** 할 수 있게 한다.
- **정직한 상한**: §4.3 의 목적(C16 layer-yield 「가용 시 부기」)은 **보존 가능하되 강제자는 없다** —
  기본 경로가 `$RUNDIR` 이고 `_goal/` 착지는 호출자가 env 를 줄 때만이다. 초안의 "그대로 성립"은 과장이었다.
  ★쓰기 실패(권한·ACL)도 `|| true` 로 흡수되어 호출자에게 드러나지 않는다(슬롯 1 A7). 이것은 **의도된
  advisory 성질**이다 — 여기서 `die` 하면 executor 의 「stdout·rc 를 바이트 그대로 통과」 계약이 비용
  부기 실패 때문에 깨진다. 다만 「강제자 없음」이 「검증도 없음」을 정당화하지는 않으므로, **형식(헤더·컬럼
  순서·`n/a`)만은 ②ⓗ 가 stub 경로로 1회 실측**한다.
`gpt` 서브커맨드는 호출마다 1행 append 한다. `--role verifier`(codex)는 비용 필드를 내지 않으므로 `n/a` 로
적는다 — **모르는 값을 0 으로 적지 않는다.** executor 경로의 stdout 계약은 불변(원문 그대로 통과).

**⑦ T15·T17 착륙**
T17 = `setup/install.sh` `REQUIRED` 에 `$TARGET/bin/orca-rpi.sh` 등재 + `bin/` 실행 비트 부여 단계 추가
(실측 — `setup/install.sh:98-100` 의 `chmod +x` 대상이 `setup/` · `hooks/` · `hooks/tests/` 뿐이라 `bin/` 이
누락돼 있었다. `bin/claude-ocx` 는 REQUIRED(`:79`)엔 있고 chmod 엔 없어 **같은 구멍**).
chmod 줄이 `2>/dev/null || true` 인 것은 신규 결정이 아니라 **기존 3줄과 동형**이며 `set -euo pipefail`
(`:13`) 아래에서 맨 `chmod` 가 인스톨러 전체를 중단시키는 것을 막는 강제된 관례다(슬롯 1 A9 — 기각).
T15 = `skills/start-rpi-cycle/SKILL.md` Phase I 에 옵션 **(e) Orca 감독 사이클**(포인터만) + preflight 실패 시
(a)/(d) 폴백 명시. **미러 `opencode-harness/skill/start-rpi-cycle/SKILL.md` 동반** — 단 opencode 번들에는
`bin/` 자체가 없고(실측) Orca 워커 진입점은 Claude Code 이므로, 미러는 옵션 (e) 를 **미착륙으로 명시**한다
(옵션 (d) 가 이미 같은 방식으로 번역돼 있는 선례 — 미러 `:162` · capstone 3-계층 정직공개와 정합).
없는 경로를 있다고 쓰지 않는다.
★**폴백 조건은 rc=3 이 아니라 rc≠0 이다(슬롯 1 A8, 실측)**. `preflight` 는 `main()` 이 `assert_orca_exe` 를
먼저 걸므로(`:486` 의 면제 목록에 `preflight` 가 없다) **Orca 미설치/경로 오지정이면 rc=1** 로 죽는다
(실행 확인 — 없는 경로·`.cmd` 둘 다 rc=1, rundir 미생성). rc=3 은 Orca 가 *설치돼 있으나 미가동*인
경로뿐이다. 옵션 (e) 문면을 「rc=3 이면 폴백」으로 쓰면 **정작 미설치 머신이 폴백 밖에 놓여** 사이클이
멈춘다 — 설치가 금지된 환경에서 그것은 복구 불가 정지다. 따라서 문면은 「`preflight` 가 **rc≠0** 이면
(a)/(d) 로 폴백」이고, 괄호 라벨도 「(Orca 미가동)」이 아니라 「(Orca 미설치·미가동 무관)」이다.

**⑧ §19.5 처분 미착륙 — 이번 사이클이 실증한 열린 클래스**
실측: `grep -rn "19\.5" skills/` → 0건 · `grep -rniE '자기 산출물|실행 가능성' skills/` → 0건
(★초안이 쓴 `grep -rin "자기 산출물|실행 가능성"` 은 `-E` 부재로 vacuous 였다 — ① 과 같은 정정).
C20 spec `docs/superpowers/specs/2026-07-25-model-policy-design.md:2348` §19.5 의 처분(검증 임무
success_criteria 에 「자기 산출물의 전제·실행 가능성을 실측으로 확인했는가」 조항 신설)이 **어느 skill 에도
착륙하지 않았다**. 함의 2가지: ⓐ §19.5 의 반증 조건이 「**지시문 보강 착륙 후** 같은 클래스 재발」을
전제하므로 C21·C22 의 BLOCKER 는 floor-축 반증 입력으로 **아직 평가 불가**다 — floor 무변경 판정은 유효하되
근거 강도는 미갱신 상태다. ⓑ 이번 Gate R 과 델타 재심들이 그 조항을 **임무 프롬프트에 손으로 주입**해서야
자기-전제 결함을 잡았다 — **회차별 발견 수는 이 절 머리의 「개정 이력」이 SSOT 이며 여기서 재기술하지
않는다**(초안은 여기에 숫자를 복제했다가 개정 이력과 어긋났다 — content-drift 클래스의 자기-재발).
조항이 skill 에 착륙하기 전까지 같은 결함이 게이트마다 재발한다.
TO-BE: C23 Phase I 에서 `skills/start-rpi-cycle/SKILL.md` 의 Gate R · Gate P · Closeout success_criteria 에
그 조항을 착륙시킨다(미러 동반). 이 절 자체가 §19.5 클래스의 재현 사례이므로 근거는 자기-실증이다.

**⑨ 슬롯 1 이 드러낸 층-수율 관측 (신규 — §18.1 트리거 입력)**
이 사이클은 **게이트(Gate R 축 5회 정정 + Gate P 축 1회 정정)가 전부 PASS 한 뒤** 교차패밀리 슬롯 1 이
33건을 제기했고 트리아지 결과 **30건이 채택**됐다(기각 3: chmod 관례 오독 · preflight 인자 미파싱의
dry↔live 패리티 보존 · 뮤테이터 ID 오독). 채택분 중 코드-계약이 실제로 뚫리는 것이 다수였다 —
빈 대입/주석에 의한 격리 세탁(③) · 따옴표 감싼 경로의 전면 미탐(③) · `cmd_gpt` 에서 검사자가 실 API 호출을
GREEN 처리(②) · 브랜치 가드 거부의 상설 검사자 부재(②) · unborn 픽스처의 양방향 파손(②).
- **관측의 성격**: 이것은 「게이트가 게을렀다」가 아니라 **동일 패밀리 검증자가 자기 설계의 전제를 공유한다**는
  구조적 사실의 재확인이다. 슬롯 1 발견의 대부분은 *실행해 보면 즉시 갈리는* 것들이었고, 실제로 트리아지
  1단계에서 awk·git·perl 을 돌리자 판정이 확정됐다 — 즉 부족했던 것은 통찰이 아니라 **자기 산출물을
  실행해 보는 습관**이며, 그것이 정확히 ⑧ 이 말한 §19.5 클래스다.
- **§18.1 트리거 대조**: (a)「특정 층이 2사이클 연속 실발견 0」 — 미성립(전 층이 발견을 냈다).
  (b)「교차패밀리가 내부-통과 BLOCKER 를 연속 적발」 — **성립**(C21·C22 에 이어 C23 슬롯 1). 다만 그
  트리거의 처분은 C19 가 이미 「차기 floor 한정 재심 1회」로 예약했고 이번 사이클이 그것을 소비하므로
  (⑧ 및 C20 §19.5 참조) **중복 예약하지 않는다**. (c)(d)는 §18.1 참조 — 이번 사이클 판정은 Closeout 의
  `review-yield.md` C23 절에 1줄로 대조한다.
- **처분**: floor(검증자 티어)를 올리는 것이 아니라 **지시문 축**을 올린다 — ⑧ 의 TO-BE(자기-전제 실측
  조항의 3게이트 착륙)가 그것이며, 이번 슬롯 1 의 채택 30건이 그 처방의 필요성에 대한 추가 증거다.
