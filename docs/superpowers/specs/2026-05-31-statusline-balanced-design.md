# Status line — "Balanced" single-line redesign

**Date:** 2026-05-31
**Author:** RPI Cycle 11 (Research/Design phase)
**Source authority:** https://code.claude.com/docs/en/statusline (full field schema + best-practice examples)

## Problem

The current `statusline.sh` (cycle: ad-hoc, pre-RPI) shows only `dim model · dir basename · cyan branch`.
User asked to redesign it following best practices so the most useful information is visible and efficient.
User's stated priorities: context-window usage visibility; works through a CCS proxy with model routing.

## Decision (user-selected: Option A — Balanced single-line)

Single-line layout, ANSI colors, no emoji, `·` separators (Windows Git Bash safe):

```
{model} · {dir} ({branch} +{staged}~{modified}) · {bar} {pct}% {usedk}/{sizek} · ${cost}
```

Example: `Opus 4.8 · .claude (master) +2~1 · ▓▓▓░░░░░░░ 28% 56k/200k · $0.42`

## Field mapping (authoritative)

| Segment | JSON source | Rendering |
|---------|-------------|-----------|
| model | `model.display_name` | bold |
| dir | `workspace.current_dir // .cwd` → basename, backslash-normalized | plain |
| branch | `git -C $dir branch --show-current` | cyan `(name)` |
| staged | `git diff --cached --numstat` line count | green `+N` (hidden if 0) |
| modified | `git diff --numstat` line count | yellow `~N` (hidden if 0) |
| bar/pct | `context_window.used_percentage` (// 0, floor) | 10-char ▓/░, threshold-colored |
| tokens | `context_window.total_input_tokens` / `context_window_size` | dim `{usedk}/{sizek}` (1M→"1M") |
| cost | `cost.total_cost_usd` | dim `$%.2f`, **hidden when 0** |

## Color thresholds — tuned to THIS user

Context bar/pct color keyed to the user's **autocompact override = 55%** (not generic 70/90):
- `< 40%` → green (comfortable)
- `40–54%` → yellow (approaching the 55% autocompact point)
- `>= 55%` → red (at/past autocompact)

## Best practices applied (from docs)

1. **git status cached** per `session_id` (5s TTL) in `${TMPDIR:-/tmp}` — script runs every ~300ms, uncached git would lag. Never use `$$` (changes per invocation, defeats cache).
2. **Absolute tokens shown** (`56k/200k`) so `%` basis is explicit → resolves the user's known proxy "100% 착시" (ambiguity over 200K vs 1M basis).
3. **Single line** — docs warn multi-line + escapes are more prone to render glitches; single line also leaves the right side free for system notifications.
4. **Windows**: forward-slash path in settings command, backslash normalization in script, `printf` for output.
5. **Null-safe**: every field uses `// fallback`; `current_usage`/`used_percentage` can be null early or post-`/compact`.
6. **Hide zero-cost** noise (CCS proxy frequently reports `$0.00`).

## Addendum (cycle 11, post-implementation): context window is per-MODEL, not per-effort

User reported the live line showed `95% 190k/200k` on Opus while actually on the 1M window.
Investigation + official-source research established:

- **`effort.level` (low/…/xhigh/max) does NOT change the context window.** Effort governs how many
  *thinking* tokens are spent *within* the window; the window is a fixed per-model/config budget.
  (Anthropic + OpenAI docs, 2026-05.) The earlier "ultracode = 1M" impression was correlation:
  ultracode (xhigh) was being used together with Opus, whose real window is 1M.
- **The CCS proxy under-reports `context_window_size`** (e.g. 200000), so Claude Code's own
  `used_percentage` and built-in "context used" indicator are computed against the wrong ceiling.
  The accurate signal is `context_window.total_input_tokens` (the real token count).

Official windows (researched 2026-05), reflecting this user's routing:

| Model (slot → backend) | Real window | Source |
|------------------------|-------------|--------|
| Opus 4.8 (opus → claude-opus-4-8) | 1,000,000 (default) | Anthropic API/Bedrock/Vertex |
| Claude Sonnet 4.6 (real) | 1,000,000 (GA 2026-03) | Anthropic |
| GPT-5.5 (sonnet slot) | 272,000 standard / 1M opt-in / 400K Codex | OpenAI |
| GPT-5.4-mini (haiku slot) | 272,000 standard / ~1.05M opt-in | OpenAI |

Implementation: a per-model **FLOOR** table keyed on `model.display_name` that only RAISES a
too-small reported size (so an opt-in 1M reported by the proxy is still trusted), then recomputes
`% = total_input_tokens · 100 / window`. Table is easily edited if routing changes.

**Not fixable from the status line:** Claude Code's own bottom-bar "100% context used · /model"
indicator uses the proxy's mis-reported size. Fixing that requires the CCS proxy to advertise the
true window to Claude Code (proxy-level change), out of scope for `statusline.sh`.

## Out of scope

- Multi-line, rate_limits (proxy = no Claude.ai sub → field absent), PR badge, effort/vim/agent segments, OSC8 links, COLUMNS-based truncation. Can be added later if requested.
- No change to `settings.json` `statusLine` block (current `bash $HOME/.claude/statusline.sh` + padding 0 is correct and already verified).
