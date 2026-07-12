#!/usr/bin/env bash
# enforce-secret-scan.sh — 시크릿/키가 파일이나 셸 명령에 박히는 것을 차단.
# settings.json 의 PreToolUse 두 그룹(Write|Edit|NotebookEdit, Bash)에 모두 연결.
# 감사 §7 item 2 + critic: bypassPermissions + 무방비 Bash 환경에서 web/파일/MCP로
# 들어온 내용이 키를 파일에 기록하거나 명령에 노출하는 것을 막는 보수적 콘텐츠 가드.
#
# 설계:
#  - 고-특이도 패턴만 검사(실제 키 포맷). prefix-only 가 아니라 충분한 길이를 요구해 오탐 최소화.
#  - placeholder(XXXX/REDACTED/EXAMPLE/your-key 등)는 무시.
#  - 탐지 시 '종류'만 보고(값은 절대 출력/로그하지 않음).
#  - SECRET_SCAN_SKIP 으로 명시 우회. payload 없음/JSON 파싱 실패 시 fail-safe 통과.
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
# GAP-003: run-log 인리치(session_id + tool_name). 저빈도 hook 이라 node 1회 추가 수용(전 verdict SID 커버).
IFS=$'\037' read -r RL_SID RL_TOOL <<< "$(echo "$INPUT" | json_get_many session_id tool_name)"
export RL_SID RL_TOOL

# Write/Edit/NotebookEdit/Bash 어디서 와도 검사 대상 텍스트를 모은다.
PAYLOAD=$(echo "$INPUT" | node -e '
  let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
    let o={}; try{o=JSON.parse(d)}catch(e){process.exit(0)}
    const t=o.tool_input||{};
    const parts=[t.content,t.new_string,t.command,t.new_source].filter(x=>typeof x==="string");
    process.stdout.write(parts.join("\n"));
  });
')
[ -z "$PAYLOAD" ] && exit 0

if [ -n "${SECRET_SCAN_SKIP:-}" ]; then
  hook_log "enforce-secret-scan" "payload" "PASS" "skip:${SECRET_SCAN_SKIP}"
  surface_bypass "secret-scan" "$RL_SID" "⚠ 시크릿 스캔 우회 (SECRET_SCAN_SKIP='${SECRET_SCAN_SKIP}') — 이 페이로드 미검사; 의도된 우회인지 확인"
  exit 0
fi

KIND=$(PAYLOAD="$PAYLOAD" node -e '
  const s = process.env.PAYLOAD || "";
  const pats = [
    ["Anthropic key",      /sk-ant-(?:oat01|ort01|api03)-[A-Za-z0-9_\-]{40,}/],
    ["AWS access key id",  /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/],
    ["GitHub token",       /\bgh[pousr]_[A-Za-z0-9]{36,}\b/],
    ["GitLab PAT",         /\bglpat-[A-Za-z0-9_\-]{20,}\b/],
    ["Slack token",        /\bxox[baprs]-[A-Za-z0-9-]{10,}/],
    ["Google API key",     /\bAIza[0-9A-Za-z_\-]{35}\b/],
    ["Private key block",  /-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----/],
  ];
  const placeholder = /XXXX|REDACTED|EXAMPLE|PLACEHOLDER|your[_-]?(?:key|token|secret)|DUMMY|FAKE/i;
  for (const [name, re] of pats) {
    const m = s.match(re);
    if (m && !placeholder.test(m[0])) { process.stdout.write(name); break; }
  }
')
[ -z "$KIND" ] && exit 0

hook_log "enforce-secret-scan" "$KIND" "BLOCK" "secret-detected"
cat >&2 <<EOF
[secret-scan] 차단: 시크릿으로 보이는 값 감지 → $KIND
  실제 키·토큰을 코드/파일/명령에 넣지 마세요. 환경변수·시크릿 매니저·credential helper를 쓰세요.
  오탐이거나 의도된 경우 1회 우회: export SECRET_SCAN_SKIP="<이유>"
EOF
exit 2
