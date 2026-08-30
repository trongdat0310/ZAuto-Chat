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
  const filePath =
    getSettingsPath(userId);


  if (!fs.existsSync(filePath)) {
    return {};
  }


  try {
    const data =
      JSON.parse(
        fs.readFileSync(
          filePath,
          "utf-8"
        )
      );


    return (
      data &&
      typeof data === "object" &&
      !Array.isArray(data)
    )
      ? data
      : {};

  } catch (error) {

    console.error(
      "[USER GROUP SETTINGS] READ ERROR:",
      userId,
      error
    );


    return {};
  }
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