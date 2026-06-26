// opencode-harness/tests/secret-gate.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { secretGate } from "../plugin/gates/secret-gate.js";
import { BlockError } from "../plugin/lib/fail-open.js";

test("blocks a secret in content; message carries kind, not value", () => {
  const akia = "AKIA" + "ABCDEFGHIJKLMNOP";
  try {
    secretGate({ tool: "write", args: { content: "key=" + akia }, env: {} });
    assert.fail("should have thrown");
  } catch (e) {
    assert.ok(e instanceof BlockError);
    assert.ok(e.message.includes("AWS access key id"));
    assert.ok(!e.message.includes(akia), "value must NOT appear");
  }
});

test("blocks a secret in a bash command", () => {
  const tok = "ghp_" + "A".repeat(36);
  assert.throws(() => secretGate({ tool: "bash", args: { command: "export T=" + tok }, env: {} }), BlockError);
});

test("SECRET_SCAN_SKIP and clean payloads allow", () => {
  const akia = "AKIA" + "ABCDEFGHIJKLMNOP";
  assert.doesNotThrow(() => secretGate({ tool: "write", args: { content: "key=" + akia }, env: { SECRET_SCAN_SKIP: "approved" } }));
  assert.doesNotThrow(() => secretGate({ tool: "write", args: { content: "nothing secret" }, env: {} }));
});

test("a secret only in oldString (deleted text) is NOT blocked (bash parity)", () => {
  // bash scans [content, new_string, command, new_source] — never old_string.
  const akia = "AKIA" + "ABCDEFGHIJKLMNOP";
  assert.doesNotThrow(() => secretGate({ tool: "edit", args: { oldString: "key=" + akia, newString: "key=REDACTED" }, env: {} }));
});
