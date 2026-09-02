import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";


const __filename =
  fileURLToPath(import.meta.url);

const __dirname =
  path.dirname(__filename);


const USER_DATA_ROOT =
  path.resolve(
    __dirname,
    "../../data/user-data"
  );


// ========================================
// PATHS
// ========================================

function conversationRoot(
  userId
) {
  return path.join(
    USER_DATA_ROOT,
    String(userId),
    "conversations"
  );
}


function messagesRoot(
  userId
) {
  return path.join(
    conversationRoot(userId),
    "messages"
  );
}


function indexFile(
  userId
) {
  return path.join(
    conversationRoot(userId),
    "index.json"
  );
}


function safeGroupId(
  groupId
) {
  return String(groupId)
    .replace(
      /[^A-Za-z0-9_-]/g,
      "_"
    );
}


function groupMessageFile(
  userId,
  groupId
) {
  return path.join(
    messagesRoot(userId),
    `${safeGroupId(groupId)}.json`
  );
}


// ========================================
// FILE HELPERS
// ========================================

function ensureDir(
  dir
) {
  fs.mkdirSync(
    dir,
    {
      recursive: true,
    }
  );
}


function readJson(
  file,
  fallback
) {
  try {

    if (
      !fs.existsSync(file)
    ) {
      return fallback;
    }


    return JSON.parse(
      fs.readFileSync(
        file,
        "utf8"
      )
    );

  } catch (error) {

    console.error(
      "[CONVERSATION STORE] READ ERROR:",
      file,
      error
    );

    return fallback;
  }
}


function writeJsonAtomic(
  file,
  value
) {
  ensureDir(
    path.dirname(file)
  );


  const tempFile =
    `${file}.${process.pid}.${Date.now()}.tmp`;


  fs.writeFileSync(
    tempFile,
    JSON.stringify(
      value,
      null,
      2
    ),
    "utf8"
  );


  fs.renameSync(
    tempFile,
    file
  );
}


// ========================================
// NORMALIZE
// ========================================

function normalizeTimestamp(
  value
) {
  const number =
    Number(value);


  if (
    !Number.isFinite(number) ||
    number <= 0
  ) {
    return Date.now();
  }


  // Neu server tra timestamp giay
  // thi chuyen sang milliseconds.
  if (
    number <
    1_000_000_000_000
  ) {
    return number * 1000;
  }


  return number;
}


function safeClone(
  value
) {
  try {

    return JSON.parse(
      JSON.stringify(value)
    );

  } catch {
    return null;
  }
}

// ========================================
// MESSAGE CO THUC SU CAN HIEN TREN CHAT?
//
// MOT SO EVENT NOI BO CUA ZALO
// CO THE DI QUA LISTENER "message"
// NHUNG KHONG PHAI TIN NHAN CHAT.
//
// VD:
// - thao tac delete
// - event noi bo
// - payload khong co noi dung
//
// KHONG DUOC LUU CHUNG THANH:
// [Tin nhắn]
// ========================================

function isDisplayableConversationMessage(
  data
) {

  const content =
    data?.content;


  // ========================================
  // TEXT MESSAGE
  // ========================================

  if (
    typeof content === "string" &&
    content.trim().length > 0
  ) {

    return true;
  }


  // ========================================
  // MESSAGE TYPE
  // ========================================

  const msgType =
    String(
      data?.msgType ?? ""
    )
      .trim()
      .toLowerCase();


  // ========================================
  // CURRENT ZALO MESSAGE TYPES
  // ========================================

  const displayableTypes =
    new Set([

      // PHOTO
      "chat.photo",

      // STICKER
      "chat.sticker",

      // VIDEO
      "chat.video",
      "chat.video.msg",

      // FILE
      "chat.file",
      "chat.file.msg",
      "share.file",

      // GIF
      "chat.gif",

      // VOICE / AUDIO
      "chat.voice",
      "chat.voice.msg",
      "chat.audio",
    ]);


  if (
    displayableTypes.has(
      msgType
    )
  ) {

    return true;
  }


  // ========================================
  // OLD NUMERIC MESSAGE TYPES
  // ========================================
  //
  // Giữ tương thích với dữ liệu cũ.
  //
  // 31 = voice
  // 32 = photo
  // 44 = video
  // 46 = file
  // 49 = gif
  //
  // ========================================

  const legacyTypes =
    new Set([
      "31",
      "32",
      "44",
      "46",
      "49",
    ]);


  if (
    legacyTypes.has(
      msgType
    )
  ) {

    return true;
  }


  return false;
}

function messagePreview(
  data
) {

  const content =
    data?.content;


  const rawMsgType =
    data?.msgType;


  const msgType =
    String(
      rawMsgType ??
      ""
    )
      .trim()
      .toLowerCase();


  // ========================================
  // TEXT MESSAGE
  // ========================================

  if (
    typeof content ===
      "string"
  ) {

    const text =
      content.trim();


    if (text) {
      return text;
    }
  }


  // ========================================
  // PHOTO PARAMS
  //
  // Zalo chat.photo:
  //
  // content.params.total_item_in_group
  // content.params.group_layout_id
  // ========================================

  const params =
    content &&
    typeof content ===
      "object"
      ? (
          content.params &&
          typeof content.params ===
            "object"
            ? content.params
            : {}
        )
      : {};


  const totalPhotoInGroup =
    Number(
      params
        .total_item_in_group ??
      params
        .totalItemInGroup ??
      0
    );


  // ========================================
  // STRING MSG TYPES
  // ========================================

  switch (msgType) {

    // ========================================
    // PHOTO
    // ========================================

    case "chat.photo":

      if (
        Number.isFinite(
          totalPhotoInGroup
        ) &&
        totalPhotoInGroup > 1
      ) {

        return `[${totalPhotoInGroup} hình ảnh]`;
      }


      return "[Hình ảnh]";


    // ========================================
    // VIDEO
    // ========================================

    case "chat.video.msg":
    case "chat.video":

      return "[Video]";


    // ========================================
    // STICKER
    // ========================================

    case "chat.sticker":

      return "[Nhãn dán]";


    // ========================================
    // FILE
    // ========================================

    case "share.file":
    case "chat.file":
    case "chat.file.msg":

      if (
        content &&
        typeof content ===
          "object" &&
        typeof content.title ===
          "string" &&
        content.title.trim()
      ) {

        return `[Tệp] ${content.title.trim()}`;
      }


      return "[Tệp]";


    // ========================================
    // GIF
    // ========================================

    case "chat.gif":

      return "[GIF]";


    // ========================================
    // VOICE
    // ========================================

    case "chat.voice":
    case "chat.voice.msg":
    case "chat.audio":

      return "[Tin nhắn thoại]";
  }


  // ========================================
  // OLD NUMERIC MSG TYPES
  //
  // GIU TUONG THICH DATA CU.
  // ========================================

  const numericType =
    Number(
      rawMsgType
    );


  switch (numericType) {

    case 31:
      return "[Tin nhắn thoại]";


    case 32:
      return "[Hình ảnh]";


    case 44:
      return "[Video]";


    case 46:
      return "[Tệp]";


    case 49:
      return "[GIF]";


    default:
      return "[Tin nhắn]";
  }
}

// ========================================
// UNREAD HELPERS
// ========================================

function normalizeUnreadCount(
  value
) {

  const number =
    Number(
      value
    );


  if (
    !Number.isFinite(
      number
    ) ||
    number < 0
  ) {

    return 0;
  }


  return Math.floor(
    number
  );
}


// ========================================
// SORT CONVERSATIONS
// ========================================

function sortConversations(
  conversations
) {
  conversations.sort(
    (a, b) => {

      const aTime =
        Number(
          a.lastMessageAt ??
          0
        );


      const bTime =
        Number(
          b.lastMessageAt ??
          0
        );


      if (
        aTime !== bTime
      ) {
        return bTime - aTime;
      }


      return String(
        a.name ?? ""
      ).localeCompare(
        String(
          b.name ?? ""
        ),
        "vi"
      );
    }
  );


  return conversations;
}


// ========================================
// SYNC ALL GROUPS
// ========================================

export function syncConversationGroups(
  userId,
  groups = []
) {
  ensureDir(
    messagesRoot(userId)
  );


  const file =
    indexFile(userId);


  const current =
    readJson(
      file,
      []
    );


  const byGroupId =
    new Map(
      current.map(
        item => [
          String(item.groupId),
          item,
        ]
      )
    );


  for (
    const group
    of groups
  ) {

    const groupId =
      String(
        group.groupId
      );


    const old =
      byGroupId.get(
        groupId
      );


    byGroupId.set(
      groupId,
      {
        groupId,

        name:
          group.name ??
          old?.name ??
          "Nhóm Zalo",

        avatar:
          group.avatar ??
          group.avt ??
          group.fullAvt ??
          old?.avatar ??
          null,

        totalMember:
          group.totalMember ??
          old?.totalMember ??
          null,

        lastMessageId:
          old?.lastMessageId ??
          null,

        lastCliMsgId:
          old?.lastCliMsgId ??
          null,

        lastContent:
          old?.lastContent ??
          null,

        lastSenderName:
          old?.lastSenderName ??
          null,

        lastIsSelf:
          old?.lastIsSelf ??
          null,

        lastMsgType:
          old?.lastMsgType ??
          null,

        lastMessageAt:
          old?.lastMessageAt ??
          null,


        // ========================================
        // READ STATE
        //
        // Với dữ liệu cũ chưa từng có unread,
        // coi trạng thái hiện tại là đã đọc.
        //
        // Như vậy sau khi update app,
        // user không tự nhiên thấy hàng chục
        // tin lịch sử thành unread.
        // ========================================

        unreadCount:
          normalizeUnreadCount(
            old?.unreadCount
          ),


        lastReadAt:
          old?.lastReadAt ??
          new Date()
            .toISOString(),


        lastReadMessageId:
          old?.lastReadMessageId ??
          old?.lastMessageId ??
          null,


        lastReadCliMsgId:
          old?.lastReadCliMsgId ??
          old?.lastCliMsgId ??
          null,


        lastReadMessageAt:
          old?.lastReadMessageAt ??
          old?.lastMessageAt ??
          null,


        createdAt:
          old?.createdAt ??
          new Date()
            .toISOString(),


        updatedAt:
          new Date()
            .toISOString(),
      }
    );
  }


  const result =
    sortConversations(
      Array.from(
        byGroupId.values()
      )
    );


  writeJsonAtomic(
    file,
    result
  );


  return result;
}

// ========================================
// PHOTO MEDIA METADATA
//
// ZALO REAL PAYLOAD:
//
// content.params = JSON string
//
// {
//   is_group_layout: 1,
//   group_layout_id: 123,
//   id_in_group: 0,
//   total_item_in_group: 4,
//   width: 1920,
//   height: 2560,
//   hd: "..."
// }
// ========================================

function extractPhotoMediaMetadata(
  data
) {

  const msgType =
    String(
      data?.msgType ??
      ""
    )
      .trim()
      .toLowerCase();


  if (
    msgType !==
      "chat.photo" &&
    msgType !==
      "32"
  ) {

    return null;
  }


  const content =
    data?.content &&
    typeof data.content ===
      "object"
      ? data.content
      : {};


  let params =
    {};


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

    } catch (_) {

      params =
        {};
    }

  } else if (
    content.params &&
    typeof content.params ===
      "object"
  ) {

    params =
      content.params;
  }


  // ========================================
  // SUPPORT CA SNAKE_CASE VA CAMELCASE
  // ========================================

  const isGroupLayout =
    Number(
      params.is_group_layout ??
      params.isGroupLayout ??
      0
    ) === 1;


  const rawGroupId =
    params.group_layout_id ??
    params.groupLayoutId ??
    null;


  const rawIndex =
    params.id_in_group ??
    params.idInGroup ??
    null;


  const rawTotal =
    params.total_item_in_group ??
    params.totalItemInGroup ??
    null;


  const width =
    Number(
      params.width ??
      content.width
    );


  const height =
    Number(
      params.height ??
      content.height
    );


  const index =
    Number(
      rawIndex
    );


  const total =
    Number(
      rawTotal
    );


  const grouped =
    isGroupLayout &&
    rawGroupId != null &&
    String(
      rawGroupId
    ).trim() !== "" &&
    Number.isFinite(
      total
    ) &&
    total > 1;


  return {

    mediaUrl:
      (
        typeof params.hd ===
          "string" &&
        params.hd.trim()
      )
        ? params.hd.trim()
        : (
            typeof content.href ===
              "string"
              ? content.href.trim()
              : null
          ),


    mediaThumbUrl:
      typeof content.thumb ===
        "string"
        ? content.thumb.trim()
        : null,


    mediaWidth:
      Number.isFinite(
        width
      ) &&
      width > 0
        ? width
        : null,


    mediaHeight:
      Number.isFinite(
        height
      ) &&
      height > 0
        ? height
        : null,


    mediaGroupId:
      grouped
        ? String(
            rawGroupId
          )
        : null,


    mediaGroupIndex:
      grouped &&
      Number.isFinite(
        index
      )
        ? index
        : null,


    mediaGroupTotal:
      grouped
        ? total
        : null,
  };
}

// ========================================
// GENERIC MEDIA METADATA
//
// DUNG CHO:
// - sticker
// - video
// - file
//
// KHONG THAY THE PHOTO.
// PHOTO VAN DUNG:
// extractPhotoMediaMetadata()
// ========================================

function extractConversationMediaMetadata(
  data
) {

  const msgType =
    String(
      data?.msgType ??
      ""
    )
      .trim()
      .toLowerCase();


  const content =
    data?.content &&
    typeof data.content ===
      "object"
      ? data.content
      : {};


  // ========================================
  // PARAMS
  //
  // ZALO CO THE TRA:
  // - JSON STRING
  // - OBJECT
  // ========================================

  let params =
    {};


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

    } catch (_) {

      params =
        {};
    }

  } else if (
    content.params &&
    typeof content.params ===
      "object"
  ) {

    params =
      content.params;
  }


  // ========================================
  // STICKER
  //
  // PAYLOAD THUC TE:
  //
  // content: {
  //   id: 8,
  //   catId: 0,
  //   type: 7
  // }
  //
  // CHUA CO URL.
  // SE ENRICH SAU O WORKER.
  // ========================================

  if (
    msgType ===
    "chat.sticker"
  ) {

    const stickerId =
      content?.id != null
        ? String(
            content.id
          )
        : null;


    const stickerCategoryId =
      content?.catId != null
        ? String(
            content.catId
          )
        : null;


    const stickerType =
      Number(
        content?.type
      );


    // ========================================
    // STICKER DETAIL
    //
    // worker da enrich:
    //
    // content.stickerDetail = [
    //   {
    //     stickerUrl,
    //     stickerSpriteUrl,
    //     stickerWebpUrl,
    //     totalFrames,
    //     duration,
    //     ...
    //   }
    // ]
    // ========================================

    const rawStickerDetail =
      content?.stickerDetail;


    const stickerDetail =
      Array.isArray(
        rawStickerDetail
      )
        ? (
            rawStickerDetail[0] ??
            null
          )
        : (
            rawStickerDetail &&
            typeof rawStickerDetail ===
              "object"
              ? rawStickerDetail
              : null
          );


    const stickerUrl =
      (
        typeof stickerDetail
          ?.stickerWebpUrl ===
          "string" &&
        stickerDetail
          .stickerWebpUrl
          .trim()
      )
        ? stickerDetail
            .stickerWebpUrl
            .trim()
        : (
            typeof stickerDetail
              ?.stickerUrl ===
              "string" &&
            stickerDetail
              .stickerUrl
              .trim()
              ? stickerDetail
                  .stickerUrl
                  .trim()
              : null
          );


    const stickerSpriteUrl =
      typeof stickerDetail
        ?.stickerSpriteUrl ===
        "string" &&
      stickerDetail
        .stickerSpriteUrl
        .trim()
        ? stickerDetail
            .stickerSpriteUrl
            .trim()
        : null;


    const totalFrames =
      Number(
        stickerDetail
          ?.totalFrames
      );


    const duration =
      Number(
        stickerDetail
          ?.duration
      );


    return {

      mediaType:
        "sticker",

      // URL sticker chinh.
      mediaUrl:
        stickerUrl,

      // Khong dung sprite lam thumbnail.
      mediaThumbUrl:
        null,

      mediaWidth:
        null,

      mediaHeight:
        null,

      mediaDuration:
        Number.isFinite(
          duration
        ) &&
        duration >= 0
          ? duration
          : null,

      mediaFileSize:
        null,

      fileName:
        null,

      fileExtension:
        null,


      // ========================================
      // STICKER METADATA
      // ========================================

      stickerId,

      stickerCategoryId,

      stickerType:
        Number.isFinite(
          stickerType
        )
          ? stickerType
          : null,

      stickerSpriteUrl,

      stickerTotalFrames:
        Number.isFinite(
          totalFrames
        ) &&
        totalFrames >= 0
          ? totalFrames
          : null,
    };
  }


  // ========================================
  // VIDEO
  //
  // PAYLOAD THUC TE:
  //
  // content.href
  // content.thumb
  //
  // params:
  // {
  //   duration: 16000,
  //   video_height: 1280,
  //   fileSize: 4592853,
  //   video_width: 720,
  //   video_rotation: 0
  // }
  // ========================================

  if (
    msgType ===
      "chat.video" ||
    msgType ===
      "chat.video.msg" ||
    msgType ===
      "44"
  ) {

    const width =
      Number(
        params.video_width ??
        params.videoWidth ??
        content.width
      );


    const height =
      Number(
        params.video_height ??
        params.videoHeight ??
        content.height
      );


    const duration =
      Number(
        params.duration ??
        content.duration
      );


    const fileSize =
      Number(
        params.fileSize ??
        params.file_size ??
        content.fileSize
      );


    return {

      mediaType:
        "video",

      mediaUrl:
        typeof content.href ===
          "string" &&
        content.href.trim()
          ? content.href.trim()
          : null,

      mediaThumbUrl:
        typeof content.thumb ===
          "string" &&
        content.thumb.trim()
          ? content.thumb.trim()
          : null,

      mediaWidth:
        Number.isFinite(
          width
        ) &&
        width > 0
          ? width
          : null,

      mediaHeight:
        Number.isFinite(
          height
        ) &&
        height > 0
          ? height
          : null,

      mediaDuration:
        Number.isFinite(
          duration
        ) &&
        duration >= 0
          ? duration
          : null,

      mediaFileSize:
        Number.isFinite(
          fileSize
        ) &&
        fileSize >= 0
          ? fileSize
          : null,

      fileName:
        null,

      fileExtension:
        null,

      stickerId:
        null,

      stickerCategoryId:
        null,

      stickerType:
        null,
    };
  }


  // ========================================
  // FILE
  //
  // PAYLOAD THUC TE:
  //
  // content.title
  // content.href
  // content.thumb
  //
  // params:
  // {
  //   fileSize: "243794",
  //   fileExt: "pdf"
  // }
  // ========================================

  if (
    msgType ===
      "share.file" ||
    msgType ===
      "chat.file" ||
    msgType ===
      "chat.file.msg" ||
    msgType ===
      "46"
  ) {

    const fileSize =
      Number(
        params.fileSize ??
        params.file_size ??
        content.fileSize
      );


    const fileName =
      typeof content.title ===
        "string" &&
      content.title.trim()
        ? content.title.trim()
        : null;


    let fileExtension =
      null;


    if (
      typeof params.fileExt ===
        "string" &&
      params.fileExt.trim()
    ) {

      fileExtension =
        params.fileExt
          .trim()
          .toLowerCase();

    } else if (
      fileName &&
      fileName.includes(".")
    ) {

      const pieces =
        fileName.split(".");


      const last =
        pieces[
          pieces.length - 1
        ];


      if (last) {

        fileExtension =
          last
            .trim()
            .toLowerCase();
      }
    }


    return {

      mediaType:
        "file",

      mediaUrl:
        typeof content.href ===
          "string" &&
        content.href.trim()
          ? content.href.trim()
          : null,

      mediaThumbUrl:
        typeof content.thumb ===
          "string" &&
        content.thumb.trim()
          ? content.thumb.trim()
          : null,

      mediaWidth:
        null,

      mediaHeight:
        null,

      mediaDuration:
        null,

      mediaFileSize:
        Number.isFinite(
          fileSize
        ) &&
        fileSize >= 0
          ? fileSize
          : null,

      fileName,

      fileExtension,

      stickerId:
        null,

      stickerCategoryId:
        null,

      stickerType:
        null,
    };
  }


  return null;
}


// ========================================
// SAVE GROUP MESSAGE
// ========================================

export function saveConversationMessage(
  userId,
  {
    message,
    groupName = null,
    senderName = null,
  }
) {
  const groupId =
    String(
      message?.threadId ??
      ""
    );


  if (!groupId) {
    return null;
  }


  const data =
    message?.data ??
    {};

    // ========================================
    // BO QUA EVENT KHONG PHAI MESSAGE HIEN THI
    //
    // QUAN TRONG:
    // KHONG TAO RECORD [Tin nhắn] MA.
    // ========================================

    if (
      !isDisplayableConversationMessage(
        data
      )
    ) {

      console.log(
        "[CONVERSATION] SKIP NON-DISPLAY EVENT:",
        {
          threadId:
            message?.threadId ??
            null,

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

  const msgId =
    data.msgId != null
      ? String(data.msgId)
      : null;


  const cliMsgId =
    data.cliMsgId != null
      ? String(data.cliMsgId)
      : null;


  const timestamp =
    normalizeTimestamp(
      data.ts
    );


  const file =
    groupMessageFile(
      userId,
      groupId
    );


  const messages =
    readJson(
      file,
      []
    );


  // ========================================
  // DEDUPE
  // ========================================

  const existing =
    messages.find(
      item => {

        if (
          msgId &&
          item.msgId === msgId
        ) {
          return true;
        }


        if (
          cliMsgId &&
          item.cliMsgId ===
            cliMsgId
        ) {
          return true;
        }


        return false;
      }
    );


  if (existing) {
    return existing;
  }


  const preview =
    messagePreview(
      data
    );

  const photoMedia =
    extractPhotoMediaMetadata(
      data
    );

  const genericMedia =
    extractConversationMediaMetadata(
      data
    );


  const record = {
    id:
      crypto.randomUUID(),

    groupId,

    msgId,

    cliMsgId,

    uidFrom:
      data.uidFrom != null
        ? String(
            data.uidFrom
          )
        : null,

    senderName:
      senderName ??
      data.dName ??
      data.senderName ??
      null,

    isSelf:
      message?.isSelf ===
      true,

    msgType:
      data.msgType ??
      null,

      // ========================================
      // PHOTO / ALBUM
      // ========================================

      mediaType:
        genericMedia
          ?.mediaType ??
        (
          photoMedia
            ? "photo"
            : null
        ),


      mediaUrl:
        photoMedia
          ?.mediaUrl ??
        genericMedia
          ?.mediaUrl ??
        null,


      mediaThumbUrl:
        photoMedia
          ?.mediaThumbUrl ??
        genericMedia
          ?.mediaThumbUrl ??
        null,


      mediaWidth:
        photoMedia
          ?.mediaWidth ??
        genericMedia
          ?.mediaWidth ??
        null,


      mediaHeight:
        photoMedia
          ?.mediaHeight ??
        genericMedia
          ?.mediaHeight ??
        null,


      mediaDuration:
        genericMedia
          ?.mediaDuration ??
        null,


      mediaFileSize:
        genericMedia
          ?.mediaFileSize ??
        null,


      fileName:
        genericMedia
          ?.fileName ??
        null,


      fileExtension:
        genericMedia
          ?.fileExtension ??
        null,


      stickerId:
        genericMedia
          ?.stickerId ??
        null,


      stickerCategoryId:
        genericMedia
          ?.stickerCategoryId ??
        null,


      stickerType:
        genericMedia
          ?.stickerType ??
        null,

      stickerSpriteUrl:
        genericMedia
          ?.stickerSpriteUrl ??
        null,


      stickerTotalFrames:
        genericMedia
          ?.stickerTotalFrames ??
        null,

      mediaGroupId:
        photoMedia
          ?.mediaGroupId ??
        null,

      mediaGroupIndex:
        photoMedia
          ?.mediaGroupIndex ??
        null,

      mediaGroupTotal:
        photoMedia
          ?.mediaGroupTotal ??
        null,

    content:
      typeof data.content ===
        "string"
        ? data.content
        : null,

    preview,

    status:
      "normal",

    timestamp,

    createdAt:
      new Date(timestamp)
        .toISOString(),

    storedAt:
      new Date()
        .toISOString(),

    // Giu lai data Zalo de sau nay
    // lam reply, attachment...
    rawData:
      safeClone(data),
  };


  messages.push(
    record
  );


  messages.sort(
    (a, b) =>
      Number(a.timestamp) -
      Number(b.timestamp)
  );


  writeJsonAtomic(
    file,
    messages
  );


  // ========================================
  // UPDATE CONVERSATION INDEX
  // ========================================

  const conversationFile =
    indexFile(userId);


  const conversations =
    readJson(
      conversationFile,
      []
    );


  let conversation =
    conversations.find(
      item =>
        String(item.groupId) ===
        groupId
    );


  if (!conversation) {

    const now =
      new Date()
        .toISOString();


    conversation = {

      groupId,


      name:
        groupName ??
        "Nhóm Zalo",


      avatar:
        null,


      totalMember:
        null,

      lastIsSelf:
        null,


      lastMsgType:
        null,


      // ========================================
      // READ STATE
      // ========================================

      unreadCount:
        0,


      lastReadAt:
        now,


      lastReadMessageId:
        null,


      lastReadCliMsgId:
        null,


      lastReadMessageAt:
        null,


      createdAt:
        now,


      updatedAt:
        now,
    };


    conversations.push(
      conversation
    );
  }


  if (groupName) {
    conversation.name =
      groupName;
  }

  // ========================================
  // ENSURE READ STATE
  // ========================================

  conversation.unreadCount =
    normalizeUnreadCount(
      conversation
        .unreadCount
    );


  if (
    !conversation
      .lastReadAt
  ) {

    conversation.lastReadAt =
      new Date()
        .toISOString();
  }

  // ========================================
  // UNREAD
  //
  // CHI DEM:
  // - message moi that su
  // - cua nguoi khac
  // - gui sau thoi diem user doc gan nhat
  //
  // KHONG DEM message do chinh user gui.
  // ========================================

  const lastReadAtMs =
    Date.parse(
      conversation
        .lastReadAt ??
      ""
    );


  const messageIsAfterRead =
    !Number.isFinite(
      lastReadAtMs
    ) ||
    timestamp >
      lastReadAtMs;


  // ========================================
  // PHOTO ALBUM
  //
  // Mot album 4 anh duoc Zalo tra ve
  // thanh 4 chat.photo event.
  //
  // Nhưng ve mat unread,
  // ta chi tinh album do la 1 lan.
  //
  // messages o day CHUA push record moi,
  // nen co the check xem album nay
  // da co photo nao duoc store truoc do chua.
  // ========================================

  const mediaGroupId =
    record
      .mediaGroupId != null
      ? String(
          record.mediaGroupId
        )
      : null;


  const albumAlreadyStored =
    mediaGroupId
      ? messages.some(
          item =>
            item.status ===
              "normal" &&
            item.isSelf !==
              true &&
            item.mediaGroupId !=
              null &&
            String(
              item.mediaGroupId
            ) ===
              mediaGroupId
        )
      : false;


  const shouldIncreaseUnread =
    record.isSelf !==
      true &&
    messageIsAfterRead &&
    !albumAlreadyStored;


  if (
    shouldIncreaseUnread
  ) {

    conversation.unreadCount =
      normalizeUnreadCount(
        conversation
          .unreadCount
      ) + 1;
  }


  const oldLastTime =
    Number(
      conversation
        .lastMessageAt ??
      0
    );


  if (
    timestamp >=
    oldLastTime
  ) {

    conversation.lastMessageId =
      msgId;


    conversation.lastCliMsgId =
      cliMsgId;


    conversation.lastContent =
      preview;


    conversation.lastSenderName =
      record.senderName;


    // ========================================
    // AI GUI TIN CUOI
    // ========================================

    conversation.lastIsSelf =
      record.isSelf ===
      true;


    // ========================================
    // LUU TYPE DE DUNG SAU NAY
    // ========================================

    conversation.lastMsgType =
      record.msgType ??
      null;


    conversation.lastMessageAt =
      timestamp;
  }


  conversation.updatedAt =
    new Date()
      .toISOString();


  sortConversations(
    conversations
  );


  writeJsonAtomic(
    conversationFile,
    conversations
  );


  return record;
}


// ========================================
// MARK RECALLED FROM ZALO UNDO EVENT
// ========================================

export function markConversationMessageRecalledFromUndo(
  userId,
  undo
) {
  const groupId =
    String(
      undo?.threadId ??
      ""
    );


  if (!groupId) {
    return null;
  }


  const data =
    undo?.data ??
    {};


  const content =
    data.content ??
    {};


  // Undo model co the chua ID goc
  // o ca data va data.content.
  const msgIds =
    new Set(
      [
        content.globalMsgId,
        data.realMsgId,
        data.msgId,
      ]
        .filter(
          value =>
            value != null
        )
        .map(
          value =>
            String(value)
        )
    );


  const cliMsgIds =
    new Set(
      [
        content.cliMsgId,
        data.cliMsgId,
      ]
        .filter(
          value =>
            value != null
        )
        .map(
          value =>
            String(value)
        )
    );


  const file =
    groupMessageFile(
      userId,
      groupId
    );


  const messages =
    readJson(
      file,
      []
    );


  const target =
    messages.find(
      item => {

        if (
          item.msgId &&
          msgIds.has(
            String(
              item.msgId
            )
          )
        ) {
          return true;
        }


        if (
          item.cliMsgId &&
          cliMsgIds.has(
            String(
              item.cliMsgId
            )
          )
        ) {
          return true;
        }


        return false;
      }
    );


  if (!target) {

    console.warn(
      "[CONVERSATION] UNDO TARGET NOT FOUND:",
      userId,
      groupId,
      Array.from(msgIds),
      Array.from(cliMsgIds)
    );


    return null;
  }


  target.status =
    "recalled";

  // Không giữ nội dung hiển thị
  // sau khi Zalo đã thu hồi.
  target.content =
    null;

  target.preview =
    "Tin nhắn đã được thu hồi";

  target.rawData =
    null;

  target.recalledAt =
    new Date()
      .toISOString();


  writeJsonAtomic(
    file,
    messages
  );


  // ========================================
  // UPDATE INDEX IF THIS WAS LAST MESSAGE
  // ========================================

  const conversationFile =
    indexFile(userId);


  const conversations =
    readJson(
      conversationFile,
      []
    );


  const conversation =
    conversations.find(
      item =>
        String(item.groupId) ===
        groupId
    );


  if (conversation) {

    const isLast =
      (
        target.msgId &&
        conversation
          .lastMessageId ===
          target.msgId
      ) ||
      (
        target.cliMsgId &&
        conversation
          .lastCliMsgId ===
          target.cliMsgId
      );


    if (isLast) {

      conversation.lastContent =
        "Tin nhắn đã được thu hồi";

      conversation.updatedAt =
        new Date()
          .toISOString();


      writeJsonAtomic(
        conversationFile,
        conversations
      );
    }
  }


  return target;
}


// ========================================
// MARK DELETE LOCAL
// DUNG SAU NAY KHI CHATPAGE CO NUT XOA
// ========================================

export function markConversationMessageDeletedLocal(
  userId,
  groupId,
  {
    msgId = null,
    cliMsgId = null,
  } = {}
) {

  const safeGroupId =
    String(
      groupId ??
      ""
    );


  if (!safeGroupId) {
    return null;
  }


  const safeMsgId =
    msgId != null
      ? String(
          msgId
        )
      : null;


  const safeCliMsgId =
    cliMsgId != null
      ? String(
          cliMsgId
        )
      : null;


  const file =
    groupMessageFile(
      userId,
      safeGroupId
    );


  const messages =
    readJson(
      file,
      []
    );


  const target =
    messages.find(
      item => {

        if (
          safeMsgId &&
          item.msgId ===
            safeMsgId
        ) {
          return true;
        }


        if (
          safeCliMsgId &&
          item.cliMsgId ===
            safeCliMsgId
        ) {
          return true;
        }


        return false;
      }
    );


  if (!target) {
    return null;
  }


  // ========================================
  // DA XOA ROI
  // ========================================

  if (
    target.status ===
    "deleted_local"
  ) {

    return target;
  }


  // ========================================
  // XOA LOCAL
  //
  // KHONG XOA RECORD VAT LY.
  //
  // GIU TOMBSTONE DE:
  // - pagination khong bi vo
  // - target lich su biet message da xoa
  // - tranh message realtime song lai
  // ========================================

  target.status =
    "deleted_local";


  target.content =
    null;


  target.preview =
    "Tin nhắn đã bị xóa";


  target.rawData =
    null;


  target.deletedAt =
    new Date()
      .toISOString();


  writeJsonAtomic(
    file,
    messages
  );


  // ========================================
  // UPDATE CONVERSATION INDEX
  // NEU MESSAGE NAY LA MESSAGE CUOI
  // ========================================

  const conversationFile =
    indexFile(
      userId
    );


  const conversations =
    readJson(
      conversationFile,
      []
    );


  const conversation =
    conversations.find(
      item =>
        String(
          item.groupId
        ) ===
        safeGroupId
    );


  if (conversation) {

    const isLast =
      (
        target.msgId &&
        String(
          conversation
            .lastMessageId ??
          ""
        ) ===
        String(
          target.msgId
        )
      ) ||
      (
        target.cliMsgId &&
        String(
          conversation
            .lastCliMsgId ??
          ""
        ) ===
        String(
          target.cliMsgId
        )
      );


    if (isLast) {

      conversation.lastContent =
        "Tin nhắn đã bị xóa";


      conversation.updatedAt =
        new Date()
          .toISOString();


      writeJsonAtomic(
        conversationFile,
        conversations
      );
    }
  }


  return target;
}

// ========================================
// MARK CONVERSATION AS READ
// ========================================

export function markUserConversationRead(
  userId,
  groupId
) {

  const safeGroupId =
    String(
      groupId ??
      ""
    ).trim();


  if (!safeGroupId) {

    return null;
  }


  const file =
    indexFile(
      userId
    );


  const conversations =
    readJson(
      file,
      []
    );


  const conversation =
    conversations.find(
      item =>
        String(
          item.groupId
        ) ===
        safeGroupId
    );


  if (!conversation) {

    return null;
  }


  const now =
    new Date()
      .toISOString();


  // ========================================
  // RESET UNREAD
  // ========================================

  conversation.unreadCount =
    0;


  conversation.lastReadAt =
    now;


  // ========================================
  // LUU READ CURSOR
  //
  // Sau nay neu can tinh lai unread,
  // ta van biet user da doc toi message nao.
  // ========================================

  conversation.lastReadMessageId =
    conversation
      .lastMessageId ??
    null;


  conversation.lastReadCliMsgId =
    conversation
      .lastCliMsgId ??
    null;


  conversation.lastReadMessageAt =
    conversation
      .lastMessageAt ??
    null;


  conversation.updatedAt =
    now;


  writeJsonAtomic(
    file,
    conversations
  );


  return {
    ...conversation,
  };
}


export function getUserConversationList(
  userId
) {

  const file =
    indexFile(
      userId
    );


  const conversations =
    readJson(
      file,
      []
    );


  let changed =
    false;


  const now =
    new Date()
      .toISOString();


  for (
    const conversation
    of conversations
  ) {

    // ========================================
    // unreadCount
    // ========================================

    const normalizedUnread =
      normalizeUnreadCount(
        conversation
          .unreadCount
      );


    if (
      conversation
        .unreadCount !==
      normalizedUnread
    ) {

      conversation.unreadCount =
        normalizedUnread;


      changed =
        true;
    }


    // ========================================
    // MIGRATION CHO DATA CU
    // ========================================

    if (
      !Object.prototype
        .hasOwnProperty
        .call(
          conversation,
          "lastReadAt"
        )
    ) {

      conversation.lastReadAt =
        now;


      conversation.lastReadMessageId =
        conversation
          .lastMessageId ??
        null;


      conversation.lastReadCliMsgId =
        conversation
          .lastCliMsgId ??
        null;


      conversation.lastReadMessageAt =
        conversation
          .lastMessageAt ??
        null;


      changed =
        true;
    }
  }


  if (
    changed
  ) {

    writeJsonAtomic(
      file,
      conversations
    );
  }


  return sortConversations(
    conversations
  );
}


// ========================================
// READ MESSAGES
// ========================================

export function getUserConversationMessages(
  userId,
  groupId,
  {
    limit = 100,
  } = {}
) {
  const messages =
    readJson(
      groupMessageFile(
        userId,
        groupId
      ),
      []
    );


  const safeLimit =
    Math.max(
      1,
      Math.min(
        Number(limit) || 100,
        500
      )
    );


  return messages
    .slice(
      -safeLimit
    )
    .sort(
      (a, b) =>
        Number(a.timestamp) -
        Number(b.timestamp)
    );
}

// ========================================
// READ MESSAGES WITH CURSOR PAGINATION
// ========================================

export function getUserConversationMessagesPage(
  userId,
  groupId,
  {
    limit = 50,
    beforeId = null,
    afterId = null,
  } = {}
) {

  const messages =
    readJson(
      groupMessageFile(
        userId,
        groupId
      ),
      []
    )
      .slice()
      .sort(
        (a, b) =>
          Number(a.timestamp) -
          Number(b.timestamp)
      );


  const safeLimit =
    Math.max(
      1,
      Math.min(
        Number(limit) || 50,
        100
      )
    );


  // ========================================
  // KHONG CHO DUNG CA 2 CURSOR
  // ========================================

  if (
    beforeId &&
    afterId
  ) {

    const error =
      new Error(
        "Chi duoc dung beforeId hoac afterId."
      );

    error.code =
      "INVALID_CURSOR";

    throw error;
  }


  // ========================================
  // LOAD CAC TIN CU HON
  //
  // beforeId = ID CUA TIN DAU TIEN
  // DANG CO TREN FLUTTER
  // ========================================

  if (beforeId) {

    const anchorIndex =
      messages.findIndex(
        item =>
          String(item.id) ===
          String(beforeId)
      );


    if (
      anchorIndex === -1
    ) {

      return {
        messages: [],
        hasBefore: false,
        hasAfter: false,
        anchorFound: false,
      };
    }


    const start =
      Math.max(
        0,
        anchorIndex -
          safeLimit
      );


    const page =
      messages.slice(
        start,
        anchorIndex
      );


    return {
      messages:
        page,

      hasBefore:
        start > 0,

      hasAfter:
        anchorIndex <
        messages.length - 1,

      anchorFound:
        true,
    };
  }


  // ========================================
  // LOAD CAC TIN MOI HON
  //
  // afterId = ID CUA TIN CUOI CUNG
  // DANG CO TREN FLUTTER
  // ========================================

  if (afterId) {

    const anchorIndex =
      messages.findIndex(
        item =>
          String(item.id) ===
          String(afterId)
      );


    if (
      anchorIndex === -1
    ) {

      return {
        messages: [],
        hasBefore: false,
        hasAfter: false,
        anchorFound: false,
      };
    }


    const start =
      anchorIndex + 1;


    const end =
      Math.min(
        messages.length,
        start +
          safeLimit
      );


    const page =
      messages.slice(
        start,
        end
      );


    return {
      messages:
        page,

      hasBefore:
        start > 0,

      hasAfter:
        end <
        messages.length,

      anchorFound:
        true,
    };
  }


  // ========================================
  // KHONG CO CURSOR
  //
  // LAN DAU MO CHAT:
  // LAY CAC TIN MOI NHAT
  // ========================================

  const start =
    Math.max(
      0,
      messages.length -
        safeLimit
    );


  const page =
    messages.slice(
      start
    );


  return {
    messages:
      page,

    hasBefore:
      start > 0,

    hasAfter:
      false,

    anchorFound:
      true,
  };
}

// ========================================
// FIND EXACT SOURCE MESSAGE
// DUNG CHO LICH SU NHAN SAU NAY
// ========================================

export function findUserConversationMessage(
  userId,
  groupId,
  {
    msgId = null,
    cliMsgId = null,
  } = {}
) {
  const messages =
    readJson(
      groupMessageFile(
        userId,
        groupId
      ),
      []
    );


  return (
    messages.find(
      item => {

        if (
          msgId &&
          item.msgId ===
            String(msgId)
        ) {
          return true;
        }


        if (
          cliMsgId &&
          item.cliMsgId ===
            String(cliMsgId)
        ) {
          return true;
        }


        return false;
      }
    ) ??
    null
  );
}

// ========================================
// GET MESSAGE CONTEXT
// DUNG CHO LICH SU NHAN
// ========================================

export function getUserConversationMessageContext(
  userId,
  groupId,
  {
    msgId = null,
    cliMsgId = null,
    before = 60,
    after = 60,
  } = {}
) {

  const messages =
    readJson(
      groupMessageFile(
        userId,
        groupId
      ),
      []
    );


  const targetIndex =
    messages.findIndex(
      item => {

        if (
          msgId &&
          item.msgId ===
            String(msgId)
        ) {
          return true;
        }


        if (
          cliMsgId &&
          item.cliMsgId ===
            String(cliMsgId)
        ) {
          return true;
        }


        return false;
      }
    );


  // ========================================
  // KHONG TIM THAY
  // ========================================

  if (
    targetIndex === -1
  ) {

    return {
      found: false,
      reason: "not_found",
      target: null,
      messages: [],
      targetIndex: -1,
    };
  }


  const target =
    messages[targetIndex];


  // ========================================
  // TIN DA THU HOI
  // ========================================

  if (
    target.status ===
    "recalled"
  ) {

    return {
      found: false,
      reason: "recalled",
      target: null,
      messages: [],
      targetIndex: -1,
    };
  }


  // ========================================
  // TIN DA XOA
  // ========================================

  if (
    target.status ===
    "deleted_local"
  ) {

    return {
      found: false,
      reason: "deleted_local",
      target: null,
      messages: [],
      targetIndex: -1,
    };
  }


  const safeBefore =
    Math.max(
      0,
      Math.min(
        Number(before) || 60,
        200
      )
    );


  const safeAfter =
    Math.max(
      0,
      Math.min(
        Number(after) || 60,
        200
      )
    );


  const start =
    Math.max(
      0,
      targetIndex -
        safeBefore
    );


  const end =
    Math.min(
      messages.length,
      targetIndex +
        safeAfter +
        1
    );


  const contextMessages =
    messages.slice(
      start,
      end
    );


  return {
    found: true,
    reason: null,

    target,

    messages:
      contextMessages,

    // Index moi trong mang contextMessages.
    targetIndex:
      targetIndex -
      start,

    hasBefore:
      start > 0,

    hasAfter:
      end <
      messages.length,
  };
}
