// ========================================
// PRICE PARSER
//
// Don vi tra ve:
// NGHIN DONG
//
// 500k      -> 500
// 500 nghin -> 500
// 1tr2      -> 1200
// 1.2tr     -> 1200
// 500.000   -> 500
//
// Parser chi chay LAZY khi Basic filter
// that su co minimumPrice.
// ========================================


// ========================================
// SPAN HELPERS
// ========================================

function overlaps(
  start,
  end,
  spans
) {
  return spans.some(
    span =>
      start < span.end &&
      end > span.start
  );
}


function addCandidate(
  candidates,
  spans,
  value,
  start,
  end
) {
  if (
    !Number.isFinite(value) ||
    value < 0
  ) {
    return;
  }


  candidates.push(
    value
  );


  spans.push({
    start,
    end,
  });
}


// ========================================
// MILLION DECIMAL
//
// 1.2tr
// 1,5tr
// 1.25 trieu
// ========================================

function collectDecimalMillions(
  text,
  candidates,
  spans
) {
  const pattern =
    /\b(\d+)[.,](\d+)\s*(tr|trieu)\b/g;


  let match;


  while (
    (
      match =
        pattern.exec(text)
    ) !== null
  ) {
    const whole =
      Number(match[1]);

    const fractionText =
      match[2];


    if (
      !Number.isFinite(whole)
    ) {
      continue;
    }


    const fraction =
      Number(
        `0.${fractionText}`
      );


    if (
      !Number.isFinite(fraction)
    ) {
      continue;
    }


    addCandidate(
      candidates,
      spans,
      Math.round(
        (
          whole +
          fraction
        ) *
        1000
      ),
      match.index,
      pattern.lastIndex
    );
  }
}


// ========================================
// VIETNAMESE MILLION SHORTHAND
//
// 1tr     -> 1000
// 1tr2    -> 1200
// 1tr25   -> 1250
// 1tr200  -> 1200
// ========================================

function collectMillionShorthand(
  text,
  candidates,
  spans
) {
  const pattern =
    /\b(\d+)\s*(tr|trieu)(\d{1,3})?\b/g;


  let match;


  while (
    (
      match =
        pattern.exec(text)
    ) !== null
  ) {
    if (
      overlaps(
        match.index,
        pattern.lastIndex,
        spans
      )
    ) {
      continue;
    }


    const millions =
      Number(match[1]);


    if (
      !Number.isFinite(
        millions
      )
    ) {
      continue;
    }


    const suffix =
      match[3] ?? "";


    let extra =
      0;


    if (
      suffix.length === 1
    ) {
      extra =
        Number(suffix) *
        100;

    } else if (
      suffix.length === 2
    ) {
      extra =
        Number(suffix) *
        10;

    } else if (
      suffix.length === 3
    ) {
      extra =
        Number(suffix);
    }


    addCandidate(
      candidates,
      spans,
      (
        millions *
        1000
      ) +
        extra,
      match.index,
      pattern.lastIndex
    );
  }
}


// ========================================
// THOUSAND UNIT
//
// 500k
// 500 k
// 500 nghin
// ========================================

function collectThousands(
  text,
  candidates,
  spans
) {
  const pattern =
    /\b(\d+(?:[.,]\d+)?)\s*(k|nghin)\b/g;


  let match;


  while (
    (
      match =
        pattern.exec(text)
    ) !== null
  ) {
    if (
      overlaps(
        match.index,
        pattern.lastIndex,
        spans
      )
    ) {
      continue;
    }


    const value =
      Number(
        match[1]
          .replace(",", ".")
      );


    if (
      !Number.isFinite(
        value
      )
    ) {
      continue;
    }


    addCandidate(
      candidates,
      spans,
      Math.round(value),
      match.index,
      pattern.lastIndex
    );
  }
}


// ========================================
// FORMATTED VND
//
// 500.000
// 500,000
// 1.200.000
// ========================================

function collectFormattedVnd(
  text,
  candidates,
  spans
) {
  const pattern =
    /\b\d{1,3}(?:[.,]\d{3})+\b/g;


  let match;


  while (
    (
      match =
        pattern.exec(text)
    ) !== null
  ) {
    if (
      overlaps(
        match.index,
        pattern.lastIndex,
        spans
      )
    ) {
      continue;
    }


    const raw =
      match[0]
        .replace(/[.,]/g, "");


    const dong =
      Number(raw);


    if (
      !Number.isFinite(dong) ||
      dong < 1000
    ) {
      continue;
    }


    addCandidate(
      candidates,
      spans,
      Math.round(
        dong / 1000
      ),
      match.index,
      pattern.lastIndex
    );
  }
}


// ========================================
// BARE NUMBER CONTEXT
//
// So khong co don vi la truong hop mo ho nhat.
// Chi loai khi ngu canh ro rang cho thay day KHONG
// phai gia: nam, dia chi, quang duong, ma/chuyen...
// ========================================

function isLikelyNonPriceBareNumber(
  text,
  start,
  end,
  value
) {
  // Nam 4 chu so rat de xuat hien trong tin,
  // khong duoc coi la gia nghin.
  if (
    value >= 1900 &&
    value <= 2100
  ) {
    return true;
  }


  const left =
    text
      .slice(
        Math.max(
          0,
          start - 24
        ),
        start
      )
      .trimEnd();


  const right =
    text
      .slice(
        end,
        Math.min(
          text.length,
          end + 24
        )
      )
      .trimStart();


  // Ngu canh truoc so:
  // "so 123", "ngo 123", "duong 32",
  // "ma 300", "chuyen 300", "ql 18"...
  if (
    /(?:^|\s)(?:so|nha|ngo|ngach|hem|duong|pho|ql|quoc lo|tinh lo|tl|ma|code|chuyen|bien|bien so)\s*$/.test(
      left
    )
  ) {
    return true;
  }


  // Don vi / y nghia sau so:
  // "300 km", "20 nguoi", "30 phut"...
  if (
    /^(?:km|m|met|meter|phut|p|gio|h|nguoi|khach|cho|chuyen|lan|km2)\b/.test(
      right
    )
  ) {
    return true;
  }


  return false;
}


// ========================================
// BARE NUMBER
//
// 300 -> 300k
//
// Co y khong doc:
// q1
// 4c
// 22h
// 15p
// phone 0912345678
//
// Chi chap nhan standalone 2-4 digits.
// ========================================

function collectBareThousands(
  text,
  candidates,
  spans
) {
  const pattern =
    /\d{2,4}/g;


  let match;


  while (
    (
      match =
        pattern.exec(text)
    ) !== null
  ) {
    const start =
      match.index;

    const end =
      pattern.lastIndex;


    if (
      overlaps(
        start,
        end,
        spans
      )
    ) {
      continue;
    }


    const before =
      start > 0
        ? text[start - 1]
        : "";


    const after =
      end < text.length
        ? text[end]
        : "";


    // ========================================
    // Phai la standalone.
    //
    // q300, 300k, 300h...
    // khong duoc coi la bare price.
    // ========================================

    if (
      /[a-z0-9]/.test(
        before
      ) ||
      /[a-z0-9]/.test(
        after
      )
    ) {
      continue;
    }


    // ========================================
    // Bo qua gio / khoang.
    //
    // 06:30
    // 6-30
    // ========================================

    if (
      before === ":" ||
      after === ":" ||
      before === "-" ||
      after === "-"
    ) {
      continue;
    }


    const value =
      Number(
        match[0]
      );


    if (
      !Number.isFinite(
        value
      )
    ) {
      continue;
    }


    if (
      isLikelyNonPriceBareNumber(
        text,
        start,
        end,
        value
      )
    ) {
      continue;
    }


    addCandidate(
      candidates,
      spans,
      value,
      start,
      end
    );
  }
}


// ========================================
// PUBLIC: ALL CANDIDATES
// ========================================

export function extractMessagePriceCandidates(
  normalizedText
) {
  const text =
    String(
      normalizedText ?? ""
    );


  const candidates =
    [];

  const spans =
    [];


  // Thu tu quan trong:
  // cu phap ro rang xu ly truoc.
  collectDecimalMillions(
    text,
    candidates,
    spans
  );


  collectMillionShorthand(
    text,
    candidates,
    spans
  );


  collectThousands(
    text,
    candidates,
    spans
  );


  collectFormattedVnd(
    text,
    candidates,
    spans
  );


  collectBareThousands(
    text,
    candidates,
    spans
  );


  return candidates;
}


// ========================================
// PUBLIC: MESSAGE PRICE
//
// Neu tin co nhieu so tien,
// lay muc CAO NHAT.
//
// VD:
// "500k - 650k"
// => 650
//
// Gia tri nay chi dung de check
// minimumPrice.
// ========================================

export function extractMessagePriceThousands(
  normalizedText
) {
  const candidates =
    extractMessagePriceCandidates(
      normalizedText
    );


  if (
    candidates.length ===
    0
  ) {
    return null;
  }


  return Math.max(
    ...candidates
  );
}