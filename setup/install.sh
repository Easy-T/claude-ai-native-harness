#!/usr/bin/env bash
# install.sh — Claude AI-Native Harness installer
# Run after cloning the repo into ~/.claude/.
#
# Usage:
#   1. (backup existing if any) mv ~/.claude ~/.claude.pre-harness-$(date +%Y%m%d)
#   2. git clone <this-repo-url> ~/.claude
#   3. bash ~/.claude/setup/install.sh
#   4. Restart Claude Code session
#   5. Install required plugins (see README §Prerequisites)
#   6. bash ~/.claude/setup/verify-all.sh

set -euo pipefail

TARGET="$HOME/.claude"
TODAY=$(date +%Y-%m-%d)

echo "=========================================="
echo "  Claude AI-Native Harness installer"
echo "=========================================="
echo

# --- 1. 사전 도구 점검 ---
echo "[1/6] 사전 도구 확인..."
MISSING=""
for cmd in node bash git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING="$MISSING $cmd"
  fi
done
if [ -n "$MISSING" ]; then
  echo "  ✗ 다음 도구가 없습니다:$MISSING"
  echo "    설치 후 다시 시도하세요."
  exit 1
fi

# Claude Code 확인
if ! command -v claude >/dev/null 2>&1; then
  echo "  ⚠ claude CLI가 PATH에 없습니다."
  echo "    https://claude.ai/code 에서 Claude Code를 설치한 뒤 진행하세요."
  echo "    (계속 진행하려면 Enter, 중단 Ctrl+C)"
  read -r _
fi
NODE_VER=$(node --version)
BASH_VER=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "  ✓ node $NODE_VER, bash $BASH_VER, git OK"

# --- 2. 핵심 인프라 파일 점검 ---
echo "[2/6] 하네스 파일 존재 확인..."
REQUIRED=(
  "$TARGET/agents/explore-strict.md"
  "$TARGET/agents/review-strict.md"
  "$TARGET/agents/execute-strict.md"
  "$TARGET/skills/common-agent-contract/SKILL.md"
  "$TARGET/skills/init-ai-ready-project/SKILL.md"
  "$TARGET/skills/start-rpi-cycle/SKILL.md"
  "$TARGET/skills/create-orchestrator-skill/SKILL.md"
  "$TARGET/hooks/_common.sh"
  "$TARGET/hooks/enforce-orchestrator.sh"
  "$TARGET/hooks/stable-claude-md.sh"
  "$TARGET/hooks/auto-compact-watch.sh"
  "$TARGET/hooks/enforce-rpi-cycle.sh"
  "$TARGET/hooks/enforce-rpi-bash.sh"
  "$TARGET/hooks/session-start-audit.sh"
  "$TARGET/setup/doctor.sh"
  "$TARGET/commands/init-ai-ready.md"
  "$TARGET/CLAUDE.md"
  "$TARGET/settings.example.json"
)
MISSING_FILES=0
for f in "${REQUIRED[@]}"; do
  [ ! -f "$f" ] && { echo "  ✗ MISSING: $f"; MISSING_FILES=$((MISSING_FILES+1)); }
done
if [ "$MISSING_FILES" -gt 0 ]; then
  echo "  ✗ $MISSING_FILES 개 파일 누락. clone이 정상 완료됐는지 확인하세요."
  exit 1
fi
echo "  ✓ 18개 필수 파일 모두 존재"

# --- 3. 실행 권한 부여 ---
echo "[3/6] 스크립트 실행 권한 부여..."
chmod +x "$TARGET/setup/"*.sh 2>/dev/null || true
chmod +x "$TARGET/hooks/"*.sh 2>/dev/null || true
chmod +x "$TARGET/hooks/tests/"*.sh 2>/dev/null || true
echo "  ✓ chmod +x 완료"

# --- 4. settings.json 생성 또는 병합 ---
echo "[4/6] settings.json 처리..."
if [ -f "$TARGET/settings.json" ]; then
  # 기존 settings.json이 있음 → hooks 키만 병합 (사용자 값 보존)
  cp "$TARGET/settings.json" "$TARGET/settings.json.backup-$TODAY"
  echo "  → 기존 settings.json 백업: settings.json.backup-$TODAY"

  HOME_DIR="$HOME" node -e '
    const fs = require("fs");
    const HOME = process.env.HOME_DIR;
    const cur = JSON.parse(fs.readFileSync(HOME + "/.claude/settings.json", "utf8"));
    const tpl = JSON.parse(fs.readFileSync(HOME + "/.claude/settings.example.json", "utf8"));
    cur.hooks = tpl.hooks;
    if (!cur.permissions) cur.permissions = tpl.permissions;
    fs.writeFileSync(HOME + "/.claude/settings.json", JSON.stringify(cur, null, 2));
    console.log("  ✓ hooks 키 병합 (env/permissions/model/enabledPlugins 등 보존)");
  '
else
  # 새로 설치 → 템플릿을 그대로 복사
  cp "$TARGET/settings.example.json" "$TARGET/settings.json"
  echo "  ✓ settings.example.json → settings.json 복사"
  echo "  ⚠ Claude Code 인증 (claude /login 또는 환경변수 ANTHROPIC_API_KEY 설정)을 별도로 진행하세요."
fi

# --- 5. doctor 실행 ---
echo "[5/6] doctor 실행 (환경 진단)..."
echo
bash "$TARGET/setup/doctor.sh" || {
  echo
  echo "  ⚠ doctor에서 일부 항목 FAIL. 위 메시지 보고 수정 후 재실행하세요."
}

# --- 6. 완료 안내 + 의존 플러그인 안내 ---
echo
echo "=========================================="
echo "  설치 완료"
echo "=========================================="
echo
echo "▶ 다음 단계 (반드시 따르세요):"
echo
echo "  [STEP 1] Claude Code 세션을 재시작"
echo "           hook 5개가 settings.json에서 로드됩니다."
echo
echo "  [STEP 2] 의존 플러그인 설치 (필수, 미설치 시 RPI 사이클 작동 X)"
echo "           새 세션에서 다음 명령으로 설치:"
echo "             /plugin install superpowers@claude-plugins-official"
echo "             /plugin install skill-creator@claude-plugins-official"
echo "             /plugin install claude-md-management@claude-plugins-official"
echo "           또는 settings.json의 enabledPlugins 키에 직접 추가."
echo
echo "  [STEP 3] 검증"
echo "             bash ~/.claude/setup/verify-all.sh"
echo "           기대 출력: 'ALL PASS — system meets §6.6 acceptance gate.'"
echo
echo "  [STEP 4] 첫 사용 (선택)"
echo "             /init-ai-ready <project_name>     # 새 프로젝트 부트스트랩"
echo "             또는 채팅에 \"기능 추가해줘\" → start-rpi-cycle 자동 발동"
echo
echo "▶ 참고:"
echo "  - settings.json은 git에서 추적되지 않습니다 (개인 설정)."
echo "  - hooks/.log/은 운영 로그라 자동 무시됩니다."
echo "  - 자세한 사용법: cat ~/.claude/README.md"
echo
exit 0
