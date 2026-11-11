import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { ThreadType } from "zca-js";
import { syncConversationGroups, setUserConversationPinned, markUserConversationRead, saveConversationMessage, getUserConversationMessages } from "./conversation-store.js";

process.env.JWT_SECRET ??= "private-avatar-test";
process.env.ZALO_SESSION_KEY ??= "00".repeat(32);
const { getConversationEventAvatars, refreshPrivateConversationAvatars } =
  await import("./private-conversation-avatar-service.js");

for (const isSelf of [true, false]) {
  test(`private avatar stays with peer for ${isSelf ? "outgoing" : "incoming"} message`, async () => {
    const result = await getConversationEventAvatars("account", {
      type: ThreadType.User, threadId: "peer", isSelf,
      data: { uidFrom: isSelf ? "self" : "peer" },
    }, { getAvatars: async (account, ids) => {
      assert.equal(account, "account");
      assert.deepEqual(ids, isSelf ? ["self", "peer"] : ["peer"]);
      return { self: "self.png", peer: "peer.png" };
    } });
    assert.equal(result.peerAvatar, "peer.png");
    assert.equal(result.senderAvatar, isSelf ? "self.png" : "peer.png");
  });
}

test("group messages only request sender avatar", async () => {
  const result = await getConversationEventAvatars("account", {
    type: ThreadType.Group, threadId: "group", data: { uidFrom: "sender" },
  }, { getAvatars: async (_, ids) => {
    assert.deepEqual(ids, ["sender"]);
    return { sender: "sender.png" };
  } });
  assert.deepEqual(result, { senderAvatar: "sender.png", peerAvatar: null });
});

test("outgoing private chat resolves title by peer ID rather than sender", async () => {
  const result = await getConversationEventAvatars("account", {
    type: ThreadType.User, threadId: "peer", isSelf: true,
    data: { uidFrom: "self", dName: "My account" },
  }, {
    getAvatars: async () => ({ self: "self.png", peer: "peer.png" }),
    getCachedName: (_, id) => {
      assert.equal(id, "peer");
      return "Correct peer title";
    },
  });
  assert.equal(result.peerName, "Correct peer title");
  assert.equal(result.peerAvatar, "peer.png");
});

function fixture(t) {
  const userId = `test-private-avatar-${process.pid}-${t.name.replace(/\W/g, "-")}`;
  t.after(() => fs.rmSync(new URL(`../../data/user-data/${userId}`, import.meta.url), {
    recursive: true, force: true,
  }));
  syncConversationGroups(userId, [
    { groupId: "peer", type: "user", name: "Peer", avatar: "wrong-self.png" },
    { groupId: "group", type: "group", name: "Group", avatar: "group.png" },
  ]);
  return userId;
}

test("list repairs persisted private avatar while preserving name pin read state and groups", async t => {
  const userId = fixture(t);
  setUserConversationPinned(userId, "peer", true);
  markUserConversationRead(userId, "peer");
  const result = await refreshPrivateConversationAvatars(userId, {
    getAvatars: async (_, ids) => {
      assert.deepEqual(ids, ["peer"]);
      return { peer: "correct-peer.png", group: "unrelated.png" };
    },
  });
  const peer = result.find(item => item.groupId === "peer");
  assert.equal(peer.avatar, "correct-peer.png");
  assert.equal(peer.name, "Peer");
  assert.equal(peer.pinned, true);
  assert.equal(peer.unreadCount, 0);
  assert.ok(peer.lastReadAt);
  assert.equal(result.find(item => item.groupId === "group").avatar, "group.png");
});

test("list repairs old incorrect private title while preserving history and unrelated groups", async t => {
  const userId = fixture(t);
  syncConversationGroups(userId, [{ groupId: "peer", type: "user", name: "My own Zalo" }]);
  saveConversationMessage(userId, {
    message: {
      type: ThreadType.User, threadId: "peer", isSelf: true,
      data: {
        uidFrom: "self", dName: "My own Zalo", msgId: "sent-1",
        msgType: "chat.text", content: "Hello peer", ts: Date.now(),
      },
    },
    groupName: "My own Zalo",
    senderName: "My own Zalo",
  });
  setUserConversationPinned(userId, "peer", true);
  const result = await refreshPrivateConversationAvatars(userId, {
    getAvatars: async (_, ids) => {
      assert.deepEqual(ids, ["peer"]);
      return { peer: "correct-peer.png" };
    },
    getCachedName: (_, id) => {
      assert.equal(id, "peer");
      return "Correct peer name";
    },
  });
  const peer = result.find(item => item.groupId === "peer");
  assert.equal(peer.name, "Correct peer name");
  assert.equal(peer.avatar, "correct-peer.png");
  assert.equal(peer.pinned, true);
  assert.equal(getUserConversationMessages(userId, "peer").length, 1);
  assert.equal(result.find(item => item.groupId === "group").name, "Group");
});

for (const failure of ["missing profile", "lookup error"]) {
  test(`list still opens on ${failure} without clearing avatars`, async t => {
    const userId = fixture(t);
    const result = await refreshPrivateConversationAvatars(userId, {
      getAvatars: async () => {
        if (failure === "lookup error") throw new Error("offline");
        return { peer: null };
      },
    });
    assert.equal(result.find(item => item.groupId === "peer").avatar, "wrong-self.png");
    assert.equal(result.length, 2);
  });
}
