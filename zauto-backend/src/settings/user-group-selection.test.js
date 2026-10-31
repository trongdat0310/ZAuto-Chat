import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { setUserGroupsEnabled, isUserGroupEnabled, readUserGroupSettings, setUserGroupEnabled } from "../zalo/user-group-settings.js";

function fixture(t) {
  const userId = `test-select-groups-${process.pid}-${t.name.replace(/\W/g, "-")}`;
  const folder = new URL(`../../data/user-data/${userId}/`, import.meta.url);
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  return { userId, folder };
}

test("select all enables groups in cache and persisted settings while preserving existing entries", t => {
  const { userId, folder } = fixture(t);
  setUserGroupEnabled(userId, "first", false);
  setUserGroupEnabled(userId, "unrelated", false);
  readUserGroupSettings(userId).first.customSetting = "keep";
  const result = setUserGroupsEnabled(userId, ["first", "second"]);
  assert.deepEqual(result, [
    { groupId: "first", enabled: true },
    { groupId: "second", enabled: true },
  ]);
  assert.equal(isUserGroupEnabled(userId, "first"), true);
  assert.equal(isUserGroupEnabled(userId, "second"), true);
  assert.equal(isUserGroupEnabled(userId, "unrelated"), false);
  const saved = JSON.parse(fs.readFileSync(new URL("group-settings.json", folder), "utf8"));
  assert.equal(saved.first.enabled, true);
  assert.equal(saved.second.enabled, true);
  assert.equal(saved.first.customSetting, "keep");
  assert.equal(saved.unrelated.enabled, false);
});

test("select all normalizes duplicate IDs and remains scoped to the account", t => {
  const { userId } = fixture(t);
  const result = setUserGroupsEnabled(userId, [" a ", "a", "", null, "b"]);
  assert.deepEqual(result.map(item => item.groupId), ["a", "b"]);
  assert.equal(isUserGroupEnabled(`${userId}-other`, "a"), false);
});

test("select all with no groups makes no file and no settings changes", t => {
  const { userId, folder } = fixture(t);
  assert.deepEqual(setUserGroupsEnabled(userId, []), []);
  assert.equal(fs.existsSync(folder), false);
});

test("turning all groups off persists disabled state while preserving other settings", t => {
  const { userId, folder } = fixture(t);
  setUserGroupsEnabled(userId, ["first", "second", "unrelated"], true);
  const result = setUserGroupsEnabled(userId, ["first", "second"], false);
  assert.deepEqual(result, [
    { groupId: "first", enabled: false },
    { groupId: "second", enabled: false },
  ]);
  assert.equal(isUserGroupEnabled(userId, "first"), false);
  assert.equal(isUserGroupEnabled(userId, "second"), false);
  assert.equal(isUserGroupEnabled(userId, "unrelated"), true);
  const saved = JSON.parse(fs.readFileSync(new URL("group-settings.json", folder), "utf8"));
  assert.equal(saved.first.enabled, false);
  assert.equal(saved.second.enabled, false);
});

test("turning groups back on after bulk disable restores all selected groups", t => {
  const { userId } = fixture(t);
  setUserGroupsEnabled(userId, ["first", "second"], false);
  setUserGroupsEnabled(userId, ["first", "second"], true);
  assert.equal(isUserGroupEnabled(userId, "first"), true);
  assert.equal(isUserGroupEnabled(userId, "second"), true);
});
