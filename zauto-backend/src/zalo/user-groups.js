import {
  connectUserZalo,
} from "./user-zalo-manager.js";

import {
  readUserGroupSettings,
} from "./user-group-settings.js";

const groupCaches =
  new Map();


// ========================================
// GET USER GROUPS
// ========================================

export async function getUserGroups(
  userId
) {
  const key =
    String(userId);

  const settings =
    readUserGroupSettings(
      key
    );

  const api =
    await connectUserZalo(
      key
    );


  console.log(
    "[USER GROUPS] Loading:",
    key
  );


  const allGroups =
    await api.getAllGroups();


  const groupIds =
    Object.keys(
      allGroups?.gridVerMap ??
      {}
    );


  if (
    groupIds.length === 0
  ) {
    groupCaches.set(
      key,
      new Map()
    );

    return [];
  }


  const response =
    await api.getGroupInfo(
      groupIds
    );


  const cache =
    new Map();


  const groups = [];


  for (
    const groupId
    of groupIds
  ) {

    const info =
      response?.gridInfoMap?.[
        groupId
      ];


    const group = {
      groupId:
        String(groupId),

      name:
        info?.name ??
        "Unknown Group",

      totalMember:
        info?.totalMember ??
        0,

      enabled:
        settings[
          String(groupId)
        ]?.enabled === true,
    };


    groups.push(
      group
    );


    cache.set(
      String(groupId),
      group
    );
  }


  groups.sort(
    (a, b) =>
      a.name.localeCompare(
        b.name,
        "vi"
      )
  );


  groupCaches.set(
    key,
    cache
  );


  console.log(
    `[USER GROUPS] ${key}: ${groups.length} group(s)`
  );


  return groups;
}


// ========================================
// GET CACHED GROUP NAME
// ========================================

export function getUserGroupName(
  userId,
  groupId
) {
  return (
    groupCaches
      .get(
        String(userId)
      )
      ?.get(
        String(groupId)
      )
      ?.name ??
    "Unknown Group"
  );
}