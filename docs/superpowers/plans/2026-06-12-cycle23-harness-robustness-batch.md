# cycle-23: 하네스 견고성 배치 (D-LIFECYCLE ~ D-INSTALL) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active
**RPI-Cycle:** 23
**Started:** 2026-06-12

**Goal:** cycle-22 병행 감사가 확정한 5개 결정(D-LIFECYCLE / D-FAILOPEN-SURFACE / D-SIDEDOOR-2 / D-TDD-VERBATIM / D-INSTALL)+부수 정정을 **4개 세션(S1~S4)으로 분할 구현**한다. 각 세션은 독립 실행 가능(zero-context 시작), 세션마다 3게이트(run-all / verify-setup / verify-integration) green + 커밋으로 마감.

**Architecture:** durable spec `docs/superpowers/specs/2026-06-04-non-bypassable-rule-surfacing-design.md`의 "Revision — cycle-23" 섹션이 SSOT. 게이트 의미론 변경(S1)이 최우선 — 이 plan 파일 자체가 `**Status:** active`라 구현 내내 게이트를 연다. 모든 동작 변경은 TDD(케이스 먼저 RED → 구현 GREEN), 모든 거버넌스 사실은 seal 또는 상시 표면으로 봉인.

**Tech Stack:** bash hooks + node lib 파서 + cases.tsv/run-all.sh 단위테스트 + verify-setup seal.

---

## 세션 공통 절차 (S1~S4 매 세션)

**시작:**
1. 읽기: 이 plan의 해당 세션 섹션 + spec Revision — cycle-23 섹션(`docs/superpowers/specs/2026-06-04-non-bypassable-rule-surfacing-design.md:38-52`) + `CONTEXT.md`.
2. `git -C ~/.claude status --short` — 깨끗하지 않으면 사용자에게 보고 후 진행 여부 확인.
3. 직전 세션 체크박스가 모두 [x]인지 확인 (아니면 그 세션부터 재개).

**종료(각 세션 마지막 Task):**
1. `bash ~/.claude/hooks/tests/run-all.sh` → 100%
2. `bash ~/.claude/setup/verify-setup.sh` → FAIL=0
3. `bash ~/.claude/setup/verify-integration.sh` → FAIL=0
4. 이 plan의 해당 세션 체크박스 [x] 갱신 + 커밋(메시지는 각 세션 말미).

---

# SESSION S1 — D-LIFECYCLE: 게이트 의미론 + 데이터 정정 + 3중 표면

### Task 1.1: stale-active plan 데이터 정정 (게이트 사실 복원)

**Files:**
- Modify: `docs/superpowers/plans/2026-06-05-cycle20-verify-integration-seal.md:5`
- Modify: `docs/superpowers/plans/2026-06-05-cycle21-genesis-record-note.md` (헤더에 Status 줄 신설)

- [x] **Step 1: cycle-20 plan Status 정정** — line 5 `**Status:** active` → `**Status:** completed` (Edit). 근거: 커밋 eb90f58이 state.json cycle 20 마감 포함 — Closeout step-2 silent-skip의 사후 정정.
- [x] **Step 2: cycle-21 plan Status 신설** — `**Goal:**` 줄 바로 위에 `**Status:** completed` 한 줄 삽입 (Edit). 근거: 커밋 a25b407 동일.
- [x] **Step 3: 확인** — `bash -c 'source ~/.claude/hooks/_common.sh; has_active_plan ~/.claude && echo ACTIVE || echo NONE'` → 이 cycle-23 plan만 출력되어야 함 (`2026-06-12-cycle23-…`). ✓ 실측: cycle-23 plan 1개만 출력.
- [x] **Step 4: Commit** — `28beee0` (명시 경로 staging — 커밋 위생 준수)

### Task 1.2: E2E.D fixture를 신규 의미론으로 선행 갱신

**Files:**
- Modify: `setup/verify-integration.sh:46-49` (E2E.D plan fixture)

체크박스-fallback 제거 후에도 E2E.D가 유효하도록, fixture plan에 명시 Status를 추가한다 (이 갱신 없이 Task 1.4를 적용하면 E2E.D가 깨진다 — 순서 고정).

- [x] **Step 1: fixture 수정** — heredoc을 다음으로 교체:

```bash
cat > "$TEST_DIR/docs/superpowers/plans/p.md" <<'PLAN'
# P
**Status:** active
- [ ] step1
PLAN
```

- [x] **Step 2: 회귀 확인** — `bash ~/.claude/setup/verify-integration.sh` → PASS=8 (아직 구현 전이므로 전부 통과해야 정상). ✓ 실측 PASS=8 FAIL=0.

### Task 1.3: RED — checkbox-only plan은 active가 아니다 (실패 케이스 작성)

**Files:**
- Modify: `hooks/tests/run-all.sh` (erc/erb 케이스 추가 — `103-cp-code-noplan` 케이스 아래)
- Modify: `hooks/tests/cases.tsv` (말미 추가)

- [x] **Step 1: run-all.sh에 케이스 추가** (`test_erb "103-…"` 줄 바로 아래):

```bash
# cycle-23 D-LIFECYCLE: 명시 Status 없는 checkbox-only plan은 active 아님 → BLOCK
CB="$SCRATCH/cbonly"; mkdir -p "$CB/docs/superpowers/plans" "$CB/src"
printf '# p\n- [ ] s\n' > "$CB/docs/superpowers/plans/p.md"
test_erc "104-checkbox-only-noplan" 2 "$(mk_event Write "$CB/src/foo.ts" "$BIG" "$CB")"
test_erb "105-heredoc-checkbox-only" 2 "$(mk_bash_event "$HEREDOC_PY" "$CB")"
```

- [x] **Step 2: cases.tsv 말미 추가** (TAB 구분 유지):

```
enforce-rpi-cycle	104-checkbox-only-noplan	2	gen_erc_checkbox_only
enforce-rpi-bash	105-heredoc-checkbox-only	2	gen_erb_checkbox_only
```

- [x] **Step 3: RED 확인** — `bash ~/.claude/hooks/tests/run-all.sh` → 104/105 **FAIL** (현재 fallback이 active 판정해 exit 0). 실패 출력 보존(RED 증거). ✓ 실측 RED: `96/98 passed — 104(expected=2,got=0)·105(expected=2,got=0)`.

### Task 1.4: GREEN — has_active_plan 의미론 변경 (`plan_status` 헬퍼 추출)

**Files:**
- Modify: `hooks/_common.sh:85-106` (has_active_plan)

- [x] **Step 1: 구현** — has_active_plan 블록을 다음으로 교체:

```bash
# --- plan_status <plan.md>: head-20의 명시 Status 첫 단어(소문자) 출력. 없으면 빈 문자열 ---
# has_active_plan / session-start-audit 가 공유 (status 추출 로직 단일화).
plan_status() {
  head -20 "$1" 2>/dev/null | grep -m1 -iE '^\*?\*?status:?\*?\*?' \
    | sed -E 's/^\*?\*?[Ss]tatus:?\*?\*?[[:space:]]*//' | awk '{print tolower($1)}' | tr -d '*' || true
}

# --- has_active_plan: <cwd>의 docs/superpowers/plans에 active plan이 있으면 경로 출력+return 0 ---
# Usage: if PLAN=$(has_active_plan "$CWD"); then ...; fi
# enforce-rpi-cycle 와 enforce-rpi-bash 가 공유 (로직 drift 방지).
# cycle-23 D-LIFECYCLE: 명시 Status(active|in_progress)만 인정 — checkbox-fallback 제거
# (Status 없는 plan이 게이트를 영구 개방하던 stale-active 경로 봉쇄. seal #27 + session-start 표면과 3중.)
has_active_plan() {
  local cwd="${1:-.}"
  local plan_dir="$cwd/docs/superpowers/plans"
  [ -d "$plan_dir" ] || return 1
  local plan
  for plan in "$plan_dir"/*.md; do
    [ -f "$plan" ] || continue
    case "$(plan_status "$plan")" in
      active|in_progress) printf '%s' "$plan"; return 0 ;;
    esac
  done
  return 1
}
```

- [x] **Step 2: GREEN 확인** — `bash ~/.claude/hooks/tests/run-all.sh` → 104/105 포함 100% (기존 09~12·15·27·35 등 명시-Status fixture는 모두 그대로 통과). ✓ 실측 98/98.
- [x] **Step 3: Commit** — `9b34bd1` (1.2~1.4 묶음, 명시 staging)

### Task 1.5: 차단 메시지 자기-설명 (표면 ③)

**Files:**
- Modify: `hooks/enforce-rpi-cycle.sh:95-100` (no-active-plan 차단 heredoc)
- Modify: `hooks/enforce-rpi-bash.sh:44-48` (동일)

- [x] **Step 1: enforce-rpi-cycle 메시지** — heredoc을 다음으로 교체:

```bash
cat >&2 <<EOF
[rpi] 차단: 활성 plan 없음 (docs/superpowers/plans/*.md).
  start-rpi-cycle을 사용해 R→P 단계를 먼저 완료하세요.
  ※ plan은 head-20에 명시 헤더 필요: **Status:** active (미체크 박스만으론 active 아님 — cycle-23)
  trivial 변경(≤5라인) 또는 docs 변경은 자동 허용.
  명시 우회: export RPI_SKIP="<이유>"
EOF
```

- [x] **Step 2: enforce-rpi-bash 메시지** — heredoc 마지막 줄 위에 한 줄 추가:

```bash
  ※ plan은 head-20에 **Status:** active 명시 필요 (cycle-23)
```

- [x] **Step 3: 확인** — `bash ~/.claude/hooks/tests/run-all.sh` → 100% (exit 코드 불변, 메시지만 변경). ✓ 실측 98/98.

### Task 1.6: RED→GREEN — session-start-audit active plan 상시 표시 (표면 ②)

**Files:**
- Modify: `hooks/tests/run-all.sh` (test_ssa 신설 — test_vlw 블록 아래)
- Modify: `hooks/tests/cases.tsv`
- Modify: `hooks/session-start-audit.sh` (`source` 줄 아래 삽입)

- [x] **Step 1: RED — 케이스 작성** (run-all.sh, verify-loop-watch 블록 뒤):

```bash
# ==================== CYCLE-23: SESSION-START-AUDIT plan 상시 표시 ====================
# 주의: 기존 test_ssa()(exit-code 기반, run-all.sh:486 인근)와 별개 함수 — 섀도잉 방지 위해 test_ssap 로 명명.
test_ssap() {
  local name="$1"; local want="$2"; local input="$3"   # want: stderr 기대 부분문자열 | noplanline
  TOTAL=$((TOTAL+1))
  local err; err=$(echo "$input" | "$HOOKS/session-start-audit.sh" 2>&1 >/dev/null)
  local good=0
  if [ "$want" = "noplanline" ]; then
    echo "$err" | grep -q '^\[plan\]' || good=1
  else
    echo "$err" | grep -qF "$want" && good=1
  fi
  [ "$good" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$name (want=$want)")
}
ssap_ev() { printf '{"session_id":"s","cwd":"%s"}' "$1"; }
SSA0="$SCRATCH/ssa0"; mkdir -p "$SSA0/docs/superpowers/plans"
test_ssap "106-zero-active" "[plan] active plan: 0" "$(ssap_ev "$SSA0")"
SSA1="$SCRATCH/ssa1"; mkdir -p "$SSA1/docs/superpowers/plans"
printf '# p\n**Status:** active\n' > "$SSA1/docs/superpowers/plans/a.md"
test_ssap "107-one-active" "a.md" "$(ssap_ev "$SSA1")"
SSA2="$SCRATCH/ssa2"; mkdir -p "$SSA2/docs/superpowers/plans"
printf '# p\n**Status:** active\n' > "$SSA2/docs/superpowers/plans/a.md"
printf '# q\n**Status:** in_progress\n' > "$SSA2/docs/superpowers/plans/b.md"
test_ssap "108-multi-active-warn" "stale-active" "$(ssap_ev "$SSA2")"
SSA3="$SCRATCH/ssa3"; mkdir -p "$SSA3"
test_ssap "109-no-plans-dir-silent" "noplanline" "$(ssap_ev "$SSA3")"
```

cases.tsv 말미:

```
session-start-audit	106-zero-active	alert	gen_ssa_zero
session-start-audit	107-one-active	alert	gen_ssa_one
session-start-audit	108-multi-active-warn	alert	gen_ssa_multi
session-start-audit	109-no-plans-dir-silent	silent	gen_ssa_nodir
```

run-all 실행 → 106~108 **FAIL** 확인 (hook이 아직 stdin/cwd를 안 읽음). ✓ 실측 RED: 99/102 (106·107·108 FAIL).

- [x] **Step 2: GREEN — hook 구현** (session-start-audit.sh, `source` 줄 바로 아래 삽입):

```bash
# --- D-LIFECYCLE 표면 ②: active plan 상시 1줄 (cwd 기준; stale-active 즉시 가시화, cycle-23) ---
INPUT=$(read_input)
CWD=$(echo "$INPUT" | resolve_cwd) || CWD=""
if [ -n "$CWD" ] && [ -d "$CWD/docs/superpowers/plans" ]; then
  ACT_N=0; ACT_NAMES=""
  for p in "$CWD/docs/superpowers/plans"/*.md; do
    [ -f "$p" ] || continue
    case "$(plan_status "$p")" in
      active|in_progress) ACT_N=$((ACT_N+1)); ACT_NAMES="$ACT_NAMES $(basename "$p")" ;;
    esac
  done
  if (( ACT_N > 1 )); then
    echo "[plan] ⚠ active plan ${ACT_N}개(≤1 기대):$ACT_NAMES — stale-active 정리 필요 (Status: completed로)" >&2
  elif (( ACT_N == 1 )); then
    echo "[plan] active plan: 1 —$ACT_NAMES" >&2
  else
    echo "[plan] active plan: 0" >&2
  fi
fi
```

- [x] **Step 3: GREEN 확인** — run-all 100%. ✓ 실측 102/102.
- [x] **Step 4: Commit** — `36d796d` (1.5~1.6 묶음, 명시 staging)

### Task 1.7: seal #27 — plan lifecycle 봉인 (표면 ①)

**Files:**
- Modify: `setup/verify-setup.sh` (#25 블록 뒤, summary 위)
- Modify: `README.md:278` (PASS 카운트 61→62)

- [x] **Step 1: RED — seal 추가 후 일부러 검증** (verify-setup.sh #25 뒤):

```bash
# 27. plan lifecycle 봉인 (D-LIFECYCLE, cycle-23): 모든 plans/*.md 명시 Status 보유 + active ≤ 1.
#     Closeout step-2(Status flip) silent-skip이 게이트를 영구 개방하던 stale-active 재발 방지.
#     (#26은 미채택·번호 소각 — spec-count parity, 안정 앵커 부재.)
NOSTAT27=""; ACT27=0
for p27 in "$HOME/.claude/docs/superpowers/plans"/*.md; do
  [ -f "$p27" ] || continue
  ST27=$(head -20 "$p27" | grep -m1 -iE '^\*?\*?status:?\*?\*?' \
    | sed -E 's/^\*?\*?[Ss]tatus:?\*?\*?[[:space:]]*//' | awk '{print tolower($1)}' | tr -d '*')
  [ -z "$ST27" ] && NOSTAT27="$NOSTAT27 $(basename "$p27")"
  case "$ST27" in active|in_progress) ACT27=$((ACT27+1)) ;; esac
done
if [ -z "$NOSTAT27" ] && [ "$ACT27" -le 1 ]; then
  ok "plan lifecycle: 전 plan 명시 Status + active=$ACT27 (≤1)"
else
  fail "plan lifecycle drift: Status 없는 plan:${NOSTAT27:-없음} / active=$ACT27 (stale-active 의심 — Closeout step-2 누락?)"
fi
```

RED 검증: `printf '# t\n- [ ] x\n' > /tmp/_seal27_probe.md && cp /tmp/_seal27_probe.md ~/.claude/docs/superpowers/plans/zz-probe.md && bash ~/.claude/setup/verify-setup.sh; rm ~/.claude/docs/superpowers/plans/zz-probe.md` → probe가 있을 때 #27 **FAIL**, 제거 후 PASS=62 확인. ✓ 실측 RED: probe 존재 시 `✗ plan lifecycle drift: zz-probe.md` / 제거 후 `✓ active=1 (≤1)`.

- [x] **Step 2: README PASS 카운트** — `README.md:278` "현재 61 PASS" → "현재 62 PASS".
- [x] **Step 3: README cases 카운트** — `README.md:272,500`의 "96 case/케이스" → 실측값(`grep -vcE '^[[:space:]]*(#|$)' ~/.claude/hooks/tests/cases.tsv` = 102)으로 갱신. (#20 seal이 검증 — 실제로 #20이 RED로 잡아낸 뒤 갱신함.)
- [x] **Step 4: 세션 종료 절차** (공통 절차 — 3게이트 green) 후 Commit: ✓ 실측 102/102 · PASS=62 FAIL=0 · PASS=8 FAIL=0 · has_active_plan=cycle-23 1개.

```bash
git add -A && git commit -m "feat(rpi): seal #27 plan-lifecycle (전 plan 명시 Status + active≤1) — 61→62 PASS (cycle-23 S1)"
```

---

# SESSION S2 — D-SIDEDOOR-2: redirect-targets 확장 + 보수차단

### Task 2.1: RED — lib 케이스 작성 (dd/install/rsync/matchAll/apply/patch)

**Files:**
- Modify: `hooks/tests/run-all.sh` (`101-cp-doc` test_lib 줄 아래)
- Modify: `hooks/tests/cases.tsv`

- [x] **Step 1: lib 케이스 추가**: ✓ run-all.sh:511(101-cp-doc) 뒤 삽입.

```bash
# cycle-23 D-SIDEDOOR-2: dd/install/rsync/다중 cp·mv(matchAll)/git apply·patch(보수차단 sentinel)
test_lib "110-dd-code"          "x.sh"            "$(CMD='dd if=/dev/zero of=x.sh bs=1' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "111-install-code"     "b.py"            "$(CMD='install -m 755 a b.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "112-rsync-code"       "d.js"            "$(CMD='rsync -a s.txt d.js' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "113-multi-cpmv-2nd"   "d.py"            "$(CMD='cp a b.md; mv c d.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "114-git-apply"        "__PATCH_APPLY__" "$(CMD='git apply fix.patch' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "115-git-apply-check"  ""                "$(CMD='git apply --check fix.patch' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "116-patch-cmd"        "__PATCH_APPLY__" "$(CMD='patch -p1 < fix.patch' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "117-rsync-dir-pass"   ""                "$(CMD='rsync -a src/ dst/' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
```

- [x] **Step 2: erb 통합 케이스 추가** (`105-heredoc-checkbox-only` 아래):

```bash
test_erb "118-git-apply-noplan" 2 "$(mk_bash_event 'git apply fix.patch' "$NP")"
test_erb "119-git-apply-plan"   0 "$(mk_bash_event 'git apply fix.patch' "$WP")"
test_erb "120-patch-noplan"     2 "$(mk_bash_event 'patch -p1 < f.patch' "$NP")"
```

- [x] **Step 3: cases.tsv 말미 추가**:

```
hooks-lib	110-dd-code	output	gen_lib_110
hooks-lib	111-install-code	output	gen_lib_111
hooks-lib	112-rsync-code	output	gen_lib_112
hooks-lib	113-multi-cpmv-2nd	output	gen_lib_113
hooks-lib	114-git-apply	output	gen_lib_114
hooks-lib	115-git-apply-check	output	gen_lib_115
hooks-lib	116-patch-cmd	output	gen_lib_116
hooks-lib	117-rsync-dir-pass	output	gen_lib_117
enforce-rpi-bash	118-git-apply-noplan	2	gen_erb_gitapply
enforce-rpi-bash	119-git-apply-plan	0	gen_erb_gitapply_plan
enforce-rpi-bash	120-patch-noplan	2	gen_erb_patch
```

- [x] **Step 4: RED 확인** — run-all → 110~120 **FAIL** (113은 첫 cp만 매칭, 나머지는 패턴 부재). ✓ 실측 RED: 105/113 (110·111·112·113·114·116·118·120 FAIL — 115·117·119는 통과-기대 케이스라 RED 대상 아님).

### Task 2.2: GREEN — redirect-targets.js 어댑터 추가

**Files:**
- Modify: `hooks/lib/redirect-targets.js`

- [x] **Step 1: 헤더 주석 갱신** — 탐지 경로 목록에 `5) dd of= / install / rsync  6) git apply·patch → __PATCH_APPLY__ sentinel(보수차단, --check/--stat류 제외)` 추가.
- [x] **Step 2: 보수차단 sentinel** — `const targets = [];` 줄 바로 아래 삽입 (최우선 단락):

```js
// 0) git apply / patch — 쓰기 대상이 패치 '내용'에 있어 명령행 추출 불가 → 보수차단 sentinel.
//    read-only 변형(--check/--stat/--numstat/--summary)·docs 전용 패치 오탐은 RPI_SKIP 탈출구로 수용 (cycle-23 D-SIDEDOOR-2).
if (/(^\s*|[;&|()]\s*)git\s+apply\b/.test(cmd) && !/--(check|stat|numstat|summary)\b/.test(cmd)) {
  process.stdout.write("__PATCH_APPLY__"); process.exit(0);
}
if (/(^\s*|[;&|()]\s*)patch\b/.test(cmd)) {
  process.stdout.write("__PATCH_APPLY__"); process.exit(0);
}
```

- [x] **Step 3: cp/mv 블록을 matchAll로 교체** (기존 `3)` 블록 전체 대체):

```js
// 3) cp / mv SRC DST : 마지막 비옵션 인자(목적지) — 명령 내 모든 cp/mv 검사 (matchAll, cycle-23)
{
  for (const mcp of cmd.matchAll(/\b(?:cp|mv)\b([^|;&]*)/g)) {
    const args = mcp[1].split(/\s+/).filter(t => t && !t.startsWith("-"));
    if (args.length >= 1) targets.push(args[args.length - 1].replace(/^["']|["']$/g, ""));
  }
}
```

- [x] **Step 4: dd / install / rsync 어댑터** — `4) python` 블록 아래 삽입:

```js
// 5) dd of=FILE
{
  const mdd = cmd.match(/\bdd\b[^|;&]*\bof=("?)([^\s">|;&()]+)\1/);
  if (mdd) targets.push(mdd[2]);
}
// 6) install / rsync SRC DST : 마지막 비옵션 인자 (디렉터리 타깃은 코드-ext 비매칭으로 자연 통과)
{
  for (const mi of cmd.matchAll(/\b(?:install|rsync)\b([^|;&]*)/g)) {
    const args = mi[1].split(/\s+/).filter(t => t && !t.startsWith("-"));
    if (args.length >= 2) targets.push(args[args.length - 1].replace(/^["']|["']$/g, ""));
  }
}
```

- [x] **Step 5: GREEN 확인** — run-all → 110~117 통과, 118~120은 아직 FAIL 가능(erb가 sentinel을 모름 → Task 2.3). ✓ 실측: 113/113 — 118~120도 즉시 GREEN (sentinel이 has_active_plan 선행 검사·기존 차단 경로(exit 2)와 그대로 맞물림; 2.3의 분기는 메시지 차별화).

### Task 2.3: GREEN — enforce-rpi-bash sentinel 처리 + 메시지

**Files:**
- Modify: `hooks/enforce-rpi-bash.sh:34-49`

- [x] **Step 1: sentinel 분기** — `[ -z "$TARGET" ] && exit 0` 줄과 has_active_plan 블록 사이에 차단 메시지 분기 추가; 최종 차단 heredoc을 TARGET 종류에 따라 분기:

```bash
# 코드 작성 의도 없음 → 통과
[ -z "$TARGET" ] && exit 0

# 코드 파일을 셸로 작성하려 함 (또는 patch/apply 보수차단) → active plan 필요
if ACTIVE=$(has_active_plan "$CWD"); then
  hook_log "enforce-rpi-bash" "$TARGET" "PASS" "plan=$(basename "$ACTIVE")"
  exit 0
fi

if [ "$TARGET" = "__PATCH_APPLY__" ]; then
  hook_log "enforce-rpi-bash" "git-apply/patch" "BLOCK" "no-active-plan-conservative"
  cat >&2 <<EOF
[rpi-bash] 차단(보수): git apply/patch는 쓰기 대상이 패치 내용에 있어 추출 불가 → active plan 필요.
  docs 전용 패치 등 오탐이면: export RPI_SKIP="<이유>"
  ※ plan은 head-20에 **Status:** active 명시 필요 (cycle-23)
EOF
  exit 2
fi

hook_log "enforce-rpi-bash" "$TARGET" "BLOCK" "no-active-plan"
cat >&2 <<EOF
[rpi-bash] 차단: 셸로 코드 파일 작성 감지 → $TARGET
  Write/Edit 우회 경로(>, >>, tee, heredoc, sed -i, cp/mv, dd, install, rsync)로 코드를 쓰려면 active plan이 필요합니다.
  start-rpi-cycle 로 R→P 완료 후 진행하거나, 명시 우회: export RPI_SKIP="<이유>"
  ※ plan은 head-20에 **Status:** active 명시 필요 (cycle-23)
EOF
exit 2
```

(주의: 기존 구조는 has_active_plan 검사가 차단보다 먼저 — 위 교체본도 동일 순서 유지. S1의 Task 1.5에서 넣은 erb 메시지 줄은 이 교체본에 흡수됨.)

- [x] **Step 2: GREEN 확인** — run-all 100% (118~120 포함). ✓ 실측 113/113 + 보수차단 의미론 실측: `git apply x.patch`(no plan)→rc=2 "[rpi-bash] 차단(보수)" / `git apply --check x.patch`→rc=0.
- [x] **Step 3: SECURITY.md 잔여 위험 갱신** — `SECURITY.md:31` "한계" 절 아래에 추가: ✓ "## enforce-rpi-bash 보수차단 / 잔여 (cycle-23)" 절 신설(보수차단 의미론 + 미탐지 잔여).

```markdown
- **enforce-rpi-bash 보수차단/잔여**: `git apply`/`patch`는 타깃 추출 불가라 plan 부재 시 명령 단위로 차단(보수) — docs 전용 패치 오탐은 `RPI_SKIP`으로 우회. 여전히 미탐지: 변수 파일명(`python -c` f-string), `./patch` 같은 상대경로 실행, 인터프리터 내부 쓰기. 시그니처 기반 1차 방어선의 의식된 상한.
```

- [x] **Step 4: README 갱신** — `README.md:340` 인근(앵커: "### Bash 명령이 차단됨") 트러블슈팅 절에 `sed -i, cp/mv, dd, install, rsync, git apply/patch(보수)` 열거 갱신; `README.md:272,500` cases 카운트 → 실측(113)으로. hook 표(`README.md:34`) enforce-rpi-bash 행의 탐지 목록도 동일 열거로 갱신. ✓ (병행 세션이 README에 statusline skill 노트를 추가해 줄번호 +3 이동 — 앵커 텍스트로 적용.)
- [x] **Step 5: 세션 종료 절차** 후 Commit: ✓ 실측 113/113 · PASS=62 FAIL=0 · PASS=8 FAIL=0.

```bash
git add -A && git commit -m "feat(rpi): Bash 사이드도어 확장 봉인 — dd/install/rsync/cp·mv matchAll + git apply·patch 보수차단 (cycle-23 S2)"
```

---

# SESSION S3 — D-FAILOPEN-SURFACE + D-INSTALL

### Task 3.1: session-start-audit hook 자가점검 (알림형)

**Files:**
- Modify: `hooks/session-start-audit.sh` (Task 1.6 블록 아래 삽입)

- [x] **Step 1: 구현**: ✓ 실측: D-LIFECYCLE 블록 fi 뒤·CLAUDE_MD= 앞 삽입 (plan 코드 그대로).

```bash
# --- D-FAILOPEN-SURFACE: 차단 hook 자가점검 (알림형 — fail-open은 유지, 고장만 표면화, cycle-23) ---
SELFCHECK_BAD=""
command -v node >/dev/null 2>&1 || SELFCHECK_BAD=" node-missing"
for hf in "$HOME/.claude/hooks/"*.sh; do
  bash -n "$hf" 2>/dev/null || SELFCHECK_BAD="$SELFCHECK_BAD syntax:$(basename "$hf")"
  [ -x "$hf" ] || SELFCHECK_BAD="$SELFCHECK_BAD nonexec:$(basename "$hf")"
done
if [ -n "$SELFCHECK_BAD" ]; then
  hook_log "session-start-audit" "hook-selfcheck" "ALERT" "$SELFCHECK_BAD"
  echo "[hook-selfcheck] ⚠ 차단 hook fail-open 위험:$SELFCHECK_BAD — bash ~/.claude/setup/doctor.sh 로 점검" >&2
fi
```

- [x] **Step 2: 수동 검증(RED→GREEN 대체 — live hooks 디렉터리 fixture화 불가)** — ① 정상: `echo '{"cwd":"/tmp"}' | bash ~/.claude/hooks/session-start-audit.sh` → `[hook-selfcheck]` 미출력. ② 고장 시뮬: `printf '#!/bin/bash\nif [ x\n' > /tmp/bad.sh && cp /tmp/bad.sh ~/.claude/hooks/zz-bad-probe.sh && echo '{"cwd":"/tmp"}' | bash ~/.claude/hooks/session-start-audit.sh; rm ~/.claude/hooks/zz-bad-probe.sh` → `syntax:zz-bad-probe.sh` 출력 확인. (probe 정리 필수 — verify-setup #24가 잡아주는 것도 함께 확인하면 보너스.) ✓ 실측 RED(구현 전): probe 주입에도 selfcheck 줄 0건 → GREEN(구현 후): ① 정상 시 미출력 ② probe 주입 시 `[hook-selfcheck] ⚠ 차단 hook fail-open 위험: syntax:zz-bad-probe.sh` 출력, probe 즉시 rm(잔존 0).

### Task 3.2: verify-setup #28 — bash -n 문법 게이트

**Files:**
- Modify: `setup/verify-setup.sh` (#27 뒤)
- Modify: `README.md:278` (62→63 PASS)

- [x] **Step 1: 구현**: ✓ 실측: #27 블록 fi 뒤·summary echo 앞 삽입 (plan 코드 그대로).

```bash
# 28. hooks/*.sh + setup/*.sh bash -n 문법 (fail-open 무표면 방지, D-FAILOPEN-SURFACE cycle-23)
SYN28=""
for f28 in "$HOME/.claude/hooks/"*.sh "$HOME/.claude/setup/"*.sh; do
  bash -n "$f28" 2>/dev/null || SYN28="$SYN28 $(basename "$f28")"
done
[ -z "$SYN28" ] && ok "bash -n: hooks+setup 문법 OK" || fail "bash -n 실패:$SYN28"
```

- [x] **Step 2: 확인** — verify-setup → PASS=63 FAIL=0. README:278 갱신(63 PASS). ✓ 실측: `✓ bash -n: hooks+setup 문법 OK` + `verify-setup: PASS=63 FAIL=0`; README:280("현재 62 PASS"→63 — 병행 statusline 노트로 :278→:280 밀림).

### Task 3.3: install.sh 3결함 수정

**Files:**
- Modify: `setup/install.sh:50-76` (REQUIRED), `:85` (카운트 echo), `:101-110` (병합), `:135` (stale 문구)

- [x] **Step 1: REQUIRED 목록** — `session-start-audit.sh` 줄 아래 `"$TARGET/hooks/surface-constitution.sh"` 추가; line 85 echo `"  ✓ 25개 필수 파일 모두 존재"` → `"  ✓ ${#REQUIRED[@]}개 필수 파일 모두 존재"` (하드코딩 제거 — 재드리프트 봉쇄). ✓ 실측: REQUIRED 26개, live tree 26/26 존재.
- [x] **Step 2: hooks 병합 — 사용자 커스텀 보존** (node 블록 교체): ✓ 실측: plan 코드 그대로 교체.

```js
const fs = require("fs");
const HOME = process.env.HOME_DIR;
const cur = JSON.parse(fs.readFileSync(HOME + "/.claude/settings.json", "utf8"));
const tpl = JSON.parse(fs.readFileSync(HOME + "/.claude/settings.example.json", "utf8"));
// 하네스 hook(~/.claude/hooks/*.sh 경로)만 템플릿 기준으로 교체. 사용자 커스텀 hook 항목은 보존.
const isHarness = h => /\.claude\/hooks\/[^/]+\.sh/.test(String((h||{}).command||""));
const merged = {};
for (const ph of new Set([...Object.keys(cur.hooks||{}), ...Object.keys(tpl.hooks||{})])) {
  const userKept = (cur.hooks?.[ph]||[])
    .map(e => ({...e, hooks:(e.hooks||[]).filter(h => !isHarness(h))}))
    .filter(e => (e.hooks||[]).length > 0);
  merged[ph] = [...(tpl.hooks?.[ph]||[]), ...userKept];
}
cur.hooks = merged;
if (!cur.permissions) cur.permissions = tpl.permissions;
fs.writeFileSync(HOME + "/.claude/settings.json", JSON.stringify(cur, null, 2));
console.log("  ✓ hooks 병합 (하네스 hook 갱신 + 사용자 커스텀 hook 보존)");
```

- [x] **Step 3: stale 문구** — line 135 `"hook 8개(9개 등록 항목)가"` → `"하네스 hook들이"` (숫자 제거 — 카운트 재드리프트 원천 차단). ✓ 실측: 적용.
- [x] **Step 4: 검증** — ① `bash -n setup/install.sh` ② 병합 시뮬: settings.json을 /tmp에 복사 + 가짜 커스텀 hook 추가 → HOME_DIR 가리켜 node 블록만 단독 실행 → 커스텀 보존 + 하네스 hook 템플릿화 확인 ③ **live settings.json은 건드리지 않음** (시뮬은 /tmp 사본에서만). ✓ 실측: bash -n OK; mktemp fakehome 시뮬 7-assert ALL PASS(혼합 entry 커스텀 보존·전용 phase 보존·env 보존·하네스 중복 0·surface-constitution 유입·하네스만 필터·live mtime 불변 — fakehome settings.json은 시크릿 없는 합성 fixture, live는 미접촉).

### Task 3.4: doctor.test.sh 수리 + verify-all 편입

**Files:**
- Modify: `setup/tests/doctor.test.sh:22-24` (Test 4)
- Modify: `setup/verify-all.sh` (STAGE 1 뒤)

- [x] **Step 1: Test 4 수정**: ✓ 실측 RED(수정 전): `FAIL: no backup directory created` exit=1 → plan 코드로 교체.

```bash
# Test 4: backup — git-managed 홈에선 doctor가 백업을 만들지 않음(의도) → SKIP. 비-git만 검사.
if [ -d "$HOME/.claude/.git" ]; then
  echo "SKIP: backup test (git-managed home — doctor skips backup by design)"
else
  ls -d "$HOME"/.claude.backup-* > /dev/null 2>&1 || \
    { echo "FAIL: no backup directory created"; exit 1; }
fi
```

- [x] **Step 2: verify-all 편입** — STAGE 1(doctor)과 STAGE 2 사이에: ✓ 실측: STAGE 1b 삽입.

```bash
echo
echo "=== STAGE 1b: doctor self-test ==="
bash "$HOME/.claude/setup/tests/doctor.test.sh" || { echo "FAIL doctor.test"; exit 1; }
```

- [x] **Step 3: 확인** — `bash ~/.claude/setup/tests/doctor.test.sh` → PASS(+SKIP 줄). `bash ~/.claude/setup/verify-all.sh` → ALL PASS. ✓ 실측 GREEN: `SKIP: backup test (git-managed home …)` + `PASS: all doctor.sh tests` exit=0; verify-all(STAGE 1→1b→2→3→4) `ALL PASS — system meets §6.6 acceptance gate.` exit=0. 부수 변이: doctor가 CLAUDE.md audit 마커 1줄 갱신(06-05→06-12, diff 1줄뿐 — 커밋 포함) + setup/.installed 재생성(추적 파일이나 빈 내용 동일 → diff 0).

### Task 3.5: doctor — superpowers skill 존재 알림 + hooks/.log 프루닝

**Files:**
- Modify: `setup/doctor.sh` (#20 grill 블록 뒤에 신규 체크 2개)

- [x] **Step 1: superpowers 필수 skill 체크** (WARN-only — upstream 의존이라 차단 아님): ✓ 실측: 삽입, 4 skill 모두 plugins/cache 존재 → `✓ superpowers skills` PASS.

```bash
# 20b. superpowers 필수 skill (start-rpi-cycle Phase R/P/I 의존) — plugins/cache 존재 알림
SP_MISS=""
for sk in brainstorming writing-plans executing-plans subagent-driven-development; do
  ls "$CLAUDE_HOME"/plugins/cache/*/superpowers/*/skills/"$sk"/SKILL.md >/dev/null 2>&1 || SP_MISS="$SP_MISS $sk"
done
if [ -z "$SP_MISS" ]; then
  check "superpowers skills" "PASS" ""
else
  check "superpowers skills" "WARN" "미설치:$SP_MISS — /plugin install superpowers@claude-plugins-official"
fi
```

- [x] **Step 2: hooks/.log 프루닝** (최근 6개월 유지 + stray `.log` 제거): ✓ 실측: 삽입, 첫 실행에서 stray `.log` 제거 + 월파일 2개(2026-05/06)라 프루닝 0건 → `✓ hook log rotation — ≤6 month files` (기대 경로 그대로).

```bash
# 20c. hooks/.log 로테이션 — 월파일 최근 6개 유지 + stray '.log' 제거
LOGDIR="$CLAUDE_HOME/hooks/.log"
if [ -d "$LOGDIR" ]; then
  rm -f "$LOGDIR/.log" 2>/dev/null || true
  OLD_LOGS=$({ ls -t "$LOGDIR"/*.log 2>/dev/null || true; } | tail -n +7)
  if [ -n "$OLD_LOGS" ]; then
    N_RM=$(printf '%s\n' "$OLD_LOGS" | wc -l)
    printf '%s\n' "$OLD_LOGS" | while read -r lf; do rm -f "$lf"; done
    check "hook log rotation" "PASS" "pruned $N_RM old month file(s), kept 6"
  else
    check "hook log rotation" "PASS" "≤6 month files"
  fi
fi
```

- [x] **Step 3: 확인** — `bash ~/.claude/setup/doctor.sh` → 신규 2 체크 PASS/WARN 표시, exit 0. **주의: #24 seal(REQUIRED_HOOKS ⊇ hooks/*.sh)은 doctor.sh 수정과 무관하게 green 유지 확인.** ✓ 실측: doctor PASS=35 WARN=2 FAIL=0 exit=0(신규 2 체크 모두 PASS); verify-setup PASS=63 FAIL=0 — #24 포함 전 seal green.
- [x] **Step 4: 세션 종료 절차** 후 Commit: ✓ 실측: run-all 113/113 · verify-setup PASS=63 FAIL=0 · verify-integration PASS=8 · verify-all ALL PASS(STAGE 1b 포함). 커밋은 git add -A 대신 명시 staging(무관 변경 skills/ui-design/design.md·plugins/ 제외 — 커밋 위생).

```bash
git add -A && git commit -m "feat(harness): fail-open 자가점검(#28+selfcheck) + install.sh 3결함 + doctor.test 수리·편입 + doctor skill/log 체크 (cycle-23 S3)"
```

---

# SESSION S4 — D-TDD-VERBATIM + 부수 정정 + Closeout

### Task 4.1: start-rpi-cycle (d) TDD-verbatim 규칙

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md` (Phase I 옵션 (d) 블록 — "검증 기준 명시" ※줄 아래)

- [ ] **Step 1: 삽입** ((d)의 `※ **검증 기준 명시:**` 단락 바로 아래):

```markdown
      ※ **TDD-verbatim (cycle-23):** stage1 프롬프트에는 plan task 본문(TDD 5-step 체크박스·코드블록 포함)을
        **verbatim 전달** — 요약·재서술 금지(요약은 RED→GREEN 단계를 증발시킴; plan이 유일한 TDD carrier).
        stage2 success_criteria에 "stage1 보고에 RED 증거(실패 출력)와 GREEN 증거(통과 출력)가 모두 없으면 FAIL" 명시.
```

- [ ] **Step 2: 골격 보존 확인** — `printf '%s' "$(cat ~/.claude/skills/start-rpi-cycle/SKILL.md)" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const o={tool_name:"Write",tool_input:{file_path:"/x/skills/s/SKILL.md",content:d},cwd:"/x"};console.log(JSON.stringify(o))})' | node ~/.claude/hooks/lib/skeleton-scan.js` → `1 3 1 1` 이상(marker/phase≥3/agent≥1/protocol=1). verify-setup #17/#18/#19/#22도 green이어야 함.

### Task 4.2: 부수 정정 일괄

**Files:**
- Modify: `agents/review-strict.md:8,10,12` ("9개"×3 → 13)
- Modify: `docs/superpowers/cycle-17-goal.md` (상단 은퇴 노트)
- Modify: `settings.example.json` (statusLine 블록)
- Modify: `README.md` (구조 트리 + enforce-rpi-cycle 행)

- [ ] **Step 1: review-strict 9→13** — 세 줄에서 "9개 파일"→"13개 파일" (`bootstrap 9개 파일이`, `산출물 9개 파일 존재`, `9개 파일 모두 존재`). 근거: cycle-19 SSOT(13 files)·execute-strict.md:8과 정합.
- [ ] **Step 2: cycle-17-goal.md 은퇴 노트** — 파일 최상단(`# cycle-17` 제목 바로 아래)에 삽입:

```markdown
> **[retired 2026-06-12 / cycle-23 — genesis-record]** 역사 기록. F2~F12는 cycle-17(84ad5a7)에서 구현 완료.
> next-cycle-goal 핸드오프는 이후 start-rpi-cycle Communication Protocol 고유 필수 필드(+seal #18)로 이관 —
> 이 파일은 그 필드의 1회성 파일화 선례로만 보존(본문 카운트는 당시 실측, 현재 SSOT 아님).
```

- [ ] **Step 3: settings.example.json statusLine** — 최상위 키로 추가(hooks 키 위), live settings.json과 동형:

```json
"statusLine": {
  "type": "command",
  "command": "bash $HOME/.claude/statusline.sh",
  "padding": 0
},
```

(#23 parity는 hook command basename만 비교 — statusLine 추가 무영향. 추가 후 `node -e 'JSON.parse(require("fs").readFileSync(process.env.HOME+"/.claude/settings.example.json","utf8"))'`로 JSON 유효성 확인.)

- [ ] **Step 4: README 구조 트리 등재** — `README.md:302-307` 인근(CLAUDE.md~.gitignore 블록)에 4줄 추가:

```
├── CONTEXT.md                            하네스 도메인 용어집 (grill-with-docs 갱신)
├── statusline.sh                         상태줄 렌더러 (settings statusLine 배선)
├── state.schema.json                     state.json 스키마 (참조 문서)
├── SECURITY.md                           위협 모델 + 수락 잔여 위험
```

(tests/statusline/은 cycle-22 산출물 — 트리 `hooks/tests/` 인근에 `├── tests/statusline/ …` 1줄 추가. setup/tests/도 setup 블록에 1줄.)

- [ ] **Step 5: README hook 표 의미론 갱신** — `README.md:33` enforce-rpi-cycle 행 끝에 "active plan = head-20 `**Status:** active|in_progress` 명시 필수 (cycle-23)" 추가; `README.md:331` "차단" 트러블슈팅 절에 동일 안내 + "Closeout 후엔 plan Status를 completed로 — stale-active는 session-start 1줄·seal #27이 표면화" 추가.

### Task 4.2b: 수락 잔여 SECURITY.md 기록 (spec "수락 잔여" 절 이행)

**Files:**
- Modify: `SECURITY.md` (S2에서 추가한 "enforce-rpi-bash 보수차단/잔여" 불릿 아래)

- [ ] **Step 1: 검증-커버리지 수락 잔여 3건 추가**:

```markdown
- **검증 커버리지 수락 잔여 (cycle-23)**: ① verify-setup #23은 hook command *basename*만 비교 — matcher 정규식 drift 미감지(안정 앵커 확보 시 재평가) ② `state.schema.json`은 검증자 없는 참조 문서 ③ verify-all에서 doctor(변이)가 선행해 `.installed`·audit-marker를 측정 전 자가치유 — 치료-후-검증 순서로 의도 수락.
```

### Task 4.3: 문서·카운트 최종 정합 + 전체 게이트

- [ ] **Step 1: 카운트 최종 실측 반영** — cases 실측(`grep -vcE '^[[:space:]]*(#|$)' hooks/tests/cases.tsv` = 113 예상) ↔ README:272,500; verify-setup PASS(63) ↔ README:278. (#20·#21 seal이 자가검증.)
- [ ] **Step 2: 3게이트 + verify-all** — `bash ~/.claude/setup/verify-all.sh` → `ALL PASS`.
- [ ] **Step 3: Commit**:

```bash
git add -A && git commit -m "docs(harness): TDD-verbatim(d) + review-strict 13 + 레지스트리 정합 + cycle-17-goal 은퇴 (cycle-23 S4)"
```

### Task 4.4: Closeout (start-rpi-cycle Phase Closeout 절차)

- [ ] **Step 1: Step C-0** — remote/gh/branch 조건 확인 (master 직커밋 워크플로면 WARN 기록 후 C-1).
- [ ] **Step 2: Step C-1 drift review** — review-strict로 사이클 마감 점검 (CONTEXT.md 신규 — 반영 확인; spec Revision 섹션 반영 확인; plan 체크박스 전부 [x]).
- [ ] **Step 3: 이 plan Status flip** — `**Status:** active` → `**Status:** completed`. (seal #27 활성 후 첫 정상 flip — flip 누락 시 다음 verify-setup이 FAIL로 잡는지가 곧 D-LIFECYCLE의 acceptance.)
- [ ] **Step 4: state.json** — cycle.count 22→23, last_completed_at/last_drift_check = 마감일.
- [ ] **Step 5: 보고 필수 필드** — harness-verify(`PASS=63 FAIL=0 (#17·#18·#19 green)` 실측), phase-skills(R: brainstorming=invoked, grill-with-docs=invoked, explore-strict=invoked / P: writing-plans=invoked / I: 세션별 선언 / Closeout: review-strict=invoked), next-cycle-goal(3라벨 — 열린 항목: 수락 잔여 목록 재평가 등).
- [ ] **Step 6: 최종 커밋** — `git add -A && git commit -m "docs(rpi): cycle-23 closeout — plan completed, state 23"`

---

## Acceptance (전체)

- run-all: 113/113 (96 + S1 6 + S2 11), cases.tsv↔run-all 1:1.
- verify-setup: PASS=63 FAIL=0 (#27 plan-lifecycle, #28 bash -n 신설; #17~#25 기존 green 유지).
- verify-integration: 8/8 (E2E.D 명시-Status fixture).
- `~/.claude`에서 enforce-rpi-cycle이 **다시 차단 가능** (cycle-23 plan completed 후: `echo '{"tool_name":"Write","tool_input":{"file_path":"'$HOME'/.claude/src/t.py","content":"a\nb\nc\nd\ne\nf"},"cwd":"'$HOME'/.claude"}' | bash ~/.claude/hooks/enforce-rpi-cycle.sh; echo $?` → 2).
- install.sh: 신선-클론 시뮬에서 surface-constitution 포함 전 파일 검출 + 커스텀 hook 보존 병합.

## 수락 잔여 (이 사이클에서 의도적으로 안 하는 것)

- verify-setup #23 basename-only 비교 유지(matcher drift 미감지 — 안정 앵커 시 재평가).
- state.schema.json 검증자 미도입(참조 문서).
- §1 stable-claude-md의 stderr 표면 유지(사용자-타이밍 관심사).
- ultracode (d)의 물리적 TDD 강제 불가(프롬프트 계약 상한 — F12 동급 수락).
