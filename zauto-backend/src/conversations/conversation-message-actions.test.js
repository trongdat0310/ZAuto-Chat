import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { ThreadType, Undo } from "zca-js";
import {
  findUserConversationMessage,
  getUserConversationList,
  markConversationMessageRecalledFromUndo,
  saveConversationMessage,
  syncConversationGroups,
} from "./conversation-store.js";

// Services import session configuration. These credentials are only for this
// isolated test process; connect is replaced with a fake, so no login occurs.
process.env.JWT_SECRET ??= "conversation-actions-test";
process.env.ZALO_SESSION_KEY ??= "00".repeat(32);
const { deleteUserConversationMessage } = await import("./conversation-delete-service.js");
const { undoUserConversationMessage } = await import("./conversation-undo-service.js");

function fixture(t, { type = "user", isSelf = true, age = 0 } = {}) {
  const userId = `test-actions-${process.pid}-${t.name.replace(/\W/g, "-")}`;
  const threadId = "peer-123";
  t.after(() => fs.rmSync(new URL(`../../data/user-data/${userId}`, import.meta.url), {
    recursive: true, force: true,
  }));
  syncConversationGroups(userId, [{ groupId: threadId, name: "Peer", type }]);
  saveConversationMessage(userId, {
    message: {
      threadId, type: type === "user" ? ThreadType.User : ThreadType.Group, isSelf,
      data: {
        msgId: "msg-1", cliMsgId: "cli-1", msgType: "chat.text",
        content: "Original content", uidFrom: isSelf ? "self" : threadId,
        ts: String(Date.now() - age),
      },
    },
    groupName: "Peer", senderName: isSelf ? "Me" : "Peer",
  });
  return {
    userId, threadId,
    read: () => findUserConversationMessage(userId, threadId, { msgId: "msg-1" }),
  };
}

for (const [type, expectedType] of [["user", ThreadType.User], ["group", ThreadType.Group]]) {
  test(`delete ${type} message uses the correct destination and onlyMe`, async t => {
    const f = fixture(t, { type, isSelf: false });
    const calls = [];
    await deleteUserConversationMessage(f.userId, f.threadId, { msgId: "msg-1" }, {
      connect: async () => ({ deleteMessage: async (...args) => { calls.push(args); return {}; } }),
    });
    assert.deepEqual(calls, [[{
      data: { msgId: "msg-1", cliMsgId: "cli-1", uidFrom: f.threadId },
      threadId: f.threadId, type: expectedType,
    }, true]]);
    assert.equal(f.read().status, "deleted_local");
  });

  test(`recall ${type} message uses the correct destination and waits for event`, async t => {
    const f = fixture(t, { type });
    const calls = [];
    await undoUserConversationMessage(f.userId, f.threadId, { msgId: "msg-1" }, {
      connect: async () => ({ undo: async (...args) => { calls.push(args); return {}; } }),
    });
    assert.deepEqual(calls, [[{ msgId: "msg-1", cliMsgId: "cli-1" }, f.threadId, expectedType]]);
    assert.equal(f.read().status, "normal");
  });
}

test("failed private delete preserves the local message", async t => {
  const f = fixture(t);
  await assert.rejects(deleteUserConversationMessage(f.userId, f.threadId, { msgId: "msg-1" }, {
    connect: async () => ({ deleteMessage: async () => { throw new Error("Zalo unavailable"); } }),
  }), /Zalo unavailable/);
  assert.equal(f.read().status, "normal");
  assert.equal(f.read().content, "Original content");
});

for (const [label, options, errorCode] of [
  ["another person's message", { isSelf: false }, "NOT_OWN_MESSAGE"],
  ["expired message", { age: 60 * 60 * 1000 + 1000 }, "RECALL_EXPIRED"],
]) {
  test(`private recall rejects ${label} before connecting`, async t => {
    const f = fixture(t, options);
    await assert.rejects(undoUserConversationMessage(f.userId, f.threadId, { msgId: "msg-1" }, {
      connect: async () => { assert.fail("Invalid recall must not connect to Zalo"); },
    }), { code: errorCode });
    assert.equal(f.read().status, "normal");
  });
}

for (const isSelf of [true, false]) {
  test(`private recall event from ${isSelf ? "self" : "peer"} clears bubble and preview`, t => {
    const f = fixture(t, { isSelf });
    const undo = new Undo("self", {
      uidFrom: isSelf ? "0" : f.threadId,
      idTo: isSelf ? f.threadId : "0",
      content: { globalMsgId: "msg-1", cliMsgId: "cli-1" },
    }, false);
    const recalled = markConversationMessageRecalledFromUndo(f.userId, undo);
    assert.equal(recalled.groupId, f.threadId);
    assert.equal(recalled.status, "recalled");
    assert.equal(recalled.content, null);
    assert.equal(recalled.rawData, null);
    assert.equal(getUserConversationList(f.userId)[0].lastContent, "Tin nhắn đã được thu hồi");
  });
}
