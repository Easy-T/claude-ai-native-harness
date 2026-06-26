// opencode-harness/tests/redirect-targets.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { extractRedirectTarget } from "../plugin/lib/redirect-targets.js";
import { codeExtRegexSource } from "../plugin/lib/code-exts.js";
const RE = codeExtRegexSource();
const t = (cmd) => extractRedirectTarget(cmd, RE);

test("redirection / tee / heredoc target a code file", () => {
  assert.equal(t("echo x > out.py"), "out.py");
  assert.equal(t("echo x >> a.sh"), "a.sh");
  assert.equal(t("cat > foo.js <<EOF"), "foo.js");
  assert.equal(t("echo x | tee -a bar.rb"), "bar.rb");
});

test("quote-aware + arrow + fd-number guards", () => {
  assert.equal(t("echo 'a > b.py'"), "");      // quoted '>' is not a redirect
  assert.equal(t("x=$(f -> g.py)"), "");        // '->' arrow, not redirect
  assert.equal(t("ls 2>&1"), "");                // fd number, no code ext
  assert.equal(t("echo x >& evil.py"), "evil.py");
});

test("sed -i / cp / mv / dd / install command-position", () => {
  assert.equal(t("sed -i 's/a/b/' z.go"), "z.go");
  assert.equal(t("cp src dst.py"), "dst.py");
  assert.equal(t("cat setup/install.sh other"), "");  // 'install' as path substring, NOT a command
  assert.equal(t("install -m 0755 a.sh /usr/bin/a.sh"), "/usr/bin/a.sh");
});

test("git apply / patch return the conservative sentinel", () => {
  assert.equal(t("git apply patch.diff"), "__PATCH_APPLY__");
  assert.equal(t("git apply --check patch.diff"), "");  // read-only variant excluded
});

test("no code-write intent returns empty", () => {
  assert.equal(t("ls -la"), "");
  assert.equal(t("echo hi > notes.md"), "");
});
