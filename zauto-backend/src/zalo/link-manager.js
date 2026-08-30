import {
  Zalo,
  LoginQRCallbackEventType,
} from "zca-js";

import {
  updateUser,
} from "../users/user-store.js";

import {
  saveUserZaloSession,
} from "./user-zalo-store.js";

import {
  startUserWorker,
} from "../workers/user-worker-manager.js";


const linkJobs =
  new Map();


function publicStatus(job) {
  if (!job) {
    return {
      status: "idle",
    };
  }

  return {
    status:
      job.status,

    qrBase64:
      job.qrBase64 ??
      null,

    qrVersion:
      job.qrVersion ??
      0,

    scannedName:
      job.scannedName ??
      null,

    zaloUserId:
      job.zaloUserId ??
      null,

    error:
      job.error ??
      null,

    startedAt:
      job.startedAt,
  };
}


// ========================================
// START LINK
// ========================================

export function startZaloLink(
  user
) {
  const userId =
    String(user.id);


  const oldJob =
    linkJobs.get(userId);


  if (
    oldJob &&
    [
      "starting",
      "waiting_scan",
      "scanned",
      "refreshing",
    ].includes(
      oldJob.status
    )
  ) {
    oldJob.abort?.();
  }


  const job = {
    status:
      "starting",

    qrBase64:
      null,

    qrVersion:
      0,

    scannedName:
      null,

    zaloUserId:
      null,

    error:
      null,

    abort:
      null,

    startedAt:
      new Date().toISOString(),
  };


  linkJobs.set(
    userId,
    job
  );


  const zalo =
    new Zalo({
      selfListen: false,

      // Khong can check npm update
      // moi lan user link.
      checkUpdate: false,
    });


  // Chay background.
  // Endpoint HTTP khong phai cho
  // den khi user scan xong.
  (async () => {
    try {

      const api =
        await zalo.loginQR(
          {
            language:
              "vi",
          },

          (event) => {

            // ========================================
            // QR GENERATED
            // ========================================

            if (
              event.type ===
              LoginQRCallbackEventType
                .QRCodeGenerated
            ) {
              job.status =
                "waiting_scan";

              job.qrBase64 =
                event.data.image;

              job.qrVersion +=
                1;

              job.error =
                null;

              job.abort =
                event.actions.abort;

              console.log(
                "[ZALO LINK] QR GENERATED:",
                userId
              );

              return;
            }


            // ========================================
            // QR SCANNED
            // ========================================

            if (
              event.type ===
              LoginQRCallbackEventType
                .QRCodeScanned
            ) {
              job.status =
                "scanned";

              job.scannedName =
                event.data
                  .display_name;

              job.abort =
                event.actions.abort;

              console.log(
                "[ZALO LINK] QR SCANNED:",
                job.scannedName
              );

              return;
            }


            // ========================================
            // QR EXPIRED
            // ========================================

            if (
              event.type ===
              LoginQRCallbackEventType
                .QRCodeExpired
            ) {
              job.status =
                "refreshing";

              job.abort =
                event.actions.abort;

              console.log(
                "[ZALO LINK] QR EXPIRED -> REFRESH"
              );

              // zca-js cung cap action retry.
              event.actions.retry();

              return;
            }


            // ========================================
            // DECLINED
            // ========================================

            if (
              event.type ===
              LoginQRCallbackEventType
                .QRCodeDeclined
            ) {
              job.status =
                "declined";

              job.error =
                "Lien ket Zalo bi tu choi.";

              job.abort =
                event.actions.abort;

              event.actions.abort();

              return;
            }


            // ========================================
            // GOT SESSION
            // ========================================

            if (
              event.type ===
              LoginQRCallbackEventType
                .GotLoginInfo
            ) {
              saveUserZaloSession(
                userId,
                {
                  cookie:
                    event.data.cookie,

                  imei:
                    event.data.imei,

                  userAgent:
                    event.data
                      .userAgent,

                  language:
                    "vi",
                }
              );

              console.log(
                "[ZALO LINK] SESSION SAVED:",
                userId
              );
            }
          }
        );


      const zaloUserId =
        String(
          api.getOwnId()
        );


      job.zaloUserId =
        zaloUserId;

      job.status =
        "linked";

      job.qrBase64 =
        null;

      job.abort =
        null;


      updateUser(
        userId,
        {
          zaloLinked:
            true,

          zaloUserId,
        }
      );

      startUserWorker(
        userId
      ).catch(
        error => {

          console.error(
            "[ZALO LINK] WORKER START ERROR:",
            userId,
            error
          );
        }
      );

      console.log(
        "[ZALO LINK] SUCCESS:",
        userId,
        "->",
        zaloUserId
      );

    } catch (error) {

      if (
        job.status ===
          "declined" ||
        job.status ===
          "cancelled"
      ) {
        return;
      }


      job.status =
        "error";

      job.error =
        error?.message ??
        String(error);


      console.error(
        "[ZALO LINK] ERROR:",
        userId,
        error
      );
    }
  })();


  return publicStatus(job);
}


// ========================================
// GET STATUS
// ========================================

export function getZaloLinkStatus(
  userId
) {
  return publicStatus(
    linkJobs.get(
      String(userId)
    )
  );
}


// ========================================
// CANCEL
// ========================================

export function cancelZaloLink(
  userId
) {
  const job =
    linkJobs.get(
      String(userId)
    );


  if (!job) {
    return {
      status:
        "idle",
    };
  }


  try {
    job.abort?.();
  } catch {
    // ignore
  }


  job.status =
    "cancelled";

  job.qrBase64 =
    null;

  job.abort =
    null;


  return publicStatus(job);
}