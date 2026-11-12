import test from "node:test";
import assert from "node:assert/strict";
import { createActiveGroupMetadataLoader } from "./active-group-metadata-loader.js";

const profile = (id, fields = {}) => ({
  gridInfoMap: { [id]: { groupId: id, name: "Nhóm thật", fullAvt: "https://zalo.example/g.jpg", ...fields } },
});
const make = (options = {}) => createActiveGroupMetadataLoader({
  applyMetadata: options.applyMetadata ?? ((userId, groupId, info) => ({ groupId, name: info.name })),
  logger: { warn() {} },
  ...options,
});

test("queries only one active groupId and extracts exact gridInfoMap entry", async () => {
  const calls = [];
  const api = { getGroupInfo: async id => {
    calls.push(id);
    return profile(id);
  } };
  const actual = await make().load("user", "g1", api);
  assert.deepEqual(calls, ["g1"]);
  assert.deepEqual(actual, { groupId: "g1", name: "Nhóm thật" });
});

test("same user+group requests share one in-flight lookup", async () => {
  let finish;
  let count = 0;
  const api = { getGroupInfo: () => {
    count++;
    return new Promise(resolve => { finish = resolve; });
  } };
  const loader = make();
  const p1 = loader.load("user", "g", api);
  const p2 = loader.load("user", "g", api);
  assert.equal(p1, p2);
  assert.equal(count, 1);
  finish(profile("g"));
  await Promise.all([p1, p2]);
  assert.equal(count, 1);
});

test("successful lookups are cached for an hour and can refresh after TTL", async () => {
  let current = 10000, count = 0;
  const loader = make({ now: () => current, successTtlMs: 3600000 });
  const api = { getGroupInfo: async id => { count++; return profile(id); } };
  await loader.load("u", "g", api);
  await loader.load("u", "g", api);
  assert.equal(count, 1);
  current += 3600001;
  await loader.load("u", "g", api);
  assert.equal(count, 2);
});

test("Zalo error 114 does not reject incoming message processing; retries are delayed", async () => {
  let current = 10000, count = 0, warnings = 0;
  const loader = make({ now: () => current, failureBackoffMs: 300000,
    logger: { warn() { warnings++; } } });
  const api = { getGroupInfo: async () => { count++; throw Object.assign(new Error("Tham số không hợp lệ"), { code: 114 }); } };
  assert.equal(await loader.load("u", "g", api), null);
  assert.equal(await loader.load("u", "g", api), null);
  assert.equal(count, 1);
  assert.equal(warnings, 1);
  current += 300001;
  assert.equal(await loader.load("u", "g", api), null);
  assert.equal(count, 2);
});

test("rejects missing or mismatched group data without corrupting saved metadata", async () => {
  let updates = 0;
  const loader = make({ applyMetadata: () => { updates++; } });
  const api = { getGroupInfo: async () => profile("other") };
  assert.equal(await loader.load("u", "g", api), null);
  assert.equal(updates, 0);
});

test("metadata queue has bounded concurrency", async () => {
  const waiting = [];
  const loader = make({ concurrency: 2 });
  const api = { getGroupInfo: id => new Promise(resolve => {
    waiting.push({ id, resolve });
  }) };
  const p1 = loader.load("u", "g1", api);
  const p2 = loader.load("u", "g2", api);
  const p3 = loader.load("u", "g3", api);
  assert.equal(waiting.length, 2);
  waiting[0].resolve(profile("g1"));
  await p1;
  assert.equal(waiting.length, 3);
  waiting[1].resolve(profile("g2"));
  waiting[2].resolve(profile("g3"));
  await Promise.all([p2, p3]);
});

test("different app accounts never share a cached group ID", async () => {
  let count = 0;
  const loader = make();
  const api = { getGroupInfo: async id => { count++; return profile(id); } };
  await loader.load("user-a", "same", api);
  await loader.load("user-b", "same", api);
  assert.equal(count, 2);
});

test("no Zalo API available does not change discovered data", async () => {
  const loader = make();
  assert.equal(await loader.load("user", "g", null), null);
  assert.equal(await loader.load("user", "", { getGroupInfo() {} }), null);
});

test("in-flight group lookup finishing after unlink cannot restore deleted metadata", async () => {
  let finish, updates = 0;
  const loader = make({ applyMetadata: () => { updates++; } });
  const api = { getGroupInfo: () => new Promise(resolve => { finish = resolve; }) };
  const pending = loader.load("user-a", "group-1", api);
  loader.cancelUser("user-a");
  finish(profile("group-1"));
  assert.equal(await pending, null);
  assert.equal(updates, 0);
});

test("cancel removes account-specific queued lookups but leaves other users untouched", async () => {
  let finish;
  const calls = [];
  const loader = make({ concurrency: 1 });
  const api = { getGroupInfo: id => {
    calls.push(id);
    if (id === "first") return new Promise(resolve => { finish = resolve; });
    return Promise.resolve(profile(id));
  } };
  const running = loader.load("user-a", "first", api);
  const cancelled = loader.load("user-a", "second", api);
  const other = loader.load("user-b", "third", api);
  loader.cancelUser("user-a");
  assert.equal(await cancelled, null);
  finish(profile("first"));
  assert.equal(await running, null);
  assert.ok(await other);
  assert.deepEqual(calls, ["first", "third"]);
});

test("relink can fetch fresh group details after cache cancellation", async () => {
  let count = 0;
  const loader = make();
  const api = { getGroupInfo: async id => {
    count++;
    return profile(id);
  } };
  await loader.load("user-a", "g", api);
  loader.cancelUser("user-a");
  await loader.load("user-a", "g", api);
  assert.equal(count, 2);
});
