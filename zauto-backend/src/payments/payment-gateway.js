import http from "node:http";
import { readFileSync } from "node:fs";

const checkoutHtml = () => readFileSync(new URL("./checkout.html", import.meta.url));
const checkoutJs = () => readFileSync(new URL("./checkout.js", import.meta.url));

// Only these routes are public through the local tunnel. In particular, do NOT
// proxy /api/zalo, /api/messages, admin routes, .env, or data/ from the main server.
export function createPaymentGateway({ handlers, html = checkoutHtml, js = checkoutJs }) {
  const server = http.createServer(async (req, res) => {
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("Referrer-Policy", "no-referrer");
    res.setHeader("X-Frame-Options", "DENY");
    res.setHeader("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' https://vietqr.app; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
    const response = {
      status(code) { res.statusCode = code; return this; },
      set(key, value) { res.setHeader(key, value); return this; },
      json(data) { res.setHeader("Content-Type", "application/json; charset=utf-8"); res.end(JSON.stringify(data)); },
    };
    try {
      const url = new URL(req.url, "http://localhost");
      const path = url.pathname;
      const request = { headers: req.headers, params: {}, get: name => req.headers[name.toLowerCase()] };
      if (req.method === "GET" && ["/", "/checkout"].includes(path)) {
        res.setHeader("Content-Type", "text/html; charset=utf-8"); res.end(html()); return;
      }
      if (req.method === "GET" && path === "/checkout.js") {
        res.setHeader("Content-Type", "text/javascript; charset=utf-8"); res.end(js()); return;
      }
      if (req.method === "GET" && path === "/health") {
        response.json({ ok: true, service: "zautochat-payments" }); return;
      }
      if (req.method === "GET" && path === "/api/payments/catalog") {
        handlers.catalog(request, response); return;
      }
      const match = path.match(/^\/api\/payments\/orders\/(ZCA[A-F0-9]{18})$/);
      if (req.method === "GET" && match) {
        request.params.id = match[1]; handlers.orderStatus(request, response); return;
      }
      if (req.method !== "POST" || !["/api/payments/orders", "/api/payments/sepay/webhook"].includes(path)) {
        response.status(404).json({ success: false, error: "Not found" }); return;
      }
      if (!/^application\/json(?:;|$)/i.test(req.headers["content-type"] || "")) {
        response.status(415).json({ success: false, error: "Use application/json" }); return;
      }
      if (req.headers["content-encoding"] && req.headers["content-encoding"] !== "identity") {
        response.status(415).json({ success: false, error: "Compressed bodies are not accepted" }); return;
      }
      const maxBytes = path.endsWith("/webhook") ? 65536 : 4096;
      const parts = []; let size = 0;
      for await (const part of req) {
        size += part.length;
        if (size > maxBytes) { response.status(413).json({ success: false, error: "Payload too large" }); return; }
        parts.push(part);
      }
      const raw = Buffer.concat(parts);
      if (path.endsWith("/webhook")) {
        request.body = raw; handlers.webhook(request, response);
      } else {
        try { request.body = JSON.parse(raw.toString("utf8")); }
        catch { response.status(400).json({ success: false, error: "Invalid JSON" }); return; }
        handlers.createOrder(request, response);
      }
    } catch {
      if (!res.headersSent) response.status(503).json({ success: false, error: "Temporarily unavailable" });
      else res.end();
    }
  });
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  server.keepAliveTimeout = 5000;
  return server;
}
