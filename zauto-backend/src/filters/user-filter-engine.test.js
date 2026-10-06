import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  fileURLToPath,
} from "node:url";

import {
  createUserFilterV2,
  deleteUserFilterV2,
  evaluateUserMessage,
  previewUserFilterV2,
  reorderUserFiltersV2,
  saveUserFilterV2,
  updateUserFilterV2,
} from "./user-filter-engine.js";

import {
  disableUserFilterRuntimeTestMetrics,
  getUserFilterRuntimeTestMetrics,
  invalidateUserFilterRuntime,
  resetUserFilterRuntimeTestMetrics,
} from "./user-filter-runtime.js";


function advancedFilter({
  groups = [],
  enabled = true,
  show = [],
  hide = [],
} = {}) {
  return {
    id: "preview-advanced",
    name: "Preview advanced",
    mode: "advanced",
    enabled,
    groupIds: groups,
    basic: {},
    advanced: {
      showKeywords: show,
      hideKeywords: hide,
    },
  };
}


const __filename =
  fileURLToPath(
    import.meta.url
  );

const __dirname =
  path.dirname(
    __filename
  );


function cleanupUserFilterTestData(
  userId
) {
  invalidateUserFilterRuntime(
    userId
  );

  fs.rmSync(
    path.resolve(
      __dirname,
      "../../data/user-data",
      String(userId)
    ),
    {
      recursive: true,
      force: true,
    }
  );
}


function basicFilter({
  groups = [],
  enabled = true,
  pickup = "",
  dropoff = "",
  include = "",
  exclude = "",
  price = null,
  time = "",
} = {}) {
  return {
    id: "preview-basic",
    name: "Preview basic",
    mode: "basic",
    enabled,
    groupIds: groups,
    basic: {
      pickup,
      dropoff,
      acceptBothDirections: false,
      includeKeywords: include,
      excludeKeywords: exclude,
      minimumPrice: price,
      timeRules: time,
    },
    advanced: {
      showKeywords: [],
      hideKeywords: [],
    },
  };
}


test(
  "preview ignores saved group scope and evaluates filter logic itself",
  () => {
    const result =
      previewUserFilterV2(
        advancedFilter({
          groups: ["group-a"],
          show: ["vip"],
        }),
        "VIP Bình Thạnh đi Thủ Đức",
        {
          groupId: "group-b",
        }
      );

    assert.equal(result.matched, true);
    assert.equal(result.filterId, "preview-advanced");
  }
);


test(
  "preview evaluates disabled draft as enabled",
  () => {
    const result =
      previewUserFilterV2(
        advancedFilter({
          enabled: false,
          show: ["vip"],
        }),
        "VIP"
      );

    assert.equal(result.matched, true);
    assert.equal(result.filterId, "preview-advanced");
  }
);


test(
  "preview uses full basic route price and time evaluation",
  () => {
    const result =
      previewUserFilterV2(
        basicFilter({
          groups: ["airport-group"],
          pickup: "q1",
          dropoff: "nội bài",
          include: "4c",
          exclude: "ghép",
          price: 500,
          time: "sáng",
        }),
        "sáng mai 7h30 Q1 đi Nội Bài xe 4c giá 650k",
        {
          groupId: "other-group",
        }
      );

    assert.equal(result.matched, true);
    assert.equal(result.filterId, "preview-basic");
  }
);



test(
  "preview rejects one-sided wildcard instead of silently dropping it",
  () => {
    assert.throws(
      () => {
        previewUserFilterV2(
          advancedFilter({
            show: ["vip*"],
          }),
          "VIP"
        );
      },
      /Dau \* phai nam o ca hai dau/
    );
  }
);


test(
  "preview rejects negative minimum price",
  () => {
    assert.throws(
      () => {
        previewUserFilterV2(
          basicFilter({
            price: -1,
          }),
          "cuốc giá 500k"
        );
      },
      /Gia toi thieu/
    );
  }
);


test(
  "preview rejects blank filter name",
  () => {
    const filter =
      advancedFilter({
        show: ["vip"],
      });

    filter.name = "   ";

    assert.throws(
      () => {
        previewUserFilterV2(
          filter,
          "VIP"
        );
      },
      /Ten bo loc/
    );
  }
);



test(
  "preview returns detailed price rejection",
  () => {
    const result =
      previewUserFilterV2(
        basicFilter({
          price: 500,
        }),
        "cuốc giá 450k"
      );

    assert.equal(
      result.matched,
      false
    );

    assert.equal(
      result.reason,
      "basic_price_below_minimum"
    );

    assert.equal(
      result.details.messagePrice,
      450
    );

    assert.equal(
      result.details.minimumPrice,
      500
    );
  }
);


test(
  "preview returns hidden keyword details",
  () => {
    const result =
      previewUserFilterV2(
        advancedFilter({
          show: ["vip"],
          hide: ["ghép"],
        }),
        "VIP ghép khách"
      );

    assert.equal(
      result.matched,
      false
    );

    assert.equal(
      result.reason,
      "advanced_hidden_keyword"
    );

    assert.equal(
      result.keyword,
      "ghép"
    );
  }
);


test(
  "preview returns expected pickup values",
  () => {
    const result =
      previewUserFilterV2(
        basicFilter({
          pickup: "q1, quận 1",
        }),
        "Bình Thạnh đi Nội Bài"
      );

    assert.equal(
      result.matched,
      false
    );

    assert.equal(
      result.reason,
      "basic_pickup_no_match"
    );

    assert.deepEqual(
      result.details.expected,
      [
        "q1",
        "quận 1",
      ]
    );
  }
);



test(
  "basic preview returns all per-condition checks when matched",
  () => {
    const result =
      previewUserFilterV2(
        basicFilter({
          pickup: "q1",
          dropoff: "nội bài",
          include: "4c",
          exclude: "ghép",
          price: 500,
          time: "sáng",
        }),
        "sáng mai 7h Q1 đi Nội Bài xe 4c giá 650k"
      );

    assert.equal(
      result.matched,
      true
    );

    assert.equal(
      result.checks.length,
      7
    );

    const statuses =
      Object.fromEntries(
        result.checks.map(
          item => [
            item.key,
            item.status,
          ]
        )
      );

    assert.equal(
      statuses.exclude,
      "pass"
    );

    assert.equal(
      statuses.pickup,
      "pass"
    );

    assert.equal(
      statuses.dropoff,
      "pass"
    );

    assert.equal(
      statuses.direction,
      "pass"
    );

    assert.equal(
      statuses.include,
      "pass"
    );

    assert.equal(
      statuses.price,
      "pass"
    );

    assert.equal(
      statuses.time,
      "pass"
    );
  }
);


test(
  "basic preview diagnostics show multiple failures at once",
  () => {
    const result =
      previewUserFilterV2(
        basicFilter({
          pickup: "q1",
          dropoff: "nội bài",
          include: "4c",
          exclude: "ghép",
          price: 500,
          time: "sáng",
        }),
        "tối nay Bình Thạnh đi Thủ Đức xe 7c giá 450k ghép khách"
      );

    assert.equal(
      result.matched,
      false
    );

    const checks =
      Object.fromEntries(
        result.checks.map(
          item => [
            item.key,
            item,
          ]
        )
      );

    assert.equal(
      checks.exclude.status,
      "fail"
    );

    assert.equal(
      checks.exclude.details.keyword,
      "ghép"
    );

    assert.equal(
      checks.pickup.status,
      "fail"
    );

    assert.equal(
      checks.dropoff.status,
      "fail"
    );

    assert.equal(
      checks.direction.status,
      "fail"
    );

    assert.equal(
      checks.include.status,
      "fail"
    );

    assert.equal(
      checks.price.status,
      "fail"
    );

    assert.equal(
      checks.price.details.messagePrice,
      450
    );

    assert.equal(
      checks.time.status,
      "fail"
    );
  }
);


test(
  "basic preview marks unused conditions as skipped",
  () => {
    const result =
      previewUserFilterV2(
        basicFilter({
          include: "vip",
        }),
        "VIP"
      );

    const statuses =
      Object.fromEntries(
        result.checks.map(
          item => [
            item.key,
            item.status,
          ]
        )
      );

    assert.equal(
      statuses.exclude,
      "skipped"
    );

    assert.equal(
      statuses.pickup,
      "skipped"
    );

    assert.equal(
      statuses.dropoff,
      "skipped"
    );

    assert.equal(
      statuses.direction,
      "skipped"
    );

    assert.equal(
      statuses.include,
      "pass"
    );

    assert.equal(
      statuses.price,
      "skipped"
    );

    assert.equal(
      statuses.time,
      "skipped"
    );
  }
);



test(
  "advanced preview shows hide overriding show",
  () => {
    const result =
      previewUserFilterV2(
        advancedFilter({
          show: ["vip"],
          hide: ["ghép"],
        }),
        "VIP ghép khách"
      );

    assert.equal(
      result.matched,
      false
    );

    assert.equal(
      result.checks.length,
      2
    );

    const checks =
      Object.fromEntries(
        result.checks.map(
          item => [
            item.key,
            item,
          ]
        )
      );

    assert.equal(
      checks.advanced_hide.status,
      "fail"
    );

    assert.equal(
      checks.advanced_hide.details.matched,
      "ghép"
    );

    assert.equal(
      checks.advanced_show.status,
      "pass"
    );

    assert.equal(
      checks.advanced_show.details.matched,
      "vip"
    );

    assert.equal(
      checks.advanced_show.details.overriddenByHide,
      true
    );
  }
);


test(
  "advanced preview passes when show matches and hide does not",
  () => {
    const result =
      previewUserFilterV2(
        advancedFilter({
          show: ["vip"],
          hide: ["ghép"],
        }),
        "VIP khách riêng"
      );

    assert.equal(
      result.matched,
      true
    );

    const checks =
      Object.fromEntries(
        result.checks.map(
          item => [
            item.key,
            item,
          ]
        )
      );

    assert.equal(
      checks.advanced_hide.status,
      "pass"
    );

    assert.equal(
      checks.advanced_show.status,
      "pass"
    );

    assert.equal(
      checks.advanced_show.details.overriddenByHide,
      false
    );
  }
);


test(
  "advanced preview marks empty show as catch all",
  () => {
    const result =
      previewUserFilterV2(
        advancedFilter({
          show: [],
          hide: ["ghép"],
        }),
        "cuốc thường"
      );

    assert.equal(
      result.matched,
      true
    );

    const checks =
      Object.fromEntries(
        result.checks.map(
          item => [
            item.key,
            item,
          ]
        )
      );

    assert.equal(
      checks.advanced_hide.status,
      "pass"
    );

    assert.equal(
      checks.advanced_show.status,
      "skipped"
    );

    assert.equal(
      checks.advanced_show.details.catchAll,
      true
    );
  }
);


test(
  "advanced preview catch all is still blocked by hide",
  () => {
    const result =
      previewUserFilterV2(
        advancedFilter({
          show: [],
          hide: ["ghép"],
        }),
        "ghép khách"
      );

    assert.equal(
      result.matched,
      false
    );

    const checks =
      Object.fromEntries(
        result.checks.map(
          item => [
            item.key,
            item,
          ]
        )
      );

    assert.equal(
      checks.advanced_hide.status,
      "fail"
    );

    assert.equal(
      checks.advanced_show.status,
      "skipped"
    );

    assert.equal(
      checks.advanced_show.details.overriddenByHide,
      true
    );
  }
);



// ========================================
// MUTATION -> WARM RUNTIME LIFECYCLE
// ========================================

test(
  "filter mutations warm runtime before the next message",
  () => {
    const userId =
      `test-filter-runtime-${process.pid}`;

    cleanupUserFilterTestData(
      userId
    );

    resetUserFilterRuntimeTestMetrics();

    try {
      const first =
        saveUserFilterV2(
          userId,
          advancedFilter({
            show: ["vip"],
          })
        );

      let metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        metrics.compileDocumentCalls,
        1
      );

      const afterCreate =
        evaluateUserMessage(
          userId,
          "VIP"
        );

      assert.equal(
        afterCreate.matched,
        true
      );

      metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        metrics.compileDocumentCalls,
        1
      );


      saveUserFilterV2(
        userId,
        {
          ...first,
          enabled: false,
        }
      );

      metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        metrics.compileDocumentCalls,
        2
      );

      const afterToggle =
        evaluateUserMessage(
          userId,
          "VIP"
        );

      assert.equal(
        afterToggle.reason,
        "no_applicable_filters"
      );

      metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        metrics.compileDocumentCalls,
        2
      );


      const second =
        saveUserFilterV2(
          userId,
          {
            ...advancedFilter({
              show: ["airport"],
            }),
            id: undefined,
            name: "second",
          }
        );

      metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        metrics.compileDocumentCalls,
        3
      );


      reorderUserFiltersV2(
        userId,
        [
          second.id,
          first.id,
        ]
      );

      metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        metrics.compileDocumentCalls,
        4
      );

      evaluateUserMessage(
        userId,
        "airport"
      );

      metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        metrics.compileDocumentCalls,
        4
      );


      deleteUserFilterV2(
        userId,
        second.id
      );

      metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        metrics.compileDocumentCalls,
        5
      );

      evaluateUserMessage(
        userId,
        "airport"
      );

      metrics =
        getUserFilterRuntimeTestMetrics();

      assert.equal(
        metrics.compileDocumentCalls,
        5
      );
    } finally {
      disableUserFilterRuntimeTestMetrics();

      cleanupUserFilterTestData(
        userId
      );
    }
  }
);



test(
  "create ignores client supplied id and never overwrites existing filter",
  () => {
    const userId =
      `test-filter-create-semantics-${process.pid}`;

    cleanupUserFilterTestData(
      userId
    );


    try {
      const first =
        createUserFilterV2(
          userId,
          {
            ...advancedFilter({
              show: ["vip"],
            }),
            id: "client-id",
            name: "first",
          }
        );


      const second =
        createUserFilterV2(
          userId,
          {
            ...advancedFilter({
              show: ["airport"],
            }),
            id: first.id,
            name: "second",
          }
        );


      assert.notEqual(
        first.id,
        second.id
      );


      assert.equal(
        evaluateUserMessage(
          userId,
          "VIP"
        ).matched,
        true
      );


      assert.equal(
        evaluateUserMessage(
          userId,
          "airport"
        ).matched,
        true
      );

    } finally {
      cleanupUserFilterTestData(
        userId
      );
    }
  }
);


test(
  "update rejects stale or missing filter id",
  () => {
    const userId =
      `test-filter-update-semantics-${process.pid}`;

    cleanupUserFilterTestData(
      userId
    );


    try {
      assert.throws(
        () => {
          updateUserFilterV2(
            userId,
            "missing-filter",
            advancedFilter({
              show: ["vip"],
            })
          );
        },
        error =>
          error?.code ===
            "FILTER_NOT_FOUND"
      );

    } finally {
      cleanupUserFilterTestData(
        userId
      );
    }
  }
);


test(
  "reorder changes realtime short circuit priority",
  () => {
    const userId =
      `test-filter-priority-${process.pid}`;

    cleanupUserFilterTestData(
      userId
    );


    try {
      const first =
        createUserFilterV2(
          userId,
          {
            ...advancedFilter({
              show: ["vip"],
            }),
            name: "first",
          }
        );


      const second =
        createUserFilterV2(
          userId,
          {
            ...advancedFilter({
              show: ["vip"],
            }),
            name: "second",
          }
        );


      const before =
        evaluateUserMessage(
          userId,
          "VIP"
        );


      assert.equal(
        before.filterId,
        first.id
      );


      reorderUserFiltersV2(
        userId,
        [
          second.id,
          first.id,
        ]
      );


      const after =
        evaluateUserMessage(
          userId,
          "VIP"
        );


      assert.equal(
        after.filterId,
        second.id
      );

    } finally {
      cleanupUserFilterTestData(
        userId
      );
    }
  }
);


test(
  "disabling higher priority filter allows next matching filter",
  () => {
    const userId =
      `test-filter-disable-priority-${process.pid}`;

    cleanupUserFilterTestData(
      userId
    );


    try {
      const first =
        createUserFilterV2(
          userId,
          {
            ...advancedFilter({
              show: ["vip"],
            }),
            name: "first",
          }
        );


      const second =
        createUserFilterV2(
          userId,
          {
            ...advancedFilter({
              show: ["vip"],
            }),
            name: "second",
          }
        );


      updateUserFilterV2(
        userId,
        first.id,
        {
          ...first,
          enabled: false,
        }
      );


      const result =
        evaluateUserMessage(
          userId,
          "VIP"
        );


      assert.equal(
        result.filterId,
        second.id
      );

    } finally {
      cleanupUserFilterTestData(
        userId
      );
    }
  }
);



// ========================================
// PREVIEW <-> REALTIME DECISION PARITY
//
// Preview bo qua group scope/enabled co chu dich,
// nhung loi evaluator cho cung filter + message
// phai cho cung quyet dinh matched.
// ========================================

const parityCases = [
  {
    name:
      "basic route accept",

    filter:
      basicFilter({
        groups: ["g"],
        pickup: "q1",
        dropoff: "nội bài",
      }),

    message:
      "Q1 đi Nội Bài",

    expected:
      true,
  },
  {
    name:
      "basic reverse route reject",

    filter:
      basicFilter({
        groups: ["g"],
        pickup: "q1",
        dropoff: "nội bài",
      }),

    message:
      "Nội Bài về Q1",

    expected:
      false,
  },
  {
    name:
      "basic round trip reject",

    filter:
      basicFilter({
        groups: ["g"],
        pickup: "q1",
        dropoff: "nội bài",
      }),

    message:
      "Q1 đi Nội Bài rồi về lại Q1",

    expected:
      false,
  },
  {
    name:
      "basic include accept",

    filter:
      basicFilter({
        groups: ["g"],
        include: "4c, vip",
      }),

    message:
      "cần xe VIP",

    expected:
      true,
  },
  {
    name:
      "basic exclude reject",

    filter:
      basicFilter({
        groups: ["g"],
        include: "vip",
        exclude: "ghép",
      }),

    message:
      "VIP ghép khách",

    expected:
      false,
  },
  {
    name:
      "basic price accept",

    filter:
      basicFilter({
        groups: ["g"],
        price: 500,
      }),

    message:
      "cuốc giá 650k",

    expected:
      true,
  },
  {
    name:
      "basic price reject",

    filter:
      basicFilter({
        groups: ["g"],
        price: 500,
      }),

    message:
      "cuốc giá 450k",

    expected:
      false,
  },
  {
    name:
      "basic time accept",

    filter:
      basicFilter({
        groups: ["g"],
        time: "sáng",
      }),

    message:
      "sáng mai 7h30 đi sân bay",

    expected:
      true,
  },
  {
    name:
      "advanced show accept",

    filter:
      advancedFilter({
        groups: ["g"],
        show: ["vip"],
        hide: ["ghép"],
      }),

    message:
      "VIP khách riêng",

    expected:
      true,
  },
  {
    name:
      "advanced hide reject",

    filter:
      advancedFilter({
        groups: ["g"],
        show: ["vip"],
        hide: ["ghép"],
      }),

    message:
      "VIP ghép khách",

    expected:
      false,
  },
  {
    name:
      "advanced catch all accept",

    filter:
      advancedFilter({
        groups: ["g"],
        show: [],
        hide: ["ghép"],
      }),

    message:
      "cuốc thường",

    expected:
      true,
  },
];


for (
  const [
    index,
    parityCase,
  ]
  of parityCases.entries()
) {
  test(
    `preview realtime parity: ${parityCase.name}`,
    () => {
      const userId =
        `test-filter-parity-${process.pid}-${index}`;

      cleanupUserFilterTestData(
        userId
      );


      try {
        const input = {
          ...parityCase.filter,

          name:
            `parity-${index}`,
        };


        createUserFilterV2(
          userId,
          input
        );


        const preview =
          previewUserFilterV2(
            input,
            parityCase.message,
            {
              groupId:
                "g",
            }
          );


        const realtime =
          evaluateUserMessage(
            userId,
            parityCase.message,
            {
              groupId:
                "g",
            }
          );


        assert.equal(
          preview.matched,
          parityCase.expected
        );


        assert.equal(
          realtime.matched,
          parityCase.expected
        );


        assert.equal(
          preview.matched,
          realtime.matched
        );


        if (
          parityCase.expected ===
            true
        ) {
          assert.equal(
            preview.mode,
            realtime.mode
          );

          assert.equal(
            preview.reason,
            realtime.reason
          );
        }

      } finally {
        cleanupUserFilterTestData(
          userId
        );
      }
    }
  );
}



// ========================================
// HOT PATH CACHE STRESS
// ========================================

test(
  "hundreds of realtime messages reuse warmed runtime without recompiling",
  () => {
    const userId =
      `test-filter-hot-path-${process.pid}`;

    cleanupUserFilterTestData(
      userId
    );

    resetUserFilterRuntimeTestMetrics();


    try {
      createUserFilterV2(
        userId,
        {
          ...advancedFilter({
            groups: ["group-a"],
            show: ["vip"],
          }),

          name:
            "group-a-vip",
        }
      );


      let metrics =
        getUserFilterRuntimeTestMetrics();


      assert.equal(
        metrics.compileDocumentCalls,
        1
      );


      // Lan dau group-a tao group plan cu the.
      const first =
        evaluateUserMessage(
          userId,
          "VIP",
          {
            groupId:
              "group-a",
          }
        );


      assert.equal(
        first.matched,
        true
      );


      metrics =
        getUserFilterRuntimeTestMetrics();


      assert.equal(
        metrics.compileDocumentCalls,
        1
      );

      assert.equal(
        metrics.groupPlanCacheMisses,
        1
      );


      for (
        let index = 0;
        index < 500;
        index += 1
      ) {
        const result =
          evaluateUserMessage(
            userId,
            index % 2 === 0
              ? "VIP"
              : "cuốc thường",
            {
              groupId:
                "group-a",
            }
          );


        assert.equal(
          typeof result.matched,
          "boolean"
        );
      }


      metrics =
        getUserFilterRuntimeTestMetrics();


      assert.equal(
        metrics.compileDocumentCalls,
        1
      );

      assert.equal(
        metrics.groupPlanCacheMisses,
        1
      );

      assert.equal(
        metrics.groupPlanCacheHits,
        500
      );

    } finally {
      disableUserFilterRuntimeTestMetrics();

      cleanupUserFilterTestData(
        userId
      );
    }
  }
);
