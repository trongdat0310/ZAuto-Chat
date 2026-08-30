import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
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
// PATH
// ========================================

function getUserDir(userId) {
  return path.join(
    rootPath,
    String(userId)
  );
}


function getDevicesPath(userId) {
  return path.join(
    getUserDir(userId),
    "devices.json"
  );
}


// ========================================
// READ
// ========================================

function readUserDevices(userId) {
  const filePath =
    getDevicesPath(userId);


  if (!fs.existsSync(filePath)) {
    return [];
  }


  try {
    const data =
      JSON.parse(
        fs.readFileSync(
          filePath,
          "utf-8"
        )
      );


    return Array.isArray(data)
      ? data
      : [];

  } catch (error) {

    console.error(
      "[USER DEVICES] READ ERROR:",
      userId,
      error
    );


    return [];
  }
}


// ========================================
// WRITE
// ========================================

function writeUserDevices(
  userId,
  devices
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
    getDevicesPath(userId),

    JSON.stringify(
      devices,
      null,
      2
    ),

    "utf-8"
  );
}


// ========================================
// REMOVE TOKEN FROM OTHER USERS
// Quan trong neu cung 1 dien thoai
// dang nhap tai khoan khac.
// ========================================

function removeTokenFromOtherUsers(
  ownerUserId,
  token
) {
  if (!fs.existsSync(rootPath)) {
    return;
  }


  const directories =
    fs.readdirSync(
      rootPath,
      {
        withFileTypes: true,
      }
    );


  for (const directory of directories) {

    if (!directory.isDirectory()) {
      continue;
    }


    const otherUserId =
      directory.name;


    if (
      otherUserId ===
      String(ownerUserId)
    ) {
      continue;
    }


    const devices =
      readUserDevices(
        otherUserId
      );


    const next =
      devices.filter(
        device =>
          device.token !== token
      );


    if (
      next.length !==
      devices.length
    ) {
      writeUserDevices(
        otherUserId,
        next
      );


      console.log(
        "[USER DEVICES] TOKEN MOVED:",
        otherUserId,
        "->",
        ownerUserId
      );
    }
  }
}


// ========================================
// REGISTER
// ========================================

export function registerUserDevice(
  userId,
  {
    token,
    platform = "unknown",
  }
) {
  const key =
    String(userId);


  removeTokenFromOtherUsers(
    key,
    token
  );


  const devices =
    readUserDevices(key);


  const existing =
    devices.find(
      device =>
        device.token === token
    );


  const now =
    new Date().toISOString();


  if (existing) {
    existing.platform =
      platform;

    existing.enabled =
      true;

    existing.updatedAt =
      now;


    writeUserDevices(
      key,
      devices
    );


    console.log(
      "[USER DEVICES] UPDATED:",
      key,
      existing.id
    );


    return existing;
  }


  const device = {
    id:
      crypto.randomUUID(),

    token,

    platform,

    enabled:
      true,

    createdAt:
      now,

    updatedAt:
      now,
  };


  devices.push(device);


  writeUserDevices(
    key,
    devices
  );


  console.log(
    "[USER DEVICES] REGISTERED:",
    key,
    device.id
  );


  return device;
}


// ========================================
// UNREGISTER
// ========================================

export function unregisterUserDevice(
  userId,
  token
) {
  const key =
    String(userId);


  const devices =
    readUserDevices(key);


  const next =
    devices.filter(
      device =>
        device.token !== token
    );


  const removed =
    next.length !==
    devices.length;


  if (removed) {
    writeUserDevices(
      key,
      next
    );


    console.log(
      "[USER DEVICES] UNREGISTERED:",
      key
    );
  }


  return removed;
}


// ========================================
// ENABLED DEVICES
// Backend push se dung ham nay.
// ========================================

export function getEnabledUserDevices(
  userId
) {
  return readUserDevices(
    userId
  ).filter(
    device =>
      device.enabled === true &&
      typeof device.token ===
        "string" &&
      device.token.length > 10
  );
}


// ========================================
// PUBLIC LIST
// Khong tra full FCM token ve app.
// ========================================

export function getPublicUserDevices(
  userId
) {
  return readUserDevices(
    userId
  ).map(
    device => ({
      id:
        device.id,

      platform:
        device.platform,

      enabled:
        device.enabled,

      tokenEnding:
        device.token
          ?.slice(-6) ??
        null,

      createdAt:
        device.createdAt,

      updatedAt:
        device.updatedAt,
    })
  );
}