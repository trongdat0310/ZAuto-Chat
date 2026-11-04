import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { createSubscriptionService } from "../subscriptions/subscription-service.js";
import { createPaymentHandlers } from "./payment-handlers.js";

const now = Date.parse("2026-11-04T12:00:00.000Z");
const account = "123456789";
const secret = "s".repeat(48);
const env = {
  SEPAY_BANK_ACCOUNT: account,
  SEPAY_WEBHOOK_SECRET: secret,
  SEPAY_ACCOUNT_NAME: "TEST",
};
const user = { id: "integration-user", phone: "0945785631" };

function response() {
  return {
    statusCode: 200,
    set() { return this; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}
function webhookRequest(tx) {
  const body = Buffer.from(JSON.stringify(tx));
  const timestamp = String(Math.floor(now / 1000));
  const signature = crypto.createHmac("sha256", secret)
    .update(timestamp + ".").update(body).digest("hex");
  return { body, headers: {
    "x-sepay-timestamp": timestamp,
    "x-sepay-signature": "sha256=" + signature,
  } };
}
function transaction(id, code, amount) {
  return {
    id, gateway: "VPBank", accountNumber: account,
    transferType: "in", transferAmount: amount,
    content: code, transactionDate: "2026-11-04 19:00:00",
    referenceCode: "BANK-" + id,
  };
}

test("signed SePay webhook credits exactly once; mismatched amount remains for review", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zauto-payment-test-"));
  try {
    const file = path.join(dir, "subscriptions.json");
    const store = createSubscriptionService({ file, clock: () => new Date(now) });
    let notifications = 0;
    const handlers = createPaymentHandlers({
      store, findUserByPhone: phone => phone === user.phone ? user : null,
      findUserById: id => id === user.id ? user : null,
      notify: () => { notifications++; },
      env, clock: () => now, logger: { info() {}, error() {} },
    });

    const create = handlers.createOrder({
      body: { phone: user.phone, planId: "monthly30" },
    }, response());
    assert.equal(create.statusCode, 201);
    const orderId = create.body.order.id;
    const good = webhookRequest(transaction(11001, orderId, 139000));
    assert.equal(handlers.webhook(good, response()).statusCode, 200);
    assert.equal(handlers.webhook(good, response()).statusCode, 200);
    assert.equal(notifications, 1);
    assert.equal(store.getPaymentOrder(orderId).status, "paid");
    assert.equal(store.getSubscription(user.id).main.planId, "monthly30");
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    assert.equal(data.logs.filter(x => x.transactionId === "11001").length, 1);

    const another = handlers.createOrder({
      body: { phone: user.phone, planId: "monthly30" },
    }, response());
    assert.equal(another.statusCode, 201);
    const bad = webhookRequest(transaction(11002, another.body.order.id, 139001));
    assert.equal(handlers.webhook(bad, response()).statusCode, 200);
    assert.equal(store.getPaymentOrder(another.body.order.id).status, "pending");
    assert.equal(notifications, 1);
    assert.equal(store.getPaymentTransactions().find(x => x.transactionId === "11002").reason, "AMOUNT_MISMATCH");
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
