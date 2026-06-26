// opencode-harness/tests/skeleton-scan.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { scanSkeleton } from "../plugin/lib/skeleton-scan.js";

test("scanSkeleton counts marker, phases, agent calls, protocol", () => {
  const c = [
    "orchestrator_skill: true",
    "# Phase 1", "# Phase 2", "# Phase 3",
    "Agent(subagent_type=explore-strict)",
    "## Communication Protocol",
  ].join("\n");
  assert.deepEqual(scanSkeleton(c), { hasMarker: 1, phase: 3, agent: 1, contract: 1 });
});

test("HTML-commented Agent() calls do NOT count (S4)", () => {
  const c = "orchestrator_skill: true\n<!-- Agent(subagent_type=x) -->\n# Phase 1";
  assert.equal(scanSkeleton(c).agent, 0);
});

test("no marker → hasMarker 0", () => {
  assert.equal(scanSkeleton("# Phase 1\n").hasMarker, 0);
});
