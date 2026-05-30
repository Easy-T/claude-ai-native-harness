// hooks/lib/skeleton-scan.js
// orchestrator 스킬 골격 계약의 '권위 정의' (enforce-orchestrator hook 과 create-orchestrator-skill 이 모두 의존).
// 입력: PreToolUse INPUT JSON (stdin) + env FP (정규화된 file_path).
// 출력 한 줄:
//   "ERR"   = INPUT 파싱 실패 (fail-open)
//   "EMPTY" = 검증할 content 없음
//   "<hasMarker> <phaseCount> <agentCount> <protocolCount>"
// Edit 의 경우 on-disk 파일에 old→new 를 적용한 '결과 파일' 전체로 검증(S3).
// Agent(subagent_type=) 카운트 전에 HTML 주석(<!-- -->) 제거 → 주석 처리된 호출은 골격을 만족시키지 못함(S4).
const fs = require("fs");
let raw = "";
process.stdin.on("data", c => raw += c);
process.stdin.on("end", () => {
  let o = {};
  try { o = JSON.parse(raw); } catch (e) { process.stdout.write("ERR"); return; }
  const t = o.tool_input || {}, tool = o.tool_name || "", fp = process.env.FP || "";
  let content = "";
  if (tool === "Edit") {
    let cur = "";
    try { cur = fs.readFileSync(fp, "utf8"); } catch (e) {}
    const oldS = t.old_string || "", newS = t.new_string || "";
    content = cur ? ((oldS && cur.indexOf(oldS) >= 0) ? cur.replace(oldS, newS) : cur) : newS;
  } else {
    content = (typeof t.content === "string" && t.content) ? t.content : (t.new_string || "");
  }
  if (!content) { process.stdout.write("EMPTY"); return; }
  const hasMarker = /^orchestrator_skill: true\s*$/m.test(content) ? 1 : 0;
  const scan = content.replace(/<!--[\s\S]*?-->/g, "");
  const phase = (scan.match(/^# Phase /gm) || []).length;
  const agent = (scan.match(/Agent\(subagent_type=/g) || []).length;
  const contract = (scan.match(/Communication Protocol/g) || []).length;
  process.stdout.write(hasMarker + " " + phase + " " + agent + " " + contract);
});
