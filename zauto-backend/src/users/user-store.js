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

function readUsers() {
  if (!fs.existsSync(usersPath)) {
    return [];
  }

  try {
    const data =
      JSON.parse(
        fs.readFileSync(
          usersPath,
          "utf-8"
        )
      );

    return Array.isArray(data)
      ? data
      : [];

  } catch (error) {
    console.error(
      "[USERS] Khong doc duoc users.json"
    );

    return [];
  }
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
}


// ========================================
// FIND
// ========================================

export function findUserById(
  userId
) {
  return (
    readUsers().find(
      user =>
        user.id === userId
    ) ?? null
  );
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
}) {
  const users =
    readUsers();

  const now =
    new Date().toISOString();

  const user = {
    id:
      crypto.randomUUID(),

    name,
    phone,
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
    readUsers();

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
    readUsers();

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