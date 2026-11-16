import test from "node:test";
import assert from "node:assert/strict";
import {
  parseLatencyLine,
  percentile,
  summarizeLatencyLog,
} from "../../scripts/latency-report.js";

test("parses existing Flutter trace format and converts microseconds to ms", () => {
  const line = "I/flutter: [LATENCY] trace=t1 " +
    "backend.filter=980.0us backend.dedupe=20us backend.store=1200us " +
    "backend.ws=300us network~=12ms flutter.socketToBus=2ms " +
    "flutter.busToHome=1ms flutter.homeToRender=17ms " +
    "flutter.internal=20ms total~=54ms";
  const result = parseLatencyLine(line);
  assert.equal(result.values["backend.filter"], 0.98);
  assert.equal(result.values["backend.store"], 1.2);
  assert.equal(result.values["flutter.internal"], 20);
  assert.equal(result.values["total~"], 54);
  assert.equal(result.clockSkew, false);
  assert.equal(parseLatencyLine("some unrelated log"), null);
});

test("reports p50/p95/p99 without treating clock skew as a duration", () => {
  const rows = Array.from({ length: 100 }, (_, i) =>
    "[LATENCY] trace=" + i + " backend.filter=100us " +
    "flutter.internal=" + (i + 1) + "ms " +
    "network~=clock-skew total~=clock-skew"
  );
  const report = summarizeLatencyLog(rows.join("\n"));
  assert.equal(report.traces, 100);
  assert.equal(report.clockSkewReports, 100);
  assert.equal(report.metrics["flutter.internal"].p50, 50);
  assert.equal(report.metrics["flutter.internal"].p95, 95);
  assert.equal(report.metrics["flutter.internal"].p99, 99);
  assert.equal(report.metrics["backend.filter"].p50, 0.1);
  assert.equal(report.metrics["total~"].n, 0);
  assert.equal(report.metrics["total~"].p95, null);
});

test("ignores invalid durations and empty samples", () => {
  const report = summarizeLatencyLog(
    "[LATENCY] total~=-8ms flutter.internal=-1ms backend.filter=abcus\n" +
    "[LATENCY] total~=clock-skew"
  );
  assert.equal(report.metrics["total~"].n, 0);
  assert.equal(report.metrics["flutter.internal"].n, 0);
  assert.equal(report.clockSkewReports, 1);
  assert.equal(percentile([], 0.95), null);
});
