# Stack Presets

Phase 1 explore-strict detects the stack signal, then Phase 2 substitutes these values.

## Core Fields

> **opencode note:** the `STACK_ALLOW_LIST` column below is **unused** in the opencode template set
> (opencode uses default-allow `permission.bash` + explicit denies; no allow array). Kept for parity
> with the CC preset table. `STACK_DESCRIPTION` / `STACK_GITIGNORE` / `CHECK_COMMANDS` are still used.

| Detection signal | `STACK_DESCRIPTION` | `STACK_ALLOW_LIST` add (unused in opencode) | `STACK_GITIGNORE` add |
|---|---|---|---|
| `package.json` exists with `next` dependency | `Next.js + Node.js` | `"Bash(npm run *)", "Bash(npm test*)", "Bash(npx*)"` | `.next/`, `out/` |
| `package.json` (other than Next) | `Node.js + npm` | `"Bash(npm run *)", "Bash(npm test*)"` | `coverage/` |
| `pyproject.toml` exists | `Python (pyproject)` | `"Bash(pytest*)", "Bash(uv run*)", "Bash(uv add*)"` | `.venv/`, `*.egg-info/`, `.pytest_cache/` |
| `Cargo.toml` exists | `Rust` | `"Bash(cargo build*)", "Bash(cargo test*)", "Bash(cargo run*)"` | `target/`, `Cargo.lock`(library 한정) |
| `go.mod` exists | `Go` | `"Bash(go build*)", "Bash(go test*)", "Bash(go run*)"` | `/bin/`, `*.out` |
| `pubspec.yaml` exists | `Flutter / Dart` | `"Bash(flutter test*)", "Bash(dart run*)"` | `build/`, `.dart_tool/` |
| empty directory (no signal) | `(미감지)` | `[]` | empty line |

## Quality Gate Fields

Used for `scripts/check.sh` generation (Task B) and `runbook.md` `{{LOCAL_CHECK_COMMAND}}` substitution.

| Detection signal | `CHECK_COMMANDS` | `LOCAL_CHECK_COMMAND` (runbook one-liner) | `SMOKE_COMMAND` |
|---|---|---|---|
| `package.json` with `next` | `npm run lint --if-present && npm test` | `bash scripts/check.sh` | `npm run build 2>/dev/null \|\| true` |
| `package.json` (other) | `npm run lint --if-present && npm test` | `bash scripts/check.sh` | _(none)_ |
| `pyproject.toml` + `uv.lock` | `uv run ruff check . && uv run ruff format --check . && uv run pytest -q` | `bash scripts/check.sh` | `uv run python -m <PACKAGE> --help 2>/dev/null \|\| true` |
| `pyproject.toml` (no uv.lock) | `python -m ruff check . && python -m pytest -q` | `bash scripts/check.sh` | _(none)_ |
| `Cargo.toml` | `cargo fmt --check && cargo clippy -- -D warnings && cargo test` | `bash scripts/check.sh` | `cargo run -- --help 2>/dev/null \|\| true` |
| `go.mod` | `go vet ./... && go test ./...` | `bash scripts/check.sh` | _(none)_ |
| `pubspec.yaml` | `flutter test` | `bash scripts/check.sh` | _(none)_ |
| empty (no signal) | `echo "No checks configured. Edit scripts/check.sh."` | `bash scripts/check.sh` | _(none)_ |

For the empty-stack case, `CHECK_COMMANDS` outputs a message and exits 0 (does not fail init).

## Detection logic

Phase 1 explore-strict checks files in this priority order. The first match wins.
