import test from "node:test";
import assert from "node:assert/strict";

import {
  normalizeFilterText,
} from "./user-filter-matcher.js";

import {
  compileTimeRules,
  extractMessageTemporalMentions,
  matchesCompiledTimeRules,
} from "./user-filter-time.js";


function matches(
  rule,
  message
) {
  const normalized =
    normalizeFilterText(
      message
    );

  return matchesCompiledTimeRules(
    compileTimeRules(
      rule
    ),
    extractMessageTemporalMentions(
      normalized
    ),
    normalized
  );
}


test(
  "matches Vietnamese daypart",
  () => {
    assert.equal(
      matches(
        "sáng",
        "cuốc sáng mai 7h30"
      ),
      true
    );

    assert.equal(
      matches(
        "sáng",
        "cuốc tối nay"
      ),
      false
    );
  }
);


test(
  "matches overlapping explicit clock range",
  () => {
    assert.equal(
      matches(
        "6h-8h",
        "đón khách lúc 7h15"
      ),
      true
    );

    assert.equal(
      matches(
        "6h-8h",
        "đón khách lúc 9h"
      ),
      false
    );
  }
);


test(
  "supports after and before clock rules",
  () => {
    assert.equal(
      matches(
        "sau 22h",
        "cuốc 23h10"
      ),
      true
    );

    assert.equal(
      matches(
        "trước 6h",
        "cuốc 5h30"
      ),
      true
    );

    assert.equal(
      matches(
        "trước 6h",
        "cuốc 7h"
      ),
      false
    );
  }
);


test(
  "matches urgent minute range",
  () => {
    assert.equal(
      matches(
        "0-30p",
        "gấp 15p"
      ),
      true
    );

    assert.equal(
      matches(
        "15p",
        "gấp 20 phút"
      ),
      false
    );
  }
);


test(
  "does not confuse 0-15 minute shorthand with clock range",
  () => {
    assert.equal(
      matches(
        "sáng",
        "gấp 0-15"
      ),
      false
    );

    assert.equal(
      matches(
        "0-15p",
        "gấp 0-15"
      ),
      true
    );
  }
);


test(
  "free text time rule falls back to keyword matching",
  () => {
    assert.equal(
      matches(
        "csct",
        "cần xe csct"
      ),
      true
    );

    assert.equal(
      matches(
        "csct",
        "cần xe bình thường"
      ),
      false
    );
  }
);


test(
  "comma separated time rules are OR",
  () => {
    assert.equal(
      matches(
        "sáng, 0-30p, csct",
        "gấp 10 phút"
      ),
      true
    );

    assert.equal(
      matches(
        "sáng, 0-30p, csct",
        "cuốc 14h"
      ),
      false
    );
  }
);



test(
  "daypart boundaries do not overlap",
  () => {
    const morning =
      compileTimeRules("sáng");

    const noon =
      compileTimeRules("trưa");

    const afternoon =
      compileTimeRules("chiều");

    const evening =
      compileTimeRules("tối");

    const night =
      compileTimeRules("đêm");

    const at1100 =
      extractMessageTemporalMentions(
        normalizeFilterText("11h")
      );

    const at1300 =
      extractMessageTemporalMentions(
        normalizeFilterText("13h")
      );

    const at1800 =
      extractMessageTemporalMentions(
        normalizeFilterText("18h")
      );

    const at2200 =
      extractMessageTemporalMentions(
        normalizeFilterText("22h")
      );


    assert.equal(
      matchesCompiledTimeRules(
        morning,
        at1100,
        normalizeFilterText("11h")
      ),
      false
    );

    assert.equal(
      matchesCompiledTimeRules(
        noon,
        at1100,
        normalizeFilterText("11h")
      ),
      true
    );


    assert.equal(
      matchesCompiledTimeRules(
        noon,
        at1300,
        normalizeFilterText("13h")
      ),
      false
    );

    assert.equal(
      matchesCompiledTimeRules(
        afternoon,
        at1300,
        normalizeFilterText("13h")
      ),
      true
    );


    assert.equal(
      matchesCompiledTimeRules(
        afternoon,
        at1800,
        normalizeFilterText("18h")
      ),
      false
    );

    assert.equal(
      matchesCompiledTimeRules(
        evening,
        at1800,
        normalizeFilterText("18h")
      ),
      true
    );


    assert.equal(
      matchesCompiledTimeRules(
        evening,
        at2200,
        normalizeFilterText("22h")
      ),
      false
    );

    assert.equal(
      matchesCompiledTimeRules(
        night,
        at2200,
        normalizeFilterText("22h")
      ),
      true
    );
  }
);
