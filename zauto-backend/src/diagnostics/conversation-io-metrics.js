import { runtimeMetricsEnabled } from "./runtime-performance.js";

const quantile = (values, ratio) => {
  if (!values.length) return null;
  const ordered = [...values].sort((a, b) => a - b);
  return Number(ordered[Math.ceil(ordered.length * ratio) - 1].toFixed(2));
};

/**
 * Opt-in aggregated I/O timings; never logs filenames, messages, or user IDs.
 * It deliberately has no timer to keep overhead at zero while idle.
 */
export function createConversationIoMetrics({
  env = process.env,
  threshold = 50,
  log = console.log,
} = {}) {
  const enabled = runtimeMetricsEnabled(env);
  const limit = Number.isInteger(threshold) && threshold > 0 ? threshold : 50;
  const buckets = new Map();

  function flush(kind) {
    const bucket = buckets.get(kind);
    if (!enabled || !bucket || bucket.values.length === 0) return null;
    const result = {
      kind,
      n: bucket.values.length,
      p50Ms: quantile(bucket.values, 0.50),
      p95Ms: quantile(bucket.values, 0.95),
      p99Ms: quantile(bucket.values, 0.99),
      maxMs: quantile(bucket.values, 1),
      bytesWritten: bucket.bytes,
    };
    buckets.delete(kind);
    log("[CONVERSATION IO] " + JSON.stringify(result));
    return result;
  }

  function record({ kind, durationMs, bytes }) {
    if (!enabled || !["messages", "index"].includes(kind) ||
        !Number.isFinite(durationMs) || durationMs < 0 ||
        !Number.isFinite(bytes) || bytes < 0) {
      return;
    }
    const bucket = buckets.get(kind) ?? { values: [], bytes: 0 };
    bucket.values.push(durationMs);
    bucket.bytes += bytes;
    buckets.set(kind, bucket);
    if (bucket.values.length >= limit) flush(kind);
  }

  return { enabled, record, flush };
}
