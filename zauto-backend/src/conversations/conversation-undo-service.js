import {
  ThreadType,
} from "zca-js";

import {
  connectUserZalo,
} from "../zalo/user-zalo-manager.js";

import {
  findUserConversationMessage,
} from "./conversation-store.js";

// ========================================
// ZALO RECALL WINDOW
// ========================================

const RECALL_WINDOW_MS =
  60 * 60 * 1000;


function getMessageTimestampMs(
  message
) {

  const candidates = [
    message?.timestamp,
    message?.rawData?.ts,
    message?.rawData?.timestamp,
  ];


  for (
    const value
    of candidates
  ) {

    const parsed =
      Number(
        value
      );


    if (
      !Number.isFinite(
        parsed
      ) ||
      parsed <= 0
    ) {
      continue;
    }


    // ========================================
    // HO TRO CA:
    //
    // UNIX seconds:
    // 1720000000
    //
    // milliseconds:
    // 1720000000000
    // ========================================

    if (
      parsed <
      100000000000
    ) {

      return parsed *
        1000;
    }


    return parsed;
  }


  return null;
}


// ========================================
// UNDO / RECALL ONE ZALO GROUP MESSAGE
// ========================================

export async function
undoUserConversationMessage(
  userId,
  groupId,
  {
    msgId = null,
    cliMsgId = null,
  } = {}
) {

  const safeUserId =
    String(
      userId ??
      ""
    );


  const safeGroupId =
    String(
      groupId ??
      ""
    ).trim();


  const safeMsgId =
    msgId != null
      ? String(
          msgId
        ).trim()
      : "";


  const safeCliMsgId =
    cliMsgId != null
      ? String(
          cliMsgId
        ).trim()
      : "";


  // ========================================
  // VALIDATE
  // ========================================

  if (!safeUserId) {

    const error =
      new Error(
        "User khong hop le."
      );

    error.code =
      "INVALID_USER";

    throw error;
  }


  if (!safeGroupId) {

    const error =
      new Error(
        "Group khong hop le."
      );

    error.code =
      "INVALID_GROUP";

    throw error;
  }


  if (
    !safeMsgId &&
    !safeCliMsgId
  ) {

    const error =
      new Error(
        "Thieu ID tin nhan."
      );

    error.code =
      "MESSAGE_ID_REQUIRED";

    throw error;
  }


  // ========================================
  // TIM MESSAGE TRONG STORE CUA DUNG USER
  // VA DUNG GROUP
  // ========================================

  const target =
    findUserConversationMessage(
      safeUserId,
      safeGroupId,
      {
        msgId:
          safeMsgId ||
          null,

        cliMsgId:
          safeCliMsgId ||
          null,
      }
    );


  if (!target) {

    const error =
      new Error(
        "Khong tim thay tin nhan."
      );

    error.code =
      "MESSAGE_NOT_FOUND";

    throw error;
  }


  // ========================================
  // NEU DA RECALL ROI
  // THI COI NHU THANH CONG
  // ========================================

  if (
    target.status ===
    "recalled"
  ) {

    return {
      alreadyRecalled:
        true,

      message:
        target,

      zaloResult:
        null,
    };
  }


  // ========================================
  // CHI TIN BINH THUONG MOI THU HOI
  // ========================================

  if (
    target.status !==
    "normal"
  ) {

    const error =
      new Error(
        "Tin nhan nay khong con co the thu hoi."
      );

    error.code =
      "MESSAGE_UNAVAILABLE";

    throw error;
  }


  // ========================================
  // CHI DUOC THU HOI TIN CUA CHINH ACCOUNT
  // ========================================

  if (
    target.isSelf !==
    true
  ) {

    const error =
      new Error(
        "Chi co the thu hoi tin nhan cua ban."
      );

    error.code =
      "NOT_OWN_MESSAGE";

    throw error;
  }

  // ========================================
  // KIEM TRA THOI HAN THU HOI
  // ========================================

  const targetTimestampMs =
    getMessageTimestampMs(
      target
    );


  if (
    targetTimestampMs != null
  ) {

    const ageMs =
      Date.now() -
      targetTimestampMs;


    // Neu timestamp nam trong tuong lai
    // do lech clock thi khong block.
    if (
      ageMs >=
      RECALL_WINDOW_MS
    ) {

      const error =
        new Error(
          "Bạn chỉ có thể thu hồi tin nhắn trong 1 giờ sau khi gửi."
        );

      error.code =
        "RECALL_EXPIRED";

      throw error;
    }
  }

  // ========================================
  // zca-js undo CAN CA msgId VA cliMsgId
  // ========================================

  const targetMsgId =
    target.msgId != null
      ? String(
          target.msgId
        ).trim()
      : "";


  const targetCliMsgId =
    target.cliMsgId != null
      ? String(
          target.cliMsgId
        ).trim()
      : "";


  if (
    !targetMsgId ||
    !targetCliMsgId
  ) {

    const error =
      new Error(
        "Tin nhan thieu msgId hoac cliMsgId de thu hoi."
      );

    error.code =
      "MESSAGE_IDS_INCOMPLETE";

    throw error;
  }


  // ========================================
  // LAY API ZALO CUA USER
  // ========================================

  const api =
    await connectUserZalo(
      safeUserId
    );

    console.log(
      "[CHAT UNDO] REQUEST:",
      {
        groupId:
          safeGroupId,

        msgId:
          targetMsgId,

        cliMsgId:
          targetCliMsgId,

        type:
          "Group",
      }
    );


  // ========================================
  // THU HOI TREN ZALO
  //
  // KHONG TU MARK recalled O DAY.
  //
  // LISTENER "undo" SE NHAN EVENT THAT
  // VA CAP NHAT CONVERSATION STORE.
  // ========================================

  const zaloResult =
    await api.undo(
      {
        msgId:
          targetMsgId,

        cliMsgId:
          targetCliMsgId,
      },

      safeGroupId,

      ThreadType.Group
    );


  console.log(
    "[CHAT UNDO] SENT:",
    safeUserId,
    safeGroupId,
    targetMsgId,
    targetCliMsgId
  );


  return {
    alreadyRecalled:
      false,

    message:
      target,

    zaloResult:
      zaloResult ??
      null,
  };
}