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