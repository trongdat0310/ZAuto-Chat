import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const messagesPath = path.resolve(
  __dirname,
  "../../data/messages.json"
);


// ========================================
// READ
// ========================================

function readMessages() {
  if (!fs.existsSync(messagesPath)) {
    return [];
  }

  try {
    const data = JSON.parse(
      fs.readFileSync(messagesPath, "utf-8")
    );

    return Array.isArray(data) ? data : [];
  } catch (error) {
    console.error(
      "[MESSAGES] Khong doc duoc messages.json"
    );

    return [];
  }
}


// ========================================
// WRITE
// ========================================

function writeMessages(messages) {
  fs.writeFileSync(
    messagesPath,
    JSON.stringify(messages, null, 2),
    "utf-8"
  );
}


// ========================================
// SAVE MESSAGE
// ========================================

export function saveMessage({
  groupId,
  groupName = null,

  senderId = null,
  senderName = null,

  zaloMessageId = null,
  clientMessageId = null,

  sourceTimestamp = null,

  content,
}) {
  const messages = readMessages();


  // ========================================
  // DEDUPE KEY
  // ========================================

  const sourceId =
    zaloMessageId ??
    clientMessageId ??
    null;


  const fallbackKey =
    crypto
      .createHash("sha256")
      .update(
        [
          String(groupId),
          String(senderId ?? ""),
          String(sourceTimestamp ?? ""),
          String(content),
        ].join("|")
      )
      .digest("hex");


  const dedupeKey =
    sourceId
      ? `zalo:${sourceId}`
      : `fallback:${fallbackKey}`;


  // ========================================
  // CHONG TRUNG
  // ========================================

  const existed =
    messages.find(
      item =>
        item.dedupeKey === dedupeKey ||

        (
          zaloMessageId &&
          item.zaloMessageId ===
            String(zaloMessageId)
        )
    );


  if (existed) {
    console.log(
      "[MESSAGES] DUPLICATE IGNORE:",
      dedupeKey
    );

    return existed;
  }


  // ========================================
  // SAVE
  // ========================================

  const message = {
    id: crypto.randomUUID(),

    dedupeKey,

    zaloMessageId:
      zaloMessageId
        ? String(zaloMessageId)
        : null,

    clientMessageId:
      clientMessageId
        ? String(clientMessageId)
        : null,

    groupId:
      String(groupId),

    groupName:
      groupName ?? null,

    senderId:
      senderId
        ? String(senderId)
        : null,

    senderName:
      senderName ?? null,

    content,

    status: "new",

    sourceTimestamp:
      sourceTimestamp
        ? String(sourceTimestamp)
        : null,

    receivedAt:
      new Date().toISOString(),
  };


  messages.unshift(message);


  if (messages.length > 1000) {
    messages.length = 1000;
  }


  writeMessages(messages);


  console.log(
    "[MESSAGES] SAVED:",
    message.id
  );


  return message;
}


// ========================================
// GET ALL
// ========================================

export function getMessages(limit = 100) {
  const messages = readMessages();

  return messages.slice(
    0,
    Math.max(1, Math.min(limit, 500))
  );
}


// ========================================
// GET ONE
// ========================================

export function getMessageById(id) {
  const messages = readMessages();

  return messages.find(
    message => message.id === id
  ) ?? null;
}

// ========================================
// UPDATE MESSAGE
// ========================================

export function updateMessage(
  id,
  updates
) {
  const messages = readMessages();

  const index = messages.findIndex(
    message => message.id === id
  );

  if (index === -1) {
    return null;
  }

  messages[index] = {
    ...messages[index],
    ...updates,
  };

  writeMessages(messages);

  return messages[index];
}