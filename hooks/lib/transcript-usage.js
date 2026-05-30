// hooks/lib/transcript-usage.js
// Claude Code transcript .jsonl(argv[1]) 에서 컨텍스트 점유 토큰과 마지막 모델명 추출 (auto-compact-watch 가 사용).
// 출력: "<maxContextTokens>\t<lastModel>".
//   maxContextTokens = 메시지별 (input + cache_read + cache_creation) 토큰의 최댓값.
// 읽기 실패 시 "0\t" (fail-safe).
// 주의: `node script.js <path>` 호출이므로 transcript 경로는 argv[2] (argv[1]은 스크립트 경로).
const fs = require("fs");
try {
  const lines = fs.readFileSync(process.argv[2], "utf8").trim().split("\n");
  let last = 0, model = "";
  for (const ln of lines) {
    try {
      const obj = JSON.parse(ln);
      const u = obj?.message?.usage;
      if (u) {
        const total = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
        if (total > last) last = total;
      }
      if (obj?.message?.model) model = obj.message.model;
    } catch (e) { /* skip bad lines */ }
  }
  process.stdout.write(last + "\t" + model);
} catch (e) { process.stdout.write("0\t"); }
