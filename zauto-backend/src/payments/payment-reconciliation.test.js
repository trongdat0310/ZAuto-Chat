import test from "node:test";
import assert from "node:assert/strict";
import { createPaymentOperations } from "./payment-store.js";
import { sha256, transactionFingerprint } from "./payment-security.js";

const ACCOUNT = "0945785631";
const dateVN = date => new Date(+date + 7 * 3600000).toISOString().slice(0, 10);
const endOfDayVN = date => new Date(Date.parse(dateVN(date) + "T00:00:00+07:00") + 86400000 - 1);
function monthAfterVN(date, months) {
  const d = new Date(+date + 7 * 3600000), day = d.getUTCDate();
  d.setUTCDate(1); d.setUTCMonth(d.getUTCMonth() + months);
  const last = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(day, last)); return new Date(+d - 7 * 3600000);
}
const isActive = (main, now) => main && Date.parse(main.startsAt) <= +now && +now <= Date.parse(main.endsAt);
function fixture({ plan = "monthly30", amount = 139000 } = {}) {
  let data = { version: 2, subscriptions: {}, usage: {}, operations: {}, logs: [] };
  let writes = 0, failWrite = false, now = new Date("2026-10-31T15:10:00Z"), exists = true;
  const plans = [
    { id: "monthly30", period: "month", addon: false },
    { id: "daily15", period: "day", addon: false },
    { id: "extra10", period: "day", addon: true },
    { id: "unlimited", period: "day", addon: false },
  ];
  const store = createPaymentOperations({ read: () => structuredClone(data),
    change: fn => { const next = structuredClone(data); const result = fn(next);
      if (failWrite) throw Object.assign(Error("disk write failed"), { code: "EIO" });
      data = next; writes++; return result; },
    clock: () => now, planById: id => plans.find(p => p.id === id), isActive, dateVN, endOfDayVN, monthAfterVN,
    validate: id => { if (typeof id !== "string" || !/^[a-z0-9_-]+$/i.test(id)) throw Error("invalid id"); },
    renewMain: (main, months) => ({ ...main, endsAt: endOfDayVN(monthAfterVN(new Date(main.endsAt), months)).toISOString() }),
  });
  function seed({ txid = 94958835, reference = "FTTEST94958835", target = "user", planId = plan } = {}) {
    const o = store.createPaymentOrder({ userId: target, planId, amount, accountNumber: ACCOUNT });
    const tx = { id: txid, gateway: "VPBank", accountNumber: ACCOUNT,
      transferType: "in", transferAmount: amount, transactionDate: "2026-10-31 22:11:00",
      content: "PAY " + o.id, code: o.id.slice(0, 4), referenceCode: reference, subAccount: "" };
    data.paymentTransactions ||= {};
    data.paymentTransactions["sepay:" + txid] = { transactionId: String(txid), status: "review",
      reason: "MISSING_OR_AMBIGUOUS_CODE", orderId: null, receivedAt: "2026-10-31T15:12:00Z",
      fingerprint: transactionFingerprint(tx), payload: structuredClone(tx), rawBody: JSON.stringify(tx) };
    data.paymentReferences ||= {};
    data.paymentReferences[sha256(JSON.stringify(["VPBank", ACCOUNT, "in", reference]))] = "sepay:" + txid;
    return { o, tx };
  }
  const { o, tx } = seed(); now = new Date("2026-10-31T15:40:00Z");
  const opts = id => ({ transactionId: String(id ?? tx.id), accountNumber: ACCOUNT, userExists: () => exists });
  const preview = extra => store.previewPaymentReview({ ...opts(), ...extra });
  const apply = extra => { const p = preview(); return store.reconcilePaymentReview({ ...opts(),
    expectedOrderId: o.id, actorId: "admin", approval: p.approval, bankReference: tx.referenceCode,
    bankVerified: true, notPreviouslyCredited: true, note: "Bank checked, not previously credited", ...extra }); };
  function patchPayload(patch, id = tx.id) { const r=data.paymentTransactions["sepay:"+id];
    Object.assign(r.payload, patch); r.rawBody=JSON.stringify(r.payload); r.fingerprint=transactionFingerprint(r.payload); }
  return { store, o, tx, seed, opts, preview, apply, patchPayload,
    data: () => data, writes: () => writes, setNow: d => now = new Date(d),
    setExists: b => exists = b, fail: b => failWrite = b };
}

test("preview recognizes complete code, expired checkout but timely bank transfer; writes nothing", () => {
  const f=fixture(), before=structuredClone(f.data()), writes=f.writes(); const p=f.preview();
  assert.equal(p.eligible,true); assert.equal(p.orderId,f.o.id); assert.equal(p.action,"assign");
  assert.equal(p.amount,139000); assert.match(p.approval,/^[a-f0-9]{64}$/);
  assert.deepEqual(f.data(),before); assert.equal(f.writes(),writes);
});
test("apply atomically pays and grants; preserves raw evidence, original receipt time and bank reference", () => {
  const f=fixture(), prior=structuredClone(f.data().paymentTransactions["sepay:"+f.tx.id]);
  const result=f.apply(); assert.equal(result.status,"paid");
  const row=f.data().paymentTransactions["sepay:"+f.tx.id];
  assert.equal(row.receivedAt,prior.receivedAt); assert.equal(row.rawBody,prior.rawBody);
  assert.deepEqual(row.payload,prior.payload); assert.equal(row.reconciliation.previousReason,prior.reason);
  assert.equal(f.store.getPaymentOrder(f.o.id).status,"paid");
  assert.equal(f.data().subscriptions.user.main.planId,"monthly30");
  assert.equal(f.data().logs.filter(l=>l.action==="payment_assign").length,1);
  assert.equal(f.data().logs.filter(l=>l.action==="payment_review_reconciled").length,1);
  assert.equal(Object.keys(f.data().paymentReferences).length,1);
});
test("repeated operator apply and webhook replay never grant twice", () => {
  const f=fixture(), p=f.preview(); const args={...f.opts(),actorId:"admin",expectedOrderId:f.o.id,
    approval:p.approval,bankReference:f.tx.referenceCode,bankVerified:true,notPreviouslyCredited:true,note:"Verified in bank statement"};
  f.store.reconcilePaymentReview(args); const ends=f.data().subscriptions.user.main.endsAt;
  assert.equal(f.store.reconcilePaymentReview(args).duplicate,true);
  assert.equal(f.store.confirmPayment({transaction:f.tx,accountNumber:ACCOUNT}).duplicate,true);
  assert.equal(f.data().subscriptions.user.main.endsAt,ends); assert.equal(f.data().logs.length,2);
});
test("old webhook replay alone remains review and does not implicitly reapprove", () => {
  const f=fixture(); assert.equal(f.store.confirmPayment({transaction:f.tx,accountNumber:ACCOUNT}).status,"review");
  assert.equal(f.data().subscriptions.user,undefined);
});
for (const field of ["bankVerified","notPreviouslyCredited","expectedOrderId","approval","note"]) {
  test("apply requires explicit operator approval: "+field, () => {
    const f=fixture(), before=structuredClone(f.data());
    assert.throws(()=>f.apply({[field]:undefined}),{code:"RECONCILIATION_APPROVAL_REQUIRED"});
    assert.deepEqual(f.data(),before);
  });
}
test("wrong bank reference confirmation blocks application", () => {
  const f=fixture(), before=structuredClone(f.data());
  assert.throws(()=>f.apply({bankReference:"wrong"}),{code:"BANK_REFERENCE_MISMATCH"}); assert.deepEqual(f.data(),before);
});
test("concurrent change after preview invalidates approval", () => {
  const f=fixture(), p=f.preview(); f.data().logs.push({action:"concurrent"});
  const before=structuredClone(f.data());
  assert.throws(()=>f.apply({approval:p.approval}),{code:"REVIEW_CHANGED"}); assert.deepEqual(f.data(),before);
});
test("failed commit keeps receipt review, reference and entitlement unchanged", () => {
  const f=fixture(), before=structuredClone(f.data()); f.fail(true);
  assert.throws(()=>f.apply(),{code:"EIO"}); assert.deepEqual(f.data(),before);
  f.fail(false); assert.equal(f.apply().status,"paid");
});
test("two real payments are two operations, second matching plan extends not resets", () => {
  const f=fixture(); const b=f.seed({txid:94959741,reference:"FTTEST94959741"});
  // New order bank transfer must follow order creation.
  f.patchPayload({transactionDate:"2026-10-31 22:41:00"},b.tx.id); f.setNow("2026-10-31T15:45:00Z");
  const stale=f.store.previewPaymentReview(f.opts(b.tx.id));
  assert.equal(f.apply().action,"assign");
  const mainId=f.data().subscriptions.user.main.id;
  f.data().usage.user={chat_accept:{spent:4}};
  const p=f.store.previewPaymentReview(f.opts(b.tx.id)); assert.equal(p.action,"renew"); assert.notEqual(p.approval,stale.approval);
  const result=f.store.reconcilePaymentReview({...f.opts(b.tx.id),actorId:"admin",expectedOrderId:b.o.id,
    approval:p.approval,bankReference:b.tx.referenceCode,bankVerified:true,notPreviouslyCredited:true,note:"Second genuine payment checked"});
  assert.equal(result.action,"renew"); assert.equal(f.data().subscriptions.user.main.id,mainId);
  assert.deepEqual(f.data().usage.user,{chat_accept:{spent:4}});
});
for(const [label,patch,reason] of [
  ["wrong amount",{transferAmount:139001},"AMOUNT_MISMATCH"],
  ["late transfer",{transactionDate:"2026-10-31 22:50:00"},"TRANSFER_OUTSIDE_WINDOW"],
  ["old transfer",{transactionDate:"2026-10-31 22:09:59"},"TRANSFER_OUTSIDE_WINDOW"],
  ["money out",{transferType:"out"},"MONEY_OUT"],
  ["wrong bank",{gateway:"Vietcombank"},"WRONG_RECEIVER"],
  ["wrong account",{accountNumber:"1234567890"},"WRONG_RECEIVER"],
  ["missing bank reference",{referenceCode:""},"BANK_REFERENCE_REQUIRED"],
]) test(label+" cannot be approved",()=>{
  const f=fixture();f.patchPayload(patch);const before=structuredClone(f.data());
  assert.equal(f.preview().eligible,false);assert.equal(f.preview().reason,reason);assert.deepEqual(f.data(),before);
});
test("unrelated review reasons cannot be overridden",()=>{
  const f=fixture();f.data().paymentTransactions["sepay:"+f.tx.id].reason="AMOUNT_MISMATCH";
  assert.equal(f.preview().reason,"REVIEW_REASON_NOT_SUPPORTED");
});
test("receipt with original payload missing fails closed",()=>{
  const f=fixture();delete f.data().paymentTransactions["sepay:"+f.tx.id].rawBody;
  assert.equal(f.preview().reason,"MISSING_ORIGINAL_PAYLOAD");
});
test("inconsistent raw evidence is not trusted",()=>{
  const f=fixture();f.data().paymentTransactions["sepay:"+f.tx.id].payload.transferAmount=1;
  assert.equal(f.preview().reason,"RECEIPT_INTEGRITY_MISMATCH");
});
test("conflicting payload replay requires manual investigation",()=>{
  const f=fixture();f.data().paymentTransactions["sepay:"+f.tx.id].conflicts=["different"];
  assert.equal(f.preview().reason,"RECEIPT_HAS_CONFLICTS");
});
test("a bank reference owned by another transaction is not cleared",()=>{
  const f=fixture();const key=Object.keys(f.data().paymentReferences)[0];f.data().paymentReferences[key]="sepay:other";
  const before=structuredClone(f.data());assert.equal(f.preview().reason,"BANK_REFERENCE_INDEX_CONFLICT");assert.deepEqual(f.data(),before);
});
test("another paid receipt with the same bank reference blocks a second credit",()=>{
  const f=fixture();f.data().paymentTransactions["sepay:other"]={status:"paid",payload:{...f.tx,id:12345}};
  assert.equal(f.preview().reason,"PREVIOUS_PAYMENT_CREDIT_FOUND");
});
test("previous payment audit for this order blocks hidden double credit",()=>{
  const f=fixture();f.data().logs.push({action:"payment_assign",orderId:f.o.id});
  assert.equal(f.preview().reason,"PREVIOUS_PAYMENT_CREDIT_FOUND");
});
test("wrong expected order is rejected",()=>{
  const f=fixture();assert.equal(f.preview({expectedOrderId:"ZCA000000000000000001"}).reason,"EXPECTED_ORDER_MISMATCH");
});
test("short code without full original memo cannot be guessed",()=>{
  const f=fixture();f.patchPayload({content:f.tx.code});assert.equal(f.preview().reason,"NOT_TRUNCATED_CODE_CASE");
});
test("ambiguous original memo cannot be guessed",()=>{
  const f=fixture();f.patchPayload({content:f.o.id+" ZCA000000000000000001"});assert.equal(f.preview().reason,"NOT_TRUNCATED_CODE_CASE");
});
test("missing user cannot receive subscription",()=>{
  const f=fixture();f.setExists(false);assert.equal(f.preview().reason,"ACCOUNT_NOT_FOUND");
});
test("changed active plan cannot be overwritten",()=>{
  const f=fixture();f.data().subscriptions.user={main:{id:"other",planId:"daily15",startsAt:"2026-10-01T00:00:00Z",endsAt:"2026-12-01T00:00:00Z"},addons:[]};
  assert.equal(f.preview().reason,"ACTIVE_PLAN_CHANGED");
});
test("daily add-on on the next day remains review",()=>{
  const f=fixture({plan:"extra10",amount:20000});f.setNow("2026-10-31T17:00:00Z");
  assert.equal(f.preview().reason,"ADDON_DAY_CHANGED");
});
test("standalone daily add-on works once in same Vietnam day",()=>{
  const f=fixture({plan:"extra10",amount:20000});assert.equal(f.apply().action,"addon");
  assert.equal(f.data().subscriptions.user.main,null);assert.equal(f.data().subscriptions.user.addons.length,1);
});
test("unsupported legacy order cannot be forced",()=>{
  const f=fixture();delete f.data().paymentOrders[f.o.id].version;
  assert.equal(f.preview().reason,"ORDER_CONFIG_CHANGED");
});
