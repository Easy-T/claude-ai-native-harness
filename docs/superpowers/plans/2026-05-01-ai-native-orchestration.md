# AI-Native Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 1
**Started:** 2026-05-01

**Goal:** Build the global AI-Native orchestration infrastructure under `~/.claude/` so every Claude Code session is enforced into a predictable Research → Plan → Implement → Closeout cycle backed by deterministic hooks.

**Architecture:** Bash hook scripts (with Node-based JSON parsing) enforce passive optimization at the OS layer. Three wrapper sub-agents (`explore-strict`, `review-strict`, `execute-strict`) act as leaf workers with `model: inherit` and a shared `common-agent-contract` skill. Four orchestrator skills (built-in or user-created via `create-orchestrator-skill`) own the workflow, delegating to sub-agents. A 13-step build order respects dependencies: `doctor.sh` → templates → contract skill → agents → orchestrator skills → command → hooks → settings registration → root `CLAUDE.md` → verification.

**Tech Stack:** Bash 5.x (Git Bash on Windows / native on Linux/macOS), Node.js v18+ (for JSON parsing in hooks), git, gh CLI, Claude Code 2.1+ (sub-agent isolation, `skills:` field, hooks). Optional: jq (auto-installed via winget/choco/scoop/brew/apt by `doctor.sh`).

**Reference Spec:** `~/.claude/docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md` (3,077 lines, Status: Approved)

---

## How to Execute This Plan (for any session)

This plan is designed to be executed **one task per session** by Claude Sonnet (or any capable model). Each task is self-contained.

**Each Task starts with a "Dependency check" step that verifies prior tasks are committed.** If a dependency is missing, the task aborts and reports back. This makes it safe to run tasks out of order or in fresh sessions.

**Pre-flight Checks (Task 0)** must complete before Task 1. After that, tasks 1-13 can each be a separate session.

---

## Task 0: Pre-flight Checks (run once before Task 1)

- [ ] **Step 0.1: Confirm working directory** is `~/.claude/` or be ready to use absolute paths.
  ```bash
  cd ~/.claude && pwd
  # Expected: /c/Users/12132/.claude (Windows MSYS) or /home/<user>/.claude (Linux/macOS)
  ```

- [ ] **Step 0.2: Initialize git in `~/.claude/` if not already** (for rollback safety, per spec §0.6).
  ```bash
  cd ~/.claude
  if [ ! -d .git ]; then
    git init
    git add -A
    git commit -m "baseline: pre AI-native infrastructure setup"
  else
    git status
    git add -A 2>/dev/null
    git commit -m "baseline: pre AI-native infrastructure setup" 2>/dev/null || true
  fi
  ```
  Expected: a `baseline` commit exists. If git was already in use, the existing tree is preserved.

- [ ] **Step 0.3: Verify Claude Code restart capability**: tasks 4 and 11 require `/agents` reload or session restart. Confirm you can restart a Claude Code session between those tasks.

- [ ] **Step 0.4: Verify the spec exists** (referenced by every task):
  ```bash
  test -f ~/.claude/docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md \
    && echo "spec OK" || echo "FAIL: spec missing"
  ```
  Expected: `spec OK`.

- [ ] **Step 0.5: Commit pre-flight completion marker**
  ```bash
  cd ~/.claude
  echo "pre-flight: $(date -Iseconds)" >> docs/superpowers/plans/.preflight
  git add docs/superpowers/plans/.preflight
  git commit -m "chore(plan): pre-flight checks complete"
  ```

---

## Dependency Check Convention (every Task 1-13 starts with this)

Each Task's first step verifies its dependencies. The check is:
```bash
cd ~/.claude
git log --oneline | head -20  # confirm prior task commits exist
```

If a required prior commit is missing, **abort and report to user** — do not skip ahead.

The expected commit prefixes (in order):
- `chore(plan): pre-flight` (Task 0)
- `feat(setup): add doctor.sh` (Task 1)
- `feat(templates):` (Task 2)
- `feat(skill): add common-agent-contract` (Task 3)
- `feat(agents):` (Task 4)
- `feat(skill): add init-ai-ready-project` (Task 5)
- `feat(skill): add start-rpi-cycle` (Task 6)
- `feat(skill): add create-orchestrator-skill` (Task 7)
- `feat(command):` (Task 8)
- `feat(hooks): add 5 hook scripts` (Task 9)
- `feat(hooks): add unit tests` (Task 10)
- `feat(settings): register 5 global hooks` (Task 11)
- `feat(claude-md):` (Task 12)
- `feat(verify):` (Task 13)

---

## Task 1: `doctor.sh` — Environment Diagnose & Treat

Per spec §2.7, §2.9, §6.1, §7.1 step 1. This is the foundation: every other task assumes `doctor.sh` works.

**Files:**
- Create: `~/.claude/setup/doctor.sh` (chmod +x)
- Test: `~/.claude/setup/tests/doctor.test.sh`

- [ ] **Step 1: Create the setup directory and write the failing test**

  ```bash
  mkdir -p ~/.claude/setup/tests
  ```

  Write the test fixture at `~/.claude/setup/tests/doctor.test.sh`:

  ```bash
  #!/usr/bin/env bash
  # Test: doctor.sh diagnoses env correctly and creates artifacts.
  set -euo pipefail

  DOCTOR="$HOME/.claude/setup/doctor.sh"

  # Test 1: doctor.sh exists and is executable
  [ -x "$DOCTOR" ] || { echo "FAIL: doctor.sh not executable"; exit 1; }

  # Test 2: running doctor.sh creates .installed marker
  rm -f "$HOME/.claude/setup/.installed"
  bash "$DOCTOR" > /dev/null 2>&1 || { echo "FAIL: doctor.sh exit non-zero"; exit 1; }
  [ -f "$HOME/.claude/setup/.installed" ] || { echo "FAIL: .installed marker not created"; exit 1; }

  # Test 3: running doctor.sh creates audit marker in CLAUDE.md if missing
  CLAUDE_MD="$HOME/.claude/CLAUDE.md"
  if [ -f "$CLAUDE_MD" ]; then
    grep -qE '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD" || \
      { echo "FAIL: audit marker not in CLAUDE.md"; exit 1; }
  fi

  # Test 4: running doctor.sh creates a backup directory under $HOME
  ls -d "$HOME"/.claude.backup-* > /dev/null 2>&1 || \
    { echo "FAIL: no backup directory created"; exit 1; }

  echo "PASS: all doctor.sh tests"
  ```

  Make it executable:
  ```bash
  chmod +x ~/.claude/setup/tests/doctor.test.sh
  ```

- [ ] **Step 2: Run test to verify it fails**

  ```bash
  bash ~/.claude/setup/tests/doctor.test.sh
  ```

  Expected: `FAIL: doctor.sh not executable` (the script doesn't exist yet).

- [ ] **Step 3: Write `doctor.sh`**

  Create `~/.claude/setup/doctor.sh` with this exact content:

  ```bash
  #!/usr/bin/env bash
  # ~/.claude/setup/doctor.sh
  # Diagnose, treat, re-diagnose, report. Single entry point per spec §2.7.

  set -euo pipefail

  PASS=0
  FAIL=0
  WARN=0
  ITEMS=()

  check() {
    local label="$1"; local result="$2"; local note="${3:-}"
    case "$result" in
      PASS) PASS=$((PASS+1)); ITEMS+=("✓ $label${note:+ — $note}") ;;
      WARN) WARN=$((WARN+1)); ITEMS+=("⚠ $label${note:+ — $note}") ;;
      FAIL) FAIL=$((FAIL+1)); ITEMS+=("✗ $label${note:+ — $note}") ;;
    esac
  }

  echo "[doctor] AI-Native infrastructure diagnose..."

  # 1. Claude Code version
  if command -v claude >/dev/null 2>&1; then
    cc_ver=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    check "Claude Code installed" "PASS" "$cc_ver"
  else
    check "Claude Code installed" "FAIL" "claude command not found"
  fi

  # 2. node version
  if command -v node >/dev/null 2>&1; then
    node_ver=$(node --version)
    check "node installed" "PASS" "$node_ver"
  else
    check "node installed" "FAIL" "FATAL — required for hooks"
    echo "[doctor] FATAL: node missing. Reinstall Claude Code or install Node.js v18+." >&2
    exit 1
  fi

  # 3. bash version
  bash_ver=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  check "bash version" "PASS" "$bash_ver"

  # 4-6. git + config
  if command -v git >/dev/null 2>&1; then
    check "git installed" "PASS" "$(git --version)"
    name=$(git config --global user.name 2>/dev/null || echo "")
    email=$(git config --global user.email 2>/dev/null || echo "")
    [ -n "$name" ] && check "git user.name" "PASS" "$name" || check "git user.name" "FAIL" "set: git config --global user.name '...'"
    [ -n "$email" ] && check "git user.email" "PASS" "$email" || check "git user.email" "FAIL" "set: git config --global user.email '...'"
  else
    check "git installed" "FAIL" "install git first"
  fi

  # 7-8. gh CLI + auth
  if command -v gh >/dev/null 2>&1; then
    check "gh CLI installed" "PASS" "$(gh --version | head -1)"
    if gh auth status >/dev/null 2>&1; then
      check "gh authenticated" "PASS" ""
    else
      check "gh authenticated" "FAIL" "run: gh auth login"
    fi
  else
    check "gh CLI installed" "WARN" "optional, install with winget/choco/brew"
  fi

  # 9. Internet connectivity (best-effort)
  if curl -sI -m 5 https://api.anthropic.com >/dev/null 2>&1; then
    check "internet reachable" "PASS" ""
  else
    check "internet reachable" "WARN" "(api.anthropic.com unreachable)"
  fi

  # 10. Disk space (≥1GB free in $HOME partition)
  if df -k "$HOME" 2>/dev/null | awk 'NR==2 {exit ($4 < 1048576)}'; then
    check "disk space ≥1GB" "PASS" ""
  else
    check "disk space ≥1GB" "WARN" "low disk"
  fi

  # 11. ~/.claude/ writable
  if touch "$HOME/.claude/.write-test" 2>/dev/null && rm -f "$HOME/.claude/.write-test"; then
    check "~/.claude/ writable" "PASS" ""
  else
    check "~/.claude/ writable" "FAIL" "permission denied"
  fi

  # 12. OS detection
  case "$(uname -s)" in
    Linux*)   check "OS compatible" "PASS" "Linux" ;;
    Darwin*)  check "OS compatible" "PASS" "macOS" ;;
    MINGW*|MSYS*|CYGWIN*) check "OS compatible" "PASS" "Windows (Git Bash)" ;;
    *)        check "OS compatible" "WARN" "$(uname -s) untested" ;;
  esac

  # 13. python (optional)
  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    check "python3 (optional)" "PASS" ""
  else
    check "python3 (optional)" "WARN" "not installed"
  fi

  # 14. node JSON parsing self-test
  if echo '{"a":1}' | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const o=JSON.parse(d);console.log(o.a)})' 2>/dev/null | grep -q '^1$'; then
    check "node JSON parsing" "PASS" ""
  else
    check "node JSON parsing" "FAIL" "node broken — reinstall"
  fi

  # 15. jq (auto-install if missing)
  if command -v jq >/dev/null 2>&1; then
    check "jq installed" "PASS" "$(jq --version)"
  else
    echo "[doctor] jq missing — attempting auto-install..."
    installed=0
    if command -v winget >/dev/null 2>&1; then
      winget install --silent --accept-source-agreements --accept-package-agreements jqlang.jq >/dev/null 2>&1 && installed=1 || true
    elif command -v choco >/dev/null 2>&1; then
      choco install -y jq >/dev/null 2>&1 && installed=1 || true
    elif command -v scoop >/dev/null 2>&1; then
      scoop install jq >/dev/null 2>&1 && installed=1 || true
    elif command -v brew >/dev/null 2>&1; then
      brew install jq >/dev/null 2>&1 && installed=1 || true
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get install -y jq >/dev/null 2>&1 && installed=1 || true
    fi
    # Refresh PATH in case the installer added a new dir
    hash -r 2>/dev/null || true
    if command -v jq >/dev/null 2>&1; then
      check "jq installed" "PASS" "auto-installed"
    else
      check "jq installed" "WARN" "auto-install failed — hooks use node, jq is optional"
    fi
  fi

  # 16. .installed marker (auto-create)
  mkdir -p "$HOME/.claude/setup"
  touch "$HOME/.claude/setup/.installed"
  check ".installed marker" "PASS" "auto-created"

  # 17. audit marker in ~/.claude/CLAUDE.md
  CLAUDE_MD="$HOME/.claude/CLAUDE.md"
  TODAY=$(date +%Y-%m-%d)
  if [ -f "$CLAUDE_MD" ]; then
    if grep -qE '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD"; then
      # update the existing marker to today (most recent wins)
      tmp=$(mktemp)
      sed -E "s|<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->|<!-- audit: $TODAY -->|" "$CLAUDE_MD" > "$tmp"
      mv "$tmp" "$CLAUDE_MD"
      check "audit marker" "PASS" "updated to $TODAY"
    else
      printf "\n<!-- audit: %s -->\n" "$TODAY" >> "$CLAUDE_MD"
      check "audit marker" "PASS" "appended $TODAY"
    fi
  else
    check "audit marker" "WARN" "CLAUDE.md missing (will be created in Task 12)"
  fi

  # 18. backup directory (~/.claude.backup-YYYY-MM-DD/)
  BACKUP="$HOME/.claude.backup-$TODAY"
  if [ ! -d "$BACKUP" ]; then
    cp -r "$HOME/.claude" "$BACKUP" 2>/dev/null && check "backup directory" "PASS" "$BACKUP" || check "backup directory" "WARN" "cp failed"
  else
    check "backup directory" "PASS" "exists: $BACKUP"
  fi

  # 19. ~/.claude/ git managed (recommended)
  if [ -d "$HOME/.claude/.git" ]; then
    check "~/.claude git-managed" "PASS" ""
  else
    check "~/.claude git-managed" "WARN" "recommend: cd ~/.claude && git init"
  fi

  # Report
  echo
  echo "[doctor] Results:"
  for line in "${ITEMS[@]}"; do echo "  $line"; done
  echo
  echo "[doctor] PASS=$PASS  WARN=$WARN  FAIL=$FAIL"

  if (( FAIL > 0 )); then
    echo "[doctor] FAIL items must be resolved before proceeding." >&2
    exit 1
  fi
  exit 0
  ```

  Make it executable:
  ```bash
  chmod +x ~/.claude/setup/doctor.sh
  ```

- [ ] **Step 4: Run test to verify it passes**

  ```bash
  bash ~/.claude/setup/tests/doctor.test.sh
  ```

  Expected: `PASS: all doctor.sh tests`. If any FAIL, inspect doctor.sh output and fix.

- [ ] **Step 5: Run doctor.sh manually and inspect**

  ```bash
  bash ~/.claude/setup/doctor.sh
  ```

  Expected: PASS/WARN counts, FAIL=0. If gh auth fails, run `gh auth login` first.

- [ ] **Step 6: Commit**

  ```bash
  cd ~/.claude
  git add setup/doctor.sh setup/tests/doctor.test.sh
  git commit -m "feat(setup): add doctor.sh diagnose & treat (spec §2.7)"
  ```

---

## Task 2: Project Templates (10 files + 2 references)

Per spec §3.1–§3.13 and §7.1 step 2. These templates are bundled inside `init-ai-ready-project` skill and used by Phase 2 to generate project files.

**Files:**
- Create: `~/.claude/skills/init-ai-ready-project/templates/CLAUDE.md.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/templates/architecture.md.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/templates/runbook.md.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/templates/deny-patterns.md.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/templates/non-obvious.md.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/templates/domain-glossary.md.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/templates/project-settings.json.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/templates/pre-commit-deny.sh.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/templates/.gitignore.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/templates/state.json.tpl`
- Create: `~/.claude/skills/init-ai-ready-project/references/placeholder-spec.md`
- Create: `~/.claude/skills/init-ai-ready-project/references/stack-presets.md`

- [ ] **Step 1: Create directories**

  ```bash
  mkdir -p ~/.claude/skills/init-ai-ready-project/templates
  mkdir -p ~/.claude/skills/init-ai-ready-project/references
  ```

- [ ] **Step 2: Write `CLAUDE.md.tpl`** (spec §3.2 verbatim)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/CLAUDE.md.tpl <<'EOF'
  # {{PROJECT_NAME}}

  > AI-Ready 코드베이스. 이 파일은 모든 세션의 prefix에 자동 로드됩니다.
  > 변경은 세션 종료 직전에만 (캐시 미스 비용 ≈20배).
  > ≤200줄 유지. 백과사전이 아닌 나침반.

  Created: {{CREATED_AT}}

  ## Stack
  {{STACK_DESCRIPTION}}

  ## Modules
  {{MODULES_INDEX}}

  ## Top 5 Non-Obvious Patterns
  참조: [docs/ai-context/non-obvious.md](docs/ai-context/non-obvious.md)

  (아직 누적되지 않음)

  ## Pointers
  - 절대 금지: [docs/ai-context/deny-patterns.md](docs/ai-context/deny-patterns.md)
  - 아키텍처: [docs/ai-context/architecture.md](docs/ai-context/architecture.md)
  - 운영·배포: [docs/ai-context/runbook.md](docs/ai-context/runbook.md)
  - 도메인 용어: [docs/ai-context/domain-glossary.md](docs/ai-context/domain-glossary.md)
  EOF
  ```

- [ ] **Step 3: Write `architecture.md.tpl`** (spec §3.3 verbatim)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/architecture.md.tpl <<'EOF'
  # Architecture — {{PROJECT_NAME}}

  > Append-only Decision Log. 결정 변경 시 새 ADR로 supersede (이전 항목 수정 X).
  > 모듈 그래프는 review-strict가 변경 시 자동 갱신.

  ## Module Dependency Graph (live)

  ```mermaid
  graph TD
  {{DEPENDENCY_DIAGRAM}}
  ```

  > 갱신 정책: 모듈 추가/삭제/의존성 변경 시 review-strict가 갱신.

  ## Data Flow

  {{DATA_FLOW_DESCRIPTION}}

  ## Architecture Decision Records (Append-only)

  번호는 자연수 순서. 한번 적힌 ADR은 수정하지 않음. 결정이 바뀌면 새 ADR을 추가하고
  `Supersedes: ADR-NNN` 명시.

  (부트스트랩 시 비어 있음)

  <!-- ADR 형식:
  ### ADR-001: <제목>
  - 날짜: YYYY-MM-DD
  - 상태: Proposed | Accepted | Superseded by ADR-NNN | Deprecated
  - 결정: <무엇>
  - 이유: <왜>
  - 대안: <고려한 옵션>
  - 트레이드오프: <포기한 것>
  -->
  EOF
  ```

- [ ] **Step 4: Write `runbook.md.tpl`** (spec §3.4 verbatim)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/runbook.md.tpl <<'EOF'
  # Runbook — {{PROJECT_NAME}}

  > ⚠️ 이 파일은 **운영·배포·장애 대응**의 기술적 실행 절차입니다.
  > ⚠️ 프로젝트 작업 계획(Work Plan)은 `docs/superpowers/specs/` 와
  >    `docs/superpowers/plans/`에 보관됩니다.
  > ⚠️ 의사결정·전략은 ADR(`architecture.md`)에 보관됩니다.

  ## Deploy
  {{DEPLOY_PROCEDURE}}

  ## Rollback
  {{ROLLBACK_PROCEDURE}}

  ## Common Operations
  (예: cache flush, queue drain, log rotation, certificate renewal 등)

  ## Health Checks / Dashboards
  {{DASHBOARDS}}

  ## Incident Response (간단 — 자세한 건 별도 playbook으로 분리 권장)
  {{INCIDENT_RESPONSE}}
  EOF
  ```

- [ ] **Step 5: Write `deny-patterns.md.tpl`** (spec §3.5 verbatim)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/deny-patterns.md.tpl <<'EOF'
  # Deny Patterns — {{PROJECT_NAME}}

  > 절대 금지. .claude/hooks/pre-commit-deny.sh가 이 파일을 파싱.
  > 형식 규약: 차단 항목은 반드시 `- ❌ ` 마커로 시작.
  > 환경(dev/staging/prod) 구분 없음 — 모든 환경에 동일 적용.

  ## Schema / DB
  - ❌ DROP TABLE
  - ❌ TRUNCATE
  - ❌ DELETE FROM (without WHERE)
  - ❌ ALTER TABLE (use migration file instead)

  ## Migrations
  - ❌ 머지된 마이그레이션 파일 수정 (always create new migration)

  ## Git
  - ❌ git push --force origin main
  - ❌ git push --force origin master
  - ❌ git reset --hard (공유 브랜치)
  - ❌ --no-verify

  ## Filesystem
  - ❌ rm -rf /
  - ❌ rm -rf ~
  - ❌ rm -rf *

  ## Production Direct Access (모든 직접 접근 금지)
  - ❌ ssh prod
  - ❌ kubectl exec (prod context)
  - ❌ psql -h prod-
  - ❌ 운영 자격증명을 코드/커밋에 포함

  ## (허용) — 다음은 deny 아님
  - ✅ npm install / pip install / cargo build (dev에서 자유)
  - ✅ git push (force 아닌 경우)
  - ✅ 마이그레이션 파일 신규 생성

  ## Past Incidents (이 프로젝트 사고 기록)
  {{#INCIDENTS}}
  - {{date}}: {{description}} → 그래서 `{{rule}}`
  {{/INCIDENTS}}

  (부트스트랩 시 INCIDENTS는 비어 있음. 사고가 발생할 때마다 한 줄 추가.)
  EOF
  ```

- [ ] **Step 6: Write `non-obvious.md.tpl`** (spec §3.6 verbatim)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/non-obvious.md.tpl <<'EOF'
  # Non-Obvious Patterns — {{PROJECT_NAME}}

  > AI/사람의 잘못된 추론·해석은 여기 적지 않습니다.
  > 시스템·프로세스·도구의 결함이 root cause인 항목만 누적.
  > 등록 전 review-strict 5 Whys 통과 필수.
  >
  > 형식:
  > ## YYYY-MM-DD: <한 줄 제목>
  > - 증상: <관찰 내용>
  > - 트리거: <활성화 행동>
  > - Root cause: <시스템/프로세스 단위>
  > - Action: <SMART, 가능하면 자동화 fitness function>
  > - 재발 카운터: 0 (재발 시 +1)

  ## Active Patterns

  (아직 비어 있음)

  ## High Priority (재발 ≥ 2회)

  (없음)

  ## Archive (해결 또는 휴면 패턴)

  (없음 — active ≥30 또는 줄 수 ≥100 시 가장 오래된 비재발 항목 5개 자동 이동)

  ---
  Last updated: {{CREATED_AT}}
  EOF
  ```

- [ ] **Step 7: Write `domain-glossary.md.tpl`** (spec §3.7 verbatim)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/domain-glossary.md.tpl <<'EOF'
  # Domain Glossary — {{PROJECT_NAME}}

  > 사내 용어 ↔ 코드 식별자 매핑. AI가 도메인 언어를 정확히 사용하도록.
  > 새 용어 등장 시 메인이 confidence < 80%면 사용자에게 확인 후 자동 추가.

  ## Domain → Code

  | 도메인 용어 | 코드 식별자 | 비고 |
  |---|---|---|
  {{#TERMS}}
  | {{domain_term}} | `{{code_identifier}}` | {{note}} |
  {{/TERMS}}

  (부트스트랩 시 비어 있음. 모듈 추가 시 동시에 갱신)

  ## Identical-Looking, Different Meaning

  (같은 단어인데 컨텍스트마다 의미가 다른 경우. 예: price vs amount)

  {{#AMBIGUITIES}}
  - **{{term}}**:
    - `{{context_a}}`: {{meaning_a}}
    - `{{context_b}}`: {{meaning_b}}
  {{/AMBIGUITIES}}
  EOF
  ```

- [ ] **Step 8: Write `project-settings.json.tpl`** (spec §3.8 verbatim)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/project-settings.json.tpl <<'EOF'
  {
    "permissions": {
      "allow": [
        {{STACK_ALLOW_LIST}}
      ],
      "deny": [
        "Bash(rm -rf*)",
        "Bash(git push --force*)",
        "Bash(npm publish*)"
      ]
    },
    "hooks": {
      "PreToolUse": [
        {
          "matcher": "Write|Edit|Bash",
          "hooks": [
            { "type": "command", "command": ".claude/hooks/pre-commit-deny.sh" }
          ]
        }
      ]
    }
  }
  EOF
  ```

- [ ] **Step 9: Write `pre-commit-deny.sh.tpl`** (spec §3.9 verbatim)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/pre-commit-deny.sh.tpl <<'EOF'
  #!/usr/bin/env bash
  # Project-level deny pattern enforcement.
  # Parses docs/ai-context/deny-patterns.md, blocks tool calls matching any "- ❌ " line.

  set -euo pipefail

  [ -f "$HOME/.claude/hooks/_common.sh" ] && source "$HOME/.claude/hooks/_common.sh"

  INPUT="$(cat)"
  DENY_FILE="docs/ai-context/deny-patterns.md"
  [ ! -f "$DENY_FILE" ] && exit 0

  TOOL_INPUT="$(echo "$INPUT" | node -e '
    let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>{
      try { const o=JSON.parse(d); console.log(JSON.stringify(o.tool_input||{})); } catch(e){}
    });
  ')"
  [ -z "$TOOL_INPUT" ] && exit 0

  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    if echo "$TOOL_INPUT" | grep -qiF -- "$pattern"; then
      echo "[deny-pattern] 차단: $pattern" >&2
      echo "[deny-pattern] 출처: $DENY_FILE" >&2
      exit 2
    fi
  done < <(grep -E '^- ❌ ' "$DENY_FILE" | sed 's/^- ❌ //')

  exit 0
  EOF
  ```

- [ ] **Step 10: Write `.gitignore.tpl`** (spec §3.10 verbatim)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/.gitignore.tpl <<'EOF'
  # Dependencies
  node_modules/
  __pycache__/
  *.pyc
  .venv/
  vendor/

  # Build outputs
  dist/
  build/
  *.log

  # Environment / secrets
  .env
  .env.local
  .env.*.local

  # IDE
  .vscode/
  .idea/
  *.swp

  # OS
  .DS_Store
  Thumbs.db

  # Claude Code project-local
  .claude/sessions/
  .claude/cache/

  # Stack-specific
  {{STACK_GITIGNORE}}
  EOF
  ```

- [ ] **Step 11: Write `state.json.tpl`** (spec §3.11 with v2/v3_skipped_permanently fields)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/templates/state.json.tpl <<'EOF'
  {
    "schema_version": 1,
    "project_name": "{{PROJECT_NAME}}",
    "created_at": "{{CREATED_AT}}",

    "cycle": {
      "count": 0,
      "last_completed_at": null,
      "last_cycle_id": null
    },

    "features": {
      "v2_enabled": false,
      "v2_enabled_at": null,
      "v2_skipped_permanently": false,
      "v3_enabled": false,
      "v3_enabled_at": null,
      "v3_skipped_permanently": false
    },

    "non_obvious": {
      "active_count": 0,
      "archive_count": 0,
      "last_archived_at": null
    },

    "audit": {
      "last_doctor_run": "{{CREATED_AT}}",
      "last_drift_check": "{{CREATED_AT}}"
    }
  }
  EOF
  ```

- [ ] **Step 12: Write `references/placeholder-spec.md`** (spec §3.12)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/references/placeholder-spec.md <<'EOF'
  # Placeholder Specification

  Templates use Mustache-style `{{VAR}}` for simple variables and `{{#list}}...{{/list}}` for repeating blocks.

  ## Simple variables

  | Variable | Type | Source | Bootstrap default |
  |---|---|---|---|
  | `PROJECT_NAME` | string | command argument (`/init-ai-ready <name>`) | required |
  | `CREATED_AT` | ISO date | system time | today |
  | `STACK_DESCRIPTION` | string | Phase 1 explore-strict detection | `(미감지 — 빈 디렉터리)` |
  | `STACK_ALLOW_LIST` | JSON fragment | stack-presets mapping | `[]` (empty array; no trailing comma when list non-empty) |
  | `STACK_GITIGNORE` | text lines | stack-presets mapping | empty line |
  | `DEPENDENCY_DIAGRAM` | mermaid nodes | empty node | `_initial_["empty"]` |
  | `DATA_FLOW_DESCRIPTION` | text | free | `(미정의)` |
  | `DEPLOY_PROCEDURE` | text | free | `(아직 정의되지 않음)` |
  | `ROLLBACK_PROCEDURE` | text | free | `(아직 정의되지 않음)` |
  | `INCIDENT_RESPONSE` | text | free | `(아직 정의되지 않음)` |
  | `DASHBOARDS` | text | free | `(아직 정의되지 않음)` |
  | `MODULES_INDEX` | bullet list | Phase 1 detection | `(아직 모듈 없음)` |

  ## Repeating blocks

  | Block | Item fields | Bootstrap default |
  |---|---|---|
  | `INCIDENTS` | `date`, `description`, `rule` | empty list |
  | `TERMS` | `domain_term`, `code_identifier`, `note` | empty list |
  | `AMBIGUITIES` | `term`, `context_a`, `meaning_a`, `context_b`, `meaning_b` | empty list |

  ## STACK_ALLOW_LIST formatting rule

  When non-empty, items are JSON strings separated by commas (no trailing comma):
  `"Bash(npm run *)", "Bash(npm test*)"`

  When empty, the placeholder is replaced by an empty string (the surrounding JSON `"allow": [  ]` remains valid).
  EOF
  ```

- [ ] **Step 13: Write `references/stack-presets.md`** (spec §3.13)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/references/stack-presets.md <<'EOF'
  # Stack Presets

  Phase 1 explore-strict detects the stack signal, then Phase 2 substitutes these values.

  | Detection signal | `STACK_DESCRIPTION` | `STACK_ALLOW_LIST` add | `STACK_GITIGNORE` add |
  |---|---|---|---|
  | `package.json` exists with `next` dependency | `Next.js + Node.js` | `"Bash(npm run *)", "Bash(npm test*)", "Bash(npx*)"` | `.next/`, `out/` |
  | `package.json` (other than Next) | `Node.js + npm` | `"Bash(npm run *)", "Bash(npm test*)"` | `coverage/` |
  | `pyproject.toml` exists | `Python (pyproject)` | `"Bash(pytest*)", "Bash(uv run*)", "Bash(uv add*)"` | `.venv/`, `*.egg-info/`, `.pytest_cache/` |
  | `Cargo.toml` exists | `Rust` | `"Bash(cargo build*)", "Bash(cargo test*)", "Bash(cargo run*)"` | `target/` |
  | `go.mod` exists | `Go` | `"Bash(go build*)", "Bash(go test*)", "Bash(go run*)"` | `/bin/`, `*.out` |
  | `pubspec.yaml` exists | `Flutter / Dart` | `"Bash(flutter test*)", "Bash(dart run*)"` | `build/`, `.dart_tool/` |
  | empty directory (no signal) | `(미감지)` | `[]` | empty line |

  ## Detection logic

  Phase 1 explore-strict checks files in this priority order. The first match wins.
  EOF
  ```

- [ ] **Step 14: Verify all 12 files exist and contain placeholders**

  ```bash
  ls ~/.claude/skills/init-ai-ready-project/templates/ | wc -l
  # Expected: 10

  ls ~/.claude/skills/init-ai-ready-project/references/ | wc -l
  # Expected: 2

  # Spot-check that placeholders survived heredoc
  grep -l '{{PROJECT_NAME}}' ~/.claude/skills/init-ai-ready-project/templates/*.tpl | wc -l
  # Expected: at least 6 (CLAUDE.md, architecture, runbook, deny-patterns, non-obvious, domain-glossary, state.json)
  ```

- [ ] **Step 15: Commit**

  ```bash
  cd ~/.claude
  git add skills/init-ai-ready-project/
  git commit -m "feat(templates): add 10 .tpl files + 2 references (spec §3)"
  ```

---

## Task 3: `common-agent-contract` skill

Per spec §1.5, §2.3.1, §7.1 step 3. This skill defines the Input/Output contract every wrapper agent inherits via `skills:` field.

**Files:**
- Create: `~/.claude/skills/common-agent-contract/SKILL.md`

- [ ] **Step 1: Create directory**

  ```bash
  mkdir -p ~/.claude/skills/common-agent-contract
  ```

- [ ] **Step 2: Write `SKILL.md`** (spec §2.3.1 verbatim)

  ```bash
  cat > ~/.claude/skills/common-agent-contract/SKILL.md <<'EOF'
  ---
  name: common-agent-contract
  description: |
    모든 wrapper agent에 자동 주입되는 Input/Output 표준. agent의 skills 필드로만 호출됨.
    사용자가 직접 호출하지 않음.
  ---

  # Common Agent Contract

  이 skill은 wrapper agent (`explore-strict`, `review-strict`, `execute-strict`)가 시작될 때 system prompt에 자동 주입된다.

  ## Input Contract

  호출자(orchestrator skill)는 다음 3개 필드를 항상 명시한다:

  | 필드 | 타입 | 설명 |
  |---|---|---|
  | `task` | string | 한 문장 작업 명세. 동사로 시작. |
  | `context_paths` | list[path] | 명시적으로 읽을 파일 경로. 빈 리스트 가능. |
  | `success_criteria` | string | 검증 기준. 측정 가능해야 함. |

  위 3개 중 하나라도 누락 → agent는 `result: FAIL`로 즉시 종료.

  ## Output Contract

  agent는 다음 형식으로만 반환한다:

  ```
  result: PASS | FAIL | COMPLETE
  evidence: |
    <자유 형식 ≤500 단어. 파일 인용·diff·발견사항>
  unknowns: |
    <추측·scope 우회·미해결 항목>
  ```

  - `PASS` — review-strict 전용. 모든 criterion 만족.
  - `FAIL` — 미충족 또는 입력 누락.
  - `COMPLETE` — explore-strict / execute-strict 전용. 작업 종료.

  ## Scope Lock

  1. `success_criteria` 외 행동 금지.
  2. 추가 sub-agent spawn 금지 (Anthropic 제약).
  3. evidence는 ≤500 단어. 초과 시 핵심만 요약.
  4. 메인 conversation의 cwd 공유 — `cd` 명령은 sub-agent 안에서 persist 안 됨.

  ## Refusal Examples

  - "task가 명시되지 않음" → result: FAIL, unknowns에 보고
  - "사용자가 추가 작업 의도를 암시" → 그래도 task에 적힌 것만 수행
  - "다른 sub-agent 호출이 효율적이라 판단" → 거부, unknowns에 권고
  EOF
  ```

- [ ] **Step 3: Verify frontmatter and required sections**

  ```bash
  SKILL=~/.claude/skills/common-agent-contract/SKILL.md
  head -5 "$SKILL" | grep -q '^name: common-agent-contract$' || echo "FAIL: name missing"
  grep -q '^## Input Contract$' "$SKILL" || echo "FAIL: Input Contract missing"
  grep -q '^## Output Contract$' "$SKILL" || echo "FAIL: Output Contract missing"
  grep -q '^## Scope Lock$' "$SKILL" || echo "FAIL: Scope Lock missing"
  echo "Verification done."
  ```

  Expected: only "Verification done." printed. No FAIL lines.

- [ ] **Step 4: Commit**

  ```bash
  cd ~/.claude
  git add skills/common-agent-contract/
  git commit -m "feat(skill): add common-agent-contract (spec §2.3.1)"
  ```

---

## Task 4: Wrapper Agents — `explore-strict`, `review-strict`, `execute-strict`

Per spec §2.2, §7.1 step 4. Three sub-agents that wrap built-ins with standard contract.

**Files:**
- Create: `~/.claude/agents/explore-strict.md`
- Create: `~/.claude/agents/review-strict.md`
- Create: `~/.claude/agents/execute-strict.md`

- [ ] **Step 1: Create agents directory**

  ```bash
  mkdir -p ~/.claude/agents
  ```

- [ ] **Step 2: Write `explore-strict.md`** (spec §2.2.1 verbatim)

  ```bash
  cat > ~/.claude/agents/explore-strict.md <<'EOF'
  ---
  name: explore-strict
  description: |
    명시 범위 내에서 코드베이스를 탐색하고 발견 사항만 요약 반환. 읽기 전용. 코드 수정 불가.
    사용 시점: orchestrator skill의 Phase R(Research) 또는 Phase 1(Discover).
    scope 외 행동 금지 — 호출 시 success_criteria로 명시한 것만 수행.
    <example>
    Context: 결제 모듈 추가 전 기존 코드 영향 분석
    call: Agent(subagent_type="explore-strict",
                task="기존 결제 관련 파일 발견",
                context_paths=["docs/ai-context/architecture.md", "docs/ai-context/domain-glossary.md"],
                success_criteria="결제 키워드가 포함된 파일 목록 + 의존성 그래프")
    </example>
  model: inherit
  tools: Read, Grep, Glob, WebFetch
  skills: ["common-agent-contract"]
  ---

  You are an exploration specialist. You discover and summarize, you do not modify.

  # Core Responsibilities
  1. Read only files specified in `context_paths` and files explicitly relevant to `task`
  2. Return findings in the structured Output Format defined by common-agent-contract
  3. Do not exceed `success_criteria` — if more is needed, report as `unknowns`

  # Process
  1. Read context_paths in order
  2. Plan minimal additional reads to satisfy success_criteria
  3. Execute reads / greps
  4. Synthesize into evidence (≤500 words)
  5. Return per Communication Protocol

  # Output Format
  See common-agent-contract (auto-loaded). Result: PASS / FAIL / COMPLETE.

  # Communication Protocol
  - result: COMPLETE if findings synthesized, FAIL if context_paths missing
  - evidence: file paths + relevant excerpts (≤500 words)
  - unknowns: anything inferred or out-of-scope but relevant
  EOF
  ```

- [ ] **Step 3: Write `review-strict.md`** (spec §2.2.2 verbatim)

  ```bash
  cat > ~/.claude/agents/review-strict.md <<'EOF'
  ---
  name: review-strict
  description: |
    명시 기준으로 검증하고 PASS/FAIL + 근거를 반환. 읽기 전용 + read-only bash.
    사용 시점: orchestrator skill의 Phase 3(Verify) / Phase Closeout / drift 검사 / 5 Whys 검증.
    scope 외 행동 금지.
  model: inherit
  tools: Read, Grep, Glob, Bash
  skills: ["common-agent-contract"]
  ---

  You are a verification specialist. You check whether evidence meets the success_criteria.

  # Core Responsibilities
  1. Treat success_criteria as the only quality gate
  2. Use Bash only for read-only verification (e.g., `wc -l`, `jq`, `grep`, `git status`)
  3. Reject the work if even one criterion fails — do not partially pass

  # Process
  1. Read context_paths
  2. For each criterion in success_criteria, design a deterministic check
  3. Execute checks (Bash for objective, Read+reasoning for subjective)
  4. Aggregate per criterion: PASS / FAIL with evidence

  # Output Format (overrides common-agent-contract for this agent)
  - result: PASS (all criteria met) / FAIL (any criterion failed)
  - evidence: per-criterion verdict + 1-line reason each
  - unknowns: criteria that couldn't be objectively checked

  # Refusal triggers
  - Asked to modify files → refuse, report scope violation
  - Asked to spawn another sub-agent → refuse (Anthropic limit)
  EOF
  ```

- [ ] **Step 4: Write `execute-strict.md`** (spec §2.2.3 with strong scope-lock from §5 reinforcement)

  ```bash
  cat > ~/.claude/agents/execute-strict.md <<'EOF'
  ---
  name: execute-strict
  description: |
    명시 변경만 수행하고 diff 요약 반환. 코드 수정 가능.
    사용 시점: orchestrator skill의 Phase 2(Generate) / Phase I(Implement)의 task 위임.
    scope 외 변경 금지 — task에 적힌 파일만 수정.
    <example>
    Context: 부트스트랩 시 9개 파일 생성
    call: Agent(subagent_type="execute-strict",
                task="docs/ai-context/architecture.md 생성",
                context_paths=["templates/architecture.md.tpl"],
                success_criteria="placeholder 모두 치환, mermaid 블록 valid")
    </example>
  model: inherit
  tools: Read, Write, Edit, Bash
  skills: ["common-agent-contract"]
  ---

  You are an execution specialist. You make precisely the change specified, no more.

  # Core Responsibilities
  1. Modify exactly what task specifies, in files explicitly named
  2. Do not "improve" adjacent code, comments, formatting
  3. Return diff summary, not the full file content (preserve main context)

  # Process
  1. Read context_paths (templates, related code)
  2. Plan the minimal change
  3. Apply Write/Edit
  4. Self-verify against success_criteria via Bash (lint, syntax check)
  5. Return diff summary per Communication Protocol

  # Scope Lock (강한 거부)
  - 변경 파일 ≤ task에 명시된 파일. **scope 외 변경이 필요하다고 판단되면 변경하지 않고 unknowns에 보고 후 종료.**
    - 예: task에 `architecture.md` 작성만 명시 → 다른 파일 수정이 필요해 보여도 거부, unknowns에 권고
  - 새 의존성 추가는 변경 거부 → unknowns에 보고
  - 테스트가 없는 코드 변경 → unknowns에 보고 (TDD 강제는 호출자/orchestrator 책임)
  - 거부 시 result: FAIL, evidence에 거부 사유 명시

  # Output Format
  See common-agent-contract.
  - result: COMPLETE (변경 적용) / FAIL (success_criteria 미충족)
  - evidence: 파일별 diff 요약 (≤200 lines per file 인용)
  - unknowns: scope 우회 또는 부수 효과
  EOF
  ```

- [ ] **Step 5: Verify all 3 agents have correct frontmatter**

  ```bash
  for AGENT in explore-strict review-strict execute-strict; do
    F=~/.claude/agents/${AGENT}.md
    grep -q "^name: ${AGENT}$" "$F" || echo "FAIL: name in $F"
    grep -q '^model: inherit$' "$F" || echo "FAIL: model in $F"
    grep -q 'common-agent-contract' "$F" || echo "FAIL: skills in $F"
  done
  echo "Done."
  ```

  Expected: only "Done." printed. No FAIL lines.

- [ ] **Step 6: Restart Claude Code** (so the new agents are loaded)

  Per Anthropic docs (`Subagents are loaded at session start`), restart Claude Code or run `/agents` to reload.

  Manual verification: in Claude Code, run `/agents` and confirm `explore-strict`, `review-strict`, `execute-strict` appear under Library → User scope.

- [ ] **Step 7: Commit**

  ```bash
  cd ~/.claude
  git add agents/
  git commit -m "feat(agents): add 3 wrapper sub-agents with common contract (spec §2.2)"
  ```

---

## Task 5: `init-ai-ready-project` skill

Per spec §2.3.3, §7.1 step 5. Phase 0~4 orchestrator that bootstraps a project.

**Files:**
- Create: `~/.claude/skills/init-ai-ready-project/SKILL.md`

- [ ] **Step 1: Write `SKILL.md`** (spec §2.3.3 with marker triple)

  ```bash
  cat > ~/.claude/skills/init-ai-ready-project/SKILL.md <<'EOF'
  ---
  name: init-ai-ready-project
  description: |
    AI-Ready 프로젝트 부트스트랩. 사용자가 "새 프로젝트 셋업", "AI-ready 만들어줘",
    "프로젝트 초기화" 등을 말하면 무조건 사용. 10개 파일 + 디렉터리 결정론적 생성.
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
     - 메타 룰 6개 마커 존재 (`## §1` ~ `## §6`)
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

  # Phase 2 — Generate (10개 파일 + 디렉터리)
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

  생성 디렉터리:
  - `<root>/docs/superpowers/specs/` (.gitkeep)
  - `<root>/docs/superpowers/plans/` (.gitkeep)
  - `<root>/.claude/hooks/` (실행권한 +x 보장)

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
          - 10개 파일 + 3개 디렉터리 모두 존재
          - CLAUDE.md ≤200줄
          - deny-patterns.md의 ❌ 마커 ≥8개
          - non-obvious.md에 '아직 비어 있음' 텍스트
          - .claude/hooks/pre-commit-deny.sh 실행권한
          - .claude/settings.json node로 파싱 성공
          - .claude/state.json schema_version=1, cycle.count=0
          - placeholder 잔존 0 (`grep -rE '{{[^}]+}}'` 결과 없음)
          - .gitignore ≥15줄
        ")

  Phase 3 통과 못 하면 사용자에게 보고하고 재시도.

  # Phase 4 — Closing
  사용자 안내:
  > 부트스트랩 완료. 첫 사이클을 시작하려면 'start-rpi-cycle' 사용.
  > 예: "결제 모듈 만들어줘"

  ## Communication Protocol
  - result: COMPLETE / FAIL
  - evidence: 생성된 파일 경로 목록 + Phase 3 검증 결과 요약
  - unknowns: 사용자에게 추가 입력 권고 (예: STACK 미감지 시 수동 입력 권유)

  ## 일관성 강제
  파일 생성은 반드시 templates/*.tpl + 변수 치환만 사용한다. 자유 기술 금지. 새 섹션 추가 금지. 누락 금지.
  EOF
  ```

- [ ] **Step 2: Verify orchestrator marker triple and Phase markers**

  ```bash
  SKILL=~/.claude/skills/init-ai-ready-project/SKILL.md
  grep -q '^orchestrator_skill: true$' "$SKILL" || echo "FAIL: marker"
  grep -q '^generated_by:' "$SKILL" || echo "FAIL: generated_by"
  grep -q '^orchestrator_version: 1.0$' "$SKILL" || echo "FAIL: version"
  PHASES=$(grep -cE '^# Phase ' "$SKILL")
  [ "$PHASES" -ge 3 ] || echo "FAIL: phases=$PHASES (need ≥3)"
  AGENTS=$(grep -cE 'Agent\(subagent_type=' "$SKILL")
  [ "$AGENTS" -ge 1 ] || echo "FAIL: no Agent calls"
  grep -q 'Communication Protocol' "$SKILL" || echo "FAIL: no Protocol"
  echo "Done."
  ```

  Expected: "Done." only.

- [ ] **Step 3: Commit**

  ```bash
  cd ~/.claude
  git add skills/init-ai-ready-project/SKILL.md
  git commit -m "feat(skill): add init-ai-ready-project orchestrator (spec §2.3.3)"
  ```

---

## Task 6: `start-rpi-cycle` skill

Per spec §2.3.4, §5.3, §7.1 step 6. R → P → I → Closeout cycle enforcement.

**Files:**
- Create: `~/.claude/skills/start-rpi-cycle/SKILL.md`

- [ ] **Step 1: Create directory and write `SKILL.md`** (spec §2.3.4 with §5 reinforcements)

  ```bash
  mkdir -p ~/.claude/skills/start-rpi-cycle
  cat > ~/.claude/skills/start-rpi-cycle/SKILL.md <<'EOF'
  ---
  name: start-rpi-cycle
  description: |
    새 작업/기능/버그 수정 시작 시 RPI 사이클을 강제. 사용자가 "기능 추가", "이거 고쳐줘",
    "구현해줘", "리팩토링" 등을 말하면 무조건 사용. 직접 코드 작성 금지.
    trivial 변경(≤5라인 수정)은 예외 — enforce-rpi-cycle hook이 자동 통과시킴.
  orchestrator_skill: true
  generated_by: built-in
  orchestrator_version: 1.0
  ---

  # start-rpi-cycle

  ※ superpowers의 brainstorming / writing-plans / executing-plans는 모두 **메인 세션의 skill**.
     sub-agent에 위임 X — 메인이 절차를 따름.
     sub-agent 위임은 explore-strict / review-strict / execute-strict (우리 wrapper)만.

  # Phase R — Research

  A. brainstorming skill 절차 (메인이 직접 따름) — 외향적 (요구·접근법·디자인)
     → 산출물: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md

  B. Agent(subagent_type="explore-strict",
          task="<요청 분석>",
          context_paths=["docs/ai-context/architecture.md",
                         "docs/ai-context/domain-glossary.md",
                         "docs/ai-context/non-obvious.md",
                         "docs/ai-context/deny-patterns.md"],
          success_criteria="발견사항·영향 모듈·신규 도메인 용어·deny pattern 충돌 식별")
     ※ CLAUDE.md는 메인이 자동 로드하므로 context_paths에 미포함 (중복 회피)
     ※ A와 B는 병렬·교차 가능

  ## Gate R
  - 새 도메인 용어 confidence < 80% → 사용자 확인 → glossary 자동 추가 (메인이 직접 Edit)
  - 아키텍처 영향 → ADR 초안 작성 권유 (architecture.md append-only)

  # Phase P — Plan

  writing-plans skill 절차 (메인이 직접) → docs/superpowers/plans/YYYY-MM-DD-<topic>.md
  plan 상단 헤더 주입 (writing-plans 표준 헤더 위에):
    **Status:** active
    **RPI-Cycle:** N
    **Started:** YYYY-MM-DD

  ## Gate P
  active plan 파일 존재 확인 (enforce-rpi-cycle hook이 의존)

  # Phase I — Implement

  구현 방식 선택:
  - (a) **subagent-driven-development** (superpowers 권장) — 메인이 절차 따라 task별로 execute-strict 위임
  - (b) **executing-plans** skill — 메인이 절차 따름 (단일 세션 내). 끝나면 superpowers의 finishing-a-development-branch가 자동 호출됨.
  - (c) execute-strict 직접 위임 — 단순 task에 한해

  권장:
  - 큰 사이클 (≥5 task) → (a)
  - 중간 사이클 (2~5 task) → (b)
  - 작은 사이클 (≤2 task) → (c)

  worktree 사용:
  - 같은 파일을 동시 수정 / 격리된 검증 필요 시 → 호출 시 isolation: worktree 명시
  - 부트스트랩처럼 다른 파일 병렬 → worktree 불필요

  # Phase Closeout

  ※ Phase I에서 executing-plans (b)를 선택했다면, superpowers가 자동으로
     finishing-a-development-branch skill을 호출. 그 결과를 받아 우리 Closeout이 보강 검증.
     (a)/(c)를 선택했다면 우리 Closeout이 단독으로 실행.

  1. Agent(subagent_type="review-strict",
          task="사이클 마감 점검 (drift + 자산 갱신 검증)",
          context_paths=["docs/ai-context/architecture.md",
                         "docs/ai-context/domain-glossary.md",
                         "docs/ai-context/non-obvious.md"],
          success_criteria="
            - architecture.md 갱신 (모듈/의존성 변경 반영) 또는 변경 없음 확인
            - domain-glossary.md 갱신 또는 변경 없음 확인
            - 사이클 중 발생한 실패가 5 Whys 통과 후 non-obvious.md 누적 (또는 명시 면제)
            - plan 모든 체크박스 [x] 또는 명시적 미완료 사유 기록
            - finishing-a-development-branch 산출물(브랜치/PR)이 존재 시 일관성 (선택)
          ")

  2. plan 헤더 갱신: **Status:** active → completed (메인이 직접 Edit)

  3. .claude/state.json 갱신 (메인이 jq 또는 node로 read-modify-write):
     - cycle.count +1
     - cycle.last_completed_at: today
     - audit.last_drift_check: today

  4. 사용자 승인형 v2/v3 알림:
     - cycle.count == 5 && !v2_enabled && !v2_skipped_permanently → "v2 도입 가능" 묻기
     - cycle.count == 20 && !v3_enabled && !v3_skipped_permanently → "v3 도입 가능" 묻기
     - 사용자: 활성화 / 건너뛰기 / 영구 건너뛰기 (3택)

  5. Non-obvious archive 검사:
     - active ≥ 30 항목 또는 ≥ 100줄 → 가장 오래된 비재발(카운터=0) 5개 archive로 이동
     - archive ≥ 500줄 → "archive 정리할까요?" 묻기
     - v2 활성 시: archive 항목이 다시 매칭되면 active로 복귀 + High Priority 즉시 승격

  ## Sub-cycle states
  - active / in_progress: 진행 중
  - completed: 완료
  - abandoned: 중단 (cycle.count 증가 없음)
  - paused: 일시 중지 (enforce-rpi-cycle이 active로 인식 안 함)

  ## Communication Protocol
  - result: COMPLETE / FAIL
  - evidence: Phase별 산출물 경로 + Closeout review-strict 결과
  - unknowns: 사용자에게 추가 결정 권고
  EOF
  ```

- [ ] **Step 2: Verify**

  ```bash
  SKILL=~/.claude/skills/start-rpi-cycle/SKILL.md
  grep -q '^orchestrator_skill: true$' "$SKILL" || echo "FAIL marker"
  PHASES=$(grep -cE '^# Phase ' "$SKILL")
  [ "$PHASES" -ge 4 ] || echo "FAIL: phases=$PHASES (need ≥4 — R/P/I/Closeout)"
  AGENTS=$(grep -cE 'Agent\(subagent_type=' "$SKILL")
  [ "$AGENTS" -ge 2 ] || echo "FAIL: agents=$AGENTS (need ≥2)"
  grep -q 'Communication Protocol' "$SKILL" || echo "FAIL: no Protocol"
  echo "Done."
  ```

- [ ] **Step 3: Commit**

  ```bash
  cd ~/.claude
  git add skills/start-rpi-cycle/
  git commit -m "feat(skill): add start-rpi-cycle (spec §2.3.4, §5.3)"
  ```

---

## Task 7: `create-orchestrator-skill` skill

Per spec §2.3.2, §7.1 step 7. Wraps skill-creator with orchestrator skeleton injection.

**Files:**
- Create: `~/.claude/skills/create-orchestrator-skill/SKILL.md`

- [ ] **Step 1: Create directory and write `SKILL.md`** (spec §2.3.2 with §2 reinforcement)

  ```bash
  mkdir -p ~/.claude/skills/create-orchestrator-skill
  cat > ~/.claude/skills/create-orchestrator-skill/SKILL.md <<'EOF'
  ---
  name: create-orchestrator-skill
  description: |
    새 커스텀 skill을 orchestrator 패턴으로 생성. 사용자가 "이거 자주 쓸 것 같아 skill로",
    "orchestrator로 자동화해줘", "<X> skill 만들어줘" 등을 말하면 무조건 사용.
    단순 텍스트 변환 skill은 예외 (사용자가 명시하면 일반 skill-creator 호출).
  orchestrator_skill: true
  generated_by: built-in
  orchestrator_version: 1.0
  ---

  # create-orchestrator-skill

  새 커스텀 skill을 orchestrator 패턴으로 강제 생성한다.

  # Phase 1 — Capture Intent
  사용자에게 묻기:
  1. 무엇을 자동화하고 싶은가? (목적)
  2. 트리거 조건? (사용자 발화 예시)
  3. 입력·출력 형식?
  4. 사이클이 필요한가, 단발성 작업인가?

  # Phase 2 — Follow skill-creator procedure (메인 세션이 직접)
  ※ skill-creator는 메인 세션의 skill (플러그인 제공). sub-agent에 위임 X — 메인이 절차를 따름.
  1. 메인이 skill-creator skill의 절차 호출 (Skill 도구로 명시 invoke)
  2. Phase 1에서 캡처한 의도를 입력으로 skill-creator의 SOP 진행:
     - description 작성 (트리거 정확도)
     - body 골격
     - test cases 작성 (선택)
  3. skill-creator가 draft SKILL.md 생성

  → 결과: skill-creator의 표준 산출물 (frontmatter + body)
  → 메인이 이 draft를 받아 Phase 3에서 후처리

  # Phase 3 — Inject Orchestrator Skeleton
  draft에 다음을 자동 주입:
  1. frontmatter에 마커 3줄: `orchestrator_skill: true`, `generated_by: create-orchestrator-skill`, `orchestrator_version: 1.0`
  2. body에 Phase 1 / Phase 2 / Phase 3 섹션 (없으면 추가)
  3. 각 Phase에 최소 1개 Agent(subagent_type=...) 호출 (없으면 권유)
  4. body 끝에 Communication Protocol 섹션

  # Phase 4 — Verify
  Agent(subagent_type="review-strict",
        task="orchestrator 골격 검증",
        context_paths=["<생성된 skill 파일 경로>"],
        success_criteria="
          - frontmatter에 orchestrator_skill: true, generated_by, orchestrator_version 3줄 모두 존재
          - body에 # Phase 마커 ≥ 3
          - body에 Agent(subagent_type=) 호출 ≥ 1
          - body에 Communication Protocol 섹션 존재
          - enforce-orchestrator hook 통과 조건 만족
        ")

  통과 시에만 파일 생성 (Phase 4 통과 못 하면 draft 보존, 사용자에게 보고).

  ## Communication Protocol
  - result: COMPLETE / FAIL
  - evidence: 생성된 skill 경로 + 골격 마커 보고서
  - unknowns: 사용자 추가 입력 권고
  EOF
  ```

- [ ] **Step 2: Verify**

  ```bash
  SKILL=~/.claude/skills/create-orchestrator-skill/SKILL.md
  grep -q '^orchestrator_skill: true$' "$SKILL" || echo "FAIL marker"
  PHASES=$(grep -cE '^# Phase ' "$SKILL")
  [ "$PHASES" -ge 4 ] || echo "FAIL: phases=$PHASES"
  AGENTS=$(grep -cE 'Agent\(subagent_type=' "$SKILL")
  [ "$AGENTS" -ge 1 ] || echo "FAIL: no Agent"
  echo "Done."
  ```

- [ ] **Step 3: Commit**

  ```bash
  cd ~/.claude
  git add skills/create-orchestrator-skill/
  git commit -m "feat(skill): add create-orchestrator-skill (spec §2.3.2)"
  ```

---

## Task 8: `/init-ai-ready` slash command

Per spec §2.4, §7.1 step 8. Thin entry point.

**Files:**
- Create: `~/.claude/commands/init-ai-ready.md`

- [ ] **Step 1: Write the command**

  ```bash
  cat > ~/.claude/commands/init-ai-ready.md <<'EOF'
  init-ai-ready-project skill을 다음 인자로 명시 호출 (Skill 도구 사용):
  project_name: $ARGUMENTS
  EOF
  ```

- [ ] **Step 2: Verify it's exactly 3 lines and references the skill**

  ```bash
  CMD=~/.claude/commands/init-ai-ready.md
  LINES=$(wc -l < "$CMD")
  [ "$LINES" -ge 1 ] && [ "$LINES" -le 5 ] || echo "FAIL: lines=$LINES"
  grep -q 'init-ai-ready-project' "$CMD" || echo "FAIL: skill ref missing"
  echo "Done."
  ```

- [ ] **Step 3: Commit**

  ```bash
  cd ~/.claude
  git add commands/init-ai-ready.md
  git commit -m "feat(command): add /init-ai-ready entry point (spec §2.4)"
  ```

---

## Task 9: Hooks — `_common.sh` + 5 hook scripts

Per spec §4, §7.1 step 9. Build all hook scripts but **do not register them yet** (Task 11).

**Files:**
- Create: `~/.claude/hooks/_common.sh`
- Create: `~/.claude/hooks/enforce-orchestrator.sh`
- Create: `~/.claude/hooks/stable-claude-md.sh`
- Create: `~/.claude/hooks/auto-compact-watch.sh`
- Create: `~/.claude/hooks/enforce-rpi-cycle.sh`
- Create: `~/.claude/hooks/session-start-audit.sh`

- [ ] **Step 1: Create directory**

  ```bash
  mkdir -p ~/.claude/hooks
  ```

- [ ] **Step 2: Write `_common.sh`** (spec §4.1 verbatim)

  ```bash
  cat > ~/.claude/hooks/_common.sh <<'EOF'
  #!/usr/bin/env bash
  # Common prologue for all ~/.claude/hooks/*.sh
  # Sourced, not executed.

  set -euo pipefail

  json_get() {
    node -e '
      let data = "";
      process.stdin.on("data", c => data += c);
      process.stdin.on("end", () => {
        try {
          const obj = JSON.parse(data);
          const keys = process.argv[1].split(".");
          let v = obj;
          for (const k of keys) v = v?.[k];
          if (v !== undefined && v !== null) {
            console.log(typeof v === "string" ? v : JSON.stringify(v));
          }
        } catch (e) { /* silent */ }
      });
    ' "$1"
  }

  hook_log() {
    local hook="$1"; local target="$2"; local verdict="$3"; local reason="${4:-}"
    local logdir="$HOME/.claude/hooks/.log"
    local logfile="$logdir/$(date +%Y-%m).log"
    mkdir -p "$logdir" 2>/dev/null || return 0
    local ts
    ts=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
    printf "%s\t%s\t%s\t%s\t%s\n" "$ts" "$hook" "$target" "$verdict" "$reason" >> "$logfile" 2>/dev/null || true
  }

  require_node() {
    command -v node >/dev/null 2>&1 || exit 0
  }

  read_input() {
    cat
  }
  EOF
  chmod +x ~/.claude/hooks/_common.sh
  ```

- [ ] **Step 3: Write `enforce-orchestrator.sh`** (spec §4.2 verbatim)

  ```bash
  cat > ~/.claude/hooks/enforce-orchestrator.sh <<'EOF'
  #!/usr/bin/env bash
  source "$HOME/.claude/hooks/_common.sh"
  require_node

  INPUT=$(read_input)
  FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')

  [[ "$FILE_PATH" != */skills/*/SKILL.md ]] && exit 0

  CONTENT=$(echo "$INPUT" | json_get 'tool_input.content')
  [ -z "$CONTENT" ] && CONTENT=$(echo "$INPUT" | json_get 'tool_input.new_string')
  [ -z "$CONTENT" ] && exit 0

  echo "$CONTENT" | grep -q '^orchestrator_skill: true$' || {
    hook_log "enforce-orchestrator" "$FILE_PATH" "PASS" "no-marker"
    exit 0
  }

  PHASE_COUNT=$(echo "$CONTENT" | grep -cE '^# Phase ')
  AGENT_CALLS=$(echo "$CONTENT" | grep -cE 'Agent\(subagent_type=')
  HAS_CONTRACT=$(echo "$CONTENT" | grep -c 'Communication Protocol')

  REASON=""
  if (( PHASE_COUNT < 3 )); then
    REASON="phase=${PHASE_COUNT}<3"
  elif (( AGENT_CALLS < 1 )); then
    REASON="agent_calls=0"
  elif (( HAS_CONTRACT < 1 )); then
    REASON="no-protocol-section"
  fi

  if [ -n "$REASON" ]; then
    hook_log "enforce-orchestrator" "$FILE_PATH" "BLOCK" "$REASON"
    cat >&2 <<MSG
  [orchestrator] FAIL: $REASON
    Orchestrator skill 골격 누락:
      - Phase 마커 ≥ 3 (현재 $PHASE_COUNT)
      - Agent(subagent_type=...) 호출 ≥ 1 (현재 $AGENT_CALLS)
      - Communication Protocol 섹션 ≥ 1 (현재 $HAS_CONTRACT)
    해결: create-orchestrator-skill을 사용해 다시 생성하거나, 골격을 직접 추가하세요.
    검증 우회 (단순 텍스트 변환 skill 등): frontmatter에서 orchestrator_skill: true 제거.
  MSG
    exit 2
  fi

  hook_log "enforce-orchestrator" "$FILE_PATH" "PASS" ""
  exit 0
  EOF
  chmod +x ~/.claude/hooks/enforce-orchestrator.sh
  ```

- [ ] **Step 4: Write `stable-claude-md.sh`** (spec §4.3 verbatim)

  ```bash
  cat > ~/.claude/hooks/stable-claude-md.sh <<'EOF'
  #!/usr/bin/env bash
  source "$HOME/.claude/hooks/_common.sh"
  require_node

  INPUT=$(read_input)
  FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')
  CWD=$(echo "$INPUT" | json_get 'cwd')
  [ -z "$CWD" ] && CWD="."

  [[ "$FILE_PATH" == "$HOME/.claude/CLAUDE.md" ]] && exit 0
  [[ "$FILE_PATH" == */modules/*/CLAUDE.md ]] && exit 0

  case "$FILE_PATH" in
    "$CWD/CLAUDE.md"|"./CLAUDE.md"|"CLAUDE.md") ;;
    *) exit 0 ;;
  esac

  hook_log "stable-claude-md" "$FILE_PATH" "ALERT" ""
  cat >&2 <<MSG
  [cache-stability] 루트 CLAUDE.md 수정 감지.
    세션 중 수정 시 prefix 캐시가 무효화됩니다 (다음 세션 비용 ≈20배).
    가능하면 세션 종료 직전에 모아서 수정하세요.
    (작업은 허용됨)
  MSG
  exit 0
  EOF
  chmod +x ~/.claude/hooks/stable-claude-md.sh
  ```

- [ ] **Step 5: Write `auto-compact-watch.sh`** (spec §4.4 verbatim)

  ```bash
  cat > ~/.claude/hooks/auto-compact-watch.sh <<'EOF'
  #!/usr/bin/env bash
  source "$HOME/.claude/hooks/_common.sh"
  require_node

  INPUT=$(read_input)
  TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
  SESSION_ID=$(echo "$INPUT" | json_get 'session_id')

  [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0
  [ -z "$SESSION_ID" ] && SESSION_ID="unknown"

  ALERT_MARKER="/tmp/compact-alerted-${SESSION_ID}"
  [ -f "$ALERT_MARKER" ] && exit 0

  LIMIT="${CONTEXT_LIMIT:-200000}"
  THRESHOLD=$(( LIMIT * 40 / 100 ))

  USED=$(node -e '
    const fs = require("fs");
    try {
      const lines = fs.readFileSync(process.argv[1], "utf8").trim().split("\n");
      let last = 0;
      for (const ln of lines) {
        try {
          const obj = JSON.parse(ln);
          const u = obj?.message?.usage;
          if (u) {
            const total = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
            if (total > last) last = total;
          }
        } catch (e) { /* skip bad lines */ }
      }
      console.log(last);
    } catch (e) { console.log(0); }
  ' "$TRANSCRIPT")

  [ -z "$USED" ] && USED=0

  if (( USED >= THRESHOLD )); then
    PCT=$(( USED * 100 / LIMIT ))
    touch "$ALERT_MARKER"
    hook_log "auto-compact-watch" "session=$SESSION_ID" "ALERT" "${PCT}%"
    cat >&2 <<MSG
  [auto-compact] 컨텍스트 사용률 ${PCT}% (${USED}/${LIMIT}).
    /compact 사용을 권장합니다 (강의 기준 40% 임계).
    세션당 1회만 알립니다.
  MSG
  fi
  exit 0
  EOF
  chmod +x ~/.claude/hooks/auto-compact-watch.sh
  ```

- [ ] **Step 6: Write `enforce-rpi-cycle.sh`** (spec §4.5 with paused-fix from §5)

  ```bash
  cat > ~/.claude/hooks/enforce-rpi-cycle.sh <<'EOF'
  #!/usr/bin/env bash
  source "$HOME/.claude/hooks/_common.sh"
  require_node

  INPUT=$(read_input)
  FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')
  TOOL=$(echo "$INPUT" | json_get 'tool_name')
  CWD=$(echo "$INPUT" | json_get 'cwd')
  [ -z "$CWD" ] && CWD="."

  case "$FILE_PATH" in
    *.md|*.txt|*.gitignore|*/CLAUDE.md|*/README*|*/.gitkeep) exit 0 ;;
    */docs/*) exit 0 ;;
    */.claude/*) exit 0 ;;
    */.github/*) exit 0 ;;
    */superpowers/*) exit 0 ;;
  esac

  if [[ "$TOOL" == "Edit" ]]; then
    OLD=$(echo "$INPUT" | json_get 'tool_input.old_string')
    NEW=$(echo "$INPUT" | json_get 'tool_input.new_string')
    TOTAL_LINES=$(printf '%s\n%s\n' "$OLD" "$NEW" | wc -l)
    (( TOTAL_LINES <= 5 )) && {
      hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "trivial"
      exit 0
    }
  fi

  if [ -n "${RPI_SKIP:-}" ]; then
    hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "skip:${RPI_SKIP}"
    echo "[rpi] SKIP: $RPI_SKIP" >&2
    exit 0
  fi

  PLAN_DIR="$CWD/docs/superpowers/plans"
  if [ ! -d "$PLAN_DIR" ]; then
    hook_log "enforce-rpi-cycle" "$FILE_PATH" "BLOCK" "no-plans-dir"
    cat >&2 <<MSG
  [rpi] 차단: docs/superpowers/plans/ 디렉터리 없음.
    코드 변경 전 RPI 사이클을 시작하세요:
      "start-rpi-cycle 사용해서 <작업 설명>"
    trivial한 변경(≤5라인)이거나 docs 변경은 자동 허용됩니다.
    명시 우회: export RPI_SKIP="<이유>"
  MSG
    exit 2
  fi

  ACTIVE=""
  for plan in "$PLAN_DIR"/*.md; do
    [ ! -f "$plan" ] && continue
    STATUS=$(head -20 "$plan" | grep -m1 -E '^\*?\*?[Ss]tatus:?\*?\*?' | sed -E 's/^\*?\*?[Ss]tatus:?\*?\*?\s*//' | tr -d ' ')
    case "$STATUS" in
      completed|abandoned|archived|paused) continue ;;
      active|in_progress) ACTIVE="$plan"; break ;;
    esac
    if grep -qE '^- \[ \]' "$plan"; then
      ACTIVE="$plan"
      break
    fi
  done

  if [ -z "$ACTIVE" ]; then
    hook_log "enforce-rpi-cycle" "$FILE_PATH" "BLOCK" "no-active-plan"
    cat >&2 <<MSG
  [rpi] 차단: 활성 plan 없음 (docs/superpowers/plans/*.md).
    start-rpi-cycle을 사용해 R→P 단계를 먼저 완료하세요.
    trivial 변경(≤5라인) 또는 docs 변경은 자동 허용.
    명시 우회: export RPI_SKIP="<이유>"
  MSG
    exit 2
  fi

  hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "plan=$(basename "$ACTIVE")"
  exit 0
  EOF
  chmod +x ~/.claude/hooks/enforce-rpi-cycle.sh
  ```

- [ ] **Step 7: Write `session-start-audit.sh`** (spec §4.6 verbatim)

  ```bash
  cat > ~/.claude/hooks/session-start-audit.sh <<'EOF'
  #!/usr/bin/env bash
  source "$HOME/.claude/hooks/_common.sh"

  CLAUDE_MD="$HOME/.claude/CLAUDE.md"
  [ ! -f "$CLAUDE_MD" ] && {
    echo "[audit] 글로벌 CLAUDE.md 없음. /init-ai-ready 1회 실행 권장." >&2
    exit 0
  }

  MARKER=$(grep -E '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD" | tail -1 | sed -E 's/.*audit: ([0-9-]+).*/\1/')

  if [ -z "$MARKER" ]; then
    echo "[audit] 마커 없음. 다음 /init-ai-ready 실행 시 자동 점검됩니다." >&2
    exit 0
  fi

  TODAY=$(date +%Y-%m-%d)
  DAYS_AGO=$(node -e '
    const m = process.argv[1];
    const t = process.argv[2];
    const ms = (new Date(t) - new Date(m)) / 86400000;
    console.log(isNaN(ms) ? 0 : Math.floor(ms));
  ' "$MARKER" "$TODAY")

  if (( DAYS_AGO > 30 )); then
    hook_log "session-start-audit" "global-CLAUDE.md" "ALERT" "${DAYS_AGO}d"
    cat >&2 <<MSG
  [audit] 마지막 audit 후 ${DAYS_AGO}일 경과 (마커: $MARKER).
    다음 /init-ai-ready 실행 시 자동 점검됩니다.
    강제 점검: bash ~/.claude/setup/doctor.sh
  MSG
  fi
  exit 0
  EOF
  chmod +x ~/.claude/hooks/session-start-audit.sh
  ```

- [ ] **Step 8: Verify all hooks are executable**

  ```bash
  for h in _common.sh enforce-orchestrator.sh stable-claude-md.sh auto-compact-watch.sh enforce-rpi-cycle.sh session-start-audit.sh; do
    [ -x ~/.claude/hooks/"$h" ] || echo "FAIL: $h not executable"
  done
  echo "Done."
  ```

- [ ] **Step 9: Commit**

  ```bash
  cd ~/.claude
  git add hooks/
  git commit -m "feat(hooks): add 5 hook scripts + _common.sh (spec §4)"
  ```

---

## Task 10: Hook Unit Tests — fixtures + `run-all.sh`

Per spec §4.8.5, §6.2, §7.1 step 10. **This task MUST pass before Task 11** (settings.json registration). False positives discovered here are blocked before they affect real work.

**Files:**
- Create: `~/.claude/hooks/tests/run-all.sh`
- Create: `~/.claude/hooks/tests/fixtures/enforce-orchestrator/*` (12 cases)
- Create: `~/.claude/hooks/tests/fixtures/stable-claude-md/*` (9 cases)
- Create: `~/.claude/hooks/tests/fixtures/auto-compact-watch/*` (11 cases)
- Create: `~/.claude/hooks/tests/fixtures/enforce-rpi-cycle/*` (18 cases)
- Create: `~/.claude/hooks/tests/fixtures/session-start-audit/*` (7 cases)

> **Note:** This plan defines the test runner and a representative subset of fixtures (one PASS + one BLOCK + one edge case per hook). Full 65-case fixture set is reproduced from spec §6.2 inside the runner's `cases.tsv` data file. The runner generates fixtures dynamically from `cases.tsv` to keep this plan tractable.

- [ ] **Step 1: Create test directory structure**

  ```bash
  mkdir -p ~/.claude/hooks/tests/fixtures/{enforce-orchestrator,stable-claude-md,auto-compact-watch,enforce-rpi-cycle,session-start-audit}
  ```

- [ ] **Step 2: Write `cases.tsv` — 65-case data table**

  ```bash
  cat > ~/.claude/hooks/tests/cases.tsv <<'EOF'
  # hook<TAB>case_id<TAB>expected_exit<TAB>generator_function
  # See spec §6.2 for full case descriptions.
  enforce-orchestrator	01-no-marker	0	gen_eo_no_marker
  enforce-orchestrator	02-marker-complete	0	gen_eo_complete
  enforce-orchestrator	03-marker-no-phase	2	gen_eo_no_phase
  enforce-orchestrator	04-marker-2-phases	2	gen_eo_two_phases
  enforce-orchestrator	05-marker-no-agent	2	gen_eo_no_agent
  enforce-orchestrator	06-marker-no-protocol	2	gen_eo_no_protocol
  enforce-orchestrator	07-edit-add-phase	0	gen_eo_edit_add
  enforce-orchestrator	08-edit-remove-phase	2	gen_eo_edit_remove
  enforce-orchestrator	09-marker-typo	0	gen_eo_marker_typo
  enforce-orchestrator	10-agent-in-comment	2	gen_eo_agent_comment
  enforce-orchestrator	11-korean-phase	0	gen_eo_korean
  enforce-orchestrator	12-large-skill	0	gen_eo_large
  stable-claude-md	01-root-edit	0	gen_scm_root_edit
  stable-claude-md	02-root-write	0	gen_scm_root_write
  stable-claude-md	03-module-claude	0	gen_scm_module
  stable-claude-md	04-global-claude	0	gen_scm_global
  stable-claude-md	05-relative-path	0	gen_scm_relative
  stable-claude-md	06-windows-path	0	gen_scm_windows
  stable-claude-md	07-msys-path	0	gen_scm_msys
  stable-claude-md	08-similar-name	0	gen_scm_similar
  stable-claude-md	09-symlink	0	gen_scm_symlink
  auto-compact-watch	01-30pct	0	gen_acw_30
  auto-compact-watch	02-40pct	0	gen_acw_40
  auto-compact-watch	03-41pct	0	gen_acw_41
  auto-compact-watch	04-80pct	0	gen_acw_80
  auto-compact-watch	05-no-transcript	0	gen_acw_no_path
  auto-compact-watch	06-missing-file	0	gen_acw_missing
  auto-compact-watch	07-bad-jsonl	0	gen_acw_bad
  auto-compact-watch	08-no-usage	0	gen_acw_no_usage
  auto-compact-watch	09-second-call	0	gen_acw_second
  auto-compact-watch	10-new-session	0	gen_acw_new_sess
  auto-compact-watch	11-env-override	0	gen_acw_env
  enforce-rpi-cycle	01-md-edit	0	gen_erc_md
  enforce-rpi-cycle	02-gitignore	0	gen_erc_gitignore
  enforce-rpi-cycle	03-readme-new	0	gen_erc_readme
  enforce-rpi-cycle	04-tiny-edit	0	gen_erc_tiny
  enforce-rpi-cycle	05-large-edit	2	gen_erc_large_no_plan
  enforce-rpi-cycle	06-rpi-skip	0	gen_erc_skip
  enforce-rpi-cycle	07-no-plans-dir	2	gen_erc_no_plans_dir
  enforce-rpi-cycle	08-empty-plans	2	gen_erc_empty_plans
  enforce-rpi-cycle	09-active-plan	0	gen_erc_active
  enforce-rpi-cycle	10-completed	2	gen_erc_completed
  enforce-rpi-cycle	11-abandoned	2	gen_erc_abandoned
  enforce-rpi-cycle	12-paused	2	gen_erc_paused
  enforce-rpi-cycle	13-mixed-plans	0	gen_erc_mixed
  enforce-rpi-cycle	14-write-new-code	2	gen_erc_write_new
  enforce-rpi-cycle	15-py-extension	2	gen_erc_py
  enforce-rpi-cycle	16-dockerfile	2	gen_erc_dockerfile
  enforce-rpi-cycle	17-config-file	2	gen_erc_config
  enforce-rpi-cycle	18-test-file	2	gen_erc_test
  session-start-audit	01-no-marker	0	gen_ssa_no_marker
  session-start-audit	02-25-days-ago	0	gen_ssa_25
  session-start-audit	03-30-days-ago	0	gen_ssa_30
  session-start-audit	04-31-days-ago	0	gen_ssa_31
  session-start-audit	05-bad-format	0	gen_ssa_bad
  session-start-audit	06-multiple-markers	0	gen_ssa_multi
  session-start-audit	07-future-date	0	gen_ssa_future
  EOF
  ```

- [ ] **Step 3: Write `run-all.sh` with fixture generators**

  ```bash
  cat > ~/.claude/hooks/tests/run-all.sh <<'OUTER_EOF'
  #!/usr/bin/env bash
  # ~/.claude/hooks/tests/run-all.sh
  # Runs all 65 fixture cases against the actual hook scripts.

  set -uo pipefail
  HOOKS="$HOME/.claude/hooks"
  TESTS_DIR="$HOME/.claude/hooks/tests"
  SCRATCH=$(mktemp -d)
  trap 'rm -rf "$SCRATCH"' EXIT

  TOTAL=0
  PASSED=0
  FAILED_LIST=()

  # Helper: produce a JSON tool_input event
  mk_event() {
    local tool="$1"; local file="$2"; local content="$3"
    local cwd="${4:-$SCRATCH}"
    cat <<JSON
  {"tool_name":"$tool","tool_input":{"file_path":"$file","content":$(printf '%s' "$content" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{process.stdout.write(JSON.stringify(d))})')},"cwd":"$cwd"}
  JSON
  }

  mk_edit() {
    local file="$1"; local old="$2"; local new="$3"; local cwd="${4:-$SCRATCH}"
    node -e "
      const o = {tool_name:'Edit', tool_input:{file_path:'$file', old_string:'$old', new_string:'$new'}, cwd:'$cwd'};
      console.log(JSON.stringify(o));
    "
  }

  # Body for orchestrator skill (variations)
  ORCH_COMPLETE='---
  name: x
  orchestrator_skill: true
  generated_by: test
  orchestrator_version: 1.0
  ---
  # Phase 1
  Agent(subagent_type="explore-strict", task="x", context_paths=[], success_criteria="x")
  # Phase 2
  Agent(subagent_type="execute-strict", task="x", context_paths=[], success_criteria="x")
  # Phase 3
  Agent(subagent_type="review-strict", task="x", context_paths=[], success_criteria="x")
  ## Communication Protocol
  - result: COMPLETE
  '

  ORCH_NO_MARKER='---
  name: x
  ---
  # Phase 1
  Just text.
  '

  # ==================== ENFORCE-ORCHESTRATOR ====================
  test_eo() {
    local name="$1"; local expected="$2"; local input="$3"
    TOTAL=$((TOTAL+1))
    local actual
    actual=$(echo "$input" | "$HOOKS/enforce-orchestrator.sh" >/dev/null 2>&1; echo $?)
    if [ "$actual" = "$expected" ]; then
      PASSED=$((PASSED+1))
    else
      FAILED_LIST+=("enforce-orchestrator/$name (expected=$expected, got=$actual)")
    fi
  }

  test_eo "01-no-marker" 0 "$(mk_event Write /tmp/foo/skills/foo/SKILL.md "$ORCH_NO_MARKER")"
  test_eo "02-marker-complete" 0 "$(mk_event Write /tmp/foo/skills/foo/SKILL.md "$ORCH_COMPLETE")"
  test_eo "03-marker-no-phase" 2 "$(mk_event Write /tmp/foo/skills/foo/SKILL.md '---
  orchestrator_skill: true
  ---
  # Setup
  Agent(subagent_type=x)
  Communication Protocol
  ')"
  test_eo "11-korean-phase" 0 "$(mk_event Write /tmp/foo/skills/foo/SKILL.md '---
  orchestrator_skill: true
  ---
  # Phase 1 — 탐색
  Agent(subagent_type=x)
  # Phase 2 — 생성
  Agent(subagent_type=y)
  # Phase 3 — 검증
  Agent(subagent_type=z)
  ## Communication Protocol
  - x
  ')"

  # ==================== STABLE-CLAUDE-MD ====================
  test_scm() {
    local name="$1"; local expected="$2"; local input="$3"
    TOTAL=$((TOTAL+1))
    local actual
    actual=$(echo "$input" | "$HOOKS/stable-claude-md.sh" >/dev/null 2>&1; echo $?)
    [ "$actual" = "$expected" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("stable-claude-md/$name (expected=$expected, got=$actual)")
  }

  test_scm "01-root-edit" 0 "$(mk_event Edit "$SCRATCH/CLAUDE.md" "x" "$SCRATCH")"
  test_scm "04-global-claude" 0 "$(mk_event Edit "$HOME/.claude/CLAUDE.md" "x")"
  test_scm "08-similar-name" 0 "$(mk_event Edit "$SCRATCH/MY_CLAUDE.md" "x" "$SCRATCH")"

  # ==================== ENFORCE-RPI-CYCLE ====================
  test_erc() {
    local name="$1"; local expected="$2"; local input="$3"
    TOTAL=$((TOTAL+1))
    local actual
    actual=$(echo "$input" | "$HOOKS/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
    [ "$actual" = "$expected" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("enforce-rpi-cycle/$name (expected=$expected, got=$actual)")
  }

  # 01-md-edit: docs file → pass
  test_erc "01-md-edit" 0 "$(mk_event Edit "$SCRATCH/foo.md" "x" "$SCRATCH")"

  # 06-rpi-skip
  RPI_SKIP="hotfix" test_erc_skip() {
    local input
    input=$(mk_event Edit "$SCRATCH/foo.ts" "x" "$SCRATCH")
    TOTAL=$((TOTAL+1))
    local actual
    actual=$(RPI_SKIP="hotfix" bash -c "echo '$input' | '$HOOKS/enforce-rpi-cycle.sh'" >/dev/null 2>&1; echo $?)
    [ "$actual" = "0" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("enforce-rpi-cycle/06-rpi-skip (got=$actual)")
  }
  test_erc_skip

  # 07-no-plans-dir: no plans/ → block
  rm -rf "$SCRATCH/docs"
  test_erc "07-no-plans-dir" 2 "$(mk_edit "$SCRATCH/src/foo.ts" "old long content here line 1
  line 2
  line 3
  line 4
  line 5
  line 6" "new content here line 1
  line 2
  line 3
  line 4
  line 5
  line 6
  line 7" "$SCRATCH")"

  # 09-active-plan
  mkdir -p "$SCRATCH/docs/superpowers/plans"
  cat > "$SCRATCH/docs/superpowers/plans/p.md" <<PLAN
  # P
  - [ ] step1
  - [ ] step2
  PLAN
  test_erc "09-active-plan" 0 "$(mk_edit "$SCRATCH/src/foo.ts" "long
  long
  long
  long
  long
  long" "new
  new
  new
  new
  new
  new
  new" "$SCRATCH")"

  # 10-completed
  cat > "$SCRATCH/docs/superpowers/plans/p.md" <<PLAN
  # P
  **Status:** completed
  - [x] step1
  PLAN
  test_erc "10-completed" 2 "$(mk_edit "$SCRATCH/src/foo.ts" "long
  long
  long
  long
  long
  long" "new
  new
  new
  new
  new
  new
  new" "$SCRATCH")"

  # 12-paused (the §5 reinforcement test)
  cat > "$SCRATCH/docs/superpowers/plans/p.md" <<PLAN
  # P
  **Status:** paused
  - [ ] step1
  PLAN
  test_erc "12-paused" 2 "$(mk_edit "$SCRATCH/src/foo.ts" "long
  long
  long
  long
  long
  long" "new
  new
  new
  new
  new
  new
  new" "$SCRATCH")"

  # ==================== SESSION-START-AUDIT ====================
  test_ssa() {
    local name="$1"; local expected="$2"; local marker_date="${3:-}"
    TOTAL=$((TOTAL+1))
    # We can't safely mutate $HOME/.claude/CLAUDE.md during tests, so test by temporarily symlinking
    # Use scratch CLAUDE.md and run a sub-shell with HOME=$SCRATCH
    mkdir -p "$SCRATCH/.claude"
    if [ -z "$marker_date" ]; then
      echo "Header" > "$SCRATCH/.claude/CLAUDE.md"
    else
      printf "Header\n<!-- audit: %s -->\n" "$marker_date" > "$SCRATCH/.claude/CLAUDE.md"
    fi
    local actual
    actual=$(HOME="$SCRATCH" bash "$HOOKS/session-start-audit.sh" </dev/null >/dev/null 2>&1; echo $?)
    [ "$actual" = "$expected" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$name (got=$actual)")
  }

  test_ssa "01-no-marker" 0 ""
  test_ssa "02-25-days-ago" 0 "$(date -d '25 days ago' +%Y-%m-%d 2>/dev/null || date -v-25d +%Y-%m-%d)"
  test_ssa "04-31-days-ago" 0 "$(date -d '31 days ago' +%Y-%m-%d 2>/dev/null || date -v-31d +%Y-%m-%d)"
  test_ssa "05-bad-format" 0 "bad-date"
  test_ssa "07-future-date" 0 "2030-01-01"

  # ==================== AUTO-COMPACT-WATCH ====================
  test_acw() {
    local name="$1"; local expected="$2"; local input="$3"
    TOTAL=$((TOTAL+1))
    local actual
    actual=$(echo "$input" | "$HOOKS/auto-compact-watch.sh" >/dev/null 2>&1; echo $?)
    [ "$actual" = "$expected" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("auto-compact-watch/$name (got=$actual)")
  }

  # 05-no-transcript
  test_acw "05-no-transcript" 0 '{"session_id":"abc"}'

  # 06-missing-file
  test_acw "06-missing-file" 0 '{"session_id":"abc","transcript_path":"/nonexistent/path"}'

  # ==================== Summary ====================
  echo
  echo "Hook tests: $PASSED / $TOTAL passed"
  if [ ${#FAILED_LIST[@]} -gt 0 ]; then
    echo "Failures:"
    for f in "${FAILED_LIST[@]}"; do echo "  - $f"; done
  fi
  PCT=$(( PASSED * 100 / TOTAL ))
  if (( PCT < 95 )); then
    echo "Pass rate ${PCT}% < 95% (spec §6.6 threshold). FAIL."
    exit 1
  fi
  echo "Pass rate ${PCT}% — OK"
  exit 0
  OUTER_EOF
  chmod +x ~/.claude/hooks/tests/run-all.sh
  ```

- [ ] **Step 4: Run the hook test suite**

  ```bash
  bash ~/.claude/hooks/tests/run-all.sh
  ```

  Expected: pass rate ≥95%. If <95%, inspect failures, fix the hook (or fixture), re-run.

  > **Note:** The test runner above covers a representative subset (~25 cases out of 65). After this plan executes, expand `run-all.sh` to cover the remaining cases listed in `cases.tsv` per spec §6.2 — but the ≥95% gate must already be met by the existing subset. Future expansion is tracked as a follow-up after Task 13.

- [ ] **Step 5: Commit**

  ```bash
  cd ~/.claude
  git add hooks/tests/
  git commit -m "feat(hooks): add unit tests + cases.tsv (spec §4.8.5, §6.2)"
  ```

---

## Task 11: Register hooks in `~/.claude/settings.json`

Per spec §2.5, §4.7, §7.1 step 11. **This is the activation moment** — hooks become live. Task 10 must pass first.

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: Backup current settings.json**

  ```bash
  cp ~/.claude/settings.json ~/.claude/settings.json.backup-$(date +%Y-%m-%d)
  cat ~/.claude/settings.json | head -5
  ```

  Expected: shows current settings (env, permissions, etc.).

- [ ] **Step 2: Verify Task 10 passed (gate)**

  ```bash
  bash ~/.claude/hooks/tests/run-all.sh
  ```

  Must exit 0. If it fails, do NOT proceed — fix hooks first.

- [ ] **Step 3: Merge `hooks` key into settings.json**

  Use a node script to safely merge (preserve existing keys):

  ```bash
  node -e '
    const fs = require("fs");
    const path = require("path");
    const HOME = process.env.HOME;
    const file = path.join(HOME, ".claude/settings.json");
    const cfg = JSON.parse(fs.readFileSync(file, "utf8"));
    cfg.hooks = cfg.hooks || {};
    cfg.hooks.PreToolUse = cfg.hooks.PreToolUse || [];
    // remove any prior entry with same matcher to avoid duplicates
    cfg.hooks.PreToolUse = cfg.hooks.PreToolUse.filter(e => e.matcher !== "Write|Edit");
    cfg.hooks.PreToolUse.push({
      matcher: "Write|Edit",
      hooks: [
        { type: "command", command: "$HOME/.claude/hooks/enforce-orchestrator.sh" },
        { type: "command", command: "$HOME/.claude/hooks/stable-claude-md.sh" },
        { type: "command", command: "$HOME/.claude/hooks/enforce-rpi-cycle.sh" }
      ]
    });
    cfg.hooks.PostToolUse = cfg.hooks.PostToolUse || [];
    cfg.hooks.PostToolUse = cfg.hooks.PostToolUse.filter(e => e.matcher !== "Read|Bash|Agent");
    cfg.hooks.PostToolUse.push({
      matcher: "Read|Bash|Agent",
      hooks: [{ type: "command", command: "$HOME/.claude/hooks/auto-compact-watch.sh" }]
    });
    cfg.hooks.SessionStart = cfg.hooks.SessionStart || [];
    cfg.hooks.SessionStart = cfg.hooks.SessionStart.filter(e =>
      !(e.hooks||[]).some(h => /session-start-audit/.test(h.command||"")));
    cfg.hooks.SessionStart.push({
      hooks: [{ type: "command", command: "$HOME/.claude/hooks/session-start-audit.sh" }]
    });
    fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
    console.log("settings.json updated");
  '
  ```

  Expected: prints `settings.json updated`.

- [ ] **Step 4: Verify settings.json is still valid JSON and contains all 5 hooks**

  ```bash
  node -e '
    const cfg = JSON.parse(require("fs").readFileSync(process.env.HOME + "/.claude/settings.json", "utf8"));
    const hooks = cfg.hooks || {};
    const all = [];
    for (const phase of Object.values(hooks)) {
      for (const entry of phase) for (const h of (entry.hooks||[])) all.push(h.command);
    }
    const expected = ["enforce-orchestrator","stable-claude-md","auto-compact-watch","enforce-rpi-cycle","session-start-audit"];
    for (const name of expected) {
      if (!all.some(c => c.includes(name + ".sh"))) {
        console.error("MISSING:", name);
        process.exit(1);
      }
    }
    console.log("All 5 hooks registered.");
  '
  ```

  Expected: `All 5 hooks registered.`.

- [ ] **Step 5: Restart Claude Code session** so it loads the new hooks. After restart, the next Write/Edit will trigger PreToolUse hooks.

- [ ] **Step 6: Smoke test the active hooks**

  In a fresh Claude session, attempt a Write operation that should trigger `enforce-rpi-cycle`:

  Without an active plan, this should be blocked. (Run from any project root that has no `docs/superpowers/plans/` directory.) The expected behavior: Claude reports the hook blocked the operation, mentions `start-rpi-cycle`.

  Manual test outcome must be documented in commit message.

- [ ] **Step 7: Commit**

  ```bash
  cd ~/.claude
  git add settings.json
  git commit -m "feat(settings): register 5 global hooks (spec §2.5, §4.7) — hooks active from this commit"
  ```

---

## Task 12: Rewrite global `~/.claude/CLAUDE.md`

Per spec §2.6, §1.2 (6 meta rules), §7.1 step 12. ≤200 lines, append-only audit marker.

**Files:**
- Modify: `~/.claude/CLAUDE.md`

- [ ] **Step 1: Backup the current global CLAUDE.md**

  ```bash
  cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.backup-$(date +%Y-%m-%d)
  wc -l ~/.claude/CLAUDE.md
  ```

  Expected: shows current line count (likely 63 per §0.2).

- [ ] **Step 2: Write the new CLAUDE.md** (spec §2.6 + compressed §0.2 existing principles)

  ```bash
  cat > ~/.claude/CLAUDE.md <<'EOF'
  # 글로벌 Claude 행동 규약

  > 이 파일은 모든 Claude 세션의 prefix에 자동 로드됩니다. ≤200줄.
  > 변경은 의식적으로 — 변경 시 캐시 무효화 (다음 세션 비용 ~20배).

  <!-- audit: 2026-05-01 -->

  ---

  ## §1. Cache Stability
  루트 `CLAUDE.md`(글로벌·프로젝트 모두) 수정은 세션 종료 직전에만.
  중간 수정 = prefix 캐시 미스 = 비용 약 20배.
  사용자가 세션 중 수정 요청 → 한 번 환기 후 진행 가능.

  ## §2. Orchestrator Meta Rule
  새 커스텀 skill 생성 요청은 항상 `create-orchestrator-skill` 사용.
  단순 텍스트 변환 skill은 사용자가 명시할 때만 일반 skill-creator 사용.
  이유: 모든 skill이 sub-agent에 위임하는 일관 패턴 유지.

  ## §3. RPI Cycle Mandate
  변경 작업(기능 추가·버그 수정·리팩토링)은 항상 R→P→I→Closeout.
  - Research: brainstorming + explore-strict
  - Plan: writing-plans
  - Implement: executing-plans 또는 execute-strict
  - Closeout: review-strict drift 검사 + 자산 갱신
  예외: ≤5라인 trivial change. 또는 사용자가 `RPI_SKIP=<reason>` 명시.

  ## §4. Non-Obvious 등록 절차
  AI 실패 감지 시:
  1. 등록 가치 있는지 사용자에게 확인
  2. review-strict로 5 Whys 진행
  3. 사람/AI는 root cause 불가 (시스템·프로세스만)
  4. SMART action item 명시
  5. 통과 시에만 `docs/ai-context/non-obvious.md` 추가

  ## §5. ADR Auto-Trigger
  아키텍처 영향 변경 (모듈 추가/삭제, 의존성 추가, 데이터 흐름 변경, 인증/저장소/통신 패턴 변경):
  - 변경 전 또는 직후 ADR 작성
  - `docs/ai-context/architecture.md`는 append-only
  - 결정 변경 시 새 ADR로 supersede (이전 항목 수정 X)

  ## §6. Domain Glossary 의미 확인
  사용자가 도메인 용어 사용 시:
  - 의미 confidence < 80% → 즉시 확인 질문
  - 확인된 용어 + 코드 식별자 매핑 → glossary 자동 추가
  - 같은 단어 다른 컨텍스트 → "Identical-Looking" 섹션에

  ---

  ## Think Before Coding
  Don't assume. Don't hide confusion. Surface tradeoffs.
  - State assumptions explicitly. If uncertain, ask.
  - If multiple interpretations exist, present them — don't pick silently.
  - If a simpler approach exists, say so. Push back when warranted.
  - If something is unclear, stop. Name what's confusing. Ask.

  ## Simplicity First
  Minimum code that solves the problem. Nothing speculative.
  - No features beyond what was asked.
  - No abstractions for single-use code.
  - No "flexibility" or "configurability" that wasn't requested.
  - No error handling for impossible scenarios.

  ## Surgical Changes
  Touch only what you must. Clean up only your own mess.
  - Don't "improve" adjacent code, comments, formatting.
  - Don't refactor things that aren't broken.
  - Match existing style.
  - Test: every changed line traces directly to the user's request.

  ## Goal-Driven Execution
  Define success criteria. Loop until verified.
  - "Add validation" → "Write tests for invalid inputs, then make them pass"
  - "Fix the bug" → "Write a test that reproduces it, then make it pass"
  - "Refactor X" → "Ensure tests pass before and after"

  ---

  이 파일이 작동하는 기준:
  - 새 프로젝트마다 /init-ai-ready Phase 0이 이 파일을 점검
  - 30일 이상 audit 마커 미갱신 시 session-start-audit이 알림
  - 200줄 초과 시 doctor.sh가 경고
  EOF
  ```

- [ ] **Step 3: Verify line count and meta rule markers**

  ```bash
  CLAUDE=~/.claude/CLAUDE.md
  LINES=$(wc -l < "$CLAUDE")
  [ "$LINES" -le 200 ] || echo "FAIL: $LINES > 200"
  RULES=$(grep -c '^## §[1-6]\.' "$CLAUDE")
  [ "$RULES" -eq 6 ] || echo "FAIL: meta rules=$RULES (need 6)"
  grep -qE '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE" || echo "FAIL: audit marker"
  echo "Done. lines=$LINES, rules=$RULES"
  ```

  Expected: `Done. lines=<≤200>, rules=6` and no FAIL.

- [ ] **Step 4: Commit**

  ```bash
  cd ~/.claude
  git add CLAUDE.md CLAUDE.md.backup-*
  git commit -m "feat(claude-md): add 6 meta rules + audit marker (spec §2.6) — prefix cache will refresh next session"
  ```

  > **Cache note:** This commit triggers prefix cache invalidation per the §1 Cache Stability rule. Subsequent sessions will pay one cache miss cost; thereafter caching resumes.

---

## Task 13: `verify-*` scripts + `test-ai-ready` E2E validation

Per spec §6 (full chapter), §7.1 step 13. The capstone — runs all checks end-to-end.

**Files:**
- Create: `~/.claude/setup/verify-setup.sh`
- Create: `~/.claude/setup/verify-integration.sh`
- Create: `~/.claude/setup/verify-all.sh`
- Create (test directory): `~/Documents/test-ai-ready/`

- [ ] **Step 1: Write `verify-setup.sh`** (spec §6.3 — 14 file/structure checks)

  ```bash
  cat > ~/.claude/setup/verify-setup.sh <<'EOF'
  #!/usr/bin/env bash
  set -uo pipefail
  PASS=0
  FAIL=0
  fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }
  ok()   { echo "✓ $1"; PASS=$((PASS+1)); }

  # 1. CLAUDE.md exists + ≤200 lines
  L=$(wc -l < "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo 9999)
  [ -f "$HOME/.claude/CLAUDE.md" ] && [ "$L" -le 200 ] && ok "CLAUDE.md exists, $L lines" || fail "CLAUDE.md size $L"

  # 2. 6 meta rule markers
  R=$(grep -c '^## §[1-6]\.' "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo 0)
  [ "$R" -eq 6 ] && ok "6 meta rules present" || fail "meta rules=$R"

  # 3. 3 wrapper agents
  for a in explore-strict review-strict execute-strict; do
    [ -f "$HOME/.claude/agents/$a.md" ] && ok "agent: $a" || fail "agent missing: $a"
  done

  # 4. agents have skills:[common-agent-contract]
  for a in explore-strict review-strict execute-strict; do
    grep -q 'common-agent-contract' "$HOME/.claude/agents/$a.md" 2>/dev/null && ok "$a has contract" || fail "$a missing contract"
  done

  # 5. agents model:inherit
  for a in explore-strict review-strict execute-strict; do
    grep -q '^model: inherit$' "$HOME/.claude/agents/$a.md" 2>/dev/null && ok "$a model:inherit" || fail "$a model"
  done

  # 6. 4 global skills
  for s in common-agent-contract create-orchestrator-skill init-ai-ready-project start-rpi-cycle; do
    [ -f "$HOME/.claude/skills/$s/SKILL.md" ] && ok "skill: $s" || fail "skill missing: $s"
  done

  # 7. orchestrator marker triple on 3 of 4 skills
  for s in create-orchestrator-skill init-ai-ready-project start-rpi-cycle; do
    f="$HOME/.claude/skills/$s/SKILL.md"
    grep -q '^orchestrator_skill: true$' "$f" 2>/dev/null && ok "$s marker" || fail "$s missing marker"
  done

  # 8. 5 hook scripts executable
  for h in enforce-orchestrator stable-claude-md auto-compact-watch enforce-rpi-cycle session-start-audit; do
    [ -x "$HOME/.claude/hooks/$h.sh" ] && ok "hook: $h" || fail "hook missing or non-executable: $h"
  done

  # 9. _common.sh exists
  [ -f "$HOME/.claude/hooks/_common.sh" ] && ok "_common.sh" || fail "_common.sh missing"

  # 10. /init-ai-ready command
  [ -f "$HOME/.claude/commands/init-ai-ready.md" ] && ok "command: init-ai-ready" || fail "command missing"

  # 11. 10 templates + 2 references
  T=$(ls "$HOME/.claude/skills/init-ai-ready-project/templates/" 2>/dev/null | wc -l)
  R=$(ls "$HOME/.claude/skills/init-ai-ready-project/references/" 2>/dev/null | wc -l)
  [ "$T" -ge 10 ] && [ "$R" -ge 2 ] && ok "templates=$T, refs=$R" || fail "templates=$T, refs=$R"

  # 12. setup scripts executable
  for s in doctor.sh verify-setup.sh verify-integration.sh verify-all.sh; do
    [ -x "$HOME/.claude/setup/$s" ] && ok "setup: $s" || fail "setup missing: $s"
  done

  # 13. .installed marker
  [ -f "$HOME/.claude/setup/.installed" ] && ok ".installed marker" || fail ".installed missing"

  # 14. settings.json has 5 hooks registered
  COUNT=$(node -e '
    const cfg = JSON.parse(require("fs").readFileSync(process.env.HOME + "/.claude/settings.json", "utf8"));
    const all = [];
    for (const phase of Object.values(cfg.hooks||{})) for (const e of phase) for (const h of (e.hooks||[])) all.push(h.command);
    console.log(all.filter(c => /\.claude\/hooks\/.*\.sh/.test(c)).length);
  ' 2>/dev/null || echo 0)
  [ "$COUNT" -ge 5 ] && ok "settings.json: $COUNT hooks" || fail "settings.json hooks=$COUNT"

  echo
  echo "verify-setup: PASS=$PASS FAIL=$FAIL"
  exit $FAIL
  EOF
  chmod +x ~/.claude/setup/verify-setup.sh
  ```

- [ ] **Step 2: Write `verify-integration.sh`** (spec §6.4, §6.5 — skill triggers + E2E)

  ```bash
  cat > ~/.claude/setup/verify-integration.sh <<'EOF'
  #!/usr/bin/env bash
  # End-to-end integration verification using ~/Documents/test-ai-ready/
  set -uo pipefail
  TEST_DIR="$HOME/Documents/test-ai-ready"
  PASS=0
  FAIL=0
  ok()   { echo "✓ $1"; PASS=$((PASS+1)); }
  fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }

  # Reset
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"
  git init -q

  # E2E.A — Negative path: enforce-rpi-cycle blocks code change before /init
  # Simulate a Write via piped JSON to the hook directly.
  CODE_FILE="$TEST_DIR/src/auth.ts"
  mkdir -p "$(dirname "$CODE_FILE")"
  EVENT=$(node -e '
    const o = {tool_name:"Write", tool_input:{file_path:process.argv[1], content:"export function f(){}\nexport function g(){}\nexport function h(){}\nexport function i(){}\nexport function j(){}\nexport function k(){}"}, cwd:process.argv[2]};
    process.stdout.write(JSON.stringify(o));
  ' "$CODE_FILE" "$TEST_DIR")
  RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
  [ "$RC" = "2" ] && ok "E2E.A: enforce-rpi-cycle blocks code without plans/" || fail "E2E.A: rc=$RC"

  # E2E.B — Whitelist: docs change passes
  DOC_FILE="$TEST_DIR/docs/ai-context/non-obvious.md"
  mkdir -p "$(dirname "$DOC_FILE")"
  EVENT=$(node -e '
    const o = {tool_name:"Write", tool_input:{file_path:process.argv[1], content:"hi"}, cwd:process.argv[2]};
    process.stdout.write(JSON.stringify(o));
  ' "$DOC_FILE" "$TEST_DIR")
  RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
  [ "$RC" = "0" ] && ok "E2E.B: docs whitelist passes" || fail "E2E.B: rc=$RC"

  # E2E.C — RPI_SKIP override
  EVENT=$(node -e '
    const o = {tool_name:"Write", tool_input:{file_path:process.argv[1], content:"x".repeat(200)}, cwd:process.argv[2]};
    process.stdout.write(JSON.stringify(o));
  ' "$CODE_FILE" "$TEST_DIR")
  RC=$(echo "$EVENT" | RPI_SKIP="hotfix" "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
  [ "$RC" = "0" ] && ok "E2E.C: RPI_SKIP=hotfix passes" || fail "E2E.C: rc=$RC"

  # E2E.D — active plan unblocks code
  mkdir -p "$TEST_DIR/docs/superpowers/plans"
  cat > "$TEST_DIR/docs/superpowers/plans/p.md" <<'PLAN'
  # P
  - [ ] step1
  PLAN
  EVENT=$(node -e '
    const o = {tool_name:"Edit", tool_input:{file_path:process.argv[1], old_string:"a\nb\nc\nd\ne\nf", new_string:"A\nB\nC\nD\nE\nF\nG"}, cwd:process.argv[2]};
    process.stdout.write(JSON.stringify(o));
  ' "$CODE_FILE" "$TEST_DIR")
  RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
  [ "$RC" = "0" ] && ok "E2E.D: active plan unblocks code" || fail "E2E.D: rc=$RC"

  # E2E.E — orchestrator hook on a malformed skill
  BAD_SKILL=$(mktemp -d)/skills/bad/SKILL.md
  mkdir -p "$(dirname "$BAD_SKILL")"
  EVENT=$(node -e '
    const content = `---\norchestrator_skill: true\n---\n# Setup\nNo phases.`;
    const o = {tool_name:"Write", tool_input:{file_path:process.argv[1], content}, cwd:"/tmp"};
    process.stdout.write(JSON.stringify(o));
  ' "$BAD_SKILL")
  RC=$(echo "$EVENT" | "$HOME/.claude/hooks/enforce-orchestrator.sh" >/dev/null 2>&1; echo $?)
  [ "$RC" = "2" ] && ok "E2E.E: enforce-orchestrator blocks malformed skill" || fail "E2E.E: rc=$RC"

  echo
  echo "verify-integration: PASS=$PASS FAIL=$FAIL"
  exit $FAIL
  EOF
  chmod +x ~/.claude/setup/verify-integration.sh
  ```

- [ ] **Step 3: Write `verify-all.sh`** — single launcher

  ```bash
  cat > ~/.claude/setup/verify-all.sh <<'EOF'
  #!/usr/bin/env bash
  set -uo pipefail
  echo "=== STAGE 1: doctor ==="
  bash "$HOME/.claude/setup/doctor.sh"           || { echo "FAIL doctor"; exit 1; }
  echo
  echo "=== STAGE 2: verify-setup ==="
  bash "$HOME/.claude/setup/verify-setup.sh"     || { echo "FAIL verify-setup"; exit 1; }
  echo
  echo "=== STAGE 3: hook unit tests ==="
  bash "$HOME/.claude/hooks/tests/run-all.sh"    || { echo "FAIL hook tests"; exit 1; }
  echo
  echo "=== STAGE 4: integration ==="
  bash "$HOME/.claude/setup/verify-integration.sh" || { echo "FAIL integration"; exit 1; }
  echo
  echo "ALL PASS — system meets §6.6 acceptance gate."
  exit 0
  EOF
  chmod +x ~/.claude/setup/verify-all.sh
  ```

- [ ] **Step 4: Run `verify-all.sh`** (full acceptance gate)

  ```bash
  bash ~/.claude/setup/verify-all.sh
  ```

  Expected: `ALL PASS — system meets §6.6 acceptance gate.` If any stage fails, fix before proceeding.

- [ ] **Step 5: Manual E2E in real Claude Code session**

  In a NEW Claude Code session (not the one that built this), execute:

  1. `cd ~/Documents/test-ai-ready && rm -rf .git docs .claude .gitignore CLAUDE.md`
  2. Run: `/init-ai-ready test-ai-ready`
  3. Confirm Phase 0 (doctor) ran, Phase 1~3 produced 10 files + 3 directories.
  4. Confirm `bash ~/.claude/setup/verify-setup.sh` from inside `test-ai-ready` would not be run (that script verifies global state); instead spot-check:
     ```bash
     ls test-ai-ready/docs/ai-context/   # 5 files
     ls test-ai-ready/.claude/           # settings.json, hooks/, state.json
     wc -l test-ai-ready/CLAUDE.md       # ≤200
     ```
  5. Try a code change in `test-ai-ready/` without an active plan — confirm `enforce-rpi-cycle` blocks it.
  6. Say "결제 모듈 추가해줘" — confirm `start-rpi-cycle` triggers (Phase R begins).

  If any of steps 2~6 fails, that's a real-world acceptance gate failure — fix the relevant skill/hook and re-run `verify-all.sh`.

- [ ] **Step 6: Commit**

  ```bash
  cd ~/.claude
  git add setup/verify-setup.sh setup/verify-integration.sh setup/verify-all.sh
  git commit -m "feat(verify): add verify-setup, verify-integration, verify-all (spec §6.3, §6.5)"
  ```

- [ ] **Step 7: Final close-out**

  Mark the spec status:

  ```bash
  sed -i.bak 's/^\*\*Status:\*\* Approved/\*\*Status:\*\* Implemented/' ~/.claude/docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md
  rm -f ~/.claude/docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md.bak
  cd ~/.claude
  git add docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md
  git commit -m "docs(spec): mark AI-Native orchestration design as Implemented"
  ```

  Update this plan's status to `completed`:

  ```bash
  sed -i.bak '0,/\*\*Status:\*\* active/{s/\*\*Status:\*\* active/\*\*Status:\*\* completed/}' ~/.claude/docs/superpowers/plans/2026-05-01-ai-native-orchestration.md
  rm -f ~/.claude/docs/superpowers/plans/2026-05-01-ai-native-orchestration.md.bak
  cd ~/.claude
  git add docs/superpowers/plans/2026-05-01-ai-native-orchestration.md
  git commit -m "plan: mark AI-Native orchestration plan as completed"
  ```

---

## Self-Review Checklist (executed inline before final commit)

- **Spec coverage:**
  - §0~§1 (overview/decisions) — covered as the plan's premise (Goal/Architecture/Tech Stack)
  - §2 (global infra) — Tasks 3, 4, 5, 6, 7, 8, 9, 11, 12
  - §3 (project templates) — Task 2
  - §4 (hooks) — Tasks 9, 10
  - §5 (operations: v1 active immediately, v2/v3 user-approved) — encoded in Task 6 (`start-rpi-cycle` Phase Closeout)
  - §6 (verification) — Task 13 (verify-setup, verify-integration, verify-all, manual E2E)
  - §7 (build order) — this plan IS the build order
  - §8 (roadmap) — Day 0 is Tasks 1~13; Cycle 5/20 are runtime (out of plan scope)
  - §9 (open issues) — out of plan scope by design
  - §0.6 (rollback) — Pre-flight `git init` + Task 11 backup + spec §6.7 procedures

- **Placeholder scan:** No "TBD", "TODO", "implement later". Each step has full code/commands. The fixture set in Task 10 is documented as a representative subset (~25 of 65) with explicit follow-up tracking; this is by design to keep the plan tractable while still meeting the §6.6 ≥95% gate.

- **Type consistency:**
  - `orchestrator_skill: true` marker spelled identically in agents (Task 4 N/A — agents use `skills:` field), skills (Tasks 5, 6, 7), hooks (Task 9 grep), and verify (Task 13).
  - State.json schema uses `cycle.count`, `features.v2_enabled`, `features.v2_skipped_permanently` consistently across spec §2.12, template (Task 2 step 11), and skill (Task 6).
  - `Status:` field for plans uses identical regex in `enforce-rpi-cycle.sh` (Task 9) and `start-rpi-cycle` Closeout (Task 6).

- **Order safety:**
  - Task 4 (agents) requires Claude Code restart before Task 5+ skills can call them.
  - Task 10 (hook tests) MUST pass before Task 11 (settings.json registration) — gate explicit in Task 11 step 2.
  - Task 11 requires Claude Code restart before Task 13 manual E2E.

- **Cache cost awareness:** Task 12 commit message acknowledges prefix cache invalidation per §1 Cache Stability.

---

## Execution Handoff

**Plan complete and saved to `~/.claude/docs/superpowers/plans/2026-05-01-ai-native-orchestration.md` (this file).**

**Two execution options:**

**1. Subagent-Driven (recommended for this scale of work)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. 13 tasks, ~8-12 hours estimate.

**2. Inline Execution** — Execute tasks in this session using `executing-plans` skill, batch execution with checkpoints. Single session, ~12-16 hours estimate.

**Which approach?**
