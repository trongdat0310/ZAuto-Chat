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
  if (attempts.size > 10000) {
    for (const [key, time] of attempts) if (now - time > 60 * 60_000) attempts.delete(key);
  }
  const user = findUserByEmail(email);
  if (!user) return;
  // Generate a high-entropy temporary password, never log it.
  const newPassword = crypto.randomBytes(18).toString("base64url") + "aA1!";
  const passwordHash = await bcrypt.hash(newPassword, 12);
  const userName = String(user.name ?? "").trim() || "bạn";
  const subject = "[ZAutoChat] Thông báo cấp lại mật khẩu tài khoản";
  const text = [
    "ZAUTOCHAT | THÔNG BÁO TÀI KHOẢN",
    "",
    `Xin chào ${userName},`,
    "",
    "Chúng tôi đã nhận được yêu cầu khôi phục mật khẩu cho tài khoản ZAutoChat được liên kết với địa chỉ email này.",
    "",
    "Hệ thống đã xử lý yêu cầu và cấp mật khẩu mới cho tài khoản của bạn.",
    "",
    "THÔNG TIN TÀI KHOẢN",
    `Mật khẩu mới: ${newPassword}`,
    "",
    "Bạn có thể sử dụng thông tin trên để đăng nhập vào ứng dụng ZAutoChat.",
    "",
    "LƯU Ý BẢO MẬT",
    "Để đảm bảo an toàn cho tài khoản, chúng tôi khuyến nghị bạn:",
    "- Đăng nhập và thay đổi mật khẩu ngay sau khi nhận được email này.",
    "- Không chia sẻ mật khẩu hoặc thông tin đăng nhập với bất kỳ ai.",
    "- Không sử dụng lại mật khẩu đã từng dùng cho các tài khoản khác.",
    "",
    "Bạn không yêu cầu đặt lại mật khẩu?",
    "Nếu bạn không thực hiện yêu cầu này, vui lòng liên hệ với bộ phận hỗ trợ ZAutoChat để được kiểm tra và hỗ trợ bảo vệ tài khoản.",
    "",
    "Trân trọng,",
    "Đội ngũ ZAutoChat",
  ].join("\n");
  const escapeHtml = value => String(value).replace(/[&<>"\u0027]/g, ch => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\u0022": "&quot;", "\u0027": "&#39;",
  })[ch]);
  const html = `<!doctype html><html lang="vi"><head><meta charset="UTF-8"></head>
<body style="font-family:Arial,sans-serif;background:#f4f6fa;padding:24px;color:#202b3c">
<div style="max-width:640px;margin:auto;background:white;padding:32px;border-radius:12px;line-height:1.7">
<h2 style="color:#17345d">ZAUTOCHAT | THÔNG BÁO TÀI KHOẢN</h2>
<p>Xin chào <strong>${escapeHtml(userName)}</strong>,</p>
<p>Chúng tôi đã nhận được yêu cầu khôi phục mật khẩu cho tài khoản ZAutoChat được liên kết với địa chỉ email này.</p>
<p>Hệ thống đã xử lý yêu cầu và cấp mật khẩu mới cho tài khoản của bạn.</p>
<h3>THÔNG TIN TÀI KHOẢN</h3>
<p><strong>Mật khẩu mới: ${escapeHtml(newPassword)}</strong></p>
<p>Bạn có thể sử dụng thông tin trên để đăng nhập vào ứng dụng ZAutoChat.</p>
<h3>LƯU Ý BẢO MẬT</h3>
<p>Để đảm bảo an toàn cho tài khoản, chúng tôi khuyến nghị bạn:</p>
<ul><li>Đăng nhập và thay đổi mật khẩu ngay sau khi nhận được email này.</li>
<li>Không chia sẻ mật khẩu hoặc thông tin đăng nhập với bất kỳ ai.</li>
<li>Không sử dụng lại mật khẩu đã từng dùng cho các tài khoản khác.</li></ul>
<p><strong>Bạn không yêu cầu đặt lại mật khẩu?</strong></p>
<p>Nếu bạn không thực hiện yêu cầu này, vui lòng liên hệ với bộ phận hỗ trợ ZAutoChat để được kiểm tra và hỗ trợ bảo vệ tài khoản.</p>
<hr><p>Trân trọng,<br><strong>Đội ngũ ZAutoChat</strong></p></div></body></html>`;
  await mailer().sendMail({
    from: process.env.SMTP_FROM,
    to: email,
    subject,
    text,
    html,
  });
  if (!updateUser(user.id, { passwordHash })) {
    throw error("USER_NOT_FOUND", "Tai khoan khong ton tai.", 404);
  }
  attempts.set(email, Date.now());
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
  const updated = updateUser(userId, { email });
  if (!updated) throw error("USER_NOT_FOUND", "Tai khoan khong ton tai.", 404);
  return updated;
}
