import fs from "node:fs";
import path from "node:path";


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

  ensureUserDirectory(
    userId
  );


  const file =
    getSettingsFile(
      userId
    );


  if (
    !fs.existsSync(
      file
    )
  ) {

    return {
      ...DEFAULT_SETTINGS,
    };
  }


  try {

    const saved =
      JSON.parse(
        fs.readFileSync(
          file,
          "utf8"
        )
      );


    return {
      ...DEFAULT_SETTINGS,
      ...saved,
    };

  } catch (error) {

    console.error(
      "[MESSAGE SETTINGS] READ ERROR:",
      userId,
      error
    );


    return {
      ...DEFAULT_SETTINGS,
    };
  }
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


  return next;
}