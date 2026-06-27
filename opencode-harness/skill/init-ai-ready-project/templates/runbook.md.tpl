# Runbook — {{PROJECT_NAME}}

> ⚠️ 이 파일은 **로컬 검증·PR·배포·장애 대응**의 기술적 실행 절차입니다.
> ⚠️ 프로젝트 작업 계획(Work Plan)은 `docs/superpowers/specs/` 와
>    `docs/superpowers/plans/`에 보관됩니다.
> ⚠️ 의사결정·전략은 ADR(`architecture.md`)에 보관됩니다.

---

## Local Quality Gate

PR 생성 전 반드시 실행:

```bash
{{LOCAL_CHECK_COMMAND}}
```

통과 기준:
- lint/format/test 모두 통과
- smoke test (있으면) 통과
- 외부 shared state (prod DB, 외부 API publish, browser profile) 미접촉

stack 검증이 없으면 `scripts/check.sh`를 수정하고 이 섹션도 업데이트하세요.

---

## CI Gate

PR 생성 후 GitHub Actions가 통과해야 merge 가능:

```bash
gh pr checks --watch
```

CI 실패 시:
1. 실패 job 확인 (`gh pr checks`)
2. 원인 수정
3. local check 재실행 (위 gate 통과 확인)
4. push
5. CI 재확인

---

## PR Creation

```bash
git push -u origin <branch>
gh pr create --fill
```

PR description에 반드시 포함:
- 구현 범위 요약
- 관련 spec/plan 경로 (`docs/superpowers/plans/...`)
- local check 결과 (통과 확인)
- 위험 및 rollback 방법
- 의도적으로 제외한 범위 (있으면)

---

## Pre-Merge Review

merge 전 review-strict subagent가 senior maintainer 관점으로 검토:
- spec/plan 충족 여부
- scope creep 없음
- security/external-state 위험 없음
- 테스트 커버리지 (happy path + 의미 있는 실패 path)
- runbook/ADR/glossary/non-obvious drift

AI는 review + 증거 제시까지만 수행. merge는 §Merge Policy 참조.

---

## Merge Policy

**AI는 merge를 결정하지 않는다.**

Merge 조건 (모두 충족 필요):
1. local check 통과
2. CI 통과 (원격 repo 있을 경우)
3. pre-merge review — Critical 0개
4. 사용자 명시 승인

기본 merge 방식:
```bash
gh pr merge --squash --delete-branch
```

프로젝트 정책이 다르면 이 줄을 수정하세요. merge 후 로컬 정리:
```bash
git checkout main && git pull
```

---

## Deploy

{{DEPLOY_PROCEDURE}}

---

## Rollback

{{ROLLBACK_PROCEDURE}}

---

## Common Operations

(예: cache flush, queue drain, log rotation, certificate renewal 등)

---

## Health Checks / Dashboards

{{DASHBOARDS}}

---

## Incident Response

(간단 — 자세한 건 별도 playbook으로 분리 권장)

{{INCIDENT_RESPONSE}}
