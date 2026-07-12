# Status line — design spec (durable, statusline subsystem)

**Date:** 2026-05-31 (v1, RPI cycle 11) — **revised in-place 2026-06-11 (v2, RPI cycle 22); v2.1 live-feedback corrections 2026-06-12 (same cycle); v2.2 GPT-slot window remap 2026-07-12 (gpt-5.6 Sol/Luna swap)**
**Source authority:** https://code.claude.com/docs/en/statusline + live OAuth usage API probe (2026-06-11)
**v2 rationale:** user requested screenshot-parity multiline redesign (Desktop/statusline.png) with
5h/7d rate-limit bars, Fable 5 mapping, icons/colors. v1 "Out of scope" items (multi-line,
rate limits) are now in scope by explicit user request; v1 single-line layout is **superseded**.

## v2 Decision (user-approved 2026-06-11): 5-line layout, emoji icons, two accounts side-by-side

```
⚡ Fable 5 [1M] ✦ max ⏵ default 🧠
📁 ~/.claude ⎇ master +2~1 💰 $2.27 ⏱ 14m +172 -12
⚡ Context  ███████░░░░░░░░ 37% (368k/1M)
🕐 5H Limit biz ████░░░░ 25% (3h30m) · indie ██░░░░░░ 13% (3h30m)
📅 7D Limit biz ████░░░░ 26% (6/12 1pm) · indie ███░░░░░ 20% (6/13 7pm)
```

### v2.1 corrections (2026-06-12, live screenshot feedback — supersede conflicting v2 lines below)
1. **lines± glyphs are ASCII** `+N` green / `-N` red — ✚(U+271A)/✖(U+2716) render emoji-width
   in the user's terminal and visually collide with the digits.
2. **base `claude-fable-5` floors to 1,000,000** like Opus. Evidence: live render showed
   `368k/200k = 100%` while the session kept working (`exceeds_200k_tokens: true`) — CC
   under-reports `context_window_size` for base Fable; official window is 1M default.
   The `[1M]` chip stays picker-variant-only (id `[1m]` SSOT); L3's `(xxx/1M)` conveys basis.
3. **Per-account reset inline** — merged `combine()` display was ambiguous (one `(2h45m)` for
   two accounts). Each account segment is self-contained: `tag bar N% (reset)`.
   7d reset gains local hour: `M/D Ham|pm` (e.g. `6/12 1pm`), built from jq gmtime fields
   (no strftime %l — not portable on mingw).
4. **Output byte budget ≤1000 bytes total (hard test)** — Claude Code truncates statusline
   output around ~1KB: live L5 was cut mid-text ("(6/1") on a ~150-col terminal; cut position
   matched cumulative 1,024 bytes, not any column width. Therefore mkbar emits a color code
   only on color *change* (run-length ANSI), not per cell.

User selections (AskUserQuestion, 2026-06-11): 풀 5줄 / 두 계정 나란히 / 이모지 아이콘.

### Line 1 — model & session mode
| Segment | JSON source | Rendering |
|---|---|---|
| model | `model.display_name` | ⚡ bold |
| 1M variant | `model.id` ends with `[1m]` | dim cyan `[1M]` chip (id is SSOT, display_name identical for both variants) |
| effort | `effort.level` | ✦ + color: max=bright magenta, xhigh=orange(208), high=yellow, else dim |
| output style | `output_style.name` | ⏵ dim cyan (shown always, per approved preview) |
| thinking | `thinking.enabled == true` | 🧠 (hidden when false/absent) |

### Line 2 — workspace & session stats
| Segment | JSON source | Rendering |
|---|---|---|
| path | `workspace.current_dir // .cwd`, backslash→slash, `$HOME`→`~` | 📁 bright blue, full path (not basename) |
| branch +staged~modified | git, cached per session_id 5s TTL (v1 mechanism unchanged) | ⎇ cyan, green `+N`, yellow `~N` (zeros hidden) |
| cost | `cost.total_cost_usd` | 💰 dim `$%.2f`, hidden when 0 |
| duration | `cost.total_duration_ms` | ⏱ dim `Xm` / `XhYm`, hidden when <60s |
| lines | `cost.total_lines_added` / `_removed` | ✚ green / ✖ red, zeros hidden |

### Line 3 — context window
- 15-cell gradient bar + `PCT% (usedk/sizek)` (1M → "1M").
- **Gradient bar semantics (all bars):** filled cells are colored by *their position on the scale*
  (not one flat color), empty cells dim gray `░`. Context ramp keyed to autocompact 55%:
  position <40% → green(114), 40–54% → yellow(221), ≥55% → red(196). So a 60% bar visually
  shows the danger zone. 5H/7D ramp: <50% green, 50–79% yellow, ≥80% red.
- 256-color ANSI (`\033[38;5;Nm`) — supported by Windows Terminal & mintty.

### Lines 4/5 — Claude rate limits (5-hour / 7-day), both CCS accounts
- Data: **OAuth usage API** `GET https://api.anthropic.com/api/oauth/usage`
  headers `Authorization: Bearer <access_token>` + `anthropic-beta: oauth-2025-04-20`.
  Response fields used: `five_hour.utilization`, `five_hour.resets_at`,
  `seven_day.utilization`, `seven_day.resets_at` (floats 0–100, ISO8601 with fractional secs).
  Verified live 2026-06-11: HTTP 200 on both accounts.
- Accounts (script-top config array, easily editable):
  `~/.ccs/cliproxy/auth/claude-bizdev@nice.co.kr.json` → tag `biz` (blue),
  `~/.ccs/cliproxy/auth/claude-indietogo@gmail.com.json` → tag `indie` (magenta).
  Tokens are CCS-proxy-managed (auto-refreshed); the script only *reads* `access_token` —
  read-only usage GET, no refresh grant → no token-family revocation risk
  ([[project_ccs_codex_token_family_revocation]] class does not apply).
  `~/.claude/.credentials.json` (pro, expired) is intentionally **not** shown.
- Per-account 8-cell mini-bars side by side: `biz ████░░░░ 25% · indie ██░░░░░░ 13%`.
- Reset display: 5H → relative `(3h30m)`; 7D → local date `(6/12)`, no leading zeros.
  If the two accounts' display strings are equal → show once; else `(biz·indie)` joined by `·`.
  Timezone: epoch + tz-offset (bash `printf '%(%z)T'` builtin) + `gmtime` in jq — no
  `localtime` dependency (mingw jq tz unreliable).

## v2 caching & performance architecture (Windows spawn cost is the constraint)

Process spawn on Windows Git Bash is ~30–80ms; statusline refreshes every ~300ms. Budget:
**no new foreground processes vs v1.** Design:

1. **Single jq pass** computes everything: stdin fields + both usage caches via
   `--slurpfile` + reset strings (`sub("\\..*";"Z")|fromdateiso8601`, `now`, `gmtime/strftime`)
   + per-cache staleness + `refresh_needed` flag. Caches ensured to exist (`{}` seeded) before jq.
2. **Usage cache files** (account-global, *not* session-scoped — usage is per-account):
   `${TMPDIR:-/tmp}/ccstatus-usage-<tag>.json` = `{"fetched_at": <epoch>, "data": <api json>}`.
   TTL 60s, age computed *inside* jq from `fetched_at` (no stat call).
3. **Background refresh**: when stale, fire one detached subshell
   (`(...) >/dev/null 2>&1 &`) that, per account: jq-extracts token, `curl -fs --max-time 8`,
   writes tmp + atomic `mv` (only on HTTP 2xx, `-f`). Stampede guard: `mkdir` lock dir;
   stuck lock (>5min, checked only in this rare path) force-removed. Current tick renders
   stale/placeholder data — next tick picks up fresh cache.
4. **No `date` spawns**: epoch & tz-offset via bash `printf '%(%s)T' / '%(%z)T'` builtins.
5. First run (no cache): lines 4/5 render `…` placeholder; refresh fires; fills next tick.
6. Staleness marker: cache age >15min → dim `(stale)` suffix (e.g. CCS down / token invalid;
   failed curl never overwrites last good cache).

## v2 context-window mapping (supersedes v1 table *mechanism kept*: FLOOR, only raises)

| Match (priority order) | Window | Basis |
|---|---|---|
| `model.id` ends `[1m]` (any model) | 1,000,000 | Claude Code 1M picker variants (Fable/Opus/Sonnet via gateway discovery) |
| display `*Opus*` | 1,000,000 | Anthropic 1M default; proxy under-reports 200K (v1 addendum still valid) |
| display `*GPT-5.6*`/`*gpt-5.6*` (Sol/Luna/Terra) | 372,000 | v2.2 (2026-07-12): GPT slots swapped to gpt-5.6-sol (custom) / gpt-5.6-luna (haiku). CLIProxy 7.2.62-5 codex catalog reports `context_window: 372000` for all gpt-5.6 tiers (threshold-style value, same family as old 272K; OpenAI docs say 1.05M but keep FLOOR conservative at catalog value). Matches `display_name` only (like all non-[1m] rows); covers both slot `_NAME`s ("GPT-5.6 Sol"/"GPT-5.6 Luna") and the raw-id-as-display case (`--model gpt-5.6-*` direct runs, where display falls back to the id string). |
| display `*GPT-5.5*`/`*gpt-5.5*` | 272,000 | OpenAI standard tier (legacy custom slot; kept for old transcripts/direct `--model gpt-5.5`) |
| display `*Haiku*`/`*mini*` | 272,000 | gpt-5.4-mini (legacy haiku slot; kept for direct use) |
| `Fable 5` base, `Sonnet` (real), others | trust reported | Claude Code base Fable/Sonnet report 200,000 correctly (verified 2026-06-11 capture); [1m] variant is the 1M opt-in |

v2.2 ordering note: the gpt-5.6 case must sit **above** the `*mini*`/legacy-GPT cases in the
script so "GPT-5.6 Luna" doesn't fall through to a lower floor; FLOOR semantics (only raise)
otherwise unchanged.

% recomputed from `total_input_tokens` against the floored window (v1 mechanism).

## v1 sections still in force
- git status cache per session_id, 5s TTL, `\037` separators, printf output, null-safe jq.
- Context color thresholds keyed to user's autocompact override 55% (40/55 breakpoints).
- Hide-zero-noise rule (cost, staged/modified, lines, duration).
- Addendum research: effort ≠ window; proxy under-reports `context_window_size`;
  per-model FLOOR table approach. (Official windows table of 2026-05 retained as history;
  v2 mapping above is current.)
- "Not fixable from the status line": Claude Code's own bottom-bar % remains proxy-based.

## v2 out of scope
- Per-model 7d buckets (`seven_day_sonnet` etc.), `extra_usage` credits — only the two
  headline gauges.
- ChatGPT/codex quota for gpt-routed tiers (different auth family; lines 4/5 always show
  the two Claude accounts regardless of active model).
- `version`, `exceeds_200k_tokens`, fast_mode segments; COLUMNS-based truncation.
- settings.json `statusLine` block — unchanged (`bash $HOME/.claude/statusline.sh`, padding 0).

## v2 test plan (Phase I verification criteria)
1. Pipe captured base-Fable JSON (200K, effort max) → 5 lines, no errors, ctx 37% green.
2. Pipe captured `[1m]` JSON (1M, 24%) → `[1M]` chip, `238k/1M`.
3. Synthetic Opus JSON (200K reported) → floored to 1M.
4. Missing caches → `…` placeholders + lock dir + bg job writes both caches (then 2 re-renders).
5. Fresh caches → real utilization bars; reset strings match `(XhYm)` / `(M/D)` shapes.
6. Stale cache (fetched_at −20min) → `(stale)` suffix; refresh fired.
7. Non-git dir JSON → line 2 without branch segment.
8. Render time: `time` the script ≤ ~1s on this machine (foreground path).
