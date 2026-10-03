import {
  getUserFilterDocument,
  getLegacyUserFilterSettings,
  saveLegacyUserFilterSettings,
} from "./user-filter-store.js";

import {
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