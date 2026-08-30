import { ThreadType } from "zca-js";

import {
  getZaloApi,
} from "./connector.js";

import {
  isGroupEnabled,
  getCachedGroupName,
} from "./groups.js";

import {
  evaluateMessage,
} from "../filters/filter-engine.js";

import {
  saveMessage,
} from "../messages/message-store.js";

import {
  broadcastEvent,
} from "../realtime/ws-server.js";

import {
  sendNewTripPush,
} from "../push/push-service.js";

let listenerStarted = false;

// ========================================
// START REALTIME LISTENER
// ========================================

export function startZaloListener() {
  if (listenerStarted) {
    console.log(
      "[LISTENER] Listener da chay."
    );

    return;
  }

  const api = getZaloApi();

  if (!api) {
    throw new Error(
      "Khong the start listener vi Zalo chua ket noi."
    );
  }


  // ========================================
  // CONNECTED
  // ========================================

  api.listener.on(
    "connected",
    () => {
      console.log(
        "[LISTENER] CONNECTED"
      );
    }
  );


  // ========================================
  // ERROR
  // ========================================

  api.listener.on(
    "error",
    (error) => {
      console.error(
        "[LISTENER] ERROR:"
      );

      console.error(error);
    }
  );


  // ========================================
  // MESSAGE
  // ========================================

  api.listener.on(
    "message",
    (message) => {

      // Chi quan tam group
      if (
        message.type !== ThreadType.Group
      ) {
        return;
      }


      // Bo qua tin cua chinh minh
      if (message.isSelf) {
        return;
      }


      const groupId =
        String(message.threadId);


      // ========================================
      // KIEM TRA GROUP CO DUOC BAT KHONG
      // ========================================

      if (!isGroupEnabled(groupId)) {

        console.log(
          `[LISTENER] IGNORE GROUP: ${groupId}`
        );

        return;
      }


      const content =
        message.data?.content;


      // Tam thoi chi xu ly text
      if (typeof content !== "string") {

        console.log("");
        console.log(
          "[LISTENER] NON-TEXT MESSAGE"
        );

        console.log(
          "Group ID:",
          groupId
        );

        return;
      }

      const filterResult =
        evaluateMessage(content);

      if (!filterResult.matched) {
        console.log(
          `[FILTER] REJECTED: ${content}`
        );

        console.log(
          `[FILTER] Reason: ${filterResult.reason}`
        );

        if (filterResult.keyword) {
          console.log(
            `[FILTER] Keyword: ${filterResult.keyword}`
          );
        }

        return;
      }

      const senderId =
        message.data?.uidFrom ??
        message.data?.senderId ??
        null;


      const senderName =
        message.data?.dName ??
        message.data?.senderName ??
        null;


      const groupName =
        getCachedGroupName(groupId);


      const savedMessage =
        saveMessage({
          groupId,

          groupName,

          senderId,

          senderName,

          zaloMessageId:
            message.data?.msgId ??
            message.msgId ??
            null,

          clientMessageId:
            message.data?.cliMsgId ??
            null,

          sourceTimestamp:
            message.data?.ts ??
            null,

          content,
        });

      broadcastEvent(
        "new_trip",
        savedMessage
      );

      sendNewTripPush(
        savedMessage
      ).catch(
        error => {
          console.error(
            "[PUSH] SEND ERROR:"
          );

          console.error(error);
        }
      );

      // ========================================
      // MESSAGE DUOC CHAP NHAN
      // ========================================

      console.log("");
      console.log(
        "================================"
      );

      console.log(
        "       MESSAGE ACCEPTED"
      );

      console.log(
        "================================"
      );

      console.log(
        "Internal ID:",
        savedMessage.id
      );

      console.log(
        "Filter:",
        filterResult.reason
      );

      if (filterResult.keyword) {
        console.log(
          "Matched keyword:",
          filterResult.keyword
        );
      }

      console.log(
        "Group ID:",
        groupId
      );

      console.log(
        "Group:",
        groupName
      );

      console.log(
        "Sender:",
        senderName ?? senderId
      );

      console.log(
        "Noi dung:",
        content
      );

      console.log(
        "Thoi gian:",
        new Date().toLocaleString()
      );

      console.log(
        "================================"
      );

      console.log("");
    }
  );


  // ========================================
  // START
  // ========================================

  api.listener.start();

  listenerStarted = true;

  console.log(
    "[LISTENER] Dang cho tin nhan..."
  );
}