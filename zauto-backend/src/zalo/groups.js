import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { getZaloApi } from "./connector.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const settingsPath = path.resolve(
  __dirname,
  "../../data/group-settings.json"
);

const groupCache = new Map();

// ========================================
// DOC CAI DAT GROUP
// ========================================

function readGroupSettings() {
  if (!fs.existsSync(settingsPath)) {
    return {};
  }

  try {
    return JSON.parse(
      fs.readFileSync(settingsPath, "utf-8")
    );
  } catch (error) {
    console.error(
      "[GROUPS] Khong doc duoc group-settings.json"
    );

    return {};
  }
}


// ========================================
// LUU CAI DAT GROUP
// ========================================

function saveGroupSettings(settings) {
  fs.writeFileSync(
    settingsPath,
    JSON.stringify(settings, null, 2),
    "utf-8"
  );
}


// ========================================
// LAY DANH SACH GROUP
// ========================================

export async function getGroups() {
  const api = getZaloApi();

  if (!api) {
    throw new Error("Zalo chua duoc ket noi.");
  }

  console.log("[GROUPS] Dang lay danh sach group...");

  const allGroups = await api.getAllGroups();

  const groupIds = Object.keys(
    allGroups?.gridVerMap ?? {}
  );

  if (groupIds.length === 0) {
    return [];
  }

  const groupInfoResponse =
    await api.getGroupInfo(groupIds);

  const settings = readGroupSettings();

  const groups = [];

  for (const groupId of groupIds) {
    const info =
      groupInfoResponse?.gridInfoMap?.[groupId];

    const group = {
      groupId,
      name: info?.name ?? "Unknown Group",
      totalMember: info?.totalMember ?? 0,
      enabled: settings[groupId]?.enabled ?? false,
    };

    groups.push(group);

    groupCache.set(
      String(groupId),
      group
    );
  }

  groups.sort((a, b) =>
    a.name.localeCompare(b.name, "vi")
  );

  console.log(
    `[GROUPS] Tim thay ${groups.length} group.`
  );

  return groups;
}


// ========================================
// BAT / TAT GROUP
// ========================================

export function setGroupEnabled(
  groupId,
  enabled
) {
  const settings = readGroupSettings();

  settings[groupId] = {
    ...(settings[groupId] ?? {}),
    enabled,
    updatedAt: new Date().toISOString(),
  };

  saveGroupSettings(settings);

  return {
    groupId,
    enabled,
  };
}

export function isGroupEnabled(groupId) {
  const settings = readGroupSettings();

  return settings[String(groupId)]?.enabled === true;
}

// ========================================
// GROUP CACHE
// ========================================

export function getCachedGroup(
  groupId
) {
  return (
    groupCache.get(
      String(groupId)
    ) ?? null
  );
}


export function getCachedGroupName(
  groupId
) {
  return (
    getCachedGroup(groupId)?.name ??
    "Unknown Group"
  );
}