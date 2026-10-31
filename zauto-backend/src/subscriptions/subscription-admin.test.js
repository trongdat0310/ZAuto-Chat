import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createSubscriptionService } from "./subscription-service.js";
import { createSubscriptionAdmin } from "./subscription-admin-core.js";
import { isSubscriptionAdmin } from "./admin-policy.js";

function fixture(t, time = "2026-01-30T18:00:00Z") {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zauto-admin-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const file = path.join(dir, "subscriptions.json");
  let now = new Date(time);
  const store = createSubscriptionService({ file, clock: () => now });
  const users = [ { id: "user", name: "Dat", phone: "0911111111", passwordHash: "secret" },
    { id: "other", name: "Khach", phone: "0900000000", passwordHash: "hidden" } ];
  const admin = createSubscriptionAdmin({ store, findUser: id => users.find(u => u.id === id), listUsers: () => users,
    isAdmin: actor => actor?.id === "admin" });
  let sequence = 0;
  return { store, admin, users, file, setTime: value => { now = new Date(value); },
    assign: (planId = "daily15", months = 1) => store.assignPlan({ userId: "user", actorId: "admin", planId, months }),
    command: (action, extra = {}, id = "user") => admin.execute({ id: "admin" }, id, action,
      { requestId: `request-${++sequence}`, expectedRevision: store.getSubscription(id).revision, ...extra }) };
}
const usage = f => f.store.getUsageStatus("user", "trip_screen_accept");
const spend = (f, id) => f.store.consumeUsage("user", "trip_screen_accept", id);

test("active renewal keeps subscription identity and spent quota", t => {
  const f = fixture(t); const initial = f.assign(); spend(f, "trip");
  const renewed = f.command("renew", { months: 1 });
  assert.equal(renewed.id, initial.id);
  assert.equal(renewed.startsAt, initial.startsAt);
  assert.equal(renewed.endsAt, "2026-03-28T16:59:59.999Z");
  assert.equal(usage(f).remaining, 14);
});
test("monthly renewal keeps current bucket then resets on anniversary", t => {
  const f = fixture(t); f.assign("monthly30"); spend(f, "trip"); f.command("renew", { months: 2 });
  assert.equal(usage(f).remaining, 29);
  f.setTime("2026-02-27T18:00:00Z"); assert.equal(usage(f).remaining, 30);
});
test("renewal cannot refill an exhausted current daily bucket", t => {
  const f = fixture(t); f.assign(); for (let i = 0; i < 15; i++) spend(f, `t-${i}`);
  f.command("renew"); assert.equal(usage(f).allowed, false);
});
test("expired renewal starts now, keeps dedupe, never revives add-ons", t => {
  const f = fixture(t); const original = f.assign(); f.assign("extra10"); spend(f, "same");
  f.setTime("2026-03-10T02:00:00Z"); const renewed = f.command("renew");
  assert.notEqual(renewed.id, original.id);
  assert.equal(renewed.startsAt, "2026-03-10T02:00:00.000Z");
  assert.equal(f.store.getSubscription("user").addons.length, 0);
  assert.equal(spend(f, "same").duplicate, true);
});
test("renew without a plan or after revoke rejects", t => {
  const f = fixture(t);
  assert.throws(() => f.command("renew"), { code: "PLAN_REQUIRED" });
  f.assign(); f.command("revoke"); assert.throws(() => f.command("renew"), { code: "PLAN_REQUIRED" });
});
for (const months of [0, -1, 25, "1", 1.5, null]) test(`reject renewal duration ${JSON.stringify(months)}`, t => {
  const f = fixture(t); f.assign();
  // Direct store deliberately rejects null; API null uses default one month.
  assert.throws(() => f.store.renewPlan({ userId: "user", actorId: "admin", months }), { code: "INVALID_DURATION" });
});
test("lost renewal response retry returns original item and one audit log", t => {
  const f = fixture(t); f.assign();
  const body = { requestId: "same-request", expectedRevision: f.store.getSubscription("user").revision, months: 3 };
  const first = f.admin.execute({ id: "admin" }, "user", "renew", body);
  const second = f.admin.execute({ id: "admin" }, "user", "renew", body);
  assert.deepEqual(second, first); assert.equal(f.store.getAuditLogs().filter(l => l.action === "renew").length, 1);
});
test("idempotency survives restart and does not apply the renewal again", t => {
  const f = fixture(t); f.assign();
  const args = { actorId: "admin", userId: "user", requestId: "after-restart", months: 2,
    expectedRevision: f.store.getSubscription("user").revision };
  const first = f.store.renewPlan(args);
  const reopened = createSubscriptionService({ file: f.file });
  assert.deepEqual(reopened.renewPlan(args), first);
});
test("double add-on request does not allocate double credits", t => {
  const f = fixture(t); f.assign();
  const body = { requestId: "addon-request", expectedRevision: f.store.getSubscription("user").revision, planId: "extra10" };
  f.admin.execute({ id: "admin" }, "user", "assign", body); f.admin.execute({ id: "admin" }, "user", "assign", body);
  assert.equal(usage(f).limit, 25); assert.equal(f.store.getSubscription("user").addons.length, 1);
});
test("same request ID with a changed body is rejected", t => {
  const f = fixture(t); f.assign();
  const body = { requestId: "request-conflict", expectedRevision: f.store.getSubscription("user").revision, months: 1 };
  f.admin.execute({ id: "admin" }, "user", "renew", body);
  assert.throws(() => f.admin.execute({ id: "admin" }, "user", "renew", { ...body, months: 2 }), { code: "REQUEST_ID_CONFLICT" });
});
test("same request ID cannot be recycled across target users", t => {
  const f = fixture(t); const body = { requestId: "request-cross-user", expectedRevision: f.store.getSubscription("user").revision, planId: "daily15" };
  f.admin.execute({ id: "admin" }, "user", "assign", body);
  assert.throws(() => f.admin.execute({ id: "admin" }, "other", "assign", body), { code: "REQUEST_ID_CONFLICT" });
});
test("stale administrative snapshot cannot overwrite a more recent assignment", t => {
  const f = fixture(t); f.assign(); const old = f.store.getSubscription("user").revision;
  f.command("renew");
  assert.throws(() => f.command("assign", { planId: "daily55", expectedRevision: old }), { code: "SUBSCRIPTION_CHANGED" });
  assert.equal(usage(f).limit, 15);
});
test("ordinary usage does not invalidate an administrative snapshot", t => {
  const f = fixture(t); f.assign(); const old = f.store.getSubscription("user").revision;
  spend(f, "a"); assert.equal(f.store.getSubscription("user").revision, old);
  assert.doesNotThrow(() => f.command("renew", { expectedRevision: old }));
});
test("revoke is idempotent and retains history", t => {
  const f = fixture(t); f.assign(); spend(f, "accepted");
  const body = { requestId: "request-revoke", expectedRevision: f.store.getSubscription("user").revision };
  f.admin.execute({ id: "admin" }, "user", "revoke", body); f.admin.execute({ id: "admin" }, "user", "revoke", body);
  assert.equal(usage(f).allowed, false); assert.equal(spend(f, "accepted").duplicate, true);
  assert.equal(f.store.getAuditLogs().filter(l => l.action === "revoke").length, 1);
});
test("successful reconciliation retry spends exactly once", t => {
  const f = fixture(t); f.assign(); const { operation } = f.store.reserveUsage("user", "chat_accept", "uncertain");
  f.store.transition("user", operation, "uncertain");
  const body = { requestId: "request-resolve", expectedRevision: f.store.getSubscription("user").revision,
    targetKey: "uncertain", outcome: "succeeded", note: "Verified in Zalo" };
  f.admin.execute({ id: "admin" }, "user", "reconcile", body); f.admin.execute({ id: "admin" }, "user", "reconcile", body);
  assert.equal(f.store.getUsageStatus("user", "chat_accept").used, 1);
});
test("active sending reservations cannot be released by Admin", t => {
  const f = fixture(t); f.assign(); const { operation } = f.store.reserveUsage("user", "chat_accept", "sending");
  f.store.transition("user", operation, "sending");
  assert.throws(() => f.command("reconcile", { targetKey: "sending", outcome: "failed", note: "Still sending" }), { code: "OPERATION_NOT_UNCERTAIN" });
});
test("non-admin cannot read users, details, logs or mutate plans", t => {
  const f = fixture(t); const actor = { id: "user", phone: "0911111111", role: "admin" };
  for (const fn of [() => f.admin.search(actor), () => f.admin.detail(actor, "other"), () => f.admin.logs(actor),
    () => f.admin.execute(actor, "other", "assign", {})]) assert.throws(fn, { code: "ADMIN_REQUIRED" });
});
test("real policy needs immutable configured user ID, not self-declared role/phone", () => {
  assert.equal(isSubscriptionAdmin({ id: "fake", role: "admin", phone: "0911111111" }, {}), false);
  assert.equal(isSubscriptionAdmin({ id: "fake" }, { ADMIN_USER_ID: "real" }), false);
  assert.equal(isSubscriptionAdmin({ id: "real" }, { ADMIN_USER_ID: "real" }), true);
});
test("body actorId and userId cannot redirect audit or mutation", t => {
  const f = fixture(t); f.command("assign", { planId: "daily15", actorId: "evil", userId: "other" });
  assert.equal(f.store.getSubscription("other").main, null);
  assert.equal(f.store.getAuditLogs()[0].actorId, "admin");
});
test("search pagination redacts private fields and is deterministic", t => {
  const f = fixture(t); const one = f.admin.search({ id: "admin" }, { limit: "1" });
  assert.equal(one.users.length, 1); assert.equal(one.total, 2); assert.equal(one.hasMore, true);
  assert.deepEqual(Object.keys(one.users[0]).sort(), ["id", "name", "phone"]);
  assert.notEqual(one.users[0].id, f.admin.search({ id: "admin" }, { offset: "1", limit: "1" }).users[0].id);
});
test("search accepts Vietnamese names without accents and international phone", t => {
  const f = fixture(t); f.users[0].name = "\u0110\u1ea1t";
  assert.equal(f.admin.search({ id: "admin" }, { q: "dat" }).users[0].id, "user");
  assert.equal(f.admin.search({ id: "admin" }, { q: "+84 911 111 111" }).users[0].id, "user");
});
for (const query of [{ offset: "-1" }, { limit: "101" }, { limit: "0" }, { q: {} }, { offset: ["1"] }]) {
  test(`reject malformed search ${JSON.stringify(query)}`, t => {
    const f = fixture(t); assert.throws(() => f.admin.search({ id: "admin" }, query));
  });
}
test("targeted audit filters before limiting and detail redacts hashes", t => {
  const f = fixture(t); f.assign(); f.command("assign", { planId: "daily55" }, "other");
  assert.equal(f.admin.logs({ id: "admin" }, "user").length, 1);
  assert.equal(f.admin.detail({ id: "admin" }, "user").user.passwordHash, undefined);
});
test("malformed command is rejected before any write", t => {
  const f = fixture(t);
  assert.throws(() => f.admin.execute({ id: "admin" }, "user", "assign", { planId: "daily15" }), { code: "INVALID_ADMIN_COMMAND" });
  assert.equal(fs.existsSync(f.file), false);
});
test("missing target never creates orphan subscriptions", t => {
  const f = fixture(t);
  assert.throws(() => f.command("assign", { planId: "daily15" }, "missing"), { code: "USER_NOT_FOUND" });
});
test("mutations for different users stay isolated", t => {
  const f = fixture(t); f.assign(); f.command("assign", { planId: "daily55" }, "other");
  assert.equal(usage(f).limit, 15); assert.equal(f.store.getUsageStatus("other", "chat_accept").limit, 55);
});

test("active renewal ends at 23:59:59 Vietnam time", t => {
  const f = fixture(t, "2026-10-25T15:18:00Z");
  f.assign();
  const renewed = f.command("renew", { months: 1 });
  assert.equal(renewed.endsAt, "2026-12-25T16:59:59.999Z");
});
