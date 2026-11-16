import { monitorEventLoopDelay, performance } from "node:perf_hooks";

export function runtimeMetricsEnabled(env = process.env) {
  return ["1", "true", "yes", "on"].includes(
    String(env.ZAUTO_PERF_METRICS ?? "").trim().toLowerCase()
  );
}

const nsToMs = value =>
  Number.isFinite(value) ? Number((value / 1_000_000).toFixed(2)) : null;

/**
 * Low-overhead, opt-in runtime telemetry.
 * Does not emit user IDs, message content, access tokens or payloads.
 * CPU percentage is relative to one CPU core (may exceed 100%).
 */
export function startRuntimePerformanceMonitor({
  env = process.env,
  intervalMs = 15_000,
  log = console.log,
} = {}) {
  if (!runtimeMetricsEnabled(env)) return () => {};

  const lag = monitorEventLoopDelay({ resolution: 20 });
  lag.enable();
  let previousCpu = process.cpuUsage();
  let previousAt = performance.now();

  const timer = setInterval(() => {
    const now = performance.now();
    const elapsedMs = Math.max(1, now - previousAt);
    const deltaCpu = process.cpuUsage(previousCpu);
    previousCpu = process.cpuUsage();
    previousAt = now;

    const memory = process.memoryUsage();
    log("[PERF] " + JSON.stringify({
      intervalMs: Math.round(elapsedMs),
      eventLoopP50Ms: nsToMs(lag.percentile(50)),
      eventLoopP95Ms: nsToMs(lag.percentile(95)),
      eventLoopP99Ms: nsToMs(lag.percentile(99)),
      eventLoopMaxMs: nsToMs(lag.max),
      rssMiB: Number((memory.rss / 1_048_576).toFixed(1)),
      heapUsedMiB: Number((memory.heapUsed / 1_048_576).toFixed(1)),
      cpuPercentOfCore: Number((
        (deltaCpu.user + deltaCpu.system) / (elapsedMs * 1000) * 100
      ).toFixed(1)),
    }));
    lag.reset();
  }, intervalMs);
  timer.unref();

  return () => {
    clearInterval(timer);
    lag.disable();
  };
}
