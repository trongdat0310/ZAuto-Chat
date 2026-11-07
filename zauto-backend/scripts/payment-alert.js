import "dotenv/config";
import nodemailer from "nodemailer";
import { fileURLToPath } from "node:url";
import { subscriptionService } from "../src/subscriptions/subscription-service.js";
import { runPaymentAlerts } from "../src/payments/payment-alert-service.js";

const args = process.argv.slice(2);
if (args.some(arg => !["--dry-run", "--test-email"].includes(arg)) || args.length > 1) {
  throw new Error("Usage: node scripts/payment-alert.js [--dry-run | --test-email]");
}
const dryRun = args.includes("--dry-run");
const testEmail = args.includes("--test-email");
const stateFile = process.env.PAYMENT_ALERT_STATE_FILE ||
  fileURLToPath(new URL("../data/payment-alert-state.json", import.meta.url));

function smtpSettings() {
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_FROM, PAYMENT_ALERT_TO } = process.env;
  const port = Number(SMTP_PORT || 587);
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASSWORD || !SMTP_FROM ||
      !PAYMENT_ALERT_TO || !/^[^\s@,]+@[^\s@,]+\.[^\s@,]+$/.test(PAYMENT_ALERT_TO) ||
      !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("PAYMENT_ALERT_MAIL_NOT_CONFIGURED: check SMTP_* and PAYMENT_ALERT_TO");
  }
  return {
    from: SMTP_FROM,
    to: PAYMENT_ALERT_TO,
    transport: {
      host: SMTP_HOST, port, secure: port === 465,
      requireTLS: port !== 465,
      auth: { user: SMTP_USER, pass: SMTP_PASSWORD },
      connectionTimeout: 15000,
      greetingTimeout: 15000,
      socketTimeout: 30000,
    },
  };
}

const mail = dryRun ? null : smtpSettings();
const deliver = async message => {
  const transport = nodemailer.createTransport(mail.transport);
  try {
    const info = await transport.sendMail({ from: mail.from, to: mail.to, ...message });
    if (!info.accepted?.length) throw new Error("PAYMENT_ALERT_SMTP_NOT_ACCEPTED");
  } finally { transport.close(); }
};

if (testEmail) {
  await deliver({
    subject: "[zchatauto][SePay] TEST email canh bao",
    text: "Day la thu nghiem SMTP; khong co giao dich nao duoc thay doi va khong danh dau su co da gui.",
  });
  console.log("[PAYMENT_ALERT] TEST EMAIL ACCEPTED by SMTP");
} else {
  const result = await runPaymentAlerts({ store: subscriptionService, stateFile, deliver, dryRun });
  console.log("[PAYMENT_ALERT] scanned=" + result.scanned + " issues=" + result.issues +
    " new=" + result.newIssues + " sent=" + result.sent + " dryRun=" + dryRun);
}
