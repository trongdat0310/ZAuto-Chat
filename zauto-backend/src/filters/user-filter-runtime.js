import {
  LEGACY_FILTER_ID,
  getUserFilterDocument,
} from "./user-filter-store.js";

import {
  compileCommaSeparatedKeywords,
  compileKeywordList,
  compileLegacyContainsList,
} from "./user-filter-matcher.js";


// ========================================
// RUNTIME CACHE
//
// userId -> {
//   document,
//   runtime
// }
//
// document trong store duoc thay object
// moi khi save.
//
// => chi can compare reference.
// => khong timestamp.
// => khong disk I/O.
// ========================================

const runtimeCache =
  new Map();


// ========================================
// EMPTY CONSTANTS
// ========================================

const EMPTY_FILTERS =
  Object.freeze([]);

const EMPTY_GROUP_PLAN =
  Object.freeze({
    filters:
      EMPTY_FILTERS,

    count:
      0,

    needsBasic:
      false,

    needsAdvanced:
      false,

    needsPrice:
      false,

    needsTime:
      false,
  });


// ========================================
// BASIC FILTER COMPILE
// ========================================

function compileBasicFilter(
  filter
) {
  const basic =
    filter.basic ?? {};


  const pickupMatchers =
    compileCommaSeparatedKeywords(
      basic.pickup
    );


  const dropoffMatchers =
    compileCommaSeparatedKeywords(
      basic.dropoff
    );


  const includeMatchers =
    compileCommaSeparatedKeywords(
      basic.includeKeywords
    );


  const excludeMatchers =
    compileCommaSeparatedKeywords(
      basic.excludeKeywords
    );


  const minimumPrice =
    Number.isFinite(
      Number(
        basic.minimumPrice
      )
    ) &&
    basic.minimumPrice !==
      null &&
    basic.minimumPrice !==
      ""
      ? Number(
          basic.minimumPrice
        )
      : null;


  const timeRules =
    String(
      basic.timeRules ?? ""
    ).trim();


  return {
    pickupMatchers,

    dropoffMatchers,

    includeMatchers,

    excludeMatchers,

    acceptBothDirections:
      basic.acceptBothDirections ===
      true,

    minimumPrice,

    timeRules,

    // ========================================
    // FEATURE FLAGS
    //
    // De message evaluator biet co can
    // parse price/time hay khong.
    // ========================================

    needsPrice:
      minimumPrice !== null,

    needsTime:
      timeRules.length > 0,

    needsDirection:
      pickupMatchers.length > 0 &&
      dropoffMatchers.length > 0 &&
      basic.acceptBothDirections !==
        true,
  };
}


// ========================================
// ADVANCED FILTER COMPILE
// ========================================

function compileAdvancedFilter(
  filter
) {
  const advanced =
    filter.advanced ?? {};


  // ========================================
  // LEGACY
  //
  // Filter cu dung includes().
  // Phai bao toan behavior cu.
  // ========================================

  const isLegacy =
    filter.id ===
    LEGACY_FILTER_ID;


  const showMatchers =
    isLegacy
      ? compileLegacyContainsList(
          advanced.showKeywords
        )
      : compileKeywordList(
          advanced.showKeywords
        );


  const hideMatchers =
    isLegacy
      ? compileLegacyContainsList(
          advanced.hideKeywords
        )
      : compileKeywordList(
          advanced.hideKeywords
        );


  return {
    showMatchers,

    hideMatchers,

    isLegacy,
  };
}


// ========================================
// COMPILE ONE FILTER
// ========================================

function compileOneFilter(
  filter
) {
  const mode =
    filter.mode ===
      "advanced"
      ? "advanced"
      : "basic";


  const compiled = {
    id:
      String(
        filter.id
      ),

    name:
      String(
        filter.name ?? ""
      ),

    mode,

    enabled:
      filter.enabled !==
      false,

    groupIds:
      Array.isArray(
        filter.groupIds
      )
        ? filter.groupIds.map(
            value =>
              String(value)
          )
        : [],

    createdAt:
      filter.createdAt ??
      null,

    updatedAt:
      filter.updatedAt ??
      null,

    basic:
      null,

    advanced:
      null,
  };


  if (
    mode ===
    "basic"
  ) {
    compiled.basic =
      compileBasicFilter(
        filter
      );
  } else {
    compiled.advanced =
      compileAdvancedFilter(
        filter
      );
  }


  return compiled;
}


// ========================================
// BUILD GROUP PLAN
//
// Chi chay khi compile/filter document doi,
// hoac lan dau group cu the duoc truy cap.
// ========================================

function buildGroupPlan(
  filters
) {
  if (
    !filters ||
    filters.length ===
      0
  ) {
    return EMPTY_GROUP_PLAN;
  }


  let needsBasic =
    false;

  let needsAdvanced =
    false;

  let needsPrice =
    false;

  let needsTime =
    false;


  for (
    const filter of filters
  ) {
    if (
      filter.mode ===
      "basic"
    ) {
      needsBasic =
        true;


      if (
        filter.basic
          ?.needsPrice ===
        true
      ) {
        needsPrice =
          true;
      }


      if (
        filter.basic
          ?.needsTime ===
        true
      ) {
        needsTime =
          true;
      }

    } else {

      needsAdvanced =
        true;
    }
  }


  return {
    filters,

    count:
      filters.length,

    needsBasic,

    needsAdvanced,

    needsPrice,

    needsTime,
  };
}


// ========================================
// COMPILE DOCUMENT
//
// Export de unit test truc tiep,
// khong can disk.
// ========================================

export function compileUserFilterDocument(
  document
) {
  const sourceFilters =
    Array.isArray(
      document?.filters
    )
      ? document.filters
      : [];


  const compiledFilters =
    [];


  const enabledAllGroups =
    [];


  const enabledByGroup =
    new Map();


  let legacyFilter =
    null;


  let enabledCount =
    0;


  // ========================================
  // COMPILE ALL FILTERS ONCE
  // ========================================

  for (
    const rawFilter of
    sourceFilters
  ) {
    const filter =
      compileOneFilter(
        rawFilter
      );


    compiledFilters.push(
      filter
    );


    if (
      filter.id ===
      LEGACY_FILTER_ID
    ) {
      legacyFilter =
        filter;
    }


    // Disabled filter van duoc compile
    // de legacy/API co the doc state,
    // nhung KHONG vao candidate index.
    if (!filter.enabled) {
      continue;
    }


    enabledCount +=
      1;


    // ========================================
    // [] = ALL GROUPS
    // ========================================

    if (
      filter.groupIds.length ===
      0
    ) {
      enabledAllGroups.push(
        filter
      );

      continue;
    }


    // ========================================
    // GROUP-SPECIFIC INDEX
    // ========================================

    for (
      const rawGroupId of
      filter.groupIds
    ) {
      const groupId =
        String(
          rawGroupId
        ).trim();


      if (!groupId) {
        continue;
      }


      let bucket =
        enabledByGroup.get(
          groupId
        );


      if (!bucket) {
        bucket = [];

        enabledByGroup.set(
          groupId,
          bucket
        );
      }


      bucket.push(
        filter
      );
    }
  }


  // ========================================
  // ALL-GROUPS PLAN
  //
  // Group khong co filter rieng se dung
  // truc tiep plan nay, khong tao array moi.
  // ========================================

  const allGroupsPlan =
    buildGroupPlan(
      enabledAllGroups
    );


  return {
    document,

    configuredCount:
      compiledFilters.length,

    enabledCount,

    compiledFilters,

    legacyFilter,

    allGroupsFilters:
      enabledAllGroups,

    filtersByGroup:
      enabledByGroup,

    allGroupsPlan,

    // Chi cache group THUC SU co
    // filter rieng.
    //
    // Group la khong co filter rieng
    // dung allGroupsPlan truc tiep.
    groupPlanCache:
      new Map(),
  };
}


// ========================================
// GET GROUP PLAN FROM COMPILED RUNTIME
//
// Khong I/O.
// Khong compile.
// Khong parse filter.
// ========================================

export function getCompiledGroupPlan(
  runtime,
  groupId
) {
  const key =
    String(
      groupId ?? ""
    ).trim();


  // Khong co group cu the
  // => chi filter all-groups.
  if (!key) {
    return runtime
      .allGroupsPlan;
  }


  const specific =
    runtime
      .filtersByGroup
      .get(
        key
      );


  // ========================================
  // KHONG CO FILTER RIENG CHO GROUP
  //
  // Tra object co san.
  // Khong cache key rac.
  // Khong allocate array.
  // ========================================

  if (
    !specific ||
    specific.length ===
      0
  ) {
    return runtime
      .allGroupsPlan;
  }


  const cached =
    runtime
      .groupPlanCache
      .get(
        key
      );


  if (cached) {
    return cached;
  }


  // ========================================
  // COMBINE 1 LAN
  //
  // Sau do cache cho group.
  // Message tiep theo khong spread nua.
  // ========================================

  const filters =
    runtime
      .allGroupsFilters
      .length >
    0
      ? [
          ...runtime
            .allGroupsFilters,

          ...specific,
        ]
      : specific;


  const plan =
    buildGroupPlan(
      filters
    );


  runtime
    .groupPlanCache
    .set(
      key,
      plan
    );


  return plan;
}


// ========================================
// GET USER RUNTIME
//
// Hot path:
// - get document RAM
// - compare object reference
// - return runtime RAM
// ========================================

export function getUserFilterRuntime(
  userId
) {
  const key =
    String(
      userId
    );


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
    return cached.runtime;
  }


  const runtime =
    compileUserFilterDocument(
      document
    );


  runtimeCache.set(
    key,
    {
      document,

      runtime,
    }
  );


  return runtime;
}


// ========================================
// GROUP PLAN FOR USER
// ========================================

export function getUserFilterGroupPlan(
  userId,
  groupId
) {
  const runtime =
    getUserFilterRuntime(
      userId
    );


  return getCompiledGroupPlan(
    runtime,
    groupId
  );
}


// ========================================
// WARM RUNTIME
//
// Goi ngay sau SAVE.
//
// => compile chi phi nam o request Save.
// => message dau tien sau save KHONG bi delay.
// ========================================

export function warmUserFilterRuntime(
  userId
) {
  return getUserFilterRuntime(
    userId
  );
}


// ========================================
// MANUAL INVALIDATE
// ========================================

export function invalidateUserFilterRuntime(
  userId
) {
  runtimeCache.delete(
    String(
      userId
    )
  );
}