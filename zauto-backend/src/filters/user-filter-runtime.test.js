import test from "node:test";
import assert from "node:assert/strict";

import {
  compileUserFilterDocument,
  disableUserFilterRuntimeTestMetrics,
  getCompiledGroupPlan,
  getUserFilterRuntimeTestMetrics,
  resetUserFilterRuntimeTestMetrics,
} from "./user-filter-runtime.js";

import {
  normalizeFilterText,
} from "./user-filter-matcher.js";

import {
  LEGACY_FILTER_ID,
} from "./user-filter-store.js";


// ========================================
// HELPERS
// ========================================

function advancedFilter({
  id,
  groups = [],
  enabled = true,
  show = [],
  hide = [],
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

    basic:
      {},

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
  enabled = true,
  price = null,
  time = "",
}) {
  return {
    id,

    name:
      id,

    mode:
      "basic",

    enabled,

    groupIds:
      groups,

    basic: {
      pickup:
        "",

      dropoff:
        "",

      acceptBothDirections:
        false,

      includeKeywords:
        "",

      excludeKeywords:
        "",

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
// ALL GROUP + SPECIFIC
// ========================================

test(
  "group plan contains all-group and matching group filters only",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "all",
          }),

          advancedFilter({
            id:
              "group-a",
            groups: [
              "a",
            ],
          }),

          advancedFilter({
            id:
              "group-b",
            groups: [
              "b",
            ],
          }),

          advancedFilter({
            id:
              "disabled-a",
            groups: [
              "a",
            ],
            enabled:
              false,
          }),
        ],
      });


    const planA =
      getCompiledGroupPlan(
        runtime,
        "a"
      );


    assert.deepEqual(
      planA.filters.map(
        item =>
          item.id
      ),
      [
        "all",
        "group-a",
      ]
    );


    const planB =
      getCompiledGroupPlan(
        runtime,
        "b"
      );


    assert.deepEqual(
      planB.filters.map(
        item =>
          item.id
      ),
      [
        "all",
        "group-b",
      ]
    );


    const planC =
      getCompiledGroupPlan(
        runtime,
        "c"
      );


    assert.deepEqual(
      planC.filters.map(
        item =>
          item.id
      ),
      [
        "all",
      ]
    );
  }
);


// ========================================
// NO APPLICABLE FILTER
// ========================================

test(
  "unrelated group gets empty plan when there is no all-group filter",
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
          }),
        ],
      });


    const plan =
      getCompiledGroupPlan(
        runtime,
        "b"
      );


    assert.equal(
      plan.count,
      0
    );

    assert.equal(
      plan.filters.length,
      0
    );
  }
);


// ========================================
// FEATURE FLAGS
// ========================================

test(
  "group plan precomputes expensive parser requirements",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id:
              "price",
            groups: [
              "a",
            ],
            price:
              500,
          }),

          basicFilter({
            id:
              "time",
            groups: [
              "a",
            ],
            time:
              "sáng",
          }),

          advancedFilter({
            id:
              "advanced",
            groups: [
              "a",
            ],
          }),
        ],
      });


    const plan =
      getCompiledGroupPlan(
        runtime,
        "a"
      );


    assert.equal(
      plan.needsBasic,
      true
    );

    assert.equal(
      plan.needsAdvanced,
      true
    );

    assert.equal(
      plan.needsPrice,
      true
    );

    assert.equal(
      plan.needsTime,
      true
    );
  }
);


// ========================================
// 50 FILTER SCALE
//
// Chung minh group index khong quet 50
// candidate o message hot path.
// ========================================

test(
  "50 configured filters are reduced to relevant group candidates",
  () => {
    const filters = [
      advancedFilter({
        id:
          "all",
      }),
    ];


    for (
      let index = 1;
      index < 50;
      index += 1
    ) {
      filters.push(
        advancedFilter({
          id:
            `filter-${index}`,

          groups: [
            `group-${index}`,
          ],
        })
      );
    }


    const runtime =
      compileUserFilterDocument({
        filters,
      });


    assert.equal(
      runtime.configuredCount,
      50
    );


    const plan =
      getCompiledGroupPlan(
        runtime,
        "group-25"
      );


    assert.equal(
      plan.count,
      2
    );


    assert.deepEqual(
      plan.filters.map(
        item =>
          item.id
      ),
      [
        "all",
        "filter-25",
      ]
    );
  }
);


// ========================================
// GROUP PLAN CACHE
// ========================================

test(
  "specific group plan is reused without allocating again",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "all",
          }),

          advancedFilter({
            id:
              "a",
            groups: [
              "a",
            ],
          }),
        ],
      });


    const first =
      getCompiledGroupPlan(
        runtime,
        "a"
      );


    const second =
      getCompiledGroupPlan(
        runtime,
        "a"
      );


    assert.equal(
      first,
      second
    );
  }
);


// ========================================
// LEGACY BEHAVIOR
// ========================================

test(
  "legacy filter keeps contains matching behavior",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              LEGACY_FILTER_ID,

            show: [
              "tan",
            ],
          }),
        ],
      });


    const matcher =
      runtime
        .legacyFilter
        .advanced
        .showMatchers[0];


    assert.equal(
      matcher.matches(
        normalizeFilterText(
          "tang hang"
        )
      ),
      true
    );
  }
);


// ========================================
// NEW ADVANCED BEHAVIOR
// ========================================

test(
  "new advanced plain keyword uses whole-word matching",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id:
              "new-filter",

            show: [
              "tân",
            ],
          }),
        ],
      });


    const filter =
      runtime
        .compiledFilters[0];


    const matcher =
      filter
        .advanced
        .showMatchers[0];


    assert.equal(
      matcher.matches(
        normalizeFilterText(
          "đi tân ngay"
        )
      ),
      true
    );


    assert.equal(
      matcher.matches(
        normalizeFilterText(
          "tặng hàng"
        )
      ),
      false
    );
  }
);


// ========================================
// ENABLE / DISABLE AND GROUP PLAN MATRIX
// ========================================

test(
  "all disabled filters produce an empty applicable plan",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id: "disabled-all",
            enabled: false,
          }),
          basicFilter({
            id: "disabled-group",
            groups: ["a"],
            enabled: false,
          }),
        ],
      });

    assert.equal(runtime.configuredCount, 2);
    assert.equal(runtime.enabledCount, 0);

    assert.equal(
      getCompiledGroupPlan(runtime, "a").count,
      0
    );

    assert.equal(
      getCompiledGroupPlan(runtime, "other").count,
      0
    );
  }
);


test(
  "group plan preserves document priority across all and specific filters",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id: "all-first",
          }),
          advancedFilter({
            id: "group-first",
            groups: ["a"],
          }),
          advancedFilter({
            id: "all-second",
          }),
          advancedFilter({
            id: "group-second",
            groups: ["a"],
          }),
        ],
      });

    assert.deepEqual(
      getCompiledGroupPlan(runtime, "a")
        .filters
        .map((item) => item.id),
      [
        "all-first",
        "group-first",
        "all-second",
        "group-second",
      ]
    );
  }
);


test(
  "missing group id only uses all-group filters",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id: "all",
          }),
          advancedFilter({
            id: "specific",
            groups: ["a"],
          }),
        ],
      });

    assert.deepEqual(
      getCompiledGroupPlan(runtime, null)
        .filters
        .map((item) => item.id),
      ["all"]
    );
  }
);


test(
  "group plan feature flags ignore disabled expensive filters",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          basicFilter({
            id: "disabled-price",
            groups: ["a"],
            price: 500,
            enabled: false,
          }),
          basicFilter({
            id: "disabled-time",
            groups: ["a"],
            time: "sáng",
            enabled: false,
          }),
          advancedFilter({
            id: "active",
            groups: ["a"],
          }),
        ],
      });

    const plan =
      getCompiledGroupPlan(runtime, "a");

    assert.equal(plan.needsBasic, false);
    assert.equal(plan.needsAdvanced, true);
    assert.equal(plan.needsPrice, false);
    assert.equal(plan.needsTime, false);
  }
);



test(
  "group-specific filter can have higher priority than all-group filter",
  () => {
    const runtime =
      compileUserFilterDocument({
        filters: [
          advancedFilter({
            id: "specific-first",
            groups: ["a"],
          }),
          advancedFilter({
            id: "all-second",
          }),
        ],
      });

    assert.deepEqual(
      getCompiledGroupPlan(runtime, "a")
        .filters
        .map((item) => item.id),
      [
        "specific-first",
        "all-second",
      ]
    );
  }
);



// ========================================
// RUNTIME CACHE INSTRUMENTATION
// ========================================

test(
  "specific group plan builds once then reuses cache",
  () => {
    resetUserFilterRuntimeTestMetrics();

    try {
      const runtime =
        compileUserFilterDocument({
          filters: [
            advancedFilter({
              id: "all",
            }),
            advancedFilter({
              id: "specific",
              groups: ["a"],
            }),
          ],
        });

      const before =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        before.compileDocumentCalls,
        1
      );

      assert.equal(
        before.buildGroupPlanCalls,
        1
      );

      const first =
        getCompiledGroupPlan(
          runtime,
          "a"
        );

      const afterFirst =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        afterFirst.groupPlanCacheMisses,
        1
      );

      assert.equal(
        afterFirst.groupPlanCacheHits,
        0
      );

      assert.equal(
        afterFirst.buildGroupPlanCalls,
        2
      );

      const second =
        getCompiledGroupPlan(
          runtime,
          "a"
        );

      const afterSecond =
        getUserFilterRuntimeTestMetrics();

      assert.equal(first, second);
      assert.equal(
        afterSecond.groupPlanCacheMisses,
        1
      );
      assert.equal(
        afterSecond.groupPlanCacheHits,
        1
      );
      assert.equal(
        afterSecond.buildGroupPlanCalls,
        2
      );
    } finally {
      disableUserFilterRuntimeTestMetrics();
    }
  }
);


test(
  "unrelated group reuses all-group plan without cache allocation",
  () => {
    resetUserFilterRuntimeTestMetrics();

    try {
      const runtime =
        compileUserFilterDocument({
          filters: [
            advancedFilter({
              id: "all",
            }),
            advancedFilter({
              id: "specific",
              groups: ["a"],
            }),
          ],
        });

      const plan =
        getCompiledGroupPlan(
          runtime,
          "other"
        );

      const metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        plan,
        runtime.allGroupsPlan
      );

      assert.equal(
        runtime.groupPlanCache.size,
        0
      );

      assert.equal(
        metrics.groupPlanCacheHits,
        0
      );

      assert.equal(
        metrics.groupPlanCacheMisses,
        0
      );

      assert.equal(
        metrics.buildGroupPlanCalls,
        1
      );
    } finally {
      disableUserFilterRuntimeTestMetrics();
    }
  }
);
