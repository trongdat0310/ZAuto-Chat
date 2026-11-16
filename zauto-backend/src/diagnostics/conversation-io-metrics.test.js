import test from "node:test";
import assert from "node:assert/strict";
import { createConversationIoMetrics } from "./conversation-io-metrics.js";

test("I/O metrics stay disabled unless explicitly enabled", () => {
  const lines = [];
  const metrics = createConversationIoMetrics({
    env: {},
    threshold: 2,
    log: value => lines.push(value),
  });
  assert.equal(metrics.enabled, false);
  metrics.record({ kind: "messages", durationMs: 20, bytes: 500 });
  assert.equal(metrics.flush("messages"), null);
  assert.deepEqual(lines, []);
});

test("aggregates message and index timings without exposing file paths", () => {
  const lines = [];
  const metrics = createConversationIoMetrics({
    env: { ZAUTO_PERF_METRICS: "1" },
    threshold: 3,
    log: value => lines.push(value),
  });
  metrics.record({ kind: "messages", durationMs: 5, bytes: 100 });
  metrics.record({ kind: "messages", durationMs: 12, bytes: 120 });
  metrics.record({ kind: "index", durationMs: 1, bytes: 10 });
  assert.equal(lines.length, 0);
  metrics.record({ kind: "messages", durationMs: 20, bytes: 140 });
  assert.equal(lines.length, 1);
  const sample = JSON.parse(lines[0].slice("[CONVERSATION IO] ".length));
  assert.deepEqual(sample, {
    kind: "messages",
    n: 3,
    p50Ms: 12,
    p95Ms: 20,
    p99Ms: 20,
    maxMs: 20,
    bytesWritten: 360,
  });
  metrics.record({ kind: "private-data/name", durationMs: 10, bytes: 100 });
  assert.equal(lines.length, 1);
  const index = metrics.flush("index");
  assert.equal(index.kind, "index");
  assert.equal(index.n, 1);
  assert.equal(index.bytesWritten, 10);
  assert.ok(!lines.join(" ").includes("private-data"));
});

test("invalid or negative durations do not corrupt the latency report", () => {
  const metrics = createConversationIoMetrics({
    env: { ZAUTO_PERF_METRICS: "1" },
    log: () => {},
  });
  metrics.record({ kind: "messages", durationMs: -3, bytes: 50 });
  metrics.record({ kind: "messages", durationMs: NaN, bytes: 50 });
  metrics.record({ kind: "messages", durationMs: 10, bytes: -1 });
  assert.equal(metrics.flush("messages"), null);
});
