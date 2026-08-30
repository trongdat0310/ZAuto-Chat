import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

import {
  ZALO_SESSION_KEY,
} from "../config/env.js";


const __filename =
  fileURLToPath(import.meta.url);

const __dirname =
  path.dirname(__filename);

const rootPath =
  path.resolve(
    __dirname,
    "../../data/user-data"
  );

const encryptionKey =
  Buffer.from(
    ZALO_SESSION_KEY,
    "hex"
  );


function getUserDir(userId) {
  return path.join(
    rootPath,
    String(userId)
  );
}


function getSessionPath(userId) {
  return path.join(
    getUserDir(userId),
    "zalo-session.enc.json"
  );
}


// ========================================
// SAVE ENCRYPTED SESSION
// ========================================

export function saveUserZaloSession(
  userId,
  credentials
) {
  const userDir =
    getUserDir(userId);

  fs.mkdirSync(
    userDir,
    {
      recursive: true,
    }
  );


  const iv =
    crypto.randomBytes(12);


  const cipher =
    crypto.createCipheriv(
      "aes-256-gcm",
      encryptionKey,
      iv
    );


  const plainText =
    JSON.stringify(credentials);


  const encrypted =
    Buffer.concat([
      cipher.update(
        plainText,
        "utf8"
      ),

      cipher.final(),
    ]);


  const authTag =
    cipher.getAuthTag();


  const envelope = {
    version: 1,

    algorithm:
      "aes-256-gcm",

    iv:
      iv.toString("base64"),

    authTag:
      authTag.toString("base64"),

    data:
      encrypted.toString("base64"),
  };


  fs.writeFileSync(
    getSessionPath(userId),

    JSON.stringify(
      envelope,
      null,
      2
    ),

    "utf-8"
  );


  console.log(
    "[ZALO SESSION] SAVED:",
    userId
  );
}


// ========================================
// LOAD
// ========================================

export function loadUserZaloSession(
  userId
) {
  const filePath =
    getSessionPath(userId);


  if (!fs.existsSync(filePath)) {
    return null;
  }


  const envelope =
    JSON.parse(
      fs.readFileSync(
        filePath,
        "utf-8"
      )
    );


  const iv =
    Buffer.from(
      envelope.iv,
      "base64"
    );


  const authTag =
    Buffer.from(
      envelope.authTag,
      "base64"
    );


  const encrypted =
    Buffer.from(
      envelope.data,
      "base64"
    );


  const decipher =
    crypto.createDecipheriv(
      "aes-256-gcm",
      encryptionKey,
      iv
    );


  decipher.setAuthTag(
    authTag
  );


  const decrypted =
    Buffer.concat([
      decipher.update(
        encrypted
      ),

      decipher.final(),
    ]);


  return JSON.parse(
    decrypted.toString("utf8")
  );
}


// ========================================
// DELETE
// ========================================

export function deleteUserZaloSession(
  userId
) {
  const filePath =
    getSessionPath(userId);


  if (
    fs.existsSync(filePath)
  ) {
    fs.unlinkSync(filePath);
  }
}