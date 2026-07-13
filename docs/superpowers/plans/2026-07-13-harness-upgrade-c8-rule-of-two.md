# Harness Upgrade C8 — GAP-013 Rule-of-Two + GAP-007a deny = D11 L4 완주 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Status:** completed
**RPI-Cycle:** 56
**Started:** 2026-07-14
**Completed:** 2026-07-14

**Best-Direction Check:** 최선안 = **D11 L4를 정직하게 완주** = 3 conjunct 전부 착륙(핀/diff-review[C7]·Rule-of-Two[C8]·deny 최후방어선[C8]). ★Gate P 정정 반영: 03 L149 앵커·C7 노트(03)가 명시한 대로 D11 L4 = **3 conjunct**이며 deny=**GAP-007a**(GAP-007의 (a) deny규칙 부분="지금 즉시 가능", 04 L138)이 **L4 conjunct**(GAP-007의 (b) srt OS-sandbox만 L5). 따라서 GAP-013 단독은 2/3(미bump) — **GAP-007a(deny)를 같은 사이클에 착륙시켜 L4 완주 → D11 3→4 HONEST**. 사용자 핵심 우려(쉬운 대안 회피·최선방향)대로 부분-착륙 방치 대신 L4 완성이 최선.
- **Rule-of-Two(GAP-013)**: `explore-strict`(reader)는 이미 `tools: Read, Grep, Glob, WebFetch`(WebFetch=untrusted 웹·쓰기無)=구조적 Rule-of-Two reader. 이 *우연적* 분리를 **명문 통제(SECURITY.md)+seal #41**로 격상.
- **deny 최후방어선(GAP-007a)**: `settings.example.json` permissions.**deny**에 자격증명 read·파괴 명령 패턴 = bypassPermissions에서도 유효한 층(02 §4 deny 규칙은 bypass서도 유효). seal #42 봉인. **런타임 bypassPermissions 실차단 검증=per-machine 지연**(C6 선례; 커밋분=deny 규칙+seal).
- **DOWNGRADE-DECLARED: 없음.** opencode 미러: explore-strict/settings는 claude-hooks 고유(opencode=정적 opencode.json permission) — 규약 canonical 전용 선언(무이식). GAP-007의 (b) srt OS-sandbox(L5)=별 사이클.

**Goal:** D11 L4 완주(3 conjunct) → 3→4. 관찰가능 success: (1) SECURITY.md Rule-of-Two+deny 섹션 grep + explore-strict 근거 (2) verify-setup #41(explore-strict no-write)·#42(settings.example deny 존재) RED→GREEN (3) seal-regression 변이(explore Write 추가·deny 제거)→#41·#42 FAIL 증명 (4) verify-all ALL PASS.

**Tech Stack:** agents/explore-strict.md·SECURITY.md·settings.example.json(permissions.deny)·verify-setup seal(bash grep)·seal-regression mutator.

## Global Constraints
- **착수 실측**: verify-setup 현재 **77**. run-all **172**(신규 run-all 케이스 없음). seal 최고 **#40**. 신규 = **#41**(Rule-of-Two)·**#42**(deny), 둘 다 #36 앞 → 77→**79**. ★동시세션 seal 충돌: 머지 직전 origin/master 실측·재번호.
- explore-strict `tools:` 라인 **불변**(이미 올바름·본문에만 근거). settings.example permissions=현재 {allow, defaultMode} → **deny 배열 추가**(additive; #23은 hook parity라 무관·확인).
- seal = **bash grep**(node 금지, C6/C7 교훈). seal-regression make_replica는 agents·settings.example.json 복제(확인) → 변이 mutator 가능.
- 신규 seal 2개 → verify-setup 77→79 → README `현재 N PASS`(#36) 동기. seal-regression PASS 5→7.

---

### Task 1: SECURITY.md Rule-of-Two + deny 섹션 + explore-strict 근거
**Files:** Modify: `SECURITY.md`, `agents/explore-strict.md`

- [x] **Step 1: SECURITY.md 섹션** — `## 동시-세션 격리` 뒤에 `## Rule-of-Two 세션 분리 + deny 최후방어선 (lethal trifecta 방어)`:
  - lethal trifecta(02 §4)=untrusted 입력+시크릿 접근+쓰기/exfil 공존→인젝션 탈취. "인젝션 조심" 프롬프트는 영구속성이라 기각 — 구조 분리만 작동.
  - **Rule-of-Two**: untrusted-웹 읽기는 `explore-strict`(reader: Read/Grep/Glob/WebFetch, 쓰기無)에 위임→발견만 반환; 오케스트레이터 검증 후 privileged 행동은 `execute-strict`(writer, untrusted 웹無). 두 능력 한 wrapper 공존 금지. seal #41 봉인.
  - **deny 최후방어선**: `settings.json`(예시=`settings.example.json`) permissions.deny에 자격증명 read·파괴 명령(`rm -rf` 등) 차단 — **bypassPermissions에서도 유효한 최후 층**. seal #42 봉인. 잔여(정직): OS-레벨 sandbox(srt)=GAP-007 L5; 런타임 bypass 실차단 검증=per-machine.
  - 잔여(정직): 메인 오케스트레이터 세션은 전 도구 보유(구조상 불가피) — Rule-of-Two는 *위임 패턴* 권고, seal은 *wrapper* 강제.
- [x] **Step 2: explore-strict.md 본문** — 프론트매터 `tools:` **불변**. 본문에 1줄: "★Rule-of-Two(SECURITY.md): 이 reader의 쓰기도구 미부여는 *의도된 lethal-trifecta 방어*. verify-setup #41 봉인."
- [x] **Step 3: grep + commit** — `grep -q 'Rule-of-Two' SECURITY.md agents/explore-strict.md && grep -q 'deny 최후방어선' SECURITY.md`. commit: `docs(gap-013/007a): SECURITY.md Rule-of-Two+deny 최후방어선 + explore-strict no-write 근거`

### Task 2: settings.example permissions.deny (deny 최후방어선)
**Files:** Modify: `settings.example.json`

- [x] **Step 1: deny 배열 추가** — permissions에 `deny`(allow 옆). 자격증명 read + 파괴 명령:
```json
    "deny": [
      "Read(**/.credentials.json)",
      "Read(**/.env)",
      "Read(**/.env.*)",
      "Read(**/id_rsa)",
      "Read(**/id_ed25519)",
      "Bash(rm -rf ~)",
      "Bash(rm -rf /)"
    ]
```
- [x] **Step 2: JSON valid + commit** — `node -e "require('./settings.example.json')"`. commit: `feat(gap-007a): settings.example permissions.deny — 자격증명 read·파괴명령 최후방어선 (bypass서도 유효)`

### Task 3: verify-setup seal #41(Rule-of-Two) + #42(deny) RED→GREEN
**Files:** Modify: `setup/verify-setup.sh`, `README.md`

- [x] **Step 1: seal 삽입** — #40 뒤, #36 앞. 둘 다 bash grep:
```bash
# 41. explore-strict(웹-읽기 reader) 쓰기도구 미부여 = Rule-of-Two 봉인 (GAP-013 D11 L4):
#     lethal trifecta 구조분리 — reader tools 에 Write/Edit/Bash/NotebookEdit 부여 시 FAIL. bash grep(staged-safe).
ES_TOOLS=$(grep -E '^tools:' "$HOME/.claude/agents/explore-strict.md" 2>/dev/null | head -1)
if [ -z "$ES_TOOLS" ]; then
  fail "explore-strict tools 라인 부재 (GAP-013)"
elif echo "$ES_TOOLS" | grep -qE '\bWebFetch\b' && ! echo "$ES_TOOLS" | grep -qE '\b(Write|Edit|NotebookEdit|Bash)\b'; then
  ok "explore-strict reader 쓰기도구 미부여 (Rule-of-Two)"
else
  fail "explore-strict Rule-of-Two 위반 (GAP-013): reader tools 에 쓰기도구 부여 또는 WebFetch 부재 — lethal trifecta 표면"
fi

# 42. settings.example deny 최후방어선 존재 (GAP-007a D11 L4): 자격증명 read·파괴명령 deny 규칙이 사라지면 FAIL.
#     bypassPermissions 에서도 유효한 층(02 §4). bash grep(staged-safe).
EX_SET="$HOME/.claude/settings.example.json"
if [ ! -f "$EX_SET" ]; then
  fail "settings.example.json 부재 (GAP-007a)"
elif grep -qE '"deny"' "$EX_SET" && grep -qE 'credentials|\.env|id_rsa' "$EX_SET" && grep -qE 'rm -rf' "$EX_SET"; then
  ok "settings.example deny 최후방어선(자격증명·파괴명령) 존재"
else
  fail "settings.example deny 최후방어선 부재 (GAP-007a): permissions.deny 에 자격증명 read·파괴명령 규칙 필요"
fi
```
- [x] **Step 2: RED 실측** — explore Write 추가 / deny 제거 복제본에서 #41·#42 FAIL(Task 4 seal-regression 정식 증명); 여기선 로직 직접 확인.
- [x] **Step 3: README** — `현재 77 PASS` → `79`.
- [x] **Step 4: GREEN + commit** — staged verify-setup 79/0. commit: `feat(gap-013/007a): verify-setup #41 Rule-of-Two + #42 deny seal (77→79, RED→GREEN)`

### Task 4: seal-regression 변이 mutator (Rule-of-Two·deny 위반 → FAIL 증명)
**Files:** Modify: `setup/tests/seal-regression.test.sh`

- [x] **Step 1: mutator 2개 추가**:
```bash
# Mutator 4 — seal #41 (explore-strict Rule-of-Two): reader tools 에 Write 부여 → #41 FAIL.
mut_explore_write() { sed -i -E 's/^(tools:.*WebFetch.*)$/\1, Write/' "$1/agents/explore-strict.md"; }
# Mutator 5 — seal #42 (deny 최후방어선): settings.example 의 deny 규칙 제거 → #42 FAIL.
mut_strip_deny() { sed -i -E '/"deny"[[:space:]]*:/,/\]/d' "$1/settings.example.json"; }
```
assert 추가:
```bash
assert_seal_fires "explore_rule_of_two" mut_explore_write "explore-strict Rule-of-Two 위반"
assert_seal_fires "deny_last_line"       mut_strip_deny    "deny 최후방어선 부재"
```
- [x] **Step 2: 실행** — staged seal-regression → control PASS + 2 신규 mutant PASS(#41·#42 발화). ★mut_strip_deny 후 settings.example JSON 유효성 주의: `/,/\]/d`가 deny 배열만 제거·trailing comma 잔여 가능 → seal은 텍스트 grep이라 JSON 파싱 무의존(deny 텍스트 사라지면 #42 fail)이므로 OK. PASS 5→7.
- [x] **Step 3: commit** — `test(gap-013/007a): seal-regression explore-Write·deny-strip 변이 → #41·#42 FAIL 증명`

### Task 5: 검증 + Closeout
- [x] **Step 1: staged verify-all** — verify-setup 79/0(#41·#42 GREEN)·seal-regression 7/0(신규 2 변이 발화)·run-all 172 무회귀·verify-all ALL PASS.
- [x] **Step 2: 03 D11 재채점** — **3→4**(L4 완주: 핀[C7]+Rule-of-Two[C8]+deny[C8]=3 conjunct 전부). C7 노트의 "L4=4는 GAP-013·GAP-007a 후속"이 이 사이클에 실현 = 정직 일관. 종합표 D11 3→4·min 문장(D11 제거→min-3=D5·D7·D9). srt OS-sandbox(GAP-007b)=L5 잔여 명기.
- [x] **Step 3: 04 GAP-013 DONE + GAP-007 (a)부분 DONE(C8)·(b)srt L5 잔여** — README 상태 C8 행.
- [x] **Step 4: PR → (머지 직전 seal 재확인) → auto-merge → state bump(55→56) → drift review-strict → 보고+next-cycle-goal(GAP-010 D1 커버리지 또는 GAP-012 D7)**.
