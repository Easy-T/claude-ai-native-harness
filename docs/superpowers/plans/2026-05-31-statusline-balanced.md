# Status line "Balanced" redesign — implementation

**Status:** completed
**RPI-Cycle:** 11
**Started:** 2026-05-31
**Completed:** 2026-05-31
**Result:** Balanced single-line status line shipped + verified (8 layout scenarios + 7 context-window scenarios; `bash -n` clean). Mid-cycle research corrected two things: (1) an IFS-tab field-collapse bug → `\037` unit separator; (2) context window is per-MODEL, not per-effort (effort only spends thinking tokens within the window). Final: per-model window FLOOR table (Opus 1M / GPT slots 272K; trusts a larger reported value) recomputes % from real tokens — fixes the user's `95% 190k/200k` → `19% 190k/1M` on Opus.

## Provenance

Spec: `docs/superpowers/specs/2026-05-31-statusline-balanced-design.md`.
User-selected Option A (single-line balanced) via brainstorming. Single-file change to
`~/.claude/statusline.sh`. No `settings.json` change (existing `statusLine` block verified working).

## Tasks

- [x] T1 — Rewrite `statusline.sh` to the Balanced layout:
      `model(bold) · dir(branch +staged~modified) · bar pct usedk/sizek · $cost`.
      - Single jq pass → tab-separated scalars (model, dir, pct, used_tokens, size, cost, session_id).
      - Backslash path normalization (`${d//\\//}`) + basename.
      - git branch + staged/modified counts, **cached per session_id, 5s TTL** in `${TMPDIR:-/tmp}`.
      - 10-char ▓/░ bar; color thresholds 40/55 (tuned to user's autocompact 55%).
      - tokens shown as `usedk/sizek` (1000000 → "1M"); cost hidden when 0.
      - ANSI-C `$'\033[..m'` colors; output via `printf '%s\n'` (real ESC bytes, not `%b`).

- [x] T2 — Verify with mock inputs covering:
      - normal (branch + dirty + mid context + cost)
      - clean repo, 0 cost (cost hidden)
      - context thresholds: <40 green, 40–54 yellow, >=55 red
      - null/early context (`{}` → no crash, 0%, 0k)
      - Windows backslash path → basename correct
      - non-git dir → no branch segment
      - cache file created & reused (second run reads cache)
      - Caught + fixed: `IFS=$'\t' read` collapses empty fields (tab is IFS-whitespace) →
        switched jq output + cache to `\037` unit separator.

- [x] T3 — (superseded by T4) Static `OPUS_CTX_MAX=1000000` Opus→1M override. Replaced because
      the real window is model-specific, not an Opus blanket, and the user routes Sonnet/Haiku to GPT.

- [x] T4 — Per-model context-window FLOOR table keyed on `model.display_name`, researched from
      official sources (2026-05): Opus 4.x → 1M (Anthropic default on API/Bedrock/Vertex); Sonnet
      & Haiku slots → GPT (272K standard tier, OpenAI; 1M is a paid opt-in). Floor only RAISES a
      too-small reported `context_window_size`; a larger reported value (opt-in 1M) is trusted.
      Recomputes `% = tokens·100/window` when overriding. `effort.level` is deliberately NOT used —
      research confirmed effort is independent of window size.

- [x] T5 — Verify context-window mapping (7 scenarios): Opus 200K→1M; Sonnet/GPT-5.5/mini→272K;
      unknown model trusts reported; already-1M no double-apply; opt-in 1M reported is trusted.
      All pass; `bash -n` clean.

## Verification (success criteria)

- All T2 scenarios render correctly with no `jq`/bash errors on stderr.
- ANSI bytes present (ESC) and bar color switches at 40/55 boundaries.
- Script remains a single line of output; no multi-line.
- `settings.json` unchanged; `jq -e .statusLine` still valid.

## Notes / deviations

- **Gate P (review-strict spec↔plan alignment):** self-verified by main agent rather than the
  review-strict subagent. Rationale: (a) single-file, tightly-scoped change; (b) subagent routing
  is currently failing in this session ("400 System messages are not allowed" via CCS proxy — same
  class as the statusline-setup agent failure earlier). Documented here for cycle transparency.
