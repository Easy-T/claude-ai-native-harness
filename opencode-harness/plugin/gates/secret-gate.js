// opencode-harness/plugin/gates/secret-gate.js
import { BlockError } from "../lib/fail-open.js";
import { scanSecret } from "../lib/secret-scan.js";

// Scans ADDED content only — content / newString / command — matching the bash source
// (enforce-secret-scan.sh: [content, new_string, command, new_source]). Deliberately does
// NOT scan oldString (removed text): the bash hook never scans old_string, so scanning it
// would block edits that merely DELETE a secret (false-positive, parity break).
// Inv 15: deny message carries ONLY the kind, never the matched value.
const SECRET_FIELDS = ["content", "newString", "command"];
export function secretGate({ tool, args, env }) {
  args = args || {};
  env = env || {};
  if (env.SECRET_SCAN_SKIP) return;
  const parts = [];
  for (const k of SECRET_FIELDS) if (typeof args[k] === "string") parts.push(args[k]);
  const payload = parts.join("\n");
  if (!payload) return;
  const kind = scanSecret(payload);
  if (kind) {
    throw new BlockError(`[secret-scan] 차단: 시크릿으로 보이는 값 감지 → ${kind}. 환경변수/시크릿매니저 사용. 우회: SECRET_SCAN_SKIP.`);
  }
}
