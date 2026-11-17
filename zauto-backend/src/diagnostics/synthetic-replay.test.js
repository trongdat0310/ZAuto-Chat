import test from "node:test";
import assert from "node:assert/strict";
import {
  replaySyntheticLoad,
  validateReplayOptions,
} from "../../scripts/synthetic-replay-core.js";

test("rejects excessive and invalid synthetic replay loads", () => {
  for (const options of [
    { users: 0 },
    { users: 13 },
    { messagesPerUser: 301 },
    { messagesPerUser: -1 },
    { duplicatesEvery: 0 },
    { rejectedEvery: 2.5 },
  ]) {
    assert.throws(() => validateReplayOptions(options));
  }
  assert.deepEqual(validateReplayOptions({
    users: 2, messagesPerUser: 12, duplicatesEvery: 4, rejectedEvery: 3,
  }), { users: 2, messagesPerUser: 12, duplicatesEvery: 4, rejectedEvery: 3 });
});

test("multi-user synthetic replay persists every unique trip without duplicates", async () => {
  const report = await replaySyntheticLoad({
    users: 2,
    messagesPerUser: 12,
    duplicatesEvery: 3,
    rejectedEvery: 4,
  });
  assert.equal(report.kind, "synthetic-filter-dedupe-conversation-store");
  assert.equal(report.persisted, 24);
  assert.equal(report.saved, 24);
  assert.equal(report.duplicatesSkipped, 8);
  assert.equal(report.rejected, 6);
  assert.equal(report.matched, 32);
  assert.equal(report.inputEvents, 38);
  assert.equal(report.networkOrRealZaloTraffic, false);
  assert.equal(report.isolatedTemporaryData, true);
  assert.ok(report.dataBytes > 0);
  assert.ok(report.processingMs.p95 >= report.processingMs.p50);
  assert.ok(report.processingMs.p99 >= report.processingMs.p95);
});

test("repeat replay runs are independently isolated and retain no user state", async () => {
  const args = { users: 1, messagesPerUser: 5, duplicatesEvery: 2, rejectedEvery: 2 };
  const first = await replaySyntheticLoad(args);
  const second = await replaySyntheticLoad(args);
  assert.equal(first.persisted, 5);
  assert.equal(second.persisted, 5);
  assert.equal(first.duplicatesSkipped, 3);
  assert.equal(second.duplicatesSkipped, 3);
});
