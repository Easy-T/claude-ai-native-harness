# cycle-17 — Gate & Hygiene Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 17
**Started:** 2026-06-04

**Goal:** §3 게이트 우회 사이드도어(F2 README 글롭·F3 셸 파서)를 닫고, 선언≠실측 drift(F4/F4b/F5/F7~F10)를 기계적 seal로 봉인하며, RPI phase-skill silent-skip(F12)을 자가-표면 필수 필드로 전환한다.

**Architecture:** durable spec `2026-06-04-non-bypassable-rule-surfacing-design.md`의 cycle-17 확장(D-F2~D-F12) 구현. 모든 변경은 advisory/기계검증(하드 신규 게이트 아님). 신규 verify-setup 체크 5개(#20~#24)로 PASS 55→60.

**Tech Stack:** bash hooks(_common.sh SSOT), node(JSON/regex 파서), verify-setup/verify-integration/run-all 테스트 하네스.

---

## File Structure (touched)

- `hooks/enforce-rpi-cycle.sh` — whitelist-1 README 글롭(F2)
- `hooks/lib/redirect-targets.js` — 셸 파일-쓰기 타깃 파서 확장(F3)
- `setup/doctor.sh` — REQUIRED_HOOKS(F4b)
- `setup/verify-setup.sh` — 신규 #20~#24
- `skills/start-rpi-cycle/SKILL.md` — phase-skills 필드+Phase 헤더(F12), sub-step 3 조건부(F5), :172 스키마(F7)
- `README.md` — cases/PASS/E2E 카운트(F8/F9/F10)
- `hooks/tests/cases.tsv` + `hooks/tests/run-all.sh` — F2/F3 회귀 케이스

> 모든 코드파일(.sh/.js) 편집은 cycle-17 active plan(본 파일)이 존재하므로 enforce-rpi-cycle 게이트 통과. cases.tsv(.tsv)·SKILL.md/README(.md)는 화이트리스트 통과.

---

## Task 1: F2 — README 글롭 확장자화 (enforce-rpi-cycle)

**Files:**
- Modify: `hooks/enforce-rpi-cycle.sh:31`
- Test: `hooks/tests/cases.tsv` + `hooks/tests/run-all.sh`

- [x] **Step 1: 회귀 테스트 추가 (run-all.sh, 실패 확인용)**

`hooks/tests/run-all.sh`의 PATCH-A 화이트리스트 섹션 끝(line 292 `test_erc "27-claude-sh-plan-pass"` 다음 줄)에 추가:

```bash
# cycle-17 F2: README 가 코드 확장자면 게이트 낙하 (이름 면제 없음), 문서 README 는 통과
test_erc "94-readme-code-block" 2 "$(mk_event Write "$NP/lib/README.sh" "$BIG" "$NP")"
test_erc "95-readme-doc-pass"   0 "$(mk_event Write "$NP/docs/README.md" "$BIG" "$NP")"
```

- [x] **Step 2: 테스트가 실패하는지 확인 (94는 현재 0 반환 = 버그)**

Run: `bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '94-readme-code-block|95-readme'`
Expected: `enforce-rpi-cycle/94-readme-code-block (expected=2, got=0)` 출력(94 실패), 95는 통과.

- [x] **Step 3: enforce-rpi-cycle.sh:31 글롭 교체**

`hooks/enforce-rpi-cycle.sh` line 31을:

```bash
  *.md|*.txt|*.gitignore|*/CLAUDE.md|*/README*|*/.gitkeep) exit 0 ;;
```

다음으로 교체:

```bash
  *.md|*.txt|*.gitignore|*/CLAUDE.md|*/README|*/README.rst|*/README.adoc|*/README.markdown|*/README.org|*/.gitkeep) exit 0 ;;
```

(근거: `README.md`/`README.txt`는 같은 줄 `*.md`/`*.txt`가 이미 통과시킴. 코드-ext README는 어느 패턴에도 안 걸려 line 39 `is_code_path`로 낙하.)

- [x] **Step 4: 테스트 통과 확인**

Run: `bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '94-readme-code-block|95-readme'`
Expected: 무출력(둘 다 통과 — 실패 목록에 없음).

- [x] **Step 5: cases.tsv에 선언 추가 (reconciliation 정합)**

`hooks/tests/cases.tsv` 끝에 추가(TAB 구분 — `printf '%s\t%s\t%s\t%s\n'` 사용):

```
enforce-rpi-cycle	94-readme-code-block	2	gen_erc_readme_code
enforce-rpi-cycle	95-readme-doc-pass	0	gen_erc_readme_doc
```

- [x] **Step 6: reconciliation 통과 확인**

Run: `bash ~/.claude/hooks/tests/run-all.sh 2>&1 | tail -5`
Expected: `cases.tsv <-> run-all 정합 OK (... declared cases all present)`, `Pass rate ... OK`.

---

## Task 2: F3 — 셸 파일-쓰기 타깃 파서 확장 (redirect-targets.js)

**Files:**
- Modify: `hooks/lib/redirect-targets.js` (전체 재작성)
- Test: `hooks/tests/cases.tsv` + `hooks/tests/run-all.sh`

- [x] **Step 1: 단위 테스트 추가 (run-all.sh, redirect-targets 섹션)**

`hooks/tests/run-all.sh` line 465(`test_lib "77-redirect-devnull"` 다음 줄)에 추가:

```bash
# cycle-17 F3: sed -i / cp / mv / python -c open(...,"w") 로 코드파일 쓰기 탐지
test_lib "96-sed-i-code"   "app.js"    "$(CMD='sed -i s/a/b/ app.js' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "97-cp-code"      "deploy.sh" "$(CMD='cp template.txt deploy.sh' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "98-mv-code"      "b.sh"      "$(CMD='mv a.txt b.sh' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "99-pyc-code"     "gen.py"    "$(CMD=$'python3 -c "open(\'gen.py\',\'w\').write(x)"' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "100-sed-i-doc"   ""          "$(CMD='sed -i s/a/b/ notes.md' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "101-cp-doc"      ""          "$(CMD='cp a.txt b.md' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
```

- [x] **Step 2: 통합 테스트 추가 (run-all.sh, enforce-rpi-bash 섹션)**

`hooks/tests/run-all.sh` line 313(`test_erb "36-rpi-skip"` 다음 줄)에 추가:

```bash
# cycle-17 F3: sed -i / cp 로 코드파일 쓰기 (no plan) → BLOCK
test_erb "102-sed-code-noplan" 2 "$(mk_bash_event 'sed -i s/a/b/ app.js' "$NP")"
test_erb "103-cp-code-noplan"  2 "$(mk_bash_event 'cp template.txt deploy.sh' "$NP")"
```

- [x] **Step 3: 테스트 실패 확인 (현재 파서는 sed/cp/mv 미탐지)**

Run: `bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '9[6-9]-|10[0-3]-'`
Expected: 96/97/98/99/102/103 실패(got=[] 또는 got=0), 100/101 통과.

- [x] **Step 4: redirect-targets.js 재작성**

`hooks/lib/redirect-targets.js` 전체를 다음으로 교체:

```javascript
// hooks/lib/redirect-targets.js
// 셸로 '코드 파일'을 쓰는 패턴 탐지 (enforce-rpi-bash 가 사용).
// 입력: env CMD = 셸 명령 문자열, env CODE_EXT_REGEX = 코드 확장자 JS 정규식 source (_common.sh code_ext_regex).
// 출력: 첫 '코드 확장자' 쓰기 대상 (/dev/null 제외). 없으면 빈 문자열.
// 탐지 경로:
//   1) 리다이렉션 >/>> 와 tee [-a]
//   2) sed -i[SUFFIX] … FILE  (in-place 편집)
//   3) cp/mv SRC DST          (DST = 마지막 비옵션 인자)
//   4) python[3] -c '…open("FILE","w"|"a"|…)…'  (보수적 best-effort: 리터럴 파일명+write 모드만)
const cmd = process.env.CMD || "";
const codeExt = new RegExp(process.env.CODE_EXT_REGEX || "\\.(sh|py|js)$", "i");
const isCode = (p) => p && codeExt.test(p) && !/^\/dev\/null$/.test(p);
const targets = [];

// 1) 리다이렉션 / tee
const reRedir = /(?:>>?|\btee\s+(?:-a\s+)?)\s*("?)([^\s">|;&()]+)\1/g;
let m;
while ((m = reRedir.exec(cmd)) !== null) targets.push(m[2]);

// 2) sed -i[SUFFIX] … FILE : -i 플래그가 있으면 비옵션 인자(마지막 토큰들) 중 코드-ext
if (/\bsed\b/.test(cmd) && /\s-i\b|\s-i\S+|--in-place/.test(cmd)) {
  const toks = cmd.split(/\s+/).filter(t => t && !t.startsWith("-"));
  for (const t of toks) targets.push(t.replace(/^["']|["']$/g, ""));
}

// 3) cp / mv SRC DST : 마지막 비옵션 인자(목적지)
{
  const mcp = cmd.match(/\b(?:cp|mv)\b([^|;&]*)/);
  if (mcp) {
    const args = mcp[1].split(/\s+/).filter(t => t && !t.startsWith("-"));
    if (args.length >= 1) targets.push(args[args.length - 1].replace(/^["']|["']$/g, ""));
  }
}

// 4) python -c open("FILE", "w"|"a"|...) — 리터럴 파일명 + write 모드만 (보수적)
{
  const mpy = cmd.match(/python[0-9.]*\s+-c\b/);
  if (mpy) {
    const reOpen = /open\s*\(\s*["']([^"']+)["']\s*,\s*["'][^"']*[wa][^"']*["']/g;
    let om;
    while ((om = reOpen.exec(cmd)) !== null) targets.push(om[1]);
  }
}

const hit = targets.find(isCode);
if (hit) process.stdout.write(hit);
```

- [x] **Step 5: 단위·통합 테스트 통과 확인**

Run: `bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '9[6-9]-|10[0-3]-'`
Expected: 무출력(전부 통과).

- [x] **Step 6: 기존 redirect 케이스 미회귀 확인**

Run: `bash ~/.claude/hooks/tests/run-all.sh 2>&1 | grep -E '75-redirect|76-redirect|77-redirect|3[0-6]-'`
Expected: 무출력(75/76/77 + 30~36 모두 여전히 통과).

- [x] **Step 7: cases.tsv 선언 추가**

`hooks/tests/cases.tsv` 끝에 추가(TAB 구분):

```
hooks-lib	96-sed-i-code	output	gen_lib_96
hooks-lib	97-cp-code	output	gen_lib_97
hooks-lib	98-mv-code	output	gen_lib_98
hooks-lib	99-pyc-code	output	gen_lib_99
hooks-lib	100-sed-i-doc	output	gen_lib_100
hooks-lib	101-cp-doc	output	gen_lib_101
enforce-rpi-bash	102-sed-code-noplan	2	gen_erb_sed
enforce-rpi-bash	103-cp-code-noplan	2	gen_erb_cp
```

- [x] **Step 8: 전체 run-all 통과 + reconciliation 확인**

Run: `bash ~/.claude/hooks/tests/run-all.sh 2>&1 | tail -5`
Expected: 정합 OK, Pass rate OK.

---

## Task 3: F4b — doctor REQUIRED_HOOKS 복구 + verify-setup #24 (disk-coverage seal)

**Files:**
- Modify: `setup/doctor.sh:252-262`
- Modify: `setup/verify-setup.sh` (#19 블록 뒤, line 147 다음)

- [x] **Step 1: doctor.sh REQUIRED_HOOKS에 surface-constitution 추가**

`setup/doctor.sh` line 260(`"session-start-audit.sh"` 줄) 다음에 추가:

```bash
  "surface-constitution.sh"
```

(결과: REQUIRED_HOOKS = 9 hook + _common.sh = 10 항목.)

- [x] **Step 2: verify-setup.sh #24 추가 (disk SSOT 커버리지)**

`setup/verify-setup.sh` line 147(`fi` — #19 블록 끝) 다음, line 149 `echo` 앞에 추가:

```bash

# 24. doctor REQUIRED_HOOKS 가 디스크의 모든 hooks/*.sh 를 커버하는가 (신규 hook 누락 봉인 — F4b 재발 방지).
#     disk = SSOT. _common.sh(sourced lib)는 양쪽에서 제외.
DISK_H=$(for f in "$HOME/.claude/hooks/"*.sh; do basename "$f" .sh; done | grep -v '^_common$' | sort -u)
DOC_H=$(awk '/REQUIRED_HOOKS=\(/{f=1;next} /^\)/{f=0} f' "$HOME/.claude/setup/doctor.sh" 2>/dev/null \
        | grep -oE '[a-z_-]+\.sh' | sed 's/\.sh$//' | grep -v '^_common$' | sort -u)
MISS24=$(comm -23 <(printf '%s\n' "$DISK_H") <(printf '%s\n' "$DOC_H"))
[ -z "$MISS24" ] && ok "doctor REQUIRED_HOOKS ⊇ hooks/*.sh" || fail "doctor REQUIRED_HOOKS omits:$(printf ' %s' $MISS24)"
```

- [x] **Step 3: #24 green 확인 (doctor 수정 후)**

Run: `bash ~/.claude/setup/verify-setup.sh 2>&1 | grep -E 'REQUIRED_HOOKS|PASS='`
Expected: `✓ doctor REQUIRED_HOOKS ⊇ hooks/*.sh`, `PASS=56 FAIL=0`.

- [x] **Step 4: RED-path 검증 (doctor에서 임시 제거 시 FAIL)**

Run:
```bash
cp ~/.claude/setup/doctor.sh /tmp/doctor.bak
sed -i '/"surface-constitution.sh"/d' ~/.claude/setup/doctor.sh
bash ~/.claude/setup/verify-setup.sh 2>&1 | grep -E 'omits|FAIL='
cp /tmp/doctor.bak ~/.claude/setup/doctor.sh && rm /tmp/doctor.bak
```
Expected: `✗ doctor REQUIRED_HOOKS omits: surface-constitution`, `FAIL=1`. (복원 후 재실행 시 green.)

---

## Task 4: F4 — verify-setup #23 (settings.json ↔ example hook parity)

**Files:**
- Modify: `setup/verify-setup.sh` (#24 블록 뒤)

- [x] **Step 1: #23 추가 (hook basename 순서+이름만, 값 비교 없음)**

`setup/verify-setup.sh`의 #24 블록 다음에 추가:

```bash

# 23. settings.json ↔ settings.example.json hook command basename 순서+이름 parity.
#     값/시크릿(env·permissions·model) 미접근 — hooks.*[].hooks[].command 의 basename 만 비교.
sj_hooks() {
  node -e '
    let c={}; try{c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))}catch(e){process.exit(0)}
    const out=[]; for(const ph of Object.values(c.hooks||{})) for(const e of ph) for(const h of (e.hooks||[])) out.push(String(h.command||"").split("/").pop());
    process.stdout.write(out.join(","));
  ' "$1" 2>/dev/null
}
HA=$(sj_hooks "$HOME/.claude/settings.json")
HB=$(sj_hooks "$HOME/.claude/settings.example.json")
if [ -z "$HB" ]; then
  fail "settings.example.json hook 추출 실패"
elif [ "$HA" = "$HB" ]; then
  ok "settings.json ↔ example hook parity"
else
  fail "settings/example hook drift (순서/이름 불일치)"
fi
```

- [x] **Step 2: #23 green 확인**

Run: `bash ~/.claude/setup/verify-setup.sh 2>&1 | grep -E 'example hook parity|PASS='`
Expected: `✓ settings.json ↔ example hook parity`, `PASS=57 FAIL=0`.

(주: explore-strict가 양쪽 hook 목록 현재 동일(9개)임을 확인 → green. 만약 RED면 settings.json/example 중 drift난 쪽을 동기화한 뒤 재확인.)

---

## Task 5: F12 — phase-skills 자가-표면 필드 (SKILL.md) + verify-setup #22

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md` (Communication Protocol + Step C-1 + Phase R/P 헤더)
- Modify: `setup/verify-setup.sh` (#23 블록 뒤)

- [x] **Step 1: Phase R 헤더에 "Skill 도구 호출" 명시**

`skills/start-rpi-cycle/SKILL.md` 상단의 다음 줄:

```
※ superpowers의 brainstorming / writing-plans / executing-plans는 모두 **메인 세션의 skill**.
   sub-agent에 위임 X — 메인이 절차를 따름.
```

다음으로 교체:

```
※ superpowers의 brainstorming / writing-plans / executing-plans는 모두 **메인 세션의 skill**.
   sub-agent에 위임 X — 메인이 **Skill 도구로 호출**해 절차를 따름("절차 체화"가 아니라 실제 호출 — Closeout `phase-skills:` 로 선언).
```

- [x] **Step 2: Communication Protocol에 phase-skills 필드 추가**

`skills/start-rpi-cycle/SKILL.md`의 `## Communication Protocol` 섹션, `- harness-verify:` 블록 다음에 추가:

```
- phase-skills: **고유 필수 필드** (모든 사이클). 각 Phase에서 호출한 skill을 능동 선언 — 복합/암묵 필드에 접지 않음(누락=구조적 불완전, harness-verify·next-cycle-goal 선례). 형식:
  · `R: brainstorming=<invoked|skipped:이유>, grill-with-docs=<…>, explore-strict=<…>`
  · `P: writing-plans=<…>`
  · `I: <executing-plans|execute-strict|subagent-driven|workflow(d)>=<…>`
  · `Closeout: review-strict=<…>`
  무사유 skip 또는 필드 생략 = 자가-표면화(silent-skip 불가). ※ hook 물리 강제는 불가(PreToolUse는 Skill 호출 히스토리·skill명 미제공·`/skill` bypass — claude-code-guide 공식 docs) → advisory 상한 수락.
```

- [x] **Step 3: Step C-1에 phase-skills 선언 sub-step 추가**

`skills/start-rpi-cycle/SKILL.md`의 `## Step C-1` 내, sub-step 7(next-cycle-goal) 블록 끝 다음에 sub-step 8 추가:

```
8. phase-skills 선언 (Communication Protocol `phase-skills:` 필드로 출력):
   - 이번 사이클 각 Phase(R/P/I/Gate/Closeout)에서 **실제 Skill 도구로 호출한** skill을 `invoked`, 호출 안 한 필수 skill은 `skipped: <이유>` 로 명시.
   - 목적: RPI phase 실행(어느 skill을 실제 호출했나)은 plan-FILE proxy로 증명 불가(enforce-rpi-cycle은 plan 존재만 검사) → 보고의 *고유 필수 필드*로 자가-표면. 누락/무사유 skip = 구조적 불완전.
   - 정지점: 자가-표면은 skip을 *눈에 띄는 선언*으로 바꿀 뿐 호출을 물리 강제하진 않음(수락된 advisory 잔여).
```

- [x] **Step 4: verify-setup #22 추가 (phase-skills parity)**

`setup/verify-setup.sh`의 #23 블록 다음에 추가(#18/#19 패턴):

```bash

# 22. phase-skills 필드 parity: Step C-1(sub-step 8 절차) ↔ Communication Protocol(출력 계약) 두 곳에
#     'phase-skills' 토큰 필연 중복(둘 다 필수). 파일-내 parity 봉인(#18/#19 인스턴스).
SK22="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
C1_22=$(awk '/^## Step C-1/{f=1;next} /^## Sub-cycle states/{f=0} f' "$SK22" 2>/dev/null)
CP_22=$(awk '/^## Communication Protocol/{f=1} f' "$SK22" 2>/dev/null)
if [ -z "$C1_22" ] || [ -z "$CP_22" ]; then
  fail "drift-guard #22: Step C-1 또는 Communication Protocol 섹션 추출 실패"
elif printf '%s' "$C1_22" | grep -q 'phase-skills' && printf '%s' "$CP_22" | grep -q 'phase-skills'; then
  ok "phase-skills 필드 ↔ Step C-1/Communication Protocol parity"
else
  fail "phase-skills 필드 drift (Step C-1 ↔ Communication Protocol 불일치)"
fi
```

- [x] **Step 5: #22 green + #18/#19 미회귀 확인**

Run: `bash ~/.claude/setup/verify-setup.sh 2>&1 | grep -E 'phase-skills|next-cycle-goal 라벨|harness-verify 필드|PASS='`
Expected: `✓ phase-skills 필드 ↔ …`, `✓ next-cycle-goal 라벨 …`, `✓ harness-verify 필드 …`, `PASS=58 FAIL=0`.

---

## Task 6: F5 + F7 — SKILL.md last_drift_check 조건부 + 스키마 경로

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md` (Step C-1 sub-step 3)

- [x] **Step 1: sub-step 3 last_drift_check 조건부화 (F5)**

`skills/start-rpi-cycle/SKILL.md`의 Step C-1 sub-step 3에서:

```
   - audit.last_drift_check: today
```

다음으로 교체:

```
   - audit.last_drift_check: today (**단, Step C-1 drift review(sub-step 1)가 실제 수행된 경우에만** — abandoned/미수행 사이클은 미갱신. 하네스 사이클은 sub-step 6 harness-verify 결과와 의미적 연동: 점검 안 한 사이클이 "오늘 점검함"으로 위장 불가.)
```

- [x] **Step 2: :172 스키마 경로 dual-context 해소 (F7)**

같은 파일 sub-step 3에서:

```
   ※ 전체 스키마: `.claude/state.schema.json` (v2/v3 optional 필드 포함)
```

다음으로 교체:

```
   ※ 전체 스키마: `state.schema.json` (state.json 과 같은 디렉터리 — 프로젝트는 `.claude/`, 전역 하네스는 루트)
```

- [x] **Step 3: #18/#19/#22 awk 경계 미회귀 확인**

Run: `bash ~/.claude/setup/verify-setup.sh 2>&1 | grep -E '라벨|harness-verify 필드|phase-skills|PASS='`
Expected: 세 parity 모두 green, `PASS=58 FAIL=0` (이 task는 새 체크 미추가 — 카운트 불변).

---

## Task 7: F8/F9/F10 — README 카운트 동기 + verify-setup #20/#21 seal

**Files:**
- Modify: `README.md` (cases :272·:500, E2E :279, PASS :278)
- Modify: `setup/verify-setup.sh` (#22 블록 뒤)

- [x] **Step 1: 실측 카운트 확정**

Run:
```bash
echo "cases=$(grep -vcE '^[[:space:]]*(#|$)' ~/.claude/hooks/tests/cases.tsv)"
echo "e2e=$(grep -cE 'ok \"E2E\.' ~/.claude/setup/verify-integration.sh)"
```
Expected: `cases=96` (Task 1·2가 +10), `e2e=8`. (다르면 실측값을 아래 Step에 반영.)

- [x] **Step 2: README cases 카운트 동기 (F9 — 2곳)**

`README.md`에서 `79 case`(line ~272)와 `79 케이스`(line ~500)의 `79`를 **실측 cases 값(96)**으로 교체. 두 곳 모두.

- [x] **Step 3: README E2E 카운트 동기 (F10)**

`README.md` line ~279 `5개 E2E 시나리오` → `8개 E2E 시나리오`. (2026-05-01 spec의 "4개"는 point-in-time 사료 — 미수정.)

- [x] **Step 4: verify-setup #20/#21 seal 추가**

`setup/verify-setup.sh`의 #22 블록 다음에 추가:

```bash

# 20. cases.tsv 실측 == README 선언 카운트 (재드리프트 봉인). README 에서 cases.tsv 를 언급한 줄의
#     '<N> 케이스/case' 숫자가 실측과 다르면 FAIL.
ACT_CASES=$(grep -vcE '^[[:space:]]*(#|$)' "$HOME/.claude/hooks/tests/cases.tsv")
BAD20=$(grep -E 'cases\.tsv' "$HOME/.claude/README.md" 2>/dev/null \
        | grep -oE '[0-9]+ ?(케이스|cases?)' | grep -oE '^[0-9]+' | grep -vx "$ACT_CASES" | head -1)
[ -z "$BAD20" ] && ok "README cases 카운트 == 실측($ACT_CASES)" || fail "README cases drift: 선언 $BAD20 ≠ 실측 $ACT_CASES"

# 21. verify-integration E2E 실측 == README 선언 카운트.
ACT_E2E=$(grep -cE 'ok "E2E\.' "$HOME/.claude/setup/verify-integration.sh")
BAD21=$(grep -oE '[0-9]+개 E2E' "$HOME/.claude/README.md" 2>/dev/null | grep -oE '^[0-9]+' | grep -vx "$ACT_E2E" | head -1)
[ -z "$BAD21" ] && ok "README E2E 카운트 == 실측($ACT_E2E)" || fail "README E2E drift: 선언 $BAD21 ≠ 실측 $ACT_E2E"
```

- [x] **Step 5: README PASS 카운트 동기 (F8 — #20~#24 추가 후 최종)**

`README.md` line ~278 `현재 46 PASS` → `현재 60 PASS`. (현 55 + 신규 #20·#21·#22·#23·#24 = 60.)

- [x] **Step 6: #20/#21 green + PASS=60 확인**

Run: `bash ~/.claude/setup/verify-setup.sh 2>&1 | grep -E 'README cases|README E2E|PASS='`
Expected: `✓ README cases 카운트 == 실측(96)`, `✓ README E2E 카운트 == 실측(8)`, `PASS=60 FAIL=0`.

---

## Task 8: 최종 검증 + dogfood + 커밋

**Files:** (검증 전용 — verify-all 실행)

- [x] **Step 1: 전체 acceptance gate**

Run: `bash ~/.claude/setup/verify-all.sh 2>&1 | tail -20`
Expected: 모든 stage PASS (verify-setup PASS=60 FAIL=0, run-all Pass rate OK + 정합 OK, verify-integration ALL PASS, ALL PASS).

- [x] **Step 2: bash 구문 검사**

Run: `for f in ~/.claude/hooks/enforce-rpi-cycle.sh ~/.claude/setup/doctor.sh ~/.claude/setup/verify-setup.sh; do bash -n "$f" && echo "ok: $f"; done; node -c ~/.claude/hooks/lib/redirect-targets.js && echo "ok: redirect-targets.js"`
Expected: 4줄 모두 `ok:`.

- [x] **Step 3: doctor 회귀 없음 확인**

Run: `bash ~/.claude/setup/doctor.sh 2>&1 | grep -E 'surface-constitution|all hooks|FAIL='`
Expected: surface-constitution 관련 항목 PASS, `all hooks present+executable ... 10개`, FAIL=0.

- [x] **Step 4: 커밋 (Closeout에서 state.json·plan status 갱신 후 함께)**

> 커밋은 Phase Closeout에서 state.json(cycle 16→17)·plan Status(active→completed)·spec·README·메모리 정리와 함께 단일 커밋. (구현 task들은 무커밋 — Closeout이 묶어 커밋/푸시.)

---

## Self-Review (작성자 점검)

- **Spec coverage:** D-F2(T1)·D-F3(T2)·D-F4b+#24(T3)·D-F4/#23(T4)·D-F12/#22(T5)·D-F5+D-F7(T6)·D-F8/9/10+#20/#21(T7)·검증/dogfood(T8). D-F11=REFUTE(무변경, Non-Goal). 전 Decision 커버.
- **PASS 산술:** 55 → +#24(56) → +#23(57) → +#22(58) → +#20/#21(60). README:278=60. 일관.
- **카운트 의존:** #20/#21 seal은 T1/T2가 cases +10(86→96)·E2E 불변(8) 한 *뒤* README 동기와 함께 추가 → green.
- **awk 경계:** phase-skills/sub-step 8/last_drift_check 편집은 `## Step C-1`/`## Communication Protocol`/`## Sub-cycle states` 헤더 불변 → #18/#19/#22 안전.
- **No placeholder:** 전 step 구체 코드·정확 경로·기대 출력 명시.
