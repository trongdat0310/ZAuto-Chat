import test from "node:test";
import assert from "node:assert/strict";

import {
  normalizeFilterText,
} from "./user-filter-matcher.js";

import {
  extractMessagePriceThousands,
} from "./user-filter-price.js";


function price(
  text
) {
  return extractMessagePriceThousands(
    normalizeFilterText(
      text
    )
  );
}


test(
  "parses bare thousand amount",
  () => {
    assert.equal(
      price(
        "cuốc này 300"
      ),
      300
    );
  }
);


test(
  "parses k amount",
  () => {
    assert.equal(
      price(
        "giá 500k"
      ),
      500
    );
  }
);


test(
  "parses nghin amount",
  () => {
    assert.equal(
      price(
        "giá 500 nghìn"
      ),
      500
    );
  }
);


test(
  "parses formatted VND amount",
  () => {
    assert.equal(
      price(
        "giá 500.000"
      ),
      500
    );


    assert.equal(
      price(
        "giá 1.200.000"
      ),
      1200
    );
  }
);


test(
  "parses million shorthand",
  () => {
    assert.equal(
      price(
        "giá 1tr"
      ),
      1000
    );


    assert.equal(
      price(
        "giá 1tr2"
      ),
      1200
    );


    assert.equal(
      price(
        "giá 1tr200"
      ),
      1200
    );


    assert.equal(
      price(
        "giá 2tr5"
      ),
      2500
    );
  }
);


test(
  "parses decimal million",
  () => {
    assert.equal(
      price(
        "giá 1.2tr"
      ),
      1200
    );


    assert.equal(
      price(
        "giá 1,5 triệu"
      ),
      1500
    );
  }
);


test(
  "chooses highest price candidate",
  () => {
    assert.equal(
      price(
        "giá khoảng 500k tới 650k"
      ),
      650
    );
  }
);


test(
  "does not confuse common trip metadata with price",
  () => {
    assert.equal(
      price(
        "22h30 cần xe 4c Q1 đi Nội Bài gấp 15p"
      ),
      null
    );
  }
);


test(
  "does not treat phone number as price",
  () => {
    assert.equal(
      price(
        "liên hệ 0912345678"
      ),
      null
    );
  }
);


test(
  "does not confuse address route distance or year with bare price",
  () => {
    assert.equal(
      price(
        "đón khách số 300 phố huế"
      ),
      null
    );

    assert.equal(
      price(
        "đón tại ngõ 125 thái hà"
      ),
      null
    );

    assert.equal(
      price(
        "đi cao tốc khoảng 120 km"
      ),
      null
    );

    assert.equal(
      price(
        "chuyến 350 đón lúc 8h"
      ),
      null
    );

    assert.equal(
      price(
        "lịch chạy năm 2026"
      ),
      null
    );
  }
);


test(
  "bare trip amount remains supported when no non-price context exists",
  () => {
    assert.equal(
      price(
        "cuốc này 300"
      ),
      300
    );

    assert.equal(
      price(
        "300 đi nội bài"
      ),
      300
    );

    assert.equal(
      price(
        "giá 450"
      ),
      450
    );
  }
);
