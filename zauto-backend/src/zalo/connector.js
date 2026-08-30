import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Zalo } from "zca-js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const credentialsPath = path.resolve(
  __dirname,
  "../../data/credentials.json"
);

let api = null;
let connected = false;
let ownId = null;
let lastError = null;

export async function connectZalo() {
  try {
    console.log("[ZALO] Dang khoi dong connector...");

    if (!fs.existsSync(credentialsPath)) {
      throw new Error(
        "Khong tim thay data/credentials.json"
      );
    }

    const credentials = JSON.parse(
      fs.readFileSync(credentialsPath, "utf-8")
    );

    const zalo = new Zalo({
      selfListen: false,
      checkUpdate: true,
    });

    api = await zalo.login(credentials);

    ownId = api.getOwnId();
    connected = true;
    lastError = null;

    console.log("[ZALO] LOGIN SUCCESS");
    console.log("[ZALO] User ID:", ownId);

    return api;
  } catch (error) {
    connected = false;
    api = null;
    lastError = error?.message ?? String(error);

    console.error("[ZALO] LOGIN FAILED");
    console.error(error);

    throw error;
  }
}

export function getZaloApi() {
  return api;
}

export function getZaloStatus() {
  return {
    connected,
    ownId,
    lastError,
  };
}