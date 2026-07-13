# Harness Upgrade C7 — GAP-011 skill/플러그인 공급망 규약 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Status:** completed
**RPI-Cycle:** 55
**Started:** 2026-07-14
**Completed:** 2026-07-14

**Best-Direction Check:** 최선안 = 개인 규모에서 서명 인프라 없이 rug-pull(승인-후-변경, 02 §4 ToxicSkills 13.4%)을 방어하는 **콘텐츠 해시 스냅샷 + 드리프트 자동 표면화**. 채택안 = 동일:
- **핀 파일**(`docs/ai-context/plugin-pins.md`): 플러그인별 version+gitCommitSha(installed_plugins.json 유래) 표 + 기계검증용 **SKILL.md 콘텐츠 cksum**(전 플러그인 SKILL.md 결정론 해시) + 드리프트 시 리뷰 절차.
- **드리프트 ALERT**(session-start-audit): 캐시 SKILL.md cksum 재계산 vs 핀 비교 → 다르면 ALERT(rug-pull/업데이트 표면화, approve-once→review-on-change). ★해시=`find … SKILL.md | sort | xargs cat | cksum`=**bash-only**(C6 교훈: node readFileSync는 staged MSYS 경로 미독).
- **drift-guard seal**(verify-setup): plugin-pins.md 존재+cksum 핀 봉인.
- **리뷰 절차**(playbook): 업데이트/ALERT 시 SKILL.md diff 리뷰 후 핀 갱신.

**정직: D11 3 유지(L4 절반), 점수 미bump**: D11 L4 = 3 + [핀/diff-review] + [Rule-of-Two 분리] + [deny 최후방어선]의 **3 conjunct**. GAP-011은 04에 "**D11 L4 절반**"으로 명시된 첫 conjunct(핀/diff-review)만 착륙 → **D11 L4 부분 충족, 점수 3 유지**(L4=4는 GAP-013[Rule-of-Two]·GAP-007a[deny] 후속 완료 시). **이는 방향 열화가 아니라 conjunctive 레벨의 스코프 분할**(rug-pull 방어는 그 자체로 고가치 보안 통제) — 무bump는 정직한 부분-진척. **DOWNGRADE-DECLARED: 없음.** opencode 미러: 미이식 선언(플러그인 캐시는 CC-고유; opencode는 자체 플러그인 관리 — C2/C3/C5 canonical-only 선례).

**Goal:** 플러그인 공급망에 핀+드리프트 표면화. 관찰가능 success: (1) `docs/ai-context/plugin-pins.md` 존재+SKILL.md cksum 핀 + verify-setup 신규 seal RED→GREEN (2) 격리 캐시 변이 시 session-start-audit ALERT·무변이 silent (3) run-all 신규 케이스 GREEN (4) playbook 공급망 리뷰 절차 grep (5) verify-all ALL PASS.

**Tech Stack:** session-start-audit(D-SUPPLY-CHAIN 블록)·verify-setup seal(#38/#39 동형 bash)·run-all(hermetic override 패턴)·installed_plugins.json(핀 유래).

## Global Constraints
- **착수 실측**: verify-setup 현재 **76**. run-all 현재 **170**. seal 최고 **#39**. 신규 seal = **#40**(#36 앞). ★동시세션 seal 충돌: 머지 직전 origin/master 실측·재번호.
- 핀 대상 실측(착수 시점): SKILL.md **46개** @ `plugins/cache/claude-plugins-official/`, cksum=**1099091361**(결정론 `find|sort|xargs cat|cksum`). superpowers 6.1.1(sha 6efe32c9)·context7/skill-creator/playwright/claude-md-management(11a39a35d5ca). ※ 값은 착수 시점 — 구현 시 재실측.
- 드리프트 검사 = **bash 파일옵스만**(node 금지 — C6 #39 MSYS 교훈). hermetic: `PLUGIN_CACHE_DIR`·`PLUGIN_PINS` override(RUNLOG_DIR/MEMORY_PROJECTS_DIR 선례). advisory(exit 0)·fail-open.
- 신규 seal → verify-setup 76→77 → README `현재 N PASS`(#36) 동기. seal-regression은 docs/ai-context(C4)+plugins 복제 필요 확인. 신규 run-all 케이스 → cases.tsv+README(#20). 케이스 191+(회피).

---

### Task 1: docs/ai-context/plugin-pins.md 생성 (버전 핀 + SKILL.md cksum + 리뷰 절차)
**Files:** Create: `docs/ai-context/plugin-pins.md`

- [x] **Step 1: 착수 실측** — `find "$HOME/.claude/plugins/cache/claude-plugins-official" -name SKILL.md | sort | xargs cat | cksum` 로 현재 cksum·개수 실측(문서 상수 무신뢰).
- [x] **Step 2: 핀 문서 작성** — (a) 표: plugin·version·gitCommitSha(installed_plugins.json 유래) (b) 기계검증 라인 `skill-cksum: <실측>` + `skill-count: <N>` (c) 헤더 근거: 02 §4 rug-pull·approve-once; 드리프트 시 절차="SKILL.md diff 리뷰(git log/캐시 비교) → 정당하면 이 핀 갱신, 아니면 롤백". `<!-- 이 cksum 은 session-start-audit 드리프트 검사와 verify-setup seal #40 이 소비 -->`.
- [x] **Step 3: commit** — `docs(gap-011): plugin-pins.md — 버전 핀(installed_plugins 유래)+SKILL.md cksum+rug-pull 리뷰 절차`

### Task 2: session-start-audit 공급망 드리프트 ALERT (RED→GREEN)
**Files:** Modify: `hooks/session-start-audit.sh`, `hooks/tests/run-all.sh`, `hooks/tests/cases.tsv`, `README.md`

- [x] **Step 1: RED 케이스 먼저** — run-all.sh(test_ssa_mem 근처)에 hermetic 테스트:
```bash
# ==================== CYCLE-C7: 공급망 드리프트 (GAP-011) ====================
test_ssa_supply() {  # $1 name  $2 want(warn|silent)  $3 cache_dir  $4 pins_file
  TOTAL=$((TOTAL+1))
  local err; err=$(echo '{"session_id":"s","cwd":"'"$SCRATCH"'"}' | PLUGIN_CACHE_DIR="$3" PLUGIN_PINS="$4" "$HOOKS/session-start-audit.sh" 2>&1 >/dev/null)
  local good=0
  if [ "$2" = "warn" ]; then echo "$err" | grep -q '\[supply-chain\]' && good=1
  else echo "$err" | grep -q '\[supply-chain\]' || good=1; fi
  [ "$good" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$1 (want=$2)")
}
SUP="$SCRATCH/supply"; mkdir -p "$SUP/cache/mp/plug/1"; printf '# skill A\n' > "$SUP/cache/mp/plug/1/SKILL.md"
SUPCK=$(find "$SUP/cache" -name SKILL.md -type f | sort | xargs cat 2>/dev/null | cksum | cut -d' ' -f1)
printf 'skill-cksum: %s\nskill-count: 1\n' "$SUPCK" > "$SUP/pins-match.md"
printf 'skill-cksum: 999999999\nskill-count: 1\n' > "$SUP/pins-drift.md"
test_ssa_supply "191-supply-match-silent" silent "$SUP/cache" "$SUP/pins-match.md"
test_ssa_supply "192-supply-drift-warn"   warn   "$SUP/cache" "$SUP/pins-drift.md"
```
- [x] **Step 2: RED 실행** — 192 FAIL(ALERT 미발화), 191 PASS. RED 확인(직접 실행 격리).
- [x] **Step 3: 구현** — session-start-audit **메모리 블록(D-MEMORY-LIFECYCLE) 뒤**, `CLAUDE_MD=` 앞에 삽입(메모리 블록 뒤=방어심층: 이 블록의 set-e 사고가 [memory] 출력을 못 지움). ★**set-e 안전 필수**: `PINNED_CK` 파이프에 `|| true`(Gate P 포착 — pins에 cksum 라인 부재 시 grep exit 1→pipefail→set-e 조기종료; 메모리 블록 line 96 `|| true` 선례):
```bash
# --- D-SUPPLY-CHAIN: 플러그인 캐시 SKILL.md 콘텐츠 해시 드리프트 (GAP-011, rug-pull 방어) ---
#   승인-후-변경(02 §4)을 핀 cksum 대조로 표면화. bash 파일옵스만(node 금지 — staged MSYS 경로 미독).
#   PLUGIN_CACHE_DIR/PLUGIN_PINS override=hermetic. advisory(exit 0)·fail-open(|| true=set-e 안전).
PLUGIN_CACHE="${PLUGIN_CACHE_DIR:-$HOME/.claude/plugins/cache}"
PINS_FILE="${PLUGIN_PINS:-$HOME/.claude/docs/ai-context/plugin-pins.md}"
if [ -d "$PLUGIN_CACHE" ] && [ -f "$PINS_FILE" ]; then
  PINNED_CK=$(grep -oE 'skill-cksum:[[:space:]]*[0-9]+' "$PINS_FILE" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
  if [ -n "$PINNED_CK" ]; then
    CUR_CK=$(find "$PLUGIN_CACHE" -name 'SKILL.md' -type f 2>/dev/null | sort | xargs cat 2>/dev/null | cksum | cut -d' ' -f1 || true)
    if [ -n "$CUR_CK" ] && [ "$CUR_CK" != "$PINNED_CK" ]; then
      hook_log "session-start-audit" "plugin-drift" "ALERT" "cksum $PINNED_CK->$CUR_CK"
      echo "[supply-chain] ⚠ 플러그인 캐시 SKILL.md 콘텐츠 변경 (cksum $PINNED_CK→$CUR_CK) — rug-pull 가능. docs/ai-context/plugin-pins.md 절차대로 diff 리뷰 후 핀 갱신" >&2
    fi
  fi
fi
```
- [x] **Step 4: GREEN 실행** — 191/192 PASS. 실 캐시 무드리프트(라이브 무경보) 확인.
- [x] **Step 5: cases.tsv + README** — 2행(191/192) → 170→172. README `170 case/케이스`(276·514) → `172`.
- [x] **Step 6: commit** — `feat(gap-011): session-start-audit 공급망 SKILL.md cksum 드리프트 ALERT — RED→GREEN, bash-only, PLUGIN_* hermetic (run-all 170→172)`

### Task 3: verify-setup seal #40 (plugin-pins 존재+cksum) RED→GREEN
**Files:** Modify: `setup/verify-setup.sh`, `README.md`

- [x] **Step 1: seal 삽입** — #39 뒤, #36 앞. bash grep(node 금지):
```bash
# 40. plugin-pins.md 존재 + SKILL.md cksum 핀 (GAP-011 D11 L4 절반): 공급망 핀이 사라지면 FAIL.
#     rug-pull 방어 앵커(드리프트 검사가 이 핀을 소비). bash grep(#38/#39 동형, staged-safe).
PINS="$HOME/.claude/docs/ai-context/plugin-pins.md"
if [ ! -f "$PINS" ]; then
  fail "plugin-pins 부재 (GAP-011): docs/ai-context/plugin-pins.md 생성 필요"
elif grep -qE 'skill-cksum:[[:space:]]*[0-9]+' "$PINS"; then
  ok "plugin-pins SKILL.md cksum 핀 존재"
else
  fail "plugin-pins cksum 핀 부재 (GAP-011): skill-cksum: <N> 라인 필요"
fi
```
- [x] **Step 2: RED 실측** — pins 부재/cksum 없는 복제본 FAIL → 존재 GREEN.
- [x] **Step 3: README** — `현재 76 PASS` → `77`.
- [x] **Step 4: commit** — `feat(gap-011): verify-setup #40 plugin-pins 존재+cksum seal (76→77, RED→GREEN)`

### Task 4: playbook 공급망 리뷰 절차
**Files:** Modify: `docs/harness-upgrade-2026-07/05-playbook.md`

- [x] **Step 1: §5 함정에 공급망 항목 추가** — 플러그인 업데이트/드리프트 ALERT 시: ① `git -C plugins/cache/...` 또는 캐시 SKILL.md diff 리뷰 ② 정당한 업데이트면 plugin-pins.md cksum 갱신(실측 재계산) ③ 미승인 변경이면 롤백/재설치. approve-once→review-on-change 규약. rug-pull(02 §4) 근거.
- [x] **Step 2: commit** — `docs(gap-011): playbook 공급망 리뷰 절차(드리프트 ALERT→diff 리뷰→핀 갱신/롤백)`

### Task 5: 검증 + Closeout
- [x] **Step 1: staged verify-all** — verify-setup 77/0(#40 GREEN)·seal-regression PASS(plugin-pins docs/ai-context 커버·plugins 복제 확인)·run-all 172·verify-all ALL PASS. #40 RED→GREEN·191/192 실증.
- [x] **Step 2: 03 D11 재채점** — **3 유지**(L4 절반=핀/diff-review 착륙; L4=4는 GAP-013 Rule-of-Two·GAP-007a deny 후속). 종합표 비고에 "L4 절반(GAP-011) 착륙" 명기·min 문장 무변(D11 여전히 min-3).
- [x] **Step 3: 04 GAP-011 DONE** — 커밋분(핀·드리프트·seal·리뷰절차). D11 L4 절반 명시. README 상태 C7 행.
- [x] **Step 4: PR → (머지 직전 seal 재확인) → auto-merge → state bump(54→55) → drift review-strict → 보고+next-cycle-goal(GAP-013 D11 나머지 절반 또는 GAP-010 D1 커버리지)**.
