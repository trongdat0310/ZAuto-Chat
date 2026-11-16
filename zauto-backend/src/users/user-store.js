import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const __filename =
  fileURLToPath(import.meta.url);

const __dirname =
  path.dirname(__filename);

const usersPath =
  path.resolve(
    __dirname,
    "../../data/users.json"
  );


// ========================================
// READ USERS
// ========================================

// Keep a short-lived, read-only snapshot for repeated auth and WebSocket
// lookups. All in-process writes replace this snapshot immediately.
// External edits of users.json become visible within 500 ms.
const userCacheTtlMs = 500;
let cachedUsers = null;
let cachedById = new Map();
let cacheExpiresAt = 0;

function updateSnapshot(users) {
  const copy = structuredClone(users);
  cachedUsers = copy;
  cachedById = new Map(
    copy.filter(user => user && user.id != null)
      .map(user => [String(user.id), user])
  );
  cacheExpiresAt = Date.now() + userCacheTtlMs;
}

function snapshotUsers({ fresh = false } = {}) {
  if (!fresh && cachedUsers !== null && Date.now() < cacheExpiresAt) {
    return cachedUsers;
  }

  let users = [];
  if (fs.existsSync(usersPath)) {
    try {
      const data = JSON.parse(fs.readFileSync(usersPath, "utf-8"));
      if (Array.isArray(data)) users = data;
    } catch (error) {
      // Do not cache a bad file indefinitely: retry after the short TTL.
      console.error("[USERS] Khong doc duoc users.json", error?.message);
    }
  }
  updateSnapshot(users);
  return cachedUsers;
}

// Return independent objects, as the previous disk-based implementation did.
// Callers must use updateUser() to persist mutations.
function readUsers({ fresh = false } = {}) {
  return structuredClone(snapshotUsers({ fresh }));
}


// ========================================
// WRITE USERS
// ========================================

function writeUsers(users) {
  fs.writeFileSync(
    usersPath,
    JSON.stringify(
      users,
      null,
      2
    ),
    "utf-8"
  );
  updateSnapshot(users);
}


// ========================================
// FIND
// ========================================

export function findUserById(
  userId
) {
  snapshotUsers();
  const user = cachedById.get(String(userId));
  return user ? structuredClone(user) : null;
}


export function findUserByEmail(email) {
  const normalized = String(email ?? "").trim().toLowerCase();
  return readUsers().find(user => user.email?.toLowerCase() === normalized) ?? null;
}

export function findUserByPhone(
  phone
) {
  return (
    readUsers().find(
      user =>
        user.phone === phone
    ) ?? null
  );
}


// ========================================
// CREATE
// ========================================

export function createUser({
  name,
  phone,
  passwordHash,
  email,
}) {
  const users =
    readUsers({ fresh: true });

  const now =
    new Date().toISOString();

  const user = {
    id:
      crypto.randomUUID(),

    name,
    phone,
    email,
    passwordHash,

    membership:
      "free",

    zaloLinked:
      false,

    zaloUserId:
      null,

    createdAt:
      now,

    updatedAt:
      now,
  };

  users.push(user);

  writeUsers(users);

  console.log(
    "[USERS] CREATED:",
    user.id
  );

  return user;
}


// ========================================
// UPDATE
// ========================================

export function updateUser(
  userId,
  updates
) {
  const users =
    readUsers({ fresh: true });

  const index =
    users.findIndex(
      user =>
        user.id === userId
    );

  if (index === -1) {
    return null;
  }

  users[index] = {
    ...users[index],
    ...updates,

    id:
      users[index].id,

    updatedAt:
      new Date().toISOString(),
  };

  writeUsers(users);

  return users[index];
}


// ========================================
// DELETE
// ========================================

export function deleteUser(
  userId
) {
  const users =
    readUsers({ fresh: true });

  const next =
    users.filter(
      user =>
        user.id !== userId
    );

  if (
    next.length ===
    users.length
  ) {
    return false;
  }

  writeUsers(next);

  return true;
}

// ========================================
// GET ALL USERS
// ========================================

export function getAllUsers() {
  return readUsers();
}


// ========================================
// GET USERS LINKED ZALO
// ========================================

export function getLinkedUsers() {
  return readUsers().filter(
    user =>
      user.zaloLinked === true
  );
}