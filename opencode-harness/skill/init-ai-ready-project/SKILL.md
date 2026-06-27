---
name: init-ai-ready-project
description: |
  opencode 프로젝트를 AI-Ready로 부트스트랩. "새 프로젝트 셋업", "AI-ready 만들어줘",
  "프로젝트 초기화"를 말하면 사용. AGENTS.md + 프로젝트 opencode.json deny-gate +
  ai-context 문서를 결정론적으로 생성(템플릿 + 변수 치환만).
---

# init-ai-ready-project (opencode 타깃)

opencode 프로젝트를 부트스트랩한다. CC `~/.claude` 하네스의 동명 스킬의 **opencode 이식판**:
`CLAUDE.md`→`AGENTS.md`, `.claude/settings.json` 훅 deny-gate → 프로젝트 `opencode.json`의
`permission.bash` 정적 deny(네이티브 L3). 메인이 절차를 따르되 파일 생성은 sub-agent에 위임.

## Inputs
- `project_name` (string, required) — 프로젝트 이름.
- `project_root` (path, optional) — 기본값: cwd.

# Phase 0 — Self-Audit (전역 하네스 점검, opencode)
1. `opencode --version` ≥ 1.17.11 확인 (서브에이전트 강제 R1 = 중앙 도구 래퍼; 1.17.9는 degraded).
2. 전역 헌법 `~/.config/opencode/AGENTS.md` drift 점검:
   - 존재 + 거버넌스 마커 8개(`## §1`~`## §8`) 존재(전역 = §1~§8 governance).
   - (있으면) `bash ~/.config/opencode/_oracle/verify-all.sh`는 빌드박스 전용 — 런타임엔 불필요.
3. 미충족 항목은 사용자에게 보고(차단 아님; 부트스트랩은 계속).

# Phase 1 — Discover
Agent(subagent_type="explore-strict",
      task="대상 디렉터리 충돌 검사 + 스택 감지",
      context_paths=["./"],
      success_criteria="존재 파일 목록, 충돌 항목, 스택 신호(package.json/pyproject.toml/Cargo.toml/go.mod/pubspec.yaml) 감지")

## Phase 1 Gate
- 충돌(기존 AGENTS.md/opencode.json 등)이 있으면 사용자에게 진행 여부 확인.
- 스택 감지 결과를 Phase 2 변수 치환에 사용(references/stack-presets.md).

# Phase 2 — Generate (12개 파일 + 디렉터리)
templates/*.tpl을 변수 치환 후 결정론적 생성. 파일이 서로 달라 worktree 불필요·병렬 가능.

생성 파일 (`<root>` 기준):
1. `<root>/AGENTS.md` ← templates/AGENTS.md.tpl
2. `<root>/docs/ai-context/architecture.md` ← templates/architecture.md.tpl
3. `<root>/docs/ai-context/runbook.md` ← templates/runbook.md.tpl
4. `<root>/docs/ai-context/deny-patterns.md` ← templates/deny-patterns.md.tpl
5. `<root>/docs/ai-context/non-obvious.md` ← templates/non-obvious.md.tpl
6. `<root>/docs/ai-context/domain-glossary.md` ← templates/domain-glossary.md.tpl
7. `<root>/opencode.json` ← templates/project-opencode.json.tpl  (프로젝트 deny-gate)
8. `<root>/.gitignore` ← templates/.gitignore.tpl
9. `<root>/state.json` ← templates/state.json.tpl  (RPI 사이클 상태)
10. `<root>/scripts/check.sh` ← templates/scripts-check.sh.tpl (chmod +x)
11. `<root>/.github/workflows/ci.yml` ← templates/github-ci.yml.tpl
12. `<root>/CONTEXT.md` ← templates/CONTEXT.md.tpl

생성 디렉터리:
- `<root>/docs/superpowers/specs/` (.gitkeep)
- `<root>/docs/superpowers/plans/` (.gitkeep)
- `<root>/docs/ai-context/`
- `<root>/scripts/`
- `<root>/.github/workflows/`

변수 치환은 references/placeholder-spec.md, references/stack-presets.md 참조.
**deny-gate 주의:** 강제는 `opencode.json`의 `permission.bash` deny 맵(정적, 네이티브). 프로젝트 고유 deny
추가 시 `docs/ai-context/deny-patterns.md`(문서) + `opencode.json`(강제) **양쪽**에 추가(CC 동적 훅 대체).

각 파일 생성을 별도 execute-strict 호출로 위임:
Agent(subagent_type="execute-strict",
      task="<file_n> 생성 (templates/<n>.tpl 사용)",
      context_paths=["skill/init-ai-ready-project/templates/<n>.tpl",
                     "skill/init-ai-ready-project/references/placeholder-spec.md"],
      success_criteria="placeholder 모두 치환, 파일 생성 성공")

# Phase 3 — Verify
Agent(subagent_type="review-strict",
      task="스캐폴드 무결성 검증 (opencode 타깃)",
      context_paths=["<root>/AGENTS.md", "<root>/opencode.json", "<root>/docs/ai-context/"],
      success_criteria="
        - 12개 파일 + 5개 디렉터리 모두 존재
        - AGENTS.md ≤200줄, docs/ai-context/* 포인터 포함
        - CONTEXT.md 존재 (프로젝트 루트)
        - deny-patterns.md의 ❌ 마커 ≥8개
        - non-obvious.md에 '아직 비어 있음' 텍스트
        - opencode.json node로 파싱 성공 + permission.bash에 'rm -rf *'/'rm -fr *'/'git push --force *'/'npm publish*'/'yarn publish*' = deny (bash-형태 보편 명령 하드 차단; 전체 deny-patterns 정책은 advisory)
        - state.json schema_version=1, cycle.count=0
        - placeholder 잔존 0 (`grep -rE '{{[^}]+}}'` 결과 없음)
        - .gitignore ≥15줄
        - scripts/check.sh 존재 + 실행권한
        - .github/workflows/ci.yml 존재
        - docs/ai-context/runbook.md에 'Local Quality Gate' + 'Merge Policy' 섹션 존재
      ")

Phase 3 통과 못 하면 사용자에게 보고하고 재시도.

# Phase 4 — Closing
사용자 안내:
> 부트스트랩 완료. `opencode.json` provider/model을 내부 LLM로 설정 후 첫 사이클 시작.
> scripts/check.sh로 로컬 gate 확인. 예: "결제 모듈 만들어줘" → start-rpi-cycle 발동.
> deny-gate(`opencode.json` permission.bash, 네이티브)는 **bash-형태 보편 파괴 명령만** 하드 차단하는
> best-effort 가드(샌드박스 아님). 전체 금지 정책(SQL·prod·컨텍스트 git)은 deny-patterns.md = advisory(리뷰·전역 게이트).

## Communication Protocol
- result: COMPLETE / FAIL
- evidence: 생성된 파일 경로 목록 + Phase 3 검증 결과 요약
- unknowns: 사용자에게 추가 입력 권고 (예: STACK 미감지 시 수동 입력)

## 일관성 강제
파일 생성은 반드시 templates/*.tpl + 변수 치환만 사용한다. 자유 기술 금지. 새 섹션 추가 금지. 누락 금지.
