import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { assessPaymentTime } from "./payment-time.js";
import { createPaymentOperations } from "./payment-store.js";
import { sha256, transactionFingerprint, verifySePaySignature } from "./payment-security.js";

// Synthetic data only; these tests never connect to a bank or modify local user data.
const ACCOUNT = "0123456789";
const ORDER = "ZCA012345678901234567";
const CREATED = "2026-10-31T15:20:04.298Z";
const RECEIVED = "2026-10-31T15:20:33.414Z";
const NOW = "2026-10-31T15:55:00Z";
function sample() {
  return {
    tx: { gateway: "VPBank", transactionDate: "2026-10-31 22:20:00",
      content: "PAY " + ORDER, code: "ZCA0", referenceCode: "TEST-MINUTE-REF" },
    order: { id: ORDER, gateway: "VPBank", createdAt: CREATED, expiresAt: "2026-10-31T15:50:04.298Z" },
    now: new Date(NOW), options: { allowVpbankMinuteTime: true, receivedAt: RECEIVED },
  };
}
function assess(s) { return assessPaymentTime(s.tx, s.order, s.now, s.options); }
test("4.298 seconds before order remains rejected by default", () => {
  const s = sample(), result = assessPaymentTime(s.tx, s.order, s.now);
  assert.equal(result.allowed, false); assert.equal(result.beforeOrderByMs, 4298);
  assert.equal(result.policy, "exact"); assert.equal(result.toleranceApplied, false);
});
test("explicit same-minute interpretation is bounded and leaves timestamps unchanged", () => {
  const s = sample(), before = structuredClone(s), result = assess(s);
  assert.equal(result.allowed, true); assert.equal(result.toleranceApplied, true);
  assert.equal(result.sameMinuteCandidate, true); assert.deepEqual(s, before);
});
for (const [name, mutate] of [
  ["previous minute", s => { s.tx.transactionDate = "2026-10-31 22:19:00"; }],
  ["previous minute last second", s => { s.tx.transactionDate = "2026-10-31 22:19:59"; }],
  ["nonzero early seconds", s => { s.tx.transactionDate = "2026-10-31 22:20:01"; }],
  ["wrong transaction bank", s => { s.tx.gateway = "Vietcombank"; }],
  ["wrong order bank", s => { s.order.gateway = "Vietcombank"; }],
  ["missing original full code", s => { s.tx.content = "PAY ZCA0"; }],
  ["multiple full codes", s => { s.tx.content += " ZCA012345678901234568"; }],
  ["missing bank reference", s => { s.tx.referenceCode = " "; }],
  ["missing receipt timestamp", s => { delete s.options.receivedAt; }],
  ["receipt predating order", s => { s.options.receivedAt = "2026-10-31T15:20:03Z"; }],
  ["receipt in future", s => { s.options.receivedAt = "2026-10-31T16:00:00Z"; }],
  ["order in future", s => { s.now = new Date("2026-10-31T15:19:00Z"); }],
  ["transfer after deadline", s => { s.tx.transactionDate = "2026-10-31 22:51:00"; }],
  ["transfer over five minutes in future", s => { s.tx.transactionDate = "2026-10-31 22:40:00"; s.now = new Date("2026-10-31T15:30:00Z"); }],
]) test("minute option does not allow " + name, () => {
  const s = sample(); mutate(s); assert.equal(assess(s).allowed, false);
});
test("same-minute tolerance ends at 59.999 seconds, not a rolling minute", () => {
  const s = sample(); s.order.createdAt = "2026-10-31T15:20:59.999Z";
  s.options.receivedAt = "2026-10-31T15:21:01Z";
  assert.equal(assess(s).allowed, true);
  s.order.createdAt = "2026-10-31T15:21:00Z";
  assert.equal(assess(s).allowed, false);
});
test("invalid time option is rejected instead of coerced", () => {
  const s = sample(); s.options.allowVpbankMinuteTime = "true";
  assert.throws(() => assess(s), { code: "INVALID_TIME_REVIEW" });
});
test("invalid order time fails closed", () => {
  const s = sample(); s.order.expiresAt = "invalid";
  assert.throws(() => assess(s), { code: "INVALID_ORDER_TIME" });
});
test("a normal timely transaction needs no exception even if delivered late", () => {
  const s = sample(); s.tx.transactionDate = "2026-10-31 22:20:10";
  const result = assessPaymentTime(s.tx, s.order, s.now);
  assert.equal(result.allowed, true); assert.equal(result.toleranceApplied, false);
});

const dateVN = date => new Date(+date + 7 * 3600000).toISOString().slice(0, 10);
const endOfDayVN = date => new Date(Date.parse(dateVN(date) + "T00:00:00+07:00") + 86400000 - 1);
function monthAfterVN(date, months) {
  const d = new Date(+date + 7 * 3600000), day = d.getUTCDate();
  d.setUTCDate(1); d.setUTCMonth(d.getUTCMonth() + months);
  const last = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(day, last)); return new Date(+d - 7 * 3600000);
}
function fixture() {
  let data = { version: 2, subscriptions: {}, usage: {}, operations: {}, logs: [] };
  let now = new Date(CREATED), exists = true, failedWrite = false, writes = 0;
  const plans = [{ id: "monthly30", period: "month", addon: false },
    { id: "daily15", period: "day", addon: false }, { id: "extra10", period: "day", addon: true }];
  const store = createPaymentOperations({ read: () => structuredClone(data),
    change: fn => { const next = structuredClone(data), result = fn(next);
      if (failedWrite) throw Object.assign(Error("test disk failure"), { code: "EIO" });
      data = next; writes++; return result; },
    planById: id => plans.find(p => p.id === id), clock: () => now,
    validate: id => assert.match(id, /^[a-z0-9_-]+$/i),
    isActive: (p, date) => p && Date.parse(p.startsAt) <= +date && +date <= Date.parse(p.endsAt),
    dateVN, endOfDayVN, monthAfterVN,
    renewMain: (main, months) => ({ ...main, endsAt: endOfDayVN(monthAfterVN(new Date(main.endsAt), months)).toISOString() }),
  });
  const order = store.createPaymentOrder({ userId: "target", planId: "monthly30", amount: 139000, accountNumber: ACCOUNT });
  const tx = { id: 123456789, gateway: "VPBank", accountNumber: ACCOUNT, subAccount: "",
    transactionDate: "2026-10-31 22:20:00", content: "PAY " + order.id, code: order.id.slice(0, 4),
    referenceCode: "TEST-MINUTE-REF", transferType: "in", transferAmount: 139000 };
  const key = "sepay:" + tx.id;
  const refKey = sha256(JSON.stringify(["VPBank", ACCOUNT, "in", tx.referenceCode]));
  data.paymentTransactions = { [key]: { transactionId: String(tx.id), status: "review", reason: "MISSING_OR_AMBIGUOUS_CODE",
    orderId: null, receivedAt: RECEIVED, payload: structuredClone(tx), rawBody: JSON.stringify(tx), fingerprint: transactionFingerprint(tx) } };
  data.paymentReferences = { [refKey]: key };
  now = new Date(NOW);
  const opts = { transactionId: String(tx.id), accountNumber: ACCOUNT, userExists: id => exists && id === "target" };
  const preview = extra => store.previewPaymentReview({ ...opts, allowVpbankMinuteTime: true, ...extra });
  const approvalArgs = () => ({ ...opts, allowVpbankMinuteTime: true, actorId: "admin", expectedOrderId: order.id,
    approval: preview().approval, bankReference: tx.referenceCode, bankVerified: true, notPreviouslyCredited: true,
    note: "Synthetic test: bank minute precision checked, not previously credited or refunded" });
  const apply = extra => store.reconcilePaymentReview({ ...approvalArgs(), ...extra });
  const patch = updates => { const r = data.paymentTransactions[key]; Object.assign(r.payload, updates);
    r.rawBody = JSON.stringify(r.payload); r.fingerprint = transactionFingerprint(r.payload); };
  return { store, tx, order, key, refKey, opts, preview, approvalArgs, apply, patch,
    data: () => data, writes: () => writes, fail: value => { failedWrite = value; },
    setExists: value => { exists = value; }, setNow: value => { now = new Date(value); } };
}
test("default reconciliation stays blocked and all previews remain read-only", () => {
  const f = fixture(), before = structuredClone(f.data()), writes = f.writes();
  assert.equal(f.store.previewPaymentReview(f.opts).reason, "TRANSFER_OUTSIDE_WINDOW");
  const result = f.preview(); assert.equal(result.eligible, true);
  assert.equal(result.timeCheck.beforeOrderByMs, 4298); assert.equal(result.timeCheck.toleranceApplied, true);
  assert.deepEqual(f.data(), before); assert.equal(f.writes(), writes);
});
test("apply records audit while retaining original bank evidence and receipt time", () => {
  const f = fixture(), before = structuredClone(f.data().paymentTransactions[f.key]);
  assert.equal(f.apply().status, "paid"); const after = f.data().paymentTransactions[f.key];
  for (const field of ["rawBody", "payload", "fingerprint", "receivedAt"]) assert.deepEqual(after[field], before[field]);
  assert.equal(after.reconciliation.timeCheck.toleranceApplied, true);
  assert.equal(f.data().logs.find(l => l.action === "payment_review_reconciled").timeCheck.policy, "vpbank_same_minute_review");
  assert.equal(f.store.getPaymentOrder(f.order.id).status, "paid");
  assert.equal(f.data().subscriptions.target.main.endsAt, "2026-11-30T16:59:59.999Z");
});
test("repeated apply and ordinary webhook replay cannot grant twice", () => {
  const f = fixture(), args = f.approvalArgs(); f.store.reconcilePaymentReview(args);
  const before = structuredClone(f.data());
  assert.equal(f.store.reconcilePaymentReview(args).duplicate, true);
  assert.equal(f.store.confirmPayment({ transaction: f.tx, accountNumber: ACCOUNT }).duplicate, true);
  assert.deepEqual(f.data(), before);
});
for (const [field, value] of [["bankVerified", false], ["notPreviouslyCredited", false], ["note", "short"], ["approval", undefined]]) {
  test("apply still requires explicit " + field, () => {
    const f = fixture(), before = structuredClone(f.data());
    assert.throws(() => f.apply({ [field]: value }), { code: "RECONCILIATION_APPROVAL_REQUIRED" });
    assert.deepEqual(f.data(), before);
  });
}
test("wrong bank reference confirmation is refused", () => {
  const f = fixture(); assert.throws(() => f.apply({ bankReference: "OTHER" }), { code: "BANK_REFERENCE_MISMATCH" });
});
test("changing mode after preview cannot reuse an approval", () => {
  const f = fixture(); f.patch({ transactionDate: "2026-10-31 22:20:10" });
  const exact = f.preview({ allowVpbankMinuteTime: false }); assert.equal(exact.eligible, true);
  assert.notEqual(f.preview().approval, exact.approval);
  assert.throws(() => f.apply({ approval: exact.approval }), { code: "REVIEW_CHANGED" });
});
test("concurrent store changes invalidate approval", () => {
  const f = fixture(), args = f.approvalArgs(); f.data().logs.push({ action: "other-change" });
  assert.throws(() => f.store.reconcilePaymentReview(args), { code: "REVIEW_CHANGED" });
});
test("failed commit retains review and retry can apply once", () => {
  const f = fixture(), before = structuredClone(f.data()); f.fail(true);
  assert.throws(() => f.apply(), { code: "EIO" }); assert.deepEqual(f.data(), before);
  f.fail(false); assert.equal(f.apply().duplicate, false);
});
for (const [name, patch, reason] of [
  ["wrong amount", { transferAmount: 139001 }, "AMOUNT_MISMATCH"],
  ["wrong account", { accountNumber: "9876543210" }, "WRONG_RECEIVER"],
  ["wrong bank", { gateway: "Vietcombank" }, "WRONG_RECEIVER"],
  ["money out", { transferType: "out" }, "MONEY_OUT"],
  ["earlier minute", { transactionDate: "2026-10-31 22:19:00" }, "TRANSFER_OUTSIDE_WINDOW"],
  ["late transfer", { transactionDate: "2026-10-31 22:51:00" }, "TRANSFER_OUTSIDE_WINDOW"],
]) test("operator review cannot approve " + name, () => {
  const f = fixture(); f.patch(patch); const before = structuredClone(f.data());
  assert.equal(f.preview().reason, reason); assert.deepEqual(f.data(), before);
});
test("changed evidence fails integrity checks", () => {
  const f = fixture(); f.data().paymentTransactions[f.key].payload.transferAmount++;
  assert.equal(f.preview().reason, "RECEIPT_INTEGRITY_MISMATCH");
});
test("deleted target account cannot be granted a plan", () => {
  const f = fixture(); f.setExists(false); assert.equal(f.preview().reason, "ACCOUNT_NOT_FOUND");
});
test("another receipt owning bank reference remains protected", () => {
  const f = fixture(); f.data().paymentReferences[f.refKey] = "sepay:other";
  assert.equal(f.preview().reason, "BANK_REFERENCE_INDEX_CONFLICT");
});
test("existing payment audit blocks another credit", () => {
  const f = fixture(); f.data().logs.push({ action: "payment_assign", orderId: f.order.id });
  assert.equal(f.preview().reason, "PREVIOUS_PAYMENT_CREDIT_FOUND");
});
test("another paid account and its expiry are untouched", () => {
  const f = fixture(); f.data().subscriptions.other = { main: { id: "existing", endsAt: "2026-11-30T16:59:59.999Z" } };
  f.data().paymentTransactions["sepay:previous"] = { status: "paid", orderId: "ZCA000000000000000001", userId: "other" };
  const before = structuredClone(f.data().subscriptions.other);
  f.apply(); assert.deepEqual(f.data().subscriptions.other, before);
  assert.equal(f.data().paymentTransactions["sepay:previous"].status, "paid");
});
test("ordinary confirmation ignores a minute option embedded in bank JSON", () => {
  const f = fixture(); const tx = { ...f.tx, id: 123456790, referenceCode: "TEST-NEW-REF",
    reviewTime: { allowVpbankMinuteTime: true, receivedAt: RECEIVED }, allowVpbankMinuteTime: true };
  const result = f.store.confirmPayment({ transaction: tx, accountNumber: ACCOUNT });
  assert.equal(result.status, "review"); assert.equal(result.reason, "TRANSFER_OUTSIDE_WINDOW");
  assert.equal(f.data().subscriptions.target, undefined);
});
test("ordinary replay of an old review does not trigger reconciliation", () => {
  const f = fixture(); const before = structuredClone(f.data());
  assert.equal(f.store.confirmPayment({ transaction: f.tx, accountNumber: ACCOUNT }).status, "review");
  assert.deepEqual(f.data(), before);
});
test("new time logic does not change HMAC authentication", () => {
  const raw = Buffer.from('{"synthetic":true}'), secret = "only-test-secret-not-for-production-123456", now = Date.parse(NOW);
  const timestamp = String(Math.floor(now / 1000));
  const signature = "sha256=" + crypto.createHmac("sha256", secret).update(timestamp + ".").update(raw).digest("hex");
  const headers = { "x-sepay-timestamp": timestamp, "x-sepay-signature": signature };
  verifySePaySignature(raw, headers, secret, now);
  assert.throws(() => verifySePaySignature(Buffer.from('{}'), headers, secret, now), { code: "INVALID_SIGNATURE" });
  assert.throws(() => verifySePaySignature(raw, headers, secret, now + 301000), { code: "INVALID_SIGNATURE" });
});
