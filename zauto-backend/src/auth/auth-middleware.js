import jwt from "jsonwebtoken";

import {
  JWT_SECRET,
} from "../config/env.js";

import {
  findUserById,
} from "../users/user-store.js";

import {
  isTokenRevoked,
} from "./revoked-token-store.js";


// ========================================
// REQUIRE AUTH
// ========================================

export function requireAuth(
  req,
  res,
  next
) {
  const authorization =
    req.headers.authorization;


  if (
    !authorization ||
    !authorization.startsWith(
      "Bearer "
    )
  ) {
    return res
      .status(401)
      .json({
        success:
          false,

        error:
          "Chua dang nhap.",
      });
  }


  const token =
    authorization
      .substring(7)
      .trim();


  try {
    const payload =
      jwt.verify(
        token,
        JWT_SECRET
      );

    if (
      isTokenRevoked(
        payload.jti
      )
    ) {
      return res
        .status(401)
        .json({
          success: false,
          error:
            "Phien dang nhap da duoc dang xuat.",
        });
    }


    const userId =
      payload.sub;


    const user =
      findUserById(
        userId
      );


    if (!user) {
      return res
        .status(401)
        .json({
          success:
            false,

          error:
            "Tai khoan khong ton tai.",
        });
    }


    req.user =
      user;

    req.authToken =
      token;

    req.authPayload =
      payload;


    next();

  } catch (error) {

    return res
      .status(401)
      .json({
        success:
          false,

        error:
          "Phien dang nhap khong hop le hoac da het han.",
      });
  }
}