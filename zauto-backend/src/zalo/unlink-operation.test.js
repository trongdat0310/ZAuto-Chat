import test from "node:test";
import assert from "node:assert/strict";
import { createZaloUnlinkOperation } from "./unlink-operation.js";

function harness(extra = {}) {
  const calls = [];
  const accounts = new Map([
    ["a", { id: "a", zaloLinked: true, zaloUserId: "zalo-a", membership: "paid" }],
    ["b", { id: "b", zaloLinked: true, zaloUserId: "zalo-b", membership: "free" }],
  ]);
  const make = (name, action) => userId => {
    calls.push([name, userId]);
    return action ? action(userId) : undefined;
  };
  const service = createZaloUnlinkOperation({
    cancelQrLogin: make("cancelQr"),
    stopWorker: make("stop", extra.stopWorker),
    cancelMetadata: make("cancelMetadata"),
    flushMessages: make("flush", extra.flushMessages),
    purgeFiles: make("purge", extra.purgeFiles ?? (() => ({ deleted: ["messages.json"] }))),
    clearCaches: make("clear"),
    markUnlinked: make("mark", userId => {
      const user = accounts.get(userId);
      if (user) {
        user.zaloLinked = false;
        user.zaloUserId = null;
      }
      return user;
    }),
    notify: make("notify", extra.notify),
  });
  return { service, calls, accounts };
}

test("unlink stops worker and flushes before purge and preserves subscription fields", async () => {
  const h = harness();
  const { user, cleanup } = await h.service.unlink("a");
  assert.deepEqual(h.calls.map(([name]) => name), [
    "cancelQr", "stop", "cancelMetadata", "flush",
    "purge", "clear", "mark", "notify",
  ]);
  assert.equal(user.zaloLinked, false);
  assert.equal(user.zaloUserId, null);
  assert.equal(user.membership, "paid");
  assert.deepEqual(cleanup.deleted, ["messages.json"]);
  assert.equal(h.accounts.get("b").zaloLinked, true);
});

test("simultaneous unlink requests for same account perform one deletion", async () => {
  let finish;
  const gate = new Promise(resolve => { finish = resolve; });
  const h = harness({ stopWorker: () => gate });
  const first = h.service.unlink("a");
  const second = h.service.unlink("a");
  await Promise.resolve();
  assert.equal(h.calls.filter(([name]) => name === "cancelQr").length, 1);
  finish();
  await Promise.all([first, second]);
  assert.equal(h.calls.filter(([name]) => name === "purge").length, 1);
});

test("failure to purge does not report successful unlink and may retry", async () => {
  let fail = true;
  const h = harness({ purgeFiles: () => {
    if (fail) throw new Error("EACCES");
    return { deleted: [] };
  } });
  await assert.rejects(h.service.unlink("a"), /EACCES/);
  assert.equal(h.accounts.get("a").zaloLinked, true);
  assert.equal(h.calls.some(([name]) => name === "notify"), false);
  fail = false;
  await h.service.unlink("a");
  assert.equal(h.accounts.get("a").zaloLinked, false);
});

test("notification delivery failures do not roll back committed unlink", async () => {
  const h = harness({ notify: () => { throw new Error("socket closed"); } });
  const result = await h.service.unlink("a");
  assert.equal(result.user.zaloLinked, false);
});

test("unlink is per app account and does not cancel another account", async () => {
  const h = harness();
  await h.service.unlink("a");
  for (const [, target] of h.calls) assert.equal(target, "a");
  assert.equal(h.accounts.get("b").zaloLinked, true);
});
