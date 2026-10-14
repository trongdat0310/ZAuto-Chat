import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
const folder = fs.mkdtempSync(path.join(os.tmpdir(), "zauto-subscriptions-"));
process.env.SUBSCRIPTIONS_DATA_FILE = path.join(folder, "subscriptions.json");
const { listPlans, assignPlan, getUsageStatus, consumeUsage, revokePlan } = await import("./subscription-service.js");
test("seven subscription plans", () => assert.equal(listPlans().length, 7));
test("screen quota, duplicate acceptance and revoke", () => {
  const userId = "quota-test-user";
  const now = new Date("2026-10-14T04:00:00.000Z");
  assignPlan({ userId, planId: "daily15", actorId: "admin", now });
  assert.equal(getUsageStatus(userId, "trip_screen_accept", now).remaining, 15);
  assert.equal(consumeUsage(userId, "trip_screen_accept", "trip-1", now).remaining, 14);
  assert.equal(consumeUsage(userId, "trip_screen_accept", "trip-1", now).duplicate, true);
  assert.equal(getUsageStatus(userId, "trip_screen_accept", now).remaining, 14);
  assert.equal(getUsageStatus(userId, "chat_accept", now).remaining, 15);
  revokePlan({ userId, actorId: "admin", now });
  assert.equal(getUsageStatus(userId, "trip_screen_accept", now).allowed, false);
});
test("daily quota resets on next Vietnam day", () => {
  const userId = "day-test-user";
  const day1 = new Date("2026-10-14T04:00:00.000Z");
  assignPlan({ userId, planId: "daily15", actorId: "admin", now: day1 });
  consumeUsage(userId, "trip_screen_accept", "trip-1", day1);
  assert.equal(getUsageStatus(userId, "trip_screen_accept", new Date("2026-10-15T04:00:00.000Z")).remaining, 15);
});
