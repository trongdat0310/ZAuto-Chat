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


    // ========================================
    // DEBUG TAM THOI
    // DE XAC NHAN RESPONSE THUC TE
    // ========================================

    console.log(
      "[USER AVATAR] RESPONSE:",
      {
        userId,
        requested:
          missingIds.length,
        response,
      }
    );


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