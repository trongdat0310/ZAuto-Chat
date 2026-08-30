import fs from "node:fs";
import path from "node:path";
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


function getFilterPath(userId) {
  return path.join(
    getUserDir(userId),
    "filter-settings.json"
  );
}


// ========================================
// DEFAULT
// ========================================

function defaultSettings() {
  return {
    enabled: true,

    includeKeywords: [],

    excludeKeywords: [],
  };
}


// ========================================
// NORMALIZE
// ========================================

function normalizeText(value = "") {
  return String(value)
    .normalize("NFD")
    .replace(
      /[\u0300-\u036f]/g,
      ""
    )
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase()
    .trim();
}


// ========================================
// SANITIZE KEYWORDS
// ========================================

function sanitizeKeywords(
  values
) {
  if (!Array.isArray(values)) {
    return [];
  }


  const cleaned =
    values
      .map(
        value =>
          String(value)
            .trim()
      )
      .filter(Boolean);


  return [
    ...new Set(cleaned),
  ];
}


// ========================================
// READ
// ========================================

export function getUserFilterSettings(
  userId
) {
  const filePath =
    getFilterPath(userId);


  if (!fs.existsSync(filePath)) {
    return defaultSettings();
  }


  try {
    const saved =
      JSON.parse(
        fs.readFileSync(
          filePath,
          "utf-8"
        )
      );


    return {
      ...defaultSettings(),
      ...saved,

      includeKeywords:
        sanitizeKeywords(
          saved?.includeKeywords
        ),

      excludeKeywords:
        sanitizeKeywords(
          saved?.excludeKeywords
        ),

      enabled:
        saved?.enabled !== false,
    };

  } catch (error) {

    console.error(
      "[USER FILTER] READ ERROR:",
      userId,
      error
    );


    return defaultSettings();
  }
}


// ========================================
// SAVE
// ========================================

export function saveUserFilterSettings(
  userId,
  updates
) {
  const current =
    getUserFilterSettings(
      userId
    );


  const next = {
    ...current,

    ...(updates.enabled !== undefined
      ? {
          enabled:
            updates.enabled === true,
        }
      : {}),

    ...(updates.includeKeywords !==
    undefined
      ? {
          includeKeywords:
            sanitizeKeywords(
              updates.includeKeywords
            ),
        }
      : {}),

    ...(updates.excludeKeywords !==
    undefined
      ? {
          excludeKeywords:
            sanitizeKeywords(
              updates.excludeKeywords
            ),
        }
      : {}),

    updatedAt:
      new Date().toISOString(),
  };


  const userDir =
    getUserDir(userId);


  fs.mkdirSync(
    userDir,
    {
      recursive: true,
    }
  );


  fs.writeFileSync(
    getFilterPath(userId),

    JSON.stringify(
      next,
      null,
      2
    ),

    "utf-8"
  );


  console.log(
    "[USER FILTER] SAVED:",
    userId
  );


  return next;
}


// ========================================
// EVALUATE
// Dung cho worker per-user o buoc sau
// ========================================

export function evaluateUserMessage(
  userId,
  messageText
) {
  const settings =
    getUserFilterSettings(
      userId
    );


  if (!settings.enabled) {
    return {
      matched: true,

      reason:
        "filter_disabled",
    };
  }


  const text =
    normalizeText(
      messageText
    );


  const includeKeywords =
    settings.includeKeywords
      .map(normalizeText)
      .filter(Boolean);


  const excludeKeywords =
    settings.excludeKeywords
      .map(normalizeText)
      .filter(Boolean);


  // ========================================
  // EXCLUDE UU TIEN CAO NHAT
  // ========================================

  const matchedExclude =
    excludeKeywords.find(
      keyword =>
        text.includes(
          keyword
        )
    );


  if (matchedExclude) {
    return {
      matched: false,

      reason:
        "excluded_keyword",

      keyword:
        matchedExclude,
    };
  }


  // ========================================
  // KHONG CO INCLUDE
  // ========================================

  if (
    includeKeywords.length === 0
  ) {
    return {
      matched: true,

      reason:
        "no_include_keywords",
    };
  }


  // ========================================
  // INCLUDE = OR
  // ========================================

  const matchedInclude =
    includeKeywords.find(
      keyword =>
        text.includes(
          keyword
        )
    );


  if (matchedInclude) {
    return {
      matched: true,

      reason:
        "included_keyword",

      keyword:
        matchedInclude,
    };
  }


  return {
    matched: false,

    reason:
      "no_include_match",
  };
}