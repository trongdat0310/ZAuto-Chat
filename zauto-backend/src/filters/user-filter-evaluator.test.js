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
  pickup = "",
  dropoff = "",
  bothDirections = false,
  include = "",
  exclude = "",
  price = null,
  time = "",
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
      pickup,

      dropoff,

      acceptBothDirections:
        bothDirections,

      includeKeywords:
        include,

      excludeKeywords:
        exclude,

      minimumPrice:
        price,

      timeRules:
        time,
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
  "basic route accepts correct pickup to dropoff direction",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "airport",

            pickup:
              "q1, quận 1",

            dropoff:
              "nội bài, nb",
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "22h cần xe Q1 đi Nội Bài"
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
      "basic_conditions_match"
    );
  }
);


test(
  "basic route rejects reverse direction",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "airport",

            pickup:
              "q1",

            dropoff:
              "nội bài",
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "Nội Bài về Q1"
      );


    assert.equal(
      result.matched,
      false
    );
  }
);


test(
  "basic both directions accepts reverse route",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "airport",

            pickup:
              "q1",

            dropoff:
              "nội bài",

            bothDirections:
              true,
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "Nội Bài về Q1"
      );


    assert.equal(
      result.matched,
      true
    );
  }
);


test(
  "basic exclude keyword overrides matching route and include",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "airport",

            pickup:
              "q1",

            dropoff:
              "nội bài",

            include:
              "4c, 4 chỗ",

            exclude:
              "ghép",
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "Q1 đi Nội Bài xe 4c ghép khách"
      );


    assert.equal(
      result.matched,
      false
    );
  }
);


test(
  "basic include keywords use OR",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "airport",

            include:
              "4c, 7c, vip",
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "cần xe 7c đi sân bay"
      );


    assert.equal(
      result.matched,
      true
    );
  }
);


test(
  "basic include rejects when none match",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "airport",

            include:
              "4c, vip",
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "cần xe 7c"
      );


    assert.equal(
      result.matched,
      false
    );
  }
);


test(
  "basic empty fields accept message",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "all-basic",
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "tin bất kỳ"
      );


    assert.equal(
      result.matched,
      true
    );
  }
);

test(
  "basic minimum price accepts sufficient price",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "priced",

            pickup:
              "q1",

            price:
              500,
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "Q1 đi Nội Bài giá 650k"
      );


    assert.equal(
      result.matched,
      true
    );


    assert.equal(
      result.filterId,
      "priced"
    );
  }
);


test(
  "basic minimum price rejects lower price",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "priced",

            price:
              500,
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "cuốc giá 450k"
      );


    assert.equal(
      result.matched,
      false
    );
  }
);


test(
  "basic minimum price rejects message without price",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "priced",

            price:
              500,
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
      false
    );
  }
);


test(
  "basic minimum price supports Vietnamese million shorthand",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "priced",

            price:
              1100,
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "Q1 đi Nội Bài 1tr2"
      );


    assert.equal(
      result.matched,
      true
    );
  }
);


test(
  "basic time is still temporarily fail open",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "timed",

            time:
              "sáng",
          }),
        ],
      });


    const result =
      evaluateCompiledGroupPlan(
        getCompiledGroupPlan(
          runtime,
          "any"
        ),

        "cuốc tối nay"
      );


    assert.equal(
      result.matched,
      true
    );


    assert.equal(
      result.reason,
      "basic_time_pending_fail_open"
    );
  }
);