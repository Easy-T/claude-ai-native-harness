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
# 빈/누락 cwd → fail-open (S12, resolve_cwd 공유)
CWD=$(echo "$INPUT" | resolve_cwd) || { hook_log "enforce-rpi-bash" "bash" "PASS" "no-cwd-failopen"; exit 0; }

# 빈 명령 → 통과 (fail-safe)
[ -z "$CMD" ] && exit 0

# 명시 우회
if [ -n "${RPI_SKIP:-}" ]; then
  hook_log "enforce-rpi-bash" "bash" "PASS" "skip:${RPI_SKIP}"
  surface_bypass "rpi-bash" "$(echo "$INPUT" | json_get session_id)" "⚠ RPI bash 게이트 우회 (RPI_SKIP='${RPI_SKIP}') — 이 세션 셸 코드작성에 게이트 미적용; 의도된 우회인지 확인"
  exit 0
fi

# 코드 파일을 셸로 작성하는 패턴 탐지. 파서는 hooks/lib/redirect-targets.js (단위테스트 가능).
# 코드 확장자 집합은 _common.sh 의 SSOT (code_ext_regex).
# fail-open 런타임 표면화 (cycle-32 rank6/G6-a): 종료코드로 '크래시(비정상 종료)'와
# '빈 출력(코드작성 의도 없음)'을 구분한다. 파서가 크래시하면 fail-open 은 유지(차단 아님 —
# 의도된 트레이드오프)하되 무표면 금지(CONTEXT.md "fail-open")라 hook_log FAILOPEN + stderr 1줄로 표면화.
# (enforce-orchestrator ERR-센티넬은 무로깅이라 단순 이식 아님 — 로깅 '추가'가 핵심.)
if TARGET=$(CMD="$CMD" CODE_EXT_REGEX="$(code_ext_regex)" node "$HOME/.claude/hooks/lib/redirect-targets.js" 2>/dev/null); then
  :   # 정상 종료(0): TARGET = 첫 코드-쓰기 대상 또는 빈 문자열
else
  hook_log "enforce-rpi-bash" "redirect-targets.js" "FAILOPEN" "parser-exit-$?"
  echo "[rpi-bash] ⚠ redirect 파서 런타임 고장 → fail-open 통과(이 명령에 게이트 비작동). bash ~/.claude/setup/doctor.sh 로 점검" >&2
  exit 0
fi

# 코드 작성 의도 없음 → 통과
[ -z "$TARGET" ] && exit 0

# 코드 파일을 셸로 작성하려 함 (또는 patch/apply 보수차단) → active plan 필요
if ACTIVE=$(has_active_plan "$CWD"); then
  hook_log "enforce-rpi-bash" "$TARGET" "PASS" "plan=$(basename "$ACTIVE")"
  exit 0
fi

if [ "$TARGET" = "__PATCH_APPLY__" ]; then
  hook_log "enforce-rpi-bash" "git-apply/patch" "BLOCK" "no-active-plan-conservative"
  cat >&2 <<EOF
[rpi-bash] 차단(보수): git apply/patch는 쓰기 대상이 패치 내용에 있어 추출 불가 → active plan 필요.
  docs 전용 패치 등 오탐이면: export RPI_SKIP="<이유>"
  ※ plan은 head-20에 **Status:** active 명시 필요 (cycle-23)
EOF
  exit 2
fi

hook_log "enforce-rpi-bash" "$TARGET" "BLOCK" "no-active-plan"
cat >&2 <<EOF
[rpi-bash] 차단: 셸로 코드 파일 작성 감지 → $TARGET
  Write/Edit 우회 경로(>, >>, tee, heredoc, sed -i, cp/mv, dd, install, rsync)로 코드를 쓰려면 active plan이 필요합니다.
  start-rpi-cycle 로 R→P 완료 후 진행하거나, 명시 우회: export RPI_SKIP="<이유>"
  ※ plan은 head-20에 **Status:** active 명시 필요 (cycle-23)
EOF
exit 2
