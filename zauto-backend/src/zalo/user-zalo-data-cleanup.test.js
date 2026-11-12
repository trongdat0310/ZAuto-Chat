import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { purgeUserZaloFiles, ZALO_DATA_ENTRIES } from "./user-zalo-data-cleanup.js";

function fixture(t) {
  const rootDir = fs.mkdtempSync(path.join(os.tmpdir(), "zauto-unlink-test-"));
  t.after(() => fs.rmSync(rootDir, { recursive: true, force: true }));
  return rootDir;
}

function write(root, userId, filename, data = "secret") {
  const file = path.join(root, userId, filename);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, data);
}

test("unlink removes only Zalo-derived files of one user", t => {
  const rootDir = fixture(t);
  const userId = "user-a";
  for (const filename of ZALO_DATA_ENTRIES) {
    if (filename === "conversations") {
      write(rootDir, userId, "conversations/index.json");
      write(rootDir, userId, "conversations/messages/group.json");
    } else write(rootDir, userId, filename);
  }
  write(rootDir, "user-b", "zalo-session.enc.json", "keep-other");
  write(rootDir, "user-b", "messages.json", "keep-other");
  write(rootDir, userId, "devices.json", "keep-device-tokens");
  write(rootDir, userId, "custom-app-settings.json", "keep-custom");

  const result = purgeUserZaloFiles(userId, { rootDir });
  for (const entry of ZALO_DATA_ENTRIES) {
    assert.equal(fs.existsSync(path.join(rootDir, userId, entry)), false, entry);
    assert.ok(result.deleted.includes(entry));
  }
  assert.equal(fs.readFileSync(path.join(rootDir, userId, "devices.json"), "utf8"), "keep-device-tokens");
  assert.equal(fs.readFileSync(path.join(rootDir, userId, "custom-app-settings.json"), "utf8"), "keep-custom");
  assert.equal(fs.readFileSync(path.join(rootDir, "user-b", "messages.json"), "utf8"), "keep-other");
  assert.equal(fs.readFileSync(path.join(rootDir, "user-b", "zalo-session.enc.json"), "utf8"), "keep-other");
  assert.deepEqual(result.preserved.sort(), ["custom-app-settings.json", "devices.json"]);
});

test("cleanup removes leftover temporary JSON snapshots", t => {
  const rootDir = fixture(t), userId = "user-a";
  write(rootDir, userId, "messages.json.tmp-101-abc");
  write(rootDir, userId, "filter-settings.json.tmp-101-abc");
  write(rootDir, userId, "filter-keywords.json.tmp-101-abc");
  write(rootDir, userId, "devices.json.tmp-keep", "keep");
  purgeUserZaloFiles(userId, { rootDir });
  assert.equal(fs.readdirSync(path.join(rootDir, userId)).join(), "devices.json.tmp-keep");
});

test("cleanup can be retried and never creates a missing user folder", t => {
  const rootDir = fixture(t);
  assert.deepEqual(purgeUserZaloFiles("not-existing", { rootDir }),
    { deleted: [], preserved: [] });
  assert.equal(fs.existsSync(path.join(rootDir, "not-existing")), false);
  write(rootDir, "existing", "messages.json");
  purgeUserZaloFiles("existing", { rootDir });
  assert.deepEqual(purgeUserZaloFiles("existing", { rootDir }), {
    deleted: [], preserved: [],
  });
});

test("rejects path traversal without touching files outside the user folder", t => {
  const rootDir = fixture(t);
  const outside = path.join(rootDir, "outside.json");
  fs.writeFileSync(outside, "untouched");
  for (const userId of ["../", "..", ".", "/tmp", "user/../outside", ""]) {
    assert.throws(() => purgeUserZaloFiles(userId, { rootDir }), /Invalid user ID/);
  }
  assert.equal(fs.readFileSync(outside, "utf8"), "untouched");
});

test("refuses symlinked account directories", t => {
  const rootDir = fixture(t);
  const other = path.join(rootDir, "real-data");
  fs.mkdirSync(other);
  fs.writeFileSync(path.join(other, "messages.json"), "must not delete");
  fs.symlinkSync(other, path.join(rootDir, "symlink-user"), "dir");
  assert.throws(() => purgeUserZaloFiles("symlink-user", { rootDir }), /Unsafe user data directory/);
  assert.equal(fs.readFileSync(path.join(other, "messages.json"), "utf8"), "must not delete");
});
