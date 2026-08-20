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
# ★유도 정규식은 밑줄·숫자까지 받는다(슬롯 C1ⓐ): '^cmd_[a-z]+\(\)' 는 cmd_worker_show·cmd_gpt5 같은
#   이름을 통째로 놓치고, 목록에서 빠진 서브커맨드는 아래 fail-closed(ⓔ)도 DRYRUN 단언도 타지 않는다 —
#   드리프트를 놓치지 않으려고 코드에서 유도하는데 유도기 자신이 바로 그 드리프트에 뚫린다.
SUBS=$(grep -oE '^cmd_[a-z0-9_]+\(\)' "$CARRIER" | sed 's/^cmd_//; s/()$//')
[ -n "$SUBS" ] || { echo "✗ 서브커맨드 추출 실패 — 앵커(^cmd_*()) 붕괴"; exit 1; }
SUBC=$(printf '%s\n' "$SUBS" | grep -c .)
# ★개수 하한(C1ⓒ): 위 -n 단언은 앵커가 부분 붕괴해 *일부만* 잡혀도 통과한다 — 실측 10개를 하한으로
#   못 박는다. 서브커맨드를 의도적으로 줄였다면 이 값을 의식적으로 낮춰라(자동 추종 금지).
SUB_FLOOR=10
if [ "$SUBC" -ge "$SUB_FLOOR" ]; then
  ok "서브커맨드 ${SUBC}개 추출(하한 ${SUB_FLOOR} 충족): $(printf '%s ' $SUBS)"
else
  bad "서브커맨드 ${SUBC}개만 추출(하한 ${SUB_FLOOR}) — 유도 앵커 부분 붕괴 또는 서브커맨드 삭제: $(printf '%s ' $SUBS)"
fi

# --- ⓐ2 소비자 동반: main() dispatch 에서도 유도해 두 집합의 일치를 단언 (C1ⓑ) -----
# 유도의 권위 원천이 함수 정의뿐이면 「정의는 있는데 dispatch 미배선(=호출 불가)」과 그 반대
# 「dispatch 아암은 있는데 정의 없음」을 둘 다 못 본다. 생산자(정의) ↔ 소비자(dispatch)를 대조한다.
DSUBS=$(grep -oE '^[[:space:]]+[a-z0-9_]+\)[[:space:]]+cmd_[a-z0-9_]+[[:space:]]+"\$@"' "$CARRIER" \
        | sed 's/^[[:space:]]*//; s/).*//')
DSUBC=$(printf '%s\n' "$DSUBS" | grep -c .)
if [ -z "$DSUBS" ]; then
  bad "dispatch 유도 실패 — main() case 앵커 붕괴로 소비자 대조 불능(생산자만으로는 배선 누락을 못 본다)"
elif [ "$(printf '%s\n' "$SUBS" | sort)" = "$(printf '%s\n' "$DSUBS" | sort)" ]; then
  ok "생산자(cmd_* 정의 ${SUBC}) ↔ 소비자(main dispatch ${DSUBC}) 집합 일치 — 정의-전용/배선-전용 0"
else
  bad "생산자↔소비자 불일치 — 정의만: [$(comm -23 <(printf '%s\n' "$SUBS" | sort) <(printf '%s\n' "$DSUBS" | sort) | tr '\n' ' ')] dispatch만: [$(comm -13 <(printf '%s\n' "$SUBS" | sort) <(printf '%s\n' "$DSUBS" | sort) | tr '\n' ' ')]"
fi

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
      # `local x; x=$(orca_t …)` — 앞의 선언 절을 걷어내야 뒤의 호출이 보인다. C23 Closeout 실측:
      # 이것 하나 때문에 preflight 가 7 이 아니라 6 으로 세어졌고, 그 6 이 기대값으로 굳어 있었다
      # (탐지자의 과소계수가 기대값에 그대로 각인되는 형태 — 계수기 자신이 SSOT 인 척한 셈).
      sub(/^[A-Za-z_][A-Za-z0-9_]*;[ \t]*/, "", s)
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

# --- ⓒ DRYRUN 정지점(=아암) 수를 코드에서 유도 ------------------------------------
# 기동 '아암'의 권위 원천은 dryrun_emit 호출 수다 — 인자 표 한 행이 정확히 이 정지점 하나를 태운다.
# (기동 *줄* 수와는 다르다: preflight 는 7줄/1정지점, handoff 는 2줄/1정지점 — 둘 다 선언된 예외.)
emit_count() {   # $1 = 서브커맨드명 → dryrun_emit 호출 줄 수
  awk -v fn="$1" '
    $0 ~ ("^cmd_" fn "\\(\\) \\{") { inf = 1; next }
    inf && /^\}/ { inf = 0 }
    inf {
      s = $0; sub(/^[ \t]*/, "", s)
      if (s ~ /^#/) next
      if (s ~ /dryrun_emit[ \t]/) n++
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

# --- ⓒ2 계수는 1회만 유도해 재사용 (같은 값을 두 번 재느라 판정이 갈리는 일을 없앤다) ---
MAP="$ROOT/subcmd-map.tsv"; : > "$MAP"
for s in $SUBS; do printf '%s\t%s\t%s\n' "$s" "$(launch_count "$s")" "$(emit_count "$s")" >> "$MAP"; done
lc_of() { awk -F'\t' -v k="$1" '$1==k{print $2; f=1} END{if(!f) print -1}' "$MAP"; }
ec_of() { awk -F'\t' -v k="$1" '$1==k{print $3; f=1} END{if(!f) print -1}' "$MAP"; }

# --- ⓒ3 기동/비-기동 분할 **자체**를 단언 (슬롯 C2ⓐⓑ) ------------------------------
# launch_count 가 0 을 내면 아래 루프의 강한 단언(rc=0 · DRYRUN 1줄 · 총 1줄 · 델타 0)이 약한 단언
# (델타 0)으로 **조용히 강등**된다 — 탐지자의 실패 방향이 안전이 아니라 면제다. 값으로 못 박아 발화시킨다.
# 아래 기대값은 C23 슬롯 C 에서 캐리어를 직접 재측정한 값이다(전달받은 수치를 그대로 믿지 않았다).
# 캐리어를 바꿨으면 여기를 **의식적으로** 갱신하라 — 자동 추종은 이 단언을 무의미하게 만든다.
EXPECT_LC='preflight=7 run=1 task=1 spawn=1 wait=1 handoff=2 release=1 gate=3 gpt=2 selfcheck=0'
LCBAD=""
for kv in $EXPECT_LC; do
  k="${kv%%=*}"; v="${kv#*=}"; a=$(lc_of "$k")
  [ "$a" = "$v" ] || LCBAD="$LCBAD ${k}(기대${v}/실측${a})"
done
for s in $SUBS; do
  case " $EXPECT_LC " in *" ${s}="*) ;; *) LCBAD="$LCBAD ${s}(기대표에 없음)" ;; esac
done
if [ -z "$LCBAD" ]; then
  ok "아암별 기동 계수 고정: $EXPECT_LC"
else
  bad "기동 계수 드리프트 —$LCBAD (캐리어 변경이면 기대값을 의식적으로 갱신하라; 아니면 launch_count 오분류다)"
fi

NLA=$(awk -F'\t' '$2>0{n++} END{print n+0}' "$MAP")
NNO=$(awk -F'\t' '$2==0{n++} END{print n+0}' "$MAP")
NOLIST=$(awk -F'\t' '$2==0{printf "%s ", $1}' "$MAP")
if [ "$NLA" -eq 9 ] && [ "$NNO" -eq 1 ] && [ "$NOLIST" = "selfcheck " ]; then
  ok "분할 고정: 기동 9 · 비-기동 1(selfcheck) — 강한 단언의 면제 대상은 이 하나뿐이다"
else
  bad "분할 드리프트: 기동=$NLA 비-기동=$NNO(=${NOLIST:-없음}) — 기대 9/1(selfcheck). 비-기동 증가는 강한 단언의 조용한 면제다"
fi

# ★독립 2차 신호(C2ⓑ): 기동 판정은 철자 화이트리스트 4종에 의존해 새 기동 철자(python·node…)를 못 본다.
#   DRYRUN 정지점의 존재는 그와 **무관한** 신호다 — 두 신호가 어긋나면 화이트리스트 구멍을 의심하라.
XBAD=""
while IFS=$'\t' read -r s lc ec; do
  [ -n "$s" ] || continue
  if [ "$lc" -gt 0 ] && [ "$ec" -eq 0 ]; then XBAD="$XBAD ${s}(기동 ${lc}줄인데 DRYRUN 정지점 0)"; fi
  if [ "$lc" -eq 0 ] && [ "$ec" -gt 0 ]; then XBAD="$XBAD ${s}(비-기동인데 DRYRUN 정지점 ${ec} — 화이트리스트가 기동을 놓쳤을 수 있다)"; fi
done < "$MAP"
if [ -z "$XBAD" ]; then
  ok "기동 판정 ↔ DRYRUN 정지점 존재 2신호 정합(${SUBC}/${SUBC}) — 화이트리스트 밖 기동 철자의 교차 탐지"
else
  bad "2신호 불일치 —$XBAD"
fi

# --- ⓒ4 인자 표의 아암 행 수 ↔ 실제 DRYRUN 아암 수 (슬롯 C2ⓒ) ----------------------
# 표의 fail-closed 는 *새 서브커맨드*만 잡는다 — 기존 서브커맨드에 기동 아암이 하나 늘면(예: gate 에
# 4번째 서브액션) 표는 그대로고 새 아암은 한 번도 돌지 않는다(무발화). 행 수를 아암 수와 대조한다.
ROWBAD=""
for s in $SUBS; do
  if ! SETS=$(argsets_for "$s"); then ROWBAD="$ROWBAD ${s}(인자표 부재)"; continue; fi
  AROWS=$(printf '%s\n' "$SETS" | awk 'END{print NR+0}')
  AEC=$(ec_of "$s")
  if [ "$(lc_of "$s")" -gt 0 ]; then
    [ "$AROWS" -eq "$AEC" ] || ROWBAD="$ROWBAD ${s}(표 ${AROWS}행 ≠ DRYRUN 아암 ${AEC})"
  else
    { [ "$AROWS" -eq 1 ] && [ "$AEC" -eq 0 ]; } || ROWBAD="$ROWBAD ${s}(비-기동인데 표 ${AROWS}행/아암 ${AEC} — 기대 1행/0아암)"
  fi
done
if [ -z "$ROWBAD" ]; then
  ok "인자 표 행 수 ↔ DRYRUN 아암 수 일치(기동 9종 전건 + selfcheck 1행/0아암)"
else
  bad "인자 표 ↔ 아암 수 드리프트 —$ROWBAD (표에 없는 아암은 한 번도 검증되지 않는다)"
fi

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
    # 분할 판정은 위 ⓒ3 에서 이미 기대값에 못 박혔다 — 여기서는 그 값을 읽어 쓴다(재측정 금지).
    if [ "$(lc_of "$s")" -gt 0 ]; then
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

# --- ⓘ emit ↔ 실호출 토큰열 일치 (슬롯 C3 · §11.10 ②) ------------------------------
# 위 기동 아암 단언은 rc · DRYRUN 줄 수 · 총 줄 수 · rundir 델타 — 넷 다 **형태(shape)** 다. emit 된
# 토큰열이 실제 "$ORCA" 호출 argv 와 같은지는 한 번도 비교하지 않는다. 그런데 ② 의 핵심 불변식은
# 형태가 아니라 **내용**이다: 캐리어 :213/:543 이 경고하는 「선택 인자를 정지점 뒤에서 조립 → emit 이
# **부분집합 argv**」는 위 형태 단언 4개를 전부 통과한다. emit 은 라이브 도달 전 사람이 읽는 유일한
# 근거이므로 그 정확성에 상설 검사자를 둔다(도입 시점 현행은 전건 일치 — 위반이 아니라 판별력 공백이었다).
#
# 정규화(양쪽에 같은 규칙 — 한쪽만 다듬으면 비교가 무의미해진다):
#   · `local` · `x=$( … )` 캡처 껍질 · 리다이렉션/파이프/`|| …` 이후 · 트레일링 `;;` 절단
#   · 실호출 선두의 `"$ORCA"`/`orca_t` 토큰 제거 — emit 은 바이너리를 싣지 않는다(그 자리가 곧 캐리어가
#     부르는 그 바이너리). `codex`/`claude-ocx` 는 emit 이 바이너리째 싣으므로 남긴다.
#   · 큰따옴표 제거 + 공백 정규화 — `OCX_MODEL="$m"` 과 `"OCX_MODEL=$m"` 은 같은 argv 다.
# ★원리적 상한(침묵 축소 금지 — 명시한다):
#   ⑴ 이것은 **소스 대조**다. 런타임 확장 결과(`"${extra[@]}"` 가 실제로 무엇으로 펼쳐지는지)는 보지
#      않는다 — emit 과 실호출이 *같은 배열 이름*을 쓰는 한 확장 결과도 같다는 데 기댄다.
#   ⑵ 바이너리 토큰 자체의 교체($ORCA → 다른 실행자)는 이 검사자가 아니라 기동 판정(화이트리스트)의 몫이다.
#   ⑶ handoff 2/2 는 1번째 응답의 $handle 에 데이터 의존해 선-emit 이 **원리적으로 불가**하다 — 이
#      검사자는 1/2 만 덮는다. preflight 는 7-call 요약이라 비교할 토큰열이 아예 없다(아래 S 분기).
# 선언된 예외는 하드코딩 목록이 아니라 emit **자신의 자기-표시 문자열**로 판별한다(§11.10 ② 「묵시적
# 예외 금지」의 취지 — 목록을 박으면 새 예외가 그 목록에 슬쩍 얹혀 무발화한다):
#   emit 첫 토큰이 «공백 + 괄호 사유» 를 가진 큰따옴표 라벨이면 예외다. 라벨 뒤 argv 가 없으면 요약형,
#   있으면 n-of-m 형(라벨만 떼고 1번째 실호출과 그대로 비교한다).
emit_call_rows() {   # $1 = 서브커맨드명 → 'E|L|S|C <TAB> 정규화 토큰열' 을 문서 순서로
  awk -v fn="$1" '
    function norm(x) {
      gsub(/"/, "", x); gsub(/[ \t]+/, " ", x)
      sub(/^ +/, "", x); sub(/ +$/, "", x)
      return x
    }
    $0 ~ ("^cmd_" fn "\\(\\) \\{") { inf = 1; next }
    inf && /^\}/ { inf = 0 }
    !inf { next }
    {
      line = $0
      while (line ~ /\\[ \t]*$/) {          # 행-연속(\)은 한 논리 줄로 합친다
        sub(/\\[ \t]*$/, " ", line)
        if ((getline nxt) <= 0) break
        sub(/^[ \t]+/, "", nxt)
        line = line nxt
      }
      s = line; sub(/^[ \t]*/, "", s)
      if (s ~ /^#/) next
      if (match(s, /dryrun_emit[ \t]+/)) {
        rest = substr(s, RSTART + RLENGTH)
        sub(/[ \t]*;;[ \t]*$/, "", rest)
        if (match(rest, /^"[^"]*"/)) {
          lab = substr(rest, RSTART, RLENGTH)
          if (lab ~ / / && lab ~ /\(/) {    # 공백 + 괄호 사유 = 사람이 읽는 자기-표시 라벨
            tail = substr(rest, RSTART + RLENGTH); sub(/^[ \t]+/, "", tail)
            if (tail == "") { print "S\t" norm(lab); next }
            print "L\t" norm(tail); next
          }
        }
        print "E\t" norm(rest); next
      }
      sub(/^local[ \t]+/, "", s)
      sub(/^[A-Za-z_][A-Za-z0-9_]*;[ \t]*/, "", s)   # `local x; x=$(…)` — launch_count 와 동형 정규화
      sub(/^local[ \t]+/, "", s)
      cap = 0
      if (match(s, /^[A-Za-z_][A-Za-z0-9_]*=\$\(/)) { s = substr(s, RLENGTH + 1); cap = 1 }
      det = s                                # 기동 판정은 env 접두를 벗긴 사본으로(launch_count 와 동형)
      while (match(det, /^[A-Za-z_][A-Za-z0-9_]*=("[^"]*"|[^ \t]+)[ \t]+/)) det = substr(det, RLENGTH + 1)
      isl = 0
      if (det ~ /^"\$ORCA"[ \t]/) isl = 1
      else if (det ~ /^orca_t[ \t]/) isl = 1
      else if (det ~ /^codex[ \t]/) isl = 1
      else if (det ~ /claude-ocx"?[ \t]/ && det ~ /^"?\$HOME/) isl = 1
      if (!isl) next
      sub(/^"\$ORCA"[ \t]+/, "", s); sub(/^orca_t[ \t]+/, "", s)
      if (cap) sub(/\).*$/, "", s)
      sub(/[ \t]+[0-9]*[<>].*$/, "", s)
      sub(/[ \t]+(\||&&).*$/, "", s)
      sub(/[ \t]*;;[ \t]*$/, "", s)
      print "C\t" norm(s)
    }
  ' "$CARRIER"
}

for s in $SUBS; do
  [ "$(lc_of "$s")" -gt 0 ] || continue      # 비-기동은 emit 도 실호출도 없다(ⓒ3 2신호 단언이 담당)
  EM=(); CA=(); SUM=0; LBL=0
  while IFS=$'\t' read -r KIND TXT; do
    case "$KIND" in
      S) SUM=1 ;;
      L) LBL=1; EM+=("$TXT") ;;
      E) EM+=("$TXT") ;;
      C) CA+=("$TXT") ;;
    esac
  done < <(emit_call_rows "$s")
  NE=${#EM[@]}; NC=${#CA[@]}
  if [ "$SUM" -eq 1 ]; then
    if [ "$NE" -eq 0 ] && [ "$NC" -gt 0 ]; then
      ok "emit↔argv '$s': 선언된 예외(요약형 자기-표시) — 단일 argv 불성립이라 토큰열 비교가 원리적으로 불가(실호출 ${NC}건은 이 검사자 범위 밖)"
    else
      bad "emit↔argv '$s': 요약 라벨과 argv emit 이 공존한다(emit=${NE} 실호출=${NC}) — 자기-표시가 실제 emit 형태와 어긋난다"
    fi
    continue
  fi
  if [ "$NE" -eq 0 ]; then
    bad "emit↔argv '$s': 기동 서브커맨드인데 DRYRUN 정지점을 하나도 찾지 못했다(추출기 붕괴 또는 정지점 삭제)"
    continue
  fi
  MIS=""; i=0
  while [ "$i" -lt "$NE" ]; do
    if [ "$i" -ge "$NC" ]; then
      MIS="$MIS [#$((i+1)) 대응 실호출 없음: emit='${EM[$i]}']"
    elif [ "${EM[$i]}" != "${CA[$i]}" ]; then
      MIS="$MIS [#$((i+1)) emit='${EM[$i]}' ≠ call='${CA[$i]}']"
    fi
    i=$((i+1))
  done
  # 실호출이 emit 보다 많은데 자기-표시가 없으면 그것이 곧 「묵시적 예외」다(§11.10 ②).
  [ "$NC" -gt "$NE" ] && [ "$LBL" -eq 0 ] \
    && MIS="$MIS [실호출 ${NC} > emit ${NE} 인데 예외 자기-표시 없음 = 묵시적 예외]"
  if [ -n "$MIS" ]; then
    bad "emit↔argv '$s':$MIS"
  elif [ "$LBL" -eq 1 ]; then
    ok "emit↔argv '$s': ${NE}/${NC} 아암 토큰열 일치 + 선언된 n-of-m 예외(나머지 $((NC-NE))건은 응답 데이터 의존 — 선-emit 원리적 불가)"
  else
    ok "emit↔argv '$s': ${NE} 아암 전부 토큰열 일치(부분집합 argv 아님)"
  fi
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
