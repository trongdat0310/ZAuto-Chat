import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const __filename =
  fileURLToPath(import.meta.url);

const __dirname =
  path.dirname(__filename);

const devicesPath =
  path.resolve(
    __dirname,
    "../../data/devices.json"
  );


// ========================================
// READ
// ========================================

function readDevices() {
  if (!fs.existsSync(devicesPath)) {
    return [];
  }

  try {
    const data =
      JSON.parse(
        fs.readFileSync(
          devicesPath,
          "utf-8"
        )
      );

    return Array.isArray(data)
        ? data
        : [];

  } catch (error) {
    console.error(
      "[DEVICES] Khong doc duoc devices.json"
    );

    return [];
  }
}


// ========================================
// WRITE
// ========================================

function writeDevices(devices) {
  fs.writeFileSync(
    devicesPath,
    JSON.stringify(
      devices,
      null,
      2
    ),
    "utf-8"
  );
}


// ========================================
// REGISTER
// ========================================

export function registerDevice({
  token,
  platform = "unknown",
}) {
  const devices =
    readDevices();

  const existed =
    devices.find(
      item =>
        item.token === token
    );


  if (existed) {
    existed.platform =
        platform;

    existed.enabled =
        true;

    existed.updatedAt =
        new Date().toISOString();

    writeDevices(devices);

    return existed;
  }


  const device = {
    id:
      crypto.randomUUID(),

    token,

    platform,

    enabled: true,

    createdAt:
      new Date().toISOString(),

    updatedAt:
      new Date().toISOString(),
  };


  devices.push(device);

  writeDevices(devices);

  console.log(
    "[DEVICES] REGISTERED:",
    device.id
  );

  return device;
}


// ========================================
// GET ENABLED TOKENS
// ========================================

export function getEnabledDevices() {
  return readDevices()
      .filter(
        device =>
          device.enabled === true &&
          typeof device.token ===
            "string" &&
          device.token.length > 0
      );
}