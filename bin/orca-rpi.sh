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

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
