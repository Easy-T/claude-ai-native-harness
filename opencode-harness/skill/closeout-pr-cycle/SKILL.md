---
name: closeout-pr-cycle
description: |
  구현 완료 후 PR 생성, CI 확인, merge 전 통합 리뷰(senior+drift), 사용자 승인 요청까지 수행.
  사용자가 "PR 만들어줘", "merge 준비해줘", "작업 마무리해줘", "CI 확인하고 merge 준비",
  "브랜치 닫아줘" 등을 말하면 사용.
  AI는 merge를 결정하지 않으며 사용자 명시 승인 없이는 merge 금지.
orchestrator_skill: true
generated_by: built-in
orchestrator_version: 1.0
---

# closeout-pr-cycle

구현이 완료된 브랜치를 PR → CI → 통합 리뷰(senior+drift) → 사용자 승인 → merge/cleanup까지 닫는다.
메인이 절차를 직접 따르되, review는 review-strict subagent에 위임.

※ 이 skill은 start-rpi-cycle의 Phase Closeout에서도 조건부 호출된다.

# Preflight Check

실행 전 확인:

```bash
git rev-parse --abbrev-ref HEAD   # 브랜치 이름 확인
git remote get-url origin 2>/dev/null && echo "remote OK" || echo "no remote"
gh auth status 2>/dev/null && echo "gh OK" || echo "gh not available"
```

- branch = main/master → **FAIL 중단**: "main 브랜치에서 직접 작업 금지. feature 브랜치로 전환 후 재실행."
- remote 없음 → Phase 1만 실행 후 WARN 보고 (PR 단계 skip)
- gh 미설치/미인증 → Phase 1~2만 실행 후 WARN 보고 (CI/merge 단계 skip)

# Phase 1 — Local Gate

runbook 로드:
- `docs/ai-context/runbook.md`의 "Local Quality Gate" 섹션 참조
- 없으면: `bash scripts/check.sh` 실행 (존재 시)
- 없으면: 사용자에게 "local check 명령을 알려주세요" 확인
※ **하네스 사이클 스위트 규약 (C18 spec §17.5 ③)**: seal-regression 조건부 스킵은 정본 하네스(`~/.claude`) 전용 — opencode 번들에는 verify-setup seal 도 그 변이 메타-테스트도 대응물이 없어 조건부 스킵 대상이 아니다. 번들 스위트(`node --test tests/*.test.mjs` + `_oracle/`)는 하네스 수정 사이클이면 항상 full 실행.

```bash
bash scripts/check.sh
```

실패 시:
- 오류 내용 보고
- **STOP**: 수정 후 재실행 요청. Phase 2 진행 불가.

git 상태 확인:
```bash
git status --short
git log --oneline origin/$(git rev-parse --abbrev-ref HEAD)..HEAD 2>/dev/null \
  || git log --oneline main..HEAD 2>/dev/null \
  || git log --oneline -5
```

uncommitted 변경 있으면 → "커밋 또는 stash 후 재실행" 요청.
커밋 없으면 → "구현된 커밋이 없습니다. 구현 후 재실행" 보고.

# Phase 2 — PR Gate

브랜치 push:
```bash
git push -u origin $(git rev-parse --abbrev-ref HEAD)
```

PR 생성 또는 기존 PR 확인:
```bash
gh pr view --json number,title,url 2>/dev/null \
  || gh pr create --fill
```
※ 신규 생성 시 `--fill` 대신 위임 초안을 `--body-file <경로>` 로 전달 가능(§17.4 — 초안이 이미 있으면
생성-후 보완보다 이 경로가 정합적이다).

PR이 새로 생성됐다면 PR body 검증:
- 구현 범위 요약 포함 여부
- `docs/superpowers/plans/` 경로 참조 여부
- 위험/rollback 포함 여부

PR body가 자동 생성(`--fill`)으로 부족하면 보완 제안 후 사용자 확인.
※ PR body 는 집필-위임 가능(구조화 데이터→opus 초안→메인 감수 — spec §17.4; fable 세션 기본 경로).
※ (번들 주: 'opus' 등 모델 명칭은 CC 하네스 기준 — opencode 환경은 동급 내부 모델로 해석. 'spec §N' 참조도 정본 하네스 spec 기준 — 번들에는 해당 규범이 인라인 착륙돼 있어 참조 해소 없이 완결)

PR URL을 사용자에게 보고.

# Phase 3 — CI Gate

gh 인증 확인 후:
```bash
gh pr checks --watch --timeout 300
```

timeout 5분 내 완료 안 되면: 현재 상태 보고 + "계속 기다릴까요, 나중에 재확인할까요?" 확인.

CI 통과 → Phase 4 진행.
CI 실패:
- 실패 job 이름 + 로그 마지막 20줄 요약
- **STOP**: "CI 실패. 수정 후 push → CI 재확인 후 재시도하세요."

# Phase 4 — 통합 리뷰 (senior + drift 합본, C17 spec §16.3-2)

review-strict subagent를 `task` 도구로 디스패치 — task: "pre-merge adversarial senior review — refute-by-default"; read: `docs/ai-context/runbook.md`, `docs/ai-context/architecture.md`, `docs/ai-context/deny-patterns.md`, `docs/ai-context/non-obvious.md`, `CONTEXT.md`, `docs/superpowers/plans/<active plan>` (실재하는 것만 전달하는 규약 불변); success:

```
임무: 준수 확인이 아니라 결함 발견이다 (C16 spec §15.2 — 내부 적대 패스).
refute-by-default: 각 검사 범주에서 결함을 찾으려 시도하고, 없으면 범주별 'none found' 명시.
검사 범주: A 계약 정합성(출력 계약·판정식·소비자 동반) · B 소비 로직(경계·폴백·마스킹)
· C 픽스처 vacuity(구현 되돌려도 GREEN 인 픽스처) · D 문서-실물 드리프트 · E 무회귀(기존 의미 침묵 변경).
F drift 체크리스트 (start-rpi-cycle Step C-1 합본 — 이 리뷰가 그 sub-step 1 을 겸한다.
  ★F 항목의 미충족은 최소 Important 로 분류하고, 보고에 "drift 절"을 분리해 항목별 판정을
  전항 명시할 것 — 분류 강등으로 PASS 를 얻는 우회 차단(§16.8 E3)):
- CONTEXT.md 갱신(신규 용어) 또는 변경 없음 확인
- plan 모든 체크박스 [x] 또는 명시적 미완료 사유 기록
- 사이클 중 발생한 실패가 5 Whys 통과 후 non-obvious.md 누적 (또는 명시 면제) — §16.8 D4
- 사이클 자산(architecture/glossary — 실재하는 것만) 갱신 또는 변경 없음 확인
- silent-downgrade 검출: spec/plan 선언 설계 vs 구현 실물 대조 — 미신고 열화 발견 시 FAIL
  (plan 의 DOWNGRADE-DECLARED 범위는 선언된 결정)
발견은 파일:행 + 원문 인용 필수 — 인용 없는 발견은 무효.
발견의 처분: 각 발견을 기존 보고 형식(Critical/Important/Minor)으로 분류해 합류 — PASS/FAIL 판정
기준(FAIL if any Critical)은 불변.

PASS only if ALL of:
- local check 통과 증거 있음 (Phase 1 결과 참조)
- PR description이 실제 diff와 일치
- 구현이 active plan scope를 충족 (plan 경로 docs/superpowers/plans/ 참조)
- scope creep 없음
- security/external-state 위험 없음 (Critical 기준)
- 테스트: happy path + 의미 있는 실패 path 커버
- runbook/ADR/glossary/non-obvious drift 없음

보고 형식:
Critical: (merge 금지) 항목
Important: (merge 전 수정 권장) 항목
Minor: (선택) 항목
Suggestions: (모두가 인정할 리팩토링만) 항목

제안 금지: 취향성 naming/style, one-use helper 추출,
미래 기능 추상화, 현 cycle 범위 밖 재설계.

FAIL if any Critical exists.
```

원본 Claude-Code 디스패치 형태 (opencode: dispatch the review-strict subagent via the task tool):

```
Agent(subagent_type="review-strict",
      task="pre-merge adversarial senior review — refute-by-default",
      context_paths=[
        "docs/ai-context/runbook.md",
        "docs/ai-context/architecture.md",
        "docs/ai-context/deny-patterns.md",
        "docs/ai-context/non-obvious.md",
      ],
      success_criteria="...")
```

※ 이 통합 리뷰 수행이 `audit.last_drift_check` 스탬프의 근거(start-rpi-cycle sub-step 3). **통합 리뷰 이후 브랜치 말미 커밋은 plan 최종 task 가 사전 명시한 선언적 기계 편집(AGENTS.md §3·layer-yield append)에 한정** — 그 외 변경은 통합 리뷰 재실행 대상(§16.3-2 D5). layer-yield 대장에는 `통합(senior+drift)` 1층 1행으로 기재(§16.8 E2); auto-merge 사이클은 통합 리뷰 완료 직후·merge 명령 이전에 append(§16.3-4 E4).

review-strict 결과를 사용자에게 구조화해서 전달:
- Critical N개 / Important N개 / Minor N개 / Suggestions N개
- Critical 있으면: 수정 목록 제시 후 Phase 5로 전달 (merge 금지)

**교차패밀리 리뷰 분기 (GAP-006 규약 — `docs/ai-context/cross-family-review.md`가 SSOT)**:
senior review 후, 고-스테이크 사이클(하네스 거버넌스 변경·루브릭 재채점·spec 변경)이면 교차패밀리(GPT) 적대 리뷰를 시도한다:
1. **probe**: runbook §1 순서(A: `command -v codex`+`codex login status` → B: `OCX_MODEL=<gpt-모델> ~/.claude/bin/claude-ocx -p --output-format json`의 `modelUsage`에 `gpt-*`). 설치/로그인 시도 절대 금지.
2. **가용 시**: runbook §2 프로토콜로 **슬롯 2**(Closeout, 코드 diff — 사이클당 2슬롯 상한의 둘째; 슬롯 1은 Gate P 직후 spec delta+plan 대상, cross-family-review.md §2) 실행(stdin 파이프·read-only·refute-by-default·원문 인용 강제) → 발견은 **2단계 트리아지**(증거 수집 opus 위임 가능·최종 판정 메인 — cross-family-review.md §2, spec §17.2)(그대로 편입 금지) → REAL 발견은 Critical/Important 목록에 병합.
   ※ **판정 전 각 발견의 대조 증거(원문 인용 실재·실측 결과) 전문 열람 의무** — 권고 무열람 일괄 승인 금지(§17.1 통독 의무 동형). 권고를 뒤집을 자유가 판정 주권의 내용이며, 열람 없이는 그 자유가 행사되지 않는다.
3. **불가 시**: SKIP + 사유 1줄 기록(비차단 — advisory fail-open).

**정정-위임 미니-사이클 (C18 spec §17.3)**:
트리아지(내부 발견·교차패밀리 REAL 판정)가 확정된 뒤의 정정은 메인이 직접 편집하지 않고 미니-사이클로 수행한다:
1. **task 목록화 — 메인**: 발견별 정정 대상 파일·절·수용 기준을 열거(판정은 이미 확정된 상태로 넘긴다).
2. **execute-strict(opus) 실행**: 목록 단위 위임 — plan task 본문 TDD-verbatim 전달 규약 동일.
3. **review-strict(opus) 검증**: 정정 diff + **관련 스위트 재실행 결과** + **원 발견 REAL 목록 전건 대응 대조(누락 0 — 원 목록을 context 로 필수 전달)**를 근거로 판정.
※ **전파-완결성 대조 (C19 spec §18.3)**: step 3 검증은 원 발견 전건 대응에 더해, 각 정정의 착륙 사이트를
4범주(spec 본문 · spec 내 착륙-verbatim 블록 · L1 소비자 skill/문서 · opencode 미러)로 전수 대조한다 —
범주에 대응물이 없으면 N/A 를 명시(무언 통과 금지). C18 정정-전파 공백 클래스(슬롯2 5건)의 구조 대응.
4. **메인 승인**: 판정 주권은 이전되지 않는다.

- **델타 재심(§15.4) 스코프 불변**: 미니-사이클은 정정 *실행 주체*의 교체이지 재심 스코프의 변경이 아니다 — 재심은 여전히 "정정이 편집한 파일/절에 한정해 원 기준 재적용".
- **예외 — 메인 직접 편집 허용 (편집-주체 축, 시점 무관)**: 위임 왕복 비용이 편집 자체보다 비싼 **선언적 기계 편집** 4건 — ⓐ`AGENTS.md` §3 ⓑlayer-yield append ⓒplan 체크박스·plan Status 헤더 ⓓ`state.json`(spec §17.3). **D5(머지-전 창) 허용 집합은 ⓐⓑ 2건으로 불변** — ⓒⓓ를 그 창의 허용 편집으로 읽는 것은 오독이며, 그 창의 판정은 §16.3-2 D5 가 계속 지배한다.

# Phase 5 — User Approval Gate

사용자에게 보고:

```
== PR Closeout Review ==
Branch: <branch>
PR: <url>
Local check: PASS
CI: PASS / SKIP
Review: Critical=N, Important=N, Minor=N

[선택]
  1. merge 진행 (Critical=0인 경우만 가능)
  2. 수정 후 재시도 (Critical 또는 Important 있을 때)
  3. abandon (PR 닫기)
```

**사용자 "1" 또는 명시 승인 없이는 Phase 6으로 절대 진행하지 않는다.**

Critical > 0이면 선택 1을 비활성으로 제시:
```
  1. merge 불가 (Critical N개 해결 후 재시도)
```

abandon 선택 시:
```bash
gh pr close $(gh pr view --json number --jq .number)
```
state.json / plan에 abandoned 기록 후 종료.

# Phase 6 — Merge/Cleanup

사용자 승인 확인 후:

merge (runbook Merge Policy 따름, 기본 squash):
```bash
gh pr merge --squash --delete-branch
```

로컬 정리:
```bash
git checkout main 2>/dev/null || git checkout master
git pull
```

worktree 사용 시 (isolation: worktree 로 실행한 경우):
- `git worktree remove` (또는 Plan-4 worktree-teardown 로직) 호출 또는 사용자에게 안내

사용자에게 최종 보고:
```
== Merge Complete ==
Branch: <branch> → merged + deleted
PR: <url>
Commit: <merge commit hash>
Local: main / master up-to-date
```

## Communication Protocol

- result: COMPLETE / FAIL / ABANDONED / PARTIAL (gh 없음/remote 없음 등)
- evidence:
  - local check 결과
  - PR URL
  - CI 결과 (통과/실패/skip)
  - review-strict 결과 요약 (Critical/Important/Minor count)
  - merge commit hash (완료 시)
- unknowns: 사용자에게 결정 권고 항목 (Important 항목 수정 여부 등)
