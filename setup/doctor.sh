#!/usr/bin/env bash
# ~/.claude/setup/doctor.sh
# Diagnose, treat, re-diagnose, report. Single entry point per spec §2.7.

set -euo pipefail

PASS=0
FAIL=0
WARN=0
ITEMS=()

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
IS_WSL=0
if [ -r /proc/version ] && grep -qiE 'microsoft|wsl' /proc/version; then
  IS_WSL=1
fi

# WSL: locate the Windows-side .claude (shared with Windows Claude) — portable, no hardcoded user.
# Priority: explicit override WINDOWS_CLAUDE_HOME > derive from Windows %USERPROFILE% via interop > empty (→ WARN).
WINDOWS_CLAUDE_HOME_CANDIDATE="${WINDOWS_CLAUDE_HOME:-}"
if [ -z "$WINDOWS_CLAUDE_HOME_CANDIDATE" ] && [ "$IS_WSL" -eq 1 ] && command -v cmd.exe >/dev/null 2>&1; then
  win_profile=$( cd /mnt/c 2>/dev/null && cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\n' || true )
  # C:\Users\Name → /mnt/c/Users/Name/.claude  (parse-safe case-glob + bash param-expansion; from-file verified)
  case "$win_profile" in
    [A-Za-z]:*)
      win_drive="${win_profile%%:*}"; win_drive=$(printf '%s' "$win_drive" | tr 'A-Z' 'a-z')
      win_rest="${win_profile#?:}"; win_rest="${win_rest//\\//}"
      WINDOWS_CLAUDE_HOME_CANDIDATE="/mnt/$win_drive$win_rest/.claude"
      ;;
  esac
fi

check() {
  local label="$1"; local result="$2"; local note="${3:-}"
  case "$result" in
    PASS) PASS=$((PASS+1)); ITEMS+=("✓ $label${note:+ — $note}") ;;
    WARN) WARN=$((WARN+1)); ITEMS+=("⚠ $label${note:+ — $note}") ;;
    FAIL) FAIL=$((FAIL+1)); ITEMS+=("✗ $label${note:+ — $note}") ;;
  esac
}

report_results() {
  echo
  echo "[doctor] Results:"
  for line in "${ITEMS[@]}"; do echo "  $line"; done
  echo
  echo "[doctor] PASS=$PASS  WARN=$WARN  FAIL=$FAIL"
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

# 11. OS detection
case "$(uname -s)" in
  Linux*)   check "OS compatible" "PASS" "Linux" ;;
  Darwin*)  check "OS compatible" "PASS" "macOS" ;;
  MINGW*|MSYS*|CYGWIN*) check "OS compatible" "PASS" "Windows (Git Bash)" ;;
  *)        check "OS compatible" "WARN" "$(uname -s) untested" ;;
esac

if [ "$IS_WSL" -eq 1 ]; then
  check "WSL environment detected" "PASS" "$(uname -r)"
  if [ -d "$WINDOWS_CLAUDE_HOME_CANDIDATE" ]; then
    if [ "$CLAUDE_HOME" = "$WINDOWS_CLAUDE_HOME_CANDIDATE" ]; then
      check "Claude home namespace" "PASS" "$CLAUDE_HOME"
    else
      check "Claude home namespace" "FAIL" "WSL detected; run with HOME=${WINDOWS_CLAUDE_HOME_CANDIDATE%/.claude} or CLAUDE_HOME=$WINDOWS_CLAUDE_HOME_CANDIDATE (current: $CLAUDE_HOME)"
      report_results
      echo "[doctor] FATAL: Claude home namespace mismatch." >&2
      exit 1
    fi
  else
    check "Windows Claude home candidate" "WARN" "$WINDOWS_CLAUDE_HOME_CANDIDATE not found"
  fi
fi

# 12. ~/.claude/ writable
if touch "$CLAUDE_HOME/.write-test" 2>/dev/null && rm -f "$CLAUDE_HOME/.write-test"; then
  check "~/.claude/ writable" "PASS" ""
else
  check "~/.claude/ writable" "FAIL" "permission denied"
fi

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
    check "jq installed" "FAIL" "auto-install failed — required for bootstrap verification"
  fi
fi

# 16. .installed marker (auto-create)
mkdir -p "$CLAUDE_HOME/setup"
touch "$CLAUDE_HOME/setup/.installed"
check ".installed marker" "PASS" "auto-created"

# 17. audit marker in ~/.claude/CLAUDE.md
CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
TODAY=$(date +%Y-%m-%d)
if [ -f "$CLAUDE_MD" ]; then
  if grep -qE '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD"; then
    # cycle-29: 기존 마커는 '보존'(덮어쓰지 않음). doctor 실행만으로 audit 신선도를 today로 위조하면
    #  (a) §3 30일 staleness 게이트가 영구 무력화되고, (b) CLAUDE.md 수정이 §1 prefix 캐시를 무효화한다.
    #  실제 audit 갱신 권한은 closeout C-1(last_drift_check)/실제 점검 절차에만 — doctor는 부트스트랩(부재 시 생성)만.
    check "audit marker" "PASS" "기존 마커 보존 (doctor는 갱신 안 함 — 실제 audit 신선도 유지)"
  else
    printf "\n<!-- audit: %s -->\n" "$TODAY" >> "$CLAUDE_MD"
    check "audit marker" "PASS" "appended $TODAY (부재→부트스트랩)"
  fi
else
  check "audit marker" "WARN" "CLAUDE.md missing — run install.sh 또는 백업에서 복원"
fi

# 18. backup directory (~/.claude.backup-YYYY-MM-DD/)
# git이 ~/.claude/를 관리하면 백업 스킵 (롤백은 git으로 가능, 디스크 절약)
BACKUP="$CLAUDE_HOME.backup-$TODAY"
if [ -d "$CLAUDE_HOME/.git" ]; then
  check "backup directory" "PASS" "skipped (~/.claude is git-managed)"
elif [ ! -d "$BACKUP" ]; then
  cp -r "$CLAUDE_HOME" "$BACKUP" 2>/dev/null && check "backup directory" "PASS" "$BACKUP" || check "backup directory" "WARN" "cp failed"
else
  check "backup directory" "PASS" "exists: $BACKUP"
fi

# 18b. backup rotation — 가장 최근 3개만 유지 (오래된 것부터 삭제)
KEEP=3
OLD_BACKUPS=$({ ls -dt "$CLAUDE_HOME".backup-* 2>/dev/null || true; } | tail -n +$((KEEP+1)))
if [ -n "$OLD_BACKUPS" ]; then
  REMOVED=0
  while IFS= read -r old; do
    rm -rf "$old" 2>/dev/null && REMOVED=$((REMOVED+1))
  done <<< "$OLD_BACKUPS"
  check "backup rotation" "PASS" "removed $REMOVED old backup(s), kept $KEEP most recent"
else
  check "backup rotation" "PASS" "≤$KEEP backups, no rotation needed"
fi

# 19. ~/.claude/ git managed (recommended)
if [ -d "$CLAUDE_HOME/.git" ]; then
  check "~/.claude git-managed" "PASS" ""
else
  check "~/.claude git-managed" "WARN" "recommend: cd ~/.claude && git init"
fi

# 20. grill-with-docs skill (auto-install from mattpocock/skills)
GRILL_SKILL="$CLAUDE_HOME/skills/grill-with-docs/SKILL.md"
if [ -f "$GRILL_SKILL" ]; then
  check "grill-with-docs skill" "PASS" ""
else
  echo "[doctor] grill-with-docs 미설치 — mattpocock/skills에서 설치 시도..."
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    mkdir -p "$CLAUDE_HOME/skills/grill-with-docs"
    INSTALL_OK=1
    for gf in SKILL.md CONTEXT-FORMAT.md ADR-FORMAT.md; do
      node -e "
        const {execSync} = require('child_process');
        try {
          const out = execSync('gh api repos/mattpocock/skills/contents/skills/engineering/grill-with-docs/$gf', {encoding:'utf8'});
          const b64 = JSON.parse(out).content.replace(/\n/g,'');
          process.stdout.write(Buffer.from(b64,'base64').toString('utf8'));
        } catch(e) { process.exit(1); }
      " 2>/dev/null > "$CLAUDE_HOME/skills/grill-with-docs/$gf" || { INSTALL_OK=0; break; }
    done
    if [ "$INSTALL_OK" -eq 1 ] && [ -f "$GRILL_SKILL" ]; then
      check "grill-with-docs skill" "PASS" "auto-installed from mattpocock/skills"
    else
      check "grill-with-docs skill" "WARN" "auto-install 실패 — 수동: https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs"
    fi
  else
    check "grill-with-docs skill" "WARN" "gh 미인증 — 수동: https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs"
  fi
fi

# 20b. superpowers 필수 skill (start-rpi-cycle Phase R/P/I 의존) — plugins/cache 존재 알림
SP_MISS=""
for sk in brainstorming writing-plans executing-plans subagent-driven-development; do
  ls "$CLAUDE_HOME"/plugins/cache/*/superpowers/*/skills/"$sk"/SKILL.md >/dev/null 2>&1 || SP_MISS="$SP_MISS $sk"
done
if [ -z "$SP_MISS" ]; then
  check "superpowers skills" "PASS" ""
else
  check "superpowers skills" "WARN" "미설치:$SP_MISS — /plugin install superpowers@claude-plugins-official"
fi

# 20c. hooks/.log 로테이션 — 월파일 최근 6개 유지 + stray '.log' 제거
LOGDIR="$CLAUDE_HOME/hooks/.log"
if [ -d "$LOGDIR" ]; then
  rm -f "$LOGDIR/.log" 2>/dev/null || true
  OLD_LOGS=$({ ls -t "$LOGDIR"/*.log 2>/dev/null || true; } | tail -n +7)
  if [ -n "$OLD_LOGS" ]; then
    N_RM=$(printf '%s\n' "$OLD_LOGS" | wc -l)
    printf '%s\n' "$OLD_LOGS" | while read -r lf; do rm -f "$lf"; done
    check "hook log rotation" "PASS" "pruned $N_RM old month file(s), kept 6"
  else
    check "hook log rotation" "PASS" "≤6 month files"
  fi
fi

# 20d. hooks/.log 당월 판정 집계 (G6-c 로그 소비 — read-only, 카운트만; 값 미표시, S8 postmortem)
LOGMONTH="$LOGDIR/$(date +%Y-%m).log"
if [ -f "$LOGMONTH" ] && [ -r "$CLAUDE_HOME/hooks/_common.sh" ]; then
  LOGSUM=$( source "$CLAUDE_HOME/hooks/_common.sh" 2>/dev/null; log_summary "$LOGMONTH" 2>/dev/null ) || LOGSUM=""
  if [ -n "$LOGSUM" ]; then
    check "hook log 당월 집계" "PASS" "$LOGSUM"
  else
    check "hook log 당월 집계" "WARN" "집계 불가"
  fi
fi

# 20e. hooks/.runlog 당월 JSONL 집계 소비 + 이상 패턴 ALERT (GAP-003 — read-only, 카운트만).
#      로테이션(≤6 월파일)도 병행. FAILOPEN>0 = 파서 크래시 신호 → WARN(이상 패턴 표면화).
RUNLOGDIR="$CLAUDE_HOME/hooks/.runlog"
if [ -d "$RUNLOGDIR" ]; then
  OLD_RL=$({ ls -t "$RUNLOGDIR"/*.jsonl 2>/dev/null || true; } | tail -n +7)
  [ -n "$OLD_RL" ] && printf '%s\n' "$OLD_RL" | while read -r rf; do rm -f "$rf"; done
  RLMONTH="$RUNLOGDIR/$(date +%Y-%m).jsonl"
  if [ -f "$RLMONTH" ] && [ -r "$CLAUDE_HOME/hooks/_common.sh" ]; then
    RLSUM=$( source "$CLAUDE_HOME/hooks/_common.sh" 2>/dev/null; runlog_summary "$RLMONTH" 2>/dev/null ) || RLSUM=""
    RL_FO=$(printf '%s' "$RLSUM" | grep -oE 'FAILOPEN=[0-9]+' | grep -oE '[0-9]+' || echo 0)
    if [ -z "$RLSUM" ]; then
      check "run-log 당월 집계" "WARN" "집계 불가"
    elif [ "${RL_FO:-0}" -gt 0 ]; then
      check "run-log 당월 집계" "WARN" "$RLSUM — FAILOPEN>0 (파서 크래시 이상 신호, session-start-audit 로그 확인)"
    else
      check "run-log 당월 집계" "PASS" "$RLSUM"
    fi
  fi
fi

# 21. hook 파일 존재 + 실행권한
REQUIRED_HOOKS=(
  "enforce-orchestrator.sh"
  "stable-claude-md.sh"
  "enforce-rpi-cycle.sh"
  "enforce-rpi-bash.sh"
  "enforce-secret-scan.sh"
  "enforce-session-budget.sh"
  "auto-compact-watch.sh"
  "verify-loop-watch.sh"
  "session-start-audit.sh"
  "surface-constitution.sh"
  "worktree-teardown.sh"
  "_common.sh"
)
HOOK_FAIL=0
for hf in "${REQUIRED_HOOKS[@]}"; do
  fp="$CLAUDE_HOME/hooks/$hf"
  if [ ! -f "$fp" ]; then
    check "hook: $hf" "FAIL" "파일 없음 — $fp"
    HOOK_FAIL=1
  elif [ ! -x "$fp" ]; then
    check "hook: $hf" "FAIL" "실행권한 없음 — chmod +x $fp"
    HOOK_FAIL=1
  else
    check "hook: $hf" "PASS" ""
  fi
done
[ "$HOOK_FAIL" -eq 0 ] && check "all hooks present+executable" "PASS" "${#REQUIRED_HOOKS[@]}개" || true

# 21b. hooks/lib 추출 파서 (hook 들이 의존 — 없으면 hook 이 fail-open으로 조용히 무력화됨)
LIB_FAIL=0
for lf in redirect-targets skeleton-scan transcript-usage model-window; do
  [ -f "$CLAUDE_HOME/hooks/lib/$lf.js" ] || { check "lib: $lf.js" "FAIL" "없음 — $CLAUDE_HOME/hooks/lib/$lf.js"; LIB_FAIL=1; }
done
[ "$LIB_FAIL" -eq 0 ] && check "hooks/lib parsers present" "PASS" "4개" || true

# 23. CLAUDE_AUTOCOMPACT_PCT_OVERRIDE in settings.json
SETTINGS_JSON="$CLAUDE_HOME/settings.json"
if [ -f "$SETTINGS_JSON" ]; then
  compact_val=$(node -e "try{const s=JSON.parse(require('fs').readFileSync('$SETTINGS_JSON','utf8'));console.log(s.env&&s.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE||'')}catch(e){}" 2>/dev/null || echo "")
  if [ -n "$compact_val" ]; then
    if [ "$compact_val" -le 40 ] 2>/dev/null; then
      check "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "PASS" "${compact_val}% (rot-정렬 ≤40)"
    else
      check "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "WARN" "${compact_val}% — rot(~300-400K) 지남. ≤40 권장(WINDOW=1M 전제; 모델ID [1m] suffix)"
    fi
  else
    check "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "WARN" "미설정 — 기본값 95%. settings.json env에 \"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE\": \"40\" 추가 권장(rot-이전)"
  fi
else
  check "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "WARN" "settings.json 없음 — settings.example.json 복사 후 설정"
fi

# 24. .credentials.json 권한 (POSIX 소유자 전용 권장; Patch C)
CREDS="$CLAUDE_HOME/.credentials.json"
if [ -f "$CREDS" ]; then
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      check ".credentials.json perms" "WARN" "Windows(NTFS) — chmod no-op; ACL/EFS로 보호 권장" ;;
    *)
      MODE=$(stat -c '%a' "$CREDS" 2>/dev/null || stat -f '%Lp' "$CREDS" 2>/dev/null || echo "")
      if [ "$MODE" = "600" ] || [ "$MODE" = "400" ]; then
        check ".credentials.json perms" "PASS" "$MODE"
      elif chmod 600 "$CREDS" 2>/dev/null; then
        check ".credentials.json perms" "PASS" "tightened to 600 (was ${MODE:-unknown})"
      else
        check ".credentials.json perms" "WARN" "loose (${MODE:-unknown}) — run: chmod 600 $CREDS"
      fi ;;
  esac
fi

# Report
report_results

if (( FAIL > 0 )); then
  echo "[doctor] FAIL items must be resolved before proceeding." >&2
  exit 1
fi
exit 0
