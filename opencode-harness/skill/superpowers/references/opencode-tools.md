# opencode tool mapping (for superpowers skills)

Skills speak in actions; here is how each action maps to opencode (sst/opencode).

| Action (skill prose) | opencode mechanism |
|---|---|
| "invoke / use the `X` skill" | the `skill` tool: `skill({ name: "X" })` |
| "dispatch a subagent" / `Agent(subagent_type="X")` | the `task` tool targeting subagent `X` (e.g. `@X`); subagents are `agent/*.md` with `mode: subagent` |
| "create a todo list" / `TodoWrite` | `todowrite` |
| "read / search / edit / write a file" | `read` / `grep` + `glob` / `edit` / `write` |
| instruction files | `AGENTS.md` (auto-loaded) + `instructions[]` (local paths) in `opencode.json` |

Constraints:
- The harness denies the `task` tool *inside* subagents (Anthropic 1-level dispatch limit; enforced via `permission.task: deny` in the wrapper agent frontmatter).
- `cd` in a dispatched bash does not persist across calls (shared, non-persistent cwd).
- No network at load: never set `skills.urls`; keep `instructions[]` to local paths only.
