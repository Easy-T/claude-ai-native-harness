# opencode-harness (offline bundle)

Unpacks to `~/.config/opencode/`. Build/staging dir is git-tracked under `~/.claude/`.

- `plugin/` — v1 ESM governance plugin (loaded offline by opencode).
- `agent/` — constrained subagents (mode:subagent + permission floor).
- `skill/`, `command/`, `docs/ai-context/`, `AGENTS.md` — governance assets.
- `_oracle/` — BUILD-BOX ONLY differential conformance oracle. **Excluded from the shipped zip.**

## Local testing (do not clobber real config)
    OPENCODE_CONFIG_DIR="$PWD" opencode run "..."

## Ship
    # from ~/.claude/opencode-harness, excluding _oracle and node_modules
    zip -r ../opencode-harness.zip . -x '_oracle/*' 'node_modules/*' 'tests/*'
