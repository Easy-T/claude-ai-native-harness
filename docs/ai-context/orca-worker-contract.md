# orca-worker-contract.md — Orca 워커 계약 SSOT

> Orca 가 워커 세션에 주입하는 preamble(RULE#1 포함) 위에 얹히는 **하네스-고유** 계약만 담는다.
> preamble 이 이미 나르는 규범(worker_done 1회 필수·5분 heartbeat·taskId+dispatchId 동봉 등)은
> 재전송하지 않는다(c21-orca-mode-design.md §2 "규범 재전송 금지", c22-orca-probe-measured.md P0-4).
> 워커는 이 문서를 CLAUDE.md 와 함께 자동 상속한다(§0.1 반증 1 — 글로벌 CLAUDE.md 는 프로세스 경계를 넘는다).

## 1. `worker_done` — 정확한 커맨드

```bash
ORCA="C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe"   # ★PATH 부재 가능성 + .cmd 는 send 거부
"$ORCA" orchestration send --type worker_done --subject "Phase <R|P|I|C>: <PASS|FAIL>" \
  --body "<변경·발견·잔여 3문장 요약>" --task-id "$TASK" --dispatch-id "$DISPATCH" \
  --outcome succeeded --files-modified "hooks/x.sh,setup/verify-setup.sh" \
  --report-path "docs/superpowers/plans/<plan>.md" --phase "<R|P|I|C>" --json
```

- 워커 세션 안에서 **워커 자신이** 이 명령을 발행한다 — `bin/orca-rpi.sh` 는 이 명령을 대신 실행하지 않는다
  (코디네이터 측 서브커맨드 세트에 `send`/`ask`/`reply` 가 없다 — T1 은 coordinator 전용 spawn/wait/gate/release 캐리어).
- `orca.cmd` 는 `orchestration send|reply` 를 `exit /b 2` 로 거부한다 — 반드시 `orca.exe` 절대경로.
- payload 에 **`taskId`+`dispatchId` 둘 다** 포함 — 실패한 재시도의 지각 완료가 현재 dispatch 를 잘못
  완료시키는 것을 방지한다.

## 2. PASS/FAIL → `--outcome` 매핑

- Phase 보고 첫 줄이 `PASS` 면 `--outcome succeeded`, `FAIL:` 이면 `--outcome failed`.
- **실패를 본문(`--body`)에만 적고 `--outcome succeeded` 를 쓰지 않는다** — "On failure, use
  `--outcome failed`; never encode failure only in prose"(orchestration 가이드 verbatim).
- `worker_done` 뒤 `task-update --status completed` 호출 금지(Orca 가 자동 처리).

## 3. `ask` vs `gate` vs `send --type escalation`

| 채널 | 용도 | 발행 주체 |
|---|---|---|
| `orchestration ask` | 워커→코디네이터 질문(코디네이터가 `reply` 로 응답) | 워커 |
| `gate-create`/`gate-resolve` | **코디네이터 소유** DAG 판정(예: Gate P PASS/FAIL) — 워커의 질문에 답하는 용도 아님 | 코디네이터(`bin/orca-rpi.sh gate`) |
| `send --type escalation` | 사고 상신(훅 차단·예상 밖 상태) | 워커 |

⚠️ **`orca orchestration escalation` 이라는 명령은 존재하지 않는다** — orchestration 하위 28개
서브커맨드 전수(`ask check coordinator-start coordinator-stop dispatch dispatch-show gate-create
gate-list gate-resolve inbox reply reset run-create run-current run-list run-show run-use send
task-create task-list task-update worker-abandon worker-list worker-read worker-release
worker-retain worker-show worker-start worker-stop`)에 없다. escalation 은 **메시지 타입**이며
정본은 `send --type escalation`(c22-orca-probe-measured.md P0-4 실측 — 설계문서 초안의 오기 정정).

## 4. RPI_SKIP 금지 · read-only 팬아웃 · GPT 세션 inherit 위임 금지

- **`RPI_SKIP` 사용 금지.** 훅이 plan 부재로 워커를 차단하면(정상 설계라면 발생하지 않는다 — 코디네이터가
  `bin/orca-rpi.sh preflight` 에서 `--worktree current` 고정 + plan 실재를 선-단언한다) `RPI_SKIP` 으로
  스스로 우회하지 말고 `send --type escalation` 으로 코디네이터에 상신하라.
- **read-only 팬아웃**: 동시에 여러 워커를 띄우는 것은 **read-only Task(리뷰 등)에서만** 허용된다.
  non-readonly(코드/문서 변경) Task 는 코디네이터 캐리어(`bin/orca-rpi.sh spawn`)가 동시 1개로
  강제한다 — Orca 는 충돌을 추론하지 않는다(`orchestration.md:181/:342`). 워커가 병렬로 다른 워커를
  스폰하려 시도하지 말 것(이 캐리어의 스폰 권한은 코디네이터 전유).
- **GPT 세션 `model:'inherit'` 위임 금지 — 리터럴 명시 강제.** 비-Claude(GPT) 워커 세션에서
  `Agent(model:'inherit')` 로 위임하면 `hooks/surface-model-policy.sh` 의 상속 축 판정이 **침묵**한다
  (세션이 GPT 임을 알아도 그 티어가 opus 이상인지 단언할 근거가 없다 — model-policy-design.md §20.3 N4).
  GPT 워커 세션에서 Agent/Workflow 를 호출할 때는 항상 **리터럴 모델**(`opus`/`sonnet`/`haiku`/`fable`)을
  명시하라.

## 5. ★ 승인 채널 층 분리 — 빠뜨리면 워커 영구 hang 또는 무승인 머지

| 층 | 누가 | 승인 채널 | 근거 |
|---|---|---|---|
| **워커**(dispatched) | 코디네이터에게 묻는다 | `orchestration ask` / `send --type decision_gate` | preamble RULE#1: *"NEVER use AskUserQuestion; use `orca orchestration ask` or send `--type decision_gate`. AskUserQuestion opens a local TUI prompt that the coordinator cannot see and cannot answer — your session will hang forever waiting on a human."* |
| **코디네이터**(사람과 같은 화면) | 사용자에게 묻는다 | **`AskUserQuestion`** | c21-orca-mode-design.md §2 경계표·§3.7 — 머지 승인은 사람 소유, `gate-resolve` 로 대체 금지 |

이 구분을 빠뜨리면 ⓐ워커가 아무도 보지 못하는 로컬 TUI 를 열고 영구 대기(hang)하거나, ⓑ머지가 사람
승인 없이 `gate` 로 처리되는 규약 위반 중 하나가 발생한다. **워커는 절대 `AskUserQuestion` 을 쓰지
않는다. 코디네이터는 머지 승인에 한해 `AskUserQuestion` 을 계속 쓴다.** (CONTEXT.md [[승인 채널 층 분리]])

## 6. 워커 셸 티어 — Task spec 이 층1 호출을 명령한다

워커 셸 자체의 `ANTHROPIC_MODEL` 은 오케스트레이션 사무용(`claude-sonnet-5[1m]` 상속)이지, 실제 추론은
Task spec 이 지시하는 층1 호출(`Agent(execute-strict|review-strict|explore-strict)`, `Workflow(...)`)에서
일어난다 — 워커는 Task spec 을 권유가 아니라 **명령**으로 취급한다(c21-orca-mode-design.md §4.1).
