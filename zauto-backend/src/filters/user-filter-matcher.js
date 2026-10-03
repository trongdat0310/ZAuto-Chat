// ========================================
// TEXT NORMALIZE
// ========================================

export function normalizeFilterText(
  value = ""
) {
  return String(value)
    .normalize("NFD")
    .replace(
      /[\u0300-\u036f]/g,
      ""
    )
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}


// ========================================
// ASCII WORD CHAR
//
// Sau normalize:
// tieng Viet da tro ve ASCII.
// ========================================

function isWordChar(
  char
) {
  if (!char) {
    return false;
  }

  const code =
    char.charCodeAt(0);

  return (
    (
      code >= 48 &&
      code <= 57
    ) ||
    (
      code >= 97 &&
      code <= 122
    )
  );
}


// ========================================
// WHOLE WORD / WHOLE PHRASE
//
// "tan":
// tan       -> yes
// di tan    -> yes
// tang      -> no
//
// "quan 1":
// di quan 1 -> yes
// ========================================

function findWholePhrase(
  text,
  phrase,
  startAt = 0
) {
  if (!phrase) {
    return -1;
  }

  let cursor =
    Math.max(
      0,
      startAt
    );

  while (
    cursor <=
    text.length -
      phrase.length
  ) {
    const index =
      text.indexOf(
        phrase,
        cursor
      );

    if (index < 0) {
      return -1;
    }

    const end =
      index +
      phrase.length;

    const before =
      index > 0
        ? text[index - 1]
        : "";

    const after =
      end < text.length
        ? text[end]
        : "";

    const beforeOk =
      !isWordChar(
        before
      );

    let afterOk =
      !isWordChar(
        after
      );

    // ========================================
    // NUMBER SPECIAL CASE
    //
    // 500 -> 500k
    // 500 -> 500
    // 500 !-> 1500
    //
    // Wildcard *500* van match 1500.
    // ========================================

    if (
      !afterOk &&
      /^\d+$/.test(
        phrase
      ) &&
      after === "k"
    ) {
      const afterK =
        end + 1 <
        text.length
          ? text[end + 1]
          : "";

      afterOk =
        !isWordChar(
          afterK
        );
    }

    if (
      beforeOk &&
      afterOk
    ) {
      return index;
    }

    cursor =
      index + 1;
  }

  return -1;
}


// ========================================
// ORDERED WILDCARD GROUPS
//
// *(q1|quan 1)*(noi bai|nb)*
//
// [
//   ["q1", "quan 1"],
//   ["noi bai", "nb"]
// ]
//
// Khong dung dynamic RegExp.
// ========================================

function parseOrderedGroups(
  source
) {
  const groups = [];

  let cursor = 0;

  while (
    cursor <
    source.length
  ) {
    // Moi group phai bat dau bang *(
    if (
      !source.startsWith(
        "*(",
        cursor
      )
    ) {
      return null;
    }


    const bodyStart =
      cursor + 2;


    const close =
      source.indexOf(
        ")*",
        bodyStart
      );


    if (close < 0) {
      return null;
    }


    const rawBody =
      source.slice(
        bodyStart,
        close
      );


    const alternatives =
      rawBody
        .split("|")
        .map(
          normalizeFilterText
        )
        .filter(Boolean);


    if (
      alternatives.length ===
      0
    ) {
      return null;
    }


    groups.push(
      [
        ...new Set(
          alternatives
        ),
      ]
    );


    // ========================================
    // DAU * SAU DAU )
    //
    // *(a|b)*
    //       ^
    //
    // Neu day la ky tu cuoi:
    //   pattern ket thuc.
    //
    // Neu sau no la "(":
    //   dau * nay dong thoi la dau *
    //   mo dau group tiep theo:
    //
    // *(a|b)*(c|d)*
    //       ^
    // ========================================

    const starIndex =
      close + 1;


    // Final *
    if (
      starIndex ===
      source.length - 1
    ) {
      cursor =
        source.length;

      break;
    }


    // Neu chua het thi *
    // bat buoc phai duoc tiep noi boi (
    if (
      source[
        starIndex + 1
      ] !== "("
    ) {
      return null;
    }


    // KHONG bo qua dau *.
    // Group sau se dung lai chinh dau * nay.
    cursor =
      starIndex;
  }


  return groups.length > 0
    ? groups
    : null;
}


// ========================================
// ORDERED MATCH
// ========================================

function matchOrderedGroups(
  text,
  groups
) {
  let cursor = 0;

  for (
    const alternatives
    of groups
  ) {
    let bestIndex = -1;
    let bestLength = 0;

    for (
      const alternative
      of alternatives
    ) {
      const index =
        text.indexOf(
          alternative,
          cursor
        );

      if (
        index < 0
      ) {
        continue;
      }

      // Lay occurrence som nhat.
      if (
        bestIndex < 0 ||
        index <
          bestIndex
      ) {
        bestIndex =
          index;

        bestLength =
          alternative.length;
      }
    }

    if (
      bestIndex < 0
    ) {
      return false;
    }

    cursor =
      bestIndex +
      bestLength;
  }

  return true;
}


// ========================================
// COMPILED MATCHER
//
// {
//   source,
//   normalizedSource,
//   kind,
//   matches(normalizedText)
// }
// ========================================

export function compileKeywordPattern(
  rawPattern
) {
  const source =
    String(
      rawPattern ?? ""
    ).trim();

  if (!source) {
    return null;
  }

  // ========================================
  // ORDERED GROUP
  //
  // *(q1|quan 1)*(noi bai|nb)*
  // ========================================

  if (
    source.startsWith(
      "*("
    )
  ) {
    const groups =
      parseOrderedGroups(
        source
      );

    if (groups) {
      return {
        source,

        normalizedSource:
          groups
            .map(
              group =>
                group.join("|")
            )
            .join(" -> "),

        kind:
          groups.length === 1
            ? "wildcard-or"
            : "ordered-wildcard",

        matches(
          normalizedText
        ) {
          return matchOrderedGroups(
            normalizedText,
            groups
          );
        },
      };
    }
  }

  // ========================================
  // CONTAINS WILDCARD
  //
  // *tan*
  // *500*
  // ========================================

  if (
    source.length >= 2 &&
    source.startsWith("*") &&
    source.endsWith("*")
  ) {
    const inner =
      normalizeFilterText(
        source.slice(
          1,
          -1
        )
      );

    if (!inner) {
      return null;
    }

    return {
      source,

      normalizedSource:
        inner,

      kind:
        "contains",

      matches(
        normalizedText
      ) {
        return normalizedText
          .includes(
            inner
          );
      },
    };
  }

  // ========================================
  // KHONG CHAP NHAN "*" LO LUNG
  //
  // abc*
  // *abc
  //
  // UI validation sau nay se bao loi.
  // ========================================

  if (
    source.includes("*")
  ) {
    return null;
  }

  const normalized =
    normalizeFilterText(
      source
    );

  if (!normalized) {
    return null;
  }

  // ========================================
  // EXACT WORD / PHRASE
  // ========================================

  return {
    source,

    normalizedSource:
      normalized,

    kind:
      /^\d+$/.test(
        normalized
      )
        ? "number"
        : "exact",

    matches(
      normalizedText
    ) {
      return (
        findWholePhrase(
          normalizedText,
          normalized
        ) >= 0
      );
    },
  };
}


// ========================================
// COMPILE ARRAY
// ========================================

export function compileKeywordList(
  values
) {
  if (
    !Array.isArray(
      values
    )
  ) {
    return [];
  }

  const result = [];

  const seen =
    new Set();

  for (
    const value of values
  ) {
    const matcher =
      compileKeywordPattern(
        value
      );

    if (!matcher) {
      continue;
    }

    const key =
      `${matcher.kind}:` +
      matcher.normalizedSource;

    if (
      seen.has(
        key
      )
    ) {
      continue;
    }

    seen.add(
      key
    );

    result.push(
      matcher
    );
  }

  return result;
}


// ========================================
// BASIC TEXT FIELD
//
// "ha noi, hn, *(noi bai|nb)*"
//
// => OR list.
// ========================================

export function compileCommaSeparatedKeywords(
  rawValue
) {
  const text =
    String(
      rawValue ?? ""
    );

  if (!text.trim()) {
    return [];
  }

  return compileKeywordList(
    text.split(",")
  );
}


// ========================================
// FIRST MATCH
// ========================================

export function findFirstKeywordMatch(
  compiledMatchers,
  normalizedText
) {
  for (
    const matcher
    of compiledMatchers
  ) {
    if (
      matcher.matches(
        normalizedText
      )
    ) {
      return matcher;
    }
  }

  return null;
}


// ========================================
// LEGACY MATCHER
//
// Bao toan logic cu:
// text.includes(keyword)
//
// Dung trong giai doan migration.
// ========================================

export function compileLegacyContainsList(
  values
) {
  if (
    !Array.isArray(
      values
    )
  ) {
    return [];
  }

  const result = [];

  const seen =
    new Set();

  for (
    const rawValue of values
  ) {
    const normalized =
      normalizeFilterText(
        rawValue
      );

    if (
      !normalized ||
      seen.has(
        normalized
      )
    ) {
      continue;
    }

    seen.add(
      normalized
    );

    result.push({
      source:
        String(
          rawValue
        ),

      normalizedSource:
        normalized,

      kind:
        "legacy-contains",

      matches(
        normalizedText
      ) {
        return normalizedText
          .includes(
            normalized
          );
      },
    });
  }

  return result;
}