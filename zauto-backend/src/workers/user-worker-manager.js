import {
  ThreadType,
} from "zca-js";

import {
  findUserById,
  getLinkedUsers,
} from "../users/user-store.js";

import {
  connectUserZalo,
  clearUserZaloConnection,
} from "../zalo/user-zalo-manager.js";

import {
  getUserGroups,
  getUserGroupName,
} from "../zalo/user-groups.js";

import {
  isUserGroupEnabled,
} from "../zalo/user-group-settings.js";

import {
  evaluateUserMessage,
} from "../filters/user-filter-engine.js";

import {
  saveUserMessage,
} from "../messages/user-message-store.js";

import {
  sendUserNewTripPush,
} from "../push/user-push-service.js";

import {
  broadcastUserEvent,
} from "../realtime/ws-server.js";

import {
  syncConversationGroups,
  saveConversationMessage,
  findUserConversationMessage,
  getUserConversationList,
  markConversationMessageRecalledFromUndo,
} from "../conversations/conversation-store.js";

import {
  getUserMessageSettings,
} from "../settings/user-message-settings-store.js";

import {
  shouldSkipDuplicateUserMessage,
} from "../messages/user-message-dedupe.js";

const workers =
  new Map();

// ========================================
// NETWORK STATE
// ========================================

let networkAvailable =
true;

const MAX_RECONNECT_ATTEMPTS =
  8;


// ========================================
// FORMAT ERROR / REASON
// ========================================

function formatReason(value) {
  if (!value) {
    return "unknown";
  }

  if (
    typeof value ===
    "string"
  ) {
    return value;
  }

  if (
    value instanceof Error
  ) {
    return value.message;
  }

  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}


// ========================================
// RECONNECT
// ========================================

function scheduleReconnect(
  userId,
  worker,
  reason
) {
  const key =
    String(userId);

  // ========================================
  // NEU TOAN BO SERVER DANG OFFLINE
  // THI KHONG RETRY ZALO LIEN TUC
  // ========================================

  if (!networkAvailable) {

    worker.status =
      "offline";

    worker.lastError =
      reason;

    worker.nextReconnectAt =
      null;


    console.warn(
      "[USER WORKER] WAITING FOR INTERNET:",
      key
    );


    return;
  }

  // Worker cu khong duoc
  // reconnect nua.
  if (
    workers.get(key) !==
    worker
  ) {
    return;
  }


  // Da co timer.
  if (worker.reconnectTimer) {
    return;
  }


  const nextAttempt =
    (
      worker.reconnectAttempts ??
      0
    ) + 1;


  if (
    nextAttempt >
    MAX_RECONNECT_ATTEMPTS
  ) {
    worker.status =
      "needs_relink";

    worker.lastError =
      reason;

    worker.nextReconnectAt =
      null;


    console.error(
      "[USER WORKER] NEEDS RELINK:",
      key,
      reason
    );

    return;
  }


  worker.status =
    "reconnecting";

  worker.lastError =
    reason;

  worker.reconnectAttempts =
    nextAttempt;


  // 5s -> 10s -> 20s -> 30s...
  const delay =
    Math.min(
      30000,
      5000 *
        Math.pow(
          2,
          Math.min(
            nextAttempt - 1,
            3
          )
        )
    );


  worker.nextReconnectAt =
    new Date(
      Date.now() + delay
    ).toISOString();


  console.warn(
    "[USER WORKER] RECONNECT SCHEDULED:",
    key,
    `attempt=${nextAttempt}`,
    `delay=${delay}ms`,
    reason
  );


  worker.reconnectTimer =
    setTimeout(
      async () => {

        worker.reconnectTimer =
          null;

        worker.nextReconnectAt =
          null;


        if (
          workers.get(key) !==
          worker
        ) {
          return;
        }


        console.log(
          "[USER WORKER] RECONNECTING:",
          key,
          `attempt=${nextAttempt}`
        );


        // Bo API cache cu.
        clearUserZaloConnection(
          key
        );


        // Worker cu khong con
        // la worker hien tai.
        workers.delete(key);


        try {

          await startUserWorker(
            key
          );


          console.log(
            "[USER WORKER] RECONNECTED:",
            key
          );

        } catch (error) {

          console.error(
            "[USER WORKER] RECONNECT FAILED:",
            key,
            error
          );


          const failedWorker =
            workers.get(key);


          if (failedWorker) {

            failedWorker
              .reconnectAttempts =
              nextAttempt;


            scheduleReconnect(
              key,
              failedWorker,
              formatReason(error)
            );
          }
        }

      },
      delay
    );
}

// ========================================
// PUBLIC STATUS
// ========================================

function publicWorker(worker) {
  if (!worker) {
    return {
      status: "stopped",
      ownId: null,
      lastError: null,
    };
  }


  return {
    status:
      worker.status,

    ownId:
      worker.ownId ??
      null,

    startedAt:
      worker.startedAt ??
      null,

    lastConnectedAt:
      worker.lastConnectedAt ??
      null,

    lastMessageAt:
      worker.lastMessageAt ??
      null,

    lastError:
      worker.lastError ??
      null,

    reconnectAttempts:
      worker.reconnectAttempts ??
      0,

    nextReconnectAt:
      worker.nextReconnectAt ??
      null,
  };
}

// ========================================
// DEBUG PHOTO ALBUM
//
// MUC TIEU:
// XAC DINH PAYLOAD THAT KHI ZALO
// GUI NHIEU ANH CUNG MOT LAN.
// ========================================

function debugPhotoAlbumMessage(
  userId,
  worker,
  message
) {

  const data =
    message?.data ??
    {};


  const msgType =
    String(
      data?.msgType ??
      ""
    )
      .trim()
      .toLowerCase();


  if (
    msgType !==
      "chat.photo"
  ) {

    return;
  }


  // Toi da 12 anh/log trong moi lan worker chay.
  if (
    (
      worker.photoAlbumDebugCount ??
      0
    ) >= 12
  ) {

    return;
  }


  worker.photoAlbumDebugCount =
    (
      worker.photoAlbumDebugCount ??
      0
    ) + 1;


  const content =
    data?.content &&
    typeof data.content ===
      "object"
      ? data.content
      : {};


  let params =
    {};


  // ========================================
  // ZALO THUONG TRA params DUOI DANG
  // JSON STRING
  // ========================================

  if (
    typeof content.params ===
      "string" &&
    content.params.trim()
  ) {

    try {

      params =
        JSON.parse(
          content.params
        );

    } catch (error) {

      params = {
        parseError:
          error?.message ??
          String(error),

        raw:
          content.params,
      };
    }

  } else if (
    content.params &&
    typeof content.params ===
      "object"
  ) {

    params =
      content.params;
  }


  console.log(
    "\n========================================"
  );

  console.log(
    "[PHOTO ALBUM DEBUG]"
  );


  console.log({
    userId:
      String(userId),

    threadId:
      message?.threadId ??
      null,

    isSelf:
      message?.isSelf ??
      null,

    msgId:
      data?.msgId ??
      null,

    cliMsgId:
      data?.cliMsgId ??
      null,

    ts:
      data?.ts ??
      null,

    msgType,

    href:
      content?.href ??
      null,

    thumb:
      content?.thumb ??
      null,
  });


  console.log(
    "[PHOTO ALBUM PARAMS]"
  );


  console.dir(
    params,
    {
      depth:
        10,

      colors:
        false,

      maxArrayLength:
        50,

      maxStringLength:
        3000,
    }
  );


  console.log(
    "[PHOTO ALBUM DEBUG END]"
  );

  console.log(
    "========================================\n"
  );
}

// ========================================
// CONVERSATION DISPLAYABLE MESSAGE
// ========================================

function isDisplayableConversationEvent(
  message
) {

  const data =
    message?.data ??
    {};


  const content =
    data?.content;


  // ========================================
  // TEXT THAT
  // ========================================

  if (
    typeof content ===
      "string" &&
    content
      .trim()
      .length >
      0
  ) {

    return true;
  }


  const msgType =
    String(
      data?.msgType ??
      ""
    )
      .trim()
      .toLowerCase();


  // ========================================
  // CAC TYPE THUC TE DA BAT DUOC TU ZALO
  // ========================================

  const supportedStringTypes =
    new Set([
      "chat.photo",
      "chat.sticker",
      "chat.video.msg",
      "chat.video",

      // File runtime cua Zalo cua ban
      // THUC TE la share.file.
      "share.file",

      // Giu them fallback
      "chat.file",
      "chat.file.msg",

      "chat.gif",

      "chat.voice",
      "chat.voice.msg",
      "chat.audio",
    ]);


  if (
    supportedStringTypes.has(
      msgType
    )
  ) {

    return true;
  }


  // ========================================
  // DATA CU DUNG NUMERIC TYPES
  // ========================================

  const numericType =
    Number(
      msgType
    );


  if (
    Number.isFinite(
      numericType
    ) &&
    new Set([
      31,
      32,
      44,
      46,
      49,
    ]).has(
      numericType
    )
  ) {

    return true;
  }


  return false;
}

// ========================================
// STORE ALL GROUP CONVERSATION MESSAGES
// ========================================

async function storeConversationEvent(
  userId,
  message
) {

  // ========================================
  // CHI LUU GROUP CHAT
  // ========================================

  if (
    message?.type !==
    ThreadType.Group
  ) {

    return null;
  }


  const groupId =
    String(
      message?.threadId ??
      ""
    ).trim();


  if (!groupId) {

    return null;
  }


  const data =
    message?.data ??
    {};


  // ========================================
  // 348.6B
  // CHI LUU CAC EVENT CO THE HIEN THI
  //
  // Bao gom:
  // - text
  // - photo
  // - sticker
  // - video
  // - file
  // - gif
  // - voice
  //
  // Bo cac system event rong.
  // ========================================

  if (
    !isDisplayableConversationEvent(
      message
    )
  ) {

    console.log(
      "[CONVERSATION] SKIP NON-DISPLAY EVENT:",
      {
        threadId:
          groupId,

        msgType:
          data?.msgType ??
          null,

        msgId:
          data?.msgId ??
          null,

        cliMsgId:
          data?.cliMsgId ??
          null,
      }
    );


    return null;
  }


  // ========================================
  // TEN GROUP
  // ========================================

  let groupName =
    null;


  try {

    groupName =
      await getUserGroupName(
        userId,
        groupId
      );

  } catch {

    // Khong lam fail listener
    // neu lay ten group bi loi.
  }


  // ========================================
  // TEN NGUOI GUI
  // ========================================

  const senderName =
    data?.dName ??
    data?.senderName ??
    null;


  // ========================================
  // LUU VAO CONVERSATION STORE
  // ========================================

  const saved =
    saveConversationMessage(
      userId,
      {
        message,
        groupName,
        senderName,
      }
    );


  if (!saved) {

    return null;
  }


  console.log(
    "[CONVERSATION] SAVED:",
    userId,
    groupId,
    saved.msgId ??
    saved.cliMsgId ??
    saved.id
  );


  // ========================================
  // REALTIME VE FLUTTER
  //
  // GOM:
  // - text
  // - photo
  // - sticker
  // - video
  // - file
  // - isSelf message
  // ========================================

  broadcastUserEvent(
    userId,
    "conversation_message",
    {
      groupId,

      message:
        saved,
    }
  );


  return saved;
}
// ========================================
// GET LATEST STORED GROUP MESSAGE CURSOR
//
// TIM MESSAGE MOI NHAT MA APP DA LUU.
//
// DUNG msgId CUA MESSAGE NAY LAM
// lastMsgId KHI REQUEST OLD MESSAGES.
// ========================================

function getLatestStoredGroupCursor(
  userId
) {

  const conversations =
    getUserConversationList(
      userId
    );


  if (
    !Array.isArray(
      conversations
    ) ||
    conversations.length ===
      0
  ) {

    return null;
  }


  let latest =
    null;


  for (
    const conversation
    of conversations
  ) {

    const msgId =
      conversation
        ?.lastMessageId != null
        ? String(
            conversation
              .lastMessageId
          ).trim()
        : "";


    const timestamp =
      Number(
        conversation
          ?.lastMessageAt ??
        0
      );


    if (
      !msgId ||
      !Number.isFinite(
        timestamp
      ) ||
      timestamp <= 0
    ) {

      continue;
    }


    if (
      latest == null ||
      timestamp >
        latest.timestamp
    ) {

      latest = {
        msgId,

        timestamp,

        groupId:
          String(
            conversation
              ?.groupId ??
            ""
          ),

        content:
          conversation
            ?.lastContent ??
          null,
      };
    }
  }


  return latest;
}
// ========================================
// REQUEST MISSED GROUP MESSAGES
//
// DUNG KHI:
// - backend vua khoi dong
// - listener vua reconnect
//
// MUC TIEU:
// lay lai cac message xay ra trong luc
// backend/listener khong hoat dong.
// ========================================

function requestMissedGroupMessages(
  userId,
  worker,
  api
) {

  const key =
    String(
      userId
    );


  // Worker cu khong duoc sync.
  if (
    workers.get(key) !==
    worker
  ) {

    return;
  }


  // Da co mot lan sync dang chay.
  if (
    worker.historySyncInProgress
  ) {

    return;
  }


  worker.historySyncInProgress =
    true;


  if (
    worker.historySyncTimer
  ) {

    clearTimeout(
      worker.historySyncTimer
    );
  }


  // Cho websocket on dinh
  // sau event connected.
  worker.historySyncTimer =
    setTimeout(
      () => {

        worker.historySyncTimer =
          null;


        if (
          workers.get(key) !==
          worker
        ) {

          worker.historySyncInProgress =
            false;

          return;
        }


        try {

          // ========================================
          // TIM MESSAGE CUOI APP DA LUU
          // ========================================

          const cursor =
            getLatestStoredGroupCursor(
              key
            );


          worker.historySyncCursor =
            cursor;


          console.log(
            "[CONVERSATION] REQUEST OLD MESSAGES:",
            key,
            {
              cursorMsgId:
                cursor?.msgId ??
                null,

              cursorTimestamp:
                cursor?.timestamp ??
                null,

              cursorGroupId:
                cursor?.groupId ??
                null,

              cursorContent:
                cursor?.content ??
                null,
            }
          );


          // ========================================
          // CO CURSOR:
          // BAT DAU TU MESSAGE CUOI DA LUU.
          //
          // CHUA TUNG CO MESSAGE:
          // FALLBACK lastId = null.
          // ========================================

          if (
            cursor?.msgId
          ) {

            api.listener
              .requestOldMessages(
                ThreadType.Group,
                cursor.msgId
              );

          } else {

            api.listener
              .requestOldMessages(
                ThreadType.Group
              );
          }


          console.log(
            "[CONVERSATION] OLD MESSAGES REQUEST SENT:",
            key,
            "cursor=",
            cursor?.msgId ??
            null
          );


          // ========================================
          // FAILSAFE
          //
          // Neu Zalo khong tra old_messages
          // thi khong de sync bi khoa mai mai.
          // ========================================

          if (
            worker.historySyncWatchdog
          ) {

            clearTimeout(
              worker.historySyncWatchdog
            );
          }


          worker.historySyncWatchdog =
            setTimeout(
              () => {

                worker.historySyncWatchdog =
                  null;


                if (
                  workers.get(key) !==
                  worker
                ) {
                  return;
                }


                if (
                  worker.historySyncInProgress
                ) {

                  console.warn(
                    "[CONVERSATION] OLD MESSAGES TIMEOUT:",
                    key
                  );


                  worker.historySyncInProgress =
                    false;
                }
              },

              12000
            );

        } catch (error) {

          worker.historySyncInProgress =
            false;


          console.error(
            "[CONVERSATION] REQUEST OLD MESSAGES ERROR:",
            key,
            error
          );
        }
      },

      600
    );
}

// ========================================
// PROCESS MESSAGE
// ========================================

async function processMessage(
  userId,
  worker,
  message
) {
  try {
    const key =
      String(userId);


    // Neu day la listener cu
    // thi tuyet doi bo qua.
    if (
      workers.get(key) !==
      worker
    ) {
      return;
    }

    // Tin do chinh account gui
    // thi bo qua.
    if (
      message.isSelf === true
    ) {
      return;
    }


    // Chi theo doi group.
    if (
      message.type !==
      ThreadType.Group
    ) {
      return;
    }


    const content =
      message.data?.content;


    // Hien tai chi xu ly text.
    if (
      typeof content !==
      "string"
    ) {
      return;
    }


    const groupId =
      String(
        message.threadId ?? ""
      );


    if (!groupId) {
      return;
    }


    worker.lastMessageAt =
      new Date().toISOString();


    // ========================================
    // GROUP ON/OFF CUA USER
    // ========================================

    if (
      !isUserGroupEnabled(
        userId,
        groupId
      )
    ) {
      console.log(
        "[USER WORKER] IGNORE GROUP:",
        userId,
        groupId
      );

      return;
    }


    // ========================================
    // FILTER CUA USER
    // ========================================

    const filter =
      evaluateUserMessage(
        userId,
        content
      );


    if (!filter.matched) {
      console.log(
        "[USER WORKER] FILTER REJECT:",
        userId,
        filter.reason,
        filter.keyword ?? ""
      );

      return;
    }


    const groupName =
      getUserGroupName(
        userId,
        groupId
      );


    const senderId =
      message.data?.uidFrom ??
      null;


    const senderName =
      message.data?.dName ??
      null;


    // ========================================
    // SAVE VAO MESSAGE STORE CUA USER
    // ========================================

    const zaloData =
      message.data ??
      {};

    // ========================================
    // DUPLICATE TRIP FILTER
    //
    // TRUNG KHI:
    // - cung senderId
    // - cung text
    // - trong khoang thoi gian quy dinh
    // ========================================

    const messageSettings =
      getUserMessageSettings(
        userId
      );


    if (
      messageSettings
        .deduplicateMessages ===
      true
    ) {

      const duplicate =
        shouldSkipDuplicateUserMessage(
          userId,
          {
            senderId,
            content,

            windowSeconds:
              messageSettings
                .dedupeWindowSeconds,
          }
        );


      if (duplicate) {

        console.log(
          "[USER DEDUPE] SKIP:",
          {
            userId,
            senderId,
            groupId,
            content,
          }
        );


        return;
      }
    }

    const saved =
      saveUserMessage(
        userId,
        {
          // ========================================
          // THONG TIN CUOC HIEN TAI
          // ========================================

          groupId,

          groupName,

          senderId,

          senderName,

          content,


          // ========================================
          // ID CU GIU LAI DE TUONG THICH
          // ========================================

          zaloMessageId:
            zaloData.msgId != null
              ? String(
                  zaloData.msgId
                )
              : null,

          clientMessageId:
            zaloData.cliMsgId != null
              ? String(
                  zaloData.cliMsgId
                )
              : null,

          sourceTimestamp:
            zaloData.ts ??
            null,


          // ========================================
          // LINK DEN TIN NHAN ZALO GOC
          // DUNG CHO LICH SU NHAN
          // ========================================

          sourceThreadId:
            groupId,

          sourceMsgId:
            zaloData.msgId != null
              ? String(
                  zaloData.msgId
                )
              : null,

          sourceCliMsgId:
            zaloData.cliMsgId != null
              ? String(
                  zaloData.cliMsgId
                )
              : null,
        }
      );


    // Duplicate thi khong push nua.
    if (!saved.created) {
      return;
    }

    // Realtime chi cho user nay
    broadcastUserEvent(
      userId,
      "new_trip",
      saved.message
    );

    console.log("");
    console.log(
      "================================"
    );

    console.log(
      "   USER MESSAGE ACCEPTED"
    );

    console.log(
      "================================"
    );

    console.log(
      "User:",
      userId
    );

    console.log(
      "Group:",
      groupName
    );

    console.log(
      "Sender:",
      senderName ??
      senderId
    );

    console.log(
      "Content:",
      content
    );

    console.log(
      "Filter:",
      filter.reason
    );

    console.log(
      "================================"
    );


    // ========================================
    // PUSH CHI CHO DEVICE CUA USER NAY
    // ========================================

    sendUserNewTripPush(
      userId,
      saved.message
    ).catch(
      error => {

        console.error(
          "[USER WORKER] PUSH ERROR:",
          userId,
          error
        );
      }
    );

  } catch (error) {

    worker.lastError =
      error?.message ??
      String(error);


    console.error(
      "[USER WORKER] MESSAGE ERROR:",
      userId,
      error
    );
  }
}


// ========================================
// START ONE USER
// ========================================

export async function startUserWorker(
  userId
) {
  const key =
    String(userId);


  const existing =
    workers.get(key);


  if (
    existing &&
    (
      existing.status ===
        "running" ||
      existing.status ===
        "starting"
    )
  ) {
    return publicWorker(
      existing
    );
  }


  const user =
    findUserById(key);


  if (!user) {
    const error =
      new Error(
        "Tai khoan khong ton tai."
      );

    error.code =
      "USER_NOT_FOUND";

    throw error;
  }


  if (
    user.zaloLinked !== true
  ) {
    const error =
      new Error(
        "Tai khoan chua lien ket Zalo."
      );

    error.code =
      "ZALO_NOT_LINKED";

    throw error;
  }


  // ========================================
  // KHONG CHO 2 USER APP
  // CUNG CHAY 1 ZALO ACCOUNT
  // ========================================

  if (user.zaloUserId) {

    for (
      const [
        otherUserId,
        otherWorker,
      ]
      of workers
    ) {

      if (
        otherUserId !== key &&
        otherWorker.status ===
          "running" &&
        otherWorker.ownId ===
          String(
            user.zaloUserId
          )
      ) {
        const error =
          new Error(
            "Tai khoan Zalo nay dang duoc su dung boi tai khoan app khac."
          );

        error.code =
          "ZALO_ALREADY_RUNNING";

        throw error;
      }
    }
  }

  const worker = {
    status:
      "starting",

      // ========================================
      // PHOTO ALBUM DEBUG
      // TAM THOI DUNG O BUOC 347
      // ========================================

      photoAlbumDebugCount:
        0,

    ownId:
      null,

    startedAt:
      null,

    lastConnectedAt:
      null,

    lastMessageAt:
      null,

    lastError:
      null,

    reconnectAttempts:
      0,

    nextReconnectAt:
      null,

    reconnectTimer:
      null,

    api:
      null,


    // ========================================
    // CATCH UP MESSAGE HISTORY
    // ========================================

    historySyncInProgress:
      false,

    historySyncTimer:
      null,

    historySyncWatchdog:
      null,

    historySyncCursor:
      null,
  };

  workers.set(
    key,
    worker
  );

  // ========================================
  // NETWORK DANG OFFLINE
  // GIU WORKER TRONG MAP DE WATCHDOG
  // CO THE KHOI PHUC SAU NAY.
  // ========================================

  if (!networkAvailable) {

    worker.status =
      "offline";

    worker.lastError =
      "internet_offline";


    console.warn(
      "[USER WORKER] OFFLINE:",
      key
    );


    return publicWorker(
      worker
    );
  }

  try {

    console.log(
      "[USER WORKER] STARTING:",
      key
    );

    // Load session + login Zalo
    const api =
      await connectUserZalo(
        key
      );

    worker.api =
      api;

    // ========================================
    // SYNC CONVERSATION INDEX
    // ========================================

    try {

      const groups =
        await getUserGroups(
          key
        );


      syncConversationGroups(
        key,
        groups
      );


      console.log(
        "[CONVERSATION] GROUPS SYNCED:",
        key,
        groups.length
      );

    } catch (error) {

      console.error(
        "[CONVERSATION] GROUP SYNC ERROR:",
        key,
        error
      );
    }

    worker.ownId =
      String(
        api.getOwnId()
      );

    // Load group de warm cache
    // groupId -> groupName.
    await getUserGroups(
      key
    );

    // ========================================
    // LISTENER
    // ========================================

    // ========================================
    // MESSAGE
    // ========================================

    api.listener.on(
      "message",

      (message) => {

      // ========================================
      // BUOC 347
      // DEBUG ALBUM PHOTO
      // ========================================

      debugPhotoAlbumMessage(
        key,
        worker,
        message
      );

        // ========================================
        // 1. LUON LUU CONVERSATION
        // KHONG QUAN TAM CO PHAI CUOC HAY KHONG
        // ========================================

        void storeConversationEvent(
          key,
          message
        ).catch(
          error => {

            console.error(
              "[CONVERSATION] STORE ERROR:",
              key,
              error
            );
          }
        );


        // ========================================
        // 2. TRIP ENGINE CU
        // NHOM ON + FILTER + PUSH...
        // ========================================

        processMessage(
          key,
          worker,
          message
        );
      }
    );

    // ========================================
    // OLD MESSAGES / CATCH UP
    //
    // DAY LA CAC MESSAGE ZALO TRA VE
    // KHI requestOldMessages() DUOC GOI.
    //
    // CHI LUU VAO CONVERSATION STORE.
    // KHONG CHAY TRIP ENGINE.
    // KHONG PUSH LAI CUOC CU.
    // ========================================

    api.listener.on(
      "old_messages",

      (
        oldMessages,
        type
      ) => {

        if (
          workers.get(key) !==
          worker
        ) {

          return;
        }


        if (
          type !==
          ThreadType.Group
        ) {

          return;
        }


        if (
          !Array.isArray(
            oldMessages
          )
        ) {

          worker.historySyncInProgress =
            false;

          return;
        }


        console.log(
          "[CONVERSATION] OLD MESSAGES RECEIVED:",
          key,
          oldMessages.length
        );

        // ========================================
        // KIEM TRA HUONG CUA CURSOR
        // ========================================

        const cursorTimestamp =
          Number(
            worker
              .historySyncCursor
              ?.timestamp ??
            0
          );


        let newerThanCursor =
          0;


        let olderOrEqualCursor =
          0;


        let minTimestamp =
          null;


        let maxTimestamp =
          null;


        for (
          const message
          of oldMessages
        ) {

          const data =
            message?.data ??
            {};


          const timestamp =
            Number(
              data?.ts ??
              data?.timestamp ??
              0
            );


          if (
            !Number.isFinite(
              timestamp
            ) ||
            timestamp <= 0
          ) {

            continue;
          }


          if (
            minTimestamp == null ||
            timestamp <
              minTimestamp
          ) {

            minTimestamp =
              timestamp;
          }


          if (
            maxTimestamp == null ||
            timestamp >
              maxTimestamp
          ) {

            maxTimestamp =
              timestamp;
          }


          if (
            cursorTimestamp > 0 &&
            timestamp >
              cursorTimestamp
          ) {

            newerThanCursor +=
              1;

          } else {

            olderOrEqualCursor +=
              1;
          }
        }


        console.log(
          "[CONVERSATION] OLD MESSAGES CURSOR DIAG:",
          key,
          {
            cursorMsgId:
              worker
                .historySyncCursor
                ?.msgId ??
              null,

            cursorTimestamp,

            total:
              oldMessages.length,

            newerThanCursor,

            olderOrEqualCursor,

            minTimestamp,

            maxTimestamp,
          }
        );

        // ========================================
        // DEBUG OLD MESSAGE BATCH
        //
        // MUC TIEU:
        // XEM ZALO CO TRA CAC TEXT MESSAGE
        // BI LO TRONG LUC BACKEND TAT HAY KHONG.
        // ========================================

        const oldMessageDiag = {
          total:
            oldMessages.length,

          text:
            0,

          selfText:
            0,

          otherText:
            0,

          textAlreadyStored:
            0,

          textMissingFromStore:
            0,

          samples:
            [],
        };


        for (
          const message
          of oldMessages
        ) {

          const data =
            message?.data ??
            {};


          const content =
            data?.content;


          if (
            typeof content !==
              "string" ||
            content.trim().length ===
              0
          ) {

            continue;
          }


          oldMessageDiag.text +=
            1;


          if (
            message?.isSelf ===
            true
          ) {

            oldMessageDiag.selfText +=
              1;

          } else {

            oldMessageDiag.otherText +=
              1;
          }


          const groupId =
            String(
              message?.threadId ??
              ""
            );


          const msgId =
            data?.msgId != null
              ? String(
                  data.msgId
                )
              : null;


          const cliMsgId =
            data?.cliMsgId != null
              ? String(
                  data.cliMsgId
                )
              : null;


          const existing =
            groupId
              ? findUserConversationMessage(
                  key,
                  groupId,
                  {
                    msgId,
                    cliMsgId,
                  }
                )
              : null;


          if (existing) {

            oldMessageDiag
              .textAlreadyStored +=
              1;

          } else {

            oldMessageDiag
              .textMissingFromStore +=
              1;
          }


          if (
            oldMessageDiag
              .samples
              .length <
            12
          ) {

            oldMessageDiag
              .samples
              .push({
                groupId,

                content:
                  content.length > 80
                    ? `${content.slice(
                        0,
                        80
                      )}...`
                    : content,

                msgId,

                cliMsgId,

                isSelf:
                  message?.isSelf ===
                  true,

                existing:
                  existing != null,

                timestamp:
                  data?.ts ??
                  data?.timestamp ??
                  null,

                msgType:
                  data?.msgType ??
                  null,
              });
          }
        }


        console.log(
          "[CONVERSATION] OLD MESSAGES DIAG:",
          key,
          oldMessageDiag
        );


        void (
          async () => {

            let newCount =
              0;


            const affectedGroups =
              new Map();


            try {

              // ========================================
              // XU LY TUAN TU
              //
              // TRANH NHIEU MESSAGE CUNG GHI
              // FILE JSON MOT LUC.
              // ========================================

              for (
                const message
                of oldMessages
              ) {

                if (
                  workers.get(key) !==
                  worker
                ) {

                  return;
                }


                const groupId =
                  String(
                    message?.threadId ??
                    ""
                  );


                if (!groupId) {
                  continue;
                }


                const data =
                  message?.data ??
                  {};


                const msgId =
                  data?.msgId != null
                    ? String(
                        data.msgId
                      )
                    : null;


                const cliMsgId =
                  data?.cliMsgId != null
                    ? String(
                        data.cliMsgId
                      )
                    : null;


                // ========================================
                // DA CO TRONG STORE
                // -> KHONG LUU LAI.
                //
                // Dieu nay cung giup:
                // deleted_local khong bi song lai.
                // ========================================

                const existing =
                  findUserConversationMessage(
                    key,
                    groupId,
                    {
                      msgId,
                      cliMsgId,
                    }
                  );


                if (existing) {
                  continue;
                }


                try {

                  await storeConversationEvent(
                    key,
                    message
                  );


                  // ========================================
                  // KIEM TRA SAU KHI STORE
                  //
                  // Neu event rong bi bo qua
                  // thi khong tinh la message moi.
                  // ========================================

                  const stored =
                    findUserConversationMessage(
                      key,
                      groupId,
                      {
                        msgId,
                        cliMsgId,
                      }
                    );


                  if (!stored) {
                    continue;
                  }


                  newCount +=
                    1;


                  affectedGroups.set(
                    groupId,
                    (
                      affectedGroups.get(
                        groupId
                      ) ??
                      0
                    ) + 1
                  );

                } catch (error) {

                  console.error(
                    "[CONVERSATION] OLD MESSAGE STORE ERROR:",
                    key,
                    groupId,
                    error
                  );
                }
              }


              console.log(
                "[CONVERSATION] OLD MESSAGES SYNCED:",
                key,
                `new=${newCount}`,
                `groups=${affectedGroups.size}`
              );


              // ========================================
              // BAO CHO FLUTTER:
              // GROUP NAY VUA CO DATA DUOC BO SUNG.
              // ========================================

              for (
                const [
                  groupId,
                  count,
                ]
                of affectedGroups
              ) {

                broadcastUserEvent(
                  key,
                  "conversation_history_synced",
                  {
                    groupId,
                    count,
                  }
                );
              }

            } catch (error) {

              console.error(
                "[CONVERSATION] OLD MESSAGES SYNC ERROR:",
                key,
                error
              );

            } finally {

              if (
                worker.historySyncWatchdog
              ) {

                clearTimeout(
                  worker.historySyncWatchdog
                );

                worker.historySyncWatchdog =
                  null;
              }
              worker.historySyncCursor =
                null;

              worker.historySyncInProgress =
                false;
            }
          }
        )();
      }
    );


    // ========================================
    // CONNECTED
    // ========================================

    api.listener.on(
      "connected",

      () => {

        if (
          workers.get(key) !==
          worker
        ) {
          return;
        }


        worker.status =
          "running";

        worker.lastConnectedAt =
          new Date()
            .toISOString();

        worker.lastError =
          null;

        worker.reconnectAttempts =
          0;

        worker.nextReconnectAt =
          null;


        console.log(
          "[USER WORKER] LISTENER CONNECTED:",
          key
        );

        // ========================================
        // SESSION VAN CON
        // + LISTENER DA KET NOI
        //
        // TU DONG LAY CAC MESSAGE BI LO.
        // ========================================

        requestMissedGroupMessages(
          key,
          worker,
          api
        );
      }
    );


    // ========================================
    // DISCONNECTED
    // ========================================

    api.listener.on(
      "disconnected",

      (reason) => {

        if (
          workers.get(key) !==
          worker
        ) {
          return;
        }


        console.warn(
          "[USER WORKER] DISCONNECTED:",
          key,
          reason
        );


        scheduleReconnect(
          key,
          worker,
          `disconnected: ${formatReason(reason)}`
        );
      }
    );


    // ========================================
    // CLOSED
    // ========================================

    api.listener.on(
      "closed",

      (reason) => {

        if (
          workers.get(key) !==
          worker
        ) {
          return;
        }


        console.warn(
          "[USER WORKER] CLOSED:",
          key,
          reason
        );


        scheduleReconnect(
          key,
          worker,
          `closed: ${formatReason(reason)}`
        );
      }
    );


    // ========================================
    // ERROR
    // ========================================

    api.listener.on(
      "error",

      (error) => {

        if (
          workers.get(key) !==
          worker
        ) {
          return;
        }


        worker.lastError =
          formatReason(error);


        // Chi ghi nhan error.
        // disconnected/closed moi
        // trigger reconnect de tranh
        // tao 2 listener cung luc.
        console.error(
          "[USER WORKER] LISTENER ERROR:",
          key,
          error
        );
      }
    );

    // ========================================
    // MESSAGE RECALLED / UNDO
    // ========================================

    api.listener.on(
      "undo",

      (undo) => {

        if (
          workers.get(key) !==
          worker
        ) {
          return;
        }


        // Hien tai chi quan tam group.
        if (
          undo?.isGroup !==
          true
        ) {
          return;
        }


        try {

          const recalled =
            markConversationMessageRecalledFromUndo(
              key,
              undo
            );


          if (recalled) {

            console.log(
              "[CONVERSATION] RECALLED:",
              key,
              recalled.groupId,
              recalled.msgId ??
              recalled.cliMsgId
            );


            // ========================================
            // BAO CHO FLUTTER CAP NHAT BUBBLE
            // ========================================

            broadcastUserEvent(
              key,
              "conversation_message_updated",
              {
                groupId:
                  recalled.groupId,

                message:
                  recalled,

                reason:
                  "recalled",
              }
            );
          }

        } catch (error) {

          console.error(
            "[CONVERSATION] UNDO ERROR:",
            key,
            error
          );
        }
      }
    );


    // ========================================
    // START
    // ========================================

    await api.listener.start();

    worker.status =
      "running";

    worker.startedAt =
      worker.startedAt ??
      new Date()
        .toISOString();

    worker.lastConnectedAt =
      new Date()
        .toISOString();

    console.log(
      "[USER WORKER] RUNNING:",
      key,
      "->",
      worker.ownId
    );


    return publicWorker(
      worker
    );

  } catch (error) {

    worker.status =
      "error";

    worker.lastError =
      error?.message ??
      String(error);


    console.error(
      "[USER WORKER] START ERROR:",
      key,
      error
    );


    throw error;
  }
}

// ========================================
// SEND MULTIPLE PHOTOS
//
// QUAN TRONG:
// TAT CA PHOTOS PHAI NAM TRONG
// CUNG MOT sendMessage()
//
// zca-js se tu tao:
// groupLayoutId
// idInGroup
// totalItemInGroup
// ========================================

export async function sendUserConversationPhotos(
  userId,
  groupId,
  {
    photos = [],
  } = {}
) {

  const key =
    String(
      userId
    );


  const safeGroupId =
    String(
      groupId ??
      ""
    ).trim();


  if (!safeGroupId) {

    const error =
      new Error(
        "Group ID khong hop le."
      );


    error.code =
      "INVALID_GROUP_ID";


    throw error;
  }


  const worker =
    workers.get(
      key
    );


  if (
    !worker ||
    !worker.api ||
    worker.status !==
      "running"
  ) {

    const error =
      new Error(
        "Zalo chua san sang de gui anh."
      );


    error.code =
      "WORKER_NOT_READY";


    throw error;
  }


  if (
    !Array.isArray(
      photos
    ) ||
    photos.length ===
      0
  ) {

    const error =
      new Error(
        "Chua co anh de gui."
      );


    error.code =
      "NO_PHOTOS";


    throw error;
  }


  if (
    photos.length >
      10
  ) {

    const error =
      new Error(
        "Moi lan chi gui toi da 10 anh."
      );


    error.code =
      "TOO_MANY_PHOTOS";


    throw error;
  }


  const attachments =
    photos.map(
      (
        photo,
        index
      ) => {

        const data =
          photo?.data;


        if (
          !Buffer.isBuffer(
            data
          ) ||
          data.length ===
            0
        ) {

          const error =
            new Error(
              `Anh ${index + 1} khong hop le.`
            );


          error.code =
            "INVALID_PHOTO_DATA";


          throw error;
        }


        const width =
          Number(
            photo?.width
          );


        const height =
          Number(
            photo?.height
          );


        if (
          !Number.isFinite(
            width
          ) ||
          width <= 0 ||
          !Number.isFinite(
            height
          ) ||
          height <= 0
        ) {

          const error =
            new Error(
              `Khong doc duoc kich thuoc anh ${index + 1}.`
            );


          error.code =
            "INVALID_PHOTO_DIMENSIONS";


          throw error;
        }


        const filename =
          String(
            photo?.filename ??
            `photo-${Date.now()}-${index}.jpg`
          );


        return {

          data,

          filename,

          metadata: {

            totalSize:
              data.length,

            width:
              Math.round(
                width
              ),

            height:
              Math.round(
                height
              ),
          },
        };
      }
    );


  // ========================================
  // CHI MOT sendMessage()
  // ========================================

  const result =
    await worker.api
      .sendMessage(
        {
          msg:
            "",

          attachments,
        },

        safeGroupId,

        ThreadType.Group
      );


  console.log(
    "[CHAT PHOTOS] SENT:",
    key,
    safeGroupId,
    `count=${attachments.length}`
  );


  return result;
}

// ========================================
// SEND PHOTO TO ZALO GROUP
//
// DUNG CHINH API CUA WORKER DANG CHAY.
//
// KHONG TU SAVE VAO CONVERSATION STORE.
// LISTENER "message" SE NHAN LAI chat.photo
// -> storeConversationEvent()
// -> broadcast ve Flutter.
// ========================================

export async function sendUserConversationPhoto(
  userId,
  groupId,
  {
    data,
    filename,
    width,
    height,
  } = {}
) {

  const key =
    String(
      userId
    );


  const safeGroupId =
    String(
      groupId ??
      ""
    ).trim();


  if (!safeGroupId) {

    const error =
      new Error(
        "Group ID khong hop le."
      );


    error.code =
      "INVALID_GROUP_ID";


    throw error;
  }


  // ========================================
  // LAY WORKER DANG CHAY
  // ========================================

  const worker =
    workers.get(
      key
    );


  if (
    !worker ||
    !worker.api ||
    worker.status !==
      "running"
  ) {

    const error =
      new Error(
        "Zalo chua san sang de gui anh."
      );


    error.code =
      "WORKER_NOT_READY";


    throw error;
  }


  // ========================================
  // VALIDATE BUFFER
  // ========================================

  if (
    !Buffer.isBuffer(
      data
    ) ||
    data.length === 0
  ) {

    const error =
      new Error(
        "Du lieu anh khong hop le."
      );


    error.code =
      "INVALID_PHOTO_DATA";


    throw error;
  }


  const safeFilename =
    String(
      filename ??
      ""
    ).trim();


  if (!safeFilename) {

    const error =
      new Error(
        "Ten file anh khong hop le."
      );


    error.code =
      "INVALID_PHOTO_FILENAME";


    throw error;
  }


  const safeWidth =
    Number(
      width
    );


  const safeHeight =
    Number(
      height
    );


  if (
    !Number.isFinite(
      safeWidth
    ) ||
    safeWidth <= 0 ||
    !Number.isFinite(
      safeHeight
    ) ||
    safeHeight <= 0
  ) {

    const error =
      new Error(
        "Khong doc duoc kich thuoc anh."
      );


    error.code =
      "INVALID_PHOTO_DIMENSIONS";


    throw error;
  }


  // ========================================
  // GUI ANH
  //
  // zca-js AttachmentSource:
  //
  // {
  //   data: Buffer,
  //   filename: "...jpg",
  //   metadata: {
  //     totalSize,
  //     width,
  //     height
  //   }
  // }
  // ========================================

  const result =
    await worker.api
      .sendMessage(
        {
          msg:
            "",

          attachments: {
            data,

            filename:
              safeFilename,

            metadata: {
              totalSize:
                data.length,

              width:
                Math.round(
                  safeWidth
                ),

              height:
                Math.round(
                  safeHeight
                ),
            },
          },
        },

        safeGroupId,

        ThreadType.Group
      );


  console.log(
    "[CHAT PHOTO] SENT:",
    key,
    safeGroupId,
    safeFilename,
    `${safeWidth}x${safeHeight}`
  );


  return result;
}


// ========================================
// STATUS ONE USER
// ========================================

export function getUserWorkerStatus(
  userId
) {
  return publicWorker(
    workers.get(
      String(userId)
    )
  );
}


// ========================================
// START ALL LINKED USERS
// ========================================

export async function startAllUserWorkers() {
  const users =
    getLinkedUsers();


  console.log(
    "[USER WORKERS] Linked users:",
    users.length
  );


  for (const user of users) {

    try {

      await startUserWorker(
        user.id
      );

    } catch (error) {

      console.error(
        "[USER WORKERS] Cannot start:",
        user.id,
        error?.message ??
        error
      );
    }
  }


  console.log(
    "[USER WORKERS] Startup complete"
  );
}

// ========================================
// NETWORK AVAILABLE / OFFLINE
// ========================================

export function setWorkersNetworkAvailable(
  available,
  reason = null
) {
  networkAvailable =
    available === true;


  console.log(
    "[USER WORKERS] NETWORK:",
    networkAvailable
      ? "ONLINE"
      : "OFFLINE"
  );


  // Neu online tro lai,
  // watchdog se goi restart rieng.
  if (networkAvailable) {
    return;
  }


  // ========================================
  // OFFLINE
  // DUNG CAC RECONNECT TIMER
  // ========================================

  for (
    const [
      userId,
      worker,
    ]
    of workers
  ) {

    if (
      worker.reconnectTimer
    ) {
      clearTimeout(
        worker.reconnectTimer
      );

      worker.reconnectTimer =
        null;
    }

    // ========================================
    // DUNG HISTORY SYNC KHI MAT INTERNET
    // ========================================

    if (
      worker.historySyncTimer
    ) {

      clearTimeout(
        worker.historySyncTimer
      );


      worker.historySyncTimer =
        null;
    }


    if (
      worker.historySyncWatchdog
    ) {

      clearTimeout(
        worker.historySyncWatchdog
      );


      worker.historySyncWatchdog =
        null;
    }


    worker.historySyncInProgress =
      false;


    worker.nextReconnectAt =
      null;


    if (
      worker.status !==
      "needs_relink"
    ) {
      worker.status =
        "offline";

      worker.lastError =
        reason ??
        "internet_offline";
    }


    console.warn(
      "[USER WORKER] MARKED OFFLINE:",
      userId
    );
  }
}


// ========================================
// DISPOSE OLD WORKER
// ========================================

async function disposeUserWorker(
  userId,
  worker
) {

  const key =
    String(
      userId
    );


  // ========================================
  // STOP RECONNECT TIMER
  // ========================================

  if (
    worker?.reconnectTimer
  ) {

    clearTimeout(
      worker.reconnectTimer
    );


    worker.reconnectTimer =
      null;
  }


  // ========================================
  // STOP HISTORY SYNC TIMER
  //
  // TRANH WORKER CU VAN GUI
  // requestOldMessages SAU KHI DA RESTART.
  // ========================================

  if (
    worker?.historySyncTimer
  ) {

    clearTimeout(
      worker.historySyncTimer
    );


    worker.historySyncTimer =
      null;
  }


  // ========================================
  // STOP HISTORY SYNC WATCHDOG
  // ========================================

  if (
    worker?.historySyncWatchdog
  ) {

    clearTimeout(
      worker.historySyncWatchdog
    );


    worker.historySyncWatchdog =
      null;
  }


  if (worker) {

    worker.historySyncCursor =
      null;

    worker.historySyncInProgress =
      false;
  }


  // ========================================
  // XOA WORKER KHOI MAP TRUOC
  //
  // NEU LISTENER CU PHAT EVENT SAU DO
  // CALLBACK SE TU BO QUA.
  // ========================================

  if (
    workers.get(key) ===
    worker
  ) {

    workers.delete(
      key
    );
  }


  // ========================================
  // STOP ZALO LISTENER
  // ========================================

  try {

    const listener =
      worker?.api?.listener;


    if (
      listener &&
      typeof listener.stop ===
        "function"
    ) {

      await Promise.resolve(
        listener.stop()
      );
    }

  } catch (error) {

    console.warn(
      "[USER WORKER] STOP OLD LISTENER ERROR:",
      key,
      error?.message ??
      error
    );
  }


  // ========================================
  // CLEAR API CACHE
  // ========================================

  clearUserZaloConnection(
    key
  );
}


// ========================================
// FORCE RESTART ONE USER
// ========================================

export async function forceRestartUserWorker(
  userId,
  reason = "force_restart"
) {
  const key =
    String(userId);


  console.warn(
    "[USER WORKER] FORCE RESTART:",
    key,
    reason
  );


  const oldWorker =
    workers.get(key);


  if (oldWorker) {

    await disposeUserWorker(
      key,
      oldWorker
    );

  } else {

    clearUserZaloConnection(
      key
    );
  }


  return startUserWorker(
    key
  );
}


// ========================================
// RESTART CAC WORKER CO THE PHUC HOI
// ========================================

export async function restartRecoverableUserWorkers(
  reason = "network_restored"
) {
  if (!networkAvailable) {
    return;
  }


  const recoverableStatuses =
    new Set([
      "running",
      "offline",
      "reconnecting",
      "error",
      "starting",
    ]);


  const userIds =
    [];


  for (
    const [
      userId,
      worker,
    ]
    of workers
  ) {

    if (
      recoverableStatuses.has(
        worker.status
      )
    ) {
      userIds.push(
        userId
      );
    }
  }


  console.log(
    "[USER WORKERS] RECOVER:",
    userIds.length,
    "worker(s)"
  );


  for (
    const userId
    of userIds
  ) {

    try {

      await forceRestartUserWorker(
        userId,
        reason
      );

    } catch (error) {

      console.error(
        "[USER WORKERS] RECOVERY FAILED:",
        userId,
        error?.message ??
        error
      );
    }
  }
}

// ========================================
// STOP ONE USER WORKER
// ========================================

export async function stopUserWorker(
  userId
) {
  const key =
    String(userId);


  const worker =
    workers.get(key);


  if (!worker) {

    clearUserZaloConnection(
      key
    );


    return {
      stopped: true,
      existed: false,
    };
  }


  console.log(
    "[USER WORKER] STOPPING:",
    key
  );


  await disposeUserWorker(
    key,
    worker
  );


  console.log(
    "[USER WORKER] STOPPED:",
    key
  );


  return {
    stopped: true,
    existed: true,
  };
}