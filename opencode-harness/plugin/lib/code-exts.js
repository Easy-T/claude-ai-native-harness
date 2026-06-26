// opencode-harness/plugin/lib/code-exts.js
// CODE_EXTS SSOT — byte-identical to ~/.claude/hooks/_common.sh (Write-gate / Bash-gate symmetry).
// Add a language here and BOTH the file-path gate and the shell-redirect gate stay in sync.
export const CODE_EXTS = [
  "sh","bash","zsh","py","rb","js","mjs","cjs","ts","tsx","jsx","go","rs","php",
  "pl","ps1","psm1","c","cc","cpp","h","hpp","java","kt","swift","scala","lua","sql","ipynb",
];

// is_code_path twin: Dockerfile or any CODE_EXTS suffix.
export function isCodePath(p) {
  if (!p) return false;
  if (/(?:^|\/)Dockerfile$/.test(p)) return true;
  return CODE_EXTS.some((ext) => p.endsWith("." + ext));
}

// code_ext_regex twin: `\.(ext1|ext2|...)$` source string (consumed by redirect-targets).
export function codeExtRegexSource() {
  return "\\.(" + CODE_EXTS.join("|") + ")$";
}
