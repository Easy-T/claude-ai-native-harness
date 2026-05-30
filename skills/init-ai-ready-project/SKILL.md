---
name: init-ai-ready-project
description: |
  AI-Ready 프로젝트 부트스트랩. 사용자가 "새 프로젝트 셋업", "AI-ready 만들어줘",
  "프로젝트 초기화" 등을 말하면 무조건 사용. 파일 + 디렉터리 결정론적 생성.
orchestrator_skill: true
generated_by: built-in
orchestrator_version: 1.0
---

# init-ai-ready-project

AI-Ready 프로젝트를 부트스트랩한다. 메인이 절차를 따르되 모든 파일 생성은 sub-agent에 위임.

## Inputs
- `project_name` (string, required) — 프로젝트 이름. command 인자로 전달.
- `project_root` (path, optional) — 기본값: cwd

# Phase 0 — Self-Audit (글로벌 점검)
1. `bash ~/.claude/setup/doctor.sh` 실행 (환경 진단·치료)
2. 글로벌 `~/.claude/CLAUDE.md` drift 점검:
   - 줄 수 ≤ 200
   - 메타 룰 8개 마커 존재 (`## §1` ~ `## §8`)
   - 마지막 audit 마커 (`<!-- audit: YYYY-MM-DD -->`) 30일 이내
3. Hook 로그 통계 (지난 7일):
   ```
   awk -F'\t' -v d="$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)" \
     '$1 >= d && $4 ~ /BLOCK|ALERT/' \
     ~/.claude/hooks/.log/$(date +%Y-%m).log 2>/dev/null | \
     awk -F'\t' '{c[$2"-"$4]++} END {for (k in c) print k, c[k]}'
   ```
   임계 초과 시 사용자에게 보고 (§4.8.1 임계 표 참조).

# Phase 1 — Discover
Agent(subagent_type="explore-strict",
      task="대상 디렉터리 충돌 검사 + 스택 감지",
      context_paths=["./"],
      success_criteria="존재 파일 목록, 충돌 가능 항목 식별, 스택 신호(package.json/pyproject.toml/Cargo.toml/go.mod/pubspec.yaml) 감지")

## Phase 1 Gate
- 충돌이 있으면 사용자에게 진행 여부 확인.
- 스택 감지 결과를 Phase 2 변수 치환에 사용.

# Phase 2 — Generate (13개 파일 + 디렉터리)
templates/*.tpl을 변수 치환 후 결정론적 생성. 다른 파일이라 worktree 불필요. 병렬 호출 가능.

생성 파일 (절대경로 기준):
1. `<root>/CLAUDE.md` ← templates/CLAUDE.md.tpl
2. `<root>/docs/ai-context/architecture.md` ← templates/architecture.md.tpl
3. `<root>/docs/ai-context/runbook.md` ← templates/runbook.md.tpl
4. `<root>/docs/ai-context/deny-patterns.md` ← templates/deny-patterns.md.tpl
5. `<root>/docs/ai-context/non-obvious.md` ← templates/non-obvious.md.tpl
6. `<root>/docs/ai-context/domain-glossary.md` ← templates/domain-glossary.md.tpl
7. `<root>/.claude/settings.json` ← templates/project-settings.json.tpl
8. `<root>/.claude/hooks/pre-commit-deny.sh` ← templates/pre-commit-deny.sh.tpl (chmod +x)
9. `<root>/.gitignore` ← templates/.gitignore.tpl
10. `<root>/.claude/state.json` ← templates/state.json.tpl
11. `<root>/scripts/check.sh` ← templates/scripts-check.sh.tpl (chmod +x)
12. `<root>/.github/workflows/ci.yml` ← templates/github-ci.yml.tpl
13. `<root>/CONTEXT.md` ← templates/CONTEXT.md.tpl

생성 디렉터리:
- `<root>/docs/superpowers/specs/` (.gitkeep)
- `<root>/docs/superpowers/plans/` (.gitkeep)
- `<root>/.claude/hooks/` (실행권한 +x 보장)
- `<root>/scripts/`
- `<root>/.github/workflows/`

변수 치환은 references/placeholder-spec.md, references/stack-presets.md 참조.

각 파일 생성을 별도 execute-strict 호출로 위임:
Agent(subagent_type="execute-strict",
      task="<file_n> 생성 (templates/<n>.tpl 사용)",
      context_paths=["~/.claude/skills/init-ai-ready-project/templates/<n>.tpl",
                     "~/.claude/skills/init-ai-ready-project/references/placeholder-spec.md"],
      success_criteria="placeholder 모두 치환, 파일 생성 성공")

# Phase 3 — Verify
Agent(subagent_type="review-strict",
      task="스캐폴드 무결성 검증",
      context_paths=["<root>/CLAUDE.md", "<root>/docs/ai-context/", "<root>/.claude/"],
      success_criteria="
        - 13개 파일 + 5개 디렉터리 모두 존재
        - CLAUDE.md ≤200줄
        - CONTEXT.md 존재 (프로젝트 루트)
        - deny-patterns.md의 ❌ 마커 ≥8개
        - non-obvious.md에 '아직 비어 있음' 텍스트
        - .claude/hooks/pre-commit-deny.sh 실행권한
        - .claude/settings.json node로 파싱 성공
        - .claude/state.json schema_version=1, cycle.count=0
        - placeholder 잔존 0 (`grep -rE '{{[^}]+}}'` 결과 없음)
        - .gitignore ≥15줄
        - scripts/check.sh 존재 + 실행권한
        - .github/workflows/ci.yml 존재
        - docs/ai-context/runbook.md에 'Local Quality Gate' + 'Merge Policy' 섹션 존재
      ")

Phase 3 통과 못 하면 사용자에게 보고하고 재시도.

# Phase 4 — Closing
사용자 안내:
> 부트스트랩 완료. scripts/check.sh로 로컬 gate 확인 후 첫 사이클 시작.
> 예: "결제 모듈 만들어줘" → start-rpi-cycle 자동 발동.
> PR 완료 후에는 'closeout-pr-cycle'이 merge까지 안내합니다.

## Communication Protocol
- result: COMPLETE / FAIL
- evidence: 생성된 파일 경로 목록 + Phase 3 검증 결과 요약
- unknowns: 사용자에게 추가 입력 권고 (예: STACK 미감지 시 수동 입력 권유)

## 일관성 강제
파일 생성은 반드시 templates/*.tpl + 변수 치환만 사용한다. 자유 기술 금지. 새 섹션 추가 금지. 누락 금지.
