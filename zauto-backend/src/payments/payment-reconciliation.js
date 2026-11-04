import crypto from "node:crypto";
import { assessPaymentTime } from "./payment-time.js";
import { paymentError, sha256, extractOrderCode, validateTransaction,
  transactionFingerprint, sameBank } from "./payment-security.js";

// LOCAL OPERATOR TOOL ONLY. Never add this to a public webhook/checkout route.
// This recovers only receipts quarantined by the old truncated-code matcher.
// All business checks run through the same confirmation code as a fresh webhook.
export function createPaymentReconciliation({ read, change, simulate, validate, clock }) {
  function prepare(data, { transactionId, expectedOrderId, accountNumber,
    gateway = "VPBank", subAccount = "", userExists, now = clock(), allowVpbankMinuteTime = false }) {
    if (typeof transactionId !== "string" || !/^[1-9]\d{0,15}$/.test(transactionId) ||
        !Number.isSafeInteger(Number(transactionId)) || !(now instanceof Date) ||
        !Number.isFinite(+now) || typeof userExists !== "function" ||
        typeof allowVpbankMinuteTime !== "boolean") {
      throw paymentError("INVALID_RECONCILIATION_INPUT");
    }
    const key = "sepay:" + transactionId;
    const receipt = data.paymentTransactions?.[key];
    const summary = { transactionId, eligible: false, status: receipt?.status || "missing" };
    const blocked = reason => ({ summary: { ...summary, reason } });
    if (!receipt) return blocked("RECEIPT_NOT_FOUND");
    if (receipt.status === "paid") {
      Object.assign(summary, { orderId: receipt.orderId, userId: receipt.userId });
      return blocked("ALREADY_PAID");
    }
    if (receipt.status !== "review" || receipt.reason !== "MISSING_OR_AMBIGUOUS_CODE") {
      return blocked("REVIEW_REASON_NOT_SUPPORTED");
    }
    if (receipt.conflicts?.length || receipt.reconciliation) return blocked("RECEIPT_HAS_CONFLICTS");
    let tx;
    try {
      if (typeof receipt.rawBody !== "string") return blocked("MISSING_ORIGINAL_PAYLOAD");
      tx = validateTransaction(JSON.parse(receipt.rawBody));
      validateTransaction(receipt.payload);
      if (String(tx.id) !== transactionId || receipt.transactionId !== transactionId ||
          transactionFingerprint(tx) !== receipt.fingerprint ||
          transactionFingerprint(receipt.payload) !== receipt.fingerprint) {
        return blocked("RECEIPT_INTEGRITY_MISMATCH");
      }
    } catch { return blocked("RECEIPT_INTEGRITY_MISMATCH"); }
    const code = extractOrderCode(tx);
    const prefix = String(tx.code || "").toUpperCase();
    if (!code || extractOrderCode({ ...tx, code: null }) !== code ||
        !/^ZCA[A-F0-9]{1,17}$/.test(prefix) || !code.startsWith(prefix)) {
      return blocked("NOT_TRUNCATED_CODE_CASE");
    }
    const order = data.paymentOrders?.[code];
    Object.assign(summary, { orderId: code, userId: order?.userId, planId: order?.planId,
      amount: tx.transferAmount, expectedAmount: order?.amount, bank: tx.gateway,
      accountNumber: tx.accountNumber, bankReference: tx.referenceCode?.trim() || "",
      transactionDate: tx.transactionDate, orderCreatedAt: order?.createdAt,
      orderExpiresAt: order?.expiresAt, originalReason: receipt.reason });
    if (!order) return blocked("ORDER_NOT_FOUND");
    const reviewTime = { allowVpbankMinuteTime, receivedAt: receipt.receivedAt };
    summary.timeCheck = assessPaymentTime(tx, order, now, reviewTime);
    if (expectedOrderId !== undefined && expectedOrderId !== code) return blocked("EXPECTED_ORDER_MISMATCH");
    if (receipt.orderId && receipt.orderId !== code) return blocked("RECEIPT_ORDER_CONFLICT");
    if (order.status !== "pending" || order.transactionId || order.entitlementId) return blocked("ORDER_ALREADY_PROCESSED");
    const reference = tx.referenceCode?.trim();
    if (!reference) return blocked("BANK_REFERENCE_REQUIRED");
    const refKey = sha256(JSON.stringify([gateway, accountNumber, "in", reference]));
    // The old handler reserved this reference BEFORE rejecting the short code.
    // Do not clear any reference belonging to another receipt.
    if (data.paymentReferences?.[refKey] !== key) return blocked("BANK_REFERENCE_INDEX_CONFLICT");
    const otherPaid = Object.entries(data.paymentTransactions || {}).some(([k, r]) => k !== key &&
      r.status === "paid" && (r.orderId === code || (r.payload &&
        sameBank(r.payload.gateway, tx.gateway) && r.payload.accountNumber === tx.accountNumber &&
        r.payload.transferType === "in" && r.payload.referenceCode?.trim() === reference)));
    const credited = data.logs.some(log => String(log.action || "").startsWith("payment_") &&
      (String(log.transactionId) === transactionId || log.orderId === code));
    if (otherPaid || credited) return blocked("PREVIOUS_PAYMENT_CREDIT_FOUND");

    // Only discard the dedupe marker in a private simulation, never on disk.
    // Failed validation or a failed atomic store write retains the original review.
    const candidate = structuredClone(data);
    delete candidate.paymentTransactions[key];
    delete candidate.paymentReferences[refKey];
    const result = simulate(candidate, { transaction: tx, accountNumber, gateway, subAccount,
      rawBody: receipt.rawBody, userExists, now, reviewTime });
    if (result.status !== "paid") return blocked(result.reason || "PAYMENT_CHECK_FAILED");
    const changedOrder = candidate.paymentOrders[code];
    const dayVN = new Date(+now + 7 * 3600000).toISOString().slice(0, 10);
    // Bind approval to the entire read snapshot and receiver configuration.
    // Any concurrent store change requires a fresh preview, not an unsafe override.
    const approval = sha256(JSON.stringify(["payment-review-v2", transactionId,
      accountNumber, gateway, subAccount, dayVN, allowVpbankMinuteTime, data]));
    return { candidate, key, receipt, summary: { ...summary, eligible: true, reason: null,
      action: result.action, entitlementEndsAt: changedOrder.entitlementEndsAt, approval } };
  }
  return {
    previewPaymentReview(options) {
      return prepare(read(), options).summary;
    },
    reconcilePaymentReview(options) {
      const { actorId, approval, bankReference, note, bankVerified, notPreviouslyCredited } = options;
      validate(actorId);
      if (!options.expectedOrderId || typeof approval !== "string" || !/^[a-f0-9]{64}$/.test(approval) ||
          typeof note !== "string" || note.trim().length < 10 || note.length > 500 ||
          typeof bankReference !== "string" || bankVerified !== true || notPreviouslyCredited !== true) {
        throw paymentError("RECONCILIATION_APPROVAL_REQUIRED", "Preview, verify the bank transfer and confirm no previous manual credit first.", 409);
      }
      return change(data => {
        const prepared = prepare(data, options);
        const { summary, candidate, key, receipt } = prepared;
        if (!summary.eligible) {
          if (summary.reason === "ALREADY_PAID" && summary.orderId === options.expectedOrderId) {
            return { status: "paid", duplicate: true, orderId: summary.orderId, userId: summary.userId };
          }
          throw paymentError(summary.reason, "Review not applied: " + summary.reason, 409);
        }
        if (approval !== summary.approval) throw paymentError("REVIEW_CHANGED", "Data changed. Run a fresh preview.", 409);
        if (bankReference.trim() !== summary.bankReference) throw paymentError("BANK_REFERENCE_MISMATCH", "Bank reference does not match the stored receipt.", 409);
        const at = (options.now || clock()).toISOString();
        const audit = { actorId, at, note: note.trim(), approval, timeCheck: summary.timeCheck,
          previousStatus: receipt.status, previousReason: receipt.reason,
          previousOrderId: receipt.orderId || null, bankVerified: true, notPreviouslyCredited: true };
        const paid = candidate.paymentTransactions[key];
        candidate.paymentTransactions[key] = { ...structuredClone(receipt), ...paid,
          receivedAt: receipt.receivedAt, rawBody: receipt.rawBody,
          payload: structuredClone(receipt.payload), reconciliation: audit };
        candidate.logs.push({ id: crypto.randomUUID(), action: "payment_review_reconciled", actorId,
          userId: summary.userId, orderId: summary.orderId, transactionId: summary.transactionId,
          at, note: audit.note, previousReason: receipt.reason, approval, timeCheck: summary.timeCheck });
        Object.assign(data, candidate);
        return { status: "paid", duplicate: false, orderId: summary.orderId, userId: summary.userId,
          action: summary.action, entitlementEndsAt: summary.entitlementEndsAt };
      });
    },
  };
}
