# opencode-harness (offline bundle)

Unpacks to `~/.config/opencode/`. Build/staging dir is git-tracked under `~/.claude/`.

- `plugin/` — v1 ESM governance plugin (loaded offline by opencode).
- `agent/` — constrained subagents (mode:subagent + permission floor).
- `skill/`, `command/`, `docs/ai-context/`, `AGENTS.md` — governance assets.
- `_oracle/` — BUILD-BOX ONLY test/conformance tooling. **Excluded from the shipped zip.**

## Local testing
opencode loads plugins from the GLOBAL `~/.config/opencode` *in addition to* any
`OPENCODE_CONFIG_DIR`, so the config-dir override does NOT isolate a run (plugins
union, causing double-loads against a stale global). The build-box scripts stage a
clean copy to a temp dir (excluding `package.json` so opencode never auto-installs)
and inject a TEST-ONLY model backend at runtime:

    bash _oracle/oc-test.sh "say hello"                  # via the CCS proxy backend
    node _oracle/capture-server.mjs out.jsonl 8319 &     # capture outbound requests
    bash _oracle/oc-capture.sh 8319 "say OK"             # ground-truth system-prompt check

Headless `opencode run` waits on stdin — pass `</dev/null` so it exits cleanly.
Verifying L1 (AGENTS.md injection) must use capture, NOT the CCS proxy: the proxy
rewrites the system prompt to Claude Code's, so it cannot witness opencode's.

## Ship
opencode auto-installs a `package.json` found in the config dir (rewrites it,
writes a lockfile, and would hit the NETWORK in an offline env). The runtime plugin
is pure ESM with relative imports only, so `package.json` (build-time types) and
lockfiles MUST NOT ship.

    # from ~/.claude/opencode-harness
    zip -r ../opencode-harness.zip . \
      -x '_oracle/*' 'node_modules/*' 'tests/*' \
         'package.json' 'package-lock.json' 'bun.lock*' '.gitignore'
