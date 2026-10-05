import crypto from "node:crypto";
import {
  performance,
} from "node:perf_hooks";


export const realtimeLatencyTraceEnabled =
  process.env.ZAUTO_LATENCY_TRACE ===
  "1";


export function createRealtimeLatencyTrace() {
  if (!realtimeLatencyTraceEnabled) {
    return null;
  }


  return {
    traceId:
      crypto.randomUUID(),

    listenerReceivedAtMs:
      Date.now(),

    listenerPerfMs:
      performance.now(),

    filterDoneAtMs:
      null,

    filterPerfMs:
      null,

    dedupeDoneAtMs:
      null,

    dedupePerfMs:
      null,

    tripCreatedAtMs:
      null,

    tripPerfMs:
      null,

    wsBroadcastAtMs:
      null,

    wsBroadcastPerfMs:
      null,
  };
}


export function markRealtimeLatencyTrace(
  trace,
  key
) {
  if (!trace) {
    return;
  }


  trace[key] =
    Date.now();


  const perfKey =
    key === "filterDoneAtMs"
      ? "filterPerfMs"
      : key === "dedupeDoneAtMs"
        ? "dedupePerfMs"
        : key === "tripCreatedAtMs"
          ? "tripPerfMs"
          : null;


  if (perfKey) {
    trace[perfKey] =
      performance.now();
  }
}


export function cloneRealtimeLatencyTrace(
  trace
) {
  if (!trace) {
    return null;
  }


  return {
    ...trace,
  };
}
