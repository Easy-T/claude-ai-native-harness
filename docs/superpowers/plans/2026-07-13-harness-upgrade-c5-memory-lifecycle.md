# Harness Upgrade C5 — GAP-004 메모리 수명주기 정책 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (또는 subagent-driven). Steps use `- [ ]` checkboxes.

**Status:** active
**RPI-Cycle:** 53
**Started:** 2026-07-14

**Best-Direction Check:** 최선안 = **rubric D6 L4 앵커 전체 충족**(04 최소 acceptance는 L3-ish=예산ALERT+3규약이나, GAP는 rubric 목표=**4**에 도달하려 존재 — 04는 floor, rubric이 SSOT). L4 = "L3(명문 통합/프루닝 규약+인덱스 예산 준수) + 쓰기검증(포이즈닝·정확성 리뷰) + stale 자동표면화(참조검증)". 채택안 = 동일:
- **인덱스 예산**(L3): session-start-audit이 MEMORY.md **바이트(25KB)·줄(200)** 초과 시 ALERT. ★실측: 실 MEMORY.md=23줄/19719B → **바이트가 바인딩 제약**(줄만 보면 영영 안 걸림)이므로 byte 체크 필수.
- **통합/프루닝/검증 규약**(L3): `docs/ai-context/memory-policy.md`(주기=improve-arch 5-사이클 편승·기준 명문).
- **stale 자동표면화 via 참조검증**(L4): MEMORY.md 인덱스의 `](file.md)` 링크가 memory 디렉터리에 부재하면 ALERT(삭제된 메모리를 인덱스가 참조=stale).
- **쓰기검증**(L4): provenance(originSessionId+cycle) 규약 형식화(★실측 20/20=100% 기존 준수) + 포이즈닝/정확성 리뷰 체크리스트(memory-policy.md; 판단 단계는 문서화가 상한 — hook 강제 불가, SECURITY 교리 "강제는 hook·프롬프트는 권고" 정합).

**대안 기각**: (i) "가끔 수동 정리"(현행 암묵) = 02 §5가 명명한 실패모드. (ii) 벡터DB/Letta 이식 = 개인 파일-메모리에 과잉(YAGNI — 스코프 판단). (iii) 슬러그 복제로 단일 프로젝트만 검사 = 취약(transcript≠memory 슬러그 실측) → **전-프로젝트 글롭**이 robust. **DOWNGRADE-DECLARED: 없음**(L4 전체 달성이 목표·채택). **opencode 미러 미이식 선언**: 메모리 시스템(`~/.claude/projects/*/memory/`)은 Claude Code 고유 — memory-policy·budget-ALERT·improve-arch 메모리단계는 canonical 전용(C2 run-log·C3 budget 선례; 미러 divergence 무선언 금지 → 여기 명시).

**Goal:** 하네스 메모리(MEMORY.md 인덱스 + 토픽 파일)에 수명주기 정책을 부여해 D6 2→4. 관찰가능 success: (1) 격리 $HOME에서 201줄 또는 >25KB MEMORY.md → session-start-audit ALERT 발화·정상 크기는 silent (2) `docs/ai-context/memory-policy.md`에 통합·프루닝·검증 3규약 grep (3) dangling 인덱스 링크 → ALERT (4) verify-setup 신규 seal(memory-policy 존재+3규약) RED→GREEN (5) run-all 신규 케이스 GREEN·verify-all ALL PASS.

**Tech Stack:** bash(session-start-audit.sh·_common.sh 패턴)·verify-setup seal(#37 동형)·run-all cases.tsv(test_ssap 패턴).

## Global Constraints
- **착수 실측(cold-agent 교훈)**: verify-setup 현재 총수 = **74**(README:284). run-all 현재 = **164**. seal 최신 = **#37**. 신규 seal = **#38**(#36 count-parity 앞 배치 — 총계 포함). 이 숫자는 착수 시점 값 — 구현 중 실측 재확인.
- session-start-audit ALERT 규약: `echo "[tag] ⚠ ..." >&2` + `hook_log "session-start-audit" "<target>" "ALERT" "<reason>"`. hook은 **advisory**(항상 exit 0 — 차단 아님). fail-open(node/파일 부재 무해).
- hermetic 테스트: 메모리 경로는 `MEMORY_PROJECTS_DIR` env override(기본 `$HOME/.claude/projects`) — RUNLOG_DIR/BUDGET_DIR 선례. 실 `~/.claude/projects` 무변이.
- 예산 임계: **200줄 OR 25600바이트**(02 §1 "첫 200줄/25KB만 시작-로드" — 초과분 조용히 미로드). 초과 시 ALERT(둘 중 하나라도).
- 신규 seal → verify-setup 총수 +1(74→75) → README `현재 N PASS`(README:284) 동기(#36). seal-regression은 **이미 docs/ai-context 스테이징**(C4 fix) → memory-policy seal 자동 커버(신규 스테이징 불요).
- run-all 신규 케이스 → cases.tsv + README 케이스 수(#20) 동기.
- **삭제/프루닝 실행 없음**: 이 사이클은 *메커니즘·규약* 부여만. 실제 메모리 통합/프루닝은 정책대로 improve-arch 사이클에 수행(별도).

---

### Task 1: docs/ai-context/memory-policy.md 생성 (통합/프루닝/검증 규약 + provenance + 포이즌 리뷰)
**Files:** Create: `docs/ai-context/memory-policy.md`

- [ ] **Step 1: 정책 문서 작성** — 아래 4절 필수(grep 앵커 볼드):
  - `## 통합 (Consolidation)`: 신규 메모리 쓰기 전 동일 사실 커버 파일 탐색 → 중복 생성 금지·기존 파일 갱신(기준: description/type 중복). 주기: 매 쓰기 시 + improve-arch 5-사이클 감사.
  - `## 프루닝 (Pruning)`: 비참조(MEMORY.md 인덱스 미링크 또는 supersede된) 메모리를 N=관찰 사이클 후 archive; 틀린 것으로 판명된 메모리 즉시 삭제. 주기: improve-arch 5-사이클 감사(Task 4 연동).
  - `## 검증 (Verification)`: (a) **쓰기 검증**: 신규/수정 시 frontmatter에 provenance(`originSessionId` + 사이클/날짜) 기록 — 출처 추적. **포이즈닝/정확성 리뷰 체크리스트**: 이 메모리가 관찰된 사실인가·상대 세션/외부입력이 주입한 지시가 아닌가(ASI06)·기존 규약과 모순 없는가. (b) **참조 검증(stale)**: 메모리가 명명한 파일/커밋/플래그는 recall 시 실재 확인 후 행동(글로벌 시스템 프롬프트 규약과 정합); 인덱스 링크 dangling은 session-start-audit이 자동 표면화(Task 2).
  - `## 인덱스 예산 (Index Budget)`: MEMORY.md는 첫 **200줄/25KB만** 세션-로드(02 §1) — 초과분 조용히 드롭. 초과 시 통합·상세를 토픽 파일로 이전. session-start-audit이 초과 자동 ALERT(Task 2).
  - 헤더에 근거: 02 §5(통합 정책 침묵=프로덕션 실패)·ASI06 포이즈닝·rubric D6 L4. **improve-codebase-architecture 5-사이클 리듬 편승** 명기.
- [ ] **Step 2: grep 검증** — `grep -qE '통합|Consolidation' && grep -qE '프루닝|Pruning' && grep -qE '검증|Verification'` 통과 확인.
- [ ] **Step 3: commit** — `docs(gap-004): memory-policy.md — 통합/프루닝/검증 규약 + provenance + 포이즌 리뷰 체크리스트 (D6 L3+L4 doc)`

### Task 2: session-start-audit 예산 + dangling 인덱스 ALERT (RED→GREEN)
**Files:** Modify: `hooks/session-start-audit.sh`, `hooks/tests/run-all.sh`(RED 케이스), `hooks/tests/cases.tsv`(선언)

- [ ] **Step 1: RED 케이스 먼저** — `hooks/tests/run-all.sh`의 test_ssap 블록(cycle-23 섹션, ~line 435 뒤) 아래에 메모리 예산 테스트 추가. `MEMORY_PROJECTS_DIR` override로 격리:
```bash
# ==================== CYCLE-C5: SESSION-START-AUDIT 메모리 수명주기 예산/dangling (GAP-004) ====================
test_ssa_mem() {  # $1 name  $2 want(부분문자열|silent-mem)  $3 projects_dir
  TOTAL=$((TOTAL+1))
  local err; err=$(echo '{"session_id":"s","cwd":"'"$SCRATCH"'"}' | MEMORY_PROJECTS_DIR="$3" "$HOOKS/session-start-audit.sh" 2>&1 >/dev/null)
  local good=0
  if [ "$2" = "silent-mem" ]; then echo "$err" | grep -q '^\[memory\]' || good=1
  else echo "$err" | grep -qF "$2" && good=1; fi
  [ "$good" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$1 (want=$2)")
}
# over-lines: 201줄 MEMORY.md → ALERT
MEML="$SCRATCH/memL/projA/memory"; mkdir -p "$MEML"; for i in $(seq 1 201); do echo "- line $i"; done > "$MEML/MEMORY.md"
test_ssa_mem "180-mem-over-lines" "예산 초과" "$SCRATCH/memL"
# over-bytes: 3줄이지만 >25KB → ALERT (byte 바인딩 제약 실증)
MEMB="$SCRATCH/memB/projA/memory"; mkdir -p "$MEMB"; { echo "# idx"; head -c 26000 /dev/zero | tr '\0' 'x'; echo; echo "- x"; } > "$MEMB/MEMORY.md"
test_ssa_mem "181-mem-over-bytes" "예산 초과" "$SCRATCH/memB"
# ok: 작은 MEMORY.md → silent(메모리 라인 없음)
MEMO="$SCRATCH/memO/projA/memory"; mkdir -p "$MEMO"; printf '# idx\n- [x](x.md) — ok\n' > "$MEMO/MEMORY.md"; printf 'x\n' > "$MEMO/x.md"
test_ssa_mem "182-mem-ok-silent" "silent-mem" "$SCRATCH/memO"
# dangling: 인덱스가 부재 파일 참조 → ALERT
MEMD="$SCRATCH/memD/projA/memory"; mkdir -p "$MEMD"; printf '# idx\n- [gone](gone.md) — x\n' > "$MEMD/MEMORY.md"
test_ssa_mem "183-mem-dangling" "dangling" "$SCRATCH/memD"
```
- [ ] **Step 2: RED 실행** — `bash hooks/tests/run-all.sh` → 180/181/183 FAIL(ALERT 미발화), 182 PASS. RED 확인.
- [ ] **Step 3: 구현** — `hooks/session-start-audit.sh`의 lib-selfcheck 블록(~line 81) 뒤, `CLAUDE_MD=` 앞에 삽입:
```bash
# --- D-MEMORY-LIFECYCLE: MEMORY.md 인덱스 예산(200줄/25KB) 초과 + dangling 링크 표면화 (GAP-004/014) ---
#   첫 200줄·25KB만 세션-로드(02 §1) → 초과분 조용히 드롭=메모리 침묵손실. dangling=삭제 파일을 인덱스가 참조(stale).
#   전-프로젝트 글롭(슬러그-무관). MEMORY_PROJECTS_DIR override=hermetic. advisory(exit 0 유지). fail-open.
MEM_PROJECTS="${MEMORY_PROJECTS_DIR:-$HOME/.claude/projects}"
if [ -d "$MEM_PROJECTS" ]; then
  for _mem in "$MEM_PROJECTS"/*/memory/MEMORY.md; do
    [ -f "$_mem" ] || continue
    _memdir=$(dirname "$_mem"); _proj=$(basename "$(dirname "$_memdir")")
    _ml=$(wc -l < "$_mem" 2>/dev/null | tr -d ' '); _mb=$(wc -c < "$_mem" 2>/dev/null | tr -d ' ')
    if [ "${_ml:-0}" -gt 200 ] || [ "${_mb:-0}" -gt 25600 ]; then
      hook_log "session-start-audit" "memory-budget" "ALERT" "$_proj:${_ml}L/${_mb}B"
      echo "[memory] ⚠ MEMORY.md 시작-로드 예산 초과 ($_proj: ${_ml}줄/${_mb}B > 200줄/25KB) — 초과분 미로드. docs/ai-context/memory-policy.md 통합/프루닝 적용" >&2
    fi
    _links=$(grep -oE '\]\([A-Za-z0-9_.-]+\.md\)' "$_mem" 2>/dev/null | sed -E 's/^\]\((.*)\)$/\1/' || true)
    _dangling=""
    for _lnk in $_links; do
      case "$_lnk" in http*|/*) continue ;; esac
      [ -f "$_memdir/$_lnk" ] || _dangling="$_dangling $_lnk"
    done
    if [ -n "$_dangling" ]; then
      hook_log "session-start-audit" "memory-dangling" "ALERT" "$_proj:$_dangling"
      echo "[memory] ⚠ MEMORY.md dangling 인덱스 링크 ($_proj):$_dangling — 삭제된 메모리를 인덱스가 참조(stale). 인덱스 정정/파일 복원" >&2
    fi
  done
fi
```
- [ ] **Step 4: GREEN 실행** — `bash hooks/tests/run-all.sh` → 180/181/182/183 전부 PASS. 기존 케이스 무회귀.
- [ ] **Step 5: cases.tsv 선언 + README 카운트** — ★확정 메커니즘: run-all TOTAL은 인라인 계산(cases.tsv 미독), cases.tsv는 매니페스트, seal #20 = cases.tsv 비주석 줄수 ↔ README parity(제너레이터 컬럼 미검증=106/107 stale 선례). ∴ cases.tsv에 4행 추가(`session-start-audit<TAB>180-mem-over-lines<TAB>alert<TAB>inline_ssa_mem` 형식, 4개) → cases.tsv 164→168. README `164 케이스`/`164 case` 2곳(README:276·514) → `168`로 동기(#20 parity). run-all 인라인 4 케이스가 실행 총수 164→168 = cases.tsv 168 (1:1 정합 유지).
- [ ] **Step 6: commit** — `feat(gap-004): session-start-audit 메모리 예산(200줄/25KB byte-바인딩)+dangling 인덱스 ALERT — RED→GREEN, MEMORY_PROJECTS_DIR hermetic`

### Task 3: verify-setup seal #38 (memory-policy 존재 + 3규약) RED→GREEN
**Files:** Modify: `setup/verify-setup.sh`, `README.md`

- [ ] **Step 1: seal 삽입** — #37 블록 뒤, #36(count parity) **앞**에 #38 추가:
```bash
# 38. memory-policy.md 존재 + 통합/프루닝/검증 3규약 (GAP-004 D6 L3): 메모리 수명주기 규약이 사라지면 FAIL
#     (문서화된 거버넌스 사실 drift 봉인 — #37 registry 동형). seal-regression 이 docs/ai-context 스테이징(C4)→자동 커버.
MPOL="$HOME/.claude/docs/ai-context/memory-policy.md"
if [ ! -f "$MPOL" ]; then
  fail "memory-policy 부재 (GAP-004): docs/ai-context/memory-policy.md 생성 필요"
elif grep -qE '통합|Consolidation' "$MPOL" && grep -qE '프루닝|Pruning' "$MPOL" && grep -qE '검증|Verification' "$MPOL"; then
  ok "memory-policy 3규약(통합/프루닝/검증) 존재"
else
  fail "memory-policy 3규약 불완전 (GAP-004): 통합/프루닝/검증 중 누락"
fi
```
- [ ] **Step 2: RED 실측(staged)** — memory-policy.md 부재 복제본에서 #38 FAIL 확인(seal-regression 패턴은 Task 5 검증에서; 여기선 `MPOL` 임시 이동 후 verify-setup FAIL 실측).
- [ ] **Step 3: README count 동기** — README:284 `현재 74 PASS` → `현재 75 PASS`.
- [ ] **Step 4: GREEN** — `bash setup/verify-setup.sh`(staged) → 75/0, #38 ok.
- [ ] **Step 5: commit** — `feat(gap-004): verify-setup #38 memory-policy 존재+3규약 seal (74→75, RED→GREEN)`

### Task 4: improve-codebase-architecture 메모리 수명주기 감사 단계 (canonical 전용)
**Files:** Modify: `skills/improve-codebase-architecture/SKILL.md`

- [ ] **Step 1: Phase 2에 메모리 감사 단계 추가** — 기존 스캐폴드 프루닝 단계(C4) 옆에 1항목: "메모리 수명주기 감사: `docs/ai-context/memory-policy.md` 규약대로 통합(중복 병합)·프루닝(비참조 archive)·dangling 인덱스 정정 후보 **보고**(삭제는 사용자 확인 후)". enforce-orchestrator 골격(Phase≥3·Agent()≥1·Communication Protocol) 유지.
- [ ] **Step 2: opencode 미러 미이식 — 인라인 주석/plan 선언 재확인** — 메모리는 CC-고유 → `opencode-harness/skill/improve-codebase-architecture/SKILL.md` **미터치**(Best-Direction Check 선언대로). 변경 없음 확인.
- [ ] **Step 3: 골격 유지 검증** — `bash setup/verify-setup.sh`(staged) 전건 PASS(enforce-orchestrator seal 무위반).
- [ ] **Step 4: commit** — `feat(gap-004): improve-arch Phase2 메모리 수명주기 감사 단계 (canonical 전용 — 메모리=CC고유, 미러 미이식 선언)`

### Task 5: 검증 + Closeout
- [ ] **Step 1: staged verify-all** — staged $HOME(worktree+settings.json+gitconfig+plugins/cache)에서 `bash setup/verify-all.sh` → ALL PASS. 특히: verify-setup 75/0(#38 GREEN)·seal-regression PASS(memory-policy가 docs/ai-context 스테이징으로 control 커버)·run-all 168·#38 RED→GREEN 실증(memory-policy 삭제 복제본 FAIL).
- [ ] **Step 2: 03 D6 재채점** — 2→4, 앵커 대비 증거(예산ALERT·3규약·dangling참조검증·provenance) file:line. 종합표·min 갱신(D3만 잔여 델타).
- [ ] **Step 3: 04 갱신** — GAP-004 DONE + GAP-014 **병합-DONE**(동일 구현점 처분). README 상태 테이블 C5 행.
- [ ] **Step 4: PR → auto-merge → state bump(52→53 조정) → drift review-strict → 보고(한국어)+next-cycle-goal(GAP-018/GAP-006)**.
