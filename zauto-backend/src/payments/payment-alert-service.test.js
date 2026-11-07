import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { collectPaymentIssues, runPaymentAlerts } from "./payment-alert-service.js";

const review = (id, reason = "AMOUNT_MISMATCH") => ({
  transactionId: id, orderId: "ZCA0123456789ABCDEF01", status: "review", reason,
});
const store = (receipts, orders = {}) => ({
  getPaymentTransactions({ limit }) { return receipts.slice(-limit).reverse(); },
  getPaymentOrder(id) { return orders[id] ?? null; },
});
const withFile = async fn => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zchatauto-payment-alert-"));
  try { await fn(path.join(dir, "alert-state.json")); }
  finally { fs.rmSync(dir, { recursive: true, force: true }); }
};

test("a review alert sends once and remains deduplicated across runs", () => withFile(async stateFile => {
  const messages = [];
  const options = { store: store([review("101")]), stateFile,
    deliver: async mail => messages.push(mail) };
  assert.equal((await runPaymentAlerts(options)).newIssues, 1);
  assert.equal((await runPaymentAlerts(options)).newIssues, 0);
  assert.equal(messages.length, 1);
  assert.match(messages[0].text, /AMOUNT_MISMATCH/);
  assert.doesNotMatch(messages[0].text, /SMTP_PASSWORD/);
  assert.equal(fs.statSync(stateFile).mode & 0o777, 0o600);
}));

test("new reason for same payment triggers a new alert", () => withFile(async stateFile => {
  let sent = 0;
  const send = async () => { sent++; };
  await runPaymentAlerts({ store: store([review("101")]), stateFile, deliver: send });
  await runPaymentAlerts({ store: store([review("101", "OTHER_REASON")]), stateFile, deliver: send });
  assert.equal(sent, 2);
}));

test("failed SMTP leaves state untouched so next run retries", () => withFile(async stateFile => {
  const options = { store: store([review("101")]), stateFile };
  await assert.rejects(runPaymentAlerts({ ...options, deliver: async () => { throw new Error("smtp down"); } }), /smtp down/);
  assert.equal(fs.existsSync(stateFile), false);
  assert.equal((await runPaymentAlerts({ ...options, deliver: async () => {} })).sent, true);
}));

test("dry run never sends email or records alert", () => withFile(async stateFile => {
  let sends = 0;
  const result = await runPaymentAlerts({ store: store([review("101")]), stateFile,
    deliver: async () => { sends++; }, dryRun: true });
  assert.equal(result.newIssues, 1);
  assert.equal(sends, 0);
  assert.equal(fs.existsSync(stateFile), false);
}));

test("paid receipt mismatch alerts, consistent paid does not", () => withFile(async stateFile => {
  const paid = { transactionId: "102", orderId: "ZCA0123456789ABCDEF01", status: "paid" };
  const orderId = paid.orderId;
  assert.equal(collectPaymentIssues(store([paid], { [orderId]: { status: "paid", transactionId: "102" } })).issues.length, 0);
  assert.equal(collectPaymentIssues(store([paid], { [orderId]: { status: "pending" } })).issues[0].type, "PAID_ORDER_MISMATCH");
}));

test("invalid existing state stops sending instead of resetting dedup", () => withFile(async stateFile => {
  fs.writeFileSync(stateFile, "broken state");
  let sends = 0;
  await assert.rejects(runPaymentAlerts({ store: store([review("101")]), stateFile,
    deliver: async () => { sends++; } }), SyntaxError);
  assert.equal(sends, 0);
}));

test("multiple issues send one aggregate email", () => withFile(async stateFile => {
  const messages = [];
  const result = await runPaymentAlerts({ store: store([review("101"), review("102")]), stateFile,
    deliver: async mail => messages.push(mail) });
  assert.equal(result.newIssues, 2);
  assert.equal(messages.length, 1);
}));
