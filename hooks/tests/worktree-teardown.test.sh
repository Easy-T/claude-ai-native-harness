#!/usr/bin/env bash
# worktree-teardown.test.sh — 실측(measured) E2E. 격리 temp repo 에서 worktree-teardown.sh 를 구동.
# 절대 실제 프로젝트를 건드리지 않는다(모두 mktemp -d 하위). "verify=단위테스트 아닌 실측" 증거.
#   T1(①③) 정상종료 → 워크트리 삭제·정션 target(메인 모사) 무사·브랜치 삭제·가짜 dev서버 kill
#   T2(②)  cwd=메인 repo 루트 → no-op   T3(④) /,$HOME,빈,비-worktree 경로 → no-op
#   T5     reason=clear → no-op(세션 지속 보호)   T6 마커일치 비-worktree(메인 repo 해소) → no-op(메인 보호)
#   T4     idempotency: 삭제된 경로 재구동 → clean no-op
#   Tf/Tg/Th/Ti(cycle-76) 미커밋·미추적 정션·status 실패 → 보존(GUARD 6), clean 복귀 시 정상 삭제
#   Tj/Tk/Tl/Tm(C25) 수정-only·staged-only·assume-unchanged 숨은 수정·삭제 직전 경합(재검사) → 보존
set -u
HOOK="$HOME/.claude/hooks/worktree-teardown.sh"
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
mkjson(){ printf '{"session_id":"t","cwd":"%s","reason":"%s"}' "$1" "${2:-prompt_input_exit}"; }
run(){ printf '%s' "$1" | bash "$HOOK" >/dev/null 2>&1; }   # exit code 무시(항상 0); 부작용만 검증
winpath(){ if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1" | sed 's|/|\\|g'; fi; }

TMP=$(mktemp -d)
REPO="$TMP/repo"
WT="$REPO/.claude/worktrees/_test-teardown"
MAIN_NM="$TMP/main_nm"          # 정션 target = "메인 node_modules" 모사 (워크트리 밖)
MARK="TEARDOWN_TESTPROC_$$"

mkdir -p "$REPO"
( cd "$REPO" && git init -q && printf 'node_modules\n' > .gitignore && git add .gitignore \
  && git -c user.email=t@t -c user.name=t commit -q -m init )
mkdir -p "$REPO/.claude/worktrees"
mkdir -p "$MAIN_NM"; echo s1 >"$MAIN_NM/keep1.txt"; echo s2 >"$MAIN_NM/keep2.txt"; echo s3 >"$MAIN_NM/keep3.txt"
TARGET_BEFORE=$(ls -1 "$MAIN_NM" | wc -l | tr -d ' ')

make_worktree(){   # 링크 워크트리 + 중첩 정션 + 가짜 dev서버 재생성
  git -C "$REPO" worktree add -q -b worktree-cycle-_test "$WT" 2>/dev/null
  mkdir -p "$WT/app/frontend/src"; echo "own" >"$WT/app/frontend/src/own.txt"
  git -C "$WT" add app/frontend/src/own.txt && git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m own
  powershell -NoProfile -Command "New-Item -ItemType Junction -Path '$(winpath "$WT/app/frontend/node_modules")' -Target '$(winpath "$MAIN_NM")' | Out-Null" >/dev/null 2>&1
  # 가짜 dev서버: 워크트리 Windows 경로 + 고유 마커를 argv 에 → STEP A 가 매칭(name=node)·kill 대상. cwd 는 워크트리 밖(락 회피).
  ( cd "$TMP" && node -e "setTimeout(function(){},60000)" "$(winpath "$WT")__${MARK}" >/dev/null 2>&1 & )
  sleep 1
}
# node-only 필터: 측정용 powershell 자신의 CommandLine 에도 MARK 가 들어가므로(자기매칭) name 으로 배제.
proc_alive(){ powershell -NoProfile -Command "@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { \$_.Name -eq 'node.exe' -and \$_.CommandLine -and \$_.CommandLine.Contains('$MARK') }).Count" 2>/dev/null | tr -d '[:space:]'; }

echo "== T2: cwd=메인 repo 루트 → no-op =="
run "$(mkjson "$REPO")"
{ [ -d "$REPO/.git" ] && [ -d "$REPO/.claude/worktrees" ]; } && ok "repo intact (no-op)" || no "repo touched"

echo "== T3: 위험/비-worktree 경로 → no-op =="
for p in "/" "$HOME" "" "$REPO/app/frontend"; do
  run "$(mkjson "$p")"
done
{ [ -e "$HOME" ] && [ -d "$REPO" ]; } && ok "home/repo intact across guard-reject paths" || no "guard-reject path caused damage"

echo "== T6: 마커일치하나 비-worktree(메인 repo 로 해소) → no-op(메인 보호) =="
DECOY="$REPO/.claude/worktrees/notawt"   # mkdir 만 — git worktree 아님 → git-dir==git-common-dir(메인) → 거부
mkdir -p "$DECOY"; echo "decoy" >"$DECOY/data.txt"
run "$(mkjson "$DECOY")"
[ -f "$DECOY/data.txt" ] && ok "non-worktree marker dir protected (linked-worktree guard)" || no "GUARD3 FAILED — non-worktree deleted!"

echo "== T5: reason=clear → no-op(세션 지속 보호) =="
make_worktree
run "$(mkjson "$WT" "clear")"
{ [ -d "$WT" ] && [ -n "$(git -C "$REPO" branch --list worktree-cycle-_test)" ]; } && ok "worktree intact on reason=clear" || no "reason gate FAILED — worktree deleted on clear"

echo "== T1: 정상종료 → 워크트리 삭제·target 무사·브랜치 삭제·프로세스 kill =="
ALIVE_BEFORE=$(proc_alive)
run "$(mkjson "$WT" "prompt_input_exit")"
TARGET_AFTER=$(ls -1 "$MAIN_NM" 2>/dev/null | wc -l | tr -d ' ')
ALIVE_AFTER=$(proc_alive)
[ ! -e "$WT" ] && ok "worktree deleted" || no "worktree NOT deleted"
[ "$TARGET_AFTER" = "$TARGET_BEFORE" ] && ok "★ target(main) intact ($TARGET_AFTER/$TARGET_BEFORE files) — junction NOT followed" || no "★ DATA LOSS: target $TARGET_AFTER/$TARGET_BEFORE"
[ -z "$(git -C "$REPO" branch --list worktree-cycle-_test)" ] && ok "branch worktree-cycle-_test deleted" || no "branch not deleted"
{ [ "${ALIVE_BEFORE:-0}" -ge 1 ] && [ "${ALIVE_AFTER:-1}" = "0" ]; } && ok "fake dev-server killed ($ALIVE_BEFORE→$ALIVE_AFTER)" || no "process kill: before=$ALIVE_BEFORE after=$ALIVE_AFTER (best-effort)"

echo "== T4: idempotency — 삭제된 경로 재구동 → clean no-op =="
run "$(mkjson "$WT" "prompt_input_exit")"
[ ! -e "$WT" ] && ok "idempotent no-op (still absent, no error)" || no "idempotency broke"

echo "== Ta: cd-out 세션(메인루트 cwd) → 마커 fallback 으로 워크트리 정리(★핵심 회귀) =="
make_worktree
MK_DIR="$HOME/.claude/worktrees-marker"; mkdir -p "$MK_DIR"
MK_SID="wtjtest_a_$$"
printf '%s\n' "$WT" > "$MK_DIR/$MK_SID"     # PreToolUse(주)/SessionStart(보조) 가 기록했을 마커(=WT_ROOT)
printf '{"session_id":"%s","cwd":"%s","reason":"prompt_input_exit"}' "$MK_SID" "$REPO" | bash "$HOOK" >/dev/null 2>&1
TGT_A=$(ls -1 "$MAIN_NM" 2>/dev/null | wc -l | tr -d ' ')
[ ! -e "$WT" ] && ok "★ cd-out 워크트리 삭제됨(마커 fallback)" || no "★ cd-out 워크트리 미삭제 — 마커 fallback 실패"
[ "$TGT_A" = "$TARGET_BEFORE" ] && ok "cd-out: target(main) 무사 ($TGT_A/$TARGET_BEFORE)" || no "cd-out DATA LOSS: $TGT_A/$TARGET_BEFORE"
[ ! -f "$MK_DIR/$MK_SID" ] && ok "cd-out: 마커 소비됨(unlink)" || no "cd-out: 마커 미소비"
rm -f "$MK_DIR/$MK_SID" 2>/dev/null

echo "== Te: 빈 session_id → 마커 미사용/미소비(cwd-only) — 타세션 활성 워크트리 보호 =="
make_worktree
mkdir -p "$MK_DIR"
printf '%s\n' "$WT" > "$MK_DIR/unknown"      # 'unknown' 마커(동시세션 공유 위험 모사)
printf '{"session_id":"","cwd":"%s","reason":"prompt_input_exit"}' "$REPO" | bash "$HOOK" >/dev/null 2>&1
{ [ -d "$WT" ] && [ -f "$MK_DIR/unknown" ]; } && ok "빈 SID: 워크트리 보존 + 'unknown' 마커 미소비" || no "빈 SID 처리 위반(워크트리/마커 변경됨)"
rm -f "$MK_DIR/unknown" 2>/dev/null
printf '{"session_id":"wtjcleanup_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1  # 정리: 보존된 WT teardown

echo "== Tb: 실세션 모사 — PreToolUse(cwd=메인루트, file_path=워크트리)로 마커 생성 → SessionEnd teardown(E2E) =="
make_worktree
B_SID="wtjtest_b_$$"
# enforce-rpi-cycle 에 cwd=메인루트($REPO) + file_path=워크트리파일 → record_worktree_marker 가 마커 생성(실 신호 경로; 합성 worktree-cwd 아님)
printf '{"session_id":"%s","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$B_SID" "$REPO" "$WT/app/frontend/src/own.txt" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1
MK_B="$MK_DIR/$B_SID"
[ -f "$MK_B" ] && ok "Tb: PreToolUse 가 마커 생성(cwd=메인루트, 경로는 tool_input)" || no "Tb: PreToolUse 마커 미생성"
printf '{"session_id":"%s","cwd":"%s","reason":"prompt_input_exit"}' "$B_SID" "$REPO" | bash "$HOOK" >/dev/null 2>&1
TGT_B=$(ls -1 "$MAIN_NM" 2>/dev/null | wc -l | tr -d ' ')
[ ! -e "$WT" ] && ok "Tb: ★E2E 워크트리 정리됨(실 신호 경로)" || no "Tb: ★E2E 워크트리 미정리"
[ "$TGT_B" = "$TARGET_BEFORE" ] && ok "Tb: target(main) 무사 ($TGT_B/$TARGET_BEFORE)" || no "Tb: DATA LOSS $TGT_B/$TARGET_BEFORE"
[ ! -f "$MK_B" ] && ok "Tb: 마커 소비됨" || no "Tb: 마커 미소비"

echo "== Tc: 동시-동일 워크트리 — 다른 SID 마커 존재 시 teardown 보류(활성 워크트리 보호, C5) =="
make_worktree
mkdir -p "$MK_DIR"
OTHER_SID="wtjtest_other_$$"; OWN_SID="wtjtest_own_$$"
printf '%s\n' "$WT" > "$MK_DIR/$OTHER_SID"   # 동시(타) 세션 마커
printf '%s\n' "$WT" > "$MK_DIR/$OWN_SID"      # 본 세션 마커
printf '{"session_id":"%s","cwd":"%s","reason":"prompt_input_exit"}' "$OWN_SID" "$REPO" | bash "$HOOK" >/dev/null 2>&1
[ -d "$WT" ] && ok "Tc: 워크트리 보존(concurrent-owner 감지)" || no "Tc: 워크트리 삭제됨 — 활성 세션 파괴 위험"
[ -f "$MK_DIR/$OTHER_SID" ] && ok "Tc: 타 세션 마커 보존" || no "Tc: 타 세션 마커 삭제"
[ ! -f "$MK_DIR/$OWN_SID" ] && ok "Tc: 본 세션 마커 소비" || no "Tc: 본 세션 마커 미소비"
rm -f "$MK_DIR/$OTHER_SID" 2>/dev/null
printf '{"session_id":"wtjtest_cleanup2_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1  # 정리: 단독이 됐으니 teardown

RL="$TMP/runlog"; mkdir -p "$RL"   # 이 블록의 hook 사유 로그(격리 — 실 runlog 오염 없음)
echo "== Tf: 미커밋 작업(추적 수정 + 미추적 파일) → 보존 — 식별 무관 불변식(§12, 2026-09-28 사고 재현: reason=other·cwd=워크트리·마커 없음) =="
make_worktree
echo "edit" >> "$WT/app/frontend/src/own.txt"; echo "new" > "$WT/app/frontend/src/new.txt"
printf '{"session_id":"wtjtest_f_%s","cwd":"%s","reason":"other"}' "$$" "$WT" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
{ [ -f "$WT/app/frontend/src/new.txt" ] && grep -q edit "$WT/app/frontend/src/own.txt"; } && ok "Tf: dirty 워크트리 보존(수정+미추적 유지)" || no "Tf: ★DATA LOSS — dirty 워크트리 삭제됨"
[ -n "$(git -C "$REPO" branch --list worktree-cycle-_test)" ] && ok "Tf: 브랜치 보존" || no "Tf: 브랜치 삭제됨"
grep -q 'noop:dirty-worktree' "$RL"/*.jsonl 2>/dev/null && ok "Tf: 사유 noop:dirty-worktree 기록" || no "Tf: dirty 사유 미기록"

echo "== Tg: 같은 dirty 워크트리를 자기 마커(§9 fallback)로 도달 → 역시 보존, 마커 소비; clean 복귀 후 정상 삭제 =="
G_SID="wtjtest_g_$$"; mkdir -p "$MK_DIR"; printf '%s\n' "$WT" > "$MK_DIR/$G_SID"
printf '{"session_id":"%s","cwd":"%s","reason":"prompt_input_exit"}' "$G_SID" "$REPO" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
[ -f "$WT/app/frontend/src/new.txt" ] && ok "Tg: 마커 경로로도 dirty 보존" || no "Tg: ★DATA LOSS — 마커 경로에서 삭제됨"
[ ! -f "$MK_DIR/$G_SID" ] && ok "Tg: 마커 소비" || no "Tg: 마커 미소비"
git -C "$WT" checkout -q -- . ; rm -f "$WT/app/frontend/src/new.txt"
printf '{"session_id":"wtjcleanup_g_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
[ ! -e "$WT" ] && ok "Tg: clean 복귀 후 정상 삭제(clean 경로 무회귀)" || no "Tg: clean 인데 미삭제"

echo "== Th: ignore 되지 않은 정션(미추적)만 있는 워크트리 → 보존 + 정션 target 무사 =="
make_worktree
powershell -NoProfile -Command "New-Item -ItemType Junction -Path '$(winpath "$WT/app/frontend/vendorlink")' -Target '$(winpath "$MAIN_NM")' | Out-Null" >/dev/null 2>&1
printf '{"session_id":"wtjtest_h_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
[ -d "$WT/app/frontend/vendorlink" ] && ok "Th: 미추적 정션 워크트리 보존" || no "Th: 미추적 정션 워크트리 삭제됨"
[ "$(ls -1 "$MAIN_NM" 2>/dev/null | wc -l | tr -d ' ')" = "$TARGET_BEFORE" ] && ok "Th: 정션 target(main) 무사" || no "Th: ★DATA LOSS — 정션 target 손상"
powershell -NoProfile -Command "[IO.Directory]::Delete('$(winpath "$WT/app/frontend/vendorlink")', \$false)" >/dev/null 2>&1   # 링크-only 제거 → clean
printf '{"session_id":"wtjcleanup_h_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1

echo "== Ti: git status 실패(손상 index) → 보존 + noop:status-failed (fail-safe) =="
make_worktree
IDX="$(git -C "$WT" rev-parse --absolute-git-dir)/index"; printf 'corrupt' > "$IDX"
printf '{"session_id":"wtjtest_i_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
[ -d "$WT" ] && ok "Ti: status 실패 워크트리 보존" || no "Ti: status 실패인데 삭제됨"
grep -q 'noop:status-failed' "$RL"/*.jsonl 2>/dev/null && ok "Ti: 사유 noop:status-failed 기록" || no "Ti: status-failed 사유 미기록"
rm -f "$IDX"; git -C "$WT" reset -q 2>/dev/null   # index 재생성 → clean
printf '{"session_id":"wtjcleanup_i_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1

# Tj~Tm(C25): 블록별 격리 로그 — Tf~Ti 가 남긴 사유가 공유 로그에서 vacuous 통과시키지 않도록.
echo "== Tj: 추적 파일 수정만(미추적 없음) → 보존 + noop:dirty-worktree =="
make_worktree
RLJ="$TMP/runlog-j"
echo "editj" >> "$WT/app/frontend/src/own.txt"
printf '{"session_id":"wtjtest_j_%s","cwd":"%s","reason":"other"}' "$$" "$WT" | RUNLOG_DIR="$RLJ" bash "$HOOK" >/dev/null 2>&1
[ -d "$WT" ] && ok "Tj: 수정-only 워크트리 보존" || no "Tj: ★DATA LOSS — 수정-only 워크트리 삭제됨"
grep -q editj "$WT/app/frontend/src/own.txt" 2>/dev/null && ok "Tj: 수정 내용 무사" || no "Tj: 수정 내용 소실"
grep -q 'noop:dirty-worktree' "$RLJ"/*.jsonl 2>/dev/null && ok "Tj: 사유 noop:dirty-worktree 기록" || no "Tj: dirty 사유 미기록"
git -C "$WT" checkout -q -- . 2>/dev/null   # clean 복귀 → 정리
printf '{"session_id":"wtjcleanup_j_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1

echo "== Tk: staged 만(새 파일 git add, 워킹트리 추가 변경 없음) → 보존 + noop:dirty-worktree =="
make_worktree
RLK="$TMP/runlog-k"
echo "stagedk" > "$WT/app/frontend/src/staged.txt"; git -C "$WT" add app/frontend/src/staged.txt 2>/dev/null
printf '{"session_id":"wtjtest_k_%s","cwd":"%s","reason":"other"}' "$$" "$WT" | RUNLOG_DIR="$RLK" bash "$HOOK" >/dev/null 2>&1
[ -d "$WT" ] && ok "Tk: staged-only 워크트리 보존" || no "Tk: ★DATA LOSS — staged-only 워크트리 삭제됨"
grep -q stagedk "$WT/app/frontend/src/staged.txt" 2>/dev/null && ok "Tk: staged 파일 무사" || no "Tk: staged 파일 소실"
grep -q 'noop:dirty-worktree' "$RLK"/*.jsonl 2>/dev/null && ok "Tk: 사유 noop:dirty-worktree 기록" || no "Tk: dirty 사유 미기록"
git -C "$WT" reset -q 2>/dev/null; rm -f "$WT/app/frontend/src/staged.txt"   # clean 복귀 → 정리
printf '{"session_id":"wtjcleanup_k_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1

echo "== Tl: assume-unchanged 추적 파일 수정(git status 에 안 보임) → 보존 + noop:hidden-index-flags =="
make_worktree
RLL="$TMP/runlog-l"
git -C "$WT" update-index --assume-unchanged app/frontend/src/own.txt 2>/dev/null; echo "hiddenl" >> "$WT/app/frontend/src/own.txt"
printf '{"session_id":"wtjtest_l_%s","cwd":"%s","reason":"other"}' "$$" "$WT" | RUNLOG_DIR="$RLL" bash "$HOOK" >/dev/null 2>&1
[ -d "$WT" ] && ok "Tl: 숨은 수정 워크트리 보존" || no "Tl: ★DATA LOSS — assume-unchanged 수정 워크트리 삭제됨"
grep -q hiddenl "$WT/app/frontend/src/own.txt" 2>/dev/null && ok "Tl: 숨은 수정 내용 무사" || no "Tl: 숨은 수정 내용 소실"
grep -q 'noop:hidden-index-flags' "$RLL"/*.jsonl 2>/dev/null && ok "Tl: 사유 noop:hidden-index-flags 기록" || no "Tl: hidden-index-flags 사유 미기록"
git -C "$WT" update-index --no-assume-unchanged app/frontend/src/own.txt 2>/dev/null; git -C "$WT" checkout -q -- . 2>/dev/null   # clean 복귀 → 정리
printf '{"session_id":"wtjcleanup_l_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1

echo "== Tm: 삭제 직전 경합 — GUARD 6 통과 뒤(STEP A) 새 파일 생성 → 재검사로 rm 생략 + noop:dirty-recheck =="
make_worktree
RLM="$TMP/runlog-m"; SHIM="$TMP/psshim"; mkdir -p "$SHIM"
REAL_PS=$(command -v powershell)   # 셤 설치 *전* 실제 경로 해석(MSYS 형태 — bash→bash→exe 로 hook 직접 호출과 같은 1회 변환)
cat > "$SHIM/powershell" <<EOF
#!/usr/bin/env bash
# Tm 가짜 powershell: 첫 호출(STEP A) 때 워크트리에 미추적 파일 생성(부모 세션 쓰기 모사) → 실제 powershell 에 인자 그대로 전달
if [ ! -f "$SHIM/.fired" ]; then : > "$SHIM/.fired"; echo racem > "$WT/app/frontend/src/race.txt"; fi
exec "$REAL_PS" "\$@"
EOF
chmod +x "$SHIM/powershell"
printf '{"session_id":"wtjtest_m_%s","cwd":"%s","reason":"other"}' "$$" "$WT" | PATH="$SHIM:$PATH" RUNLOG_DIR="$RLM" bash "$HOOK" >/dev/null 2>&1
[ -d "$WT" ] && ok "Tm: 경합 워크트리 보존" || no "Tm: ★DATA LOSS — 경합 중 워크트리 삭제됨"
grep -q racem "$WT/app/frontend/src/race.txt" 2>/dev/null && ok "Tm: 경합 중 생성된 새 파일 무사" || no "Tm: 경합 중 생성된 새 파일 소실(또는 셤 미발화)"
grep -q 'noop:dirty-recheck' "$RLM"/*.jsonl 2>/dev/null && ok "Tm: 사유 noop:dirty-recheck 기록" || no "Tm: dirty-recheck 사유 미기록"
rm -f "$WT/app/frontend/src/race.txt"   # clean 복귀 → 정리(셤 없이)
printf '{"session_id":"wtjcleanup_m_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1

echo "== Td: self-healing sweep (SessionStart 배선) — dir-제거 등록/고아 worktree-* 청소, 활성/비-컨벤션 보호 =="
git -C "$REPO" worktree add -q -b worktree-cycle-swA "$REPO/.claude/worktrees/swA" 2>/dev/null; rm -rf "$REPO/.claude/worktrees/swA"   # dir 제거 → prunable+고아
git -C "$REPO" worktree add -q -b worktree-cycle-swB "$REPO/.claude/worktrees/swB" 2>/dev/null                                         # 활성 → 보호
git -C "$REPO" worktree add -q -b worktree-cycle-swC "$REPO/.claude/worktrees/swC" 2>/dev/null; git -C "$REPO" worktree remove "$REPO/.claude/worktrees/swC" 2>/dev/null   # 고아 브랜치
FEAT="feature-keepme-$$"; git -C "$REPO" branch "$FEAT" 2>/dev/null
printf '{"session_id":"sw_%s","cwd":"%s"}' "$$" "$REPO" | bash "$HOME/.claude/hooks/session-start-audit.sh" >/dev/null 2>&1
[ "$(git -C "$REPO" worktree list --porcelain 2>/dev/null | grep -c prunable)" = "0" ] && ok "Td: prunable 등록 0(prune)" || no "Td: prunable 잔존"
[ -z "$(git -C "$REPO" branch --list worktree-cycle-swA)" ] && ok "Td: dir-제거 고아 브랜치 swA 삭제" || no "Td: swA 미삭제"
[ -z "$(git -C "$REPO" branch --list worktree-cycle-swC)" ] && ok "Td: 고아 브랜치 swC 삭제" || no "Td: swC 미삭제"
{ [ -d "$REPO/.claude/worktrees/swB" ] && [ -n "$(git -C "$REPO" branch --list worktree-cycle-swB)" ]; } && ok "Td: 활성 워크트리 swB+브랜치 보호" || no "Td: 활성 swB 손상"
[ -n "$(git -C "$REPO" branch --list "$FEAT")" ] && ok "Td: 비-컨벤션 브랜치 보호" || no "Td: feature 브랜치 손상"
git -C "$REPO" worktree remove "$REPO/.claude/worktrees/swB" 2>/dev/null; git -C "$REPO" branch -D worktree-cycle-swB "$FEAT" 2>/dev/null   # 정리

# cleanup: 마커 프로세스 잔존 시 강제 종료 + temp 전체 삭제(모두 TMP 하위라 정션이 있어도 외부 무영향)
rm -f "$HOME/.claude/worktrees-marker/wtjtest_"* "$HOME/.claude/worktrees-marker/wtjcleanup_"* 2>/dev/null
powershell -NoProfile -Command "Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { \$_.CommandLine -and \$_.CommandLine.Contains('$MARK') } | ForEach-Object { try { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }" >/dev/null 2>&1
git -C "$REPO" worktree prune 2>/dev/null
rm -rf "$TMP" 2>/dev/null

echo "-------------------------------------------"
echo "worktree-teardown.test: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
