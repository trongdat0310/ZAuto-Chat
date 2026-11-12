import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Only Zalo-derived state for one app account. In particular, devices.json
// stays: it belongs to the app account, not to the linked Zalo identity.
// Subscription usage, payment and audit records live outside this user folder.
export const ZALO_DATA_ENTRIES = Object.freeze([
  "zalo-session.enc.json",
  "zalo-session.json", // legacy credentials, if present
  "group-settings.json",
  "filter-settings.json",
  "filter-keywords.json",
  "message-settings.json",
  "messages.json",
  "conversations",
]);

const DATA_ROOT = fileURLToPath(new URL("../../data/user-data/", import.meta.url));
const TEMP_PREFIXES = Object.freeze(
  ZALO_DATA_ENTRIES.filter(name => name.endsWith(".json")).map(name => name + ".tmp-")
);

export function purgeUserZaloFiles(userId, { rootDir = DATA_ROOT } = {}) {
  const id = String(userId ?? "");
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id)) {
    throw Object.assign(new Error("Invalid user ID for Zalo cleanup."), {
      code: "INVALID_USER_ID",
    });
  }
  const root = path.resolve(rootDir);
  const dir = path.join(root, id);
  // No traversal through the user directory. Never follow a symlink to a
  // different account or location.
  if (path.dirname(dir) !== root) {
    throw new Error("Unsafe user data location.");
  }
  let stat;
  try {
    stat = fs.lstatSync(dir);
  } catch (error) {
    if (error.code === "ENOENT") return { deleted: [], preserved: [] };
    throw error;
  }
  if (!stat.isDirectory() || stat.isSymbolicLink()) {
    throw new Error("Unsafe user data directory.");
  }

  const deleted = [];
  const candidates = new Set(ZALO_DATA_ENTRIES);
  for (const entry of fs.readdirSync(dir)) {
    if (TEMP_PREFIXES.some(prefix => entry.startsWith(prefix))) {
      candidates.add(entry);
    }
  }

  for (const entry of candidates) {
    const target = path.join(dir, entry);
    try {
      const item = fs.lstatSync(target);
      // Constrain recursive removal to the one fixed conversations folder.
      if (item.isDirectory() && entry !== "conversations") {
        throw new Error("Unexpected directory in Zalo cleanup: " + entry);
      }
      fs.rmSync(target, { force: true, recursive: entry === "conversations" });
      deleted.push(entry);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }

  // Unknown files and devices.json are intentionally never removed.
  return {
    deleted,
    preserved: fs.readdirSync(dir),
  };
}
