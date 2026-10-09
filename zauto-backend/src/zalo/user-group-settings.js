import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";


const __filename =
  fileURLToPath(import.meta.url);

const __dirname =
  path.dirname(__filename);


const rootPath =
  path.resolve(
    __dirname,
    "../../data/user-data"
  );


// ========================================
// RAM CACHE
//
// Group enabled check nam tren message hot path.
// Chi doc file lan dau moi user.
// ========================================

const settingsCache =
  new Map();


// ========================================
// FILE PATH
// ========================================

function getUserDir(userId) {
  return path.join(
    rootPath,
    String(userId)
  );
}


function getSettingsPath(userId) {
  return path.join(
    getUserDir(userId),
    "group-settings.json"
  );
}


// ========================================
// READ
// ========================================

export function readUserGroupSettings(
  userId
) {
  const key =
    String(
      userId
    );


  const cached =
    settingsCache.get(
      key
    );


  if (cached) {
    return cached;
  }


  const filePath =
    getSettingsPath(
      key
    );


  let settings =
    {};


  if (
    fs.existsSync(
      filePath
    )
  ) {
    try {
      const data =
        JSON.parse(
          fs.readFileSync(
            filePath,
            "utf-8"
          )
        );


      if (
        data &&
        typeof data === "object" &&
        !Array.isArray(
          data
        )
      ) {
        settings =
          data;
      }

    } catch (error) {

      console.error(
        "[USER GROUP SETTINGS] READ ERROR:",
        key,
        error
      );
    }
  }


  settingsCache.set(
    key,
    settings
  );


  return settings;
}


// ========================================
// WRITE
// ========================================

function writeUserGroupSettings(
  userId,
  settings
) {
  const userDir =
    getUserDir(userId);


  fs.mkdirSync(
    userDir,
    {
      recursive: true,
    }
  );


  fs.writeFileSync(
    getSettingsPath(userId),

    JSON.stringify(
      settings,
      null,
      2
    ),

    "utf-8"
  );


  settingsCache.set(
    String(
      userId
    ),
    settings
  );
}


// ========================================
// SET ENABLED
// ========================================

export function setUserGroupEnabled(
  userId,
  groupId,
  enabled
) {
  const settings =
    readUserGroupSettings(
      userId
    );


  const key =
    String(groupId);


  settings[key] = {
    ...(settings[key] ?? {}),

    enabled:
      enabled === true,

    updatedAt:
      new Date().toISOString(),
  };


  writeUserGroupSettings(
    userId,
    settings
  );


  console.log(
    "[USER GROUP SETTINGS]",
    userId,
    groupId,
    "=>",
    enabled
  );


  return {
    groupId: key,
    enabled:
      enabled === true,
  };
}


// ========================================
// CHECK ENABLED
// ========================================

export function isUserGroupEnabled(
  userId,
  groupId
) {
  const settings =
    readUserGroupSettings(
      userId
    );


  return (
    settings[
      String(groupId)
    ]?.enabled === true
  );
}
// Enable only the groups verified against the account's current Zalo list.
// Persist once so selecting many groups does not issue one write per group.
export function enableUserGroups(userId, groupIds = []) {
  const ids = [...new Set(groupIds.map(id => String(id ?? "").trim()).filter(Boolean))];
  if (ids.length === 0) return [];
  const settings = { ...readUserGroupSettings(userId) };
  const updatedAt = new Date().toISOString();
  for (const id of ids) {
    settings[id] = { ...(settings[id] ?? {}), enabled: true, updatedAt };
  }
  writeUserGroupSettings(userId, settings);
  return ids.map(groupId => ({ groupId, enabled: true }));
}
