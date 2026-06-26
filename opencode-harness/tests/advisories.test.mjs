// opencode-harness/tests/advisories.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { advisoriesFor, NATIVE_TOOLS } from "../plugin/lib/advisories.js";

const kinds = (r) => r.map((a) => a.kind).sort();

test("NATIVE_TOOLS includes the model-channel native tools, excludes MCP", () => {
  for (const t of ["bash", "edit", "write", "apply_patch", "read"]) assert.ok(NATIVE_TOOLS.has(t), t);
  assert.ok(!NATIVE_TOOLS.has("some_mcp_tool"));
});

test("RPI_SKIP surfaces a bypass advisory on bash/edit/write only", () => {
  assert.deepEqual(kinds(advisoriesFor({ tool: "bash", args: { command: "x" }, env: { RPI_SKIP: "y" } })), ["rpi-bypass"]);
  assert.deepEqual(kinds(advisoriesFor({ tool: "edit", args: { filePath: "/p/a.go" }, env: { RPI_SKIP: "y" } })).filter((k) => k === "rpi-bypass"), ["rpi-bypass"]);
  // unset → no rpi-bypass
  assert.ok(!kinds(advisoriesFor({ tool: "bash", args: { command: "x" }, env: {} })).includes("rpi-bypass"));
  // read is not a write-class tool → no rpi-bypass even with RPI_SKIP
  assert.ok(!kinds(advisoriesFor({ tool: "read", args: { filePath: "/p/a.go" }, env: { RPI_SKIP: "y" } })).includes("rpi-bypass"));
});

test("dependency manifests trigger the §5 ADR advisory", () => {
  for (const fp of ["package.json", "/proj/go.mod", "/p/requirements.txt", "/p/Cargo.toml", "/p/pom.xml", "/p/pyproject.toml", "/p/app.csproj"]) {
    assert.ok(kinds(advisoriesFor({ tool: "edit", args: { filePath: fp }, env: {} })).includes("adr"), `adr for ${fp}`);
  }
});

test("UI files trigger the §8 ui-design advisory", () => {
  for (const fp of ["/p/Btn.tsx", "/p/x.jsx", "/p/c.vue", "/p/d.svelte", "/p/app.css", "/p/t.scss"]) {
    assert.ok(kinds(advisoriesFor({ tool: "write", args: { filePath: fp }, env: {} })).includes("ui"), `ui for ${fp}`);
  }
});

test("non-trigger files yield no advisory; Windows backslash path is normalized", () => {
  assert.deepEqual(advisoriesFor({ tool: "write", args: { filePath: "/p/notes.md" }, env: {} }), []);
  // backslash path must still match (normalizePath parity)
  assert.ok(kinds(advisoriesFor({ tool: "edit", args: { filePath: "C:\\proj\\package.json" }, env: {} })).includes("adr"));
});

test("adr/ui fire only for file-WRITING tools — read of a manifest is not an edit", () => {
  // reading package.json must NOT nag about an ADR (CC surfaces on Write/Edit only)
  assert.deepEqual(advisoriesFor({ tool: "read", args: { filePath: "/p/package.json" }, env: {} }), []);
  assert.deepEqual(advisoriesFor({ tool: "read", args: { filePath: "/p/app.css" }, env: {} }), []);
});

test("advisory entries carry non-empty text", () => {
  for (const a of advisoriesFor({ tool: "edit", args: { filePath: "/p/x.tsx" }, env: { RPI_SKIP: "1" } })) {
    assert.equal(typeof a.kind, "string");
    assert.ok(a.text && a.text.length > 0, "text present");
  }
});
