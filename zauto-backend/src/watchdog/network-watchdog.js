import https from "node:https";


import {
  setWorkersNetworkAvailable,
  restartRecoverableUserWorkers,
} from "../workers/user-worker-manager.js";


// ========================================
// CONFIG
// ========================================

const CHECK_INTERVAL_MS =
  10000;

const PROBE_TIMEOUT_MS =
  4000;

const FAILURE_THRESHOLD =
  2;


// Chi can 1 dia chi truy cap duoc
// la xem nhu Internet dang online.
const PROBE_URLS = [
  "https://zalo.me",
  "https://www.google.com/generate_204",
  "https://www.cloudflare.com",
];


// ========================================
// STATE
// ========================================

let timer =
  null;

let checking =
  false;

let state =
  "unknown";

let consecutiveFailures =
  0;

let lastCheckAt =
  null;

let lastOnlineAt =
  null;

let lastOfflineAt =
  null;


// ========================================
// PROBE ONE URL
// ========================================

function probeUrl(
  url
) {
  return new Promise(
    resolve => {

      let settled =
        false;


      const finish =
        result => {

          if (settled) {
            return;
          }

          settled =
            true;

          resolve(
            result
          );
        };


      const request =
        https.request(
          url,
          {
            method:
              "HEAD",

            timeout:
              PROBE_TIMEOUT_MS,

            headers: {
              "User-Agent":
                "ZAuto-Network-Watchdog",
            },
          },

          response => {

            // Bat ky HTTP response nao
            // cung chung minh da ra Internet duoc.
            response.resume();

            finish(
              true
            );
          }
        );


      request.on(
        "timeout",

        () => {

          request.destroy();

          finish(
            false
          );
        }
      );


      request.on(
        "error",

        () => {

          finish(
            false
          );
        }
      );


      request.end();
    }
  );
}


// ========================================
// CHECK INTERNET
// ========================================

async function checkInternet() {

  for (
    const url
    of PROBE_URLS
  ) {

    const ok =
      await probeUrl(
        url
      );


    if (ok) {
      return true;
    }
  }


  return false;
}


// ========================================
// RUN ONE CHECK
// ========================================

async function runCheck() {

  if (checking) {
    return;
  }


  checking =
    true;


  try {

    lastCheckAt =
      new Date()
        .toISOString();


    const online =
      await checkInternet();


    // ========================================
    // ONLINE
    // ========================================

    if (online) {

      consecutiveFailures =
        0;

      lastOnlineAt =
        new Date()
          .toISOString();


      if (
        state ===
        "offline"
      ) {

        console.log("");
        console.log(
          "================================"
        );

        console.log(
          "[WATCHDOG] INTERNET RESTORED"
        );

        console.log(
          "================================"
        );


        state =
          "online";


        setWorkersNetworkAvailable(
          true
        );


        await restartRecoverableUserWorkers(
          "internet_restored"
        );


        return;
      }


      if (
        state ===
        "unknown"
      ) {

        state =
          "online";


        setWorkersNetworkAvailable(
          true
        );


        console.log(
          "[WATCHDOG] INTERNET ONLINE"
        );
      }


      return;
    }


    // ========================================
    // FAILED
    // ========================================

    consecutiveFailures +=
      1;


    console.warn(
      "[WATCHDOG] PROBE FAILED:",
      `${consecutiveFailures}/${FAILURE_THRESHOLD}`
    );


    // Khong danh offline chi vi
    // 1 request loi tam thoi.
    if (
      consecutiveFailures <
      FAILURE_THRESHOLD
    ) {
      return;
    }


    if (
      state !==
      "offline"
    ) {

      state =
        "offline";

      lastOfflineAt =
        new Date()
          .toISOString();


      console.log("");
      console.error(
        "================================"
      );

      console.error(
        "[WATCHDOG] INTERNET OFFLINE"
      );

      console.error(
        "================================"
      );


      setWorkersNetworkAvailable(
        false,
        "internet_offline"
      );
    }

  } catch (error) {

    console.error(
      "[WATCHDOG] ERROR:",
      error
    );

  } finally {

    checking =
      false;
  }
}


// ========================================
// START
// ========================================

export function startNetworkWatchdog() {

  if (timer) {

    console.log(
      "[WATCHDOG] Already running"
    );

    return;
  }


  console.log(
    "[WATCHDOG] Started:",
    `interval=${CHECK_INTERVAL_MS}ms`,
    `threshold=${FAILURE_THRESHOLD}`
  );


  // Check ngay lap tuc.
  void runCheck();


  timer =
    setInterval(
      () => {

        void runCheck();

      },
      CHECK_INTERVAL_MS
    );
}


// ========================================
// PUBLIC STATUS
// ========================================

export function getNetworkWatchdogStatus() {

  return {
    state,

    consecutiveFailures,

    failureThreshold:
      FAILURE_THRESHOLD,

    checkIntervalMs:
      CHECK_INTERVAL_MS,

    lastCheckAt,

    lastOnlineAt,

    lastOfflineAt,
  };
}