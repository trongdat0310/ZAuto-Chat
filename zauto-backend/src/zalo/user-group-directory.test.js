import test from "node:test";
import assert from "node:assert/strict";
import { createUserGroupDirectory, USER_GROUP_CACHE_TTL_MS } from "./user-group-directory.js";

function fixture() {
  let time = 1000, calls = 0, infoCalls = 0;
  const settings = new Map();
  const apis = new Map();
  const apiFor = key => {
    if (!apis.has(key)) {
      apis.set(key, {
        async getAllGroups() {
          calls++;
          return { gridVerMap: { "group-2": {}, "group-1": {} } };
        },
        async getGroupInfo(ids) {
          infoCalls++;
          assert.deepEqual(ids, ["group-2", "group-1"]);
          return { gridInfoMap: {
            "group-1": { name: "A - group", totalMember: 5, avatar: "avatar-1" },
            "group-2": { name: "B - group", totalMember: 31, avt: "avatar-2" },
          } };
        },
      });
    }
    return apis.get(key);
  };
  const directory = createUserGroupDirectory({
    connect: async key => apiFor(key),
    readSettings: key => settings.get(key) || {},
    now: () => time,
    logger: { log() {} },
  });
  return {
    directory, settings, apis, apiFor,
    tick: ms => { time += ms; },
    calls: () => calls, infoCalls: () => infoCalls,
  };
}

test("repeated group API reads reuse metadata for 5 minutes", async () => {
  const f = fixture();
  const first = await f.directory.getUserGroups("user-a");
  assert.equal(first.length, 2);
  assert.deepEqual(first.map(g => g.name), ["A - group", "B - group"]);
  for (let i = 0; i < 30; i++) {
    f.tick(1000);
    assert.equal((await f.directory.getUserGroups("user-a")).length, 2);
  }
  assert.equal(f.calls(), 1);
  assert.equal(f.infoCalls(), 1);
  assert.equal(f.directory.getUserGroupName("user-a", "group-2"), "B - group");
});

test("read-only cached responses still reflect changed notification settings immediately", async () => {
  const f = fixture();
  const first = await f.directory.getUserGroups("user-a");
  assert.equal(first[0].enabled, false);
  f.settings.set("user-a", { "group-1": { enabled: true } });
  const second = await f.directory.getUserGroups("user-a");
  assert.equal(second[0].enabled, true);
  assert.equal(first[0].enabled, false);
  assert.equal(f.calls(), 1);
  second[0].name = "modified locally";
  const third = await f.directory.getUserGroups("user-a");
  assert.equal(third[0].name, "A - group");
});

test("cache expires at five minutes, but explicit refresh bypasses the TTL", async () => {
  const f = fixture();
  await f.directory.getUserGroups("u");
  f.tick(USER_GROUP_CACHE_TTL_MS - 1);
  await f.directory.getUserGroups("u");
  assert.equal(f.calls(), 1);
  await f.directory.getUserGroups("u", { forceRefresh: true });
  assert.equal(f.calls(), 2);
  f.tick(USER_GROUP_CACHE_TTL_MS);
  await f.directory.getUserGroups("u");
  assert.equal(f.calls(), 3);
});

test("caches are isolated per logged-in user", async () => {
  const f = fixture();
  f.settings.set("u-1", { "group-2": { enabled: true } });
  const a = await f.directory.getUserGroups("u-1");
  const b = await f.directory.getUserGroups("u-2");
  assert.equal(f.calls(), 2);
  assert.equal(a[1].enabled, true);
  assert.equal(b[1].enabled, false);
  await f.directory.getUserGroups("u-1");
  assert.equal(f.calls(), 2);
  assert.equal(f.directory.getUserGroupName("u-2", "unknown"), "Unknown Group");
});

test("a new Zalo API connection invalidates the old metadata snapshot", async () => {
  const f = fixture();
  await f.directory.getUserGroups("u");
  f.apis.delete("u");
  await f.directory.getUserGroups("u");
  assert.equal(f.calls(), 2);
  assert.equal(f.infoCalls(), 2);
});

test("concurrent requests to the same account share one Zalo fetch", async () => {
  let calls = 0, release;
  const gate = new Promise(resolve => { release = resolve; });
  const api = {
    async getAllGroups() { calls++; await gate; return { gridVerMap: { 9: {} } }; },
    async getGroupInfo() { return { gridInfoMap: { 9: { name: "Test" } } }; },
  };
  const dir = createUserGroupDirectory({
    connect: async () => api, readSettings: () => ({}), logger: { log() {} },
  });
  const a = dir.getUserGroups("user");
  const b = dir.getUserGroups("user");
  await Promise.resolve();
  await Promise.resolve();
  release();
  assert.deepEqual(await a, await b);
  assert.equal(calls, 1);
});

test("failed Zalo refresh is not cached and can be retried", async () => {
  let calls = 0;
  const api = {
    async getAllGroups() {
      calls++;
      if (calls === 1) throw new Error("Zalo temporarily unavailable");
      return { gridVerMap: { ok: {} } };
    },
    async getGroupInfo() { return { gridInfoMap: { ok: { name: "OK" } } }; },
  };
  const dir = createUserGroupDirectory({
    connect: async () => api, readSettings: () => ({}), logger: { log() {} },
  });
  await assert.rejects(dir.getUserGroups("u"), /temporarily unavailable/);
  assert.equal(dir.getUserGroupName("u", "ok"), "Unknown Group");
  assert.equal((await dir.getUserGroups("u")).length, 1);
  assert.equal(calls, 2);
});

test("empty group lists are cached and can be refreshed", async () => {
  let calls = 0;
  const api = { async getAllGroups() { calls++; return { gridVerMap: {} }; } };
  const dir = createUserGroupDirectory({
    connect: async () => api, readSettings: () => ({}), logger: { log() {} },
  });
  assert.deepEqual(await dir.getUserGroups("u"), []);
  assert.deepEqual(await dir.getUserGroups("u"), []);
  assert.equal(calls, 1);
  assert.deepEqual(await dir.getUserGroups("u", { forceRefresh: true }), []);
  assert.equal(calls, 2);
});

test("explicit invalidation removes group name and requires a fresh fetch", async () => {
  const f = fixture();
  await f.directory.getUserGroups("u");
  f.directory.clearUserGroupCache("u");
  assert.equal(f.directory.getUserGroupName("u", "group-1"), "Unknown Group");
  await f.directory.getUserGroups("u");
  assert.equal(f.calls(), 2);
});

test("an in-flight old connection cannot overwrite the refreshed new connection", async () => {
  let releaseOld;
  const oldGate = new Promise(resolve => { releaseOld = resolve; });
  const old = {
    async getAllGroups() { await oldGate; return { gridVerMap: { old: {} } }; },
    async getGroupInfo() { return { gridInfoMap: { old: { name: "Old" } } }; },
  };
  const fresh = {
    async getAllGroups() { return { gridVerMap: { fresh: {} } }; },
    async getGroupInfo() { return { gridInfoMap: { fresh: { name: "Fresh" } } }; },
  };
  let connected = old;
  const dir = createUserGroupDirectory({
    connect: async () => connected, readSettings: () => ({}), logger: { log() {} },
  });
  const staleRequest = dir.getUserGroups("u");
  await Promise.resolve();
  await Promise.resolve();
  connected = fresh;
  const freshGroups = await dir.getUserGroups("u");
  assert.equal(freshGroups[0].name, "Fresh");
  releaseOld();
  await staleRequest;
  assert.equal(dir.getUserGroupName("u", "fresh"), "Fresh");
  assert.equal((await dir.getUserGroups("u"))[0].name, "Fresh");
});
