import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { createSubscriptionService } from "../subscriptions/subscription-service.js";
import { paymentConfig } from "./payment-config.js";
import { createPaymentHandlers } from "./payment-handlers.js";
import { createPaymentGateway } from "./payment-gateway.js";
import { verifySePaySignature, validateTransaction, transactionTime, extractOrderCode,
  checkoutToken } from "./payment-security.js";

const SECRET = "unit-test-secret-only-never-use-in-production-123456";
const ACCOUNT = "0945785631";
function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zca-payment-test-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const file = path.join(dir, "subscriptions.json");
  let now = new Date("2026-10-29T15:00:00.000Z"), sequence = 0;
  const env = { SEPAY_BANK_ACCOUNT: ACCOUNT, SEPAY_WEBHOOK_SECRET: SECRET };
  const store = createSubscriptionService({ file, clock: () => now });
  const users = [{ id: "user", phone: "0900000000", name: "Test" }];
  const notices = [];
  const handlers = createPaymentHandlers({ store, env, clock: () => +now,
    findUserByPhone: phone => users.find(u => u.phone === phone), findUserById: id => users.find(u => u.id === id),
    notify: id => notices.push(id), logger: { info() {}, error() {} } });
  return { dir, file, store, handlers, env, users, notices, now: () => now,
    setTime: value => { now = new Date(value); },
    create: (planId = "extra10", extra = {}) => store.createPaymentOrder({ userId: "user", planId,
      amount: paymentConfig(env).prices[planId], accountNumber: ACCOUNT, requestId: "test-request-" + (++sequence).toString().padStart(8, "0"), ...extra }),
    tx: (order, extra = {}) => ({ id: 92704, gateway: "VPBank", transactionDate: new Date(+now + 7 * 3600000).toISOString().slice(0, 19).replace("T", " "),
      accountNumber: ACCOUNT, subAccount: "", code: order.id, content: "Thanh toan " + order.id,
      transferType: "in", transferAmount: order.amount, accumulated: 0, referenceCode: "", ...extra }),
  };
}
function response() {
  return { statusCode: 200, status(code) { this.statusCode = code; return this; }, set() { return this; }, json(body) { this.body = body; return this; } };
}
function signed(raw, now, secret = SECRET) {
  const stamp = String(Math.floor(+now / 1000));
  return { "x-sepay-timestamp": stamp,
    "x-sepay-signature": "sha256=" + crypto.createHmac("sha256", secret).update(stamp + ".").update(raw).digest("hex") };
}
function deliver(f, tx, extra = {}) {
  const raw = Buffer.from(JSON.stringify(tx));
  const res = response();
  f.handlers.webhook({ body: raw, headers: signed(raw, f.now()), ...extra }, res);
  return res;
}
const quota = f => f.store.getUsageStatus("user", "chat_accept");
const ledger = f => JSON.parse(fs.readFileSync(f.file, "utf8"));

test("signed VPBank transfer pays order and activates standalone 10 credits", t => {
  const f = fixture(t); const o = f.create(); const tx = f.tx(o);
  const r = deliver(f, tx);
  assert.equal(r.statusCode, 200); assert.deepEqual(r.body, { success: true });
  assert.equal(f.store.getPaymentOrder(o.id).status, "paid"); assert.equal(quota(f).remaining, 10);
  assert.equal(f.store.getSubscription("user").main, null);
  assert.equal(f.store.getSubscription("user").addons[0].endsAt, "2026-10-29T16:59:59.999Z");
  assert.equal(ledger(f).paymentTransactions["sepay:92704"].rawBody, JSON.stringify(tx));
});
test("same transaction and retry after process restart never grant twice", t => {
  const f = fixture(t), o = f.create(), tx = f.tx(o);
  deliver(f, tx); deliver(f, tx);
  const reopened = createSubscriptionService({ file: f.file, clock: f.now });
  assert.equal(reopened.confirmPayment({ transaction: tx, accountNumber: ACCOUNT }).duplicate, true);
  assert.equal(quota(f).remaining, 10); assert.equal(f.store.getAuditLogs().length, 1);
});
test("a second transaction cannot pay the same order again", t => {
  const f = fixture(t), o = f.create(); deliver(f, f.tx(o)); deliver(f, f.tx(o, { id: 92705 }));
  assert.equal(quota(f).remaining, 10);
  assert.equal(ledger(f).paymentTransactions["sepay:92705"].reason, "ORDER_ALREADY_PAID");
});
test("same bank reference under a different SePay ID is quarantined", t => {
  const f = fixture(t), a = f.create(), b = f.create();
  deliver(f, f.tx(a, { referenceCode: "BANK-ONE" }));
  deliver(f, f.tx(b, { id: 92705, referenceCode: "BANK-ONE" }));
  assert.equal(quota(f).remaining, 10);
  assert.equal(ledger(f).paymentTransactions["sepay:92705"].reason, "DUPLICATE_BANK_REFERENCE");
});
test("modified payload reusing a processed ID cannot mutate entitlements", t => {
  const f = fixture(t), a = f.create(), b = f.create(); deliver(f, f.tx(a)); deliver(f, f.tx(b));
  assert.equal(quota(f).remaining, 10);
  assert.equal(ledger(f).paymentTransactions["sepay:92704"].conflicts.length, 1);
  assert.equal(f.store.getPaymentOrder(b.id).status, "pending");
});
for (const [name, patch, reason] of [
  ["money out", { transferType: "out" }, "MONEY_OUT"],
  ["wrong account", { accountNumber: "1234567890" }, "WRONG_RECEIVER"],
  ["wrong bank", { gateway: "Vietcombank" }, "WRONG_RECEIVER"],
  ["underpayment", { transferAmount: 19999 }, "AMOUNT_MISMATCH"],
  ["overpayment", { transferAmount: 20001 }, "AMOUNT_MISMATCH"],
  ["missing code", { content: "Chuyen tien", code: null }, "MISSING_OR_AMBIGUOUS_CODE"],
  ["unknown code", { content: "ZCA000000000000000001", code: "ZCA000000000000000001" }, "ORDER_NOT_FOUND"],
]) test(name + " does not activate a plan", t => {
  const f = fixture(t), o = f.create(); assert.equal(deliver(f, f.tx(o, patch)).statusCode, 200);
  assert.equal(quota(f).allowed, false); assert.equal(f.store.getPaymentOrder(o.id).status, "pending");
  assert.equal(ledger(f).paymentTransactions["sepay:92704"].reason, reason);
});
test("one transfer containing two order codes is not guessed", t => {
  const f = fixture(t), a = f.create(), b = f.create();
  deliver(f, f.tx(a, { content: a.id + " " + b.id, code: null }));
  assert.equal(quota(f).allowed, false);
});
test("full memo token and provider code must agree, substrings rejected", () => {
  const a = "ZCA012345678901234567", b = "ZCA012345678901234568";
  assert.equal(extractOrderCode({ content: "pay " + a + " done", code: null }), a);
  assert.equal(extractOrderCode({ content: "X" + a, code: null }), null);
  assert.equal(extractOrderCode({ content: a + "X", code: null }), null);
  assert.equal(extractOrderCode({ content: a, code: b }), null);
  assert.equal(extractOrderCode({ content: "bank memo", code: a }), a);
});
test("transfers made after deadline are recorded for review", t => {
  const f = fixture(t), o = f.create(); f.setTime("2026-10-29T15:31:00Z");
  deliver(f, f.tx(o)); assert.equal(quota(f).allowed, false);
  assert.equal(ledger(f).paymentTransactions["sepay:92704"].reason, "TRANSFER_OUTSIDE_WINDOW");
});
test("late webhook for a transfer made inside the payment window is valid", t => {
  const f = fixture(t), o = f.create("daily15"), tx = f.tx(o);
  f.setTime("2026-10-29T17:30:00Z"); deliver(f, tx);
  assert.equal(quota(f).remaining, 15); assert.equal(f.store.getPaymentOrder(o.id).status, "paid");
});
test("late daily add-on delivered on a different Vietnam day is reviewed", t => {
  const f = fixture(t), o = f.create(), tx = f.tx(o);
  f.setTime("2026-10-29T17:00:00Z"); deliver(f, tx);
  assert.equal(quota(f).allowed, false);
  assert.equal(ledger(f).paymentTransactions["sepay:92704"].reason, "ADDON_DAY_CHANGED");
});
test("transfer predating order or far in future cannot pay", t => {
  for (const date of ["2026-10-29 21:59:59", "2026-10-29 22:10:00"]) {
    const f = fixture(t), o = f.create(); deliver(f, f.tx(o, { transactionDate: date }));
    assert.equal(quota(f).allowed, false);
  }
});
test("monthly same-plan purchase extends expiry without resetting usage", t => {
  const f = fixture(t); const initial = f.store.assignPlan({ userId: "user", actorId: "admin", planId: "monthly30" });
  f.store.consumeUsage("user", "chat_accept", "trip-1");
  const o = f.create("monthly30"); assert.equal(o.action, "renew"); deliver(f, f.tx(o));
  const renewed = f.store.getSubscription("user").main;
  assert.equal(renewed.id, initial.id); assert.equal(quota(f).remaining, 29);
  assert.equal(renewed.endsAt, "2026-12-29T16:59:59.999Z");
});
test("daily same-plan purchase does not refill exhausted daily quota", t => {
  const f = fixture(t); f.store.assignPlan({ userId: "user", actorId: "admin", planId: "daily15" });
  for (let i=0; i<15; i++) f.store.consumeUsage("user", "chat_accept", "trip-" + i);
  const o = f.create("daily15"); deliver(f, f.tx(o));
  assert.equal(quota(f).remaining, 0); assert.equal(f.store.getPaymentOrder(o.id).status, "paid");
});
test("expired main can be replaced by new paid main; history stays", t => {
  const f = fixture(t); f.store.assignPlan({ userId: "user", actorId: "admin", planId: "daily15" });
  f.store.consumeUsage("user", "chat_accept", "trip-1");
  f.setTime("2026-12-01T10:00:00Z"); const o = f.create("daily30"); deliver(f, f.tx(o));
  assert.equal(quota(f).remaining, 30); assert.equal(f.store.getAcceptedOperations("user").length, 1);
});
test("different active main is not silently overwritten by an order", t => {
  const f = fixture(t); f.store.assignPlan({ userId: "user", actorId: "admin", planId: "daily15" });
  assert.throws(() => f.create("monthly30"), { code: "ACTIVE_PLAN_CONFLICT" });
});
test("admin changed main during checkout: money goes to review, not overwrite", t => {
  const f = fixture(t), o = f.create("daily15");
  f.store.assignPlan({ userId: "user", actorId: "admin", planId: "daily55" }); deliver(f, f.tx(o));
  assert.equal(quota(f).limit, 55); assert.equal(f.store.getPaymentOrder(o.id).status, "pending");
});
test("paid add-on on monthly main spends add-on first and stacks", t => {
  const f = fixture(t); f.store.assignPlan({ userId: "user", actorId: "admin", planId: "monthly30" });
  f.store.consumeUsage("user", "chat_accept", "main-first");
  const a=f.create(), b=f.create("extra30"); deliver(f,f.tx(a)); deliver(f,f.tx(b,{id:92705}));
  assert.equal(quota(f).remaining, 69);
  for(let i=0;i<7;i++) f.store.consumeUsage("user", "chat_accept", "extra-"+i);
  f.setTime("2026-10-29T17:00:00Z"); assert.equal(quota(f).remaining,29);
});
test("deleted target user is reviewed without granting to another account", t => {
  const f = fixture(t), o = f.create(); f.users.length=0; deliver(f,f.tx(o));
  assert.equal(quota(f).allowed,false); assert.equal(ledger(f).paymentTransactions["sepay:92704"].reason,"ACCOUNT_NOT_FOUND");
});
test("legacy order missing receiver snapshot cannot auto-apply", t => {
  const f=fixture(t),o=f.create(),data=ledger(f); delete data.paymentOrders[o.id].version;
  fs.writeFileSync(f.file,JSON.stringify(data)); deliver(f,f.tx(o)); assert.equal(quota(f).allowed,false);
});
test("order retry is idempotent and locks original price", t => {
  const f=fixture(t), opts={requestId:"same-unique-request"}; const a=f.create("extra10",opts);
  const b=f.create("extra10",{...opts,amount:1000}); assert.deepEqual(a,b);
  assert.throws(()=>f.create("extra30",opts),{code:"REQUEST_ID_CONFLICT"});
});
test("limit outstanding orders to avoid unbounded public creation", t => {
  const f=fixture(t);for(let i=0;i<5;i++)f.create();
  assert.throws(()=>f.create(),{code:"TOO_MANY_ORDERS"});
});
test("storage lock contention returns 503, retry then credits once", t => {
  const f=fixture(t),o=f.create();fs.writeFileSync(f.file+".lock","locked");
  assert.equal(deliver(f,f.tx(o)).statusCode,503);fs.unlinkSync(f.file+".lock");
  assert.equal(f.store.getPaymentOrder(o.id).status,"pending");deliver(f,f.tx(o));assert.equal(quota(f).remaining,10);
});
test("failed atomic rename does not persist paid state or grant twice", t => {
  const f=fixture(t),o=f.create();const original=fs.renameSync;
  const mock=t.mock.method(fs,"renameSync",(...args)=>{if(args[1]===f.file)throw Object.assign(Error("disk"),{code:"EIO"});return original(...args);});
  assert.equal(deliver(f,f.tx(o)).statusCode,503);mock.mock.restore();
  assert.equal(f.store.getPaymentOrder(o.id).status,"pending");assert.equal(quota(f).allowed,false);
  deliver(f,f.tx(o));assert.equal(quota(f).remaining,10);
});
test("blank, malformed, negative, fractional, and string amounts are rejected", t => {
  const f=fixture(t),o=f.create();for(const amount of [0,-1,1.5,"20000",null]){
    assert.equal(deliver(f,f.tx(o,{transferAmount:amount})).statusCode,400);
  }assert.equal(quota(f).allowed,false);
});
test("HMAC rejects wrong secret, tampering, missing headers and reserialized body", t => {
  const f=fixture(t),o=f.create(),raw=Buffer.from(JSON.stringify(f.tx(o)));
  for(const req of [
    {body:raw,headers:{}},
    {body:raw,headers:signed(raw,f.now(),"bad")},
    {body:Buffer.concat([raw,Buffer.from(" ")]),headers:signed(raw,f.now())},
    {body:JSON.parse(raw),headers:signed(raw,f.now())},
  ]) { const r=response();f.handlers.webhook(req,r);assert.equal(r.statusCode,401); }
  assert.equal(quota(f).allowed,false);
});
test("HMAC timestamp freshness permits 5 minutes but not stale or future replay", () => {
  const raw=Buffer.from('{"unicode":"\\u1ec7","spacing": 1}'),now=Date.parse("2026-10-29T15:00:00Z");
  for(const delta of [-301000,301000])assert.throws(()=>verifySePaySignature(raw,signed(raw,now+delta),SECRET,now),{code:"INVALID_SIGNATURE"});
  assert.doesNotThrow(()=>verifySePaySignature(raw,signed(raw,now-300000),SECRET,now));
});
test("invalid signed JSON is rejected, not acknowledged success", t => {
  const f=fixture(t),raw=Buffer.from("not json"),r=response();f.handlers.webhook({body:raw,headers:signed(raw,f.now())},r);
  assert.equal(r.statusCode,400);
});
test("bank timestamp parsing is Vietnam time and rejects impossible dates", () => {
  assert.equal(transactionTime("2026-10-29 22:00:00"),Date.parse("2026-10-29T15:00:00Z"));
  for(const v of ["2026-02-30 12:00:00","2026-10-29 24:10:00","2026-10-29T12:00:00Z",""])assert.throws(()=>transactionTime(v));
});
test("configuration requires secret and account; pricing is validated", () => {
  assert.throws(()=>paymentConfig({}),{code:"PAYMENTS_NOT_CONFIGURED"});
  assert.throws(()=>paymentConfig({SEPAY_ENABLED:"false"}),{code:"PAYMENTS_DISABLED"});
  for(const v of ['{"extra10":1}','{"unknown":20000}','[]','{"extra10":"20000"}']){
    assert.throws(()=>paymentConfig({SEPAY_BANK_ACCOUNT:ACCOUNT,SEPAY_WEBHOOK_SECRET:SECRET,SEPAY_PRICES_JSON:v}),{code:"INVALID_PAYMENT_PRICES"});
  }
});
test("API rejects client-supplied price and identity overrides", t => {
  const f=fixture(t);
  for(const other of [{amount:1},{userId:"admin"},{status:"paid"}]){const r=response();f.handlers.createOrder({body:{phone:"0900000000",planId:"extra10",...other}},r);assert.equal(r.statusCode,400);}
});
test("API returns QR and checkout token; status hides PII and raw data", t => {
  const f=fixture(t),r=response();f.handlers.createOrder({body:{phone:"+84900000000",planId:"extra10"}},r);
  assert.equal(r.statusCode,201);assert.match(r.body.qrUrl,/bank=VPBank/);assert.equal(r.body.order.amount,20000);
  const req={params:{id:r.body.order.id},get:()=>r.body.checkoutToken},status=response();f.handlers.orderStatus(req,status);
  assert.equal(status.statusCode,200);assert.equal(status.body.order.status,"pending");
  assert.equal(status.body.order.userId,undefined);assert.equal(status.body.order.accountNumber,undefined);
  const bad=response();f.handlers.orderStatus({...req,get:()=>""},bad);assert.equal(bad.statusCode,403);
});
test("expired status is computed without preventing later valid delivery", t => {
  const f=fixture(t),o=f.create("daily15"),tx=f.tx(o);f.setTime("2026-10-29T16:00:00Z");
  const req={params:{id:o.id},get:()=>checkoutToken(SECRET,o.id)},r=response();f.handlers.orderStatus(req,r);
  assert.equal(r.body.order.status,"expired");deliver(f,tx);const r2=response();f.handlers.orderStatus(req,r2);assert.equal(r2.body.order.status,"paid");
});
test("required virtual account is enforced", t => {
  const f=fixture(t);f.env.SEPAY_SUB_ACCOUNT="12345678901";
  const o=f.create("extra10",{subAccount:"12345678901"});deliver(f,f.tx(o));assert.equal(quota(f).allowed,false);
  deliver(f,f.tx(o,{id:92705,subAccount:"12345678901"}));assert.equal(quota(f).remaining,10);
});
test("notification failure cannot roll back a durable paid order", t => {
  const f=fixture(t),o=f.create();const h=createPaymentHandlers({store:f.store,env:f.env,clock:()=>+f.now(),findUserById:()=>({id:"user"}),notify(){throw Error("ws offline");},logger:{info(){},error(){}}});
  const raw=Buffer.from(JSON.stringify(f.tx(o))),r=response();h.webhook({body:raw,headers:signed(raw,f.now())},r);
  assert.equal(r.statusCode,200);assert.equal(quota(f).remaining,10);
});
test("HTTP local gateway: checkout -> create -> signed duplicate webhook -> paid", async t => {
  const f=fixture(t),server=createPaymentGateway({handlers:f.handlers});
  await new Promise(resolve=>server.listen(0,"127.0.0.1",resolve));t.after(()=>new Promise(resolve=>{server.closeAllConnections();server.close(resolve);}));
  const base="http://127.0.0.1:"+server.address().port;
  const page=await fetch(base+"/checkout");assert.equal(page.status,200);assert.match(await page.text(),/ZAutoChat/);
  assert.equal((await fetch(base+"/api/zalo/status")).status,404);assert.equal((await fetch(base+"/.env")).status,404);
  const r=await fetch(base+"/api/payments/orders",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({phone:"0900000000",planId:"extra10"})});assert.equal(r.status,201);const o=await r.json();
  const raw=Buffer.from(JSON.stringify(f.tx(o.order))),headers={"content-type":"application/json",...signed(raw,f.now())};
  const sent=await Promise.all([1,2].map(()=>fetch(base+"/api/payments/sepay/webhook",{method:"POST",headers,body:raw})));
  for(const reply of sent){assert.equal(reply.status,200);assert.deepEqual(await reply.json(),{success:true});}
  const status=await fetch(base+"/api/payments/orders/"+o.order.id,{headers:{"X-Checkout-Token":o.checkoutToken}});
  assert.equal((await status.json()).order.status,"paid");assert.equal(quota(f).remaining,10);
});
