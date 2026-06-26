// opencode-harness/plugin/lib/code-exts.js
// CODE_EXTS SSOT — byte-identical to ~/.claude/hooks/_common.sh (Write-gate / Bash-gate symmetry).
// Add a language here and BOTH the file-path gate and the shell-redirect gate stay in sync.
export const CODE_EXTS = [
  "sh","bash","zsh","py","rb","js","mjs","cjs","ts","tsx","jsx","go","rs","php",
  "pl","ps1","psm1","c","cc","cpp","h","hpp","java","kt","swift","scala","lua","sql","ipynb",
];

// normalize_path twin (~/.claude/hooks/_common.sh): backslash → forward-slash.
// Required on Windows (opencode passes raw args.filePath with backslashes); without it
// the `/`-literal path regexes in the gates silently miss (spec-before-plan bypass, R2-class).
export function normalizePath(p) {
  return String(p ?? "").replace(/\\/g, "/");
}

// is_code_path twin: Dockerfile or any CODE_EXTS suffix. Normalizes first so a
// backslash Dockerfile path is recognized (parity with bash is_code_path post-normalize).
export function isCodePath(p) {
  p = normalizePath(p);
  if (!p) return false;
  if (/(?:^|\/)Dockerfile$/.test(p)) return true;
  return CODE_EXTS.some((ext) => p.endsWith("." + ext));
}

// code_ext_regex twin: `\.(ext1|ext2|...)$` source string (consumed by redirect-targets).
export function codeExtRegexSource() {
  return "\\.(" + CODE_EXTS.join("|") + ")$";
}
