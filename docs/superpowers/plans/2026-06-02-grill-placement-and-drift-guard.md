# grill 재배치 + 문서-강제 Drift Guard 구현 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Steps use checkbox (`- [ ]`).

**Status:** completed
**RPI-Cycle:** 12
**Started:** 2026-06-02

**Goal:** grill을 Phase R의 brainstorming 뒤(design stress-test)로 재배치하고, grill→spec 역류 누락과 CLAUDE.md §3↔skill drift를 기계적으로 봉인한다.

**Architecture:** (1) start-rpi-cycle Phase R 재배치 + Gate R review-strict 격상 + spec 역류 단계 명시. (2) enforce-rpi-cycle에 spec-before-plan 바닥 추가. (3) verify-setup.sh에 §3↔Phase R content-drift 체크(#17) 추가 — skill body=SSOT. (4) README 정정. (5) 세션 끝 CLAUDE.md §3 정합.

**Tech Stack:** Bash, awk/grep, Markdown, Claude Code hook/skill 시스템. Spec: `docs/superpowers/specs/2026-06-02-grill-placement-and-drift-guard-design.md`.

---

## File Map

| 파일 | 변경 |
|---|---|
| `setup/verify-setup.sh` | check #17 추가 |
| `hooks/enforce-rpi-cycle.sh` | spec-before-plan 게이트 추가 |
| `hooks/tests/cases.tsv` + `hooks/tests/run-all.sh` | 케이스 28/29/30 |
| `skills/start-rpi-cycle/SKILL.md` | Phase R 재배치 + Gate R 격상 + ADR + Closeout verify-setup |
| `README.md` | scenario 2 순서 + 12→13 + Phase R.A→R.B |
| `CLAUDE.md` | §3 Research 줄 정합 (**세션 끝, §1**) |

---

## Task 1: enforce-rpi-cycle.sh — spec-before-plan 게이트

**Files:** Modify `hooks/enforce-rpi-cycle.sh`

- [ ] **Step 1:** `CWD=...resolve_cwd...` 줄(11) 바로 다음, `# === 화이트리스트 1` 주석(13) 직전에 삽입:

```bash
# === Spec-before-plan 게이트 (cycle-12): Phase-P plan은 Phase-R design spec을 전제 ===
# plans/*.md 작성 시 sibling specs/*.md 가 없으면 차단 (grill→spec 역류 누락의 기계적 바닥).
case "$FILE_PATH" in
  */docs/superpowers/plans/*.md)
    if [ -z "${RPI_SKIP:-}" ] && ! ls "$CWD/docs/superpowers/specs"/*.md >/dev/null 2>&1; then
      hook_log "enforce-rpi-cycle" "$FILE_PATH" "BLOCK" "no-spec-before-plan"
      cat >&2 <<EOF
[rpi] 차단: plan 작성 전 design spec 없음 (docs/superpowers/specs/*.md).
  Phase R(brainstorming→grill→spec 역류)로 spec을 먼저 만든 뒤 writing-plans로 진행하세요.
  명시 우회: export RPI_SKIP="<이유>"
EOF
      exit 2
    fi
    ;;
esac
```

- [ ] **Step 2:** `bash -n hooks/enforce-rpi-cycle.sh` → 출력 없음.

---

## Task 2: hooks/tests — 케이스 28/29/30

**Files:** Modify `hooks/tests/cases.tsv`, `hooks/tests/run-all.sh`

- [ ] **Step 1:** `cases.tsv` 끝에 추가:

```
# Patch H (2026-06-02) — spec-before-plan gate (enforce-rpi-cycle)
enforce-rpi-cycle	28-plan-no-spec-block	2	gen_erc_plan_nospec
enforce-rpi-cycle	29-plan-with-spec-pass	0	gen_erc_plan_spec
enforce-rpi-cycle	30-plan-no-spec-skip	0	gen_erc_plan_skip
```

- [ ] **Step 2:** `run-all.sh`의 `# ==================== Summary` 블록(line ~553) 직전에 삽입:

```bash
# ==================== PATCH-H: SPEC-BEFORE-PLAN GATE (enforce-rpi-cycle) ====================
SBP_NO="$SCRATCH/sbp_nospec"; mkdir -p "$SBP_NO/docs/superpowers/plans"            # plans dir, NO specs
SBP_OK="$SCRATCH/sbp_spec";  mkdir -p "$SBP_OK/docs/superpowers/plans" "$SBP_OK/docs/superpowers/specs"
printf '# d\n' > "$SBP_OK/docs/superpowers/specs/x-design.md"
PLANBODY=$'# Plan\n**Status:** active\n- [ ] step1\n- [ ] step2'
test_erc "28-plan-no-spec-block"  2 "$(mk_event Write "$SBP_NO/docs/superpowers/plans/p.md" "$PLANBODY" "$SBP_NO")"
test_erc "29-plan-with-spec-pass" 0 "$(mk_event Write "$SBP_OK/docs/superpowers/plans/p.md" "$PLANBODY" "$SBP_OK")"
test_erc_plan_skip() {
  local input; input=$(mk_event Write "$SBP_NO/docs/superpowers/plans/p.md" "$PLANBODY" "$SBP_NO")
  TOTAL=$((TOTAL+1))
  local actual; actual=$(echo "$input" | RPI_SKIP=hotfix "$HOOKS/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
  [ "$actual" = "0" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("enforce-rpi-cycle/30-plan-no-spec-skip (got=$actual)")
}
test_erc_plan_skip
```

- [ ] **Step 3:** `bash hooks/tests/run-all.sh` → 28/29/30 PASS, 정합 OK, pass rate ≥95%.

---

## Task 3: verify-setup.sh — check #17 (§3 ↔ Phase R drift guard)

**Files:** Modify `setup/verify-setup.sh`

- [ ] **Step 1:** check #16 블록(lib parsers, line ~100) 다음, `echo` 요약(line ~102) 직전에 삽입:

```bash
# 17. RPI phase vocabulary: CLAUDE.md §3 must name every tool start-rpi-cycle Phase R names.
#     content drift guard — skill body = SSOT, §3 asserted as superset. "§3 omits grill" 클래스 봉인.
SK17="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
PR17=$(awk '/^# Phase R/{f=1;next} /^# Phase /{f=0} f' "$SK17" 2>/dev/null)
S3_17=$(awk '/^## §3\./{f=1;next} /^## §[0-9]/{f=0} f' "$HOME/.claude/CLAUDE.md" 2>/dev/null)
if [ -z "$PR17" ] || [ -z "$S3_17" ]; then
  fail "drift-guard #17: Phase R 또는 §3 섹션 추출 실패 (헤더 변경?)"
else
  MISS17=""
  for t in grill-with-docs brainstorming explore-strict; do
    printf '%s' "$PR17" | grep -q "$t" && ! printf '%s' "$S3_17" | grep -q "$t" && MISS17="$MISS17 $t"
  done
  [ -z "$MISS17" ] && ok "§3 ↔ start-rpi-cycle Phase R tools agree" || fail "§3 omits Phase-R tool(s):$MISS17 (drift vs start-rpi-cycle)"
fi
```

- [ ] **Step 2:** `bash -n setup/verify-setup.sh` → 출력 없음.
- [ ] **Step 3:** `bash setup/verify-setup.sh 2>&1 | grep -i 'phase-r\|§3'` → **RED 예상** (`✗ §3 omits Phase-R tool(s): grill-with-docs`). #17이 작동한다는 증거. (§3 수정 후 green 전환은 Task 6.)

---

## Task 4: start-rpi-cycle/SKILL.md — Phase R 재배치 + Gate R 격상 + ADR + Closeout

**Files:** Modify `skills/start-rpi-cycle/SKILL.md`

- [ ] **Step 1:** `# Phase R — Research` 부터 `## Gate R` 블록 전체(line 18–43)를 다음으로 교체:

```
# Phase R — Research

A. brainstorming skill 절차 (메인이 직접 따름) — 외향적 (요구·접근법·디자인)
   → 산출물: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md (design spec)
   ※ 누적 CONTEXT.md가 있으면 그 어휘를 기반으로 사용

B. grill-with-docs skill 절차 (메인이 직접 따름) — A의 design을 도메인 모델·코드에 비춰 stress-test
   ※ 미설치 시: `bash ~/.claude/setup/doctor.sh` 로 자동 설치
   → 산출물: CONTEXT.md 갱신(용어집), ADR(조건부)
   ※ ADR은 docs/ai-context/architecture.md (append-only, §5 SSOT)에 기록 — grill 기본 docs/adr/ 대신 하네스 SSOT 사용
   → grill 종료 후 메인이 직접: domain-glossary.md 메타데이터 테이블에 신규 용어 기록
   ★ spec 역류(reconcile): grill에서 깎인 용어·확정된 design 결정을 A의 spec 문서에 직접 Edit 반영.
     grill은 spec을 건드리지 않으므로 이 역류를 빠뜨리면 writing-plans가 낡은 spec을 읽는다.

C. Agent(subagent_type="explore-strict",
        task="<요청 분석>",
        context_paths=["CONTEXT.md",
                       "docs/ai-context/architecture.md",
                       "docs/ai-context/domain-glossary.md",
                       "docs/ai-context/non-obvious.md",
                       "docs/ai-context/deny-patterns.md"],
        success_criteria="발견사항·영향 모듈·신규 도메인 용어·deny pattern 충돌 식별")
   ※ CLAUDE.md는 메인이 자동 로드하므로 context_paths에 미포함 (중복 회피)
   ※ C는 B와 병렬·교차 가능 (A 완료 후)

## Gate R (차단형 — review-strict)
1. Agent(subagent_type="review-strict",
        task="spec ↔ 도메인 어휘/grill 결과 일관성 검증",
        context_paths=["CONTEXT.md",
                       "<현재 spec: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md>"],
        success_criteria="
          PASS only if ALL:
          - design spec 파일 존재
          - spec 도메인 용어가 CONTEXT.md canonical과 일치 (_Avoid_ 별칭 누출 0)
          - grill에서 확정된 design 결정이 spec에 반영됨 (spec 역류 완료)
          - CONTEXT.md 갱신됨 또는 신규 용어 없음(no-op) 명시
          FAIL with: 누락 용어·미반영 결정·spec 부재 목록")
   FAIL 시: spec 역류/CONTEXT.md 보강 후 재실행 (또는 "Gate R override: <이유>" 명시)
2. 신규 도메인 용어 confidence < 80% → 사용자 확인 → domain-glossary.md 메타데이터 추가
3. 아키텍처 영향 → ADR을 architecture.md(append-only)에 작성 권유
```

- [ ] **Step 2:** Step C-1(Drift Check) 마지막에 새 항목 추가 (item 5 "Non-obvious archive 검사" 다음):

```
6. 전역 하네스(~/.claude) 자체를 수정한 사이클이면: `bash ~/.claude/setup/verify-setup.sh` 실행 →
   PASS 확인 (cross-doc drift 게이트 #17: §3↔Phase R 포함). FAIL이면 문서 불일치 수정 후 재실행.
```

- [ ] **Step 3:** 검증 `grep -n "grill-with-docs\|spec 역류\|review-strict\|verify-setup" skills/start-rpi-cycle/SKILL.md` → Phase R(B), Gate R, Closeout에서 매칭.

---

## Task 5: README.md — 정정

**Files:** Modify `README.md`

- [ ] **Step 1:** line 22 `부트스트랩 (12 파일 + 디렉터리)` → `부트스트랩 (13 파일 + 디렉터리)`.
- [ ] **Step 2:** line 162 교체:
  - old: `1. **Phase R (Research)**: grill-with-docs(도메인 어휘 확립) + brainstorming + explore-strict — 요구사항·접근법·디자인 정리`
  - new: `1. **Phase R (Research)**: brainstorming → grill-with-docs(design을 도메인 모델에 stress-test, CONTEXT.md/ADR) → explore-strict — 요구사항·접근법·디자인 정리`
- [ ] **Step 3:** line 85 `grill-with-docs — Phase R.A 도메인 어휘 확립` → `grill-with-docs — Phase R.B design stress-test (도메인 어휘 확립)`.

---

## Task 6: CLAUDE.md §3 정합 — **세션 끝(§1)**

**Files:** Modify `CLAUDE.md`

> ⚠️ §1 Cache Stability: 이 편집은 구현의 **마지막**(세션 종료 직전)에만. prefix 캐시 1회 무효화.

- [ ] **Step 1:** line 22 교체:
  - old: `- Research: brainstorming + explore-strict`
  - new: `- Research: brainstorming → grill-with-docs → explore-strict`
- [ ] **Step 2:** `wc -l CLAUDE.md` → ≤200.

---

## Task 7: 최종 검증 + Closeout

- [ ] **Step 1:** `bash hooks/tests/run-all.sh` → pass rate ≥95%, 정합 OK.
- [ ] **Step 2:** `bash setup/verify-setup.sh` → FAIL=0 (#17 green).
- [ ] **Step 3:** `bash setup/verify-all.sh` → ALL PASS.
- [ ] **Step 4:** state.json: cycle.count 11→12, last_completed_at/last_drift_check = 2026-06-02.
- [ ] **Step 5:** non-obvious 교훈 등록 (SSOT-drift 클래스) — 메모리 + 보고.
- [ ] **Step 6:** plan Status active→completed. 커밋.
