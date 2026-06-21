#!/usr/bin/env bash
# worktree-teardown.test.sh — 실측(measured) E2E. 격리 temp repo 에서 worktree-teardown.sh 를 구동.
# 절대 실제 프로젝트를 건드리지 않는다(모두 mktemp -d 하위). "verify=단위테스트 아닌 실측" 증거.
#   T1(①③) 정상종료 → 워크트리 삭제·정션 target(메인 모사) 무사·브랜치 삭제·가짜 dev서버 kill
#   T2(②)  cwd=메인 repo 루트 → no-op   T3(④) /,$HOME,빈,비-worktree 경로 → no-op
#   T5     reason=clear → no-op(세션 지속 보호)   T6 마커일치 비-worktree(메인 repo 해소) → no-op(메인 보호)
#   T4     idempotency: 삭제된 경로 재구동 → clean no-op
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
( cd "$REPO" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
mkdir -p "$REPO/.claude/worktrees"
mkdir -p "$MAIN_NM"; echo s1 >"$MAIN_NM/keep1.txt"; echo s2 >"$MAIN_NM/keep2.txt"; echo s3 >"$MAIN_NM/keep3.txt"
TARGET_BEFORE=$(ls -1 "$MAIN_NM" | wc -l | tr -d ' ')

make_worktree(){   # 링크 워크트리 + 중첩 정션 + 가짜 dev서버 재생성
  git -C "$REPO" worktree add -q -b worktree-cycle-_test "$WT" 2>/dev/null
  mkdir -p "$WT/app/frontend/src"; echo "own" >"$WT/app/frontend/src/own.txt"
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
printf '%s\n' "$WT" > "$MK_DIR/$MK_SID"     # SessionStart 가 기록했을 마커(=WT_ROOT)
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

# cleanup: 마커 프로세스 잔존 시 강제 종료 + temp 전체 삭제(모두 TMP 하위라 정션이 있어도 외부 무영향)
rm -f "$HOME/.claude/worktrees-marker/wtjtest_"* "$HOME/.claude/worktrees-marker/wtjcleanup_"* 2>/dev/null
powershell -NoProfile -Command "Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { \$_.CommandLine -and \$_.CommandLine.Contains('$MARK') } | ForEach-Object { try { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }" >/dev/null 2>&1
git -C "$REPO" worktree prune 2>/dev/null
rm -rf "$TMP" 2>/dev/null

echo "-------------------------------------------"
echo "worktree-teardown.test: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
