#!/usr/bin/env bash
# ~/.claude/hooks/tests/run-all.sh
# Runs implemented fixture cases against the actual hook scripts.

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

# Bash tool event (command field) — for enforce-rpi-bash (Patch A)
mk_bash_event() {
  local cmd="$1"; local cwd="${2:-$SCRATCH}"
  cat <<JSON
{"tool_name":"Bash","tool_input":{"command":$(printf '%s' "$cmd" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{process.stdout.write(JSON.stringify(d))})')},"cwd":"$cwd"}
JSON
}

# NotebookEdit event (notebook_path + new_source) — for enforce-rpi-cycle matcher (Patch A)
mk_nb_event() {
  local file="$1"; local src="$2"; local cwd="${3:-$SCRATCH}"
  cat <<JSON
{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"$file","new_source":$(printf '%s' "$src" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{process.stdout.write(JSON.stringify(d))})')},"cwd":"$cwd"}
JSON
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

# 15-write-tiny: Write ≤5 lines to new code file with active plan → PASS (trivial bypass)
cat > "$SCRATCH/docs/superpowers/plans/p.md" <<PLAN
# P
**Status:** active
- [ ] step1
PLAN
test_erc "15-write-tiny" 0 "$(mk_event Write "$SCRATCH/src/new_file.ts" "const x = 1;
const y = 2;" "$SCRATCH")"

# ==================== PATCH-A: WHITELIST HARDENING (enforce-rpi-cycle) ====================
# Isolated projects so we don't couple to the mutated $SCRATCH plan state above.
NP="$SCRATCH/np"; mkdir -p "$NP/docs/superpowers" "$NP/.claude/hooks" "$NP/vendor/superpowers" "$NP/src" "$NP/skills/foo"   # NO plans dir
WP="$SCRATCH/wp"; mkdir -p "$WP/docs/superpowers/plans" "$WP/.claude/hooks"
printf '# p\n**Status:** active\n- [ ] s\n' > "$WP/docs/superpowers/plans/p.md"
BIG=$'a=1\nb=2\nc=3\nd=4\ne=5\nf=6\ng=7\nh=8'   # 8-line code body (non-trivial)

# Code under whitelisted dirs must now require a plan (closes S5/S11/S16 smuggling + self-modification)
test_erc "20-docs-py-block"        2 "$(mk_event Write "$NP/docs/gen.py" "$BIG" "$NP")"
test_erc "21-claude-sh-block"      2 "$(mk_event Write "$NP/.claude/hooks/evil.sh" "$BIG" "$NP")"
test_erc "22-superpowers-py-block" 2 "$(mk_event Write "$NP/vendor/superpowers/x.py" "$BIG" "$NP")"
# Non-code under whitelisted dirs still passes (no false positives)
test_erc "23-docs-md-pass"         0 "$(mk_event Write "$NP/docs/notes.md" "$BIG" "$NP")"
test_erc "24-claude-json-pass"     0 "$(mk_event Write "$NP/.claude/settings.json" "$BIG" "$NP")"
# NotebookEdit now routed + path resolved from notebook_path (closes S2)
test_erc "25-notebook-block"       2 "$(mk_nb_event "$NP/nb.ipynb" "$BIG" "$NP")"
test_erc "26-notebook-pass"        0 "$(mk_nb_event "$WP/nb.ipynb" "$BIG" "$WP")"
# With an active plan, code under .claude/ is allowed (governance change via RPI)
test_erc "27-claude-sh-plan-pass"  0 "$(mk_event Write "$WP/.claude/hooks/x.sh" "$BIG" "$WP")"

# ==================== PATCH-A: BASH SIDE-DOOR (enforce-rpi-bash) ====================
test_erb() {
  local name="$1"; local expected="$2"; local input="$3"; local env_pfx="${4:-}"
  TOTAL=$((TOTAL+1))
  local actual
  if [ -n "$env_pfx" ]; then
    actual=$(echo "$input" | env $env_pfx "$HOOKS/enforce-rpi-bash.sh" >/dev/null 2>&1; echo $?)
  else
    actual=$(echo "$input" | "$HOOKS/enforce-rpi-bash.sh" >/dev/null 2>&1; echo $?)
  fi
  [ "$actual" = "$expected" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("enforce-rpi-bash/$name (expected=$expected, got=$actual)")
}
HEREDOC_PY=$'cat > out.py <<EOF\nprint(1)\nEOF'
test_erb "30-heredoc-code-noplan" 2 "$(mk_bash_event "$HEREDOC_PY" "$NP")"
test_erb "31-redirect-md-noplan"  0 "$(mk_bash_event 'echo hi > notes.md' "$NP")"
test_erb "32-devnull"             0 "$(mk_bash_event 'foo > /dev/null' "$NP")"
test_erb "33-tee-code-noplan"     2 "$(mk_bash_event 'echo x | tee app.js' "$NP")"
test_erb "34-no-redirect"         0 "$(mk_bash_event 'npm run build' "$NP")"
test_erb "35-heredoc-code-plan"   0 "$(mk_bash_event "$HEREDOC_PY" "$WP")"
test_erb "36-rpi-skip"            0 "$(mk_bash_event "$HEREDOC_PY" "$NP")" "RPI_SKIP=hotfix"

# ==================== PATCH-A: ORCHESTRATOR CASE-INSENSITIVE (enforce-orchestrator) ====================
SK_BAD=$'---\norchestrator_skill: true\n---\n# Phase 1\nonly one phase'
test_eo "13-lowercase-skill-md" 2 "$(mk_event Write "$NP/skills/foo/skill.md" "$SK_BAD" "$NP")"

# ==================== PATCH-C: SECRET SCAN (enforce-secret-scan) ====================
test_ess() {
  local name="$1"; local expected="$2"; local input="$3"; local env_pfx="${4:-}"
  TOTAL=$((TOTAL+1))
  local actual
  if [ -n "$env_pfx" ]; then
    actual=$(echo "$input" | env $env_pfx "$HOOKS/enforce-secret-scan.sh" >/dev/null 2>&1; echo $?)
  else
    actual=$(echo "$input" | "$HOOKS/enforce-secret-scan.sh" >/dev/null 2>&1; echo $?)
  fi
  [ "$actual" = "$expected" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("enforce-secret-scan/$name (expected=$expected, got=$actual)")
}
# Fake-but-matching secrets built at RUNTIME so this test file holds NO literal secret
# (otherwise the scanner would self-trip when run-all.sh is later edited).
FAKE_ANT="sk-ant-oat01-$(printf 'a%.0s' $(seq 1 60))"
FAKE_AKIA="AKIA$(printf 'A%.0s' $(seq 1 16))"
PLACEHOLDER_ANT="sk-ant-oat01-$(printf 'X%.0s' $(seq 1 44))"
test_ess "40-write-anthropic-key" 2 "$(mk_event Write "$SCRATCH/x.txt" "token = $FAKE_ANT" "$SCRATCH")"
test_ess "41-write-aws-key"       2 "$(mk_event Write "$SCRATCH/x.txt" "aws = $FAKE_AKIA" "$SCRATCH")"
test_ess "42-bash-key-redirect"   2 "$(mk_bash_event "echo $FAKE_ANT > /tmp/leak.env" "$SCRATCH")"
test_ess "43-placeholder-pass"    0 "$(mk_event Write "$SCRATCH/x.txt" "token = $PLACEHOLDER_ANT" "$SCRATCH")"
test_ess "44-clean-pass"          0 "$(mk_event Write "$SCRATCH/x.txt" "just normal code here, no secrets" "$SCRATCH")"
test_ess "45-skip-override"       0 "$(mk_event Write "$SCRATCH/x.txt" "token = $FAKE_ANT" "$SCRATCH")" "SECRET_SCAN_SKIP=approved"

# ==================== PATCH-B: VERIFY-LOOP-WATCH (advisory Stop hook) ====================
# Output-based: assert systemMessage emitted (alert) vs not (silent) — exit is always 0.
rm -f /tmp/verify-reminded-vlwt* 2>/dev/null
test_vlw() {
  local name="$1"; local want="$2"; local input="$3"
  TOTAL=$((TOTAL+1))
  local out got=silent
  out=$(echo "$input" | "$HOOKS/verify-loop-watch.sh" 2>/dev/null)
  echo "$out" | grep -q 'verify-loop' && got=alert
  [ "$got" = "$want" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("verify-loop-watch/$name (want=$want got=$got)")
}
vlw_ev() { printf '{"session_id":"%s","stop_hook_active":%s,"cwd":"%s","transcript_path":"/x"}' "$1" "$2" "$3"; }

# full project: git + active plan + scripts/check.sh + uncommitted code change
VP="$SCRATCH/vlw_full"; mkdir -p "$VP/docs/superpowers/plans" "$VP/scripts" "$VP/src"
git -C "$VP" init -q 2>/dev/null; git -C "$VP" config user.email t@t 2>/dev/null; git -C "$VP" config user.name t 2>/dev/null
printf '# p\n**Status:** active\n- [ ] s\n' > "$VP/docs/superpowers/plans/p.md"
printf '#!/bin/bash\necho ok\n' > "$VP/scripts/check.sh"
printf 'x=1\n' > "$VP/src/a.py"
git -C "$VP" add -A >/dev/null 2>&1; git -C "$VP" commit -qm init >/dev/null 2>&1
printf 'x=2\ny=3\n' > "$VP/src/a.py"
test_vlw "40-alert-all-conditions" alert  "$(vlw_ev vlwt40 false "$VP")"; rm -f /tmp/verify-reminded-vlwt40
test_vlw "41-stop-active"          silent "$(vlw_ev vlwt41 true  "$VP")"
touch /tmp/verify-reminded-vlwt42; test_vlw "42-dedup-marker" silent "$(vlw_ev vlwt42 false "$VP")"; rm -f /tmp/verify-reminded-vlwt42

# clean repo (no uncommitted change) -> silent
VPC="$SCRATCH/vlw_clean"; mkdir -p "$VPC/docs/superpowers/plans" "$VPC/scripts" "$VPC/src"
git -C "$VPC" init -q 2>/dev/null; git -C "$VPC" config user.email t@t 2>/dev/null; git -C "$VPC" config user.name t 2>/dev/null
printf '# p\n**Status:** active\n- [ ] s\n' > "$VPC/docs/superpowers/plans/p.md"
printf '#!/bin/bash\n' > "$VPC/scripts/check.sh"; printf 'x=1\n' > "$VPC/src/a.py"
git -C "$VPC" add -A >/dev/null 2>&1; git -C "$VPC" commit -qm init >/dev/null 2>&1
test_vlw "43-clean-repo" silent "$(vlw_ev vlwt43 false "$VPC")"; rm -f /tmp/verify-reminded-vlwt43

# no active plan (exits before git) -> silent
VPNP="$SCRATCH/vlw_noplan"; mkdir -p "$VPNP/scripts"; printf '#!/bin/bash\n' > "$VPNP/scripts/check.sh"
test_vlw "44-no-plan" silent "$(vlw_ev vlwt44 false "$VPNP")"; rm -f /tmp/verify-reminded-vlwt44

# active plan but no scripts/check.sh -> silent
VPNC="$SCRATCH/vlw_nocheck"; mkdir -p "$VPNC/docs/superpowers/plans"; printf '# p\n**Status:** active\n- [ ] s\n' > "$VPNC/docs/superpowers/plans/p.md"
test_vlw "45-no-checksh" silent "$(vlw_ev vlwt45 false "$VPNC")"; rm -f /tmp/verify-reminded-vlwt45

# ==================== PATCH-D: AUDIT-RESIDUAL FIXES ====================
# S14 — Status trailing-text parsed by first word (via enforce-rpi-cycle plan gate)
DST="$SCRATCH/d_s14"; mkdir -p "$DST/docs/superpowers/plans" "$DST/src"
printf '# x\n**Status:** completed - cleanup pending\n- [ ] leftover\n' > "$DST/docs/superpowers/plans/p.md"
test_erc "50-s14-completed-trailing-block" 2 "$(mk_edit "$DST/src/a.ts" $'a\nb\nc\nd\ne\nf' $'x\ny\nz\nw\nv\nu' "$DST")"
printf '# y\n**Status:** active (wip today)\n- [ ] s\n' > "$DST/docs/superpowers/plans/p.md"
test_erc "51-s14-active-trailing-pass"     0 "$(mk_edit "$DST/src/a.ts" $'a\nb\nc\nd\ne\nf' $'x\ny\nz\nw\nv\nu' "$DST")"

# S7 — trivial = max(OLD,NEW) lines (no plans dir)
DNP="$SCRATCH/d_noplan"; mkdir -p "$DNP/src"
test_erc "52-s7-3x3-trivial-pass" 0 "$(mk_edit "$DNP/src/a.ts" $'a\nb\nc' $'x\ny\nz' "$DNP")"
test_erc "53-s7-6x6-block"        2 "$(mk_edit "$DNP/src/a.ts" $'a\nb\nc\nd\ne\nf' $'x\ny\nz\nw\nv\nu' "$DNP")"

# S3 — orchestrator gut via Edit on an on-disk 3-phase skill -> BLOCK (validates reconstructed file)
DSKROOT="$SCRATCH/d_skill"; mkdir -p "$DSKROOT/skills/foo"
cat > "$DSKROOT/skills/foo/SKILL.md" <<'SK'
---
orchestrator_skill: true
---
# Phase 1
Agent(subagent_type="x")
# Phase 2
Agent(subagent_type="y")
# Phase 3
Agent(subagent_type="z")
## Communication Protocol
- ok
SK
S3OLD=$(cat <<'O'
# Phase 1
Agent(subagent_type="x")
# Phase 2
Agent(subagent_type="y")
# Phase 3
Agent(subagent_type="z")
## Communication Protocol
- ok
O
)
test_eo "14-s3-gut-via-edit" 2 "$(mk_edit "$DSKROOT/skills/foo/SKILL.md" "$S3OLD" $'# Phase 1\nonly one now' "$DSKROOT")"

# S4 — Agent() only inside an HTML comment -> BLOCK (stripped before count)
S4BODY=$'---\norchestrator_skill: true\n---\n# Phase 1\n# Phase 2\n# Phase 3\n<!-- Agent(subagent_type="x") -->\n## Communication Protocol\n- ok'
test_eo "15-s4-commented-agent" 2 "$(mk_event Write "$DSKROOT/skills/foo/SKILL.md" "$S4BODY" "$DSKROOT")"

# item5 — auto-compact-watch model-aware window (output-based: assert the window denominator)
test_acw_model() {
  local name="$1"; local model="$2"; local tokens="$3"; local want_win="$4"
  TOTAL=$((TOTAL+1))
  local tf; tf=$(mktemp "$SCRATCH/tr-XXXXXX.jsonl")
  printf '{"message":{"model":"%s","usage":{"input_tokens":%d,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' "$model" "$tokens" > "$tf"
  local sid="im5-$$-$name"; rm -f "/tmp/compact-alerted-$sid"
  local out; out=$(echo "{\"session_id\":\"$sid\",\"transcript_path\":\"$tf\"}" | CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=55 "$HOOKS/auto-compact-watch.sh" 2>&1)
  rm -f "/tmp/compact-alerted-$sid" "$tf"
  echo "$out" | grep -q "/$want_win" && PASSED=$((PASSED+1)) || FAILED_LIST+=("auto-compact-watch/$name (want win=$want_win, got: $out)")
}
test_acw_model "60-opus48-1M"   claude-opus-4-8   480000 1000000
test_acw_model "61-sonnet-200k" claude-sonnet-4-6 100000 200000

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

# 03-41pct: token usage above 40% threshold → alert (exit 0)
test_acw_threshold() {
  local name="$1"; local tokens="$2"
  TOTAL=$((TOTAL+1))
  local tf; tf=$(mktemp "$SCRATCH/transcript-XXXXXX.jsonl")
  printf '{"message":{"usage":{"input_tokens":%d,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' "$tokens" > "$tf"
  local SID="threshold-$$"
  rm -f "/tmp/compact-alerted-$SID"
  local actual
  actual=$(echo "{\"session_id\":\"$SID\",\"transcript_path\":\"$tf\"}" | "$HOOKS/auto-compact-watch.sh" >/dev/null 2>&1; echo $?)
  rm -f "/tmp/compact-alerted-$SID"
  [ "$actual" = "0" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("auto-compact-watch/$name (got=$actual)")
}
# 30pct (60000 of 200000): below threshold → no alert, still exit 0
test_acw_threshold "01-30pct" 60000
# 41pct (82000 of 200000): above 40% threshold → alert, exit 0
test_acw_threshold "03-41pct" 82000
# 80pct (160000 of 200000): well above threshold → alert, exit 0
test_acw_threshold "04-80pct" 160000

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
