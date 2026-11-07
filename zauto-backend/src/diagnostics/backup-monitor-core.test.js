import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { inspectBackupHealth, runBackupAlert, formatBackupEmail } from "./backup-monitor-core.js";

const now = new Date("2026-11-07T14:00:00.000Z");
const archive = "backend-20261107-030015.tar.gz";
const services = { local: { loadState: "loaded", result: "success" },
  offsite: { loadState: "loaded", result: "success" } };
async function withDir(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zchat-backup-alert-"));
  try { await fn(dir); } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
function healthyDir(dir) {
  const backups = path.join(dir, "backups");
  fs.mkdirSync(backups);
  const file = path.join(backups, archive);
  fs.writeFileSync(file, "some archive");
  const mtime = new Date("2026-11-07T10:00:00.000Z");
  fs.utimesSync(file, mtime, mtime);
  const marker = path.join(dir, "offsite.json");
  fs.writeFileSync(marker, JSON.stringify({ version: 1, archive,
    completedAt: "2026-11-07T10:20:00.000Z" }));
  return { localDir: backups, offsiteMarker: marker, serviceResults: services, now };
}

test("fresh offsite and local archive yield no issues", () => withDir(async dir => {
  assert.deepEqual(inspectBackupHealth(healthyDir(dir)).issues, []);
}));

test("missing archive and offsite state are reported without crashing", () => withDir(async dir => {
  const result = inspectBackupHealth({ localDir: path.join(dir, "missing"),
    offsiteMarker: path.join(dir, "absent"), serviceResults: services, now });
  assert.deepEqual(result.issues.map(x => x.code),
    ["LOCAL_BACKUP_UNREADABLE", "LOCAL_BACKUP_MISSING", "OFFSITE_BACKUP_MISSING"]);
}));

test("outdated local archive and offsite marker are both reported", () => withDir(async dir => {
  const opts = healthyDir(dir);
  const old = new Date("2026-11-04T10:00:00.000Z");
  fs.utimesSync(path.join(opts.localDir, archive), old, old);
  fs.writeFileSync(opts.offsiteMarker, JSON.stringify({ version: 1, archive,
    completedAt: old.toISOString() }));
  assert.deepEqual(inspectBackupHealth(opts).issues.map(x => x.code),
    ["LOCAL_BACKUP_STALE", "OFFSITE_BACKUP_STALE"]);
}));

test("offsite missing latest archive is flagged after grace period", () => withDir(async dir => {
  const opts = healthyDir(dir);
  fs.writeFileSync(opts.offsiteMarker, JSON.stringify({ version: 1,
    archive: "backend-20261106-030015.tar.gz", completedAt: "2026-11-07T10:20:00.000Z" }));
  assert.deepEqual(inspectBackupHealth(opts).issues.map(x => x.code), ["OFFSITE_BACKUP_BEHIND"]);
}));

test("systemd backup unit exit-code causes immediate alert", () => withDir(async dir => {
  const opts = healthyDir(dir);
  opts.serviceResults = { ...services, local: { loadState: "loaded", result: "exit-code" } };
  assert.deepEqual(inspectBackupHealth(opts).issues.map(x => x.code), ["LOCAL_BACKUP_SERVICE_FAILED"]);
}));

test("one alert per incident, no duplicates, with recovery email", () => withDir(async dir => {
  const messages = [], stateFile = path.join(dir, "state.json");
  const issue = [{ code: "OFFSITE_BACKUP_SERVICE_FAILED", detail: "result=exit-code" }];
  const opts = { issues: issue, stateFile, now, deliver: async msg => { messages.push(msg); } };
  assert.equal((await runBackupAlert(opts)).sent, true);
  assert.equal((await runBackupAlert(opts)).sent, false);
  assert.equal(messages.length, 1);
  assert.match(messages[0].text, /OFFSITE_BACKUP_SERVICE_FAILED/);
  assert.equal(fs.statSync(stateFile).mode & 0o777, 0o600);
  assert.equal((await runBackupAlert({ ...opts, issues: [] })).sent, true);
  assert.equal(messages.length, 2);
  assert.match(messages[1].subject, /Đã khôi phục/);
  assert.equal((await runBackupAlert({ ...opts, issues: [] })).sent, false);
  assert.equal((await runBackupAlert(opts)).sent, true);
  assert.equal(messages.length, 3);
}));

test("persistent outage only reminds once per 24 hours", () => withDir(async dir => {
  const stateFile = path.join(dir, "state.json");
  let sent = 0;
  const base = { issues: [{ code: "LOCAL_BACKUP_STALE", detail: "too old" }],
    stateFile, deliver: async () => { sent++; } };
  await runBackupAlert({ ...base, now });
  await runBackupAlert({ ...base, now: new Date(+now + 23 * 3600000) });
  await runBackupAlert({ ...base, now: new Date(+now + 24 * 3600000) });
  assert.equal(sent, 2);
}));

test("SMTP failure does not acknowledge incident", () => withDir(async dir => {
  const stateFile = path.join(dir, "state.json");
  const opts = { issues: [{ code: "LOCAL_BACKUP_STALE", detail: "too old" }], stateFile, now };
  await assert.rejects(runBackupAlert({ ...opts, deliver: async () => { throw new Error("SMTP_FAIL"); } }), /SMTP_FAIL/);
  assert.equal(fs.existsSync(stateFile), false);
  assert.equal((await runBackupAlert({ ...opts, deliver: async () => {} })).sent, true);
}));

test("dry-run never sends or persists", () => withDir(async dir => {
  const stateFile = path.join(dir, "state.json");
  const result = await runBackupAlert({ stateFile, now,
    issues: [{ code: "LOCAL_BACKUP_STALE", detail: "too old" }], dryRun: true,
    deliver: async () => { throw new Error("should not send"); } });
  assert.equal(result.newOrReminder, 1);
  assert.equal(result.sent, false);
  assert.equal(fs.existsSync(stateFile), false);
}));

test("corrupted state is never silently reset", () => withDir(async dir => {
  const stateFile = path.join(dir, "state.json");
  fs.writeFileSync(stateFile, "invalid-json");
  await assert.rejects(runBackupAlert({ issues: [], stateFile, now,
    deliver: async () => {} }), SyntaxError);
}));

test("alert email contains error codes without secrets", () => {
  const mail = formatBackupEmail({ newIssues: [{ code: "OFFSITE_BACKUP_STALE", detail: "26 hours" }],
    recovered: [], now });
  assert.match(mail.text, /OFFSITE_BACKUP_STALE/);
  assert.match(mail.subject, /Backup/);
  assert.doesNotMatch(mail.text, /AWS_SECRET_ACCESS_KEY/);
});
