import "dotenv/config";
import { subscriptionService } from "../src/subscriptions/subscription-service.js";
// Local read-only report: no secret, raw bank payload, or password is printed.
const rows = subscriptionService.getPaymentTransactions({ limit: 100 });
console.table(rows.map(row => ({ transaction: row.transactionId || "legacy", status: row.status,
  reason: row.reason || "", order: row.orderId || "", received: row.receivedAt || row.at })));
console.log("Review entries are NOT auto-refunded or manually activated by this command.");
