import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

import {
  JWT_SECRET,
  JWT_EXPIRES_IN,
} from "../config/env.js";

import {
  createUser,
  findUserByPhone,
} from "../users/user-store.js";

import crypto from "node:crypto";

import {
  validatePassword,
} from "./password-policy.js";


// ========================================
// NORMALIZE PHONE
// ========================================

function normalizePhone(value) {
  let phone =
    String(value ?? "")
      .replace(/\D/g, "");


  // +84xxxxxxxxx
  // => 0xxxxxxxxx
  if (
    phone.startsWith("84") &&
    phone.length >= 11
  ) {
    phone =
      "0" + phone.substring(2);
  }


  return phone;
}


// ========================================
// PUBLIC USER
// ========================================

export function toPublicUser(
  user
) {
  return {
    id:
      user.id,

    name:
      user.name,

    phone:
      user.phone,

    membership:
      user.membership ??
      "free",

    zaloLinked:
      user.zaloLinked === true,

    zaloUserId:
      user.zaloUserId ??
      null,

    createdAt:
      user.createdAt,
  };
}


// ========================================
// CREATE TOKEN
// ========================================

function createToken(user) {
  return jwt.sign(
    {
      sub:
        user.id,

      phone:
        user.phone,
    },

    JWT_SECRET,

    {
      expiresIn:
        JWT_EXPIRES_IN,

      jwtid:
        crypto.randomUUID(),
    }
  );
}


// ========================================
// REGISTER
// ========================================

export async function registerUser({
  name,
  phone,
  password,
}) {
  const cleanName =
    String(name ?? "")
      .trim();

  const cleanPhone =
    normalizePhone(phone);

  const cleanPassword =
    String(password ?? "");


  if (
    cleanName.length < 2
  ) {
    throw new Error(
      "Ho ten khong hop le."
    );
  }


  if (
    cleanPhone.length < 9 ||
    cleanPhone.length > 15
  ) {
    throw new Error(
      "So dien thoai khong hop le."
    );
  }


  if (
    cleanPassword.length < 6
  ) {
    throw new Error(
      "Mat khau phai co it nhat 6 ky tu."
    );
  }


  if (
    findUserByPhone(
      cleanPhone
    )
  ) {
    const error =
      new Error(
        "So dien thoai da duoc dang ky."
      );

    error.code =
      "PHONE_EXISTS";

    throw error;
  }


  const passwordHash =
    await bcrypt.hash(
      cleanPassword,
      12
    );

  const passwordCheck =
    validatePassword(
      password
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


  const user =
    createUser({
      name:
        cleanName,

      phone:
        cleanPhone,

      passwordHash,
    });


  return {
    token:
      createToken(user),

    user:
      toPublicUser(user),
  };
}


// ========================================
// LOGIN
// ========================================

export async function loginUser({
  phone,
  password,
}) {
  const cleanPhone =
    normalizePhone(phone);

  const cleanPassword =
    String(password ?? "");


  const user =
    findUserByPhone(
      cleanPhone
    );


  if (!user) {
    const error =
      new Error(
        "Sai so dien thoai hoac mat khau."
      );

    error.code =
      "INVALID_LOGIN";

    throw error;
  }


  const valid =
    await bcrypt.compare(
      cleanPassword,
      user.passwordHash
    );


  if (!valid) {
    const error =
      new Error(
        "Sai so dien thoai hoac mat khau."
      );

    error.code =
      "INVALID_LOGIN";

    throw error;
  }


  return {
    token:
      createToken(user),

    user:
      toPublicUser(user),
  };
}