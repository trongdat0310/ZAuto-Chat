import dotenv from "dotenv";

dotenv.config();

const JWT_SECRET =
  process.env.JWT_SECRET;

const JWT_EXPIRES_IN =
  process.env.JWT_EXPIRES_IN ?? "30d";

if (!JWT_SECRET) {
  throw new Error(
    "JWT_SECRET chua duoc cau hinh trong .env"
  );
}

const ZALO_SESSION_KEY =
  process.env.ZALO_SESSION_KEY;

if (
  !ZALO_SESSION_KEY ||
  !/^[0-9a-fA-F]{64}$/.test(
    ZALO_SESSION_KEY
  )
) {
  throw new Error(
    "ZALO_SESSION_KEY phai la 32-byte hex key."
  );
}

export {
  JWT_SECRET,
  JWT_EXPIRES_IN,
  ZALO_SESSION_KEY,
};