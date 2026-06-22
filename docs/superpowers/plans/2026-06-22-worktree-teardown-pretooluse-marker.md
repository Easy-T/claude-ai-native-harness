# Worktree-Teardown PreToolUse Marker WRITE — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline) implements this plan
> task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Status:** active
**RPI-Cycle:** 40
**Started:** 2026-06-22

**Goal:** Make worktree-teardown actually fire in real sessions by recording the `session_id`-keyed marker from
**PreToolUse** (where the worktree absolute path arrives via `tool_input`), not from `SessionStart` cwd (always
the main repo root). Add a concurrency guard so a peer session's active worktree is never deleted. Success =
a real-input-shape test (cwd=main root + worktree path in `tool_input`) writes the marker, SessionEnd (cwd=main
root) tears the worktree down with `rm_ok=1` and the junction target intact; all existing tests unregressed.

**Architecture:** Two new pure-bash, fail-open helpers in `_common.sh` (`wt_root_from_path`,
`record_worktree_marker`) shared by 3 sites. The two PreToolUse gates (`enforce-rpi-cycle` Write|Edit|NotebookEdit,
`enforce-rpi-bash` Bash) call `record_worktree_marker` at the top, before any block/exit. `SessionStart` WRITE
demoted to secondary via the same helper. `SessionEnd` CONSUME unchanged + new C5 concurrency guard.

**Tech Stack:** Bash (MSYS2 Git Bash on Win11), node (JSON parse via `_common.sh` helpers), Claude Code hooks.

## Global Constraints (verbatim from spec §2, §9.3, §10)

- **Data-loss = 0.** CONSUME path unchanged: reparse pre-removal → `remaining==0` assert → POSIX `rm -rf`.
  **`git worktree remove --force` is FORBIDDEN.** Marker-derived path passes the same GUARD 2 (sanity) + GUARD 3
  (`--absolute-git-dir` linked-worktree proof) before any `rm`. Always `exit 0`.
- **C1:** empty/`unknown` `session_id` ⇒ skip marker WRITE **and** CONSUME.
- **C4 / fail-open:** every marker op best-effort (`|| true`, `2>/dev/null`); `record_worktree_marker` &
  `wt_root_from_path` MUST be set-e safe (the gates run `set -euo pipefail` with no `set +e`) → always
  `return 0` from `record_worktree_marker`; its internal `wt_root_from_path` failure caught by `|| return 0`.
  Marker WRITE must NEVER change a gate's exit code or block decision.
- **C5 (new):** before any destructive step, scan `worktrees-marker/`; if *another* SID's marker points at the
  same `WT_ROOT` → no-op (`noop:concurrent-owner`). Can only PREVENT a deletion, never cause one.
- **No new hook file, no `settings.json`/`settings.example.json` change** → seals #8/#14/#23/#24 untouched.
- Surgical: every changed line traces to this goal. Match existing hook style.

## File Structure

- `hooks/_common.sh` — Modify: add `wt_root_from_path` + `record_worktree_marker` after `wt_marker_path` (~line 147).
- `hooks/enforce-rpi-cycle.sh` — Modify: add `session_id` to the line-7 `json_get_many`; call `record_worktree_marker`
  after FILE_PATH normalize (~line 9); reuse `$SID` at the bypass line (~line 71).
- `hooks/enforce-rpi-bash.sh` — Modify: hoist `SID` after CMD parse (~line 17), call `record_worktree_marker`;
  reuse `$SID` at the bypass line (~line 27).
- `hooks/session-start-audit.sh` — Modify: WRITE block (lines 8-25) → `record_worktree_marker` + corrected
  comment; keep stale-prune (26-33).
- `hooks/worktree-teardown.sh` — Modify: add C5 concurrency guard after GUARD 3 (~line 76), before BRANCH (~line 78).
- `hooks/tests/run-all.sh` + `hooks/tests/cases.tsv` — Modify: add cases 161-166 (4 gate-E2E + 2 unit) → DECLARED 146→152.
- `hooks/tests/worktree-teardown.test.sh` — Modify: add Tb (real-signal E2E) + Tc (concurrency) → 13→20.
- `README.md` — Modify: cases count 146→152.
- `setup/verify-setup.sh` — Modify only if a seal hardcodes the cases count or test count (read #20/#21 first).
- `CONTEXT.md` — Modify: marker term note (PreToolUse-keyed).
- `state.json` — Modify: cycle.count 39→40, dates (Closeout).

**Run tests with a clean POSIX PATH prefix** (Bash-tool PATH is Windows-mangled → false failures):
`export PATH="/usr/bin:/mingw64/bin:/c/WINDOWS/System32:/c/WINDOWS:/c/WINDOWS/System32/WindowsPowerShell/v1.0:/c/Program Files/Git/cmd:/c/Program Files/nodejs:/c/Users/12132/AppData/Roaming/npm:/c/Users/12132/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"`

---

### Task 1: `_common.sh` helpers (`wt_root_from_path`, `record_worktree_marker`) + unit cases

**Files:**
- Modify: `hooks/_common.sh` (after `wt_marker_path`, ~line 147)
- Modify: `hooks/tests/run-all.sh` (add 2 unit cases near the cycle-39 marker section ~line 475) + `hooks/tests/cases.tsv`

**Interfaces — Produces:**
- `wt_root_from_path <path-or-command>` → prints `<repo>/.claude/worktrees/<name>` and returns 0 on match; returns 1 (no output) on no-match.
- `record_worktree_marker <session_id> <path-or-command>` → writes `WT_ROOT` to `wt_marker_path(sid)` if sid valid AND path contains a worktree; always returns 0.

- [ ] **Step 1: Write the failing unit cases** in `run-all.sh` (after the cycle-39 `test_ssa_prune` block, ~line 475):

```bash
# ==================== CYCLE-40: wt_root_from_path 단위 (정규식 + worktrees-marker 자기-비매칭 안전) ====================
test_lib "165-wtroot-extract" "/tmp/r/.claude/worktrees/cyc-x" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; wt_root_from_path "$1"' _ "/tmp/r/.claude/worktrees/cyc-x/app/f.ts")"
test_lib "166-wtroot-markerdir-nomatch" "" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; wt_root_from_path "$1" || true' _ "$HOME/.claude/worktrees-marker/sid")"
```

- [ ] **Step 2: Add the two declarations to `cases.tsv`** (append after line 160):

```
# cycle-40 (2026-06-22) — PreToolUse 워크트리 마커 WRITE (실-입력 shape) + wt_root_from_path 단위
hooks-lib	165-wtroot-extract	output	gen_lib_165
hooks-lib	166-wtroot-markerdir-nomatch	output	gen_lib_166
```

- [ ] **Step 3: Run to verify RED.** Expected: `165-wtroot-extract` FAILS (function undefined → empty output ≠ expected). `166` may spuriously pass (empty==empty). Reconciliation still OK (TOTAL grows with DECLARED).

Run: `bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '165|166|reconcile|passed'`
Expected: a failure line `hooks-lib/165-wtroot-extract`.

- [ ] **Step 4: Implement the helpers** in `_common.sh` immediately after the `wt_marker_path` function (after line 147):

```bash
# --- wt_root_from_path <path-or-command>: 임의 경로/명령 문자열에서 첫 <repo>/.claude/worktrees/<name> 추출 (SSOT) ---
# teardown(CONSUME)·session-start(보조 WRITE)·PreToolUse(주 WRITE) 3-site 가 동일 규칙 공유.
# ERE: <repo>=구분자(공백/따옴표/셸메타) 없는 최대 런, <name>=그 뒤 단일 세그먼트. 매칭 0, 무매칭 1(무출력).
# (worktrees-marker/ 는 'worktrees/' 가 아니므로 자기-비매칭 — record 가 잘못된 마커를 쓰지 않게 하는 안전 속성.)
wt_root_from_path() {
  local s; s=$(normalize_path "${1:-}")
  local re='([^[:space:]"'\''=;|&<>(),`]+)/\.claude/worktrees/([^/[:space:]"'\''=;|&<>(),`]+)'
  if [[ "$s" =~ $re ]]; then
    printf '%s/.claude/worktrees/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  return 1
}

# --- record_worktree_marker <session_id> <path-or-command>: 워크트리 경로 감지 시 session_id-키 마커에 WT_ROOT 기록 ---
# SessionEnd teardown 이 종료세션의 워크트리를 cwd 와 무관하게 식별하도록. PreToolUse(주)·SessionStart(보조) 가 호출.
# C1: 빈/unknown SID skip(동시세션 'unknown' 마커 공유 → 타세션 활성 워크트리 오정리 방지).
# strictly fail-open + set -e 안전: 항상 return 0 (내부 무매칭은 || return 0 으로 흡수, 모든 쓰기 best-effort).
record_worktree_marker() {
  local sid="${1:-}" src="${2:-}"
  [ -n "$sid" ] && [ "$sid" != "unknown" ] || return 0
  local wt; wt=$(wt_root_from_path "$src") || return 0
  mkdir -p "$HOME/.claude/worktrees-marker" 2>/dev/null || true
  printf '%s\n' "$wt" > "$(wt_marker_path "$sid")" 2>/dev/null || true
  return 0
}
```

- [ ] **Step 5: Run to verify GREEN.**

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '165|166|passed|정합'`
Expected: 165 & 166 pass; reconciliation `148 declared == 148 run` (146 + 2 so far).

- [ ] **Step 6: Commit.**

```bash
git add hooks/_common.sh hooks/tests/run-all.sh hooks/tests/cases.tsv
git commit -m "feat(hooks): _common wt_root_from_path + record_worktree_marker (SSOT) (cycle-40)"
```

---

### Task 2: `enforce-rpi-cycle.sh` PreToolUse marker WRITE + gate cases 161-163

**Files:**
- Modify: `hooks/enforce-rpi-cycle.sh` (line 7 json_get_many; insert after line 9; line 71 bypass reuse)
- Modify: `hooks/tests/run-all.sh` (add gate-E2E helper + cases 161-163) + `hooks/tests/cases.tsv`

**Interfaces — Consumes:** `record_worktree_marker` (Task 1).

- [ ] **Step 1: Write the failing gate cases** in `run-all.sh` (after the Task-1 unit cases, ~line 477). Add the helper once, then cases:

```bash
# 실-입력 shape: cwd=메인 레포 루트(워크트리 아님) + tool_input 에 워크트리 절대경로 → record 가 마커 기록.
# (cycle-39 가 놓친 입력 shape — 합성 worktree-cwd 를 먹이지 않는다.)
PTU_MAIN="$SCRATCH/pturepo"; PTUWT="$PTU_MAIN/.claude/worktrees/cycle-p"; mkdir -p "$PTUWT/app" "$PTU_MAIN/src"
WTROOT_P="$PTU_MAIN/.claude/worktrees/cycle-p"
ptu_cycle_ev() { SID="$1" FILE="$2" CWD="$3" node -e 'console.log(JSON.stringify({session_id:process.env.SID,tool_name:"Write",tool_input:{file_path:process.env.FILE,content:"x"},cwd:process.env.CWD}))'; }
ptu_bash_ev()  { printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$2" "$3"; }
test_ptu_mark() {
  local name="$1" hook="$2" input="$3" sid="$4" want="$5" wantval="${6:-}"   # want: written|absent
  TOTAL=$((TOTAL+1))
  local mp; mp=$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; wt_marker_path "$1"' _ "$sid")
  rm -f "$mp" 2>/dev/null
  echo "$input" | "$HOOKS/$hook" >/dev/null 2>&1
  local got=absent; [ -f "$mp" ] && got=written
  local okk=0
  if [ "$got" = "$want" ]; then
    if [ "$want" = "written" ] && [ -n "$wantval" ]; then
      [ "$(head -1 "$mp" 2>/dev/null)" = "$wantval" ] && okk=1
    else okk=1; fi
  fi
  rm -f "$mp" 2>/dev/null
  [ "$okk" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("$name (want=$want/$wantval got=$got)")
}
test_ptu_mark "161-ptu-cycle-write"      "enforce-rpi-cycle.sh" "$(ptu_cycle_ev "ptu161_$$" "$PTUWT/app/foo.ts" "$PTU_MAIN")"     "ptu161_$$" written "$WTROOT_P"
test_ptu_mark "162-ptu-cycle-empty-skip" "enforce-rpi-cycle.sh" "$(ptu_cycle_ev "" "$PTUWT/app/foo.ts" "$PTU_MAIN")"              ""          absent
test_ptu_mark "163-ptu-cycle-nonwt-skip" "enforce-rpi-cycle.sh" "$(ptu_cycle_ev "ptu163_$$" "$PTU_MAIN/src/foo.ts" "$PTU_MAIN")" "ptu163_$$" absent
```

- [ ] **Step 2: Add declarations to `cases.tsv`** (after the Task-1 lines):

```
enforce-rpi-cycle	161-ptu-cycle-write	written	gen_ptu_161
enforce-rpi-cycle	162-ptu-cycle-empty-skip	absent	gen_ptu_162
enforce-rpi-cycle	163-ptu-cycle-nonwt-skip	absent	gen_ptu_163
```

- [ ] **Step 3: Run to verify RED.** 161 FAILS (current cycle gate never writes a marker → got=absent). 162/163 pass (nothing writes).

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '161|162|163'`
Expected: `enforce-rpi-cycle/161-ptu-cycle-write (want=written/... got=absent)`.

- [ ] **Step 4: Implement** — edit `enforce-rpi-cycle.sh`:

(a) line 7 — add `session_id` to the batch read:
```bash
IFS=$'\037' read -r FILE_PATH NB_PATH TOOL SID <<< "$(echo "$INPUT" | json_get_many tool_input.file_path tool_input.notebook_path tool_name session_id)"
```
(b) immediately after line 9 (`FILE_PATH=$(normalize_path "$FILE_PATH")`), insert:
```bash
# --- WORKTREE MARKER (cycle-40): 워크트리 경로를 만지는 PreToolUse 에서 session_id-키 마커 기록 (SessionEnd teardown).
#   SessionStart cwd 는 항상 CLI 실행디렉터리(메인루트)라 워크트리 식별 불가 → 워크트리 절대경로가 실제 도달하는
#   여기서 기록(spec §10). strictly fail-open: block 판정 전에 호출하되 exit/판정에 영향 0 (helper 가 항상 return 0).
record_worktree_marker "$SID" "$FILE_PATH"
```
(c) line 71 — replace the inline session_id read with `$SID`:
```bash
  surface_bypass "rpi-cycle" "$SID" "⚠ RPI 게이트 우회 (RPI_SKIP='${RPI_SKIP}') — 이 세션 코드변경에 RPI 미적용; 의도된 우회인지 확인"
```

- [ ] **Step 5: Run to verify GREEN.** 161 now written (content==WT_ROOT). All erc cases (01-95, 104, 139, 145, 152, 19) still pass (non-worktree paths → no marker, exit codes unchanged).

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '161|162|163|enforce-rpi-cycle|passed'`
Expected: 161/162/163 pass; no enforce-rpi-cycle regression.

- [ ] **Step 6: Commit.**

```bash
git add hooks/enforce-rpi-cycle.sh hooks/tests/run-all.sh hooks/tests/cases.tsv
git commit -m "feat(hooks): enforce-rpi-cycle records worktree marker from PreToolUse (cycle-40)"
```

---

### Task 3: `enforce-rpi-bash.sh` PreToolUse marker WRITE + gate case 164

**Files:**
- Modify: `hooks/enforce-rpi-bash.sh` (after line 17 CMD; line 27 bypass reuse)
- Modify: `hooks/tests/run-all.sh` (case 164) + `hooks/tests/cases.tsv`

- [ ] **Step 1: Write the failing case** in `run-all.sh` (after case 163):

```bash
test_ptu_mark "164-ptu-bash-write" "enforce-rpi-bash.sh" "$(ptu_bash_ev "ptu164_$$" "cd $PTUWT/app && npm i" "$PTU_MAIN")" "ptu164_$$" written "$WTROOT_P"
```

- [ ] **Step 2: Add declaration to `cases.tsv`:**

```
enforce-rpi-bash	164-ptu-bash-write	written	gen_ptu_164
```

- [ ] **Step 3: Run to verify RED.** 164 FAILS (bash gate never writes a marker yet → absent).

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '164'`
Expected: `enforce-rpi-bash/164-ptu-bash-write (want=written/... got=absent)`.

- [ ] **Step 4: Implement** — edit `enforce-rpi-bash.sh`:

(a) after line 17 (`CMD=$(echo "$INPUT" | json_get 'tool_input.command')`), insert:
```bash
# --- WORKTREE MARKER (cycle-40): Bash 명령의 워크트리 절대경로에서 session_id-키 마커 기록 (spec §10). fail-open. ---
SID=$(echo "$INPUT" | json_get session_id)
record_worktree_marker "$SID" "$CMD"
```
(b) line 27 — replace the inline session_id read with `$SID`:
```bash
  surface_bypass "rpi-bash" "$SID" "⚠ RPI bash 게이트 우회 (RPI_SKIP='${RPI_SKIP}') — 이 세션 셸 코드작성에 게이트 미적용; 의도된 우회인지 확인"
```

- [ ] **Step 5: Run to verify GREEN.** 164 written; all enforce-rpi-bash cases (30-36, 102-120, 130-132, 143, 150, 155) unregressed.

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '164|enforce-rpi-bash|passed|정합'`
Expected: 164 pass; reconciliation `150 declared == 150 run`; no bash-gate regression.

- [ ] **Step 6: Commit.**

```bash
git add hooks/enforce-rpi-bash.sh hooks/tests/run-all.sh hooks/tests/cases.tsv
git commit -m "feat(hooks): enforce-rpi-bash records worktree marker from PreToolUse (cycle-40)"
```

---

### Task 4: `session-start-audit.sh` WRITE → SSOT helper (secondary path; preserve 156-160)

**Files:**
- Modify: `hooks/session-start-audit.sh` (lines 8-25 → helper call + corrected comment; keep prune 26-33)

- [ ] **Step 1: Confirm baseline GREEN** for the session-start marker cases (156-160) before refactor.

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '15[6-9]|160'`
Expected: 156-160 all pass.

- [ ] **Step 2: Replace the WRITE block** (lines 8-25) with the SSOT helper + corrected comment (keep the SID read line and `WT_MARK_DIR` for the prune block that follows):

```bash
# --- WORKTREE MARKER (SessionEnd teardown fallback): 워크트리 절대경로가 도달하는 PreToolUse(enforce-rpi-cycle/bash)
#   가 1차 기록(cycle-40, spec §10). 여기(SessionStart)는 *보조* — 드물게 워크트리에서 직접 claude 를 띄워 cwd 가
#   워크트리인 경우만 기록. (SessionStart/End cwd 는 CLI 실행디렉터리=메인루트라 일반적으론 워크트리 아님 — cycle-39 전제 오류.)
#   strictly fail-open(set -e 안전: helper 가 항상 return 0; 빈/unknown SID 는 helper 가 skip).
SID=$(echo "$INPUT" | json_get 'session_id'); [ -n "$SID" ] || SID="unknown"
WT_MARK_DIR="$HOME/.claude/worktrees-marker"
record_worktree_marker "$SID" "$CWD"
```

(The stale-prune block at lines 26-33 stays unchanged — it references `WT_MARK_DIR`, still defined above.)

- [ ] **Step 3: Run to verify GREEN preserved.** 156-160 still pass (same behavior via helper: cwd=worktree → written; empty/nonwt → absent; prune unchanged).

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '15[6-9]|160|106|107|108|109|session-start'`
Expected: 156-160 + 106-109 pass; no session-start-audit regression.

- [ ] **Step 4: Commit.**

```bash
git add hooks/session-start-audit.sh
git commit -m "refactor(hooks): session-start marker via record_worktree_marker SSOT; correct cwd framing (cycle-40)"
```

---

### Task 5: `worktree-teardown.sh` C5 concurrency guard + standalone Tb (E2E) / Tc (concurrency)

**Files:**
- Modify: `hooks/worktree-teardown.sh` (insert C5 after line 76, before line 78)
- Modify: `hooks/tests/worktree-teardown.test.sh` (add Tb + Tc → 13→20)

- [ ] **Step 1: Write the failing standalone tests** in `worktree-teardown.test.sh`, inserted after the `Te` block (after line 94, before the cleanup at line 96). Tb validates Tasks 1-3 E2E (will pass); Tc is RED for C5:

```bash
echo "== Tb: 실세션 모사 — PreToolUse(cwd=메인루트, file_path=워크트리)로 마커 생성 → SessionEnd teardown(E2E) =="
make_worktree
B_SID="wtjtest_b_$$"
# enforce-rpi-cycle 에 cwd=메인루트($REPO) + file_path=워크트리파일 → record_worktree_marker 가 마커 생성(실 신호 경로)
printf '{"session_id":"%s","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$B_SID" "$REPO" "$WT/app/frontend/src/own.txt" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1
MK_B="$HOME/.claude/worktrees-marker/$B_SID"
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
printf '{"session_id":"wtjtest_cleanup_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1  # 정리: 단독이 됐으니 teardown
```

(Note: the final cleanup glob at line 97 already removes `wtjtest_*`; the new SIDs match.)

- [ ] **Step 2: Run to verify RED (Tc).**

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/worktree-teardown.test.sh 2>&1 | grep -E 'Tb|Tc|FAIL|PASS='`
Expected: Tb PASS (E2E works from Tasks 1-3); Tc shows `FAIL: Tc: 워크트리 삭제됨` (no C5 guard yet) → overall FAIL exit 1.

- [ ] **Step 3: Implement C5** in `worktree-teardown.sh` — insert after line 76 (the `wt-name-mismatch` GUARD-3 check), before line 78 (`BRANCH=...`):

```bash
# GUARD 5 (cycle-40): 동시-동일 워크트리 보호 — 다른 SID 마커가 같은 WT_ROOT 를 가리키면(본 세션 마커는 위에서 소비됨)
#  동시 세션이 이 워크트리를 활성 사용 중일 수 있음 → 정리 보류(leftover, 데이터손실 아님). 활성 워크트리 삭제 금지.
_WT_MK_DIR="$HOME/.claude/worktrees-marker"
if [ -d "$_WT_MK_DIR" ]; then
  for _omk in "$_WT_MK_DIR"/*; do
    [ -f "$_omk" ] || continue
    _omv=$(head -1 "$_omk" 2>/dev/null); _omv=$(normalize_path "$_omv")
    if [ "$_omv" = "$WT_ROOT" ]; then
      hook_log "worktree-teardown" "$WT_ROOT" "PASS" "noop:concurrent-owner=$(basename "$_omk")"; exit 0
    fi
  done
fi
```

- [ ] **Step 4: Run to verify GREEN (13→20).**

Run: `export PATH=...(clean); bash ~/.claude/hooks/tests/worktree-teardown.test.sh; echo "exit=$?"`
Expected: `worktree-teardown.test: PASS=20 FAIL=0`, exit=0.

- [ ] **Step 5: Commit.**

```bash
git add hooks/worktree-teardown.sh hooks/tests/worktree-teardown.test.sh
git commit -m "feat(hooks): worktree-teardown C5 concurrency guard + PreToolUse-write E2E tests (cycle-40)"
```

---

### Task 6: Doc/SSOT sync (README cases 146→152, verify-setup seals, CONTEXT) + full gate

**Files:**
- Modify: `README.md` (cases count), `CONTEXT.md` (marker term), `setup/verify-setup.sh` (only if a seal hardcodes a count)

- [ ] **Step 1: Locate the count seals.** Read how verify-setup.sh #20 (and #21 if present) asserts the cases / test counts, and find the README cases number.

Run: `grep -nE '14[0-9]|15[0-9]|cases|worktree-teardown.test|13/13|13 ' ~/.claude/setup/verify-setup.sh ~/.claude/README.md | grep -iE 'case|teardown|146|13'`

- [ ] **Step 2: Update README** cases count 146→152 (and the worktree-teardown.test.sh count 13→20 if README states it). Match the exact phrasing found.

- [ ] **Step 3: Update verify-setup.sh** ONLY if a seal hardcodes 146 (→152) or the standalone test count 13 (→20). If #20 derives the count from `cases.tsv` (`DECLARED_N`) dynamically, no edit needed — confirm by reading.

- [ ] **Step 4: Update CONTEXT.md** marker term: note the marker is **PreToolUse-keyed (primary), SessionStart secondary** — cwd is the CLI launch dir, not the worktree (one line; keep canonical "marker = fallback identifier, not delete-authority").

- [ ] **Step 5: Full reconciliation + acceptance gate.**

```bash
export PATH=...(clean)
bash ~/.claude/hooks/tests/run-all.sh; echo "run-all exit=$?"
bash ~/.claude/hooks/tests/worktree-teardown.test.sh; echo "teardown exit=$?"
bash ~/.claude/setup/verify-setup.sh; echo "verify-setup exit=$?"
bash ~/.claude/setup/verify-all.sh; echo "verify-all exit=$?"
```
Expected: run-all `152 declared == 152 run`, pass-rate OK, exit 0; teardown PASS=20 FAIL=0 exit 0; verify-setup PASS exit 0; verify-all ALL PASS exit 0.

- [ ] **Step 6: Commit.**

```bash
git add README.md CONTEXT.md setup/verify-setup.sh
git commit -m "docs(hooks): sync README cases 146→152 + CONTEXT marker framing (cycle-40)"
```

---

## Self-Review (writing-plans checklist)

1. **Spec coverage:** §10.2 (helpers + 2 gate calls + session-start demotion + CONSUME unchanged) → Tasks 1-4;
   §10.3 C5 → Task 5; §10.5 surfaces/counts → all tasks + Task 6; §10.6 5-Whys → already in spec, validated by
   the real-input RED (Task 2 step 3). Covered.
2. **Placeholder scan:** every code step has literal content; no TBD. The only deferred specifics are the exact
   README/verify-setup seal strings — Task 6 step 1 locates them empirically before editing (acceptable: the
   number to change is data, not logic).
3. **Type/name consistency:** `wt_root_from_path` / `record_worktree_marker` / `wt_marker_path` / `WT_ROOT` /
   `WT_MARK_DIR` used consistently across tasks; `$SID` hoist matches the bypass-line reuse in both gates.
4. **RED-first integrity:** Task 1 (165), Task 2 (161), Task 3 (164), Task 5 (Tc) each have a concrete RED step
   before the implementing edit. Task 4 (refactor) and Task 6 (doc/SSOT) are regression-preserving, not new
   behavior — explicitly framed as "GREEN preserved", no false RED claimed.
