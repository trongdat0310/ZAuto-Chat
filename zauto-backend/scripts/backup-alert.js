import "dotenv/config";
import { execFileSync } from "node:child_process";
import nodemailer from "nodemailer";
import { inspectBackupHealth, runBackupAlert } from "../src/diagnostics/backup-monitor-core.js";

const args = process.argv.slice(2);
if (args.length > 1 || args.some(arg => !["--dry-run", "--test-email"].includes(arg))) {
  throw new Error("Usage: node scripts/backup-alert.js [--dry-run | --test-email]");
}
const dryRun = args.includes("--dry-run");
const testEmail = args.includes("--test-email");
const stateFile = process.env.BACKUP_ALERT_STATE_FILE ||
  "/var/lib/zchatauto-backups/backup-alert-state.json";
const offsiteMarker = process.env.ZCHATAUTO_OFFSITE_MARKER ||
  "/var/lib/zchatauto-backups/offsite-last-success.json";

function statusOf(unit) {
  try {
    const lines = execFileSync("/usr/bin/systemctl",
      ["show", "--property=LoadState,Result", unit],
      { encoding: "utf8", timeout: 10000 }).trim().split("\n");
    const props = Object.fromEntries(lines.map(line => line.split("=", 2)));
    return { loadState: props.LoadState || "unknown", result: props.Result || "unknown" };
  } catch {
    return { loadState: "unknown", result: "query-failed" };
  }
}

function mailSettings() {
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_FROM,
    BACKUP_ALERT_TO, PAYMENT_ALERT_TO } = process.env;
  const port = Number(SMTP_PORT || 587);
  const to = BACKUP_ALERT_TO || PAYMENT_ALERT_TO;
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASSWORD || !SMTP_FROM ||
      !to || !/^[^\s@,]+@[^\s@,]+\.[^\s@,]+$/.test(to) ||
      !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("BACKUP_ALERT_MAIL_NOT_CONFIGURED: check SMTP_* and BACKUP_ALERT_TO");
  }
  return { from: SMTP_FROM, to,
    transport: { host: SMTP_HOST, port, secure: port === 465,
      requireTLS: port !== 465,
      auth: { user: SMTP_USER, pass: SMTP_PASSWORD },
      connectionTimeout: 15000, greetingTimeout: 15000, socketTimeout: 30000 } };
}

const mail = dryRun ? null : mailSettings();
async function deliver(message) {
  const transport = nodemailer.createTransport(mail.transport);
  try {
    const result = await transport.sendMail({ from: mail.from, to: mail.to, ...message });
    if (!result.accepted?.length) throw new Error("BACKUP_ALERT_SMTP_NOT_ACCEPTED");
  } finally { transport.close(); }
}

if (testEmail) {
  await deliver({ subject: "[zchatauto][Backup] TEST cảnh báo sao lưu",
    text: "Đây là email kiểm tra SMTP. Không thay đổi dữ liệu backup hay trạng thái cảnh báo." });
  console.log("[BACKUP_ALERT] TEST EMAIL ACCEPTED by SMTP");
} else {
  const serviceResults = {
    local: statusOf("zchatauto-backup.service"),
    offsite: statusOf("zchatauto-offsite-backup.service"),
  };
  const health = inspectBackupHealth({ serviceResults, offsiteMarker });
  const result = await runBackupAlert({ issues: health.issues, stateFile, deliver, dryRun });
  console.log("[BACKUP_ALERT] issues=" + result.issues + " newOrReminder=" + result.newOrReminder +
    " recovered=" + result.recovered + " sent=" + result.sent + " dryRun=" + dryRun);
  for (const issue of health.issues) console.log("[BACKUP_ALERT] " + issue.code + ": " + issue.detail);
}
