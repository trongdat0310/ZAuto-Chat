import { paymentError, transactionTime, sameBank, extractOrderCode } from "./payment-security.js";

// Default checks stay exact. This narrow exception is only an operator-selected
// interpretation for an already-stored receipt, NOT a claim that VPBank always
// truncates seconds. The original payload/timestamps must never be rewritten.
export function assessPaymentTime(tx, order, now, {
  allowVpbankMinuteTime = false, receivedAt,
} = {}) {
  if (typeof allowVpbankMinuteTime !== "boolean" || !(now instanceof Date) ||
      !Number.isFinite(+now)) throw paymentError("INVALID_TIME_REVIEW");
  const bankTime = transactionTime(tx.transactionDate);
  const created = Date.parse(order.createdAt), expires = Date.parse(order.expiresAt);
  if (!Number.isFinite(created) || !Number.isFinite(expires) || expires <= created) {
    throw paymentError("INVALID_ORDER_TIME", "Invalid order timestamps.", 503);
  }
  const beforeOrder = bankTime < Math.floor(created / 1000) * 1000;
  const afterDeadline = bankTime > expires;
  const inFuture = bankTime > +now + 300000;
  const received = typeof receivedAt === "string" ? Date.parse(receivedAt) : NaN;
  const sameMinuteCandidate = beforeOrder && !afterDeadline && !inFuture &&
    sameBank(tx.gateway, "VPBank") && sameBank(order.gateway, "VPBank") &&
    bankTime % 60000 === 0 && bankTime === Math.floor(created / 60000) * 60000 &&
    created <= +now && Number.isFinite(received) && received >= created && received <= +now &&
    typeof tx.referenceCode === "string" && tx.referenceCode.trim().length > 0 &&
    extractOrderCode({ ...tx, code: null }) === order.id;
  const toleranceApplied = allowVpbankMinuteTime && sameMinuteCandidate;
  return {
    allowed: !afterDeadline && !inFuture && (!beforeOrder || toleranceApplied),
    policy: allowVpbankMinuteTime ? "vpbank_same_minute_review" : "exact",
    beforeOrder, afterDeadline, inFuture,
    beforeOrderByMs: Math.max(0, created - bankTime),
    sameMinuteCandidate, toleranceApplied,
  };
}
