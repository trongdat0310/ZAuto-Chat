import {
  normalizeFilterText,
  findFirstKeywordMatch,
} from "./user-filter-matcher.js";


// ========================================
// MESSAGE CONTEXT
//
// Moi message chi normalize MOT LAN.
//
// Basic evaluator sau nay se mo rong object
// nay bang lazy price/time parsing.
// ========================================

export function createFilterMessageContext(
  messageText
) {
  const rawText =
    String(
      messageText ?? ""
    );


  return {
    rawText,

    text:
      normalizeFilterText(
        rawText
      ),

    // ========================================
    // RESERVED FOR BASIC
    //
    // Buoc sau se parse lazy:
    // undefined = chua parse
    // null      = parse roi, khong tim thay
    // value     = ket qua
    // ========================================

    price:
      undefined,

    mentionedTimeRanges:
      undefined,

    mentionedMinuteValues:
      undefined,
  };
}


// ========================================
// FILTER RESULT HELPERS
// ========================================

function accepted(
  filter,
  reason,
  {
    keyword = null,
  } = {}
) {
  return {
    state:
      "accept",

    matched:
      true,

    reason,

    filterId:
      filter.id,

    filterName:
      filter.name,

    mode:
      filter.mode,

    keyword,
  };
}


function rejected(
  filter,
  reason,
  {
    keyword = null,
  } = {}
) {
  return {
    state:
      "reject",

    matched:
      false,

    reason,

    filterId:
      filter.id,

    filterName:
      filter.name,

    mode:
      filter.mode,

    keyword,
  };
}


// ========================================
// ADVANCED FILTER
//
// Hide chi co quyen veto TRONG FILTER NAY.
//
// Nhieu filter ket hop OR nen filter khac
// van co the ACCEPT message.
// ========================================

export function evaluateAdvancedFilter(
  filter,
  context
) {
  const advanced =
    filter.advanced;


  if (!advanced) {
    return rejected(
      filter,
      "advanced_runtime_missing"
    );
  }


  // ========================================
  // 1. HIDE FIRST
  //
  // Hide > Show trong cung filter.
  // ========================================

  const hideMatch =
    findFirstKeywordMatch(
      advanced.hideMatchers,
      context.text
    );


  if (hideMatch) {
    return rejected(
      filter,
      "advanced_hidden_keyword",
      {
        keyword:
          hideMatch.source,
      }
    );
  }


  // ========================================
  // 2. SHOW EMPTY = ACCEPT ALL
  //
  // Dung theo UI:
  // "Neu tu khoa trong = hien thi tat ca"
  // ========================================

  if (
    advanced
      .showMatchers
      .length ===
    0
  ) {
    return accepted(
      filter,
      "advanced_no_show_keywords"
    );
  }


  // ========================================
  // 3. SHOW = OR
  // ========================================

  const showMatch =
    findFirstKeywordMatch(
      advanced.showMatchers,
      context.text
    );


  if (showMatch) {
    return accepted(
      filter,
      "advanced_show_keyword",
      {
        keyword:
          showMatch.source,
      }
    );
  }


  // ========================================
  // 4. NO SHOW MATCH
  // ========================================

  return rejected(
    filter,
    "advanced_no_show_match"
  );
}


// ========================================
// ONE FILTER DISPATCH
//
// Basic tam thoi chua active.
//
// Fail-open la CO CHU DICH:
// trong luc Basic evaluator chua xong,
// khong duoc phep lam mat cuoc.
// ========================================

export function evaluateCompiledFilter(
  filter,
  context
) {
  if (
    filter.mode ===
    "advanced"
  ) {
    return evaluateAdvancedFilter(
      filter,
      context
    );
  }


  return {
    state:
      "pending",

    matched:
      null,

    reason:
      "basic_evaluator_pending",

    filterId:
      filter.id,

    filterName:
      filter.name,

    mode:
      filter.mode,

    keyword:
      null,
  };
}


// ========================================
// GROUP PLAN
//
// Filter ket hop OR:
//
// filter 1 reject
// filter 2 reject
// filter 3 accept
// => STOP + ACCEPT
//
// Khong co filter ap dung group:
// => ACCEPT
//
// Co Basic chua ho tro:
// => fail-open tam thoi.
// ========================================

export function evaluateCompiledGroupPlan(
  plan,
  messageText
) {
  // ========================================
  // KHONG CO FILTER CHO GROUP
  //
  // Dung logic da chot:
  // filter cua group A khong anh huong group B.
  // ========================================

  if (
    !plan ||
    plan.count ===
      0
  ) {
    return {
      matched:
        true,

      reason:
        "no_applicable_filters",

      filterId:
        null,

      filterName:
        null,

      mode:
        null,

      keyword:
        null,

      evaluatedFilters:
        0,
    };
  }


  // ========================================
  // NORMALIZE MESSAGE MOT LAN
  // ========================================

  const context =
    createFilterMessageContext(
      messageText
    );


  let evaluatedFilters =
    0;

  let hasPendingBasic =
    false;


  // ========================================
  // OR BETWEEN FILTERS
  //
  // Short-circuit ngay khi ACCEPT.
  // ========================================

  for (
    const filter of plan.filters
  ) {
    const result =
      evaluateCompiledFilter(
        filter,
        context
      );


    evaluatedFilters +=
      1;


    if (
      result.state ===
      "accept"
    ) {
      return {
        ...result,

        evaluatedFilters,
      };
    }


    if (
      result.state ===
      "pending"
    ) {
      hasPendingBasic =
        true;
    }
  }


  // ========================================
  // BASIC CHUA IMPLEMENT
  //
  // Khong reject message co kha nang
  // Basic filter se accept.
  // ========================================

  if (hasPendingBasic) {
    return {
      matched:
        true,

      reason:
        "basic_filter_pending_fail_open",

      filterId:
        null,

      filterName:
        null,

      mode:
        "basic",

      keyword:
        null,

      evaluatedFilters,
    };
  }


  // ========================================
  // TAT CA ADVANCED FILTER DEU REJECT
  // ========================================

  return {
    matched:
      false,

    reason:
      "no_filter_match",

    filterId:
      null,

    filterName:
      null,

    mode:
      null,

    keyword:
      null,

    evaluatedFilters,
  };
}