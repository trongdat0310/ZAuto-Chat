import test from "node:test";
import assert from "node:assert/strict";
import {
  runtimeMetricsEnabled,
  startRuntimePerformanceMonitor,
} from "./runtime-performance.js";

test("runtime telemetry is strictly opt-in", () => {
  assert.equal(runtimeMetricsEnabled({}), false);
  assert.equal(runtimeMetricsEnabled({ ZAUTO_PERF_METRICS: "0" }), false);
  assert.equal(runtimeMetricsEnabled({ ZAUTO_PERF_METRICS: "1" }), true);
  assert.equal(runtimeMetricsEnabled({ ZAUTO_PERF_METRICS: "TRUE" }), true);
});

test("disabled telemetry performs no scheduled logging", async () => {
  let reports = 0;
  const stop = startRuntimePerformanceMonitor({
    env: {},
    intervalMs: 20,
    log: () => reports++,
  });
  await new Promise(resolve => setTimeout(resolve, 60));
  stop();
  assert.equal(reports, 0);
});

test("enabled runtime report includes only aggregate performance values", async () => {
  let stop;
  try {
    const nextReport = new Promise((resolve, reject) => {
      const timeout = setTimeout(() =>
        reject(new Error("runtime performance report did not arrive")), 1500);
      stop = startRuntimePerformanceMonitor({
        env: { ZAUTO_PERF_METRICS: "1" },
        intervalMs: 60,
        log: line => {
          clearTimeout(timeout);
          resolve(line);
        },
      });
    });
    const line = await nextReport;
    assert.ok(line.startsWith("[PERF] "));
    const parsed = JSON.parse(line.slice("[PERF] ".length));
    assert.equal(typeof parsed.eventLoopP95Ms, "number");
    assert.equal(typeof parsed.rssMiB, "number");
    assert.equal(typeof parsed.cpuPercentOfCore, "number");
    assert.equal(Object.hasOwn(parsed, "message"), false);
    assert.equal(Object.hasOwn(parsed, "userId"), false);
  } finally {
    stop?.();
  }
});
