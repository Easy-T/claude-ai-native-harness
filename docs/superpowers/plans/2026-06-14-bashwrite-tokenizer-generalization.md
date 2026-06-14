# bash-write 토크나이저 일반화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox(`- [ ]`).

**Status:** completed
**RPI-Cycle:** 34
**Started:** 2026-06-14

**Goal:** `redirect-targets.js` 토크나이저에 `>&` 파일명 타깃 탐지 추가(NEW-redir-fd-amp 봉인, fd-number 자동 제외)하고, `_common.sh` plan_status awk 펜스 정규식을 `~~~`까지 확장(NEW-planstatus-tilde-fence 봉인). 6 대표 케이스 TDD, 기존 redirect/planstatus 무회귀.

**Architecture:** spec=`docs/superpowers/specs/2026-06-14-bashwrite-tokenizer-generalization-design.md`. 두 변경 모두 라이브 게이트 내부(redirect-targets.js=enforce-rpi-bash 의존, _common.sh=전 hook 공유) → TDD + 즉시 run-all 무회귀. cases.tsv↔run-all 정합(case_id 비주석 실재 + TOTAL==declared) 유지.

**Tech Stack:** node(JS 토크나이저), bash/awk.

> **커밋 정책:** working-tree 구현+검증만, commit/merge는 Closeout 사용자 승인까지 deferred(cycle-33과 동일).

---

## File Structure
- Modify `hooks/lib/redirect-targets.js:38-43` (op-감지에 `>&` 흡수).
- Modify `hooks/_common.sh:92` (awk 펜스 정규식 `(```|~~~)`).
- Modify `hooks/tests/cases.tsv` (6 케이스 추가).
- Modify `hooks/tests/run-all.sh` (6 test 호출 추가).

---

## Task 1: `>&` 파일명 타깃 탐지 (redirect-targets.js)

**Files:** Modify `hooks/lib/redirect-targets.js`, `hooks/tests/cases.tsv`, `hooks/tests/run-all.sh`

- [x] **Step 1: Write failing tests** — (1a) `cases.tsv`의 `enforce-rpi-bash 132-node-eval-noplan` 줄(현 135) **뒤**에 추가:

```
hooks-lib	140-redir-fdamp-code	output	gen_lib_140
hooks-lib	141-redir-fdamp-num-pass	output	gen_lib_141
hooks-lib	142-redir-2to1-pass	output	gen_lib_142
enforce-rpi-bash	143-fdamp-noplan	2	gen_erb_143
```

(1b) `run-all.sh`의 `test_lib "129-ruby-eval-code" ...`(현 541) **뒤**에 추가:

```bash
# cycle-34: >& 파일명 타깃 탐지 (fd-number 는 isCode 로 자연 제외)
test_lib "140-redir-fdamp-code"     "evil.py" "$(CMD='echo x >& evil.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "141-redir-fdamp-num-pass" ""        "$(CMD='ls foo >&2' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "142-redir-2to1-pass"      ""        "$(CMD='ls 2>&1' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
```

(1c) `run-all.sh`의 `test_erb "132-node-eval-noplan" ...`(현 333) **뒤**에 추가:

```bash
# cycle-34: >& 코드 파일 우회 E2E
test_erb "143-fdamp-noplan" 2 "$(mk_bash_event 'echo x >& evil.py' "$NP")"
```

- [x] **Step 2: Run to verify RED**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | grep -E '140-redir-fdamp-code|143-fdamp-noplan|/ 133 passed|Pass rate'`
Expected: Failures에 `hooks-lib/140-redir-fdamp-code (exp=[evil.py] got=[])` + `enforce-rpi-bash/143-fdamp-noplan (expected=2, got=0)`. 141·142는 통과(오탐0). 정합 OK(133 declared==133 run). 비공허 RED.

- [x] **Step 3: Implement** — `hooks/lib/redirect-targets.js:39-41` 의 op-감지 3줄을 교체:

기존:
```javascript
      let j = i + 1;
      if (cmd[j] === ">") j++;
      if (cmd[j] === "|") j++;
```
신규:
```javascript
      let j = i + 1;
      if (cmd[j] === ">") j++;
      if (cmd[j] === "|") j++;          // >| / >>|  noclobber
      else if (cmd[j] === "&") j++;     // >& / >>&  both-streams to file (fd-num targets filtered by isCode)
```

- [x] **Step 4: Run to verify GREEN(부분)**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | grep -E '140-redir|141-redir|142-redir|143-fdamp|passed'`
Expected: 140·141·142·143 실패 목록에서 사라짐. `133 / 133 passed`. (144·145는 아직 미추가.)

- [x] **Step 5: Stage (commit deferred)** — `git add hooks/lib/redirect-targets.js hooks/tests/cases.tsv hooks/tests/run-all.sh`

---

## Task 2: `~~~` 펜스 인식 (_common.sh plan_status)

**Files:** Modify `hooks/_common.sh`, `hooks/tests/cases.tsv`, `hooks/tests/run-all.sh`

- [x] **Step 1: Write failing tests** — (2a) `cases.tsv` 끝(현 `139-prose-status-noplan` 뒤)에 추가:

```
hooks-lib	144-planstatus-tilde-fence-skip	output	gen_lib_144
enforce-rpi-cycle	145-tilde-fence-noplan	2	gen_erc_145
```

(2b) `run-all.sh`의 `test_lib "138-planstatus-real-active" ...`(현 548) **뒤**에 추가:

```bash
# cycle-34: ~~~ (tilde) 펜스 내 active 누출 봉인
PS_TILDE=$(mktemp "$SCRATCH/ps-XXXXXX.md"); printf '# Plan\n~~~\n**Status:** active\n~~~\n**Status:** completed\n' > "$PS_TILDE"
test_lib "144-planstatus-tilde-fence-skip" "completed" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; plan_status "$1"' _ "$PS_TILDE")"
```

(2c) `run-all.sh`의 `test_erc "139-prose-status-noplan" ...`(현 337) **뒤**에 추가:

```bash
# cycle-34: ~~~-펜스 active 만 있는 plan → active 미인정 → 코드 Write 차단 (E2E)
TILDE="$SCRATCH/tilde"; mkdir -p "$TILDE/docs/superpowers/plans" "$TILDE/src"
printf '# Plan\n~~~\n**Status:** active\n~~~\n' > "$TILDE/docs/superpowers/plans/p.md"
test_erc "145-tilde-fence-noplan" 2 "$(mk_event Write "$TILDE/src/foo.ts" "$BIG" "$TILDE")"
```

- [x] **Step 2: Run to verify RED**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | grep -E '144-planstatus|145-tilde|passed'`
Expected: Failures에 `hooks-lib/144-planstatus-tilde-fence-skip (exp=[completed] got=[active])` + `enforce-rpi-cycle/145-tilde-fence-noplan (expected=2, got=0)`. `133 / 135 passed`. 비공허 RED.

- [x] **Step 3: Implement** — `hooks/_common.sh:92` 의 awk 펜스 라인 교체:

기존:
```bash
    /^[[:space:]]*```/ { fence = !fence; next }
```
신규:
```bash
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
```

- [x] **Step 4: Run to verify GREEN**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | tail -4`
Expected: `135 / 135 passed` · `cases.tsv <-> run-all 정합 OK (135 declared == 135 run, 비주석 실재)` · `Pass rate 100% — OK`.

- [x] **Step 5: Stage (commit deferred)** — `git add hooks/_common.sh hooks/tests/cases.tsv hooks/tests/run-all.sh`

---

## Task 3: 무회귀 전수 검증

- [x] **Step 1: hook 단위 — 기존 redirect/planstatus 무회귀 + 신규 6 GREEN**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | tail -4`
Expected: `135 / 135 passed`, 정합 OK, Pass rate 100%. (기존 122-132·136-139 불변 + 신규 140-145.)

- [x] **Step 2: verify-setup 무회귀**

Run: `bash "$HOME/.claude/setup/verify-setup.sh" 2>&1 | tail -2`
Expected: `verify-setup: PASS=65 FAIL=0`. (#28 bash -n 가 _common.sh/redirect-targets.js 문법 유효 확인.)

- [x] **Step 3: 전체 수용 게이트**

Run: `bash "$HOME/.claude/setup/verify-all.sh" 2>&1 | grep -E 'STAGE|passed|PASS=|ALL PASS'`
Expected: STAGE 3 run-all `135 / 135` · seal 5/0 · failopen 5/0 · rpi-prereq-gate 3/0 · `ALL PASS`.

- [x] **Step 4: 라이브 변경 추적**

Run: `cd "$HOME/.claude" && git status --short`
Expected: M redirect-targets.js, M _common.sh, M cases.tsv, M run-all.sh + spec/plan. 의도된 변경만.

---

## Self-Review
- **Spec coverage**: 결정1=Task1, 결정2=Task2, 무회귀=Task3. 6 케이스 spec §2 표와 1:1. ✓
- **Placeholder scan**: 전 Step 실제 코드/명령/기대. ✓
- **이름 일관**: case_id(140-145) cases.tsv↔run-all 정확 일치. `>&` else-if 분기, awk `(```|~~~)`. `$LIBREGEX`·`$NP`·`$BIG`·`mk_bash_event`·`mk_event` 기존 정의 재사용(run-all 내 스코프). ✓
- **엣지**: `>&-`→`-` isCode false 무차단; `2>&1`→`1` 무차단(142 검증); 혼합펜스 범위밖. ✓
