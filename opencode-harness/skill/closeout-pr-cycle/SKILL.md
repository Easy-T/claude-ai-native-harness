---
name: closeout-pr-cycle
description: |
  구현 완료 후 PR 생성, CI 확인, merge 전 senior review, 사용자 승인 요청까지 수행.
  사용자가 "PR 만들어줘", "merge 준비해줘", "작업 마무리해줘", "CI 확인하고 merge 준비",
  "브랜치 닫아줘" 등을 말하면 사용.
  AI는 merge를 결정하지 않으며 사용자 명시 승인 없이는 merge 금지.
orchestrator_skill: true
generated_by: built-in
orchestrator_version: 1.0
---

# closeout-pr-cycle

구현이 완료된 브랜치를 PR → CI → senior review → 사용자 승인 → merge/cleanup까지 닫는다.
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

PR이 새로 생성됐다면 PR body 검증:
- 구현 범위 요약 포함 여부
- `docs/superpowers/plans/` 경로 참조 여부
- 위험/rollback 포함 여부

PR body가 자동 생성(`--fill`)으로 부족하면 보완 제안 후 사용자 확인.

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

# Phase 4 — Senior Review

review-strict subagent를 `task` 도구로 디스패치 — task: "pre-merge senior maintainer review"; read: `docs/ai-context/runbook.md`, `docs/ai-context/architecture.md`, `docs/ai-context/deny-patterns.md`, `docs/ai-context/non-obvious.md`; success:

```
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
      task="pre-merge senior maintainer review",
      context_paths=[
        "docs/ai-context/runbook.md",
        "docs/ai-context/architecture.md",
        "docs/ai-context/deny-patterns.md",
        "docs/ai-context/non-obvious.md",
      ],
      success_criteria="...")
```

review-strict 결과를 사용자에게 구조화해서 전달:
- Critical N개 / Important N개 / Minor N개 / Suggestions N개
- Critical 있으면: 수정 목록 제시 후 Phase 5로 전달 (merge 금지)

**교차패밀리 리뷰 분기 (GAP-006 규약 — `docs/ai-context/cross-family-review.md`가 SSOT)**:
senior review 후, 고-스테이크 사이클(하네스 거버넌스 변경·루브릭 재채점·spec 변경)이면 교차패밀리(GPT) 적대 리뷰를 시도한다:
1. **probe**: runbook §1 순서(A: `command -v codex`+`codex login status` → B: `claude --model <gpt-모델> -p --output-format json`의 `modelUsage`에 `gpt-*`). 설치/로그인 시도 절대 금지.
2. **가용 시**: runbook §2 프로토콜로 **사이클당 1회** 실행(stdin 파이프·read-only·refute-by-default·원문 인용 강제) → 발견은 **메인 세션이 원문 실측 대조 후 REAL/기각 트리아지**(그대로 편입 금지) → REAL 발견은 Critical/Important 목록에 병합.
3. **불가 시**: SKIP + 사유 1줄 기록(비차단 — advisory fail-open).

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
