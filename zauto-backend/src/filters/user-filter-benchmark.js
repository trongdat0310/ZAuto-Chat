import {
  performance,
} from "node:perf_hooks";

import {
  compileUserFilterDocument,
  getCompiledGroupPlan,
} from "./user-filter-runtime.js";

import {
  evaluateCompiledGroupPlan,
} from "./user-filter-evaluator.js";


function advancedFilter(
  id,
  keyword
) {
  return {
    id,

    name:
      id,

    mode:
      "advanced",

    enabled:
      true,

    groupIds:
      [],

    basic:
      {},

    advanced: {
      showKeywords: [
        keyword,
      ],

      hideKeywords:
        [],
    },
  };
}


function basicFilter(
  id,
  {
    pickup = "",
    dropoff = "",
    include = "",
    exclude = "",
    price = null,
    time = "",
  } = {}
) {
  return {
    id,

    name:
      id,

    mode:
      "basic",

    enabled:
      true,

    groupIds:
      [],

    basic: {
      pickup,

      dropoff,

      acceptBothDirections:
        false,

      includeKeywords:
        include,

      excludeKeywords:
        exclude,

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


function buildAdvancedWorkload(
  count,
  matchPosition
) {
  const filters = [];

  for (
    let index = 0;
    index < count;
    index += 1
  ) {
    filters.push(
      advancedFilter(
        `advanced-${index + 1}`,
        index ===
          matchPosition - 1
          ? "target"
          : `never-${index + 1}`
      )
    );
  }


  return {
    filters,

    message:
      "target",
  };
}


function buildBasicWorkload(
  count
) {
  const filters = [];

  for (
    let index = 0;
    index < count;
    index += 1
  ) {
    filters.push(
      basicFilter(
        `basic-${index + 1}`,
        {
          price:
            1000 - index * 5,

          time:
            index === count - 1
              ? "tối"
              : "sáng",
        }
      )
    );
  }


  return {
    filters,

    message:
      "cuốc tối nay 20h giá 1tr2",
  };
}


function buildAdvancedNoMatchWorkload(
  count
) {
  const filters =
    [];


  for (
    let index = 0;
    index < count;
    index += 1
  ) {
    filters.push(
      advancedFilter(
        `advanced-no-match-${index + 1}`,
        `never-${index + 1}`
      )
    );
  }


  return {
    filters,

    message:
      "Q1 đi Nội Bài xe 4c giá 650k sáng mai 7h",
  };
}


function buildFullBasicWorkload(
  count
) {
  const filters =
    [];


  for (
    let index = 0;
    index < count;
    index += 1
  ) {
    filters.push(
      basicFilter(
        `full-basic-${index + 1}`,
        {
          pickup:
            "q1",

          dropoff:
            "nội bài",

          include:
            index === count - 1
              ? "4c"
              : `never-${index + 1}`,

          exclude:
            "ghép",

          price:
            500,

          time:
            "sáng",
        }
      )
    );
  }


  return {
    filters,

    message:
      "sáng mai 7h30 Q1 đi Nội Bài xe 4c giá 650k",
  };
}


function buildMixedWorkload(
  count
) {
  const filters = [];

  let targetAdvancedIndex =
    -1;


  for (
    let index = count - 1;
    index >= 0;
    index -= 1
  ) {
    if (
      index % 2 ===
      0
    ) {
      targetAdvancedIndex =
        index;

      break;
    }
  }


  for (
    let index = 0;
    index < count;
    index += 1
  ) {
    if (
      index % 2 ===
      0
    ) {
      filters.push(
        advancedFilter(
          `mixed-advanced-${index + 1}`,
          index === targetAdvancedIndex
            ? "target"
            : `never-${index + 1}`
        )
      );

    } else {

      filters.push(
        basicFilter(
          `mixed-basic-${index + 1}`,
          {
            price:
              900,

            time:
              "sáng",
          }
        )
      );
    }
  }


  return {
    filters,

    message:
      "target tối nay 20h giá 800k",
  };
}


function runCase({
  name,
  filters,
  message,
  iterations,
}) {
  const runtime =
    compileUserFilterDocument({
      filters,
    });

  const plan =
    getCompiledGroupPlan(
      runtime,
      "benchmark"
    );


  for (
    let index = 0;
    index < 1000;
    index += 1
  ) {
    evaluateCompiledGroupPlan(
      plan,
      message
    );
  }


  const started =
    performance.now();


  let evaluatedFilters =
    0;


  for (
    let index = 0;
    index < iterations;
    index += 1
  ) {
    const result =
      evaluateCompiledGroupPlan(
        plan,
        message
      );


    evaluatedFilters +=
      result.evaluatedFilters ??
      0;
  }


  const elapsedMs =
    performance.now() -
    started;


  return {
    name,

    iterations,

    totalMs:
      Number(
        elapsedMs.toFixed(3)
      ),

    avgMicroseconds:
      Number(
        (
          elapsedMs *
          1000 /
          iterations
        ).toFixed(3)
      ),

    messagesPerSecond:
      Math.round(
        iterations /
        (
          elapsedMs /
          1000
        )
      ),

    avgEvaluatedFilters:
      Number(
        (
          evaluatedFilters /
          iterations
        ).toFixed(2)
      ),
  };
}


const iterations =
  Number(
    process.env.FILTER_BENCH_ITERATIONS ??
    50000
  );


const cases =
  [];


for (
  const count of [
    5,
    20,
    50,
  ]
) {
  const advancedFirst =
    buildAdvancedWorkload(
      count,
      1
    );

  cases.push(
    runCase({
      name:
        `advanced-${count}-match-first`,

      ...advancedFirst,

      iterations,
    })
  );


  const advancedLast =
    buildAdvancedWorkload(
      count,
      count
    );

  cases.push(
    runCase({
      name:
        `advanced-${count}-match-last`,

      ...advancedLast,

      iterations,
    })
  );


  const advancedNoMatch =
    buildAdvancedNoMatchWorkload(
      count
    );

  cases.push(
    runCase({
      name:
        `advanced-${count}-no-match`,

      ...advancedNoMatch,

      iterations,
    })
  );


  const basic =
    buildBasicWorkload(
      count
    );

  cases.push(
    runCase({
      name:
        `basic-price-time-${count}`,

      ...basic,

      iterations,
    })
  );


  const fullBasic =
    buildFullBasicWorkload(
      count
    );

  cases.push(
    runCase({
      name:
        `basic-full-${count}-match-last`,

      ...fullBasic,

      iterations,
    })
  );


  const mixed =
    buildMixedWorkload(
      count
    );

  cases.push(
    runCase({
      name:
        `mixed-${count}`,

      ...mixed,

      iterations,
    })
  );
}


console.table(
  cases
);
