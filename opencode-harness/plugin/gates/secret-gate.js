// opencode-harness/plugin/gates/secret-gate.js
import { BlockError } from "../lib/fail-open.js";
import { CONTENT_KEYS } from "../lib/arg-keys.js";
import { scanSecret } from "../lib/secret-scan.js";

// Gathers content/oldString/newString (CONTENT_KEYS) + command, scans for a secret.
// Inv 15: deny message carries ONLY the kind, never the matched value.
export function secretGate({ tool, args, env }) {
  args = args || {};
  env = env || {};
  if (env.SECRET_SCAN_SKIP) return;
  const parts = [];
  for (const k of CONTENT_KEYS) if (typeof args[k] === "string") parts.push(args[k]);
  if (typeof args.command === "string") parts.push(args.command);
  const payload = parts.join("\n");
  if (!payload) return;
  const kind = scanSecret(payload);
  if (kind) {
    throw new BlockError(`[secret-scan] 차단: 시크릿으로 보이는 값 감지 → ${kind}. 환경변수/시크릿매니저 사용. 우회: SECRET_SCAN_SKIP.`);
  }
}
