#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')
FILE_PATH=$(normalize_path "$FILE_PATH")

# 1. 대상 path 확인 — */skills/*/SKILL.md (대소문자 무시: skill.md/Skill.md 등도 검증, S13)
shopt -s nocasematch
if [[ "$FILE_PATH" != */skills/*/skill.md ]]; then shopt -u nocasematch; exit 0; fi
shopt -u nocasematch

# 2~4. 검증 대상 컨텐츠 산출 + 골격 카운트 (node 단일 수행)
#  - Edit: on-disk 파일에 old→new를 적용한 '결과 파일' 전체로 검증 (S3: new_string 헌크만 보던 우회 차단).
#    marker는 결과 파일 frontmatter 기준 → Edit로 Phase를 무력화해도 잡힌다.
#  - Write: content(없으면 new_string).
#  - 골격 카운트 전에 HTML 주석(<!-- -->) 제거 (S4: 주석 속 Agent() 오탐 차단).
#    (펜스 ``` 는 제거하지 않음 — 실제 skill이 펜스로 호출을 문서화하므로 false-block 위험.)
SKEL=$(echo "$INPUT" | FP="$FILE_PATH" node -e '
  const fs=require("fs");
  let raw=""; process.stdin.on("data",c=>raw+=c); process.stdin.on("end",()=>{
    let o={}; try{o=JSON.parse(raw)}catch(e){process.stdout.write("ERR");return;}
    const t=o.tool_input||{}, tool=o.tool_name||"", fp=process.env.FP||"";
    let content="";
    if(tool==="Edit"){
      let cur=""; try{cur=fs.readFileSync(fp,"utf8")}catch(e){}
      const oldS=t.old_string||"", newS=t.new_string||"";
      content = cur ? ((oldS && cur.indexOf(oldS)>=0) ? cur.replace(oldS,newS) : cur) : newS;
    } else {
      content = (typeof t.content==="string" && t.content) ? t.content : (t.new_string||"");
    }
    if(!content){ process.stdout.write("EMPTY"); return; }
    const hasMarker = /^orchestrator_skill: true\s*$/m.test(content) ? 1 : 0;
    const scan = content.replace(/<!--[\s\S]*?-->/g,"");
    const phase = (scan.match(/^# Phase /gm)||[]).length;
    const agent = (scan.match(/Agent\(subagent_type=/g)||[]).length;
    const contract = (scan.match(/Communication Protocol/g)||[]).length;
    process.stdout.write(hasMarker+" "+phase+" "+agent+" "+contract);
  });
')
[ "$SKEL" = "ERR" ] && exit 0      # 파싱 실패 → fail-safe 통과
[ "$SKEL" = "EMPTY" ] && exit 0    # 컨텐츠 없음 → 통과
read -r HAS_MARKER PHASE_COUNT AGENT_CALLS HAS_CONTRACT <<< "$SKEL"

# orchestrator 마커 없으면 통과(opt-out)
if [ "$HAS_MARKER" != "1" ]; then
  hook_log "enforce-orchestrator" "$FILE_PATH" "PASS" "no-marker"
  exit 0
fi

REASON=""
if (( PHASE_COUNT < 3 )); then
  REASON="phase=${PHASE_COUNT}<3"
elif (( AGENT_CALLS < 1 )); then
  REASON="agent_calls=0"
elif (( HAS_CONTRACT < 1 )); then
  REASON="no-protocol-section"
fi

if [ -n "$REASON" ]; then
  hook_log "enforce-orchestrator" "$FILE_PATH" "BLOCK" "$REASON"
  cat >&2 <<EOF
[orchestrator] FAIL: $REASON
  Orchestrator skill 골격 누락:
    - Phase 마커 ≥ 3 (현재 $PHASE_COUNT)
    - Agent(subagent_type=...) 호출 ≥ 1 (현재 $AGENT_CALLS)
    - Communication Protocol 섹션 ≥ 1 (현재 $HAS_CONTRACT)
  해결: create-orchestrator-skill을 사용해 다시 생성하거나, 골격을 직접 추가하세요.
  검증 우회 (단순 텍스트 변환 skill 등): frontmatter에서 \`orchestrator_skill: true\` 제거.
EOF
  exit 2
fi

hook_log "enforce-orchestrator" "$FILE_PATH" "PASS" ""
exit 0
