---
name: orca-rpi-cycle
description: |
  Orca ADE 오케스트레이션으로 표준 RPI 사이클(Research→Plan→Implement→Closeout, 4-Task DAG)을 구동한다.
  사용자가 "Orca로 돌려", "Orca 사용해서 사이클 시작", "orca orchestration으로 진행해줘",
  "C<N> 사이클 Orca로" 등을 말하거나 start-rpi-cycle Phase I 옵션 (e)를 선택하면 반드시 사용.
  bin/orca-rpi.sh(유일 스폰 캐리어)를 통해서만 orca 워커를 기동하며, preflight 실패 시
  자동으로 기존 Phase I 옵션 (a)/(d) 로 폴백한다 — Orca 는 선택적 가속기, 필수 경로가 아니다.
orchestrator_skill: true
generated_by: create-orchestrator-skill
orchestrator_version: 1.0
---

# orca-rpi-cycle

Orca ADE 를 통해 표준 RPI 4-Task DAG(R→P→I→C)를 구동한다. 이 skill 은 `bin/orca-rpi.sh`
(유일 스폰 캐리어, docs/ai-context/c21-orca-mode-design.md §7 T1)를 통해서만 Orca 워커를 기동하며,
워커 계약은 `docs/ai-context/orca-worker-contract.md` 를 따른다(이 skill 은 그 계약을 재전송하지 않는다).

# Phase 0 — Preflight (fail-open)

```bash
bin/orca-rpi.sh preflight
git rev-parse --abbrev-ref HEAD
```

- **rc=0**: Orca 가동·orchestration 도달·`worktree current`·plan 실재·settings 백업 전부 확인됨 — 아래 브랜치 가드를 통과하면 Phase 1 로 진행.
- **★브랜치 가드 (통과 못하면 Phase 1 금지)**: `worktree current` 는 실측상 `isMainWorktree=true`·
  `branch=refs/heads/master` 다. 즉 `--worktree current` 로 띄운 I 워커는 **머지 대상 브랜치(master)에 직접
  커밋**하므로 사람의 머지 승인이 무의미해진다(거절해도 이미 착륙). `git rev-parse --abbrev-ref HEAD` 결과가
  `master` 또는 `main` 이면 **non-readonly 워커(R/P/I/C) 스폰을 금지**한다 — 코디네이터가 먼저 사이클
  브랜치(예: `orca-cycle-<N>`)를 만들어 체크아웃한 뒤 Phase 1 로 진행한다. read-only 팬아웃(Phase 4)은
  브랜치와 무관하게 허용된다.
- **rc=3**(또는 그 외 비-0)**: Orca 를 즉시 포기하고 기존 사이클 경로로 폴백한다.** 사이클은 절대 멈추지
  않는다 — Orca 는 선택적 가속기다(c21-orca-mode-design.md §9 시나리오3). 폴백 경로는 사이클 크기에 따라
  (a) subagent-driven-development 또는 (d) ultracode Workflow(ON 인 세션만) — 예를 들어 (a) 폴백에서
  Implement task(plan 의 heavy task) 를 위임하는 실제 호출 형태(CLAUDE.md §3: 코드/TDD 위임은
  execute-strict — Research 위임은 explore-strict 를 쓴다):

  ```
  Agent(subagent_type="execute-strict",
        task="<plan task 본문 verbatim>",
        context_paths=["docs/superpowers/plans/<현재 plan>.md",
                        "docs/ai-context/<관련 spec>.md"],
        success_criteria="<plan task 의 검증 기준>")
  ```

  preflight 실패 사유(orca 미가동/repo 미등록/plan 부재 등)를 사용자에게 1줄로 보고하고 폴백을 계속한다 —
  재시도 루프 없음.

# Phase 1 — Run + Task DAG 생성

Preflight 성공 시에만 진행. Run 1개 + Task 4개(R/P/I/C)를 깊이 4 짜리 의존 체인으로 만든다
(가이드 권고 상한, `orchestration.md:390`):

```bash
RUN=$(bin/orca-rpi.sh run --objective "<사이클 목표 한 줄>")
T_R=$(bin/orca-rpi.sh task --title "R: Research" --spec "$R_SPEC")
T_P=$(bin/orca-rpi.sh task --title "P: Plan" --spec "$P_SPEC" --deps "[\"$T_R\"]")
T_I=$(bin/orca-rpi.sh task --title "I: Implement" --spec "$I_SPEC" --deps "[\"$T_P\"]")
T_C=$(bin/orca-rpi.sh task --title "C: Closeout" --spec "$C_SPEC" --deps "[\"$T_I\"]")
```

`$R_SPEC`/`$P_SPEC`/`$I_SPEC`/`$C_SPEC` 는 아래 4종 템플릿을 **그대로**(재서술 금지) 채워 넣는다 —
각 템플릿은 preamble 이 이미 나르는 규범을 재전송하지 않고, 이 사이클 고유의 지시만 담는다:

4종 템플릿의 **첫 지시는 예외 없이 계약문서 읽기**다 — `docs/ai-context/orca-worker-contract.md` 는
`CLAUDE.md` 같은 자동 로드 특수 파일이 **아니고**, 그것을 워커에 주입하는 단계도 없다(자동 상속 아님).
또한 각 템플릿은 층1 호출(`Agent(...)`/`Workflow(...)`)을 **명령**한다 — 워커 셸의 `ANTHROPIC_MODEL` 은
오케스트레이션 사무용(sonnet)이고 실제 추론은 층1 호출에서 일어나므로(설계 §4.1), 워커가 사무용 셸에서
직접 추론하면 모델-정책 발화 지점을 통째로 우회한다.

**R (Research) 템플릿**:
```
Phase R — Research. 먼저 C:/Users/12132/.claude/docs/ai-context/orca-worker-contract.md 를
읽어라(절대경로 — 자동 상속되지 않는다). 탐색은 이 셸에서 직접 하지 말고 반드시
Agent(subagent_type="explore-strict", task="<이 사이클의 탐색 명세 한 문장>",
context_paths=["docs/superpowers/specs/<관련 spec>.md","CONTEXT.md"],
success_criteria="<측정 가능한 기준>") 로 위임하라(권유 아님 — 명령).
docs/superpowers/specs/ 의 관련 durable spec(또는 재사용 대상)을 읽고 CONTEXT.md 어휘와
정합하는지 확인하라. spec delta 가 있으면 즉시 상신(orchestration ask)하고,
없으면 "spec 재확인, delta 없음(no-op)" 을 결과에 명시하라.
완료 시 worker_done --outcome succeeded|failed(보고 첫 줄의 PASS/FAIL 을 그대로 따른다) --body "<3문장 요약>"
--files-modified "<변경파일 CSV>" --phase R.
```

**P (Plan) 템플릿**:
```
Phase P — Plan. 먼저 C:/Users/12132/.claude/docs/ai-context/orca-worker-contract.md 를
읽어라(절대경로 — 자동 상속되지 않는다). plan 집필은 이 셸에서 직접 하지 말고 반드시
Agent(subagent_type="execute-strict", task="superpowers:writing-plans 절차로 plan 을 집필",
context_paths=["docs/superpowers/specs/<관련 spec>.md","<R 결과 경로>"],
success_criteria="<plan 완결 기준>") 로 위임하고, Gate P 판정은 반드시
Agent(subagent_type="review-strict", task="plan 을 Gate P 기준으로 판정",
context_paths=["docs/superpowers/plans/<작성한 plan>.md"],
success_criteria="PASS/FAIL 과 근거") 로 위임하라(권유 아님 — 명령).
superpowers:writing-plans 절차로 docs/superpowers/plans/ 에 plan 을 작성하라.
Best-Direction Check 필드 필수(DOWNGRADE-DECLARED 없으면 "없음" 명시). 완료 시
worker_done --outcome succeeded|failed(Gate P 가 FAIL 이면 failed — 본문에만 적지 말 것)
--body "<3문장 요약>" --report-path "<plan 경로>" --phase P.
```

**I (Implement) 템플릿**:
```
Phase I — Implement. 먼저 C:/Users/12132/.claude/docs/ai-context/orca-worker-contract.md 를
읽어라(절대경로 — 자동 상속되지 않는다). 구현은 이 셸에서 직접 하지 말고 반드시
Workflow({scriptPath: "C:/Users/12132/.claude/workflows/rpi-implement.js",
args: [<plan task 배열>]}) 로 위임하라 — 2-stage execute→review canonical 캐리어다
(권유 아님 — 명령). plan 의 미완료 task 를 순서대로 구현하라. 각 task 는 TDD(RED 확인 →
구현 → GREEN 확인)로 진행하고 커밋하라. 완료 시 worker_done --outcome succeeded|failed
--body "<변경·발견·잔여 3문장>" --files-modified "<CSV>" --phase I. 실패 시 반드시
--outcome failed(본문에만 실패를 적지 말 것).
```

**C (Closeout) 템플릿**:
```
Phase C — Closeout. 먼저 C:/Users/12132/.claude/docs/ai-context/orca-worker-contract.md 를
읽어라(절대경로 — 자동 상속되지 않는다). plan 체크박스 전부 [x] 확인,
CONTEXT.md/non-obvious.md 갱신 여부 점검, bash setup/verify-setup.sh 실행해 PASS/FAIL 보고.
RPI_SKIP 사후 탐지: 이 사이클 시간창에 해당하는 ~/.claude/hooks/.log/<YYYY-MM>.log 줄에서
"skip:" 카운트가 0 인지 단언하고 그 수치를 결과에 적어라(RPI_SKIP 은 워커가 자기 env 를
소유하므로 예방 불가 — 탐지로 보완한다). 위 점검의 판정 부분은 이 셸에서 직접 내리지 말고 반드시
Agent(subagent_type="review-strict", task="Closeout 점검 결과를 판정",
context_paths=["docs/superpowers/plans/<현재 plan>.md","CONTEXT.md"],
success_criteria="PASS/FAIL 과 근거") 로 위임하라(권유 아님 — 명령). 완료 시
worker_done --outcome succeeded|failed(보고 첫 줄의 PASS/FAIL 을 그대로 따른다 —
verify-setup.sh 가 FAIL 이면 --outcome failed) --body "<3문장 요약>" --phase C.
머지 승인은 코디네이터가 사람에게 AskUserQuestion 으로 묻는다 — 이 워커는 머지를 결정하지 않는다.
```

# Phase 2 — 워커 기동 (spawn 최초 1회, 이후 handoff)

```bash
D_R=$(bin/orca-rpi.sh spawn --run "$RUN" --task "$T_R" --worktree current)
```

R 완료(`worker_done`) 후, 같은 터미널을 재사용해 다음 Phase 로 넘긴다(`--model`/`--effort` 와
배타 — 설계 §3.5). `handoff` 의 stdout 은 새 dispatch id 1줄이며, **원장 교체를 위해 `--prev-task` 가
사실상 필수**다(원장이 비어있지 않은데 `--prev-task` 가 없으면 캐리어가 거부한다):

```bash
D_P=$(bin/orca-rpi.sh handoff --dispatch "$D_R" --task "$T_P" --prev-task "$T_R")
D_I=$(bin/orca-rpi.sh handoff --dispatch "$D_P" --task "$T_I" --prev-task "$T_P")
D_C=$(bin/orca-rpi.sh handoff --dispatch "$D_I" --task "$T_C" --prev-task "$T_I")
```

# Phase 3 — 대기 (블로킹, sleep 루프 금지)

각 Phase 스폰/handoff 직후:

```bash
bin/orca-rpi.sh wait --run "$RUN" --timeout-ms 900000
```

`wait` 는 `worker_done`/`escalation`/`question`/`decision_gate` 배치를 반환한다. **`wait` 는 이전 배치를
자동으로 `--ack` 한다** — 호출자는 ack 를 신경 쓰지 않는다(가이드: ack 하기 전까지 같은 Delivery 가 무한
재생된다). 응답 파싱에 실패하면 `wait` 는 비-0 을 반환한다(빈 출력 + rc=0 으로 위장하지 않는다) — 비-0 은
체크포인트가 아니라 사고이므로 사용자에게 보고한다.

- **`question`/`decision_gate`**: 코디네이터가 **orca.exe 절대경로**로 직접 답한 뒤 다시 `wait` 를 호출한다.
  `bin/orca-rpi.sh` 는 스폰 캐리어이지 유일한 orca 호출 지점이 아니며, 맨 `orca` 가 `orca.cmd` 로 해소되는
  설치가 실재하고 `orca.cmd` 는 `send|reply` 를 `exit /b 2` 로 거부한다:

  ```bash
  "C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe" orchestration reply \
    --id <msg_id> --body "<답>" --json
  ```

- **`worker_done --outcome succeeded`**: 그 Phase 를 완료로 기록하고 다음 Phase 로 진행한다.
- **`worker_done --outcome failed`**: **DAG 를 전진시키지 않는다.** 실패한 구현으로 다음 Phase 를 시작하지
  말고, 사용자에게 실패 본문을 보고하고 재작업(같은 Task 재스폰 `spawn --retry-of <dispatch_id>`) 여부를
  결정받는다.
- **timeout / 빈 배치**: 통상 정상 체크포인트다(코딩 작업은 15-60분이 정상 — 계속 대기). 단 **터미널이
  종료·소멸하면 무한 대기가 된다** — 가이드 verbatim: *"keep using rolling waits unless you receive
  `worker_done`/`escalation`, **the terminal exits or disappears**, or the user explicitly asks you to
  stop."* 따라서 **연속 3회 timeout 이면** 생존을 확인한다:

  캐리어에는 `worker-show` 서브커맨드가 **없다**(`preflight`·`run`·`task`·`spawn`·`wait`·`handoff`·
  `release`·`gate`·`gpt`·`selfcheck` 뿐 — 그 외는 `die`). 생존 확인은 **read-only 조회**(레코드를 만들거나
  상태를 바꾸지 않는다)이므로 캐리어 강제 대상이 아니며, 위 `reply` 와 같이 **orca.exe 절대경로**로 직접 부른다:

  ```bash
  "C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe" orchestration worker-show \
    --dispatch "$D_R" --json
  ```

  터미널이 소멸했으면 대기를 끝내고(추가 `wait` 금지) 어느 Phase 에서 소멸했는지 사용자에게 보고한다.

# Phase 4 — read-only 리뷰 팬아웃 (C 완료 후, 유일한 병렬 축)

```bash
T_V1=$(bin/orca-rpi.sh task --title "V1: 설계층 적대리뷰" --spec "$V1_SPEC" --deps "[\"$T_C\"]")
T_V2=$(bin/orca-rpi.sh task --title "V2: 코드층 적대리뷰" --spec "$V2_SPEC" --deps "[\"$T_C\"]")
D_V1=$(bin/orca-rpi.sh spawn --run "$RUN" --task "$T_V1" --worktree current --readonly)
D_V2=$(bin/orca-rpi.sh spawn --run "$RUN" --task "$T_V2" --worktree current --readonly)
```

**두 dispatch 가 모두 settle 할 때까지 `wait` 를 반복한다** — `wait` 한 번은 먼저 끝난 쪽만 수확하므로,
한 번만 호출하고 Phase 5 로 가면 나머지 리뷰 결과를 통째로 잃는다:

```bash
# V1/V2 각각의 worker_done 을 받을 때까지 반복 (Phase 3 의 실패·소멸 분기 동일 적용)
bin/orca-rpi.sh wait --run "$RUN" --timeout-ms 1800000
bin/orca-rpi.sh wait --run "$RUN" --timeout-ms 1800000
```

`--readonly` 는 캐리어 **로컬 카운터**(non-readonly 동시-1 상한)를 우회하는 **선언**이며, Orca 가 강제하는
read-only 샌드박스가 아니다 — 플래그는 Orca 에 전달되지 않고, 권한 제한도 Task 내용 검증도 없다. 순전히
코디네이터의 자기-선언이다. 병렬 안전성은 **Task spec 이 실제로 read-only 인지**에 달려 있고 그 판단은
코디네이터 책임이다(Orca 는 충돌을 추론하지 않는다, 설계 §3.6). read-only 팬아웃은 이 캐리어의 유일한
병렬 축이다.

**V1(설계층) 템플릿**:
```
먼저 C:/Users/12132/.claude/docs/ai-context/orca-worker-contract.md 를 읽어라(자동 상속되지 않는다).
V1(설계층): spec delta + plan 을 적대적으로 검토하라(refute-by-default). read-only.
판정은 Agent(subagent_type="review-strict", task="설계층 적대 리뷰", context_paths=[<spec>, <plan>],
success_criteria="PASS only if ... / FAIL with 발견 목록") 로 위임하라 — 워커 셸에서 직접 판정하지 말 것.
발견마다 원문 인용 + 실측 대조. worker_done --outcome succeeded|failed --body "<발견 N건 요약>" --phase V1.
```

**V2(코드층) 템플릿**:
```
먼저 C:/Users/12132/.claude/docs/ai-context/orca-worker-contract.md 를 읽어라(자동 상속되지 않는다).
V2(코드층): 이번 사이클 diff 를 적대적으로 검토하라(refute-by-default). read-only.
판정은 Agent(subagent_type="review-strict", task="코드층 적대 리뷰", context_paths=[<변경 파일들>],
success_criteria="PASS only if ... / FAIL with 발견 목록") 로 위임하라 — 워커 셸에서 직접 판정하지 말 것.
발견마다 파일:줄 인용. worker_done --outcome succeeded|failed --body "<발견 N건 요약>" --phase V2.
```

# Phase 5 — 정리 + 머지 승인 (사람 소유)

```bash
bin/orca-rpi.sh release --dispatch "$D_R" --task "$T_R"
bin/orca-rpi.sh release --dispatch "$D_P" --task "$T_P"
bin/orca-rpi.sh release --dispatch "$D_I" --task "$T_I"
bin/orca-rpi.sh release --dispatch "$D_C" --task "$T_C"
bin/orca-rpi.sh release --dispatch "$D_V1" --task "$T_V1"
bin/orca-rpi.sh release --dispatch "$D_V2" --task "$T_V2"
```

R/P/I 도 빠짐없이 release 한다(멱등 — 이미 release 된 dispatch 재호출은 무해). **정직 부기**:
`worker-release` 는 verbatim *"Never closes … reused or pre-existing terminals"* 이므로, `handoff` 로
재사용된 터미널(R→P→I→C 체인)은 **닫히지 않는다** — release 가 보장하는 것은 아카이브 보존뿐이다.

**머지 승인은 항상 `AskUserQuestion`(사람) — 절대 `bin/orca-rpi.sh gate` 로 대체하지 않는다.**
이유는 승인 채널이 층으로 분리돼 있기 때문이다(CONTEXT.md [[승인 채널 층 분리]]):

| 층 | 채널 |
|---|---|
| 워커(dispatched) | `orchestration ask` / `decision_gate` — preamble RULE#1 이 `AskUserQuestion` 을 금지한다(워커의 TUI 는 아무도 못 본다) |
| 코디네이터(사람과 같은 화면, 이 skill 을 실행 중인 세션) | **`AskUserQuestion`** — 머지 승인은 사람 소유 |

`bin/orca-rpi.sh gate` 는 코디네이터가 소유하는 DAG 판정(예: Gate P PASS/FAIL)에만 쓴다 — 사람에게
묻는 용도가 아니다. 이 구분을 혼동하면 워커가 영구 hang 하거나 머지가 무승인으로 처리된다.

## Communication Protocol
- result: COMPLETE / FAIL / FALLBACK(Orca 미가동 — 기존 (a)/(d) 경로로 진행함)
- evidence: Run id · Task 4개(R/P/I/C) + V1/V2 id · 각 Phase 의 `worker_done` 요약 3문장 ·
  `release` 결과(settings.json 무변경 diff 포함)
- unknowns: preflight 가 rc=3 을 낸 사유(orca 미가동/repo 미등록/plan 부재 등)를 사용자에게 보고
