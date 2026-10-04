import test from "node:test";
import assert from "node:assert/strict";

import {
  normalizeFilterText,
  compileKeywordPattern,
  compileCommaSeparatedKeywords,
  findFirstKeywordMatch,
  findFirstKeywordOccurrence,
  findOrderedKeywordPair,
} from "./user-filter-matcher.js";


function matches(
  pattern,
  message
) {
  const matcher =
    compileKeywordPattern(
      pattern
    );

  assert.ok(
    matcher,
    `Matcher must compile: ${pattern}`
  );

  return matcher.matches(
    normalizeFilterText(
      message
    )
  );
}


test(
  "normalize Vietnamese text",
  () => {
    assert.equal(
      normalizeFilterText(
        "  QUẬN   1 Đi NỘI BÀI "
      ),
      "quan 1 di noi bai"
    );
  }
);


test(
  "plain keyword matches whole word",
  () => {
    assert.equal(
      matches(
        "tân",
        "đi tân ngay"
      ),
      true
    );

    assert.equal(
      matches(
        "tân",
        "đi tặng đồ"
      ),
      false
    );
  }
);


test(
  "plain phrase ignores accents and case",
  () => {
    assert.equal(
      matches(
        "nội bài",
        "Đi NỘI BÀI ngay"
      ),
      true
    );
  }
);


test(
  "numeric keyword matches k suffix",
  () => {
    assert.equal(
      matches(
        "500",
        "giá 500k"
      ),
      true
    );

    assert.equal(
      matches(
        "500",
        "giá 1500"
      ),
      false
    );
  }
);


test(
  "wildcard performs substring match",
  () => {
    assert.equal(
      matches(
        "*500*",
        "giá 1500k"
      ),
      true
    );
  }
);


test(
  "single wildcard OR group",
  () => {
    assert.equal(
      matches(
        "*(nội bài|nb)*",
        "q1 đi NB"
      ),
      true
    );

    assert.equal(
      matches(
        "*(nội bài|nb)*",
        "q1 đi thủ đức"
      ),
      false
    );
  }
);


test(
  "ordered wildcard groups preserve direction",
  () => {
    const pattern =
      "*(q1|quận 1)*(nội bài|nb)*";

    assert.equal(
      matches(
        pattern,
        "Q1 đi Nội Bài"
      ),
      true
    );

    assert.equal(
      matches(
        pattern,
        "Nội Bài về Q1"
      ),
      false
    );
  }
);


test(
  "comma separated keywords use OR",
  () => {
    const compiled =
      compileCommaSeparatedKeywords(
        "hà nội, hn, nội bài"
      );

    const match =
      findFirstKeywordMatch(
        compiled,
        normalizeFilterText(
          "cần xe HN ngay"
        )
      );

    assert.ok(
      match
    );

    assert.equal(
      match.source,
      "hn"
    );
  }
);


test(
  "invalid one-sided wildcard is rejected",
  () => {
    assert.equal(
      compileKeywordPattern(
        "noi bai*"
      ),
      null
    );

    assert.equal(
      compileKeywordPattern(
        "*noi bai"
      ),
      null
    );
  }
);

test(
  "ordered wildcard supports multiple groups",
  () => {
    const pattern =
      "*(q1|quận 1)*(nội bài|nb)*(500|600)*";

    assert.equal(
      matches(
        pattern,
        "Q1 đi Nội Bài giá 500k"
      ),
      true
    );

    assert.equal(
      matches(
        pattern,
        "500k Q1 đi Nội Bài"
      ),
      false
    );
  }
);

test(
  "keyword occurrence returns position",
  () => {
    const matchers =
      compileCommaSeparatedKeywords(
        "q1, quận 1"
      );


    const result =
      findFirstKeywordOccurrence(
        matchers,
        normalizeFilterText(
          "đón Q1 đi Nội Bài"
        )
      );


    assert.ok(
      result
    );


    assert.equal(
      result.matcher.source,
      "q1"
    );


    assert.equal(
      result.index >= 0,
      true
    );


    assert.equal(
      result.end >
        result.index,
      true
    );
  }
);


test(
  "ordered route requires pickup before dropoff",
  () => {
    const pickup =
      compileCommaSeparatedKeywords(
        "q1, quận 1"
      );


    const dropoff =
      compileCommaSeparatedKeywords(
        "nội bài, nb"
      );


    assert.ok(
      findOrderedKeywordPair(
        pickup,
        dropoff,
        normalizeFilterText(
          "Q1 đi Nội Bài"
        )
      )
    );


    assert.equal(
      findOrderedKeywordPair(
        pickup,
        dropoff,
        normalizeFilterText(
          "Nội Bài về Q1"
        )
      ),
      null
    );
  }
);


test(
  "ordered route can use a later valid pickup occurrence",
  () => {
    const pickup =
      compileCommaSeparatedKeywords(
        "q1"
      );


    const dropoff =
      compileCommaSeparatedKeywords(
        "nội bài"
      );


    const result =
      findOrderedKeywordPair(
        pickup,
        dropoff,
        normalizeFilterText(
          "Nội Bài về Q1 rồi Q1 đi Nội Bài"
        )
      );


    assert.ok(
      result
    );


    assert.equal(
      result.pickup.index <
        result.dropoff.index,
      true
    );
  }
);