import {
  LEGACY_FILTER_ID,
  getUserFilterDocument,
  getLegacyUserFilterSettings,
  saveLegacyUserFilterSettings,
} from "./user-filter-store.js";


// ========================================
// RUNTIME CACHE
//
// userId -> {
//   document,
//   enabled,
//   includeKeywords,
//   excludeKeywords
// }
//
// document reference doi moi lan save.
// Vi vay khong can timestamp check.
// ========================================

const runtimeCache =
  new Map();


// ========================================
// NORMALIZE
// ========================================

function normalizeText(
  value = ""
) {
  return String(value)
    .normalize("NFD")
    .replace(
      /[\u0300-\u036f]/g,
      ""
    )
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase()
    .replace(
      /\s+/g,
      " "
    )
    .trim();
}


// ========================================
// LEGACY RUNTIME
//
// Buoc nay van giu dung logic cu.
//
// Sau buoc tiep theo function nay se
// duoc thay boi compiled Basic/Advanced plan.
// ========================================

function getLegacyRuntime(
  userId
) {
  const key =
    String(userId);


  const document =
    getUserFilterDocument(
      key
    );


  const cached =
    runtimeCache.get(
      key
    );


  if (
    cached &&
    cached.document ===
      document
  ) {
    return cached;
  }


  const legacy =
    document.filters.find(
      item =>
        item.id ===
        LEGACY_FILTER_ID
    );


  const runtime = {
    document,

    enabled:
      legacy
        ? legacy.enabled !==
          false
        : true,

    includeKeywords:
      legacy
        ? legacy
            .advanced
            .showKeywords
            .map(
              normalizeText
            )
            .filter(Boolean)
        : [],

    excludeKeywords:
      legacy
        ? legacy
            .advanced
            .hideKeywords
            .map(
              normalizeText
            )
            .filter(Boolean)
        : [],
  };


  runtimeCache.set(
    key,
    runtime
  );


  return runtime;
}


// ========================================
// OLD API COMPATIBILITY
// ========================================

export function getUserFilterSettings(
  userId
) {
  return getLegacyUserFilterSettings(
    userId
  );
}


export function saveUserFilterSettings(
  userId,
  updates
) {
  const result =
    saveLegacyUserFilterSettings(
      userId,
      updates
    );


  runtimeCache.delete(
    String(userId)
  );


  return result;
}


// ========================================
// EVALUATE
//
// HIEN TAI:
// giu behavior cu de khong pha production.
//
// KHAC BIET:
// - khong doc JSON moi message
// - keyword da normalize san trong RAM
// ========================================

export function evaluateUserMessage(
  userId,
  messageText
) {
  const runtime =
    getLegacyRuntime(
      userId
    );


  if (!runtime.enabled) {
    return {
      matched:
        true,

      reason:
        "filter_disabled",
    };
  }


  const text =
    normalizeText(
      messageText
    );


  // ========================================
  // EXCLUDE
  // ========================================

  const matchedExclude =
    runtime
      .excludeKeywords
      .find(
        keyword =>
          text.includes(
            keyword
          )
      );


  if (matchedExclude) {
    return {
      matched:
        false,

      reason:
        "excluded_keyword",

      keyword:
        matchedExclude,
    };
  }


  // ========================================
  // NO INCLUDE
  // ========================================

  if (
    runtime
      .includeKeywords
      .length ===
    0
  ) {
    return {
      matched:
        true,

      reason:
        "no_include_keywords",
    };
  }


  // ========================================
  // INCLUDE = OR
  // ========================================

  const matchedInclude =
    runtime
      .includeKeywords
      .find(
        keyword =>
          text.includes(
            keyword
          )
      );


  if (matchedInclude) {
    return {
      matched:
        true,

      reason:
        "included_keyword",

      keyword:
        matchedInclude,
    };
  }


  return {
    matched:
      false,

    reason:
      "no_include_match",
  };
}


// ========================================
// FUTURE V2 ENGINE HOOK
//
// Buoc tiep theo se dung document nay
// de compile:
// - Basic
// - Advanced
// - group index
// - price/time lazy parser
// ========================================

export function getUserFilterDocumentForRuntime(
  userId
) {
  return getUserFilterDocument(
    userId
  );
}