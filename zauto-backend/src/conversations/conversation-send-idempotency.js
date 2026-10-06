const CACHE_TTL_MS =
  5 * 60 * 1000;

const MAX_ENTRIES =
  5000;


// userId:requestId -> {
//   promise,
//   result,
//   completedAt,
// }
const sends =
  new Map();


function cleanupExpired() {
  const now =
    Date.now();

  for (
    const [
      key,
      entry,
    ]
    of sends
  ) {
    if (
      entry.result !==
        undefined &&
      now -
        Number(
          entry.completedAt ??
          0
        ) >
        CACHE_TTL_MS
    ) {
      sends.delete(
        key
      );
    }
  }


  if (
    sends.size <=
    MAX_ENTRIES
  ) {
    return;
  }


  const completed =
    Array.from(
      sends.entries()
    )
      .filter(
        (
          [, entry]
        ) =>
          entry.result !==
            undefined
      )
      .sort(
        (
          [, a],
          [, b]
        ) =>
          Number(
            a.completedAt ??
            0
          ) -
          Number(
            b.completedAt ??
            0
          )
      );


  const removeCount =
    sends.size -
    MAX_ENTRIES;


  for (
    let index = 0;
    index < removeCount &&
      index < completed.length;
    index += 1
  ) {
    sends.delete(
      completed[index][0]
    );
  }
}


export function normalizeConversationSendRequestId(
  value
) {
  const requestId =
    String(
      value ??
      ""
    ).trim();


  if (!requestId) {
    return null;
  }


  if (
    requestId.length >
      160 ||
    !/^[A-Za-z0-9._:-]+$/
      .test(
        requestId
      )
  ) {
    const error =
      new Error(
        "clientRequestId khong hop le."
      );

    error.code =
      "INVALID_CLIENT_REQUEST_ID";

    throw error;
  }


  return requestId;
}


export async function runConversationSendOnce(
  userId,
  requestId,
  executor
) {
  const safeRequestId =
    normalizeConversationSendRequestId(
      requestId
    );


  // Backward compatibility cho client cu.
  if (!safeRequestId) {
    return executor();
  }


  cleanupExpired();


  const key =
    `${String(userId)}:${safeRequestId}`;


  const existing =
    sends.get(
      key
    );


  if (existing) {
    if (
      existing.result !==
      undefined
    ) {
      return existing.result;
    }


    if (existing.promise) {
      return existing.promise;
    }
  }


  const entry = {
    promise:
      null,

    result:
      undefined,

    completedAt:
      null,
  };


  const promise =
    Promise.resolve()
      .then(
        executor
      )
      .then(
        result => {

          entry.result =
            result;

          entry.completedAt =
            Date.now();

          entry.promise =
            null;


          return result;
        }
      )
      .catch(
        error => {

          // Loi khong cache.
          // User co the retry cung requestId.
          sends.delete(
            key
          );


          throw error;
        }
      );


  entry.promise =
    promise;


  sends.set(
    key,
    entry
  );


  return promise;
}


// Test helper.
export function clearConversationSendIdempotencyCache() {
  sends.clear();
}
