import test from "node:test";
import assert from "node:assert/strict";
import { createUserGroupDirectory } from "./user-group-directory.js";

function harness() {
  const byUser = new Map();
  const settings = new Map();
  let writes = 0;
  const readConversations = userId => byUser.get(userId) ?? [];
  const persistGroups = (userId, groups) => {
    writes++;
    const list = [...readConversations(userId)];
    for (const group of groups) {
      const i = list.findIndex(x => x.groupId === group.groupId);
      if (i < 0) list.push(group);
      else list[i] = { ...list[i], ...group };
    }
    byUser.set(userId, list);
  };
  const make = () => createUserGroupDirectory({
    readConversations, persistGroups,
    readSettings: userId => settings.get(userId) || {},
    logger: { log() {} },
  });
  return { make, byUser, settings, writes: () => writes };
}

test("groups are discovered only after a group message", async () => {
  const h = harness();
  const d = h.make();
  assert.deepEqual(await d.getUserGroups("u"), []);
  const item = d.discoverUserGroup("u", { threadId: "g-1", data: { groupName: "Hà Nội" } });
  assert.equal(item.name, "Hà Nội");
  assert.deepEqual(await d.getUserGroups("u"), [
    { groupId: "g-1", name: "Hà Nội", avatar: null, totalMember: null, enabled: false },
  ]);
  assert.equal(h.writes(), 1);
});

test("repeated messages do not create duplicate groups or writes", async () => {
  const h = harness(), d = h.make();
  for (let i = 0; i < 200; i++) d.discoverUserGroup("u", { threadId: "g1", data: {} });
  assert.equal(h.writes(), 1);
  assert.equal((await d.getUserGroups("u")).length, 1);
});

test("group title is not confused with sender name and may later improve", async () => {
  const h = harness(), d = h.make();
  d.discoverUserGroup("u", { threadId: "g", data: { dName: "Sender name" } });
  assert.equal(d.getUserGroupName("u", "g"), "Nhóm g");
  d.discoverUserGroup("u", { threadId: "g", data: { groupName: "Tên nhóm thật" } });
  assert.equal(d.getUserGroupName("u", "g"), "Tên nhóm thật");
  assert.equal(h.writes(), 2);
});

test("stored groups survive restart and user accounts remain isolated", async () => {
  const h = harness(), d = h.make();
  d.discoverUserGroup("first", { threadId: "g1", groupName: "Nhóm 1" });
  const restarted = h.make();
  assert.equal((await restarted.getUserGroups("first")).length, 1);
  assert.equal((await restarted.getUserGroups("second")).length, 0);
  assert.equal(restarted.getUserGroupName("first", "g1"), "Nhóm 1");
});

test("enabled flags remain separate and newly discovered groups default to OFF", async () => {
  const h = harness(), d = h.make();
  d.discoverUserGroup("u", { threadId: "g1" });
  assert.equal((await d.getUserGroups("u"))[0].enabled, false);
  h.settings.set("u", { g1: { enabled: true } });
  assert.equal((await d.getUserGroups("u"))[0].enabled, true);
  h.settings.set("u", { g1: { enabled: false } });
  assert.equal((await d.getUserGroups("u"))[0].enabled, false);
  assert.equal(h.writes(), 1);
});

test("private conversations do not appear in group directory", async () => {
  const h = harness();
  h.byUser.set("u", [
    { groupId: "dm1", name: "Private", type: "user" },
    { groupId: "g1", name: "Real group", type: "group" },
  ]);
  assert.deepEqual((await h.make().getUserGroups("u")).map(x => x.groupId), ["g1"]);
});

test("invalid group IDs are ignored", async () => {
  const h = harness(), d = h.make();
  assert.equal(d.discoverUserGroup("u", { threadId: " " }), null);
  assert.equal(d.discoverUserGroup("u", { threadId: "bad\nvalue" }), null);
  assert.equal(h.writes(), 0);
});

test("clearing process-local cache does not delete persisted conversations", async () => {
  const h = harness(), d = h.make();
  d.discoverUserGroup("u", { threadId: "g" });
  d.clearUserGroupCache("u");
  assert.equal((await d.getUserGroups("u")).length, 1);
});


test("single-group Zalo details fix name, avatar and member count", async () => {
  const h = harness(), d = h.make();
  d.discoverUserGroup("u", { threadId: "g-1", data: { dName: "Người gửi", avatar: "https://wrong.sender.jpg" } });
  const fixed = d.applyUserGroupMetadata("u", "g-1", {
    groupId: "g-1", name: "Nhóm Lái Xe", fullAvt: "https://zalo.example/group-full.jpg",
    avt: "https://zalo.example/small.jpg", totalMember: 42,
  });
  assert.equal(fixed.name, "Nhóm Lái Xe");
  assert.equal(fixed.avatar, "https://zalo.example/group-full.jpg");
  assert.equal(fixed.totalMember, 42);
  assert.deepEqual((await d.getUserGroups("u"))[0], {
    groupId: "g-1", name: "Nhóm Lái Xe",
    avatar: "https://zalo.example/group-full.jpg", totalMember: 42, enabled: false,
  });
  assert.equal(h.writes(), 2);
});

test("realtime group messages cannot overwrite a resolved group avatar", () => {
  const h = harness(), d = h.make();
  d.discoverUserGroup("u", { threadId: "g", data: {} });
  d.applyUserGroupMetadata("u", "g", {
    name: "Tên chính thức", fullAvt: "https://zalo.example/avatar.jpg",
  });
  d.discoverUserGroup("u", { threadId: "g", data: { dName: "Tên người gửi", avatar: "https://wrong.user" } });
  assert.equal(d.getUserGroupName("u", "g"), "Tên chính thức");
  assert.equal(h.byUser.get("u")[0].avatar, "https://zalo.example/avatar.jpg");
  assert.equal(h.writes(), 2);
});

test("group metadata respects existing pin and read state without changing enabled flags", async () => {
  const h = harness(), d = h.make();
  h.byUser.set("u", [{ groupId: "g", type: "group",
    name: "Nhóm g", pinned: true, unreadCount: 8, lastContent: "Tin nhắn", hidden: true }]);
  h.settings.set("u", { g: { enabled: true } });
  d.applyUserGroupMetadata("u", "g", { name: "Tên đúng", avt: "//zalo.example/photo.jpg" });
  const stored = h.byUser.get("u")[0];
  assert.equal(stored.pinned, true);
  assert.equal(stored.unreadCount, 8);
  assert.equal(stored.lastContent, "Tin nhắn");
  assert.equal(stored.hidden, true);
  assert.equal((await d.getUserGroups("u"))[0].enabled, true);
  assert.equal(stored.avatar, "https://zalo.example/photo.jpg");
});

test("invalid group avatars do not replace previously saved group photo", () => {
  const h = harness(), d = h.make();
  d.discoverUserGroup("u", {
    threadId: "g", groupAvatar: "https://zalo.example/g.jpg",
  });
  assert.equal(d.applyUserGroupMetadata("u", "g", { avatar: "javascript:alert(1)" }), null);
  assert.equal(h.byUser.get("u")[0].avatar, "https://zalo.example/g.jpg");
});

test("metadata cannot create unseen groups or edit a different account", async () => {
  const h = harness(), d = h.make();
  d.discoverUserGroup("a", { threadId: "g" });
  assert.equal(d.applyUserGroupMetadata("b", "g", { name: "Other user group" }), null);
  assert.equal((await d.getUserGroups("b")).length, 0);
  assert.equal(h.writes(), 1);
});
