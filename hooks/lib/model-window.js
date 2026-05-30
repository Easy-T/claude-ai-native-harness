// hooks/lib/model-window.js <model>
// 모델명 → 컨텍스트 창 토큰 수 (auto-compact-watch 가 사용). 'which models have which window' 단일 소스.
// CONTEXT_LIMIT env 가 양수면 우선(override). 새 모델 출시 시 MAP 에 한 줄만 추가.
// 주의: `node model-window.js <model>` 이므로 모델명은 argv[2] (argv[1]은 스크립트 경로).
const model = (process.argv[2] || "").toLowerCase();
const env = parseInt(process.env.CONTEXT_LIMIT || "", 10);
if (Number.isFinite(env) && env > 0) {
  process.stdout.write(String(env));
} else {
  const MAP = [
    [/opus-4-(7|8)/, 1000000],  // Opus 4.7 / 4.8 — 1M context
    [/1m/, 1000000],            // 명시적 1M 계열
  ];
  const hit = MAP.find(([re]) => re.test(model));
  process.stdout.write(String(hit ? hit[1] : 200000));  // 기본 200K (표준 모델)
}
