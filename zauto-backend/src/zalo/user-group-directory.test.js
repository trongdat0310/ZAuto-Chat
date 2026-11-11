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
    { groupId: "g-1", name: "Hà Nội", avatar: null, totalMember: 0, enabled: false },
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
