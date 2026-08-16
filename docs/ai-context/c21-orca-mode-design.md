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
