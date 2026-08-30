import {
  ThreadType,
} from "zca-js";

import {
  connectUserZalo,
} from "../zalo/user-zalo-manager.js";

import {
  getUserGroups,
} from "../zalo/user-groups.js";

import {
  findUserConversationMessage,
} from "./conversation-store.js";


// ========================================
// SEND MESSAGE / REPLY TO ZALO GROUP
// ========================================

export async function
sendUserConversationMessage(
  userId,
  groupId,
  text,
  {
    replyToMsgId = null,
    replyToCliMsgId = null,
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


  const safeText =
    typeof text ===
      "string"
      ? text.trim()
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


  if (!safeText) {

    const error =
      new Error(
        "Noi dung tin nhan dang trong."
      );

    error.code =
      "EMPTY_MESSAGE";

    throw error;
  }


  if (
    safeText.length >
    2000
  ) {

    const error =
      new Error(
        "Tin nhan qua dai."
      );

    error.code =
      "MESSAGE_TOO_LONG";

    throw error;
  }


  // ========================================
  // KIEM TRA GROUP
  // ========================================

  const groups =
    await getUserGroups(
      safeUserId
    );


  const groupExists =
    groups.some(
      item =>
        String(
          item.groupId
        ) ===
        safeGroupId
    );


  if (!groupExists) {

    const error =
      new Error(
        "Khong tim thay group trong tai khoan Zalo."
      );

    error.code =
      "GROUP_NOT_FOUND";

    throw error;
  }


  // ========================================
  // BUILD QUOTE NEU DANG REPLY
  // ========================================

  let quote =
    null;


  const safeReplyToMsgId =
    replyToMsgId != null
      ? String(
          replyToMsgId
        ).trim()
      : "";


  const safeReplyToCliMsgId =
    replyToCliMsgId != null
      ? String(
          replyToCliMsgId
        ).trim()
      : "";


  const hasReplyTarget =
    Boolean(
      safeReplyToMsgId ||
      safeReplyToCliMsgId
    );


  if (hasReplyTarget) {

    const target =
      findUserConversationMessage(
        safeUserId,
        safeGroupId,
        {
          msgId:
            safeReplyToMsgId ||
            null,

          cliMsgId:
            safeReplyToCliMsgId ||
            null,
        }
      );


    if (!target) {

      const error =
        new Error(
          "Khong tim thay tin nhan can tra loi."
        );

      error.code =
        "REPLY_TARGET_NOT_FOUND";

      throw error;
    }


    // ========================================
    // KHONG REPLY TIN DA THU HOI / XOA
    // ========================================

    if (
      target.status !==
        "normal" ||
      !target.rawData
    ) {

      const error =
        new Error(
          "Tin nhan nay khong con co the tra loi."
        );

      error.code =
        "REPLY_TARGET_UNAVAILABLE";

      throw error;
    }


    // ========================================
    // rawData CHINH LA message.data
    // DA DUOC CONVERSATION STORE LUU LAI.
    //
    // zca-js sendMessage:
    // quote: message.data
    // ========================================

    quote =
      target.rawData;


    if (
      quote.msgId == null &&
      quote.cliMsgId == null
    ) {

      const error =
        new Error(
          "Tin nhan goc thieu Zalo message ID."
        );

      error.code =
        "REPLY_TARGET_UNAVAILABLE";

      throw error;
    }
  }


  // ========================================
  // CONNECT DUNG ZALO ACCOUNT
  // ========================================

  const api =
    await connectUserZalo(
      safeUserId
    );


  // ========================================
  // PAYLOAD
  // ========================================

  const sendPayload =
    quote
      ? {
          msg:
            safeText,

          quote,
        }

      : {
          msg:
            safeText,
        };


  // ========================================
  // GUI VAO GROUP
  // ========================================

  const zaloResult =
    await api.sendMessage(
      sendPayload,

      safeGroupId,

      ThreadType.Group
    );


  console.log(
    quote
      ? "[CHAT REPLY]"
      : "[CHAT SEND]",

    safeUserId,
    safeGroupId,

    quote?.msgId ??
    quote?.cliMsgId ??
    ""
  );


  return {
    groupId:
      safeGroupId,

    text:
      safeText,

    replied:
      quote != null,

    replyToMsgId:
      quote?.msgId ??
      null,

    replyToCliMsgId:
      quote?.cliMsgId ??
      null,

    zaloResult:
      zaloResult ??
      null,
  };
}