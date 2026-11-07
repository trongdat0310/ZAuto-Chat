import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const safeText = value => String(value ?? "").replace(/[\r\n\t\x00-\x1f]/g, " ").slice(0, 100);

export function collectPaymentIssues(store, limit = 500) {
  const receipts = store.getPaymentTransactions({ limit });
  const issues = [];
  for (const receipt of receipts) {
    const transaction = safeText(receipt.transactionId || "unknown");
    const orderId = safeText(receipt.orderId || "");
    let type, reason = "";
    if (receipt.status === "review") {
      type = "PAYMENT_REVIEW";
      reason = safeText(receipt.reason || "UNKNOWN");
    } else if (receipt.status === "paid") {
      let order = null;
      try { if (orderId) order = store.getPaymentOrder(orderId); }
      catch { /* An invalid or unreadable order is an inconsistency to investigate. */ }
      if (!order || order.status !== "paid" || String(order.transactionId) !== String(receipt.transactionId)) {
        type = "PAID_ORDER_MISMATCH";
      }
    }
    if (!type) continue;
    const fingerprint = crypto.createHash("sha256")
      .update(JSON.stringify([type, transaction, orderId, reason])).digest("hex");
    issues.push({ type, transaction, orderId, reason, fingerprint });
  }
  return { scanned: receipts.length, issues };
}

function readState(filename) {
  let content;
  try { content = fs.readFileSync(filename, "utf8"); }
  catch (error) {
    if (error.code === "ENOENT") return { version: 1, sent: {} };
    throw error;
  }
  const state = JSON.parse(content);
  if (!state || state.version !== 1 || !state.sent || Array.isArray(state.sent) ||
      typeof state.sent !== "object") {
    throw new Error("PAYMENT_ALERT_STATE_INVALID: inspect the existing file; it was not reset");
  }
  return state;
}

function saveState(filename, state) {
  fs.mkdirSync(path.dirname(filename), { recursive: true, mode: 0o700 });
  const tmp = filename + "." + crypto.randomUUID() + ".tmp";
  try {
    const fd = fs.openSync(tmp, "wx", 0o600);
    try {
      fs.writeFileSync(fd, JSON.stringify(state, null, 2) + "\n");
      fs.fsyncSync(fd);
    } finally { fs.closeSync(fd); }
    fs.renameSync(tmp, filename);
  } finally {
    fs.rmSync(tmp, { force: true });
  }
}

export function formatPaymentAlert(issues, now = new Date()) {
  const lines = issues.slice(0, 50).map((issue, index) =>
    (index + 1) + ". " + issue.type + " | SePay ID: " + issue.transaction +
    " | Don: " + (issue.orderId || "khong ro") + " | Ly do: " + (issue.reason || "n/a"));
  return {
    subject: "[zchatauto][SePay] " + issues.length + " giao dich can kiem tra",
    text: [
      "ZCHATAUTO | CANH BAO THANH TOAN SEPAY",
      "Thoi gian (VN): " + now.toLocaleString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh" }),
      "So su co moi: " + issues.length,
      "",
      ...lines,
      ...(issues.length > lines.length ? ["... con " + (issues.length - lines.length) + " su co; kiem tra bao cao tren server."] : []),
      "",
      "Day la canh bao chi doc. Khong tu dong cap goi hay phe duyet thanh toan.",
      "Doi chieu don hang goc va giao dich SePay/VPBank truoc khi xu ly thu cong.",
      "Chay: sudo -u zchatauto npm run payments:report",
      "Khong chuyen tien lai chi de thu lai doi soat.",
    ].join("\n"),
  };
}

// One email per scan contains every new issue. Save fingerprints only after
// SMTP accepts the email, so delivery failures are retried on the next run.
// A crash between SMTP acceptance and disk persistence can cause a repeat.
export async function runPaymentAlerts({ store, stateFile, deliver, dryRun = false, now = () => new Date() }) {
  if (typeof stateFile !== "string" || !stateFile) throw new Error("PAYMENT_ALERT_STATE_FILE_REQUIRED");
  const { scanned, issues } = collectPaymentIssues(store);
  const state = readState(stateFile);
  const newIssues = issues.filter(issue => !Object.hasOwn(state.sent, issue.fingerprint));
  if (!dryRun && newIssues.length) {
    if (typeof deliver !== "function") throw new Error("PAYMENT_ALERT_DELIVERY_NOT_CONFIGURED");
    await deliver(formatPaymentAlert(newIssues, now()));
    const sentAt = now().toISOString();
    for (const issue of newIssues) state.sent[issue.fingerprint] = sentAt;
    saveState(stateFile, state);
  }
  return { scanned, issues: issues.length, newIssues: newIssues.length, sent: !dryRun && newIssues.length > 0 };
}
