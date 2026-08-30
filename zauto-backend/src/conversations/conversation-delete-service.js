import {
  ThreadType,
} from "zca-js";

import {
  connectUserZalo,
} from "../zalo/user-zalo-manager.js";

import {
  findUserConversationMessage,
  markConversationMessageDeletedLocal,
} from "./conversation-store.js";


// ========================================
// DELETE MESSAGE FOR CURRENT ZALO ACCOUNT
//
// onlyMe = true
//
// MESSAGE BI XOA O PHIA USER HIEN TAI.
// NGUOI KHAC TRONG GROUP VAN THAY.
// ========================================

export async function
deleteUserConversationMessage(
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
  // TIM MESSAGE TRONG CONVERSATION STORE
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


  const targetMsgId =
    String(
      target.msgId ??
      ""
    ).trim();


  const targetCliMsgId =
    String(
      target.cliMsgId ??
      ""
    ).trim();


  if (
    !targetMsgId ||
    !targetCliMsgId
  ) {

    const error =
      new Error(
        "Tin nhan thieu msgId hoac cliMsgId."
      );

    error.code =
      "MESSAGE_IDS_INCOMPLETE";

    throw error;
  }


  // ========================================
  // deleteMessage CAN uidFrom CUA MESSAGE GOC
  // ========================================

  const uidFrom =
    String(
      target.rawData?.uidFrom ??
      target.senderId ??
      target.uidFrom ??
      ""
    ).trim();


  if (!uidFrom) {

    const error =
      new Error(
        "Tin nhan thieu uidFrom de xoa tren Zalo."
      );

    error.code =
      "MESSAGE_SENDER_REQUIRED";

    throw error;
  }


  const api =
    await connectUserZalo(
      safeUserId
    );


  // ========================================
  // XOA O PHIA TOI TREN ZALO
  //
  // Chu ky hien tai cua zca-js:
  //
  // api.deleteMessage(
  //   destination,
  //   onlyMe
  // )
  // ========================================

  const zaloResult =
    await api.deleteMessage(
      {
        data: {
          cliMsgId:
            targetCliMsgId,

          msgId:
            targetMsgId,

          uidFrom,
        },

        threadId:
          safeGroupId,

        type:
          ThreadType.Group,
      },

      true
    );


  console.log(
    "[CHAT DELETE ZALO] SENT:",
    safeUserId,
    safeGroupId,
    targetMsgId,
    targetCliMsgId,
    uidFrom
  );


  // ========================================
  // ZALO THANH CONG ROI MOI DANH DAU LOCAL
  // ========================================

  const deleted =
    markConversationMessageDeletedLocal(
      safeUserId,
      safeGroupId,
      {
        msgId:
          targetMsgId,

        cliMsgId:
          targetCliMsgId,
      }
    );


  return {
    message:
      deleted ??
      target,

    zaloResult:
      zaloResult ??
      null,
  };
}