import crypto from "node:crypto";


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

    filterDoneAtMs:
      null,

    tripCreatedAtMs:
      null,

    wsBroadcastAtMs:
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
