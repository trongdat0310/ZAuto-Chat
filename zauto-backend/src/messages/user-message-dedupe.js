// ========================================
// DEDUPE CACHE
//
// userId
//   -> key(senderId + text)
//      -> timestamp
// ========================================

const recentMessagesByUser =
  new Map();


// ========================================
// NORMALIZE TEXT
// ========================================

function normalizeContent(
  content
) {

  return String(
    content ?? ""
  )

    // Chuan Unicode.
    .normalize("NFKC")

    // Chu thuong.
    .toLowerCase()

    // Xoa khoang trang thua.
    .replace(
      /\s+/g,
      " "
    )

    .trim();
}


// ========================================
// BUILD DEDUPE KEY
//
// senderId + normalized text
// ========================================

function buildDedupeKey(
  senderId,
  content
) {

  const normalized =
    normalizeContent(
      content
    );


  const sender =
    String(
      senderId ?? ""
    ).trim();


  if (
    !sender ||
    !normalized
  ) {
    return null;
  }


  return (
    sender +
    "::" +
    normalized
  );
}


// ========================================
// CHECK DUPLICATE
//
// true  = bo qua
// false = hien cuoc
// ========================================

export function shouldSkipDuplicateUserMessage(
  userId,
  {
    senderId,
    content,
    windowSeconds = 5,
  }
) {

  const key =
    buildDedupeKey(
      senderId,
      content
    );


  // Khong co senderId hoac text
  // -> KHONG dedupe.
  if (!key) {
    return false;
  }


  const userKey =
    String(
      userId
    );


  const now =
    Date.now();


  const windowMs =
    Math.max(
      1000,

      Number(
        windowSeconds
      ) *
      1000
    );


  let recent =
    recentMessagesByUser.get(
      userKey
    );


  if (!recent) {

    recent =
      new Map();


    recentMessagesByUser.set(
      userKey,
      recent
    );
  }


  // ========================================
  // DON CACHE CU
  // ========================================

  for (
    const [
      oldKey,
      oldTimestamp,
    ]
    of recent.entries()
  ) {

    if (
      now -
      oldTimestamp >
      windowMs
    ) {

      recent.delete(
        oldKey
      );
    }
  }


  // ========================================
  // CHECK
  // ========================================

  const previousTimestamp =
    recent.get(
      key
    );


  if (
    previousTimestamp != null &&
    now -
      previousTimestamp <=
      windowMs
  ) {
    return true;
  }


  // ========================================
  // LAN DAU
  // ========================================

  recent.set(
    key,
    now
  );


  return false;
}