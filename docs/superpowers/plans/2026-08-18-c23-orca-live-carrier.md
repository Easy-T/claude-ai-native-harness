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

**Spec:** `docs/ai-context/c21-orca-mode-design.md` — 특히 **§11.10**(C23 설계 결정 ①~⑧, 4차 정정 판본).
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
   (`ORCA_CLI_COMMAND=<stub>` **및** `ORCA_RPI_RUNDIR=<임시>`)로 격리하고 **부작용 로그 0줄**을 단언한다.
   Task 1 만이 **의도-라이브**이며 그 블록에는 `LIVE-INTENT(<사유>)` 가 붙어 있다.
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
7. **혼합 개행 파일은 `Edit` 금지, `perl -0777 -i` 만** — `docs/superpowers/specs/2026-07-25-model-policy-design.md`
   (CR=1823) · `docs/ai-context/c21-orca-mode-design.md`(CR=728). CR 계수는
   `perl -ne '$n++ if /\r/; END{print "$n\n"}'` 만 신뢰한다(`grep -c` 는 MSYS 에서 조용히 틀린다).
8. **경로는 argv/stdin 으로 전달** — 인라인 인터프리터 소스에 셸 변수 보간·리터럴 `/tmp/` 금지(non-obvious #3, seal #52).
9. **기준선**: `setup/verify-setup.sh` 90 PASS / 0 FAIL · `hooks/tests/run-all.sh` 305/305 ·
   `setup/tests/seal-regression.test.sh` 27/0. Task 7 이 verify-setup 을 **91**, seal-regression 을 **29** 로 올린다.
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
- Modify: `bin/orca-rpi.sh:232,234` (spawn dispatch id) · `:296,298` (wait delivery id) ·
  `:323,326` (handoff handle) · `:352,353` (handoff dispatch id) · `:411,413` (gate id)
- Modify: `docs/ai-context/c22-orca-probe-measured.md` (append — 새 파일 금지)

**Interfaces:**
- Consumes: 없음(첫 task)
- Produces: 실측 확정된 jq 경로 4종. Task 2~4 는 같은 파일을 편집하므로 **이 task 이후 순차 실행**한다.

- [ ] **Step 1: 스테일 원장 슬롯 해제 (증거 먼저 기록)**

C22 의 stub 검증이 라이브 `$HOME/.claude/.orca-rpi` 에 직접 써서 `t1` 이 남아 있다(§11.10 ②).
그대로 두면 C23 의 첫 non-readonly spawn 이 상한 초과로 거부된다. 지우기 **전에** 상태를 남긴다.

```bash
cd "$HOME/.claude"
echo "--- BEFORE ---"; ls -la .orca-rpi/; cat .orca-rpi/active-nonreadonly.tasks
cp .orca-rpi/active-nonreadonly.tasks "$HOME/.claude/.orca-rpi/stale-t1.evidence" 2>/dev/null
: > .orca-rpi/active-nonreadonly.tasks
echo "--- AFTER ---"; wc -l < .orca-rpi/active-nonreadonly.tasks
```

Expected: BEFORE 에 `t1` 1줄, AFTER 에 `0`. 이 출력을 Step 8 의 probe 문서 append 에 인용한다.

- [ ] **Step 2: preflight (라이브 · rc=0 확인)**

`LIVE-INTENT(응답 shape 실측이 이 사이클의 주축 산출물 — 스텁으로는 측정 불가)`

```bash
cd "$HOME/.claude"
git rev-parse --abbrev-ref HEAD          # orca-cycle-23 여야 한다(master 면 중단)
bash bin/orca-rpi.sh preflight; echo "rc=$?"
cat .orca-rpi/wt_sel; echo
```

Expected: `preflight: OK worktree=<repoId>::<path>` + `rc=0`.
rc=3 이면 **자동 재시도 금지** — Orca 미가동이므로 이 task 를 여기서 중단하고
`docs/ai-context/c22-orca-probe-measured.md` 에 「preflight rc=3, 미측정 사유」를 append 한 뒤
Task 2 로 넘어간다(goal: 실패해도 원문 기록이 산출물이다).

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
`--retry-request` 수용 여부도 여기서 read-only 로 확인한다(부작용 0):

```bash
ORCA="C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe"
for c in run-create task-create worker-start gate-create check; do
  echo "=== $c ==="; "$ORCA" orchestration "$c" --help 2>&1 | grep -iE 'retry-request|exact recovery' || echo "(없음)"
done
```

- [ ] **Step 6: `[P2]` 주석 제거 + 실경로 반영**

측정 결과가 추정과 **같으면** 주석만 지우고, **다르면** jq 경로를 실측값으로 바꾼다.
아래는 추정이 전부 맞은 경우의 diff 형태다(다르면 경로 문자열만 교체).

```bash
cd "$HOME/.claude"
perl -0777 -i -pe '
  s/^\s*# dispatch id 실제 응답 shape 미측정.*\n//m;
  s/^\s*# gate id 필드 경로 미측정.*\n//m;
  s/^\s*# worker\.agent_terminal_handle 실제 응답 shape 미측정.*\n//m;
  s/^\s*# delivery id 필드 경로 미측정.*\n//m;
  s/\s*# \[P2\]$//mg;
' bin/orca-rpi.sh
grep -c '\[P2\]' bin/orca-rpi.sh
bash -n bin/orca-rpi.sh && echo "bash -n OK"
```

Expected: `grep -c` → **0** · `bash -n OK`. 미해제분이 있으면 그 사이트의 `[P2]` 는 **남기고**
주석을 「미해제 사유: …」로 바꾼다(침묵 잔여 금지).

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

# 판정 불가는 fail-closed — "커밋 대상이 머지 브랜치가 아님"을 단언할 수 없으면 스폰하지 않는다.
# fail-open 약속은 Orca *가용성* 축(preflight rc=3)의 것이지 안전 가드의 것이 아니다.
assert_branch_not_merge_target() {   # $1 = --worktree 값
  local p br
  p=$(worktree_path_of "$1")
  [ -n "$p" ] || p="$PWD"            # 문서화된 폴백 — 셀렉터 미획득 시에만
  br=$(git -C "$p" rev-parse --abbrev-ref HEAD 2>/dev/null) \
    || die "거부: 브랜치 판정 불가 — 'git -C $p rev-parse --abbrev-ref HEAD' 실패. 커밋 대상이 머지 브랜치가 아님을 단언할 수 없으면 스폰하지 않는다(fail-closed, 설계 §11.10 ①)"
  [ -n "$br" ] || die "거부: 브랜치 판정 불가 — 빈 브랜치명($p). fail-closed(설계 §11.10 ①)"
  case "$br" in
    master|main)
      die "거부: non-readonly 워커를 머지 대상 브랜치('$br' @ $p)에서 스폰할 수 없다 — 워커가 같은 체크아웃에 직접 커밋해 사람의 머지 승인이 사후 무력화된다. 사이클 브랜치를 만들어 체크아웃하라(설계 §11.10 ①)" ;;
  esac
  return 0
}
```

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

- [ ] **Step 7: 커밋**

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

(아래 `local resp rc extra=()`(`:215`)는 `local resp rc` 로 바꾼다.)

`cmd_wait` — `[ -n "$run" ] || die`(`:250`) 뒤:

```bash
  [ -n "$run" ] || die "wait: --run 필수"
  is_dryrun && dryrun_emit orchestration check --run "$run" --wait --types worker_done,escalation,question,decision_gate --timeout-ms "$timeout" --json
  require_jq; ensure_rundir
```

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
printf 'r::%s' "$D" > "$D/rd/wt_sel"
for s in "run --objective [C23]x" "task --title t --spec s" "spawn --run r --task t" "wait --run r" "handoff --task t --dispatch d" "release --dispatch d" "gate create --task t --question q" "preflight"; do
  OUT=$(env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_CLI_COMMAND="$D/no-such-orca" ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh $s 2>&1); RC=$?
  printf '%-40s rc=%s lines=%s first=%s\n' "$s" "$RC" "$(printf '%s\n' "$OUT" | wc -l)" "$(printf '%s\n' "$OUT" | head -1 | cut -c1-20)"
done
echo "rundir 파일 목록:"; ls -1 "$D/rd"
```

Expected (GREEN): 8개 전부 `rc=0` · `lines=1` · `first=DRYRUN:` ·
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

지역 변수 선언(`:137`)과 호출부(`:149`)도 함께 바꾼다:

```bash
  local objective="" retry_request=""
```

```bash
  local rr=()
  [ -n "$retry_request" ] && rr=(--retry-request "$retry_request")
  resp=$("$ORCA" orchestration run-create --objective "$objective" "${rr[@]}" --json)
```

`cmd_spawn` 도 같은 형태로 `--retry-request` 아암·변수·`extra` 전달을 추가한다.
Task 1 Step 5 에서 **수용이 확인되지 않은** 명령(`task-create`/`gate-create`/`check`)에는
**넣지 않는다** — 받는다고 가정하고 배선하지 않는다(§11.10 ④).

- [ ] **Step 2: 비-0 응답 시 정확 복구 명령 출력**

`cmd_run` 의 실패 분기(`:152`)를 아래로 교체한다. 봉투 최상위 `.id` 가 **요청 상관ID**이므로
그것이 곧 `--retry-request` 인자다(c22-probe P0-2).

```bash
  if [ "$rc" -ne 0 ]; then
    local req_id; req_id=$(printf '%s' "$resp" | jq -r '.id // empty' 2>/dev/null)
    if [ -n "$req_id" ]; then
      echo "run: 정확 복구(중복 레코드 없이 원 결과 회수) — 아래를 그대로 실행하라:" >&2
      echo "  $SELF run --objective '<같은 objective>' --retry-request $req_id" >&2
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

- [ ] **Step 5: 검증 — 인자 수용 · 원장 형식 (부작용 0줄)**

```bash
cd "$HOME/.claude"
D=$(mktemp -d); mkdir -p "$D/rd"; git -C "$D" init -q; git -C "$D" checkout -q -b c23-fixture
printf 'r::%s' "$D" > "$D/rd/wt_sel"
env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh run --objective "[C23]x" --retry-request req_123; echo "rc=$?"
env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_RPI_RUNDIR="$D/rd" bash bin/orca-rpi.sh run --objective "[C23]x" --retry-request; echo "빈값 rc=$?"
env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_RPI_RUNDIR="$D/rd" ORCA_RPI_LEDGER="$D/led.tsv" bash bin/orca-rpi.sh gpt --role verifier --prompt p --out "$D/o.txt"; echo "gpt rc=$?"
echo "원장 존재? $([ -f "$D/led.tsv" ] && echo yes || echo 'no — DRYRUN 이 원장 앞에서 멈췄다(정상)')"
```

Expected: 1번 `rc=0` + `DRYRUN: … --retry-request req_123 …` · 2번 `rc=1`(빈 값 거부) ·
3번 `rc=0` + `DRYRUN: codex exec …` · 원장 미생성(DRYRUN 이 부작용 앞에서 멈춘 증거).

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

# --- 픽스처: 비-머지-대상 브랜치의 임시 git repo (§11.10 ② ⓚ) --------------------
# 생성 실패는 SKIP 이 아니라 FAIL 이다 — 전제 미성립을 침묵시키지 않는다.
FIX="$ROOT/wt"; mkdir -p "$FIX"
git -C "$FIX" init -q 2>/dev/null || { echo "✗ 픽스처 git init 실패 — 전제 미성립"; exit 1; }
git -C "$FIX" checkout -q -b c23-dryrun-fixture 2>/dev/null || true
FIXBR=$(git -C "$FIX" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
case "${FIXBR:-}" in
  ""|master|main) echo "✗ 픽스처 브랜치='${FIXBR:-빈값}' — 비-머지-대상이어야 한다(전제 미성립)"; exit 1 ;;
esac
ok "픽스처: 임시 repo 브랜치='$FIXBR'(비-머지-대상) — 브랜치 가드 통과 조건 확보"

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
args_for() {
  case "$1" in
    preflight) printf '' ;;
    run)       printf -- '--objective|[C23] dryrun probe' ;;
    task)      printf -- '--title|t1|--spec|s1' ;;
    spawn)     printf -- '--run|r1|--task|t1' ;;
    wait)      printf -- '--run|r1' ;;
    handoff)   printf -- '--task|t1|--dispatch|d1' ;;
    release)   printf -- '--dispatch|d1' ;;
    gate)      printf -- 'create|--task|t1|--question|q1' ;;
    gpt)       printf -- '--role|verifier|--prompt|p1|--out|@OUT@' ;;
    selfcheck) printf '' ;;
    *) return 1 ;;
  esac
}

snapshot() { ( cd "$1" && find . -type f -exec cksum {} \; 2>/dev/null | sort ); }

for s in $SUBS; do
  if ! A=$(args_for "$s"); then
    bad "인자 표에 없는 신규 서브커맨드 '$s' — DRYRUN 게이트 미검증 상태로 추가됐다(fail-closed, §11.10 ② ⓔ)"
    continue
  fi
  RD="$ROOT/rd_$s"; mkdir -p "$RD"
  printf 'c23fixture::%s' "$FIX" > "$RD/wt_sel"
  ARGS=()
  if [ -n "$A" ]; then
    OLDIFS="$IFS"; IFS='|'; read -r -a RAW <<< "$A"; IFS="$OLDIFS"
    for x in "${RAW[@]}"; do
      [ -n "$x" ] || continue
      [ "$x" = "@OUT@" ] && x="$RD/out.txt"
      ARGS+=("$x")
    done
  fi
  BEFORE=$(snapshot "$RD")
  if [ "${#ARGS[@]}" -gt 0 ]; then
    OUT=$(cd "$SRC" && env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_CLI_COMMAND="$ROOT/no-such-orca" ORCA_RPI_RUNDIR="$RD" bash "$CARRIER" "$s" "${ARGS[@]}" 2>&1)
  else
    OUT=$(cd "$SRC" && env -u WT_SEL ORCA_RPI_DRYRUN=1 ORCA_CLI_COMMAND="$ROOT/no-such-orca" ORCA_RPI_RUNDIR="$RD" bash "$CARRIER" "$s" 2>&1)
  fi
  RC=$?
  AFTER=$(snapshot "$RD")
  LC=$(printf '%s\n' "$OUT" | grep -c '^DRYRUN: ')
  if [ "$(launch_count "$s")" -gt 0 ]; then
    if [ "$RC" -eq 0 ] && [ "$LC" -eq 1 ] && [ "$BEFORE" = "$AFTER" ]; then
      ok "기동군 '$s': DRYRUN 존중(rc=0 · DRYRUN: 1줄 · rundir 델타 0)"
    else
      bad "기동군 '$s': rc=$RC DRYRUN줄=$LC rundir델타=$([ "$BEFORE" = "$AFTER" ] && echo 0 || echo '≠0') — 출력: $(printf '%s' "$OUT" | head -2 | tr '\n' '|')"
    fi
  else
    if [ "$BEFORE" = "$AFTER" ]; then
      ok "비-기동 '$s': 외부 기동 없음 + 부작용 0(DRYRUN 면제 — 성질에 의한 분할)"
    else
      bad "비-기동 '$s': rundir 델타 ≠0 — 외부 기동이 없는데 쓰기가 있다"
    fi
  fi
done

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

Expected: `PASS=11 FAIL=0`(픽스처 1 + 서브커맨드 10) · `rc=0`.

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

Expected (RED): `✗ 인자 표에 없는 신규 서브커맨드 'newthing'` + `rc=1`.
이것이 「게이트 없는 신규 서브커맨드 추가」를 잡는 앵커다.

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
# 격리 토큰은 **같은 단위 + 앞 15줄**, LIVE-INTENT 는 **파일 안 앞뒤 15줄**(단위 무관)이 인정 범위다.
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
    for (j = 1; j <= nv; j++) { d = cl[i] - vl[j]; if (d < 0) d = -d; if (d <= 15) live = 1 }
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
    t = a[i]; gsub(/^["]+/, "", t)
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
      nx = a[i+1]; gsub(/^["]+/, "", nx)
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
  if ($0 ~ /ORCA_RPI_DRYRUN=/)  { nt++; tl[nt] = FNR; tu[nt] = unit; tk[nt] = "DRY" }
  if ($0 ~ /ORCA_CLI_COMMAND=/) { nt++; tl[nt] = FNR; tu[nt] = unit; tk[nt] = "CLI" }
  if ($0 ~ /ORCA_RPI_RUNDIR=/)  { nt++; tl[nt] = FNR; tu[nt] = unit; tk[nt] = "RD" }
  if ($0 ~ /LIVE-INTENT\([^)][^)][^)][^)][^)][^)]+\)/) { nv++; vl[nv] = FNR }
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
} > "$S53_TMP/fixture.md"
S53_FIX=$(awk -f "$S53_TMP/s53.awk" "$S53_TMP/fixture.md" 2>/dev/null | cut -f1 | tr '\n' ',')
if [ "$S53_FIX" != "ISO,NOISO," ]; then
  fail "부작용-차단 seal: 자기-시험 픽스처 판별 실패(기대 'ISO,NOISO,' 실측 '${S53_FIX:-빈값}') — 탐지자가 죽었다면 위반 0 은 무의미하다"
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
CK=$(awk -f "$TMPD/s53.awk" docs/superpowers/plans/*.md docs/ai-context/*.md 2>/dev/null \
     | awk -F'\t' -v L="$HOME/.claude/docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md" '$1=="NOISO" && $2==L {print $5}' \
     | sed 's/[[:space:]][[:space:]]*/ /g' | sort | cksum | tr -d ' ')
echo "동결값=$CK"
perl -pi -e "s/\@\@S53_LEDGER_CKSUM\@\@/$CK/g" setup/verify-setup.sh
grep -c 'S53_LEDGER_CKSUM' setup/verify-setup.sh
```

Expected: `동결값=<숫자>` · 마지막 `grep -c` → **0**(플레이스홀더 전부 치환).

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
  { printf '\n'; printf 'bash bin/orca-%s.sh gate create --task t9 --question q9\n' "rpi"; printf '\n'; } >> "$p"
}
```

- [ ] **Step 3: 단언 2줄 추가 (`pathpass_interp` 줄 뒤, `:199` 다음)**

```bash
assert_seal_fires "s53_unisolated"  mut_s53_unisolated  "부작용-차단 주입 누락"
assert_seal_fires "s53_substitute"  mut_s53_substitute  "1회성 예외 대장 drift"
```

- [ ] **Step 4: RED→GREEN 확인 (full 실행 — 40분+)**

⚠️ **실행 중 `~/.claude` 파일을 편집하지 말 것** — witness cksum 불변이 물리 전제다(Global Constraint 6).

```bash
cd "$HOME/.claude"
bash setup/tests/seal-regression.test.sh 2>&1 | tail -12
```

Expected: `seal-regression: PASS=29 FAIL=0` + `✓ live ~/.claude untouched (witness cksum stable across run)`.
`s53_substitute` 가 PASS 한다는 것은 **개수가 유지된 치환을 잡았다**는 뜻이다(§11.10 ③ B1 해소의 실증).

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
대신 **clean 아카이브 추출 + 계약 검사**로 확인한다(네트워크 0회 · 설치 0회).

```bash
cd "$HOME/.claude"
bash -n setup/install.sh && echo "bash -n OK"
T=$(mktemp -d); git archive HEAD | tar -x -C "$T"
TARGET="$T" bash -c 'source /dev/stdin <<EOF
$(sed -n "/^REQUIRED=(/,/^)/p" '"$T"'/setup/install.sh)
EOF
M=0; for f in "${REQUIRED[@]}"; do [ -f "$f" ] || { echo "MISSING: $f"; M=$((M+1)); }; done
echo "REQUIRED=${#REQUIRED[@]} MISSING=$M"'
ls -l "$T/bin/"
```

Expected: `bash -n OK` · `REQUIRED=35 MISSING=0`(34 → 35) · `bin/` 에 `orca-rpi.sh`·`claude-ocx` 존재.

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
- Modify: `skills/start-rpi-cycle/SKILL.md` — Phase I 옵션 (e)(`:152` 뒤) · Gate R/Gate P/Closeout
  success_criteria 3곳
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

- [ ] **Step 2: 정본에 옵션 (e) 추가 (`- (c) …` 줄 뒤, `- (d) …` 앞)**

```markdown
- (e) **Orca 감독 사이클** — Phase 를 Orca ADE Task DAG 로 돌린다(포인터: `Skill(orca-rpi-cycle)`).
      진입 전 `bash ~/.claude/bin/orca-rpi.sh preflight` 가 rc=0 이어야 하며, **rc=3(Orca 미가동)이면
      자동으로 (a)/(d) 로 폴백**한다 — Orca 는 선택적 가속기이지 사이클의 전제가 아니다.
      ★**사이클 브랜치에서만** — 캐리어가 `master`/`main` 에서 non-readonly 스폰을 코드로 거부한다
      (워커가 같은 체크아웃에 커밋해 머지 승인이 사후 무력화되는 것을 막는다).
      상세는 `docs/ai-context/c21-orca-mode-design.md` §7·§11.10.
```

- [ ] **Step 3: 미러에 옵션 (e) 추가 — 미착륙으로 명시**

`opencode-harness/skill/start-rpi-cycle/SKILL.md` 의 `- (c) …` 뒤(`:161` 뒤):

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
- Modify: `docs/superpowers/specs/2026-07-25-model-policy-design.md` §19.6 추가
  (**혼합 개행 CR=1823 — `perl -0777 -i` 만 사용, `Edit` 금지**)

**Interfaces:**
- Consumes: §18.1 트리거 (b)(C22 에서 성립 — 「차기 floor 한정 재심 1회 예약」) · §19.5 반증 조건
- Produces: floor 재심 판정 1건. 이 사이클의 layer-yield 행.

- [ ] **Step 1: 재심 입력 실측**

```bash
cd "$HOME/.claude"
sed -n '2340,2375p' docs/superpowers/specs/2026-07-25-model-policy-design.md
tail -8 docs/ai-context/review-yield.md
```

- [ ] **Step 2: 판정 작성 — §19.6 을 spec 에 append**

판정의 뼈대는 이미 실측으로 정해져 있다(§11.10 ⑧): §19.5 의 처분이 **미착륙**이었으므로 반증 조건
(「지시문 보강 착륙 후 같은 클래스 재발」)이 아직 **평가 불가**였고, 따라서 C21·C22 의 BLOCKER 는
floor-축 반증 입력이 되지 못한다.

이 파일은 혼합 개행(CR=1823)이라 `Edit` 을 쓰면 전 파일이 LF 로 통일돼 거대한 거짓 diff 가 난다.
**append 만** 한다(`cat >> …` 또는 `perl -0777 -i -pe` 로 말미 추가). 아래가 그 문안이다.

```markdown
### §19.6 floor 한정 재심 (C23 — §18.1 트리거 (b) 소비)

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

- [ ] **Step 3: `review-yield.md` 에 C23 절 append**

Closeout 직전에 층별 실측을 채워 넣는다(§15.3 S19 — 말미 층 실측 후 append).

```markdown
## C23 (cycle 74, 2026-08-18) — Orca 캐리어 자기-적용

- Gate R: FAIL→정정 · 실발견 10 · 발견
- Gate R 델타 재심 ×5: `0 PASS/5 FAIL` → 최종 PASS · 실발견 20(7+7+2+4, 5회차 0) · 발견
- stage2 ×N: … · 통합(senior+drift): … · 교차패밀리 슬롯1/슬롯2: …
- **트리거 대조(§18.1 판정 3)**: (a) … · (b) … · (c) … · (d) …
- **floor 재심 판정**: 무변경 — §19.5 반증 조건이 지시문 미착륙으로 **평가 불가**였음(spec §19.6)
```

- [ ] **Step 4: 커밋**

```bash
cd "$HOME/.claude"
perl -ne '$n++ if /\r/; END{print "CR=$n\n"}' docs/superpowers/specs/2026-07-25-model-policy-design.md
git add docs/superpowers/specs/2026-07-25-model-policy-design.md docs/ai-context/review-yield.md
git commit -m "docs(policy): C23 T-floor — §19.6 floor 한정 재심 판정(무변경) + review-yield C23 절"
```

Expected: CR=**1823**(불변 — 혼합 개행 보존 확인).

---

## 검증 수열 (Closeout 전 필수)

| 순서 | 명령 | 기준선 | 목표 |
|---|---|---|---|
| 1 | `bash setup/verify-setup.sh` | 90/0 | **91/0** |
| 2 | `bash hooks/tests/run-all.sh` | 305/305 | 305/305 (무회귀) |
| 3 | `bash setup/tests/orca-carrier.test.sh` | (신규) | 11/0 |
| 4 | `bash setup/tests/seal-regression.test.sh` | 27/0 | **29/0** (full 필수 — setup/ diff 존재) |
| 5 | `bash setup/verify-all.sh` | ALL PASS | ALL PASS (STAGE 2e 포함) |

4번 실행 중에는 **`~/.claude` 를 편집하지 않는다**(witness cksum 불변이 물리 전제).

## 선언된 잔여

1. **seal #53 탐지 범위 = 캐리어 호출 한정** — `"$ORCA" orchestration <변이>` 직접 호출과
   `bin/claude-ocx` 직접 호출은 미탐이다. 덮으려면 orchestration 28개 서브커맨드의 읽기/변이 분할을
   먼저 실측해야 하고 이번 사이클에 그 실측이 없다(§11.10 ③).
2. **1회성 예외 대장의 좁은 잔여** — 위반 1건을 격리하며 **바이트 동일 텍스트**의 새 위반을 다른
   위치에 넣으면 cksum 이 불변이라 무발화한다. 줄 번호 이동 불변성의 직접 귀결이며 감수한다.
3. **`LIVE-INTENT` parity 는 자기-정합 검사** — 같은 커밋에서 총계를 함께 올리면 통과한다.
   잡는 것은 *침묵의* 추가이지 의식적 확장이 아니다.
4. **DRYRUN 은 원장 뮤텍스를 검증하지 않는다** — 동시-1 상한은 본질적으로 쓰기라 dry 경로로 검증
   불가. 그 축은 stub `$ORCA` + `ORCA_RPI_RUNDIR` 격리 경로가 계속 담당한다.
5. **`--retry-request` 는 실측 확인된 명령에만 배선** — `task-create`/`gate-create`/`check` 는
   Task 1 Step 5 의 `--help` 결과에 따라 확장하거나 **미확인으로 남긴다**.
