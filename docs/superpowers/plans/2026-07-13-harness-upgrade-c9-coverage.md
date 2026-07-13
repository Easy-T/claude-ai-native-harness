# Harness Upgrade C9 — GAP-010 미테스트 표면 커버 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Status:** paused
**RPI-Cycle:** 57
**Started:** 2026-07-14
**Paused:** 2026-07-14 — 사용자 요청으로 보류. **완료분**: Task 1(enforce-orchestrator ERR-센티넬 hook_log FAILOPEN, 커밋 `1196639`). **잔여**: Task 2(커버리지 6 케이스 — 전부 로직 실측 완료[193 model-window /1m/·194 opus[1m]·195/196/197 secret GitHub/Slack/PrivKey·198 stable-claude-md ALERT], run-all.sh 미배선), Task 3(closeout·D1 4 유지·머지). **재개**: 이 plan Status `paused`→`active` 후 Task 2부터.

**Best-Direction Check:** 최선안 = 회귀 감지선(커버리지)을 넓히고 **무로깅 fail-open을 0화**(D1 L5 요건: 조용한 fail-open은 회귀를 숨긴다 — cycle-37 vacuous RED 교훈). 채택안 = 동일: ①enforce-orchestrator ERR-센티넬(현재 `[ "$SKEL" = "ERR" ] && exit 0` **무로깅**)에 `hook_log FAILOPEN` 추가 ②미커버 표면 6 케이스(01 §6-2/6-3 선별): model-window `/1m/` 행·secret-scan 미테스트 4(GitHub/Slack/PrivKey/placeholder-면제)·stable-claude-md ALERT 단언. (skeleton-scan ERR은 기존 case 74 커버 — 중복 회피; ERR-센티넬 표면화는 ① Task 1 hook_log.) **더 쉬운 대안 "작동 중이니 방치" 기각**(가드 변경이 기존 차단 무효화해도 침묵 — 커버리지가 유일 감지). **DOWNGRADE-DECLARED: 없음.** opencode 미러: enforce-orchestrator hook_log은 claude-hooks 고유 — 미이식 선언.

**정직 목표 = D1 4 유지(점수 미bump·부분 L5 진척)** ★착수 시 L5 앵커 실측: D1 L5 = L4 + **3 conjunct**(①전표면 MCP 포함 게이트 ②모든 fail-open 로깅·표면화 ③OS-레벨 백스톱 deny/sandbox). GAP-010은 **②(ERR-센티넬 로깅=마지막 무로깅 fail-open 0화)만 착륙**; ③(deny)은 C8 #42가 이미 착륙; **①MCP 게이트는 미해결**(전용 GAP 부재·MCP 도구 hook-게이팅 난이=별 축). ∴ **conjunctive L5는 2/3 → D1 점수 4 유지**(C7/C8 conjunctive 정직 선례 계승; over-claim 회피 — Gate P 잡기 전 선제 정정). **GAP-010 가치는 점수bump 아닌 커버리지 breadth(6 회귀 감지선)+fail-open 표면화**(그 자체 고가치 — Best-Direction=올바른 작업 > 점수). MCP 게이트가 착륙하면 D1→5(후속·별 GAP).

**★시크릿 리터럴 규약**: secret-scan 테스트는 파일에 **리터럴 시크릿 0**(런타임 조립) — 기존 규약(run-all `FAKE_ANT` 선례; PrivKey 마커도 분할 `"...OPENSSH ""PRIVATE KEY..."` 조립). 이 plan 문서 자체도 리터럴 마커 미포함.

**Goal:** 미테스트 표면 6 케이스 + ERR-센티넬 무로깅 0화. **D1 4 유지**(부분 L5 진척=②fail-open 로깅; MCP 게이트 미완). success: (1) enforce-orchestrator ERR 경로 hook_log(FAILOPEN) grep 단언 (2) run-all +6=178(cases.tsv·README·#20 동기)·6 신규 케이스 GREEN (3) verify-all ALL PASS.

**Tech Stack:** hooks/enforce-orchestrator.sh·run-all.sh(test_lib/test_ess/신규 stderr 드라이버)·cases.tsv·README.

## Global Constraints
- **착수 실측**: verify-setup 현재 **79**(C9 신규 seal 없음). run-all **172**. 케이스 번호 193+(190·192 회피). seal 최고 #42.
- 신규 6 케이스 → run-all 172→178 → cases.tsv+README(#20, README:276·514) 178 동기.
- enforce-orchestrator hook_log = FAILOPEN verdict(doctor 20e FAILOPEN>0 WARN·run-log 흡수 — 기존 패턴). fail-open 보존(exit 0 유지, 로깅만 추가).
- 테스트=임시 $HOME/SCRATCH 격리 — 기존 test_lib/test_ess 패턴 복제. secret 마커는 런타임 분할 조립(리터럴 0).

---

### Task 1: enforce-orchestrator ERR-센티넬 hook_log (무로깅 fail-open 0화)
**Files:** Modify: `hooks/enforce-orchestrator.sh`

- [ ] **Step 1: ERR 경로 hook_log 추가** — `[ "$SKEL" = "ERR" ] && exit 0` → `[ "$SKEL" = "ERR" ] && { hook_log "enforce-orchestrator" "$FILE_PATH" "FAILOPEN" "skeleton-scan ERR (파서 실패 fail-open)"; exit 0; }`. (EMPTY 경로는 정상 통과라 로깅 불요 — ERR만 fail-open.)
- [ ] **Step 2: 구문 + commit** — `bash -n`. commit: `feat(gap-010): enforce-orchestrator ERR-센티넬 hook_log FAILOPEN — 무로깅 fail-open 0화 (D1 L5)`

### Task 2: 커버리지 6 케이스 (RED→GREEN)
**Files:** Modify: `hooks/tests/run-all.sh`, `hooks/tests/cases.tsv`, `README.md`

- [ ] **Step 1: RED 확인** — 각 표면 현행 미커버 grep(예: `grep -c '193-\|modelwin-1m' run-all.sh`=0).
- [ ] **Step 2: 케이스 추가**(model-window/skeleton은 test_lib, secret은 test_ess, stable은 신규 드라이버):
  - **⑤ model-window `/1m/`**: `test_lib "193-modelwin-1m" "1000000" "$(node "$LIB/model-window.js" claude-neo-1m)"` (opus/fable 미매칭·`/1m/`만).
  - **⑤ model-window `[1m]` 프로덕션 ID**(test_lib, 미커버): `test_lib "194-modelwin-opus-1m-suffix" "1000000" "$(node "$LIB/model-window.js" 'claude-opus-4-8[1m]')"` (case 78은 suffix-없는 plain opus만 — 실 프로덕션 ID `claude-opus-4-8[1m]`[autocompact 워크어라운드]가 1M 해소 미커버·load-bearing). ※placeholder 면제는 기존 case 43·skeleton ERR은 case 74가 이미 커버 → 중복 회피; ERR-센티넬 표면화는 Task 1 hook_log + Task 3 grep.
  - **① secret GitHub**: `FAKE_GH="gh""p_$(printf 'a%.0s' $(seq 1 40))"; test_ess "195-secret-github" 2 "$(mk_event Write "$SCRATCH/x.md" "t=$FAKE_GH")"`.
  - **① secret Slack**: `FAKE_SLK="xox""b-$(printf '1%.0s' $(seq 1 12))"; test_ess "196-secret-slack" 2 "$(mk_event Write "$SCRATCH/x.md" "s=$FAKE_SLK")"`.
  - **① secret PrivKey**(마커 분할 조립=리터럴 0): `FAKE_PK="-----BEGIN OPENSSH ""PRIVATE KEY-----"; test_ess "197-secret-privkey" 2 "$(mk_event Write "$SCRATCH/x.md" "$FAKE_PK")"`.
  - **② stable-claude-md ALERT**(신규 stderr 드라이버, 미커버=ALERT 단언): test_scm은 exit만 봄. ★경로 실측: 글로벌 `$HOME/.claude/CLAUDE.md`는 stable-claude-md.sh:11서 제외-종료(ALERT 전)→**비-글로벌 `$SCRATCH/CLAUDE.md`**로 ALERT 발화(문구="[cache-stability] 루트 CLAUDE.md 수정 감지"):
    ```bash
    test_scm_alert() {  # $1 name
      TOTAL=$((TOTAL+1))
      local err; err=$(echo "$(mk_event Edit "$SCRATCH/CLAUDE.md" "x")" | "$HOOKS/stable-claude-md.sh" 2>&1 >/dev/null)
      echo "$err" | grep -qF 'cache-stability' && PASSED=$((PASSED+1)) || FAILED_LIST+=("stable-claude-md/$1 (ALERT 미발화: $err)")
    }
    test_scm_alert "198-scm-alert-asserted"
    ```
- [ ] **Step 3: GREEN 실행** — `bash run-all.sh` → 193-198 PASS·기존 무회귀.
- [ ] **Step 4: cases.tsv + README** — 6행(193-198) → 172→178. README `172 case/케이스`(276·514) → `178`.
- [ ] **Step 5: commit** — `feat(gap-010): 커버리지 6 케이스(model-window /1m/·secret GitHub/Slack/PrivKey·skeleton ERR·stable-claude-md ALERT) run-all 172→178`

### Task 3: 검증 + Closeout
- [ ] **Step 1: staged verify-all** — run-all 178·verify-setup 79/0(무변)·seal-regression 5/0·verify-all ALL PASS. enforce-orchestrator ERR hook_log grep 단언.
- [ ] **Step 2: 03 D1 재채점** — **점수 4 유지**(부분 L5 진척): GAP-010 = L5 conjunct ②(모든 fail-open 로깅·표면화=ERR-센티넬 0화) 착륙 + 커버리지 breadth. **①전표면 MCP 게이트 미해결로 conjunctive L5 미완 → 4 유지**(③deny는 C8 착륙). D1 앵커에 C9 부분-진척 노트 + 종합표 비고(무bump 사유). min 무변(D1은 min-3 아님).
- [ ] **Step 3: 04 GAP-010 DONE** — README 상태 C9 행.
- [ ] **Step 4: PR → auto-merge → state bump(56→57) → drift review-strict → 보고+next-cycle-goal(GAP-012 D7 또는 GAP-002bc D5)**.
