// opencode-harness/tests/code-exts.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { CODE_EXTS, isCodePath, codeExtRegexSource } from "../plugin/lib/code-exts.js";

test("CODE_EXTS matches the _common.sh SSOT verbatim", () => {
  assert.equal(CODE_EXTS.join(" "),
    "sh bash zsh py rb js mjs cjs ts tsx jsx go rs php pl ps1 psm1 c cc cpp h hpp java kt swift scala lua sql ipynb");
});

test("isCodePath flags code extensions + Dockerfile, not docs", () => {
  assert.equal(isCodePath("hooks/foo.py"), true);
  assert.equal(isCodePath("a/b/Dockerfile"), true);
  assert.equal(isCodePath("Dockerfile"), true);
  assert.equal(isCodePath("notes.md"), false);
  assert.equal(isCodePath("README"), false);
  assert.equal(isCodePath(""), false);
});

test("codeExtRegexSource builds the JS regex source", () => {
  const re = new RegExp(codeExtRegexSource(), "i");
  assert.equal(re.test("x.py"), true);
  assert.equal(re.test("x.ipynb"), true);
  assert.equal(re.test("x.md"), false);
});
