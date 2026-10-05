import {
  ThreadType,
} from "zca-js";

import {
  connectUserZalo,
} from "../zalo/user-zalo-manager.js";

import {
  getUserMessageById,
  updateUserMessage,
} from "./user-message-store.js";

import {
  findUserConversationMessage,
} from "../conversations/conversation-store.js";


const acceptInFlight =
  new Map();


function acceptLockKey(
  userId,
  messageId
) {
  return `${String(userId)}:${String(messageId)}`;
}

// ========================================
// ACCEPT
// ========================================

async function acceptUserMessageInternal(
  userId,
  messageId,
  replyText = "Nhận"
) {
  // ========================================
  // GET TRIP MESSAGE
  // ========================================

  const message =
    getUserMessageById(
      userId,
      messageId
    );


  // ========================================
  // NOT FOUND
  // ========================================

  if (!message) {
    const error =
      new Error(
        "Khong tim thay cuoc."
      );

    error.code =
      "MESSAGE_NOT_FOUND";

    throw error;
  }


  // ========================================
  // DA NHAN
  // ========================================

  if (
    message.status ===
    "accepted"
  ) {
    return {
      alreadyAccepted: true,
      message,
    };
  }


  // ========================================
  // DA BO QUA
  // ========================================

  if (
    message.status ===
    "ignored"
  ) {
    const error =
      new Error(
        "Cuoc nay da bi bo qua."
      );

    error.code =
      "MESSAGE_ALREADY_IGNORED";

    throw error;
  }


  // ========================================
  // REPLY TEXT
  // ========================================

  const text =
    String(
      replyText ?? ""
    ).trim();


  if (!text) {
    throw new Error(
      "Noi dung tra loi khong duoc rong."
    );
  }


  // ========================================
  // SOURCE MESSAGE IDS
  // ========================================

  const sourceThreadId =
    String(
      message.sourceThreadId ??
      message.groupId
    );


  const sourceMsgId =
    message.sourceMsgId ??
    message.zaloMessageId ??
    null;


  const sourceCliMsgId =
    message.sourceCliMsgId ??
    message.clientMessageId ??
    null;


  // ========================================
  // FIND ORIGINAL ZALO MESSAGE
  // ========================================

  let sourceMessage =
    null;


  if (
    sourceMsgId ||
    sourceCliMsgId
  ) {
    sourceMessage =
      findUserConversationMessage(
        userId,
        sourceThreadId,
        {
          msgId:
            sourceMsgId,

          cliMsgId:
            sourceCliMsgId,
        }
      );
  }


  // ========================================
  // BUILD ZALO QUOTE
  // ========================================

  let quote =
    null;


  if (
    sourceMessage &&
    sourceMessage.status ===
      "normal" &&
    sourceMessage.rawData
  ) {
    const raw =
      sourceMessage.rawData;


    quote = {
      content:
        raw.content,

      msgType:
        raw.msgType,

      propertyExt:
        raw.propertyExt,

      uidFrom:
        raw.uidFrom,

      msgId:
        raw.msgId,

      cliMsgId:
        raw.cliMsgId,

      ts:
        raw.ts,

      ttl:
        raw.ttl ??
        0,
    };
  }


  // ========================================
  // FALLBACK QUOTE SNAPSHOT
  //
  // Neu conversation store chua kip luu tin goc,
  // dung snapshot da gan vao trip ngay luc listener nhan event.
  // ========================================

  if (
    !quote &&
    message.sourceQuote &&
    typeof message.sourceQuote ===
      "object"
  ) {
    const snapshot =
      message.sourceQuote;


    if (
      snapshot.msgId != null ||
      snapshot.cliMsgId != null
    ) {
      quote = {
        content:
          snapshot.content,

        msgType:
          snapshot.msgType,

        propertyExt:
          snapshot.propertyExt,

        uidFrom:
          snapshot.uidFrom,

        msgId:
          snapshot.msgId,

        cliMsgId:
          snapshot.cliMsgId,

        ts:
          snapshot.ts,

        ttl:
          snapshot.ttl ??
          0,
      };
    }
  }


  // ========================================
  // PAYLOAD
  //
  // Co quote:
  // {
  //   msg: "Nhận",
  //   quote: {...}
  // }
  //
  // Khong co quote:
  // "Nhận"
  // ========================================

  const sendPayload =
    quote
      ? {
          msg:
            text,

          quote,
        }
      : text;


  // ========================================
  // GET USER ZALO API
  // ========================================

  const api =
    await connectUserZalo(
      userId
    );


  console.log(
    "[USER ACCEPT]",
    userId,
    "Message:",
    messageId
  );


  console.log(
    "[USER ACCEPT] Group:",
    sourceThreadId
  );


  console.log(
    "[USER ACCEPT] Quote:",
    quote
      ? "YES"
      : "NO"
  );


  if (
    !quote &&
    (
      sourceMsgId ||
      sourceCliMsgId
    )
  ) {
    const error =
      new Error(
        "Tin nhan goc chua san sang de tra loi."
      );


    error.code =
      "SOURCE_MESSAGE_UNAVAILABLE";


    throw error;
  }


  // ========================================
  // SEND ZALO
  // ========================================

  const result =
    await api.sendMessage(
      sendPayload,
      sourceThreadId,
      ThreadType.Group
    );


  // ========================================
  // GET REPLY MESSAGE ID
  // ========================================

  const replyMsgId =
    result?.message?.msgId ??
    result?.msgId ??
    null;


  const replyCliMsgId =
    result?.message?.cliMsgId ??
    result?.cliMsgId ??
    null;


  // ========================================
  // MARK TRIP AS ACCEPTED
  // ========================================

  const updated =
    updateUserMessage(
      userId,
      messageId,
      {
        status:
          "accepted",

        replyText:
          text,

        // ========================================
        // TIN "NHAN" CUA CHINH USER
        // ========================================

        replyZaloMessageId:
          replyMsgId != null
            ? String(
                replyMsgId
              )
            : null,

        replyZaloCliMessageId:
          replyCliMsgId != null
            ? String(
                replyCliMsgId
              )
            : null,

        acceptedAt:
          new Date()
            .toISOString(),
      }
    );


  console.log(
    "[USER ACCEPT] SUCCESS:",
    userId,
    messageId
  );


  return {
    alreadyAccepted: false,
    message: updated,
  };
}


export async function acceptUserMessage(
  userId,
  messageId,
  replyText = "Nhận"
) {
  const key =
    acceptLockKey(
      userId,
      messageId
    );


  const existing =
    acceptInFlight.get(
      key
    );


  if (existing) {
    return existing;
  }


  const promise =
    acceptUserMessageInternal(
      userId,
      messageId,
      replyText
    );


  acceptInFlight.set(
    key,
    promise
  );


  try {
    return await promise;
  } finally {
    if (
      acceptInFlight.get(
        key
      ) ===
      promise
    ) {
      acceptInFlight.delete(
        key
      );
    }
  }
}


// ========================================
// IGNORE
// ========================================

export async function ignoreUserMessage(
  userId,
  messageId
) {
  const message =
    getUserMessageById(
      userId,
      messageId
    );


  if (!message) {
    const error =
      new Error(
        "Khong tim thay cuoc."
      );

    error.code =
      "MESSAGE_NOT_FOUND";

    throw error;
  }


  if (
    message.status ===
    "accepted"
  ) {
    const error =
      new Error(
        "Cuoc nay da duoc nhan."
      );

    error.code =
      "MESSAGE_ALREADY_ACCEPTED";

    throw error;
  }


  if (
    message.status ===
    "ignored"
  ) {
    return {
      alreadyIgnored: true,
      message,
    };
  }


  const updated =
    updateUserMessage(
      userId,
      messageId,
      {
        status:
          "ignored",

        ignoredAt:
          new Date().toISOString(),
      }
    );


  console.log(
    "[USER IGNORE]",
    userId,
    messageId
  );


  return {
    alreadyIgnored: false,
    message: updated,
  };
}