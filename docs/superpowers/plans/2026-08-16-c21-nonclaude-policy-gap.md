# C21 비-Claude 세션 Agent 리터럴 축 복원 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active
**RPI-Cycle:** 72
**Started:** 2026-08-16

**Goal:** 비-Claude 세션(GPT/Orca)에서 `session_model_of()` 의 `claude-` 접두 편향 때문에 Agent 경로가 `:169` 에서 전량 조기 종료하던 상태를 끝내고, **세션 티어를 참조하지 않는 리터럴 축**(Rule A fable-누출 · Rule B floor · Rule B fable-누출)만 복원한다.

**Architecture:** 3축. ⑴ **판별식 1축 정정** — `session_model_of()` 를 패밀리-중립 문자클래스 + 「첫 비-`input` 매치」 구조 앵커로 교체(spec §20.2 후보 E). 하류(`tier_of`·`:171` 이후 분기)는 무변경이며 비-Claude 세션의 상속 축은 기존 `SESSION_TIER != 0`·`= "4"` 가드가 자동 skip 한다. ⑵ **픽스처 봉인** — 실 GPT shape 4 + 앵커 적대 2 = 6 케이스. ⑶ **기록 정합** — 신규 seal(non-obvious #3 SMART ①) · I1 등록 · GAP 원 기록 정정 부기 · C20 이월 3건 처분.

**Tech Stack:** bash(POSIX/MSYS) · awk · node(hooks/lib · 픽스처 stdin) · perl(바이트 편집) · git

**Best-Direction Check:** 최선안 = spec §20.2 가 6입력 × 후보 4종 대비로 채택한 **후보 E(패밀리-중립 + 구조 앵커)** + 리터럴 축 한정 복원 / 채택안 = **동일**. → **DOWNGRADE-DECLARED: 없음.**
- 근거: 더 정확한 후보 D(node JSON 파싱)는 6입력 전건 정확하나 훅 핫패스 **2.1배 지연**(276ms vs E 120ms · 현행 134ms, §20.2)이라 비용-편익 불성립 — 폐기가 아니라 §20.6-8 재판정 조건부 보존이므로 방향 열화가 아니다. 더 단순한 후보 A(중립화만)는 적대 GPT 입력에서 툴콜 `input.model` 을 `haiku` 로 오판별해 **N4 를 조건부 위반**하므로 단순함이 아니라 규범 위반으로 기각.
- 스코프 축소 아님: `:169` 제거와 Workflow 복원을 넣지 **않은** 것은 §20.2/§20.3 의 실측 기반 기각·의식적 수용이지 난이도 회피가 아니다.

## Global Constraints
spec `docs/superpowers/specs/2026-07-25-model-policy-design.md` **§20**(`:2397-2597`)이 SSOT. plan 은 **재설계하지 않는다** — 설계를 바꿔야 할 근거가 나오면 구현을 멈추고 메인에 보고한다.
- **N1** — 이 결함은 **C17 슬롯1 A1 정정의 미완결분**(§20.1). "신규 결함"·"C17 이 놓쳤다" 프레이밍 금지. A1 이 제거한 가드는 `:171` **이후**의 티어 처분이고 판별 실패는 그보다 앞선 `:169` 라 구조적으로 도달 불가였다. 전제를 바꾼 것은 C20 §19.1(브리지 자산화)이다.
- **N2** — 수단은 **판별식 패밀리-중립화 + 구조 앵커(후보 E)** 뿐(§20.2). `:169` 조기 종료 제거는 **기각**(판별 실패 ≠ 미지 티어 · Claude 세션 50중 12가 assistant 라인 0건).
- **N3** — 범위는 **Agent 리터럴 축만**. `hooks/surface-model-policy.sh:42-158`(Workflow 경로) **diff 0**(§20.3 · §16.4-5).
- **N4** — 상속 축(`inherit`)은 **계속 skip**(§20.3). 미지 세션에 임의 티어 부여 금지.
- **★I1 — 혼합-개행 파일에 Edit 도구 금지.** spec 파일은 CRLF **1823** + LF 혼합(총 2597줄) → Edit 상당 동작이 전량 CRLF 정규화를 일으켜 **723줄 무관 diff**. `perl -0777 -i -pe` 바이트 편집만. 계수는 `grep -c $'\r'` 가 이 파일에서 **0** 을 반환하므로 금지 — `perl -ne '$n++ if /\r/; END{print "$n\n"}' <파일>` 을 쓴다. 본 plan 이 건드리는 파일 실측(2026-08-16): `hooks/*`·`setup/*`·`docs/ai-context/*.md`·`.gitignore` = **CRLF 0(순수 LF)** → Edit 허용 / `README.md` = **CRLF 576/576(순수 CRLF)** → 결정성을 위해 perl 바이트 편집.
- **실 shape 필수** — 픽스처 stdin 은 `hooks/tests/run-all.sh:1042 mk_agent_event` 계열. 합성 shape 금지(`run-all.sh:1041` verbatim "실측 캡처 shape verbatim … 합성 shape 금지 (cycle-40 교훈)").
- **마커 위생** — `session_marker()`(`hooks/_common.sh:197`)가 `/tmp/<slug>-<session_id>` 로 1세션 1회를 억제. 수동 프로브는 **케이스마다 고유 `session_id`** + 전후 `/tmp/model-policy-*` 정리. 놓치면 **CONTROL 조차 침묵**해 RED 를 오판한다(§20.0 상한 2).
- **seal 번호** — plan 은 배정하지 않는다. `#<NEXT>` 를 쓰고 Task 3 Step 1 에서 `origin/master` 실측 발급(§6). 현행 최대 = **51**(실측).
- **경로 전달** — bash 가 만든 경로를 네이티브 인터프리터에 **소스 보간 금지**, argv/stdin 전달(non-obvious #3 · MSYS 가 `/tmp/x` 를 `C:\tmp\x` 로 오해석).
- **기준선(2026-08-16 실측)**: `cases.tsv` 비주석 **291**(smp 최대 번호 **72**) · run-all **291/291** · verify-setup **89/0** · seal-regression **26/0**.

**공용 프로브 헬퍼**(Task 1 이 정의 · Task 2 재사용):
```bash
cd ~/.claude
ev() { SUB="$1" MODEL="$2" TP="$3" SID="$4" node -e '
  const ti={description:"x",prompt:"x",subagent_type:process.env.SUB,run_in_background:false};
  if(process.env.MODEL) ti.model=process.env.MODEL;
  console.log(JSON.stringify({session_id:process.env.SID,transcript_path:process.env.TP,cwd:"",
    permission_mode:"bypassPermissions",effort:{level:"xhigh"},hook_event_name:"PreToolUse",
    tool_name:"Agent",tool_input:ti,tool_use_id:"toolu_x"}));'; }
run() { o=$(printf '%s' "$1" | bash hooks/surface-model-policy.sh 2>/dev/null); rc=$?
        c=0; printf '%s' "$o" | grep -q additionalContext && c=1; echo "exit=$rc ctx=$c"; }
GPT=projects/C--Users-12132-orca-workspaces-orca-lab-lab-gpt3/13eb0a8a-7ec9-4874-8639-e133ac9ef5cc.jsonl
CLA=projects/C--Users-12132--claude/12b8cf20-c73f-45db-a4d2-585cd3126593.jsonl
```

## Task 간 파일 겹침 (worktree 격리 불성립 → **순차 실행 T1→T6**)
| 파일 | 겹치는 task | 성격 |
|---|---|---|
| `setup/verify-setup.sh` | **T3**(신규 seal) · **T5**(I3 `:621` stderr 포획) | 같은 파일 다른 절 — T3 선행 고정 |
| `README.md` | **T2**(cases 291→297) · **T3**(89→90 PASS) | 다른 줄, 같은 파일 |
| `hooks/surface-model-policy.sh` | **T1** 편집 · **T2** Step 3 이 `git stash` 로 일시 되돌림(복구 필수) | 시간적 겹침 |
---
### Task 1: 판별식 정정 — 패밀리-중립화 + 구조 앵커 (S1·S3·S4)
**Files:** Modify `hooks/surface-model-policy.sh:9`(면역 계약 주석)·`:30-35`(`session_model_of`) / **무편집(N3 불변 구역)** `hooks/surface-model-policy.sh:42-158` / Test `hooks/tests/run-all.sh`(러너 — 이 task 는 편집 안 함)
**Interfaces:** Consumes = spec §20.2 채택 코드(`:2450-2457`) · 실 transcript 2종 / Produces = 정정된 `session_model_of()` — **T2 의 픽스처 6건이 이 계약을 봉인**한다
- [ ] **Step 1: RED 재현 (PROBE + CONTROL 쌍)** — 위 공용 헬퍼 정의 후:
```bash
cd ~/.claude; rm -f /tmp/model-policy-*-c21red*
echo -n "PROBE   (GPT + review-strict haiku): "; run "$(ev review-strict haiku "$GPT" c21red1)"
echo -n "CONTROL (CLA + review-strict haiku): "; run "$(ev review-strict haiku "$CLA" c21red2)"
rm -f /tmp/model-policy-*-c21red*
```
Expected(현행): `PROBE → exit=0 ctx=0` · `CONTROL → exit=0 ctx=1` [메인 실측 ✓ · §20.0 ⓓ]. **★CONTROL 이 `ctx=0` 이면 RED 무효** — 마커 흡수/transcript 부재이지 결함 재현이 아니다. `session_id` 를 바꿔 재실행하고 그래도 침묵하면 중단·보고.
- [ ] **Step 2: RED 출력 기록** — Step 1 의 두 줄을 커밋 본문 또는 사이클 보고에 verbatim 인용(사후 재현 앵커).
- [ ] **Step 3: 정정 적용 — `:30-35` 교체 + `:9` 주석 갱신**
`hooks/surface-model-policy.sh` 는 순수 LF → Edit 허용. `:30-35` 전체를 아래로 교체(**spec §20.2 `:2450-2457` 과 로직 byte-동일**):
```bash
session_model_of() {  # $1=transcript path — 마지막 assistant 라인의 message.model (라인-내 첫 비-input 매치)
  tail -c 1000000 "$1" 2>/dev/null | awk '
    /"type":"assistant"/ {
      s=$0; off=0; pick=""
      while (match(s, /"model":[[:space:]]*"[A-Za-z0-9._-]+"/)) {
        abs = off + RSTART
        pre = substr($0, (abs>60 ? abs-60 : 1), (abs>60 ? 60 : abs-1))
        if (pre !~ /"input":[[:space:]]*\{/) { pick = substr($0, abs, RLENGTH); break }
        off = abs + RLENGTH - 1
        s = substr($0, off+1)
      }
      if (pick != "") { m=pick; sub(/^"model":[[:space:]]*"/,"",m); sub(/"$/,"",m) } }
    END { if (m != "") print m }'
}
```
`:9` 주석 교체(구 문면의 괄호 「assistant JSON 은 model 이 content 앞」이 **전제**이고 중립화는 그 전제 밖으로 나간다, §20.2 실측 ②):
```bash
# 라인 내 **첫 비-`input` 매치**를 취해 content 인용·툴콜 input.model 인자에 면역(Claude=model 선행 3851/3 ·
# GPT=content 선행 0/40 실측, spec §20.2). 라인의 매치가 전부 input 소속이면 빈 값 → :169 fail-open.
```
검사: `bash -n hooks/surface-model-policy.sh && echo "bash -n OK"`
- [ ] **Step 4: GREEN 확인 — 4 arm**
```bash
cd ~/.claude; rm -f /tmp/model-policy-*-c21grn*
echo -n "A1 review-strict haiku  : "; run "$(ev review-strict  haiku   "$GPT" c21grn1)"
echo -n "A2 review-strict fable  : "; run "$(ev review-strict  fable   "$GPT" c21grn2)"
echo -n "A3 execute-strict fable : "; run "$(ev execute-strict fable   "$GPT" c21grn3)"
echo -n "A4 review-strict inherit: "; run "$(ev review-strict  inherit "$GPT" c21grn4)"
tail -4 hooks/.log/$(date +%Y-%m).log 2>/dev/null | grep -oE 'rule-[a-z0-9-]+'
rm -f /tmp/model-policy-*-c21grn*
```
Expected [§20.2 실측 표 `:2523-2528`]: A1 `ctx=1`(`rule-b-verifier-below-opus-floor`) · A2 `ctx=1`(`rule-b-fable-leak`) · A3 `ctx=1`(`rule-a-fable-leak`) · **A4 `ctx=0`**(N4). A4 가 `ctx=1` 이면 N4 위반 → **중단·보고**.
- [ ] **Step 5: N3 증명 + 무회귀**
```bash
cd ~/.claude
wfblk() { awk '/^if \[ "\$TOOL" = "Workflow" \]; then$/{f=1} f{print} /^fi$/{if(f) exit}' "$1"; }
A=$(git show HEAD:hooks/surface-model-policy.sh | wfblk /dev/stdin | cksum); B=$(wfblk hooks/surface-model-policy.sh | cksum)
[ "$A" = "$B" ] && echo "N3 OK: Workflow 블록 cksum 불변 ($B)" || { echo "N3 VIOLATION: $A != $B"; exit 1; }
git diff -U0 hooks/surface-model-policy.sh | grep -oE '^@@ -[0-9]+' | tr -d '@ -' \
  | awk '$1>=42 && $1<=158 {n++} END{ printf "Workflow-구역 hunk=%d\n", n+0; exit (n>0) }'
bash hooks/tests/run-all.sh 2>&1 | tail -3
```
Expected: `N3 OK` — 기준 cksum **816060560 9101**(117줄, 2026-08-16 실측) · `Workflow-구역 hunk=0` · `291 / 291 passed` + `정합 OK (291 declared == 291 run)`.
- [ ] **Step 6: Commit**
```bash
cd ~/.claude && git add hooks/surface-model-policy.sh \
 && git commit -m "fix(c21): session_model_of 패밀리-중립화 + 첫 비-input 매치 앵커 (T1·N2)"
```
---
### Task 2: 비-Claude 픽스처 6건 (S2·S3)
**Files:** Modify `hooks/tests/run-all.sh`(smp 블록 말미 — 현행 `:1362` 뒤, `# ==== Summary` 앞) · `hooks/tests/cases.tsv`(말미 append, 4열 TSV `hook<TAB>case_id<TAB>expected_exit<TAB>generator_function`) · `README.md:292`(`291 case`)·`:559`(`291 케이스`)
**Interfaces:** Consumes = T1 의 정정 함수 · 기존 `mk_agent_event`(`:1042`)·`test_smp`(`:1052`)·`$SCRATCH`(`:8`) / Produces = 케이스 73~78 → run-all **297/297**(T6 재검) / **겹침** = `README.md`(T3 도 수정, 다른 줄)
번호 확인(현행 최대 72): `grep 'surface-model-policy' hooks/tests/cases.tsv | tail -1`
- [ ] **Step 1: 픽스처 transcript 3종 생성부 추가** — `# C17 슬롯2 B2 (69~72)` 블록 다음(현행 `:1362` 뒤). **실 GPT 라인 shape** = `content` 가 `model` **앞**(§20.2 키 순서 실측: GPT model-first 0 / content-first 40):
```bash
# --- C21 (73~78): 비-Claude 세션 Agent 리터럴 축 복원 (spec §20) ---
SMP_GPT_T=$(mktemp "$SCRATCH/smp-gpt-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"content":[{"type":"thinking","thinking":"x"}],"model":"gpt-5.6-sol"}}\n' > "$SMP_GPT_T"
# 적대 ⓐ: content 안 툴콜 input.model:"haiku" 가 세션 model 보다 앞 — 앵커 없으면 haiku 오판별(후보 A ✗)
SMP_ADVGPT_T=$(mktemp "$SCRATCH/smp-advgpt-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Agent","input":{"model":"haiku","prompt":"x"}}],"model":"gpt-5.6-sol"}}\n' > "$SMP_ADVGPT_T"
# 적대 ⓑ: Claude model 선행 + 툴콜 후행 — 앵커가 Claude shape 를 깨지 않음(후보 B ✗ 대조)
SMP_ADVCLA_T=$(mktemp "$SCRATCH/smp-advcla-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-fable-5","content":[{"type":"tool_use","name":"Agent","input":{"model":"haiku","prompt":"x"}}]}}\n' > "$SMP_ADVCLA_T"
```
- [ ] **Step 2: 케이스 73~78 + cases.tsv 등재** — 위 생성부 바로 아래:
```bash
# 73~75: 비-Claude(GPT) 세션 리터럴 축 3 arm 복원 (§20.3 — 세션 티어 무참조)
test_smp "73-nonclaude-rule-b-literal-haiku"  0 1 "$(mk_agent_event review-strict  haiku   "$SMP_GPT_T" "smp73-$$")"
test_smp "74-nonclaude-rule-b-fable-leak"     0 1 "$(mk_agent_event review-strict  fable   "$SMP_GPT_T" "smp74-$$")"
test_smp "75-nonclaude-rule-a-fable-leak"     0 1 "$(mk_agent_event execute-strict fable   "$SMP_GPT_T" "smp75-$$")"
# 76: N4 — 상속 축 계속 skip. ALERT 로 뒤집히면 N4 위반 회귀.
test_smp "76-nonclaude-inherit-silent"        0 0 "$(mk_agent_event review-strict  inherit "$SMP_GPT_T" "smp76-$$")"
# 77: 앵커 회귀 센티널 — 툴콜 input.model 이 채택되면 haiku(tier 1) → :201 floor arm 발화(후보 A 회귀).
#     앵커 생존 시 pick 빈 값 → :169 fail-open → SILENT.
test_smp "77-anchor-gpt-toolcall-input-model" 0 0 "$(mk_agent_event review-strict  inherit "$SMP_ADVGPT_T" "smp77-$$")"
# 78: 무회귀 — Claude model-선행 라인은 툴콜이 뒤여도 세션 판별 불변(fable 세션 + 명시 inherit → Rule A ALERT).
test_smp "78-anchor-claude-toolcall-nonregress" 0 1 "$(mk_agent_event execute-strict inherit "$SMP_ADVCLA_T" "smp78-$$")"
```
`cases.tsv` 말미 append(탭 구분 — `printf '%s\t%s\t%s\t%s\n'` 사용, 스페이스 금지):
```
surface-model-policy	73-nonclaude-rule-b-literal-haiku	0	mk_agent_event
surface-model-policy	74-nonclaude-rule-b-fable-leak	0	mk_agent_event
surface-model-policy	75-nonclaude-rule-a-fable-leak	0	mk_agent_event
surface-model-policy	76-nonclaude-inherit-silent	0	mk_agent_event
surface-model-policy	77-anchor-gpt-toolcall-input-model	0	mk_agent_event
surface-model-policy	78-anchor-claude-toolcall-nonregress	0	mk_agent_event
```
- [ ] **Step 3: RED 실증 — 판별식만 되돌려 73~75 FAIL 확인**

T1 이 선행하므로 픽스처만으로는 RED 를 볼 수 없다. **판별식만** 일시 되돌린다(복구 필수):
```bash
cd ~/.claude
git stash push -- hooks/surface-model-policy.sh
bash hooks/tests/run-all.sh 2>&1 | grep -E 'surface-model-policy/7[3-8]|passed' | head -10
git stash pop                                  # ★복구 — 반드시 실행
git diff --stat hooks/surface-model-policy.sh  # 복구 확인: T1 정정이 워킹트리에 존재
```
Expected(stash 중): `73`·`74`·`75` 가 `FAILED_LIST` 에 `ctx=0` 으로 등장 · `76`·`77`·`78` 은 PASS(현행 코드에서도 각각 ctx=0/0/1 — 메인 실측 ✓). `stash pop` 후 297/297.
※ **77 은 이 RED 수열에서 판별력을 보이지 않는다**(현행·정정 후 둘 다 SILENT). 판별 대상은 「후보 A 로의 회귀」이며 함수 단위로는 A→`haiku` / E→빈 값이 실측됐다. **훅 E2E 로 A 변종을 돌린 실측은 없다(미검증)** — 77 은 회귀 센티널로 착륙시키고 그 상한을 여기 명기한다.
- [ ] **Step 4: GREEN + reconciliation + README 동기**
```bash
cd ~/.claude
perl -i -pe 's/291 case/297 case/g; s/291 케이스/297 케이스/g' README.md
grep -cE '297 (case|케이스)' README.md                  # Expected: 2
grep -cvE '^[[:space:]]*(#|$)' hooks/tests/cases.tsv    # Expected: 297
bash hooks/tests/run-all.sh 2>&1 | tail -3
bash setup/verify-setup.sh 2>&1 | tail -1
```
Expected: `297 / 297 passed` · `정합 OK (297 declared == 297 run)` · `verify-setup: PASS=89 FAIL=0`(seal #20 이 README 동기 검사 — 미동기면 자동 FAIL).
- [ ] **Step 5: Commit**
```bash
cd ~/.claude && git add hooks/tests/run-all.sh hooks/tests/cases.tsv README.md \
 && git commit -m "test(c21): 비-Claude 세션 픽스처 6건 (73~78) — 리터럴 3 arm·N4·앵커 2 (T2)"
```
---
### Task 3: 신규 seal `#<NEXT>` — 경로-전달 규약 + seal-regression 변이 (S8·S3)
**Files:** Modify `setup/verify-setup.sh`(신규 체크 — `:633` 모드팩 블록 `fi` 뒤, `EXPECTED_TOTAL=` 주석 앞) · `setup/tests/seal-regression.test.sh`(`mut_*` 1개 + `assert_seal_fires` 1행) · `README.md:300`(`현재 89 PASS`→`현재 90 PASS`)
**Interfaces:** Consumes = `docs/ai-context/non-obvious.md:99-102` **SMART ①**(기한 "C21 초입" = 이번 사이클) · seal #51 vacuous-방지 선례(`verify-setup.sh:626-627`) / Produces = verify-setup **90/0** · seal-regression **27/0** / **겹침** = `setup/verify-setup.sh`(T5-I3, 다른 절) · `README.md`(T2)
**seal 대상**(non-obvious.md verbatim): 「경로 전달 규약 — `setup/tests/`·`hooks/tests/` 의 `python -c`/`node -e` 인라인 소스에 리터럴 `/tmp/` 또는 셸 변수 보간 경로가 있으면 FAIL 하는 seal 1건 추가 + RED→GREEN 증명」
**비-vacuous 실측(2026-08-16)**: 대상 인라인 호출 = `run-all.sh` **13** · `worktree-teardown.test.sh` **1** · `failopen-surface.test.sh` **2**(주석 제외) → 스캐너 **TOTAL=16**(한 줄 다중 호출 포함) · **VIOLATION=0**. 대상 0 이면 vacuous 이므로 **seal 자신이 `TOTAL > 0` 을 확인**한다(#51 선례).
- [ ] **Step 1: seal 번호 발급**
```bash
cd ~/.claude && git show origin/master:setup/verify-setup.sh \
  | grep -oE '^# [0-9]+\. ' | grep -oE '[0-9]+' | sort -n | tail -1
```
출력 + 1 을 `<NEXT>` 로 확정. 현행 최대 **51**(실측) → 통상 `#52`. 동시 사이클 시 값이 달라질 수 있으므로 **이 명령 출력이 SSOT**.
- [ ] **Step 2: seal 본체 추가**
```bash
# <NEXT>. 경로-전달 규약 (non-obvious #3 SMART ①): setup/tests/·hooks/tests/ 의 인라인 인터프리터
#     소스에 리터럴 /tmp/ 또는 (겹따옴표 소스의) 셸 변수 보간이 있으면 FAIL. MSYS 에서 bash 경로를
#     네이티브 python/node 가 C:\tmp\x 로 오해석해 픽스처가 조용히 미생성되고, 계수기형 오라클이 그
#     빈 입력을 "위반 없음"으로 보고하던 클래스(C20 Task 6 라이브 재현).
PP_OUT=$(awk '
  /^[[:space:]]*#/ { next }
  { line = $0; pos = 1
    while (match(substr(line, pos), /(python3?|node)[ \t]+-[ce][ \t]+/)) {
      st = pos + RSTART - 1; pos = st + RLENGTH; rest = substr(line, pos); q = substr(rest, 1, 1)
      if (q == "\047") { i = index(substr(rest, 2), "\047"); src = (i > 0) ? substr(rest, 2, i - 1) : substr(rest, 2); interp = 0 }
      else if (q == "\"") { i = index(substr(rest, 2), "\""); src = (i > 0) ? substr(rest, 2, i - 1) : substr(rest, 2); interp = 1 }
      else { src = rest; interp = 0 }
      TOTAL++
      if (index(src, "/tmp/") > 0 || (interp && src ~ /\$[A-Za-z_{(]/)) { V++; printf "%s:%d ", FILENAME, FNR }
    } }
  END { printf "\nTOTAL=%d VIOLATION=%d\n", TOTAL + 0, V + 0 }
' "$HOME/.claude/hooks/tests"/*.sh "$HOME/.claude/setup/tests"/*.sh 2>/dev/null)
PP_TOTAL=$(printf '%s' "$PP_OUT" | tail -1 | grep -oE 'TOTAL=[0-9]+' | cut -d= -f2)
PP_VIOL=$(printf '%s' "$PP_OUT" | tail -1 | grep -oE 'VIOLATION=[0-9]+' | cut -d= -f2)
PP_SITES=$(printf '%s' "$PP_OUT" | head -1)
if [ "${PP_TOTAL:-0}" -eq 0 ]; then
  fail "경로-전달 seal: 검사 대상 0 (인라인 인터프리터 호출 부재 — vacuous seal 방지, #51 선례)"
elif [ "${PP_VIOL:-0}" -eq 0 ]; then
  ok "경로-전달 규약: 인라인 인터프리터 ${PP_TOTAL}건 위반 0 (non-obvious #3 SMART ①)"
else
  fail "경로-전달 규약 위반 ${PP_VIOL}건 — 인라인 소스의 리터럴 /tmp/ 또는 변수 보간 경로: ${PP_SITES}. argv/stdin 으로 전달할 것 (non-obvious #3)"
fi
```
- [ ] **Step 3: RED→GREEN 증명 (격리 사본 · 라이브 무편집)** — Step 2 의 awk 프로그램(`PP_OUT=$(awk '` 다음 줄부터 `' "$HOME/...` 직전까지)을 `$R/seal.awk` 로 복사한 뒤:
```bash
cd ~/.claude
export RPI_SKIP="C21 T3 — seal 판별력 RED 실증(임시 사본)"
R=$(mktemp -d); mkdir -p "$R/hooks/tests" "$R/setup/tests"
cp hooks/tests/*.sh "$R/hooks/tests/"; cp setup/tests/*.sh "$R/setup/tests/"
printf '%s\n' 'PPV=$(mktemp -d); node -e "console.log($PPV)"' >> "$R/hooks/tests/run-all.sh"
echo "--- 원본(GREEN) ---"; awk -f "$R/seal.awk" hooks/tests/*.sh setup/tests/*.sh | tail -1
echo "--- 주입본(RED) ---"; awk -f "$R/seal.awk" "$R"/hooks/tests/*.sh "$R"/setup/tests/*.sh | tail -1
rm -rf "$R"; unset RPI_SKIP
```
Expected: 원본 `TOTAL=16 VIOLATION=0` · 주입본 `TOTAL=17 VIOLATION=1` [메인 실측 ✓ — 동일 주입 문자열로 확인].
- [ ] **Step 4: seal-regression 변이 1개 추가** — `mut_schema_required_empty` 정의 다음:
```bash
# Mutator 23 — seal #<NEXT>(경로-전달 규약)의 RED: replica 의 테스트 파일에 겹따옴표 인라인 소스 +
# 셸 변수 보간을 1건 주입한다. non-obvious #3 이 기술한 실패 형태 그 자체이며, seal 이 대상 계수만
# 하고 위반 판정을 안 하면(vacuous) GREEN 으로 새어 나간다.
mut_pathpass_interp() { printf '%s\n' 'PPV=$(mktemp -d); node -e "console.log($PPV)"' >> "$1/hooks/tests/run-all.sh"; }
```

`assert_seal_fires` 마지막 행(`schema_required_empty`) 다음: `assert_seal_fires "pathpass_interp" mut_pathpass_interp "경로-전달 규약 위반"`
※ 기대 FAIL 문자열은 Step 2 의 `fail` 메시지에서 따왔다(`assert_seal_fires` 는 `grep -qF` 부분일치 — `:81`).
- [ ] **Step 5: README 동기 + 전 스위트**
```bash
cd ~/.claude
perl -i -pe 's/현재 89 PASS/현재 90 PASS/g' README.md
grep -c '현재 90 PASS' README.md                        # Expected: 1
bash setup/verify-setup.sh 2>&1 | tail -2
bash setup/tests/seal-regression.test.sh 2>&1 | tail -2
bash hooks/tests/run-all.sh 2>&1 | tail -2
```
Expected: `verify-setup: PASS=90 FAIL=0`(seal #36 이 README 선언 == 런타임 실측 parity 검사) · `seal-regression: PASS=27 FAIL=0` · `297 / 297 passed`.
- [ ] **Step 6: Commit**
```bash
cd ~/.claude && git add setup/verify-setup.sh setup/tests/seal-regression.test.sh README.md \
 && git commit -m "feat(c21): 경로-전달 규약 seal #<NEXT> + 변이 23 — non-obvious #3 SMART ① 이행 (T3)"
```
---
### Task 4: I1 non-obvious 등록 — Edit 혼합-개행 파괴 (S6)
**Files:** Modify `docs/ai-context/non-obvious.md`(항목 **4** append — 순수 LF, Edit 허용)
**Interfaces:** Consumes = `docs/ai-context/review-yield.md:63`(§4 1단계 승인 근거) · `_goal/c20-i1-repro-measured.md`(3케이스 매트릭스) / Produces = 항목 4(파일 헤더 「★규약: 재현 픽스처 동반」 GAP-012 충족)
- [ ] **Step 1: §4 1단계(사용자 확인) 근거 확보** — `grep -n 'I1 처분' docs/ai-context/review-yield.md`

Expected: `:63` verbatim 「**I1 처분: Edit 혼합-개행 파괴 = non-obvious 등록 후보(재현 픽스처 제작 가능 — C18-형 "5 Whys 불가" 면제 불성립) → §4 1단계 사용자 확인 완료(2026-08-10 머지 정지점 승인) — 차기 사이클 초입 review-strict 5 Whys+재현 픽스처 등록 확정**」. 항목 4 본문에 근거로 인용(1단계 재확인 불요).
- [ ] **Step 2: 재현 픽스처 실행 — 기전 재현(Edit 도구 비의존)**

Edit 은 모델 도구라 셸이 자동 호출할 수 없다. 픽스처는 **기전 재현**(혼합 파일에 개행 정규화가 동반되면 무관 줄이 diff 에 잡힘) + **대조군**(바이트 편집):
```bash
cd ~/.claude; export RPI_SKIP="C21 T4 — I1 재현 픽스처 실행"
D=$(mktemp -d)
printf 'alpha\r\nbravo\r\ncharlie\r\ndelta\r\necho\nfoxtrot\n' > "$D/orig.txt"
cp "$D/orig.txt" "$D/edit.txt"; cp "$D/orig.txt" "$D/perl.txt"
perl -i    -pe 's/\r\n/\n/g; s/^charlie$/charlie-EDITED/' "$D/edit.txt"   # Edit 도구 상당(혼합→전량 LF)
perl -0777 -i -pe 's/charlie/charlie-EDITED/'             "$D/perl.txt"   # 바이트 편집(개행 보존)
crlf() { perl -ne '$n++ if /\r/; END{print $n+0}' "$1"; }
printf 'BEFORE   CRLF=%s\n' "$(crlf "$D/orig.txt")"
printf 'EDIT상당 CRLF=%s  changed=%s\n' "$(crlf "$D/edit.txt")" "$(diff "$D/orig.txt" "$D/edit.txt" | grep -c '^<')"
printf 'perl     CRLF=%s  changed=%s\n' "$(crlf "$D/perl.txt")" "$(diff "$D/orig.txt" "$D/perl.txt" | grep -c '^<')"
rm -rf "$D"; unset RPI_SKIP
```
Expected [메인 실측 ✓]: `BEFORE CRLF=4` · `EDIT상당 CRLF=0 changed=4` · `perl CRLF=4 changed=1` — **1줄 편집 의도가 4줄 diff 로 번진다.**
- [ ] **Step 3: 항목 4 작성** — 기존 항목 1~3 의 5필드(**관측 / 5 Whys / SMART / 재현 픽스처 / 관계**)를 따르고 아래를 반드시 포함:
- **관측**: C19(2026-08-10) 리뷰 정정 중 Edit 이 혼합-개행 파일 전체를 LF 로 통일해 편집 범위 밖 줄이 diff 에 잡힘. C20 Phase R 3케이스(`_goal/c20-i1-repro-measured.md`): A(CRLF 머리+LF 꼬리)=**파괴** · B(LF 다수+CRLF 1)=**파괴** · C(순수 CRLF)=**보존**. **★방향은 CRLF→LF** — C19 layer-yield `:63` 의 "LF 꼬리를 CRLF 재작성"은 방향이 반대이며 이 등록이 실측 방향으로 정정한다(실패 *클래스*는 동일).
- **5 Whys**: root cause 는 **시스템/프로세스**여야 한다(사람/AI 불가 — CLAUDE.md §4-3). 권고 종착지 = 「**파일의 개행 상태가 편집 전에 조회되는 자리가 절차에 없다** — 도구 선택(Edit vs 바이트 편집)이 파일 속성에 의존하는데 그 확인 단계가 어느 skill 에도 배치돼 있지 않고, `grep -c $'\r'` 가 이 클래스 파일에서 **0 을 반환**해 확인을 시도해도 오답이 나온다」.
- **SMART**: **측정 가능한 지표 + 기한**. 최소 1건은 「plan/skill 의 편집 지시가 대상 파일의 개행 상태를 명시하게 한다 — 측정 = 혼합-개행 파일을 편집하는 task 의 Files 블록에 개행 실측 줄 존재(`perl -ne` 계수 인용), 기한 = **C22 Phase P**」 형태.
- **재현 픽스처**: Step 2 명령 블록을 그대로 싣고 기대 출력 3줄 병기. **자동화 상한 명시**(Edit 은 모델 도구라 셸 재현 불가 → 기전 재현) — 침묵 잔여 금지(항목 1 선례).
- **관계**: spec §19.7-7(C20 이 "실측 방향으로 기재하고 원 기록을 정정 부기할 것"으로 예약) · C19 layer-yield `:63`·`:79`(②차기 이월) 지목.
- [ ] **Step 4: 5 Whys 검증 — review-strict 위임 (CLAUDE.md §4-2)**
```
Agent(subagent_type="review-strict",
      task="non-obvious.md 항목 4 의 5 Whys 검증",
      context_paths=["~/.claude/docs/ai-context/non-obvious.md","~/.claude/CLAUDE.md",
                     "~/.claude/_goal/c20-i1-repro-measured.md"],
      success_criteria="
        PASS only if ALL:
        - 항목 4 가 5필드(관측/5 Whys/SMART/재현 픽스처/관계)를 모두 보유
        - 5 Whys 종착 root cause 가 **시스템 또는 프로세스** — 사람/AI 귀책이면 FAIL (CLAUDE.md §4-3)
        - 각 Why 가 직전 Why 의 답을 실제로 파고듦 (동어반복·건너뜀 없음)
        - SMART 에 **측정 가능한 지표**와 **기한**이 둘 다 존재
        - 재현 픽스처가 실행 가능한 명령이고 자동화 상한이 명시됨
        - 관측 서술의 개행 방향이 CRLF→LF (C19 기록과 반대라는 정정 부기 포함)
        FAIL with: 위반 항목별 지적 + 요구 정정")
```
FAIL 이면 지적 항목만 정정 후 **델타 재심**(직전 FAIL 지목 항목의 해소 + 정정이 편집한 절에 한정한 원 기준 재적용 — C16 §15.4).
- [ ] **Step 5: 검증 + Commit**
```bash
cd ~/.claude
grep -c '^## 4\.' docs/ai-context/non-obvious.md      # Expected: 1
grep -c '재현 픽스처' docs/ai-context/non-obvious.md  # Expected: 기준 4(항목1~3+헤더 규약) + 1 = 5
bash setup/verify-setup.sh 2>&1 | tail -1             # Expected: PASS=90 FAIL=0
git add docs/ai-context/non-obvious.md \
 && git commit -m "docs(c21): non-obvious #4 등록 — Edit 혼합-개행 파괴(CRLF→LF) 5 Whys+픽스처 (T4)"
```
---
### Task 5: GAP 원 기록 정정 부기 + C20 이월 3건 처분 (S5·S7 — light-병합)
light-병합 근거(C17 §16.3-3): (a)(b)(c) 전부 순수 문서·기계 편집(I3 만 코드 1줄)이고 files 합집합이 상호 비겹침. successCriteria 는 conjunct.
**Files:** Modify `docs/ai-context/c21-gap-nonclaude-session-blindness.md`(`:19-22` 표 · `:78-79` F1 · `:81-83` F2) · `docs/ai-context/c20-carryover-recovery.md`(I2·I3 절 말미 · `:99-107` · `:109-121`) · `.gitignore:25` · `setup/verify-setup.sh:621`(I3)
**Interfaces:** Consumes = §20.2(`:169` 지목 기각) · §20.3 N3(`:54`=의식적 수용) · §20.6-6(정정 부기 지시) · T1~T3 산출(파일:줄 인용원) / Produces = 추적 사이트 2곳의 spec-모순 해소 + 이월 3건 종결 / **겹침** = `setup/verify-setup.sh`(T3, 다른 절) → T3 완료 후 실행
- [ ] **Step 1: (a) GAP 원 기록 정정 부기 — 3사이트**
**삭제 금지**(§19.7-7 선례 · §20.6-6 — 오판정의 이력도 근거). 원문 유지 + 인용 블록 `> **C21 판정**: …` 추가:
1. **`:19-22` 표 아래** — `:169` 행: 「§20.2 가 이 지목을 **기각**했다. `:169` 는 *판별 실패*의 fail-open 이고 *미지 티어* 와 상태 의미가 다르다(전자는 판별 자체가 불가). 제거 시 별개 클래스의 처분까지 바뀌며 그 모집단은 작지 않다 — `projects/C--Users-12132--claude/*.jsonl` **50개 중 12개**가 assistant 라인 0건(§20.2 실측). **`:169` 는 유지**되었고 정정은 판별식 1축에 국한됐다.」 `:54` 행: 「§20.3 **N3** 가 이를 결함이 아니라 §16.4-5 의 **의식적 수용**으로 판정 — Workflow 경로는 C21 에서 개정하지 않는다(diff 0). 재판정하려면 C2 부분-평가 복잡도 상한을 뒤집는 독립 근거가 선행해야 한다(§20.6-2).」
2. **`:78-79` F1 아래** — 「F1(패밀리-중립화)은 **채택됐으나 단독으로는 불충분**했다. 단순 중립화(후보 A)는 GPT 라인에서 툴콜 `input.model` 인자를 세션 모델로 오판별하며(`haiku` → `tier_of`=1 → `SESSION_TIER != 0` 가드 통과) 이는 **N4 가 금지한 "미지 세션에 임의 티어 부여"의 실현**이다. 채택안 = F1 + **구조 앵커**(라인-내 첫 **비-`input`** 매치 = 후보 E).」
3. **`:81-83` F2 아래** — 「F2 의 전제(「하나가 불가능하면 전부를 포기한다」)는 참이나 **처방의 절반이 기각**됐다. 리터럴 축은 이미 세션을 참조하지 않으므로(§20.2 실측 ③: `SESSION_TIER` 참조 4회가 전부 `inherit` 분기 내부) **새 가드 없이** `SESSION_MODEL` 만 채워지면 복원된다 — 조기 종료 분리는 불요했다.」
- [ ] **Step 2: (b)-I2 — ownership 오타 침묵-skip 처분** (재현: `c20-carryover-recovery.md:45-65` · **경로는 argv 전달**, non-obvious #3)
```bash
cd ~/.claude; export RPI_SKIP="C21 T5 — I2 재현"
D=$(mktemp -d)
printf '%s\n' '{ "modeName":"typo-test", "workers":[ {"role":"verifier","ownership":"review_only","command":"claude --model haiku"} ] }' > "$D/typo.json"
bash -c 'source ~/.claude/setup/lib/modepack-oracle.sh; modepack_oracle_scan "$1"; echo "exit=$?"' _ "$D"
rm -rf "$D"; unset RPI_SKIP
```
Expected: `TOTAL=1 LITERAL=1 DYNAMIC=0 VIOLATION=0` + `exit=0`(오타 = 검사 면제, 침묵 통과).

**판정을 § I2 말미에 부기한다**(둘 중 하나 · **어느 쪽이든 근거를 적는다**):
- **정정** — 미지 `ownership` 값을 계수해 표면화(3값 계약 동형 · "모르는 값 = 판정 불가, 표면화"). `modepack-oracle.sh` 에 `UNKNOWN=` 카운터 + #51 처분 arm + seal-regression 변이가 동반돼 **범위가 T3 급으로 커진다**.
- **수용 잔여** — 주축(Agent 리터럴 축)이 아니고 T3 가 이미 seal 예산 1건을 소비했으므로 미루되 **재판정 조건**(모드팩 파일 수 > 1 또는 ownership 값 집합 확장 시)과 **기한**(C22)을 명시한다.
- 권고 = **정정**이나 스코프상 **수용 잔여도 정당**.
- [ ] **Step 3: (b)-I3 — 오라클 stderr 폐기 정정 (권고 = 정정)**
`setup/verify-setup.sh:621` 의 `2>/dev/null` 이 위반 상세를 버린다. 상세는 stderr 로만 나온다:
```bash
cd ~/.claude; export RPI_SKIP="C21 T5 — I3 stderr 분리 실측"
D=$(mktemp -d)
printf '%s\n' '{ "modeName":"probe", "workers":[ {"role":"verifier","ownership":"review-only","command":"claude --model haiku"} ] }' > "$D/typo.json"
bash -c 'source ~/.claude/setup/lib/modepack-oracle.sh; modepack_oracle_scan "$1" 2>&1 >/dev/null' _ "$D"
rm -rf "$D"; unset RPI_SKIP
```
Expected [메인 실측 ✓]: `  typo.json: workers[0] (role=verifier) review-only 인데 haiku(tier 1) < floor 3`

정정 — `:621` 을 stderr 포획형으로 교체하고 `:629` 의 `fail` 문구 끝에 ` — 상세: ${MP_DETAIL:-없음}` 을 덧붙인다:
```bash
MP_ERR=$(mktemp); MP_OUT=$(modepack_oracle_scan "$HOME/.claude/modes" 2>"$MP_ERR"); MP_RC=$?
MP_DETAIL=$(cat "$MP_ERR" 2>/dev/null); rm -f "$MP_ERR"
```
`2>/dev/null` 의 원 목적(오라클 부재 시 소음 억제)은 `[ -f "$MP_ORACLE" ]` 가드(`:618`)가 이미 담당 → 회귀 없음. 검증: `bash setup/verify-setup.sh 2>&1 | tail -1` → `PASS=90 FAIL=0` · `bash setup/tests/seal-regression.test.sh 2>&1 | tail -1` → `PASS=27 FAIL=0`.
- [ ] **Step 4: (b)-`.gitignore` 베어 `.bak` 정정 (권고 = 정정)**
```bash
cd ~/.claude
git check-ignore -v settings.json.bak; echo "before rc=$?"      # Expected: 출력 없음, rc=1
git status --short | grep -F 'settings.json.bak'                # Expected: ?? settings.json.bak (실재)
perl -i -pe 's/^settings\.json\.bak-\*$/settings.json.bak*/' .gitignore
sed -n '25p' .gitignore                                          # Expected: settings.json.bak*
git check-ignore -v settings.json.bak; echo "after rc=$?"        # Expected: .gitignore:25 매치, rc=0
git check-ignore -q settings.json.bak-test; echo "legacy rc=$?"  # Expected: rc=0 (무회귀)
```
`c20-carryover-recovery.md:109-121` 말미에 rc 전후 대비(1 → 0)를 부기한다.
- [ ] **Step 5: (c) 이월 수취 규약 판정 부기** — `c20-carryover-recovery.md:99-107` 의 「ledger 이월 선언 ↔ 수취 절 등재」 기계 검사는 **이번 사이클 범위 밖**(seal 1건은 T3 가 소비했고 이 검사는 ledger 파싱 계약을 새로 정의해야 한다). 그 절에 1줄 부기:

> **C21 판정**: 차기 이월(C22 후보). 사유 = 이번 사이클 seal 예산 1건은 non-obvious #3 SMART ①(기한 "C21 초입")이 선점 — 기한 있는 항목이 우선한다. 재판정 조건 = C22 Phase R 에서 ledger 이월 선언의 레이블 추출 규칙이 결정될 때.
- [ ] **Step 6: 검증 + Commit**
```bash
cd ~/.claude
grep -c 'C21 판정' docs/ai-context/c21-gap-nonclaude-session-blindness.md   # Expected: 3 (표·F1·F2)
grep -c 'C21 판정' docs/ai-context/c20-carryover-recovery.md                # Expected: ≥4 (I2·I3·.bak·(c))
bash setup/verify-setup.sh 2>&1 | tail -1
git add docs/ai-context/c21-gap-nonclaude-session-blindness.md \
        docs/ai-context/c20-carryover-recovery.md .gitignore setup/verify-setup.sh \
 && git commit -m "docs(c21): GAP 원 기록 정정 부기 3사이트 + C20 이월 3건 처분 (T5)"
```
---
### Task 6: 최종 무회귀 + 카운트 동기 (S3)
**Files:** 편집 없음(검증 전용). drift 발견 시에만 `README.md` 정정.
**Interfaces:** Consumes = T1~T5 전 산출 / Produces = 사이클 보고용 3스위트 수치 + run-log 1줄
- [ ] **Step 1: 3스위트 완주**
```bash
cd ~/.claude
bash hooks/tests/run-all.sh              2>&1 | tail -4
bash setup/verify-setup.sh               2>&1 | tail -2
bash setup/tests/seal-regression.test.sh 2>&1 | tail -2
```
Expected: `297 / 297 passed` + `정합 OK (297 declared == 297 run)` · `verify-setup: PASS=90 FAIL=0` · `seal-regression: PASS=27 FAIL=0`. (기준선 291/89/26 대비 +6/+1/+1 = T2·T3·T3 산출.)
- [ ] **Step 2: 카운트 parity 명시 대조** (seal #20·#36 이 자동 검사하나 육안 확인)
```bash
cd ~/.claude
echo "cases 실측: $(grep -cvE '^[[:space:]]*(#|$)' hooks/tests/cases.tsv)"
grep -E 'cases\.tsv' README.md | grep -oE '[0-9]+ ?(케이스|cases?)'
grep -oE '현재 [0-9]+ PASS' README.md
```
Expected: 실측 `297` · README 선언 전건 `297` · `현재 90 PASS`.
- [ ] **Step 3: N3 최종 확인 (사이클 누적 diff 기준)**
```bash
cd ~/.claude
wfblk() { awk '/^if \[ "\$TOOL" = "Workflow" \]; then$/{f=1} f{print} /^fi$/{if(f) exit}' "$1"; }
A=$(git show master:hooks/surface-model-policy.sh | wfblk /dev/stdin | cksum); B=$(wfblk hooks/surface-model-policy.sh | cksum)
[ "$A" = "$B" ] && echo "N3 최종 OK ($B)" || { echo "N3 VIOLATION: $A != $B"; exit 1; }
```
Expected: `N3 최종 OK (816060560 9101)` — 사이클 시작 실측과 동일.
- [ ] **Step 4: run-log 요약 1줄 소비**
```bash
cd ~/.claude && bash -c 'source ~/.claude/hooks/_common.sh; runlog_summary ~/.claude/hooks/.runlog/$(date +%Y-%m).jsonl'
```
출력(EVENTS/BLOCK/SKIP/FAILOPEN)을 사이클 보고에 1줄 포함(GAP-003 · start-rpi-cycle `:251`). 파일 부재 시 생략.
---
## 수용 잔여
spec **§20.6-1~9** 전건이 그대로 유효하다(상속 축 판정 불가 · Workflow 비대칭 존속 · advisory 상한 · `tier_of` 의 비-Claude 뭉갬 = 정직한 과분류 · 복원 후 커버리지 미측정 · GAP 원 기록 정정[T5 해소] · ⓓ 표본 1픽스처[T2 해소] · GPT 툴콜-only 라인 판별-불가 · 앵커 60자 휴리스틱). plan 고유 추가분 1건:
10. **케이스 77 의 판별력은 훅 E2E 로 미검증** — 함수 단위(후보 A→`haiku` / E→빈 값)만 실측했고 A 변종을 훅에 실어 돌린 실측은 없다. 77 은 회귀 센티널로 착륙하며 그 상한은 Task 2 Step 3 에 명기했다.
