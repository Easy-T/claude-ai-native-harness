# C22 P0 프로브 실측 (2026-08-17)

> 설계문서 `docs/ai-context/c21-orca-mode-design.md` §7 Phase 0 하드 게이트 이행분.
> **모두 read-only.** 실행자 = `C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe`

## P0-3 — settings.json 무결성 (최우선 관문) ✅ PASS

```
before: 1463565029 9486 settings.json
after : 1463565029 9486 settings.json     ← 프로브 5건 실행 후
```
**변경 0.** `agent hooks status --json` 은 진짜 read-only 다(설계문서가 "off 가 무엇을 지우는지 미문서화"라며 1순위 위험으로 지목했던 항목 — status 축은 안전 확정, **off 축은 여전히 미측정·발행 금지**).

훅 공존 실측: **Orca 관리 11 + 하네스 13 = 24**. 서로를 참조하지 않는 독립 엔트리.

## P0-1 — 5건 실행 결과

### ⓐ `orca status --json` → ok:true
```
app.running=true  app.pid=1528  desktopWindowStatus=available
runtime.state=ready  runtime.reachable=true  appVersion=1.4.183
capabilities: orchestration.contract.v1 · orchestration.federation.v1 ·
              orchestration.worker-launch-preferences.v1 · terminal.multiplex.v1 …
```
**`orchestration.contract.v1` 케이퍼빌리티 실재** = orchestration 이 정식 지원 표면임을 런타임이 선언한다.

### ⓑ `orchestration run-list --json` → ok:true
```
runs = 1  (id="run_legacy_local", objective="Legacy orchestration state (inspect only)")
```
툼스톤 1건뿐 — **실행 전례 0 불변**. 단 §8-A2 "experimental 활성 여부 미확인"은 **해소**(RPC 가 응답한다).

### ⓒ `worktree current --json` → ok:true ★§8-C13 해소
```
worktree.id         = 9253fb88-f084-4cb8-90f7-91a3226fbf08::C:/Users/12132/.claude
worktree.repoId     = 9253fb88-f084-4cb8-90f7-91a3226fbf08
worktree.projectId  = github:easy-t/claude-ai-native-harness
worktree.path       = C:/Users/12132/.claude
worktree.head       = 39e3f1f4e6e8a511fb212252e91bfc67206c04e8
worktree.branch     = refs/heads/master
worktree.isMainWorktree = true
```
**하네스를 정확히 가리킨다**(head 가 당시 master 팁과 일치). 셀렉터 id 형식 = `<repoId>::<path>` 실물 확정.
전제였던 사용자 액션(repo 등록)은 **완료**: `repo list` → `orca-lab` + **`.claude` (path=C:/Users/12132/.claude, kind=git)** 2건.

### ⓓ `agent hooks status --json` → ok:true
```
enabled=true  settingsPath=…/AppData/Roaming/orca/orca-data.json  appliedBy=offline
claude      : state=installed      configPath=C:\Users\12132\.claude\settings.json   managedHooksPresent=true
codex       : state=installed      (orca 자체 runtime-home)
gemini      : state=installed      antigravity: state=installed
openclaude  : state=not_installed  amp: state=not_installed
```
★**Orca 는 하네스 `settings.json` 을 자기 관리 대상으로 인식한다**(`managedHooksPresent: true`).
→ `agent hooks off` 발행 시 **하네스 파일을 편집할 것**이 강하게 시사된다. 발행 금지 유지 · 캐리어 preflight 의 백업/diff 는 **필수**로 확정(설계문서 §3.1 유지).

### ⓔ `orchestration dispatch --dry-run` → **미실행** (사유 기록)
`--help` 로 플래그 실재만 확인:
```
Usage: orca orchestration dispatch --task <task_id> --to <handle> [--from <handle>]
       [--run <run_id>] [--inject] [--dry-run] [--return-preamble] [--json]
```
`--task` 가 **필수**라 실행하려면 Task 를 먼저 만들어야 하는데, 그건 read-only 가 아니다 → 아래 P0-2 와 함께 사용자 승인 대기.

## P0-2 — 응답 필드 경로: **부분 확정**

| 필드 | 상태 | 실측값 |
|---|---|---|
| 봉투(envelope) | ✅ 확정 | `{id, ok, result}` — 전 명령 공통 |
| worktree selector | ✅ 확정 | `result.worktree.id` = `<repoId>::<path>` |
| run id | ⬜ 미확정 | `run-create` 응답 미실행 |
| task id | ⬜ 미확정 | `task-create` 응답 미실행 |
| dispatch id / delivery id / gate id | ⬜ 미확정 | 상동 |
| `worker.agent_terminal_handle` | ⬜ 미확정 | `worker-show` 는 dispatch 선행 필요 |

## ★차단 사유 — 되돌릴 수 없음

`orchestration --help` 서브커맨드 **28종 전수**:
```
ask check coordinator-start coordinator-stop dispatch dispatch-show gate-create gate-list
gate-resolve inbox reply reset run-create run-current run-list run-show run-use send
task-create task-list task-update worker-abandon worker-list worker-read worker-release
worker-retain worker-show worker-start worker-stop
```
**`run-delete`·`task-delete`·`run-archive`·`run-close` 전부 부재.** 만든 Run/Task 를 개별 삭제하는 수단이 없다.

되돌림 후보는 둘뿐이며 **둘 다 부적합**:
- `orchestration reset (--all | --tasks | --messages)` — **스코프가 전역**이다. 내가 만든 것만 지울 수 없다. (설계문서 T19 가 deny 후보로 지목한 바로 그 명령)
- `task-update --id <t> --status <s>` — 상태 전이일 뿐 삭제가 아니다. 레코드는 남는다.

→ **P0-2 완결에는 영구 DB 레코드 생성이 필요**하다. 현재 `runs=1`(툼스톤)인 깨끗한 상태를 오염시키는 셈이므로 **사용자 승인 없이 진행하지 않는다**.

## 이번 프로브로 해소된 설계문서 미확인 항목

| 항목 | 종전 | 실측 후 |
|---|---|---|
| §8-A2 experimental 활성 | 미확인 | **해소** — RPC 응답(`ok:true`) |
| §8-C13 `worktree current` 반환값 | 근거 없음 | **해소** — 위 ⓒ |
| §9-A1 repo 등록 | 미등록 | **완료** (사용자 수행) |
| §9-A3 hooks status 안전성 | 미확인 | **해소** — cksum 불변 |
| §3.0 orca PATH | "없다" | **정정** — 사용자 PATH 9번째 등록(셸 스냅샷이 낡았을 뿐) |
| P0-2 응답 필드 | 미확인 | **부분** — 봉투·selector 만 |

## 미측정으로 남는 것 (정직 부기)

- `agent hooks off/on` 의 실제 편집 범위 — **발행 금지 유지**
- Run/Task/Dispatch/Gate 응답 shape — 위 차단 사유
- 워커 preamble 원문(P0-4) — dispatch 선행 필요

---

# P0-2 · P0-4 완결 (2026-08-17, 사용자 승인 후 — 프로브용 Run 1개)

생성물(삭제 수단 부재 — DB 영구 잔존, objective/title 에 `[PROBE]` 명시):
`run_720d6f472515` · `task_946e358573bc`. 워커는 **띄우지 않았다**(`dispatch --dry-run` → `dispatch:null, injected:false`).

## P0-2 — 응답 필드 경로 **확정**

| 필드 | 경로 | 실측값 |
|---|---|---|
| 봉투 | `{id, ok, result, _meta}` | `_meta.runtimeId` 동반 |
| **run id** | `result.run.id` | `run_720d6f472515` |
| coordinator handle | `result.run.coordinator_handle` | `term_a77af4ad-…` |
| coordinator pane key | `result.run.coordinator_pane_key` | `2fdb2541-…:9fb1a676-…` |
| **task id** | `result.task.id` | `task_946e358573bc` |
| task status | `result.task.status` | `ready` (생성 직후 기본값) |
| task deps | `result.task.deps` | `"[]"` — **JSON 문자열이지 배열이 아니다** |
| provenance | `result.task.created_by_process_incarnation` | `<repoId>::<path>@@…` — 워크트리 셀렉터가 그대로 박힌다 |
| 멱등 | `result.mutation.{requestId,replayed}` | `replayed:false` |
| dry-run | `result.{dispatch,injected,dryRun,preamble}` | `null / false / true / <원문>` |

★**함정**: 봉투의 최상위 `id`(`6ae6d4eb-…`)는 **요청 상관 ID이지 run/task id가 아니다**. `result.run.id`(`run_…` 접두)와 형식부터 다르다. 캐리어가 `.id` 를 그대로 집으면 조용히 틀린 값을 잡는다.

★`deps` 는 **문자열** `"[]"` 로 돌아온다. `--deps <json_array>` 로 넣지만 읽을 때는 파싱이 필요하다.

## P0-4 — preamble 원문 확보 + ★규약 충돌 1건

`--return-preamble` 로 워커에게 주입될 원문 전체를 확보했다. 주요 계약:

- `worker_done` **정확히 1회** 필수 · `--body` 는 3문장 요약 강제 · `--outcome succeeded|failed`
- payload 에 **taskId + dispatchId 둘 다** 포함(실패한 재시도의 지각 완료가 현 dispatch 를 완료시키는 것 방지)
- **5분마다 heartbeat** — 단 `check --wait`/`ask` 블로킹 중에는 생략(그 자체가 liveness)
- escalation = `send --type escalation` (`orchestration escalation` 이라는 명령은 **없다** — 설계문서 T3 의 정정 항목 확인됨)
- worker_done 후 **추가 행동 금지**(sleep/poll 루프 금지, 셸 종료도 금지 — 터미널 재사용 대기)

### ★충돌 — preamble 이 `AskUserQuestion` 을 전면 금지한다

preamble verbatim:
> **BEHAVIOR RULE #1 (MUST NOT VIOLATE):** NEVER use AskUserQuestion; use `orca orchestration ask` or send `--type decision_gate`. AskUserQuestion opens a local TUI prompt that the coordinator cannot see and cannot answer — your session will hang forever waiting on a human.

그런데 설계문서는 **3곳**에서 머지 승인을 AskUserQuestion 으로 규정한다:
- §2 경계표: 「**사용자 머지 승인** = 사람 · `gate-resolve` 로 대체 **금지**」
- §3.7 `:232`: 「★ 사용자 머지 승인 = AskUserQuestion (사람) — gate 로 대체 금지」
- §9 시나리오1 9단계: 「머지 승인은 **사용자에게 AskUserQuestion**(gate 아님)」

**둘 다 옳고, 층이 다르다** — 충돌은 실재하나 해소 가능하다:

| 층 | 누가 | 승인 채널 | 근거 |
|---|---|---|---|
| **워커**(dispatched) | 코디네이터에게 묻는다 | `orchestration ask` / `decision_gate` | preamble RULE #1 — 워커의 TUI 는 아무도 못 본다 |
| **코디네이터**(사람과 같은 화면) | 사용자에게 묻는다 | **AskUserQuestion** | 설계문서 §2 — 머지는 사람 소유 |

→ **T3 워커 계약에 반드시 명시할 것**: 「워커 세션에서는 AskUserQuestion 금지(hang), 대신 `ask`. 단 **코디네이터 세션의 머지 승인 AskUserQuestion 은 유지**」. 이 구분을 빠뜨리면 ⓐ워커가 영구 hang 하거나 ⓑ머지가 사람 승인 없이 gate 로 처리되는 규약 위반 중 하나가 난다.

**+ 파생 확인**: 워커 계약이 나를 대체하지 않는다 — preamble 은 Orca 가 주입하므로 **T3 는 그 위에 얹히는 하네스-고유 계약만** 담으면 된다(중복 재전송 금지 — 설계문서 §2 「규범 재전송 금지」와 정합).

## P0 게이트 판정: **통과**

| 항목 | 상태 |
|---|---|
| P0-1 5건 | ✅ 완료(dispatch 는 dry-run) |
| P0-2 필드 경로 | ✅ **확정** — `[P2]` 마커 해제 가능 |
| P0-3 settings 무결성 | ✅ cksum 불변 |
| P0-4 preamble | ✅ 원문 확보 + **충돌 1건 표면화·해소안 명시** |

→ 설계문서 §7 「P0 산출물 없으면 T1~T3 코드 작성 금지」 **해제**. T1 캐리어는 이제 실측 위에서 작성된다.

## 잔여 미측정

- `worker-start` 실제 응답 shape(`worker.agent_terminal_handle`) — 워커를 띄워야 나온다. T1 작성 시 `# [P2]` 유지.
- `gate-create` / `check` 의 delivery id — 상동.
- `agent hooks off` 의 편집 범위 — **발행 금지 유지**.

---

# C23 라이브 측정 (2026-08-18 — 실 워커 1기동, read-only)

> **의도-라이브(`LIVE-INTENT`)** — 측정이 목적이다. 사고-라이브 0건.
> 잔존 영구 객체 4: Run `run_f0bdcb0f7f76` · Task `task_6b4fa5a1601e` ·
> Dispatch `ctx_b35f37d7e59e`(released) · Gate `gate_7153aa08d7e0`(resolved PASS).
> C22 stub 검증이 남긴 스테일 슬롯 `t1` 은 이 측정 **전에** 해제했다
> (증거 사본 `.orca-rpi/stale-t1.evidence`, BEFORE=`t1` 1줄 → AFTER=0줄).

## 판정표 — `[P2]` 4종

| 종 | 추정 경로 | 실측 경로 | 판정 |
|---|---|---|---|
| dispatch id (`worker-start`) | `.result.dispatch.id` | **`.result.dispatchId`** | ❌ **빗나감** — 이번 사이클 최대 수확 |
| delivery id (`check`) | 3중 폴백 `.result.delivery.id` ∥ `.result.deliveryId` ∥ `.result.delivery_id` | **`.result.deliveryId`** | ⚠️ 부분 적중 — 3중 중 2번째만 실재, 나머지 둘은 스키마 부재 |
| `agent_terminal_handle` (`worker-show`) | `.result.worker.agent_terminal_handle` | **동일** | ✅ 적중 |
| gate id (`gate-create`) | `.result.gate.id` | **동일** | ✅ 적중 |

**4종 전부 실측**(goal success criteria 「최소 3종」 초과 달성). 마커 해제 8사이트,
유지 2사이트(`cmd_handoff` — 아래 미해제 절 참조).

## ★ 근본 원인: 응답 shape 가 명령군마다 다르다

추정이 빗나간 이유는 「추측을 잘못해서」가 아니라 **`.result.dispatch.id` 가 실재하기 때문**이다 —
단, `worker-show` 에만 있다. 캐리어의 `cmd_spawn` 이 읽는 것은 `worker-start` 응답인데, 두 명령의
직렬화 규약이 다르다.

| 명령군 | 규약 | 실측 근거 |
|---|---|---|
| 워커 생애주기 변이 — `worker-start` · `worker-stop` · `worker-release` | **평면 camelCase** (`.result.dispatchId`) | `last-worker-start.json` · `c23-worker-stop.json` · release 응답 |
| 배치 수신 — `check` | **평면 camelCase** (`.result.deliveryId`) | `last-check.json` |
| 레코드 생성 변이 — `run-create` · `task-create` · `gate-create` | **타입 키 아래 중첩 snake_case** (`.result.run.id` · `.result.task.id` · `.result.gate.id`) | `last-run-create.json` · `last-task-create.json` · `last-gate-create.json` |
| 읽기 모델 — `worker-show` | **중첩 snake_case 레코드** (`.result.dispatch.id` · `.result.worker.agent_terminal_handle`) | `c23-worker-show.json` |

따라서 갈림은 「변이 vs 읽기」 축이 아니라 **「dispatch 축(평면) vs 레코드 축(중첩)」** 이다.
`gate-create` 는 변이인데 중첩이고 `check` 는 읽기인데 평면이라, 어느 단순 규칙으로도 코드
독해만으로는 예측할 수 없었다. **이것이 `[P2]`(실측 전 하드코딩 금지) 규약의 정당화 사례다.**

### `worker-start` 응답 원문 발췌 (`.orca-rpi/last-worker-start.json`)

```json
{ "id": "bb9b4332-…", "ok": true,
  "result": {
    "runId": "run_f0bdcb0f7f76", "taskId": "task_6b4fa5a1601e",
    "dispatchId": "ctx_b35f37d7e59e", "state": "ready", "stage": "input_accepted",
    "effects": [ { "kind": "terminal", "role": "agent", "action": "created",
                   "id": "term_42a7b36b-…", "surface": "visible" } ],
    "mutation": { "requestId": "77c96f2b-…", "replayed": false } } }
```

`.result` 아래 `dispatch` 라는 **키 자체가 없다**. `jq 'paths(scalars)|select(.[-1]=="id")'` 로 뽑은
`id` 말단 경로는 `id`(봉투 상관ID)와 `result.effects.N.id` 뿐이었다 — dispatch id 는 `id` 로
끝나지도 않아서, 「말단이 id 인 경로」를 훑는 탐색으로도 걸리지 않는다.

### `worker-show` 는 `.result.dispatch.id` 를 가지고 있다

```
result.dispatch.id                     = ctx_b35f37d7e59e
result.dispatch.assignee_handle        = term_42a7b36b-…
result.worker.dispatch_id              = ctx_b35f37d7e59e
result.worker.agent_terminal_handle    = term_42a7b36b-…
result.terminal.handle                 = term_42a7b36b-…
result.terminalResource.terminalHandle = term_42a7b36b-…
```

`.result` 최상위 키 = `dispatch` · `observation` · `terminal` · `terminalResource` · `worker`.
handle 은 **동값 별칭 4경로**로 노출된다 — 캐리어는 계약 경로 1개만 쓴다(별칭 폴백은 "모른다"의 표기다).

## `check` 실측 — 빈 배치의 shape

```json
{ "ok": true, "result": { "runId": "run_f0bdcb0f7f76", "deliveryId": null,
    "messages": [], "count": 0, "acknowledged": null,
    "timedOut": true, "cancelled": false, "connectionLost": false } }
```

`deliveryId` **필드는 존재하고 값만 null** 이다. 따라서 `.result.deliveryId // empty` 하나로
「필드 부재」와 「빈 배치」가 모두 empty 로 접혀 캐리어의 `pending-ack` 처분이 정확해진다.
3중 폴백의 다른 두 경로는 스키마에 없었다 — 「모른다」의 표기였고 실측이 그것을 없앴다.

## ★ 워커가 `worker_done` 을 보내지 않았다 — 원인 판정

`wait --timeout-ms 900000` 이 **`timedOut: true` · `count: 0`** 으로 종료했다. 진단 관측:

| 관측 | 값 |
|---|---|
| `worker.state` / `stage` | `ready` / `input_accepted` (15분간 변화 없음) |
| `dispatch.status` | `dispatched` · `completed_at`=null · `last_heartbeat_at`=**null** |
| `terminal.connected` / `writable` | true / true (죽지 않았다) |
| `terminal.lastOutputAt` | 디스패치 **27초 후**, 이후 **약 20분간 무출력** |
| `worker-read` 터미널 버퍼 120줄 | 전부 **preamble 원문**. Claude Code 배너 + `You are working inside Orca…` 이후 어시스턴트 응답 0줄, preamble 말미에서 잘림 |
| Run 인박스 | `count: 0` |

**판정**: preamble 이 워커 터미널에 *전달·표시* 되었으나(그래서 `stage: input_accepted` 는 참)
**에이전트 턴이 시작되지 않았다**. 캐리어 결함이 아니다 — `worker-start` 는 rc=0 이었고 `effects` 도
`terminal created/visible` 로 정상이다. 하트비트가 한 번도 없다는 점이 이를 뒷받침한다(preamble 은
5분 주기 하트비트를 명령하는데 0건 = 워커가 preamble 을 **읽지 않았다**).

**미측정으로 남는 것**: 정상 완주 시의 `worker_done` 배치 shape(= `deliveryId` 의 **비-null** 값과
`messages[]` 원소 구조). `deliveryId` **경로**는 확정됐으나 **값이 채워진 배치**는 못 봤다.
자동 재시도는 하지 않았다(goal ④ · plan Task 1 Step 3 재실행 금지 — 삭제 불가 객체 증식 방지).

## `release` 는 settled 워커만 받는다 (부수 실측)

```json
{ "ok": false, "error": { "code": "dispatch_inactive",
  "message": "Dispatch ctx_b35f37d7e59e is ready; only a settled worker can release. Use worker-stop to cancel an active worker." } }
```

캐리어는 이 비-0 을 삼키지 않고 **원장 슬롯을 유지한 채** 사유를 표면화했다(설계대로 동작).
오류가 지시한 `worker-stop` → `release` 순서로 정리했고 최종 `state: released` 를 확인했다.
`worker-stop` 응답: `state: stopped` · `processAction: closed_agent_terminal` · `close.ptyKilled: true`.
**교훈**: 기동은 됐으나 일하지 않은 워커의 정리 경로는 `release` 가 아니라 `worker-stop` + `release` 다.

## `--retry-request` help 원문 (read-only · 부작용 0)

`orca orchestration <cmd> --help` 을 5개 명령에 실행한 결과 — **전부 `--retry-request` 를 수용**한다.

```
=== run-create ===      --retry-request
=== task-create ===     --retry-request
=== worker-start ===    --retry-request
=== gate-create ===     --retry-request
=== check ===           --retry-request
```

`run-create --help` 전문(대표):

```
orca orchestration run-create

Usage: orca orchestration run-create --objective <text> [--from <handle>] [--json]

Create and bind a lightweight orchestration Run

Options:
  --help                 Show this help message
  --json                 Emit machine-readable JSON
  --pairing-code
  --environment
  --objective
  --from
  --retry-request

Notes:
  A Run is a namespace and home inbox. It never schedules or places workers.
  --retry-request is only for exact recovery after an unknown mutation result.
```

`worker-start` Usage 줄(옵션 위치 확인용):

```
Usage: orca orchestration worker-start --task <task_id> [--on <saved-environment>]
  [--worktree <current|selector|new-child|new-top-level>] (--agent <agent> | --terminal <handle>)
  [--model <id>] [--effort <level>] [--name <name>] [--repo <selector>] [--base-branch <ref>]
  [--display-name <text>] [--comment <text>] [--setup <run|skip|inherit>] [--retry-of <dispatch_id>]
  [--timeout-ms <n>] [--run <run_id>] [--from <handle>] [--retry-request <id>] [--json]
```

즉 「exact recovery after an unknown mutation result」 = 응답을 못 받은 변이의 **정확 복구** 전용.
이 실측으로 **CLI 수용 범위 = 5개 명령 전부**가 확정됐다(미확인 잔여 0). 다만 이것이 곧 캐리어의
배선 범위는 아니다 — **배선은 변이 4개**(`cmd_run`·`cmd_task`·`cmd_spawn`·`cmd_gate create`)이고,
`check` 는 수용은 하지만 **선언된 미배선**이다(`bin/orca-rpi.sh:378-380` — help Notes 의 "unknown
**mutation** result" 와 §11.10 ④ⓐ 의 「변이 서브커맨드」 한정. 대기/조회에는 회수할 mutation 이 없다).
★「수용 5」와 「배선 4」를 한 문장으로 뭉개면 `check` 의 미배선이 *누락*으로 오독된다.

## 미해제 `[P2]` — 2사이트 (`cmd_handoff`)

`handoff` 는 이번 사이클에서 **한 번도 호출하지 않았다**(호출하려면 워커를 한 기 더 띄워야 하고
라이브 예산 밖이다). 따라서 `worker-start --terminal` 응답은 미측정이다. 처분:

- **경로는 `.result.dispatchId` 로 갱신**했다 — 같은 CLI 명령(`worker-start`)의 agent 아암이
  실측으로 평면 camelCase 임이 확정됐으므로 구 `.result.dispatch.id` 는 **알려진-틀린 경로**다.
  틀린 것을 그대로 두는 것은 「미측정」의 정직한 표현이 아니다.
- **마커는 유지**했다 — terminal 아암이 agent 아암과 동형이라는 것은 *유추*이지 실측이 아니다.

다음 사이클이 handoff 를 실제로 호출하면 이 2사이트가 해제된다.

## 잔여 미측정 (C23 시점)

- `worker-start --terminal`(handoff 축) 응답 shape — 위 참조.
- **채워진** `check` 배치(`deliveryId` 비-null · `messages[]` 원소 구조 · `acknowledged` 의미) —
  워커가 완주해야 나온다. 경로는 확정, 값 shape 는 미확정.
- `agent hooks off` 의 편집 범위 — **발행 금지 유지**(C22 이래 불변).
- 워커 턴 미시작의 상위 원인(Orca 측 입력 제출 실패 vs Claude Code 기동 타이밍) — 이번 사이클
  스코프 밖. 재현되면 별도 사이클로 다룬다.
