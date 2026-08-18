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
  git -C "$1" checkout -q -B "$2" 2>/dev/null || return 1
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
  # ★델타는 「픽스처를 심은 뒤」부터 잰다(§11.10 ② ⓙ: 절대량이 아니라 델타) — 아암 루프와 같은 idiom.
  #   이 선-기록이 없으면 run_dry 자신의 wt_sel 쓰기가 AFTER 에만 잡혀 델타가 **캐리어 동작과 무관하게**
  #   항상 ≠0 이 된다(단언이 무조건 거짓 = 판정 불능).
  printf 'c23fixture::%s' "$MFIX" > "$RD/wt_sel"
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
