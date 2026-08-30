import {
  firebaseMessaging,
} from "./firebase-admin.js";

import {
  getEnabledDevices,
} from "../devices/device-store.js";


// ========================================
// NEW TRIP PUSH
// ========================================

export async function sendNewTripPush(
  trip
) {
  const devices =
    getEnabledDevices();


  if (devices.length === 0) {
    console.log(
      "[PUSH] Khong co device nao."
    );

    return;
  }


  const tokens =
    devices.map(
      device => device.token
    );


  const title =
    "🚕 CUỐC MỚI";


  const body =
    trip.groupName
      ? `${trip.groupName}: ${trip.content}`
      : trip.content;


  console.log(
    `[PUSH] Sending to ${tokens.length} device(s)`
  );


  const messaging =
    firebaseMessaging();


  const result =
    await messaging.sendEachForMulticast({
      tokens,

      data: {
        type: "new_trip",

        messageId:
          String(
            trip.id ?? ""
          ),

        groupId:
          String(
            trip.groupId ?? ""
          ),

        groupName:
          String(
            trip.groupName ?? ""
          ),

        senderName:
          String(
            trip.senderName ?? ""
          ),

        content:
          String(
            trip.content ?? ""
          ),
      },

      android: {
        priority: "high",
      },

      apns: {
        headers: {
          "apns-priority": "10",
        },

        payload: {
          aps: {
            alert: {
              title:
                  "🚕 CUỐC MỚI",

              body,
            },

            sound:
                "default",

            category:
                "TRIP_ACTIONS",
          },
        },
      },
    });


  console.log(
    "[PUSH] Success:",
    result.successCount
  );

  console.log(
    "[PUSH] Failure:",
    result.failureCount
  );


  if (
    result.failureCount > 0
  ) {
    result.responses
      .forEach(
        (
          response,
          index
        ) => {

          if (!response.success) {
            console.error(
              "[PUSH] Failed token:",
              tokens[index]
            );

            console.error(
              response.error
            );
          }
        }
      );
  }
}