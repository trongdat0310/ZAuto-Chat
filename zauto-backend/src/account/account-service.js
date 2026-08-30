import fs from "node:fs";
import path from "node:path";
import bcrypt from "bcryptjs";
import { fileURLToPath } from "node:url";

import {
  findUserById,
  updateUser,
  deleteUser,
} from "../users/user-store.js";

import {
  stopUserWorker,
} from "../workers/user-worker-manager.js";

import {
  validatePassword,
} from "../auth/password-policy.js";


const __filename =
  fileURLToPath(import.meta.url);

const __dirname =
  path.dirname(__filename);

const userDataRoot =
  path.resolve(
    __dirname,
    "../../data/user-data"
  );


// ========================================
// UPDATE NAME
// ========================================

export function updateAccountName(
  userId,
  name
) {
  const cleanedName =
    String(name ?? "")
      .trim();


  if (
    cleanedName.length < 2 ||
    cleanedName.length > 80
  ) {
    const error =
      new Error(
        "Ten phai tu 2 den 80 ky tu."
      );

    error.code =
      "INVALID_NAME";

    throw error;
  }


  const user =
    findUserById(
      userId
    );


  if (!user) {
    const error =
      new Error(
        "Tai khoan khong ton tai."
      );

    error.code =
      "USER_NOT_FOUND";

    throw error;
  }


  const updated =
    updateUser(
      userId,
      {
        name:
          cleanedName,
      }
    );


  return {
    id:
      updated.id,

    name:
      updated.name,

    phone:
      updated.phone,

    membership:
      updated.membership,

    zaloLinked:
      updated.zaloLinked ===
      true,

    zaloUserId:
      updated.zaloUserId ??
      null,
  };
}


// ========================================
// CHANGE PASSWORD
// ========================================

export async function changeAccountPassword(
  userId,
  currentPassword,
  newPassword
) {
  const user =
    findUserById(
      userId
    );


  if (!user) {
    const error =
      new Error(
        "Tai khoan khong ton tai."
      );

    error.code =
      "USER_NOT_FOUND";

    throw error;
  }


  if (
    typeof currentPassword !==
      "string" ||
    !currentPassword
  ) {
    const error =
      new Error(
        "Vui long nhap mat khau hien tai."
      );

    error.code =
      "CURRENT_PASSWORD_REQUIRED";

    throw error;
  }


  const passwordCheck =
    validatePassword(
      newPassword
    );


  if (!passwordCheck.valid) {

    const error =
      new Error(
        passwordCheck.error
      );

    error.code =
      "WEAK_PASSWORD";

    throw error;
  }


  const correct =
    await bcrypt.compare(
      currentPassword,
      user.passwordHash
    );


  if (!correct) {
    const error =
      new Error(
        "Mat khau hien tai khong dung."
      );

    error.code =
      "WRONG_PASSWORD";

    throw error;
  }


  const samePassword =
    await bcrypt.compare(
      newPassword,
      user.passwordHash
    );


  if (samePassword) {
    const error =
      new Error(
        "Mat khau moi phai khac mat khau hien tai."
      );

    error.code =
      "SAME_PASSWORD";

    throw error;
  }


  const passwordHash =
    await bcrypt.hash(
      newPassword,
      12
    );


  updateUser(
    userId,
    {
      passwordHash,
    }
  );


  return {
    success: true,
  };
}


// ========================================
// DELETE ACCOUNT
// ========================================

export async function deleteAccount(
  userId,
  password
) {
  const key =
    String(userId);


  const user =
    findUserById(
      key
    );


  if (!user) {
    const error =
      new Error(
        "Tai khoan khong ton tai."
      );

    error.code =
      "USER_NOT_FOUND";

    throw error;
  }


  if (
    typeof password !==
      "string" ||
    !password
  ) {
    const error =
      new Error(
        "Can nhap mat khau de xac nhan xoa tai khoan."
      );

    error.code =
      "PASSWORD_REQUIRED";

    throw error;
  }


  const correct =
    await bcrypt.compare(
      password,
      user.passwordHash
    );


  if (!correct) {
    const error =
      new Error(
        "Mat khau khong dung."
      );

    error.code =
      "WRONG_PASSWORD";

    throw error;
  }


  // ========================================
  // 1. STOP ZALO WORKER
  // ========================================

  try {
    await stopUserWorker(
      key
    );
  } catch (error) {

    console.warn(
      "[DELETE ACCOUNT] STOP WORKER ERROR:",
      key,
      error?.message ??
      error
    );
  }


  // ========================================
  // 2. DELETE ALL USER DATA
  // ========================================

  const userDir =
    path.join(
      userDataRoot,
      key
    );


  if (
    fs.existsSync(
      userDir
    )
  ) {
    fs.rmSync(
      userDir,
      {
        recursive: true,
        force: true,
      }
    );
  }


  // ========================================
  // 3. DELETE APP USER
  // ========================================

  deleteUser(
    key
  );


  console.log(
    "[DELETE ACCOUNT] SUCCESS:",
    key
  );


  return {
    success: true,
  };
}