# Orca 스폰 캐리어 + RPI skill + 워커 계약 (T1-T3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active
**RPI-Cycle:** 73
**Started:** 2026-08-17

**Goal:** Orca ADE 오케스트레이션을 하네스 규약 안에서 구동하는 최소 실행 집합 — T1(`bin/orca-rpi.sh` 유일 스폰 캐리어) · T2(`skills/orca-rpi-cycle/SKILL.md`) · T3(`docs/ai-context/orca-worker-contract.md`) — 를 착륙시킨다. T4~T21(특히 `modes/` 삭제)은 범위 밖.

**Architecture:** 3개 독립 산출물. T1(bash, 코드)이 유일하게 `$ORCA`(orca.exe)를 호출하는 지점이며 인자·명령·동시성 불변식을 코드로 강제한다. T2(skill)는 `create-orchestrator-skill`로 생성하며 T1의 서브커맨드를 Task spec 템플릿에서 인용한다. T3(문서)는 Orca 가 주입하는 preamble 위에 얹히는 하네스-고유 계약만 담고 규범을 재전송하지 않는다. 세 산출물은 서로 참조하되 코드 의존은 없어 순차 구현 가능 — T1 → T2 → T3 순으로 진행(T2/T3 가 T1의 정확한 서브커맨드명을 인용해야 하므로).

**Tech Stack:** bash(POSIX 호환, MSYS/Windows 환경) + `jq`(확인됨: `jq-1.8.1` at `/c/Users/12132/bin/jq`) + 기존 하네스 `hooks/_common.sh`(`has_active_plan`만 서브셸로 소싱 — `set -euo pipefail` 오염 방지).

**Spec:** `docs/ai-context/c21-orca-mode-design.md`(durable spec, 재진입 재사용 — 신규 생성 아님. §0~§11 특히 §2·§3·§7·§8·§9·§11) + `docs/ai-context/c22-orca-probe-measured.md`(P0 실측 SSOT, 필드 경로 확정 근거).

**spec delta 판정:** 없음(no-op). 기계적 증거: `git diff 39a1dea..HEAD -- docs/superpowers/specs/` = 0줄(직전 사이클 merge 커밋 `39a1dea` 이후 무변경). `docs/ai-context/c21-orca-mode-design.md`·`c22-orca-probe-measured.md` 는 이번 R phase 에서 read-only(git status 로 미변경 확인). CONTEXT.md 에 3개 용어(스폰 캐리어·워커 계약·승인 채널 층 분리)를 canonicalize 했으나 이는 기존 durable spec 어휘의 확인일 뿐 새 design 결정이 아니다.

## Global Constraints

(전부 `c21-orca-mode-design.md` / `c22-orca-probe-measured.md` verbatim 근거 — 각 task 는 이 제약을 암묵 포함한다)

- `$ORCA` 해소 = `${ORCA_CLI_COMMAND:-C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe}`. **`orca.cmd` 금지** — `orca.cmd:13-14` 가 `orchestration send|reply` 를 `exit /b 2` 로 거부한다(worker_done 이 send 이므로 결정적, §3.0).
- `--agent claude` 고정. `--worktree` 는 `current` 또는 `$WT_SEL`(설계 §5.3 "selector 재조립 금지" — `worktree current --json` 반환값을 verbatim 보존, 재조립 시 MSYS 경로 보간 사고 재현 위험).
- `--model`/`--effort`/`--on`/`--worktree new-child`/`--worktree new-top-level` 인자를 **캐리어가 절대 받지 않는다** — 모델 티어는 워커 내부(Agent/Workflow)로 미루는 것이 설계의 핵심(§2 경계표·§4.1 3근거 — 특히 `--effort` 는 `--model` 필요·`--terminal` 과 배타).
- 금지 명령(§3.10): `orchestration reset`(스코프 전역, 되돌림 불가) · `coordinator-start`/`coordinator-stop`(은퇴, 효과 0) · `agent hooks off`(Orca 가 하네스 settings.json 을 `managedHooksPresent:true` 로 관리 — c22-probe P0-3) · `skills install`(하네스 오염) · `claude-teams`(provenance 충돌). 캐리어는 고정 서브커맨드→고정 orca.exe 호출만 가지므로 **구조적으로 이 명령들을 호출할 코드 경로가 없다** — 방어는 "런타임 문자열 매칭"이 아니라 "그런 경로를 안 만드는 것"이다.
- non-readonly task 동시 spawn 상한 = 1(§3.6 불변식 — `orchestration.md:181` "Orca does not schedule workers or infer conflicts", `:342` "Independent tasks … are not isolation requirements" — 동시 편집 안전성은 100% 캐리어 책임).
- `봉투 = {id, ok, result, _meta}` — **함정**: 최상위 `.id` 는 요청 상관ID 이지 run/task id 가 아니다. `run id = result.run.id`(`run_` 접두, 실측 `run_720d6f472515`) · `task id = result.task.id`(`task_` 접두, 실측 `task_946e358573bc`) · `coordinator handle = result.run.coordinator_handle`(c22-probe P0-2 완결).
- `result.task.deps` 는 **문자열** `"[]"` — 배열이 아니라 파싱 필요(c22-probe P0-2).
- `worker.agent_terminal_handle`(`worker-show --dispatch` 응답) · 실제 `worker-start` 성공 시 dispatch id 필드(`result.dispatch`) · `gate-create` 의 gate id 필드는 **미측정** — 워커를 실제로 띄워야 나온다(c22-probe "잔여 미측정"). 이 세 지점만 `# [P2]` 주석을 코드에 남긴다(다른 필드는 확정 실측이라 [P2] 불필요).
- `check --wait` 는 15초마다 stderr 로 keepalive JSON 을 낸다(스키마 usage verbatim) — stdout/stderr 분리 필수, 배치 전건 순회 후에만 `--ack`(§3.4, `:139-140` verbatim).
- `worker-start` 는 `exit 0 == ready` 만 성공. 실패해도 **자동 재시도 금지** — `--retry-of <dispatch_id>` 명시만(§3.3, `orchestration.md:212`).
- preflight 에서 `settings.json` 백업, release 에서 diff 단언(§3.1·§2 경계표 — Orca 가 settings.json 을 자기 관리 대상으로 인식하므로 무변경이 기대값).
- preamble 이 워커의 `AskUserQuestion` 을 **전면 금지**(RULE#1 — "your session will hang forever waiting on a human"). 워커는 `orchestration ask`/`decision_gate` 만. **코디네이터 층(사람과 같은 화면)은 `AskUserQuestion` 유지** — 머지 승인은 사람 소유, gate 대체 금지(c22-probe P0-4, CONTEXT.md [[승인 채널 층 분리]]).
- `orchestration escalation` 이라는 명령은 **존재하지 않는다** — escalation 은 메시지 타입, 정본은 `send --type escalation`(c22-probe P0-4, orchestration 하위 28개 서브커맨드 전수 확인됨).
- `worker_done` 은 정확히 1회, `--body` 3문장 요약 강제, `--outcome succeeded|failed`. payload 에 `taskId`+`dispatchId` 둘 다 포함(재시도 완료가 현재 dispatch 를 잘못 완료시키는 것 방지). `worker_done` 뒤 추가 행동 금지(sleep/poll 루프·셸 종료 금지 — 터미널 재사용 대기, c22-probe P0-4).
- 범위 밖 금지: `modes/orca-rpi-implement.json`·`setup/lib/modepack-oracle.sh` 삭제(T20/T21) · `hooks/surface-model-policy.sh` 개정(T4, 이미 cycle-72 에서 착륙 완료 — spec §20) · `setup/lib/orca-carrier-oracle.sh`(T6) · `hooks/tests/cases.tsv` 신규 GPT 케이스(T5, T4 부속이라 이미 완료) · install.sh REQUIRED 등록(T17).

---

## File Structure

- **Create:** `bin/orca-rpi.sh` — 유일 스폰 캐리어(bash, 실행권한 755). 서브커맨드: `preflight run task spawn wait handoff release gate gpt selfcheck`.
- **Create:** `skills/orca-rpi-cycle/SKILL.md` — `create-orchestrator-skill` 산출물. Task spec 템플릿 4종(R/P/I/C) + 리뷰 슬롯 2종.
- **Create:** `docs/ai-context/orca-worker-contract.md` — 워커 계약 SSOT 문서.

세 파일은 서로 참조(T2 가 T1 서브커맨드명 인용, T3 가 T1 불변식·T2 트리거를 재확인)하나 실행 의존은 없다 — 각 task 는 독립적으로 테스트 가능한 산출물을 낸다.

---

### Task 1: `bin/orca-rpi.sh` — 유일 스폰 캐리어

**Files:**
- Create: `bin/orca-rpi.sh` (실행권한 755)

**Interfaces:**
- Consumes: `$HOME/.claude/hooks/_common.sh` 의 `has_active_plan()`(서브셸에서만 소싱), 시스템 `jq`, 시스템 `$ORCA`(orca.exe), `$HOME/.claude/bin/claude-ocx`, 시스템 `codex`.
- Produces: 서브커맨드별 stdout 계약 — `run`→run id 1줄 / `task`→task id 1줄 / `gate create`→gate id 1줄(`# [P2]`) / `spawn`→dispatch id 1줄(`# [P2]`) / `handoff`→worker-start 원본 JSON / `wait`→필터된 delivery JSON / `release`/`gate resolve`/`gate list`/`gpt`→orca/codex/claude-ocx 원본 출력. 후속 task(T2 SKILL.md, T3 계약 문서)는 이 서브커맨드명·인자명·stdout 계약을 그대로 인용한다.

**설계 근거(구현 전 확정 — 재도출 금지):**

1. **금지 명령은 런타임 매칭이 아니라 구조로 막는다.** 캐리어는 고정 서브커맨드 10개만 갖고, 각각 고정된 `$ORCA orchestration <verb>` 1개만 호출한다. `orchestration reset`/`coordinator-start`/`coordinator-stop`/`agent hooks off`/`skills install`/`claude-teams` 를 호출하는 코드 경로 자체가 없다 — 따라서 소스에 이 리터럴들을 **denylist로 나열하지 않는다**(나열하면 그 나열 자체가 "소스에 금지 리터럴 0건" 검증을 스스로 깨뜨린다 — c21-orca-mode-design.md §6.4 가 지적한 "정의행 자체가 카운트를 오염" 클래스와 동형 함정을 피한다).
2. **`--model`/`--effort`/`--on`/`new-child`/`new-top-level` 는 다른 종류의 금지다** — 이건 "캐리어가 절대 호출 안 하는 명령"이 아니라 "**호출자가 캐리어에 줄 수 없는 인자**"이므로, 캐리어가 이 정확한 토큰들을 인식해 **거부**해야 한다(방어 로직 자체가 이 문자열들을 포함하는 것은 정상 — 금지 대상은 "명령 리터럴"이지 "거부 로직의 패턴 문자열"이 아니다).
3. **모든 유효성 검사는 `$ORCA` 호출 전에 끝난다** — 실제 Orca 실행 여부와 무관하게 ⓑⓒ 를 테스트할 수 있어야 한다.
4. **`main "$@"` 는 직접 실행될 때만 발화한다**(`[ "${BASH_SOURCE[0]}" = "$0" ]` 가드) — `. bin/orca-rpi.sh` 로 소싱하면 함수만 로드되고 자동 실행되지 않는다. 이게 있어야 TDD ⓑⓒ 를 실제 Orca 호출 없이 함수 단위로 격리 테스트할 수 있다.
5. **자원-생성 서브커맨드(`run`/`task`/`gate create`/`spawn`)는 봉투가 아니라 추출된 ID 1줄만 stdout 에 낸다** — c22-probe 의 "함정"(최상위 `.id` 오채택)을 코드로 구조적으로 예방한다. 원본 JSON 은 `$RUNDIR/last-*.json` 에 보존(디버깅용).
6. **non-readonly 동시성 추적은 파일 기반**(`$RUNDIR/active-nonreadonly.tasks`, 1줄 1 task id) — 캐리어는 매 서브커맨드 호출마다 새 프로세스이므로 상태를 파일에 둔다. `spawn`(readonly 아님) 이 카운트 ≥1 이면 `$ORCA` 호출 전에 거부. `worker-start` 가 실패(비-ready)하면 추가한 슬롯을 롤백. `release` 가 슬롯을 비운다.

- [x] **Step 1: 스켈레톤 작성 (가드 없음 — RED 준비)**

`bin/orca-rpi.sh` 를 아래 내용으로 작성한다. 이 시점에는 `assert_no_forbidden_args`/동시성 가드를 **호출하지 않은 상태**로 둔다(다음 step 에서 RED 를 잡기 위해):

```bash
#!/usr/bin/env bash
# bin/orca-rpi.sh — 유일 스폰 캐리어 (c21-orca-mode-design.md §7 T1)
#   Orca ADE 오케스트레이션을 하네스 규약 안에서 구동하는 코드 레벨 경계.
#   서브커맨드: preflight run task spawn wait handoff release gate gpt selfcheck
#   불변식은 문서가 아니라 이 스크립트가 강제한다 — 상세 근거는 docs/ai-context/c21-orca-mode-design.md.
set -u

# orca.cmd 는 orchestration send/reply 를 exit /b 2 로 거부한다(orca.cmd:13-14 verbatim) —
# worker_done 이 send 이므로 .exe 가 결정적으로 필요하다(설계 §3.0 함정②).
ORCA="${ORCA_CLI_COMMAND:-C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe}"
RUNDIR="${ORCA_RPI_RUNDIR:-$HOME/.claude/.orca-rpi}"
SELF="$(basename "$0")"

die() { echo "$SELF: $*" >&2; exit 1; }
ensure_rundir() { mkdir -p "$RUNDIR"; touch "$RUNDIR/active-nonreadonly.tasks"; }
require_jq() { command -v jq >/dev/null 2>&1 || die "jq 미설치 — 이 캐리어는 jq 에 의존한다"; }

# --worktree 는 'current' 또는 $WT_SEL 값만 허용한다(설계 §5.3 "selector 재조립 금지" —
# worktree current --json 반환값을 verbatim 보존, 재조립 시 MSYS 경로 보간 사고 재현 위험).
assert_worktree_arg() {
  local v="$1"
  [ "$v" = "current" ] && return 0
  if [ -n "${WT_SEL:-}" ] && [ "$v" = "$WT_SEL" ]; then return 0; fi
  die "거부: --worktree 는 'current' 또는 \$WT_SEL 값만 허용됩니다(받음: $v) — 설계 §5.3/§5.4"
}

cmd_preflight() { :; }
cmd_run() { :; }
cmd_task() { :; }
cmd_spawn() {
  local readonly_flag=0 task="" worktree="current" run=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --readonly) readonly_flag=1; shift ;;
      --run) run="$2"; shift 2 ;;
      --task) task="$2"; shift 2 ;;
      --worktree) assert_worktree_arg "$2"; worktree="$2"; shift 2 ;;
      # ★스켈레톤 한정: 미인식 인자를 거부하지 않고 그냥 건너뛴다(shift 1개) —
      #   이래야 다음 step 의 RED(가드 부재 시 --model 이 조용히 통과)가 실제로 재현된다.
      #   Step 6 의 최종본은 이 분기를 진짜 die 로 교체한다.
      *) shift ;;
    esac
  done
  [ -n "$task" ] && [ -n "$run" ] || die "spawn: --run 과 --task 필수"
  echo "spawn: would call worker-start (스켈레톤 — 가드 미적용)"
}
cmd_wait() { :; }
cmd_handoff() { :; }
cmd_release() { :; }
cmd_gate() { :; }
cmd_gpt() { :; }
cmd_selfcheck() {
  bash -n "$0" && echo "OK bash -n" || return 1
}

main() {
  local cmd="${1:-}"; [ $# -gt 0 ] && shift
  case "$cmd" in
    preflight) cmd_preflight "$@" ;;
    run) cmd_run "$@" ;;
    task) cmd_task "$@" ;;
    spawn) cmd_spawn "$@" ;;
    wait) cmd_wait "$@" ;;
    handoff) cmd_handoff "$@" ;;
    release) cmd_release "$@" ;;
    gate) cmd_gate "$@" ;;
    gpt) cmd_gpt "$@" ;;
    selfcheck) cmd_selfcheck "$@" ;;
    *) die "알 수 없는 서브커맨드: '$cmd' — preflight|run|task|spawn|wait|handoff|release|gate|gpt|selfcheck 중 하나" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
```

- [x] **Step 2: RED 확인 — 가드 없는 스켈레톤이 위험 인자를 거부하지 못함을 실측**

```bash
chmod +x bin/orca-rpi.sh
bash -n bin/orca-rpi.sh && echo "bash -n OK"
bin/orca-rpi.sh spawn --run run_x --task task_x --model opus; echo "rc=$?"
```
Expected (RED): `rc=0` 그리고 `"spawn: would call worker-start …"` 가 출력됨 — `--model` 이 **거부되지 않고 통과**한다. 이 출력을 그대로 plan 실행 보고에 인용한다(RED 증거).

- [x] **Step 3: 가드 추가 (GREEN 목표)**

`assert_no_forbidden_args` 함수를 추가하고 `main()` 의 dispatch 직전에서 호출한다. ★단 `gpt` 서브커맨드는
제외한다 — 거기서의 `--model` 은 Orca 워커에 실리는 티어 선언이 아니라 GPT 모델명(`gpt-5.6-sol` 등, 경로 A/B
호출 대상)이라 의미가 다르다(설계 §4.3). 같은 토큰이라도 subcommand 마다 지시대상이 다르므로, 이 시점에
`gpt` 를 빠뜨리면 `cmd_gpt` 의 `--model` 이 죽은 옵션이 된다 — main() 자체가 그 인자를 절대 넘겨주지 않기
때문이다:

```bash
# 호출자가 캐리어에 줄 수 없는 인자 — "명령 리터럴"이 아니라 "거부 로직의 패턴 문자열"이므로
# 여기 포함은 T1 TDD ⓓ("소스에 금지 명령 리터럴 0건")의 대상이 아니다(설계 근거 2번 참조).
assert_no_forbidden_args() {
  local a
  for a in "$@"; do
    case "$a" in
      --model|--model=*)
        die "거부: '--model' 은 이 캐리어가 받지 않는 인자입니다 — 모델 티어는 워커 내부(Agent/Workflow)로 미룬다(설계 §2·§4.1)" ;;
      --effort|--effort=*)
        die "거부: '--effort' 은 이 캐리어가 받지 않는 인자입니다 — --model 없이는 무의미하고 --terminal 과 배타입니다(설계 §3.5 스키마 NOTE)" ;;
      --on|--on=*)
        die "거부: '--on' 은 이 캐리어가 받지 않는 인자입니다(설계 §3.10)" ;;
      new-child|new-top-level)
        die "거부: '$a' — 워크트리는 always current 입니다(설계 §5.3 plan 가시성)" ;;
    esac
  done
}
```

`main()` 을 아래로 교체:

```bash
main() {
  local cmd="${1:-}"; [ $# -gt 0 ] && shift
  # gpt 서브커맨드는 --model 을 다른 의미(GPT 모델명)로 정당하게 받으므로 이 가드에서 제외한다.
  [ "$cmd" = "gpt" ] || assert_no_forbidden_args "$@"
  case "$cmd" in
    preflight) cmd_preflight "$@" ;;
    run) cmd_run "$@" ;;
    task) cmd_task "$@" ;;
    spawn) cmd_spawn "$@" ;;
    wait) cmd_wait "$@" ;;
    handoff) cmd_handoff "$@" ;;
    release) cmd_release "$@" ;;
    gate) cmd_gate "$@" ;;
    gpt) cmd_gpt "$@" ;;
    selfcheck) cmd_selfcheck "$@" ;;
    *) die "알 수 없는 서브커맨드: '$cmd' — preflight|run|task|spawn|wait|handoff|release|gate|gpt|selfcheck 중 하나" ;;
  esac
}
```

- [x] **Step 4: GREEN 확인 (ⓑ 증거)**

```bash
bin/orca-rpi.sh spawn --run run_x --task task_x --model opus; echo "rc=$?"
bin/orca-rpi.sh spawn --run run_x --task task_x --effort xhigh; echo "rc=$?"
bin/orca-rpi.sh handoff --task task_x --dispatch d_x --effort high; echo "rc=$?"
```
Expected (GREEN): 3건 전부 `rc=1` + `거부: '--model'…`/`'--effort'…` 사유가 stderr 에 출력.

- [x] **Step 5: 동시성 가드 — RED 확인**

먼저 `cmd_spawn` 에 파일 기반 동시성 카운트를 아직 추가하지 않은 채로, 활성 슬롯을 수동으로 시뮬레이션해 가드 부재를 확인한다:

```bash
mkdir -p "$HOME/.claude/.orca-rpi"
echo "task_prev" > "$HOME/.claude/.orca-rpi/active-nonreadonly.tasks"
bin/orca-rpi.sh spawn --run run_x --task task_new; echo "rc=$?"
```
Expected (RED): `rc=0`(또는 스켈레톤의 `--run`/`--task` 필수 체크만 통과해 "would call…" 출력) — 활성 슬롯이 1개 있는데도 2번째 spawn 이 거부되지 않는다.

- [x] **Step 6: 동시성 가드 구현 (GREEN 목표) + 나머지 서브커맨드 전체 완성**

이 step 은 스켈레톤의 스텁 함수 9개(`cmd_preflight`/`cmd_run`/`cmd_task`/`cmd_spawn`/`cmd_wait`/`cmd_handoff`/`cmd_release`/`cmd_gate`/`cmd_gpt`)와 `cmd_selfcheck` 전부를 아래 최종 구현으로 **교체**한다(파일 안의 동명 함수 정의를 전부 이 블록으로 바꾼다 — `cmd_spawn` 은 특히 미인식 인자 분기가 `*) shift ;;` 에서 `*) die …` 로 바뀐다):

```bash
cmd_preflight() {
  require_jq
  ensure_rundir
  cp "$HOME/.claude/settings.json" "$RUNDIR/settings.pre-orca.json" || die "preflight: settings.json 백업 실패"

  "$ORCA" status --json >"$RUNDIR/preflight-status.json" 2>&1 || { echo "preflight: orca status 실패 — Orca 미가동, 사이클은 기존 Phase I (a)/(d) 로 폴백" >&2; exit 3; }
  jq -e '.ok == true' "$RUNDIR/preflight-status.json" >/dev/null 2>&1 || { echo "preflight: orca status ok!=true" >&2; exit 3; }

  "$ORCA" orchestration run-list --json >"$RUNDIR/preflight-runlist.json" 2>&1 || { echo "preflight: orchestration RPC 도달 실패" >&2; exit 3; }
  "$ORCA" repo list --json >"$RUNDIR/preflight-repolist.json" 2>&1 || { echo "preflight: repo list 실패" >&2; exit 3; }

  local wt_sel; wt_sel=$("$ORCA" worktree current --json 2>/dev/null | jq -r '.result.worktree.id // empty')
  [ -n "$wt_sel" ] || { echo "preflight: worktree current 셀렉터 미획득 — 'orca repo add' 로 이 repo 등록 확인(설계 §9-A1)" >&2; exit 3; }
  printf '%s' "$wt_sel" > "$RUNDIR/wt_sel"

  "$ORCA" agent hooks status --json >"$RUNDIR/preflight-hooks-status.json" 2>&1 || { echo "preflight: agent hooks status 실패" >&2; exit 3; }
  "$ORCA" agent-context --json 2>/dev/null | cksum > "$RUNDIR/agent-context.cksum"
  "$ORCA" skills get orchestration --json 2>/dev/null | cksum > "$RUNDIR/skills-orchestration.cksum"

  # 하네스 전제 — plan 실재 단언(워커가 BLOCK 을 만나 RPI_SKIP 을 학습하는 경로 원천 차단, 설계 §3.1·§5.3).
  # 서브셸에서만 소싱 — _common.sh 의 `set -euo pipefail` 이 이 스크립트 본체를 오염시키지 않게.
  if ! ( . "$HOME/.claude/hooks/_common.sh"; has_active_plan "$PWD" >/dev/null ); then
    echo "preflight: no active plan — Orca 모드 진입 거부" >&2
    exit 3
  fi

  echo "preflight: OK worktree=$wt_sel"
}

cmd_run() {
  local objective=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --objective) objective="$2"; shift 2 ;;
      *) die "run: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$objective" ] || die "run: --objective 필수"
  require_jq; ensure_rundir
  local resp; resp=$("$ORCA" orchestration run-create --objective "$objective" --json) || die "run: run-create 실패"
  printf '%s' "$resp" > "$RUNDIR/last-run-create.json"
  # ★함정(c22-probe P0-2) — 봉투 최상위 .id 는 요청 상관ID(run id 아님). result.run.id 만 채택.
  local run_id; run_id=$(printf '%s' "$resp" | jq -r '.result.run.id // empty')
  [ -n "$run_id" ] || die "run: result.run.id 추출 실패 — 응답: $RUNDIR/last-run-create.json"
  printf '%s\n' "$run_id"
}

cmd_task() {
  local title="" spec="" deps=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --spec) spec="$2"; shift 2 ;;
      --deps) deps="$2"; shift 2 ;;
      *) die "task: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$title" ] && [ -n "$spec" ] || die "task: --title 와 --spec 필수"
  require_jq; ensure_rundir
  local extra=()
  [ -n "$deps" ] && extra=(--deps "$deps")
  local resp; resp=$("$ORCA" orchestration task-create --task-title "$title" --spec "$spec" "${extra[@]}" --json) || die "task: task-create 실패"
  printf '%s' "$resp" > "$RUNDIR/last-task-create.json"
  local task_id; task_id=$(printf '%s' "$resp" | jq -r '.result.task.id // empty')
  [ -n "$task_id" ] || die "task: result.task.id 추출 실패 — 응답: $RUNDIR/last-task-create.json"
  printf '%s\n' "$task_id"
}

cmd_spawn() {
  local readonly_flag=0 task="" worktree="current" run=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --readonly) readonly_flag=1; shift ;;
      --run) run="$2"; shift 2 ;;
      --task) task="$2"; shift 2 ;;
      --worktree) assert_worktree_arg "$2"; worktree="$2"; shift 2 ;;
      *) die "spawn: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$task" ] && [ -n "$run" ] || die "spawn: --run 과 --task 필수"
  require_jq; ensure_rundir

  if [ "$readonly_flag" -eq 0 ]; then
    local active; active=$(wc -l < "$RUNDIR/active-nonreadonly.tasks" 2>/dev/null || echo 0)
    if [ "${active:-0}" -ge 1 ]; then
      die "거부: non-readonly task 동시 실행 상한(1) 초과 — 활성: $(tr '\n' ' ' < "$RUNDIR/active-nonreadonly.tasks") (설계 §3.6 — Orca 는 충돌을 추론하지 않는다, orchestration.md:181/:342)"
    fi
    echo "$task" >> "$RUNDIR/active-nonreadonly.tasks"
  fi

  local resp rc
  resp=$("$ORCA" orchestration worker-start --run "$run" --task "$task" --worktree "$worktree" --agent claude --json)
  rc=$?
  printf '%s' "$resp" > "$RUNDIR/last-worker-start.json"

  if [ "$rc" -ne 0 ]; then
    if [ "$readonly_flag" -eq 0 ]; then
      grep -vFx "$task" "$RUNDIR/active-nonreadonly.tasks" > "$RUNDIR/active-nonreadonly.tasks.tmp" 2>/dev/null
      mv "$RUNDIR/active-nonreadonly.tasks.tmp" "$RUNDIR/active-nonreadonly.tasks" 2>/dev/null
    fi
    echo "spawn: worker-start 비-0(ready 아님) — 자동 재시도 금지, --retry-of 로만 재시도(설계 §3.3)" >&2
    exit "$rc"
  fi
  # dispatch id 실제 응답 shape 미측정(워커를 실제로 띄워야 확인 — c22-probe 잔여) [P2]
  local dispatch_id; dispatch_id=$(printf '%s' "$resp" | jq -r '.result.dispatch.id // .result.dispatch // empty')  # [P2]
  printf '%s\n' "$dispatch_id"
}

cmd_wait() {
  local run="" timeout=900000 ack=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --run) run="$2"; shift 2 ;;
      --timeout-ms) timeout="$2"; shift 2 ;;
      --ack) ack="$2"; shift 2 ;;
      *) die "wait: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$run" ] || die "wait: --run 필수"
  require_jq; ensure_rundir
  local extra=()
  [ -n "$ack" ] && extra=(--ack "$ack")
  # ★stderr 로 keepalive 분리(15초 간격, 스키마 usage verbatim) — stdout 은 이미 깨끗하지만
  #   병합 상황을 대비해 _keepalive 필터도 이중으로 건다(설계 §3.4 jq 'select(._keepalive|not)').
  "$ORCA" orchestration check --run "$run" --wait --types worker_done,escalation,question \
    --timeout-ms "$timeout" "${extra[@]}" --json \
    1>"$RUNDIR/last-check.json" 2>>"$RUNDIR/keepalive.log"
  local rc=$?
  jq 'select(._keepalive|not)' "$RUNDIR/last-check.json" 2>/dev/null
  return "$rc"
}

cmd_handoff() {
  local task="" dispatch=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --task) task="$2"; shift 2 ;;
      --dispatch) dispatch="$2"; shift 2 ;;
      *) die "handoff: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$task" ] && [ -n "$dispatch" ] || die "handoff: --task 와 --dispatch 필수"
  require_jq; ensure_rundir
  # worker.agent_terminal_handle 실제 응답 shape 미측정(worker-show 는 dispatch 선행 필요 — c22-probe 잔여) [P2]
  local resp handle
  resp=$("$ORCA" orchestration worker-show --dispatch "$dispatch" --json) || die "handoff: worker-show 실패"
  handle=$(printf '%s' "$resp" | jq -r '.result.worker.agent_terminal_handle // empty')  # [P2]
  [ -n "$handle" ] || die "handoff: agent_terminal_handle 획득 실패 — 응답 확인 필요"
  # ★--terminal 재사용은 --model/--effort 와 배타(스키마 NOTE, 설계 §3.5) — 이 서브커맨드는 그 인자를 아예 안 받는다.
  "$ORCA" orchestration worker-start --task "$task" --terminal "$handle" --json
}

cmd_release() {
  local dispatch="" task=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dispatch) dispatch="$2"; shift 2 ;;
      --task) task="$2"; shift 2 ;;
      *) die "release: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$dispatch" ] || die "release: --dispatch 필수"
  ensure_rundir
  "$ORCA" orchestration worker-release --dispatch "$dispatch" --json
  local rc=$?
  if [ -n "$task" ] && [ -f "$RUNDIR/active-nonreadonly.tasks" ]; then
    grep -vFx "$task" "$RUNDIR/active-nonreadonly.tasks" > "$RUNDIR/active-nonreadonly.tasks.tmp" 2>/dev/null
    mv "$RUNDIR/active-nonreadonly.tasks.tmp" "$RUNDIR/active-nonreadonly.tasks" 2>/dev/null
  fi
  if [ -f "$RUNDIR/settings.pre-orca.json" ] && ! diff -q "$RUNDIR/settings.pre-orca.json" "$HOME/.claude/settings.json" >/dev/null 2>&1; then
    echo "release: 경고 — settings.json 이 preflight 이후 변경됨(훅 배선 무변경 단언 실패, 설계 §3.1/§3.9)" >&2
  fi
  return "$rc"
}

cmd_gate() {
  local action="${1:-}"; [ $# -gt 0 ] && shift
  local task="" question="" id="" resolution=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --task) task="$2"; shift 2 ;;
      --question) question="$2"; shift 2 ;;
      --id) id="$2"; shift 2 ;;
      --resolution) resolution="$2"; shift 2 ;;
      *) die "gate: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  require_jq; ensure_rundir
  case "$action" in
    create)
      [ -n "$task" ] && [ -n "$question" ] || die "gate create: --task 와 --question 필수"
      local resp; resp=$("$ORCA" orchestration gate-create --task "$task" --question "$question" --options '["PASS","FAIL"]' --json) || die "gate create: 실패"
      printf '%s' "$resp" > "$RUNDIR/last-gate-create.json"
      # gate id 필드 경로 미측정(gate-create 미실행 — c22-probe 잔여) [P2]
      local gate_id; gate_id=$(printf '%s' "$resp" | jq -r '.result.gate.id // .id // empty')  # [P2]
      [ -n "$gate_id" ] || die "gate create: gate id 추출 실패 — 응답 확인: $RUNDIR/last-gate-create.json"
      printf '%s\n' "$gate_id"
      ;;
    resolve)
      [ -n "$id" ] && [ -n "$resolution" ] || die "gate resolve: --id 와 --resolution 필수"
      "$ORCA" orchestration gate-resolve --id "$id" --resolution "$resolution" --json
      ;;
    list)
      [ -n "$task" ] || die "gate list: --task 필수"
      "$ORCA" orchestration gate-list --task "$task" --json
      ;;
    *) die "gate: 서브액션은 create|resolve|list 중 하나(받음: '$action')" ;;
  esac
}

cmd_gpt() {
  local role="" prompt="" model="gpt-5.6-sol" out=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --role) role="$2"; shift 2 ;;
      --prompt) prompt="$2"; shift 2 ;;
      --model) model="$2"; shift 2 ;;
      --out) out="$2"; shift 2 ;;
      *) die "gpt: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$prompt" ] || die "gpt: --prompt 필수"
  case "$role" in
    executor)
      # 경로 B — 규율 아래 실행자(하네스 안, 설계 §4.3). 대상 문서는 stdin 으로 전달(호출자 책임).
      OCX_MODEL="$model" "$HOME/.claude/bin/claude-ocx" -p "$prompt" --output-format json
      ;;
    verifier)
      [ -n "$out" ] || die "gpt --role verifier: --out 필수(cross-family-review.md -o 소비 규율)"
      rm -f "$out"
      codex exec -m "$model" -c model_reasoning_effort=ultra -c model_verbosity=high \
        --sandbox read-only --skip-git-repo-check -o "$out" "$prompt"
      local rc=$?
      [ -s "$out" ] || die "gpt --role verifier: 출력 파일 미생성 — API 실패 가능성(cross-family-review.md -o 소비 규율)"
      return "$rc"
      ;;
    *) die "gpt: --role 는 executor 또는 verifier 만 허용(받음: '$role')" ;;
  esac
}

cmd_selfcheck() {
  local rc=0
  bash -n "$0" && echo "OK bash -n" || { echo "FAIL bash -n"; rc=1; }
  command -v jq >/dev/null 2>&1 && echo "OK jq: $(command -v jq)" || { echo "FAIL jq 미설치"; rc=1; }
  case "$ORCA" in
    *.cmd) echo "FAIL: \$ORCA 가 orca.cmd 로 해소됨 — orchestration send/reply 거부(설계 §3.0 함정②)"; rc=1 ;;
    *) echo "OK ORCA=$ORCA" ;;
  esac
  return "$rc"
}
```

- [x] **Step 7: GREEN 확인 (ⓒ 증거) + 무회귀 확인**

```bash
rm -f "$HOME/.claude/.orca-rpi/active-nonreadonly.tasks"
echo "task_prev" > "$HOME/.claude/.orca-rpi/active-nonreadonly.tasks"
bin/orca-rpi.sh spawn --run run_x --task task_new; echo "rc=$?"
rm -f "$HOME/.claude/.orca-rpi/active-nonreadonly.tasks"

# readonly 는 상한 미적용 확인(§3.6 read-only 팬아웃 — 병렬 축)
echo "task_prev" > "$HOME/.claude/.orca-rpi/active-nonreadonly.tasks"
bin/orca-rpi.sh spawn --run run_x --task task_ro --readonly; echo "readonly rc=$? (orca 미가동이면 실패해도 '거부: non-readonly' 문구가 없어야 함 — 카운트 로직을 안 탄 것)"
rm -f "$HOME/.claude/.orca-rpi/active-nonreadonly.tasks"
```
Expected (GREEN): 첫 호출 `rc=1` + `거부: non-readonly task 동시 실행 상한(1) 초과…` — `$ORCA` 를 호출하지 않고 즉시 거부(orca 미가동 환경에서도 재현 가능).

```bash
# gpt 서브커맨드의 --model 이 main() 의 전역 가드에 죽지 않는지 확인(빈 --prompt 로 인자파싱까지만 태움 —
# 이 인자만 없으면 codex/claude-ocx 실호출 전에 die 하므로 codex/claude-ocx 미설치 환경에서도 안전).
bin/orca-rpi.sh gpt --role verifier --model gpt-5.6-terra; echo "rc=$?"
```
Expected: `rc=1` + `gpt: --prompt 필수`(인자파싱까지 도달했다는 뜻 — `거부: '--model'…` 이 아니어야 한다. 그게 나오면 main() 의 `gpt` 제외 분기가 깨진 것).

- [x] **Step 8: ⓐⓓ 증거 + 무회귀**

```bash
bash -n bin/orca-rpi.sh && echo "ⓐ bash -n: OK"
bin/orca-rpi.sh selfcheck; echo "selfcheck rc=$?"
grep -c 'orchestration reset\|coordinator-start\|coordinator-stop\|agent hooks off\|skills install\|claude-teams' bin/orca-rpi.sh
```
Expected: `ⓐ bash -n: OK` · selfcheck `rc=0`(orca.exe 경로가 `.cmd` 아니므로) · grep count = **0**(ⓓ 증거 — 이 6개 금지 명령 리터럴이 소스에 전혀 없음).

- [x] **Step 9: `.gitignore` 에 런타임 디렉터리 등록**

`$RUNDIR`(`$HOME/.claude/.orca-rpi/`)는 preflight 백업·마지막 응답 JSON·동시성 추적 파일 등 **런타임 상태**이지
소스가 아니다 — `worktrees-marker/`(worktree-teardown 훅의 동형 선례)와 같은 대접을 준다. `.gitignore` 에
아래 줄을 `/worktrees-marker/` 항목 근처에 추가한다:

```gitignore
# Orca 스폰 캐리어 런타임 상태(preflight 백업·last-*.json·동시성 추적·skill draft) — per-session, never source
/.orca-rpi/
```

- [x] **Step 10: Commit**

```bash
git add bin/orca-rpi.sh .gitignore
git commit -m "feat(orca): T1 — bin/orca-rpi.sh 유일 스폰 캐리어 착륙"
```

---

### Task 2: `skills/orca-rpi-cycle/SKILL.md`

**Files:**
- Create: `skills/orca-rpi-cycle/SKILL.md` (반드시 `create-orchestrator-skill` skill 을 통해 생성 — CLAUDE.md §2 강제, 일반 skill-creator 직접 호출 금지)

**Interfaces:**
- Consumes: Task 1 이 확정한 `bin/orca-rpi.sh` 서브커맨드명(`preflight run task spawn wait handoff release gate gpt selfcheck`)과 그 인자 계약.
- Produces: `hooks/lib/skeleton-scan.js` 가 검증하는 4계약(frontmatter 마커 3줄·`# Phase ` ≥3·`Agent(subagent_type=` ≥1·`Communication Protocol` 절 ≥1) 을 만족하는 SKILL.md. Task spec 템플릿 4종(R/P/I/C) + 리뷰 슬롯 2종(cross-family-review.md §2 슬롯1/슬롯2 대응).

**이 task 는 execute-strict 위임이 아니라 메인이 `create-orchestrator-skill` Skill 도구를 직접 호출한다** (CLAUDE.md §2 + create-orchestrator-skill/SKILL.md Phase 2 "메인 세션이 직접" 규약). 아래 순서로 진행:

- [x] **Step 1: `Skill(skill="create-orchestrator-skill")` 호출**

- [x] **Step 2: Phase 1(Capture Intent) 에 아래 답을 직접 채워 넣는다** (사용자에게 되묻지 않음 — 이미 c21-orca-mode-design.md·c22-orca-probe-measured.md 로 확정됨):
  1. 목적: Orca ADE 로 표준 RPI 4-Task DAG(R→P→I→C)를 구동 — `bin/orca-rpi.sh` 를 통해서만 `worker-start` 발행.
  2. 트리거: "C\<N\> 사이클 시작해줘, Orca 로 돌려" / start-rpi-cycle Phase I 옵션 (e) 선택 시.
  3. 입력: RPI 사이클 목표(자연어) + 현재 plan 경로. 출력: Run 1개 + Task 4개(R/P/I/C) + read-only 리뷰 팬아웃 2개, `worker_done` 집계 보고.
  4. 사이클형(4-Task DAG, deps 체인 R→P→I→C, 깊이 4 = 가이드 권고 상한 — `orchestration.md:390` "avoid dependency chains deeper than 3-4 steps").

- [x] **Step 3: Phase 2(skill-creator 호출) — draft 골격에 아래 내용을 명시 지시**:
  - `bin/orca-rpi.sh preflight` 실패(rc=3) 시 **자동으로 기존 Phase I 옵션 (a)/(d) 로 폴백** — Orca 는 선택적 가속기, 사이클을 멈추지 않는다(설계 §9 시나리오3).
  - preflight 성공 시: `run` → `task`(R/P/I/C, deps 체인) → 각 Phase 마다 `spawn --worktree current`(1번째) 또는 `handoff --dispatch <이전 dispatch>`(2번째부터, 터미널 재사용) → `wait --run <RUN> --timeout-ms 900000`(코디네이터는 블로킹 대기, sleep 루프 금지) → `worker_done` 수신 시 다음 Task 로 진행.
  - Closeout(C) 완료 후: read-only 리뷰 2슬롯을 **동시** `spawn --readonly` 로 팬아웃(설계 §3.6 STAGE 5 — "Create the Run and every independent Task first, then start all independent workers before waiting") 후 단일 `wait` 로 수확.
  - 머지 승인은 `AskUserQuestion`(사람) — `gate` 로 대체 금지([[승인 채널 층 분리]] — CONTEXT.md).
  - Task spec 템플릿 4종을 body 에 포함 — 각 템플릿은 `bin/orca-rpi.sh task --title "<R|P|I|C>: ..." --spec "<아래 템플릿>"` 로 전달되는 실제 텍스트:

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
  - 리뷰 슬롯 2종 템플릿(read-only, `spawn --readonly` 로 팬아웃):
    ```
    V1(설계층): spec delta + plan 을 적대적으로 검토하라(refute-by-default). read-only.
    발견마다 원문 인용 + 실측 대조. worker_done --outcome succeeded --body "<발견 N건 요약>" --phase V1.

    V2(코드층): 이번 사이클 diff 를 적대적으로 검토하라(refute-by-default). read-only.
    발견마다 파일:줄 인용. worker_done --outcome succeeded --body "<발견 N건 요약>" --phase V2.
    ```

- [x] **Step 4: Phase 3(Inject Orchestrator Skeleton) — draft 에 자동 주입 확인**:
  - frontmatter 3줄: `orchestrator_skill: true` / `generated_by: create-orchestrator-skill` / `orchestrator_version: 1.0`
  - body `# Phase ` 헤더 ≥3개(R/P/I/C 4단계 서술 + Communication Protocol 이면 자연히 충족)
  - 실제 `Agent(subagent_type=...)` 호출 ≥1개 — 이 skill 은 Orca 워커를 스폰하는 것이 본질이지만, `preflight` 실패 시 폴백 경로(옵션 (a)/(d))를 설명하는 절에 최소 1개의 실제 `Agent(subagent_type="execute-strict", …)` 예시 호출을 포함시켜 계약을 만족시킨다(폴백 경로가 실제로 이 형태이므로 인위적 삽입이 아니다).
  - `Communication Protocol` 절 — result(COMPLETE/FAIL) · evidence(Run/Task id, worker_done 로그) · unknowns.

- [x] **Step 5: Phase 4(Verify) — `hooks/lib/skeleton-scan.js` 직접 통과 확인**

Phase 4 규약("파일 생성은 통과 후에만")을 지키려면 draft 를 **최종 경로가 아닌 스크래치 경로**에 먼저 쓰고
그걸 검증한 뒤에만 `skills/orca-rpi-cycle/SKILL.md` 로 옮긴다:

```bash
mkdir -p "$HOME/.claude/.orca-rpi"
DRAFT="$HOME/.claude/.orca-rpi/skill-draft.md"   # git 비추적 스크래치 경로(Task 1 의 RUNDIR 관례 재사용)
# (Step 2-4 에서 조립한 draft 내용을 $DRAFT 에 쓴다)
node -e '
  const fs = require("fs");
  const content = fs.readFileSync(process.argv[1], "utf8");
  const input = JSON.stringify({tool_name:"Write", tool_input:{content}});
  process.stdout.write(input);
' "$DRAFT" | FP="skills/orca-rpi-cycle/SKILL.md" node hooks/lib/skeleton-scan.js
```
Expected: 공백 구분 4개 정수 `<hasMarker> <phase> <agent> <contract>`(예: `1 4 1 2`) 이고 `hasMarker=1
&& phase>=3 && agent>=1 && contract>=1`. FAIL 시 draft 를 보정하고 재검증 — **통과한 뒤에만**
`mv "$DRAFT" skills/orca-rpi-cycle/SKILL.md`(create-orchestrator-skill Phase 4 규약: "통과 시에만 파일 생성").

- [x] **Step 6: Commit**

```bash
git add skills/orca-rpi-cycle/SKILL.md
git commit -m "feat(orca): T2 — skills/orca-rpi-cycle/SKILL.md (create-orchestrator-skill 산출물)"
```

---

### Task 3: `docs/ai-context/orca-worker-contract.md`

**Files:**
- Create: `docs/ai-context/orca-worker-contract.md`

**Interfaces:**
- Consumes: Task 1 의 정확한 서브커맨드명(`orca.exe` 절대경로·`worker_done` 정확 커맨드는 Orca CLI 명령이지 `bin/orca-rpi.sh` 서브커맨드가 아님 — worker_done 은 워커가 **직접** `$ORCA orchestration send` 를 호출한다, T1 은 coordinator 측 subcommand 세트에 `send`/`ask`/`reply` 를 포함하지 않는다).
- Produces: seal #52-ⓑ(향후 T10)가 검사할 필수 토큰 6종의 SSOT: `--outcome` · `--worktree current` · `read-only 팬아웃` · `RPI_SKIP 금지` · `orca.exe` · `inherit 위임 금지`.

- [x] **Step 1: 문서 작성**

`docs/ai-context/orca-worker-contract.md` 를 아래 내용으로 작성한다(★외곽 펜스는 4-backtick — 안의
`worker_done` 예시가 3-backtick bash 블록을 담고 있어 3-backtick 으로 감싸면 그 안쪽 블록의 닫는
펜스에서 외곽이 조기 종료된다. 실제 파일에는 이 4-backtick 자체는 쓰지 않는다 — 안의 내용만 그대로 옮긴다):

````markdown
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
````

- [x] **Step 2: seal #52-ⓑ 필수 토큰 6종 존재 확인**

```bash
for tok in '\-\-outcome' '\-\-worktree current' 'read-only 팬아웃' 'RPI_SKIP 금지' 'orca\.exe' 'inherit 위임 금지'; do
  grep -c "$tok" docs/ai-context/orca-worker-contract.md
done
```
Expected: 6줄 전부 `≥1`.

- [x] **Step 3: Commit**

```bash
git add docs/ai-context/orca-worker-contract.md
git commit -m "docs(orca): T3 — orca-worker-contract.md 워커 계약 SSOT"
```

---

## Best-Direction Check

**최선안**: 이 plan 이 구현하는 T1(코드 강제 스폰 캐리어)·T2(create-orchestrator-skill 산출물)·T3(preamble-비중복 계약 문서)는 `c21-orca-mode-design.md` 가 3-lens 적대 평가(실현가능성·하네스 시너지·적대적 파괴)로 3안 중 채택한 "안 2 — 층 분리형" 설계를 그대로 구현한다 — 이것이 이미 알려진 최선안이다.
**채택안**: 위와 동일(최선안 그대로 구현, 축소 없음).
**DOWNGRADE-DECLARED: 없음.**

세부 판단 3건은 설계 문서가 확정하지 않은 구현 디테일이며 축소가 아니라 구조적 필연:
1. 금지 명령 6종을 소스에 denylist 로 나열하지 않고 구조(고정 서브커맨드→고정 orca.exe 호출)로만 막은 것 — design §6.4 가 지적한 "정의행 자체가 vacuous 가드를 무력화" 클래스를 T1 자신도 피하기 위함(T6 오라클이 아직 없는 상태에서 스스로 그 함정에 빠지지 않는 것이 더 나은 방향이지 열화가 아니다).
2. 자원-생성 서브커맨드가 원본 JSON 대신 추출 ID 1줄만 반환하는 것 — c22-probe 의 "함정"(최상위 `.id` 오채택)을 코드로 구조적으로 막는 **더 강한** 설계(원본 그대로 반환하고 문서로 "조심하라"고 적는 것보다 우월).
3. 동시성 추적을 파일 기반으로 구현한 것 — 캐리어가 매 호출 새 프로세스인 구조적 제약 하에서 상태를 유지하는 유일한 방법(설계 문서 자체가 이 구현 디테일까지는 내려가지 않았으나, 파일 기반 잠금은 이 하네스의 기존 관례 — `worktrees-marker/` 등 — 와 정합).

## 무회귀 검증 (전체 착륙 후)

```bash
bash setup/verify-setup.sh          # 기준선 90/0 무회귀 확인
bash hooks/tests/run-all.sh         # 기준선 305/305(또는 이 사이클 실측 기준선) 무회귀 확인 — T1-T3 는 hooks/ 를 건드리지 않으므로 회귀 없어야 함
bash setup/tests/seal-regression.test.sh   # setup/+입력집합 diff 없으면 SKIP+사유(이번 사이클은 setup/ 미변경 예상) — 조건부, Closeout 에서 diff 확인 후 결정
```

---

## 실행 결과 · Closeout 재감사 · 정정 (2026-08-17)

### 착륙물

| Task | 파일 | 최종 |
|---|---|---|
| T1 | `bin/orca-rpi.sh` | 500줄 · git mode **100755**(`git update-index --chmod=+x` — `core.filemode=false` 라 작업트리 권한이 인덱스에 반영되지 않던 결함을 닫음) |
| T2 | `skills/orca-rpi-cycle/SKILL.md` | 256줄 · `skeleton-scan.js` → `1 6 7 1` (요건 `1 ≥3 ≥1 ≥1`) |
| T3 | `docs/ai-context/orca-worker-contract.md` | 91줄 · seal #52-ⓑ 토큰 6종 전부 ≥1 · 승인 채널 층 분리 표 §5 |
| 부속 | `.gitignore`(`/.orca-rpi/`) · `CONTEXT.md`(용어 3종) · `docs/ai-context/scaffold-registry.md`(`orca-rpi-cycle` 등재, Skills 10→11) · `docs/ai-context/c21-orca-mode-design.md` §11.9(spec delta 10건) | — |

### TDD 증거 (stub `$ORCA` 로 격리 재수행 — 라이브 DB 오염 0)

- ⓐ `bash -n bin/orca-rpi.sh` → OK · `selfcheck` → rc=0
- ⓑ `spawn --run r --task t --model opus` → **rc=1** + `거부: '--model' 은 이 캐리어가 받지 않는 인자입니다 …`
  · `task … --effort xhigh` → rc=1 · `wait … --on env` → rc=1 · `spawn --worktree new-child` → rc=1
  · **오탐 제거 확인**: `run --objective new-child`(값 토큰) → rc=0 정상 통과 (정정 전에는 전역 스캐너가 정당한 값을 거부했다)
- ⓒ 원장 선점 후 2번째 `spawn` → **rc=1** + `거부: non-readonly task 동시 실행 상한(1) 초과 — 활성: task_A`
- ⓓ 금지 명령 리터럴 `grep -c` → **0**
- 추가: `$ORCA`=`*.cmd` → 전 서브커맨드 rc=1(`selfcheck`/`gpt` 는 의도적 예외) · `# [P2]` 는 **4종**(dispatch id · delivery id · gate id · `agent_terminal_handle`)에만

### 재감사에서 나온 정정 (검증 3층 + 교차패밀리 2슬롯)

**캐리어 C-1~C-20**: `ensure_rundir` fail-closed · 원장 접근 원자화(mkdir 뮤텍스) · `outcome_unknown` 에서 슬롯 **비-롤백** · `--retry-of` 수용 · dispatch/gate id 의 `.id` 폴백 제거(요청 상관 ID 오채택 차단) · `handoff` 가 dispatch id 를 출력하고 원장을 원자 교체 · `--types` 에 **`decision_gate` 추가** · `jq` 실패 비-침묵화 · **전건 순회 후 ack 를 코드로 강제**(직전 배치 자동 `--ack`, 불일치 ack 거부) · keepalive 로그에 묻힌 진단 표면화 · release 는 rc=0 일 때만 슬롯 해제 + 실제 `diff -u` 출력 · `assert_orca_exe` 를 `main()` 에서 강제 · 금지 인자 가드를 **위치-인식**으로 교체 · `gpt --model`→`--gpt-model` · `"${2:-}"` 가드 · `wt_sel` 파일 소비 · preflight `timeout` 래핑 · 응답을 die 이전에 저장 · `task --run` 수용 · selfcheck 실재성 검사

**SKILL S-1~S-11**: 브랜치 가드 신설(`master|main` 에서 non-readonly 스폰 금지 — `current` 가 main worktree/master 라 사람 승인이 사후 무력화됨) · 4종 템플릿이 **층1 호출을 명령**(`Agent(explore|execute|review-strict)`·`Workflow(rpi-implement.js)`) · 템플릿 첫 지시로 **계약문서 절대경로 읽기**(자동 상속되지 않음) · `--outcome succeeded|failed` · `--prev-task` 동반 · `reply` 절대경로 `.exe` · `--outcome failed` 시 DAG 미전진 · 터미널 소멸 분기 · Phase 4 는 두 dispatch 가 settle 할 때까지 수확 · 전 dispatch release + 재사용 터미널 미폐쇄 정직 부기 · `--readonly` overclaim 정정

**계약 T-1~T-4**: 자동 상속 거짓 단언 제거 · `--outcome <succeeded|failed>` · 코디네이터 `reply` 경로 명시 · `decision_gate` 수신 보장 명시

### 선언된 잔여 (silent downgrade 아님 — 차기 사이클)

1. **`install.sh` REQUIRED 등재** — 설계 §7 의 T1 행에 포함돼 있으나 사용자 goal 이 T17 을 범위 밖으로 명시. 이번엔 실행 비트 커밋만 이행. (§11.9 ⑨)
2. **`gpt` 서브커맨드의 비용 원장 append**(설계 §4 의 `_goal/<cycle>-ocx-ledger.tsv`) — goal 의 T1 불변식 목록 밖이라 미구현.
3. **`worker-start`/`worker-show`/`gate-create`/`check` 실응답 shape** — 실 워커를 띄워야 확정. `# [P2]` 4종 유지.
4. **`--retry-request` 기반 정확 복구**(unknown mutation) — 미구현, 재시도는 `--retry-of` 만.
5. **우발 생성된 라이브 Orca run `run_4e4776c1b041`(objective="new-child")** — 정정 위임의 증거 수집 명령이 stub 없이 라이브 CLI 에 도달해 생성. 삭제 명령 부재 + `orchestration reset` 은 금지 명령(안전제약 6) → **영구 잔존**. 이후 전 검증은 stub 으로 격리 재수행.

### 무회귀 검증 결과

- `setup/verify-setup.sh` → **PASS=90 FAIL=0** (정정 전 89/1 — seal #37 scaffold-registry 미등재)
- `hooks/tests/run-all.sh` → **305/305**
- `setup/tests/seal-regression.test.sh` → **full 실행**(`skills/` diff 존재 → SKIP 불가)
