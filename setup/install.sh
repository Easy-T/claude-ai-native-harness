#!/usr/bin/env bash
# install.sh — Claude AI-Native Harness installer
# 새 PC 또는 기존 ~/.claude 위에 이 하네스를 설치.
#
# Usage:
#   1. git clone <this-repo> ~/.claude  (or copy files into ~/.claude/)
#   2. bash ~/.claude/setup/install.sh
#   3. Claude Code 세션 재시작
#   4. bash ~/.claude/setup/verify-all.sh

set -euo pipefail

TARGET="$HOME/.claude"
TODAY=$(date +%Y-%m-%d)

echo "=========================================="
echo "  Claude AI-Native Harness installer"
echo "=========================================="
echo

# --- 1. 사전 점검 ---
echo "[1/6] 사전 도구 확인..."
MISSING=""
for cmd in node bash git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING="$MISSING $cmd"
  fi
done
if [ -n "$MISSING" ]; then
  echo "  ✗ 다음 도구가 필요합니다:$MISSING"
  echo "  설치 후 다시 시도하세요."
  exit 1
fi

# Claude Code 확인
if ! command -v claude >/dev/null 2>&1; then
  echo "  ⚠ claude CLI가 PATH에 없습니다. (https://claude.ai/code 에서 설치)"
  echo "    설치 후 이 스크립트를 다시 실행하세요."
  echo "    (그래도 진행하려면 Enter, 중단하려면 Ctrl+C)"
  read -r _
fi
echo "  ✓ node $(node --version), bash $(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+'), git OK"

# --- 2. 핵심 인프라 파일 존재 확인 ---
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
  "$TARGET/hooks/session-start-audit.sh"
  "$TARGET/setup/doctor.sh"
  "$TARGET/commands/init-ai-ready.md"
  "$TARGET/CLAUDE.md"
  "$TARGET/settings.example.json"
)
MISSING_FILES=0
for f in "${REQUIRED[@]}"; do
  if [ ! -f "$f" ]; then
    echo "  ✗ MISSING: $f"
    MISSING_FILES=$((MISSING_FILES + 1))
  fi
done
if [ "$MISSING_FILES" -gt 0 ]; then
  echo "  ✗ $MISSING_FILES 개 파일이 누락. clone이 정상적으로 완료됐는지 확인하세요."
  exit 1
fi
echo "  ✓ 17개 필수 파일 모두 존재"

# --- 3. 실행 권한 부여 ---
echo "[3/6] 스크립트 실행 권한 부여..."
chmod +x "$TARGET/setup/"*.sh 2>/dev/null || true
chmod +x "$TARGET/hooks/"*.sh 2>/dev/null || true
chmod +x "$TARGET/hooks/tests/"*.sh 2>/dev/null || true
echo "  ✓ chmod +x 완료"

# --- 4. settings.json 생성 또는 병합 ---
echo "[4/6] settings.json 처리..."
if [ -f "$TARGET/settings.json" ]; then
  # 기존 settings.json이 있음 → hooks 키만 병합 (나머지 사용자 값 보존)
  cp "$TARGET/settings.json" "$TARGET/settings.json.backup-$TODAY"
  echo "  → 기존 settings.json 백업: settings.json.backup-$TODAY"

  node -e '
    const fs = require("fs");
    const HOME = process.env.HOME;
    const cur = JSON.parse(fs.readFileSync(HOME + "/.claude/settings.json", "utf8"));
    const tpl = JSON.parse(fs.readFileSync(HOME + "/.claude/settings.example.json", "utf8"));

    // 사용자 값 보존 + hooks 병합
    cur.hooks = tpl.hooks;

    // hooks가 비어 있으면 보강
    if (!cur.permissions) cur.permissions = tpl.permissions;

    fs.writeFileSync(HOME + "/.claude/settings.json", JSON.stringify(cur, null, 2));
    console.log("  ✓ hooks 키를 기존 settings.json에 병합 (env/permissions/model 보존)");
  '
else
  # 새로 설치 → 템플릿을 그대로 복사
  cp "$TARGET/settings.example.json" "$TARGET/settings.json"
  echo "  ✓ settings.example.json → settings.json 복사 (편집 권장)"
  echo "  ⚠ ANTHROPIC_AUTH_TOKEN 등 env 값을 추가하세요."
fi

# --- 5. doctor 실행 ---
echo "[5/6] doctor 실행 (환경 진단)..."
echo
bash "$TARGET/setup/doctor.sh" || {
  echo
  echo "  ⚠ doctor에서 일부 항목이 FAIL. 위 메시지를 보고 수정 후 재실행하세요."
}

# --- 6. 완료 안내 ---
echo
echo "=========================================="
echo "  설치 완료"
echo "=========================================="
echo
echo "다음 단계:"
echo "  1. Claude Code 세션을 재시작하세요 (hook 등록 활성화)"
echo "  2. 검증: bash ~/.claude/setup/verify-all.sh"
echo "     → 'ALL PASS' 확인"
echo "  3. 새 프로젝트 부트스트랩: /init-ai-ready <project_name>"
echo "  4. 자세한 사용법: cat ~/.claude/README.md"
echo
echo "주의:"
echo "  - settings.json은 .gitignore로 추적되지 않습니다 (개인 설정)"
echo "  - 필요한 env 값(ANTHROPIC_AUTH_TOKEN 등)을 추가하세요"
echo "  - hooks/.log/은 운영 로그라 자동 무시됩니다"
echo
exit 0
