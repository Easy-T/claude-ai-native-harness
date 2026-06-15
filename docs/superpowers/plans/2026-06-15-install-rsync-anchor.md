# install/rsync 토크나이저 명령-위치 앵커 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox(`- [ ]`).

**Status:** completed
**RPI-Cycle:** 37
**Started:** 2026-06-15

**Goal:** `redirect-targets.js`의 install/rsync 탐지를 명령-위치 앵커로 제한해 경로/파일명 내 'install' 부분일치 오탐(over-block)을 봉인. 충실한 재현자=`cat setup/install.sh hooks/foo.py`(OLD→`hooks/foo.py` 추출=차단, NEW→`""`). 기존 install/rsync 정상탐지(111/112/117) 무회귀. (Gate P 교정: 단일 `bash -n setup/install.sh`는 `args.length>=2` 가드가 흡수해 미차단 — 결함은 install 뒤 ≥2 토큰일 때만 발화.)

**Architecture:** spec=`docs/superpowers/specs/2026-06-14-bashwrite-tokenizer-generalization-design.md` §결정(3)(cycle-37 delta). git-apply(line 21) 앵커 선례 동형. 라이브 게이트 내부 수정 → TDD + 즉시 run-all 무회귀.

**Tech Stack:** node(JS 정규식).

> **커밋 정책:** working-tree 구현+검증 → Closeout에서 master 머지·푸시(사용자 "끝까지" 승인).

---

## File Structure
- Modify `hooks/lib/redirect-targets.js:130` (install/rsync 정규식 앵커).
- Modify `hooks/tests/cases.tsv` + `run-all.sh` (2 케이스 154-155).
- Modify `README.md` (cases 139→141).

---

## Task 1: install/rsync 명령-위치 앵커

**Files:** `hooks/lib/redirect-targets.js`, `hooks/tests/cases.tsv`, `hooks/tests/run-all.sh`

- [x] **Step 1: Write failing tests** — (1a) `cases.tsv`의 `153-logsummary-counts` 뒤에 추가 (탭 구분; 155 expected_exit=**0**=통과/미차단):

```
# cycle-37 (2026-06-15) — install/rsync 명령-위치 앵커 (경로 substring 오탐 봉인)
hooks-lib	154-install-substr-pass	output	gen_lib_154
enforce-rpi-bash	155-install-substr-noplan-pass	0	gen_erb_155
```

(1b) `run-all.sh`의 `test_lib "117-rsync-dir-pass" ...` **뒤**에 추가:

```bash
# cycle-37: 'install'이 명령이 아니라 경로 substring(setup/install.sh)이면 미탐지 — 후행 ≥2 토큰이라도 오탐0
test_lib "154-install-substr-pass" "" "$(CMD='cat setup/install.sh hooks/foo.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
```

(1c) `run-all.sh`의 `test_erb "120-patch-noplan" ...` **뒤**에 추가:

```bash
# cycle-37: cat setup/install.sh hooks/foo.py 는 install 명령 아님 → no-plan 이어도 통과(과차단 봉인)
test_erb "155-install-substr-noplan-pass" 0 "$(mk_bash_event 'cat setup/install.sh hooks/foo.py' "$NP")"
```

- [x] **Step 2: Run to verify RED**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | grep -E '154-install|155-install|passed'`
Expected: 154(`exp=[] got=[hooks/foo.py]`)·155(`expected=0, got=2`) 둘 다 Failures. `139 / 141 passed`. 비공허 RED(실측: OLD→`hooks/foo.py` 추출=차단).

- [x] **Step 3: Implement** — `hooks/lib/redirect-targets.js:130` 의 정규식 교체:

기존:
```javascript
  for (const mi of cmd.matchAll(/\b(?:install|rsync)\b([^|;&]*)/g)) {
```
신규:
```javascript
  for (const mi of cmd.matchAll(/(?:^|[;&|()])\s*(?:install|rsync)\s+([^|;&]*)/g)) {
```

근거: `(?:^|[;&|()])` = install/rsync 가 *명령 시작*(라인 처음 또는 분리자 뒤)일 때만; `\s+` = 뒤에 공백+인자(진짜 명령)일 때만. `cat setup/install.sh hooks/foo.py`: 'install'이 `/` 뒤 → 미매칭. `echo install foo.py bar.py`: 'install'이 `echo `(공백) 뒤 → 미매칭(오탐0). `install -m 755 a b.py`: 라인시작 → 매칭(불변); `foo && install x y.sh`: `&&` 뒤 → 매칭(불변).

- [x] **Step 4: Run to verify GREEN**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | grep -E '111-install|112-rsync|117-rsync|154-install|155-install|passed'`
Expected: 154·155 통과; 기존 111(`install -m 755 a b.py`→b.py)·112(`rsync -a s.txt d.js`→d.js)·117(dir→"") 불변. `141 / 141 passed`.

- [x] **Step 5: Stage** — `git add hooks/lib/redirect-targets.js hooks/tests/cases.tsv hooks/tests/run-all.sh`

---

## Task 2: README 동기화 + 무회귀

- [x] **Step 1: README cases 카운트** — `README.md:274` `139 case`→`141 case`, `:510` `139 케이스`→`141 케이스`.

- [x] **Step 2: run-all 무회귀** — Run: `bash "$HOME/.claude/hooks/tests/run-all.sh" 2>&1 | tail -4` → `141 / 141 passed`, 정합 OK.

- [x] **Step 3: verify-setup(+#20 seal)** — Run: `bash "$HOME/.claude/setup/verify-setup.sh" 2>&1 | grep -E 'README cases|PASS='` → `✓ README cases==141`, `PASS=65 FAIL=0`.

- [x] **Step 4: 전체 수용 게이트** — Run: `bash "$HOME/.claude/setup/verify-all.sh" 2>&1 | grep -E 'passed|ALL PASS'` → run-all `141 / 141`, `ALL PASS`.

---

## Self-Review
- **Spec coverage**: 결정(3)=Task1, 무회귀+README=Task2. ✓
- **Placeholder scan**: 실제 코드/명령/기대. (1a 정정 주의: 155 expected_exit=0.) ✓
- **무회귀 손검증(실측 완료)**: 111 `install -m 755 a b.py`→`^`매칭→b.py; 112 `rsync -a s.txt d.js`→d.js; 117 `rsync -a src/ dst/`→dst/(isCode false→""). NEW 실측 B/C→`[]`, D/E/F→`b.py`/`b.py`/`y.sh`. RED 실측: B(`cat setup/install.sh hooks/foo.py`)→OLD `hooks/foo.py`. ✓
- **이름 일관**: case_id 154-155 cases.tsv↔run-all 일치; expected 154=output, 155=exit 0. ✓
