#!/usr/bin/env bash
# surface-constitution.sh — advisory PreToolUse hook (cycle-16, D-ADOPT).
# 매칭 액션 순간 §5(ADR)/§8(UI) 헌법 조항을 모델 컨텍스트로 환기한다. 차단하지 않는다(advisory, exit 0).
# 모델에 닿는 유일한 비차단 경로 = hookSpecificOutput.additionalContext (stderr 아님 — 공식 hooks 문서).
# 소음 방지: §5·§8 각각 1세션 1회만 emit (session_marker). 트리거(결정적 경로/확장자만):
#   §5 = 의존성 매니페스트, §8 = UI 확장자. 비매칭 = 무출력 no-op.
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')
FILE_PATH=$(normalize_path "$FILE_PATH")
[ -z "$FILE_PATH" ] && exit 0

SESSION_ID=$(echo "$INPUT" | json_get 'session_id'); [ -z "$SESSION_ID" ] && SESSION_ID="unknown"

# §5 — 아키텍처 영향 변경 트리거: 의존성 매니페스트
case "$FILE_PATH" in
  */package.json|package.json|*/go.mod|go.mod|*/requirements.txt|requirements.txt|*/pyproject.toml|pyproject.toml|*/Cargo.toml|Cargo.toml|*/pom.xml|pom.xml|*/build.gradle|build.gradle|*/build.gradle.kts|*/Gemfile|Gemfile|*/composer.json|composer.json|*.csproj|*/pubspec.yaml|pubspec.yaml)
    MARKER="$(session_marker surface-adr "$SESSION_ID")"
    [ -f "$MARKER" ] && exit 0
    touch "$MARKER" 2>/dev/null || true
    hook_log "surface-constitution" "$FILE_PATH" "ALERT" "section5-adr"
    emit_additional_context "[§5 ADR] 의존성 매니페스트 수정 감지 — 아키텍처 영향(의존성 추가/삭제) 변경이면 docs/ai-context/architecture.md 에 ADR 을 append-only 로 작성하세요(변경 전/직후, 결정 변경은 새 ADR supersede). (advisory · 1세션 1회 · 차단 아님)"
    exit 0
    ;;
esac

# §8 — UI/UX 시각 작업 트리거: UI 확장자
case "$FILE_PATH" in
  *.tsx|*.jsx|*.vue|*.svelte|*.css|*.scss|*.sass|*.less|*.styl)
    MARKER="$(session_marker surface-ui "$SESSION_ID")"
    [ -f "$MARKER" ] && exit 0
    touch "$MARKER" 2>/dev/null || true
    hook_log "surface-constitution" "$FILE_PATH" "ALERT" "section8-ui"
    emit_additional_context "[§8 UI] UI/UX 시각 파일(컴포넌트/스타일) 수정 감지 — ui-design skill 을 사용하세요(design.md 주입 + Anti-Slop Checklist 검증). (advisory · 1세션 1회 · 차단 아님)"
    exit 0
    ;;
esac

exit 0
