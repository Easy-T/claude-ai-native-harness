# Prerequisites — opencode governance harness

Read this before running `install.sh`. The harness is designed to run **fully offline** once installed.

## Required

| Requirement | Why | Check |
|---|---|---|
| **opencode ≥ 1.17.11** | The runtime's central tool wrapper fires the plugin's `tool.execute.before`/`after` on **subagent (`task`) calls** at ≥ 1.17.10, which is what closes R1 (enforcing constrained-subagent *content*). The plugin API is byte-identical to 1.17.10. **1.17.9 runs degraded** (primary-agent enforcement only — subagent content not gated). | `opencode --version` |
| **git** | The worktree-teardown substitute (`git worktree prune`) and the closeout/PR flow shell out to git. Absent → those paths fail-open (non-fatal). | `git --version` |
| **opencode's bundled runtime (bun)** | opencode ships its own bun; the plugin is pure ESM (`node:` builtins + relative imports) and needs no separate Node install at runtime. (Node is only needed on the **build box** to run `_oracle/` tests.) | — |
| **An internal LLM provider** | This harness does **not** use the CCS proxy. Configure your company's internal model endpoint in `~/.config/opencode/opencode.json` under `provider`/`model`. | edit `opencode.json` |

## Offline guarantees

- **No runtime internet is required.** Skills, the governance plugin, and `AGENTS.md` are all local files in the config dir. Skill discovery never reaches the network (the bundle declares **no** `skills.urls`).
- `package.json` **must ship** (it does) — without a `package.json` in the config dir, opencode **hangs at plugin load**. Its dependency install is a *background, fail-open* step: offline it logs `WARN background dependency install failed` and then loads the local plugin anyway. `@opencode-ai/plugin` is a build-time **types-only** devDependency, never needed at runtime.
- `node_modules`/lockfiles are **not** shipped (platform-specific, regenerated). Do not add them.

## Install

```sh
# after unzipping the bundle
cd <unzipped-bundle>
bash install.sh           # backs up any existing ~/.config/opencode, then deploys
# then: set provider/model in ~/.config/opencode/opencode.json, restart opencode
```

## Caveats

- **Global config is loaded at startup, in union with any `OPENCODE_CONFIG_DIR`.** Do not rely on `OPENCODE_CONFIG_DIR` to isolate a run — opencode also loads the global `~/.config/opencode`. Install to the global dir (what `install.sh` does).
- **First run on a networked box** may rewrite `package.json` (devDeps→deps) and create `node_modules` — cosmetic, harmless, and confined to your config dir. Offline, none of that happens.
