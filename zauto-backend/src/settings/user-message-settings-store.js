import fs from "node:fs";
import path from "node:path";



// ========================================
// RAM CACHE
//
// Message hot path khong doc file moi lan.
// ========================================

const settingsCache =
  new Map();


const DEFAULT_SETTINGS = {

  // Lọc trùng cuốc
  deduplicateMessages: true,

  // Phai trung voi thoi gian hien thi card cuoc.
    dedupeWindowSeconds: 10,
};


function getUserDirectory(
  userId
) {

  return path.resolve(
    "data",
    "user-data",
    String(userId)
  );
}


function getSettingsFile(
  userId
) {

  return path.join(
    getUserDirectory(
      userId
    ),
    "message-settings.json"
  );
}


function ensureUserDirectory(
  userId
) {

  const directory =
    getUserDirectory(
      userId
    );


  fs.mkdirSync(
    directory,
    {
      recursive: true,
    }
  );


  return directory;
}


// ========================================
// GET SETTINGS
// ========================================

export function getUserMessageSettings(
  userId
) {
  const key =
    String(
      userId
    );


  const cached =
    settingsCache.get(
      key
    );


  if (cached) {
    return cached;
  }


  ensureUserDirectory(
    key
  );


  const file =
    getSettingsFile(
      key
    );


  let settings;


  if (
    !fs.existsSync(
      file
    )
  ) {

    settings = {
      ...DEFAULT_SETTINGS,
    };

  } else {

    try {

      const saved =
        JSON.parse(
          fs.readFileSync(
            file,
            "utf8"
          )
        );


      settings = {
        ...DEFAULT_SETTINGS,
        ...saved,
      };

    } catch (error) {

      console.error(
        "[MESSAGE SETTINGS] READ ERROR:",
        key,
        error
      );


      settings = {
        ...DEFAULT_SETTINGS,
      };
    }
  }


  settingsCache.set(
    key,
    settings
  );


  return settings;
}


// ========================================
// UPDATE SETTINGS
// ========================================

export function updateUserMessageSettings(
  userId,
  patch = {}
) {

  const current =
    getUserMessageSettings(
      userId
    );


  const next = {
    ...current,
  };


  if (
    typeof patch.deduplicateMessages ===
    "boolean"
  ) {

    next.deduplicateMessages =
      patch.deduplicateMessages;
  }


  if (
    patch.dedupeWindowSeconds != null
  ) {

    const seconds =
      Number(
        patch.dedupeWindowSeconds
      );


    if (
      Number.isFinite(
        seconds
      ) &&
      seconds >= 1 &&
      seconds <= 60
    ) {

      next.dedupeWindowSeconds =
        Math.round(
          seconds
        );
    }
  }


  ensureUserDirectory(
    userId
  );


  fs.writeFileSync(
    getSettingsFile(
      userId
    ),

    JSON.stringify(
      next,
      null,
      2
    ),

    "utf8"
  );


  settingsCache.set(
    String(
      userId
    ),
    next
  );


  return next;
}