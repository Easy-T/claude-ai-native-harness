# fail-open 런타임 표면화 Implementation Plan (cycle-32, rank6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 32
**Started:** 2026-06-13

**Goal:** 차단 hook이 자기-고장(lib 파서 크래시) 시 침묵 허용(fail-open)하던 경로를 *런타임 표면화*한다 — ① enforce-rpi-bash.sh가 redirect-targets.js 크래시를 종료코드로 감지해 `hook_log FAILOPEN` + stderr로 표면화(fail-open은 유지), ② session-start-audit.sh가 차기 세션 시작 시 lib/\*.js 런타임 스모크로 손상 파서를 ALERT. `setup/tests/failopen-surface.test.sh`가 RED→GREEN으로 증명, verify-all STAGE 2c 배선.

**Architecture:** spec `audit-reverification.md` §4 rank6의 명시 fix를 구현. fail-open은 의도된 트레이드오프라 *차단으로 확대하지 않고 표면화만*(CONTEXT.md "fail-open" 표준). 테스트는 cycle-31 seal-regression / cycle-18 격리 청사진 재사용 — 임시 `$HOME` 복제본에 크래시 스텁 주입, 라이브 파서/로그 비변형(cksum witness). ③(orchestrator/secret-scan FAILOPEN 로그)은 defer — 근거 §Task 6.

**Tech Stack:** bash(`set -uo pipefail`) + node(lib 파서) + Git Bash/win32. hook_log(_common.sh) 5-필드 누적.

---

## File Structure

- **Create** `setup/tests/failopen-surface.test.sh` — 격리 복제본에 파서 크래시 스텁 주입 → ①②의 FAILOPEN/ALERT 표면화를 E2E 단언(1 control + 1 crash per channel + immutability = 5 ok). acceptance-tier, cases.tsv 미포함.
- **Modify** `hooks/enforce-rpi-bash.sh:32` — `node ... 2>/dev/null || true` → 종료코드 분기 if/else.
- **Modify** `hooks/session-start-audit.sh` (line 34 `fi` 뒤) — lib/\*.js 런타임 스모크 블록 삽입.
- **Modify** `setup/verify-all.sh` (line 14 뒤) — STAGE 2c 배선.

---

### Task 1: 메타테스트 작성 (failopen-surface.test.sh)

**Files:**
- Create: `setup/tests/failopen-surface.test.sh`

- [x] **Step 1: 테스트 파일 작성** (전체 내용 — 플레이스홀더 없음)

```bash
#!/usr/bin/env bash
# Meta-test (cycle-32, rank6/G6-a·G3-b): 차단 hook이 lib 파서 크래시 시 fail-open 하더라도
# '침묵'이 아니라 '표면화'됨을 증명. 두 채널:
#   ① enforce-rpi-bash.sh — redirect-targets.js 크래시 → hook_log FAILOPEN + stderr, fail-open 유지(exit 0).
#   ② session-start-audit.sh — lib/*.js 런타임 스모크 → 손상 파서 → hook_log ALERT + stderr.
# Acceptance-tier (seal-regression.test.sh / verify-integration.sh 동급), verify-all STAGE 2c 로 배선 —
# hooks/tests/cases.tsv 단위케이스 아님(파서는 정상 CMD로 throw 안 함 G1-c; run-all 129 불변).
#
# 격리(cycle-18/#25/cycle-31 청사진): 라이브 ~/.claude hooks 서브셋을 임시 $HOME 으로 복제하고
# 복제본 파서에만 크래시 스텁을 주입, 복제본 hook 을 HOME=<복제본> 으로 실행한다.
# 라이브 파서/로그는 절대 쓰지 않음 — 종료 시 cksum witness 로 증명.
set -uo pipefail
SRC="$HOME/.claude"
PASS=0; FAIL=0
ok()  { echo "✓ $1"; PASS=$((PASS+1)); }
bad() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# --- live immutability witnesses: 버그난 테스트가 건드릴 수 있는 파서+편집 hook 의 cksum ---
witness() { local f; for f in hooks/lib/redirect-targets.js hooks/lib/skeleton-scan.js \
                                hooks/lib/transcript-usage.js hooks/lib/model-window.js \
                                hooks/enforce-rpi-bash.sh hooks/session-start-audit.sh; do
              cksum "$SRC/$f" 2>/dev/null; done; }
LIVE_BEFORE="$(witness)"

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

# --- helpers ---
make_replica() {  # $1 = replica home root
  local C="$1/.claude"
  mkdir -p "$C"
  cp -p "$SRC/CLAUDE.md" "$C/CLAUDE.md" 2>/dev/null || true   # session-start-audit 가 읽음
  [ -d "$SRC/hooks" ] && cp -a "$SRC/hooks" "$C/hooks"
  rm -rf "$C/hooks/.log"                                       # 새 로그 라인 단언 위해 clean 시작
  chmod +x "$C/hooks/"*.sh 2>/dev/null || true                # win32 cp -a +x 손실 방어
}
mk_bash_event() {  # $1=cmd $2=cwd
  CMD="$1" CWD="$2" node -e 'process.stdout.write(JSON.stringify({tool_name:"Bash",tool_input:{command:process.env.CMD},cwd:process.env.CWD}))'
}
mk_ssa_event() {   # $1=cwd
  CWD="$1" node -e 'process.stdout.write(JSON.stringify({session_id:"s",cwd:process.env.CWD}))'
}
replica_log() { cat "$1/.claude/hooks/.log/"*.log 2>/dev/null; }
CRASH_STUB='process.exit(1);'   # 비정상 종료 + 빈 stdout = 손상/throw 파서 시뮬

# === ① enforce-rpi-bash : redirect-targets.js 크래시 → fail-open 유지(exit 0) + FAILOPEN 로깅 ===
# ①control: HEALTHY 복제본은 무-plan 코드쓰기를 여전히 BLOCK(exit 2) — 새 분기가 정상 차단을 안 깬다.
H="$ROOT/erb_ok"; mkdir -p "$H"; make_replica "$H"
rc=0
mk_bash_event 'echo x > evil.py' "$H/.claude" | HOME="$H" bash "$H/.claude/hooks/enforce-rpi-bash.sh" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
  ok "①control: healthy parser still BLOCKs code-write w/o plan (exit 2)"
else
  bad "①control: expected exit 2 (block), got $rc — 새 분기가 정상 차단을 깸"
fi

# ①crash: 크래시 스텁 → 여전히 fail-open(exit 0, 차단 아님) AND FAILOPEN 로깅.
H="$ROOT/erb_crash"; mkdir -p "$H"; make_replica "$H"
printf '%s' "$CRASH_STUB" > "$H/.claude/hooks/lib/redirect-targets.js"
rc=0
mk_bash_event 'echo x > evil.py' "$H/.claude" | HOME="$H" bash "$H/.claude/hooks/enforce-rpi-bash.sh" >/dev/null 2>&1 || rc=$?
LOG="$(replica_log "$H")"
if [ "$rc" -eq 0 ] && printf '%s' "$LOG" | grep -qF 'FAILOPEN'; then
  ok "①crash: 파서 크래시 → fail-open 유지(exit 0) + FAILOPEN 로깅"
else
  bad "①crash: rc=$rc(want 0), FAILOPEN in log? log=[$(printf '%s' "$LOG" | tr '\n' '|')]"
fi

# === ② session-start-audit : lib/*.js 런타임 스모크 → 손상 파서 ALERT ===
# ②control: HEALTHY 복제본은 lib-runtime ALERT 를 false-fire 하지 않는다.
H="$ROOT/ssa_ok"; mkdir -p "$H"; make_replica "$H"
err="$(mk_ssa_event "$H" | HOME="$H" bash "$H/.claude/hooks/session-start-audit.sh" 2>&1 >/dev/null)"
if printf '%s' "$err" | grep -qF 'lib 파서 런타임 고장'; then
  bad "②control: healthy 복제본이 lib runtime ALERT 를 false-fire"
else
  ok "②control: healthy 복제본 → lib runtime ALERT 없음(no false-fire)"
fi

# ②crash: lib/*.js 1개 손상 → selfcheck ALERT (stderr 특정 문자열 + log lib-selfcheck).
H="$ROOT/ssa_crash"; mkdir -p "$H"; make_replica "$H"
printf '%s' "$CRASH_STUB" > "$H/.claude/hooks/lib/skeleton-scan.js"
err="$(mk_ssa_event "$H" | HOME="$H" bash "$H/.claude/hooks/session-start-audit.sh" 2>&1 >/dev/null)"
LOG="$(replica_log "$H")"
if printf '%s' "$err" | grep -qF 'lib 파서 런타임 고장' && printf '%s' "$LOG" | grep -qF 'lib-selfcheck'; then
  ok "②crash: 손상 skeleton-scan.js → selfcheck ALERT (stderr + log)"
else
  bad "②crash: lib-runtime ALERT 누락. err=[$(printf '%s' "$err" | tr '\n' '|')] log=[$(printf '%s' "$LOG" | tr '\n' '|')]"
fi

# === live immutability: witness 파일 byte-동일(모든 변이는 복제본 내부) ===
LIVE_AFTER="$(witness)"
if [ "$LIVE_BEFORE" = "$LIVE_AFTER" ]; then
  ok "live ~/.claude 파서+hook 비변형 (witness cksum 안정)"
else
  bad "live ~/.claude 변형됨 — 격리 breach"
fi

echo
echo "failopen-surface: PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

- [x] **Step 2: 실행권한 부여**

Run: `chmod +x "$HOME/.claude/setup/tests/failopen-surface.test.sh"`
Expected: (무출력)

---

### Task 2: RED 측정 (현 코드 침묵 통과 실증)

- [x] **Step 1: 미수정 코드에서 테스트 실행**

Run: `bash "$HOME/.claude/setup/tests/failopen-surface.test.sh"; echo "EXIT=$?"`
Expected: `failopen-surface: PASS=3 FAIL=2` / `EXIT=2`
- ①control PASS(정상 차단 불변), ②control PASS(false-fire 없음), immutability PASS.
- **①crash FAIL** (현 `|| true`가 크래시→빈 TARGET→exit 0 침묵, FAILOPEN 미로깅) + **②crash FAIL** (lib 스모크 미존재).
- 이 2 FAIL이 "현 코드가 침묵 통과"의 실증 = RED.

---

### Task 3: ① enforce-rpi-bash.sh 종료코드 분기

**Files:**
- Modify: `hooks/enforce-rpi-bash.sh:32`

- [x] **Step 1: TARGET 라인을 if/else 분기로 교체**

old (line 30-32):
```bash
# 코드 파일을 셸로 작성하는 패턴 탐지. 파서는 hooks/lib/redirect-targets.js (단위테스트 가능).
# 코드 확장자 집합은 _common.sh 의 SSOT (code_ext_regex).
TARGET=$(CMD="$CMD" CODE_EXT_REGEX="$(code_ext_regex)" node "$HOME/.claude/hooks/lib/redirect-targets.js" 2>/dev/null || true)
```

new:
```bash
# 코드 파일을 셸로 작성하는 패턴 탐지. 파서는 hooks/lib/redirect-targets.js (단위테스트 가능).
# 코드 확장자 집합은 _common.sh 의 SSOT (code_ext_regex).
# fail-open 런타임 표면화 (cycle-32 rank6/G6-a): 종료코드로 '크래시(비정상 종료)'와
# '빈 출력(코드작성 의도 없음)'을 구분한다. 파서가 크래시하면 fail-open 은 유지(차단 아님 —
# 의도된 트레이드오프)하되 무표면 금지(CONTEXT.md "fail-open")라 hook_log FAILOPEN + stderr 1줄로 표면화.
# (enforce-orchestrator ERR-센티넬은 무로깅이라 단순 이식 아님 — 로깅 '추가'가 핵심.)
if TARGET=$(CMD="$CMD" CODE_EXT_REGEX="$(code_ext_regex)" node "$HOME/.claude/hooks/lib/redirect-targets.js" 2>/dev/null); then
  :   # 정상 종료(0): TARGET = 첫 코드-쓰기 대상 또는 빈 문자열
else
  hook_log "enforce-rpi-bash" "redirect-targets.js" "FAILOPEN" "parser-exit-$?"
  echo "[rpi-bash] ⚠ redirect 파서 런타임 고장 → fail-open 통과(이 명령에 게이트 비작동). bash ~/.claude/setup/doctor.sh 로 점검" >&2
  exit 0
fi
```

- [x] **Step 2: 구문 검증**

Run: `bash -n "$HOME/.claude/hooks/enforce-rpi-bash.sh" && echo OK`
Expected: `OK`

---

### Task 4: ② session-start-audit.sh lib 런타임 스모크

**Files:**
- Modify: `hooks/session-start-audit.sh` (line 34 `fi` 뒤)

- [x] **Step 1: 기존 selfcheck 블록 뒤에 lib 스모크 블록 삽입**

old (line 31-34):
```bash
if [ -n "$SELFCHECK_BAD" ]; then
  hook_log "session-start-audit" "hook-selfcheck" "ALERT" "$SELFCHECK_BAD"
  echo "[hook-selfcheck] ⚠ 차단 hook fail-open 위험:$SELFCHECK_BAD — bash ~/.claude/setup/doctor.sh 로 점검" >&2
fi
```

new:
```bash
if [ -n "$SELFCHECK_BAD" ]; then
  hook_log "session-start-audit" "hook-selfcheck" "ALERT" "$SELFCHECK_BAD"
  echo "[hook-selfcheck] ⚠ 차단 hook fail-open 위험:$SELFCHECK_BAD — bash ~/.claude/setup/doctor.sh 로 점검" >&2
fi

# --- D-FAILOPEN-SURFACE ②: lib/*.js 런타임 스모크 (cycle-32 rank6/G6-a) ---
# bash -n 은 .sh 구문만 잡는다 — .js 런타임 손상(throw/syntax)은 못 잡는다. 각 파서를 무해 입력
# (</dev/null + 무-env/argv)으로 1회 실행: 건강한 파서는 graceful exit 0, 손상 파서만 비정상 종료한다.
# 손상 파서는 차단 hook 의 게이트를 조용히 무력화하므로 차기 세션 시작에 ALERT 로 표면화(fail-open 유지).
if command -v node >/dev/null 2>&1; then
  JS_BAD=""
  for jf in "$HOME/.claude/hooks/lib/"*.js; do
    [ -e "$jf" ] || continue
    node "$jf" </dev/null >/dev/null 2>&1 || JS_BAD="$JS_BAD $(basename "$jf")"
  done
  if [ -n "$JS_BAD" ]; then
    hook_log "session-start-audit" "lib-selfcheck" "ALERT" "jsruntime:$JS_BAD"
    echo "[hook-selfcheck] ⚠ lib 파서 런타임 고장:$JS_BAD — bash ~/.claude/setup/doctor.sh 로 점검" >&2
  fi
fi
```

- [x] **Step 2: 구문 검증**

Run: `bash -n "$HOME/.claude/hooks/session-start-audit.sh" && echo OK`
Expected: `OK`

---

### Task 5: GREEN 측정

- [x] **Step 1: 수정 후 테스트 실행**

Run: `bash "$HOME/.claude/setup/tests/failopen-surface.test.sh"; echo "EXIT=$?"`
Expected: `failopen-surface: PASS=5 FAIL=0` / `EXIT=0`
- ①crash·②crash 가 GREEN 으로 전환 = FAILOPEN/ALERT 표면화 구현됨.

---

### Task 6: verify-all STAGE 2c 배선 + ③ defer 결정

**Files:**
- Modify: `setup/verify-all.sh` (line 14 뒤)

> **③(orchestrator ERR-센티넬 / secret-scan FAILOPEN 로그) defer 결정 (Gate R PASS 검증됨):**
> (a) enforce-orchestrator.sh:17 ERR-센티넬은 skeleton-scan 이 *graceful 파싱실패*로 "ERR"+exit 0 한 경우만 잡음 — 파서가 *크래시*하면 SKEL 이 빈 문자열이 되어 no-marker PASS 로 통과하므로 ERR 줄에 로그만 추가해도 크래시 클래스를 못 잡음(①식 종료코드 재구조 필요=범위 확대).
> (b) 그 크래시 클래스(skeleton-scan.js 손상)는 ②가 이미 선제 표면화.
> (c) enforce-secret-scan 은 인라인 self-swallow node(`catch(e){process.exit(0)}`)라 깨끗한 종료코드 분기점 없음.
> (d) G6-b 는 §1에서 non-deficiency, rank6 gapIds(G3-b·G6-a·failopen-trustbase) 미포함.
> → §4 rank6 에 기록 후 생략 (억지 진행 금지 원칙).

- [x] **Step 1: STAGE 2c 삽입**

old (line 12-14):
```bash
echo "=== STAGE 2b: seal-regression meta-test ==="
bash "$HOME/.claude/setup/tests/seal-regression.test.sh" || { echo "FAIL seal-regression"; exit 1; }
echo
```

new:
```bash
echo "=== STAGE 2b: seal-regression meta-test ==="
bash "$HOME/.claude/setup/tests/seal-regression.test.sh" || { echo "FAIL seal-regression"; exit 1; }
echo
echo "=== STAGE 2c: fail-open surface meta-test ==="
bash "$HOME/.claude/setup/tests/failopen-surface.test.sh" || { echo "FAIL failopen-surface"; exit 1; }
echo
```

- [x] **Step 2: 구문 검증**

Run: `bash -n "$HOME/.claude/setup/verify-all.sh" && echo OK`
Expected: `OK`

---

### Task 7: Closeout — baseline 불변 + 자산 갱신 + 커밋

- [x] **Step 1: 전체 verify-all (baseline 불변 측정)**

Run: `bash "$HOME/.claude/setup/verify-all.sh" 2>&1 | tail -40`
Expected: STAGE 1·1b·2(verify-setup PASS=65 FAIL=0)·2b(seal PASS=5/0)·**2c(failopen PASS=5/0)**·3(run-all 129/129·정합 OK)·4(integration)·`ALL PASS`.

- [x] **Step 2: CONTEXT.md "fail-open" 절에 런타임 실현 문장 추가** (자산 갱신; CONTEXT.md 는 repo 파일 — §1 캐시 무관)

- [x] **Step 3: audit-reverification.md §4 rank6 → ✅ + ③ defer 기록** (`6 |` → `6 ✅ |`, 핵심 fix 에 cycle-32 실측·③ defer 사유)

- [x] **Step 4: state.json cycle.count 31→32, last_completed_at/last_drift_check = 2026-06-13**

- [x] **Step 5: 이 plan Status active→completed, 전 체크박스 [x]**

- [x] **Step 6: review-strict closeout drift PASS 확인**

- [x] **Step 7: 명시 staging 단일 커밋 (git add -A 금지, skills/ui-design/design.md 제외) + push → ahead 0**

Staging 대상: `setup/tests/failopen-surface.test.sh` `hooks/enforce-rpi-bash.sh` `hooks/session-start-audit.sh` `setup/verify-all.sh` `setup/verify-setup.sh`(변경 시) `CONTEXT.md` `docs/superpowers/specs/2026-06-13-audit-reverification.md` `docs/superpowers/plans/2026-06-13-cycle32-failopen-runtime-surfacing.md` `state.json`
