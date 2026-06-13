# Seal-Regression Meta-Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 31
**Started:** 2026-06-13
**Completed:** 2026-06-13

> **실측 결과:** RED `seal-regression: PASS=2 FAIL=3`(no-op 변이 → 변이군 비공허 증명) → GREEN `PASS=5 FAIL=0`(실 변이 → 3 seal 클래스 #30·#23·#20 발화 검출). verify-all `ALL PASS`(doctor 35/0·doctor.test PASS·verify-setup 65/0·**STAGE 2b 5/0**·run-all 129/129·verify-integration 8/8). 라이브 무변이 cksum witness ✓. Part B는 §4 rank9에 ⏸ 사유 기록 후 의도적 defer.

**Goal:** verify-setup.sh의 drift seal들이 주입된 변이에 실제로 `FAIL + non-zero exit`를 내는지 격리 복제본에서 E2E로 증명하는 영구 메타테스트(`setup/tests/seal-regression.test.sh`)를 신설하고 `verify-all.sh`에 배선해, audit-reverification §4 rank9의 G4-a("seal 깨고 FAIL 기대하는 자동 테스트 부재")를 봉인한다.

**Architecture:** cycle-18 `verify-integration.sh`의 격리 청사진(`mktemp -d` + `trap rm -rf` + `set -uo pipefail`)을 복제한다. 라이브 `~/.claude`의 verify-setup이 검사하는 부분집합만 임시 `$HOME`에 복제하고(런타임 디렉터리 제외), **복제본만** 변이시킨 뒤 `HOME=<복제본> bash verify-setup.sh`를 돌려 (a) 무변이 대조군은 exit 0, (b) 대표 변이 ≥2(여기선 3, 서로 다른 seal 클래스)는 non-zero exit + 해당 seal FAIL 메시지를 단언한다. 라이브 무변이성은 cksum witness로 자체 단언한다. `doctor.sh→doctor.test.sh`(STAGE 1b) 선례와 동형으로 `verify-setup.sh` 검증 테스트를 **STAGE 2b**에 배선한다.

**Tech Stack:** bash (Git Bash/win32), `mktemp -d`, `cp -a`, GNU `sed -i -E`, `cksum`, node(간접 — 복제본 verify-setup이 호출).

---

## File Structure

- `setup/tests/seal-regression.test.sh` (**Create**) — acceptance-tier 메타테스트. `doctor.test.sh`/`verify-integration.sh`의 peer. `hooks/tests/cases.tsv` 유닛 케이스가 **아님**(→ run-all 129 불변, verify-setup 65 불변). 단일 책임: "verify-setup seal이 드리프트에 발화함"을 증명.
- `setup/verify-all.sh` (**Modify**) — STAGE 2(verify-setup) 직후 STAGE 2b로 새 러너 배선. 기존 `|| { echo "FAIL x"; exit 1; }` 가드 패턴 준수.

> 커밋 정책: 본 goal은 **단일 커밋**(명시 staging, `git add -A` 금지, `skills/ui-design/design.md` 제외)을 요구하므로 writing-plans의 "frequent commits" 기본을 override — Task별 커밋 없이 Closeout에서 1커밋.

## Non-Obvious 주의 (explore-strict Phase R 발견)

- `ai-context/*`(deny-patterns·non-obvious·architecture·domain-glossary)는 이 하네스 repo에 **부재**(target 프로젝트용 템플릿). 하네스 거버넌스 SSOT = `CLAUDE.md` + `CONTEXT.md` + `verify-setup.sh` seal.
- 고정 `/tmp` 마커 금지(cycle-18/#25 교훈) — 전부 `mktemp -d` 파생 경로 사용. `trap rm -rf` 정리.
- `cp -a`가 Git Bash에서 실행 비트(+x)를 보존하는지는 **대조군 실행으로 실증 확인**(seal #8/#12가 `-x` 검사). 대조군이 +x 손실로 FAIL하면 복제 후 `chmod +x` 복원 추가.
- seal #28(bash -n)은 `setup/*.sh`만 검사(setup/tests/ 미포함) → 새 테스트는 구문검사 대상 아님(doctor.test.sh와 동일). 단 `verify-all.sh` 편집은 #28 대상이므로 유효 bash 유지.

---

## Task 1: seal-regression.test.sh 신설 (TDD RED→GREEN)

**Files:**
- Create: `setup/tests/seal-regression.test.sh`

- [x] **Step 1: RED — 변이군을 no-op 스텁으로 둔 채 테스트 작성**

먼저 아래 GREEN 최종본을 작성하되, **3개 mutator 함수 본문을 `:`(no-op)로** 둔다. 즉 `mut_state_count_string`/`mut_settings_matcher`/`mut_readme_cases`를 각각 `{ :; }`로. (대조군·witness·드라이버 골격은 GREEN과 동일.)

- [x] **Step 2: RED 실행 — 변이군 단언이 실패함을 관찰**

Run: `bash "$HOME/.claude/setup/tests/seal-regression.test.sh"`
Expected: 대조군 ✓(무변이 복제본 exit 0) + witness ✓(라이브 불변) 이지만, **3개 mutant 단언은 ✗**(no-op이라 복제본이 클린 → verify-setup exit 0 → "non-zero 기대" 불충족). 요약 `seal-regression: PASS=2 FAIL=3`, exit 3.
근거: 변이군 단언이 **비공허(non-vacuous)** — 실제 seal 발화 없이는 통과 불가임을 증명.

- [x] **Step 3: GREEN — mutator 3종을 실 sed 변이로 교체**

3개 함수 본문을 아래 최종 코드로 채운다. 파일 전체 최종본:

```bash
#!/usr/bin/env bash
# Meta-test (cycle-31, G4-a): prove verify-setup.sh drift seals actually FAIL + non-zero exit
# when drift is injected. Acceptance-tier (peer of doctor.test.sh / verify-integration.sh),
# wired into verify-all.sh STAGE 2b — NOT a hooks/tests/cases.tsv unit case
# (so run-all stays 129 and verify-setup stays 65; this runner lives OUTSIDE verify-setup).
#
# Isolation (cycle-18 / #25 blueprint): replicate the live ~/.claude subset that verify-setup
# inspects into a fresh temp $HOME, mutate ONLY the replica, then run the replica's own
# verify-setup.sh under HOME=<replica>. The live ~/.claude is never written — proven at the
# end via cksum witnesses on every file any mutator could touch.
set -uo pipefail
SRC="$HOME/.claude"
PASS=0; FAIL=0
ok()  { echo "✓ $1"; PASS=$((PASS+1)); }
bad() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# --- live immutability witnesses: cksum files any mutator could touch, before & after ---
witness() { local f; for f in state.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv; do
              cksum "$SRC/$f" 2>/dev/null; done; }
LIVE_BEFORE="$(witness)"

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

# --- replicate the harness subset verify-setup.sh inspects (runtime dirs excluded for speed) ---
make_replica() {
  local C="$1/.claude" f d
  mkdir -p "$C"
  for f in CLAUDE.md README.md SECURITY.md settings.json settings.example.json state.json state.schema.json; do
    [ -f "$SRC/$f" ] && cp -p "$SRC/$f" "$C/$f"
  done
  for d in hooks setup skills agents commands; do
    [ -d "$SRC/$d" ] && cp -a "$SRC/$d" "$C/$d"
  done
  mkdir -p "$C/docs/superpowers/plans"
  cp -a "$SRC/docs/superpowers/plans/." "$C/docs/superpowers/plans/" 2>/dev/null || true
  rm -rf "$C/hooks/.log"   # drop runtime noise the seals never read
  chmod +x "$C/hooks/"*.sh "$C/setup/"*.sh 2>/dev/null || true  # guard cp -a +x loss on win32
}

run_replica_verify() {  # $1 = replica HOME ; echoes verify-setup output; return code = its exit
  HOME="$1" bash "$1/.claude/setup/verify-setup.sh" 2>&1
}

# === Control: an unmutated replica must PASS (seals do not false-fire on a clean copy) ===
CTRL="$ROOT/control"; mkdir -p "$CTRL"; make_replica "$CTRL"
OUT="$(run_replica_verify "$CTRL")"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q 'FAIL=0'; then
  ok "control: unmutated replica → verify-setup exit 0, FAIL=0"
else
  bad "control: replica exit=$RC (expected 0) — replica build/baseline broken. tail: $(printf '%s' "$OUT" | tail -3 | tr '\n' '|')"
fi

# === Mutant driver: build replica, apply mutator, require non-zero exit AND the seal's FAIL line ===
assert_seal_fires() {  # $1=label  $2=mutator-fn  $3=expected FAIL substring
  local label="$1" mut="$2" needle="$3"
  local h="$ROOT/mut_$label"; mkdir -p "$h"; make_replica "$h"
  "$mut" "$h/.claude"
  local out rc
  out="$(run_replica_verify "$h")"; rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qF "$needle"; then
    ok "mutant[$label]: exit=$rc (non-zero) + seal FAIL «$needle»"
  else
    bad "mutant[$label]: rc=$rc, missing «$needle». tail: $(printf '%s' "$out" | tail -3 | tr '\n' '|')"
  fi
}

# Mutator 1 — seal #30 (state.json ↔ schema): corrupt cycle.count integer → string.
mut_state_count_string() { sed -i -E 's/("count":[[:space:]]*)([0-9]+)/\1"\2"/' "$1/state.json"; }
# Mutator 2 — seal #23 (settings.json ↔ example harness-hook parity): shrink a harness hook matcher.
mut_settings_matcher()   { sed -i 's/"Write|Edit|NotebookEdit"/"Write|Edit"/' "$1/settings.json"; }
# Mutator 3 — seal #20 (README cases count ↔ cases.tsv actual): drift the declared count down by 1.
mut_readme_cases() {
  local actual; actual=$(grep -vcE '^[[:space:]]*(#|$)' "$1/hooks/tests/cases.tsv")
  sed -i -E "s/${actual} (케이스|cases?)/$((actual-1)) \1/g" "$1/README.md"
}

assert_seal_fires "state_schema"    mut_state_count_string "state.json schema 위반"
assert_seal_fires "settings_parity" mut_settings_matcher   "settings/example harness-hook drift"
assert_seal_fires "readme_cases"    mut_readme_cases       "README cases drift"

# === Live immutability: witnessed files byte-identical (all mutation stayed in replicas) ===
LIVE_AFTER="$(witness)"
if [ "$LIVE_BEFORE" = "$LIVE_AFTER" ]; then
  ok "live ~/.claude untouched (witness cksum stable across run)"
else
  bad "live ~/.claude MUTATED during run — isolation breach"
fi

echo
echo "seal-regression: PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

- [x] **Step 4: GREEN 실행 — 전 단언 통과 관찰**

Run: `bash "$HOME/.claude/setup/tests/seal-regression.test.sh"`
Expected: 대조군 ✓ + mutant[state_schema] ✓ + mutant[settings_parity] ✓ + mutant[readme_cases] ✓ + witness ✓. 요약 `seal-regression: PASS=5 FAIL=0`, exit 0.
만약 대조군이 +x 손실로 FAIL하면 `make_replica`의 `chmod +x ...` 줄이 이미 복원하므로 통과해야 함 — 그래도 실패 시 tail 메시지로 원인 식별 후 복제 범위 보강.

- [x] **Step 5: 실행 비트 부여**

Run: `chmod +x "$HOME/.claude/setup/tests/seal-regression.test.sh"`
Expected: (출력 없음) — 이후 `[ -x ]` true.

---

## Task 2: verify-all.sh STAGE 2b 배선

**Files:**
- Modify: `setup/verify-all.sh` (STAGE 2 직후)

- [x] **Step 1: STAGE 2b 블록 삽입**

`setup/verify-all.sh`의 STAGE 2(verify-setup) 블록 직후, STAGE 3 앞에 삽입:

```bash
echo "=== STAGE 2b: seal-regression meta-test ==="
bash "$HOME/.claude/setup/tests/seal-regression.test.sh" || { echo "FAIL seal-regression"; exit 1; }
echo
```

- [x] **Step 2: verify-all 전체 실행 — 새 stage 포함 전 stage 통과**

Run: `bash "$HOME/.claude/setup/verify-all.sh"`
Expected: STAGE 1/1b/2/**2b**/3/4 전부 통과, 마지막 `ALL PASS — system meets §6.6 acceptance gate.`, exit 0. STAGE 2b 출력에 `seal-regression: PASS=5 FAIL=0` 포함.

---

## Task 3: 자산 갱신 (Closeout 부기)

**Files:**
- Modify: `docs/superpowers/specs/2026-06-13-audit-reverification.md` (§4 rank9 행)
- Modify: `CONTEXT.md` (drift seal 어휘에 seal-regression 메타테스트 개념 추가 + #29/#30 현행화)
- Modify: `state.json` (cycle.count 30→31, last_completed_at)

- [x] **Step 1: reverification §4 rank9 — Part A ✅(cycle-31) / Part B ⏸(defer 사유)로 갱신**

`9 ⏸` 행을 Part A 완료 + Part B 보류로 갱신. Part B 보류 사유: "machine harness-verify 트리거는 rank2(trivial 게이트)가 KEEP된 것과 같은 단일-운영자 자기기만 클래스 + SKILL.md prose는 hook 강제 불가(closeout이 git diff 실행함을 PreToolUse가 못 봄, phase-skills/F12와 동형 advisory 잔여) → 저가치×SKILL.md 골격 위험 → defer."

- [x] **Step 2: CONTEXT.md drift-seal 절에 메타테스트 개념 추가 + 현행화**

`### drift seal` 절(28-30줄 근처)의 seal 열거를 현행(#17~#25·#27~#30)으로 정정하고, 한 줄 추가: seal-regression.test.sh가 verify-all STAGE 2b에서 대표 변이로 seal 발화를 E2E 증명(자가-표면화의 메타 레벨).

- [x] **Step 3: state.json count 30→31**

`cycle.count` 30→31, `cycle.last_completed_at`·`audit.last_drift_check` = 2026-06-13. (drift review 실제 수행 시에만 last_drift_check 갱신 — 본 사이클은 Closeout review-strict 수행하므로 갱신.)

- [x] **Step 4: 갱신 후 verify-setup 재확인 (state #30 정합)**

Run: `bash "$HOME/.claude/setup/verify-setup.sh" | tail -2`
Expected: `verify-setup: PASS=65 FAIL=0` (count=31 정수라 seal #30 통과).

---

## Task 4: 최종 검증 + 단일 커밋 + push

- [x] **Step 1: baseline 불변 실측**

Run: `bash "$HOME/.claude/setup/verify-all.sh"` (run-all 129/129, verify-setup 65/0, verify-integration 8/8, STAGE 2b 5/0 포함)
Expected: ALL PASS, exit 0.

- [x] **Step 2: 라이브 무변이 교차확인**

seal-regression 테스트의 witness 단언(✓)으로 라이브 무변이 확인 + `git -C "$HOME/.claude" status --porcelain`에 design.md 외 예상 파일만(테스트 신설·verify-all·spec·CONTEXT.md·state.json·plan) 나타남 확인. 예상외 변이 발견 시 되돌리지 말고 보고.

- [x] **Step 3: 명시 staging + 커밋 (design.md 제외, `git add -A` 금지)**

```bash
cd "$HOME/.claude"
git add setup/tests/seal-regression.test.sh setup/verify-all.sh \
        docs/superpowers/specs/2026-06-13-audit-reverification.md \
        docs/superpowers/plans/2026-06-13-cycle31-seal-regression-metatest.md \
        CONTEXT.md state.json
git commit -m "test(harness): seal-regression 메타테스트 — drift seal 발화 E2E 증명 #G4-a (cycle-31 rank9 Part A)"
```

- [x] **Step 4: push + ahead 0 확인**

Run: `git -C "$HOME/.claude" push && git -C "$HOME/.claude" status -sb | head -1`
Expected: push 성공, `## master...origin/master` (ahead 표기 없음).

---

## Self-Review

**1. Spec coverage (audit-reverification §4 rank9 G4-a):**
- "임시 $HOME 대표변이로 FAIL→exit E2E 1개" → Task 1(대조군 + 변이 3종, 각 non-zero exit + seal 메시지 단언). ✓ (대표 변이 ≥2 요구 → 3 제공, 서로 다른 seal 클래스: schema #30 / 내용-parity #23 / 카운트-parity #20.)
- "verify-all에 배선" → Task 2 STAGE 2b. ✓
- "라이브 ~/.claude 절대 무수정" → witness cksum 단언(Task 1) + Task 4 Step 2 교차확인. ✓
- "run-all 129 불변·verify-setup 65 불변" → 테스트가 cases.tsv 미포함·verify-setup 외부 러너(File Structure 명시). ✓
- "Part B 위험 시 보류·기록" → Task 3 Step 1 rank9 ⏸ 사유 기록. ✓

**2. Placeholder scan:** 전 step에 실제 코드/명령/기대출력 포함. TBD/TODO 없음. ✓

**3. Type consistency:** 함수명 `make_replica`/`run_replica_verify`/`assert_seal_fires`/`witness`/`mut_*` Task 1 내 일관. seal FAIL needle 문자열은 verify-setup.sh:154/192/268 실측 일치. ✓

**4. TDD 보강:** RED(Step 2)는 no-op 변이군이 FAIL=3을 내는 실패 출력, GREEN(Step 4)은 PASS=5 FAIL=0 통과 출력 — RED·GREEN 증거 모두 캡처 대상.
