# C14 — C13 잔여 종결 + eval 층(GAP-012) + doctor #23 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 65
**Started:** 2026-07-28

**Goal:** C13이 "완료"로 보고했으나 적대 검증이 뒤집은 잔여(goal 성공기준 3개 미충족 + material drift 7건)를 전부 닫고, 같은 클래스의 재발을 막는 매니페스트 자동 봉인과 eval 층(GAP-012)을 세운다.

**Architecture:** 신규 설계 최소 — **선언과 실물의 간극을 닫는 것**이 목적. 3축으로 나뉜다: ①매니페스트가 디스크와 어긋나도 침묵하는 구멍을 **디스크=SSOT 대조 seal**로 봉인(C14-A) ②사용자-대면 텍스트·spec 인용의 drift 정정(C14-B/E) ③탐지 커버리지 확장(C14-C 파서 삼항, C14-D Rule C3 축 재정의)과 그 회귀 봉인(C14-F 뮤테이터). 부수로 doctor #23 오보 정정(C14-G)과 non-obvious 신설+픽스처 규약(C14-H/J).

**Tech Stack:** bash(POSIX/MSYS, Git Bash) · node(파서 `hooks/lib/*.js`, stdin 전달만) · git

## Global Constraints

- **seal/드리프트 검사는 bash 파일옵스만** — node 보간형 금지. C14-G가 그 위반 인스턴스를 정정하는 사이클이라 신규 도입은 자기모순. (spec §13.8·§13.10)
- **`settings.json`은 gitignored + `ANTHROPIC_AUTH_TOKEN` 보유** — `git add` 절대 금지(`-f` 포함), **값 출력 금지**(키 존재/숫자 비교만). (goal §5)
- **`~/.ccs/` 및 심링크 대상은 읽기만** — 리포 밖 파일 수정 금지. (goal §5)
- **설치·로그인·인증·업데이트 시도 절대 금지**(codex/ChatGPT OAuth 토큰 패밀리 revoke 이력). `~/.codex/config.toml` 쓰기 금지. (goal §5)
- **루트 `CLAUDE.md` 수정은 세션 종료 직전에만**(§1 캐시 안정성) → **Task 9(마지막)** 에 배치. (goal §5)
- `verify-setup`·`seal-regression`·`run-all`은 **포그라운드만**, **서브에이전트에 실행 위임 금지**(600s watchdog 스톨 실측 이력). (goal §5)
- wrapper agent(execute/review/explore-strict) 호출에 **schema 금지**(StructuredOutput 부재).
- **MERGE_POLICY: wait** — PR까지 만들되 머지는 사용자 명시 승인 후에만. (goal U4)
- 카운트 SSOT: seal 추가 시 `README.md:285` `현재 N PASS` 동기 필수(#36이 자동 FAIL) · 픽스처 추가 시 `README.md:277`·`:515` 235 동기 필수(#20이 자동 FAIL).
- **베이스라인(2026-07-28 브랜치에서 실측)**: `run-all` 235/235 · `verify-setup` 82/0 · `seal-regression` 9/0. 이 이상을 유지한다.

**Best-Direction Check:** 최선안 = 각 결함을 *탐지 자동화*(seal/픽스처)까지 포함해 클래스 단위로 닫고, 파서 미탐은 구조적 원인(깊이-0 첫 `{` 단일 반환)을 고쳐 해소 / 채택안 = **동일**.
- **DOWNGRADE-DECLARED: 없음.**
- 판정 근거(전부 spec §13에 기록): C14-C는 삼항을 *구현*으로 해소하고(후보 수집) opts 오식별은 같은 수정이 실질 흡수하므로 잔여만 정직 공개 — 기능 열화가 아니라 정적 분석의 알려진 상한(§13.7). C14-I(`verifyModel` args) **미채택**은 스코프 축소가 아니라 **설계 판정** — 스크립트가 세션 티어를 모르므로 조건부 삽입이 구조적 부정합이고, §12.6 정정으로 이 잔여는 이미 "침묵 → 관측되는 잔여"로 성격이 바뀌었다(§13.12). C14-J는 파일 신설이 아니라 skill 정정 — `docs/ai-context/{architecture,domain-glossary,deny-patterns,runbook}.md` 부재는 사고가 아니라 아키텍처(cycle-31 선행 판정 실재, §13.4).

## File Structure

| 파일 | 역할 | task |
|---|---|---|
| `setup/verify-setup.sh` (Modify) | seal #46(lib 매니페스트 4-way 디스크 대조) · #47(agents 제외목록 ⊆) · #48(skill 조건부 선언) · item-8 hook 루프 12종 | 1, 4, 9 |
| `setup/doctor.sh` (Modify) | 21b lib 목록 5종 · #23 stdin 전달 정정 | 1, 7 |
| `setup/tests/failopen-surface.test.sh` (Modify) | witness cksum 목록에 `workflow-spawns.js` 추가 | 1 |
| `setup/tests/doctor.test.sh` (Modify) | #23 stdin 회귀 테스트(Test 6) — cases.tsv 무관 | 7 |
| `setup/tests/seal-regression.test.sh` (Modify) | 뮤테이터 `mut_doctor_lib_drop`(T1) · #45 커버 2종(T6) · `mut_skill_conditional`(T9) + **witness 목록 갱신**(T1, 불변식 `:11`) — 총 9→13 | 1, 6, 9 |
| `hooks/lib/workflow-spawns.js` (Modify) | `findOpts` → `findOptsCandidates`(깊이-0 `{` **전부** 수집) + 헤더 한계 공개 갱신 | 3 |
| `hooks/surface-model-policy.sh` (Modify) | Rule C3 축 재정의(제외목록) · Rule B 메시지 floor 표현 정정 | 4, 2 |
| `workflows/rpi-implement.js` (Modify) | `meta.phases[1].detail` 문구 정정 | 2 |
| `README.md` (Modify) | hook 12개 + `surface-model-policy` 행 · `:66` WebSearch · 모델 디스패치 섹션 · 카운트 동기(PASS 82→84→85→86, cases 235→239→242) | 1, 2, 3, 4, 9 |
| `docs/ai-context/non-obvious.md` (**Create**) | 하네스 non-obvious SSOT + 픽스처 동반 규약 | 8 |
| `docs/ai-context/scaffold-registry.md` (Modify) | `:24` hook 설명 옛 표현·사이클 라벨 · 신규 seal #46/#47/#48 등재(제목 카운트 28→31) · non-obvious.md 문서 표 등재 | 1, 2, 4, 8, 9 |
| `docs/ai-context/model-policy.md` (Modify) | Rule C3 축 재정의 서술(`:35`) — 역할×모델 매트릭스 SSOT | 4 |
| `docs/superpowers/specs/2026-07-25-model-policy-design.md` (Modify) | §12.1 stale 인용 5곳 · §12.4-3 ccs 취소 · §3 `:108` 포인터 | 2, 5 |
| `skills/start-rpi-cycle/SKILL.md` · `closeout-pr-cycle` · `improve-codebase-architecture` (Modify) | context_paths 조건부 선언 | 9 |
| `hooks/tests/cases.tsv` + `hooks/tests/run-all.sh` (Modify) | 신규 픽스처(파서 3 + E2E 1 · Rule C3 3) — 총 235→242 | 3, 4 |
| `CLAUDE.md` (Modify) | §4 픽스처 동반 규약 · §5 architecture.md 전제 정정 — **마지막 task** | 9 |

---

### Task 1: C14-A — 매니페스트 자동 봉인 (M1·M2·M7 + 재발 방지 seal #46)

**Files:**
- Modify: `setup/doctor.sh:353` (lib 목록 4→5), `:356` (카운트 문구)
- Modify: `setup/verify-setup.sh:49-50` (item-8 hook 루프 11→12), 신규 seal #46 (파일 끝 seal #45 블록 뒤·#36 블록 앞)
- Modify: `setup/tests/failopen-surface.test.sh:19-21` (witness 목록)
- Modify: `README.md:285` (`현재 82 PASS` → `현재 84 PASS`)
- Modify: `docs/ai-context/scaffold-registry.md` (Seals 표에 #46 등재 + 제목 카운트)

**Interfaces:**
- Produces: seal #46 — `hooks/lib/*.js` 디스크 실재가 4개 매니페스트(doctor 21b · verify-setup item-16 · install.sh REQUIRED · failopen witness) 전부에 포함되는지 `comm -23`으로 대조. Task 4의 seal #47이 같은 관용구를 재사용한다.
- Consumes: 없음(첫 task).

- [x] **Step 1: RED — 신규 seal이 없음을 확인하고, 결함 3건을 실물로 재현**

```bash
cd ~/.claude
# M1: doctor 는 4종만 안다 (디스크는 5종)
sed -n '353p' setup/doctor.sh          # 기대: workflow-spawns 없음
ls hooks/lib/*.js | wc -l              # 기대: 5
# M2: hook 권한 루프에 surface-model-policy 부재
sed -n '49,50p' setup/verify-setup.sh  # 기대: '11 hook scripts' + 11개 목록
# M7: witness 목록도 4종
sed -n '19,21p' setup/tests/failopen-surface.test.sh
# 신규 seal 부재 확인
grep -c '^# 46\.' setup/verify-setup.sh   # 기대: 0
```
Expected: doctor/verify-setup/witness 모두 `workflow-spawns` 누락 · `# 46.` 0건.

- [x] **Step 2: RED 픽스처 — seal #46이 드리프트에 발화함을 증명할 뮤테이터를 먼저 작성**

`setup/tests/seal-regression.test.sh` 의 뮤테이터 정의부(`:92` `mut_floor_shrink` 뒤)에 추가:

```bash
# C14 seal #46: doctor 21b 매니페스트에서 lib 하나를 빼면 디스크 대조가 발화해야 한다
mut_doctor_lib_drop() { sed -i -E 's/(for lf in [a-z-]+ [a-z-]+ [a-z-]+ [a-z-]+) workflow-spawns;/\1;/' "$1/setup/doctor.sh"; }
```

★**witness 불변식 동반 갱신 (필수 — Gate P 신규 발견)**: 이 파일 `:11` 이 선언한 불변식은
*"cksum witnesses on **every file any mutator could touch**"* 다. 신규 뮤테이터가 `setup/doctor.sh` 를
건드리므로 witness 목록(`:19-20`)에 **반드시 추가**한다(빠뜨리면 라이브 오염을 탐지 못 한다):
```bash
witness() { local f; for f in state.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv skills/ui-design/design.md opencode-harness/skill/ui-design/design.md agents/explore-strict.md settings.example.json setup/doctor.sh skills/start-rpi-cycle/SKILL.md; do
              cksum "$SRC/$f" 2>/dev/null; done; }
```
※ `skills/start-rpi-cycle/SKILL.md` 는 Task 9의 `mut_skill_conditional` 이 건드리므로 함께 등재한다
(같은 불변식 — 두 뮤테이터가 서로 다른 task 에서 추가되지만 witness 는 한 곳이라 여기서 한 번에).

그리고 assert 목록(`:106` `assert_seal_fires "floor_18" …` 뒤)에 추가:

```bash
assert_seal_fires "lib_manifest"    mut_doctor_lib_drop    "hooks/lib 매니페스트 drift"
```

- [x] **Step 3: RED 실행 — 뮤테이터가 아직 발화하지 않음을 확인**

Run (포그라운드):
```bash
cd ~/.claude && bash setup/tests/seal-regression.test.sh 2>&1 | tail -6
```
Expected: **FAIL** — `✗ mutant[lib_manifest]: rc=0, missing «hooks/lib 매니페스트 drift»` (seal #46이 없으므로 변이해도 verify-setup이 통과). `seal-regression: PASS=9 FAIL=1`.

- [x] **Step 4: GREEN(a) — M1/M2/M7 매니페스트 3곳 정정**

`setup/doctor.sh:353`:
```bash
for lf in redirect-targets skeleton-scan transcript-usage model-window workflow-spawns; do
```
`setup/doctor.sh:356` — 하드코딩 "4개"를 디스크 실측으로:
```bash
[ "$LIB_FAIL" -eq 0 ] && check "hooks/lib parsers present" "PASS" "$(ls "$CLAUDE_HOME"/hooks/lib/*.js 2>/dev/null | wc -l | tr -d ' ')개" || true
```
`setup/verify-setup.sh:49-50` (주석 카운트 동기 + hook 1개 추가):
```bash
# 8. 12 hook scripts executable
for h in enforce-orchestrator stable-claude-md auto-compact-watch enforce-rpi-cycle enforce-rpi-bash enforce-secret-scan enforce-session-budget verify-loop-watch session-start-audit surface-constitution surface-model-policy worktree-teardown; do
```
`setup/tests/failopen-surface.test.sh:19-21` witness 목록에 파서 추가:
```bash
witness() { local f; for f in hooks/lib/redirect-targets.js hooks/lib/skeleton-scan.js \
                                hooks/lib/transcript-usage.js hooks/lib/model-window.js \
                                hooks/lib/workflow-spawns.js \
                                hooks/enforce-rpi-bash.sh hooks/session-start-audit.sh; do
              cksum "$SRC/$f" 2>/dev/null; done; }
```

- [x] **Step 5: GREEN(b) — seal #46 신설 (디스크=SSOT 4-way 대조)**

`setup/verify-setup.sh` 의 seal #45 블록 끝(`fi` 뒤, `# 36.` 주석 앞)에 삽입. **bash 파일옵스만**:

```bash
# 46. hooks/lib/*.js 매니페스트 자동 봉인 (C14-A, spec §13.8): 디스크가 SSOT.
#     로드-베어링 파서가 매니페스트에서 빠지면 부재해도 침묵 통과한다 — M1(doctor 21b)·M7(witness)이
#     그 실증(C13 신규 workflow-spawns.js 가 3곳 중 2곳에서 누락). seal #24(doctor⊇hooks/*.sh) 동형
#     확장 — 하드코딩 목록이 아니라 디스크와 대조하므로 다음 lib 신설 때 자동 발화한다.
DISK_LIB=$(for f in "$HOME/.claude/hooks/lib/"*.js; do basename "$f" .js; done | sort -u)
lib_missing_in() {  # $1=파일 경로 — 그 파일 텍스트에 없는 lib 이름을 출력
  local hay; hay=$(cat "$1" 2>/dev/null)
  local n; for n in $DISK_LIB; do case "$hay" in *"$n"*) ;; *) printf '%s ' "$n" ;; esac; done
}
MISS46=""
for mf in setup/doctor.sh setup/verify-setup.sh setup/install.sh setup/tests/failopen-surface.test.sh; do
  m=$(lib_missing_in "$HOME/.claude/$mf")
  [ -n "$m" ] && MISS46="$MISS46 $mf:[$m]"
done
if [ -z "$MISS46" ]; then
  ok "hooks/lib 매니페스트 봉인: 디스크 $(printf '%s\n' $DISK_LIB | wc -l | tr -d ' ')종이 doctor·verify-setup·install·witness 전부에 등재"
else
  fail "hooks/lib 매니페스트 drift (C14-A): 누락 —$MISS46. 디스크가 SSOT — 신규 파서는 4곳 모두에 등재해야 함(spec §13.8)"
fi
```

- [x] **Step 6: GREEN 실행 — 카운트 동기 후 3종 전량 통과**

★**체크는 2개 늘어난다**(Gate P 산술 정정): item-8 루프는 **1 iteration = `ok`/`fail` 1회**이므로
Step 4의 `surface-model-policy` 추가가 **+1**, seal #46 신설이 **+1** → **82 → 84**.
(`setup/verify-setup.sh:51` 실물 확인: 루프 본문이 `[ -x … ] && ok … || fail …` 단일 호출.)
`README.md:285` 를 동기:
```
│   ├── verify-setup.sh                   §6.3 file/structure 체크 (현재 84 PASS)
```
Run (포그라운드, 순서대로):
```bash
cd ~/.claude
bash setup/verify-setup.sh 2>&1 | tail -3          # 기대: PASS=84 FAIL=0
bash setup/tests/seal-regression.test.sh 2>&1 | tail -4  # 기대: PASS=10 FAIL=0 (lib_manifest 발화)
bash hooks/tests/run-all.sh 2>&1 | tail -3          # 기대: 235/235 (무회귀)
```

- [x] **Step 7: scaffold-registry 등재**

`docs/ai-context/scaffold-registry.md` Seals 표에 행 추가(기존 `| #45 |` 행 뒤) + 제목 카운트 `#17~#45 … 28` → `#17~#46 … 29`:
```
| #46 | hooks/lib 매니페스트 봉인 (디스크=SSOT, 4-way 대조) | C14 (2026-07-28) |
```
Run: `grep -c '^| #' docs/ai-context/scaffold-registry.md` — 기대: 29 (제목 카운트와 자기검산 일치)

- [x] **Step 8: Commit**

```bash
cd ~/.claude
git add setup/doctor.sh setup/verify-setup.sh setup/tests/failopen-surface.test.sh \
        setup/tests/seal-regression.test.sh README.md docs/ai-context/scaffold-registry.md
git commit -m "feat(c14-a): hooks/lib 매니페스트 자동 봉인 — 디스크=SSOT 4-way 대조 seal #46 + M1/M2/M7 정정"
```

> **설계 검산 (plan 작성 시 실측, 2026-07-28)**: 위 Step 5 로직을 현 디스크에 그대로 돌린 결과
> `setup/doctor.sh:[workflow-spawns] setup/tests/failopen-surface.test.sh:[workflow-spawns]` —
> 실재 드리프트 2건(M1·M7)을 정확히 잡고 이미 5종을 가진 verify-setup·install 은 통과시켰다.
> 즉 이 seal 은 vacuous 하지 않다(Step 4 정정 후엔 빈 출력이 되어야 GREEN).

---

### Task 2: C14-B — 사용자-대면 텍스트 정합 (M3·M4·M5 + spec stale 인용)

**Files:**
- Modify: `hooks/surface-model-policy.sh:159` (Rule B 메시지), `:4` (헤더 주석)
- Modify: `workflows/rpi-implement.js:6` (meta.phases Verify detail)
- Modify: `README.md:28`(제목), hook 표(행 추가), `:66`(explore-strict 도구), 모델 디스패치 섹션 신설
- Modify: `docs/ai-context/scaffold-registry.md:24` (hook 설명 옛 표현 + 사이클 라벨)
- Modify: `docs/superpowers/specs/2026-07-25-model-policy-design.md:108`(§3 산문 supersede 포인터), `:421`·`:447-448`·`:416`(stale live-line 인용 5곳)

**Interfaces:**
- Consumes: 없음(독립).
- Produces: `grep -rn "검증자 티어 ≥ 세션\|검증자 하향 금지"` 가 **genesis-record(완료 사이클 plans) + `_Avoid_` 정의 + §13 M-표 인용**만 남기는 상태. Task 6의 뮤테이터가 이 상태를 봉인하지는 않는다(문면 부정-단언 seal은 이번 범위 밖 — 아래 주 참조).

- [x] **Step 1: RED — 옛 표현이 현행 주장으로 살아있음을 확인**

```bash
cd ~/.claude
# 라이브 코드/문서에서 현행-주장 인스턴스 (genesis plans 제외)
grep -n '검증자 티어 ≥ 세션' hooks/surface-model-policy.sh          # 기대: 159
grep -n '검증자 하향 금지' workflows/rpi-implement.js                 # 기대: 6
grep -n '검증자 하향' docs/ai-context/scaffold-registry.md            # 기대: 24
grep -c 'model-policy' README.md                                      # 기대: 0
grep -n '11개 hook' README.md                                         # 기대: 28
sed -n '66p' README.md                                                # 기대: WebFetch 만, WebSearch 없음
# spec stale 인용: 선언된 행과 실제 행이 다름
sed -n '421p' docs/superpowers/specs/2026-07-25-model-policy-design.md   # ':38'/':53' 이라 씀
grep -n "model: 'opus'\|agentType: 'review-strict'" workflows/rpi-implement.js  # 실제: 42 / 57
```
Expected: 위 각 행이 그대로 존재 · README `model-policy` 0건 · spec 인용(`:38`/`:53`)과 실제(`:42`/`:57`) 불일치.

- [x] **Step 2: M3 — Rule B 메시지를 floor 표현으로 정정**

`hooks/surface-model-policy.sh:159` 의 `emit_additional_context` 문자열에서 옛 문면을 교체:
```
— 검증자 티어 ≥ 세션 티어(작업자 기준선)가 원칙(cross-family-review.md §3).
```
→
```
— 검증자 기준선은 max(세션 티어, 작업자 티어)입니다(spec §12.1, SSOT: docs/ai-context/model-policy.md).
```
같은 파일 `:4` 헤더 주석의 `Rule B(검증자 하향, 전 세션)` 는 **규칙 이름 서술**이라 유지하되 모호성 제거:
```
# Rule B(검증자가 기준선 max(세션,작업자) 미만, 전 세션)·Rule C/C2/C3(Workflow 스크립트 경로 — C12·C13)를 additionalContext 로 환기.
```

- [x] **Step 3: M4 — canonical 캐리어 meta 정정**

`workflows/rpi-implement.js:6`:
```javascript
    { title: 'Verify', detail: 'task별 review-strict (모델 무지정=세션 상속 — 검증자 기준선 max(세션,작업자) 유지)' },
```

- [x] **Step 4: M5 — README 3건 + 모델 디스패치 섹션 신설**

`README.md:28`: `### 11개 hook (활성)` → `### 12개 hook (활성)`
`README.md:66`: explore-strict 도구 목록 정정:
```
| `explore-strict` | 읽기 전용 (Read/Grep/Glob/WebFetch/WebSearch) | 코드베이스 탐색 + 발견 사항 요약 + 웹 근거 조달 |
```
hook 표(`:31` 헤더 아래)에 `surface-constitution` 행 뒤로 행 추가:
```
| `surface-model-policy` | 알림 | PreToolUse `Agent`\|`Workflow` | 역할×모델 매트릭스(구현=opus·탐색=sonnet·검증=기준선 `max(세션,작업자)`)를 `additionalContext`로 환기. Rule A(fable 실행자 하향 미적용)·B(검증자 기준선 미달)·C/C2/C3(Workflow 스크립트 per-spawn 판정 — `hooks/lib/workflow-spawns.js` 파서). 규칙별 1세션 1회, 차단 아님. SSOT: `docs/ai-context/model-policy.md` |
```
그리고 `### 12개 hook (활성)` 표 **뒤**에 섹션 신설(README에 `model-policy` 문자열이 0건이라 하네스의 한 축이 안내서에 없는 상태를 해소):
```markdown
### 모델 디스패치 거버넌스 (역할×모델 매트릭스)

역할별로 다른 모델을 쓴다 — SSOT는 `docs/ai-context/model-policy.md`.

| 역할 | 모델 | effort |
|---|---|---|
| 오케스트레이션·판단·게이트 해석 | 세션 모델 (위임 금지) | 세션 effort |
| 구현 (execute-strict) | **opus** | ultracode: heavy `xhigh` / light `high` |
| 탐색 (explore-strict) | **sonnet** (frontmatter 기본) | **xhigh** + WebSearch/WebFetch |
| 검증 (review-strict) | **상속** — 기준선 `max(세션 티어, 작업자 티어)` 미만 금지 | 상속 |
| 교차 검증 (고-스테이크 closeout) | GPT (`cross-family-review.md` 규약) | 사이클당 1회 |

강제는 3층: **L1** 문서(이 표 + `start-rpi-cycle` skill) · **L2** hook `surface-model-policy`(advisory 환기, 차단 아님) · **L3** verify-setup seal #45(토큰 존재 봉인). 상향은 항상 허용, 하향은 검증자에 한해 `DOWNGRADE-DECLARED(사유)`가 유일 탈출구.
```

- [x] **Step 5: scaffold-registry `:24` 정정**

```
| `surface-model-policy.sh` | fable 실행자 하향 미적용·검증자 기준선 max(세션,작업자) 미달을 advisory 환기(역할×모델 매트릭스 L2) | tri-model C11 (2026-07-25), C12/C13 확장 |
```

- [x] **Step 6: spec stale live-line 인용 5곳 정정 (적대 검증 D 지적)**

`docs/superpowers/specs/2026-07-25-model-policy-design.md`:
- `:421` `model:'opus'`(:38) → `(:42)` · 무지정(:53) → `(:57)`
- `:447` stage2 opts(:52-56) → `(:56-60)`
- `:448` args 스키마(:24-31) → `(:25-35)`
- `:416` `hooks/surface-model-policy.sh:105-114` → `:126-162`
각 정정 지점에 시점 라벨을 덧붙여 재발을 막는다(§12.6 D3 선례 동형):
```
> **행 인용 갱신 (C14, 2026-07-28)**: 위 행 번호는 C13 이 `:20-23` 에 4줄을 삽입하면서 밀려난 것을
> 실측 재대조한 값이다. 이 절의 인용은 load-bearing(탈출구 부재 논증의 근거)이므로 캐리어 편집 시
> 동반 갱신 대상이다.
```
**§12.1 '동반 갱신 필요 목록'(`:463-469`) 말미에 포인터 1줄 추가**(목록 자체는 C13 Gate R 시점의
genesis 기록이라 항목을 늘리지 않는다 — Self-Review 갭 3):
```
※ **C14 보강**: 위 목록은 C13 Gate R 시점의 전수 결과다. 그 전수가 놓친 실사용 인스턴스
  (`hooks/surface-model-policy.sh:159` Rule B 메시지 · `workflows/rpi-implement.js:6` meta detail 등)는
  **§13.6 material drift 표**가 전수 기록한다 — 동반 갱신 대상의 현행 SSOT 는 §13.6 이다.
```
`:108` 산문에 supersede 포인터 추가(`:105` 표 선례 동형):
```
- **상향은 항상 허용**(사유 불요), **하향은 검증자에 한해 금지**(⚠**§12.1이 supersede**: 기준선은 세션 단독이 아니라 `max(세션, 작업자)`)·실행자는 이 표 자체가 선언이다.
```

- [x] **Step 7: GREEN — 현행-주장 인스턴스 0건 확인**

```bash
cd ~/.claude
# 라이브 코드/런타임 노출 텍스트에 옛 표현이 남았는가 (genesis plans·_Avoid_ 정의·§13 M-표 인용은 정당)
grep -rn '검증자 티어 ≥ 세션\|검증자 하향 금지' \
  hooks/ workflows/ README.md docs/ai-context/ 2>/dev/null
```
Expected: **빈 출력**(rc=1).
```bash
grep -c 'model-policy' README.md      # 기대: ≥1
grep -c '12개 hook' README.md          # 기대: 1
sed -n '66p' README.md | grep -c WebSearch   # 기대: 1
# spec 인용 정합 자기검산 — 기계 대조(눈 대조 금지)
A=$(grep -n "model: 'opus'," workflows/rpi-implement.js | head -1 | cut -d: -f1)
B=$(grep -n "agentType: 'review-strict'," workflows/rpi-implement.js | head -1 | cut -d: -f1)
echo "actual stage1=$A stage2=$B"
grep -n "(:$A)" docs/superpowers/specs/2026-07-25-model-policy-design.md | head -2
grep -n "(:$B," docs/superpowers/specs/2026-07-25-model-policy-design.md | head -2
```
Expected: `actual stage1=42 stage2=57` · spec §12.1 `:421` 이 `(:42)`·`(:57)` 을 인용(정정 후).
정정 전이라면 두 grep 이 **빈 출력**(= stale 인용 잔존 = RED).
Run (포그라운드): `bash setup/verify-setup.sh 2>&1 | tail -3` — 기대 `PASS=84 FAIL=0`(Task 1 이후 기준, 무회귀).

> **주(정직 공개)**: 이 정합을 지키는 **문면 부정-단언 seal 은 신설하지 않는다**. 적대 검증이 지적한
> "회귀 봉인 없음"은 사실이나, 부정-단언 seal(`'검증자 하향 금지' 부재`)은 `_Avoid_` 정의문·genesis
> plans·§13 M-표의 **정당한 인용까지 FAIL 시킨다**(현재 그 인용이 6곳 실재). 앵커를 "hooks/ workflows/
> README/ai-context 하위에서만"으로 좁히면 seal 이 디렉터리 구조에 결속돼 취약해진다.
> → **수용 잔여**로 기록하고 Task 6의 뮤테이터는 #45 축만 다룬다. 재발 시 grep 1줄로 탐지 가능함을
> 이 plan 이 남긴다. (DOWNGRADE-DECLARED 대상 아님 — 신규 기능의 열화가 아니라 seal 설계의 적용 범위 판정.)

- [x] **Step 8: Commit**

```bash
cd ~/.claude
git add hooks/surface-model-policy.sh workflows/rpi-implement.js README.md \
        docs/ai-context/scaffold-registry.md docs/superpowers/specs/2026-07-25-model-policy-design.md
git commit -m "fix(c14-b): 사용자-대면 텍스트 floor 표현 정합 — Rule B 메시지·캐리어 meta·README 12 hook+모델 디스패치 섹션·spec stale 인용 5곳"
```

---

### Task 3: C14-C — 파서 삼항 opts 미탐 해소 (M6) + 오식별 잔여 정직 공개

**Files:**
- Modify: `hooks/lib/workflow-spawns.js:174-188` (`findOpts` → `findOptsCandidates`), `:153` (호출부), `:23-31` (한계 공개)
- Modify: `hooks/tests/cases.tsv` (3행 추가), `hooks/tests/run-all.sh` (3 케이스 + 픽스처 변수)
- Modify: `README.md:277`·`:515` (235 → 239)

**Interfaces:**
- Consumes: 없음(파서는 독립 — hook 은 이 파서 출력을 소비하지만 계약(`<agentType>\t<model>` 스폰당 1행)은 **불변**).
- Produces: 삼항 opts 가 **후보 2개를 각각 스폰으로 방출** → 무선언 분기가 관측된다. Task 4의 Rule C3 재정의가 이 출력을 소비하지만 계약 변경이 없어 독립적으로 착륙 가능.

- [x] **Step 1: RED — 삼항 미탐과 오식별을 실물로 재현**

```bash
cd ~/.claude
printf "%s" "await agent('p', h ? {agentType:'execute-strict',model:'opus'} : {agentType:'execute-strict'})" \
  | node hooks/lib/workflow-spawns.js | cat -A
```
Expected(현행 결함): `execute-strict^Iopus` **1행만** — 무선언 분기 소실(= fable 세션 SILENT, 마스킹).
```bash
printf "%s" "await agent(()=>{return 1},{agentType:'execute-strict',model:'opus'})" \
  | node hooks/lib/workflow-spawns.js | cat -A
```
Expected(현행 결함): `?^I-` — 첫 인자의 화살표 함수 본문 `{`를 opts로 오식별.

- [x] **Step 2: RED 픽스처 3건 등록**

`hooks/tests/cases.tsv` 끝(파서 케이스 마지막 `hooks-lib` 행 뒤)에 3행 추가 — **탭 구분**:
```
hooks-lib	200-ws-ternary-opts-both	0	test_lib
hooks-lib	201-ws-firstarg-arrow-body	0	test_lib
hooks-lib	202-ws-ternary-verifier	0	test_lib
```
`hooks/tests/run-all.sh` 의 파서 케이스 블록 끝(마지막 `test_lib "199-…"` 뒤)에 추가:
```bash
# C14: 삼항 opts — 두 분기를 각각 스폰으로 방출(준수 리터럴이 무선언을 가리지 않음, spec §13.7)
test_lib "200-ws-ternary-opts-both" \
  "$(printf 'execute-strict\topus\nexecute-strict\t-')" \
  "$(printf "%s" "await agent('p', h ? {agentType:'execute-strict',model:'opus'} : {agentType:'execute-strict'})" | node "$HOOKS/lib/workflow-spawns.js")"
# C14: 첫 인자의 화살표 함수 본문이 진짜 opts 를 **가리지 않는다** — 후보 전수 수집이라 둘 다 방출된다.
#   종전엔 '?\t-' 1행만 나와 execute-strict/opus 선언이 통째로 소실됐다(미탐). 이제 2행이며
#   첫 행 '?\t-' 는 화살표 본문(안전 방향 오탐 — spec §13.7 정직 공개), 둘째 행이 진짜 opts.
test_lib "201-ws-firstarg-arrow-body" \
  "$(printf '?\t-\nexecute-strict\topus')" \
  "$(printf "%s" "await agent(()=>{return 1},{agentType:'execute-strict',model:'opus'})" | node "$HOOKS/lib/workflow-spawns.js")"
# C14: 검증자 축도 동일 — 삼항의 하향 분기가 소실되지 않는다
test_lib "202-ws-ternary-verifier" \
  "$(printf 'review-strict\topus\nreview-strict\thaiku')" \
  "$(printf "%s" "await agent('v', ok ? {agentType:'review-strict',model:'opus'} : {agentType:'review-strict',model:'haiku'})" | node "$HOOKS/lib/workflow-spawns.js")"
```

- [x] **Step 3: RED 실행 — 3건이 실패함을 확인**

Run (포그라운드):
```bash
cd ~/.claude && bash hooks/tests/run-all.sh 2>&1 | tail -8
```
Expected: **FAIL** — `hooks-lib/200-ws-ternary-opts-both` · `201-ws-firstarg-arrow-body` · `202-ws-ternary-verifier` 3건 + `surface-model-policy/35-rule-c-ternary-masking-e2e` 가 `FAILED_LIST` 에 나타나고 총계 `235 / 239` (E2E 픽스처 35 까지 4건 RED).

- [x] **Step 4: GREEN — `findOpts` 를 후보 수집으로 교체**

`hooks/lib/workflow-spawns.js:174-188` 의 `findOpts` 를 아래로 **치환**(이름 변경 + 배열 반환):
```javascript
// 호출 인자 깊이 0 의 '{...}' 를 **전부** 수집한다 (C14, spec §13.7).
// 단일 '첫 {' 만 취하면 ①삼항 opts 의 둘째 분기가 소실되고(준수 리터럴이 무선언을 가리는 마스킹)
// ②첫 인자의 객체/화살표 본문을 opts 로 오식별한다. 후보를 모두 방출하면 둘 다 안전 방향으로 해소된다.
function findOptsCandidates(mask, open, close) {
  const out = [];
  let p = 0, b = 0;
  for (let i = open + 1; i < close; i++) {
    const c = mask[i];
    if (c === "(") p++;
    else if (c === ")") p--;
    else if (c === "[") b++;
    else if (c === "]") b--;
    else if (c === "{" && p === 0 && b === 0) {
      const e = matchPair(mask, i, "{", "}");
      if (e === -1 || e > close) break;
      out.push([i, e]);
      i = e;                    // 이 후보 내부는 건너뛴다(중첩 객체는 프로퍼티 워크가 처리)
    }
  }
  return out;
}
```
`:153` 호출부를 아래로 **치환** — 후보마다 1스폰 방출, 후보가 없으면 종전대로 1스폰(`?`/`-`):
```javascript
    const cands = findOptsCandidates(mask, open, close);
    const propsList = cands.length ? cands.map((c) => parseProps(mask, strings, c[0], c[1])) : [{}];
    for (const props of propsList) {
      if (out.length >= MAX_SPAWNS) break;
      const at = props.agentType, mo = props.model;
      out.push({
        agentType: at === undefined ? "?" : at === null ? "*" : at,
        model: mo === undefined || mo === null ? "-" : mo,
      });
    }
```
※ 기존 `out.push({...})` 블록(`:156-159` — `:160` 은 while 루프의 닫는 `}` 이므로 **건드리지 말 것**)은 위 루프로 대체되므로 삭제한다.

- [x] **Step 5: 한계 공개 갱신 (정직 공개 — spec §13.7 (b) 축)**

`hooks/lib/workflow-spawns.js:23-31` 한계 목록에서 opts 관련 불릿을 아래로 교체/추가:
```
//   · opts 를 변수로 넘기면(agent('p', OPTS)) 깊이 0 에 '{' 가 없어 키 부재로 보인다 → '?'/'-'.
//     스프레드(...base)로 들어온 키도 마찬가지로 부재 취급.
//   · **인자 경계를 나누지 않는다**(C14 정직 공개): 깊이 0 의 '{...}' 를 **전부** opts 후보로 보고
//     각각을 1스폰으로 방출한다. 삼항 opts 의 모든 분기가 관측되는 대신, 첫 인자가 객체 리터럴이면
//     (agent({t:1},{opts})) 그 객체도 1스폰으로 방출된다 — 대개 agentType/model 키가 없어 '?'/'-' 가
//     되므로 fable 세션에서 Rule C3 **오탐**이 될 수 있다(안전 방향: 미탐보다 오탐 선택).
//     정확한 판정은 "마지막 인자" 의미론(깊이-0 콤마 분할)이 필요하며 1-인자 호출·트레일링 콤마 등
//     경계 케이스를 새로 연다 — 채택하지 않았다(spec §13.7).
//   · Object.assign({},{...}) 처럼 opts 가 호출로 감싸이면 깊이 0 '{' 가 없어 '?'/'-'(미탐 잔여).
```

- [x] **Step 5b: E2E 픽스처 — 미탐 해소를 hook 경유로 실증 (goal §4.3 "E2E로 실증")**

★파서 단위(`test_lib`)만으론 "hook 이 그 출력으로 실제 발화하는가"를 증언하지 못한다(C13의 교훈:
파서는 정확했는데 hook 이 그 행을 버려 p2/p3가 SILENT였다). `test_smp` 로 1건 추가.

`hooks/tests/cases.tsv` 에 1행(탭 구분):
```
surface-model-policy	35-rule-c-ternary-masking-e2e	0	mk_wf_event
```
`hooks/tests/run-all.sh` SMP 블록에 추가:
```bash
# C14: 삼항 opts 마스킹 해소를 hook 경유 E2E 로 실증 — 준수 분기(opus)가 무선언 분기를 가리지 못한다
WF_TERNARY="export const meta = {name: 'x', description: 'x'}
await agent('impl', heavy ? {agentType: 'execute-strict', model: 'opus'} : {agentType: 'execute-strict'})"
test_smp "35-rule-c-ternary-masking-e2e" 0 1 "$(mk_wf_event script "$WF_TERNARY" "$SMP_FABLE_T" "smp35-$$")"
```
Expected(정정 후): **ALERT**(ctx=1) — 정정 전엔 SILENT 였다(파서가 `execute-strict\topus` 1행만 내
Rule C 가 준수로 판정). 이것이 §13.7이 "마스킹 클래스가 호출-내 축에서 생존" 이라 부른 것의 해소 증명.

- [x] **Step 6: GREEN 실행 + 무회귀 확인**

`README.md:277` `235 case` → `239 case`, `:515` `235 케이스` → `239 케이스` 동기(#20 seal).
(파서 3 + E2E 1 = **+4**)
Run (포그라운드):
```bash
cd ~/.claude
bash hooks/tests/run-all.sh 2>&1 | tail -4        # 기대: 239 / 239 · 정합 OK
# canonical 캐리어 무회귀 — 자기고발이 생기지 않아야 한다
node hooks/lib/workflow-spawns.js < workflows/rpi-implement.js | cat -A
#   기대: execute-strict^Iopus / review-strict^I- (2행, 종전과 동일)
bash setup/verify-setup.sh 2>&1 | tail -3          # 기대: PASS=84 FAIL=0
```

- [x] **Step 7: Commit**

```bash
cd ~/.claude
git add hooks/lib/workflow-spawns.js hooks/tests/cases.tsv hooks/tests/run-all.sh README.md
git commit -m "fix(c14-c): 파서 opts 후보 전수 수집 — 삼항 분기 마스킹 해소 + 첫-인자 오식별 완화, 잔여 정직 공개"
```

---

### Task 4: C14-D — Rule C3 축 재정의 (모델-무선언 스폰) + seal #47

> **의존**: Task 3 이후에 실행한다. Gate R 지적 — seal #47이 대조할 "C3 제외 목록"이 이 task 에서
> 처음 생기므로, 목록 신설(Step 3)과 seal(Step 5)이 같은 task 안에 있어야 한다.

**Files:**
- Modify: `hooks/surface-model-policy.sh:73-77` (Rule C3 분기), `:116` (메시지)
- Modify: `setup/verify-setup.sh` (신규 seal #47 — #46 뒤)
- Modify: `hooks/tests/cases.tsv` (3행), `hooks/tests/run-all.sh` (3 케이스)
- Modify: `README.md:285`(84→85), `:277`·`:515`(239→242), `docs/ai-context/model-policy.md:35`(Rule C3 서술), `docs/ai-context/scaffold-registry.md`(#47 등재)

**Interfaces:**
- Consumes: Task 3의 파서 출력(계약 불변 — `<agentType>\t<model>`).
- Produces: `SP_C3_EXCLUDE` 상수(hook 내 리터럴 목록) — seal #47이 `agents/*.md` 의 비-inherit model 선언과 ⊆ 대조한다.

- [x] **Step 1: RED — p2/p3 실측 재현 (goal §4.1 미충족분)**

```bash
cd ~/.claude && mkdir -p /tmp/probe
printf '{"type":"assistant","message":{"model":"claude-fable-5","content":[]}}\n' > /tmp/probe/fable-5.jsonl
mkev(){ KIND="$1" VAL="$2" TP="$3" SID="$4" node -e '
  const ti={}; ti[process.env.KIND]=process.env.VAL;
  console.log(JSON.stringify({session_id:process.env.SID,transcript_path:process.env.TP,cwd:"",
    permission_mode:"bypassPermissions",effort:{level:"xhigh"},hook_event_name:"PreToolUse",
    tool_name:"Workflow",tool_input:ti,tool_use_id:"t"}));'; }
run(){ rm -f /tmp/model-policy-c*-"$3"* 2>/dev/null
       O=$(mkev script "$1" "$2" "$3" | bash hooks/surface-model-policy.sh 2>/dev/null)
       printf '%s' "$O" | grep -q additionalContext && echo "$3 ALERT" || echo "$3 SILENT"; }
H="export const meta={name:'x',description:'x'}"
run "$H
await agent('q',{agentType:'explore-strict',label:'a'})"    /tmp/probe/fable-5.jsonl p2
run "$H
await agent('q',{agentType:'general-purpose',label:'a'})"   /tmp/probe/fable-5.jsonl p3
```
Expected(현행): `p2 SILENT` · `p3 SILENT`. **목표 상태는 p2 SILENT(유지) · p3 ALERT**(spec §13.3 — p2는 frontmatter `model: sonnet`이라 역류 없음, p3는 `agents/` 파일 자체가 없어 세션 상속).

- [x] **Step 2: RED 픽스처 3건 등록**

`hooks/tests/cases.tsv` 끝에 추가(탭 구분):
```
surface-model-policy	32-rule-c3-builtin-inherit	0	mk_wf_event
surface-model-policy	33-rule-c3-explore-declared-ok	0	mk_wf_event
surface-model-policy	34-rule-c3-builtin-nonfable-ok	0	mk_wf_event
```
`hooks/tests/run-all.sh` 의 SMP 블록 끝(`test_smp "31-…"` 뒤)에 픽스처 변수 + 케이스 추가:
```bash
# C14 Rule C3 축 재정의: model 을 선언하는 frontmatter 가 없는 agentType 은 세션을 상속한다 (spec §13.3)
WF_BUILTIN="export const meta = {name: 'x', description: 'x'}
await agent('research this', {agentType: 'general-purpose', label: 'r'})"
WF_EXPLORE="export const meta = {name: 'x', description: 'x'}
await agent('scan this', {agentType: 'explore-strict', label: 'r'})"
# 32: builtin(general-purpose)은 frontmatter 가 없어 fable 세션에서 역류 → ALERT
test_smp "32-rule-c3-builtin-inherit" 0 1 "$(mk_wf_event script "$WF_BUILTIN" "$SMP_FABLE_T" "smp32-$$")"
# 33: explore-strict 는 frontmatter model: sonnet 보유 → 역류 없음 → 무발화(오탐 방지 대조군)
test_smp "33-rule-c3-explore-declared-ok" 0 0 "$(mk_wf_event script "$WF_EXPLORE" "$SMP_FABLE_T" "smp33-$$")"
# 34: 비-fable 세션은 C3 대상 아님 → 무발화
test_smp "34-rule-c3-builtin-nonfable-ok" 0 0 "$(mk_wf_event script "$WF_BUILTIN" "$SMP_SONNET_T" "smp34-$$")"
```

- [x] **Step 3: RED 실행 후 GREEN — Rule C3 분기를 축 재정의**

Run (포그라운드) 먼저: `bash hooks/tests/run-all.sh 2>&1 | tail -6`
Expected: `32-rule-c3-builtin-inherit` **FAIL**(현행 SILENT), 33·34는 우연히 PASS(현행도 무발화).

`hooks/surface-model-policy.sh:73-77` 의 `elif [ "$SP_TYPE" = "?" ]; then` 블록을 아래로 **치환**:
```bash
    else
      # Rule C3 (spec §13.3, C14 축 재정의): 세션 모델을 상속하는 스폰 = **model 을 선언하지 않는** 스폰.
      # 판정 축은 agentType 의 명시 여부가 아니라 model 선언의 존재다 —
      #   ① '?'(agentType 키 부재)는 §11.3 실측대로 상속
      #   ② 리터럴 agentType 중 frontmatter 에 model 을 선언하지 않는 것(builtin general-purpose/Explore/
      #      Plan 등 — agents/*.md 파일 자체가 없다)도 동일하게 상속한다.
      # 제외(3 사유): explore-strict=frontmatter model 선언 보유 / execute·review-strict=Rule C·C2 전담 /
      #   '*'=동적이라 상속 단언 불가(GPT [C]4). 제외목록 ①축은 seal #47 이 디스크와 ⊆ 대조한다.
      case "$SP_TYPE" in
        explore-strict|execute-strict|review-strict|'*') ;;
        *) [ "$WF_TIER" = "4" ] && [ "$SP_MODEL" = "-" ] && C3_HIT=1 ;;
      esac
    fi
```
※ 위 `else` 는 기존 `if [ "$SP_TYPE" = "execute-strict" ]; then … elif [ "$SP_TYPE" = "?" ]; then … fi` 의
`elif` 를 대체한다(execute-strict 분기는 그대로 유지). `?` 는 `case` 의 `*)` 에 자연 포함된다.

`:116` 메시지를 축에 맞게 정정:
```
[model-policy] Workflow 스크립트가 **model 을 선언하지 않는** 서브에이전트를 스폰합니다(agentType 부재 또는 frontmatter 에 model 이 없는 builtin) — 이 경로는 **세션 모델을 상속**하므로(spec §11.3·§13.3) fable 세션에선 리서치 fan-out 전체가 플래그십으로 역류합니다. 역할에 맞는 하위 모델을 opts.model 로 명시하십시오(탐색=sonnet). SSOT: docs/ai-context/model-policy.md (advisory · 1세션 1회 · 차단 아님)
```

- [x] **Step 4: GREEN 실행 — p3 ALERT · p2 SILENT 확인**

Run (포그라운드):
```bash
cd ~/.claude
bash hooks/tests/run-all.sh 2>&1 | tail -4     # 기대: 242 / 242
```
그리고 Step 1의 probe 재실행 — 기대: **`p2 SILENT` · `p3 ALERT`**.
추가로 p1·p5·p6 무회귀 확인(같은 probe 하네스로): 전부 ALERT 유지.

- [x] **Step 5: seal #47 — agents 제외목록 ⊆ 봉인**

`setup/verify-setup.sh` 의 seal #46 블록 뒤에 삽입:
```bash
# 47. Rule C3 제외목록 봉인 (C14-D, spec §13.3 ①축): agents/*.md 에서 model 을 **선언**하는(=inherit 이
#     아닌) wrapper 는 세션을 상속하지 않으므로 C3 대상이 아니다 — 그 이름이 hook 의 제외 목록에
#     포함되어야 한다(⊆ 방향; 등호 아님 — execute/review-strict 는 Rule C·C2 전담이라는 설계 결정이고
#     '*' 는 동적 판정이라 디스크 대응물이 없다). 새 wrapper 가 하위 모델을 선언하며 추가될 때
#     hook 갱신 누락을 발화한다. bash 파일옵스만.
MISS47=""
for af in "$HOME/.claude/agents/"*.md; do
  an=$(basename "$af" .md)
  am=$(grep -m1 -E '^model:' "$af" 2>/dev/null | sed -E 's/^model:[[:space:]]*//' | tr -d '\r')
  { [ -n "$am" ] && [ "$am" != "inherit" ]; } || continue
  grep -q "$an" "$HOME/.claude/hooks/surface-model-policy.sh" 2>/dev/null || MISS47="$MISS47 $an"
done
if [ -z "$MISS47" ]; then
  ok "Rule C3 제외목록 봉인: model 선언 wrapper 가 hook 제외 목록에 등재됨"
else
  fail "Rule C3 제외목록 drift (C14-D): hook 미등재 —$MISS47. model 을 선언하는 wrapper 는 세션 상속이 아니므로 C3 제외 목록에 추가해야 함(spec §13.3)"
fi
```

- [x] **Step 6: 카운트 동기 + 전량 검증**

`README.md:285` `현재 84 PASS` → `현재 85 PASS` · `:277`/`:515` 239 → 242.
`docs/ai-context/model-policy.md:35` 의 Rule C3 서술을 축에 맞게 정정:
```
Rule C3(**model 을 선언하지 않는** 스폰의 세션 모델 상속 역류 — agentType 부재 또는 frontmatter 에 model 이 없는 builtin, fable 세션 한정; explore-strict 는 frontmatter sonnet 보유라 제외, C13·C14)
```
`docs/ai-context/scaffold-registry.md` Seals 표에 `| #47 | Rule C3 제외목록 봉인 (agents model 선언 ⊆ hook) | C14 (2026-07-28) |` + 제목 카운트 29 → 30.
Run (포그라운드): `bash setup/verify-setup.sh 2>&1 | tail -3`(기대 `PASS=85 FAIL=0`) · `bash setup/tests/seal-regression.test.sh 2>&1 | tail -3`(기대 `PASS=10 FAIL=0`).

- [x] **Step 7: Commit**

```bash
cd ~/.claude
git add hooks/surface-model-policy.sh setup/verify-setup.sh hooks/tests/cases.tsv hooks/tests/run-all.sh \
        README.md docs/ai-context/model-policy.md docs/ai-context/scaffold-registry.md
git commit -m "feat(c14-d): Rule C3 축을 '모델-무선언 스폰'으로 재정의 — builtin 역류 탐지 + seal #47 제외목록 봉인"
```

> **설계 검산 (plan 작성 시 실측, 2026-07-28)**: Step 5 로직을 현 디스크에 돌린 결과
> `declaring wrapper: explore-strict (model=sonnet)` → 미등재 `[ explore-strict]` = **RED**.
> Step 3의 제외목록이 착륙하면 GREEN 이 된다 — 즉 이 seal 은 vacuous 하지 않다.

---

### Task 5: C14-E — spec §12.4-3 ccs 거짓 기록 정정

**Files:**
- Modify: `docs/superpowers/specs/2026-07-25-model-policy-design.md:539-540` (§12.4 항목 3)

**Interfaces:**
- Consumes: 없음. Produces: 없음(문서 전용).

- [x] **Step 1: RED — 심링크 사실과 spec 서술의 괴리 확인**

```bash
cd ~/.claude
ls -ld skills/ccs-delegation                      # 기대: lrwxrwxrwx … -> /c/Users/12132/.ccs/…
git ls-tree HEAD skills/ | grep ccs                # 기대: 120000 blob … (심링크 blob)
git log --all --oneline -- skills/ccs-delegation/SKILL.md   # 기대: 빈 출력(추적된 적 없음)
sed -n '539,540p' docs/superpowers/specs/2026-07-25-model-policy-design.md  # "config.json 지시" 서술
```
Expected: 모드 120000 · git 이력 0건 → 이 정정은 **리포에 존재할 수 없다**.

- [x] **Step 2: 리포 밖 실파일 상태를 읽기만 해서 재확인 (쓰기 금지)**

```bash
cd ~/.claude && T=$(readlink -f skills/ccs-delegation)
echo "target: $T"
grep -c 'config\.json' "$T/SKILL.md"; grep -c 'config\.yaml' "$T/SKILL.md"
```
Expected: `config.json` **0** · `config.yaml` **4** — 로컬 정정 자체는 유효(단 배포 경로 미착륙).
※ `~/.ccs/` 는 **읽기 전용**. 이 스텝에서 어떤 쓰기도 하지 않는다.

- [x] **Step 3: spec §12.4 항목 3 을 사실로 교체**

`docs/superpowers/specs/2026-07-25-model-policy-design.md` 의 §12.4-3 항목을 아래로 치환:
```
3. **`skills/ccs-delegation/SKILL.md`가 `~/.ccs/config.json` 지시** — 실재는 `config.yaml`.
   **★C14 정정(2026-07-28)**: C13 이 "정정 착륙"이라 기록한 것은 **거짓**이다 — `skills/ccs-delegation`
   은 심링크(`git ls-tree HEAD` 모드 **120000**, blob 내용 = 링크 포인터 한 줄)이고
   `git log --all -- skills/ccs-delegation/SKILL.md` 는 빈 출력(리포 역사상 추적된 적 없음)이다.
   C13 의 근거 grep 은 **심링크 대상(리포 밖 비-git 디렉터리)** 을 읽은 것이라 이 정정은 리포에
   존재할 수 없었다(plan 의 `git add …/SKILL.md` 도 `beyond a symbolic link` 로 구조적 실행 불가).
   현 상태(C14 읽기 전용 재확인): 링크 대상 실파일은 `config.json` 0건 / `config.yaml` 4건 —
   **로컬 정정은 유효하나 배포 경로(`install.sh:7` `git clone`)로는 따라오지 않는다.**
   → 판정: **리포 관점에서는 "갱신 대상 아님"**(비추적 로컬 정션 — `scaffold-registry.md:42` 가 이미
   `(로컬 정션, 비추적)` 으로 정직 기술). 하네스 문서는 알고 있었는데 spec/plan 이 그것을 무시하고
   리포 파일처럼 행번호까지 지정해 정정을 지시한 것이 설계 결함이었다.
   **클래스 교훈**: 리포 내 경로처럼 보이는 심링크가 검증을 오도한다 → grep 증거는 `git ls-files`
   교차 확인이 필수 동반자(§13.9 · non-obvious 등록 대상 — Task 8).
```

- [x] **Step 4: 검증 + Commit**

```bash
cd ~/.claude
grep -c '심링크' docs/superpowers/specs/2026-07-25-model-policy-design.md   # 기대: ≥2 (§12.4-3 + §13.9)
git add docs/superpowers/specs/2026-07-25-model-policy-design.md
git commit -m "fix(c14-e): spec §12.4-3 ccs '정정 착륙' 거짓 기록 취소 — 심링크 사실로 대체"
```

---

### Task 6: C14-F — seal #45 seal-regression 뮤테이터 (goal §4.3 미충족분)

**Files:**
- Modify: `setup/tests/seal-regression.test.sh` (뮤테이터 2종 + assert 2행)

**Interfaces:**
- Consumes: Task 1이 추가한 `mut_doctor_lib_drop` 패턴(동일 관용구 재사용).
- Produces: seal-regression 총계 10 → 12.

- [x] **Step 1: RED — #45 대상 뮤테이터가 0개임을 확인**

```bash
cd ~/.claude
grep -n '^assert_seal_fires' setup/tests/seal-regression.test.sh
grep -c 'mut_explore_effort\|mut_explore_websearch' setup/tests/seal-regression.test.sh  # 기대: 0
```
Expected: explore 대상은 `mut_explore_write`(seal #41) 뿐 — **seal #45 전체가 커버 밖**. 즉 "9/0 통과"가 #45의 발화를 증언하지 않는다.

- [x] **Step 2: GREEN — 뮤테이터 2종 추가**

`setup/tests/seal-regression.test.sh` 뮤테이터 정의부(Task 1의 `mut_doctor_lib_drop` 뒤)에 추가:
```bash
# C14-F: seal #45 conjunct ②(explore-strict frontmatter) 커버 — C13 이 세운 앵커가 실제로 발화하는가
mut_explore_effort()    { sed -i -E 's/^effort:[[:space:]]*xhigh/effort: medium/' "$1/agents/explore-strict.md"; }
mut_explore_websearch() { sed -i -E 's/^(tools:.*), WebSearch/\1/' "$1/agents/explore-strict.md"; }
```
assert 목록에 2행 추가:
```bash
assert_seal_fires "explore_effort"    mut_explore_effort     "역할×모델 매트릭스 봉인 붕괴"
assert_seal_fires "explore_websearch" mut_explore_websearch  "역할×모델 매트릭스 봉인 붕괴"
```

- [x] **Step 3: GREEN 실행**

Run (포그라운드):
```bash
cd ~/.claude && bash setup/tests/seal-regression.test.sh 2>&1 | tail -6
```
Expected: `✓ mutant[explore_effort]` · `✓ mutant[explore_websearch]` 포함 **`seal-regression: PASS=12 FAIL=0`**
산식: control 1 + **witness(live 무변경) 1** + 기존 뮤테이터 7 + Task 1의 `lib_manifest` 1 + 이번 2 = **12**
(베이스라인 9 = control 1 + witness 1 + 뮤테이터 7 — 실측 확인값).
**주의**: 이 러너는 자기 카운트를 README 등에 선언하지 않으므로 카운트 동기 작업은 불필요하다
(`seal-regression.test.sh:4-7` 주석이 "no numbers here" 를 명시).

- [x] **Step 4: Commit**

```bash
cd ~/.claude
git add setup/tests/seal-regression.test.sh
git commit -m "test(c14-f): seal #45 뮤테이터 2종 추가 — explore-strict effort/WebSearch 앵커 발화 증명"
```

---

### Task 7: C14-G — doctor #23 MSYS 경로 오보 정정

**Files:**
- Modify: `setup/doctor.sh:358-372` (#23 블록)
- Modify: `setup/tests/doctor.test.sh` (재현 테스트 추가)

**Interfaces:**
- Consumes: 없음. Produces: 없음(진단 전용).

- [x] **Step 1: RED — 오보를 실물로 재현 (값 출력 금지, 키 존재만)**

```bash
cd ~/.claude
S="$HOME/.claude/settings.json"
# 현행 doctor 형태: bash 보간 경로를 node 에 넘김
node -e "try{const s=JSON.parse(require('fs').readFileSync('$S','utf8'));console.log('PCT-present:'+(s.env&&('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE' in s.env)))}catch(e){console.log('THREW:'+e.code)}"
# 제안 형태: stdin 전달
cat "$S" | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const s=JSON.parse(d);console.log('PCT-present:'+(s.env&&('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE' in s.env)))}catch(e){console.log('THREW')}})"
```
Expected: 첫째 **`THREW:ENOENT`**(MSYS 경로를 Windows node 가 못 읽음 → `catch(e){}` 가 삼켜 빈 값 → "미설정" WARN 오보) · 둘째 **`PCT-present:true`**(실제로는 설정돼 있음).
※ **값은 절대 출력하지 않는다** — 키 존재 boolean 만.

- [x] **Step 2: GREEN — stdin 전달로 교체**

`setup/doctor.sh:361` 의 `compact_val=$(node -e "…readFileSync('$SETTINGS_JSON'…")` 행을 아래로 치환:
```bash
  # ★MSYS 경로를 Windows node 에 보간하면 ENOENT 로 조용히 실패해 "미설정" 오보가 된다(C14-G, spec §13.10).
  # 파일 내용을 stdin 으로 넘긴다 — 경로 해석을 bash 에 맡기고 node 는 파싱만 한다. 값은 출력하지 않는다.
  compact_val=$(cat "$SETTINGS_JSON" 2>/dev/null | node -e "
    let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{
      try{ const s=JSON.parse(d); const v=(s.env&&s.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE)||''; console.log(v) }catch(e){ console.log('') }
    })" 2>/dev/null || echo "")
```

- [x] **Step 3: 재현 테스트 추가 (GAP-012 픽스처 규약 2번째 실적용)**

`setup/tests/doctor.test.sh` 의 **마지막 줄 `echo "PASS: all doctor.sh tests"` 앞**에 추가.
※ 이 파일은 `ok`/`bad` 헬퍼가 없다 — 관용구는 `set -euo pipefail` + `{ echo "FAIL: …"; exit 1; }`
(Test 5 선례 동형). 변수는 상단에 이미 정의된 `$DOCTOR` 를 쓴다. 라이브 `settings.json` 은 **읽지도
않는다**(정적 소스 검사만 — 토큰 보유 파일에 접근할 이유가 없다):
```bash
# Test 6 (C14-G): #23 이 MSYS 경로 보간이 아니라 stdin 으로 settings.json 을 읽는가 (오보 회귀 봉인).
# RED 재현자: bash 로 보간한 /c/Users/... 경로를 Windows node 의 readFileSync 에 넘기면 ENOENT 이고
# catch(e){} 가 삼켜 빈 값 → "미설정 WARN" 오보. 실제로는 키가 설정돼 있어도 그렇게 보고했다(spec §13.10).
if grep -qF "readFileSync('\$SETTINGS_JSON'" "$DOCTOR"; then
  echo "FAIL: doctor #23 이 bash-보간 경로를 node 에 넘김 (MSYS 미독 → '미설정' 오보) — stdin 전달로 교체 필요"; exit 1
fi
```

- [x] **Step 4: GREEN 실행**

Run (포그라운드):
```bash
cd ~/.claude
bash setup/doctor.sh 2>&1 | grep -i 'AUTOCOMPACT'
```
Expected: `미설정 — 기본값 95%` **가 아니라** 실제 값 기반 판정(현재 이 머신은 키가 존재하므로 `PASS`/`WARN` 중 하나 — 값 자체는 doctor 가 출력하나 **plan/보고에는 옮기지 않는다**).
```bash
bash setup/tests/doctor.test.sh 2>&1 | tail -3    # 기대: 신규 단언 PASS, FAIL=0
```

- [x] **Step 5: Commit**

```bash
cd ~/.claude
git add setup/doctor.sh setup/tests/doctor.test.sh
git commit -m "fix(c14-g): doctor #23 MSYS 경로 오보 정정 — stdin 전달 + 회귀 테스트"
```
※ `settings.json` 은 **절대 `git add` 하지 않는다**(gitignored + 토큰 보유).

---

### Task 8: C14-H — non-obvious.md 신설 + GAP-012 픽스처 동반 규약 + 첫 실적용 2건

**Files:**
- Create: `docs/ai-context/non-obvious.md`
- Modify: `docs/ai-context/scaffold-registry.md` (문서 표에 등재)

**Interfaces:**
- Consumes: Task 5의 심링크 교훈(등록 항목 #2의 소재).
- Produces: `docs/ai-context/non-obvious.md` — Task 9의 `CLAUDE.md §4` 정정이 이 파일의 규약을 가리킨다.

- [x] **Step 1: RED — 파일 부재 확인**

```bash
cd ~/.claude
ls docs/ai-context/non-obvious.md 2>&1        # 기대: No such file or directory
grep -n 'non-obvious' CLAUDE.md                # 기대: §4 가 이 경로를 지시(전제는 있는데 파일이 없다)
```
Expected: 파일 부재 + `CLAUDE.md:34` 가 그 경로를 지시 — **전제와 실물의 간극**.

- [x] **Step 2: GREEN — 파일 신설 (규약 헤더 + 등록 2건)**

`docs/ai-context/non-obvious.md` 를 아래 내용으로 생성:
```markdown
# non-obvious.md — 하네스 자신의 AI 실패 등록부

> 이 파일은 **글로벌 하네스(`~/.claude`) 작업 중 발생한 AI 실패**를 누적한다.
> 대상 프로젝트의 `docs/ai-context/non-obvious.md`(init-ai-ready-project 템플릿 산출물)와 **경로만
> 같고 문맥이 다르다** — 이쪽은 하네스 사이클의 Closeout 이 기록한다(spec §13.5).
> 등록 절차는 `CLAUDE.md §4`(5 Whys · 시스템 원인만 · SMART action item).

## ★규약: 재현 픽스처 동반 (GAP-012)

등록 항목은 **재현 픽스처 경로를 필수 필드로** 갖는다. 픽스처 없는 등록은 불완전하다.

- **왜**: 등록만 있고 재현자가 없으면 다음 사이클이 같은 가정을 반복한다. C13 이 그 실증 —
  "goal 은 없을 것"이라는 추론을 확인 없이 사실로 승격해 요구 3개를 놓쳤고, 그 실패를 잡아낼
  자동 재현자가 없었다(spec §13.1).
- **픽스처는 "테스트 통과"가 아니라 "요구 충족"을 겨눈다**: 내가 만든 픽스처는 내가 해석한 범위만
  검사하므로, 픽스처가 GREEN 인 것과 요구가 충족된 것은 다른 명제다(C13 은 run-all 235/235 인 채로
  요구 3개가 미착륙이었다).
- 형식: 각 항목에 `**재현 픽스처:**` 줄을 두고 **실행 가능한 경로 또는 명령**을 적는다.
  자동화가 불가한 절차적 실패는 `절차: <체크 지점>` 으로 적되, **그 체크가 어느 파일의 어느 단계에
  배치됐는지**를 반드시 명시한다(선언만 남기지 않는다).

---

## 1. gitignored 파일의 **부재를 확인 없이 가정**하면 요구를 통째로 놓친다

- **관측 (2026-07-27, C13 Closeout)**: 프롬프트의 "goal 은 gitignored 라 없을 수 있다"를 확인 없이
  사실로 승격하고 요구사항을 durable spec 으로만 읽었다. `_goal/c13-dispatch-governance-goal.md`
  (18,744 bytes)는 **디스크에 실재했다**. 결과: goal §4 성공기준 6개 중 3개가 미검증 상태로
  "COMPLETE" 보고 → 적대 검증 4 렌즈 중 3이 그 보고를 뒤집었다.
- **5 Whys (시스템 원인까지)**:
  1. 왜 요구 3개를 놓쳤나? → 요구사항 SSOT(goal §4)를 읽지 않았다.
  2. 왜 읽지 않았나? → 파일이 없다고 판단했다.
  3. 왜 없다고 판단했나? → "gitignored" 라는 프롬프트 문구를 "부재" 로 해석했다.
  4. 왜 그 해석을 검증하지 않았나? → 검증 비용이 `ls` 한 번인데도 **확인 단계가 절차에 없었다**.
  5. 왜 절차에 없었나? → **비추적 요구사항 문서를 읽는 규약 자체가 없었다** — durable spec 이
     요구를 전부 옮겼다고 암묵 가정했으나, spec §11.2 는 probe 를 요약만 하고 *어느 probe 가
     성공기준인지*는 goal 에만 있었다. ← **시스템 원인**(사람/AI 아님).
- **SMART action item**: Closeout 에서 **goal 파일의 성공기준 절을 직접 열어 항목별로 대조**하고
  그 증거를 보고에 포함한다. 파일 부재를 주장하려면 `ls` 출력을 근거로 제시한다.
- **재현 픽스처**: `절차: start-rpi-cycle Closeout Step C-1` — Closeout 보고에 goal §4 항목별 대조
  증거가 없으면 불완전. 자동 재현자는 불가(요구사항 문서 경로가 사이클마다 다름)이므로
  **절차 체크로 고정**하고, 그 체크가 실제로 수행됐는지는 보고의 대조 표가 증언한다.
  ※ 이 잔여(자동화 불가)를 명시하는 것 자체가 규약의 일부다 — 침묵 잔여 금지.

## 2. 리포 내 경로처럼 보이는 **심링크**가 grep 증거를 오도한다

- **관측 (2026-07-27, C13)**: `grep -c 'config.json' skills/ccs-delegation/SKILL.md` = 0 을 근거로
  "정정 착륙" 을 보고했다. 그러나 `skills/ccs-delegation` 은 심링크(`git ls-tree HEAD` 모드
  **120000**)라 그 grep 은 **워킹 디렉터리 파일시스템**(리포 밖 비-git 디렉터리)을 읽은 것이었다.
  `git log --all -- skills/ccs-delegation/SKILL.md` 는 빈 출력 — 리포 역사상 추적된 적이 없다.
  결과: 배포 경로(`install.sh:7` `git clone`)에는 정정이 따라오지 않는데 "착륙" 으로 기록됐다.
- **5 Whys**:
  1. 왜 거짓 보고가 났나? → grep 결과를 리포 내용으로 해석했다.
  2. 왜 그렇게 해석했나? → 경로가 리포 안(`skills/…`)처럼 보였다.
  3. 왜 심링크임을 몰랐나? → `ls -ld`/`git ls-files` 교차 확인을 하지 않았다.
  4. 왜 안 했나? → grep 이 파일시스템을 읽는다는 사실과 "리포 내용" 이 다르다는 구분이
     **검증 절차에 없었다**.
  5. 왜 없었나? → **"워킹트리 grep = 리포 내용" 이라는 암묵 등식**이 규약에 명시적으로 부정된 적이
     없었다. ← **시스템 원인**.
- **SMART action item**: 리포 착륙을 주장하는 grep 증거는 **`git ls-files` 또는 `git ls-tree` 교차
  확인을 동반**한다. 특히 `skills/` 하위처럼 심링크가 섞인 디렉터리는 필수.
- **재현 픽스처**: `bash -c 'cd ~/.claude && git ls-tree HEAD skills/ | grep ccs'` →
  `120000 blob …` (모드 120000 = 심링크)가 나오면 그 경로의 파일 grep 은 리포 증거가 아니다.
  대조군: `git ls-files skills/ccs-delegation/` → **빈 출력**(추적 파일 0개).
```

- [x] **Step 3: scaffold-registry 등재**

`docs/ai-context/scaffold-registry.md` 의 문서 표(ai-context 항목들이 열거된 곳)에 행 추가:
```
| `non-obvious.md` | 하네스 자신의 AI 실패 등록부 + 재현 픽스처 동반 규약(GAP-012) | C14 (2026-07-28) |
```

- [x] **Step 4: 검증 — 규약 grep + 픽스처 실행**

```bash
cd ~/.claude
ls -l docs/ai-context/non-obvious.md                     # 기대: 실재
grep -c '재현 픽스처' docs/ai-context/non-obvious.md      # 기대: ≥3 (규약 1 + 항목 2)
grep -c '^## [0-9]' docs/ai-context/non-obvious.md        # 기대: 2 (등록 2건)
# 항목 2의 픽스처가 실제로 도는가
git ls-tree HEAD skills/ | grep ccs                       # 기대: 120000 blob …
git ls-files skills/ccs-delegation/                       # 기대: 빈 출력
```

- [x] **Step 5: Commit**

```bash
cd ~/.claude
git add docs/ai-context/non-obvious.md docs/ai-context/scaffold-registry.md
git commit -m "feat(c14-h): non-obvious.md 신설 — GAP-012 재현 픽스처 동반 규약 + 등록 2건(goal 미확인·심링크 오도)"
```

---

### Task 9: C14-J — skill context_paths 조건부 선언 + CLAUDE.md §5 정정 (**마지막 task**)

> **★배치 이유**: 루트 `CLAUDE.md` 수정은 **세션 종료 직전에만**(글로벌 §1 캐시 안정성 — 중간 수정 시
> prefix 캐시 미스로 다음 세션 비용 ~20배). 따라서 이 task 는 반드시 마지막에 실행한다.

**Files:**
- Modify: `skills/start-rpi-cycle/SKILL.md:30`·`:41-44`·`:178-180`
- Modify: `skills/closeout-pr-cycle/SKILL.md:37`·`:101-104`
- Modify: `skills/improve-codebase-architecture/SKILL.md:25-26`·`:38-40`·`:118`
- Modify: `docs/ai-context/scaffold-registry.md` (**Step 3c — seal #48 등재 + 제목 카운트 30→31**)
- Modify: `setup/verify-setup.sh` (**Step 3b — seal #48 신설**; 삽입 위치 = seal #47 블록 뒤 · **seal #36 블록 앞**. #36은 `EXPECTED_TOTAL=PASS+FAIL+1` 로 자기 카운트를 세므로 반드시 마지막 체크여야 한다)
- Modify: `setup/tests/seal-regression.test.sh` (**Step 3b — `mut_skill_conditional` + assert**; witness 목록은 Task 1에서 이미 `skills/start-rpi-cycle/SKILL.md` 포함하도록 갱신됨)
- Modify: `README.md:285` (**Step 3b — `현재 85 PASS` → `현재 86 PASS`**)
- Modify: `CLAUDE.md` §5 (architecture.md 전제)

**Interfaces:**
- Consumes: Task 8의 `docs/ai-context/non-obvious.md`(이제 실재하므로 조건부 대상에서 **빠진다**).
- Produces: 없음(최종 task).

- [x] **Step 1: RED — 부재 경로를 무조건 지시하는 상태 확인**

```bash
cd ~/.claude
for f in architecture domain-glossary deny-patterns runbook non-obvious; do
  printf '%-20s ' "$f"; [ -e "docs/ai-context/$f.md" ] && echo EXISTS || echo MISSING
done
grep -rn 'docs/ai-context/\(architecture\|domain-glossary\|deny-patterns\|runbook\)' skills/*/SKILL.md | grep -v init-ai-ready
```
Expected: `non-obvious` = **EXISTS**(Task 8이 만듦) · 나머지 4개 = MISSING · 3개 skill 이 그 4개를 무조건 지시.

- [x] **Step 2: GREEN — 조건부 선언으로 정정 (경로 목록은 보존)**

`skills/start-rpi-cycle/SKILL.md:41-44` 의 context_paths 블록 **뒤**에 ※ 주를 추가(경로는 유지):
```
   ※ **경로는 실재하는 것만 전달한다** — `docs/ai-context/{architecture,domain-glossary,deny-patterns}.md`는
     대상 프로젝트의 스캐폴드 산출물(init-ai-ready-project)이라 **글로벌 하네스에는 부재가 정상**이다
     (spec §13.4 · CONTEXT.md "스캐폴드 산출물 경계"). 하네스 사이클에서는 CONTEXT.md +
     `docs/ai-context/{model-policy,non-obvious,cross-family-review}.md` 가 실재 SSOT다.
```
`:178-180` Closeout 블록에도 동일 취지 1줄:
```
   ※ 위 경로 중 **실재하는 것만** 전달(하네스에서는 architecture·domain-glossary 부재가 정상 — spec §13.4).
```
`:30` 의 ADR SSOT 서술을 정직하게:
```
   ※ ADR은 `docs/ai-context/architecture.md`(append-only, §5 SSOT)에 기록 — grill 기본 docs/adr/ 대신 하네스 SSOT 사용.
     **단 이 파일은 대상 프로젝트에서만 실재한다**(하네스 자신의 아키텍처 결정은 durable spec 의 in-place 개정으로 기록 — spec §13.4).
```
`skills/closeout-pr-cycle/SKILL.md:101-104` 와 `skills/improve-codebase-architecture/SKILL.md:38-40` 의
context_paths 블록 뒤에도 각각 1줄:
```
   ※ 실재하는 경로만 전달 — 위 `docs/ai-context/*` 는 대상 프로젝트 스캐폴드 산출물이라 글로벌 하네스에는 부재가 정상(spec §13.4).
```
`improve-codebase-architecture/SKILL.md:25-26` 의 **전제조건** 서술은 "존재" 단언이므로 조건부로:
```
- docs/ai-context/architecture.md 존재 (대상 프로젝트 기준 — 하네스 자체 실행 시엔 durable spec 이 대체)
- docs/ai-context/domain-glossary.md 존재 (동상 — 하네스는 CONTEXT.md 가 용어 SSOT)
```

- [x] **Step 3: CLAUDE.md §5 정정 (§4 는 불요 — non-obvious 가 실재하게 됨)**

`CLAUDE.md` §5 의 `docs/ai-context/architecture.md`는 append-only` 행을 아래로:
```
- `docs/ai-context/architecture.md`는 append-only (대상 프로젝트 기준 — **글로벌 하네스 자신**의 아키텍처 결정은 durable spec in-place 개정으로 기록, spec §13.4)
```
※ **§4 는 편집하지 않는다** — Task 8이 `docs/ai-context/non-obvious.md` 를 실재하게 만들었으므로
§4 가 지시하는 경로가 이제 참이다(spec §13.5). §4 에는 픽스처 규약 1줄만 덧붙인다:
```
5. 통과 시에만 `docs/ai-context/non-obvious.md` 추가 — **재현 픽스처 경로를 필수 필드로** 동반(GAP-012, 그 파일 헤더 규약)
```

- [x] **Step 3b: seal #48 — skill context_paths 축 봉인 (spec §13.8 3번째 불릿 · goal §4.9 후단)**

★Gate P 지적 수용: 초안은 이 seal 을 "문면 결속이 취약하다"는 사유로 미신설하려 했으나, 그것은
**spec §13.8이 이미 검토하고 좁힌 처방을 재논증**하는 것이었다. §13.8의 처방("경로 실재가 아니라
**조건부 지시 문구의 존재**를 봉인")을 그대로 구현한다 — 부재 경로를 FAIL 시키지 않으므로
대상-프로젝트 겸용 skill 이 깨지지 않는다.

`setup/verify-setup.sh` 의 seal #47 블록 뒤에 삽입:
```bash
# 48. skill context_paths 조건부 선언 봉인 (C14-J, spec §13.8): 부재가 정상인 스캐폴드 산출물 경로를
#     지시하는 skill 은 "실재하는 것만 전달" 선언을 동반해야 한다. 경로 실재를 요구하지 않는다 —
#     그러면 대상-프로젝트 겸용 skill 이 깨진다(§13.4). 지시와 선언의 **동반**만 검사한다.
#     RED 재현자: 선언 문구를 지우면 발화(seal-regression mut_skill_conditional).
MISS48=""
for sk in start-rpi-cycle closeout-pr-cycle improve-codebase-architecture; do
  sf="$HOME/.claude/skills/$sk/SKILL.md"
  [ -f "$sf" ] || continue
  grep -qE 'docs/ai-context/(architecture|domain-glossary|deny-patterns|runbook)' "$sf" || continue
  grep -q '실재하는' "$sf" || MISS48="$MISS48 $sk"
done
if [ -z "$MISS48" ]; then
  ok "skill context_paths 조건부 선언 봉인 (스캐폴드 산출물 경로 지시 ↔ '실재하는 것만' 선언 동반)"
else
  fail "skill context_paths 무조건 지시 (C14-J): 선언 누락 —$MISS48. 하네스엔 부재가 정상인 경로이므로 '실재하는 것만 전달' 선언 필요(spec §13.4·§13.8)"
fi
```
카운트 +1 → **PASS 85 → 86**. `README.md:285` 를 `현재 86 PASS` 로 동기.

`setup/tests/seal-regression.test.sh` 에 뮤테이터 + assert 추가(총 12 → 13):
```bash
mut_skill_conditional() { sed -i 's/실재하는/존재하는/g' "$1/skills/start-rpi-cycle/SKILL.md"; }
```
```bash
assert_seal_fires "skill_conditional" mut_skill_conditional "skill context_paths 무조건 지시"
```

- [x] **Step 3c: scaffold-registry 등재 (seal #48)**

`docs/ai-context/scaffold-registry.md` Seals 표에 `| #48 | skill context_paths 조건부 선언 봉인 (스캐폴드 산출물 경로) | C14 (2026-07-28) |` 행 추가(`| #47 |` 행 뒤) + 제목 카운트 `#17~#47 … 30` → `#17~#48 … 31`.

Run: `grep -c '^| #' docs/ai-context/scaffold-registry.md` — 기대: 31 (제목 카운트와 자기검산 일치)

※ seal #37 은 hook/skill basename 만 검사하고 Seals 표는 미검사이므로 이 등재는 자동 FAIL 로 강제되지 않는다(Gate P 관측) — 그래서 각 seal 신설 task 에 등재 스텝을 **명시 배치**해 침묵 드리프트를 막는다. 최종 카운트 28 → 29(T1) → 30(T4) → 31(T9).

- [x] **Step 4: GREEN 검증 — 전량 3종 + skill 게이트**

Run (포그라운드, 순서대로):
```bash
cd ~/.claude
bash setup/verify-setup.sh 2>&1 | tail -3               # 기대: PASS=86 FAIL=0
bash hooks/tests/run-all.sh 2>&1 | tail -3               # 기대: 242 / 242
bash setup/tests/seal-regression.test.sh 2>&1 | tail -3  # 기대: PASS=13 FAIL=0
wc -l CLAUDE.md                                          # 기대: ≤200 (글로벌 제약)
```
※ `CLAUDE.md` 편집은 `stable-claude-md` hook 이 알림을 내지만 **차단이 아니다**(글로벌 `~/.claude/CLAUDE.md` 는 그 hook 의 대상에서 제외 — README:36).

- [x] **Step 5: Commit**

```bash
cd ~/.claude
git add skills/start-rpi-cycle/SKILL.md skills/closeout-pr-cycle/SKILL.md \
        skills/improve-codebase-architecture/SKILL.md CLAUDE.md \
        setup/verify-setup.sh setup/tests/seal-regression.test.sh README.md \
        docs/ai-context/scaffold-registry.md
git commit -m "fix(c14-j): skill context_paths 조건부 선언 + seal #48 봉인 — 스캐폴드 산출물 경계 명문화 + CLAUDE.md §4 픽스처 규약/§5 전제 정정"
```

---

## Self-Review (writing-plans 규약 — plan 작성자가 직접 수행, 2026-07-28)

**1. Spec 커버리지** — spec §13의 각 절이 task 로 매핑되는가:

| spec 절 | task | 비고 |
|---|---|---|
| §13.1 방법론 실패 | Task 8 (등록 1) | 첫 실적용 |
| §13.2 probe 정의 | Task 4 Step 1/4 | RED/GREEN 재현자로 사용 |
| §13.3 C14-D 판정 | Task 4 | 제외목록 3사유 + seal #47 |
| §13.4 C14-J 판정 | Task 9 | 4파일 조건부(non-obvious 제외) |
| §13.5 C14-H 판정 | Task 8 | `docs/ai-context/non-obvious.md` |
| §13.6 M1~M7 | Task 1(M1·M2·M7) · Task 2(M3·M4·M5) · Task 3(M6) | 전건 |
| §13.7 C14-C 판정 | Task 3 | 삼항 구현 + 오식별 공개 |
| §13.8 seal 설계 | Task 1(#46 lib 매니페스트) · Task 4(#47 agents 제외목록) · Task 9 Step 3b(#48 skill context_paths) | 3축 전부 착륙. **초안은 #48을 "문면 결속 취약" 사유로 미신설하려 했으나 Gate P 가 그것이 §13.8의 처방을 재논증하는 것임을 지적 → 수용하고 신설**(§13.8이 이미 "경로 실재가 아니라 조건부 문구 존재를 봉인" 으로 좁혀둔 형태 그대로). |
| §13.9 ccs | Task 5 | |
| §13.10 doctor #23 | Task 7 | |
| §13.11 seal-regression | Task 6 | |
| §13.12 C14-I 미채택 | — | 설계 판정이라 task 없음(Best-Direction Check 에 선언) |

**갭 1 — 해소됨(Gate P 지적 수용)**: 초안은 §13.8의 "skill context_paths 축 seal" 미신설을
"문면 결속 취약" 사유로 선언했으나, Gate P 가 **그것이 spec §13.8의 처방을 재논증하는 것**임을
지적했다(§13.8은 이미 "경로 실재가 아니라 조건부 문구 존재를 봉인" 으로 그 반론을 흡수해 좁혀둔
형태였다). → **Task 9 Step 3b 로 seal #48 신설**. goal §4.9 후단("신규 seal 이 가짜 경로에 FAIL
발화")도 이로써 매핑된다(뮤테이터 `mut_skill_conditional` 이 RED 재현자).

**갭 2 (의식적 — 유지)**: Task 2의 "옛 표현 부정-단언 seal" 미신설 — Task 2 Step 7 주에 사유 기록.
이것은 재논증이 아니다: spec §13은 이 seal 을 처방한 적이 없고(§13.6 M3/M4는 *정정*만 요구),
부정-단언이 `_Avoid_` 정의문·genesis plans·§13 M-표의 정당 인용 6곳을 FAIL 시킨다는 것이 실측이다.

**갭 3 (신규 · 의식적)**: goal §3 C14-B 가 언급한 "spec §12.1 '동반 갱신 필요 목록' 에 M3/M4 추가"는
Task 2 Step 6 이 **§12.1 stale 인용 정정만** 다루고 목록 자체엔 항목을 추가하지 않는다.
사유: 그 목록(`:463-469`)은 **C13 Gate R 시점의 전수 결과**를 기록한 genesis 성격이고, C14가 발견한
누락은 §13.6 M-표가 이미 전수 기록한다(같은 사실을 두 곳에 두면 다음 사이클에 드리프트 소지).
→ 대신 Task 2 Step 6 에서 §12.1 목록 말미에 **§13.6 포인터 1줄**을 추가한다(아래 보강).

**2. Placeholder 스캔** — "TBD"/"적절히"/"유사하게" 0건. 모든 코드 스텝에 실제 코드 블록 존재.
seal #46·#47 로직과 doctor RED 앵커는 **plan 작성 시 라이브 디스크에 실행해 non-vacuous 검산 완료**.

**3. 타입/이름 정합** — `findOptsCandidates`(Task 3 정의) ↔ Task 3 Step 4 호출부 일치 ·
`mut_doctor_lib_drop`(Task 1 정의) ↔ Task 6이 "동일 관용구 재사용" 으로만 참조(재정의 없음) ·
seal 번호 #46(Task 1) → #47(Task 4) 충돌 없음 · PASS 카운트 82→84(T1: item-8 +1, seal #46 +1)→85(T4: seal #47)→86(T9: seal #48) 일관 ·
케이스 카운트 235→239(T3: 파서3+E2E1)→242(T4: C3 3) 일관.

**4. 실행 순서 제약**: Task 3 → Task 4(파서 출력 소비) · Task 8 → Task 9(non-obvious 실재 전제) ·
Task 9 **최후**(CLAUDE.md 캐시 안정성). 나머지(1·2·5·6·7)는 상호 독립이나 **Task 1을 먼저** 두는 것이
권장(카운트 baseline 을 82→84로 먼저 고정해야 이후 task 의 기대값이 단순해진다).
