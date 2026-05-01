# Stack Presets

Phase 1 explore-strict detects the stack signal, then Phase 2 substitutes these values.

| Detection signal | `STACK_DESCRIPTION` | `STACK_ALLOW_LIST` add | `STACK_GITIGNORE` add |
|---|---|---|---|
| `package.json` exists with `next` dependency | `Next.js + Node.js` | `"Bash(npm run *)", "Bash(npm test*)", "Bash(npx*)"` | `.next/`, `out/` |
| `package.json` (other than Next) | `Node.js + npm` | `"Bash(npm run *)", "Bash(npm test*)"` | `coverage/` |
| `pyproject.toml` exists | `Python (pyproject)` | `"Bash(pytest*)", "Bash(uv run*)", "Bash(uv add*)"` | `.venv/`, `*.egg-info/`, `.pytest_cache/` |
| `Cargo.toml` exists | `Rust` | `"Bash(cargo build*)", "Bash(cargo test*)", "Bash(cargo run*)"` | `target/` |
| `go.mod` exists | `Go` | `"Bash(go build*)", "Bash(go test*)", "Bash(go run*)"` | `/bin/`, `*.out` |
| `pubspec.yaml` exists | `Flutter / Dart` | `"Bash(flutter test*)", "Bash(dart run*)"` | `build/`, `.dart_tool/` |
| empty directory (no signal) | `(미감지)` | `[]` | empty line |

## Detection logic

Phase 1 explore-strict checks files in this priority order. The first match wins.
