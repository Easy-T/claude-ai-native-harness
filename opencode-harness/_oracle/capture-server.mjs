#!/usr/bin/env node
// BUILD-BOX ONLY (lives in _oracle/, EXCLUDED from the shipped zip).
//
// A minimal anthropic-compatible endpoint that captures opencode's OUTBOUND
// request body to a file, then returns a valid (streaming or non-streaming)
// response so opencode finishes cleanly. This lets us verify L1 (does opencode
// inject AGENTS.md / instructions into the system prompt it SENDS?) by
// inspecting ground truth — what opencode actually transmits — instead of
// round-tripping through a model/proxy that may rewrite the system prompt.
//
// Usage: node _oracle/capture-server.mjs <out-file> [port]
import http from "node:http";
import { appendFileSync } from "node:fs";

const OUT = process.argv[2] || "capture.json";
const PORT = Number(process.argv[3] || 8319);

const server = http.createServer((req, res) => {
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", () => {
    const body = Buffer.concat(chunks).toString("utf8");
    // Append EVERY captured request as one JSONL line — opencode fires several
    // requests per run (main agent call + title/summary calls); the main one
    // carries AGENTS.md, so we must keep all of them, not just the last.
    try {
      appendFileSync(OUT, JSON.stringify({ url: req.url, method: req.method, body }) + "\n");
    } catch (e) {
      process.stderr.write(`[capture] write failed: ${e}\n`);
    }
    process.stderr.write(`[capture] ${req.method} ${req.url} bytes=${body.length}\n`);

    let wantsStream = false;
    try { wantsStream = JSON.parse(body)?.stream === true; } catch { /* ignore */ }

    if (wantsStream) {
      res.writeHead(200, {
        "content-type": "text/event-stream",
        "cache-control": "no-cache",
        connection: "keep-alive",
      });
      const send = (event, data) =>
        res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
      send("message_start", {
        type: "message_start",
        message: { id: "msg_capture", type: "message", role: "assistant",
          model: "capture", content: [], stop_reason: null, stop_sequence: null,
          usage: { input_tokens: 1, output_tokens: 1 } },
      });
      send("content_block_start", { type: "content_block_start", index: 0,
        content_block: { type: "text", text: "" } });
      send("content_block_delta", { type: "content_block_delta", index: 0,
        delta: { type: "text_delta", text: "CAPTURE_OK" } });
      send("content_block_stop", { type: "content_block_stop", index: 0 });
      send("message_delta", { type: "message_delta",
        delta: { stop_reason: "end_turn", stop_sequence: null },
        usage: { output_tokens: 1 } });
      send("message_stop", { type: "message_stop" });
      res.end();
    } else {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({
        id: "msg_capture", type: "message", role: "assistant", model: "capture",
        content: [{ type: "text", text: "CAPTURE_OK" }],
        stop_reason: "end_turn", stop_sequence: null,
        usage: { input_tokens: 1, output_tokens: 1 },
      }));
    }
  });
});

server.listen(PORT, "127.0.0.1", () => {
  process.stderr.write(`[capture] listening on http://127.0.0.1:${PORT} -> ${OUT}\n`);
});
