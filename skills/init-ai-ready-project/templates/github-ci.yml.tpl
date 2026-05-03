name: CI

on:
  pull_request:
  push:
    branches: [main, master]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        if: hashFiles('pyproject.toml') != ''
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install uv
        if: hashFiles('pyproject.toml') != ''
        uses: astral-sh/setup-uv@v4

      - name: Set up Node
        if: hashFiles('package.json') != ''
        uses: actions/setup-node@v4
        with:
          node-version: '22'

      - name: Set up Rust
        if: hashFiles('Cargo.toml') != ''
        uses: dtolnay/rust-toolchain@stable

      - name: Run project checks
        run: bash scripts/check.sh
