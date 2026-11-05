# Ubuntu single-host deployment (pre-production checklist)

These are templates, not evidence that the server is deployed. Use one Node.js instance and a local disk for the current JSON stores. Do not expose port 3000 to the Internet.

## 1. Prepare host

Install Ubuntu Server, Node.js 22 or 24, Git and cloudflared from official packages. Create a dedicated unprivileged user `zchatauto`. Place this repository at `/opt/zchatauto` and give that user ownership of the backend's `data/` directory. Use a non-login service user where practical.

```sh
cd /opt/zchatauto/zauto-backend
npm ci
sudo install -d -m 700 -o zchatauto -g zchatauto data
sudo install -d -m 700 /etc/zchatauto
```

Create `/etc/zchatauto/backend.env` as a root-owned file with mode `0600`. It must contain the actual required secrets and existing app configuration. At minimum, review `JWT_SECRET`, `ZALO_SESSION_KEY`, `ADMIN_USER_ID` (or the documented bootstrap alternative), payment settings and SMTP settings. Never commit this file.

```dotenv
NODE_ENV=production
PORT=3000
CLOUDFLARE_TUNNEL_MODE=true
# JWT_SECRET=...
# ZALO_SESSION_KEY=... (64 hexadecimal characters)
# ADMIN_USER_ID=...
# SEPAY_ENABLED=false
```

Keep `SEPAY_ENABLED=false` until webhook validation and an end-to-end test have passed. Ensure the service user can read the environment file (e.g. use a dedicated group with mode 0640 instead of 0600 if systemd does not load it as root on your setup). **Do not copy real credentials into the repository.**

## 2. Start the backend under systemd

```sh
sudo cp deploy/systemd/zchatauto-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now zchatauto-backend
sudo systemctl status zchatauto-backend
curl -fsS http://127.0.0.1:3000/health
```

The service binds to `127.0.0.1` when `CLOUDFLARE_TUNNEL_MODE=true`. If it fails, inspect `sudo journalctl -u zchatauto-backend -n 100 --no-pager` and fix configuration before continuing.

## 3. Cloudflare Tunnel and DNS

Cloudflare must be authoritative for the hostname's DNS records to use the normal Cloudflare Tunnel public hostname routing. If the domain is registered at iNET, you may keep registration there while switching authoritative nameservers to Cloudflare; confirm the impact on existing DNS, email, and website records first. Alternatively use a Cloudflare-supported DNS arrangement verified for your account. Do not blindly overwrite current iNET records.

Create a **named tunnel** using the official cloudflared setup instructions, store its credentials securely and adapt `deploy/cloudflared/config.yml.example`. Route `api.zchatauto.io.vn` to the tunnel, with origin `http://127.0.0.1:3000`. Keep `cloudflared` managed by systemd. Verify the health endpoint via HTTPS and confirm direct public access to port 3000 is blocked.

Do not put Cloudflare Access interactive login in front of public mobile API or SePay webhook unless clients are explicitly configured to authenticate to Access. Apply WAF/rate limits without breaking signed webhook delivery.

## 4. Payment rollout

Run `npm run test:security` and `npm run test:payments` first. Configure `SEPAY_BANK_ACCOUNT`, `SEPAY_WEBHOOK_SECRET` (at least 32 characters), `SEPAY_ACCOUNT_NAME`, and any relevant price overrides. The current webhook expects `x-sepay-timestamp` and `x-sepay-signature` using HMAC-SHA256 over timestamp + period + raw JSON body; **confirm your SePay delivery or adapter actually supplies these fields**. If not, leave payments disabled and adapt the integration deliberately rather than bypassing signature verification.

Test a small real payment, order amount, transaction reference, duplicate delivery and review workflow before production enablement.

## 5. Backups and recovery

The script `deploy/backup-subscriptions.sh` backs up **only** `data/subscriptions.json`. Run it with permission to read the source and write a protected backup directory. Schedule it via a systemd timer or cron, encrypt off-host copies, rotate old backups and practice restore on a separate machine. Back up the rest of the JSON stores (users, sessions, token revocations, configuration and relevant user data) using a consistent, tested process. Stop the backend or use a coordinated snapshot for a full multi-file backup.

Never restore a backup over a running production instance. Keep a second independent copy off the server.

## 6. Before switching traffic

- Confirm all automated tests pass on the target Node.js version.
- Verify mobile app API/WebSocket base URLs and HTTPS/WSS.
- Check email registration, password reset, JWT rotation, Zalo workers and admin authorization.
- Verify Cloudflare Tunnel origin isolation, firewall, service permissions, logs and backups.
- Validate SePay webhook signature contract and real end-to-end settlement.
