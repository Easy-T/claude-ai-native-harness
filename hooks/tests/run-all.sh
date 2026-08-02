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

# GAP-010 (C9): ALERT 발화 자체를 단언 (기존 test_scm 은 exit 0 만 봄 — 경고문이 조용히 사라져도 침묵).
# 비-글로벌 루트 CLAUDE.md 는 stderr 에 [cache-stability] 를 내야 한다.
test_scm_alert() {  # $1 name
  TOTAL=$((TOTAL+1))
  local err; err=$(mk_event Edit "$SCRATCH/CLAUDE.md" "x" "$SCRATCH" | "$HOOKS/stable-claude-md.sh" 2>&1 >/dev/null)
  echo "$err" | grep -qF 'cache-stability' && PASSED=$((PASSED+1)) || FAILED_LIST+=("stable-claude-md/$1 (ALERT 미발화: $err)")
}
test_scm_alert "198-scm-alert-asserted"

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

# cycle-17 F2: README 가 코드 확장자면 게이트 낙하 (이름 면제 없음), 문서 README 는 통과
test_erc "94-readme-code-block" 2 "$(mk_event Write "$NP/lib/README.sh" "$BIG" "$NP")"
test_erc "95-readme-doc-pass"   0 "$(mk_event Write "$NP/docs/README.md" "$BIG" "$NP")"

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
# cycle-17 F3: sed -i / cp 로 코드파일 쓰기 (no plan) → BLOCK
test_erb "102-sed-code-noplan" 2 "$(mk_bash_event 'sed -i s/a/b/ app.js' "$NP")"
test_erb "103-cp-code-noplan"  2 "$(mk_bash_event 'cp template.txt deploy.sh' "$NP")"
# cycle-23 D-LIFECYCLE: 명시 Status 없는 checkbox-only plan은 active 아님 → BLOCK
CB="$SCRATCH/cbonly"; mkdir -p "$CB/docs/superpowers/plans" "$CB/src"
printf '# p\n- [ ] s\n' > "$CB/docs/superpowers/plans/p.md"
test_erc "104-checkbox-only-noplan" 2 "$(mk_event Write "$CB/src/foo.ts" "$BIG" "$CB")"
test_erb "105-heredoc-checkbox-only" 2 "$(mk_bash_event "$HEREDOC_PY" "$CB")"
# cycle-23 D-SIDEDOOR-2: git apply/patch 보수차단 (plan 없으면 BLOCK, 있으면 PASS)
test_erb "118-git-apply-noplan" 2 "$(mk_bash_event 'git apply fix.patch' "$NP")"
test_erb "119-git-apply-plan"   0 "$(mk_bash_event 'git apply fix.patch' "$WP")"
test_erb "120-patch-noplan"     2 "$(mk_bash_event 'patch -p1 < f.patch' "$NP")"
# cycle-37: cat setup/install.sh hooks/foo.py 는 install 명령 아님 → no-plan 이어도 통과(과차단 봉인)
test_erb "155-install-substr-noplan-pass" 0 "$(mk_bash_event 'cat setup/install.sh hooks/foo.py' "$NP")"
# cycle-25 rank1: redirect-targets 4벡터 E2E (단일인용 차단·화살표 통과·node-eval 차단)
test_erb "130-singlequote-noplan" 2 "$(mk_bash_event "echo x > 'evil.py'" "$NP")"
test_erb "131-arrow-pass-noplan"  0 "$(mk_bash_event 'echo done -> next.js' "$NP")"
test_erb "132-node-eval-noplan"   2 "$(mk_bash_event $'node -e \'fs.writeFileSync("g.js",1)\'' "$NP")"
# cycle-34: >& 코드 파일 우회 E2E
test_erb "143-fdamp-noplan" 2 "$(mk_bash_event 'echo x >& evil.py' "$NP")"
# cycle-26 rank3: prose 'Status: active'(non-bold) plan은 active 아님 → 코드 Write 차단
PROSE="$SCRATCH/prose"; mkdir -p "$PROSE/docs/superpowers/plans" "$PROSE/src"
printf '# Example\nStatus: active\n\n**Status:** completed\n' > "$PROSE/docs/superpowers/plans/p.md"
test_erc "139-prose-status-noplan" 2 "$(mk_event Write "$PROSE/src/foo.ts" "$BIG" "$PROSE")"
# cycle-34: ~~~-펜스 active 만 있는 plan → active 미인정 → 코드 Write 차단 (E2E)
TILDE="$SCRATCH/tilde"; mkdir -p "$TILDE/docs/superpowers/plans" "$TILDE/src"
printf '# Plan\n~~~\n**Status:** active\n~~~\n' > "$TILDE/docs/superpowers/plans/p.md"
test_erc "145-tilde-fence-noplan" 2 "$(mk_event Write "$TILDE/src/foo.ts" "$BIG" "$TILDE")"

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
# GAP-010 (C9): 미테스트 패턴 3종 — GitHub PAT·Slack 토큰·SSH PrivKey 마커 (전부 런타임 분할 조립, 리터럴 0)
FAKE_GH="gh""p_$(printf 'a%.0s' $(seq 1 40))"
FAKE_SLK="xox""b-$(printf '1%.0s' $(seq 1 12))"
FAKE_PK="-----BEGIN OPENSSH ""PRIVATE KEY-----"
test_ess "195-secret-github"      2 "$(mk_event Write "$SCRATCH/x.md" "t=$FAKE_GH" "$SCRATCH")"
test_ess "196-secret-slack"       2 "$(mk_event Write "$SCRATCH/x.md" "s=$FAKE_SLK" "$SCRATCH")"
test_ess "197-secret-privkey"     2 "$(mk_event Write "$SCRATCH/x.md" "$FAKE_PK" "$SCRATCH")"

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

# ==================== CYCLE-23: SESSION-START-AUDIT plan 상시 표시 ====================
# 주의: 기존 test_ssa()(exit-code 기반)와 별개 함수 — 섀도잉 방지 위해 test_ssap 로 명명.
test_ssap() {
  local name="$1"; local want="$2"; local input="$3"   # want: stderr 기대 부분문자열 | noplanline
  TOTAL=$((TOTAL+1))
  local err; err=$(echo "$input" | "$HOOKS/session-start-audit.sh" 2>&1 >/dev/null)
  local good=0
  if [ "$want" = "noplanline" ]; then
    echo "$err" | grep -q '^\[plan\]' || good=1
  else
    echo "$err" | grep -qF "$want" && good=1
  fi
  [ "$good" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$name (want=$want)")
}
ssap_ev() { printf '{"session_id":"s","cwd":"%s"}' "$1"; }
SSA0="$SCRATCH/ssa0"; mkdir -p "$SSA0/docs/superpowers/plans"
test_ssap "106-zero-active" "[plan] active plan: 0" "$(ssap_ev "$SSA0")"
SSA1="$SCRATCH/ssa1"; mkdir -p "$SSA1/docs/superpowers/plans"
printf '# p\n**Status:** active\n' > "$SSA1/docs/superpowers/plans/a.md"
test_ssap "107-one-active" "a.md" "$(ssap_ev "$SSA1")"
SSA2="$SCRATCH/ssa2"; mkdir -p "$SSA2/docs/superpowers/plans"
printf '# p\n**Status:** active\n' > "$SSA2/docs/superpowers/plans/a.md"
printf '# q\n**Status:** in_progress\n' > "$SSA2/docs/superpowers/plans/b.md"
test_ssap "108-multi-active-warn" "stale-active" "$(ssap_ev "$SSA2")"
SSA3="$SCRATCH/ssa3"; mkdir -p "$SSA3"
test_ssap "109-no-plans-dir-silent" "noplanline" "$(ssap_ev "$SSA3")"

# ==================== CYCLE-C5: SESSION-START-AUDIT 메모리 수명주기 예산/dangling (GAP-004) ====================
# MEMORY_PROJECTS_DIR override 로 실 ~/.claude/projects 무변이 (RUNLOG_DIR/BUDGET_DIR 선례).
test_ssa_mem() {  # $1 name  $2 want(부분문자열|silent-mem)  $3 projects_dir
  TOTAL=$((TOTAL+1))
  local err; err=$(echo '{"session_id":"s","cwd":"'"$SCRATCH"'"}' | MEMORY_PROJECTS_DIR="$3" "$HOOKS/session-start-audit.sh" 2>&1 >/dev/null)
  local good=0
  if [ "$2" = "silent-mem" ]; then echo "$err" | grep -q '^\[memory\]' || good=1
  else echo "$err" | grep -qF "$2" && good=1; fi
  [ "$good" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$1 (want=$2)")
}
# over-lines: 201줄(작은 바이트) → 줄 경로만 발화
MEML="$SCRATCH/memL/projA/memory"; mkdir -p "$MEML"; for i in $(seq 1 201); do echo "- line $i"; done > "$MEML/MEMORY.md"
test_ssa_mem "185-mem-over-lines" "예산 초과" "$SCRATCH/memL"
# over-bytes: 3줄이지만 >25KB → 바이트 경로만 발화 (byte 바인딩 제약 실증)
MEMB="$SCRATCH/memB/projA/memory"; mkdir -p "$MEMB"; { echo "# idx"; head -c 26000 /dev/zero | tr '\0' 'x'; echo; echo "- x"; } > "$MEMB/MEMORY.md"
test_ssa_mem "186-mem-over-bytes" "예산 초과" "$SCRATCH/memB"
# ok: 작은 MEMORY.md + 링크 실재 → silent
MEMO="$SCRATCH/memO/projA/memory"; mkdir -p "$MEMO"; printf '# idx\n- [x](x.md) — ok\n' > "$MEMO/MEMORY.md"; printf 'x\n' > "$MEMO/x.md"
test_ssa_mem "187-mem-ok-silent" "silent-mem" "$SCRATCH/memO"
# dangling: 인덱스가 부재 파일 참조 → ALERT
MEMD="$SCRATCH/memD/projA/memory"; mkdir -p "$MEMD"; printf '# idx\n- [gone](gone.md) — x\n' > "$MEMD/MEMORY.md"
test_ssa_mem "188-mem-dangling" "dangling" "$SCRATCH/memD"

# ==================== CYCLE-C7: SESSION-START-AUDIT 공급망 SKILL.md cksum 드리프트 (GAP-011) ====================
# PLUGIN_CACHE_DIR/PLUGIN_PINS override 로 실 ~/.claude/plugins 무변이.
test_ssa_supply() {  # $1 name  $2 want(warn|silent)  $3 cache_dir  $4 pins_file
  TOTAL=$((TOTAL+1))
  local err; err=$(echo '{"session_id":"s","cwd":"'"$SCRATCH"'"}' | PLUGIN_CACHE_DIR="$3" PLUGIN_PINS="$4" "$HOOKS/session-start-audit.sh" 2>&1 >/dev/null)
  local good=0
  if [ "$2" = "warn" ]; then echo "$err" | grep -q '\[supply-chain\]' && good=1
  else echo "$err" | grep -q '\[supply-chain\]' || good=1; fi
  [ "$good" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$1 (want=$2)")
}
SUP="$SCRATCH/supply"; mkdir -p "$SUP/cache/mp/plug/1"; printf '# skill A\n' > "$SUP/cache/mp/plug/1/SKILL.md"
SUPCK=$(find "$SUP/cache" -name SKILL.md -type f | sort | xargs cat 2>/dev/null | cksum | cut -d' ' -f1)
printf 'skill-cksum: %s\nskill-count: 1\n' "$SUPCK" > "$SUP/pins-match.md"
printf 'skill-cksum: 999999999\nskill-count: 1\n' > "$SUP/pins-drift.md"
test_ssa_supply "191-supply-match-silent" silent "$SUP/cache" "$SUP/pins-match.md"
test_ssa_supply "192-supply-drift-warn"   warn   "$SUP/cache" "$SUP/pins-drift.md"

# ==================== CYCLE-39: SESSION-START-AUDIT 워크트리 마커 (cd-out teardown fallback) ====================
# 실제 $HOME/.claude/worktrees-marker 사용 — 고유 SID + 즉시 정리(실 세션 SID 는 UUID 라 충돌 없음).
WT_MARK_DIR="$HOME/.claude/worktrees-marker"
ssa_mark_ev() { printf '{"session_id":"%s","cwd":"%s"}' "$1" "$2"; }
WTM="$SCRATCH/wtmrepo/.claude/worktrees/cycle-z"; mkdir -p "$WTM"
# write/skip: cwd+SID 조합별 마커 파일 존재 여부
test_ssa_mark() {
  local name="$1"; local sid="$2"; local cwd="$3"; local want="$4"   # want: written|absent
  TOTAL=$((TOTAL+1))
  local mp; mp=$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; wt_marker_path "$1"' _ "$sid")
  rm -f "$mp" 2>/dev/null
  echo "$(ssa_mark_ev "$sid" "$cwd")" | "$HOOKS/session-start-audit.sh" >/dev/null 2>&1
  local got=absent; [ -f "$mp" ] && got=written
  rm -f "$mp" 2>/dev/null
  [ "$got" = "$want" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$name (want=$want got=$got)")
}
test_ssa_mark "156-marker-write"      "wtm156_$$" "$WTM"      written
test_ssa_mark "157-marker-empty-skip" ""          "$WTM"      absent
test_ssa_mark "158-marker-nonwt-skip" "wtm158_$$" "$SCRATCH"  absent
# prune: 기록된 WT_ROOT 부재→마커 제거, 존재→보존 (SessionStart cwd=비-워크트리라 자기 마커는 미기록)
test_ssa_prune() {
  local name="$1"; local target="$2"; local want="$3"   # want: pruned|kept
  TOTAL=$((TOTAL+1))
  mkdir -p "$WT_MARK_DIR" 2>/dev/null
  local psid="wtmp_${name}_$$"
  printf '%s\n' "$target" > "$WT_MARK_DIR/$psid"
  echo "$(ssa_mark_ev "wtmfresh_$$" "$SCRATCH")" | "$HOOKS/session-start-audit.sh" >/dev/null 2>&1
  local got=kept; [ -f "$WT_MARK_DIR/$psid" ] || got=pruned
  rm -f "$WT_MARK_DIR/$psid" 2>/dev/null
  [ "$got" = "$want" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$name (want=$want got=$got)")
}
test_ssa_prune "159-marker-stale-prune" "$SCRATCH/gone-nonexistent-$$" pruned
test_ssa_prune "160-marker-active-keep" "$WTM"                          kept

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

# rot-timing (GAP-018): 350K(rot-zone, opus 1M)에서 PCT=55는 무경고(WARN 45%→THRESHOLD 450K>350K)=재캘리브 前 문제,
# PCT=40은 경고(WARN 30%→THRESHOLD 300K<350K)=rot 이전 조기 발화. auto-compact-watch 파라메트릭(WARN=PCT-10) 관계 가드.
test_acw_rot() {  # $1 name  $2 pct  $3 want(warn|silent)
  TOTAL=$((TOTAL+1))
  local tf; tf=$(mktemp "$SCRATCH/acwrot-XXXXXX.jsonl")
  printf '{"message":{"model":"claude-opus-4-8","usage":{"input_tokens":350000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' > "$tf"
  local sid="acwrot-$$-$1"; rm -f "/tmp/compact-alerted-$sid"
  local out; out=$(echo "{\"session_id\":\"$sid\",\"transcript_path\":\"$tf\"}" | CLAUDE_AUTOCOMPACT_PCT_OVERRIDE="$2" "$HOOKS/auto-compact-watch.sh" 2>&1)
  rm -f "/tmp/compact-alerted-$sid" "$tf"
  local good=0
  if [ "$3" = "warn" ]; then echo "$out" | grep -q 'auto-compact' && good=1
  else [ -z "$out" ] && good=1; fi
  [ "$good" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("auto-compact-watch/$1 (want=$3 got:$out)")
}
test_acw_rot "189-rot-pct55-silent" 55 silent
test_acw_rot "190-rot-pct40-warn"   40 warn

# ==================== PATCH-F: hooks/lib unit tests (extracted parsers, directly testable) ====================
LIB="$HOME/.claude/hooks/lib"
test_lib() {
  local name="$1"; local expected="$2"; local actual="$3"
  TOTAL=$((TOTAL+1))
  [ "$actual" = "$expected" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("hooks-lib/$name (exp=[$expected] got=[$actual])")
}
# transcript-usage.js: max(input+cache_read+cache_creation) over messages + last model
TUF=$(mktemp "$SCRATCH/tu-XXXXXX.jsonl")
printf '{"message":{"model":"claude-opus-4-8","usage":{"input_tokens":300000,"cache_read_input_tokens":180000,"cache_creation_input_tokens":0}}}\n' > "$TUF"
test_lib "70-transcript-usage"   "$(printf '480000\tclaude-opus-4-8')" "$(node "$LIB/transcript-usage.js" "$TUF")"
test_lib "71-transcript-missing" "$(printf '0\t')"                     "$(node "$LIB/transcript-usage.js" /nonexistent/x.jsonl 2>/dev/null)"
# skeleton-scan.js: "<marker> <phase> <agent> <protocol>" (Write uses content; HTML comments stripped before agent count)
SKMD=$'---\norchestrator_skill: true\n---\n# Phase 1\nAgent(subagent_type="x")\n# Phase 2\nAgent(subagent_type="y")\n# Phase 3\nAgent(subagent_type="z")\n## Communication Protocol\n- ok'
test_lib "72-skeleton-complete"  "1 3 3 1" "$(mk_event Write "/tmp/x/skills/foo/SKILL.md" "$SKMD" "/tmp/x" | node "$LIB/skeleton-scan.js")"
SKCOM=$'---\norchestrator_skill: true\n---\n# Phase 1\n# Phase 2\n# Phase 3\n<!-- Agent(subagent_type="x") -->\n## Communication Protocol'
test_lib "73-skeleton-commented" "1 3 0 1" "$(mk_event Write "/tmp/x/skills/foo/SKILL.md" "$SKCOM" "/tmp/x" | node "$LIB/skeleton-scan.js")"
test_lib "74-skeleton-err"       "ERR"     "$(printf 'not json' | node "$LIB/skeleton-scan.js")"
# redirect-targets.js: first redirection/tee target with a code extension (CODE_EXT_REGEX from _common SSOT, via subshell)
LIBREGEX=$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; code_ext_regex')
test_lib "75-redirect-code"      "out.py" "$(CMD='cat > out.py <<EOF' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "76-redirect-doc"       ""       "$(CMD='echo hi > notes.md' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "77-redirect-devnull"   ""       "$(CMD='foo > /dev/null'    CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
# cycle-17 F3: sed -i / cp / mv / python -c open(...,"w") 로 코드파일 쓰기 탐지
test_lib "96-sed-i-code"   "app.js"    "$(CMD='sed -i s/a/b/ app.js' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "97-cp-code"      "deploy.sh" "$(CMD='cp template.txt deploy.sh' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "98-mv-code"      "b.sh"      "$(CMD='mv a.txt b.sh' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "99-pyc-code"     "gen.py"    "$(CMD=$'python3 -c "open(\'gen.py\',\'w\').write(x)"' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "100-sed-i-doc"   ""          "$(CMD='sed -i s/a/b/ notes.md' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "101-cp-doc"      ""          "$(CMD='cp a.txt b.md' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
# cycle-23 D-SIDEDOOR-2: dd/install/rsync/다중 cp·mv(matchAll)/git apply·patch(보수차단 sentinel)
test_lib "110-dd-code"          "x.sh"            "$(CMD='dd if=/dev/zero of=x.sh bs=1' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "111-install-code"     "b.py"            "$(CMD='install -m 755 a b.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "112-rsync-code"       "d.js"            "$(CMD='rsync -a s.txt d.js' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "113-multi-cpmv-2nd"   "d.py"            "$(CMD='cp a b.md; mv c d.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "114-git-apply"        "__PATCH_APPLY__" "$(CMD='git apply fix.patch' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "115-git-apply-check"  ""                "$(CMD='git apply --check fix.patch' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "116-patch-cmd"        "__PATCH_APPLY__" "$(CMD='patch -p1 < fix.patch' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "117-rsync-dir-pass"   ""                "$(CMD='rsync -a src/ dst/' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
# cycle-37: 'install'이 명령이 아니라 경로 substring(setup/install.sh)이면 후행 ≥2 토큰이라도 미탐지(오탐0)
test_lib "154-install-substr-pass" ""             "$(CMD='cat setup/install.sh hooks/foo.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
# cycle-25 rank1: redirect-targets 4벡터 봉인 (단일인용·noclobber·인터프리터eval·따옴표/화살표 오탐)
test_lib "122-redir-singlequote"   "evil.py" "$(CMD="echo x > 'evil.py'" CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "123-redir-noclobber"     "evil.py" "$(CMD='echo x >| evil.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "124-redir-arrow-pass"    ""        "$(CMD='step1 -> output.js' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "125-redir-quoted-msg-pass" ""      "$(CMD='git commit -m "rename a > b.py"' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "126-redir-quoted-target" "out.py"  "$(CMD='cat > "out.py"' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "127-node-eval-code"      "gen.js"  "$(CMD=$'node -e \'fs.writeFileSync("gen.js", x)\'' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "128-perl-eval-code"      "y.pl"    "$(CMD=$'perl -e \'open(F,">","y.pl")\'' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "129-ruby-eval-code"      "z.rb"    "$(CMD=$'ruby -e \'File.write("z.rb", x)\'' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
# cycle-34: >& 파일명 타깃 탐지 (fd-number 는 isCode 로 자연 제외)
test_lib "140-redir-fdamp-code"     "evil.py" "$(CMD='echo x >& evil.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "141-redir-fdamp-num-pass" ""        "$(CMD='ls foo >&2' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
test_lib "142-redir-2to1-pass"      ""        "$(CMD='ls 2>&1' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"
# workflow-spawns.js: agent() 스폰당 "<agentType>\t<model>"
#   model: 리터럴 / 키 부재 = '-' / 키 존재·동적 = '*'  (C15 3값 계약)   ·   agentType: 리터럴 / 키 부재 = '?' / 키 존재·동적 = '*'  (C13 3값 계약)
WS="$LIB/workflow-spawns.js"
test_lib "171-ws-single-bare"   "$(printf 'execute-strict\t-')" \
  "$(printf "await agent('a', {agentType: 'execute-strict'})" | node "$WS")"
test_lib "172-ws-single-model"  "$(printf 'execute-strict\topus')" \
  "$(printf "await agent('a', {agentType: 'execute-strict', model: 'opus'})" | node "$WS")"
test_lib "173-ws-masking"       "$(printf 'execute-strict\topus\nexecute-strict\t-')" \
  "$(printf "await agent('a', {agentType: 'execute-strict', model: 'opus'})\nawait agent('b', {agentType: 'execute-strict'})" | node "$WS")"
test_lib "174-ws-model-first"   "$(printf 'review-strict\tsonnet')" \
  "$(printf "await agent('v', {model: 'sonnet', agentType: 'review-strict'})" | node "$WS")"
test_lib "175-ws-quoted-keys"   "$(printf 'execute-strict\topus')" \
  "$(printf 'await agent("a", {"agentType": "execute-strict", "model": "opus"})' | node "$WS")"
test_lib "176-ws-agentless"     "$(printf '?\t-')" \
  "$(printf "await agent('research', {label: 'r'})" | node "$WS")"
test_lib "177-ws-prompt-noise"  "$(printf 'execute-strict\t-')" \
  "$(printf "const P = \`policy: model: 'opus' required\`\nawait agent(P, {agentType: 'execute-strict'})" | node "$WS")"
test_lib "178-ws-empty"         "" "$(printf '' | node "$WS")"
# C13 closeout — GPT 교차패밀리 리뷰 [A] REAL 정정 회귀 (렉서 전환; spec §12.6)
test_lib "179-ws-string-noise"  "" \
  "$(printf 'const s = "agent(\x27p\x27, {agentType:\x27execute-strict\x27, model:\x27opus\x27})";' | node "$WS")"
test_lib "180-ws-decl-not-call" "" "$(printf 'function agent(prompt, opts) {}' | node "$WS")"
test_lib "181-ws-member-call"   "" "$(printf "obj.agent('p', {agentType:'execute-strict'})" | node "$WS")"
test_lib "182-ws-dollar-ident"  "" "$(printf "my\$agent('p', {agentType:'execute-strict'})" | node "$WS")"
test_lib "183-ws-comment-field" "$(printf 'execute-strict\t-')" \
  "$(printf "agent('p', {\n agentType:'execute-strict'\n /* model:'opus' */\n})" | node "$WS")"
test_lib "184-ws-regex-paren"   "$(printf 'execute-strict\topus')" \
  "$(printf "agent(\n String(/[)]/),\n {agentType:'execute-strict', model:'opus'}\n)" | node "$WS")"
test_lib "185-ws-nested-tmpl"   "$(printf 'execute-strict\t-')" \
  "$(printf "agent(\n \`outer \${\`model: 'opus'\`}\`,\n {agentType:'execute-strict'}\n)" | node "$WS")"
test_lib "186-ws-dynamic-model" "$(printf 'execute-strict\t*')" \
  "$(printf "agent('p', {agentType:'execute-strict', model:\`\${MODE}\`})" | node "$WS")"
# C15: model 축 3값 — 동적 선언(키 존재·비-리터럴)은 '-'(키 부재)와 구분해 '*' 로 방출 (spec §14.1)
test_lib "204-ws-dynamic-model-call" "$(printf 'execute-strict\t*')" \
  "$(printf "%s" "agent('p', {agentType:'execute-strict', model: chooseModel()})" | node "$WS")"
test_lib "205-ws-dynamic-model-vs-absent" "$(printf 'general-purpose\t*\ngeneral-purpose\t-')" \
  "$(printf "agent('a', {agentType:'general-purpose', model: M})\nagent('b', {agentType:'general-purpose'})" | node "$WS")"
# C15 GPT 교차리뷰 정정 회귀 (X1/X2/X3/X4/X6 — spec §14.5)
test_lib "206-ws-shorthand-model" "$(printf 'general-purpose\t*')" \
  "$(printf "%s" "agent('p', {agentType: 'general-purpose', model})" | node "$WS")"
test_lib "207-ws-shorthand-dup-lww" "$(printf 'execute-strict\t*')" \
  "$(printf "%s" "agent('p', {agentType: 'execute-strict', model: 'opus', model})" | node "$WS")"
WS_UKEY=$(mktemp "$SCRATCH/ws-ukey-XXXXXX.js")
printf 'agent("p", {agentType: "general-purpose", mo\\u0064el: f()})' > "$WS_UKEY"
test_lib "208-ws-unicode-ident-key" "$(printf 'general-purpose\t*')" "$(node "$WS" < "$WS_UKEY")"
test_lib "209-ws-computed-key-prefix" "$(printf 'execute-strict\t-')" \
  "$(printf "agent('p', {agentType: 'execute-strict', ['model' + 'X']: 'opus'})" | node "$WS")"
WS_TMPLPROP=$(mktemp "$SCRATCH/ws-tmplprop-XXXXXX.js")
printf 'agent("p", {label: `t-${x}`, agentType: "general-purpose", model: f()})' > "$WS_TMPLPROP"
test_lib "210-ws-tmpl-prop-before" "$(printf 'general-purpose\t*')" "$(node "$WS" < "$WS_TMPLPROP")"
test_lib "211-ws-grouped-literal-model" "$(printf 'execute-strict\tfable')" \
  "$(printf "agent('p', {agentType: 'execute-strict', model: ('fable')})" | node "$WS")"
test_lib "187-ws-firstarg-obj"  "$(printf 'execute-strict\t-')" \
  "$(printf "agent(\n makePrompt({model:'opus'}),\n {agentType:'execute-strict'}\n)" | node "$WS")"
test_lib "188-ws-nested-prop"   "$(printf 'review-strict\topus')" \
  "$(printf "agent('p', {agentType:'review-strict', meta:{model:'haiku'}, model:'opus'})" | node "$WS")"
test_lib "189-ws-dup-lastwins"  "$(printf 'execute-strict\tfable')" \
  "$(printf "agent('p', {agentType:'execute-strict', model:'opus', model:'fable'})" | node "$WS")"
test_lib "190-ws-suffix-key"    "$(printf '?\t-')" \
  "$(printf "agent('p', {myagentType:'execute-strict', fallback_model:'opus'})" | node "$WS")"
test_lib "191-ws-ternary-key"   "$(printf 'execute-strict\t-')" \
  "$(printf "agent('p', {agentType:'execute-strict', x: cond ? \"model\" : \"opus\"})" | node "$WS")"
test_lib "192-ws-computed-key"  "$(printf 'execute-strict\tfable')" \
  "$(printf "agent('p', {['agentType']:'execute-strict', ['model']:'fable'})" | node "$WS")"
test_lib "195-ws-escape-decode" "$(printf 'execute-strict\tfable')" \
  "$(printf "agent('p', {agentType:'execute\\\\u002dstrict', model:'\\\\x66able'})" | node "$WS")"
# 값이 여러 물리 행이 되면 "스폰당 1행" 계약이 깨져 bash read 가 필드를 분해한다 (line continuation)
WS_CONT=$(mktemp "$SCRATCH/ws-cont-XXXXXX.js")
printf 'agent(%s, {agentType:%s, model:`fa\\\nble`})\n' "'p'" "'execute-strict'" > "$WS_CONT"
test_lib "196-ws-line-continuation" "$(printf 'execute-strict\tfable')" "$(node "$WS" < "$WS_CONT")"
test_lib "198-ws-dynamic-type"  "$(printf '*\t-')" \
  "$(printf "agent('p', {agentType: TYPE})" | node "$WS")"
# 닫히지 않는 후보 반복이 O(N²) 로 정지 불능이 되지 않음 (시도 상한) — 10s 안에 반환
WS_BOMB=$(node -e 'process.stdout.write("agent(".repeat(20000))')
test_lib "199-ws-halting-bound" "ok" \
  "$(printf '%s' "$WS_BOMB" | timeout 10 node "$WS" >/dev/null 2>&1 && echo ok || echo timeout)"
# C14: 삼항 opts — 두 분기를 각각 스폰으로 방출(준수 리터럴이 무선언을 가리지 않음, spec §13.7)
test_lib "200-ws-ternary-opts-both" \
  "$(printf 'execute-strict\topus\nexecute-strict\t-')" \
  "$(printf "%s" "await agent('p', h ? {agentType:'execute-strict',model:'opus'} : {agentType:'execute-strict'})" | node "$WS")"
# C14: 첫 인자의 화살표 함수 본문이 진짜 opts 를 **가리지 않는다** — 후보 전수 수집이라 둘 다 방출된다.
#   종전엔 '?\t-' 1행만 나와 execute-strict/opus 선언이 통째로 소실됐다(미탐). 이제 2행이며
#   첫 행 '?\t-' 는 화살표 본문(안전 방향 오탐 — spec §13.7 정직 공개), 둘째 행이 진짜 opts.
test_lib "201-ws-firstarg-arrow-body" \
  "$(printf '?\t-\nexecute-strict\topus')" \
  "$(printf "%s" "await agent(()=>{return 1},{agentType:'execute-strict',model:'opus'})" | node "$WS")"
# C14: 검증자 축도 동일 — 삼항의 하향 분기가 소실되지 않는다
test_lib "202-ws-ternary-verifier" \
  "$(printf 'review-strict\topus\nreview-strict\thaiku')" \
  "$(printf "%s" "await agent('v', ok ? {agentType:'review-strict',model:'opus'} : {agentType:'review-strict',model:'haiku'})" | node "$WS")"
# C14 (GPT 교차리뷰): 그룹핑 괄호로 감싼 삼항도 두 분기를 방출한다 — 괄호 하나로 마스킹이 부활하던 결함.
test_lib "203-ws-grouped-ternary" \
  "$(printf 'review-strict\topus\nreview-strict\thaiku')" \
  "$(printf "%s" "agent('v', (ok ? {agentType:'review-strict',model:'opus'} : {agentType:'review-strict',model:'haiku'}))" | node "$WS")"
# cycle-26 rank3: plan_status bold-only + 펜스 스킵 (prose 'Status: active' 게이트 오개방 봉인)
PS_PROSE=$(mktemp "$SCRATCH/ps-XXXXXX.md"); printf '# Plan\nStatus: active\n\n**Status:** completed\n' > "$PS_PROSE"
test_lib "136-planstatus-prose-skip" "completed" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; plan_status "$1"' _ "$PS_PROSE")"
PS_FENCE=$(mktemp "$SCRATCH/ps-XXXXXX.md"); printf '# Plan\n```\n**Status:** active\n```\n**Status:** completed\n' > "$PS_FENCE"
test_lib "137-planstatus-fence-skip" "completed" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; plan_status "$1"' _ "$PS_FENCE")"
PS_REAL=$(mktemp "$SCRATCH/ps-XXXXXX.md"); printf '**Status:** active\n' > "$PS_REAL"
test_lib "138-planstatus-real-active" "active" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; plan_status "$1"' _ "$PS_REAL")"
# cycle-34: ~~~ (tilde) 펜스 내 active 누출 봉인
PS_TILDE=$(mktemp "$SCRATCH/ps-XXXXXX.md"); printf '# Plan\n~~~\n**Status:** active\n~~~\n**Status:** completed\n' > "$PS_TILDE"
test_lib "144-planstatus-tilde-fence-skip" "completed" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; plan_status "$1"' _ "$PS_TILDE")"
# model-window.js: 모델명 -> 컨텍스트 창 (CONTEXT_LIMIT override)
test_lib "78-modelwin-opus"     "1000000" "$(node "$LIB/model-window.js" claude-opus-4-8)"
test_lib "79-modelwin-default"  "200000"  "$(node "$LIB/model-window.js" claude-sonnet-4-6)"
test_lib "80-modelwin-override" "300000"  "$(CONTEXT_LIMIT=300000 node "$LIB/model-window.js" claude-sonnet-4-6)"
test_lib "121-modelwin-fable"   "1000000" "$(node "$LIB/model-window.js" claude-fable-5)"
# GAP-010 (C9): /1m/ 행 커버 (opus/fable 미매칭·"1m" 토큰만으로 1M 해소) + 프로덕션 [1m] suffix ID (autocompact 워크어라운드 load-bearing)
test_lib "193-modelwin-1m"            "1000000" "$(node "$LIB/model-window.js" claude-neo-1m)"
test_lib "194-modelwin-opus-1m-suffix" "1000000" "$(node "$LIB/model-window.js" 'claude-opus-4-8[1m]')"

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

# C15-E (spec §14.3): active plan 존재 시 stdout [resume] 1줄 (SessionStart stdout→컨텍스트 채널), 부재 시 무출력
# HOME override 금지 — session-start-audit.sh:2 가 $HOME/.claude/hooks/_common.sh 를 source 하므로 override 시
#   resolve_cwd 미정의 → CWD="" → plan 블록 미진입(픽스처 구조적 GREEN 불가). stdin cwd 전달 + 실 HOME 은
#   test_ssa_mark 선례와 동형이며, 실 HOME 의 audit/메모리/plugin 블록은 전부 stderr 라 stdout 단언을 오염하지 않는다.
test_ssa_resume() {
  local name="$1"; local expect="$2"; local plan_body="$3"; local src="${4:-}"
  TOTAL=$((TOTAL+1))
  local D="$SCRATCH/ssa-resume-$name"; mkdir -p "$D/docs/superpowers/plans"
  [ -n "$plan_body" ] && printf '%s\n' "$plan_body" > "$D/docs/superpowers/plans/p.md"
  local out rc
  out=$(printf '{"cwd":"%s","session_id":"ssa-res-%s"%s}' "$D" "$$" "${src:+,\"source\":\"$src\"}" | bash "$HOOKS/session-start-audit.sh" 2>/dev/null); rc=$?
  local ok=0
  if [ "$expect" = "EMPTY" ]; then { [ -z "$out" ] && [ "$rc" = "0" ]; } && ok=1
  else { printf '%s' "$out" | grep -qE "$expect" && [ "$rc" = "0" ]; } && ok=1; fi
  [ "$ok" = "1" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-start-audit/$name (rc=$rc out=${out:0:60})")
}
test_ssa_resume "08-resume-active-plan" '^\[resume\] active plan: p\.md \(미체크 1\)' $'**Status:** active\n- [ ] Task 1\n- [x] Task 0'
test_ssa_resume "09-resume-no-active" EMPTY $'**Status:** completed\n- [x] Task 1'
# C15 GPT 정정(X13): 같은 세션의 compact SessionStart 는 [resume] 억제 — source 게이트
test_ssa_resume "10-resume-compact-suppressed" EMPTY $'**Status:** active\n- [ ] Task 1' compact

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

# ==================== PATCH-H: SPEC-BEFORE-PLAN GATE (enforce-rpi-cycle) ====================
SBP_NO="$SCRATCH/sbp_nospec"; mkdir -p "$SBP_NO/docs/superpowers/plans"
SBP_OK="$SCRATCH/sbp_spec";  mkdir -p "$SBP_OK/docs/superpowers/plans" "$SBP_OK/docs/superpowers/specs"
printf '# d\n' > "$SBP_OK/docs/superpowers/specs/x-design.md"
PLANBODY=$'# Plan\n**Status:** active\n- [ ] step1\n- [ ] step2'
test_erc "28-plan-no-spec-block"  2 "$(mk_event Write "$SBP_NO/docs/superpowers/plans/p.md" "$PLANBODY" "$SBP_NO")"
test_erc "29-plan-with-spec-pass" 0 "$(mk_event Write "$SBP_OK/docs/superpowers/plans/p.md" "$PLANBODY" "$SBP_OK")"
test_erc_plan_skip() {
  local input; input=$(mk_event Write "$SBP_NO/docs/superpowers/plans/p.md" "$PLANBODY" "$SBP_NO")
  TOTAL=$((TOTAL+1))
  local actual; actual=$(echo "$input" | RPI_SKIP=hotfix "$HOOKS/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
  [ "$actual" = "0" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("enforce-rpi-cycle/30-plan-no-spec-skip (got=$actual)")
}
test_erc_plan_skip

# ==================== CYCLE-16: SURFACE-CONSTITUTION (advisory §5/§8 JIT) ====================
# Output-based: assert additionalContext emitted (alert) vs not (silent). Exit always 0.
rm -f /tmp/surface-adr-sct* /tmp/surface-ui-sct* 2>/dev/null
sc_ev() { printf '{"session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" "$2"; }
test_sc() {
  local name="$1"; local want="$2"; local input="$3"; local pat="${4:-additionalContext}"
  TOTAL=$((TOTAL+1))
  local out got=silent
  out=$(echo "$input" | "$HOOKS/surface-constitution.sh" 2>/dev/null)
  echo "$out" | grep -qF "$pat" && got=alert
  [ "$got" = "$want" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("surface-constitution/$name (want=$want got=$got)")
}
test_sc "90-section5-manifest" alert  "$(sc_ev sct90 "$SCRATCH/proj/package.json")" "ADR"
test_sc "91-section8-ui"       alert  "$(sc_ev sct91 "$SCRATCH/proj/Button.tsx")"   "ui-design"
test_sc "92-nonmatch-silent"   silent "$(sc_ev sct92 "$SCRATCH/proj/README.md")"
touch /tmp/surface-adr-sct93 2>/dev/null
test_sc "93-dedup-silent"      silent "$(sc_ev sct93 "$SCRATCH/proj/package.json")"
rm -f /tmp/surface-adr-sct93 2>/dev/null

# ==================== CYCLE-35: BYPASS SURFACING (G3-a) + LOG CONSUMPTION (G6-c) ====================
# 출력 기반: bypass 분기가 additionalContext 로 우회를 표면화(alert) vs 무(silent). exit 항상 0(기존 skip 테스트 불변).
test_bypass() {
  local name="$1"; local hook="$2"; local input="$3"; local env_pfx="$4"; local sid="$5"
  TOTAL=$((TOTAL+1))
  rm -f /tmp/bypass-*-"$sid" 2>/dev/null
  local out got=silent
  out=$(echo "$input" | env $env_pfx "$HOOKS/$hook" 2>/dev/null)
  { echo "$out" | grep -qF 'additionalContext' && echo "$out" | grep -qF '우회'; } && got=alert
  rm -f /tmp/bypass-*-"$sid" 2>/dev/null
  [ "$got" = alert ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("$name (want=alert got=$got)")
}
bsid_ev() { printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$2" "$3"; }
wsid_ev() { SID="$1" FILE="$2" CONTENT="$3" CWD="$4" node -e 'console.log(JSON.stringify({session_id:process.env.SID,tool_name:"Write",tool_input:{file_path:process.env.FILE,content:process.env.CONTENT},cwd:process.env.CWD}))'; }
test_bypass "150-bypass-rpibash-surface"    "enforce-rpi-bash.sh"    "$(bsid_ev byp35a 'echo x > foo.py' "$NP")"     "RPI_SKIP=hotfix"           byp35a
test_bypass "151-bypass-secretscan-surface" "enforce-secret-scan.sh" "$(bsid_ev byp35b 'echo hello world' "$NP")"    "SECRET_SCAN_SKIP=approved" byp35b
test_bypass "152-bypass-rpicycle-surface"   "enforce-rpi-cycle.sh"   "$(wsid_ev byp35c "$NP/src/x.ts" "$BIG" "$NP")" "RPI_SKIP=hotfix"           byp35c
# cycle-35: log_summary 당월 집계 (G6-c, 값 미표시 — 카운트만)
LOGT=$(mktemp "$SCRATCH/logsum-XXXXXX.log")
{ printf 'ts\tenforce-rpi-bash\tx.py\tBLOCK\tno-active-plan\n'
  printf 'ts\tenforce-rpi-cycle\ty.sh\tBLOCK\tno-active-plan\n'
  printf 'ts\tenforce-rpi-bash\tbash\tPASS\tskip:hotfix\n'
  printf 'ts\tredirect-targets.js\tparser\tFAILOPEN\tparser-exit-1\n'; } > "$LOGT"
test_lib "153-logsummary-counts" "BLOCK=2 SKIP=1 FAILOPEN=1 ALERT=0" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; log_summary "$1"' _ "$LOGT")"

# ==================== CYCLE-52 (GAP-003): 사이클 run-log JSONL (hook_log 피기백 + runlog_summary) ====================
# rl-171: hook_log 초크포인트가 run_log_event 를 피기백해 RUNLOG_DIR 에 유효 JSONL 1줄(gen_ai.* 필드) 방출.
#         node 는 마지막 줄 JSON.parse 유효성만; 필드는 grep(값 미노출). RUNLOG_DIR override = hermetic.
RLD1="$SCRATCH/rl171"
RUNLOG_DIR="$RLD1" RL_SID="s171" RL_TOOL="Bash" bash -c 'source "$HOME/.claude/hooks/_common.sh"; hook_log "enforce-rpi-bash" "foo.py" "BLOCK" "no-active-plan"' 2>/dev/null
RLF1=$(ls "$RLD1"/*.jsonl 2>/dev/null | head -1)
TOTAL=$((TOTAL+1)); g_rl1=bad
if [ -n "$RLF1" ] \
   && node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split(/\n/).pop())' "$RLF1" 2>/dev/null \
   && grep -q '"verdict":"BLOCK"' "$RLF1" && grep -q '"gen_ai.tool.name":"Bash"' "$RLF1" && grep -q '"session_id":"s171"' "$RLF1"; then g_rl1=ok; fi
[ "$g_rl1" = ok ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("run-log/rl-171-emit-chain (got=$g_rl1)")

# rl-172: 우회(skip) verdict 도 JSONL 로 방출 — PASS + reason skip: 캡처(우회 관측).
RLD2="$SCRATCH/rl172"
RUNLOG_DIR="$RLD2" RL_SID="s172" RL_TOOL="Write" bash -c 'source "$HOME/.claude/hooks/_common.sh"; hook_log "enforce-rpi-cycle" "x.ts" "PASS" "skip:hotfix"' 2>/dev/null
RLF2=$(ls "$RLD2"/*.jsonl 2>/dev/null | head -1)
TOTAL=$((TOTAL+1)); g_rl2=bad
if [ -n "$RLF2" ] && grep -q '"verdict":"PASS"' "$RLF2" && grep -q '"reason":"skip:hotfix"' "$RLF2"; then g_rl2=ok; fi
[ "$g_rl2" = ok ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("run-log/rl-172-emit-bypass (got=$g_rl2)")

# rl-173: runlog_summary 가 JSONL 을 소비해 verdict 카운트 출력(closeout 소비 원천, 값 미노출).
RLJT=$(mktemp "$SCRATCH/rljson-XXXXXX.jsonl")
{ printf '{"verdict":"BLOCK","reason":"no-active-plan"}\n'
  printf '{"verdict":"BLOCK","reason":"no-active-plan"}\n'
  printf '{"verdict":"PASS","reason":"skip:hotfix"}\n'
  printf '{"verdict":"PASS","reason":"plan=p.md"}\n'
  printf '{"verdict":"FAILOPEN","reason":"parser-exit-1"}\n'; } > "$RLJT"
test_lib "rl-173-runlog-summary" "EVENTS=5 BLOCK=2 PASS=2 SKIP=1 FAILOPEN=1 ALERT=0" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; runlog_summary "$1"' _ "$RLJT")"

# ==================== CYCLE-53 (GAP-002): 세션 예산 governor ====================
# 기본 OFF + 임계 차단 + 우회 + 80% 경고. BUDGET_DIR override 로 hermetic(카운터 격리).
sb_ev() { printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":"echo x"},"cwd":"%s"}' "$1" "$SCRATCH"; }
SBDIR="$SCRATCH/sbudget"; mkdir -p "$SBDIR"
# sb-180: SESSION_TOOL_BUDGET 미설정 → 무영향(exit 0), 카운터 미생성
TOTAL=$((TOTAL+1))
sb180=$(echo "$(sb_ev sb180)" | BUDGET_DIR="$SBDIR" "$HOOKS/enforce-session-budget.sh" >/dev/null 2>&1; echo $?)
[ "$sb180" = 0 ] && [ ! -f "$SBDIR/sb180" ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-budget/sb-180-off-noop (exit=$sb180)")
# sb-181: 예산 내(budget=5, 첫 호출→1) → exit 0 + 카운터=1
TOTAL=$((TOTAL+1))
sb181=$(echo "$(sb_ev sb181)" | SESSION_TOOL_BUDGET=5 BUDGET_DIR="$SBDIR" "$HOOKS/enforce-session-budget.sh" >/dev/null 2>&1; echo $?)
[ "$sb181" = 0 ] && [ "$(cat "$SBDIR/sb181" 2>/dev/null)" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-budget/sb-181-under (exit=$sb181 cnt=$(cat "$SBDIR/sb181" 2>/dev/null))")
# sb-182: 예산 초과(budget=2, 카운터 프리시드 2 → 3>2) → exit 2 (차단)
TOTAL=$((TOTAL+1)); echo 2 > "$SBDIR/sb182"
sb182=$(echo "$(sb_ev sb182)" | SESSION_TOOL_BUDGET=2 BUDGET_DIR="$SBDIR" "$HOOKS/enforce-session-budget.sh" >/dev/null 2>&1; echo $?)
[ "$sb182" = 2 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-budget/sb-182-over-block (exit=$sb182 want 2)")
# sb-183: GOAL_BUDGET_SKIP + 초과 → exit 0 (우회)
TOTAL=$((TOTAL+1)); echo 5 > "$SBDIR/sb183"
sb183=$(echo "$(sb_ev sb183)" | SESSION_TOOL_BUDGET=2 GOAL_BUDGET_SKIP=extend BUDGET_DIR="$SBDIR" "$HOOKS/enforce-session-budget.sh" >/dev/null 2>&1; echo $?)
[ "$sb183" = 0 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-budget/sb-183-skip-bypass (exit=$sb183 want 0)")
# sb-184: 80% 경고 방출(budget=5, 프리시드 3 → 4≥ceil(4)) → additionalContext 출력(FLAG A: 경고 브랜치 단언)
TOTAL=$((TOTAL+1)); echo 3 > "$SBDIR/sb184"
sb184out=$(echo "$(sb_ev sb184)" | SESSION_TOOL_BUDGET=5 BUDGET_DIR="$SBDIR" "$HOOKS/enforce-session-budget.sh" 2>/dev/null)
echo "$sb184out" | grep -q 'additionalContext' && echo "$sb184out" | grep -q '80%' && PASSED=$((PASSED+1)) || FAILED_LIST+=("session-budget/sb-184-warn-emit (no additionalContext)")

# ==================== CYCLE-40: PRETOOLUSE 워크트리 마커 WRITE (실-입력 shape) + wt_root_from_path 단위 ====================
# 주: test_lib(538) 정의 이후 배치 — 165/166 가 test_lib 사용. 실 $HOME/.claude/worktrees-marker 사용(고유 SID+즉시 정리).
# 실-입력 shape: cwd=메인 레포 루트(워크트리 아님) + tool_input 에 워크트리 절대경로 → record 가 마커 기록.
# (cycle-39 가 놓친 입력 shape — 합성 worktree-cwd 를 먹이지 않는다.)
PTU_MAIN="$SCRATCH/pturepo"; PTUWT="$PTU_MAIN/.claude/worktrees/cycle-p"; mkdir -p "$PTUWT/app" "$PTU_MAIN/src"
WTROOT_P="$PTU_MAIN/.claude/worktrees/cycle-p"
# printf 로 직접 구성(node env 미경유) — node 에 경로를 env 로 넘기면 MSYS2 가 /tmp→C:/... 로 자동변환해
# 마커내용(Windows형) vs 기대 WTROOT_P(MSYS형)가 불일치한다. mk_event/ssa_mark_ev 선례대로 경로는 직접 보간.
ptu_cycle_ev() { printf '{"session_id":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":"x"},"cwd":"%s"}' "$1" "$2" "$3"; }
ptu_bash_ev()  { printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$2" "$3"; }
test_ptu_mark() {
  local name="$1" hook="$2" input="$3" sid="$4" want="$5" wantval="${6:-}"   # want: written|absent
  TOTAL=$((TOTAL+1))
  local mp; mp=$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; wt_marker_path "$1"' _ "$sid")
  rm -f "$mp" 2>/dev/null
  echo "$input" | "$HOOKS/$hook" >/dev/null 2>&1
  local got=absent; [ -f "$mp" ] && got=written
  local okk=0
  if [ "$got" = "$want" ]; then
    if [ "$want" = "written" ] && [ -n "$wantval" ]; then
      [ "$(head -1 "$mp" 2>/dev/null)" = "$wantval" ] && okk=1
    else okk=1; fi
  fi
  rm -f "$mp" 2>/dev/null
  [ "$okk" = 1 ] && PASSED=$((PASSED+1)) || FAILED_LIST+=("$name (want=$want/$wantval got=$got)")
}
test_ptu_mark "161-ptu-cycle-write"      "enforce-rpi-cycle.sh" "$(ptu_cycle_ev "ptu161_$$" "$PTUWT/app/foo.ts" "$PTU_MAIN")"     "ptu161_$$" written "$WTROOT_P"
test_ptu_mark "162-ptu-cycle-empty-skip" "enforce-rpi-cycle.sh" "$(ptu_cycle_ev "" "$PTUWT/app/foo.ts" "$PTU_MAIN")"              ""          absent
test_ptu_mark "163-ptu-cycle-nonwt-skip" "enforce-rpi-cycle.sh" "$(ptu_cycle_ev "ptu163_$$" "$PTU_MAIN/src/foo.ts" "$PTU_MAIN")" "ptu163_$$" absent
test_ptu_mark "164-ptu-bash-write"       "enforce-rpi-bash.sh"  "$(ptu_bash_ev "ptu164_$$" "cd $PTUWT/app && npm i" "$PTU_MAIN")" "ptu164_$$" written "$WTROOT_P"
# wt_root_from_path 단위: 경로 추출 + worktrees-marker/ 자기-비매칭(record 가 잘못된 마커를 쓰지 않게 하는 안전 속성)
test_lib "165-wtroot-extract" "/tmp/r/.claude/worktrees/cyc-x" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; wt_root_from_path "$1"' _ "/tmp/r/.claude/worktrees/cyc-x/app/f.ts")"
test_lib "166-wtroot-markerdir-nomatch" "" "$(bash -c 'source "$HOME/.claude/hooks/_common.sh"; wt_root_from_path "$1" || true' _ "$HOME/.claude/worktrees-marker/sid")"

# ==================== CYCLE-41: self-healing sweep (prunable+고아 worktree-* 청소, 활성/비-컨벤션 보호) ====================
SWREPO="$SCRATCH/swrepo"; mkdir -p "$SWREPO"
git -C "$SWREPO" init -q 2>/dev/null; git -C "$SWREPO" config user.email t@t 2>/dev/null; git -C "$SWREPO" config user.name t 2>/dev/null
git -C "$SWREPO" commit -q --allow-empty -m init 2>/dev/null
mkdir -p "$SWREPO/.claude/worktrees"
git -C "$SWREPO" worktree add -q -b worktree-cycle-a "$SWREPO/.claude/worktrees/a" 2>/dev/null; rm -rf "$SWREPO/.claude/worktrees/a"   # dir 제거 → prunable + 고아 브랜치
git -C "$SWREPO" worktree add -q -b worktree-cycle-b "$SWREPO/.claude/worktrees/b" 2>/dev/null                                         # 활성 → 보호
git -C "$SWREPO" branch keepme 2>/dev/null                                                                                             # 비-컨벤션 → 보호
bash -c 'source "$HOME/.claude/hooks/_common.sh"; sweep_orphan_worktrees "$1"' _ "$SWREPO"
test_lib "167-sweep-prunable-zero"  "0"                "$(git -C "$SWREPO" worktree list --porcelain 2>/dev/null | grep -c prunable)"
test_lib "168-sweep-orphan-deleted" ""                 "$(git -C "$SWREPO" branch --list worktree-cycle-a | tr -d ' ')"
test_lib "169-sweep-active-kept"    "worktree-cycle-b" "$(git -C "$SWREPO" branch --list worktree-cycle-b | tr -d ' +*')"
test_lib "170-sweep-nonconv-kept"   "keepme"           "$(git -C "$SWREPO" branch --list keepme | tr -d ' ')"

# ==================== SURFACE-MODEL-POLICY (tri-model C11) ====================
# stdin 은 2026-07-25 실측 캡처 shape verbatim (spec §1.2) — 합성 shape 금지 (cycle-40 교훈).
mk_agent_event() {
  local sub="$1"; local model="$2"; local transcript="$3"; local sid="$4"
  SUB="$sub" MODEL="$model" TP="$transcript" SID="$sid" node -e '
    const ti = {description:"x", prompt:"x", subagent_type:process.env.SUB, run_in_background:false};
    if (process.env.MODEL) ti.model = process.env.MODEL;
    const o = {session_id:process.env.SID, transcript_path:process.env.TP, cwd:"", permission_mode:"bypassPermissions",
               effort:{level:"xhigh"}, hook_event_name:"PreToolUse", tool_name:"Agent", tool_input:ti, tool_use_id:"toolu_x"};
    console.log(JSON.stringify(o));
  '
}
test_smp() {
  local name="$1"; local expected_exit="$2"; local expect_ctx="$3"; local input="$4"
  TOTAL=$((TOTAL+1))
  local out actual ctx=0
  out=$(printf '%s' "$input" | "$HOOKS/surface-model-policy.sh" 2>/dev/null); actual=$?
  printf '%s' "$out" | grep -q 'additionalContext' && ctx=1
  if [ "$actual" = "$expected_exit" ] && [ "$ctx" = "$expect_ctx" ]; then PASSED=$((PASSED+1))
  else FAILED_LIST+=("surface-model-policy/$name (exit=$actual ctx=$ctx)"); fi
}
rm -f /tmp/model-policy-a-smp* /tmp/model-policy-b-smp* /tmp/model-policy-c-smp* /tmp/model-policy-c2-smp* /tmp/model-policy-c2l-smp* /tmp/model-policy-c3-smp* 2>/dev/null   # stale-marker 플레이크 방지 (MSYS PID 재활용 — senior review C12)
SMP_FABLE_T=$(mktemp "$SCRATCH/smp-fable-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-fable-5","content":[]}}\n' > "$SMP_FABLE_T"
SMP_SONNET_T=$(mktemp "$SCRATCH/smp-sonnet-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-sonnet-5","content":[]}}\n' > "$SMP_SONNET_T"
SMP_OPUS_T=$(mktemp "$SCRATCH/smp-opus-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-opus-5","content":[]}}\n' > "$SMP_OPUS_T"
SMP_HAIKU_T=$(mktemp "$SCRATCH/smp-haiku-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-haiku-4-5","content":[]}}\n' > "$SMP_HAIKU_T"
SMP_QUOTE_T=$(mktemp "$SCRATCH/smp-quote-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-fable-5","content":[{"type":"text","text":"claude-opus-5[1m] 언급 텍스트"}]}}\n' > "$SMP_QUOTE_T"

# 01: fable + exec 무지정 → C17 무지정=frontmatter opus(§16.1 실측) — 침묵 전환 (구 ALERT)
test_smp "01-rule-a-fable-nomodel" 0 0 "$(mk_agent_event execute-strict "" "$SMP_FABLE_T" "smp01-$$")"
# 02: fable 세션 + execute-strict + model:'opus' → 정책 준수 (ctx=0)
test_smp "02-rule-a-opus-ok" 0 0 "$(mk_agent_event execute-strict opus "$SMP_FABLE_T" "smp02-$$")"
# 03: fable 세션 + review-strict + model:'sonnet' → Rule B opus-floor 미달 ALERT (ctx=1)
test_smp "03-rule-b-below-opus-floor" 0 1 "$(mk_agent_event review-strict sonnet "$SMP_FABLE_T" "smp03-$$")"
# 04: review-strict + model 무지정(=frontmatter opus) → 무출력 (ctx=0)
test_smp "04-rule-b-nomodel-ok" 0 0 "$(mk_agent_event review-strict "" "$SMP_FABLE_T" "smp04-$$")"
# 05: sonnet 세션 + execute-strict + model 부재 → Rule A 비대상 (ctx=0)
test_smp "05-nonfable-execute-ok" 0 0 "$(mk_agent_event execute-strict "" "$SMP_SONNET_T" "smp05-$$")"
# 06: 깨진 stdin → fail-open exit 0 무출력
test_smp "06-broken-stdin" 0 0 "not-json"
# 07: transcript 부재 → fail-open exit 0 무출력
test_smp "07-no-transcript" 0 0 "$(mk_agent_event execute-strict "" "$SCRATCH/smp-none.jsonl" "smp07-$$")"
# 08: assistant 라인 content 가 타 모델 id 를 인용해도 message.model(첫 매치)로 판정 → Rule A ALERT
#     (C17: 트리거를 명시 inherit 로 — 무지정은 frontmatter opus 라 더는 위반이 아니다. 원 성질=content 인용 면역)
test_smp "08-quoted-id-immune" 0 1 "$(mk_agent_event execute-strict inherit "$SMP_QUOTE_T" "smp08-$$")"

# --- Rule C (Workflow 매처, C12 spec §10): 실측 shape verbatim ---
mk_wf_event() {
  local body_kind="$1"; local body_val="$2"; local transcript="$3"; local sid="$4"
  KIND="$body_kind" VAL="$body_val" TP="$transcript" SID="$sid" node -e '
    const ti = {};
    ti[process.env.KIND] = process.env.VAL;
    const o = {session_id:process.env.SID, transcript_path:process.env.TP, cwd:"", permission_mode:"bypassPermissions",
               effort:{level:"xhigh"}, hook_event_name:"PreToolUse", tool_name:"Workflow", tool_input:ti, tool_use_id:"toolu_x"};
    console.log(JSON.stringify(o));
  '
}
WF_BAD_SCRIPT="export const meta = {name: 'x', description: 'x'}
await agent('do it', {agentType: 'execute-strict'})"
WF_OK_SCRIPT="export const meta = {name: 'x', description: 'x'}
await agent('do it', {agentType: 'execute-strict', model: 'opus'})"
# C17: scriptPath 픽스처(11)의 주제는 "파일 읽기"라 트리거를 명시 inherit 스폰으로 교체(무선언은 침묵 전환)
WF_SP_BAD_CONTENT="export const meta = {name: 'x', description: 'x'}
await agent('do it', {agentType: 'execute-strict', model: 'inherit'})"
WF_SP_BAD=$(mktemp "$SCRATCH/wf-sp-bad-XXXXXX.js"); printf '%s\n' "$WF_SP_BAD_CONTENT" > "$WF_SP_BAD"

# 09: fable + 인라인 wf exec 무선언 → C17 무선언=frontmatter opus 추종 → 침묵 전환 (구 ALERT)
test_smp "09-rule-c-inline-nomodel" 0 0 "$(mk_wf_event script "$WF_BAD_SCRIPT" "$SMP_FABLE_T" "smp09-$$")"
# 10: fable + 인라인 + model:'opus' 존재 → 무출력
test_smp "10-rule-c-inline-opus-ok" 0 0 "$(mk_wf_event script "$WF_OK_SCRIPT" "$SMP_FABLE_T" "smp10-$$")"
# 11: fable + scriptPath 파일에 execute-strict 명시 inherit → ALERT (주제: scriptPath 파일 읽기)
test_smp "11-rule-c-scriptpath-explicit-inherit" 0 1 "$(mk_wf_event scriptPath "$WF_SP_BAD" "$SMP_FABLE_T" "smp11-$$")"
# 12: sonnet 세션 → Rule C 비대상 (무출력)
test_smp "12-rule-c-nonfable-ok" 0 0 "$(mk_wf_event script "$WF_BAD_SCRIPT" "$SMP_SONNET_T" "smp12-$$")"
# 13: scriptPath 파일 부재 → fail-open 무출력
test_smp "13-rule-c-scriptpath-missing" 0 0 "$(mk_wf_event scriptPath "$SCRATCH/wf-none.js" "$SMP_FABLE_T" "smp13-$$")"

# --- Rule C2 (Workflow 검증자 하향) + C7 인용부호 키 정정 (C12 GPT 트리아지 [B]3·[C]7) ---
WF_C2_BAD="export const meta = {name: 'x', description: 'x'}
await agent('verify it', {agentType: 'review-strict',
  model: 'sonnet'})"
WF_C2_OK="export const meta = {name: 'x', description: 'x'}
await agent('verify it', {agentType: 'review-strict', label: 'v'})"
WF_QK_OK='export const meta = {name: "x", description: "x"}
await agent("do it", {agentType: "execute-strict", "model": "opus"})'

# 14: fable + 스크립트가 review-strict 를 model:'sonnet' 으로 스폰 → Rule C2 ALERT
test_smp "14-rule-c2-review-downshift" 0 1 "$(mk_wf_event script "$WF_C2_BAD" "$SMP_FABLE_T" "smp14-$$")"
# 15: review-strict 무model(=frontmatter opus 3 ≥ 폴백 floor 3) → 무출력
test_smp "15-rule-c2-review-nomodel-ok" 0 0 "$(mk_wf_event script "$WF_C2_OK" "$SMP_FABLE_T" "smp15-$$")"
# 16: sonnet + 검증-전용(실행자 전무) + review sonnet → 폴백=opus 상수 3 > 2 — 새로 발화 (구 SILENT)
test_smp "16-rule-c2-fallback-opus-floor" 0 1 "$(mk_wf_event script "$WF_C2_BAD" "$SMP_SONNET_T" "smp16-$$")"
# 17: 인용부호 키 '"model":' 도 선언으로 인정 → Rule C 오탐 없음 (C7 정정)
test_smp "17-rule-c-quotedkey-ok" 0 0 "$(mk_wf_event script "$WF_QK_OK" "$SMP_FABLE_T" "smp17-$$")"
# 18: fable + execute-strict 에 model:'fable' 명시 → 하향 미적용과 동일, Rule C ALERT ([B]1 정정)
WF_FABLE_SCRIPT="export const meta = {name: 'x', description: 'x'}
await agent('do it', {agentType: 'execute-strict', model: 'fable'})"
test_smp "18-rule-c-fable-explicit" 0 1 "$(mk_wf_event script "$WF_FABLE_SCRIPT" "$SMP_FABLE_T" "smp18-$$")"
# 19: transcript 의 model 키가 공백 포함('"model": "...') 이어도 세션 판별 → Rule A ALERT ([B]5 정정)
SMP_SPACED_T=$(mktemp "$SCRATCH/smp-spaced-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model": "claude-fable-5","content":[]}}\n' > "$SMP_SPACED_T"
#     (C17: 트리거를 명시 inherit 로 — 주제=공백 model 키 세션 판별)
test_smp "19-spaced-model-key" 0 1 "$(mk_agent_event execute-strict inherit "$SMP_SPACED_T" "smp19-$$")"

# --- C13: per-spawn 판정 + Rule C3 (spec §12.3) ---
# C17: 20/21 의 주제는 per-spawn 마스킹 해소·프롬프트 노이즈 오인 방지 — 위반 트리거를 명시 inherit 로 교체
WF_MASK="export const meta = {name: 'x', description: 'x'}
await agent('a', {agentType: 'execute-strict', model: 'opus'})
await agent('b', {agentType: 'execute-strict', model: 'inherit'})"
WF_PROMPT_NOISE="export const meta = {name: 'x', description: 'x'}
const P = \`policy: model: 'opus' required\`
await agent(P, {agentType: 'execute-strict', model: 'inherit'})"
WF_COMMENT_ONLY="export const meta = {name: 'x', description: 'x'}
// 배경: execute-strict 는 구현용이다
await agent('research', {label: 'r', model: 'sonnet'})"
WF_FANOUT="export const meta = {name: 'x', description: 'x'}
await agent('research this', {label: 'r'})"
WF_FANOUT_OK="export const meta = {name: 'x', description: 'x'}
await agent('research this', {label: 'r', model: 'sonnet'})"
WF_EX_UP="export const meta = {name: 'x', description: 'x'}
await agent('a', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'sonnet'})"

# 20: 마스킹 — 준수 스폰이 무선언 스폰을 가리지 못함 (per-spawn 판정)
test_smp "20-rule-c-masking-detected" 0 1 "$(mk_wf_event script "$WF_MASK" "$SMP_FABLE_T" "smp20-$$")"
# 21: 프롬프트 문자열의 model: 리터럴은 선언으로 오인되지 않음 (미탐 해소)
test_smp "21-rule-c-prompt-noise" 0 1 "$(mk_wf_event script "$WF_PROMPT_NOISE" "$SMP_FABLE_T" "smp21-$$")"
# 22: 주석에만 execute-strict 언급 + 실제 스폰은 model 선언 → 무발화 (오탐 해소)
test_smp "22-rule-c-comment-no-fp" 0 0 "$(mk_wf_event script "$WF_COMMENT_ONLY" "$SMP_FABLE_T" "smp22-$$")"
# 23: Rule C3 — fable 세션 + agentType-less 무선언 스폰 → ALERT (사각 해소, U1 표적)
test_smp "23-rule-c3-fanout-inherit" 0 1 "$(mk_wf_event script "$WF_FANOUT" "$SMP_FABLE_T" "smp23-$$")"
# 24: 같은 fan-out 이 model 선언 → 무발화
test_smp "24-rule-c3-fanout-declared" 0 0 "$(mk_wf_event script "$WF_FANOUT_OK" "$SMP_FABLE_T" "smp24-$$")"
# 25: 비-fable 세션의 fan-out → Rule C3 비대상
test_smp "25-rule-c3-nonfable-ok" 0 0 "$(mk_wf_event script "$WF_FANOUT" "$SMP_SONNET_T" "smp25-$$")"
# 26: floor — sonnet 세션 + 실행자 opus 상향 + 검증자 sonnet → 작업자 floor 3 > 2 위반 ALERT (C16 임무-분리 — 산식 결과 동일)
test_smp "26-rule-c2-floor-worker" 0 1 "$(mk_wf_event script "$WF_EX_UP" "$SMP_SONNET_T" "smp26-$$")"

# --- C13 closeout: GPT 교차패밀리 리뷰 [C] REAL 정정 (spec §12.6) ---
WF_EX_UP_INHERIT="export const meta = {name: 'x', description: 'x'}
await agent('a', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict'})"
WF_EX_UP_OTHER="export const meta = {name: 'x', description: 'x'}
await agent('a', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'gpt-custom'})"
# C17: 30 의 주제는 3규칙 동시-emit 무손실 — 무선언 exec 를 명시 inherit 로 교체
WF_MULTI="export const meta = {name: 'x', description: 'x'}
await agent('implement', {agentType: 'execute-strict', model: 'inherit'})
await agent('research', {})
await agent('review', {agentType: 'review-strict', model: 'haiku'})"
WF_DYN_TYPE="export const meta = {name: 'x', description: 'x'}
await agent('p', {agentType: TYPE})"

# 27: sonnet + exec opus + review 무지정 → 무지정=frontmatter opus 3 ≥ floor 3 — 침묵 반전 (구 ALERT;
#     구 "model 지우면 경고만 사라지는 거짓 복구" 서사는 신 의미론(무지정=실제 opus)에서 소멸 — §16.2)
test_smp "27-rule-c2-nomodel-above-floor" 0 0 "$(mk_wf_event script "$WF_EX_UP_INHERIT" "$SMP_SONNET_T" "smp27-$$")"
# 28: [C]2 — 기타 모델(tier 0) 검증자도 면제되지 않음
test_smp "28-rule-c2-tier0-not-exempt" 0 1 "$(mk_wf_event script "$WF_EX_UP_OTHER" "$SMP_SONNET_T" "smp28-$$")"
# 29: [C]1 반대 방향 — fable 세션 + 실행자 opus + 검증자 무지정(frontmatter opus 3 ≥ floor 3) → 무발화(정상 경로)
test_smp "29-rule-c2-nomodel-floor-met" 0 0 "$(mk_wf_event script "$WF_EX_UP_INHERIT" "$SMP_FABLE_T" "smp29-$$")"
# 30: [C]5 — C·C3·C2 동시 성립 시 첫 규칙이 나머지를 삼키지 않음(3 규칙 모두 1회 emit)
test_smp_multi() {
  TOTAL=$((TOTAL+1))
  local out; out=$(printf '%s' "$1" | "$HOOKS/surface-model-policy.sh" 2>/dev/null)
  # 3개 규칙 메시지가 **한** additionalContext 에 모두 들어갔는지 (각 메시지가 "[model-policy] Workflow" 로 시작)
  local c; c=$(printf '%s' "$out" | grep -o '\[model-policy\] Workflow' | wc -l)
  if [ "$c" -ge 3 ]; then PASSED=$((PASSED+1))
  else FAILED_LIST+=("surface-model-policy/30-rule-priority-no-loss (msgs=$c)"); fi
}
test_smp_multi "$(mk_wf_event script "$WF_MULTI" "$SMP_FABLE_T" "smp30-$$")"
# 31: [C]4 — 동적 agentType('*')은 상속을 단언할 수 없으므로 Rule C3 대상 아님
test_smp "31-rule-c3-dynamic-type-exempt" 0 0 "$(mk_wf_event script "$WF_DYN_TYPE" "$SMP_FABLE_T" "smp31-$$")"
# C14 Rule C3 축 재정의: model 을 선언하는 frontmatter 가 없는 agentType 은 세션을 상속한다 (spec §13.3)
WF_BUILTIN="export const meta = {name: 'x', description: 'x'}
await agent('research this', {agentType: 'general-purpose', label: 'r'})"
WF_EXPLORE="export const meta = {name: 'x', description: 'x'}
await agent('scan this', {agentType: 'explore-strict', label: 'r'})"
# 32: builtin(general-purpose)은 frontmatter 가 없어 fable 세션에서 역류 → ALERT
test_smp "32-rule-c3-builtin-inherit" 0 1 "$(mk_wf_event script "$WF_BUILTIN" "$SMP_FABLE_T" "smp32-$$")"
# 33: explore-strict 는 frontmatter model: sonnet 보유 → 역류 없음 → 무발화(오탐 방지 대조군)
test_smp "33-rule-c3-explore-declared-ok" 0 0 "$(mk_wf_event script "$WF_EXPLORE" "$SMP_FABLE_T" "smp33-$$")"
# 34: 비-fable 세션은 C3 대상 아님 → 무발화
test_smp "34-rule-c3-builtin-nonfable-ok" 0 0 "$(mk_wf_event script "$WF_BUILTIN" "$SMP_SONNET_T" "smp34-$$")"
# C14 (35): 삼항 opts 마스킹 해소를 hook 경유 E2E 로 실증 — 준수 분기(opus)가 무선언 분기를 가리지 못한다.
#   파서 단위(test_lib)만으론 "hook 이 그 출력으로 실제 발화하는가"를 증언 못 한다(C13 교훈: 파서는
#   정확했는데 hook 이 그 행을 버려 SILENT 였음). 정정 전 SILENT(ctx=0) → 정정 후 ALERT(ctx=1).
#   (C17: else 분기를 명시 inherit 로 — 무선언은 침묵 전환이라 주제(삼항 마스킹 해소)를 봉인 못 한다)
WF_TERNARY="export const meta = {name: 'x', description: 'x'}
await agent('impl', heavy ? {agentType: 'execute-strict', model: 'opus'} : {agentType: 'execute-strict', model: 'inherit'})"
test_smp "35-rule-c-ternary-masking-e2e" 0 1 "$(mk_wf_event script "$WF_TERNARY" "$SMP_FABLE_T" "smp35-$$")"
# C14 (36, GPT 교차리뷰): 명시 `model:'inherit'` 도 세션 상속이므로 C3 대상 — '-'(무선언)만 보던 결함.
WF_EXPL_INHERIT="export const meta = {name: 'x', description: 'x'}
await agent('research', {agentType: 'general-purpose', model: 'inherit'})"
test_smp "36-rule-c3-explicit-inherit" 0 1 "$(mk_wf_event script "$WF_EXPL_INHERIT" "$SMP_FABLE_T" "smp36-$$")"
# C15 (37): 동적 model 선언(execute-strict) — 선언은 존재·값만 런타임 → Rule C 면제 (spec §14.1 매트릭스)
WF_DYN_MODEL="export const meta = {name: 'x', description: 'x'}
await agent('impl', {agentType: 'execute-strict', model: pickModel()})"
test_smp "37-rule-c-dynamic-model-exempt" 0 0 "$(mk_wf_event script "$WF_DYN_MODEL" "$SMP_FABLE_T" "smp37-$$")"
# C15 (38): 동적 model 검증자 — floor 미달 단언 불가 → Rule C2 면제 (tier 0 오평가 방지, spec §14.1)
WF_DYN_REVIEW="export const meta = {name: 'x', description: 'x'}
await agent('impl', {agentType: 'execute-strict', model: 'opus'})
await agent('verify', {agentType: 'review-strict', model: chooseVerifier()})"
test_smp "38-rule-c2-dynamic-model-exempt" 0 0 "$(mk_wf_event script "$WF_DYN_REVIEW" "$SMP_SONNET_T" "smp38-$$")"
# C15 (39): 동적 model fan-out — "무선언"이 아니므로 Rule C3 면제 (파서가 '*' 로 방출, C3 는 '-'/'inherit' 만 매치)
WF_DYN_FANOUT="export const meta = {name: 'x', description: 'x'}
await agent('research', {agentType: 'general-purpose', model: modelFor(i)})"
test_smp "39-rule-c3-dynamic-model-exempt" 0 0 "$(mk_wf_event script "$WF_DYN_FANOUT" "$SMP_FABLE_T" "smp39-$$")"
# C16 §15.1: floor 임무-분리 — Workflow(준수-확인) floor = 작업자 티어. 검증자==작업자면 세션이 위여도 무발화.
WF_WORKER_FLOOR="await agent('impl', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'opus'})"
test_smp "41-rule-c2-worker-floor-ok" 0 0 "$(mk_wf_event script "$WF_WORKER_FLOOR" "$SMP_FABLE_T" "smp41-$$")"
WF_WORKER_FLOOR_S="await agent('impl', {agentType: 'execute-strict', model: 'sonnet'})
await agent('v', {agentType: 'review-strict', model: 'sonnet'})"
test_smp "42-rule-c2-worker-floor-sonnet" 0 0 "$(mk_wf_event script "$WF_WORKER_FLOOR_S" "$SMP_FABLE_T" "smp42-$$")"
# C16 슬롯1 S1/S2 (C17 산식 갱신): 무선언 실행자는 frontmatter opus(3)·명시 inherit/동적은 세션 티어로
# 평가 — 하위 리터럴 실행자가 floor 를 끌어내리지 못함. opus 세션 사용(판정 격리).
WF_MIXED_EXEC="await agent('a', {agentType: 'execute-strict'})
await agent('b', {agentType: 'execute-strict', model: 'sonnet'})
await agent('v', {agentType: 'review-strict', model: 'sonnet'})"
test_smp "43-rule-c2-mixed-inherit-exec" 0 1 "$(mk_wf_event script "$WF_MIXED_EXEC" "$SMP_OPUS_T" "smp43-$$")"
# C16 슬롯2 F4 (C17 산식 갱신): 미지-티어 리터럴 실행자(tier_of=0)는 opus 상수(3)로 평가 — 하위 판별-가능 리터럴이 floor 를 끌어내리지 못함.
WF_UNKNOWN_EXEC="await agent('a', {agentType: 'execute-strict', model: 'gpt-custom'})
await agent('b', {agentType: 'execute-strict', model: 'sonnet'})
await agent('v', {agentType: 'review-strict', model: 'sonnet'})"
test_smp "48-rule-c2-unknown-worker-floor" 0 1 "$(mk_wf_event script "$WF_UNKNOWN_EXEC" "$SMP_FABLE_T" "smp48-$$")"
# C16 senior I1: F4 폴백 평가는 floor 전용 — 미지-티어 리터럴 실행자가 fable 세션 Rule C 를 오발화하지 않음(원시 티어 판정).
#   C17: review 를 fable→opus 로 (A5 미지→opus floor 평가 겸용 — 구: 미지 실행자=세션 상계 4 → opus 3<4 C2 ALERT / 신: 미지=opus 3 → 3≥3 SILENT)
WF_UNKNOWN_ONLY="await agent('a', {agentType: 'execute-strict', model: 'gpt-custom'})
await agent('v', {agentType: 'review-strict', model: 'opus'})"
test_smp "49-rule-c-unknown-literal-exempt" 0 0 "$(mk_wf_event script "$WF_UNKNOWN_ONLY" "$SMP_FABLE_T" "smp49-$$")"
# C16 §15.1: canonical carrier 실물 4세션 E2E — stage2 model:'opus' 명시 후 전 세션 무발화
# (구 carrier: sonnet/haiku 세션 ALERT — §12.1 표의 위반 칸이 §15.1 로 소멸함을 실물로 봉인. 슬롯1 S12)
WF_CANON="$(cat "$HOME/.claude/workflows/rpi-implement.js")"
test_smp "44-canonical-fable-silent" 0 0 "$(mk_wf_event script "$WF_CANON" "$SMP_FABLE_T" "smp44-$$")"
test_smp "45-canonical-opus-silent" 0 0 "$(mk_wf_event script "$WF_CANON" "$SMP_OPUS_T" "smp45-$$")"
test_smp "46-canonical-sonnet-silent" 0 0 "$(mk_wf_event script "$WF_CANON" "$SMP_SONNET_T" "smp46-$$")"
test_smp "47-canonical-haiku-silent" 0 0 "$(mk_wf_event script "$WF_CANON" "$SMP_HAIKU_T" "smp47-$$")"
# C15 GPT 정정(X8): C3 hedge 내용 봉인 — additionalContext 존재만 보던 픽스처는 hedge 원복을 못 잡는다
test_smp_hedge() {
  TOTAL=$((TOTAL+1))
  rm -f /tmp/model-policy-c3-smp40-* 2>/dev/null
  local out; out=$(printf '%s' "$1" | "$HOOKS/surface-model-policy.sh" 2>/dev/null)
  if printf '%s' "$out" | grep -q '자체 바인딩'; then PASSED=$((PASSED+1))
  else FAILED_LIST+=("surface-model-policy/40-c3-hedge-content"); fi
}
test_smp_hedge "$(mk_wf_event script "$WF_BUILTIN" "$SMP_FABLE_T" "smp40-$$")"

# --- C17 (spec §16): Rule A/B v2(fable-누출 + opus-floor) · C2 폴백 opus 상수 · C2-leak 신설 ---
# C17 (50): Rule A 유지 arm — fable 세션 명시 inherit 실행자 = fable 누출 → ALERT
test_smp "50-rule-a-explicit-inherit" 0 1 "$(mk_agent_event execute-strict inherit "$SMP_FABLE_T" "smp50-$$")"
# C17 (51): Rule A — fable 세션 명시 fable 실행자 → ALERT
test_smp "51-rule-a-explicit-fable" 0 1 "$(mk_agent_event execute-strict fable "$SMP_FABLE_T" "smp51-$$")"
# C17 (52): Rule B 누출 arm — fable 세션 검증자 명시 inherit → ALERT (구: tier0 guard 침묵 — 새로 발화)
test_smp "52-rule-b-fable-explicit-inherit" 0 1 "$(mk_agent_event review-strict inherit "$SMP_FABLE_T" "smp52-$$")"
# C17 (53): Rule B floor — sonnet 세션 검증자 명시 inherit = 세션 평가 2<3 → ALERT (새로 발화)
test_smp "53-rule-b-sonnet-explicit-inherit" 0 1 "$(mk_agent_event review-strict inherit "$SMP_SONNET_T" "smp53-$$")"
# C17 (54): 구 하향 arm 제거 앵커 — fable 세션 검증자 opus → SILENT (구 ALERT 소음 — T7 라이브 재현)
test_smp "54-rule-b-fable-opus-silent" 0 0 "$(mk_agent_event review-strict opus "$SMP_FABLE_T" "smp54-$$")"
# C17 (55): Rule B 미지-리터럴 비면제 → ALERT (구: != 0 guard 침묵 — 새로 발화)
test_smp "55-rule-b-unknown-literal" 0 1 "$(mk_agent_event review-strict gpt-custom "$SMP_FABLE_T" "smp55-$$")"
# C17 (56): Rule C2 — 명시 inherit 검증자 세션 평가 유지(C13 존속) — sonnet 세션 2<3 → ALERT
WF_EX_UP_EXPL_INH="export const meta = {name: 'x', description: 'x'}
await agent('a', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'inherit'})"
test_smp "56-rule-c2-explicit-inherit-below-floor" 0 1 "$(mk_wf_event script "$WF_EX_UP_EXPL_INH" "$SMP_SONNET_T" "smp56-$$")"
# C17 (57): Rule B floor 전-세션 가드 — opus 세션 검증자 sonnet 2<3 → ALERT (구 세션-하향과 동일 발화·사유 교체)
test_smp "57-rule-b-opus-session-sonnet" 0 1 "$(mk_agent_event review-strict sonnet "$SMP_OPUS_T" "smp57-$$")"
# C17 (58): Rule C2 폴백 opus 상수 — fable 검증-전용 + review opus → SILENT (구: 세션 폴백 4>3 ALERT —
#     2026-08-02 검증-전용 Workflow 라이브 오발화의 재현·해소 앵커)
WF_REVIEWONLY_OPUS="export const meta = {name: 'x', description: 'x'}
await agent('verify it', {agentType: 'review-strict', model: 'opus'})"
test_smp "58-rule-c2-reviewonly-opus-silent" 0 0 "$(mk_wf_event script "$WF_REVIEWONLY_OPUS" "$SMP_FABLE_T" "smp58-$$")"
# C17 (59/60): Rule B floor — 동일-티어 구멍 소멸 (§16.8 A4; 구 하향식 2<2·1<1 거짓 침묵 → 새로 발화)
test_smp "59-rule-b-sonnet-session-sonnet" 0 1 "$(mk_agent_event review-strict sonnet "$SMP_SONNET_T" "smp59-$$")"
test_smp "60-rule-b-haiku-session-haiku" 0 1 "$(mk_agent_event review-strict haiku "$SMP_HAIKU_T" "smp60-$$")"
# C17 (61/62): fable-리터럴 누출 arm 전 세션 (§16.8 A6 — U4 금지는 세션 무관; 구: 상향 허용 침묵)
test_smp "61-rule-b-nonfable-fable-leak" 0 1 "$(mk_agent_event review-strict fable "$SMP_SONNET_T" "smp61-$$")"
test_smp "62-rule-a-nonfable-fable-leak" 0 1 "$(mk_agent_event execute-strict fable "$SMP_SONNET_T" "smp62-$$")"
# C17 (63): Rule C fable-리터럴 전 세션 (A6) — sonnet 세션 wf exec fable → ALERT
WF_FABLE_NONFABLE="export const meta = {name: 'x', description: 'x'}
await agent('do it', {agentType: 'execute-strict', model: 'fable'})"
test_smp "63-rule-c-nonfable-fable-leak" 0 1 "$(mk_wf_event script "$WF_FABLE_NONFABLE" "$SMP_SONNET_T" "smp63-$$")"
# C17 (64): C2-leak 신설 arm — 검증자 fable-리터럴 전 세션 (A6; 구: floor 충족 침묵 → 새로 발화)
WF_C2_FABLE_VERIFIER="await agent('impl', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'fable'})"
test_smp "64-rule-c2-fable-verifier" 0 1 "$(mk_wf_event script "$WF_C2_FABLE_VERIFIER" "$SMP_OPUS_T" "smp64-$$")"
# C17 (65): Rule B floor 미지-세션 수행 (§16.8 A1 — 리터럴 평가는 세션 불요; 구: SESSION_TIER=0 전체 skip)
SMP_UNKNOWN_T=$(mktemp "$SCRATCH/smp-unknown-XXXXXX.jsonl")
printf '{"type":"assistant","message":{"model":"claude-quasar-1","content":[]}}\n' > "$SMP_UNKNOWN_T"
test_smp "65-rule-b-unknown-session-literal" 0 1 "$(mk_agent_event review-strict sonnet "$SMP_UNKNOWN_T" "smp65-$$")"
# C17 (66): Rule B 신 메시지 내용 봉인 (§16.8 B2 — ctx 존재만 보면 구 메시지 잔존 미탐; hedge 동형)
test_smp_b_msg() {
  TOTAL=$((TOTAL+1))
  local out; out=$(printf '%s' "$1" | "$HOOKS/surface-model-policy.sh" 2>/dev/null)
  if printf '%s' "$out" | grep -q 'max(작업자'; then PASSED=$((PASSED+1))
  else FAILED_LIST+=("surface-model-policy/66-rule-b-message-floor-token"); fi
}
test_smp_b_msg "$(mk_agent_event review-strict sonnet "$SMP_FABLE_T" "smp66-$$")"
# C17 (67): C2-leak — fable 세션 검증자 명시 inherit (=fable 상속) → ALERT (구: 4≥floor 침묵 — 새로 발화)
WF_C2_INH_FABLE="await agent('impl', {agentType: 'execute-strict', model: 'opus'})
await agent('v', {agentType: 'review-strict', model: 'inherit'})"
test_smp "67-rule-c2-fable-inherit-verifier" 0 1 "$(mk_wf_event script "$WF_C2_INH_FABLE" "$SMP_FABLE_T" "smp67-$$")"

# ==================== Summary ====================
echo
echo "Hook tests: $PASSED / $TOTAL passed"
if [ ${#FAILED_LIST[@]} -gt 0 ]; then
  echo "Failures:"
  for f in "${FAILED_LIST[@]}"; do echo "  - $f"; done
fi
# ==================== CASES.TSV <-> RUN-ALL RECONCILIATION ([4]) ====================
# 모든 cases.tsv 선언 케이스 ID가 run-all.sh 에 실재해야 함 (phantom 카탈로그 항목 = drift 차단).
RECON_FAIL=0
while IFS=$'\t' read -r rhook rid rrest; do
  case "$rhook" in \#*|'') continue ;; esac
  # cycle-27 G2-b: 선언 id가 run-all '비주석' 라인에 실재해야 함 (주석-온리 phantom 차단;
  #   test_* 헬퍼 호출·인라인 FAILED_LIST 블록 양형식 모두 비주석 라인에 id 보유).
  grep -F "$rid" "$TESTS_DIR/run-all.sh" | grep -qvE '^[[:space:]]*#' \
    || { echo "  reconcile: 선언 id가 비주석 테스트로 미실재 → $rhook/$rid"; RECON_FAIL=1; }
done < "$TESTS_DIR/cases.tsv"
# cycle-27 G2-b: TOTAL(실행) == 선언 수 — 역방향 drift(미선언 실행) + 미실행 phantom 동시 차단(양방향).
DECLARED_N=$(grep -cvE '^[[:space:]]*(#|$)' "$TESTS_DIR/cases.tsv")
if [ "$TOTAL" -ne "$DECLARED_N" ]; then
  echo "  reconcile: TOTAL 실행($TOTAL) != cases.tsv 선언($DECLARED_N) — 역방향 drift 또는 미실행 phantom"; RECON_FAIL=1
fi
if [ "$RECON_FAIL" -ne 0 ]; then
  echo "cases.tsv <-> run-all 정합 실패 (위 케이스를 구현하거나 cases.tsv에서 제거)."
  exit 1
fi
echo "cases.tsv <-> run-all 정합 OK ($DECLARED_N declared == $TOTAL run, 비주석 실재)"

PCT=$(( PASSED * 100 / TOTAL ))
if (( PCT < 95 )); then
  echo "Pass rate ${PCT}% < 95% (spec §6.6 threshold). FAIL."
  exit 1
fi
echo "Pass rate ${PCT}% — OK"
exit 0
