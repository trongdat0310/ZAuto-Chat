import { findUserByPhone } from "../src/users/user-store.js";
// No account is created and no password is printed or changed.
const phone = String(process.argv[2] || "").replace(/\D/g, "").replace(/^84(?=\d{9}$)/, "0");
if (!/^0\d{9}$/.test(phone)) {
  console.error("Usage: node scripts/find-admin-user.js 0911111111");
  process.exitCode = 1;
} else {
  const user = findUserByPhone(phone);
  if (!user) { console.error("Account not found. Create/verify the intended account first."); process.exitCode = 1; }
  else console.log(`ADMIN_USER_ID=${user.id}`);
}
