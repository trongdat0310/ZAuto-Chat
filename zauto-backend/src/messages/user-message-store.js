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
// RAM CACHE + WRITE-BEHIND STATE
//
// Realtime hot path:
// - cache miss: doc disk 1 lan
// - message tiep theo: chi RAM
// - save: mutate RAM, schedule persist
// ========================================

const messageCache =
  new Map();


// userId -> {
//   dirty,
//   scheduled,
//   writing,
//   waiters,
// }
const writeStates =
  new Map();


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
  const key =
    String(
      userId
    );


  const cached =
    messageCache.get(
      key
    );


  if (cached) {
    return cached;
  }


  const filePath =
    getMessagesPath(
      key
    );


  let messages =
    [];


  if (
    fs.existsSync(
      filePath
    )
  ) {
    try {
      const data =
        JSON.parse(
          fs.readFileSync(
            filePath,
            "utf-8"
          )
        );


      if (
        Array.isArray(
          data
        )
      ) {
        messages =
          data;
      }

    } catch (error) {

      console.error(
        "[USER MESSAGES] READ ERROR:",
        key,
        error
      );
    }
  }


  messageCache.set(
    key,
    messages
  );


  return messages;
}


// ========================================
// ASYNC ATOMIC PERSIST
//
// Khong chan event loop truoc websocket.
// Neu co nhieu thay doi trong luc dang ghi,
// loop se ghi snapshot moi nhat them 1 lan.
// ========================================

function getWriteState(
  userId
) {
  const key =
    String(
      userId
    );


  let state =
    writeStates.get(
      key
    );


  if (!state) {
    state = {
      dirty:
        false,

      scheduled:
        false,

      writing:
        false,

      waiters:
        [],
    };


    writeStates.set(
      key,
      state
    );
  }


  return state;
}


function resolveWriteWaiters(
  state
) {
  if (
    state.dirty ||
    state.scheduled ||
    state.writing
  ) {
    return;
  }


  const waiters =
    state.waiters.splice(
      0
    );


  for (
    const resolve of waiters
  ) {
    resolve();
  }
}


async function flushUserMessagesInternal(
  userId
) {
  const key =
    String(
      userId
    );


  const state =
    getWriteState(
      key
    );


  if (state.writing) {
    return;
  }


  state.scheduled =
    false;

  state.writing =
    true;


  try {

    while (state.dirty) {

      state.dirty =
        false;


      const messages =
        readUserMessages(
          key
        );


      // Snapshot string duoc tao truoc await.
      // Message den sau se set dirty=true
      // va duoc ghi o vong tiep theo.
      const serialized =
        JSON.stringify(
          messages,
          null,
          2
        );


      const userDir =
        getUserDir(
          key
        );


      await fs.promises.mkdir(
        userDir,
        {
          recursive: true,
        }
      );


      const filePath =
        getMessagesPath(
          key
        );


      const tempPath =
        `${filePath}.tmp-${process.pid}-${Date.now()}`;


      await fs.promises.writeFile(
        tempPath,
        serialized,
        "utf-8"
      );


      await fs.promises.rename(
        tempPath,
        filePath
      );
    }

  } catch (error) {

    // Thu lai snapshot moi nhat lan sau.
    state.dirty =
      true;


    console.error(
      "[USER MESSAGES] ASYNC WRITE ERROR:",
      key,
      error
    );


    setTimeout(
      () => {
        scheduleUserMessagesPersist(
          key
        );
      },
      250
    );

  } finally {

    state.writing =
      false;


    resolveWriteWaiters(
      state
    );
  }
}


function scheduleUserMessagesPersist(
  userId
) {
  const key =
    String(
      userId
    );


  const state =
    getWriteState(
      key
    );


  state.dirty =
    true;


  if (
    state.scheduled ||
    state.writing
  ) {
    return;
  }


  state.scheduled =
    true;


  setImmediate(
    () => {
      void flushUserMessagesInternal(
        key
      );
    }
  );
}


// Test / graceful shutdown helper.
export function flushUserMessages(
  userId
) {
  const key =
    String(
      userId
    );


  const state =
    getWriteState(
      key
    );


  if (
    !state.dirty &&
    !state.scheduled &&
    !state.writing
  ) {
    return Promise.resolve();
  }


  return new Promise(
    resolve => {

      state.waiters.push(
        resolve
      );


      if (
        !state.scheduled &&
        !state.writing
      ) {
        state.scheduled =
          true;


        setImmediate(
          () => {
            void flushUserMessagesInternal(
              key
            );
          }
        );
      }
    }
  );
}


// Test helper. Khong dung tren production hot path.
export function clearUserMessageCache(
  userId
) {
  const key =
    String(
      userId
    );


  messageCache.delete(
    key
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


  scheduleUserMessagesPersist(
    userId
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


  scheduleUserMessagesPersist(
    userId
  );


  return messages[index];
}