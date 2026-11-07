import fs from "node:fs";
import crypto from "node:crypto";
import path from "node:path";

const ARCHIVE = /^backend-\d{8}-\d{6}\.tar\.gz$/;
const MAX_AGE_MS = 26 * 60 * 60 * 1000;
const UPLOAD_GRACE_MS = 60 * 60 * 1000;
const REMINDER_MS = 24 * 60 * 60 * 1000;
const errorIssue = (code, detail) => ({ code, detail });

export function inspectBackupHealth({
  localDir = "/var/backups/zchatauto",
  offsiteMarker = "/var/lib/zchatauto-backups/offsite-last-success.json",
  serviceResults = {},
  now = new Date(),
  maxAgeMs = MAX_AGE_MS,
  uploadGraceMs = UPLOAD_GRACE_MS,
} = {}) {
  const issues = [];
  const time = +now;
  if (!Number.isFinite(time)) throw new Error("INVALID_TIME");
  let latest = null;
  try {
    for (const name of fs.readdirSync(localDir)) {
      if (!ARCHIVE.test(name)) continue;
      const stat = fs.lstatSync(path.join(localDir, name));
      if (!stat.isFile() || stat.isSymbolicLink()) continue;
      if (!latest || stat.mtimeMs > latest.mtimeMs) {
        latest = { name, mtimeMs: stat.mtimeMs, size: stat.size };
      }
    }
  } catch (error) {
    issues.push(errorIssue("LOCAL_BACKUP_UNREADABLE", error.code || "FS_ERROR"));
  }
  if (!latest) {
    issues.push(errorIssue("LOCAL_BACKUP_MISSING", "No backup archive found"));
  } else if (latest.size === 0 || latest.mtimeMs > time + 5 * 60_000 || time - latest.mtimeMs > maxAgeMs) {
    issues.push(errorIssue("LOCAL_BACKUP_STALE", "Newest local archive is empty or older than 26 hours"));
  }

  let offsite = null;
  try {
    const obj = JSON.parse(fs.readFileSync(offsiteMarker, "utf8"));
    if (obj?.version !== 1 || typeof obj.completedAt !== "string" ||
        !ARCHIVE.test(obj.archive || "") || !Number.isFinite(Date.parse(obj.completedAt))) {
      throw new Error("INVALID_MARKER");
    }
    offsite = { archive: obj.archive, completedAt: obj.completedAt };
    const offsiteMs = Date.parse(offsite.completedAt);
    if (offsiteMs > time + 5 * 60_000 || time - offsiteMs > maxAgeMs) {
      issues.push(errorIssue("OFFSITE_BACKUP_STALE", "Last successful R2 upload is older than 26 hours"));
    } else if (latest && latest.name !== offsite.archive && time - latest.mtimeMs >= uploadGraceMs) {
      issues.push(errorIssue("OFFSITE_BACKUP_BEHIND", "Latest local archive has not been uploaded to R2"));
    }
  } catch (error) {
    issues.push(errorIssue(error.code === "ENOENT" ? "OFFSITE_BACKUP_MISSING" : "OFFSITE_MARKER_INVALID",
      error.code || "INVALID_MARKER"));
  }

  for (const [key, code] of [
    ["local", "LOCAL_BACKUP_SERVICE_FAILED"],
    ["offsite", "OFFSITE_BACKUP_SERVICE_FAILED"],
  ]) {
    const unit = serviceResults[key];
    if (!unit || unit.loadState !== "loaded" || unit.result !== "success") {
      issues.push(errorIssue(code, "unit=" + (unit?.loadState || "unknown") + ", result=" + (unit?.result || "unknown")));
    }
  }
  return { issues, latest, offsite };
}

function readState(filename) {
  let raw;
  try { raw = fs.readFileSync(filename, "utf8"); }
  catch (error) {
    if (error.code === "ENOENT") return { version: 1, active: {} };
    throw error;
  }
  const obj = JSON.parse(raw);
  if (!obj || obj.version !== 1 || !obj.active || Array.isArray(obj.active) ||
      typeof obj.active !== "object") {
    throw new Error("BACKUP_ALERT_STATE_INVALID: do not delete existing alert state");
  }
  for (const entry of Object.values(obj.active)) {
    if (!entry || typeof entry.firstSeenAt !== "string" || typeof entry.lastSentAt !== "string" ||
        !Number.isFinite(Date.parse(entry.lastSentAt))) {
      throw new Error("BACKUP_ALERT_STATE_INVALID: malformed existing entries");
    }
  }
  return obj;
}

function saveState(filename, data) {
  const parent = path.dirname(filename);
  fs.mkdirSync(parent, { recursive: true, mode: 0o700 });
  const temp = filename + "." + crypto.randomUUID() + ".tmp";
  try {
    const fd = fs.openSync(temp, "wx", 0o600);
    try {
      fs.writeFileSync(fd, JSON.stringify(data, null, 2) + "\n");
      fs.fsyncSync(fd);
    } finally { fs.closeSync(fd); }
    fs.renameSync(temp, filename);
  } finally { fs.rmSync(temp, { force: true }); }
}

export function formatBackupEmail({ newIssues, recovered, now = new Date() }) {
  const title = newIssues.length ? "CẢNH BÁO SAO LƯU ZCHATAUTO" : "SAO LƯU ZCHATAUTO ĐÃ PHỤC HỒI";
  const subject = newIssues.length ? "[zchatauto][Backup] " + newIssues.length + " sự cố cần kiểm tra" :
    "[zchatauto][Backup] Đã khôi phục " + recovered.length + " sự cố";
  const time = now.toLocaleString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh" });
  return {
    subject,
    text: [title, "Thời gian (Việt Nam): " + time, "",
      ...(newIssues.length ? ["CÁC LỖI HIỆN TẠI:", ...newIssues.map(x =>
        "- " + x.code + ": " + x.detail), ""] : []),
      ...(recovered.length ? ["CÁC LỖI ĐÃ PHỤC HỒI:", ...recovered.map(x => "- " + x), ""] : []),
      "Kiểm tra: sudo systemctl status zchatauto-backup.service zchatauto-offsite-backup.service --no-pager",
      "Xem nhật ký: sudo journalctl -u zchatauto-offsite-backup.service -n 40 --no-pager",
      "Không xóa dữ liệu hoặc thay đổi cấu hình bảo mật khi chưa đối chiếu nguyên nhân.",
    ].join("\n"),
  };
}

// Persist after SMTP accepts the alert. A crash in between can produce one duplicate email.
export async function runBackupAlert({ issues, stateFile, deliver, now = new Date(),
  dryRun = false, reminderMs = REMINDER_MS }) {
  const time = +now;
  if (!Array.isArray(issues) || !Number.isFinite(time) || !stateFile) throw new Error("INVALID_BACKUP_ALERT_INPUT");
  const state = readState(stateFile);
  const current = new Map(issues.map(issue => [issue.code, issue]));
  if (current.size !== issues.length || issues.some(x => !/^[A-Z_]+$/.test(x.code))) {
    throw new Error("INVALID_BACKUP_ISSUES");
  }
  const recovered = Object.keys(state.active).filter(code => !current.has(code));
  const toSend = issues.filter(issue => {
    const previous = state.active[issue.code];
    return !previous || time - Date.parse(previous.lastSentAt) >= reminderMs;
  });
  const outcome = { issues: issues.length, newOrReminder: toSend.length, recovered: recovered.length,
    sent: false, dryRun };
  if (dryRun || (!toSend.length && !recovered.length)) return outcome;
  if (typeof deliver !== "function") throw new Error("BACKUP_ALERT_MAIL_NOT_CONFIGURED");
  await deliver(formatBackupEmail({ newIssues: toSend, recovered, now }));
  const sentAt = now.toISOString();
  for (const issue of toSend) {
    state.active[issue.code] = { firstSeenAt: state.active[issue.code]?.firstSeenAt || sentAt, lastSentAt: sentAt };
  }
  for (const code of recovered) delete state.active[code];
  saveState(stateFile, state);
  return { ...outcome, sent: true };
}
