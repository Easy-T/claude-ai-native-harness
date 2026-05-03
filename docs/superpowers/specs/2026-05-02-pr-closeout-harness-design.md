# PR Closeout Harness — Design Spec

**Author:** Easy-T (with Claude)
**Created:** 2026-05-02
**Status:** Approved
**Spec location:** `~/.claude/docs/superpowers/specs/2026-05-02-pr-closeout-harness-design.md`

---

## §0. 개요

### 0.1 문제 정의

현재 RPI Cycle의 Closeout은 "구현 완료 + drift 검사 + 자산 갱신"으로 정의된다. 실제 프로젝트에서 구현이 끝난 뒤에는 다음 단계가 남는다:

```
local lint/test → commit 정리 → branch push → PR 생성 →
CI 통과 확인 → PR description 검증 → merge 전 review →
사용자 승인 → merge → worktree cleanup → main 동기화 →
plan/runbook/state 갱신
```

현재 Closeout은 이 절차를 닫지 않는다. 결과적으로:
- worktree/branch가 merge 없이 방치됨
- CI 통과 없이 "완료"로 처리됨
- AI가 사용자 승인 없이 merge하거나, 반대로 사용자가 직접 merge해야 함
- 다음 사이클 시작 전 브랜치 상태 불일치

### 0.2 목표

1. RPI Closeout을 **GitHub PR lifecycle까지 확장** — "merge 가능한 상태를 증거와 함께 제시 + 승인 후 merge/cleanup까지 닫는다"
2. 모든 새 프로젝트가 **로컬 검증 + CI 파이프라인**을 기본 갖추도록 init 보강
3. AI는 **merge를 결정하지 않는다** — review + 증거 제시 + 승인 요청만

### 0.3 범위

**포함:**
- `runbook.md.tpl` — PR lifecycle 섹션 추가
- `scripts-check.sh.tpl` — stack-aware 로컬 검증 스크립트 (신규)
- `github-ci.yml.tpl` — GitHub Actions CI 기본 설정 (신규)
- `init-ai-ready-project` — 위 2개 파일 생성 추가 (10 → 12파일)
- `stack-presets.md` — CHECK_COMMANDS, CI_SETUP, SMOKE_COMMAND 필드 추가
- `closeout-pr-cycle` — 신규 orchestrator skill
- `start-rpi-cycle` — Closeout에서 closeout-pr-cycle 호출
- `verify-setup.sh` / `verify-integration.sh` — 신규 파일/skill 검증 추가

**제외:**
- 자동 merge (사용자 승인 없이 merge 금지)
- branch protection 자동 설정
- release automation / semantic versioning
- 배포 자동화
- GitHub 권한/organization 정책 수정

---

## §1. Closeout 확장 설계

### 1.1 새 Phase Closeout 흐름

```
Phase Closeout
  Step 0. runbook.md 로드 확인
  Step 1. Local Quality Gate
  Step 2. Git/Worktree Gate
  Step 3. PR Gate
  Step 4. CI Gate
  Step 5. Pre-Merge Senior Review
  Step 6. User Approval Gate
  Step 7. Merge + Cleanup
  Step 8. state/plan/asset drift 갱신
```

### 1.2 각 단계 상세

#### Step 0. runbook.md 로드 확인
- `docs/ai-context/runbook.md` 존재 확인
- "Local Quality Gate" 섹션 존재 확인
- 없으면: WARN 보고 후 default gate 사용 (bash scripts/check.sh)

#### Step 1. Local Quality Gate
- `scripts/check.sh` 존재 시: `bash scripts/check.sh` 실행
- 없으면: runbook Local Quality Gate 명령 사용
- 없으면: 사용자에게 check 명령 확인
- 실패 시: 수정 후 재실행 요청 (merge 진행 불가)

#### Step 2. Git/Worktree Gate
```
git status → clean or explained
current branch ≠ main/master
at least 1 commit ahead of base
no uncommitted changes (or user explicitly waived)
```

#### Step 3. PR Gate
```bash
git push -u origin <branch>
gh pr create --fill   # 또는 gh pr view (이미 존재 시)
```
PR body에 필수 포함:
- 구현 범위 요약
- 관련 spec/plan 경로
- local check 결과
- 위험/rollback 방법
- 의도적 제외 범위

#### Step 4. CI Gate
```bash
gh pr checks --watch   # 또는 timeout 5분 후 상태 보고
```
- 통과: Step 5 진행
- 실패: 실패 job + 원인 보고 → 수정 요청

#### Step 5. Pre-Merge Senior Review
review-strict subagent 호출 (§3 기준 사용).

#### Step 6. User Approval Gate
```
AI: "review 결과: <요약>. merge 진행할까요? (merge / 수정 후 재시도 / abandon)"
User: 명시 승인 필요
```
AI는 이 step에서 어떤 이유로도 merge를 독자적으로 진행하지 않는다.

#### Step 7. Merge + Cleanup
```bash
gh pr merge --squash --delete-branch   # runbook policy 따름
# worktree 사용 시: ExitWorktree(action: "remove")
```
이후:
- `git checkout main && git pull`
- ExitWorktree (isolation: worktree 사용 시)

#### Step 8. 자산 갱신
- plan 헤더 Status: completed
- state.json cycle.count+1, last_completed_at
- architecture/glossary/non-obvious drift 확인 (기존 Closeout 로직 유지)

---

## §2. runbook.md 스키마 확장

현재 runbook 섹션: Deploy / Rollback / Common Operations / Health Checks / Incident Response

확장 후:

```
## Local Quality Gate
## CI Gate
## PR Creation
## Pre-Merge Review
## Merge Policy
## Deploy
## Rollback
## Common Operations
## Health Checks / Dashboards
## Incident Response
```

### 2.1 Local Quality Gate 섹션 스키마

```md
## Local Quality Gate

PR 생성 전 반드시 실행:

```bash
{{LOCAL_CHECK_COMMAND}}
```

통과 기준:
- lint/format/test 모두 통과
- 외부 shared state (DB 실운영, 외부 API publish) 미접촉
```

### 2.2 Merge Policy 섹션 스키마

```md
## Merge Policy

AI는 merge를 결정하지 않는다.

Merge 조건:
1. local check 통과
2. CI 통과
3. pre-merge review Critical 0
4. 사용자 명시 승인

기본 merge 방식:
```bash
gh pr merge --squash --delete-branch
```
```

---

## §3. Pre-Merge Review 기준

### 3.1 review-strict 호출 방식

```python
Agent(subagent_type="review-strict",
      task="pre-merge senior maintainer review",
      context_paths=[
        "docs/ai-context/runbook.md",
        "docs/ai-context/architecture.md",
        "docs/ai-context/deny-patterns.md",
        "docs/ai-context/non-obvious.md",
        "<active plan path>",
      ],
      success_criteria="""
        PASS only if:
        - local check 통과 증거 있음
        - GitHub CI 통과 또는 원격 없음
        - PR description이 실제 diff와 일치
        - 구현이 active plan의 scope를 충족
        - scope creep 없음 (plan 외 변경 없음)
        - security/external-state 위험 없음 (Critical 기준 참조)
        - 테스트가 최소 happy path + 의미 있는 실패 path 커버

        보고 형식:
        Critical: merge 금지 사항
        Important: merge 전 수정 권장
        Minor: 선택적 개선
        Suggestions: 모두가 인정할 리팩토링만

        제안 금지:
        - 취향성 naming/style
        - 한 번 쓰는 helper 추출
        - 미래 기능을 위한 추상화
        - Foundation/cycle 범위 밖 재설계
        - "더 깔끔해 보임" 수준 리팩토링

        Runbook/ADR/glossary/non-obvious drift 확인 포함.
      """)
```

### 3.2 Critical 기준 (merge 금지)
- 요구사항/plan 누락
- 테스트 실패 / CI 실패
- 데이터 손실 / credential 노출 / publish / 외부 shared state 오염 위험
- 보안 취약점 (OWASP Top 10 수준)
- scope 외 대규모 변경

### 3.3 Important 기준 (merge 전 수정 권장)
- 실패 가능한 테스트 구멍
- PR 설명과 diff 불일치
- rollback 불명확
- runbook/ADR/glossary drift

### 3.4 Minor / Suggestions
- Minor: 명확히 작은 중복, 저위험 readability
- Suggestions: 3곳 이상 반복 로직, 책임 분리 필요 시만

---

## §4. scripts/check.sh 설계

### 4.1 원칙
- stack-aware: pyproject.toml / package.json / Cargo.toml 감지
- 실패를 숨기지 않음 (set -euo pipefail)
- 외부 shared state 미접촉 (prod DB, 외부 API publish 금지)
- 빈 프로젝트는 placeholder + exit 0 (init 시 실패 방지)

### 4.2 템플릿 구조

```bash
#!/usr/bin/env bash
set -euo pipefail
echo "== {{PROJECT_NAME}} check =="

{{CHECK_COMMANDS}}

echo "== check complete =="
```

### 4.3 stack별 CHECK_COMMANDS

| Stack | Detection | CHECK_COMMANDS |
|-------|-----------|----------------|
| Python uv | pyproject.toml | `uv run ruff check . && uv run ruff format --check . && uv run pytest -q` |
| Python pip | pyproject.toml | `python -m ruff check . && python -m pytest -q` |
| Node | package.json | `npm run lint --if-present && npm test` |
| Rust | Cargo.toml | `cargo fmt --check && cargo clippy -- -D warnings && cargo test` |
| None detected | — | `echo "No checks configured. Edit scripts/check.sh."` + exit 0 |

---

## §5. GitHub Actions CI 설계

### 5.1 원칙
- bash scripts/check.sh를 CI에서도 실행 (로컬과 동일한 gate)
- multi-stack 지원 (pyproject.toml / package.json / Cargo.toml 감지)
- GitHub 없는 환경에서도 파일이 있어도 무해 (CI가 작동 안 할 뿐)
- 기본 생성, 프로젝트 요건에 맞게 수정 가능

### 5.2 기본 구조

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main, master]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        if: hashFiles('pyproject.toml') != ''
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install uv
        if: hashFiles('pyproject.toml') != ''
        uses: astral-sh/setup-uv@v4
      - name: Set up Node
        if: hashFiles('package.json') != ''
        uses: actions/setup-node@v4
        with:
          node-version: '22'
      - name: Set up Rust
        if: hashFiles('Cargo.toml') != ''
        uses: dtolnay/rust-toolchain@stable
      - name: Run project checks
        run: bash scripts/check.sh
```

---

## §6. init-ai-ready-project 변경 사항

### 6.1 생성 파일 변경 (10 → 12개)

추가:
- `<root>/scripts/check.sh` ← templates/scripts-check.sh.tpl (chmod +x)
- `<root>/.github/workflows/ci.yml` ← templates/github-ci.yml.tpl

생성 디렉터리 추가:
- `<root>/scripts/`
- `<root>/.github/workflows/`

### 6.2 Phase 3 검증 기준 추가
- `scripts/check.sh` 존재 + 실행권한
- `.github/workflows/ci.yml` 존재
- runbook에 "Local Quality Gate", "Merge Policy" 섹션 존재

### 6.3 Phase 4 Closing 안내 보강
> 부트스트랩 완료. scripts/check.sh를 실행해서 로컬 gate 확인 후 첫 사이클 시작.

---

## §7. closeout-pr-cycle skill 설계

### 7.1 트리거 예시
- "PR 만들어줘"
- "merge 준비해줘"
- "작업 마무리해줘"
- "CI 확인하고 merge 준비해줘"
- "브랜치 닫아줘"

### 7.2 Phase 구조
```
Phase 1 — Local Gate
Phase 2 — PR Gate
Phase 3 — CI Gate
Phase 4 — Senior Review
Phase 5 — User Approval
Phase 6 — Merge/Cleanup
```

### 7.3 실패 처리
- Local Gate 실패: FAIL 보고, 수정 요청
- CI 실패: 실패 job 요약 + 수정 요청
- Review Critical 있음: 수정 목록 제시 + abandon 여부 확인
- 사용자 abandon: state/plan에 abandoned 기록

### 7.4 gh 미설치 or remote 없음
- gh 미설치: local check + commit만 확인, PR 단계 skip + WARN 보고
- remote 없음: push/PR 단계 skip + WARN 보고
- branch = main/master: FAIL 보고 (main에서 직접 작업 금지)

---

## §8. start-rpi-cycle Closeout 수정 방향

Phase Closeout 시작 시:

```
git remote 존재 && gh auth status 통과 && branch ≠ main/master
  → closeout-pr-cycle 호출
  → 결과 받아 Step 8 (state/plan/asset 갱신) 진행

else
  → local check만 실행
  → WARN: PR lifecycle 미수행 이유 보고
  → Step 8 진행
```

---

## §9. verify scripts 갱신 범위

`setup/verify-setup.sh` 추가 검증:
- `skills/closeout-pr-cycle/SKILL.md` 존재
- orchestrator_skill: true 마커 존재
- Phase ≥ 6 (Phase 1~6 모두 존재)
- Agent(subagent_type="review-strict") 호출 존재

`setup/verify-integration.sh` (존재 시) 추가:
- templates/scripts-check.sh.tpl 존재
- templates/github-ci.yml.tpl 존재
- init 생성 산출물 카운트: 12 (기존 10)

---

## §10. 설계 원칙 요약

1. **AI는 merge를 결정하지 않는다** — 증거 수집 + review + 승인 요청까지만
2. **로컬 gate = CI gate** — scripts/check.sh가 양쪽에서 실행
3. **runbook이 Closeout의 기준** — 프로젝트마다 merge policy를 runbook에 명시
4. **init이 gate를 심는다** — 새 프로젝트는 처음부터 check.sh + CI 포함
5. **실패는 숨기지 않는다** — set -euo pipefail, || true 금지 (placeholder 제외)
6. **기존 Closeout 자산 갱신 유지** — PR lifecycle은 추가, 기존 drift 검사는 유지
