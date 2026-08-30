import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  cert,
  getApps,
  initializeApp,
} from "firebase-admin/app";

import {
  getMessaging,
} from "firebase-admin/messaging";


const __filename =
  fileURLToPath(import.meta.url);

const __dirname =
  path.dirname(__filename);


const serviceAccountPath =
  path.resolve(
    __dirname,
    "../../data/firebase-service-account.json"
  );


let initialized = false;


// ========================================
// INITIALIZE
// ========================================

export function initFirebaseAdmin() {
  if (initialized) {
    return;
  }

  if (getApps().length > 0) {
    initialized = true;
    return;
  }


  if (
    !fs.existsSync(
      serviceAccountPath
    )
  ) {
    throw new Error(
      "Khong tim thay firebase-service-account.json"
    );
  }


  const serviceAccount =
    JSON.parse(
      fs.readFileSync(
        serviceAccountPath,
        "utf-8"
      )
    );


  initializeApp({
    credential:
      cert(serviceAccount),
  });


  initialized = true;

  console.log(
    "[FIREBASE] Admin initialized"
  );
}


export function firebaseMessaging() {
  if (!initialized) {
    initFirebaseAdmin();
  }

  return getMessaging();
}