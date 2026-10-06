import fs from "node:fs";
import path from "node:path";
import {
  fileURLToPath,
} from "node:url";


const __filename =
fileURLToPath(
  import.meta.url
);

const __dirname =
path.dirname(
  __filename
);


const rootPath =
path.resolve(
  __dirname,
  "../../data/user-data"
);


const MAX_SAVED_KEYWORDS =
500;

const MAX_KEYWORD_LENGTH =
255;


// ========================================
// PATH
// ========================================

function getUserDir(
  userId
) {
  return path.join(
    rootPath,
    String(userId)
  );
}


function getLibraryPath(
  userId
) {
  return path.join(
    getUserDir(
      userId
    ),
    "filter-keywords.json"
  );
}


// ========================================
// HELPERS
// ========================================

function nowIso() {
  return new Date()
    .toISOString();
}


function sanitizeKeyword(
  value
) {
  return String(
    value ?? ""
  )
    .trim()
    .slice(
      0,
      MAX_KEYWORD_LENGTH
    );
}


function sanitizeKeywords(
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
    const raw of values
  ) {
    const keyword =
      sanitizeKeyword(
        raw
      );


    if (!keyword) {
      continue;
    }


    const key =
      keyword
        .toLowerCase();


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
      keyword
    );


    if (
      result.length >=
      MAX_SAVED_KEYWORDS
    ) {
      break;
    }
  }


  return result;
}


// ========================================
// READ
//
// This store is only used by explicit
// keyword-library API calls.
//
// It is NOT part of the realtime filter
// evaluation hot path.
// ========================================

export function getUserSavedFilterKeywords(
  userId
) {
  const filePath =
    getLibraryPath(
      userId
    );


  if (
    !fs.existsSync(
      filePath
    )
  ) {
    return [];
  }


  try {
    const saved =
      JSON.parse(
        fs.readFileSync(
          filePath,
          "utf-8"
        )
      );


    return sanitizeKeywords(
      saved?.keywords
    );

  } catch (error) {

    console.error(
      "[USER FILTER KEYWORD STORE] READ ERROR:",
      userId,
      error
    );


    return [];
  }
}


// ========================================
// WRITE
//
// Atomic temp-file rename, same approach
// as the filter document store.
// ========================================

export function saveUserSavedFilterKeywords(
  userId,
  keywords
) {
  const sanitized =
    sanitizeKeywords(
      keywords
    );


  const userDir =
    getUserDir(
      userId
    );


  fs.mkdirSync(
    userDir,
    {
      recursive: true,
    }
  );


  const filePath =
    getLibraryPath(
      userId
    );


  const tempPath =
    `${filePath}.tmp-${process.pid}-${Date.now()}`;


  fs.writeFileSync(
    tempPath,

    JSON.stringify(
      {
        version: 1,

        keywords:
          sanitized,

        updatedAt:
          nowIso(),
      },
      null,
      2
    ),

    "utf-8"
  );


  fs.renameSync(
    tempPath,
    filePath
  );


  return sanitized;
}
