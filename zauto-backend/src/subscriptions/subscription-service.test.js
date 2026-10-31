import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createSubscriptionService, monthAfterVN } from "./subscription-service.js";
import { runMeteredAcceptance } from "./acceptance-runner.js";
import { isSubscriptionAdmin } from "./admin-policy.js";

function fixture(t, time = "2026-10-14T04:00:00Z") {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zauto-subscriptions-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const file = path.join(dir, "subscriptions.json");
  let now = new Date(time);
  const store = createSubscriptionService({ file, clock: () => now });
  const assign = (planId = "daily15", months = 1) => store.assignPlan({ userId: "user", actorId: "admin", planId, months });
  return { store, file, assign, setTime: value => { now = new Date(value); } };
}
const usage = (f, feature = "trip_screen_accept") => f.store.getUsageStatus("user", feature);
const consume = (f, id, feature = "trip_screen_accept") => f.store.consumeUsage("user", feature, id);

test("seven immutable plans", t => {
  const f = fixture(t);
  assert.equal(f.store.listPlans().length, 7);
  assert.throws(() => { f.store.listPlans()[0].limit = 100000; }, TypeError);
});
test("no subscription and expired subscription deny usage", t => {
  const f = fixture(t);
  assert.equal(usage(f).allowed, false);
  f.assign();
  f.setTime("2026-11-14T16:59:59.999Z");
  assert.equal(usage(f).allowed, true);
  f.setTime("2026-11-14T17:00:00Z");
  assert.equal(usage(f).allowed, false);
});
test("daily quota is independently metered for each feature", t => {
  const f = fixture(t); f.assign(); consume(f, "a");
  assert.equal(usage(f).remaining, 14);
  assert.equal(usage(f, "chat_accept").remaining, 15);
  assert.equal(usage(f, "auto_accept").remaining, 15);
});
test("quota exhaustion rejects the sixteenth operation", t => {
  const f = fixture(t); f.assign();
  for (let i = 0; i < 15; i++) consume(f, `trip-${i}`);
  assert.equal(usage(f).remaining, 0);
  assert.throws(() => consume(f, "overflow"), { code: "SUBSCRIPTION_LIMIT_REACHED" });
});
test("completed target is not charged twice, even across feature and midnight", t => {
  const f = fixture(t); f.assign(); consume(f, "same");
  assert.equal(consume(f, "same").duplicate, true);
  f.setTime("2026-10-14T17:00:00Z");
  assert.equal(consume(f, "same", "chat_accept").duplicate, true);
  assert.equal(usage(f, "chat_accept").used, 0);
});
test("new target resets exactly at midnight Vietnam time", t => {
  const f = fixture(t, "2026-10-14T16:59:59Z"); f.assign(); consume(f, "before");
  assert.equal(usage(f).remaining, 14);
  f.setTime("2026-10-14T17:00:00Z");
  assert.equal(usage(f).remaining, 15);
});
test("monthly plan does not reset on a new day", t => {
  const f = fixture(t); f.assign("monthly30"); consume(f, "a");
  f.setTime("2026-10-15T04:00:00Z");
  assert.equal(usage(f).remaining, 29);
});
test("multi-month plan renews its allowance on the monthly anniversary", t => {
  const f = fixture(t); f.assign("monthly30", 3); consume(f, "a");
  f.setTime("2026-11-14T04:00:00Z");
  assert.equal(usage(f).remaining, 30);
});
test("calendar months clamp in Vietnam time, including leap year", () => {
  assert.equal(monthAfterVN(new Date("2026-01-30T18:00:00Z"), 1).toISOString(), "2026-02-27T18:00:00.000Z");
  assert.equal(monthAfterVN(new Date("2024-01-30T18:00:00Z"), 1).toISOString(), "2024-02-28T18:00:00.000Z");
});
test("add-on requires active main plan", t => {
  const f = fixture(t);
  assert.throws(() => f.assign("extra10"), { code: "ACTIVE_PLAN_REQUIRED" });
});
test("expired add-on usage never consumes the monthly main allowance", t => {
  const f = fixture(t); f.assign("monthly30"); f.assign("extra10");
  for (let i = 0; i < 12; i++) consume(f, `extra-${i}`);
  assert.equal(usage(f).remaining, 28);
  f.setTime("2026-10-14T17:00:00Z");
  assert.equal(usage(f).remaining, 28);
  assert.equal(usage(f).used, 2);
});
test("multiple add-ons stack without changing main subscription", t => {
  const f = fixture(t); const main = f.assign(); f.assign("extra10"); f.assign("extra30");
  assert.equal(usage(f).remaining, 55);
  assert.equal(f.store.getSubscription("user").main.id, main.id);
});
test("unlimited uses null instead of Infinity and still deduplicates", t => {
  const f = fixture(t); f.assign("unlimited"); consume(f, "a");
  assert.equal(usage(f).remaining, null);
  assert.equal(consume(f, "a").duplicate, true);
  assert.equal(JSON.parse(JSON.stringify(usage(f))).limit, null);
});
test("reassignment and revoke preserve completed-target history", t => {
  const f = fixture(t); f.assign(); consume(f, "a"); f.assign("daily30");
  assert.equal(consume(f, "a").duplicate, true);
  f.store.revokePlan({ userId: "user", actorId: "admin" });
  assert.equal(usage(f).allowed, false);
  assert.equal(consume(f, "a").duplicate, true);
  assert.equal(f.store.getAuditLogs().length, 3);
});
test("reject unknown feature and prototype-polluting keys", t => {
  const f = fixture(t); f.assign();
  assert.throws(() => usage(f, "anything"), { code: "INVALID_FEATURE" });
  assert.throws(() => f.store.getSubscription("__proto__"), { code: "INVALID_ID" });
  assert.throws(() => f.assign("__proto__"), { code: "INVALID_PLAN" });
});
test("reservation persists across service instances and holds the last slot", t => {
  const f = fixture(t); f.assign();
  for (let i = 0; i < 14; i++) consume(f, `a-${i}`);
  f.store.reserveUsage("user", "chat_accept", "chat-first");
  f.store.reserveUsage("user", "trip_screen_accept", "pending");
  const other = createSubscriptionService({ file: f.file, clock: () => new Date("2026-10-14T04:00:00Z") });
  assert.equal(other.getUsageStatus("user", "trip_screen_accept").remaining, 0);
  assert.equal(usage(f).used, 14);
  assert.equal(usage(f).reserved, 1);
  assert.throws(() => other.reserveUsage("user", "trip_screen_accept", "another"), { code: "SUBSCRIPTION_LIMIT_REACHED" });
});
test("different simultaneous targets cannot both spend the last slot", async t => {
  const f = fixture(t); f.assign();
  for (let i = 0; i < 14; i++) consume(f, `a-${i}`);
  let finish;
  const wait = new Promise(resolve => { finish = resolve; });
  let sends = 0;
  const one = runMeteredAcceptance({ userId: "user", feature: "trip_screen_accept", targetKey: "one", store: f.store,
    perform: async mark => { mark(); sends++; await wait; return { ok: true }; } });
  await assert.rejects(runMeteredAcceptance({ userId: "user", feature: "trip_screen_accept", targetKey: "two", store: f.store,
    perform: async () => { sends++; return {}; } }), { code: "SUBSCRIPTION_LIMIT_REACHED" });
  finish(); await one;
  assert.equal(sends, 1); assert.equal(usage(f).used, 15);
});
test("concurrent repeated target cannot trigger a second send", async t => {
  const f = fixture(t); f.assign();
  let finish;
  const wait = new Promise(resolve => { finish = resolve; });
  const args = { userId: "user", feature: "chat_accept", targetKey: "same", store: f.store };
  const first = runMeteredAcceptance({ ...args, perform: async mark => { mark(); await wait; return { text: "ok" }; } });
  await assert.rejects(runMeteredAcceptance({ ...args, perform: async () => { throw Error("must not send"); } }), { code: "ACCEPT_IN_PROGRESS" });
  finish(); await first;
  const retry = await runMeteredAcceptance({ ...args, perform: async () => { throw Error("must not send"); } });
  assert.equal(retry.alreadyAccepted, true);
  assert.equal(retry.text, "ok");
});
test("failure before external send releases the reservation", async t => {
  const f = fixture(t); f.assign();
  await assert.rejects(runMeteredAcceptance({ userId: "user", feature: "chat_accept", targetKey: "fail", store: f.store,
    perform: async () => { throw Error("not connected"); } }), /not connected/);
  assert.equal(usage(f, "chat_accept").remaining, 15);
  assert.equal(usage(f, "chat_accept").used, 0);
});
test("timeout after send is held for review, not retried or counted as success", async t => {
  const f = fixture(t); f.assign();
  const args = { userId: "user", feature: "chat_accept", targetKey: "timeout", store: f.store };
  await assert.rejects(runMeteredAcceptance({ ...args, perform: async mark => { mark(); throw Error("timeout"); } }), { code: "ACCEPT_OUTCOME_UNKNOWN" });
  assert.equal(usage(f, "chat_accept").used, 0);
  assert.equal(usage(f, "chat_accept").reserved, 1);
  await assert.rejects(runMeteredAcceptance({ ...args, perform: async () => ({}) }), { code: "ACCEPT_OUTCOME_UNKNOWN" });
  f.store.resolveUncertain({ userId: "user", targetKey: "timeout", actorId: "admin", outcome: "failed", note: "Verified not delivered" });
  assert.equal(usage(f, "chat_accept").remaining, 15);
});
test("administrator cannot release a currently sending reservation", t => {
  const f = fixture(t); f.assign();
  const { operation } = f.store.reserveUsage("user", "chat_accept", "running");
  f.store.transition("user", operation, "sending");
  assert.throws(() => f.store.resolveUncertain({ userId: "user", targetKey: "running", actorId: "admin", outcome: "failed", note: "Do not release" }), { code: "OPERATION_NOT_UNCERTAIN" });
});
test("corrupt store fails closed without resetting the counters", t => {
  const f = fixture(t); f.assign(); fs.writeFileSync(f.file, "not json");
  assert.throws(() => usage(f));
  assert.throws(() => f.assign());
  assert.equal(fs.readFileSync(f.file, "utf8"), "not json");
  assert.equal(fs.existsSync(`${f.file}.lock`), false);
});
test("v1 migration preserves count and creates an untouched backup", t => {
  const f = fixture(t); const main = f.assign();
  const legacy = { subscriptions: { user: { main, addons: [] } }, usage: { user: { trip_screen_accept: { "2026-10-14": 7 } } }, logs: [] };
  fs.writeFileSync(f.file, JSON.stringify(legacy));
  assert.equal(usage(f).remaining, 8);
  consume(f, "after-migration");
  assert.equal(usage(f).remaining, 7);
  assert.deepEqual(JSON.parse(fs.readFileSync(`${f.file}.v1.bak`)), legacy);
});
test("admin ID is fail-closed; phone and forged role do not grant access", () => {
  assert.equal(isSubscriptionAdmin({ id: "id", phone: "0911111111", role: "admin" }, {}), false);
  assert.equal(isSubscriptionAdmin({ id: "impostor", phone: "0911111111" }, { ADMIN_USER_ID: "real" }), false);
  assert.equal(isSubscriptionAdmin({ id: "real" }, { ADMIN_USER_ID: "real" }), true);
});
test("process-level lock rejects a competing mutation without overwriting", async t => {
  const f = fixture(t); f.assign();
  fs.writeFileSync(`${f.file}.lock`, "held-by-another-process");
  const module = new URL("./subscription-service.js", import.meta.url).href;
  const script = `import { createSubscriptionService } from ${JSON.stringify(module)};
    const s = createSubscriptionService({ file: ${JSON.stringify(f.file)} });
    try { s.assignPlan({ userId: 'user', actorId: 'admin', planId: 'daily30' }); process.exit(1); }
    catch (e) { process.exit(e.code === 'SUBSCRIPTION_BUSY' ? 0 : 2); }`;
  const child = spawn(process.execPath, ["--input-type=module", "-e", script]);
  const exit = await new Promise((resolve, reject) => { child.on("error", reject); child.on("exit", resolve); });
  assert.equal(exit, 0);
  fs.unlinkSync(`${f.file}.lock`);
  assert.equal(usage(f).limit, 15);
});

test("subscription expires at the end of the anniversary day in Vietnam", t => {
  const f = fixture(t, "2026-10-25T15:18:00Z");
  f.assign("daily15");
  assert.equal(f.store.getSubscription("user").main.endsAt, "2026-11-25T16:59:59.999Z");
  f.setTime("2026-11-25T16:59:59Z");
  assert.equal(usage(f).allowed, true);
  f.setTime("2026-11-25T17:00:00Z");
  assert.equal(usage(f).allowed, false);
});
