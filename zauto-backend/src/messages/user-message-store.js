import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";


const __filename =
  fileURLToPath(import.meta.url);

const __dirname =
  path.dirname(__filename);


const rootPath =
  path.resolve(
    __dirname,
    "../../data/user-data"
  );


// ========================================
// PATH
// ========================================

function getUserDir(userId) {
  return path.join(
    rootPath,
    String(userId)
  );
}


function getMessagesPath(userId) {
  return path.join(
    getUserDir(userId),
    "messages.json"
  );
}


// ========================================
// READ
// ========================================

function readUserMessages(userId) {
  const filePath =
    getMessagesPath(userId);


  if (!fs.existsSync(filePath)) {
    return [];
  }


  try {
    const data =
      JSON.parse(
        fs.readFileSync(
          filePath,
          "utf-8"
        )
      );


    return Array.isArray(data)
      ? data
      : [];

  } catch (error) {

    console.error(
      "[USER MESSAGES] READ ERROR:",
      userId,
      error
    );


    return [];
  }
}


// ========================================
// WRITE
// ========================================

function writeUserMessages(
  userId,
  messages
) {
  const userDir =
    getUserDir(userId);


  fs.mkdirSync(
    userDir,
    {
      recursive: true,
    }
  );


  fs.writeFileSync(
    getMessagesPath(userId),

    JSON.stringify(
      messages,
      null,
      2
    ),

    "utf-8"
  );
}


// ========================================
// SAVE
// ========================================

export function saveUserMessage(
  userId,
  {
    groupId,
    groupName = null,

    senderId = null,
    senderName = null,

    // ========================================
    // ID CU
    // ========================================

    zaloMessageId = null,
    clientMessageId = null,

    sourceTimestamp = null,


    // ========================================
    // LINK DEN TIN NHAN ZALO GOC
    // ========================================

    sourceThreadId = null,
    sourceMsgId = null,
    sourceCliMsgId = null,

    content,
  }
) {
  const messages =
    readUserMessages(userId);


  // ========================================
  // DEDUPE
  // ========================================

  const sourceId =
    zaloMessageId ??
    clientMessageId ??
    null;


  const fallbackHash =
    crypto
      .createHash("sha256")
      .update(
        [
          String(groupId),
          String(senderId ?? ""),
          String(sourceTimestamp ?? ""),
          String(content ?? ""),
        ].join("|")
      )
      .digest("hex");


  const dedupeKey =
    sourceId
      ? `zalo:${groupId}:${sourceId}`
      : `fallback:${fallbackHash}`;


  const existed =
    messages.find(
      item =>
        item.dedupeKey ===
        dedupeKey
    );


  if (existed) {
    console.log(
      "[USER MESSAGES] DUPLICATE:",
      userId,
      dedupeKey
    );


    return {
      created: false,
      message: existed,
    };
  }


  const message = {
    id:
      crypto.randomUUID(),

    dedupeKey,


    // ========================================
    // ID CU - GIU DE TUONG THICH
    // ========================================

    zaloMessageId:
      zaloMessageId != null
        ? String(
            zaloMessageId
          )
        : null,

    clientMessageId:
      clientMessageId != null
        ? String(
            clientMessageId
          )
        : null,


    // ========================================
    // GROUP / SENDER
    // ========================================

    groupId:
      String(
        groupId
      ),

    groupName,

    senderId:
      senderId != null
        ? String(
            senderId
          )
        : null,

    senderName,


    // ========================================
    // CONTENT
    // ========================================

    content:
      String(
        content ??
        ""
      ),

    status:
      "new",


    // ========================================
    // LINK DEN TIN NHAN ZALO GOC
    // ========================================

    sourceThreadId:
      sourceThreadId != null
        ? String(
            sourceThreadId
          )
        : String(
            groupId
          ),

    sourceMsgId:
      sourceMsgId != null
        ? String(
            sourceMsgId
          )
        : (
            zaloMessageId != null
              ? String(
                  zaloMessageId
                )
              : null
          ),

    sourceCliMsgId:
      sourceCliMsgId != null
        ? String(
            sourceCliMsgId
          )
        : (
            clientMessageId != null
              ? String(
                  clientMessageId
                )
              : null
          ),


    sourceTimestamp:
      sourceTimestamp != null
        ? String(
            sourceTimestamp
          )
        : null,


    // ========================================
    // TIMES
    // ========================================

    receivedAt:
      new Date()
        .toISOString(),

    acceptedAt:
      null,
  };


  messages.unshift(
    message
  );


  // Tam gioi han 1000 cuoc / user
  if (
    messages.length > 1000
  ) {
    messages.length =
      1000;
  }


  writeUserMessages(
    userId,
    messages
  );


  console.log(
    "[USER MESSAGES] SAVED:",
    userId,
    message.id
  );


  return {
    created: true,
    message,
  };
}


// ========================================
// GET ALL
// ========================================

export function getUserMessages(
  userId,
  limit = 100
) {
  const messages =
    readUserMessages(userId);


  const safeLimit =
    Math.max(
      1,
      Math.min(
        Number(limit) || 100,
        500
      )
    );


  return messages.slice(
    0,
    safeLimit
  );
}


// ========================================
// GET ONE
// ========================================

export function getUserMessageById(
  userId,
  messageId
) {
  return (
    readUserMessages(
      userId
    ).find(
      message =>
        message.id ===
        messageId
    ) ?? null
  );
}


// ========================================
// UPDATE
// ========================================

export function updateUserMessage(
  userId,
  messageId,
  updates
) {
  const messages =
    readUserMessages(userId);


  const index =
    messages.findIndex(
      message =>
        message.id ===
        messageId
    );


  if (index === -1) {
    return null;
  }


  messages[index] = {
    ...messages[index],
    ...updates,

    // Khong cho updates doi internal ID
    id:
      messages[index].id,
  };


  writeUserMessages(
    userId,
    messages
  );


  return messages[index];
}