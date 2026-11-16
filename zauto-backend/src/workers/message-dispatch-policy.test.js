import test from "node:test";
import assert from "node:assert/strict";
import {
  logTripDecision,
  needsStickerEnrichment,
  verboseTripLoggingEnabled,
} from "./message-dispatch-policy.js";

test("only sticker messages require asynchronous enrichment", () => {
  assert.equal(needsStickerEnrichment({ data: { msgType: "chat.text" } }), false);
  assert.equal(needsStickerEnrichment({ data: { msgType: "chat.photo" } }), false);
  assert.equal(needsStickerEnrichment({ data: { msgType: "CHAT.STICKER" } }), true);
  assert.equal(needsStickerEnrichment({ data: { msgType: " chat.sticker " } }), true);
  assert.equal(needsStickerEnrichment(null), false);
});

test("verbose per-message logs are off by default and accept only explicit opt-in", () => {
  assert.equal(verboseTripLoggingEnabled({}), false);
  assert.equal(verboseTripLoggingEnabled({ ZAUTO_VERBOSE_TRIP_LOGS: "0" }), false);
  assert.equal(verboseTripLoggingEnabled({ ZAUTO_VERBOSE_TRIP_LOGS: "1" }), true);
  const logs = [];
  const emitted = logTripDecision("trip_created", {
    reason: "matched",
    traceId: "trace-1",
  }, {
    env: {},
    log: value => logs.push(value),
  });
  assert.equal(emitted, false);
  assert.deepEqual(logs, []);
});

test("optional diagnostics include decisions only, never message content or sender", () => {
  const logs = [];
  const enabled = { ZAUTO_VERBOSE_TRIP_LOGS: "1" };
  assert.equal(logTripDecision("trip_created", {
    reason: "matched",
    traceId: "trace-123",
    content: "Sensitive trip text",
    senderId: "phone number",
  }, {
    env: enabled,
    log: value => logs.push(value),
  }), true);
  assert.equal(logs.length, 1);
  assert.ok(!logs[0].includes("Sensitive trip text"));
  assert.ok(!logs[0].includes("phone number"));
  assert.deepEqual(
    JSON.parse(logs[0].slice("[TRIP DECISION] ".length)),
    { decision: "trip_created", reason: "matched", traceId: "trace-123" },
  );

  assert.equal(logTripDecision("filter_rejected", {
    reason: "Keyword private phrase",
    traceId: " ",
  }, {
    env: enabled,
    log: value => logs.push(value),
  }), true);
  assert.equal(JSON.parse(logs[1].slice("[TRIP DECISION] ".length)).reason, "redacted");
  assert.equal(logTripDecision("arbitrary", {}, {
    env: enabled,
    log: value => logs.push(value),
  }), false);
  assert.equal(logs.length, 2);
});
