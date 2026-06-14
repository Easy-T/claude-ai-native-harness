# 우회-사용 표면화 + 로그 소비 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox(`- [ ]`).

**Status:** completed
**RPI-Cycle:** 35
**Started:** 2026-06-14

**Goal:** 3 게이트 bypass 분기에 세션당-1회 additionalContext 표면화(surface_bypass, G3-a)를 추가하고, doctor에 당월 .log 집계 sub-check(log_summary, G6-c)를 추가한다. **차단 변경 없음(advisory만), secret 값 미표시 불변식 유지.** 4 케이스 TDD, 무회귀.

**Architecture:** spec=`docs/superpowers/specs/2026-06-14-bypass-surfacing-and-log-consumption-design.md`. _common.sh에 헬퍼 2개(surface_bypass·log_summary; 둘 다 항상 return 0=비차단), 3 enforce-* 게이트 bypass 분기에서 surface_bypass 호출, doctor 20d에서 log_summary를 **서브셸 source**로 호출(env 무오염). 라이브 게이트 수정 → TDD + 즉시 run-all 무회귀.

**Tech Stack:** bash/awk/node, additionalContext JSON, session_marker dedup.

> **커밋 정책:** working-tree 구현+검증만, commit/merge는 Closeout 사용자 승인까지 deferred.

---

## File Structure
- Modify `hooks/_common.sh` (surface_bypass + log_summary 추가, emit_additional_context 뒤).
- Modify `hooks/enforce-rpi-cycle.sh:68-72`, `enforce-rpi-bash.sh:25-28`, `enforce-secret-scan.sh:28-31` (bypass 분기에 surface_bypass).
- Modify `setup/doctor.sh` (20c 뒤 20d sub-check).
- Modify `hooks/tests/cases.tsv` + `run-all.sh` (4 케이스 150-153 + 헬퍼).
- Modify `README.md` (cases 카운트 135→139).

---

## Task 1: 우회-사용 표면화 (surface_bypass + 3 게이트)

**Files:** `hooks/_common.sh`, 3 enforce-*.sh, `hooks/tests/cases.tsv`, `run-all.sh`

- [x] **Step 1: Write failing tests** — (1a) `cases.tsv` 끝(145 뒤)에 추가:

```
# cycle-35 (2026-06-14) — 우회-사용 표면화(G3-a) + 로그 소비(G6-c)
enforce-rpi-bash	150-bypass-rpibash-surface	output	gen_erb_150
enforce-secret-scan	151-bypass-secretscan-surface	output	gen_ess_151
enforce-rpi-cycle	152-bypass-rpicycle-surface	output	gen_erc_152
```

(1b) `run-all.sh`의 surface-constitution 블록 끝(`rm -f /tmp/surface-adr-sct93 2>/dev/null` 줄) **다음**, `# ==================== Summary ====================` 줄 **앞**에 신규 블록 추가($NP/$BIG/$SCRATCH/test_lib 모두 이 위치에서 스코프 내):

```bash
# ==================== CYCLE-35: BYPASS SURFACING (G3-a) ====================
# 출력 기반: bypass 분기가 additionalContext 로 우회를 표면화(alert) vs 무(silent). exit 항상 0(기존 skip 테스트 불변).
test_bypass() {
  local name="$1"; local hook="$2"; local input="$3"; local env_pfx="$4"; local sid="$5"
  TOTAL=$((TOTAL+1))
  rm -f /tmp/bypass-*-"$sid" 2>/dev/null
  local out got=silent
  out=$(echo "$input" | env $env_pfx "$HOOKS/$hook" 2>/dev/null)
  { echo "$out" | grep -qF 'additionalContext' && echo "$out" | grep -qF '우회'; } && got=alert
  rm -f /tmp/bypass-*-"$sid" 2>/dev/null
  [ "$got" = alert ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("$name (want=alert got=$got)")
}
bsid_ev() { printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$2" "$3"; }
wsid_ev() { SID="$1" FILE="$2" CONTENT="$3" CWD="$4" node -e 'console.log(JSON.stringify({session_id:process.env.SID,tool_name:"Write",tool_input:{file_path:process.env.FILE,content:process.env.CONTENT},cwd:process.env.CWD}))'; }
test_bypass "150-bypass-rpibash-surface"    "enforce-rpi-bash.sh"    "$(bsid_ev byp35a 'echo x > foo.py' "$NP")"            "RPI_SKIP=hotfix"           byp35a
test_bypass "151-bypass-secretscan-surface" "enforce-secret-scan.sh" "$(bsid_ev byp35b 'echo hello world' "$NP")"           "SECRET_SCAN_SKIP=approved" byp35b
test_bypass "152-bypass-rpicycle-surface"   "enforce-rpi-cycle.sh"   "$(wsid_ev byp35c "$NP/src/x.ts" "$BIG" "$NP")"        "RPI_SKIP=hotfix"           byp35c
```

- [x] **Step 2: Run to verify RED**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | grep -E '150-bypass|151-bypass|152-bypass|passed'`
Expected: 150·151·152 셋 다 Failures(`want=alert got=silent`) — 현재 surface_bypass 미존재로 additionalContext 미방출. `135 / 138 passed`. 비공허 RED.

- [x] **Step 3: Implement** — (3a) `hooks/_common.sh`의 `emit_additional_context() { ... }`(line 150) **다음 줄**에 추가:

```bash

# --- surface_bypass <hook> <session_id> <msg>: 우회-사용을 세션당 1회 additionalContext 로 표면화 (G3-a) ---
# advisory 전용 — 항상 return 0(표면화 실패가 작업을 차단하면 안 됨). session_marker 로 우회-세션 매-명령 bloat 방지.
surface_bypass() {
  local hook="$1" sid="${2:-unknown}" msg="$3" mark
  mark=$(session_marker "bypass-$hook" "$sid")
  if [ -f "$mark" ]; then return 0; fi
  : > "$mark" 2>/dev/null || true
  emit_additional_context "$msg" || true
  return 0
}
```

(3b) `hooks/enforce-rpi-bash.sh:25-28` 의 RPI_SKIP 분기를 교체:

```bash
if [ -n "${RPI_SKIP:-}" ]; then
  hook_log "enforce-rpi-bash" "bash" "PASS" "skip:${RPI_SKIP}"
  surface_bypass "rpi-bash" "$(echo "$INPUT" | json_get session_id)" "⚠ RPI bash 게이트 우회 (RPI_SKIP='${RPI_SKIP}') — 이 세션 셸 코드작성에 게이트 미적용; 의도된 우회인지 확인"
  exit 0
fi
```

(3c) `hooks/enforce-secret-scan.sh:28-31` 의 SECRET_SCAN_SKIP 분기를 교체:

```bash
if [ -n "${SECRET_SCAN_SKIP:-}" ]; then
  hook_log "enforce-secret-scan" "payload" "PASS" "skip:${SECRET_SCAN_SKIP}"
  surface_bypass "secret-scan" "$(echo "$INPUT" | json_get session_id)" "⚠ 시크릿 스캔 우회 (SECRET_SCAN_SKIP='${SECRET_SCAN_SKIP}') — 이 페이로드 미검사; 의도된 우회인지 확인"
  exit 0
fi
```

(3d) `hooks/enforce-rpi-cycle.sh:68-72` 의 RPI_SKIP 분기를 교체(기존 stderr echo 유지 + surface 추가):

```bash
if [ -n "${RPI_SKIP:-}" ]; then
  hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "skip:${RPI_SKIP}"
  echo "[rpi] SKIP: $RPI_SKIP" >&2
  surface_bypass "rpi-cycle" "$(echo "$INPUT" | json_get session_id)" "⚠ RPI 게이트 우회 (RPI_SKIP='${RPI_SKIP}') — 이 세션 코드변경에 RPI 미적용; 의도된 우회인지 확인"
  exit 0
fi
```

- [x] **Step 4: Run to verify GREEN(부분)**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | grep -E '150-bypass|151-bypass|152-bypass|36-rpi-skip|45-skip|06-rpi-skip|passed'`
Expected: 150·151·152 실패 목록서 사라짐. 기존 skip(36/45/06/30) exit 0 불변. `138 / 138 passed`. (153 아직 미추가.)

- [x] **Step 5: Stage** — `git add hooks/_common.sh hooks/enforce-rpi-bash.sh hooks/enforce-secret-scan.sh hooks/enforce-rpi-cycle.sh hooks/tests/cases.tsv hooks/tests/run-all.sh`

---

## Task 2: 로그 소비 (log_summary + doctor 20d)

**Files:** `hooks/_common.sh`, `setup/doctor.sh`, `hooks/tests/cases.tsv`, `run-all.sh`

- [x] **Step 1: Write failing test** — (2a) `cases.tsv`의 `152-bypass-rpicycle-surface` 뒤에 추가:

```
hooks-lib	153-logsummary-counts	output	gen_lib_153
```

(2b) `run-all.sh`의 Task1 bypass 블록 끝(test_bypass 152 줄) **뒤**에 추가:

```bash
# cycle-35: log_summary 당월 집계 (G6-c, 값 미표시 — 카운트만)
LOGT=$(mktemp "$SCRATCH/logsum-XXXXXX.log")
{ printf 'ts\tenforce-rpi-bash\tx.py\tBLOCK\tno-active-plan\n'
  printf 'ts\tenforce-rpi-cycle\ty.sh\tBLOCK\tno-active-plan\n'
  printf 'ts\tenforce-rpi-bash\tbash\tPASS\tskip:hotfix\n'
  printf 'ts\tredirect-targets.js\tparser\tFAILOPEN\tparser-exit-1\n'; } > "$LOGT"
test_lib "153-logsummary-counts" "BLOCK=2 SKIP=1 FAILOPEN=1 ALERT=0" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; log_summary "$1"' _ "$LOGT")"
```

- [x] **Step 2: Run to verify RED**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | grep -E '153-logsummary|passed'`
Expected: `hooks-lib/153-logsummary-counts (exp=[BLOCK=2 SKIP=1 FAILOPEN=1 ALERT=0] got=[])` — log_summary 미존재. `138 / 139 passed`. 비공허 RED.

- [x] **Step 3: Implement** — (3a) `hooks/_common.sh` 의 surface_bypass 함수 **다음**에 추가:

```bash

# --- log_summary <logfile>: 당월 .log 의 verdict 카운트만 출력 (값 미표시, G6-c 로그 소비) ---
log_summary() {
  local f="${1:-}"
  if [ ! -f "$f" ]; then printf 'BLOCK=0 SKIP=0 FAILOPEN=0 ALERT=0'; return 0; fi
  awk -F'\t' '
    $4=="BLOCK"{b++} $4=="FAILOPEN"{fo++} $4=="ALERT"{a++}
    ($4=="PASS" && $5 ~ /^skip:/){s++}
    END{printf "BLOCK=%d SKIP=%d FAILOPEN=%d ALERT=%d", b+0, s+0, fo+0, a+0}
  ' "$f" 2>/dev/null || printf 'BLOCK=0 SKIP=0 FAILOPEN=0 ALERT=0'
}
```

(3b) `setup/doctor.sh` 의 20c 블록 끝(`fi` — 현 273 근처, `check "hook log rotation"` 들어있는 `if [ -d "$LOGDIR" ]` 블록의 닫는 `fi`) **다음**에 20d 추가:

```bash

# 20d. hooks/.log 당월 판정 집계 (G6-c 로그 소비 — read-only, 카운트만; 값 미표시, S8 postmortem)
LOGMONTH="$LOGDIR/$(date +%Y-%m).log"
if [ -f "$LOGMONTH" ] && [ -r "$CLAUDE_HOME/hooks/_common.sh" ]; then
  LOGSUM=$( source "$CLAUDE_HOME/hooks/_common.sh" 2>/dev/null; log_summary "$LOGMONTH" 2>/dev/null ) || LOGSUM=""
  if [ -n "$LOGSUM" ]; then
    check "hook log 당월 집계" "PASS" "$LOGSUM"
  else
    check "hook log 당월 집계" "WARN" "집계 불가"
  fi
fi
```

- [x] **Step 4: Run to verify GREEN**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | tail -4`
Expected: `139 / 139 passed` · 정합 `139 declared == 139 run` · Pass rate 100%.

- [x] **Step 5: Stage** — `git add hooks/_common.sh setup/doctor.sh hooks/tests/cases.tsv hooks/tests/run-all.sh`

---

## Task 3: README 동기화 + 무회귀 전수

- [x] **Step 1: README cases 카운트 동기화 (#20 seal 선제)** — `README.md:274` `135 case`→`139 case`, `README.md:510` `135 케이스`→`139 케이스`.

- [x] **Step 2: run-all 무회귀**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | tail -4`
Expected: `139 / 139 passed`, 정합 OK, 100%. 기존 skip(36/45/06/30)·전체 불변.

- [x] **Step 3: verify-setup 무회귀(+#20 README seal)**

Run: `bash "$HOME/.claude/setup/verify-setup.sh" 2>&1 | grep -E 'README cases|FAIL|PASS='`
Expected: `✓ README cases 카운트 == 실측(139)`, `verify-setup: PASS=65 FAIL=0`.

- [x] **Step 4: 전체 수용 게이트 (doctor 20d·bypass surface 포함)**

Run: `bash "$HOME/.claude/setup/verify-all.sh" 2>&1 | grep -E 'STAGE|passed|PASS=|ALL PASS|집계'`
Expected: doctor에 `hook log 당월 집계` 항목, run-all `139 / 139`, `ALL PASS`.

- [x] **Step 5: 라이브 변경 추적**

Run: `cd "$HOME/.claude" && git status --short`
Expected: M _common.sh, M enforce-rpi-bash/secret-scan/rpi-cycle, M doctor.sh, M cases.tsv, M run-all.sh, M README.md + spec/plan. 의도된 변경만.

---

## Self-Review
- **Spec coverage**: 결정1(surface)=Task1, 결정2(log)=Task2, README+무회귀=Task3. 4 케이스 spec §2 표와 1:1. ✓
- **Placeholder scan**: 전 Step 실제 코드/명령/기대. ✓
- **비차단 불변식**: surface_bypass·log_summary 둘 다 항상 return 0; doctor 20d는 서브셸 source(env 무오염)+`|| LOGSUM=""`; 기존 skip 테스트 exit 0 불변. ✓
- **secret 미표시**: surface는 SKIP reason만, log_summary는 카운트만. ✓
- **이름 일관**: surface_bypass/log_summary/session_marker("bypass-$hook")/emit_additional_context; case_id 150-153 cases.tsv↔run-all 일치. ✓
- **카운트**: 135→139(+4), README 동기화로 #20 seal 통과. doctor PASS 35→36(카운트 무단언 — cycle-33 explore 확인). ✓
