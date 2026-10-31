"use strict";
const $ = id => document.getElementById(id);
const vnd = value => new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND" }).format(value);
let catalog = [], current = null, timer, submitting = false, checking = false, requestId = null;
async function api(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    const res = await fetch(path, { ...options, signal: controller.signal, cache: "no-store" });
    let body;
    try { body = await res.json(); } catch { throw Error("Phan hoi may chu khong hop le."); }
    if (!res.ok || body.success !== true) throw Error(body.error || "Khong the xu ly yeu cau.");
    return body;
  } finally { clearTimeout(timeout); }
}
function status(text, state = "pending") { $("status").textContent = text; $("status").dataset.state = state; }
function save() { try { sessionStorage.setItem("zca-checkout", JSON.stringify(current)); } catch { /* private browser */ } }
function showOrder(value) {
  current = value;
  $("create").hidden = true; $("payment").hidden = false;
  $("order-id").textContent = value.order.id;
  $("amount").textContent = vnd(value.order.amount);
  $("bank").textContent = value.bank; $("account").textContent = value.accountNumber;
  $("owner").textContent = value.accountName; $("memo").textContent = value.transferContent;
  $("expires").textContent = new Date(value.order.expiresAt).toLocaleString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh" }) + " (VN)";
  $("qr-fallback").hidden = true; $("qr").hidden = false;
  $("qr").onerror = () => { $("qr").hidden = true; $("qr-fallback").hidden = false; };
  // Never render arbitrary HTML or load an image URL from local storage unchecked.
  const qr = new URL("https://vietqr.app/img");
  qr.search = new URLSearchParams({ acc: value.accountNumber, bank: "VPBank", amount: String(value.order.amount), des: value.order.id });
  $("qr").src = qr.href;
  status("\u0110ang ch\u1edd ng\u00e2n h\u00e0ng x\u00e1c nh\u1eadn...");
  save(); clearTimeout(timer); poll();
}
async function poll() {
  if (!current || checking) return;
  checking = true; $("check").disabled = true;
  const id = current.order.id;
  try {
    const data = await api("/api/payments/orders/" + encodeURIComponent(id), {
      headers: { "X-Checkout-Token": current.checkoutToken },
    });
    if (current?.order.id !== id) return;
    current.order = { ...current.order, ...data.order }; save();
    if (data.order.status === "paid") {
      status("Thanh to\u00e1n th\u00e0nh c\u00f4ng. G\u00f3i \u0111\u00e3 \u0111\u01b0\u1ee3c c\u1ea5p/gia h\u1ea1n. M\u1edf ZAutoChat v\u00e0 k\u00e9o xu\u1ed1ng Home \u0111\u1ec3 c\u1eadp nh\u1eadt l\u01b0\u1ee3t.", "paid");
      $("qr").hidden = true;
      clearTimeout(timer); return;
    }
    if (data.order.reviewRequired) {
      status("Giao d\u1ecbch c\u1ea7n ki\u1ec3m tra. Li\u00ean h\u1ec7 0945.785.631 v\u00e0 cung c\u1ea5p m\u00e3 \u0111\u01a1n; kh\u00f4ng chuy\u1ec3n ti\u1ec1n l\u1ea7n n\u1eefa.", "review");
    } else if (data.order.status === "expired") {
      status("\u0110\u01a1n \u0111\u00e3 h\u1ebft h\u1ea1n. Kh\u00f4ng chuy\u1ec3n th\u00eam. N\u1ebfu \u0111\u00e3 thanh to\u00e1n, b\u1ea5m ki\u1ec3m tra ho\u1eb7c li\u00ean h\u1ec7 h\u1ed7 tr\u1ee3.", "expired");
      $("qr").hidden = true;
    } else status("\u0110ang ch\u1edd thanh to\u00e1n. Tr\u1ea1ng th\u00e1i t\u1ef1 c\u1eadp nh\u1eadt m\u1ed7i 5 gi\u00e2y.");
    clearTimeout(timer);
    if (data.order.status === "pending") timer = setTimeout(poll, 5000);
  } catch (error) {
    status("Ch\u01b0a k\u1ebft n\u1ed1i \u0111\u01b0\u1ee3c m\u00e1y ch\u1ee7: " + error.message + " Kh\u00f4ng chuy\u1ec3n th\u00eam l\u1ea7n n\u1eefa.", "error");
    clearTimeout(timer);
    timer = setTimeout(poll, 15000);
  } finally { checking = false; $("check").disabled = false; }
}
$("order-form").addEventListener("input", () => { if (!submitting) requestId = null; });
$("plan").addEventListener("change", () => {
  const plan = catalog.find(p => p.id === $("plan").value); $("price").textContent = plan ? vnd(plan.price) : "";
});
$("order-form").addEventListener("submit", async event => {
  event.preventDefault(); if (submitting) return;
  submitting = true; $("submit").disabled = true; $("error").textContent = "";
  try {
    requestId ||= crypto.randomUUID();
    const response = await api("/api/payments/orders", { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phone: $("phone").value.trim(), planId: $("plan").value, requestId }) });
    showOrder(response);
  } catch (error) { $("error").textContent = error.name === "AbortError" ? "Yeu cau qua thoi gian. Hay thu lai; khong chuyen tien khi chua co ma don." : error.message; }
  finally { submitting = false; $("submit").disabled = false; }
});
$("check").addEventListener("click", () => { clearTimeout(timer); poll(); });
$("copy").addEventListener("click", async () => {
  try { await navigator.clipboard.writeText(current.transferContent); $("copy").textContent = "\u0110\u00e3 sao ch\u00e9p"; }
  catch { status("H\u00e3y sao ch\u00e9p th\u1ee7 c\u00f4ng m\u00e3 n\u1ed9i dung chuy\u1ec3n kho\u1ea3n."); }
});
$("new").addEventListener("click", () => {
  clearTimeout(timer); current = null; requestId = null;
  try { sessionStorage.removeItem("zca-checkout"); } catch { /* storage disabled */ }
  $("create").hidden = false; $("payment").hidden = true;
});
async function init() {
  try {
    const data = await api("/api/payments/catalog"); catalog = data.plans;
    for (const plan of catalog) { const option = document.createElement("option"); option.value = plan.id; option.textContent = plan.name; $("plan").append(option); }
    const selected = new URLSearchParams(location.search).get("plan");
    if (catalog.some(p => p.id === selected)) $("plan").value = selected;
    $("plan").disabled = false; $("submit").disabled = false; $("plan").dispatchEvent(new Event("change"));
    let saved;
    try { saved = JSON.parse(sessionStorage.getItem("zca-checkout") || "null"); } catch { /* invalid cached order */ }
    if (saved && /^ZCA[A-F0-9]{18}$/.test(saved.order?.id) && /^[a-f0-9]{64}$/.test(saved.checkoutToken)) showOrder(saved);
  } catch (error) { $("error").textContent = error.message; }
}
init();
