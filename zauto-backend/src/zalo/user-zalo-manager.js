import {
  Zalo,
} from "zca-js";

import {
  loadUserZaloSession,
} from "./user-zalo-store.js";


const connections =
  new Map();


// ========================================
// CONNECT USER ZALO
// ========================================

export async function connectUserZalo(
  userId
) {
  const key =
    String(userId);


  const existing =
    connections.get(key);


  if (
    existing?.connected === true &&
    existing.api
  ) {
    return existing.api;
  }


  const credentials =
    loadUserZaloSession(
      key
    );


  if (!credentials) {
    const error =
      new Error(
        "Tai khoan chua lien ket Zalo."
      );

    error.code =
      "ZALO_NOT_LINKED";

    throw error;
  }


  console.log(
    "[USER ZALO] Connecting:",
    key
  );


  const zalo =
    new Zalo({
      selfListen: true,
      checkUpdate: false,
    });


  try {

    const api =
      await zalo.login(
        credentials
      );


    const ownId =
      String(
        api.getOwnId()
      );


    connections.set(
      key,
      {
        zalo,
        api,

        connected: true,

        ownId,

        connectedAt:
          new Date().toISOString(),

        lastError: null,
      }
    );


    console.log(
      "[USER ZALO] CONNECTED:",
      key,
      "->",
      ownId
    );


    return api;

  } catch (error) {

    connections.set(
      key,
      {
        zalo: null,
        api: null,

        connected: false,

        ownId: null,

        connectedAt: null,

        lastError:
          error?.message ??
          String(error),
      }
    );


    console.error(
      "[USER ZALO] CONNECT FAILED:",
      key,
      error
    );


    throw error;
  }
}


// ========================================
// GET API
// ========================================

export function getUserZaloApi(
  userId
) {
  return (
    connections.get(
      String(userId)
    )?.api ??
    null
  );
}


// ========================================
// STATUS
// ========================================

export function getUserZaloStatus(
  userId
) {
  const connection =
    connections.get(
      String(userId)
    );


  if (!connection) {
    return {
      connected: false,
      ownId: null,
      lastError: null,
    };
  }


  return {
    connected:
      connection.connected ===
      true,

    ownId:
      connection.ownId ??
      null,

    connectedAt:
      connection.connectedAt ??
      null,

    lastError:
      connection.lastError ??
      null,
  };
}

// ========================================
// CLEAR USER ZALO CONNECTION CACHE
// ========================================

export function clearUserZaloConnection(
  userId
) {
  const key =
    String(userId);

  const existed =
    connections.delete(key);

  console.log(
    "[USER ZALO] CONNECTION CACHE CLEARED:",
    key,
    existed
  );

  return existed;
}