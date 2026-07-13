# Harness Upgrade C6 — GAP-018 autocompact 트리거 재캘리브레이션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Status:** active
**RPI-Cycle:** 54
**Started:** 2026-07-14

**Best-Direction Check:** 최선안 = autocompact 트리거를 rot 실증(~300-400K)·dumb-zone(40%=400K) **이전**으로 정렬(D3 L4 conjunct "compact 트리거가 rot 이전" 충족) + **결정론 drift-guard**(rot-정렬 기본값이 되돌려지면 FAIL) + doctor 능동 권고 + 정책 문서화. 채택안 = 동일:
- **기본값 rot-정렬**: `settings.example.json` PCT 60→40(1M 기준 400K); doctor #23 권고 60→40 + **rot-미정렬 능동 WARN**(set>40이면 경고).
- **drift-guard seal**: verify-setup 신규 seal — settings.example PCT_OVERRIDE **≤40** 봉인(#37 동형 node-read). RED(60>40 FAIL)→GREEN(40).
- **행동 검증**: auto-compact-watch은 OVERRIDE_PCT에서 WARN=PCT−10 **파생**(hook 무변경) → rot-zone(350K) 테스트로 PCT=55(THRESHOLD 450K)→무경고=RED-state·PCT=40(THRESHOLD 300K)→경고=GREEN 실증.
- **문서**: playbook §5-5에 rot-정렬 트리거 정책 + **WINDOW=1M 가드**(창 붕괴 시 40%는 80K 과빈발 — [1m] suffix 전제).

**정직한 목표 = D3 3→4(L4), 5 아님**: D3 L4 = 모델-인지 창 + 캐시 seal + 서브에이전트 격리 + **트리거 rot 이전**. 앞 3개는 기충족, GAP-018이 4번째(트리거) 충족 → **L4 달성=4**. L5의 나머지 conjunct(창-매핑 신규모델 auto-safe[model-window.js:11-16 하드코딩]·캐시 적중률 측정)는 **GAP-018 스코프 밖**(별 축·별 사이클) — C5가 L5의 "MEMORY.md 인덱스 예산 seal" conjunct은 이미 전달했으나 3개 중 1개라 L5 미달. **DOWNGRADE-DECLARED: 없음**(L5 나머지는 GAP-018 접근의 열화가 아니라 별개 gap의 스코프; 트리거 재캘리브 자체는 최선안 채택).

**per-machine 지연 선언(커밋·배포 불가, C3 budget 선례)**: 라이브 `settings.json` PCT 55→40은 **gitignored per-machine** → 커밋 불가 + 메인 체크아웃 peer 점유로 배포 불가 → **문서화된 수동 절차**(재시작 후 `/context`=1M·트리거 ~400K 확인)로 남김. "1세션 관찰(compact 후 연속성)"도 런타임이라 지연 — RPI post-compact 연속성(spec/plan 재주입)이 비용 흡수함을 문서 인용([[autocompact_proxy_display]]).

**Goal:** autocompact 트리거를 rot 이전으로 재캘리브 → D3 3→4. 관찰가능 success: (1) settings.example PCT=40 && verify-setup 신규 seal(≤40) RED→GREEN (2) doctor #23 권고=40 + set>40 시 WARN (3) auto-compact-watch rot-zone(350K) 테스트: PCT=55 무경고·PCT=40 경고 (4) playbook §5-5 rot-정렬 정책+WINDOW=1M 가드 grep (5) verify-all ALL PASS.

**Tech Stack:** settings.example.json(env)·doctor.sh(#23)·verify-setup seal(#37 동형)·run-all(test_acw 패턴)·auto-compact-watch(파생, 무변경).

## Global Constraints
- **착수 실측**: verify-setup 현재 **75**(README:284). run-all 현재 **168**. seal 최고 = **#38**(C5). 신규 seal = **#39**(#36 앞). ★**동시세션 seal 충돌**: ui-design v3도 seal 추가중 → **머지 직전 origin/master 실측·충돌 시 재번호**(C5 #38 선점 선례).
- settings.example.json:8 현재 `"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "60"`. 라이브 settings.json은 gitignored(불커밋). env 값은 #23(settings↔example hook parity) 대상 아님(hook matcher만 — 확인).
- 신규 seal → verify-setup 75→76 → README `현재 N PASS`(#36) 동기. seal-regression은 settings.example를 make_replica가 이미 복제 → 신규 seal 자동 커버.
- 신규 run-all 케이스 → cases.tsv + README(#20) 동기. 케이스 번호 189+(sb-180~184·mem 185-188 회피).
- rot 정렬 값 = **40%**(1M=400K; dumb-zone 40% Horthy·rot 시작 300-400K). auto-compact-watch WARN=30%(300K)=pre-rot heads-up.

---

### Task 1: settings.example PCT 60→40 + doctor #23 rot-정렬 권고/WARN
**Files:** Modify: `settings.example.json`, `setup/doctor.sh`

- [ ] **Step 1: settings.example.json** — line8 `"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "60"` → `"40"`.
- [ ] **Step 2: doctor.sh #23** — 로직 교체: set & ≤40 → PASS; set & >40 → WARN(rot-미정렬, ≤40 권장); unset → WARN(rec 40). WINDOW=1M 전제 문구:
```bash
  if [ -n "$compact_val" ]; then
    if [ "$compact_val" -le 40 ] 2>/dev/null; then
      check "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "PASS" "${compact_val}% (rot-정렬 ≤40)"
    else
      check "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "WARN" "${compact_val}% — rot(~300-400K) 지남. ≤40 권장(WINDOW=1M 전제; [1m] suffix)"
    fi
  else
    check "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "WARN" "미설정 — 기본값 95%. settings.json env에 \"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE\": \"40\" 추가 권장(rot-이전)"
  fi
```
- [ ] **Step 3: 구문·정합** — `bash -n setup/doctor.sh`; settings.example JSON valid(`node -e require`).
- [ ] **Step 4: commit** — `feat(gap-018): settings.example PCT 60→40 + doctor #23 rot-정렬 권고/WARN (트리거 rot 이전)`

### Task 2: verify-setup seal #39 (settings.example PCT ≤40) RED→GREEN
**Files:** Modify: `setup/verify-setup.sh`, `README.md`

- [ ] **Step 1: seal 삽입** — #38 뒤, #36 **앞**:
```bash
# 39. settings.example autocompact 트리거 rot-정렬 (GAP-018 D3 L4): PCT_OVERRIDE ≤40(=1M 기준 ≤400K, rot 이전).
#     60/55 등 rot-지난 값이면 FAIL — rot 곡선(02 §5·§4 dumb-zone 40%)에 정렬된 기본값 봉인. WINDOW=1M 전제([1m]).
EX_PCT=$(node -e "try{const s=JSON.parse(require('fs').readFileSync('$HOME/.claude/settings.example.json','utf8'));console.log((s.env&&s.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE)||'')}catch(e){}" 2>/dev/null)
if [ -z "$EX_PCT" ]; then
  fail "settings.example CLAUDE_AUTOCOMPACT_PCT_OVERRIDE 부재 (GAP-018)"
elif [ "$EX_PCT" -le 40 ] 2>/dev/null; then
  ok "settings.example autocompact 트리거 rot-정렬 (${EX_PCT}% ≤40)"
else
  fail "settings.example autocompact 트리거 rot-미정렬 (GAP-018): ${EX_PCT}% >40 (rot ~300-400K 이전=≤40)"
fi
```
- [ ] **Step 2: RED 실측** — Task 1 전(example=60) 복제본에서 #39 FAIL(60>40) 확인; Task 1 후(40) GREEN.
- [ ] **Step 3: README** — `현재 75 PASS` → `76`.
- [ ] **Step 4: commit** — `feat(gap-018): verify-setup #39 settings.example rot-정렬 seal (75→76, RED→GREEN)`

### Task 3: auto-compact-watch rot-timing 검증 테스트 (run-all)
**Files:** Modify: `hooks/tests/run-all.sh`, `hooks/tests/cases.tsv`, `README.md`

- [ ] **Step 1: 테스트 추가** — test_acw_model 블록(~line 557) 뒤. transcript 350K(rot-zone)에서 PCT별 경고 유무:
```bash
# rot-timing (GAP-018): 350K(rot-zone)에서 PCT=55는 무경고(THRESHOLD 450K)=재캘리브 전 문제, PCT=40은 경고(THRESHOLD 300K)
test_acw_rot() {  # $1 name  $2 pct  $3 want(warn|silent)
  TOTAL=$((TOTAL+1))
  local tf="$SCRATCH/acwrot-$2.jsonl"; printf '{"message":{"model":"claude-opus-4-8","usage":{"input_tokens":350000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":0}}}\n' > "$tf"
  local sid="acwrot-$$-$2"; rm -f "/tmp/compact-alerted-$sid"
  local out; out=$(echo "{\"session_id\":\"$sid\",\"transcript_path\":\"$tf\"}" | CLAUDE_AUTOCOMPACT_PCT_OVERRIDE="$2" "$HOOKS/auto-compact-watch.sh" 2>&1)
  rm -f "/tmp/compact-alerted-$sid" "$tf"
  local good=0
  if [ "$3" = "warn" ]; then echo "$out" | grep -q 'auto-compact' && good=1
  else [ -z "$out" ] && good=1; fi
  [ "$good" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("auto-compact-watch/$1 (want=$3 got:$out)")
}
test_acw_rot "189-rot-pct55-silent" 55 silent
test_acw_rot "190-rot-pct40-warn"   40 warn
```
- [ ] **Step 2: 실행** — `bash hooks/tests/run-all.sh` → 189/190 PASS(파생 로직이 값에 반응 실증). 무회귀.
- [ ] **Step 3: cases.tsv + README** — 2행 추가(189/190) → cases.tsv 168→170. README `168 case/케이스`(276·514) → `170`.
- [ ] **Step 4: commit** — `feat(gap-018): auto-compact-watch rot-timing 검증(55%무경고/40%경고 @350K) run-all 168→170`

### Task 4: playbook §5-5 rot-정렬 트리거 정책 문서
**Files:** Modify: `docs/harness-upgrade-2026-07/05-playbook.md`

- [ ] **Step 1: §5 함정 5(`[1m]` suffix) 확장** — rot-정렬 트리거 정책 추가: 왜 40%(rot 곡선·dumb-zone)·WINDOW=1M 가드(창 붕괴 시 40%=80K 과빈발)·라이브 settings.json 수동 변경 절차(재시작 후 `/context` 1M+트리거 400K 확인)·1세션 관찰은 RPI 연속성이 흡수(지연 선언).
- [ ] **Step 2: commit** — `docs(gap-018): playbook §5 rot-정렬 트리거 정책 + WINDOW=1M 가드 + 라이브 수동절차`

### Task 5: 검증 + Closeout
- [ ] **Step 1: staged verify-all** — verify-setup 76/0(#39 GREEN)·seal-regression PASS(example rot-정렬 복제 커버)·run-all 170·verify-all ALL PASS. #39 RED→GREEN 실증.
- [ ] **Step 2: 03 D3 재채점** — 3→4(L4 트리거 conjunct 충족; L5 나머지 창-매핑·캐시 hit-rate 별도 선언). 종합표·min 갱신.
- [ ] **Step 3: 04 GAP-018 DONE** — 커밋 가능분(example/doctor/seal/test/doc) + per-machine 지연분(라이브 PCT·/context·관찰) 명시. README 상태 C6 행.
- [ ] **Step 4: PR → (머지 직전 origin/master seal 재확인·충돌 시 #39 재번호) → auto-merge → state bump(53→54 조정) → drift review-strict → 보고+next-cycle-goal(GAP-006/GAP-010)**.
