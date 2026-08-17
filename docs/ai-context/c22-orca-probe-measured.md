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
