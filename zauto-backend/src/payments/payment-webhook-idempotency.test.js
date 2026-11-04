import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { createPaymentHandlers } from "./payment-handlers.js";

const secret = "a".repeat(48);
const now = Date.UTC(2026, 10, 4, 12, 0, 0);
const transaction = {
  id: 12345, gateway: "VPBank", accountNumber: "123456789",
  transferType: "in", transferAmount: 139000,
  content: "ZCA0123456789ABCDEF01",
  transactionDate: "2026-11-04 19:00:00",
};
function request() {
  const raw = Buffer.from(JSON.stringify(transaction));
  const timestamp = String(Math.floor(now / 1000));
  const signature = crypto.createHmac("sha256", secret)
    .update(timestamp + ".").update(raw).digest("hex");
  return { body: raw, headers: {
    "x-sepay-timestamp": timestamp,
    "x-sepay-signature": "sha256=" + signature,
  } };
}
function response() {
  return {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}
function makeHandlers(confirmPayment, notify) {
  return createPaymentHandlers({
    store: { confirmPayment },
    findUserByPhone: () => null,
    findUserById: () => ({ id: "user1" }),
    notify,
    clock: () => now,
    logger: { info() {}, error() {} },
    env: {
      SEPAY_WEBHOOK_SECRET: secret,
      PAYMENT_ACCOUNT_NUMBER: "123456789",
      PAYMENT_ACCOUNT_NAME: "Test Account",
      PAYMENT_GATEWAY: "VPBank",
    },
  });
}

test("webhook notifies once for a paid transaction, not for replay", () => {
  let calls = 0, notifications = 0;
  const handlers = makeHandlers(() => {
    calls++;
    return { status: "paid", userId: "user1", duplicate: calls > 1 };
  }, () => { notifications++; });
  const first = handlers.webhook(request(), response());
  const second = handlers.webhook(request(), response());
  assert.equal(first.statusCode, 200);
  assert.equal(second.statusCode, 200);
  assert.equal(notifications, 1);
});

test("webhook never notifies on review, ignored, or duplicate paid receipts", () => {
  let notifications = 0;
  for (const result of [
    { status: "review", userId: "user1", duplicate: false },
    { status: "ignored", userId: "user1", duplicate: false },
    { status: "paid", userId: "user1", duplicate: true },
  ]) {
    const handlers = makeHandlers(() => result, () => { notifications++; });
    assert.equal(handlers.webhook(request(), response()).statusCode, 200);
  }
  assert.equal(notifications, 0);
});

test("invalid webhook signature never reaches the payment store", () => {
  let called = false;
  const handlers = makeHandlers(() => { called = true; }, () => {});
  const req = request();
  req.headers["x-sepay-signature"] = "sha256=" + "0".repeat(64);
  const result = handlers.webhook(req, response());
  assert.equal(result.statusCode, 401);
  assert.equal(called, false);
});
