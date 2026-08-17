# C23 — Orca 캐리어 자기-적용 + 부작용 경계의 코드화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active
**RPI-Cycle:** 74
**Started:** 2026-08-18

**Goal:** C22 가 만든 스폰 캐리어를 C23 자신에게 처음 적용해 미측정 응답 shape 를 실측으로 해제하고,
그 과정에서 드러난 부작용 경계(브랜치 가드 · 검증-전용 경로 · 주입 seal)를 문서에서 코드로 옮긴다.

**Architecture:** 세 층으로 나뉜다. ⓐ **라이브 측정**(Task 1) — read-only 워커 1기동으로 4종 필드 경로를
확정하고 `[P2]` 를 해제한다. ⓑ **캐리어 경화**(Task 2~4) — 브랜치 가드 · `ORCA_RPI_DRYRUN` ·
`--retry-request`/원장을 캐리어 코드에 넣는다. ⓒ **검사자 배정**(Task 5~7) — 새 불변식마다 코드 검사자를
붙인다(STAGE 2e 테스트 · seal #53 · seal-regression 뮤테이터). 마지막으로 배포·문서 착륙(Task 8~10)을 한다.

**Tech Stack:** bash(POSIX + bash 배열) · awk(어휘 스캐너) · jq · git · Orca ADE CLI(`orca.exe`)

**Spec:** `docs/ai-context/c21-orca-mode-design.md` — 특히 **§11.10**(C23 설계 결정 ①~⑨, **6차 정정 판본**
= 교차패밀리 슬롯 1 트리아지 채택 30건 반영분).
보조: `docs/ai-context/c22-orca-probe-measured.md`(P0 실측 SSOT) · `docs/ai-context/non-obvious.md` #5 ·
`docs/superpowers/specs/2026-07-25-model-policy-design.md` §18.1·§19.5.

**Best-Direction Check:** 최선안 = 「부작용 경계를 **코드로** 강제하고, 각 불변식마다 **코드 검사자**를
배정하며, 미측정 필드는 **실측으로만** 해제한다」 / 채택안 = 동일.
**DOWNGRADE-DECLARED: 없음.**
근거: 더 쉬운 대안 3종을 모두 기각했다 — ⓐ 브랜치 가드를 SKILL.md 지시문에 두기(C22 가 이미 그렇게 했고
실패했다 — §11.10 ①) ⓑ `[P2]` 를 코드 독해로 추정 해제(추정을 실측으로 표기하는 것이 이 사이클이
교정 중인 클래스) ⓒ seal #53 을 파일 스코프로 두기(토큰 1개가 파일 전체를 세탁 — [[판별력 공백]]).
스코프는 goal 이 정한 범위(A·B·C·D)로 한정하며 T6~T14·T20/T21 은 무접촉이다(스코프 축소는 열화가 아니다).

---

## Global Constraints

이 절의 요구는 **모든 task 에 암묵적으로 포함**된다. 값은 spec/goal 에서 verbatim 복사했다.

1. **라이브 Orca CLI 도달 금지(Task 1 제외)** — 모든 검증 명령은 `ORCA_RPI_DRYRUN=1` 또는
   (`ORCA_CLI_COMMAND=<stub>` **및** `ORCA_RPI_RUNDIR=<임시>`)로 격리한다.
   Task 1 만이 **의도-라이브**이며 그 블록에는 `LIVE-INTENT(<사유>)` 가 붙어 있다.
   ★**이 제약이 세는 것은 「라이브 Orca 도달」이지 「stub 로그 줄 수」가 아니다**(슬롯 1 E3 정정).
   stub 로그의 기대 줄 수는 **각 Step 의 Expected 가 정한다** — 가드가 발화해야 하는 경로는 0줄,
   가드 부재를 실증하는 RED(Task 2 Step 1)와 정상 발행 양성 대조(Task 2 Step 5 feature 아암)는 **1줄**이
   정답이다. 초안은 「부작용 로그 0줄을 단언한다」를 전역 요구로 적어, 자기 plan 의 RED 와 결정적으로
   충돌했다. 어느 쪽이든 라이브 Orca 에는 도달하지 않는다(stub 이 흡수).
2. **되돌릴 수 없음** — `run-delete`/`task-delete` 가 부재하고 `orchestration reset` 계열은 **금지**다.
   생성하는 Run/Task 는 영구 잔존하므로 objective/title 에 `[C23]` 를 반드시 박는다.
3. **`orca agent hooks off` 발행 금지** · **CCS cliproxy 제거 금지** ·
   **CCS 심볼릭링크 3종**(`skills/ccs-delegation`, `commands/ccs`, `commands/ccs.md`) **불가침**.
4. **설치·로그인·인증·업데이트 시도 절대 금지**(`cross-family-review.md:15`) — mode-pack 설치 포함.
   ⇒ `setup/install.sh` 는 **전체 실행하지 않는다**(`setup/doctor.sh:235-260` 이 `gh api` 로 skill 을
   자동 설치한다). 검증은 REQUIRED 계약 + `bash -n` + seal #29 로 한다(Task 8).
5. **머지는 사용자 명시 승인 없이 금지**(AskUserQuestion). 단 **워커 세션에서는 AskUserQuestion 금지**
   (영구 hang) — `orchestration ask`/`decision_gate` 사용.
6. **seal-regression 실행 중 `~/.claude` 편집 금지** — witness cksum 불변이 물리 전제다(C21 26/1 전례).
7. **혼합 개행 파일은 `Edit` 금지** — `docs/superpowers/specs/2026-07-25-model-policy-design.md`
   (CR=1823) · `docs/ai-context/c21-orca-mode-design.md`(CR=728). 막으려는 위해는 **도구 이름이 아니라
   in-place 전-파일 재작성**이다(`Edit` 은 전 파일을 LF 로 통일해 거대한 거짓 diff 를 만든다). 따라서
   허용 수단은 **말미 append(`cat >> …`)** 또는 **`perl -0777 -i`** 둘 다이며, append 는 O_APPEND 라
   기존 바이트를 건드리지 않아 CR 수가 보존된다(슬롯 1 E5 정정 — 초안의 「`perl` 만」은 Task 10 문면과
   충돌했다). CR 계수는 `perl -ne '$n++ if /\r/; END{print "$n\n"}'` 만 신뢰한다(`grep -c` 는 MSYS 에서
   조용히 틀린다).
8. **경로는 argv/stdin 으로 전달** — 인라인 인터프리터 소스에 셸 변수 보간·리터럴 `/tmp/` 금지(non-obvious #3, seal #52).
9. **기준선**: `setup/verify-setup.sh` 90 PASS / 0 FAIL · `hooks/tests/run-all.sh` 305/305 ·
   `setup/tests/seal-regression.test.sh` 27/0. **Task 6** 이 verify-setup 을 90→**91**(seal #53 1건),
   **Task 7** 이 seal-regression 을 27→**29**(뮤테이터 2건) 로 올린다.
10. **범위 밖**: T6~T14 · T20/T21. 특히 `modes/`·`setup/lib/modepack-oracle.sh` 삭제는 T10~T12 와
    같은 커밋이어야 하므로 **무접촉**.

**LIVE-INTENT-총계: 4**

(Task 1 의 Step 2·3·4·5 각 1단위. seal #53 이 이 선언과 실측을 대조한다 — 자기-면제를 파일 안에서
표면화하는 장치이며, 같은 커밋에서 총계를 함께 올리면 통과하는 **자기-정합 검사**다(선언된 상한).)

---

## File Structure

| 파일 | 책임 | 처분 |
|---|---|---|
| `bin/orca-rpi.sh` | 스폰 캐리어 — 경계를 코드로 강제 | 수정(Task 1·2·3·4) |
| `setup/tests/orca-carrier.test.sh` | §11.10 ② 불변식의 코드 검사자(DRYRUN 존중 전수) | **신설**(Task 5) |
| `setup/verify-all.sh` | 인수 게이트 파이프라인 | 수정 — STAGE 2e 배선(Task 5) |
| `setup/verify-setup.sh` | L3 드리프트 seal 모음 | 수정 — seal #53 추가(Task 6) |
| `setup/tests/seal-regression.test.sh` | seal 이 실제로 발화함을 변이로 증명 | 수정 — 뮤테이터 2 + witness(Task 7) |
| `README.md` | verify-setup 카운트 SSOT(`현재 N PASS`) | 수정 — 90→91(Task 6) |
| `setup/install.sh` | 배포 계약(REQUIRED + 실행 비트) | 수정(Task 8) |
| `skills/start-rpi-cycle/SKILL.md` | RPI 절차 정본 | 수정 — 옵션 (e) + §19.5 조항(Task 9) |
| `opencode-harness/skill/start-rpi-cycle/SKILL.md` | 위 파일의 opencode 미러 | 수정 — 동반(Task 9) |
| `docs/ai-context/c22-orca-probe-measured.md` | Orca 응답 shape 실측 SSOT | append(Task 1·3) |
| `docs/ai-context/scaffold-registry.md` | 스캐폴드 노화 방지 대장 | append(Task 5) |
| `docs/ai-context/review-yield.md` | 층별 리뷰 수율 글로벌 대장 | append(Task 10) |
| `docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md` | C22 실행 기록 | 부기 1줄(Task 6) |

---

## Task 1: Orca 라이브 측정 — `[P2]` 4종 해제

**Files:**
- Modify(**마커 해제**): `bin/orca-rpi.sh:232,234` (spawn dispatch id) · `:296,298` (wait delivery id) ·
  `:323,326` (worker-show handle) · `:411,413` (gate id) — **8사이트 / 4종 중 3종**
- Modify(**마커 유지 + 사유 명시**): `:352,353` (handoff dispatch id) — **2사이트**. handoff 를 호출하지
  않으므로 미측정이며, 「전부 해제」로 쓰면 추정을 실측으로 승격한다(슬롯 1 A6 · spec §11.10 ⑤).
  goal 의 success criteria 「최소 3종」은 이 처분으로 충족된다(dispatch id·delivery id·handle·gate id 중
  spawn 축 dispatch id + delivery id + handle + gate id = 실측 대상 4종 전부가 Step 4/5 로 관측되고,
  미해제로 남는 것은 *같은 종의 다른 사이트*다).
- Modify: `docs/ai-context/c22-orca-probe-measured.md` (append — 새 파일 금지)

**Interfaces:**
- Consumes: 없음(첫 task)
- Produces: 실측 확정된 jq 경로 4종. Task 2~4 는 같은 파일을 편집하므로 **이 task 이후 순차 실행**한다.

- [ ] **Step 1: 스테일 원장 슬롯 해제 (증거 먼저 기록)**

C22 의 stub 검증이 라이브 `$HOME/.claude/.orca-rpi` 에 직접 써서 `t1` 이 남아 있다(§11.10 ②).
그대로 두면 C23 의 첫 non-readonly spawn 이 상한 초과로 거부된다. 지우기 **전에** 상태를 남긴다.

```bash
cd "$HOME/.claude"
# ★파괴 전 전제 확인 두 가지 — 순서가 load-bearing 이다(슬롯 1 D4·D5)
BR=$(git rev-parse --abbrev-ref HEAD); echo "branch=$BR"
case "$BR" in master|main) echo "✗ 머지 대상 브랜치 — 이 task 를 실행하지 않는다"; exit 1 ;; esac
echo "--- BEFORE ---"; ls -la .orca-rpi/; cat .orca-rpi/active-nonreadonly.tasks
grep -qx 't1' .orca-rpi/active-nonreadonly.tasks \
  || { echo "✗ 원장 내용이 예상(t1)과 다르다 — 실제 활성 task 일 수 있으므로 지우지 않는다"; exit 1; }
cp .orca-rpi/active-nonreadonly.tasks "$HOME/.claude/.orca-rpi/stale-t1.evidence" \
  || { echo "✗ 증거 복사 실패 — 원장을 건드리지 않는다"; exit 1; }
: > .orca-rpi/active-nonreadonly.tasks
echo "--- AFTER ---"; wc -l < .orca-rpi/active-nonreadonly.tasks
```

Expected: `branch=orca-cycle-23` · BEFORE 에 `t1` 1줄 · AFTER 에 `0`. 이 출력을 Step 8 의 probe 문서
append 에 인용한다.
★세 가드가 **truncation 앞**에 있어야 하는 이유: 초안은 브랜치 확인을 Step 2 에, 내용 확인을 사후
육안 대조에 뒀고 `cp` 의 rc 도 안 봤다. 그러면 「master 라서 중단」하기 *전에* 이미 라이브 동시-1 원장을
0바이트로 만든 상태가 되고, 내용이 예상과 달라도(=진짜 활성 task) 되돌릴 근거가 사라진다. 지우는 것은
라이브 안전 원장이므로 **파괴적 줄 앞에 전제를 세운다.**

- [ ] **Step 2: `--help` 실측(부작용 0) → preflight (라이브 · rc=0 확인)**

★**먼저 `--help` 실측을 끝낸다**(슬롯 1 A5·D2). Task 4 의 배선 범위는 이 프로브의 산출물에 종속되는데,
`--help` 는 **로컬 CLI 만으로 실행 가능**하고 부작용이 0 이다. 초안은 이것을 Step 5 말미에 뒀고 Step 2 는
「rc≠0 이면 중단」이라, Orca 데몬만 내려가 있어도 Task 4 가 입력 없이 시작하게 돼 있었다.

```bash
cd "$HOME/.claude"
ORCA="C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe"
for c in run-create task-create worker-start gate-create check; do
  echo "=== $c ==="; "$ORCA" orchestration "$c" --help 2>&1 | grep -iE 'retry-request|exact recovery' || echo "(없음)"
done
```

이 출력은 Step 8 의 probe 문서 append 에 **원문 그대로** 넣는다(§11.10 ④ — 현재 repo 안에 help 원문이
없다). `orca.exe` 자체가 없어 이 루프가 전부 실패하면 그 사실을 기록하고, Task 4 의 `--retry-request`
배선은 **이미 실측된 2개 명령(`run-create`·`worker-start`)에 한정**한 채 나머지는 미확인으로 남긴다.
(위 블록은 캐리어 호출이 아니라 `$ORCA` 직접 호출이며 `--help` 라 부작용 0 이다 — seal #53 의 선언된
미탐 잔여 ⓐ 에 해당하고, `LIVE-INTENT` 대상도 아니다.)

여기부터가 라이브다:
`LIVE-INTENT(응답 shape 실측이 이 사이클의 주축 산출물 — 스텁으로는 측정 불가)`

```bash
cd "$HOME/.claude"
bash bin/orca-rpi.sh preflight; echo "rc=$?"
cat .orca-rpi/wt_sel; echo
```

Expected: `preflight: OK worktree=<repoId>::<path>` + `rc=0`.
**rc≠0 이면 자동 재시도 금지** — 이 task 를 여기서 중단하고
`docs/ai-context/c22-orca-probe-measured.md` 에 「preflight rc=<값>, 미측정 사유」를 append 한 뒤
Task 2 로 넘어간다(goal: 실패해도 원문 기록이 산출물이다).
★rc 값의 의미가 둘로 갈린다(실측): **rc=3 = Orca 설치돼 있으나 미가동/전제 미충족**(status 실패 ·
`no active plan` 등 8종), **rc=1 = `assert_orca_exe` 탈락 = 실행자 부재·경로 오지정**. 둘 다 중단
사유이며, 「rc=3 만 취급」하면 미설치 머신이 처분 밖에 놓인다(슬롯 1 A8 — Task 9 의 옵션 (e) 문면도
같은 이유로 rc≠0 으로 쓴다).

- [ ] **Step 3: Run + Task 생성 (라이브)**

`LIVE-INTENT(dispatch/delivery/handle/gate 4종 필드 경로는 실 워커 없이는 확인 불가)`

```bash
cd "$HOME/.claude"
RUN=$(bash bin/orca-rpi.sh run --objective "[C23] carrier self-application probe — response shape measurement"); echo "RUN=$RUN"
SPEC='[C23] PROBE (read-only). 먼저 C:/Users/12132/.claude/docs/ai-context/orca-worker-contract.md 를 읽어라(절대경로 — 자동 상속되지 않는다). 이 Task 는 read-only 다: 파일 생성·수정 금지, git 상태 변경 금지, 설치·인증 금지. 수행할 일은 정확히 둘이다. (1) C:/Users/12132/.claude/bin/orca-rpi.sh 의 첫 줄을 읽어 그대로 인용한다. (2) 그 인용의 정확성 판정을 Agent(subagent_type="review-strict", task="인용이 파일 첫 줄과 byte-일치하는지 확인", context_paths=["C:/Users/12132/.claude/bin/orca-rpi.sh"], success_criteria="PASS only if byte-일치") 로 위임한다 — 권유가 아니라 명령이다. 완료 즉시 preamble 이 준 taskId/dispatchId 로 worker_done 을 발행하라: "C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe" orchestration send --type worker_done --subject "Phase PROBE: PASS" --body "<3문장 요약>" --task-id "<taskId>" --dispatch-id "<dispatchId>" --outcome succeeded --phase PROBE --json . AskUserQuestion 금지(영구 hang) — 물을 것이 있으면 orchestration ask 를 쓴다. worker_done 이후 추가 행동 금지.'
TASK=$(bash bin/orca-rpi.sh task --title "[C23] PROBE read-only shape measurement" --spec "$SPEC" --run "$RUN"); echo "TASK=$TASK"
jq '{envelope_id: .id, mutation_requestId: .result.mutation.requestId, run_id: .result.run.id}' .orca-rpi/last-run-create.json
```

Expected: `RUN=run_…` · `TASK=task_…` · 마지막 jq 가 `.id`(요청 상관ID)와 `.result.run.id`(진짜 run id)가
**다름**을 보인다(c22-probe P0-2 재확인). 셋 중 하나라도 비면 그 원문을 그대로 기록하고 중단한다.

★**부분 실패 시 이 Step 을 재실행하지 않는다**(슬롯 1 D6). `run-create` 가 서버에서 커밋된 뒤 응답이
끊기거나 후속 `task-create` 가 실패한 상태에서 다시 돌리면 **삭제 불가능한 `[C23]` Run 이 2개**가 된다.
멱등 재발행 수단(`--retry-request`)은 **Task 4 에서야 착륙**하고 그 배선의 입력이 바로 이 측정이라,
이 부트스트랩 순환은 순서를 바꿔 풀 수 없다. 따라서 처분은 「원문을 기록하고 멈춘다」이며 이것은
「선언된 잔여 6」으로 명시돼 있다. 잔존물이 생기면 그 id 를 probe 문서에 남겨 다음 사이클이 식별할 수
있게 한다(`run-delete` 부재라 정리가 아니라 **기록**이 유일한 처분이다).

- [ ] **Step 4: 워커 spawn + 배치 수신 (라이브 — dispatch id · delivery id 측정)**

`LIVE-INTENT(worker-start/check 응답 shape 는 실 워커 기동으로만 관측된다)`

```bash
cd "$HOME/.claude"
D=$(bash bin/orca-rpi.sh spawn --run "$RUN" --task "$TASK" --worktree current --readonly); echo "DISPATCH=$D"
jq 'paths(scalars) as $p | select($p[-1]=="id") | {path: ($p|join(".")), value: getpath($p)}' .orca-rpi/last-worker-start.json
bash bin/orca-rpi.sh wait --run "$RUN" --timeout-ms 900000 > .orca-rpi/c23-wait.out; echo "rc=$?"
jq 'paths(scalars) as $p | select($p[-1]|test("^(id|deliveryId|delivery_id)$")) | {path: ($p|join(".")), value: getpath($p)}' .orca-rpi/last-check.json
```

Expected: `DISPATCH=` 가 비어 있지 않으면 `.result.dispatch.id` 추정이 **맞은 것**이고,
`spawn: dispatch id 추출 실패` 로 죽으면 **빗나간 것**이다 — 어느 쪽이든 위 `jq paths` 출력이
실제 경로를 준다. 그것이 이번 사이클의 최대 수확이다. `wait` 도 동일하게 판정한다.

★**빗나갔을 때의 복구 절차(슬롯 1 D7)** — `worker-start` 는 실 워커를 만든 **뒤** jq 추출에 실패하면
`die` 하므로 부작용은 이미 났고 `$D` 만 비어 있다. 그 상태로 Step 5 의 `release` 를 부르면
`release: --dispatch 필수` 로 즉사하고, `--readonly` 스폰이라 동시-1 슬롯도 잡히지 않아 **재실행이
워커를 증식**시킨다. 복구 데이터는 이미 손에 있다 — 위 `jq paths` 가 `last-worker-start.json` 의 실경로를
출력했다. 따라서 **재스폰하지 말고** 그 경로로 id 를 직접 뽑아 release 한다:

```bash
cd "$HOME/.claude"
jq -r '<위 출력이 알려준 실경로>' .orca-rpi/last-worker-start.json   # 예: .result.worker.dispatchId
D="$(jq -r '<그 실경로>' .orca-rpi/last-worker-start.json)"; echo "recovered DISPATCH=$D"
```

이 절차는 이미 출력 중인 데이터를 쓰는 것이라 스코프 확대가 아니다. `$D` 를 끝내 못 얻으면 워커가
살아 있는 채로 남으므로, 그 사실과 `last-worker-start.json` 전문을 probe 문서에 기록한다.

- [ ] **Step 5: handle · gate id 측정 + 릴리즈 (라이브)**

`LIVE-INTENT(worker-show handle 과 gate-create id 는 살아 있는 dispatch/task 위에서만 관측된다)`

```bash
cd "$HOME/.claude"
ORCA="C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe"
"$ORCA" orchestration worker-show --dispatch "$D" --json > .orca-rpi/c23-worker-show.json; echo "rc=$?"
jq 'paths(scalars) as $p | select($p[-1]|test("handle|terminal")) | {path: ($p|join(".")), value: getpath($p)}' .orca-rpi/c23-worker-show.json
G=$(bash bin/orca-rpi.sh gate create --task "$TASK" --question "[C23] PROBE gate id shape 측정"); echo "GATE=$G"
jq 'paths(scalars) as $p | select($p[-1]=="id") | {path: ($p|join(".")), value: getpath($p)}' .orca-rpi/last-gate-create.json
bash bin/orca-rpi.sh gate resolve --id "$G" --resolution PASS
bash bin/orca-rpi.sh release --dispatch "$D" --task "$TASK"; echo "release rc=$?"
```

Expected: handle 경로와 gate id 경로가 확정된다. `gate create` 가 **완료된 Task** 에서 거부되면
그 거부 원문을 기록하고 gate id 를 미해제로 남긴다(§11.10 ⑤ — 거절도 수확이다).
(`--retry-request` help 실측은 **Step 2 로 이동**했다 — 라이브 발행보다 먼저 끝내야 Task 4 가 입력을
갖는다.)

- [ ] **Step 6: `[P2]` 주석 제거 + 실경로 반영**

측정 결과가 추정과 **같으면** 주석만 지우고, **다르면** jq 경로를 실측값으로 바꾼다.

★**해제는 비대칭이다 — `handoff` 2사이트(`:352`·`:353`)는 남긴다**(슬롯 1 A6 · spec §11.10 ⑤).
Step 4/5 가 호출하는 것은 `spawn`·`wait`·`worker-show`·`gate` 뿐이고 **`handoff` 는 한 번도 호출하지
않는다**(호출하려면 워커를 한 기 더 띄워야 하고, 그것은 「read-only 1기동」이라는 이번 사이클의 라이브
예산을 넘는다). `handoff` 의 `worker-start --terminal` 응답이 agent 기반 `worker-start` 와 **동형이라는
보장이 없으므로**, 그 2사이트까지 마커를 떼면 **틀린 jq 경로를 실측값으로 승격**하게 된다. 침묵 잔여
금지의 올바른 이행은 「전부 해제」가 아니라 **마커 유지 + 사유 명시**다.

```bash
cd "$HOME/.claude"
perl -0777 -i -pe '
  # 해제군: spawn(:232,234) · wait(:296,298) · worker-show(:323,326) · gate(:411,413)
  s/^\s*# dispatch id 실제 응답 shape 미측정.*\n//m;
  s/^\s*# gate id 필드 경로 미측정.*\n//m;
  s/^\s*# worker\.agent_terminal_handle 실제 응답 shape 미측정.*\n//m;
  s/^\s*# delivery id 필드 경로 미측정.*\n//m;
  s/(\.result\.dispatch\.id \/\/ empty.\)\s*)#\s*\[P2\]$/$1# 실측(C23 Step 4)/m;
  s/(\.result\.delivery[^\n]*empty.[^\n]*?)\s*#\s*\[P2\]$/$1/m;
  s/(agent_terminal_handle[^\n]*empty.\)\s*)#\s*\[P2\]$/$1# 실측(C23 Step 5)/m;
  s/(\.result\.gate\.id \/\/ empty.\)\s*)#\s*\[P2\]$/$1# 실측(C23 Step 5)/m;
  # 유지군: handoff 2사이트 — 사유를 명시로 바꾼다
  s/^(\s*# stdout 계약 = dispatch id 1줄\(.*?\)) \[P2\]$/$1 [P2 미해제 사유: handoff 응답 미측정(C23) — terminal 기반 worker-start 가 agent 기반과 동형인지 미확인]/m;
  s/^(\s*local dispatch_id; dispatch_id=\$\(printf .%s. "\$hresp".*)#\s*\[P2\]$/$1# [P2 미해제: 위 사유]/m;
' bin/orca-rpi.sh
grep -n '\[P2' bin/orca-rpi.sh
bash -n bin/orca-rpi.sh && echo "bash -n OK"
```

Expected: `grep -n '\[P2'` → **정확히 2줄**(`:352`·`:353` 계열, 둘 다 「미해제 사유」 문구 동반) ·
`bash -n OK`. 0줄이 나오면 유지군까지 지운 것이므로 되돌린다. 3줄 이상이면 해제군 치환이 빗나간 것이니
그 줄을 직접 확인하고 손으로 고친다 — **정규식이 안 맞으면 정규식을 억지로 늘리지 말고 그 줄만 편집한다**
(치환식 확장이 다른 줄을 삼키는 편이 더 위험하다).
측정 경로가 추정과 **다르면** 위 치환 대신 해당 `jq -r '…'` 문자열 자체를 실측 경로로 바꾸고 마커를 뗀다.

- [ ] **Step 7: `wait` 의 3중 폴백 축소**

3중 폴백(`.result.delivery.id // .result.deliveryId // .result.delivery_id`)은 "모른다"는 뜻이었다.
실측된 경로 **하나만** 남긴다.

```bash
cd "$HOME/.claude"
sed -n '292,302p' bin/orca-rpi.sh
```

측정된 경로가 `.result.delivery.id` 였다면 그 한 줄로 교체한다:

```bash
perl -0777 -i -pe "s{jq -r '\.result\.delivery\.id // \.result\.deliveryId // \.result\.delivery_id // empty'}{jq -r '.result.delivery.id // empty'}" bin/orca-rpi.sh
bash -n bin/orca-rpi.sh && echo "bash -n OK"
```

- [ ] **Step 8: probe 문서 append + 커밋**

`docs/ai-context/c22-orca-probe-measured.md` 말미에 아래 골격으로 append 한다(새 파일 금지).
각 항목은 **명령 · 원문 발췌 · 판정(추정 일치/불일치)** 3요소를 갖춘다.

```markdown
## C23 라이브 측정 (2026-08-18 — 실 워커 1기동, read-only)

> 의도-라이브(`LIVE-INTENT`) — 측정이 목적이다. 잔존 Run/Task: `<RUN>` / `<TASK>`.
> C22 stub 검증이 남긴 스테일 슬롯 `t1` 은 이 측정 전에 해제했다(증거: 위 Step 1 출력).

| 종 | 추정 경로 | 실측 경로 | 판정 |
|---|---|---|---|
| dispatch id | `.result.dispatch.id` | … | … |
| delivery id | 3중 폴백 | … | … |
| agent_terminal_handle | `.result.worker.agent_terminal_handle` | … | … |
| gate id | `.result.gate.id` | … | … |

### `--retry-request` help 원문 (read-only · 부작용 0)
```

```bash
cd "$HOME/.claude"
git add bin/orca-rpi.sh docs/ai-context/c22-orca-probe-measured.md
git commit -m "feat(orca): C23 T1 — 라이브 측정으로 [P2] 해제 + probe 문서 append"
```

---

## Task 2: 브랜치 가드 — 지시문에서 코드로

**Files:**
- Modify: `bin/orca-rpi.sh` — `assert_worktree_arg` 뒤에 함수 2개 추가 · `cmd_spawn`/`cmd_handoff` 에 호출 삽입

**Interfaces:**
- Consumes: `RUNDIR`(`:14`) · `WT_SEL` · `die()`(`:24`)
- Produces: `worktree_path_of <값>` → path(stdout) · `assert_branch_not_merge_target <값>` → rc=0 또는 die

- [ ] **Step 1: RED — 가드 없는 현재 캐리어가 master 에서 non-readonly spawn 을 통과시킴을 실측**

```bash
cd "$HOME/.claude"
D=$(mktemp -d); mkdir -p "$D/rd"
printf '#!/usr/bin/env bash\nprintf "SIDE-EFFECT: %%s\\n" "$*" >> "$STUB_LOG"\nprintf %%s "{\\"id\\":\\"req\\",\\"ok\\":true,\\"result\\":{\\"dispatch\\":{\\"id\\":\\"d_stub\\"}}}"\n' > "$D/orca-stub"
chmod +x "$D/orca-stub"; export STUB_LOG="$D/side.log"; : > "$STUB_LOG"
git -C "$D" init -q; git -C "$D" checkout -q -b master
# ★커밋 1건 필수 — unborn branch 에서 `rev-parse --abbrev-ref HEAD` 는 stdout 에 'HEAD' 를 내며 rc=128 이라
#   가드가 「판정 불가」로 죽고 Expected 문안이 어긋난다(슬롯 1 B6 실측). RED/GREEN 은 같은 픽스처여야 한다.
git -C "$D" -c user.email=c23@local -c user.name=c23 commit -q --allow-empty -m init
printf 'r::%s' "$D" > "$D/rd/wt_sel"
env -u WT_SEL ORCA_CLI_COMMAND="$D/orca-stub" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh spawn --run r1 --task t1 --worktree "r::$D"; echo "rc=$?"
echo "부작용 줄수=$(wc -l < "$STUB_LOG")"
```

Expected (RED): `rc=0` + `d_stub` 출력 + **부작용 줄수=1** — master 브랜치인데 non-readonly spawn 이
`worker-start` 를 실제로 발행한다. 이 출력을 실행 보고에 그대로 인용한다.

- [ ] **Step 2: GREEN 목표 — 가드 함수 추가**

`bin/orca-rpi.sh` 의 `assert_worktree_arg` 정의(`:64-77`) **바로 뒤**에 삽입한다.

```bash
# ── 브랜치 가드 (§11.10 ①) ───────────────────────────────────────────────────
# non-readonly 워커는 코디네이터와 같은 체크아웃에서 커밋한다 — 그 체크아웃이 머지 대상이면
# 사람의 머지 승인이 *사후* 무력화된다(거절해도 이미 착륙해 있다). 지시문이 아니라 여기서 거부한다.
# 측정 대상은 cwd 가 아니라 **워커가 뜨는 워크트리**다 — cwd 를 재면 오탐·미탐이 양방향으로 난다.
worktree_path_of() {   # $1 = --worktree 값('current' 또는 셀렉터) → stdout = path(없으면 빈 문자열)
  local v="$1" sel=""
  if [ "$v" = "current" ]; then
    if [ -n "${WT_SEL:-}" ]; then sel="$WT_SEL"
    elif [ -s "$RUNDIR/wt_sel" ]; then sel=$(cat "$RUNDIR/wt_sel" 2>/dev/null)
    fi
  else
    sel="$v"
  fi
  [ -n "$sel" ] || return 0
  # 셀렉터는 '<repoId>::<path>' — 마지막 '::' 뒤가 path(재조립 금지, 절단만 한다).
  printf '%s' "${sel##*::}"
}

# ★ambient GIT_DIR/GIT_WORK_TREE 를 제거하고 묻는다 — `git -C <path>` 는 cwd 만 바꾸고 **저장소 결정은
# GIT_DIR 이 이긴다**(실측: `GIT_DIR=<repoB>/.git git -C <repoA> rev-parse --abbrev-ref HEAD` → repoB 의
# 브랜치, rc=0). 제거하지 않으면 가드가 다른 저장소를 보고 **무음 통과**한다(슬롯 1 B1).
git_at() { env -u GIT_DIR -u GIT_WORK_TREE git -C "$@"; }

# 판정 불가는 fail-closed — "커밋 대상이 머지 브랜치가 아님"을 단언할 수 없으면 스폰하지 않는다.
# fail-open 약속은 Orca *가용성* 축(preflight rc≠0)의 것이지 안전 가드의 것이 아니다.
assert_branch_not_merge_target() {   # $1 = --worktree 값
  local p br
  p=$(worktree_path_of "$1")
  [ -n "$p" ] || p="$PWD"            # 문서화된 폴백 — 셀렉터 미획득 시에만
  # symbolic-ref 를 먼저 쓴다: unborn branch(커밋 0건)에서도 rc=0 으로 이름을 준다.
  # rev-parse 는 그 경우 stdout='HEAD' + rc=128 이라 판정이 뒤집힌다(슬롯 1 B6).
  br=$(git_at "$p" symbolic-ref --short HEAD 2>/dev/null) || br=""
  # detached HEAD 는 symbolic-ref 가 실패한다 → rev-parse 가 'HEAD' 를 주고 아래 case 를 통과(허용).
  [ -n "$br" ] || br=$(git_at "$p" rev-parse --abbrev-ref HEAD 2>/dev/null) || br=""
  [ -n "$br" ] || die "거부: 브랜치 판정 불가 — '$p' 에서 브랜치명을 얻지 못했다(git 저장소가 아니거나 접근 불가). 커밋 대상이 머지 브랜치가 아님을 단언할 수 없으면 스폰하지 않는다(fail-closed, 설계 §11.10 ①)"
  case "$br" in
    master|main)
      die "거부: non-readonly 워커를 머지 대상 브랜치('$br' @ $p)에서 스폰할 수 없다 — 워커가 같은 체크아웃에 직접 커밋해 사람의 머지 승인이 사후 무력화된다. 사이클 브랜치를 만들어 체크아웃하라(설계 §11.10 ①)" ;;
  esac
  return 0
}
```

★`handoff` 축의 **선언된 잔여**: 이 가드가 읽는 것은 `wt_sel` 인데, `handoff` 가 재사용하는 terminal 은
**dispatch 소유**다(`bin/orca-rpi.sh:325` 가 `worker-show --dispatch` 로 얻은 handle 을 `:345` 에서 재사용).
`spawn` 과 `handoff` 사이에 `wt_sel` 이 갈리면(`preflight` 가 매 실행 `:118` 에서 덮어쓴다) 가드는 실제
워커가 뜰 워크트리가 아닌 곳을 판정한다. 이번 사이클에 닫지 못하는 이유는 dispatch→워크트리 바인딩이
`[P2]` 미측정이기 때문이다 — Task 1 의 `jq paths` 전수 출력에 워크트리 필드가 나오면 차기 사이클에
상향한다(슬롯 1 A1 · spec §11.10 ① · 「선언된 잔여 7」).

- [ ] **Step 3: 호출 삽입 — `cmd_spawn`(non-readonly 만) · `cmd_handoff`(정의상 non-readonly)**

`cmd_spawn` 에서 필수 인자 검사(`:201`) 바로 뒤, `require_jq; ensure_rundir`(`:202`) **앞**에 넣는다
(가드는 원장 쓰기보다 앞이어야 한다):

```bash
  [ -n "$task" ] && [ -n "$run" ] || die "spawn: --run 과 --task 필수"
  # read-only 팬아웃은 브랜치 무관 허용 — 커밋하지 않기로 *선언*된 경로다(§11.9 ⑧ 자기-선언 상한 상속).
  [ "$readonly_flag" -eq 1 ] || assert_branch_not_merge_target "$worktree"
  require_jq; ensure_rundir
```

`cmd_handoff` 는 `--readonly` 아암이 없어 **정의상 non-readonly** 이고 `--worktree` 도 받지 않으므로
`current` 로 조회한다. 필수 인자 검사(`:321`) 뒤, `require_jq; ensure_rundir`(`:322`) 앞:

```bash
  [ -n "$task" ] && [ -n "$dispatch" ] || die "handoff: --task 와 --dispatch 필수"
  # handoff 는 --readonly 를 받지 않는다(정의상 편집 워커) — R→P→I→C 4단계 중 3단계가 이 경로다.
  assert_branch_not_merge_target current
  require_jq; ensure_rundir
```

- [ ] **Step 4: GREEN 확인 — 거부 + 부작용 0줄 단언**

```bash
cd "$HOME/.claude"
D=$(mktemp -d); mkdir -p "$D/rd"
printf '#!/usr/bin/env bash\nprintf "SIDE-EFFECT: %%s\\n" "$*" >> "$STUB_LOG"\nprintf %%s "{\\"id\\":\\"req\\",\\"ok\\":true,\\"result\\":{\\"dispatch\\":{\\"id\\":\\"d_stub\\"}}}"\n' > "$D/orca-stub"
chmod +x "$D/orca-stub"; export STUB_LOG="$D/side.log"; : > "$STUB_LOG"
git -C "$D" init -q; git -C "$D" checkout -q -b master
# ★커밋 1건 필수 — unborn branch 에서 `rev-parse --abbrev-ref HEAD` 는 stdout 에 'HEAD' 를 내며 rc=128 이라
#   가드가 「판정 불가」로 죽고 Expected 문안이 어긋난다(슬롯 1 B6 실측). RED/GREEN 은 같은 픽스처여야 한다.
git -C "$D" -c user.email=c23@local -c user.name=c23 commit -q --allow-empty -m init
printf 'r::%s' "$D" > "$D/rd/wt_sel"
env -u WT_SEL ORCA_CLI_COMMAND="$D/orca-stub" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh spawn --run r1 --task t1 --worktree "r::$D"; echo "non-readonly rc=$?"
env -u WT_SEL ORCA_CLI_COMMAND="$D/orca-stub" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh handoff --task t1 --dispatch d1; echo "handoff rc=$?"
echo "부작용 줄수=$(wc -l < "$STUB_LOG")"
```

Expected (GREEN): 두 호출 모두 `rc=1` + `거부: non-readonly 워커를 머지 대상 브랜치('master' …` ·
**부작용 줄수=0**. 부작용이 1줄이라도 있으면 가드가 외부 호출 뒤에 놓인 것이므로 FAIL 이다.

- [ ] **Step 5: 무회귀 — read-only 는 브랜치 무관 허용 + 비-머지 브랜치는 통과**

```bash
cd "$HOME/.claude"
D=$(mktemp -d); mkdir -p "$D/rd"
printf '#!/usr/bin/env bash\nprintf "SIDE-EFFECT: %%s\\n" "$*" >> "$STUB_LOG"\nprintf %%s "{\\"id\\":\\"req\\",\\"ok\\":true,\\"result\\":{\\"dispatch\\":{\\"id\\":\\"d_stub\\"}}}"\n' > "$D/orca-stub"
chmod +x "$D/orca-stub"; export STUB_LOG="$D/side.log"; : > "$STUB_LOG"
git -C "$D" init -q; git -C "$D" checkout -q -b master
# ★커밋 1건 필수 — unborn branch 에서 `rev-parse --abbrev-ref HEAD` 는 stdout 에 'HEAD' 를 내며 rc=128 이라
#   가드가 「판정 불가」로 죽고 Expected 문안이 어긋난다(슬롯 1 B6 실측). RED/GREEN 은 같은 픽스처여야 한다.
git -C "$D" -c user.email=c23@local -c user.name=c23 commit -q --allow-empty -m init
printf 'r::%s' "$D" > "$D/rd/wt_sel"
env -u WT_SEL ORCA_CLI_COMMAND="$D/orca-stub" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh spawn --run r1 --task tro --readonly --worktree "r::$D"; echo "readonly rc=$?"
git -C "$D" checkout -q -b feature-x
: > "$STUB_LOG"
env -u WT_SEL ORCA_CLI_COMMAND="$D/orca-stub" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh spawn --run r1 --task t2 --worktree "r::$D"; echo "feature rc=$?"
echo "feature 부작용 줄수=$(wc -l < "$STUB_LOG")"
```

Expected: `readonly rc=0`(브랜치 무관 허용) · `feature rc=0` + `feature 부작용 줄수=1`(정상 발행).

- [ ] **Step 6: fail-closed 확인 — git repo 가 아닌 path**

```bash
cd "$HOME/.claude"
D=$(mktemp -d); mkdir -p "$D/rd" "$D/notgit"
printf '#!/usr/bin/env bash\nprintf "SIDE-EFFECT: %%s\\n" "$*" >> "$STUB_LOG"\n' > "$D/orca-stub"
chmod +x "$D/orca-stub"; export STUB_LOG="$D/side.log"; : > "$STUB_LOG"
printf 'r::%s' "$D/notgit" > "$D/rd/wt_sel"
env -u WT_SEL ORCA_CLI_COMMAND="$D/orca-stub" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh handoff --task t1 --dispatch d1; echo "rc=$?"
echo "부작용 줄수=$(wc -l < "$STUB_LOG")"
```

Expected: `rc=1` + `거부: 브랜치 판정 불가` · **부작용 줄수=0**.

- [ ] **Step 7: `GIT_DIR` 오염이 가드를 뚫지 못함을 단언 (슬롯 1 B1 회귀 봉인)**

```bash
cd "$HOME/.claude"
D=$(mktemp -d); mkdir -p "$D/rd" "$D/A" "$D/B"
printf '#!/usr/bin/env bash\nprintf "SIDE-EFFECT: %%s\\n" "$*" >> "$STUB_LOG"\n' > "$D/orca-stub"
chmod +x "$D/orca-stub"; export STUB_LOG="$D/side.log"; : > "$STUB_LOG"
for r in A B; do
  git -C "$D/$r" init -q
  git -C "$D/$r" -c user.email=c23@local -c user.name=c23 commit -q --allow-empty -m init
done
git -C "$D/A" checkout -q -b master
git -C "$D/B" checkout -q -b feature-x
printf 'r::%s' "$D/A" > "$D/rd/wt_sel"
GIT_DIR="$D/B/.git" env -u WT_SEL ORCA_CLI_COMMAND="$D/orca-stub" ORCA_RPI_RUNDIR="$D/rd" \
  bash bin/orca-rpi.sh spawn --run r1 --task t1 --worktree "r::$D/A"; echo "rc=$?"
echo "부작용 줄수=$(wc -l < "$STUB_LOG")"
```

Expected: `rc=1` + `거부: … 머지 대상 브랜치('master' @ …/A)` · **부작용 줄수=0**.
가드가 `feature-x`(=repo B)를 읽어 rc=0 으로 통과하면 `git_at` 의 `env -u` 가 빠진 것이다 — 실측으로
그 형태는 **무음 통과**한다. 이 단언이 그 회귀의 유일한 탐지자다.

- [ ] **Step 8: 커밋**

```bash
cd "$HOME/.claude"
bash -n bin/orca-rpi.sh && echo "bash -n OK"
git add bin/orca-rpi.sh
git commit -m "feat(orca): C23 T2 — 브랜치 가드를 지시문에서 코드로 (spawn+handoff, fail-closed)"
```

---

## Task 3: `ORCA_RPI_DRYRUN` 검증-전용 경로

**Files:**
- Modify: `bin/orca-rpi.sh` — 헬퍼 2개 추가 · 9개 기동 서브커맨드에 정지 지점 삽입 · `main()` 의
  `assert_orca_exe` 를 DRYRUN 뒤로

**Interfaces:**
- Consumes: `die()` · `RUNDIR`
- Produces: `is_dryrun` → rc 0/1 · `dryrun_emit <argv…>` → `DRYRUN: <argv>` 1줄 + `exit 0`
- Task 5 의 STAGE 2e 테스트가 이 계약(rc=0 · `DRYRUN:` 1줄 · rundir 델타 0)에 의존한다.

- [ ] **Step 1: RED — DRYRUN 경로 부재 실측**

```bash
cd "$HOME/.claude"
grep -cE 'DRYRUN|dry-run' bin/orca-rpi.sh
D=$(mktemp -d); mkdir -p "$D/rd"
ORCA_RPI_DRYRUN=1 ORCA_CLI_COMMAND="$D/no-such-orca" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh run --objective "[C23] x"; echo "rc=$?"
```

Expected (RED): `grep -c` → **0** · `rc=1` + `거부: $ORCA 실행 불가` — DRYRUN 을 줘도
`assert_orca_exe` 가 먼저 죽인다. 이것이 §11.10 ② 가 정지 순서를 선언한 이유다.

- [ ] **Step 2: 헬퍼 추가 (`die()` 정의 바로 뒤, `:24` 다음)**

```bash
# ── 검증-전용 경로 (§11.10 ②) ────────────────────────────────────────────────
# 인자·금지 플래그·워크트리·브랜치 가드를 전부 통과한 뒤 **부작용 경계 직전**에 정지한다.
# 정지 지점이 원장/설정 쓰기와 외부 호출 **양쪽 앞**이라 격리 토큰 1개로 충분하다.
# 상한: 원장 뮤텍스(동시-1 상한)는 본질적으로 쓰기라 이 경로로 검증되지 않는다.
is_dryrun() { [ -n "${ORCA_RPI_DRYRUN:-}" ]; }
dryrun_emit() { printf 'DRYRUN: %s\n' "$*"; exit 0; }
```

- [ ] **Step 3: `main()` — 실행자 존재 단언을 DRYRUN 뒤로 (`:486`)**

```bash
  # gpt 제외와 같은 이유로 DRYRUN 도 제외한다 — 외부 프로세스를 부르지 않는 경로가 그 실행자의
  # 존재를 요구할 근거가 없고, Orca 미설치 머신에서도 인자·가드를 시험할 수 있어야 한다(§11.10 ②).
  case "$cmd" in selfcheck|gpt) ;; *) is_dryrun || assert_orca_exe ;; esac
```

- [ ] **Step 4: 9개 기동 서브커맨드에 정지 지점 삽입**

각 정지 지점은 **가드 뒤 · 첫 쓰기 앞**이다.

`cmd_preflight` — 함수 첫 줄(`require_jq` 앞):

```bash
cmd_preflight() {
  is_dryrun && dryrun_emit "preflight: status / orchestration run-list / repo list / worktree current / agent hooks status"
  require_jq
```

`cmd_run` — `[ -n "$objective" ] || die`(`:145`) 뒤:

```bash
  [ -n "$objective" ] || die "run: --objective 필수"
  is_dryrun && dryrun_emit orchestration run-create --objective "$objective" --json
  require_jq; ensure_rundir
```

`cmd_task` — `extra` 조립을 `ensure_rundir` 앞으로 올리고 그 뒤에서 정지한다(배열 조립은 부작용이 아니다):

```bash
  [ -n "$title" ] && [ -n "$spec" ] || die "task: --title 와 --spec 필수"
  local extra=()
  [ -n "$deps" ] && extra=(--deps "$deps")
  [ -n "$run" ] && extra+=(--run "$run")
  is_dryrun && dryrun_emit orchestration task-create --task-title "$title" --spec "$spec" "${extra[@]}" --json
  require_jq; ensure_rundir
```

(그 아래 기존 `local extra=()` 3줄은 **삭제**한다 — 중복 선언이 위 값을 지운다.)

`cmd_spawn` — 브랜치 가드 뒤, `require_jq; ensure_rundir` 앞:

```bash
  [ "$readonly_flag" -eq 1 ] || assert_branch_not_merge_target "$worktree"
  local extra=()
  [ -n "$retry_of" ] && extra=(--retry-of "$retry_of")
  is_dryrun && dryrun_emit orchestration worker-start --run "$run" --task "$task" --worktree "$worktree" --agent claude "${extra[@]}" --json
  require_jq; ensure_rundir
```

(아래 두 줄을 **함께** 처리한다 — 하나만 하면 `extra` 가 조립 직후 빈 배열로 덮이거나 같은 대입이
두 번 남는다: `local resp rc extra=()`(`:215`) → `local resp rc` · `[ -n "$retry_of" ] &&
extra=(--retry-of "$retry_of")`(`:217`) → **삭제**(위 `:483-484` 로 이전됨). `:216` 의 스키마 NOTE
주석은 이전된 조립 줄 위로 함께 옮긴다 — 주석만 남으면 무엇을 설명하는지 사라진다.)

`cmd_wait` — ★**ack 블록 전체를 정지점 앞으로 올린다**(슬롯 1 B2). 그 블록(`:252-265`)은 **읽기만**
한다(`cat "$RUNDIR/pending-ack" 2>/dev/null || true` — 없는 경로를 읽어도 부작용 0)이므로 `ensure_rundir`
앞에 둘 수 있고, 올려야 두 가지가 동시에 고쳐진다: ⓐ `DRYRUN:` 출력에 `--ack` 가 실린다(안 올리면
「인자 파싱을 검증한다」는 ②의 존재 이유가 바로 그 인자에서 무너진다) ⓑ 미ack 불일치 거부가 dry
경로에서도 발화한다. `:250` 의 `[ -n "$run" ] || die` 뒤 ~ `require_jq; ensure_rundir`(`:251`) 앞을
아래로 교체한다:

```bash
  [ -n "$run" ] || die "wait: --run 필수"

  # ★ack 강제(가이드: "A bound Run replays the same Delivery until --ack; process every message
  #   before acknowledging") — 전건 순회 후 ack 를 문서가 아니라 코드로 만든다.
  #   이 블록은 읽기 전용이라 DRYRUN 정지점 **앞**에 둔다(§11.10 ② argv 완전성).
  local pending use_ack=""
  pending=$(cat "$RUNDIR/pending-ack" 2>/dev/null || true)
  if [ -n "$ack" ]; then
    [ -n "$pending" ] || die "wait: --ack 거부 — 미ack 배치가 없다(이 캐리어가 전건 emit 한 배치만 ack 할 수 있다)"
    [ "$ack" = "$pending" ] || die "wait: --ack 거부 — 미ack 배치($pending)와 불일치(받음: $ack)"
    use_ack="$ack"
  else
    use_ack="$pending"   # 직전 배치를 전건 emit 했으므로 자동 ack
  fi
  local extra=()
  [ -n "$use_ack" ] && extra=(--ack "$use_ack")

  is_dryrun && dryrun_emit orchestration check --run "$run" --wait --types worker_done,escalation,question,decision_gate --timeout-ms "$timeout" "${extra[@]}" --json
  require_jq; ensure_rundir
```

(원래 자리(`:252-265`)에 있던 같은 블록은 **삭제**한다 — 중복 선언이 남으면 `local extra=()` 가 위 값을
지운다. `cmd_task` 의 중복 선언 처분과 동형이다.)

`cmd_handoff` — 브랜치 가드 뒤:

```bash
  assert_branch_not_merge_target current
  is_dryrun && dryrun_emit orchestration worker-show --dispatch "$dispatch" --json
  require_jq; ensure_rundir
```

`cmd_release` — `[ -n "$dispatch" ] || die`(`:368`) 뒤:

```bash
  [ -n "$dispatch" ] || die "release: --dispatch 필수"
  is_dryrun && dryrun_emit orchestration worker-release --dispatch "$dispatch" --json
  ensure_rundir
```

`cmd_gate` — 파싱 루프 뒤, `require_jq; ensure_rundir`(`:402`) **앞**. 가드가 DRYRUN 에서도
load-bearing 하도록 필수 인자 검사를 함께 둔다:

```bash
  if is_dryrun; then
    case "$action" in
      create)  [ -n "$task" ] && [ -n "$question" ] || die "gate create: --task 와 --question 필수"
               dryrun_emit orchestration gate-create --task "$task" --question "$question" --options '["PASS","FAIL"]' --json ;;
      resolve) [ -n "$id" ] && [ -n "$resolution" ] || die "gate resolve: --id 와 --resolution 필수"
               dryrun_emit orchestration gate-resolve --id "$id" --resolution "$resolution" --json ;;
      list)    [ -n "$task" ] || die "gate list: --task 필수"
               dryrun_emit orchestration gate-list --task "$task" --json ;;
      *) die "gate: 서브액션은 create|resolve|list 중 하나(받음: '$action')" ;;
    esac
  fi
  require_jq; ensure_rundir
```

`cmd_gpt` — 각 role 아암 안, 첫 부작용 앞(`verifier` 는 `rm -f "$out"` 이 부작용이므로 그 앞):

```bash
    executor)
      is_dryrun && dryrun_emit claude-ocx -p "$prompt" --output-format json
      OCX_MODEL="$gpt_model" "$HOME/.claude/bin/claude-ocx" -p "$prompt" --output-format json
      ;;
    verifier)
      [ -n "$out" ] || die "gpt --role verifier: --out 필수(cross-family-review.md -o 소비 규율)"
      is_dryrun && dryrun_emit codex exec -m "$gpt_model" --sandbox read-only --skip-git-repo-check -o "$out" "$prompt"
      rm -f "$out"
```

- [ ] **Step 5: GREEN 확인 — rc=0 · `DRYRUN:` 1줄 · 부작용 0줄**

```bash
cd "$HOME/.claude"
D=$(mktemp -d); mkdir -p "$D/rd"; git -C "$D" init -q; git -C "$D" checkout -q -b c23-fixture
git -C "$D" -c user.email=c23@local -c user.name=c23 commit -q --allow-empty -m init   # ★unborn 금지(B6)
printf 'r::%s' "$D" > "$D/rd/wt_sel"
for s in "run --objective [C23]x" "task --title t --spec s" "spawn --run r --task t" "wait --run r" "handoff --task t --dispatch d" "release --dispatch d" "gate create --task t --question q" "preflight"; do
  OUT=$(env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_CLI_COMMAND="$D/no-such-orca" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh $s 2>&1); RC=$?
  printf '%-40s rc=%s lines=%s first=%s\n' "$s" "$RC" "$(printf '%s\n' "$OUT" | wc -l)" "$(printf '%s\n' "$OUT" | head -1 | cut -c1-20)"
done
echo "--- argv 완전성(ack) ---"
env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_CLI_COMMAND="$D/no-such-orca" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh wait --run r --ack d_x; echo "ack-불일치 rc=$?"
printf 'd_x' > "$D/rd/pending-ack"
env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_CLI_COMMAND="$D/no-such-orca" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh wait --run r --ack d_x; echo "ack-일치 rc=$?"
rm -f "$D/rd/pending-ack"
echo "rundir 파일 목록:"; ls -1 "$D/rd"
```

Expected (GREEN): 8개 전부 `rc=0` · `lines=1` · `first=DRYRUN:` ·
`ack-불일치 rc=1` + `wait: --ack 거부 — 미ack 배치가 없다…`(가드가 dry 에서도 발화) ·
`ack-일치 rc=0` + 출력 줄에 **`--ack d_x` 가 실려 있음**(argv 완전성 — 슬롯 1 B2) ·
`rundir 파일 목록` 이 **`wt_sel` 하나뿐**(원장 무오염 — `active-nonreadonly.tasks` 미생성).

- [ ] **Step 6: 커밋**

```bash
cd "$HOME/.claude"
bash -n bin/orca-rpi.sh && echo "bash -n OK"
git add bin/orca-rpi.sh
git commit -m "feat(orca): C23 T3 — ORCA_RPI_DRYRUN 검증-전용 경로 (부작용 경계 직전 정지)"
```

---

## Task 4: `--retry-request` 정확 복구 + `gpt` 비용 원장

**Files:**
- Modify: `bin/orca-rpi.sh` — `cmd_run`/`cmd_spawn` 파서 + 실패 경로 · `cmd_gpt` 원장 append

**Interfaces:**
- Consumes: Task 3 의 `is_dryrun`/`dryrun_emit`
- Produces: `gpt_ledger_append <role> <model> <rc> <cost>` · `LEDGER` 경로(`ORCA_RPI_LEDGER` override)

- [ ] **Step 1: `--retry-request` 파서 수용 (Task 1 Step 5 에서 수용이 확인된 명령만)**

`cmd_run` 파서(`:140-143`)에 아암 추가:

```bash
      --objective) objective="${2:-}"; [ -n "$objective" ] || die "run: --objective 필수"; shift 2 ;;
      # 정확 복구 — 같은 요청 id 로 멱등 재발행해 중복 레코드 없이 원 결과를 회수한다(§11.10 ④).
      --retry-request) retry_request="${2:-}"; [ -n "$retry_request" ] || die "run: --retry-request 값(요청 id) 필요"; shift 2 ;;
      *) die "run: 인식하지 않는 인자 '$1'" ;;
```

지역 변수 선언(`:137`)을 바꾼다:

```bash
  local objective="" retry_request=""
```

★**`rr` 조립은 Task 3 이 넣은 DRYRUN 정지점보다 `.` `앞`이어야 한다**(슬롯 1 D1). `dryrun_emit` 은
`exit 0` 하므로, 조립을 원래 호출부(`:149`) 자리에 두면 dry 경로에서 **도달조차 하지 않고** Step 5 의
Expected(`DRYRUN: … --retry-request req_123 …`)가 결정적으로 불가능해진다. 배열 조립은 부작용이 아니므로
정지점 앞이 옳다 — `cmd_task`·`cmd_spawn` 이 이미 그 형태다. 따라서 Task 3 이 만든 `cmd_run` 블록을
아래로 **교체**한다(`rr` 조립 → 정지점 → 라이브 호출 순):

```bash
  [ -n "$objective" ] || die "run: --objective 필수"
  local rr=()
  [ -n "$retry_request" ] && rr=(--retry-request "$retry_request")
  is_dryrun && dryrun_emit orchestration run-create --objective "$objective" "${rr[@]}" --json
  require_jq; ensure_rundir
```

그리고 호출부(`:149`)는 조립 없이 배열만 전달한다:

```bash
  resp=$("$ORCA" orchestration run-create --objective "$objective" "${rr[@]}" --json)
```

`cmd_spawn` 도 같은 형태로 `--retry-request` 아암·변수를 추가하되, **`extra` 조립은 Task 3 이 이미
정지점 앞으로 올려 뒀으므로** 그 배열에 아암을 하나 더 붙이면 된다.
**배선 범위**: Task 1 Step 2 의 help 실측에서 **수용이 확인된 명령에만** 넣는다. 확인되지 않은
명령(`task-create`/`gate-create`/`check`)에는 넣지 않는다 — 받는다고 가정하고 배선하지 않는다(§11.10 ④).
★help 실측 자체가 수행되지 않았으면(`orca.exe` 부재 등) 배선은 **이미 실측된 2개
(`run-create`·`worker-start`)에 한정**하고 나머지는 미확인으로 남긴다 — 「확인된 명령만」이라는 조건을
만족시킬 입력이 없다고 해서 추정 배선으로 넘어가지 않는다(슬롯 1 A5·D2).

- [ ] **Step 2: 비-0 응답 시 정확 복구 명령 출력**

먼저 `SELF` 선언(`bin/orca-rpi.sh:15`) 바로 뒤에 실행 가능한 경로 변수를 하나 추가한다.
`SELF`(=`basename`)는 오류 접두사 용도라 그대로 두고, **안내 줄에 넣을 경로**만 따로 만든다:

```bash
SELF="$(basename "$0")"
# 안내 줄에 붙여 넣을 용도 — basename 은 PATH 에 없어 그대로 복사하면 command-not-found 다(§11.10 ④).
SELF_PATH="$0"
```

`cmd_run` 의 실패 분기(`:152`)를 아래로 교체한다. 봉투 최상위 `.id` 가 **요청 상관ID**이므로
그것이 곧 `--retry-request` 인자다(c22-probe P0-2).

```bash
  if [ "$rc" -ne 0 ]; then
    local req_id; req_id=$(printf '%s' "$resp" | jq -r '.id // empty' 2>/dev/null)
    if [ -n "$req_id" ]; then
      # ★붙여 넣으면 바로 도는 줄이어야 한다 — placeholder 를 쓰면 안내가 아니라 숙제다(§11.10 ④).
      #   $SELF(=basename)는 PATH 에 없으므로 실제 경로를 쓴다(T17 은 실행 비트만 주지 PATH 는 안 건드린다).
      echo "run: 정확 복구(중복 레코드 없이 원 결과 회수) — 아래를 그대로 실행하라:" >&2
      printf '  bash %q run --objective %q --retry-request %q\n' "$SELF_PATH" "$objective" "$req_id" >&2
    else
      echo "run: 요청 id 를 응답에서 뽑지 못했다 — 정확 복구 명령을 제시할 수 없다. 그냥 재발행하면 중복 레코드가 생긴다(삭제 명령 부재). 응답 확인: $RUNDIR/last-run-create.json" >&2
    fi
    die "run: run-create 실패(rc=$rc) — 응답: $RUNDIR/last-run-create.json"
  fi
```

`cmd_spawn` 의 실패 분기(`:222-231`)에도 같은 3분기를 추가한다(기존 `--retry-of` 안내는 **유지** —
두 축은 다르다: `--retry-of` 는 *새* 시도, `--retry-request` 는 같은 mutation 의 멱등 재발행).

- [ ] **Step 3: 비용 원장 함수 추가 (`require_jq` 정의 뒤)**

```bash
# ── gpt 비용 원장 (§11.10 ⑥ — §4.3·§9 시나리오 2 supersede) ─────────────────
# 캐리어는 사이클 번호를 모르므로 _goal/<cycle>-… 을 스스로 구성할 수 없다. 기본은 런타임 경로,
# 사이클이 원하면 ORCA_RPI_LEDGER 로 _goal/<cycle>-ocx-ledger.tsv 를 지정한다.
# 상한: 강제자는 없다 — 호출자가 env 를 줄 때만 _goal/ 에 착지한다.
LEDGER="${ORCA_RPI_LEDGER:-$RUNDIR/gpt-ledger.tsv}"
gpt_ledger_append() {   # $1=role $2=model $3=rc $4=cost(모르면 n/a)
  mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || return 0
  [ -s "$LEDGER" ] || printf 'ts\trole\tmodel\trc\ttotal_cost_usd\n' >> "$LEDGER" 2>/dev/null
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$3" "$4" >> "$LEDGER" 2>/dev/null || true
}
```

- [ ] **Step 4: `cmd_gpt` 두 아암에 원장 배선 (stdout 계약 불변)**

executor 는 **바이트 그대로 통과**해야 하므로 임시 파일을 거친다(`$( )` 는 후행 개행을 먹는다):

```bash
    executor)
      is_dryrun && dryrun_emit claude-ocx -p "$prompt" --output-format json
      local tf ercc cost
      tf=$(mktemp)
      OCX_MODEL="$gpt_model" "$HOME/.claude/bin/claude-ocx" -p "$prompt" --output-format json > "$tf"
      ercc=$?
      cat "$tf"
      cost=$(jq -r '.total_cost_usd // empty' < "$tf" 2>/dev/null)
      rm -f "$tf"
      gpt_ledger_append executor "$gpt_model" "$ercc" "${cost:-n/a}"
      return "$ercc"
      ;;
```

verifier(codex)는 비용 필드를 내지 않으므로 `n/a` — **모르는 값을 0 으로 적지 않는다**:

```bash
      local rc=$?
      gpt_ledger_append verifier "$gpt_model" "$rc" "n/a"
      [ -s "$out" ] || die "gpt --role verifier: 출력 파일 미생성 — API 실패 가능성(cross-family-review.md -o 소비 규율)"
      return "$rc"
```

- [ ] **Step 5: 검증 — 인자 수용 · 실패 분기 · 원장 형식**

DRYRUN 만으로는 이 task 의 산출물 3분기와 원장 append 를 **한 번도 실행하지 않는다**(슬롯 1 C2·C3).
따라서 검증은 세 축이다: ⓐ dry 로 인자 수용/거부 ⓑ **비-0 stub** 으로 정확 복구 안내 ⓒ **비-dry stub**
으로 원장 1행 형식.

```bash
cd "$HOME/.claude"
D=$(mktemp -d); mkdir -p "$D/rd"; git -C "$D" init -q; git -C "$D" checkout -q -b c23-fixture
git -C "$D" -c user.email=c23@local -c user.name=c23 commit -q --allow-empty -m init
printf 'r::%s' "$D" > "$D/rd/wt_sel"

echo "--- ⓐ dry: 인자 수용·거부 ---"
env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh run --objective "[C23]x" --retry-request req_123; echo "rc=$?"
env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh run --objective "[C23]x" --retry-request; echo "빈값 rc=$?"
env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_RPI_RUNDIR="$D/rd" ORCA_RPI_LEDGER="$D/led.tsv" bash bin/orca-rpi.sh gpt --role verifier --prompt p --out "$D/o.txt"; echo "gpt rc=$?"
echo "원장 존재? $([ -f "$D/led.tsv" ] && echo yes || echo 'no — DRYRUN 이 원장 앞에서 멈췄다(정상)')"

echo "--- ⓑ 비-0 응답: 정확 복구 안내 3분기 ---"
printf '#!/usr/bin/env bash\nprintf %%s "{\\"id\\":\\"req_abc\\",\\"ok\\":false}"\nexit 7\n' > "$D/orca-fail"; chmod +x "$D/orca-fail"
env -u WT_SEL ORCA_CLI_COMMAND="$D/orca-fail" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh run --objective "[C23] O'Brien" 2>&1; echo "실패 rc=$?"
printf '#!/usr/bin/env bash\nprintf %%s "{\\"ok\\":false}"\nexit 7\n' > "$D/orca-noid"; chmod +x "$D/orca-noid"
env -u WT_SEL ORCA_CLI_COMMAND="$D/orca-noid" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh run --objective "[C23]y" 2>&1 | grep -c '요청 id 를 응답에서 뽑지 못했다'

echo "--- ⓒ 비-dry: 원장 1행 형식 ---"
mkdir -p "$D/bin"
printf '#!/usr/bin/env bash\nprev=""; out=""\nfor a in "$@"; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done\n[ -n "$out" ] && printf "stub-review\\n" > "$out"\nexit 0\n' > "$D/bin/codex"; chmod +x "$D/bin/codex"
PATH="$D/bin:$PATH" env -u WT_SEL ORCA_CLI_COMMAND="$D/no-such-orca" ORCA_RPI_RUNDIR="$D/rd" ORCA_RPI_LEDGER="$D/led2.tsv" bash bin/orca-rpi.sh gpt --role verifier --prompt p --out "$D/o2.txt"; echo "원장 rc=$?"
awk -F'\t' '{print NR": fields="NF" -> "$0}' "$D/led2.tsv" 2>/dev/null
```

★이 블록의 두 가지가 load-bearing 이다(둘 다 초고에서 틀렸고 seal #53 프로토타입 실행이 잡았다):
① **스텁 파일명은 `codex`** — 캐리어가 `codex exec …` 를 맨 이름으로 부르므로 `codex-stub` 이라 지으면
PATH 가 **실제 codex 를 잡아 진짜 API 를 때린다**. 스텁은 `-o` 대상 파일도 채워야 `[ -s "$out" ]` 를
통과한다. ② **호출 줄 자신에 격리 토큰 2종**(`ORCA_CLI_COMMAND=` + `ORCA_RPI_RUNDIR=`) — 줄 이어쓰기(`\`)로
토큰을 윗줄에 두면 seal 의 ⓑ 요건(두 토큰 동반)이 깨져 이 plan 자신이 NOISO 로 FAIL 한다.

Expected:
- ⓐ 1번 `rc=0` + `DRYRUN: … --retry-request req_123 …` · 2번 `rc=1`(빈 값 거부) ·
  3번 `rc=0` + `DRYRUN: codex exec …` · 원장 미생성.
- ⓑ 첫 호출이 `실패 rc=1` 이면서 stderr 에 **`--objective '[C23] O'\''Brien' --retry-request req_abc`
  형태의 붙여 넣기 가능한 줄**(placeholder `<같은 objective>` 가 **없어야** 한다 — 슬롯 1 A4) ·
  둘째 호출의 `grep -c` → **1**(id 부재 경고 분기 도달).
- ⓒ 원장 `led2.tsv` 가 **2줄**(헤더 + 1행) · 각 줄 `fields=5` · 데이터 행의 5번째 필드가 `n/a`.
  `codex` stub 이 `-o` 파일을 안 만들어 `die` 하더라도 **원장 append 는 그 앞에서 일어난다** —
  이 순서가 곧 「비용 부기가 검증 실패에 흡수되지 않는다」의 증거다. 원장이 아예 없으면
  `gpt_ledger_append` 배선이 빠진 것이므로 FAIL.

- [ ] **Step 6: 커밋**

```bash
cd "$HOME/.claude"
bash -n bin/orca-rpi.sh && echo "bash -n OK"
git add bin/orca-rpi.sh
git commit -m "feat(orca): C23 T4 — --retry-request 정확 복구 안내 + gpt 비용 원장(ORCA_RPI_LEDGER)"
```

---

## Task 5: `setup/tests/orca-carrier.test.sh` — DRYRUN 불변식의 코드 검사자

**Files:**
- Create: `setup/tests/orca-carrier.test.sh`
- Modify: `setup/verify-all.sh` — STAGE 2e 배선(STAGE 2d 와 STAGE 3 사이)
- Modify: `docs/ai-context/scaffold-registry.md` — 표에 1행 append

**Interfaces:**
- Consumes: Task 3 의 `is_dryrun`/`dryrun_emit` 계약 · Task 2 의 브랜치 가드
- Produces: STAGE 2e. 「인자 표에 없는 신규 서브커맨드 → FAIL」이 드리프트 앵커다.

- [ ] **Step 1: 테스트 신설**

```bash
#!/usr/bin/env bash
# setup/tests/orca-carrier.test.sh — §11.10 ② 불변식의 코드 검사자 (verify-all STAGE 2e).
#   「외부 프로세스를 실제로 기동하는 서브커맨드는 예외 없이 DRYRUN 을 존중한다」
# 서브커맨드 목록과 기동/비-기동 분할을 **코드에서 유도**한다 — 하드코딩 목록은 드리프트를 놓친다.
# 라이브 Orca 에 절대 도달하지 않는다: 존재하지 않는 ORCA_CLI_COMMAND + ORCA_RPI_DRYRUN=1.
set -uo pipefail
SRC="$HOME/.claude"
CARRIER="$SRC/bin/orca-rpi.sh"
PASS=0; FAIL=0
ok()  { echo "✓ $1"; PASS=$((PASS+1)); }
bad() { echo "✗ $1"; FAIL=$((FAIL+1)); }

[ -f "$CARRIER" ] || { echo "✗ 캐리어 부재: $CARRIER"; exit 1; }
ROOT=$(mktemp -d); trap 'rm -rf "$ROOT"' EXIT

# --- 픽스처 2종: 비-머지-대상 / 머지-대상 (§11.10 ② ⓚ·ⓛ·ⓕ) ---------------------
# 생성 실패는 SKIP 이 아니라 FAIL 이다 — 전제 미성립을 침묵시키지 않는다.
# ★커밋 1건 필수(ⓛ): unborn branch 에서 rev-parse 는 stdout='HEAD' + rc=128 이라
#   ㉠ 아래 전제 단언이 vacuous PASS 하고 ㉡ 가드는 'fail-closed' 로 거부해 rc=1 이 된다.
mkfix() {   # $1 = 디렉터리 · $2 = 브랜치명
  mkdir -p "$1"
  git -C "$1" init -q 2>/dev/null || return 1
  git -C "$1" -c user.email=c23@local -c user.name=c23 commit -q --allow-empty -m init 2>/dev/null || return 1
  git -C "$1" checkout -q -b "$2" 2>/dev/null || return 1
  # symbolic-ref: unborn 에서도 rc=0 으로 이름을 준다(가드와 같은 판별 경로).
  git -C "$1" symbolic-ref --short HEAD 2>/dev/null
}
FIX="$ROOT/wt"
FIXBR=$(mkfix "$FIX" c23-dryrun-fixture) \
  || { echo "✗ 픽스처 생성 실패 — 전제 미성립(SKIP 아님)"; exit 1; }
case "${FIXBR:-}" in
  ""|master|main) echo "✗ 픽스처 브랜치='${FIXBR:-빈값}' — 비-머지-대상이어야 한다(전제 미성립)"; exit 1 ;;
esac
ok "픽스처A: 임시 repo 브랜치='$FIXBR'(비-머지-대상) — 브랜치 가드 통과 조건 확보"

MFIX="$ROOT/wt_master"
MFIXBR=$(mkfix "$MFIX" master) \
  || { echo "✗ master 픽스처 생성 실패 — 전제 미성립"; exit 1; }
[ "$MFIXBR" = "master" ] \
  || { echo "✗ master 픽스처 브랜치='$MFIXBR' — 'master' 여야 한다(전제 미성립)"; exit 1; }
ok "픽스처B: 임시 repo 브랜치='master'(머지-대상) — 가드 *거부* 단언의 입력 확보"

# --- ⓐ 서브커맨드 목록을 코드에서 유도 -------------------------------------------
SUBS=$(grep -oE '^cmd_[a-z]+\(\)' "$CARRIER" | sed 's/^cmd_//; s/()$//')
[ -n "$SUBS" ] || { echo "✗ 서브커맨드 추출 실패 — 앵커(^cmd_*()) 붕괴"; exit 1; }
ok "서브커맨드 $(printf '%s\n' "$SUBS" | wc -l)개 추출: $(printf '%s ' $SUBS)"

# --- ⓑ 커맨드-위치 외부 기동 여부를 코드에서 유도 --------------------------------
# command -v "$ORCA" / [ -x "$ORCA" ] / case "$ORCA" in 은 첫 토큰이 달라 '기동'이 아니다.
launch_count() {   # $1 = 서브커맨드명 → 기동 줄 수
  awk -v fn="$1" '
    $0 ~ ("^cmd_" fn "\\(\\) \\{") { inf = 1; next }
    inf && /^\}/ { inf = 0 }
    inf {
      s = $0
      sub(/^[ \t]*/, "", s)
      if (s ~ /^#/) next
      sub(/^local[ \t]+/, "", s)
      sub(/^[A-Za-z_][A-Za-z0-9_]*=\$\(/, "", s)
      while (match(s, /^[A-Za-z_][A-Za-z0-9_]*=("[^"]*"|[^ \t]+)[ \t]+/)) s = substr(s, RLENGTH + 1)
      if (s ~ /^"\$ORCA"[ \t]/) n++
      else if (s ~ /^orca_t[ \t]/) n++
      else if (s ~ /^codex[ \t]/) n++
      else if (s ~ /claude-ocx"?[ \t]/ && s ~ /^"?\$HOME/) n++
    }
    END { print n + 0 }
  ' "$CARRIER"
}

# --- 인자 표: 신규 서브커맨드가 여기 없으면 FAIL(fail-closed, ⓔ) ------------------
# ★계수 단위는 함수가 아니라 **기동 아암**이다(§11.10 ② ⓑ · 슬롯 1 A2). gate 는 3아암, gpt 는 2아암이고
#   DRYRUN 정지도 아암마다 들어가므로, 함수당 1샘플만 돌리면 `gate resolve`/`gpt executor` 의 정지점을
#   지워도 스위트가 GREEN 을 유지한다(판별력 공백). 한 줄 = 한 아암, 필드 구분자는 '|'.
argsets_for() {
  case "$1" in
    preflight) printf '\n' ;;
    run)       printf -- '--objective|[C23] dryrun probe\n' ;;
    task)      printf -- '--title|t1|--spec|s1\n' ;;
    spawn)     printf -- '--run|r1|--task|t1\n' ;;
    wait)      printf -- '--run|r1\n' ;;
    handoff)   printf -- '--task|t1|--dispatch|d1\n' ;;
    release)   printf -- '--dispatch|d1\n' ;;
    gate)      printf -- 'create|--task|t1|--question|q1\nresolve|--id|g1|--resolution|PASS\nlist|--task|t1\n' ;;
    gpt)       printf -- '--role|verifier|--prompt|p1|--out|@OUT@\n--role|executor|--prompt|p1\n' ;;
    selfcheck) printf '\n' ;;
    *) return 1 ;;
  esac
}

snapshot() { ( cd "$1" && find . -type f -exec cksum {} \; 2>/dev/null | sort ); }

run_dry() {   # $1=rundir $2=워크트리픽스처 $3.. = 캐리어 인자 → stdout=출력, 전역 RC
  local rd="$1" fix="$2"; shift 2
  printf 'c23fixture::%s' "$fix" > "$rd/wt_sel"
  ( cd "$SRC" && env -u WT_SEL -u GIT_DIR -u GIT_WORK_TREE \
      ORCA_RPI_DRYRUN=1 ORCA_CLI_COMMAND="$ROOT/no-such-orca" ORCA_RPI_RUNDIR="$rd" \
      bash "$CARRIER" "$@" 2>&1 )
}

for s in $SUBS; do
  if ! SETS=$(argsets_for "$s"); then
    bad "인자 표에 없는 신규 서브커맨드 '$s' — DRYRUN 게이트 미검증 상태로 추가됐다(fail-closed, §11.10 ② ⓔ)"
    continue
  fi
  IDX=0
  while IFS= read -r A; do
    IDX=$((IDX+1))
    RD="$ROOT/rd_${s}_${IDX}"; mkdir -p "$RD"
    ARGS=()
    if [ -n "$A" ]; then
      OLDIFS="$IFS"; IFS='|'; read -r -a RAW <<< "$A"; IFS="$OLDIFS"
      for x in "${RAW[@]}"; do
        [ -n "$x" ] || continue
        [ "$x" = "@OUT@" ] && x="$RD/out.txt"
        ARGS+=("$x")
      done
    fi
    printf 'c23fixture::%s' "$FIX" > "$RD/wt_sel"
    BEFORE=$(snapshot "$RD")
    OUT=$(run_dry "$RD" "$FIX" "$s" "${ARGS[@]+"${ARGS[@]}"}")
    RC=$?
    AFTER=$(snapshot "$RD")
    LC=$(printf '%s\n' "$OUT" | grep -c '^DRYRUN: ')
    TL=$(printf '%s\n' "$OUT" | wc -l)
    LABEL="$s${A:+ [${A%%|*}…]}#$IDX"
    if [ "$(launch_count "$s")" -gt 0 ]; then
      # ★총 줄 수도 1 이어야 한다(슬롯 1 C1): 접두 줄만 세면 정지점보다 **앞에서** 외부 프로세스를
      #   부르는 오배치가 통과한다 — 캐리어에 set -e 가 없어 뒤의 exit 0 이 rc 를 덮기 때문이다.
      #   8/9 서브커맨드는 ensure_rundir 의 touch 가 델타를 만들어 우연히 걸리지만 cmd_gpt 는
      #   rundir 를 아예 참조하지 않아 그 우연이 없다(거기서 실 API 를 때리며 GREEN 이 된다).
      if [ "$RC" -eq 0 ] && [ "$LC" -eq 1 ] && [ "$TL" -eq 1 ] && [ "$BEFORE" = "$AFTER" ]; then
        ok "기동 아암 '$LABEL': DRYRUN 존중(rc=0 · DRYRUN: 1줄 · 총 1줄 · rundir 델타 0)"
      else
        bad "기동 아암 '$LABEL': rc=$RC DRYRUN줄=$LC 총줄=$TL rundir델타=$([ "$BEFORE" = "$AFTER" ] && echo 0 || echo '≠0') — 출력: $(printf '%s' "$OUT" | head -2 | tr '\n' '|')"
      fi
    else
      if [ "$BEFORE" = "$AFTER" ]; then
        ok "비-기동 '$LABEL': 외부 기동 없음 + 부작용 0(DRYRUN 면제 — 성질에 의한 분할)"
      else
        bad "비-기동 '$LABEL': rundir 델타 ≠0 — 외부 기동이 없는데 쓰기가 있다"
      fi
    fi
  done <<< "$SETS"
done

# --- ⓕ 가드의 *거부* 도 상설 단언 대상 (§11.10 ② ⓕ · 슬롯 1 B7) --------------------
# 위 루프는 전부 "비-머지 브랜치에서 rc=0" 만 본다 → 브랜치 가드 호출을 통째로 지워도 전건 GREEN.
# Task 2 의 RED/GREEN 은 1회성 수동 절차라 어떤 스위트에도 등재되지 않으므로, 여기가 유일한 상설 탐지자다.
for g in "spawn|--run|r1|--task|t1" "handoff|--task|t1|--dispatch|d1"; do
  GS="${g%%|*}"; GA="${g#*|}"
  RD="$ROOT/rd_guard_$GS"; mkdir -p "$RD"
  OLDIFS="$IFS"; IFS='|'; read -r -a GARGS <<< "$GA"; IFS="$OLDIFS"
  BEFORE=$(snapshot "$RD")
  OUT=$(run_dry "$RD" "$MFIX" "$GS" "${GARGS[@]}")
  RC=$?
  AFTER=$(snapshot "$RD")
  if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q '머지 대상 브랜치' && [ "$BEFORE" = "$AFTER" ]; then
    ok "가드 거부 '$GS': master 픽스처에서 rc=$RC + 사유 문자열 + 부작용 0"
  else
    bad "가드 거부 '$GS': rc=$RC (0 이면 브랜치 가드가 없다) — 출력: $(printf '%s' "$OUT" | head -2 | tr '\n' '|')"
  fi
done

# --- ⓖ 비-0 응답의 정확 복구 안내 분기 (§11.10 ② ⓖ · 슬롯 1 C2) --------------------
# DRYRUN 경로는 이 분기 앞에서 exit 0 하므로 dry 로는 영원히 미실행이다. stub 에 비-0 종료 변형을 준다.
RDF="$ROOT/rd_fail"; mkdir -p "$RDF"; printf 'c23fixture::%s' "$FIX" > "$RDF/wt_sel"
printf '#!/usr/bin/env bash\nprintf %%s "{\\"id\\":\\"req_abc\\",\\"ok\\":false}"\nexit 7\n' > "$ROOT/orca-fail"
chmod +x "$ROOT/orca-fail"
FOUT=$( cd "$SRC" && env -u WT_SEL -u GIT_DIR -u GIT_WORK_TREE \
        ORCA_CLI_COMMAND="$ROOT/orca-fail" ORCA_RPI_RUNDIR="$RDF" \
        bash "$CARRIER" run --objective "[C23] recovery probe" 2>&1 )
if printf '%s' "$FOUT" | grep -q -- '--retry-request req_abc' \
   && printf '%s' "$FOUT" | grep -q -- '--objective' \
   && ! printf '%s' "$FOUT" | grep -q '<같은 objective>'; then
  ok "실패 분기: 요청 id 추출 + 붙여 넣기 가능한 정확 복구 명령(placeholder 없음)"
else
  bad "실패 분기: 정확 복구 안내가 없거나 placeholder 가 남아 있다 — 출력: $(printf '%s' "$FOUT" | tr '\n' '|' | cut -c1-200)"
fi

# --- ⓗ gpt 비용 원장 형식 (§11.10 ② ⓗ·⑥ · 슬롯 1 C3) -------------------------------
# DRYRUN 은 원장 함수 호출 앞에서 멈추므로 형식이 한 번도 실측되지 않는다. 비-dry + stub codex 로 1회.
mkdir -p "$ROOT/bin"
printf '#!/usr/bin/env bash\nprev=""; out=""\nfor a in "$@"; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done\n[ -n "$out" ] && printf "stub-review\\n" > "$out"\nexit 0\n' > "$ROOT/bin/codex"
chmod +x "$ROOT/bin/codex"
RDL="$ROOT/rd_ledger"; mkdir -p "$RDL"
LED="$RDL/gpt-ledger.tsv"
( cd "$SRC" && PATH="$ROOT/bin:$PATH" env -u WT_SEL ORCA_RPI_RUNDIR="$RDL" ORCA_RPI_LEDGER="$LED" \
    bash "$CARRIER" gpt --role verifier --prompt p1 --out "$RDL/o.txt" >/dev/null 2>&1 )
LROWS=$(wc -l < "$LED" 2>/dev/null || echo 0)
LFLD=$(awk -F'\t' 'END{print NF+0}' "$LED" 2>/dev/null || echo 0)
LNA=$(awk -F'\t' 'NR==2{print $5}' "$LED" 2>/dev/null || echo "")
if [ "$LROWS" -eq 2 ] && [ "$LFLD" -eq 5 ] && [ "$LNA" = "n/a" ]; then
  ok "gpt 원장: 헤더+1행 · 5필드 · verifier 비용 'n/a'(모르는 값을 0 으로 적지 않음)"
else
  bad "gpt 원장: 줄수=$LROWS 필드=$LFLD 비용필드='$LNA' (기대 2/5/n/a) — 원장 배선 또는 형식 결함"
fi

echo
echo "orca-carrier: PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

- [ ] **Step 2: 실행 — 전 서브커맨드 GREEN 확인**

```bash
cd "$HOME/.claude"
chmod +x setup/tests/orca-carrier.test.sh
bash setup/tests/orca-carrier.test.sh; echo "rc=$?"
```

Expected: `PASS=20 FAIL=0` · `rc=0`.

계수 근거(슬롯 1 A2·B7·C1·C2·C3 반영 후):
| 구간 | 건수 | 내역 |
|---|---|---|
| 루프 앞 | 3 | 픽스처A(비-머지) · 픽스처B(master) · 서브커맨드 추출 |
| 아암 루프 | 13 | preflight·run·task·spawn·wait·handoff·release 각 1(=7) + gate 3 + gpt 2 + selfcheck 1 |
| 가드 거부 | 2 | `spawn`·`handoff` 를 master 픽스처에서 rc≠0 단언 |
| 실패 분기 | 1 | 비-0 stub → 정확 복구 안내(placeholder 없음) |
| gpt 원장 | 1 | 헤더+1행 · 5필드 · `n/a` |
| **합** | **20** | |

★서브커맨드는 10개인데 아암은 13개다 — `gate`(create/resolve/list)와 `gpt`(verifier/executor)가
아암마다 정지점을 갖기 때문이다. 함수당 1샘플이면 `gate resolve`·`gpt executor` 의 정지점 삭제가
무발화한다.

- [ ] **Step 3: 드리프트 앵커 RED 확인 — 표에 없는 서브커맨드**

```bash
cd "$HOME/.claude"
T=$(mktemp -d); cp bin/orca-rpi.sh "$T/orca-rpi.sh"
printf '\ncmd_newthing() {\n  "$ORCA" orchestration run-create --json\n}\n' >> "$T/orca-rpi.sh"
HOME_BAK="$HOME"; mkdir -p "$T/home/.claude/bin" "$T/home/.claude/setup/tests"
cp "$T/orca-rpi.sh" "$T/home/.claude/bin/orca-rpi.sh"
cp setup/tests/orca-carrier.test.sh "$T/home/.claude/setup/tests/"
HOME="$T/home" bash "$T/home/.claude/setup/tests/orca-carrier.test.sh"; echo "rc=$?"
```

Expected (RED): 출력에 `✗ 인자 표에 없는 신규 서브커맨드 'newthing'` 이 있고 `rc≠0`.
이것이 「게이트 없는 신규 서브커맨드 추가」를 잡는 앵커다.
★이 격리 HOME 에서는 `bin/claude-ocx` 등 주변 파일이 없어 **다른 단언도 함께 FAIL 할 수 있다** —
이 Step 이 보는 것은 오직 위 문자열의 존재와 비-0 종료다(`rc=1` 을 정확히 요구하지 않는다. FAIL 이
여러 건이면 `exit $FAIL` 이 그 개수를 반환한다).

- [ ] **Step 4: verify-all 배선 (STAGE 2d 와 STAGE 3 사이)**

```bash
echo "=== STAGE 2e: orca carrier DRYRUN 불변식 ==="
bash "$HOME/.claude/setup/tests/orca-carrier.test.sh" || { echo "FAIL orca-carrier"; exit 1; }
echo
```

- [ ] **Step 5: scaffold-registry 등재**

`docs/ai-context/scaffold-registry.md` 표에 1행 추가:

```markdown
| `setup/tests/orca-carrier.test.sh` | 캐리어의 외부-기동 서브커맨드가 DRYRUN 을 예외 없이 존중함을 코드-유도 목록으로 증명(게이트 없는 신규 서브커맨드 추가를 fail-closed 로 차단) | C23 |
```

- [ ] **Step 6: 커밋**

```bash
cd "$HOME/.claude"
bash setup/verify-all.sh 2>&1 | tail -20
git add setup/tests/orca-carrier.test.sh setup/verify-all.sh docs/ai-context/scaffold-registry.md
git commit -m "test(orca): C23 T5 — STAGE 2e orca-carrier DRYRUN 불변식 검사자"
```

---

## Task 6: seal #53 — 부작용-차단 주입 명시

**Files:**
- Modify: `setup/verify-setup.sh` — #52 블록(`:638-707`) 직후 · #36(`:709-716`) 앞에 삽입
- Modify: `README.md:300` — `(현재 90 PASS)` → `(현재 91 PASS)`
- Modify: `docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md` — C23 부기 1줄

**Interfaces:**
- Consumes: `ok()`/`fail()`(verify-setup 내부)
- Produces: seal #53. Task 7 의 뮤테이터 2건이 이 seal 의 발화를 증명한다.

- [ ] **Step 1: RED — seal 부재 실측**

```bash
cd "$HOME/.claude"
grep -c 'LIVE-INTENT' setup/verify-setup.sh
bash setup/verify-setup.sh 2>&1 | tail -3
```

Expected (RED): `grep -c` → **0** · `verify-setup: PASS=90 FAIL=0` — 격리 없는 캐리어 호출 블록이
코퍼스에 6건 있는데 아무도 보지 않는다.

- [ ] **Step 2: 동결값 산출 순서를 확정 (순환 회피)**

대장 cksum 은 **스캐너가 존재해야** 계산할 수 있고, 스캐너는 seal 안에 인라인으로 들어간다.
따라서 순서는 「Step 3 에서 스캐너 포함 seal 을 삽입하되 동결값 자리에 플레이스홀더
`@@S53_LEDGER_CKSUM@@` 를 둔다 → Step 4 에서 그 스캐너를 임시 파일로 추출해 실행한 값으로 치환」이다.
플레이스홀더가 남아 있으면 seal 은 반드시 FAIL 하므로(문자열 비교 불일치) **치환 누락이 침묵하지 않는다**.

- [ ] **Step 3: seal #53 삽입**

`setup/verify-setup.sh` 의 `PP_*` 블록이 끝나는 `fi`(`:707`) 다음, `EXPECTED_TOTAL=` 줄(`:710`) 앞에 넣는다.

```bash
# 53. 부작용-차단 주입 명시 (C23, non-obvious #5 SMART ①② — 기한 "C23 Phase P"):
#     docs/superpowers/plans/*.md + docs/ai-context/*.md 의 **증거 단위**(연속 비-공백 줄의 최대 런)에
#     커맨드-위치 캐리어 부작용 호출이 있으면, 그 호출 줄 자신 또는 **앞 15줄 이내**에
#     ⓐ ORCA_RPI_DRYRUN= (단독 충분) 또는 ⓑ ORCA_CLI_COMMAND= + ORCA_RPI_RUNDIR=(동반 필수)
#     가 있어야 한다. 없으면 FAIL. 라이브가 *목적*인 단위는 LIVE-INTENT(<6자 이상 사유>) 로 면제된다.
#     ★문단 단위인 이유: 펜스 모델은 중첩 펜스로 패리티가 깨진다(C22 plan 실측 — 오탐 1건).
#     ★근접 창인 이유: 공백줄 없는 긴 절에서 토큰 1개가 절 전체를 세탁한다(non-obvious.md 실측 87줄 단일 문단).
#     ★vacuous 방지: TOTAL=0 → FAIL 을 쓰지 않는다(캐리어 호출 없는 미래 사이클을 거짓 FAIL).
#       대신 **런타임 조립 자기-시험 픽스처**(ISO 1 + NOISO 1)로 탐지자가 양방향 판별함을 매번 증명한다.
#     ★1회성 예외 대장: C22 plan 6단위는 *이미 실행된 기록*이라 소급 편집이 왜곡/허위 재분류다.
#       개수가 아니라 **호출 줄 집합의 cksum 을 동결**한다(치환 우회 차단).
S53_AWK='
# 파일 단위 2-상 처리: 수집(라인 순회) → 분류(파일 끝). LIVE-INTENT 는 호출 **뒤**에도 올 수 있어
# (마크다운에서 선언은 보통 코드블록 다음 Expected 줄에 붙는다) 한 번에 판정할 수 없다.
# 격리 토큰은 **같은 단위 + 앞 15줄**. LIVE-INTENT 는 **같은 단위이거나 앞 15줄** + **줄 전체가 선언**
# 일 때만 인정한다(거리만으로는 *언급*과 *선언*이 구분되지 않는다 — spec §11.10 ③ 7차 정정).
BEGIN { QQ = "[\"" sprintf("%c", 39) "]+" }   # 양끝에서 벗길 따옴표(", ')
function classify(  i,j,d,cli,rd,iso,live,st) {
  for (i = 1; i <= nc; i++) {
    cli = 0; rd = 0; iso = 0; live = 0
    for (j = 1; j <= nt; j++) {
      if (tu[j] != cu[i]) continue
      d = cl[i] - tl[j]
      if (d < 0 || d > 15) continue
      if (tk[j] == "DRY") iso = 1
      else if (tk[j] == "CLI") cli = 1
      else if (tk[j] == "RD") rd = 1
    }
    for (j = 1; j <= nv; j++) {
      d = cl[i] - vl[j]
      if (vu[j] == cu[i] || (d >= 0 && d <= 15)) live = 1
    }
    st = (iso || (cli && rd)) ? "ISO" : (live ? "LIVE" : "NOISO")
    # 필드: STATUS \t FILE \t LINE \t RC \t UNIT \t TEXT (TEXT 가 마지막 — 탭 포함 시에도 잘리지 않게)
    printf "%s\t%s\t%d\t%d\t%d\t%s\n", st, CURF, cl[i], (rcu[cu[i]] ? 1 : 0), cu[i], ct[i]
  }
  nc = 0; nt = 0; nv = 0; unit = 0; split("", rcu, ":")
}
function callof(line,  s,n,a,i,t,nx,em,sk) {
  s = line
  sub(/^[ \t]*/, "", s)
  if (s ~ /^#/) return ""
  if (substr(s, 1, 1) == "`") return ""
  gsub(/\$\(/, " ", s)
  n = split(s, a, /[ \t]+|[;&|()]+/)
  em = 0; sk = 0
  for (i = 1; i <= n; i++) {
    # ★따옴표는 **양끝** 모두 벗긴다(슬롯 1 B4 실측). 선두만 벗기면
    # `bash "$HOME/.claude/bin/orca-rpi.sh" run …` 이 닫는 따옴표 때문에 경로 정규식에서 탈락해
    # **호출 자체가 스캔에 들어오지 않는다**(awk 실행으로 출력 0줄 확인). 이건 고의 우회가 아니라
    # 관용적 표기이고 — 이 plan 의 Task 5 도 `bash "$CARRIER"` 형태다 — 통째로 침묵하는 미탐이다.
    t = a[i]; gsub("^" QQ, "", t); gsub(QQ "$", "", t)
    if (t == "") continue
    # env 의 자기 옵션은 건너뛴다 — `env -u WT_SEL bash …/orca-rpi.sh spawn` 을 놓치면
    # 격리 없는 호출이 통째로 미탐된다(C23 Phase P 실측: 이 형태가 코퍼스에 다수).
    if (sk) { sk = 0; continue }
    if (t == "env") { em = 1; continue }
    if (em && t == "-u") { sk = 1; continue }
    if (em && t ~ /^-/) continue
    if (t == "bash" || t == "sh" || t == "exec" || t == "time") continue
    if (t ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    if (t ~ /(^|\/)orca-rpi\.sh$/) {
      nx = a[i+1]; gsub("^" QQ, "", nx); gsub(QQ "$", "", nx)
      if (nx ~ /^(run|task|spawn|wait|handoff|release|gate|preflight|gpt)$/) return line
      return ""
    }
    return ""
  }
  return ""
}
FNR == 1 { if (NR > 1) classify(); CURF = FILENAME; nc = 0; nt = 0; nv = 0; unit = 1; split("", rcu, ":") }
/^[ \t]*$/ { unit++; next }
{
  c = callof($0)
  if (c != "") { nc++; cl[nc] = FNR; cu[nc] = unit; ct[nc] = c }
  # ★격리 토큰은 ①주석 줄이 아니고 ②`=` 뒤에 비-공백 값이 있어야 인정한다(슬롯 1 A3 실측).
  #   캐리어의 술어는 `[ -n "${ORCA_RPI_DRYRUN:-}" ]` 라 **빈 대입은 라이브 실행**인데 문자열 존재만
  #   보면 ISO 로 오분류한다. 더 넓게는 `# ORCA_RPI_DRYRUN=1` **주석 한 줄**만으로도 세탁됐다.
  #   탐지자와 런타임 술어가 어긋나면 seal 은 「PASS 하는데 Run 이 생기는」 최악의 방향으로 틀린다.
  ls = $0; sub(/^[ \t]*/, "", ls)
  if (substr(ls, 1, 1) != "#") {
    if ($0 ~ /ORCA_RPI_DRYRUN=[^ \t]/)  { nt++; tl[nt] = FNR; tu[nt] = unit; tk[nt] = "DRY" }
    if ($0 ~ /ORCA_CLI_COMMAND=[^ \t]/) { nt++; tl[nt] = FNR; tu[nt] = unit; tk[nt] = "CLI" }
    if ($0 ~ /ORCA_RPI_RUNDIR=[^ \t]/)  { nt++; tl[nt] = FNR; tu[nt] = unit; tk[nt] = "RD" }
  }
  # ★LIVE-INTENT 는 **줄 전체가 선언**일 때만 센다(공백·백틱 제외 후 그것 하나만 남아야 한다).
  #   거리로는 언급과 선언이 안 갈린다 — 「예시 문자열은 `LIVE-INTENT(…)` 이다」 같은 산문이
  #   11줄 뒤 호출을 면제해 버린다(슬롯 1 B5, spec §11.10 ③ 7차 정정).
  lv = $0; gsub(/^[ \t`]+/, "", lv); gsub(/[ \t`]+$/, "", lv)
  if (lv ~ /^LIVE-INTENT\([^)][^)][^)][^)][^)][^)]+\)$/) { nv++; vl[nv] = FNR; vu[nv] = unit }
  if ($0 ~ /rc=/) rcu[unit] = 1
}
END { classify() }
'
S53_TMP=$(mktemp -d)
printf '%s' "$S53_AWK" > "$S53_TMP/s53.awk"

# --- 자기-시험 픽스처(런타임 조립 — 리터럴로 두면 이 파일 자신이 코퍼스 오염원이 된다) ---
S53_CARRIER_TOKEN="bin/orca-rpi.sh"
{ printf 'ISO probe\n'
  printf 'ORCA_CLI_COMMAND=/x ORCA_RPI_RUNDIR=/y bash %s spawn --run r --task t\n' "$S53_CARRIER_TOKEN"
  printf '\n'
  printf 'NOISO probe\n'
  printf 'bash %s spawn --run r --task t\n' "$S53_CARRIER_TOKEN"
  printf '\n'
  # ★따옴표 감싼 경로 — 이 형태가 통째로 미탐이던 회귀를 봉인한다(슬롯 1 B4).
  printf 'NOISO quoted probe\n'
  printf 'bash "$HOME/.claude/%s" run --objective x\n' "$S53_CARRIER_TOKEN"
  printf '\n'
  # ★빈 대입은 격리가 아니다 — 캐리어 술어가 -n 이라 라이브로 실행된다(슬롯 1 A3).
  printf 'NOISO empty-assign probe\n'
  printf 'ORCA_RPI_DRYRUN= bash %s run --objective x\n' "$S53_CARRIER_TOKEN"
  printf '\n'
  # ★주석 줄은 격리원이 될 수 없다(슬롯 1 A3 — 대조 노동에서 추가 발견).
  printf 'NOISO commented-token probe\n'
  printf '# ORCA_RPI_DRYRUN=1\n'
  printf 'bash %s run --objective x\n' "$S53_CARRIER_TOKEN"
  printf '\n'
} > "$S53_TMP/fixture.md"
S53_FIX=$(awk -f "$S53_TMP/s53.awk" "$S53_TMP/fixture.md" 2>/dev/null | cut -f1 | tr '\n' ',')
if [ "$S53_FIX" != "ISO,NOISO,NOISO,NOISO,NOISO," ]; then
  fail "부작용-차단 seal: 자기-시험 픽스처 판별 실패(기대 'ISO,NOISO,NOISO,NOISO,NOISO,' 실측 '${S53_FIX:-빈값}') — 탐지자가 죽었다면 위반 0 은 무의미하다"
else
  S53_LEDGER="$HOME/.claude/docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md"
  S53_ALL=$(awk -f "$S53_TMP/s53.awk" "$HOME/.claude/docs/superpowers/plans"/*.md "$HOME/.claude/docs/ai-context"/*.md 2>/dev/null)
  S53_BAD=$(printf '%s\n' "$S53_ALL" | awk -F'\t' -v L="$S53_LEDGER" '$1=="NOISO" && $2!=L {print $2":"$3}' | tr '\n' ' ')
  # 호출 텍스트는 마지막 필드다 — 앞 5필드를 잘라내 탭 포함 텍스트도 온전히 얻는다.
  S53_LED_CK=$(printf '%s\n' "$S53_ALL" | awk -F'\t' -v L="$S53_LEDGER" '$1=="NOISO" && $2==L { l=$0; sub(/^([^\t]*\t){5}/, "", l); print l }' | sed 's/[[:space:]][[:space:]]*/ /g' | sort | cksum | tr -d ' ')
  S53_LIVE_N=$(printf '%s\n' "$S53_ALL" | awk -F'\t' '$1=="LIVE"{print $2"\t"$5}' | sort -u | awk -F'\t' '{c[$1]++} END{for (f in c) printf "%s=%d ", f, c[f]}')
  S53_CLAIM=$(printf '%s\n' "$S53_ALL" | awk -F'\t' '$1=="NOISO" && $4==1 {print $2"\t"$5}' | sort -u | wc -l)
  S53_PARITY=""
  for _f in $(printf '%s\n' "$S53_ALL" | awk -F'\t' '$1=="LIVE"{print $2}' | sort -u); do
    # 계수 단위는 **증거 단위**다(호출 수가 아니라) — 한 블록 안의 여러 호출은 1건으로 센다.
    _k=$(printf '%s\n' "$S53_ALL" | awk -F'\t' -v F="$_f" '$1=="LIVE" && $2==F {print $5}' | sort -u | wc -l)
    _d=$(grep -oE 'LIVE-INTENT-총계: *[0-9]+' "$_f" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
    [ "${_d:-없음}" = "$_k" ] || S53_PARITY="$S53_PARITY $_f(선언=${_d:-부재}≠실측=$_k)"
  done
  rm -rf "$S53_TMP"
  if [ -n "$S53_BAD" ]; then
    fail "부작용-차단 주입 누락 — 격리 토큰도 LIVE-INTENT 도 없는 캐리어 호출: ${S53_BAD}(non-obvious #5 SMART ①)"
  elif [ "$S53_LED_CK" != "@@S53_LEDGER_CKSUM@@" ]; then
    fail "1회성 예외 대장 drift — C22 plan 의 미격리 호출 줄 집합이 바뀌었다(동결=@@S53_LEDGER_CKSUM@@ 실측=$S53_LED_CK). 소급 편집·치환 모두 여기서 잡힌다"
  elif [ -n "$S53_PARITY" ]; then
    fail "LIVE-INTENT 총계 parity 불일치 —${S53_PARITY} (자기-면제는 같은 파일 안에서 'LIVE-INTENT-총계: k' 로 표면화해야 한다)"
  else
    ok "부작용-차단 주입 명시: 미격리 캐리어 호출 0 · 실행-주장 단위 ${S53_CLAIM} · LIVE-INTENT ${S53_LIVE_N:-0건} (non-obvious #5 SMART ①②)"
  fi
fi
```

- [ ] **Step 4: 대장 cksum 동결값 산출 후 치환**

```bash
cd "$HOME/.claude"
# Step 3 의 awk 를 임시 파일로 뽑아 실행값을 얻는다(seal 자신을 돌리지 않고 스캐너만 재사용).
TMPD=$(mktemp -d)
sed -n "/^S53_AWK='\$/,/^'\$/p" setup/verify-setup.sh | sed '1d;$d' > "$TMPD/s53.awk"
# ★seal 과 **완전히 같은 식**이어야 한다(경로도 절대경로로 — seal 이 $HOME 절대경로로 스캔하므로
#   상대경로로 돌리면 $2==L 이 한 건도 매치되지 않아 '빈 입력 cksum'(42949672950)이 나온다.
#   그리고 텍스트는 $5(=UNIT 번호)가 아니라 **마지막 필드**다 — 앞 5필드를 잘라내야 한다.)
LINES=$(awk -f "$TMPD/s53.awk" "$HOME/.claude/docs/superpowers/plans"/*.md "$HOME/.claude/docs/ai-context"/*.md 2>/dev/null \
     | awk -F'\t' -v L="$HOME/.claude/docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md" '$1=="NOISO" && $2==L { l=$0; sub(/^([^\t]*\t){5}/, "", l); print l }' \
     | sed 's/[[:space:]][[:space:]]*/ /g')
N=$(printf '%s\n' "$LINES" | grep -c .)
CK=$(printf '%s\n' "$LINES" | sort | cksum | tr -d ' ')
echo "호출 줄수=$N 동결값=$CK"
# ★위생 검사는 「빈 입력이 아님」이 아니라 **줄 수**여야 한다(슬롯 1 C4 실측).
#   판별식 결함으로 8줄 중 1줄이 빠져 7줄만 잡혀도 cksum 은 빈 입력값(42949672950)이 아니므로
#   「비어 있지 않은가」식 가드는 통과하고, 누락된 호출이 신규 위반 검사와 대장 동일성 검사 **양쪽에서
#   영구히 사라지면서** verify-setup 은 91/0 이 된다. 「빈 입력 아님」은 필요조건일 뿐이다.
[ "$N" -eq 8 ] || { echo "✗ 호출 줄수=$N (기대 8 — 6단위/8호출줄). 판별식 또는 경로가 어긋났다"; exit 1; }
perl -pi -e "s/\@\@S53_LEDGER_CKSUM\@\@/$CK/g" setup/verify-setup.sh
grep -c 'S53_LEDGER_CKSUM' setup/verify-setup.sh
```

Expected: `호출 줄수=8` · `동결값=3763352650710` · 마지막 `grep -c` → **0**(플레이스홀더 전부 치환).

★이 두 값은 **추정이 아니라 실측**이다 — Phase P 말미에 이 plan 의 `S53_AWK` 를 그대로 추출해
실코퍼스에 돌려 얻었다(같은 실행에서 자기-시험 픽스처는 `ISO,NOISO,NOISO,NOISO,NOISO,`,
대장 **밖** NOISO 는 **0건**, `LIVE` 단위는 이 plan 4건 = 선언 `LIVE-INTENT-총계: 4` 와 일치).
그 실행이 잡아낸 실제 결함이 하나 있다 — Task 4 Step 5 ⓒ 의 초고가 stub 을 `codex-stub` 으로 지어
실제 `codex` 를 가리지 못했고 격리 토큰도 줄 이어쓰기로 떨어져 있어 **이 plan 자신이 NOISO** 였다.
동결값이 다르게 나오면 대장 파일이 바뀐 것이므로 **먼저 그 이유를 확인**하고 값을 갱신한다.
★줄 수가 8 이 아니면 **멈춘다** — 이 시점의 잘못된 동결값은 되돌리기 어렵다(다음 사이클이 그 값을
정본으로 신뢰한다). B4 정정(따옴표 양끝 벗기기) 때문에 이전보다 더 잡힐 수도 있으니, 8 이 아니면
실제로 무엇이 늘거나 줄었는지 `printf '%s\n' "$LINES"` 로 먼저 확인하고 이 숫자를 갱신할지
판별식을 고칠지 판단한다.

- [ ] **Step 5: C22 plan 부기 (왜곡 없는 공개)**

`docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md` 의 실행 절 머리(첫 `## ` 섹션 앞)에 넣는다:

```markdown
> ★C23 부기(2026-08-18): 아래 증거 블록 중 6건은 seal #53 착륙 **전**에 실행돼 격리 없이 라이브
> 원장(`$HOME/.claude/.orca-rpi`)에 도달했다(non-obvious #5). 기록을 왜곡하지 않기 위해 소급 편집을
> 하지 않고 seal 의 1회성 예외 대장에 등재했다 — **재실행할 때는 반드시 격리 접두를 붙일 것.**
```

- [ ] **Step 6: README 카운트 동기 + GREEN 확인**

```bash
cd "$HOME/.claude"
perl -pi -e 's/현재 90 PASS/현재 91 PASS/' README.md
grep -n '현재 [0-9]\+ PASS' README.md
bash setup/verify-setup.sh 2>&1 | tail -6
```

Expected (GREEN): `verify-setup: PASS=91 FAIL=0` + `✓ 부작용-차단 주입 명시: 미격리 캐리어 호출 0 …`
+ `✓ verify-setup 카운트 seal: README 선언(91) == 런타임 실측(91)`.

- [ ] **Step 7: 커밋**

```bash
cd "$HOME/.claude"
git add setup/verify-setup.sh README.md docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md
git commit -m "feat(seal): C23 T6 — seal #53 부작용-차단 주입 명시 (non-obvious #5 SMART ①②)"
```

---

## Task 7: seal-regression 뮤테이터 2건 + witness 확장

**Files:**
- Modify: `setup/tests/seal-regression.test.sh` — `witness()`(`:19`) 확장 · 뮤테이터 2개 · 단언 2줄

**Interfaces:**
- Consumes: Task 6 의 seal #53 FAIL 문자열(`부작용-차단 주입 누락` · `1회성 예외 대장 drift`)
- Produces: 단언 27 → **29**

- [ ] **Step 1: witness 확장 — 뮤테이터가 건드릴 수 있는 파일 2개 추가**

`witness()` 의 파일 목록 끝(`docs/ai-context/model-policy.md` 뒤)에 추가:

```bash
docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md docs/ai-context/c21-orca-mode-design.md
```

- [ ] **Step 2: 뮤테이터 2개 추가 (`mut_pathpass_interp` 정의 뒤)**

```bash
# Mutator 24 (C23) — seal #53 의 RED ⓐ: 대장 **밖** plan 에 격리 없는 캐리어 호출을 1건 주입한다.
# ★호출 문자열은 **런타임 조립**한다 — 소스에 리터럴로 적으면 이 파일이 스캔 대상은 아니지만
#   (코퍼스는 plans/ + docs/ai-context/) 같은 클래스의 자기-오염을 습관으로 만들지 않기 위함이다.
mut_s53_unisolated() {
  local p; p="$1/docs/superpowers/plans/c23-mutant-probe.md"
  { printf '# mutant\n\n'; printf 'bash bin/orca-%s.sh spawn --run r --task t\n' "rpi"; printf '\n'; } > "$p"
}
# Mutator 25 (C23) — seal #53 의 RED ⓑ: 대장 파일에서 **개수를 유지한 채 치환**한다(기존 위반 1건에
# 격리 접두를 붙이고 텍스트가 다른 새 위반 1건을 추가). 개수 동결이면 6→6 이라 무발화하고,
# 호출 줄 집합 cksum 동결에서만 RED 가 된다 — 「개수가 아니라 동일성」이 load-bearing 함의 증명.
mut_s53_substitute() {
  local p; p="$1/docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md"
  perl -0777 -i -pe 's{^(bin/orca-rpi\.sh spawn --run run_x --task task_x --model opus; echo "rc=\$\?")$}{ORCA_CLI_COMMAND=/x ORCA_RPI_RUNDIR=/y $1}m' "$p"
  # ★치환 성공을 스스로 단언한다(슬롯 1 C5). 대상 줄의 공백·인자 순서가 미래에 바뀌면 치환이 0건이 되고
  #   append 만 남아 **6→7 순증**이 된다 — cksum 은 어차피 바뀌므로 테스트는 계속 PASS 하는데
  #   「개수 유지 치환을 잡는다」는 이 뮤테이터의 존재 이유만 조용히 거짓이 된다.
  grep -q 'ORCA_CLI_COMMAND=/x ORCA_RPI_RUNDIR=/y bin/orca-rpi.sh spawn' "$p" \
    || { echo "  (mut_s53_substitute: 치환 0건 — 대상 줄이 바뀌었다. 개수-유지 변이를 만들지 못했다)"; return 1; }
  { printf '\n'; printf 'bash bin/orca-%s.sh gate create --task t9 --question q9\n' "rpi"; printf '\n'; } >> "$p"
}
```

- [ ] **Step 3: 단언 2줄 추가 (`pathpass_interp` 줄 뒤, `:199` 다음)**

```bash
assert_seal_fires "s53_unisolated"  mut_s53_unisolated  "부작용-차단 주입 누락"
assert_seal_fires "s53_substitute"  mut_s53_substitute  "1회성 예외 대장 drift"
```

- [ ] **Step 4: 표적 부분집합 실행 — 신규 뮤테이터 2건만 (~6분)**

★**여기서 full 을 돌리지 않는다.** Task 8 이 `setup/install.sh`(replica 복제 대상)를, Task 9 가
`skills/start-rpi-cycle/SKILL.md`(**witness 목록 `:19` 에 실재**)를 편집한다. 지금 40분짜리 full 을
돌리면 그 결과는 두 편집 *이전* 트리의 인증이고, 편집을 미루면 이번엔 「실행 중 편집 금지」(물리 제약,
C22 에서 `✗ live MUTATED` 로 실증)와 부딪힌다. **full 은 「검증 수열」 4번에서 1회** 돈다 —
그 시점은 **Task 8·9 완료 후 · Task 10 Step 1-2 뒤**이고, Task 10 Step 3(`review-yield.md` append —
witness 파일)은 그 실행이 **끝난 뒤**다. 세 문면이 같은 순서를 가리키게 맞춰 둔다(Gate P 실측 M2 ·
슬롯 1 D3 — 초안은 「Task 10 이 끝난 뒤」와 「Step 3 은 4번 뒤」가 동시에 참일 수 없었다).

부분집합은 원본을 건드리지 않고 사본에서 만든다 — 신규 라벨(`s53_*`)만 남기고 나머지 단언을
주석 처리한다. control 과 live-immutability 단언은 무조건 남는다(둘 다 `assert_seal_fires` 호출이
아니라서 필터에 안 걸린다).

```bash
cd "$HOME/.claude"
T=$(mktemp -d)
awk '/^assert_seal_fires "/ && $0 !~ /"s53_/ { print "#" $0; next } { print }' \
    setup/tests/seal-regression.test.sh > "$T/subset.sh"
grep -c '^assert_seal_fires "' "$T/subset.sh"
bash "$T/subset.sh" 2>&1 | tail -8
rm -rf "$T"
```

Expected: `grep -c` → **2**(s53 둘만 살아남음) · `seal-regression: PASS=4 FAIL=0`
(control 1 + s53 2 + live-immutability 1) + `✓ live ~/.claude untouched (witness cksum stable across run)`.
`s53_substitute` 가 PASS 한다는 것은 **개수가 유지된 치환을 잡았다**는 뜻이다(§11.10 ③ B1 해소의 실증).
둘 중 하나라도 `rc=0, missing «…»` 으로 떨어지면 Task 6 의 seal 이 그 변이를 못 잡는 것이므로
뮤테이터가 아니라 **seal 쪽을 고친다**(뮤테이터를 seal 에 맞추면 판별력 공백이 그대로 봉인된다).

- [ ] **Step 5: 커밋**

```bash
cd "$HOME/.claude"
git add setup/tests/seal-regression.test.sh
git commit -m "test(seal): C23 T7 — seal #53 뮤테이터 2건(대장 밖 주입 · 동수 치환) 27→29"
```

---

## Task 8: T17 — `setup/install.sh` 배포 계약

**Files:**
- Modify: `setup/install.sh:79` 부근(REQUIRED 배열) · `:98-100`(chmod 블록)

**Interfaces:**
- Consumes: 없음
- Produces: `$TARGET/bin/orca-rpi.sh` 배포 보장 + 실행 비트

- [ ] **Step 1: RED — 현재 계약의 구멍 실측**

```bash
cd "$HOME/.claude"
grep -n 'bin/' setup/install.sh
git ls-files -s bin/orca-rpi.sh bin/claude-ocx
```

Expected (RED): REQUIRED 에 `bin/claude-ocx` 는 있고 `bin/orca-rpi.sh` 는 **없다** ·
chmod 대상이 `setup/`·`hooks/`·`hooks/tests/` 뿐이라 **`bin/` 이 통째로 빠져 있다**(`bin/claude-ocx` 도 같은 구멍) ·
git index mode 는 `100755`.

- [ ] **Step 2: REQUIRED 등재**

`"$TARGET/bin/claude-ocx"` 줄 바로 뒤에 추가:

```bash
  "$TARGET/bin/orca-rpi.sh"
```

- [ ] **Step 3: `bin/` 실행 비트 부여**

chmod 블록(`:98-100`)의 마지막 줄 뒤에 추가:

```bash
chmod +x "$TARGET/bin/"* 2>/dev/null || true
```

- [ ] **Step 4: 검증 — 전체 실행 금지, 계약만 확인 (Global Constraint 4)**

`setup/doctor.sh:235-260` 이 `gh api` 로 skill 을 자동 설치하므로 `install.sh` 를 통째로 돌리지 않는다.
대신 **REQUIRED 배열만 떼어 내 계약 검사**로 확인한다(네트워크 0회 · 설치 0회 · chmod 0회 —
소스하는 것은 배열 리터럴뿐이라 `install.sh` 의 어떤 부작용 줄도 실행되지 않는다).

★검사 기준은 **워킹트리**다. `git archive HEAD` 는 이번 편집 *이전* 스냅샷이라 Step 2 를 되돌린
`REQUIRED=34` 를 재확인할 뿐이고, 그러면 이 Step 은 자기 편집을 검사하지 못한다(Gate P 실측 M1).
아직 커밋 전이므로 워킹트리가 유일한 최신 계약이다.

```bash
cd "$HOME/.claude"
bash -n setup/install.sh && echo "bash -n OK"
REQ=$(mktemp)
sed -n '/^REQUIRED=(/,/^)/p' setup/install.sh > "$REQ"
TARGET="$HOME/.claude" bash -c 'source "$1"
M=0; for f in "${REQUIRED[@]}"; do [ -f "$f" ] || { echo "MISSING: $f"; M=$((M+1)); }; done
echo "REQUIRED=${#REQUIRED[@]} MISSING=$M"' _ "$REQ"
rm -f "$REQ"
grep -n 'chmod +x "\$TARGET/bin/"' setup/install.sh
git ls-files -s bin/orca-rpi.sh bin/claude-ocx
```

Expected: `bash -n OK` · `REQUIRED=35 MISSING=0`(34 → 35) · `chmod` grep 1줄 히트 ·
git index mode 둘 다 `100755`.
`REQUIRED=34` 가 나오면 Step 2 편집이 배열 밖(다른 배열·주석)에 떨어진 것이다.

- [ ] **Step 5: seal #29 무회귀 + 커밋**

```bash
cd "$HOME/.claude"
bash setup/verify-setup.sh 2>&1 | grep -iE 'install|REQUIRED' ; bash setup/verify-setup.sh 2>&1 | tail -3
git add setup/install.sh
git commit -m "feat(install): C23 T17 — REQUIRED 에 bin/orca-rpi.sh 등재 + bin/ 실행 비트"
```

---

## Task 9: T15 — Phase I 옵션 (e) + §19.5 조항 착륙 (정본 + 미러)

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md` — Phase I 옵션 (e)(**(d) 블록 끝 `:166` 뒤 · `권장:` `:168` 앞**) ·
  Gate R/Gate P/Closeout success_criteria 3곳
- Modify: `opencode-harness/skill/start-rpi-cycle/SKILL.md` — 동반(미러, seal #50 conjunct ③)

**Interfaces:**
- Consumes: `bin/orca-rpi.sh preflight` 의 rc=3 폴백 계약
- Produces: RPI 절차에 Orca 진입점. §11.10 ⑧ 의 TO-BE 이행.

- [ ] **Step 1: RED — 현 상태 실측**

```bash
cd "$HOME/.claude"
grep -ci orca skills/start-rpi-cycle/SKILL.md
grep -ci orca opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -rn "19\.5" skills/ | wc -l
grep -rniE '자기 산출물|실행 가능성' skills/ | wc -l
```

Expected (RED): 앞 둘 **0** — RPI 절차에 Orca 진입점이 없다. 뒤 둘 **0** — C20 §19.5 처분이 미착륙이다.

- [ ] **Step 2: 정본에 옵션 (e) 추가 — (d) 블록 **뒤**, `권장:` 앞**

★삽입 위치는 **(d) 뒤**다. (c) 뒤에 넣으면 목록이 a,b,c,e,d 순이 되고, 무엇보다 (d) 는
`- (d) …` 한 줄이 아니라 `:152`–`:166` 의 **15줄 블록**(※ 주석 9개 포함)이라 「(c) 줄 뒤」와
「(d) 앞」이 같은 지점을 가리키지도 않는다. 앵커는 줄 번호가 아니라 텍스트로 잡는다 —
`권장:` 바로 앞의 빈 줄이 유일하게 안정적인 경계다.

```bash
cd "$HOME/.claude"
grep -n '^권장:' skills/start-rpi-cycle/SKILL.md   # 삽입 직전 실측 — :168 예상
```

```markdown
- (e) **Orca 감독 사이클** — Phase 를 Orca ADE Task DAG 로 돌린다(포인터: `Skill(orca-rpi-cycle)`).
      진입 전 `bash ~/.claude/bin/orca-rpi.sh preflight` 가 rc=0 이어야 하며, **rc≠0 이면(Orca
      미설치·미가동 무관) 자동으로 (a)/(d) 로 폴백**한다 — Orca 는 선택적 가속기이지 사이클의 전제가
      아니다. (rc=3 = 설치돼 있으나 미가동/전제 미충족 · rc=1 = 실행자 부재·경로 오지정. rc=3 만
      폴백시키면 **설치가 금지된 환경의 미설치 머신이 폴백 밖에 놓여** 사이클이 멈춘다.)
      ★**사이클 브랜치에서만** — 캐리어가 `master`/`main` 에서 non-readonly 스폰을 코드로 거부한다
      (워커가 같은 체크아웃에 커밋해 머지 승인이 사후 무력화되는 것을 막는다).
      상세는 `docs/ai-context/c21-orca-mode-design.md` §7·§11.10.
```

- [ ] **Step 3: 미러에 옵션 (e) 추가 — 미착륙으로 명시**

`opencode-harness/skill/start-rpi-cycle/SKILL.md` — 정본과 같은 규칙으로 **(d) 블록(`:162`–`:175`) 뒤,
`권장:`(`:177`) 앞**에 넣는다(미러의 (d) 는 정본과 내용이 다르다 — Workflow 도구 부재라 「순차
execute-strict→review-strict」다. 번호만 맞추고 본문은 각자 것을 유지):

```markdown
- (e) **Orca 감독 사이클 — 이 번들에서는 미착륙.** opencode 번들에는 `bin/` 자체가 없고 Orca 워커
      진입점이 Claude Code 이기 때문이다. 없는 경로를 있다고 쓰지 않는다(capstone 3-계층 정직공개).
      Claude Code 하네스에서는 가용하다 — `~/.claude/skills/start-rpi-cycle/SKILL.md` 옵션 (e).
```

- [ ] **Step 4: §19.5 조항을 3개 게이트 success_criteria 에 착륙 (정본 + 미러)**

Gate R · Gate P · Closeout Step C-1 의 `success_criteria="` 블록 각각에 아래 1줄을 추가한다.

```markdown
          - **자기 산출물의 전제·실행 가능성을 실측으로 확인했는가** — 검증 대상이 인용한 줄 번호·
            grep 결과·파일 존재를 직접 재현하고, 재현되지 않으면 그 항목은 FAIL (C20 spec §19.5 처분)
```

Gate P 에는 `LIVE-INTENT` 검토 조항도 함께 넣는다(§11.10 ③ 의 지시문 층 보정):

```markdown
          - plan 의 `LIVE-INTENT` 사용 건수·사유가 타당한가 (자기-면제이므로 게이트가 제2자 검토를
            대신한다 — 총계 parity 는 seal #53 이 코드로 표면화하되 타당성 판단은 여기서 한다)
```

- [ ] **Step 5: seal #50 미러 conjunct 무회귀 + 정합 확인**

```bash
cd "$HOME/.claude"
grep -c 'FABLE-TAKEOVER' opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -c '위임 X' opencode-harness/skill/start-rpi-cycle/SKILL.md
grep -c '자기 산출물의 전제' skills/start-rpi-cycle/SKILL.md
grep -c '자기 산출물의 전제' opencode-harness/skill/start-rpi-cycle/SKILL.md
bash setup/verify-setup.sh 2>&1 | tail -3
```

Expected: `FABLE-TAKEOVER` ≥1 · `위임 X` **0** · `자기 산출물의 전제` 가 정본 **3** · 미러 **3** ·
`verify-setup: PASS=91 FAIL=0`.

- [ ] **Step 6: 커밋**

```bash
cd "$HOME/.claude"
git add skills/start-rpi-cycle/SKILL.md opencode-harness/skill/start-rpi-cycle/SKILL.md
git commit -m "feat(rpi): C23 T15 — Phase I 옵션 (e) Orca 감독 사이클 + §19.5 자기-전제 조항 착륙(미러 동반)"
```

---

## Task 10: floor 한정 재심 판정 + `review-yield.md` 기록

**Files:**
- Modify: `docs/ai-context/review-yield.md` — C23 절 append
- Modify: `docs/superpowers/specs/2026-07-25-model-policy-design.md` — **§21 신설**(말미 append)
  (**혼합 개행 CR=1823 — `perl -0777 -i` 만 사용, `Edit` 금지**)
  ★번호 주의: `§19.6` 은 **이미 존재**한다(`:2374` 「§19.6 검증 계획」 — C20 소유). 현존 최고 번호는
  `§20.7`(`:2599`)이므로 C23 판정은 **`§21`** 로 신설한다. 기존 번호에 덧쓰면 C20 의 검증 계획이
  이 판정으로 가려진다(Gate P 실측 B4).

**Interfaces:**
- Consumes: §18.1 트리거 (b)(C22 에서 성립 — 「차기 floor 한정 재심 1회 예약」) · §19.5 반증 조건
- Produces: floor 재심 판정 1건. 이 사이클의 layer-yield 행.

- [ ] **Step 1: 재심 입력 실측**

```bash
cd "$HOME/.claude"
sed -n '2340,2375p' docs/superpowers/specs/2026-07-25-model-policy-design.md
tail -8 docs/ai-context/review-yield.md
# 번호 충돌 사전 확인 — 신설 번호가 진짜로 비어 있는지
grep -n '^#\+ *§2[0-9]' docs/superpowers/specs/2026-07-25-model-policy-design.md | tail -5
```

Expected: `§19.5`(`:2348`)와 `§19.6 검증 계획`(`:2374`)이 보이고, 마지막 `grep` 의 최대 번호가
**`§20.7`**(`:2599`) 다. `§21` 이 출력에 있으면 이미 누가 쓴 것이므로 **다음 빈 번호로 올린다**.

- [ ] **Step 2: 판정 작성 — §21 을 spec 말미에 append**

판정의 뼈대는 이미 실측으로 정해져 있다(§11.10 ⑧): §19.5 의 처분이 **미착륙**이었으므로 반증 조건
(「지시문 보강 착륙 후 같은 클래스 재발」)이 아직 **평가 불가**였고, 따라서 C21·C22 의 BLOCKER 는
floor-축 반증 입력이 되지 못한다.

이 파일은 혼합 개행(CR=1823)이라 `Edit` 을 쓰면 전 파일이 LF 로 통일돼 거대한 거짓 diff 가 난다.
**append 만** 한다(`cat >> …` 또는 `perl -0777 -i -pe` 로 말미 추가). 아래가 그 문안이다.

```markdown
## §21 floor 한정 재심 (C23 — §18.1 트리거 (b) 소비)

**입력**: C19 가 예약한 재심 1회. 트리거 (b) = GPT 슬롯이 내부-통과 BLOCKER 를 C21·C22 **2사이클 연속** 적발.

**판정: floor 무변경**(`max(작업자, opus)` 유지). 근거 3:
1. **반증 입력이 성립하지 않는다.** §19.5 는 반증 조건을 「**지시문 보강 착륙 후** 같은 클래스 재발」로
   정의했는데, 그 보강(자기-전제 실측 조항)이 C23 Task 9 **이전까지 어느 skill 에도 착륙하지 않았다**
   (실측: `grep -rn "19\.5" skills/` → 0건). 따라서 C21·C22 의 BLOCKER 는 floor 를 반증하지 못한다.
2. **이번 사이클이 대안 가설을 지지한다.** C23 Gate R 은 같은 floor(opus)에서 조항을 **프롬프트에
   손으로 주입**하자 자기-전제 결함을 5회차에 걸쳐 잡아냈다(개정 이력 참조). 즉 부족했던 것은
   *검증자 티어*가 아니라 *검증 지시문*이었다는 쪽에 증거가 쌓였다.
3. **처분은 티어가 아니라 지시문 축으로 간다** — C20 §19.5 가 정한 그대로다. C23 Task 9 가 그 조항을
   Gate R·Gate P·Closeout 에 착륙시켰으므로, **다음 사이클부터 §19.5 의 반증 조건이 처음으로 평가 가능**해진다.

**차기 재심 트리거**: 조항 착륙 후에도 교차패밀리 슬롯이 내부-통과 BLOCKER 를 적발하면 (b)가 재성립하며,
그때의 재심은 **반증 입력이 유효하므로** floor 상향을 실질 검토한다.
```

```bash
cd "$HOME/.claude"
grep -c '^## §21 floor 한정 재심' docs/superpowers/specs/2026-07-25-model-policy-design.md
grep -c '^### §19.6 검증 계획' docs/superpowers/specs/2026-07-25-model-policy-design.md
perl -ne '$n++ if /\r/; END{print "CR=$n\n"}' docs/superpowers/specs/2026-07-25-model-policy-design.md
```

Expected: 첫 `grep -c` → **1**(신설 절 1개) · 둘째 → **1**(C20 §19.6 이 살아 있음 — 덧쓰기 안 함) ·
`CR=1823`(불변 — `Edit` 이 아니라 append 를 썼다는 증거).

- [ ] **Step 3: `review-yield.md` 에 C23 절 append**

Closeout 직전에 층별 실측을 채워 넣는다(§15.3 S19 — 말미 층 실측 후 append).

```markdown
## C23 (cycle 74, 2026-08-18) — Orca 캐리어 자기-적용

- Gate R: FAIL→정정 · 실발견 10 · 발견
- Gate R 델타 재심 ×5: `1 PASS/4 FAIL` · 실발견 20(7+7+2+4+0, 5회차 0으로 종결) · 발견
- Gate P: FAIL→정정 · 실발견 9(BLOCKER 4 · MEDIUM 2 · MINOR 3) · 발견
- Gate P 델타 재심 ×1: `1 PASS/0 FAIL` · 실발견 0(지목 9건 전건 해소 확인) · 확인
- stage2 ×N: … · 통합(senior+drift): … · 교차패밀리 슬롯2: …
- 교차패밀리 슬롯1(GPT sol/ultra, Gate P 델타 재심 PASS 직후): 실행 · 실발견 30 · 발견
  (제기 33 → 트리아지 채택 30 / 기각 3. 2단계 트리아지 — 1단계 증거 수집 opus ×5 병렬, 2단계 판정 메인)
- **트리거 대조(§18.1 판정 3)**: (a) … · (b) … · (c) … · (d) …
- **floor 재심 판정**: 무변경 — §19.5 반증 조건이 지시문 미착륙으로 **평가 불가**였음(spec §21)
```

```bash
cd "$HOME/.claude"
grep -c '^## C23 (cycle 74' docs/ai-context/review-yield.md
grep -c '트리거 대조' docs/ai-context/review-yield.md
```

Expected: 첫 `grep -c` → **1** · 둘째 → **≥1**(§18.1 판정 3 의 트리거 대조 1줄이 실재).
`…` 자리표시자가 하나라도 남아 있으면 이 Step 은 미완이다 — 실측 수치로 전부 치환한다.

- [ ] **Step 4: 커밋**

```bash
cd "$HOME/.claude"
perl -ne '$n++ if /\r/; END{print "CR=$n\n"}' docs/superpowers/specs/2026-07-25-model-policy-design.md
git add docs/superpowers/specs/2026-07-25-model-policy-design.md docs/ai-context/review-yield.md
git commit -m "docs(policy): C23 T-floor — §21 floor 한정 재심 판정(무변경) + review-yield C23 절"
```

Expected: CR=**1823**(불변 — 혼합 개행 보존 확인).

---

## 검증 수열 (Closeout 전 필수)

| 순서 | 명령 | 기준선 | 목표 |
|---|---|---|---|
| 1 | `bash setup/verify-setup.sh` | 90/0 | **91/0** |
| 2 | `bash hooks/tests/run-all.sh` | 305/305 | 305/305 (무회귀) |
| 3 | `bash setup/tests/orca-carrier.test.sh` | (신규) | **20/0** |
| 4 | `bash setup/tests/seal-regression.test.sh` | 27/0 | **29/0** (full 필수 — setup/ diff 존재) |
| 5 | `bash setup/verify-all.sh` | ALL PASS | ALL PASS (STAGE 2e 포함) |

4번은 **Task 8·9 완료 후, Task 10 Step 1-2 뒤** 1회 돈다 — Task 8(`setup/install.sh`, replica 복제 대상)·
Task 9(`skills/start-rpi-cycle/SKILL.md`, **witness `:19`**)가 seal-regression 의 입력을 바꾸므로
그 전에 돌린 full 은 최종 트리를 인증하지 못한다(Task 7 Step 4 는 표적 부분집합 4/0 만).
4번 실행 중에는 **`~/.claude` 를 편집하지 않는다**(witness cksum 불변이 물리 전제 — C22 에서
`✗ live ~/.claude MUTATED during run` 으로 실증). Task 10 Step 3 의 `review-yield.md` append 는
witness 파일이므로 **4번이 끝난 뒤**에 한다(실행 전/후는 무관, 실행 *중*만 금지).

## 선언된 잔여

1. **seal #53 탐지 범위 = 캐리어 호출 한정** — `"$ORCA" orchestration <변이>` 직접 호출과
   `bin/claude-ocx` 직접 호출은 미탐이다. 덮으려면 orchestration 28개 서브커맨드의 읽기/변이 분할을
   먼저 실측해야 하고 이번 사이클에 그 실측이 없다(§11.10 ③).
2. **1회성 예외 대장의 좁은 잔여** — 위반 1건을 격리하며 **바이트 동일 텍스트**의 새 위반을 다른
   위치에 넣으면 cksum 이 불변이라 무발화한다. 줄 번호 이동 불변성의 직접 귀결이며 감수한다.
   (다만 정렬이 `sort` 이지 `sort -u` 가 아니라 **다중집합**이 보존되므로, 현 코퍼스처럼 바이트 동일
   줄이 이미 2개 있으면 그중 하나만 격리해도 발화한다 — 설계가 우연히 옳은 지점이다.)
3. **`LIVE-INTENT` parity 는 자기-정합 검사** — 같은 커밋에서 총계를 함께 올리면 통과한다.
   잡는 것은 *침묵의* 추가이지 의식적 확장이 아니다.
4. **DRYRUN 은 원장 뮤텍스를 검증하지 않는다** — 동시-1 상한은 본질적으로 쓰기라 dry 경로로 검증
   불가. 그 축은 stub `$ORCA` + `ORCA_RPI_RUNDIR` 격리 경로가 계속 담당한다.
5. **`--retry-request` 는 실측 확인된 명령에만 배선** — `task-create`/`gate-create`/`check` 는
   **Task 1 Step 2** 의 `--help` 결과에 따라 확장하거나 **미확인으로 남긴다**. help 실측 자체가
   불가능하면(`orca.exe` 부재) 이미 실측된 `run-create`·`worker-start` 2개에 한정한다.
6. **Task 1 부분 실패 시 `[C23]` Run 이 잔존할 수 있다** — `run-create` 커밋 후 응답 유실이나 후속
   `task-create` 실패가 나면 재실행 없이 멈춘다. 멱등 재발행 수단(`--retry-request`)이 Task 4 에서야
   착륙하고 그 배선의 입력이 이 측정이라, 이 부트스트랩 순환은 순서로 풀 수 없다. `run-delete` 가
   부재하므로 처분은 정리가 아니라 **기록**이다(잔존 id 를 probe 문서에 남긴다 — 슬롯 1 D6).
7. **`handoff` 브랜치 가드는 `wt_sel` 축의 근사** — 실제 워커가 뜨는 워크트리는 **dispatch 소유**인데
   가드는 `wt_sel` 을 읽는다. 둘이 갈리면(`preflight` 가 매 실행 덮어쓴다) 가드가 다른 곳을 판정한다.
   dispatch→워크트리 바인딩이 `[P2]` 미측정이라 이번 사이클에 닫지 못한다 — Task 1 의 `jq paths`
   전수 출력에 워크트리 필드가 나오면 차기 사이클에 상향한다(슬롯 1 A1 · spec §11.10 ①).
8. **`handoff` 의 `[P2]` 2사이트는 미해제로 남는다** — `handoff` 를 호출하지 않으므로 미측정이고,
   terminal 기반 `worker-start` 응답이 agent 기반과 동형이라는 보장이 없다. 「전부 해제」로 쓰면
   추정을 실측으로 승격하게 되므로 마커를 유지하고 사유를 명시한다(슬롯 1 A6 · spec §11.10 ⑤).
9. **`gpt` 비용 원장의 쓰기 실패는 흡수된다** — 권한·ACL 실패가 `|| true` 로 삼켜져 호출자에게
   드러나지 않는다. 여기서 `die` 하면 executor 의 「stdout·rc 바이트 그대로 통과」 계약이 비용 부기
   실패 때문에 깨지므로 의도된 advisory 성질이다. 다만 **형식**(헤더·컬럼·`n/a`)은 Task 5 의
   상설 단언이 stub 경로로 1회 실측한다(슬롯 1 A7 → C3 로 이관).
