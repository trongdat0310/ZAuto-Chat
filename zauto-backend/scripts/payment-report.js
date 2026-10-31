import "dotenv/config";
import { subscriptionService } from "../src/subscriptions/subscription-service.js";
import { extractOrderCode } from "../src/payments/payment-security.js";
// Local read-only diagnostics. Never print tokens, passwords, raw bank content
// or update an order/entitlement from this report.
const rows = subscriptionService.getPaymentTransactions({ limit: 100 });
console.table(rows.map(row => {
  const payload = row.payload;
  const candidate = typeof payload?.content === "string" ? extractOrderCode(payload) : null;
  const order = candidate ? subscriptionService.getPaymentOrder(candidate) : null;
  return {
    transaction: row.transactionId || "legacy",
    status: row.status,
    reason: row.reason || "",
    order: row.orderId || "",
    providerCode: typeof payload?.code === "string"
      ? payload.code.replace(/[^A-Za-z0-9_-]/g, "?").slice(0, 64) : "",
    fullCode: candidate || "",
    candidateStatus: order?.status || (candidate ? "not_found" : ""),
    received: row.receivedAt || row.at,
  };
}));
console.log("Read-only: fullCode/candidateStatus are diagnostic, NOT payment approval.");
console.log("Review receipts stay quarantined. Do not delete them or transfer again to retry.");
console.log("Compare the original order and bank transfer before any manual reconciliation.");
