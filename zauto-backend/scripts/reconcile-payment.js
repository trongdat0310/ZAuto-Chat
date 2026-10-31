import "dotenv/config";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { subscriptionService as store } from "../src/subscriptions/subscription-service.js";
import { paymentConfig } from "../src/payments/payment-config.js";
import { findUserById } from "../src/users/user-store.js";

// Default is READ-ONLY. No public HTTP route exposes reconciliation.
try {
  const { values: args } = parseArgs({ options: {
    transaction: { type: "string" }, order: { type: "string" }, approve: { type: "string" },
    "bank-reference": { type: "string" }, note: { type: "string" },
    apply: { type: "boolean", default: false }, "dry-run": { type: "boolean", default: false },
    "bank-verified": { type: "boolean", default: false },
    "not-previously-credited": { type: "boolean", default: false },
    "vpbank-minute-time": { type: "boolean", default: false },
    help: { type: "boolean", default: false },
  } });
  if (args.help) {
    console.log(`Read-only preview:
  node scripts/reconcile-payment.js --transaction SEPAY_ID

Apply ONE verified receipt only (after backup and manual bank verification):
  node scripts/reconcile-payment.js --transaction SEPAY_ID --order ZCA_FULL_CODE --approve PREVIEW_HASH --bank-reference BANK_REFERENCE --bank-verified --not-previously-credited --note "Verified in VPBank; not previously credited/refunded" --apply

Optional LOCAL time review (never enabled for public webhook requests):
  Add --vpbank-minute-time to BOTH preview and apply only after checking the bank
  record for a :00 timestamp in the SAME MINUTE as order creation. It cannot
  allow earlier minutes, late transfers, changed evidence or a wrong amount.
  A matching minute alone does NOT prove the bank truncated the timestamp.

Only old MISSING_OR_AMBIGUOUS_CODE receipts with a truncated provider code are supported.
A preview never grants a plan, never changes order status and never sends money.
--apply changes local entitlements/order status; it does not initiate a bank transfer.
Do not apply to simulated bank events or payments already compensated/refunded.
Run a new preview after each application or any concurrent data change.`);
  } else {
    if (!args.transaction || (args.apply && args["dry-run"])) throw Error("Specify --transaction ID; do not combine --apply and --dry-run.");
    const config = paymentConfig();
    const options = { transactionId: args.transaction, expectedOrderId: args.order,
      accountNumber: config.accountNumber, gateway: config.gateway, subAccount: config.subAccount,
      userExists: id => Boolean(findUserById(id)),
      allowVpbankMinuteTime: args["vpbank-minute-time"] };
    const preview = store.previewPaymentReview(options);
    const user = preview.userId ? findUserById(preview.userId) : null;
    console.log(args.apply ? "APPLY REQUESTED (checks are repeated under the store lock)" : "DRY RUN - NO DATA CHANGED");
    console.table([{ transaction: preview.transactionId, eligible: preview.eligible,
      reason: preview.reason || "CHECKS_PASSED", order: preview.orderId || "",
      userPhone: user?.phone || "", plan: preview.planId || "", amount: preview.amount,
      expectedAmount: preview.expectedAmount, action: preview.action || "" }]);
    // Only operational fields; never display secrets, auth hashes or raw webhook.
    console.log(JSON.stringify(preview, null, 2));
    if (args["vpbank-minute-time"]) {
      console.log("TIME REVIEW: same-minute interpretation selected; not proof of bank rounding. Verify this specific transfer before --apply.");
    }
    if (!args.apply) {
      console.log("Verify the actual VPBank receipt, recipient, amount and beneficiary account. Do not pay again.");
      if (!preview.eligible) process.exitCode = 2;
    } else {
      if (!preview.eligible) throw Error("Not eligible for this recovery tool: " + preview.reason);
      const actorId = String(process.env.ADMIN_USER_ID || "").trim();
      if (!actorId || !findUserById(actorId)) throw Error("Set ADMIN_USER_ID to the existing administrator before applying.");
      if (!args.order || args.order !== preview.orderId || args.approve !== preview.approval ||
          args["bank-reference"] !== preview.bankReference || !args["bank-verified"] ||
          !args["not-previously-credited"] || !args.note || args.note.trim().length < 10) {
        throw Error("Apply requires the exact preview hash/order/reference plus --bank-verified, --not-previously-credited and --note. Run --help.");
      }
      const file = process.env.SUBSCRIPTIONS_DATA_FILE || fileURLToPath(new URL("../data/subscriptions.json", import.meta.url));
      const backupDir = path.join(path.dirname(file), "payment-review-backups");
      fs.mkdirSync(backupDir, { recursive: true });
      const backup = path.join(backupDir, path.basename(file) + "." + Date.now() + "." + crypto.randomUUID() + ".bak");
      fs.copyFileSync(file, backup, fs.constants.COPYFILE_EXCL);
      // change() rejects stale approval or an active file lock; never delete a lock.
      const result = store.reconcilePaymentReview({ ...options, actorId, approval: args.approve,
        bankReference: args["bank-reference"], bankVerified: args["bank-verified"],
        notPreviouslyCredited: args["not-previously-credited"], note: args.note });
      console.log("Backup:", backup);
      console.log("Result:", JSON.stringify(result));
      console.log("Refresh checkout using its original checkout token, then pull to refresh Home.");
    }
  }
} catch (error) {
  console.error("[PAYMENT REVIEW]", error.code || "STOPPED", error.message);
  process.exitCode = 1;
}
