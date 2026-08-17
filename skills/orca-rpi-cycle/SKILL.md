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
```

- **rc=0**: Orca 가동·orchestration 도달·`worktree current`·plan 실재·settings 백업 전부 확인됨 — Phase 1 로 진행.
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

**R (Research) 템플릿**:
```
Phase R — Research. docs/superpowers/specs/ 의 관련 durable spec(또는 재사용 대상)을 읽고
CONTEXT.md 어휘와 정합하는지 확인하라. spec delta 가 있으면 즉시 상신(orchestration ask)하고,
없으면 "spec 재확인, delta 없음(no-op)" 을 결과에 명시하라. AskUserQuestion 사용 금지 —
질문은 orchestration ask 로. 완료 시 worker_done --outcome succeeded --body "<3문장 요약>"
--files-modified "<변경파일 CSV>" --phase R.
```

**P (Plan) 템플릿**:
```
Phase P — Plan. superpowers:writing-plans 절차로 docs/superpowers/plans/ 에 plan 을 작성하라.
Best-Direction Check 필드 필수(DOWNGRADE-DECLARED 없으면 "없음" 명시). 완료 시
worker_done --outcome succeeded --body "<3문장 요약>" --report-path "<plan 경로>" --phase P.
```

**I (Implement) 템플릿**:
```
Phase I — Implement. plan 의 미완료 task 를 순서대로 구현하라. 각 task 는 TDD(RED 확인 →
구현 → GREEN 확인)로 진행하고 커밋하라. 완료 시 worker_done --outcome succeeded|failed
--body "<변경·발견·잔여 3문장>" --files-modified "<CSV>" --phase I. 실패 시 반드시
--outcome failed(본문에만 실패를 적지 말 것).
```

**C (Closeout) 템플릿**:
```
Phase C — Closeout. plan 체크박스 전부 [x] 확인, CONTEXT.md/non-obvious.md 갱신 여부 점검,
bash setup/verify-setup.sh 실행해 PASS/FAIL 보고. 완료 시 worker_done --outcome succeeded
--body "<3문장 요약>" --phase C. 머지 승인은 코디네이터가 사람에게 AskUserQuestion 으로 묻는다 —
이 워커는 머지를 결정하지 않는다.
```

# Phase 2 — 워커 기동 (spawn 최초 1회, 이후 handoff)

```bash
D_R=$(bin/orca-rpi.sh spawn --run "$RUN" --task "$T_R" --worktree current)
```

R 완료(`worker_done`) 후, 같은 터미널을 재사용해 다음 Phase 로 넘긴다(`--model`/`--effort` 와
배타 — 설계 §3.5):

```bash
D_P=$(bin/orca-rpi.sh handoff --dispatch "$D_R" --task "$T_P")
D_I=$(bin/orca-rpi.sh handoff --dispatch "$D_P" --task "$T_I")
D_C=$(bin/orca-rpi.sh handoff --dispatch "$D_I" --task "$T_C")
```

# Phase 3 — 대기 (블로킹, sleep 루프 금지)

각 Phase 스폰/handoff 직후:

```bash
bin/orca-rpi.sh wait --run "$RUN" --timeout-ms 900000
```

`wait` 는 `worker_done`/`escalation`/`question` 배치를 반환한다. `question` 이 오면 코디네이터가
`orca orchestration reply --id <msg_id> --body "<답>" --json` 로 답한 뒤 다시 `wait` 를 호출한다.
timeout 이나 빈 배치는 정상 체크포인트다(코딩 작업은 15-60분이 정상 — 계속 대기).
`worker_done` 을 받으면 그 Phase 를 완료로 기록하고 다음 Phase 로 진행한다.

# Phase 4 — read-only 리뷰 팬아웃 (C 완료 후, 유일한 병렬 축)

```bash
T_V1=$(bin/orca-rpi.sh task --title "V1: 설계층 적대리뷰" --spec "$V1_SPEC" --deps "[\"$T_C\"]")
T_V2=$(bin/orca-rpi.sh task --title "V2: 코드층 적대리뷰" --spec "$V2_SPEC" --deps "[\"$T_C\"]")
bin/orca-rpi.sh spawn --run "$RUN" --task "$T_V1" --worktree current --readonly
bin/orca-rpi.sh spawn --run "$RUN" --task "$T_V2" --worktree current --readonly
bin/orca-rpi.sh wait --run "$RUN" --timeout-ms 1800000
```

`--readonly` 는 non-readonly 동시-1 상한을 우회한다 — read-only 팬아웃만이 이 캐리어의 유일한
병렬 축이다(Orca 는 충돌을 추론하지 않으므로 동시 편집 안전은 캐리어 책임, 설계 §3.6).

**V1(설계층) 템플릿**:
```
V1(설계층): spec delta + plan 을 적대적으로 검토하라(refute-by-default). read-only.
발견마다 원문 인용 + 실측 대조. worker_done --outcome succeeded --body "<발견 N건 요약>" --phase V1.
```

**V2(코드층) 템플릿**:
```
V2(코드층): 이번 사이클 diff 를 적대적으로 검토하라(refute-by-default). read-only.
발견마다 파일:줄 인용. worker_done --outcome succeeded --body "<발견 N건 요약>" --phase V2.
```

# Phase 5 — 정리 + 머지 승인 (사람 소유)

```bash
bin/orca-rpi.sh release --dispatch "$D_C" --task "$T_C"
bin/orca-rpi.sh release --dispatch "<V1 dispatch>" --task "$T_V1"
bin/orca-rpi.sh release --dispatch "<V2 dispatch>" --task "$T_V2"
```

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
