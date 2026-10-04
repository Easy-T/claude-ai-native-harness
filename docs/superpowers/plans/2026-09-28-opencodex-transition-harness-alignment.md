# opencodex 전환 하네스 정합 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 76
**Started:** 2026-09-28

**Goal:** CCS 퇴역과 opencodex 상시가동 이후 하네스에 남은 어긋남 6가지를 정정한다. 모두 실측으로 드러난 것이다.
1. Rule C3 가 opencodex 생성 래퍼 `ocx-*` 를 오탐해, live `verify-setup` 이 FAIL=1(#47)이다.
2. model-window 세대 규칙에 회귀 케이스가 없다.
3. worktree-teardown 이 미커밋 작업이 있는 worktree 를 지운다(라이브 사고).
4. statusline 5h/7d 바가 죽은 CCS 토큰에 묶여 있다.
5. CCS 퇴역 문서가 정리되지 않았다.
6. 플러그인 핀이 드리프트했다.

**Architecture:** 서로 독립인 하네스 표면 6곳을 각각 정정한다.
- 판정 로직이 있는 곳(hook·seal·teardown·statusline)은 테스트를 먼저 쓴다(RED → GREEN).
- 새 동작은 run-all · seal-regression · teardown E2E · statusline 스위트에 고정한다.
- 같은 사실을 담은 문서(CONTEXT.md · model-policy.md · SECURITY.md · README · skill)는 소유 task 안에서 함께 갱신한다.

**Tech Stack:** bash(MSYS Git Bash) · node · jq · PowerShell 5.1(E2E 보조)

**Spec:**
- `docs/superpowers/specs/2026-07-25-model-policy-design.md` §22: §22.1 C3 패턴 면제, §22.2 model-window 세대 규칙. §13.3 표 ④행과 §P1 supersede 포인터도 포함한다.
- `docs/superpowers/specs/2026-06-21-worktree-teardown-sessionend-design.md` §12
- `docs/superpowers/specs/2026-05-31-statusline-balanced-design.md` v3 절
- 사용자 결정: `~/.claude/_goal/2026-09-28-opencodex-ops-closeout-goal.md` 의 "사용자 결정" 4·5·7

**Best-Direction Check:** 최선안 = 채택안 = 아래 6개. **DOWNGRADE-DECLARED: 없음.**
- ① **C3:** 생성기-소유 패턴 면제를 채택하고, 그 전제(마커·model 선언)는 seal 이 봉인한다. 사용자 결정 7 이 이 방향을 먼저 확정했다.
  - 런타임 frontmatter 해소 안은 판정 축(model 선언 존재)이 같다. 그러면서 hook 이 레지스트리 해소를 재구현해야 해서 오판정 표면만 늘어난다(spec §22.1).
- ② **model-window:** 세대 규칙 + 양성 회귀 2건.
- ③ **teardown:** **식별 무관 불변식**(미커밋 = 보존)을 채택한다.
  - 소유자 식별을 강화하는 안은 자식 세션이 스스로 마커를 만드는 경로에서 다시 뚫린다(spec §12.2).
- ④ **statusline:** Claude Code 가 주는 자체 `rate_limits` 를 쓴다. 네트워크 호출과 자격증명 읽기가 0 이 된다.
- ⑤ **문서:** 현행 사실로 정정한다. 역사 문서는 배너로 무효 구간을 표시한다.
- ⑥ **핀:** review-on-change 판정 후 갱신한다. 판정은 LEGIT-UPDATE 로 수령했다.

## Global Constraints

- **편집 위치:** git worktree `C:/Users/12132/.claude/.claude/worktrees/opencodex-ops`(브랜치 `opencodex-ops-c75-c76`, base `1ec9912`).
  - 메인 트리 HEAD 는 바꾸지 않는다.
  - 메인 트리에 남은 미커밋 사본은 머지 후 동기화 단계에서 정리한다.
- **커밋 금지 파일:** `debug/` · `plugins/` · `skills/disk-cleanup/` · `skills/system-optimize/` · `opencode-harness/COMPANY-ONBOARDING.md` · `agents/ocx-*.md` · `skills/init-ai-ready-project/templates/pre-commit-deny.sh.tpl`
  - `git add` 는 경로를 명시해서만 한다.
- **`claude`/`claude-ocx` 는 worktree 안에서 실행하지 않는다.**
  - 자식 세션의 SessionEnd 가 teardown 을 일으킨다(spec teardown §12.1).
  - live hook 은 메인 트리의 `$HOME/.claude/hooks` 다. 따라서 이 금지는 **머지와 메인 동기화가 끝날 때까지** 유효하다.
- verify-setup seal 은 bash 파일 조작만 쓴다(node readFileSync 금지 — C6 교훈).
- 금지 사항:
  - 루트 CLAUDE.md 수정
  - `injectAgents` 토글
  - `~/.codex/config.toml` 수정
  - 자격증명 파일 읽기
- **텍스트 치환 규칙:** 문서를 기계적으로 편집할 때 JS `String.replace(str, str)` 를 쓰지 않는다. 치환 문자열의 `$`+백틱, `$'`, `$&` 가 특수 패턴으로 해석된다(사이클 75 plan 손상 실사고). `indexOf` + `slice` 나 Edit 도구를 쓴다.
- **README 카운트(seal #20):** `hooks/tests/cases.tsv` 는 305 → T1 후 **307** → T2 후 **309**.
  - README.md 292·559행 두 곳을 **케이스를 추가하는 같은 Step 에서** 올린다. 그래야 중간 상태에서 #20 이 FAIL 하지 않는다.

## 검증 하네스 — staged HOME (모든 테스트 Step 공통)

아래 대상은 모두 `$HOME/.claude` 를 기준으로 동작한다.
- run-all.sh(6-7행)
- worktree-teardown.test.sh(9행)
- verify-setup.sh
- seal-regression.test.sh(`SRC=$HOME/.claude`)

그래서 worktree 편집은 **staged HOME** 에서 검증한다. staged HOME 의 구성은 다음과 같다.
- worktree 사본
- git 이 나르지 않는 live 입력: `settings.json`, `agents/ocx-*.md`, `plugins/`, `.gitconfig`

statusline 스위트는 `SL=` 로 대상을 지정한다.

```bash
WT=/c/Users/12132/.claude/.claude/worktrees/opencodex-ops
STG=$(mktemp -d "${TMPDIR:-/tmp}/stg-home-XXXXXX"); mkdir -p "$STG/.claude"
restage() {  # worktree 의 현재 상태를 staged HOME 에 덮어쓴다(편집 후마다 호출)
  ( cd "$WT" && tar --exclude=.git -cf - . ) | ( cd "$STG/.claude" && tar -xf - )
  chmod +x "$STG/.claude/hooks/"*.sh "$STG/.claude/setup/"*.sh 2>/dev/null || true
}
restage
cp -p "$HOME/.claude/settings.json" "$STG/.claude/"
cp -p "$HOME/.claude/agents/"ocx-*.md "$STG/.claude/agents/"
cp -a "$HOME/.claude/plugins" "$STG/.claude/plugins"
cp -p "$HOME/.gitconfig" "$STG/.gitconfig"
# 실행 예
HOME="$STG" bash "$STG/.claude/setup/verify-setup.sh" 2>&1 | tail -3
HOME="$STG" bash "$STG/.claude/setup/tests/seal-regression.test.sh" 2>&1 | tail -5
HOME="$STG" bash "$STG/.claude/hooks/tests/run-all.sh" 2>&1 | tail -5
HOME="$STG" bash "$STG/.claude/hooks/tests/worktree-teardown.test.sh" 2>&1 | tail -3
SL="$WT/statusline.sh" bash "$WT/tests/statusline/run-tests.sh" 2>&1 | tail -3
```

## Review Focus

1. **손으로 쓴 `ocx-foo.md`(마커 없음):** model 선언 여부와 관계없이 패턴 면제로 C3 를 빠져나가면 안 된다.
   - 테스트: seal #47 전제 검사 + seal-regression 변이 `c3_ocx_unmarked`(T1).
2. **ocx 스폰과 general-purpose 무선언 스폰이 섞인 Workflow:** 패턴이 다른 스폰의 C3 발화를 가리면 안 된다.
   - 테스트: 케이스 87(T1).
3. **worktree 안의 정션:**
   - gitignored 정션(node_modules)이면 dirty 로 오판정되지 않아야 한다. 오판정되면 정상 정리가 멈춘다.
   - ignore 되지 않은 정션이면 보존되어야 하고, 정션 target 도 무사해야 한다.
   - 테스트: fixture `.gitignore` 로 T1/Ta/Tb 삭제 유지 확인 + Th(T3).
4. **`rate_limits` 가 없는 입력(API 키 인증·구버전·첫 응답 전):** 크래시 없이 `…` 로 렌더되어야 한다.
   - 테스트: statusline T4(T4).
5. **`resets_at` 이 ISO 문자열이거나 파싱할 수 없는 문자열인 경우:** ISO 는 파싱되어야 한다. 파싱 불가 값은 reset 접미사만 빠지고 필드 정렬이 유지되어야 한다.
   - 테스트: statusline T5·T5b(T4).

---

### Task 0: 작업 트리 이관

- [x] **Step 1:** 메인 트리의 미커밋 변경을 worktree 로 옮긴다(`cp -p`). worktree 는 base 가 HEAD 와 같다.
  - 대상은 SECURITY.md, spec 4건, `hooks/lib/model-window.js`, `hooks/tests/{cases.tsv,run-all.sh}`, plan 2건이다.
  - `.tpl` 은 제외한다.
  - 결과: `git diff --stat` 이 메인 트리와 worktree 에서 모두 `7 files changed, 124 insertions(+), 10 deletions(-)` 로 일치한다.
- [x] **Step 2:** 이후 모든 편집(spec 보정 포함)은 worktree 에서만 한다.
  - 메인 트리의 plan 사본은 이관 시점에 고정된다.
  - 활성 plan 게이트(`enforce-rpi-cycle`)는 파일의 git root 기준으로 plan 을 찾는다. 따라서 worktree 편집은 worktree 의 이 plan 이 연다.

### Task 1: Rule C3 — ocx-* 생성기-소유 패턴 면제 (heavy)

**Files:**
- Modify: `hooks/surface-model-policy.sh`(Rule C3 case, 107-114행)
- Modify: `setup/verify-setup.sh`(seal #47, 514-532행 — 505행은 #46)
- Modify: `setup/tests/seal-regression.test.sh`(Mutator 3개 추가 + assert 3줄)
- Modify: `hooks/tests/run-all.sh`(1181행 뒤) · `hooks/tests/cases.tsv`(234행 `26-rule-c2-floor-worker` 뒤)
- Modify: `README.md`(292·559행 305→307)
- Modify: `docs/ai-context/model-policy.md`(37행 Rule C3 제외 서술)
- (Phase R 에서 선반영) `CONTEXT.md`: "생성기-소유 패턴 면제" 용어 신설

**Interfaces:**
- hook 제외 arm 은 반드시 단독 행 `        ocx-*) ;;` 으로 둔다.
- seal #47 은 이 행을 정규식 `^[[:space:]]*ocx-\*\)[[:space:]]*;;` 로 찾는다.
- 변이는 이 행을 `sed '/^[[:space:]]*ocx-\*) ;;/d'` 로 지운다.

- [x] **Step 1: 실패 테스트 작성 + README 카운트 동기화.** `test_smp "26-rule-c2-floor-worker"` 행(run-all.sh 1181행) 뒤에 추가한다.

```bash
# 86/87 (C25 spec §22.1): opencodex 생성 래퍼 ocx-* 는 model 을 고정 선언 → C3 비대상. 패턴이 다른 무선언 스폰을 가리면 안 됨
WF_OCX="export const meta = {name: 'x', description: 'x'}
await agent('r', {agentType: 'ocx-gpt-6-sol'})"
WF_OCX_MIX="export const meta = {name: 'x', description: 'x'}
await agent('r', {agentType: 'ocx-gpt-6-sol'})
await agent('s', {agentType: 'general-purpose'})"
test_smp "86-rule-c3-ocx-generated-exempt" 0 0 "$(mk_wf_event script "$WF_OCX" "$SMP_FABLE_T" "smp86-$$")"
test_smp "87-rule-c3-ocx-no-mask" 0 1 "$(mk_wf_event script "$WF_OCX_MIX" "$SMP_FABLE_T" "smp87-$$")"
```

`cases.tsv` 234행(`surface-model-policy	26-rule-c2-floor-worker	0	mk_wf_event`) 뒤에 추가한다. 필드 구분자는 탭이다.

```
surface-model-policy	86-rule-c3-ocx-generated-exempt	0	mk_wf_event
surface-model-policy	87-rule-c3-ocx-no-mask	0	mk_wf_event
```

README.md 292행 `305 case` → `307 case`, 559행 `(305 케이스` → `(307 케이스`.
확인: `grep -vcE '^[[:space:]]*(#|$)' hooks/tests/cases.tsv` = 307.

- [x] **Step 2: seal-regression 변이 작성.** `mut_c3_exclude_drop` 정의(126행) 뒤에 추가한다.

```bash
# Mutator C25-a/b/c — seal #47 패턴 면제 (C25 spec §22.1): 라이브 디스크에 ocx 래퍼가 없어도 vacuous 가 되지 않게
# 변이가 직접 합성 래퍼를 심는다. a = 패턴 arm 삭제(생성 래퍼 미커버 drift), b = 마커 없는 ocx-*(전제 ① 위반),
# c = 마커는 있으나 model: inherit(전제 ② 위반).
mut_c3_ocx_pattern_drop() {
  printf -- '---\nname: "ocx-zz-synth"\nmodel: "ocx-claude-native--zz"\n---\n<!-- generated-by: opencodex -->\n' > "$1/agents/ocx-zz-synth.md"
  sed -i '/^[[:space:]]*ocx-\*) ;;/d' "$1/hooks/surface-model-policy.sh"
}
mut_c3_ocx_unmarked() { printf -- '---\nname: "ocx-zz-handmade"\nmodel: sonnet\n---\nhand-written\n' > "$1/agents/ocx-zz-handmade.md"; }
# c = 마커는 있으나 model: inherit (전제 ② 단독 위반)
mut_c3_ocx_marked_inherit() { printf -- '---\nname: "ocx-zz-inh"\nmodel: inherit\n---\n<!-- generated-by: opencodex -->\n' > "$1/agents/ocx-zz-inh.md"; }
```

`assert_seal_fires "c3_exclude_drop" …` 행(233행) 뒤에 추가한다.

```bash
assert_seal_fires "c3_ocx_pattern_drop" mut_c3_ocx_pattern_drop "Rule C3 제외목록 drift"
assert_seal_fires "c3_ocx_unmarked"     mut_c3_ocx_unmarked     "Rule C3 패턴 면제 전제 위반"
assert_seal_fires "c3_ocx_marked_inherit" mut_c3_ocx_marked_inherit "Rule C3 패턴 면제 전제 위반"
```

변이 b 가 `model: sonnet` 을 선언하는 이유가 있다. model 을 선언해도 마커가 없으면 FAIL 이어야 한다는 점을 고정하기 위해서다. `model: inherit` 는 더 쉬운 경우라 이 케이스가 포섭한다.

- [x] **Step 3: RED 확인(staged HOME).** 검증 하네스로 `restage` 후 실행한다.
  - `HOME="$STG" bash "$STG/.claude/hooks/tests/run-all.sh" 2>&1 | grep -E "86-|87-|Hook tests"` → 86 FAIL(ctx=1). 87 은 PASS(기존 동작).
  - `HOME="$STG" bash "$STG/.claude/setup/verify-setup.sh" 2>&1 | tail -3` → `PASS=90 FAIL=1`(#47 — live ocx 래퍼 4개 미등재). README 가 이미 307 이므로 #20 은 PASS.
  - `HOME="$STG" bash "$STG/.claude/setup/tests/seal-regression.test.sh" 2>&1 | grep -E "control|c3_ocx|PASS="`:
    - control: FAIL(#47)
    - `c3_ocx_unmarked`: FAIL(needle "Rule C3 패턴 면제 전제 위반" 부재)
    - `c3_ocx_marked_inherit`: FAIL(현 #47 은 inherit 을 건너뛰어 발화하지 않음)
    - `c3_ocx_pattern_drop`: 판정 무의미(arm 이 아직 없음)
- [x] **Step 4: hook 구현.** `hooks/surface-model-policy.sh` Rule C3 case 의 첫 arm 뒤에 삽입한다.

```bash
      case "$SP_TYPE" in
        explore-strict|execute-strict|review-strict|'*') ;;
        # 생성기-소유 패턴 면제 (C25 spec §22.1 = §13.3 ④): opencodex `ocx claude` 가 생성하는 ocx-<route> 래퍼는
        # frontmatter 에 프록시 라우트 model 을 고정 선언한다(세션 비상속). 로스터가 opencodex 업데이트마다 바뀌므로
        # (gpt-5.x→gpt-6 실측) 이름이 아니라 패턴으로 면제한다. 전제(생성기 마커+model 선언)는 seal #47 이 봉인.
        ocx-*) ;;
```

그 아래 `# ★C14 GPT 교차리뷰 정정` 주석과 `*)` arm 은 그대로 둔다.
같은 case 위 주석 블록의 `# 제외(3 사유): explore-strict=frontmatter model 선언 보유 / …` 는 **사유 수를 바꾸지 않고** 첫 사유에 인스턴스를 덧붙인다: `# 제외(3 사유): explore-strict=frontmatter model 선언 보유(ocx-* 생성 래퍼도 같은 사유 — 생성기-소유 패턴, C25 §22.1) / …`. ocx-* 는 ①축(model 선언 보유)의 패턴형이므로, 바로 아래 "①축은 seal #47 이 대조" 서술과도 맞는다.

- [x] **Step 5: seal #47 구현.** `verify-setup.sh` 의 `MISS47=""` 부터 #47 의 마지막 `fi` 까지를 다음으로 바꾼다.

```bash
MISS47=""; PRE47=""
SMP_HOOK="$HOME/.claude/hooks/surface-model-policy.sh"
OCX_ARM=0; grep -qE "^[[:space:]]*ocx-\*\)[[:space:]]*;;" "$SMP_HOOK" 2>/dev/null && OCX_ARM=1
for af in "$HOME/.claude/agents/"*.md; do
  [ -f "$af" ] || continue
  an=$(basename "$af" .md)
  am=$(grep -m1 -E '^model:' "$af" 2>/dev/null | sed -E 's/^model:[[:space:]]*//' | tr -d '\r"')
  # C25 §22.1: ocx-* 는 패턴 arm 으로 면제 — 단 opencodex 생성 래퍼(마커 + inherit 아닌 model 선언)만.
  # 전제가 깨진 ocx-* 는 이름 등재로도 면제되지 않는다(접두 자체가 생성기 전용).
  case "$an" in
    ocx-*)
      if grep -q '<!-- generated-by: opencodex -->' "$af" 2>/dev/null && [ -n "$am" ] && [ "$am" != "inherit" ]; then
        [ "$OCX_ARM" = "1" ] || MISS47="$MISS47 $an(ocx-* 패턴 arm 부재)"
      else
        PRE47="$PRE47 $an"
      fi
      continue ;;
  esac
  { [ -n "$am" ] && [ "$am" != "inherit" ]; } || continue
  # ★C14 GPT 교차리뷰 정정: 전문 grep 은 hook 의 설명 주석이 제외목록을 가린다 — **실효 case arm** 에서만 찾는다.
  grep -qE "^[[:space:]]*[a-z|'*-]*${an}[a-z|'*-]*\)[[:space:]]*;;" "$SMP_HOOK" 2>/dev/null || MISS47="$MISS47 $an"
done
if [ -z "$MISS47$PRE47" ]; then
  ok "Rule C3 제외목록 봉인: model 선언 wrapper 가 hook 제외 목록(이름 또는 ocx-* 생성기 패턴)에 등재됨"
else
  [ -n "$MISS47" ] && fail "Rule C3 제외목록 drift (C14-D): hook 미등재 —$MISS47. model 을 선언하는 wrapper 는 세션 상속이 아니므로 C3 제외 목록에 추가해야 함(spec §13.3)"
  [ -n "$PRE47" ] && fail "Rule C3 패턴 면제 전제 위반 (C25 §22.1): —$PRE47. ocx- 접두는 opencodex 생성 래퍼(generated-by 마커 + model 선언) 전용 — 손으로 쓴 에이전트는 이름을 바꿀 것"
fi
```

*(Closeout 정정: 착륙 코드의 `am=` 줄은 이 스니펫과 다르다 — `model:` 을 YAML frontmatter 안에서만 읽고, 1행 UTF-8 BOM 제거·구분자 `---` 뒤 공백 허용, 값은 CR → 뒤쪽 주석 → 앞뒤 공백 → 감싼 따옴표 순으로 정규화한다(슬롯 2 A1·A2, 10-03 델타 재심 BOM·공백 회귀). 현행 = `setup/verify-setup.sh` #47 · spec model-policy §22.1.)*

seal 번호 주석 블록 `# 47. …` 끝에 한 줄을 추가한다.
`#     C25: ocx-* 는 생성기-소유 패턴 arm 으로 커버하고, 그 전제(마커·model 선언)를 함께 검사한다(spec §22.1).`

**수용 잔여(기록만):** 두 결함이 겹치면 #47 이 fail 줄 2개를 낸다. 이때 verify-setup 의 "현재 N PASS" 카운트 봉인이 부수적으로 FAIL 한다. 두 결함이 동시에 발생하는 드문 경우라 수용한다.

- [x] **Step 6: 전파.** `docs/ai-context/model-policy.md` 37행의 `explore-strict 는 frontmatter sonnet 보유라 제외, C13·C14)` 를 `explore-strict 는 frontmatter sonnet 보유라 제외·opencodex 생성 `ocx-*` wrapper 는 생성기-소유 패턴으로 제외(전제=생성기 마커+model 선언, seal #47 — C25 §22.1), C13·C14)` 로 바꾼다.
- [x] **Step 7: GREEN 확인(staged HOME).** `restage` 후 실행한다.
  - verify-setup → `PASS=91 FAIL=0`
  - seal-regression → 새 변이 3건 포함 `FAIL=0`
  - run-all → 86/87 PASS

**결과(T1):** RED — staged verify-setup `PASS=90 FAIL=1`(#47 만) · run-all 306/307(86 만 FAIL, ctx=1) · seal-regression control FAIL·`c3_ocx_unmarked` needle 부재 FAIL(pattern_drop 은 arm 부재 상태라 무의미 발화). GREEN — staged verify-setup `PASS=91 FAIL=0`. 전체 스위트 GREEN 은 Task 7 에 기록.

### Task 2: model-window 세대 규칙 회귀 케이스 (light)

**Files:**
- `hooks/lib/model-window.js`: 세대 규칙. Task 0 에서 이관 완료.
- `hooks/tests/run-all.sh`: 771행 `121-modelwin-fable` 뒤.
- `hooks/tests/cases.tsv`: 93행 뒤.
- `README.md`: 307 → 309.

- [x] **Step 1: 케이스 추가 + README 카운트.** run-all 771행 `test_lib "121-modelwin-fable" …` 뒤에 추가한다.

```bash
# C25 spec §22.2: 세대 규칙 영구 회귀 — Opus 5.5(사용자 결정) + 규칙이 200K→1M 으로 뒤집은 Sonnet 4.6 양성
test_lib "212-modelwin-opus55"   "1000000" "$(node "$LIB/model-window.js" claude-opus-5-5)"
test_lib "213-modelwin-sonnet46" "1000000" "$(node "$LIB/model-window.js" claude-sonnet-4-6)"
```

cases.tsv 93행(`hooks-lib	121-modelwin-fable	output	gen_lib_121`) 뒤에 추가한다.

```
hooks-lib	212-modelwin-opus55	output	gen_lib_212
hooks-lib	213-modelwin-sonnet46	output	gen_lib_213
```

README.md 292행 `307 case` → `309 case`, 559행 `(307 케이스` → `(309 케이스`.
확인: `grep -vcE '^[[:space:]]*(#|$)' hooks/tests/cases.tsv` = 309.

- [x] **Step 2: RED 확인(HEAD 규칙 대상).** 다음을 실행한다.
  ```
  git -C "$WT" show HEAD:hooks/lib/model-window.js > "$STG/mw-head.js"
  node "$STG/mw-head.js" claude-opus-5-5
  node "$STG/mw-head.js" claude-sonnet-4-6
  ```
  기대값: 둘 다 `200000`. 구 규칙은 두 케이스 모두 FAIL 이다.
- [x] **Step 3: GREEN(staged HOME).** `restage` 후 확인한다.
  - `node "$WT/hooks/lib/model-window.js" claude-opus-5-5` → `1000000`
  - `HOME="$STG" bash "$STG/.claude/hooks/tests/run-all.sh"` → 212/213 PASS
  - staged verify-setup 에서 #20 PASS

**결과(T2):** RED — HEAD 규칙 `200000 200000` · GREEN — worktree 규칙 `1000000 1000000`, cases.tsv 309.

### Task 3: worktree-teardown 미커밋 가드 (heavy)

**Files:**
- `hooks/worktree-teardown.sh`: GUARD 5 블록의 `fi` 뒤, `BRANCH=$(git …` 앞. 머리 주석 7-8행도 수정.
- `hooks/tests/worktree-teardown.test.sh`
- `SECURITY.md`: `worktree-teardown` 안전 모델 절.
- `README.md`: 43행 hook 표.
- (Phase R 에서 선반영) `CONTEXT.md`: worktree teardown 항목에 GUARD 6.

- [x] **Step 1: fixture 현실화 + 실패 테스트 작성.**
  - fixture repo 초기 커밋에 `.gitignore`(`node_modules`)를 넣는다. 24행 `( cd "$REPO" && git init -q && …commit --allow-empty… )` 을 다음으로 바꾼다.

```bash
( cd "$REPO" && git init -q && printf 'node_modules\n' > .gitignore && git add .gitignore \
  && git -c user.email=t@t -c user.name=t commit -q -m init )
```

  - `make_worktree` 의 `mkdir -p …; echo "own" >…own.txt` 행 뒤에 추가한다. 작업 결과는 커밋돼 있다는 현실적 가정이다.

```bash
  git -C "$WT" add app/frontend/src/own.txt && git -C "$WT" -c user.email=t@t -c user.name=t commit -q -m own
```

  - `echo "== Td:` 행 앞에 추가한다.

```bash
RL="$TMP/runlog"; mkdir -p "$RL"   # 이 블록의 hook 사유 로그(격리 — 실 runlog 오염 없음)
echo "== Tf: 미커밋 작업(추적 수정 + 미추적 파일) → 보존 — 식별 무관 불변식(§12, 2026-09-28 사고 재현: reason=other·cwd=워크트리·마커 없음) =="
make_worktree
echo "edit" >> "$WT/app/frontend/src/own.txt"; echo "new" > "$WT/app/frontend/src/new.txt"
printf '{"session_id":"wtjtest_f_%s","cwd":"%s","reason":"other"}' "$$" "$WT" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
{ [ -f "$WT/app/frontend/src/new.txt" ] && grep -q edit "$WT/app/frontend/src/own.txt"; } && ok "Tf: dirty 워크트리 보존(수정+미추적 유지)" || no "Tf: ★DATA LOSS — dirty 워크트리 삭제됨"
[ -n "$(git -C "$REPO" branch --list worktree-cycle-_test)" ] && ok "Tf: 브랜치 보존" || no "Tf: 브랜치 삭제됨"
grep -q 'noop:dirty-worktree' "$RL"/*.jsonl 2>/dev/null && ok "Tf: 사유 noop:dirty-worktree 기록" || no "Tf: dirty 사유 미기록"

echo "== Tg: 같은 dirty 워크트리를 자기 마커(§9 fallback)로 도달 → 역시 보존, 마커 소비; clean 복귀 후 정상 삭제 =="
G_SID="wtjtest_g_$$"; mkdir -p "$MK_DIR"; printf '%s\n' "$WT" > "$MK_DIR/$G_SID"
printf '{"session_id":"%s","cwd":"%s","reason":"prompt_input_exit"}' "$G_SID" "$REPO" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
[ -f "$WT/app/frontend/src/new.txt" ] && ok "Tg: 마커 경로로도 dirty 보존" || no "Tg: ★DATA LOSS — 마커 경로에서 삭제됨"
[ ! -f "$MK_DIR/$G_SID" ] && ok "Tg: 마커 소비" || no "Tg: 마커 미소비"
git -C "$WT" checkout -q -- . ; rm -f "$WT/app/frontend/src/new.txt"
printf '{"session_id":"wtjcleanup_g_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
[ ! -e "$WT" ] && ok "Tg: clean 복귀 후 정상 삭제(clean 경로 무회귀)" || no "Tg: clean 인데 미삭제"

echo "== Th: ignore 되지 않은 정션(미추적)만 있는 워크트리 → 보존 + 정션 target 무사 =="
make_worktree
powershell -NoProfile -Command "New-Item -ItemType Junction -Path '$(winpath "$WT/app/frontend/vendorlink")' -Target '$(winpath "$MAIN_NM")' | Out-Null" >/dev/null 2>&1
printf '{"session_id":"wtjtest_h_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
[ -d "$WT/app/frontend/vendorlink" ] && ok "Th: 미추적 정션 워크트리 보존" || no "Th: 미추적 정션 워크트리 삭제됨"
[ "$(ls -1 "$MAIN_NM" 2>/dev/null | wc -l | tr -d ' ')" = "$TARGET_BEFORE" ] && ok "Th: 정션 target(main) 무사" || no "Th: ★DATA LOSS — 정션 target 손상"
powershell -NoProfile -Command "[IO.Directory]::Delete('$(winpath "$WT/app/frontend/vendorlink")', \$false)" >/dev/null 2>&1   # 링크-only 제거 → clean
printf '{"session_id":"wtjcleanup_h_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1

echo "== Ti: git status 실패(손상 index) → 보존 + noop:status-failed (fail-safe) =="
make_worktree
IDX="$(git -C "$WT" rev-parse --absolute-git-dir)/index"; printf 'corrupt' > "$IDX"
printf '{"session_id":"wtjtest_i_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | RUNLOG_DIR="$RL" bash "$HOOK" >/dev/null 2>&1
[ -d "$WT" ] && ok "Ti: status 실패 워크트리 보존" || no "Ti: status 실패인데 삭제됨"
grep -q 'noop:status-failed' "$RL"/*.jsonl 2>/dev/null && ok "Ti: 사유 noop:status-failed 기록" || no "Ti: status-failed 사유 미기록"
rm -f "$IDX"; git -C "$WT" reset -q 2>/dev/null   # index 재생성 → clean
printf '{"session_id":"wtjcleanup_i_%s","cwd":"%s","reason":"prompt_input_exit"}' "$$" "$WT" | bash "$HOOK" >/dev/null 2>&1
```

  - 머리 주석의 테스트 목록에 한 줄을 추가한다: `#   Tf/Tg/Th/Ti(cycle-76) 미커밋·미추적 정션·status 실패 → 보존(GUARD 6), clean 복귀 시 정상 삭제`.
- [x] **Step 2: RED 확인(staged HOME).** `restage` 후 `HOME="$STG" bash "$STG/.claude/hooks/tests/worktree-teardown.test.sh" 2>&1 | tail -20` 을 실행한다.
  - 기대: Tf·Tg·Th·Ti 의 **보존 단언과 사유 단언**이 FAIL 이다. 현 훅은 이 경우들을 지우기 때문이다. Tf 가 워크트리를 지우면 Tg 는 연쇄로 실패한다. Gate 재심 실측: RED `PASS=28 FAIL=7` — Tf 3건이 모두 FAIL 이다. 브랜치 삭제(STEP D)에는 reason 조건이 없다. §12.1 사고의 branch-skip 은 cwd 잠금으로 rm_ok=0 이었기 때문이다.
  - 기존 T1·Ta·Tb·Tc·Te 는 PASS 를 유지한다. fixture 가 clean 이기 때문이다.
- [x] **Step 3: 가드 구현.** `hooks/worktree-teardown.sh` GUARD 5 블록의 `fi` 뒤, `BRANCH=$(git -C "$WT_ROOT" rev-parse --abbrev-ref HEAD …` 앞에 넣는다. 이 위치는 모든 파괴 단계(STEP A kill 포함)보다 앞이다.

```bash
# GUARD 6 (cycle-76, spec §12): 미커밋 작업이 있는 워크트리는 지우지 않는다 — 식별 경로(cwd/마커) 무관 불변식.
#  2026-09-28 사고: 워크트리 안에서 띄운 headless 자식 `claude -p` 의 SessionEnd(reason=other, cwd=워크트리, 부모 마커 없음)가
#  부모 세션의 활성 워크트리를 삭제. ignored 파일(node_modules 등)은 dirty 로 세지 않는다. status 실패 = dirty(fail-safe).
#  leftover ≠ data loss (C5 와 같은 편향).
_WT_ST=$(git -C "$WT_ROOT" status --porcelain --untracked-files=normal 2>/dev/null); _WT_RC=$?
if [ "$_WT_RC" -ne 0 ]; then
  hook_log "worktree-teardown" "$WT_ROOT" "PASS" "noop:status-failed rc=$_WT_RC"; exit 0
fi
if [ -n "$_WT_ST" ]; then
  hook_log "worktree-teardown" "$WT_ROOT" "PASS" "noop:dirty-worktree n=$(printf '%s\n' "$_WT_ST" | wc -l | tr -d ' ')"; exit 0
fi
```

  *(Closeout 정정: 착륙 코드는 이 스니펫이 아니라 판정 함수 `wt_keep_reason()` 이다 — status 에 `--ignore-submodules=none`, `ls-files -v` 의 assume-unchanged/skip-worktree 검사(`noop:hidden-index-flags`·`noop:ls-files-failed`), 같은 판정의 `rm` 직전 재검사(`noop:dirty-recheck`)를 더했다(슬롯 2 B2·F1). 현행 = `hooks/worktree-teardown.sh` · spec teardown §12.3.)*

  - 머리 주석의 안전 불변식(7-8행) 끝에 `+ 미커밋 작업(ignored 제외)이 없을 때만(GUARD 6, cycle-76)` 을 덧붙인다.
- [x] **Step 4: 전파.**
  - `SECURITY.md` "`worktree-teardown` 안전 모델" 절, `**데이터손실 0 다중방어**` 목록 끝에 추가한다:
    `  - **미커밋 보존(GUARD 6, cycle-76)**: 식별 경로(cwd·마커)와 무관하게 `git status --porcelain` 이 비어 있지 않거나(미커밋 수정·ignore 안 된 미추적 파일·정션) status 가 실패하면 삭제하지 않는다. 계기=워크트리 안에서 띄운 headless 자식 세션의 SessionEnd 가 부모 워크트리를 지운 라이브 사고(2026-09-28). 수용 잔여: ignore 된 비-재생성 파일(로컬 .env 등)은 clean 워크트리 삭제 시 여전히 소실.`
    *(Closeout 정정: 이 문안은 GUARD 6 보강(index 플래그·서브모듈·재검사)과 수용 잔여 (a)~(f) 로 대체됐다 — 현행 = SECURITY.md teardown 절.)*
  - 같은 절 "검증" 줄의 `(13/13)` 을 실측 수로 갱신하고, 목록에 `미커밋·미추적 정션·status 실패 보존` 을 추가한다.
  - `README.md` 43행 `worktree-teardown` 행의 가드 서술 `가드(마커·sanity·linked-worktree 증명)로` 를 `가드(마커·sanity·linked-worktree 증명·미커밋 보존)로` 로 바꾼다.
- [x] **Step 5: GREEN(staged HOME).** `restage` 후 `HOME="$STG" bash "$STG/.claude/hooks/tests/worktree-teardown.test.sh"` → `PASS=35 FAIL=0`.
  - 산식: 기존 25 + Tf 3 + Tg 3 + Th 2 + Ti 2 = 35.
  - 기존 25 는 2026-09-29 live 실측값(`PASS=25 FAIL=0`)이다.
  - run-all 무회귀.

**결과(T3):** staged E2E RED `PASS=28 FAIL=7`(Tf 3·Tg 1·Th 1·Ti 2) → GREEN `PASS=35 FAIL=0`.

### Task 4: statusline v3 — native rate_limits (heavy; `statusline` skill 경유)

**Files:** `statusline.sh` · `tests/statusline/run-tests.sh` · `skills/statusline/SKILL.md`(10·36-42·50·67행)

- [x] **Step 1: `statusline` skill 호출.** Phase 1 컨텍스트 로드 단계다. 1KB 예산과 FLOOR 표를 확인한다.
- [x] **Step 2: 실패 테스트 작성.** `run-tests.sh` 를 다음과 같이 바꾼다.
  - 머리 주석의 격리 설명을 v3 로 교체한다: "stdin `rate_limits` 픽스처 주입 — 캐시·토큰·네트워크 없음".
  - `seed_caches` 를 삭제하고 `with_limits` 를 추가한다. `run()` 이 절대경로 픽스처도 받게 한다.

```bash
run() { # run <fixture-file|abs-path> <fake-home>   -> stdout (ANSI-stripped)
  local f="$1"; [ -f "$f" ] || f="$FX/$1"
  HOME="$2" USERPROFILE="$2" TMPDIR="$2" bash "$SL" <"$f" 2>/dev/null | strip
}

with_limits() { # with_limits <fixture> <u5> <u7> [iso|junk] -> writes $d/in.json (needs $d); 5h reset +3h30m, 7d +24h
  local now r5 r7; printf -v now '%(%s)T' -1; r5=$(( now + 12630 )); r7=$(( now + 86400 ))
  case "${4:-}" in
    iso)  jq --argjson u5 "$2" --argjson u7 "$3" --argjson r5 "$r5" --argjson r7 "$r7" \
            '. + {rate_limits:{five_hour:{used_percentage:$u5,resets_at:($r5|todate)},seven_day:{used_percentage:$u7,resets_at:($r7|todate)}}}' "$FX/$1" >"$d/in.json" ;;
    junk) jq --argjson u5 "$2" --argjson u7 "$3" --argjson r7 "$r7" \
            '. + {rate_limits:{five_hour:{used_percentage:$u5,resets_at:"not-a-date"},seven_day:{used_percentage:$u7,resets_at:$r7}}}' "$FX/$1" >"$d/in.json" ;;
    *)    jq --argjson u5 "$2" --argjson u7 "$3" --argjson r5 "$r5" --argjson r7 "$r7" \
            '. + {rate_limits:{five_hour:{used_percentage:$u5,resets_at:$r5},seven_day:{used_percentage:$u7,resets_at:$r7}}}' "$FX/$1" >"$d/in.json" ;;
  esac
}
```

  - **T1:** `d=$(mktemp -d); with_limits base-fable.json 25 26; out=$(run "$d/in.json" "$d")`.
    - 계정별 단언 3개(biz/indie 2줄 + 7d 합본)와 "T1 not stale" 를 다음으로 바꾼다.
      - `check "T1 5h bar + inline reset" "$out" '5H Limit [█░]+ 25% \(3h(29|30)m\)'`
      - `check "T1 7d bar + date/hour" "$out" '7D Limit [█░]+ 26% \([0-9]{1,2}/[0-9]{1,2} [0-9]{1,2}(am|pm)\)'`
      - `check "T1 no account tags" "$(grep -cE 'biz|indie' <<<"$out")" '^0$'`
    - `rawbytes` 도 `$d/in.json` 입력으로 잰다: `bash "$SL" <"$d/in.json"`.
  - **T2/T3/T6/T7:** `seed_caches "$d" 5` 호출만 삭제한다. 단언은 바꾸지 않는다.
  - **T4(누락):** 원본 `base-fable.json`(rate_limits 없음)으로 확인한다. `T4 no stale marker on empty` 는 유지한다. *(Closeout 정정: v3 에서 stale 로직이 사라져 이 단언은 공허해졌으므로 삭제했다 — 통합 리뷰 M3.)*
    - `check "T4 5h placeholder" "$out" '5H Limit …'`
    - `check "T4 7d placeholder" "$out" '7D Limit …'`
    - 5줄 유지
  - **T5(교체 — stale 폐지):** `d=$(mktemp -d); with_limits base-fable.json 25 26 iso; out=$(run "$d/in.json" "$d")` → `check "T5 ISO resets_at parsed" "$out" '5H Limit [█░]+ 25% \(3h(29|30)m\)'`.
  - **T5b(신규):** `with_limits base-fable.json 25 26 junk` 로 두 가지를 확인한다.
    - `check "T5b unparseable reset -> bar kept, no suffix" "$out" '5H Limit [█░]+ 25%$'`
    - `check "T5b 7d unaffected" "$out" '7D Limit [█░]+ 26% \('`
  - **T8(신규):** `check "T8 no credential read / network" "$(grep -cE 'curl|\.ccs|access_token' "$SL")" '^0$'`. *(Closeout 정정: 패턴을 `curl|wget|fetch|https?://|/dev/tcp|Invoke-WebRequest|\.ccs|auth\.json|credentials|access_token|\.codex/|\.opencodex/` 로 넓히고 주석 줄을 제외했다 — 슬롯 2 C6. 대표 패턴 봉인이지 전수 증명은 아니다.)*
- [x] **Step 3: RED.** `SL="$WT/statusline.sh" bash "$WT/tests/statusline/run-tests.sh"` → T1 새 단언 · T4 · T5 · T5b · T8 FAIL.
- [x] **Step 4: 구현(`statusline.sh`).**
  - 머리 주석
    - L4/L5 줄을 `L4/L5 Claude 5h/7d rate limits from Claude Code's own stdin rate_limits (v3, spec v3 2026-09-28)` 로 바꾼다.
    - Constraints 줄의 `usage fetched by a detached bg subshell (…)` 를 삭제한다.
  - 삭제
    - config 블록: `ACCTS`·`AUTH_DIR`·`USAGE_TTL/STALE_AT/LOCK`. `TMP` 는 git 캐시가 쓰므로 유지한다.
    - `BC/IC` 캐시 준비 3줄
    - background refresh 블록 전체
    - `STALE` 계산과 `acct_seg`
  - jq
    - `age`·`acct` 정의를 삭제하고 다음을 넣는다. `limit` 은 jq 내장 이름이라 쓰지 않는다. `[epoch][0] // null` 은 파싱할 수 없는 문자열이 빈 스트림이 되어 필드가 밀리는 것을 막는다.

```jq
def epoch: if type == "number" then . elif type == "string" then parsedate else null end;
def rlim($w; fmt): ((.rate_limits // {})[$w] // {}) as $x
  | [ ($x.used_percentage // -1 | floor),
      (([$x.resets_at // null | if . == null then null else epoch end][0] // null) as $r
        | if $r then ($r | fmt) else "" end) ];
```

    - 배열 끝의 `+ acct($B) + acct($I)` 와 `+ [ (if (age($B) …) ]` 두 줄을 `+ rlim("five_hour"; (. - $now) | relfmt) + rlim("seven_day"; datefmt)` 로 바꾼다.
    - jq 주석의 `stdin fields + both usage caches` 를 `stdin fields incl. rate_limits` 로 바꾼다.
  - `read` 행
    - 변수 목록을 `… ADDED REMOVED R5 R5R R7 R7R` 로 바꾼다.
    - jq 호출에서 `--slurpfile B "$BC" --slurpfile I "$IC"` 를 제거한다.
  - 렌더(`# ---------- L4/L5` 블록 전체 교체):

```bash
# ---------- L4/L5: Claude rate limits (stdin rate_limits — v3) ----------
lim_seg() { # lim_seg <util> <reset> -> $SEG
  local u=$1 rst=$2
  if [ "${u:--1}" -lt 0 ] 2>/dev/null; then SEG="${D}…${R}"
  else mkbar "$u" 8 50 80; SEG="${BAR} ${u}%"; [ -n "$rst" ] && SEG+=" ${D}(${rst})${R}"; fi
}
lim_seg "$R5" "$R5R"; L4="🕐 ${B}5H Limit${R} $SEG"
lim_seg "$R7" "$R7R"; L5="📅 ${B}7D Limit${R} $SEG"
```

- [x] **Step 5: GREEN + 바이트 감사.**
  - `SL="$WT/statusline.sh" bash "$WT/tests/statusline/run-tests.sh"` → `fail=0`.
  - `d=$(mktemp -d); now=$(date +%s); jq --argjson r5 $((now+12630)) --argjson r7 $((now+86400)) '. + {rate_limits:{five_hour:{used_percentage:25,resets_at:$r5},seven_day:{used_percentage:26,resets_at:$r7}}}' "$WT/tests/statusline/fixtures/base-fable.json" > "$d/in.json"`
  - `bash "$WT/statusline.sh" < "$d/in.json" | LC_ALL=C wc -c` → ≤1000.
  - 실행 시간(`time`)은 ≤1s 여야 한다. 백그라운드 서브셸이 없으므로 이전보다 빠르거나 같아야 한다.
- [x] **Step 6: skill 갱신.** `skills/statusline/SKILL.md` 를 v3 로 교체한다.
  - 10행 description: `OAuth usage API, 토큰 read-only` → `stdin rate_limits 계약`.
  - 36-42행 하드 제약
    - usage API 계약과 토큰 read-only 두 항목을 **"rate_limits 계약"** 한 항목으로 바꾼다: `stdin .rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}`, resets_at 은 epoch 초 또는 ISO. 없으면 `…`. 자격증명 읽기·네트워크 호출 0 — 추가 금지. *(Closeout 정정: `used_percentage` 부재 → `…`, `resets_at` 만 부재/파싱 불가 → 막대 유지·접미사만 생략(슬롯 2 A5). T8 은 대표 패턴 봉인 — 전수 증명 아님(C6).)*
    - 포그라운드 비용 항목에서 `usage는 60s 캐시 + mkdir-lock 백그라운드 refresh` 를 삭제한다.
  - 50행 복원 절차: `+ jq/curl 존재 확인. CCS 계정 구성이 다르면 … ACCTS 배열만 수정.` → `+ jq 존재 확인.`
  - 67행 Phase 3 검증 기준: `토큰 read-only·60s 캐시 구조` → `자격증명·네트워크 0(T8)·rate_limits 부재 시 placeholder`. *(Closeout 정정: 착륙 문구는 T8 을 "대표 패턴 봉인"으로 한정한다 — C6.)*
  - 확인
    - `grep -nE 'usage API|oauth/usage|access_token|ACCTS|60s 캐시|curl' skills/statusline/SKILL.md` → 0건
    - opencode 미러 존재 여부: `ls opencode-harness/skill | grep -i statusline`(2026-09-28 실측 0건 — 미러 없음)

**결과(T4):** RED `pass=24 fail=9` → GREEN `pass=33 fail=0` · 바이트 458(≤1000) · 실행 0.5s · SKILL.md 금지어 grep 0 · opencode 미러 없음.

### Task 5: CCS 퇴역 문서 정리 (light)

**Files:**
- `docs/ai-context/cross-family-review.md`
- `docs/ai-context/ade-cutover-handoff.md`
- `opencode-harness/_oracle/oc-test.sh`
- `opencode-harness/README.md`(19행)
- `opencode-harness/MIGRATION-VERIFICATION.md`(75·147행)
- `SECURITY.md`(durable 기록 확인)

- [x] **Step 1: cross-family-review.md.**
  - 경로 A 줄에 현행 사실을 덧붙인다(2026-09-28 실측).
    - codex CLI 의 백엔드는 opencodex(`127.0.0.1:10100`)다.
    - `ws 426 Upgrade Required` 후 HTTP 폴백은 정상이다.
    - 스모크 결과는 `OK`.
    - canonical `-m gpt-5.6-sol` 이 opencodex 에서 여전히 수용되는지 **worktree 밖 cwd 에서** 1회 실측한다: `echo probe | codex exec -m gpt-5.6-sol --sandbox read-only --skip-git-repo-check "Reply: OK"`. 결과(수용 또는 거부와 대체 모델)를 적는다.
  - SKIP 모드 ⓒ 를 "(CCS 시절) 로컬 cliproxy / (현행) opencodex 계정 풀 고갈"로 정정한다.
  - 경로 B 에 경고를 추가한다.
    - opencodex 2.69.0 에서 thinking 이 켜진 `claude -p` 는 `reasoning.summary='none'` 400 으로 실패한다(업스트림 `src/claude/inbound.ts:516`).
    - `MAX_THINKING_TOKENS=0` 은 effort 가 none 이 되어 리뷰 품질이 떨어진다. 따라서 **경로 A 를 쓴다.**
    - 경로 B 는 **worktree 밖 cwd 에서만** 실행한다(자식 SessionEnd → teardown).
- [x] **Step 2: ade-cutover-handoff.md.**
  - 머리에 배너를 단다: "⚠ 역사 문서(2026-09-28 CCS 퇴역) — §4 'CCS 는 아직 제거하지 않는다'와 §5 롤백(8317 생존 전제)은 무효. 현 상태 = SECURITY.md 네트워크 절 · 메모리 `project_ccs_routing.md`(롤백은 거기 절차)."
  - §4·§5 제목 아래에 같은 취지를 한 줄씩 적는다.
- [x] **Step 3: oc-test.sh.**
  - 치환
    - baseURL `http://127.0.0.1:8317/v1` → `http://127.0.0.1:10100/v1`
    - apiKey `ccs-internal-managed` → `ocx-bridge`
    - 머리 주석 "CCS proxy" → "opencodex proxy(127.0.0.1:10100, Anthropic 호환 — 2026-09-28 실측 `claude-sonnet-4-6`·`gpt-6-sol` 응답)"
    - `opencode-harness/README.md` 19행과 `MIGRATION-VERIFICATION.md` 75·147행: "CCS proxy backend" → "opencodex proxy backend"
  - 확인
    - `grep -rn '8317\|ccs-internal-managed' opencode-harness/_oracle/oc-test.sh opencode-harness/README.md` → 0건
    - 라이브 1회(**worktree 밖 cwd**, opencode 설치 시): `bash "$WT/opencode-harness/_oracle/oc-test.sh" "say hello"` → 응답. opencode 가 없으면 SKIP 하고 사유를 기록한다.
- [x] **Step 4: durable 기록 확인.** `SECURITY.md` 31-33행(Task 0 이관분)이 현행 통신과 CCS 종료를 적고 있는지 확인한다. 현행 통신은 네이티브 Anthropic + opencodex loopback 서비스다. 부족하면 한 줄 보강한다.

**결과(T5):** 경로 A canonical `-m gpt-5.6-sol` 실측 `OK`(codex-cli 0.158.0, opencodex 경유, ws 426→HTTP 폴백) · oc-test 라이브 `HELLO-OC` rc=0(opencode 1.17.11 → opencodex, claude-sonnet-4-6) · oc-test/README 8317·ccs-internal-managed grep 0 · SECURITY.md 네트워크 절에 statusline v3·경로 A 경유 2줄 보강.

### Task 6: 플러그인 핀 갱신 (light)

**Files:** `docs/ai-context/plugin-pins.md`

- [x] **Step 1: 판정 수령 — LEGIT-UPDATE.** explore-strict(opus)가 superpowers 6.3.0↔6.4.1 보안 표면 diff 와 릴리스 노트를 리뷰했다.
  - 보안 표면 변화는 0 이다.
    - hooks.json 은 동일하다.
    - 신규 스크립트는 자기 작업공간 쓰기만 한다.
    - 네트워크·자격증명 접근과 프롬프트 인젝션은 없다.
    - `gh issue create` 는 승인 게이트 뒤에 있다.
  - 행동 변화가 있다. executing-plans 가 task 사이에 확인 없이 연속 실행하도록 바뀌어, Phase I (b) 에 영향이 있다. 사이클 보고에 표면화한다.
  - 한계
    - 6.2.0 캐시가 이미 없어서 6.2.0→6.3.0 구간은 릴리스 노트로만 재구성했다.
    - context7·playwright 는 SKILL.md 가 없다.
    - skill-creator 는 캐시 3개 디렉터리가 byte 동일하다.
- [x] **Step 2: 갱신.**
  - 표를 다음 값으로 바꾼다.
    - superpowers: `6.4.1` / `5bf4e78011075bcfc0dc295f0724994cd123ee71`
    - context7·skill-creator·playwright: `fa59bc903774` / `fa59bc9037741ecfa131aa27938272605710d7b2`
    - claude-md-management: 불변
  - `skill-cksum: 252811375` · `skill-count: 33` 으로 바꾼다. 갱신 직전에 `find "$HOME/.claude/plugins/cache/claude-plugins-official" -name SKILL.md | sort | xargs cat | cksum` 로 재실측한다.
  - 갱신 이력 주석을 1개 추가한다. 내용은 판정 근거 요약, 행동 변화, 한계, 그리고 **명명 특성 재관찰**이다.
    - 명명 특성 재관찰: `fa59bc9…` 와 `5bf4e78…` 는 이 하네스 repo 에 **없는 객체**다(`git cat-file -t` 실패). 따라서 07-17 에 세운 "캐시 버전명 = 로컬 하네스 커밋 sha" 관찰은 이번에 성립하지 않는다. cksum 이 유일한 실검증이라는 결론은 불변이다. *(Closeout 정정: 과잉 일반화였다. 같은 캐시에 하네스 커밋명 dir `1ec99123d23a` 도 공존하므로 "명명 원천이 혼재한다"가 정확하다 — 통합 리뷰 M5, plugin-pins 이력 주석도 정정.)*
- [x] **Step 3: 확인.**
  - staged verify-setup 에서 seal #40 PASS.
  - session-start-audit 의 드리프트 ALERT 가 사라지는지는 머지 후 메인 트리 기준으로 다음 세션에서 확인한다. 사이클 보고에 기록한다.

**결과(T6):** staged verify-setup `PASS=91 FAIL=0`(#40 `plugin-pins SKILL.md cksum 핀 존재` ✓) · session-start-audit 판정식(129-131행)을 그대로 재현하면 핀 `252811375` == 현재 캐시 `252811375` → 머지 후 드리프트 ALERT 소멸 예상. 실제 소멸은 다음 세션 SessionStart 에서 확인한다.

**재판정(2026-10-03, Closeout 중):** 위 예상은 머지 전에 깨졌다 — 09-30T11:36Z 마켓플레이스가 context7·skill-creator·playwright 를 `fa59bc903774`→`2a8ad9f74633` 으로 교체해 라이브 캐시가 `413615869`/34 가 됐다. `diff -rq` 3/3 콘텐츠 차이 0(캐시 장부 파일만)·skill-creator SKILL.md `cmp` 동일 → byte-동일 사본 1개가 전량 해시에 추가된 것뿐이므로 정당 판정, 핀을 `413615869`/34 로 갱신(이력 주석 동반). 고아 dir 이 정리되면 한 번 더 드리프트가 뜬다(이력 주석에 예고).

### Task 7: Closeout

- [x] **Step 1: 전체 검증(staged HOME, 최종 restage 후).**
  - verify-setup `FAIL=0`
  - seal-regression full `FAIL=0`
  - run-all 전체 PASS(309)
  - teardown E2E 35/0
  - statusline 스위트 fail=0
  - verify-all

  **결과(T7 S1):** 최종 restage 후 staged `verify-all.sh` **ALL PASS, RC=0**.
  - doctor 40/0 · WARN 1 은 staged 사본이 git repo 가 아니어서 나는 경고다.
  - verify-setup **91/0**.
  - seal-regression **34/0**. 새 뮤테이터 3종이 모두 발화했고 live witness cksum 은 불변이다.
  - failopen 5/0 · rpi-prereq 3/0 · orca-carrier 34/0.
  - run-all **309/309** · teardown E2E **35/0** · integration 8/0.
  - statusline `pass=33 fail=0` · base-fable 337 bytes.
  - RED 대조: seal-regression 구현 전 스냅샷은 `PASS=31 FAIL=3` 이다(control 과 `c3_ocx_unmarked`·`c3_ocx_marked_inherit` 의 needle 부재).
  - (주의) 첫 verify-all 은 사이클 라벨 정정(C76→C25, 주석·메시지 문자열만) 때문에 중단하고 다시 돌렸다. 중단한 실행의 고아 프로세스가 같은 로그에 `MUTATED` 줄을 남겼지만, 그 줄은 NUL 구간 뒤에 섞인 옛 출력이었다. 최종 로그는 NUL 0 바이트이고 seal-regression 요약이 1회만 나온다.
- [x] **Step 2: 커밋 → PR → closeout-pr-cycle 통합 리뷰.** 통합 리뷰는 senior+drift 이고, 교차패밀리 슬롯 2(경로 A, worktree 밖 cwd)를 함께 돈다.

  **진행(T7 S2):** 커밋 `6711cfb` → PR #44 → 통합 리뷰(senior+drift, review-strict opus) PASS · Critical 0 · Important 4 · Minor 8 → 교차패밀리 슬롯 2(경로 A `gpt-5.6-sol`) 17건 → 메인 2단계 트리아지 **REAL 16 · 기각 1**(C1: 뮤테이터 집합 단위 판별력 성립, RED 31/3) + 내부 I3(수용 잔여·차기 후보)·I4·M3~M8 → 정정-위임 미니-사이클(그룹 S·T·L, execute-strict opus) → 델타 재심.
  - 미완료 사유(I4, 해소): 델타 재심 PASS 전에는 체크하지 않았다 — 2회차 PASS(2026-10-03)로 체크.
  - 2026-10-03 재개(직전 세션 강제 종료): 미커밋 정정을 되돌리지 않고 메인이 마무리했다 — 전파 누락 3곳(CONTEXT.md GUARD 6 서술·statusline SKILL.md `resets_at` 부재 동작·MIGRATION-VERIFICATION.md 프록시 서술), 정정이 만든 회귀 1건(seal #47 frontmatter 파싱이 BOM 1행 파일을 건너뜀 → BOM 제거 + 뮤테이터 `c3_bom_model`; RED = BOM 래퍼 심고 `PASS=91 FAIL=0`, GREEN = `FAIL=1` 제외목록 drift 발화), 수용 잔여 (f) 서술 정정(파일 링크는 `abort-rm` 경로; 코드 판독 근거·E2E 불가 명시)과 재검사 보존 시 STEP A/B 선행 부작용 선언.
  - 델타 재심 1회차(review-strict opus, 2026-10-03): **FAIL** · 실발견 2 + Minor 1 — ① plan 착륙-verbatim 스니펫 5곳(seal #47 `am=`·GUARD 6·SECURITY 문안·T8·SKILL 문구)이 정정 전 그대로인데 주석도 N/A 선언도 없음(전파 ② 범주 무언 통과) → `*(Closeout 정정: …)*` 주석 5곳 ② unknown 으로 올라온 `--- `(구분자 뒤 공백) 1행도 BOM 과 같은 회귀 부류로 판정 → 두 구분자 정규식에 `[ \t]*` 허용, `c3_bom_model` 을 BOM+공백 결합으로(RED: 정정 전 BOM+공백·순수 공백 둘 다 91/0 → GREEN 90/1 · 판별력: BOM 제거만 빼도, 공백 허용만 빼도 91/0 생존) ③ Minor: verify-setup 주석 "과탐 쪽으로"는 비-ocx 분기에만 맞음 → 정정. 부수: CONTEXT.md 사유 목록에 `noop:ls-files-failed`, teardown spec 개정 표기에 10-03.
  - 델타 재심 2회차(review-strict opus, 2026-10-03): **PASS** — 주석 5곳 실물 대조 일치, 픽스처 28종 × 현행/1회차/HEAD 대조 의도 외 결과 0. 선언 2건: 닫는 구분자 공백 허용을 지키는 뮤테이터 부재(차기 보강 후보) · Claude Code 실제 구분자 규칙 미실측(수용 잔여).

  **결과(T7 최종, Closeout 정정 후 — S1 의 309/34/35/33 은 정정 전 당시 값):** 최종 restage staged `verify-all.sh` **ALL PASS, RC=0**(2026-10-03 15:04, 로그 `delta3-1003-verify-all.log`).
  - doctor 40/0(WARN 1 = staged 사본 git repo 아님) · verify-setup **91/0** · seal-regression **39/0**(뮤테이터 +5: frontmatter·정규화 4 + BOM/공백 1)
  - failopen 5/0 · rpi-prereq 3/0 · orca-carrier 34/0 · run-all **315/315** · teardown E2E **47/0** · integration 8/0
  - statusline `pass=37 fail=0` · base-fable 337 bytes(최대 385)

**non-obvious 처분 — 명시 면제 + 차기 등록 후보 3건.** CLAUDE.md §4 는 등록 전에 사용자 확인과 5 Whys 를 요구한다. 무인 진행이라 이번 사이클에서는 등록하지 않고, 사이클 보고에 후보로 올린다(침묵 이월이 아니라 선언 이월이다).
- ⓐ JS `String.replace(str, str)` 의 치환 패턴(`$`+백틱 등)이 C24 plan 에 134행 중복을 만들었다. 이 plan 의 Global Constraints 에 편집 규칙으로 반영했다.
- ⓑ Edit 도구가 혼합-개행 spec 을 전부 CRLF 로 바꿨다(non-obvious.md #4(혼합 개행 Edit) 의 재발). Gate 델타 재심이 잡았고, perl 바이트 편집으로 다시 적용했다.
- ⓒ worktree 안에서 띄운 headless `claude -p` 자식의 SessionEnd 가 부모 worktree 를 지웠다(데이터 손실 0). Task 3 의 GUARD 6 이 구조적 대응이고, 등록 후보는 "자식 세션의 cwd 가 식별 신호를 오염시키는 클래스"다.

- [x] **Step 3: 마감.** 통합 리뷰 이후 선언적 편집(state·대장·Status)만 허용(D5) — 델타 재심 PASS 뒤 머지 직전에 했다.
  - state.json cycle 74 → 76(75·76) · last_completed_at·last_drift_check 2026-10-03
  - review-yield 대장 C24·C25 절 append
  - plan Status → completed(75 는 완료)
  - 머지 후 메인 트리 동기화는 이 plan 밖 마감 절차로 하고 사이클 보고에 기록한다. 계획했던 `pull --ff-only` 는 쓸 수 없다 — 메인 master 에 다른 세션의 미push 로컬 커밋(`a57fdfc`, review-yield 대장 append)이 있어서다. 내 사본(정정 전 초안)을 내용 확인 후 제거하고, 그 커밋을 보존하는 `git merge origin/master` 로 통합한다(대장 충돌은 append 시각 순서로 둘 다 유지).
