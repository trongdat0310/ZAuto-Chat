import {
  getUserFilterDocument,
  getLegacyUserFilterSettings,
  saveLegacyUserFilterSettings,
  sanitizeUserFilter,
  upsertUserFilter,
  deleteUserFilter,
} from "./user-filter-store.js";

import {
  compileUserFilterDocument,
  getCompiledGroupPlan,
  getUserFilterGroupPlan,
  warmUserFilterRuntime,
} from "./user-filter-runtime.js";

import {
  evaluateCompiledGroupPlan,
} from "./user-filter-evaluator.js";


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


  return evaluateCompiledGroupPlan(
    plan,
    messageText
  );
}
