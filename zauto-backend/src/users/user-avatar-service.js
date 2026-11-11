import {
  connectUserZalo,
} from "../zalo/user-zalo-manager.js";


// ========================================
// USER AVATAR CACHE
//
// key:
//   userId cua tai khoan app
//
// value:
//   Map Zalo uid -> avatar URL
// ========================================

const avatarCache =
  new Map();

// Names are cached from the SAME getUserInfo response as avatars.
// A name belongs to the requested Zalo user ID, never to message.data.dName.
const displayNameCache = new Map();

export function getCachedUserDisplayName(accountId, zaloUserId) {
  return displayNameCache.get(String(accountId))?.get(String(zaloUserId)) ?? null;
}


// ========================================
// GET CACHE
// ========================================

function getAccountCache(
  userId
) {

  const key =
    String(
      userId
    );


  let cache =
    avatarCache.get(
      key
    );


  if (!cache) {

    cache =
      new Map();

    avatarCache.set(
      key,
      cache
    );
  }


  return cache;
}


// ========================================
// GET AVATARS
// ========================================

export async function
getUserAvatars(
  userId,
  userIds = []
) {

  const cache =
    getAccountCache(
      userId
    );


  const uniqueIds =
    [
      ...new Set(
        userIds
          .map(
            value =>
              String(
                value ??
                ""
              ).trim()
          )
          .filter(
            value =>
              value.length > 0
          )
      ),
    ];


  if (
    uniqueIds.length ===
    0
  ) {

    return {};
  }


  const missingIds =
    uniqueIds.filter(
      id =>
        !cache.has(
          id
        )
    );


  // ========================================
  // TAT CA DA CO CACHE
  // ========================================

  if (
    missingIds.length ===
    0
  ) {

    return Object.fromEntries(

      uniqueIds.map(
        id => [
          id,
          cache.get(
            id
          ) ?? null,
        ]
      )
    );
  }


  try {

    const api =
      await connectUserZalo(
        userId
      );


    if (
      !api ||
      typeof api.getUserInfo !==
        "function"
    ) {

      return Object.fromEntries(

        uniqueIds.map(
          id => [
            id,
            cache.get(
              id
            ) ?? null,
          ]
        )
      );
    }


    // ========================================
    // GET USER INFO THEO BATCH
    //
    // zca-js ho tro string[] user IDs.
    // ========================================

    const response =
      await api.getUserInfo(
        missingIds
      );


    // Do not log raw Zalo user profiles (private personal data).

    // ========================================
    // ZCA-JS TRA USER INFO
    //
    // Thu cac dang response pho bien:
    // - response.changed_profiles
    // - response.profiles
    // - response.users
    // ========================================

    const profiles =
      response?.changed_profiles ??
      response?.profiles ??
      response?.users ??
      {};


    if (
      profiles &&
      typeof profiles ===
        "object"
    ) {
      const accountKey = String(userId);
      let names = displayNameCache.get(accountKey);
      if (!names) {
        names = new Map();
        displayNameCache.set(accountKey, names);
      }

      for (
        const id
        of missingIds
      ) {

        const profile =
          profiles[id];


        if (
          !profile
        ) {

          cache.set(
            id,
            null
          );

          continue;
        }


        // displayName is the name of this profile for this account.
        // Do not use the sender's dName as the private conversation title.
        const displayName = [
          profile.displayName,
          profile.zaloName,
          profile.display_name,
          profile.zalo_name,
        ].find(value => typeof value === "string" && value.trim());
        if (displayName) names.set(id, displayName.trim());

        const avatar =
          profile.avatar
            ?.toString()
            .trim() ??
          null;


        cache.set(
          id,
          avatar ||
          null
        );
      }
    }


  } catch (error) {

    console.error(
      "[USER AVATAR] GET ERROR:",
      userId,
      missingIds,
      error?.message ??
      error
    );


    // ========================================
    // LOI KHONG LAM HONG CHAT
    //
    // Khong cache null khi API loi,
    // de lan sau con thu lai.
    // ========================================
  }


  return Object.fromEntries(

    uniqueIds.map(
      id => [
        id,
        cache.get(
          id
        ) ?? null,
      ]
    )
  );
}