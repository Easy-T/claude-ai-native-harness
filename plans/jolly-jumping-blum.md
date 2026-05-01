# T3 wiki re-extraction plan

## Context

The graph rebuild is complete and `wiki/_system/hot.md` identifies the next optional maintenance task as T3 re-extraction: files with very short wiki bodies relative to source PDFs (`cpp < 200`) and large PDF size (`> 5MB`). The goal is to improve existing wiki pages whose current text likely missed image-layer tables, prices, schedules, or dense screenshots, while keeping `raw/` immutable and preserving wiki schema/link integrity.

## Recommended approach

1. **Recompute the T3 target list**
   - Run a read-only Python analysis from the project root that maps each `wiki/*.md` YAML `source:` path to its source PDF, counts wiki body characters, obtains PDF page count and file size, and computes `cpp = body_chars / page_count`.
   - Filter for `cpp < 200` and `PDF size > 5MB`.
   - Exclude the 19 T1+T2 files already re-extracted if they no longer meet the threshold after the previous session.
   - Print the final target list before editing so the execution scope is visible.

2. **Re-extract each target source PDF into its existing wiki page**
   - Do not create new wiki pages for T3; update the existing page whose YAML `source:` points to the target PDF.
   - Use PyMuPDF (`fitz`) as the fallback extraction path because Windows lacks `pdftoppm` and prior CID-encoded PDFs needed `page.get_text("html")` plus entity decoding or rendered pixmaps.
   - For each PDF, prioritize image-layer and dense-data recovery:
     - apartment/area names
     - prices, jeonse, contribution amounts, loan limits
     - project stages and schedules
     - tables, rankings, and comparison rows
     - investment logic and warnings
   - Preserve the existing page filename and YAML shape unless a field is clearly stale; update `updated:` to today.
   - Keep or improve relevant `[[wikilink]]` references, but avoid adding links to nonexistent pages.

3. **Quality-control updated pages**
   - For each changed page, ensure:
     - standard YAML fields remain present
     - `source:` exactly matches an existing `raw/...` path
     - `> [!takeaway] 핵심 인사이트` label is present
     - no placeholder/comment-thread/OCR UI junk remains
     - body is materially richer than before or has a clear note if extraction was partial
   - If a PDF remains visually/OCR difficult, mark confidence appropriately rather than fabricating data.

4. **Run wiki validation and graph rebuild**
   - Run `/wiki-lint` equivalent script and fix any introduced YAML/link/content issues.
   - Rebuild `graphify-out/graph.json`, `graphify-out/GRAPH_REPORT.md`, and `graphify-out/graph.html` only after lint is clean.
   - Confirm node/link counts and any isolated nodes.

5. **Update orchestrator-owned tracking files**
   - Append a concise entry to `wiki/_system/log.md` describing the T3 re-extraction batch.
   - Update `wiki/_system/hot.md` with the new session summary, lint/graph status, and remaining next tasks.
   - Only update `wiki/_system/_progress.md` if T3 items are explicitly represented there.

## Critical files likely to be modified

- Existing `wiki/*.md` pages selected by the recomputed T3 criteria
- `graphify-out/graph.json`
- `graphify-out/GRAPH_REPORT.md`
- `graphify-out/graph.html`
- `wiki/_system/log.md`
- `wiki/_system/hot.md`
- Possibly `wiki/_system/_progress.md` if matching T3 checklist entries exist

## Verification

- Read-only target analysis prints the selected T3 list and count.
- After edits, run wiki-lint and require `0 errors` before graph rebuild.
- Rebuild graph and verify `graph.json`, `GRAPH_REPORT.md`, and `graph.html` regenerate successfully.
- Spot-check 2-3 updated wiki pages against their PDFs for recovered concrete data and valid `source:` paths.
