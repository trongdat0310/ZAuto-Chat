import { paymentError } from "./payment-security.js";

// Existing ZAutoChat prices, in VND. Never take amount or price from the browser.
export const DEFAULT_PRICES = Object.freeze({ monthly30: 139000, daily15: 299000,
  daily30: 499000, daily55: 899000, unlimited: 9999999, extra10: 20000, extra30: 50000 });

export function paymentConfig(env = process.env) {
  if (["false", "0"].includes(String(env.SEPAY_ENABLED).toLowerCase())) {
    throw paymentError("PAYMENTS_DISABLED", "Thanh toan dang tam dung.", 503);
  }
  const accountNumber = String(env.SEPAY_BANK_ACCOUNT || "").trim();
  const secret = env.SEPAY_WEBHOOK_SECRET;
  if (!/^\d{6,30}$/.test(accountNumber) || typeof secret !== "string" || secret.length < 32) {
    throw paymentError("PAYMENTS_NOT_CONFIGURED", "Chua cau hinh tai khoan VPBank va khoa webhook (toi thieu 32 ky tu).", 503);
  }
  const ttlMinutes = Number(env.SEPAY_ORDER_TTL_MINUTES || 30);
  if (!Number.isInteger(ttlMinutes) || ttlMinutes < 5 || ttlMinutes > 120) throw paymentError("INVALID_PAYMENT_CONFIG", "Thoi han don phai tu 5 den 120 phut.", 503);
  let overrides = {};
  try { overrides = JSON.parse(env.SEPAY_PRICES_JSON || "{}"); }
  catch { throw paymentError("INVALID_PAYMENT_PRICES", "SEPAY_PRICES_JSON khong hop le.", 503); }
  if (!overrides || Array.isArray(overrides) || typeof overrides !== "object" ||
      Object.entries(overrides).some(([id, price]) => !Object.hasOwn(DEFAULT_PRICES, id) ||
        !Number.isSafeInteger(price) || price < 1000 || price > 500000000)) {
    throw paymentError("INVALID_PAYMENT_PRICES", "Gia goi phai la so nguyen VND tu 1000 den 500000000.", 503);
  }
  return { accountNumber, gateway: "VPBank", accountName: String(env.SEPAY_ACCOUNT_NAME || "PHI TRONG DAT"),
    subAccount: String(env.SEPAY_SUB_ACCOUNT || "").trim(), secret, ttlMinutes,
    prices: Object.freeze({ ...DEFAULT_PRICES, ...overrides }) };
}
