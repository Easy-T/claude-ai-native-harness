#!/usr/bin/env bash
# enforce-rpi-bash.sh — RPI 게이트의 Bash 사이드도어 봉인.
# enforce-rpi-cycle 은 Write|Edit 만 막는다. 코드를 셸 리다이렉션/heredoc/tee 로
# 작성하면(`cat > x.py <<EOF`, `echo ... > x.sh`) 그 게이트를 우회한다(감사 시나리오 S1).
# 이 hook 은 PreToolUse matcher "Bash" 에 걸려, 코드 확장자 파일을 셸로 '작성'하려는
# 명령을 active plan 없이 실행하지 못하게 한다.
#
# 보수적 설계 (오탐 최소화):
#  - 리다이렉션(`>`/`>>`) 또는 `tee` 의 '대상'이 코드 확장자로 끝날 때만 트리거.
#  - /dev/null, .md/.txt/.json/.log 등 비코드 대상은 무시.
#  - 트리거돼도 active plan 있으면 통과 / RPI_SKIP 있으면 통과.
#  - 명령 파싱이 모호하거나 비면 fail-safe 로 통과(exit 0) — 작업을 막지 않음.
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
CMD=$(echo "$INPUT" | json_get 'tool_input.command')
CWD=$(echo "$INPUT" | json_get 'cwd')
CWD=$(normalize_path "$CWD")
# 빈/누락 cwd → fail-open (비결정적 "." 해석 회피, S12)
if [ -z "$CWD" ]; then
  hook_log "enforce-rpi-bash" "bash" "PASS" "no-cwd-failopen"
  exit 0
fi

# 빈 명령 → 통과 (fail-safe)
[ -z "$CMD" ] && exit 0

# 명시 우회
if [ -n "${RPI_SKIP:-}" ]; then
  hook_log "enforce-rpi-bash" "bash" "PASS" "skip:${RPI_SKIP}"
  exit 0
fi

# 코드 파일을 셸로 작성하는 패턴 탐지 (리다이렉션/tee 대상이 코드 확장자)
# node 로 정밀 파싱 (grep 정규식 이식성 회피).
TARGET=$(CMD="$CMD" node -e '
  const cmd = process.env.CMD || "";
  const codeExt = /\.(sh|bash|zsh|py|rb|js|mjs|cjs|ts|tsx|jsx|go|rs|php|pl|ps1|psm1|c|cc|cpp|h|hpp|java|kt|swift|scala|lua|sql|ipynb)$/i;
  const targets = [];
  // > file | >> file | tee [-a] file  (>&fd, >&-, 2> 등 fd 리다이렉션은 대상이 코드 확장자가 아니라 자동 제외)
  const re = /(?:>>?|\btee\s+(?:-a\s+)?)\s*("?)([^\s">|;&()]+)\1/g;
  let m;
  while ((m = re.exec(cmd)) !== null) targets.push(m[2]);
  const hit = targets.find(p => codeExt.test(p) && !/^\/dev\/null$/.test(p));
  if (hit) process.stdout.write(hit);
' 2>/dev/null || true)

# 코드 작성 의도 없음 → 통과
[ -z "$TARGET" ] && exit 0

# 코드 파일을 셸로 작성하려 함 → active plan 필요
if ACTIVE=$(has_active_plan "$CWD"); then
  hook_log "enforce-rpi-bash" "$TARGET" "PASS" "plan=$(basename "$ACTIVE")"
  exit 0
fi

hook_log "enforce-rpi-bash" "$TARGET" "BLOCK" "no-active-plan"
cat >&2 <<EOF
[rpi-bash] 차단: 셸로 코드 파일 작성 감지 → $TARGET
  Write/Edit 우회 경로(>, >>, tee, heredoc)로 코드를 쓰려면 active plan이 필요합니다.
  start-rpi-cycle 로 R→P 완료 후 진행하거나, 명시 우회: export RPI_SKIP="<이유>"
EOF
exit 2
