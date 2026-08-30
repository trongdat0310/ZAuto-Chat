import {
  ThreadType,
} from "zca-js";

import {
  getZaloApi,
} from "../zalo/connector.js";

import {
  getMessageById,
  updateMessage,
} from "./message-store.js";


// ========================================
// ACCEPT MESSAGE / NHAN CUOC
// ========================================

export async function acceptMessage(
  messageId,
  replyText = "Nhận"
) {
  const api = getZaloApi();

  if (!api) {
    throw new Error(
      "Zalo chua duoc ket noi."
    );
  }


  // ========================================
  // TIM MESSAGE
  // ========================================

  const message =
    getMessageById(messageId);

  if (!message) {
    const error =
      new Error(
        "Khong tim thay message."
      );

    error.code =
      "MESSAGE_NOT_FOUND";

    throw error;
  }


  // ========================================
  // CHONG BAM 2 LAN
  // ========================================

  if (
    message.status === "accepted"
  ) {
    return {
      alreadyAccepted: true,
      message,
    };
  }


  // Cuoc da bo qua thi khong nhan nua
  if (
    message.status === "ignored"
  ) {
    const error =
      new Error(
        "Cuoc nay da bi bo qua."
      );

    error.code =
      "MESSAGE_ALREADY_IGNORED";

    throw error;
  }


  const text =
    String(replyText).trim();

  if (!text) {
    throw new Error(
      "Noi dung tra loi khong duoc rong."
    );
  }


  console.log("");
  console.log(
    "[ACCEPT] Dang nhan cuoc..."
  );

  console.log(
    "[ACCEPT] Message:",
    message.id
  );

  console.log(
    "[ACCEPT] Group:",
    message.groupId
  );

  console.log(
    "[ACCEPT] Reply:",
    text
  );


  // ========================================
  // GUI TIN NHAN VAO ZALO GROUP
  // ========================================

  try {
    const result =
      await api.sendMessage(
        text,
        message.groupId,
        ThreadType.Group
      );


    const replyMsgId =
      result?.message?.msgId ??
      result?.msgId ??
      null;


    // ========================================
    // CAP NHAT TRANG THAI
    // ========================================

    const updated =
      updateMessage(
        message.id,
        {
          status: "accepted",

          replyText: text,

          replyZaloMessageId:
            replyMsgId
              ? String(replyMsgId)
              : null,

          acceptedAt:
            new Date().toISOString(),
        }
      );


    console.log(
      "[ACCEPT] SEND SUCCESS"
    );

    console.log(
      "[ACCEPT] Reply Msg ID:",
      replyMsgId
    );


    return {
      alreadyAccepted: false,
      message: updated,
    };

  } catch (error) {
    console.error(
      "[ACCEPT] SEND FAILED:"
    );

    console.error(error);

    throw error;
  }
}


// ========================================
// IGNORE MESSAGE / BO QUA CUOC
// ========================================

export async function ignoreMessage(
  messageId
) {
  const message =
    getMessageById(messageId);


  if (!message) {
    const error =
      new Error(
        "Khong tim thay message."
      );

    error.code =
      "MESSAGE_NOT_FOUND";

    throw error;
  }


  // ========================================
  // DA NHAN THI KHONG DUOC BO QUA
  // ========================================

  if (
    message.status === "accepted"
  ) {
    const error =
      new Error(
        "Cuoc nay da duoc nhan."
      );

    error.code =
      "MESSAGE_ALREADY_ACCEPTED";

    throw error;
  }


  // ========================================
  // DA BO QUA ROI
  // ========================================

  if (
    message.status === "ignored"
  ) {
    return {
      alreadyIgnored: true,
      message,
    };
  }


  // ========================================
  // CAP NHAT TRANG THAI
  // ========================================

  const updated =
    updateMessage(
      message.id,
      {
        status: "ignored",

        ignoredAt:
          new Date().toISOString(),
      }
    );


  console.log(
    "[IGNORE] Message ignored:",
    message.id
  );


  return {
    alreadyIgnored: false,
    message: updated,
  };
}