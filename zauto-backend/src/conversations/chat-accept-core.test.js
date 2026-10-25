import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createChatAcceptService } from "./chat-accept-core.js";
import { createSubscriptionService } from "../subscriptions/subscription-service.js";
import { acceptTargetKey, runMeteredAcceptance } from "../subscriptions/acceptance-runner.js";

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zauto-chat-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const store = createSubscriptionService({ file: path.join(dir, "store.json") });
  store.assignPlan({ userId: "user", actorId: "admin", planId: "daily15" });
  const target = { groupId: "111", msgId: "222", cliMsgId: "333", uidFrom: "444",
    senderName: "Tài xế 🚕", status: "normal", isSelf: false,
    rawData: { content: "Cuoc moi", uidFrom: "444", msgId: "222", cliMsgId: "333" } };
  const calls = [];
  const deps = { store, groupType: 1,
    findMessage: (user, group) => user === "user" && group === "111" ? target : null,
    getGroups: async () => [{ groupId: "111" }],
    connect: async () => ({ sendMessage: async (...args) => { calls.push(args); return { message: { msgId: "sent" } }; } }),
  };
  const accept = createChatAcceptService(deps);
  const input = { groupId: "111", msgId: "222", cliMsgId: "333", replyText: "Nhan" };
  return { store, target, calls, deps, accept, input };
}
test("tap sends once with server-derived mention and charges chat only", async t => {
  const f = fixture(t);
  const response = await f.accept("user", { ...f.input, uidFrom: "forged", senderName: "fake", feature: "auto_accept" });
  assert.equal(f.calls.length, 1);
  const [payload, groupId, type] = f.calls[0];
  assert.equal(groupId, "111"); assert.equal(type, 1);
  assert.equal(payload.msg, `@${f.target.senderName} Nhan`);
  assert.equal(payload.quote, f.target.rawData, "Zalo reply must quote the tapped message");
  assert.deepEqual(payload.mentions, [{ pos: 0, uid: "444", len: (`@${f.target.senderName}`).length }]);
  assert.equal(response.alreadyAccepted, false);
  assert.equal(f.store.getUsageStatus("user", "chat_accept").used, 1);
  assert.equal(f.store.getUsageStatus("user", "trip_screen_accept").used, 0);
});
test("repeated chat target sends and charges only once", async t => {
  const f = fixture(t);
  await f.accept("user", f.input);
  assert.equal((await f.accept("user", f.input)).alreadyAccepted, true);
  assert.equal(f.calls.length, 1);
});
test("same target already accepted on trip screen is not sent again in chat", async t => {
  const f = fixture(t);
  await runMeteredAcceptance({ userId: "user", feature: "trip_screen_accept", store: f.store,
    targetKey: acceptTargetKey("111", "222", "333"), perform: async mark => { mark(); return { text: "screen" }; } });
  assert.equal((await f.accept("user", f.input)).alreadyAccepted, true);
  assert.equal(f.calls.length, 0);
  assert.equal(f.store.getUsageStatus("user", "chat_accept").used, 0);
});
test("recalled, self and non-text messages cannot be accepted", async t => {
  const f = fixture(t);
  f.target.status = "recalled";
  await assert.rejects(f.accept("user", f.input), { code: "ACCEPT_TARGET_UNAVAILABLE" });
  f.target.status = "normal"; f.target.isSelf = true;
  await assert.rejects(f.accept("user", f.input), { code: "ACCEPT_TARGET_UNAVAILABLE" });
  f.target.isSelf = false; f.target.rawData.content = {};
  await assert.rejects(f.accept("user", f.input), { code: "ACCEPT_TARGET_UNAVAILABLE" });
  assert.equal(f.calls.length, 0);
});
test("message without original quote identifiers is rejected before sending", async t => {
  const f = fixture(t);
  delete f.target.rawData.msgId;
  delete f.target.rawData.cliMsgId;
  await assert.rejects(f.accept("user", f.input), { code: "REPLY_TARGET_UNAVAILABLE" });
  assert.equal(f.calls.length, 0);
});
test("invalid pointers, empty reply and conflicting IDs never send", async t => {
  const f = fixture(t);
  await assert.rejects(f.accept("user", { ...f.input, groupId: "../other" }), { code: "INVALID_ACCEPT_TARGET" });
  await assert.rejects(f.accept("user", { ...f.input, replyText: "  " }), { code: "INVALID_ACCEPT_REPLY" });
  await assert.rejects(f.accept("user", { ...f.input, cliMsgId: "different" }), { code: "REPLY_TARGET_NOT_FOUND" });
  assert.equal(f.calls.length, 0);
});
test("cannot accept another account's stored message or a non-member group", async t => {
  const f = fixture(t);
  await assert.rejects(f.accept("other", f.input), { code: "REPLY_TARGET_NOT_FOUND" });
  const accept = createChatAcceptService({ ...f.deps, getGroups: async () => [] });
  await assert.rejects(accept("user", f.input), { code: "GROUP_NOT_FOUND" });
  assert.equal(f.calls.length, 0);
});
test("quota exhausted means no connect and no external send", async t => {
  const f = fixture(t);
  for (let i = 0; i < 15; i++) f.store.consumeUsage("user", "chat_accept", `old-${i}`);
  let connects = 0;
  const accept = createChatAcceptService({ ...f.deps, connect: async () => { connects++; throw Error("must not connect"); } });
  await assert.rejects(accept("user", f.input), { code: "SUBSCRIPTION_LIMIT_REACHED" });
  assert.equal(connects, 0);
});
test("missing numeric sender ID cannot be used to mention everyone", async t => {
  const f = fixture(t); f.target.uidFrom = "-1";
  await assert.rejects(f.accept("user", f.input), { code: "INVALID_ACCEPT_SENDER" });
  assert.equal(f.calls.length, 0);
});

test("missing send acknowledgement holds the reservation without reporting success", async t => {
  const f = fixture(t);
  const accept = createChatAcceptService({ ...f.deps, connect: async () => ({ sendMessage: async () => ({ message: null }) }) });
  await assert.rejects(accept("user", f.input), { code: "ACCEPT_OUTCOME_UNKNOWN" });
  assert.equal(f.store.getUsageStatus("user", "chat_accept").used, 0);
  assert.equal(f.store.getUsageStatus("user", "chat_accept").reserved, 1);
});
