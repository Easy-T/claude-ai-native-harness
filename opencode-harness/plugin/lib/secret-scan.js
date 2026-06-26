// opencode-harness/plugin/lib/secret-scan.js
// VERBATIM patterns from ~/.claude/hooks/enforce-secret-scan.sh. High-specificity only
// (length floors calibrated to minimize false positives — do NOT tighten/loosen).
// First-match-wins (break). Inv 15: return ONLY the kind name; never the matched value.
const PATTERNS = [
  ["Anthropic key",     /sk-ant-(?:oat01|ort01|api03)-[A-Za-z0-9_\-]{40,}/],
  ["AWS access key id", /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/],
  ["GitHub token",      /\bgh[pousr]_[A-Za-z0-9]{36,}\b/],
  ["GitLab PAT",        /\bglpat-[A-Za-z0-9_\-]{20,}\b/],
  ["Slack token",       /\bxox[baprs]-[A-Za-z0-9-]{10,}/],
  ["Google API key",    /\bAIza[0-9A-Za-z_\-]{35}\b/],
  ["Private key block", /-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----/],
];
const PLACEHOLDER = /XXXX|REDACTED|EXAMPLE|PLACEHOLDER|your[_-]?(?:key|token|secret)|DUMMY|FAKE/i;

export function scanSecret(text) {
  const s = text || "";
  for (const [name, re] of PATTERNS) {
    const m = s.match(re);
    if (m && !PLACEHOLDER.test(m[0])) return name;
  }
  return null;
}
