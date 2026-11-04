import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createSubscriptionService } from "./subscription-service.js";
import { createChatAcceptService } from "../conversations/chat-accept-core.js";
import { createAcceptanceProjection, mergeAcceptedHistory } from "./acceptance-history.js";
import { runMeteredAcceptance, acceptTargetKey } from "./acceptance-runner.js";

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zauto-history-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const store = createSubscriptionService({ file: path.join(dir, "data.json") });
  store.assignPlan({ userId: "user", actorId: "admin", planId: "daily15" });
  let sends = 0, lastPayload;
  const target = { groupId: "group", msgId: "m1", cliMsgId: "c1", uidFrom: "123", senderName: "Driver",
    status: "normal", isSelf: false, rawData: { content: "Original trip", msgId: "m1", cliMsgId: "c1", uidFrom: "123", ts: "1" } };
  const accept = createChatAcceptService({ store, groupType: 1, findMessage: () => target,
    getGroups: async () => [{ groupId: "group", name: "My group" }], connect: async () => ({
      sendMessage: async payload => { sends++; lastPayload = payload; return { message: { msgId: "sent1", cliMsgId: "sentc1" } }; },
    }) });
  return { store, accept, target, get sends() { return sends; }, get payload() { return lastPayload; } };
}
const input = { groupId: "group", msgId: "m1", cliMsgId: "c1", replyText: "ok" };

test("chat success supplies original content, mention identity and durable history", async t => {
  const f = fixture(t); const result = await f.accept("user", input);
  assert.equal(result.sourceContent, "Original trip"); assert.equal(result.groupName, "My group");
  assert.equal(f.payload.msg, "@Driver ok"); assert.equal(f.payload.mentions[0].uid, "123");
  const rows = mergeAcceptedHistory([], f.store.getAcceptedOperations("user"));
  assert.equal(rows.length, 1); assert.equal(rows[0].status, "accepted");
  assert.equal(rows[0].acceptanceSource, "chat_accept"); assert.equal(rows[0].content, "Original trip");
});
test("client cannot forge sender, feature or content for chat history", async t => {
  const f = fixture(t); const result = await f.accept("user", { ...input, senderId: "attacker", senderName: "Fake", feature: "auto_accept", sourceContent: "fake" });
  assert.equal(result.senderId, "123"); assert.equal(result.sourceContent, "Original trip");
  assert.equal(f.store.getUsageStatus("user", "auto_accept").used, 0);
});
test("repeated chat request sends once and creates one history entry", async t => {
  const f = fixture(t); await f.accept("user", input); const again = await f.accept("user", input);
  assert.equal(again.alreadyAccepted, true); assert.equal(f.sends, 1);
  assert.equal(mergeAcceptedHistory([], f.store.getAcceptedOperations("user")).length, 1);
});
test("screen and chat share one accepted target and charge only original feature", async t => {
  const f = fixture(t); await f.accept("user", input);
  const retry = await runMeteredAcceptance({ store: f.store, userId: "user", feature: "trip_screen_accept",
    targetKey: acceptTargetKey("group", "m1", "c1"), perform: async () => { throw Error("must not send"); } });
  assert.equal(retry.alreadyAccepted, true);
  assert.equal(f.store.getUsageStatus("user", "trip_screen_accept").used, 0);
  assert.equal(f.store.getUsageStatus("user", "chat_accept").used, 1);
});
test("ledger repairs an old pending-cache entry using the existing internal ID", async t => {
  const f = fixture(t); await f.accept("user", input);
  const rows = mergeAcceptedHistory([{ id: "old-id", groupId: "group", sourceMsgId: "m1", status: "new", content: "old", receivedAt: "old-time" }], f.store.getAcceptedOperations("user"));
  assert.equal(rows.length, 1); assert.equal(rows[0].id, "old-id"); assert.equal(rows[0].receivedAt, "old-time");
  assert.equal(rows[0].status, "accepted");
});
test("legacy client-ID-only cache deduplicates against canonical message ID", async t => {
  const f = fixture(t); await f.accept("user", input);
  const rows = mergeAcceptedHistory([{ id: "cli-only", groupId: "group", clientMessageId: "c1", status: "accepted" }], f.store.getAcceptedOperations("user"));
  assert.equal(rows.length, 1); assert.equal(rows[0].id, "cli-only");
});
test("two existing aliases collapse into one history row", async t => {
  const f = fixture(t); await f.accept("user", input);
  const rows = mergeAcceptedHistory([
    { id: "msg-old", groupId: "group", sourceMsgId: "m1", status: "accepted" },
    { id: "cli-old", groupId: "group", sourceCliMsgId: "c1", status: "accepted" },
  ], f.store.getAcceptedOperations("user"));
  assert.equal(rows.length, 1);
});
test("same message ID in another group does not collapse", async t => {
  const f = fixture(t); await f.accept("user", input);
  const rows = mergeAcceptedHistory([{ id: "other-group", groupId: "other", sourceMsgId: "m1", status: "accepted" }], f.store.getAcceptedOperations("user"));
  assert.equal(rows.length, 2);
});
test("projection marks an existing trip accepted and broadcasts to its owner only", async t => {
  const f = fixture(t); const result = await f.accept("user", input);
  const events = []; let lastSaved, updated;
  const project = createAcceptanceProjection({ saveMessage: (userId, data) => {
    lastSaved = { userId, data }; return { message: { id: "stored-id" } };
  }, updateMessage: (userId, id, changes) => { updated = { userId, id, ...changes }; return { id, ...changes }; },
  broadcast: (...args) => events.push(args) });
  project("user", result);
  assert.equal(lastSaved.userId, "user"); assert.equal(lastSaved.data.content, "Original trip");
  assert.equal(updated.status, "accepted"); assert.equal(events[0][0], "user");
  assert.equal(events[0][1], "trip_accepted"); assert.equal(events[0][2].messageId, "stored-id");
  assert.equal(f.sends, 1);
});
test("websocket failure cannot turn confirmed acceptance into failed send", async t => {
  const f = fixture(t); const result = await f.accept("user", input);
  const project = createAcceptanceProjection({ saveMessage: () => ({ message: { id: "id" } }),
    updateMessage: (_, id, changes) => ({ id, ...changes }), broadcast: () => { throw Error("socket failed"); } });
  assert.equal(project("user", result).status, "accepted");
  assert.equal(f.store.getUsageStatus("user", "chat_accept").used, 1);
});
test("secondary store failure leaves ledger history readable without resending", async t => {
  const f = fixture(t); const result = await f.accept("user", input);
  const project = createAcceptanceProjection({ saveMessage: () => { throw Error("disk full"); } });
  assert.throws(() => project("user", result), /disk full/);
  assert.equal(mergeAcceptedHistory([], f.store.getAcceptedOperations("user"))[0].content, "Original trip");
  await f.accept("user", input); assert.equal(f.sends, 1);
});
test("failed and uncertain operations are never shown as accepted", () => {
  for (const status of ["failed", "uncertain", "sending", "reserved"]) {
    assert.equal(mergeAcceptedHistory([], [{ status, targetKey: "a", result: { groupId: "g", sourceMsgId: "m" } }]).length, 0);
  }
});
test("confirmed reconciliation restores saved pre-send context into history", async t => {
  const f = fixture(t);
  const context = { groupId: "g", sourceMsgId: "m", sourceContent: "before timeout", acceptanceSource: "chat_accept" };
  await assert.rejects(runMeteredAcceptance({ userId: "user", feature: "chat_accept", targetKey: "unknown", context, store: f.store,
    perform: async mark => { mark(); throw Error("timeout"); } }), { code: "ACCEPT_OUTCOME_UNKNOWN" });
  f.store.resolveUncertain({ userId: "user", targetKey: "unknown", actorId: "admin", outcome: "succeeded", note: "Verified delivered" });
  assert.equal(mergeAcceptedHistory([], f.store.getAcceptedOperations("user"))[0].content, "before timeout");
});
test("bounded history is newest-first and preserves unrelated legacy accepts", () => {
  const records = Array.from({ length: 600 }, (_, i) => ({ id: `id-${i}`, groupId: "g", sourceMsgId: `${i}`,
    status: "accepted", acceptedAt: new Date(Date.UTC(2026, 0, 1) + i * 1000).toISOString() }));
  const rows = mergeAcceptedHistory(records, []);
  assert.equal(rows.length, 500); assert.equal(rows[0].id, "id-599");
});
test("ledger reads are scoped to the requested user", async t => {
  const f = fixture(t); await f.accept("user", input);
  assert.equal(f.store.getAcceptedOperations("other").length, 0);
});
test("unknown target, own message and recalled message cannot consume quota", async t => {
  const f = fixture(t);
  await assert.rejects(f.accept("user", { ...input, msgId: "wrong" }), { code: "REPLY_TARGET_NOT_FOUND" });
  f.target.isSelf = true; await assert.rejects(f.accept("user", input), { code: "ACCEPT_TARGET_UNAVAILABLE" });
  f.target.isSelf = false; f.target.status = "recalled";
  await assert.rejects(f.accept("user", input), { code: "ACCEPT_TARGET_UNAVAILABLE" });
  assert.equal(f.sends, 0); assert.equal(f.store.getUsageStatus("user", "chat_accept").used, 0);
});
