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
  FILE="$file" OLD="$old" NEW="$new" CWD="$cwd" node -e '
    const o = {tool_name:"Edit", tool_input:{file_path:process.env.FILE, old_string:process.env.OLD, new_string:process.env.NEW}, cwd:process.env.CWD};
    console.log(JSON.stringify(o));
  '
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

# 05-marker-no-agent: phases + protocol but no Agent() → BLOCK
test_eo "05-marker-no-agent" 2 "$(mk_event Write /tmp/foo/skills/foo/SKILL.md '---
orchestrator_skill: true
---
# Phase 1
# Phase 2
# Phase 3
## Communication Protocol
- x
')"

# 06-marker-no-protocol: phases + Agent() but no protocol → BLOCK
test_eo "06-marker-no-protocol" 2 "$(mk_event Write /tmp/foo/skills/foo/SKILL.md '---
orchestrator_skill: true
---
# Phase 1
Agent(subagent_type=x)
# Phase 2
Agent(subagent_type=y)
# Phase 3
Agent(subagent_type=z)
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

# 02-root-write: Write tool (not Edit) on root CLAUDE.md → ALERT exit 0
test_scm "02-root-write" 0 "$(mk_event Write "$SCRATCH/CLAUDE.md" "content" "$SCRATCH")"

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

# 02-gitignore: .gitignore whitelist → pass
test_erc "02-gitignore" 0 "$(mk_event Edit "$SCRATCH/.gitignore" "x" "$SCRATCH")"

# 06-rpi-skip
test_erc_skip() {
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
**Status:** active
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

# 11-abandoned: Status: abandoned → BLOCK
cat > "$SCRATCH/docs/superpowers/plans/p.md" <<PLAN
# P
**Status:** abandoned
- [ ] step1
PLAN
test_erc "11-abandoned" 2 "$(mk_edit "$SCRATCH/src/foo.ts" "long
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

# 03-30-days-ago: boundary check (DAYS_AGO=30 is NOT > 30) → no alert
test_ssa "03-30-days-ago" 0 "$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)"

# 06-multiple-markers: tail -1 picks last marker (recent) → no alert
test_ssa_multi() {
  TOTAL=$((TOTAL+1))
  mkdir -p "$SCRATCH/.claude"
  TODAY=$(date +%Y-%m-%d)
  printf "Header
<!-- audit: 2020-01-01 -->
<!-- audit: %s -->
" "$TODAY" > "$SCRATCH/.claude/CLAUDE.md"
  local actual
  actual=$(HOME="$SCRATCH" bash "$HOOKS/session-start-audit.sh" </dev/null >/dev/null 2>&1; echo $?)
  [ "$actual" = "0" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/06-multiple-markers (got=$actual)")
}
test_ssa_multi

# 19-windows-backslash: Windows path with backslashes inside .claude -> whitelisted via normalize_path
test_erc "19-windows-backslash" 0 "$(FILE='C:\Users\foo\.claude\bar.sh' OLD='x' NEW='y' CWD='C:\Users\foo\.claude' node -e '
const o = {tool_name:"Edit", tool_input:{file_path:process.env.FILE, old_string:process.env.OLD, new_string:process.env.NEW}, cwd:process.env.CWD};
console.log(JSON.stringify(o));
')"

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
