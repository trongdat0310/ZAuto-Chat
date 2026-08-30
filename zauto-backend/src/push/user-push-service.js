import {
  firebaseMessaging,
} from "./firebase-admin.js";


import {
  getEnabledUserDevices,
} from "../devices/user-device-store.js";


// ========================================
// TEST PUSH
// ========================================

export async function sendUserTestPush(
  userId
) {
  const devices =
    getEnabledUserDevices(
      userId
    );


  if (devices.length === 0) {
    return {
      successCount: 0,
      failureCount: 0,
      noDevices: true,
    };
  }


  const tokens =
    devices.map(
      device =>
        device.token
    );


  const result =
    await firebaseMessaging()
      .sendEachForMulticast({
        tokens,

        notification: {
          title:
            "ZAUTO TEST",

          body:
            "Push notification riêng của tài khoản đã hoạt động.",
        },

        data: {
          type:
            "test_push",
        },
      });


  console.log(
    "[USER PUSH TEST]",
    userId,
    "Success:",
    result.successCount,
    "Failure:",
    result.failureCount
  );


  return {
    successCount:
      result.successCount,

    failureCount:
      result.failureCount,

    noDevices:
      false,
  };
}


// ========================================
// NEW TRIP PUSH
// Se dung o Realtime Worker sap toi.
// ========================================

export async function sendUserNewTripPush(
  userId,
  trip
) {
  const devices =
    getEnabledUserDevices(
      userId
    );


  if (devices.length === 0) {
    console.log(
      "[USER PUSH] No devices:",
      userId
    );

    return {
      successCount: 0,
      failureCount: 0,
    };
  }


  const tokens =
    devices.map(
      device =>
        device.token
    );


  const body =
    trip.groupName
      ? `${trip.groupName}: ${trip.content}`
      : String(
          trip.content ?? ""
        );


  const result =
    await firebaseMessaging()
      .sendEachForMulticast({
        tokens,

        data: {
          type:
            "new_trip",

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


        // Android:
        // Flutter background handler
        // se tao local notification.
        android: {
          priority:
            "high",
        },


        // iOS:
        // APNs hien notification.
        apns: {
          headers: {
            "apns-priority":
              "10",
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
    "[USER PUSH]",
    userId,
    "Success:",
    result.successCount,
    "Failure:",
    result.failureCount
  );


  return {
    successCount:
      result.successCount,

    failureCount:
      result.failureCount,
  };
}