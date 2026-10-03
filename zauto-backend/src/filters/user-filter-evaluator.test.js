import test from "node:test";
import assert from "node:assert/strict";

import {
  compileUserFilterDocument,
  getCompiledGroupPlan,
} from "./user-filter-runtime.js";

import {
  evaluateCompiledGroupPlan,
} from "./user-filter-evaluator.js";


// ========================================
// HELPERS
// ========================================

function advancedFilter({
  id,
  groups = [],
  show = [],
  hide = [],
  enabled = true,
}) {
  return {
    id,

    name:
      id,

    mode:
      "advanced",

    enabled,

    groupIds:
      groups,

    basic: {},

    advanced: {
      showKeywords:
        show,

      hideKeywords:
        hide,
    },
  };
}


function basicFilter({
  id,
  groups = [],
}) {
  return {
    id,

    name:
      id,

    mode:
      "basic",

    enabled:
      true,

    groupIds:
      groups,

    basic: {
      pickup:
        "q1",

      dropoff:
        "nội bài",

      acceptBothDirections:
        false,

      includeKeywords:
        "",

      excludeKeywords:
        "",

      minimumPrice:
        null,

      timeRules:
        "",
    },

    advanced: {
      showKeywords:
        [],

      hideKeywords:
        [],
    },
  };
}


// ========================================
// NO FILTER
// ========================================

test(
  "no applicable filters accepts message",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "only-a",

            groups: [
              "a",
            ],

            show: [
              "nội bài",
            ],
          }),
        ],
      });


    const plan =
      getCompiledGroupPlan(
        runtime,
        "b"
      );


    const result =
      evaluateCompiledGroupPlan(
        plan,
        "q1 đi nội bài"
      );


    assert.equal(
      result.matched,
      true
    );

    assert.equal(
      result.reason,
      "no_applicable_filters"
    );
  }
);


// ========================================
// SHOW MATCH
// ========================================

test(
  "advanced show keyword accepts",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "airport",

            show: [
              "*(nội bài|nb)*",
            ],
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "Q1 đi Nội Bài"
      );


    assert.equal(
      result.matched,
      true
    );

    assert.equal(
      result.filterId,
      "airport"
    );

    assert.equal(
      result.reason,
      "advanced_show_keyword"
    );
  }
);


// ========================================
// SHOW EMPTY
// ========================================

test(
  "advanced empty show list accepts everything not hidden",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "all",

            hide: [
              "*ghép*",
            ],
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "Q1 đi Nội Bài"
      );


    assert.equal(
      result.matched,
      true
    );

    assert.equal(
      result.reason,
      "advanced_no_show_keywords"
    );
  }
);


// ========================================
// HIDE > SHOW
// ========================================

test(
  "advanced hide overrides show inside same filter",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "airport",

            show: [
              "*nội bài*",
            ],

            hide: [
              "*ghép*",
            ],
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "ghép khách đi Nội Bài"
      );


    assert.equal(
      result.matched,
      false
    );

    assert.equal(
      result.reason,
      "no_filter_match"
    );
  }
);


// ========================================
// HIDE IS LOCAL TO FILTER
// ========================================

test(
  "one filter hide does not veto another matching filter",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "airport",

            show: [
              "*nội bài*",
            ],

            hide: [
              "*ghép*",
            ],
          }),

          advancedFilter({
            id:
              "vip",

            show: [
              "*vip*",
            ],
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "cuốc VIP ghép khách đi Nội Bài"
      );


    assert.equal(
      result.matched,
      true
    );

    assert.equal(
      result.filterId,
      "vip"
    );
  }
);


// ========================================
// OR + SHORT CIRCUIT
// ========================================

test(
  "advanced filters short circuit after first accept",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "reject-first",

            show: [
              "*hải phòng*",
            ],
          }),

          advancedFilter({
            id:
              "accept-second",

            show: [
              "*nội bài*",
            ],
          }),

          advancedFilter({
            id:
              "never-needed",

            show: [
              "*vip*",
            ],
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "Q1 đi Nội Bài"
      );


    assert.equal(
      result.matched,
      true
    );

    assert.equal(
      result.filterId,
      "accept-second"
    );

    assert.equal(
      result.evaluatedFilters,
      2
    );
  }
);


// ========================================
// ALL REJECT
// ========================================

test(
  "all advanced filters rejecting rejects message",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "airport",

            show: [
              "*nội bài*",
            ],
          }),

          advancedFilter({
            id:
              "vip",

            show: [
              "*vip*",
            ],
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "Bình Thạnh đi Thủ Đức"
      );


    assert.equal(
      result.matched,
      false
    );

    assert.equal(
      result.reason,
      "no_filter_match"
    );
  }
);


// ========================================
// BASIC TEMPORARY FAIL OPEN
// ========================================

test(
  "basic filter fails open until basic evaluator is implemented",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "basic",

            groups: [
              "a",
            ],
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "a"
        ),

        "message bat ky"
      );


    assert.equal(
      result.matched,
      true
    );

    assert.equal(
      result.reason,
      "basic_filter_pending_fail_open"
    );
  }
);