# Doctor 이식성 + RPI 전제조건 게이트 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 33
**Started:** 2026-06-14

**Goal:** `setup/doctor.sh`의 하드코딩 WSL 경로(`/mnt/c/Users/12132`, line 13·111)를 env-override+`%USERPROFILE%` 유도로 치환(G7-a)하고, `setup/verify-all.sh`에 RPI 전제조건 STAGE 0 게이트를 추가해 superpowers 트리오 부재 시 "ALL PASS" 거짓 보증을 차단(G7-b)한다.

**Architecture:** spec=`docs/superpowers/specs/2026-06-14-doctor-portability-and-rpi-prereq-gate-design.md`. 결정(1) doctor.sh 자기완결 유도(WSL 분기는 라이브 휴면 IS_WSL=0 → 무회귀). 결정(2) verify-all STAGE 0 = 수용 게이트(doctor 20b WARN는 install-time advisory로 유지, run-context 분리). 둘 다 TDD RED→GREEN, 무회귀 게이트.

**Tech Stack:** bash, node(미사용), git-bash/WSL.

> **커밋 정책 (사용자 standing 제약 + goal):** 본 사이클은 working-tree에 구현+검증만 하고, **git commit/merge는 Closeout에서 사용자 명시 승인 후**에만(차후 cycle들과 함께 batch 가능). 각 Step의 "commit"은 *스테이징/검증 완료* 의미로 읽고 실제 커밋은 deferred.

---

## File Structure

- Modify `setup/doctor.sh` (lines 12-17 유도 블록, line 111 메시지) — 하드코딩 제거.
- Modify `setup/tests/doctor.test.sh` (Test 5 추가) — 이식성 불변식.
- Create `setup/tests/rpi-prereq-gate.test.sh` — STAGE 0 메타테스트.
- Modify `setup/verify-all.sh` (STAGE 0 추가 + STAGE 2d 배선).

---

## Task 1: doctor.sh 이식성 (결정 1)

**Files:**
- Test: `setup/tests/doctor.test.sh` (Test 5 추가, line 33 앞)
- Modify: `setup/doctor.sh:12-17`, `setup/doctor.sh:111`

- [x] **Step 1: Write the failing test** — `setup/tests/doctor.test.sh`의 `echo "PASS: all doctor.sh tests"`(line 34) **직전**에 삽입:

```bash
# Test 5 (cycle-33): doctor.sh 이식성 — 하드코딩된 사용자-특정 WSL 경로 부재 (G7-a 회귀 방지).
# WSL Windows-home candidate/FATAL 메시지가 특정 사용자(/mnt/c/Users/12132)로 하드코딩되면
# 타 사용자 fresh-clone 비이식 → env override(WINDOWS_CLAUDE_HOME) + %USERPROFILE% 유도로 치환되어야 함.
if grep -nF '/mnt/c/Users/12132' "$DOCTOR" >/dev/null 2>&1; then
  echo "FAIL: doctor.sh에 하드코딩된 사용자-특정 경로(/mnt/c/Users/12132) 잔존 — 이식성 위반"; exit 1
fi
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash "$HOME/.claude/setup/tests/doctor.test.sh"`
Expected: FAIL — `doctor.sh에 하드코딩된 사용자-특정 경로(/mnt/c/Users/12132) 잔존` (현재 doctor.sh:13·111에 실재).

- [x] **Step 3: Write minimal implementation** — (3a) `setup/doctor.sh:12-17`을 아래로 교체:

```bash
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
IS_WSL=0
if [ -r /proc/version ] && grep -qiE 'microsoft|wsl' /proc/version; then
  IS_WSL=1
fi

# WSL: locate the Windows-side .claude (shared with Windows Claude) — portable, no hardcoded user.
# Priority: explicit override WINDOWS_CLAUDE_HOME > derive from Windows %USERPROFILE% via interop > empty (→ WARN).
WINDOWS_CLAUDE_HOME_CANDIDATE="${WINDOWS_CLAUDE_HOME:-}"
if [ -z "$WINDOWS_CLAUDE_HOME_CANDIDATE" ] && [ "$IS_WSL" -eq 1 ] && command -v cmd.exe >/dev/null 2>&1; then
  win_profile=$( cd /mnt/c 2>/dev/null && cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\n' || true )
  # C:\Users\Name → /mnt/c/Users/Name/.claude  (parse-safe case-glob + bash param-expansion; from-file verified)
  case "$win_profile" in
    [A-Za-z]:*)
      win_drive="${win_profile%%:*}"; win_drive=$(printf '%s' "$win_drive" | tr 'A-Z' 'a-z')   # 'C' → 'c'
      win_rest="${win_profile#?:}"; win_rest="${win_rest//\\//}"                                # '\Users\Name' → '/Users/Name'
      WINDOWS_CLAUDE_HOME_CANDIDATE="/mnt/$win_drive$win_rest/.claude"                           # /mnt/c/Users/Name/.claude
      ;;
  esac
fi
```

(3b) `setup/doctor.sh:111` (FATAL 메시지)의 하드코딩 `HOME=/mnt/c/Users/12132`를 유도 변수로 교체:

```bash
      check "Claude home namespace" "FAIL" "WSL detected; run with HOME=${WINDOWS_CLAUDE_HOME_CANDIDATE%/.claude} or CLAUDE_HOME=$WINDOWS_CLAUDE_HOME_CANDIDATE (current: $CLAUDE_HOME)"
```

- [x] **Step 4: Run test to verify it passes**

Run: `bash "$HOME/.claude/setup/tests/doctor.test.sh"`
Expected: `PASS: all doctor.sh tests` (Test 5 통과 + Test 1-4 불변; 이 호스트 IS_WSL=0이라 doctor exit 0 보존).

- [x] **Step 5: Stage (commit deferred to Closeout approval)**

```bash
git add setup/doctor.sh setup/tests/doctor.test.sh
```

---

## Task 2: verify-all RPI 전제조건 STAGE 0 게이트 (결정 2)

**Files:**
- Create: `setup/tests/rpi-prereq-gate.test.sh`
- Modify: `setup/verify-all.sh` (STAGE 0 삽입 + STAGE 2d 배선)

- [x] **Step 1: Write the failing test** — `setup/tests/rpi-prereq-gate.test.sh` 생성:

```bash
#!/usr/bin/env bash
# setup/tests/rpi-prereq-gate.test.sh
# verify-all STAGE 0 (RPI 전제조건 게이트) 메타테스트 — cycle-33 G7-b.
#  ① superpowers 트리오 부재 복제본 → verify-all 이 ALL PASS 거부(exit≠0 + STAGE0 메시지, no "ALL PASS")
#  ② 라이브 트리오 존재(STAGE 0 라이브 통과 = 무회귀)  ③ 라이브 verify-all.sh 무변형 witness
set -uo pipefail
PASS=0; FAIL=0
LIVE_VA="$HOME/.claude/setup/verify-all.sh"
WIT_BEFORE=$(cksum "$LIVE_VA" 2>/dev/null || echo "NA")

# ① 부재 복제본 → ALL PASS 거부
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude/setup"
cp "$LIVE_VA" "$TMP/.claude/setup/verify-all.sh"
OUT=$(HOME="$TMP" bash "$TMP/.claude/setup/verify-all.sh" 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && printf '%s' "$OUT" | grep -q 'STAGE 0' \
   && printf '%s' "$OUT" | grep -q 'superpowers 핵심 skill 부재' \
   && ! printf '%s' "$OUT" | grep -q 'ALL PASS'; then
  echo "✓ no-superpowers replica → ALL PASS 거부 (exit=$RC, STAGE0 fail msg, no ALL PASS)"; PASS=$((PASS+1))
else
  echo "✗ no-superpowers replica: expected exit≠0 + STAGE0 fail msg + no ALL PASS (got rc=$RC)"; FAIL=$((FAIL+1))
fi

# ② 라이브 트리오 존재 = STAGE 0 라이브 통과 (무회귀)
MISS=""
for sk in brainstorming writing-plans executing-plans; do
  ls "$HOME"/.claude/plugins/cache/*/superpowers/*/skills/"$sk"/SKILL.md >/dev/null 2>&1 || MISS="$MISS $sk"
done
if [ -z "$MISS" ]; then
  echo "✓ live trio present (STAGE 0 passes live — no regression)"; PASS=$((PASS+1))
else
  echo "✗ live trio missing:$MISS"; FAIL=$((FAIL+1))
fi

# ③ 라이브 verify-all.sh 무변형 witness
WIT_AFTER=$(cksum "$LIVE_VA" 2>/dev/null || echo "NA")
if [ "$WIT_BEFORE" = "$WIT_AFTER" ]; then
  echo "✓ live verify-all.sh untouched (cksum stable)"; PASS=$((PASS+1))
else
  echo "✗ live verify-all.sh mutated"; FAIL=$((FAIL+1))
fi

echo
echo "rpi-prereq-gate: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash "$HOME/.claude/setup/tests/rpi-prereq-gate.test.sh"`
Expected: `rpi-prereq-gate: PASS=2 FAIL=1` (비공허 RED) — ①이 FAIL: 현재 verify-all에 STAGE 0가 없어 복제본 실행이 STAGE 1 doctor에서 다른 이유로 죽고 'STAGE 0'/'superpowers 핵심 skill 부재' 메시지가 없음. (②③은 PASS.)

- [x] **Step 3: Write minimal implementation** — (3a) `setup/verify-all.sh`의 `set -uo pipefail`(line 2) **다음 줄**, 첫 `echo "=== STAGE 1` 앞에 STAGE 0 삽입:

```bash
echo "=== STAGE 0: RPI 전제조건 (superpowers 핵심 트리오) ==="
# verify-all 은 수용 게이트("ALL PASS"=완전가동 보증). RPI 엔진인 superpowers 트리오
# (start-rpi-cycle Phase R/P/I 가 호출: brainstorming/writing-plans/executing-plans)가 부재하면
# "ALL PASS"를 거짓 보증하므로 차단. (doctor.sh 20b WARN 는 install-time advisory 로 유지 — run-context 분리;
#  이 트리오는 doctor 20b 4종의 수용-임계 부분집합으로 의도적 비동일.)
RPI_PREREQ_MISSING=""
for sk in brainstorming writing-plans executing-plans; do
  ls "$HOME"/.claude/plugins/cache/*/superpowers/*/skills/"$sk"/SKILL.md >/dev/null 2>&1 \
    || RPI_PREREQ_MISSING="$RPI_PREREQ_MISSING $sk"
done
if [ -n "$RPI_PREREQ_MISSING" ]; then
  echo "FAIL STAGE 0: superpowers 핵심 skill 부재 —$RPI_PREREQ_MISSING" >&2
  echo "  RPI(start-rpi-cycle Phase R/P/I)가 작동하지 않습니다. 설치: /plugin install superpowers@claude-plugins-official" >&2
  echo "  (이 게이트 미통과 시 최종 수용 메시지를 출력하지 않음 — 거짓 보증 방지)" >&2
  exit 1
fi
echo "[stage0] RPI 전제조건 OK (brainstorming/writing-plans/executing-plans present)"
echo
```

(3b) 같은 파일에서 `=== STAGE 2c: fail-open surface meta-test ===` 블록(현재 line 15-16) **다음**, `=== STAGE 3` 앞에 STAGE 2d 배선:

```bash
echo "=== STAGE 2d: RPI prereq gate meta-test ==="
bash "$HOME/.claude/setup/tests/rpi-prereq-gate.test.sh" || { echo "FAIL rpi-prereq-gate"; exit 1; }
echo
```

- [x] **Step 4: Run test to verify it passes**

Run: `bash "$HOME/.claude/setup/tests/rpi-prereq-gate.test.sh"`
Expected: `rpi-prereq-gate: PASS=3 FAIL=0` (① 이제 복제본이 STAGE 0에서 메시지+exit1 → GREEN; ②③ 유지).

- [x] **Step 5: Stage (commit deferred)**

```bash
git add setup/verify-all.sh setup/tests/rpi-prereq-gate.test.sh
```

---

## Task 3: 무회귀 전수 검증

- [x] **Step 1: hook 단위테스트 무회귀**

Run: `bash "$HOME/.claude/hooks/tests/run-all.sh"`
Expected: `129 / 129 passed` (cases.tsv 미변경 → 불변).

- [x] **Step 2: verify-setup 무회귀**

Run: `bash "$HOME/.claude/setup/verify-setup.sh"`
Expected: `PASS=65 FAIL=0` (#28 bash -n 가 편집된 doctor.sh/verify-all.sh 문법 유효 확인 포함).

- [x] **Step 3: 전체 수용 게이트 (STAGE 0/2d 신설 반영)**

Run: `bash "$HOME/.claude/setup/verify-all.sh"`
Expected: STAGE 0 `[stage0] RPI 전제조건 OK` → … → STAGE 2d `rpi-prereq-gate: PASS=3 FAIL=0` → `ALL PASS — system meets §6.6 acceptance gate.` (라이브 트리오 존재 → STAGE 0 통과; 무회귀).

- [x] **Step 4: 라이브 무변형 + 변경 추적 확인**

Run: `cd "$HOME/.claude" && git status --porcelain`
Expected: M `setup/doctor.sh`, M `setup/tests/doctor.test.sh`, M `setup/verify-all.sh`, ?? `setup/tests/rpi-prereq-gate.test.sh` (+ spec/plan/state). 의도된 변경만.

---

## Self-Review (writing-plans 체크리스트)

- **Spec coverage**: 결정(1)=Task1, 결정(2)=Task2, 무회귀=Task3. spec §3 테스트 전략 1:1 매핑. ✓
- **Placeholder scan**: 모든 Step 실제 코드/명령/기대출력 포함. ✓
- **Type/이름 일관**: `WINDOWS_CLAUDE_HOME`(override env), `WINDOWS_CLAUDE_HOME_CANDIDATE`(파생 변수), `RPI_PREREQ_MISSING`, 트리오 `brainstorming/writing-plans/executing-plans` — Task 전반 일관. STAGE 0 메시지 문자열('STAGE 0','superpowers 핵심 skill 부재')이 test ①의 grep 패턴과 정확히 일치. ✓
- **엣지**: cmd.exe 부재/IS_WSL=0 → 유도 블록 스킵, 후보 빈값 → WARN(crash 없음); `${WINDOWS_CLAUDE_HOME:-}`로 set -u 안전. ✓
