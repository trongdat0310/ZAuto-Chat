import test from "node:test";
import assert from "node:assert/strict";

import {
  previewUserFilterV2,
} from "./user-filter-engine.js";


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
