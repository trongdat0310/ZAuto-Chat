import {
  getUserFilterDocument,
  getLegacyUserFilterSettings,
  saveLegacyUserFilterSettings,
  sanitizeUserFilter,
  upsertUserFilter,
  deleteUserFilter,
  reorderUserFilters,
} from "./user-filter-store.js";

import {
  compileUserFilterDocument,
  getCompiledGroupPlan,
  getUserFilterGroupPlan,
  warmUserFilterRuntime,
} from "./user-filter-runtime.js";

import {
  createFilterMessageContext,
  evaluateAdvancedFilterDiagnostics,
  evaluateBasicFilterDiagnostics,
  evaluateCompiledFilter,
  evaluateCompiledGroupPlan,
} from "./user-filter-evaluator.js";

import {
  compileKeywordPattern,
} from "./user-filter-matcher.js";


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
// Store tao document object moi.
//
// Warm runtime ngay trong request save
// de message realtime sau do khong phai
// compile filter.
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
// EVALUATE USER MESSAGE
//
// HOT PATH:
//
// 1. get cached group plan
// 2. normalize message mot lan
// 3. short-circuit filter OR
//
// KHONG:
// - disk I/O
// - JSON.parse
// - compile keyword
// - quet filter group khac
// ========================================

export function evaluateUserMessage(
  userId,
  messageText,
  {
    groupId = null,
  } = {}
) {
  const plan =
    getUserFilterGroupPlan(
      userId,
      groupId
    );


  return evaluateCompiledGroupPlan(
    plan,
    messageText
  );
}


// ========================================
// DOCUMENT ACCESS
// ========================================

export function getUserFilterDocumentForRuntime(
  userId
) {
  return getUserFilterDocument(
    userId
  );
}

// ========================================
// V2 INPUT VALIDATION
//
// Khong de sanitizer am tham bien input sai
// thanh mot filter co y nghia khac.
// ========================================

function assertValidKeywordPattern(
  value,
  fieldName
) {
  const source =
    String(
      value ?? ""
    ).trim();


  if (!source) {
    return;
  }


  if (
    compileKeywordPattern(
      source
    )
  ) {
    return;
  }


  throw new Error(
    `${fieldName}: tu khoa khong hop le "${source}". ` +
    "Dau * phai nam o ca hai dau."
  );
}


function assertValidCommaSeparatedKeywords(
  value,
  fieldName
) {
  const parts =
    String(
      value ?? ""
    )
      .split(",")
      .map(
        item => item.trim()
      )
      .filter(Boolean);


  for (
    const part of parts
  ) {
    assertValidKeywordPattern(
      part,
      fieldName
    );
  }
}


function assertValidKeywordList(
  values,
  fieldName
) {
  if (
    values ===
    null ||
    values ===
    undefined
  ) {
    return;
  }


  if (!Array.isArray(values)) {
    throw new Error(
      `${fieldName}: danh sach tu khoa khong hop le.`
    );
  }


  for (
    const value of values
  ) {
    assertValidKeywordPattern(
      value,
      fieldName
    );
  }
}


function validateUserFilterV2Input(
  input
) {
  const source =
    input &&
    typeof input === "object"
      ? input
      : {};


  if (
    !String(
      source.name ?? ""
    ).trim()
  ) {
    throw new Error(
      "Ten bo loc khong duoc de trong."
    );
  }


  const mode =
    source.mode === "advanced"
      ? "advanced"
      : "basic";


  if (
    source.groupIds !==
      undefined &&
    !Array.isArray(
      source.groupIds
    )
  ) {
    throw new Error(
      "Danh sach nhom ap dung khong hop le."
    );
  }


  if (
    mode === "basic"
  ) {
    const basic =
      source.basic &&
      typeof source.basic === "object"
        ? source.basic
        : {};


    assertValidCommaSeparatedKeywords(
      basic.pickup,
      "Diem don"
    );

    assertValidCommaSeparatedKeywords(
      basic.dropoff,
      "Diem tra"
    );

    assertValidCommaSeparatedKeywords(
      basic.includeKeywords,
      "Tu khoa nhan"
    );

    assertValidCommaSeparatedKeywords(
      basic.excludeKeywords,
      "Tu khoa bo qua"
    );

    assertValidCommaSeparatedKeywords(
      basic.timeRules,
      "Khung gio"
    );


    const rawPrice =
      basic.minimumPrice;


    if (
      rawPrice !== null &&
      rawPrice !== undefined &&
      rawPrice !== ""
    ) {
      const parsed =
        Number(
          rawPrice
        );


      if (
        !Number.isFinite(
          parsed
        ) ||
        parsed < 0
      ) {
        throw new Error(
          "Gia toi thieu phai la so lon hon hoac bang 0."
        );
      }
    }

  } else {

    const advanced =
      source.advanced &&
      typeof source.advanced === "object"
        ? source.advanced
        : {};


    assertValidKeywordList(
      advanced.showKeywords,
      "Tu khoa hien thi"
    );

    assertValidKeywordList(
      advanced.hideKeywords,
      "Tu khoa an"
    );
  }


  return source;
}


// ========================================
// V2 DOCUMENT API
// ========================================

export function getUserFilterDocumentV2(
  userId
) {
  return getUserFilterDocument(
    userId
  );
}


export function saveUserFilterV2(
  userId,
  input
) {
  validateUserFilterV2Input(
    input
  );


  const filter =
    upsertUserFilter(
      userId,
      input
    );


  warmUserFilterRuntime(
    userId
  );


  return filter;
}


export function reorderUserFiltersV2(
  userId,
  orderedIds
) {
  const document =
    reorderUserFilters(
      userId,
      orderedIds
    );


  warmUserFilterRuntime(
    userId
  );


  return document;
}


export function deleteUserFilterV2(
  userId,
  filterId
) {
  const deleted =
    deleteUserFilter(
      userId,
      filterId
    );


  if (deleted) {
    warmUserFilterRuntime(
      userId
    );
  }


  return deleted;
}


// ========================================
// PREVIEW ONE UNSAVED FILTER
//
// Khong ghi disk.
// Khong dung cache.
// Dung cung compiler/evaluator voi realtime.
// ========================================

export function previewUserFilterV2(
  input,
  messageText,
  {
    groupId = null,
  } = {}
) {
  validateUserFilterV2Input(
    input
  );


  const filter =
    sanitizeUserFilter({
      ...input,

      // Preview kiem tra chinh logic filter dang soan.
      // Group scope khong duoc lam preview thanh
      // "no_applicable_filters".
      groupIds:
        [],

      enabled:
        true,
  });


  const runtime =
    compileUserFilterDocument({
      version:
        2,

      filters: [
        filter,
      ],
    });


  const plan =
    getCompiledGroupPlan(
      runtime,
      groupId
    );


  const summary =
    evaluateCompiledGroupPlan(
      plan,
      messageText
    );


  const compiledFilter =
    runtime.compiledFilters[0];


  const checks =
    compiledFilter?.mode ===
      "basic"
      ? evaluateBasicFilterDiagnostics(
          compiledFilter,
          messageText
        )
      : compiledFilter?.mode ===
            "advanced"
        ? evaluateAdvancedFilterDiagnostics(
            compiledFilter,
            messageText
          )
        : null;


  if (summary.matched === true) {
    return {
      ...summary,

      checks,
    };
  }


  


  if (!compiledFilter) {
    return summary;
  }


  const detailed =
    evaluateCompiledFilter(
      compiledFilter,
      createFilterMessageContext(
        messageText
      )
    );


  return {
    ...summary,

    reason:
      detailed.reason,

    filterId:
      detailed.filterId,

    filterName:
      detailed.filterName,

    mode:
      detailed.mode,

    keyword:
      detailed.keyword,

    details:
      detailed.details ??
      null,

    checks,
  };
}
