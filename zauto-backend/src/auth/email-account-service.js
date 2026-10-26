import bcrypt from "bcryptjs";
import crypto from "node:crypto";
import nodemailer from "nodemailer";
import { findUserByEmail, findUserById, updateUser } from "../users/user-store.js";

const emailValid = value => typeof value === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) && value.length <= 254;
const normalize = value => String(value ?? "").trim().toLowerCase();
const error = (code, message, status = 400) => Object.assign(new Error(message), { code, status });
const attempts = new Map();

function mailer() {
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_FROM } = process.env;
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASSWORD || !SMTP_FROM) throw error("MAIL_NOT_CONFIGURED", "SMTP chua duoc cau hinh.", 503);
  return nodemailer.createTransport({
    host: SMTP_HOST, port: Number(SMTP_PORT || 587),
    secure: Number(SMTP_PORT || 587) === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASSWORD },
  });
}

export async function requestPasswordRecovery(value) {
  const email = normalize(value);
  if (!emailValid(email)) return;
  const now = Date.now();
  const previous = attempts.get(email) || 0;
  if (now - previous < 5 * 60_000) return;
  attempts.set(email, now);
  if (attempts.size > 10000) {
    for (const [key, time] of attempts) if (now - time > 60 * 60_000) attempts.delete(key);
  }
  const user = findUserByEmail(email);
  if (!user) return;
  // Generate a high-entropy temporary password, never log it.
  const newPassword = crypto.randomBytes(18).toString("base64url") + "aA1!";
  const passwordHash = await bcrypt.hash(newPassword, 12);
  await mailer().sendMail({
    from: process.env.SMTP_FROM, to: email,
    subject: "ZAutoChat - Mat khau moi",
    text: "Mat khau moi cua ban: " + newPassword + "\nHay dang nhap va doi mat khau ngay.",
  });
  updateUser(user.id, { passwordHash });
}

export async function changeAccountEmail(userId, value, password) {
  const email = normalize(value);
  if (!emailValid(email)) throw error("INVALID_EMAIL", "Email khong hop le.");
  const user = findUserById(userId);
  if (!user) throw error("USER_NOT_FOUND", "Tai khoan khong ton tai.", 404);
  if (!password || !await bcrypt.compare(String(password), user.passwordHash)) {
    throw error("WRONG_PASSWORD", "Mat khau khong dung.", 403);
  }
  const existing = findUserByEmail(email);
  if (existing && existing.id !== userId) throw error("EMAIL_EXISTS", "Email da duoc su dung.", 409);
  return updateUser(userId, { email });
}
