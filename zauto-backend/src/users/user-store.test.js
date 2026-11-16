import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { isSessionCurrent } from "../auth/session-version.js";

async function isolatedStore(t, initialUsers = []) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "zchatauto-user-cache-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const moduleDir = path.join(root, "src", "users");
  const dataDir = path.join(root, "data");
  fs.mkdirSync(moduleDir, { recursive: true });
  fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(path.join(root, "package.json"), '{"type":"module"}');
  const file = path.join(dataDir, "users.json");
  fs.writeFileSync(file, JSON.stringify(initialUsers));
  fs.copyFileSync(
    fileURLToPath(new URL("./user-store.js", import.meta.url)),
    path.join(moduleDir, "user-store.js"),
  );
  const store = await import(pathToFileURL(path.join(moduleDir, "user-store.js")).href);
  return { store, file };
}

test("cached lookups are isolated copies, not mutable shared account objects", async (t) => {
  const { store } = await isolatedStore(t, [
    { id: "u1", sessionVersion: "old", profile: { title: "driver" } },
  ]);
  const user = store.findUserById("u1");
  user.sessionVersion = "tampered";
  user.profile.title = "tampered";
  assert.equal(store.findUserById("u1").sessionVersion, "old");
  assert.equal(store.findUserById("u1").profile.title, "driver");
  assert.equal(store.findUserById("missing"), null);
});

test("session rotation and delete invalidate cached WebSocket account view instantly", async (t) => {
  const { store } = await isolatedStore(t, [
    { id: "u1", sessionVersion: "old", name: "Driver" },
  ]);
  assert.equal(isSessionCurrent(store.findUserById("u1"), { sv: "old" }), true);
  const updated = store.updateUser("u1", { sessionVersion: "new" });
  assert.equal(updated.sessionVersion, "new");
  assert.equal(isSessionCurrent(store.findUserById("u1"), { sv: "old" }), false);
  assert.equal(isSessionCurrent(store.findUserById("u1"), { sv: "new" }), true);
  assert.equal(store.deleteUser("u1"), true);
  assert.equal(store.findUserById("u1"), null);
});

test("fresh mutations honor external file edits instead of overwriting them", async (t) => {
  const { store, file } = await isolatedStore(t, [
    { id: "u1", sessionVersion: "v1", name: "Driver" },
  ]);
  assert.equal(store.findUserById("u1").sessionVersion, "v1");
  fs.writeFileSync(file, JSON.stringify([
    { id: "u1", sessionVersion: "v2", name: "Driver" },
  ]));
  const updated = store.updateUser("u1", { name: "Changed" });
  assert.equal(updated.sessionVersion, "v2");
  assert.equal(store.findUserById("u1").sessionVersion, "v2");
  assert.equal(store.findUserById("u1").name, "Changed");
});

test("out-of-process edits are refreshed after bounded cache TTL", async (t) => {
  const { store, file } = await isolatedStore(t, [
    { id: "u1", sessionVersion: "v1" },
  ]);
  assert.equal(store.findUserById("u1").sessionVersion, "v1");
  fs.writeFileSync(file, JSON.stringify([
    { id: "u1", sessionVersion: "v2" },
  ]));
  await new Promise(resolve => setTimeout(resolve, 600));
  assert.equal(store.findUserById("u1").sessionVersion, "v2");
});
