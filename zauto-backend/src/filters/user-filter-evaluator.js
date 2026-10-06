import {
  normalizeFilterText,
  findFirstKeywordMatch,
  findFirstKeywordOccurrence,
  findOrderedKeywordPair,
} from "./user-filter-matcher.js";

import {
  extractMessagePriceThousands,
} from "./user-filter-price.js";

import {
  extractMessageTemporalMentions,
  matchesCompiledTimeRules,
} from "./user-filter-time.js";



// ========================================
// TEST INSTRUMENTATION
//
// Mac dinh TAT.
// Chi test moi bat de dem hot-path work.
// ========================================

let evaluatorTestMetrics =
  null;


export function resetUserFilterEvaluatorTestMetrics() {
  evaluatorTestMetrics = {
    normalizeCalls:
      0,

    priceParseCalls:
      0,

    timeParseCalls:
      0,

    filterEvaluationCalls:
      0,
  };


  return {
    ...evaluatorTestMetrics,
  };
}


export function getUserFilterEvaluatorTestMetrics() {
  return evaluatorTestMetrics
    ? {
        ...evaluatorTestMetrics,
      }
    : null;
}


export function disableUserFilterEvaluatorTestMetrics() {
  evaluatorTestMetrics =
    null;
}


function bumpEvaluatorMetric(
  key
) {
  if (!evaluatorTestMetrics) {
    return;
  }


  evaluatorTestMetrics[key] +=
    1;
}


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


  bumpEvaluatorMetric(
    "normalizeCalls"
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

    temporalMentions:
      undefined,
  };
}

// ========================================
// LAZY PRICE
//
// undefined:
// chua parse.
//
// null:
// da parse, tin khong co gia.
//
// number:
// nghin dong.
//
// Nhieu Basic filter cung message
// van chi parse MOT LAN.
// ========================================

function getContextPrice(
  context
) {
  if (
    context.price !==
    undefined
  ) {
    return context.price;
  }


  bumpEvaluatorMetric(
    "priceParseCalls"
  );


  context.price =
    extractMessagePriceThousands(
      context.text
    );


  return context.price;
}


// ========================================
// LAZY TIME
// ========================================

function getContextTemporalMentions(
  context
) {
  if (
    context.temporalMentions !==
    undefined
  ) {
    return context.temporalMentions;
  }


  bumpEvaluatorMetric(
    "timeParseCalls"
  );


  context.temporalMentions =
    extractMessageTemporalMentions(
      context.text
    );


  return context.temporalMentions;
}


// ========================================
// FILTER RESULT HELPERS
// ========================================

function accepted(
  filter,
  reason,
  {
    keyword = null,
    details = null,
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

    details,
  };
}


function rejected(
  filter,
  reason,
  {
    keyword = null,
    details = null,
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

    details,
  };
}

function pending(
  filter,
  reason
) {
  return {
    state:
      "pending",

    matched:
      null,

    reason,

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
// ADVANCED PREVIEW DIAGNOSTICS
//
// Chi dung cho Preview thu cong.
// Hai nhanh Hide / Show duoc danh gia doc lap
// de UI co the giai thich ro:
// HIDE co uu tien cao hon SHOW.
// ========================================

export function evaluateAdvancedFilterDiagnostics(
  filter,
  messageText
) {
  const advanced =
    filter?.advanced;


  if (!advanced) {
    return [];
  }


  const context =
    createFilterMessageContext(
      messageText
    );


  const hideMatch =
    findFirstKeywordMatch(
      advanced.hideMatchers,
      context.text
    );


  const hideCheck = {
    key:
      "advanced_hide",

    status:
      advanced.hideMatchers.length ===
        0
        ? "skipped"
        : (
            hideMatch
              ? "fail"
              : "pass"
          ),

    details: {
      matched:
        hideMatch?.source ??
        null,

      expected:
        advanced.hideMatchers.map(
          matcher => matcher.source
        ),
    },
  };


  const showMatch =
    findFirstKeywordMatch(
      advanced.showMatchers,
      context.text
    );


  const showCheck = {
    key:
      "advanced_show",

    status:
      advanced.showMatchers.length ===
        0
        ? "skipped"
        : (
            showMatch
              ? "pass"
              : "fail"
          ),

    details: {
      matched:
        showMatch?.source ??
        null,

      expected:
        advanced.showMatchers.map(
          matcher => matcher.source
        ),

      catchAll:
        advanced.showMatchers.length ===
        0,

      overriddenByHide:
        hideMatch !== null &&
        (
          showMatch !== null ||
          advanced.showMatchers.length ===
            0
        ),
    },
  };


  return [
    hideCheck,
    showCheck,
  ];
}


// ========================================
// BASIC FILTER
//
// Thu tu:
// 1. exclude
// 2. pickup
// 3. dropoff
// 4. direction
// 5. include
// 6. price/time
//
// Price/time se lam buoc ke tiep.
// ========================================

export function evaluateBasicFilter(
  filter,
  context
) {
  const basic =
    filter.basic;


  if (!basic) {
    return rejected(
      filter,
      "basic_runtime_missing"
    );
  }


  // ========================================
  // 1. EXCLUDE
  //
  // Exclude thang moi dieu kien khac
  // TRONG filter nay.
  // ========================================

  const excludeMatch =
    findFirstKeywordMatch(
      basic.excludeMatchers,
      context.text
    );


  if (excludeMatch) {
    return rejected(
      filter,
      "basic_excluded_keyword",
      {
        keyword:
          excludeMatch.source,
      }
    );
  }


  // ========================================
  // 2. PICKUP
  // ========================================

  const hasPickupRule =
    basic
      .pickupMatchers
      .length >
    0;


  const pickup =
    hasPickupRule
      ? findFirstKeywordOccurrence(
          basic.pickupMatchers,
          context.text
        )
      : null;


  if (
    hasPickupRule &&
    !pickup
  ) {
    return rejected(
      filter,
      "basic_pickup_no_match",
      {
        details: {
          expected:
            basic.pickupMatchers.map(
              matcher => matcher.source
            ),
        },
      }
    );
  }


  // ========================================
  // 3. DROPOFF
  // ========================================

  const hasDropoffRule =
    basic
      .dropoffMatchers
      .length >
    0;


  const dropoff =
    hasDropoffRule
      ? findFirstKeywordOccurrence(
          basic.dropoffMatchers,
          context.text
        )
      : null;


  if (
    hasDropoffRule &&
    !dropoff
  ) {
    return rejected(
      filter,
      "basic_dropoff_no_match",
      {
        details: {
          expected:
            basic.dropoffMatchers.map(
              matcher => matcher.source
            ),
        },
      }
    );
  }


  // ========================================
  // 4. DIRECTION
  //
  // Chi ap dung khi:
  // - co pickup
  // - co dropoff
  // - acceptBothDirections = false
  // ========================================

  if (
    basic.needsDirection
  ) {
    let directionMatched =
      false;


    // Fast path:
    // occurrence dau tien da dung thu tu.
    if (
      pickup &&
      dropoff &&
      pickup.index <
        dropoff.index
    ) {
      directionMatched =
        true;

    } else {

      // Slow path rat hiem:
      // message co nhieu occurrence.
      directionMatched =
        findOrderedKeywordPair(
          basic.pickupMatchers,
          basic.dropoffMatchers,
          context.text
        ) !== null;
    }


    if (
      !directionMatched
    ) {
      return rejected(
        filter,
        "basic_wrong_direction",
        {
          details: {
            pickup:
              pickup?.matcher?.source ??
              null,

            dropoff:
              dropoff?.matcher?.source ??
              null,
          },
        }
      );
    }


    // Khi user TAT "Nhan ca hai chieu",
    // tin co ca chieu nguoc (dropoff -> pickup)
    // la cuoc hai chieu/khu hoi va phai bi bo qua.
    const reverseDirectionMatched =
      findOrderedKeywordPair(
        basic.dropoffMatchers,
        basic.pickupMatchers,
        context.text
      ) !== null;


    if (
      reverseDirectionMatched
    ) {
      return rejected(
        filter,
        "basic_round_trip_detected",
        {
          details: {
            pickup:
              pickup?.matcher?.source ??
              null,

            dropoff:
              dropoff?.matcher?.source ??
              null,
          },
        }
      );
    }
  }


  // ========================================
  // 5. INCLUDE KEYWORD
  //
  // Rong = khong dat them dieu kien.
  // ========================================

  if (
    basic
      .includeMatchers
      .length >
    0
  ) {
    const includeMatch =
      findFirstKeywordMatch(
        basic.includeMatchers,
        context.text
      );


    if (!includeMatch) {
      return rejected(
        filter,
        "basic_include_no_match",
        {
          details: {
            expected:
              basic.includeMatchers.map(
                matcher => matcher.source
              ),
          },
        }
      );
    }
  }


  // ========================================
  // 6. PRICE / TIME
  //
  // Route + keyword da PASS.
  //
  // Neu filter con price/time thi tam thoi
  // khong duoc ACCEPT cho den khi parser
  // buoc ke tiep xong.
  // ========================================

  // ========================================
  // 6. MINIMUM PRICE
  // ========================================

  if (
    basic.needsPrice
  ) {
    const price =
      getContextPrice(
        context
      );


    // UI da quy dinh:
    // co minimumPrice nhung tin khong ghi gia
    // => KHONG MATCH.
    if (
      price === null
    ) {
      return rejected(
        filter,
        "basic_price_missing",
        {
          details: {
            minimumPrice:
              basic.minimumPrice,
          },
        }
      );
    }


    if (
      price <
      basic.minimumPrice
    ) {
      return rejected(
        filter,
        "basic_price_below_minimum",
        {
          details: {
            messagePrice:
              price,

            minimumPrice:
              basic.minimumPrice,
          },
        }
      );
    }
  }


  // ========================================
  // 7. TIME
  // ========================================

  if (
    basic.needsTime
  ) {
    const temporalMentions =
      getContextTemporalMentions(
        context
      );


    if (
      !matchesCompiledTimeRules(
        basic.compiledTimeRules,
        temporalMentions,
        context.text
      )
    ) {
      return rejected(
        filter,
        "basic_time_no_match",
        {
          details: {
            timeRules:
              basic.timeRules,
          },
        }
      );
    }
  }


  // ========================================
  // ALL BASIC CONDITIONS PASSED
  // ========================================

  return accepted(
    filter,
    "basic_conditions_match"
  );

}

// ========================================
// BASIC PREVIEW DIAGNOSTICS
//
// Chi dung cho thao tac Preview thu cong.
// KHONG duoc goi tren realtime hot path.
//
// Moi dieu kien duoc danh gia doc lap de UI
// co the hien toan bo PASS / FAIL / SKIP,
// thay vi dung o loi dau tien.
// ========================================

export function evaluateBasicFilterDiagnostics(
  filter,
  messageText
) {
  const basic =
    filter?.basic;


  if (!basic) {
    return [];
  }


  const context =
    createFilterMessageContext(
      messageText
    );


  const checks = [];


  const addCheck = (
    key,
    status,
    details = null
  ) => {
    checks.push({
      key,
      status,
      details,
    });
  };


  // ========================================
  // EXCLUDE
  // ========================================

  if (
    basic.excludeMatchers.length ===
    0
  ) {
    addCheck(
      "exclude",
      "skipped"
    );

  } else {

    const match =
      findFirstKeywordMatch(
        basic.excludeMatchers,
        context.text
      );


    addCheck(
      "exclude",
      match
        ? "fail"
        : "pass",
      {
        keyword:
          match?.source ??
          null,

        expected:
          basic.excludeMatchers.map(
            matcher => matcher.source
          ),
      }
    );
  }


  // ========================================
  // PICKUP
  // ========================================

  const hasPickup =
    basic.pickupMatchers.length >
    0;


  const pickup =
    hasPickup
      ? findFirstKeywordOccurrence(
          basic.pickupMatchers,
          context.text
        )
      : null;


  addCheck(
    "pickup",
    hasPickup
      ? (
          pickup
            ? "pass"
            : "fail"
        )
      : "skipped",
    hasPickup
      ? {
          matched:
            pickup?.matcher?.source ??
            null,

          expected:
            basic.pickupMatchers.map(
              matcher => matcher.source
            ),
        }
      : null
  );


  // ========================================
  // DROPOFF
  // ========================================

  const hasDropoff =
    basic.dropoffMatchers.length >
    0;


  const dropoff =
    hasDropoff
      ? findFirstKeywordOccurrence(
          basic.dropoffMatchers,
          context.text
        )
      : null;


  addCheck(
    "dropoff",
    hasDropoff
      ? (
          dropoff
            ? "pass"
            : "fail"
        )
      : "skipped",
    hasDropoff
      ? {
          matched:
            dropoff?.matcher?.source ??
            null,

          expected:
            basic.dropoffMatchers.map(
              matcher => matcher.source
            ),
        }
      : null
  );


  // ========================================
  // DIRECTION
  // ========================================

  if (!basic.needsDirection) {
    addCheck(
      "direction",
      "skipped"
    );

  } else if (
    !pickup ||
    !dropoff
  ) {
    addCheck(
      "direction",
      "fail",
      {
        blockedByMissingRoute:
          true,
      }
    );

  } else {

    const directionMatched =
      pickup.index <
        dropoff.index ||
      findOrderedKeywordPair(
        basic.pickupMatchers,
        basic.dropoffMatchers,
        context.text
      ) !== null;


    const reverseDirectionMatched =
      directionMatched &&
      findOrderedKeywordPair(
        basic.dropoffMatchers,
        basic.pickupMatchers,
        context.text
      ) !== null;


    addCheck(
      "direction",
      directionMatched &&
      !reverseDirectionMatched
        ? "pass"
        : "fail",
      {
        pickup:
          pickup.matcher.source,

        dropoff:
          dropoff.matcher.source,

        roundTripDetected:
          reverseDirectionMatched,
      }
    );
  }


  // ========================================
  // INCLUDE
  // ========================================

  if (
    basic.includeMatchers.length ===
    0
  ) {
    addCheck(
      "include",
      "skipped"
    );

  } else {

    const match =
      findFirstKeywordMatch(
        basic.includeMatchers,
        context.text
      );


    addCheck(
      "include",
      match
        ? "pass"
        : "fail",
      {
        matched:
          match?.source ??
          null,

        expected:
          basic.includeMatchers.map(
            matcher => matcher.source
          ),
      }
    );
  }


  // ========================================
  // PRICE
  // ========================================

  if (!basic.needsPrice) {
    addCheck(
      "price",
      "skipped"
    );

  } else {

    const price =
      getContextPrice(
        context
      );


    addCheck(
      "price",
      price !== null &&
      price >= basic.minimumPrice
        ? "pass"
        : "fail",
      {
        messagePrice:
          price,

        minimumPrice:
          basic.minimumPrice,
      }
    );
  }


  // ========================================
  // TIME
  // ========================================

  if (!basic.needsTime) {
    addCheck(
      "time",
      "skipped"
    );

  } else {

    const temporalMentions =
      getContextTemporalMentions(
        context
      );


    const matched =
      matchesCompiledTimeRules(
        basic.compiledTimeRules,
        temporalMentions,
        context.text
      );


    addCheck(
      "time",
      matched
        ? "pass"
        : "fail",
      {
        timeRules:
          basic.timeRules,
      }
    );
  }


  return checks;
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
  bumpEvaluatorMetric(
    "filterEvaluationCalls"
  );


  if (
    filter.mode ===
    "advanced"
  ) {
    return evaluateAdvancedFilter(
      filter,
      context
    );
  }


  return evaluateBasicFilter(
    filter,
    context
  );
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