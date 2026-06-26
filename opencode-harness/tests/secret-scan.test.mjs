// opencode-harness/tests/secret-scan.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { scanSecret } from "../plugin/lib/secret-scan.js";

test("detects real-shaped keys and returns ONLY the kind", () => {
  const akia = "AKIA" + "ABCDEFGHIJKLMNOP";      // built at runtime; 16 [A-Z0-9]
  assert.equal(scanSecret("id=" + akia), "AWS access key id");
  const aiza = "AIza" + "0123456789012345678901234567890ABCD"; // 35 trailing
  assert.equal(scanSecret(aiza), "Google API key");
  const pk = "-----BEGIN " + "OPENSSH PRIVATE KEY" + "-----"; // runtime-built; no literal in file
  assert.equal(scanSecret(pk), "Private key block");
});

test("placeholders are ignored", () => {
  const ph = "AKIA" + "EXAMPLE".padEnd(16, "X"); // matches AKIA shape AND contains EXAMPLE marker
  assert.equal(scanSecret(ph), null);
  assert.equal(scanSecret("your-key-here"), null);
});

test("clean text returns null", () => {
  assert.equal(scanSecret("just a normal sentence with no secrets"), null);
  assert.equal(scanSecret(""), null);
});
