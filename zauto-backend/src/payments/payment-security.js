import crypto from "node:crypto";

export const paymentError = (code, message = code, status = 400) =>
  Object.assign(new Error(message), { code, status });
export const sha256 = value => crypto.createHash("sha256").update(value).digest("hex");
export const isOrderId = value => typeof value === "string" && /^ZCA[A-F0-9]{18}$/.test(value);
const bankKey = value => String(value).replace(/\s/g, "").toLowerCase();
export const sameBank = (a, b) => bankKey(a) === bankKey(b);

export function verifySePaySignature(rawBody, headers, secret, now = Date.now()) {
  const timestamp = headers["x-sepay-timestamp"];
  const signature = headers["x-sepay-signature"];
  if (!Buffer.isBuffer(rawBody) || rawBody.length > 65536 ||
      typeof secret !== "string" || secret.length < 32 ||
      typeof timestamp !== "string" || !/^\d{10}$/.test(timestamp) ||
      Math.abs(Math.floor(now / 1000) - Number(timestamp)) > 300 ||
      typeof signature !== "string" || !/^sha256=[a-f0-9]{64}$/i.test(signature)) {
    throw paymentError("INVALID_SIGNATURE", "Chu ky webhook khong hop le.", 401);
  }
  const expected = crypto.createHmac("sha256", secret).update(timestamp + ".").update(rawBody).digest();
  const received = Buffer.from(signature.slice(7), "hex");
  if (!crypto.timingSafeEqual(expected, received)) {
    throw paymentError("INVALID_SIGNATURE", "Chu ky webhook khong hop le.", 401);
  }
}

export function transactionTime(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(value)) {
    throw paymentError("INVALID_TRANSACTION_DATE");
  }
  const time = Date.parse(value.replace(" ", "T") + "+07:00");
  if (!Number.isFinite(time) || new Date(time + 7 * 3600000).toISOString().slice(0, 19).replace("T", " ") !== value) {
    throw paymentError("INVALID_TRANSACTION_DATE");
  }
  return time;
}

export function validateTransaction(tx) {
  if (!tx || Array.isArray(tx) || !Number.isSafeInteger(tx.id) || tx.id < 1 ||
      typeof tx.gateway !== "string" || !tx.gateway || tx.gateway.length > 80 ||
      typeof tx.accountNumber !== "string" || !/^\d{6,30}$/.test(tx.accountNumber) ||
      !["in", "out"].includes(tx.transferType) ||
      !Number.isSafeInteger(tx.transferAmount) || tx.transferAmount <= 0 ||
      typeof tx.content !== "string" || tx.content.length > 8192 ||
      (tx.code != null && (typeof tx.code !== "string" || tx.code.length > 128)) ||
      (tx.subAccount != null && (typeof tx.subAccount !== "string" || tx.subAccount.length > 128)) ||
      (tx.referenceCode != null && (typeof tx.referenceCode !== "string" || tx.referenceCode.length > 128))) {
    throw paymentError("INVALID_TRANSACTION", "Du lieu giao dich khong hop le.");
  }
  transactionTime(tx.transactionDate);
  return tx;
}

// Never match a partial token or silently pick the first of several order codes.
export function extractOrderCode(tx) {
  const content = tx.content.toUpperCase();
  const matches = [...content.matchAll(/(?:^|[^A-Z0-9])(ZCA[A-F0-9]{18})(?![A-Z0-9])/g)].map(m => m[1]);
  const codes = [...new Set(matches)];
  const providerCode = String(tx.code || "").toUpperCase();
  if (codes.length > 1) return null;
  if (codes.length === 1) {
    const fullCode = codes[0];
    if (!providerCode || providerCode === fullCode) return fullCode;
    // SePay derives "code" using the merchant's configurable pattern. A
    // digits-only/short pattern can return ZCA7 for ZCA7A... in the bank
    // content. Accept that metadata ONLY when the signed original content
    // supplies one complete, bounded code and the short code is its prefix.
    // Never resolve an order by a partial code, amount, or account alone.
    const truncatedPrefix = /^ZCA[A-F0-9]{1,17}$/.test(providerCode) &&
      fullCode.startsWith(providerCode);
    return truncatedPrefix ? fullCode : null;
  }
  // Preserve the exact full-code fallback; short metadata alone is not enough.
  return isOrderId(providerCode) ? providerCode : null;
}

export function transactionFingerprint(tx) {
  return sha256(JSON.stringify([tx.id, bankKey(tx.gateway), tx.accountNumber, tx.subAccount || "",
    tx.transactionDate, tx.transferType, tx.transferAmount, tx.content, tx.code || "", tx.referenceCode || ""]));
}

// Domain separation: a checkout token cannot be reused as a webhook signature.
export function checkoutToken(secret, id) {
  return crypto.createHmac("sha256", secret).update("zautochat-checkout-v1:" + id).digest("hex");
}
export function verifyCheckoutToken(secret, id, token) {
  if (typeof token !== "string" || !/^[a-f0-9]{64}$/.test(token) || !isOrderId(id)) return false;
  return crypto.timingSafeEqual(Buffer.from(token, "hex"), Buffer.from(checkoutToken(secret, id), "hex"));
}
