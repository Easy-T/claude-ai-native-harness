# opencode-harness (offline bundle)

Unpacks to `~/.config/opencode/`. Build/staging dir is git-tracked under `~/.claude/`.

- `plugin/` — v1 ESM governance plugin (loaded offline by opencode).
- `agent/` — constrained subagents (mode:subagent + permission floor).
- `skill/` (21: 14 superpowers + 7 custom incl. `init-ai-ready-project` = opencode-target project bootstrap), `command/`, `docs/ai-context/`, `AGENTS.md` — governance assets.
- `_oracle/` — BUILD-BOX ONLY test/conformance tooling. **Excluded from the shipped zip.**
- `install.sh`, `PREREQUISITES.md` — **ship**: target deploy helper + prerequisites (read PREREQUISITES.md first).

## Local testing
opencode loads plugins from the GLOBAL `~/.config/opencode` *in addition to* any
`OPENCODE_CONFIG_DIR`, so the config-dir override does NOT isolate a run (plugins
union, causing double-loads against a stale global). The build-box scripts stage a
clean copy to a temp dir (keeping `package.json` — required for plugin load — and
stripping the canonical exclusion set: build-box tooling + generated/VCS files; see
Ship) and inject a TEST-ONLY model backend at runtime:

    bash _oracle/oc-test.sh "say hello"                  # via the CCS proxy backend
    node _oracle/capture-server.mjs out.jsonl 8319 &     # capture outbound requests
    bash _oracle/oc-capture.sh 8319 "say OK"             # ground-truth system-prompt check

Headless `opencode run` waits on stdin — pass `</dev/null` so it exits cleanly.
Verifying L1 (AGENTS.md injection) must use capture, NOT the CCS proxy: the proxy
rewrites the system prompt to Claude Code's, so it cannot witness opencode's.

## Ship
opencode **HANGS at plugin load when no `package.json` exists in the config dir**,
so a minimal `package.json` (with `"type": "module"`) MUST ship (live-verified,
spec §15). opencode's dependency install is a BACKGROUND, fail-open step: in an
offline env it logs `WARN background dependency install failed` and then loads the
local plugin anyway — the runtime plugin is pure ESM importing only `node:` builtins
+ relative files, so it needs **no installed deps** (`@opencode-ai/plugin` is a
build-time types-only devDependency; opencode may inject+install it on a networked
box, a harmless cosmetic mutation, but offline it is simply skipped). `node_modules`
+ lockfiles are platform-specific and regenerated — they MUST NOT ship.

    # from ~/.claude/opencode-harness  (package.json SHIPS; node_modules/lockfiles do not)
    # CANONICAL exclusion set — identical to install.sh + _oracle/_stage.sh.
    zip -r ../opencode-harness.zip . \
      -x '_oracle/*' 'tests/*' 'node_modules/*' '.git/*' \
         'package-lock.json' 'bun.lock*' '.gitignore' '_skills_capture.jsonl'

## Prerequisites & Install
Read **PREREQUISITES.md** (opencode ≥ 1.17.11, git, an internal LLM provider; no runtime internet).
On the target box, after unzipping:

    cd <unzipped-bundle>
    bash install.sh        # backs up any existing ~/.config/opencode, deploys (keeps package.json)
    # then set provider/model in ~/.config/opencode/opencode.json, restart opencode

## Verify & Accept (build box)
    bash _oracle/verify-all.sh    # all units + differential & discovery oracles + clean-stage gate
    bash _oracle/acceptance.sh    # build zip → unzip → assert self-contained + offline plugin load

Both are non-destructive (never mutate `~/.config/opencode`) and offline.
