// Pure hot-path decisions kept separate from Zalo I/O for regression tests.
export function needsStickerEnrichment(message) {
  return String(message?.data?.msgType ?? "").trim().toLowerCase() === "chat.sticker";
}

export function verboseTripLoggingEnabled(env = process.env) {
  return String(env.ZAUTO_VERBOSE_TRIP_LOGS ?? "").trim() === "1";
}

const allowedDecisions = new Set([
  "group_disabled",
  "filter_rejected",
  "duplicate_skipped",
  "trip_created",
]);

// Optional diagnostics: log state only, NEVER message content, keyword,
// sender name/ID, group title, or phone. Disabled in normal operation.
export function logTripDecision(decision, {
  reason = "",
  traceId = "",
} = {}, {
  env = process.env,
  log = console.log,
} = {}) {
  if (!verboseTripLoggingEnabled(env) || !allowedDecisions.has(decision)) {
    return false;
  }
  const safeReason = /^[a-z_]{1,48}$/i.test(String(reason))
    ? String(reason)
    : "redacted";
  const safeTrace = /^[a-zA-Z0-9-]{1,64}$/.test(String(traceId))
    ? String(traceId)
    : "-";
  log("[TRIP DECISION] " + JSON.stringify({
    decision,
    reason: safeReason,
    traceId: safeTrace,
  }));
  return true;
}
