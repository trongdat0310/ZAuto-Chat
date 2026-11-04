import bcrypt from "bcryptjs";
import { createUser, findUserByEmail, findUserByPhone, findUserById } from "../users/user-store.js";

const ADMIN_PHONE = "0945785631";
const ADMIN_EMAIL = "trongdat0310@gmail.com";

// Run before the HTTP listener starts. Never trust a public registration to
// become an administrator based solely on a matching email or phone.
export async function bootstrapAdmin(env = process.env) {
  const password = env.ADMIN_INITIAL_PASSWORD;
  const configuredId = String(env.ADMIN_USER_ID || "").trim();
  if (!password) {
    if (configuredId) {
      if (!findUserById(configuredId)) {
        throw new Error("ADMIN_USER_ID does not match a persisted account.");
      }
      return;
    }
    throw new Error("Set ADMIN_INITIAL_PASSWORD (first deployment) or ADMIN_USER_ID (existing admin).");
  }
  if (String(password).length < 12) {
    throw new Error("ADMIN_INITIAL_PASSWORD must be at least 12 characters.");
  }

  const byPhone = findUserByPhone(ADMIN_PHONE);
  const byEmail = findUserByEmail(ADMIN_EMAIL);
  if (byPhone || byEmail) {
    // Explicitly pin the account's immutable ID. Never elevate an account
    // registered earlier just because its phone or email matches.
    if (!configuredId || !byPhone || !byEmail ||
        byPhone.id !== configuredId || byEmail.id !== configuredId) {
      throw new Error("Admin phone/email already exists. Verify ownership and set ADMIN_USER_ID explicitly.");
    }
    return;
  }
  if (configuredId) {
    throw new Error("ADMIN_USER_ID is configured but the bootstrap account does not exist.");
  }

  const passwordHash = await bcrypt.hash(String(password), 12);
  const user = createUser({
    name: "ZAutoChat Admin",
    phone: ADMIN_PHONE,
    email: ADMIN_EMAIL,
    passwordHash,
  });
  // The server-side policy reads this ID; no admin ID or password is sent
  // to clients, and restarting never resets an existing password.
  env.ADMIN_USER_ID = user.id;
  console.log("[ADMIN] Initial administrator created. Save ADMIN_USER_ID in deployment secrets:", user.id);
}
