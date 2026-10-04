import {
  compileKeywordList,
  findFirstKeywordMatch,
  normalizeFilterText,
} from "./user-filter-matcher.js";


// ========================================
// CONSTANTS
// ========================================

const DAYPART_RANGES =
  Object.freeze({
    sang: [
      [300, 660],
    ],

    trua: [
      [660, 780],
    ],

    chieu: [
      [780, 1080],
    ],

    toi: [
      [1080, 1380],
    ],

    dem: [
      [1320, 1440],
      [0, 240],
    ],

    khuya: [
      [1320, 1440],
      [0, 240],
    ],
  });


// ========================================
// HELPERS
// ========================================

function isValidClock(
  hour,
  minute = 0
) {
  return (
    Number.isInteger(hour) &&
    Number.isInteger(minute) &&
    hour >= 0 &&
    hour <= 24 &&
    minute >= 0 &&
    minute < 60 &&
    !(
      hour === 24 &&
      minute !== 0
    )
  );
}


function toMinuteOfDay(
  hour,
  minute = 0
) {
  if (
    !isValidClock(
      hour,
      minute
    )
  ) {
    return null;
  }


  return (
    hour * 60 +
    minute
  );
}


function parseClockParts(
  hourText,
  hMinuteText,
  colonMinuteText
) {
  const hour =
    Number(
      hourText
    );

  const minute =
    Number(
      colonMinuteText ??
      hMinuteText ??
      0
    );


  return toMinuteOfDay(
    hour,
    minute
  );
}


function splitClockRange(
  start,
  end
) {
  if (
    start === null ||
    end === null
  ) {
    return [];
  }


  if (
    start <= end
  ) {
    return [
      [start, end],
    ];
  }


  return [
    [start, 1440],
    [0, end],
  ];
}


function rangesOverlap(
  a,
  b
) {
  return (
    a[0] <= b[1] &&
    b[0] <= a[1]
  );
}


function anyRangeOverlap(
  leftRanges,
  rightRanges
) {
  for (
    const left of leftRanges
  ) {
    for (
      const right of rightRanges
    ) {
      if (
        rangesOverlap(
          left,
          right
        )
      ) {
        return true;
      }
    }
  }


  return false;
}


function pushRange(
  target,
  range
) {
  if (
    !range ||
    range.length !== 2
  ) {
    return;
  }


  target.push(
    range
  );
}


// ========================================
// COMPILE USER RULES
//
// Chay MOT LAN khi document/filter thay doi.
// ========================================

function compileOneTimeRule(
  rawRule
) {
  const source =
    String(
      rawRule ?? ""
    ).trim();


  const text =
    normalizeFilterText(
      source
    );


  if (!text) {
    return null;
  }


  const daypart =
    DAYPART_RANGES[
      text
    ];


  if (daypart) {
    return {
      kind:
        "time",

      source,

      ranges:
        daypart,
    };
  }


  let match =
    /^(\d{1,3})\s*-\s*(\d{1,3})\s*(?:p|ph|phut)$/.exec(
      text
    );


  if (match) {
    const start =
      Number(
        match[1]
      );

    const end =
      Number(
        match[2]
      );


    if (
      start >= 0 &&
      end >= start &&
      end <= 1440
    ) {
      return {
        kind:
          "minute",

        source,

        ranges: [
          [start, end],
        ],
      };
    }
  }


  match =
    /^(\d{1,3})\s*(?:p|ph|phut)$/.exec(
      text
    );


  if (match) {
    const end =
      Number(
        match[1]
      );


    if (
      end >= 0 &&
      end <= 1440
    ) {
      return {
        kind:
          "minute",

        source,

        ranges: [
          [0, end],
        ],
      };
    }
  }


  match =
    /^(sau|truoc)\s+(\d{1,2})(?:h(?:(\d{1,2}))?|:(\d{2}))?$/.exec(
      text
    );


  if (match) {
    const minute =
      parseClockParts(
        match[2],
        match[3],
        match[4]
      );


    if (
      minute !== null
    ) {
      return {
        kind:
          "time",

        source,

        ranges:
          match[1] ===
            "sau"
            ? [
                [minute, 1440],
              ]
            : [
                [0, minute],
              ],
      };
    }
  }


  match =
    /^(\d{1,2})(?:h(?:(\d{1,2}))?|:(\d{2}))?\s*-\s*(\d{1,2})(?:h(?:(\d{1,2}))?|:(\d{2}))?$/.exec(
      text
    );


  if (match) {
    const start =
      parseClockParts(
        match[1],
        match[2],
        match[3]
      );

    const end =
      parseClockParts(
        match[4],
        match[5],
        match[6]
      );


    const ranges =
      splitClockRange(
        start,
        end
      );


    if (
      ranges.length >
      0
    ) {
      return {
        kind:
          "time",

        source,

        ranges,
      };
    }
  }


  return {
    kind:
      "keyword",

    source,

    matchers:
      compileKeywordList([
        source,
      ]),
  };
}


export function compileTimeRules(
  rawValue
) {
  const parts =
    String(
      rawValue ?? ""
    )
      .split(",")
      .map(
        value =>
          value.trim()
      )
      .filter(Boolean);


  const timeRanges =
    [];

  const minuteRanges =
    [];

  const keywordMatchers =
    [];


  for (
    const part of parts
  ) {
    const compiled =
      compileOneTimeRule(
        part
      );


    if (!compiled) {
      continue;
    }


    if (
      compiled.kind ===
      "time"
    ) {
      timeRanges.push(
        ...compiled.ranges
      );

      continue;
    }


    if (
      compiled.kind ===
      "minute"
    ) {
      minuteRanges.push(
        ...compiled.ranges
      );

      continue;
    }


    keywordMatchers.push(
      ...compiled.matchers
    );
  }


  return {
    raw:
      String(
        rawValue ?? ""
      ).trim(),

    timeRanges,

    minuteRanges,

    keywordMatchers,

    hasRules:
      timeRanges.length > 0 ||
      minuteRanges.length > 0 ||
      keywordMatchers.length > 0,
  };
}


// ========================================
// MESSAGE TIME PARSER
//
// Chay LAZY, chi khi group plan co Basic
// filter that su can time.
// ========================================

function collectDayparts(
  text,
  timeRanges
) {
  const pattern =
    /\b(sang|trua|chieu|toi|dem|khuya)\b/g;


  let match;


  while (
    (
      match =
        pattern.exec(text)
    ) !== null
  ) {
    const ranges =
      DAYPART_RANGES[
        match[1]
      ];


    for (
      const range of ranges
    ) {
      pushRange(
        timeRanges,
        range
      );
    }
  }
}


function collectBeforeAfter(
  text,
  timeRanges
) {
  const pattern =
    /\b(sau|truoc)\s+(\d{1,2})(?:h(?:(\d{1,2}))?|:(\d{2}))?\b/g;


  let match;


  while (
    (
      match =
        pattern.exec(text)
    ) !== null
  ) {
    const minute =
      parseClockParts(
        match[2],
        match[3],
        match[4]
      );


    if (
      minute === null
    ) {
      continue;
    }


    pushRange(
      timeRanges,
      match[1] ===
        "sau"
        ? [minute, 1440]
        : [0, minute]
    );
  }
}


function collectExplicitClockRanges(
  text,
  timeRanges
) {
  const pattern =
    /\b(\d{1,2})(?:h(?:(\d{1,2}))?|:(\d{2}))?\s*-\s*(\d{1,2})(?:h(?:(\d{1,2}))?|:(\d{2}))?\b/g;


  let match;


  while (
    (
      match =
        pattern.exec(text)
    ) !== null
  ) {
    // "0-15" theo UI la khoang PHUT gap,
    // khong phai 00:00-15:00.
    if (
      match[1] === "0" &&
      match[2] === undefined &&
      match[3] === undefined &&
      match[5] === undefined &&
      match[6] === undefined
    ) {
      continue;
    }


    const start =
      parseClockParts(
        match[1],
        match[2],
        match[3]
      );

    const end =
      parseClockParts(
        match[4],
        match[5],
        match[6]
      );


    for (
      const range of
      splitClockRange(
        start,
        end
      )
    ) {
      pushRange(
        timeRanges,
        range
      );
    }
  }
}


function collectClockPoints(
  text,
  timeRanges
) {
  const pattern =
    /\b(\d{1,2})(?:h(\d{1,2})?|:(\d{2}))\b/g;


  let match;


  while (
    (
      match =
        pattern.exec(text)
    ) !== null
  ) {
    const minute =
      parseClockParts(
        match[1],
        match[2],
        match[3]
      );


    if (
      minute === null
    ) {
      continue;
    }


    pushRange(
      timeRanges,
      [minute, minute]
    );
  }
}


function collectMinuteMentions(
  text,
  minuteRanges
) {
  const explicit =
    /\b(\d{1,3})\s*(?:p|ph|phut)\b/g;


  let match;


  while (
    (
      match =
        explicit.exec(text)
    ) !== null
  ) {
    const value =
      Number(
        match[1]
      );


    if (
      value < 0 ||
      value > 1440
    ) {
      continue;
    }


    pushRange(
      minuteRanges,
      [value, value]
    );
  }


  // UI cho phep message "0-15" nhu mot cach
  // viet so phut gap. Chi nhan dang dang 0-N
  // de khong nham "6-8" la khoang gio.
  const zeroRange =
    /\b0\s*-\s*(\d{1,3})\b/g;


  while (
    (
      match =
        zeroRange.exec(text)
    ) !== null
  ) {
    const end =
      Number(
        match[1]
      );


    if (
      end < 0 ||
      end > 1440
    ) {
      continue;
    }


    pushRange(
      minuteRanges,
      [0, end]
    );
  }
}


export function extractMessageTemporalMentions(
  normalizedText
) {
  const text =
    String(
      normalizedText ?? ""
    );


  const timeRanges =
    [];

  const minuteRanges =
    [];


  collectDayparts(
    text,
    timeRanges
  );


  collectBeforeAfter(
    text,
    timeRanges
  );


  collectExplicitClockRanges(
    text,
    timeRanges
  );


  collectClockPoints(
    text,
    timeRanges
  );


  collectMinuteMentions(
    text,
    minuteRanges
  );


  return {
    timeRanges,

    minuteRanges,
  };
}


// ========================================
// MATCH COMPILED RULES
// ========================================

export function matchesCompiledTimeRules(
  compiledRules,
  temporalMentions,
  normalizedText
) {
  if (
    !compiledRules ||
    compiledRules.hasRules !==
      true
  ) {
    return true;
  }


  if (
    compiledRules
      .keywordMatchers
      .length >
      0 &&
    findFirstKeywordMatch(
      compiledRules
        .keywordMatchers,
      normalizedText
    )
  ) {
    return true;
  }


  if (
    compiledRules
      .timeRanges
      .length >
      0 &&
    temporalMentions
      .timeRanges
      .length >
      0 &&
    anyRangeOverlap(
      compiledRules
        .timeRanges,
      temporalMentions
        .timeRanges
    )
  ) {
    return true;
  }


  if (
    compiledRules
      .minuteRanges
      .length >
      0 &&
    temporalMentions
      .minuteRanges
      .length >
      0 &&
    anyRangeOverlap(
      compiledRules
        .minuteRanges,
      temporalMentions
        .minuteRanges
    )
  ) {
    return true;
  }


  return false;
}
