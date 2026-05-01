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
