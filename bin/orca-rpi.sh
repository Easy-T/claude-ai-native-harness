#!/usr/bin/env bash
# bin/orca-rpi.sh — 유일 스폰 캐리어 (c21-orca-mode-design.md §7 T1)
#   Orca ADE 오케스트레이션을 하네스 규약 안에서 구동하는 코드 레벨 경계.
#   서브커맨드: preflight run task spawn wait handoff release gate gpt selfcheck
#   불변식은 문서가 아니라 이 스크립트가 강제한다 — 상세 근거는 docs/ai-context/c21-orca-mode-design.md.
#   stdout 계약: run=run id / task=task id / spawn=dispatch id / handoff=dispatch id / gate create=gate id
#     (handoff 는 봉투 JSON 이 아니라 dispatch id 1줄만 낸다 — 원본은 $RUNDIR/last-handoff.json).
#   gpt 서브커맨드의 모델 인자는 '--gpt-model' 이다(캐리어 어느 서브커맨드도 '--model' 리터럴을 받지 않는다).
set -u

# orca.cmd 는 orchestration send/reply 를 exit /b 2 로 거부한다(orca.cmd:13-14 verbatim) —
# worker_done 이 send 이므로 .exe 가 결정적으로 필요하다(설계 §3.0 함정②).
ORCA="${ORCA_CLI_COMMAND:-C:/Users/12132/AppData/Local/Programs/orca/resources/bin/orca.exe}"
RUNDIR="${ORCA_RPI_RUNDIR:-$HOME/.claude/.orca-rpi}"
SELF="$(basename "$0")"
# 안내 줄에 붙여 넣을 용도 — basename 은 PATH 에 없어 그대로 복사하면 command-not-found 다(§11.10 ④).
SELF_PATH="$0"

# hang 하는 CLI 는 rc 를 주지 않는다 — "사이클은 절대 멈추지 않는다"는 fail-open 약속이 깨진다.
# timeout(1) 이 있으면 상한을 씌우고, 없으면 그대로 호출한다(가용성 의존 금지).
ORCA_TIMEOUT_BIN="$(command -v timeout 2>/dev/null || true)"
orca_t() {
  if [ -n "$ORCA_TIMEOUT_BIN" ]; then "$ORCA_TIMEOUT_BIN" 60 "$ORCA" "$@"; else "$ORCA" "$@"; fi
}

die() { echo "$SELF: $*" >&2; exit 1; }

# ── 검증-전용 경로 (§11.10 ②) ────────────────────────────────────────────────
# 인자·금지 플래그·워크트리·브랜치 가드를 전부 통과한 뒤 **부작용 경계 직전**에 정지한다.
# 정지 지점이 원장/설정 쓰기와 외부 호출 **양쪽 앞**이라 격리 토큰 1개로 충분하다.
# 상한: 원장 뮤텍스(동시-1 상한)는 본질적으로 쓰기라 이 경로로 검증되지 않는다.
is_dryrun() { [ -n "${ORCA_RPI_DRYRUN:-}" ]; }
dryrun_emit() { printf 'DRYRUN: %s\n' "$*"; exit 0; }

# mkdir -p / touch 실패를 무시하면 동시성 원장이 침묵 무효화된다(ORCA_RPI_RUNDIR=/dev/null 재현) —
# 원장은 동시-1 불변식의 유일한 저장소이므로 여기서 즉시 죽는다.
ensure_rundir() {
  mkdir -p "$RUNDIR" || die "RUNDIR 생성 실패: $RUNDIR — 동시성 원장을 쓸 수 없다"
  touch "$RUNDIR/active-nonreadonly.tasks" || die "원장 파일 생성 실패: $RUNDIR/active-nonreadonly.tasks"
}
require_jq() { command -v jq >/dev/null 2>&1 || die "jq 미설치 — 이 캐리어는 jq 에 의존한다"; }

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

# ── 동시성 원장 뮤텍스 ────────────────────────────────────────────────────────
# 읽기-검사-추가 사이에 잠금이 없으면 두 프로세스가 동시에 0을 읽고 둘 다 워커를 띄운다.
# mkdir 은 POSIX 원자 연산 — 파일 잠금 없이도 상호배제가 성립한다.
SLOT_LOCK_HELD=0
slot_lock() {
  ensure_rundir
  local i=0
  while ! mkdir "$RUNDIR/.lock" 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -ge 100 ] && die "원장 잠금 획득 실패(~10초) — 스테일 잠금이면 '$RUNDIR/.lock' 을 확인 후 제거하라"
    sleep 0.1
  done
  SLOT_LOCK_HELD=1
  trap 'slot_unlock' EXIT INT TERM
}
slot_unlock() {
  [ "$SLOT_LOCK_HELD" -eq 1 ] || return 0
  SLOT_LOCK_HELD=0
  rmdir "$RUNDIR/.lock" 2>/dev/null || true
}
# 잠금 안에서만 호출할 것.
slot_remove() {
  local t="$1"
  grep -vFx "$t" "$RUNDIR/active-nonreadonly.tasks" > "$RUNDIR/active-nonreadonly.tasks.tmp" 2>/dev/null
  mv "$RUNDIR/active-nonreadonly.tasks.tmp" "$RUNDIR/active-nonreadonly.tasks" 2>/dev/null || true
}

# --worktree 는 'current' 또는 실측 selector 값만 허용한다(설계 §5.3 "selector 재조립 금지" —
# worktree current --json 반환값을 verbatim 보존, 재조립 시 MSYS 경로 보간 사고 재현 위험).
# 우선순위: current → $WT_SEL → $RUNDIR/wt_sel(preflight 가 실측 기록한 값).
assert_worktree_arg() {
  local v="$1" sel=""
  case "$v" in
    new-child|new-top-level)
      die "거부: '$v' — 워크트리는 always current 입니다(설계 §5.3 plan 가시성)" ;;
  esac
  [ "$v" = "current" ] && return 0
  if [ -n "${WT_SEL:-}" ] && [ "$v" = "$WT_SEL" ]; then return 0; fi
  if [ -s "$RUNDIR/wt_sel" ]; then
    sel=$(cat "$RUNDIR/wt_sel" 2>/dev/null)
    if [ -n "$sel" ] && [ "$v" = "$sel" ]; then return 0; fi
  fi
  die "거부: --worktree 는 'current' 또는 \$WT_SEL / $RUNDIR/wt_sel 값만 허용됩니다(받음: $v) — 설계 §5.3/§5.4"
}

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

# 호출자가 캐리어에 줄 수 없는 인자 — "명령 리터럴"이 아니라 "거부 로직의 패턴 문자열"이므로
# 여기 포함은 T1 TDD ⓓ("소스에 금지 명령 리터럴 0건")의 대상이 아니다(설계 근거 2번 참조).
# ★위치-인식: 각 파서 루프의 첫 줄에서만 호출한다(= 옵션 자리). 값 토큰까지 무차별 스캔하면
#   'run --objective new-child' 같은 정당한 *값*을 거부한다.
reject_forbidden_flag() {
  case "${1:-}" in
    --model|--model=*)
      die "거부: '--model' 은 이 캐리어가 받지 않는 인자입니다 — 모델 티어는 워커 내부(Agent/Workflow)로 미룬다(설계 §2·§4.1)" ;;
    --effort|--effort=*)
      die "거부: '--effort' 은 이 캐리어가 받지 않는 인자입니다 — --model 없이는 무의미하고 --terminal 과 배타입니다(설계 §3.5 스키마 NOTE)" ;;
    --on|--on=*)
      die "거부: '--on' 은 이 캐리어가 받지 않는 인자입니다(설계 §3.10)" ;;
  esac
}

# $ORCA 불변식 — 런타임을 건드리는 전 서브커맨드에 강제한다(selfcheck 는 죽는 대신 *보고*하므로 제외).
assert_orca_exe() {
  case "$ORCA" in
    *.cmd)
      die "거부: \$ORCA 가 orca.cmd 로 해소됨 — orchestration send/reply 를 exit /b 2 로 거부한다(설계 §3.0 함정②). ORCA_CLI_COMMAND 에 orca.exe 절대경로를 지정하라" ;;
  esac
  if [ ! -x "$ORCA" ] && ! command -v "$ORCA" >/dev/null 2>&1; then
    die "거부: \$ORCA 실행 불가 — '$ORCA' 는 실행 가능한 파일도, PATH 로 해소되는 명령도 아니다"
  fi
}

cmd_preflight() {
  # ★preflight 만 argv 가 아니라 *요약*이다 — 6-call 시퀀스라 단일 argv 가 원리적으로 성립하지 않는다.
  #   그래서 「(요약)」을 문자열 안에 박아, 다른 서브커맨드의 완전-argv 계약과 혼동되지 않게 한다.
  is_dryrun && dryrun_emit "preflight (요약 — 단일 argv 불성립): status / orchestration run-list / repo list / worktree current / agent hooks status"
  require_jq
  ensure_rundir
  cp "$HOME/.claude/settings.json" "$RUNDIR/settings.pre-orca.json" || die "preflight: settings.json 백업 실패"

  orca_t status --json >"$RUNDIR/preflight-status.json" 2>&1 || { echo "preflight: orca status 실패 — Orca 미가동, 사이클은 기존 Phase I (a)/(d) 로 폴백" >&2; exit 3; }
  jq -e '.ok == true' "$RUNDIR/preflight-status.json" >/dev/null 2>&1 || { echo "preflight: orca status ok!=true" >&2; exit 3; }

  orca_t orchestration run-list --json >"$RUNDIR/preflight-runlist.json" 2>&1 || { echo "preflight: orchestration RPC 도달 실패" >&2; exit 3; }
  orca_t repo list --json >"$RUNDIR/preflight-repolist.json" 2>&1 || { echo "preflight: repo list 실패" >&2; exit 3; }

  local wt_sel; wt_sel=$(orca_t worktree current --json 2>/dev/null | jq -r '.result.worktree.id // empty')
  [ -n "$wt_sel" ] || { echo "preflight: worktree current 셀렉터 미획득 — 'orca repo add' 로 이 repo 등록 확인(설계 §9-A1)" >&2; exit 3; }
  printf '%s' "$wt_sel" > "$RUNDIR/wt_sel"

  orca_t agent hooks status --json >"$RUNDIR/preflight-hooks-status.json" 2>&1 || { echo "preflight: agent hooks status 실패" >&2; exit 3; }
  # ★아래 두 cksum 은 *기록용 스냅샷*이지 게이트가 아니다 — 파이프라인 앞단($ORCA)이 실패해도
  #   cksum 자체는 빈 입력에 대해 성공하므로, 게이트로 쓰면 실패를 성공으로 가린다.
  orca_t agent-context --json 2>/dev/null | cksum > "$RUNDIR/agent-context.cksum"
  orca_t skills get orchestration --json 2>/dev/null | cksum > "$RUNDIR/skills-orchestration.cksum"

  # 하네스 전제 — plan 실재 단언(워커가 BLOCK 을 만나 RPI_SKIP 을 학습하는 경로 원천 차단, 설계 §3.1·§5.3).
  # 서브셸에서만 소싱 — _common.sh 의 `set -euo pipefail` 이 이 스크립트 본체를 오염시키지 않게.
  if ! ( . "$HOME/.claude/hooks/_common.sh"; has_active_plan "$PWD" >/dev/null ); then
    echo "preflight: no active plan — Orca 모드 진입 거부" >&2
    exit 3
  fi

  echo "preflight: OK worktree=$wt_sel"
}

cmd_run() {
  local objective="" retry_request=""
  while [ $# -gt 0 ]; do
    reject_forbidden_flag "$1"
    case "$1" in
      --objective) objective="${2:-}"; [ -n "$objective" ] || die "run: --objective 필수"; shift 2 ;;
      # 정확 복구 — 같은 요청 id 로 멱등 재발행해 중복 레코드 없이 원 결과를 회수한다(§11.10 ④).
      --retry-request) retry_request="${2:-}"; [ -n "$retry_request" ] || die "run: --retry-request 값(요청 id) 필요"; shift 2 ;;
      *) die "run: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$objective" ] || die "run: --objective 필수"
  # 선택 인자 배열은 DRYRUN 정지점 **앞**에서 조립한다 — 뒤에서 조립하면 emit 이 부분집합 argv 가 된다(§11.10 ②).
  local rr=()
  [ -n "$retry_request" ] && rr=(--retry-request "$retry_request")
  is_dryrun && dryrun_emit orchestration run-create --objective "$objective" "${rr[@]}" --json
  require_jq; ensure_rundir
  # 응답은 die 이전에 항상 저장한다 — 실패 시 증거가 사라지면 진단이 불가능하다.
  local resp rc
  resp=$("$ORCA" orchestration run-create --objective "$objective" "${rr[@]}" --json)
  rc=$?
  printf '%s' "$resp" > "$RUNDIR/last-run-create.json"
  if [ "$rc" -ne 0 ]; then
    # 봉투 최상위 .id 는 요청 상관ID(c22-probe P0-2) — 그것이 곧 --retry-request 인자다.
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
  # ★함정(c22-probe P0-2) — 봉투 최상위 .id 는 요청 상관ID(run id 아님). result.run.id 만 채택.
  local run_id; run_id=$(printf '%s' "$resp" | jq -r '.result.run.id // empty')
  [ -n "$run_id" ] || die "run: result.run.id 추출 실패 — 응답: $RUNDIR/last-run-create.json"
  printf '%s\n' "$run_id"
}

cmd_task() {
  local title="" spec="" deps="" run="" retry_request=""
  while [ $# -gt 0 ]; do
    reject_forbidden_flag "$1"
    case "$1" in
      --title) title="${2:-}"; [ -n "$title" ] || die "task: --title 와 --spec 필수"; shift 2 ;;
      --spec) spec="${2:-}"; [ -n "$spec" ] || die "task: --title 와 --spec 필수"; shift 2 ;;
      --deps) deps="${2:-}"; [ -n "$deps" ] || die "task: --deps 값 필요(json 배열)"; shift 2 ;;
      # run 바인딩이 프로세스 경계를 넘는지 미보장 — 명시 전달 경로를 둔다(실측 help 에 존재).
      --run) run="${2:-}"; [ -n "$run" ] || die "task: --run 값 필요"; shift 2 ;;
      # 정확 복구 — task-create 수용은 C23 Task 1 --help 실측(§11.10 ④ 「확인된 명령만」).
      --retry-request) retry_request="${2:-}"; [ -n "$retry_request" ] || die "task: --retry-request 값(요청 id) 필요"; shift 2 ;;
      *) die "task: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$title" ] && [ -n "$spec" ] || die "task: --title 와 --spec 필수"
  local extra=()
  [ -n "$deps" ] && extra=(--deps "$deps")
  [ -n "$run" ] && extra+=(--run "$run")
  [ -n "$retry_request" ] && extra+=(--retry-request "$retry_request")
  is_dryrun && dryrun_emit orchestration task-create --task-title "$title" --spec "$spec" "${extra[@]}" --json
  require_jq; ensure_rundir
  local resp rc
  resp=$("$ORCA" orchestration task-create --task-title "$title" --spec "$spec" "${extra[@]}" --json)
  rc=$?
  printf '%s' "$resp" > "$RUNDIR/last-task-create.json"
  [ "$rc" -eq 0 ] || die "task: task-create 실패(rc=$rc) — 응답: $RUNDIR/last-task-create.json"
  local task_id; task_id=$(printf '%s' "$resp" | jq -r '.result.task.id // empty')
  [ -n "$task_id" ] || die "task: result.task.id 추출 실패 — 응답: $RUNDIR/last-task-create.json"
  printf '%s\n' "$task_id"
}

cmd_spawn() {
  local readonly_flag=0 task="" worktree="current" run="" retry_of="" retry_request=""
  while [ $# -gt 0 ]; do
    reject_forbidden_flag "$1"
    case "$1" in
      --readonly) readonly_flag=1; shift ;;
      --run) run="${2:-}"; [ -n "$run" ] || die "spawn: --run 과 --task 필수"; shift 2 ;;
      --task) task="${2:-}"; [ -n "$task" ] || die "spawn: --run 과 --task 필수"; shift 2 ;;
      --worktree) [ -n "${2:-}" ] || die "spawn: --worktree 값 필요"; assert_worktree_arg "$2"; worktree="$2"; shift 2 ;;
      # 승인된 유일 재시도 경로 — 실패 안내가 --retry-of 를 지시하므로 파서가 반드시 받아야 한다.
      --retry-of) retry_of="${2:-}"; [ -n "$retry_of" ] || die "spawn: --retry-of 값(dispatch id) 필요"; shift 2 ;;
      # ★--retry-of 와 다른 축이다 — 저쪽은 *새* 시도(레코드 증가), 이쪽은 같은 mutation 의 멱등 재발행(§11.10 ④).
      --retry-request) retry_request="${2:-}"; [ -n "$retry_request" ] || die "spawn: --retry-request 값(요청 id) 필요"; shift 2 ;;
      *) die "spawn: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$task" ] && [ -n "$run" ] || die "spawn: --run 과 --task 필수"
  # read-only 팬아웃은 브랜치 무관 허용 — 커밋하지 않기로 *선언*된 경로다(§11.9 ⑧ 자기-선언 상한 상속).
  [ "$readonly_flag" -eq 1 ] || assert_branch_not_merge_target "$worktree"
  local extra=()
  # --retry-of 는 배치(placement)를 상속하지 않는다(스키마 NOTE) — --worktree/--agent 를 매번 재지정한다.
  [ -n "$retry_of" ] && extra=(--retry-of "$retry_of")
  [ -n "$retry_request" ] && extra+=(--retry-request "$retry_request")
  is_dryrun && dryrun_emit orchestration worker-start --run "$run" --task "$task" --worktree "$worktree" --agent claude "${extra[@]}" --json
  require_jq; ensure_rundir

  if [ "$readonly_flag" -eq 0 ]; then
    # 읽기-검사-추가를 한 임계구역에 넣는다(잠금 없으면 두 프로세스가 동시에 0을 읽는다).
    slot_lock
    local active; active=$(wc -l < "$RUNDIR/active-nonreadonly.tasks" 2>/dev/null || echo 0)
    if [ "${active:-0}" -ge 1 ]; then
      die "거부: non-readonly task 동시 실행 상한(1) 초과 — 활성: $(tr '\n' ' ' < "$RUNDIR/active-nonreadonly.tasks") (설계 §3.6 — Orca 는 충돌을 추론하지 않는다, orchestration.md:181/:342)"
    fi
    echo "$task" >> "$RUNDIR/active-nonreadonly.tasks"
    slot_unlock
  fi

  local resp rc
  resp=$("$ORCA" orchestration worker-start --run "$run" --task "$task" --worktree "$worktree" --agent claude "${extra[@]}" --json)
  rc=$?
  printf '%s' "$resp" > "$RUNDIR/last-worker-start.json"

  if [ "$rc" -ne 0 ]; then
    # ★슬롯을 롤백하지 않는다 — 스키마 NOTE: "Failed or outcome_unknown exits 1".
    #   outcome_unknown 은 워커가 살아있을 수 있으므로, 슬롯을 푸는 순간 동시-1 불변식이 깨진다.
    echo "spawn: worker-start 비-0(rc=$rc, ready 아님) — 자동 재시도 금지, --retry-of <dispatch_id> 로만 재시도(설계 §3.3)" >&2
    if [ "$readonly_flag" -eq 0 ]; then
      echo "spawn: 원장 슬롯 유지 — outcome_unknown 가능성(워커 생존 가능). 재시도 전 'release --task $task' 로 명시 해제 필요" >&2
    fi
    echo "spawn: 응답 JSON(stage/failedStage/setup/effects/residualResources/recovery): $RUNDIR/last-worker-start.json" >&2
    # 정확 복구 안내 — 봉투 최상위 .id 가 요청 상관ID다(c22-probe P0-2). 위 --retry-of 안내는 유지한다:
    # --retry-of 는 *새* 시도, --retry-request 는 같은 mutation 의 멱등 재발행이라 축이 다르다(§11.10 ④).
    local req_id; req_id=$(printf '%s' "$resp" | jq -r '.id // empty' 2>/dev/null)
    if [ -n "$req_id" ]; then
      # ★붙여 넣으면 바로 도는 줄이어야 한다 — placeholder 금지. $SELF(=basename)는 PATH 에 없다.
      #   원 호출의 선택 인자(--readonly/--retry-of)를 그대로 싣는다 — 빠뜨리면 재발행이 *다른* mutation 이 된다.
      local line; line="  bash $(printf '%q' "$SELF_PATH") spawn"
      [ "$readonly_flag" -eq 1 ] && line="$line --readonly"
      line="$line --run $(printf '%q' "$run") --task $(printf '%q' "$task") --worktree $(printf '%q' "$worktree")"
      [ -n "$retry_of" ] && line="$line --retry-of $(printf '%q' "$retry_of")"
      line="$line --retry-request $(printf '%q' "$req_id")"
      echo "spawn: 정확 복구(중복 dispatch 없이 원 결과 회수) — 아래를 그대로 실행하라:" >&2
      printf '%s\n' "$line" >&2
    else
      echo "spawn: 요청 id 를 응답에서 뽑지 못했다 — 정확 복구 명령을 제시할 수 없다. 그냥 재발행하면 중복 dispatch 가 생긴다(삭제 명령 부재). 응답 확인: $RUNDIR/last-worker-start.json" >&2
    fi
    exit "$rc"
  fi
  # ★실측(C23 Task 1 Step 4): worker-start 응답은 dispatch 를 중첩 객체가 아니라 **평면 camelCase**
  # `.result.dispatchId` 로 낸다(실측값 예: ctx_b35f37d7e59e). 추정이던 `.result.dispatch.id` 는
  # worker-**show** 의 shape 였다 — 같은 축의 *다른 명령* 에서 온 경로라 코드 독해로는 구분되지 않았다.
  # 객체 폴백(.result.dispatch)은 객체 직렬화를 id 로 출력하므로 쓰지 않는다.
  local dispatch_id; dispatch_id=$(printf '%s' "$resp" | jq -r '.result.dispatchId // empty')
  [ -n "$dispatch_id" ] || die "spawn: dispatch id 추출 실패 — 응답 확인: $RUNDIR/last-worker-start.json"
  printf '%s\n' "$dispatch_id"
}

cmd_wait() {
  local run="" timeout=900000 ack=""
  while [ $# -gt 0 ]; do
    reject_forbidden_flag "$1"
    case "$1" in
      --run) run="${2:-}"; [ -n "$run" ] || die "wait: --run 필수"; shift 2 ;;
      --timeout-ms) timeout="${2:-}"; [ -n "$timeout" ] || die "wait: --timeout-ms 값 필요"; shift 2 ;;
      --ack) ack="${2:-}"; [ -n "$ack" ] || die "wait: --ack 값(delivery id) 필요"; shift 2 ;;
      *) die "wait: 인식하지 않는 인자 '$1'" ;;
    esac
  done
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
  # ★--retry-request 는 여기 배선하지 않는다(선언된 미배선 — 침묵 잔여 금지): `check` 도 수용은 하지만
  #   (C23 Task 1 --help 실측) help Notes 가 "only for exact recovery after an unknown **mutation** result"
  #   이고 §11.10 ④ⓐ 의 배선 대상은 「변이 서브커맨드」다. check 는 대기/조회라 회수할 mutation 이 없다.

  is_dryrun && dryrun_emit orchestration check --run "$run" --wait --types worker_done,escalation,question,decision_gate --timeout-ms "$timeout" "${extra[@]}" --json
  require_jq; ensure_rundir

  # ★--types 에 decision_gate 필수 — 워커 preamble RULE#1 이 'send --type decision_gate' 를 명시
  #   허용하므로, 이 타입이 wake 목록에서 빠지면 워커가 게이트를 올린 채 영구 hang 한다.
  # ★stderr 로 keepalive 분리(15초 간격, 스키마 usage verbatim) — stdout 은 이미 깨끗하지만
  #   병합 상황을 대비해 _keepalive 필터도 이중으로 건다(설계 §3.4 jq 'select(._keepalive|not)').
  "$ORCA" orchestration check --run "$run" --wait --types worker_done,escalation,question,decision_gate \
    --timeout-ms "$timeout" "${extra[@]}" --json \
    1>"$RUNDIR/last-check.json" 2>>"$RUNDIR/keepalive.log"
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    # orca 진단 메시지는 keepalive 로그에 묻힌다 — 코디네이터에게 최소한을 표면화한다.
    echo "wait: orca check 비-0(rc=$rc) — keepalive.log 최근 20줄:" >&2
    tail -n 20 "$RUNDIR/keepalive.log" >&2 2>/dev/null
  fi

  # jq 실패를 침묵 삼키면(최상위가 배열이면 rc=5) 코디네이터가 "빈 배치=정상"으로 오해해
  # worker_done 을 통째로 유실한다 — 원본을 그대로 내고 비-0 을 돌려준다.
  local out jq_rc
  out=$(jq 'select(._keepalive|not)' "$RUNDIR/last-check.json" 2>>"$RUNDIR/keepalive.log")
  jq_rc=$?
  if [ "$jq_rc" -ne 0 ]; then
    cat "$RUNDIR/last-check.json"
    echo "wait: check 응답 파싱 실패(jq rc=$jq_rc) — 원본 그대로 출력. 원본: $RUNDIR/last-check.json" >&2
    return 1
  fi
  [ -n "$out" ] && printf '%s\n' "$out"

  # 배치 emit 이 성공한 뒤에만 ack 자격을 기록한다(rc 비-0 이면 배치 미확정 — pending 을 건드리지 않는다).
  if [ "$rc" -eq 0 ]; then
    # ★실측(C23 Task 1 Step 4): check 응답의 실경로는 평면 camelCase `.result.deliveryId` 다
    # (worker-start 축과 동형). 3중 폴백의 나머지 둘(`.result.delivery.id`·`.result.delivery_id`)은
    # 스키마에 없다 — 배치가 비어도 `deliveryId` 필드는 존재하고 값만 null 이므로, 필드 부재와
    # 빈 배치는 이 한 경로로 구분된다.
    local delivery_id
    delivery_id=$(printf '%s' "$out" | jq -r '.result.deliveryId // empty' 2>/dev/null)
    if [ -n "$delivery_id" ]; then
      printf '%s' "$delivery_id" > "$RUNDIR/pending-ack"
    else
      rm -f "$RUNDIR/pending-ack"
    fi
  fi
  return "$rc"
}

cmd_handoff() {
  local task="" dispatch="" prev_task="" run=""
  while [ $# -gt 0 ]; do
    reject_forbidden_flag "$1"
    case "$1" in
      --task) task="${2:-}"; [ -n "$task" ] || die "handoff: --task 와 --dispatch 필수"; shift 2 ;;
      --dispatch) dispatch="${2:-}"; [ -n "$dispatch" ] || die "handoff: --task 와 --dispatch 필수"; shift 2 ;;
      # 원장 원자 교체용 — 이 터미널을 붙잡고 있던 직전 task.
      --prev-task) prev_task="${2:-}"; [ -n "$prev_task" ] || die "handoff: --prev-task 값 필요"; shift 2 ;;
      --run) run="${2:-}"; [ -n "$run" ] || die "handoff: --run 값 필요"; shift 2 ;;
      *) die "handoff: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$task" ] && [ -n "$dispatch" ] || die "handoff: --task 와 --dispatch 필수"
  # handoff 는 --readonly 를 받지 않는다(정의상 편집 워커) — R→P→I→C 4단계 중 3단계가 이 경로다.
  assert_branch_not_merge_target current
  # ★handoff 는 2-call 이다 — 2번째(`worker-start --task … --terminal <handle>`)의 argv 는 1번째 응답의
  #   `$handle` 에 **데이터 의존**해 선-emit 이 원리적으로 불가하다. `preflight` 와 동류의 예외이므로
  #   emit 앞에 라벨을 박아 자기-표시한다(spec §11.10 ② 「묵시적 예외 금지」 — C23 Task 3 stage2 O2).
  #   라벨은 접두사일 뿐 argv 토큰열은 실호출과 그대로 일치한다.
  is_dryrun && dryrun_emit "handoff 1/2 (2번째 worker-start --terminal <handle> 는 이 응답에 의존 — 선-emit 불가):" orchestration worker-show --dispatch "$dispatch" --json
  require_jq; ensure_rundir
  # ★실측(C23 Task 1 Step 5): worker-show 는 중첩 snake_case **레코드**를 낸다 —
  # `.result.worker.agent_terminal_handle` 이 맞다(실측값 예: term_42a7b36b-…).
  # 동값 별칭 3종이 함께 존재하지만(.result.dispatch.assignee_handle · .result.terminal.handle ·
  # .result.terminalResource.terminalHandle) 계약 경로 하나만 쓴다 — 별칭 폴백은 "모른다"의 표기다.
  local resp handle
  resp=$("$ORCA" orchestration worker-show --dispatch "$dispatch" --json) || die "handoff: worker-show 실패"
  handle=$(printf '%s' "$resp" | jq -r '.result.worker.agent_terminal_handle // empty')
  [ -n "$handle" ] || die "handoff: agent_terminal_handle 획득 실패 — 응답 확인 필요"

  # 원장 원자 교체(prev-task 제거 + task 추가) — handoff 도 편집 워커이므로 동시-1 원장을 유지해야 한다.
  slot_lock
  if [ -s "$RUNDIR/active-nonreadonly.tasks" ]; then
    [ -n "$prev_task" ] || die "handoff: 원장에 활성 task 가 있는데 --prev-task 가 없다 — 무엇을 교체하는지 불명이면 동시-1 불변식이 깨진다(활성: $(tr '\n' ' ' < "$RUNDIR/active-nonreadonly.tasks"))"
    grep -qFx "$prev_task" "$RUNDIR/active-nonreadonly.tasks" || die "handoff: --prev-task '$prev_task' 가 원장에 없다 — 교체가 아니라 추가가 되어 상한이 무너진다(활성: $(tr '\n' ' ' < "$RUNDIR/active-nonreadonly.tasks"))"
    slot_remove "$prev_task"
  fi
  echo "$task" >> "$RUNDIR/active-nonreadonly.tasks"
  slot_unlock

  local extra=()
  [ -n "$run" ] && extra=(--run "$run")
  # ★--terminal 은 --agent 와 배타(스키마 verbatim: "Neither can combine with --terminal",
  #   "(--agent <agent> | --terminal <handle>)") — 이 경로는 --terminal 재사용이므로 --agent 를 절대 안 준다.
  #   같은 이유로 --model/--effort 도 받지 않는다(설계 §3.5).
  local hresp hrc
  hresp=$("$ORCA" orchestration worker-start --task "$task" --terminal "$handle" "${extra[@]}" --json)
  hrc=$?
  printf '%s' "$hresp" > "$RUNDIR/last-handoff.json"
  if [ "$hrc" -ne 0 ]; then
    echo "handoff: worker-start 비-0(rc=$hrc, ready 아님) — 원장 슬롯 유지(outcome_unknown 가능). 재시도 전 'release --task $task' 로 명시 해제 필요" >&2
    die "handoff: worker-start 실패 — 응답: $RUNDIR/last-handoff.json"
  fi
  # stdout 계약 = dispatch id 1줄(봉투 JSON 전문을 흘리면 호출자의 D=$(... handoff ...) 가 결정적으로 깨진다)
  # [P2 미해제 사유: terminal 기반 worker-start(--terminal) 응답은 C23 에서 **미측정**이다 — handoff 를
  #  호출하려면 워커를 한 기 더 띄워야 하고 그것은 이번 사이클의 라이브 예산(read-only 1기동) 밖이다.
  #  경로는 agent 기반 실측(`.result.dispatchId`, C23 Step 4)에서 **유추해 갱신**했다: 같은 CLI 명령이라
  #  동형일 가능성이 높다. 그럼에도 마커를 남기는 이유는 유추가 실측이 아니기 때문이고, 경로를
  #  갱신하는 이유는 알려진-틀린 `.result.dispatch.id` 를 그대로 두는 것이 「미측정」의 정직한 표현이
  #  아니기 때문이다(C23 Task 1 Step 6 처분 — plan 은 마커 유지만 지시했으나 실측이 형제 사이트의
  #  경로까지 반증했으므로 「유지 + 유추 반영」으로 강화).]
  local dispatch_id; dispatch_id=$(printf '%s' "$hresp" | jq -r '.result.dispatchId // empty')  # [P2 미해제: 위 사유]
  [ -n "$dispatch_id" ] || die "handoff: dispatch id 추출 실패 — 응답 확인: $RUNDIR/last-handoff.json"
  printf '%s\n' "$dispatch_id"
}

cmd_release() {
  local dispatch="" task=""
  while [ $# -gt 0 ]; do
    reject_forbidden_flag "$1"
    case "$1" in
      --dispatch) dispatch="${2:-}"; [ -n "$dispatch" ] || die "release: --dispatch 필수"; shift 2 ;;
      --task) task="${2:-}"; [ -n "$task" ] || die "release: --task 값 필요"; shift 2 ;;
      *) die "release: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$dispatch" ] || die "release: --dispatch 필수"
  is_dryrun && dryrun_emit orchestration worker-release --dispatch "$dispatch" --json
  ensure_rundir
  "$ORCA" orchestration worker-release --dispatch "$dispatch" --json
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    if [ -n "$task" ]; then
      slot_lock
      slot_remove "$task"
      slot_unlock
    fi
  else
    # 해제 실패인데 슬롯을 비우면 편집 워커가 살아있는 채 다음 spawn 이 통과한다.
    echo "release: worker-release 비-0(rc=$rc) — 원장 슬롯 유지(워커 생존 가능). 해제 확인 후 재시도하라" >&2
  fi
  if [ -f "$RUNDIR/settings.pre-orca.json" ] && ! diff -q "$RUNDIR/settings.pre-orca.json" "$HOME/.claude/settings.json" >/dev/null 2>&1; then
    echo "release: 경고 — settings.json 이 preflight 이후 변경됨(훅 배선 무변경 단언 실패, 설계 §3.1/§3.9). diff:" >&2
    diff -u "$RUNDIR/settings.pre-orca.json" "$HOME/.claude/settings.json" >&2
  fi
  return "$rc"
}

cmd_gate() {
  local action="${1:-}"; [ $# -gt 0 ] && shift
  local task="" question="" id="" resolution="" retry_request=""
  while [ $# -gt 0 ]; do
    reject_forbidden_flag "$1"
    case "$1" in
      --task) task="${2:-}"; [ -n "$task" ] || die "gate: --task 값 필요"; shift 2 ;;
      --question) question="${2:-}"; [ -n "$question" ] || die "gate: --question 값 필요"; shift 2 ;;
      --id) id="${2:-}"; [ -n "$id" ] || die "gate: --id 값 필요"; shift 2 ;;
      --resolution) resolution="${2:-}"; [ -n "$resolution" ] || die "gate: --resolution 값 필요"; shift 2 ;;
      # 정확 복구 — gate-create 수용은 C23 Task 1 --help 실측(§11.10 ④ 「확인된 변이 명령만」).
      --retry-request) retry_request="${2:-}"; [ -n "$retry_request" ] || die "gate: --retry-request 값(요청 id) 필요"; shift 2 ;;
      *) die "gate: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  # DRYRUN 정지점 앞에서 조립한다 — 뒤면 emit 이 부분집합 argv 가 된다(§11.10 ②).
  local rr=()
  [ -n "$retry_request" ] && rr=(--retry-request "$retry_request")
  if is_dryrun; then
    case "$action" in
      create)  [ -n "$task" ] && [ -n "$question" ] || die "gate create: --task 와 --question 필수"
               dryrun_emit orchestration gate-create --task "$task" --question "$question" --options '["PASS","FAIL"]' "${rr[@]}" --json ;;
      resolve) [ -n "$id" ] && [ -n "$resolution" ] || die "gate resolve: --id 와 --resolution 필수"
               dryrun_emit orchestration gate-resolve --id "$id" --resolution "$resolution" --json ;;
      list)    [ -n "$task" ] || die "gate list: --task 필수"
               dryrun_emit orchestration gate-list --task "$task" --json ;;
      *) die "gate: 서브액션은 create|resolve|list 중 하나(받음: '$action')" ;;
    esac
  fi
  require_jq; ensure_rundir
  case "$action" in
    create)
      [ -n "$task" ] && [ -n "$question" ] || die "gate create: --task 와 --question 필수"
      local resp rc
      resp=$("$ORCA" orchestration gate-create --task "$task" --question "$question" --options '["PASS","FAIL"]' "${rr[@]}" --json)
      rc=$?
      printf '%s' "$resp" > "$RUNDIR/last-gate-create.json"
      [ "$rc" -eq 0 ] || die "gate create: 실패(rc=$rc) — 응답: $RUNDIR/last-gate-create.json"
      # ★실측(C23 Task 1 Step 5): gate-create 는 생성 레코드를 **타입 키 아래 중첩**해 낸다 —
      # `.result.gate.id` 가 맞다(실측값 예: gate_7153aa08d7e0). run-create/task-create 와 동형이고
      # worker-start 축(평면 camelCase)과는 다르다 — 이 갈림이 dispatch id 추정을 빗나가게 했다.
      # .id 폴백 금지 — 최상위 .id 는 요청 상관ID라 gate-resolve 가 영구 미해소된다(c22-probe P0-2).
      local gate_id; gate_id=$(printf '%s' "$resp" | jq -r '.result.gate.id // empty')
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
  # 모델 인자 이름이 '--gpt-model' 인 이유: "이 캐리어의 어느 서브커맨드도 '--model' 리터럴을
  # 수용하지 않는다"는 불변식을 예외 없이 만들기 위함(예외가 있으면 가드가 조건부가 된다).
  local role="" prompt="" gpt_model="gpt-5.6-sol" out=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --role) role="${2:-}"; [ -n "$role" ] || die "gpt: --role 값 필요(executor|verifier)"; shift 2 ;;
      --prompt) prompt="${2:-}"; [ -n "$prompt" ] || die "gpt: --prompt 필수"; shift 2 ;;
      --gpt-model) gpt_model="${2:-}"; [ -n "$gpt_model" ] || die "gpt: --gpt-model 값 필요"; shift 2 ;;
      --out) out="${2:-}"; [ -n "$out" ] || die "gpt: --out 값 필요"; shift 2 ;;
      *) die "gpt: 인식하지 않는 인자 '$1'" ;;
    esac
  done
  [ -n "$prompt" ] || die "gpt: --prompt 필수"
  case "$role" in
    executor)
      # 경로 B — 규율 아래 실행자(하네스 안, 설계 §4.3). 대상 문서는 stdin 으로 전달(호출자 책임).
      is_dryrun && dryrun_emit "OCX_MODEL=$gpt_model" "$HOME/.claude/bin/claude-ocx" -p "$prompt" --output-format json
      # stdout·rc 를 바이트 그대로 통과시켜야 하므로 임시 파일을 거친다($( ) 는 후행 개행을 먹는다).
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
    verifier)
      [ -n "$out" ] || die "gpt --role verifier: --out 필수(cross-family-review.md -o 소비 규율)"
      is_dryrun && dryrun_emit codex exec -m "$gpt_model" -c model_reasoning_effort=ultra -c model_verbosity=high --sandbox read-only --skip-git-repo-check -o "$out" "$prompt"
      rm -f "$out"
      codex exec -m "$gpt_model" -c model_reasoning_effort=ultra -c model_verbosity=high \
        --sandbox read-only --skip-git-repo-check -o "$out" "$prompt"
      local rc=$?
      # codex 는 비용 필드를 내지 않으므로 n/a — 모르는 값을 0 으로 적지 않는다(§11.10 ⑥).
      # ★부기는 [ -s "$out" ] 검증 **앞**이다 — 비용 부기가 검증 실패에 흡수되면 안 된다.
      gpt_ledger_append verifier "$gpt_model" "$rc" "n/a"
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
    *)
      # 존재하지 않는 경로도 .cmd 만 아니면 OK 를 내던 결함 정정 — 실행 가능성까지 확인한다.
      if [ -x "$ORCA" ] || command -v "$ORCA" >/dev/null 2>&1; then
        echo "OK ORCA=$ORCA"
      else
        echo "FAIL: \$ORCA 실행 불가 — '$ORCA' 는 실행 가능한 파일도, PATH 로 해소되는 명령도 아니다"; rc=1
      fi
      ;;
  esac
  return "$rc"
}

main() {
  local cmd="${1:-}"; [ $# -gt 0 ] && shift
  # 금지 인자(--model/--effort/--on)는 각 파서의 *옵션 위치*에서만 거부한다(reject_forbidden_flag) —
  # 무차별 스캔은 'run --objective new-child' 같은 정당한 값 토큰까지 죽인다.
  # selfcheck 는 진단 전용이라 assert 로 죽는 대신 스스로 FAIL 을 보고한다.
  # selfcheck 제외: 죽는 대신 보고하는 진단 커맨드다(C-20 이 여기서 실재·실행가능을 검사).
  # gpt 제외: 교차패밀리 리뷰 경로는 $ORCA 를 전혀 쓰지 않는다 — Orca 미설치 머신에서도 가용해야 한다.
  # gpt 제외와 같은 이유로 DRYRUN 도 제외한다 — 외부 프로세스를 부르지 않는 경로가 그 실행자의
  # 존재를 요구할 근거가 없고, Orca 미설치 머신에서도 인자·가드를 시험할 수 있어야 한다(§11.10 ②).
  case "$cmd" in selfcheck|gpt) ;; *) is_dryrun || assert_orca_exe ;; esac
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
