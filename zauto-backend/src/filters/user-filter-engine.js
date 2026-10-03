import {
  getUserFilterDocument,
  getLegacyUserFilterSettings,
  saveLegacyUserFilterSettings,
} from "./user-filter-store.js";

import {
  normalizeFilterText,
  findFirstKeywordMatch,
} from "./user-filter-matcher.js";

import {
  getUserFilterRuntime,
  warmUserFilterRuntime,
} from "./user-filter-runtime.js";


// ========================================
// LEGACY RUNTIME VIEW
//
// Runtime chung da compile san tat ca
// Basic / Advanced.
//
// Hien tai evaluator production van chi
// dung legacy filter de khong thay doi
// behavior cho toi khi V2 evaluator xong.
// ========================================

function getLegacyRuntime(
  userId
) {
  const runtime =
    getUserFilterRuntime(
      userId
    );


  const legacy =
    runtime.legacyFilter;


  if (!legacy) {
    return {
      enabled:
        true,

      includeMatchers:
        [],

      excludeMatchers:
        [],
    };
  }


  return {
    enabled:
      legacy.enabled !==
      false,

    includeMatchers:
      legacy
        .advanced
        ?.showMatchers ??
      [],

    excludeMatchers:
      legacy
        .advanced
        ?.hideMatchers ??
      [],
  };
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


// ========================================
// LEGACY SAVE
//
// Sau khi save:
// - store tao document object moi
// - warm runtime se compile ngay
//
// => message realtime tiep theo khong
// bi ganh chi phi compile.
// ========================================

export function saveUserFilterSettings(
  userId,
  updates
) {
  const result =
    saveLegacyUserFilterSettings(
      userId,
      updates
    );


  warmUserFilterRuntime(
    userId
  );


  return result;
}


// ========================================
// EVALUATE
//
// HIEN TAI VAN GIU BEHAVIOR FILTER CU.
//
// groupId da duoc truyen vao san
// de buoc tiep theo bat V2 evaluator.
// ========================================

export function evaluateUserMessage(
  userId,
  messageText,
  {
    groupId = null,
  } = {}
) {
  // Tam thoi chua dung groupId.
  // Buoc V2 evaluator se dung no de lay
  // indexed group plan.
  void groupId;


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
    normalizeFilterText(
      messageText
    );


  // ========================================
  // EXCLUDE
  // ========================================

  const matchedExclude =
    findFirstKeywordMatch(
      runtime
        .excludeMatchers,
      text
    );


  if (matchedExclude) {
    return {
      matched:
        false,

      reason:
        "excluded_keyword",

      keyword:
        matchedExclude.source,
    };
  }


  // ========================================
  // NO INCLUDE
  // ========================================

  if (
    runtime
      .includeMatchers
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
    findFirstKeywordMatch(
      runtime
        .includeMatchers,
      text
    );


  if (matchedInclude) {
    return {
      matched:
        true,

      reason:
        "included_keyword",

      keyword:
        matchedInclude.source,
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
// DOCUMENT ACCESS
//
// Giu lai cho cac buoc migrate / debug.
// ========================================

export function getUserFilterDocumentForRuntime(
  userId
) {
  return getUserFilterDocument(
    userId
  );
}