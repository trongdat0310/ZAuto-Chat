# ZAutoChat: SePay + VPBank, backend chay local

## Pham vi va an toan

- Nhan webhook HMAC-SHA256, doi chieu ngan hang/tai khoan/noi dung/so tien/thoi gian.
- Don hang, bien nhan giao dich va quyen su dung goi duoc ghi trong CUNG giao dich
  file `data/subscriptions.json`, bang lock lien tien trinh + fsync + atomic rename.
- Chi phu hop mot may chu co dia cung ben vung. Khong dung nhieu may/replica, NFS
  hoac dia tam; production lon can transactional database, rate limiter chung va
  cong viec doi soat SePay API. Ban nay KHONG tu polling SePay API/hoan tien.
- Khong log secret, password, chu ky hay noi dung raw webhook. Raw payload duoc luu
  trong data private de doi soat. Bao ve va sao luu data/; khong dua no len GitHub.
- Khong dua toan bo backend port 3000 ra Internet: repo co cac API cu khong bat buoc
  dang nhap. Dung cong thanh toan rieng 3001 duoc gioi han route nhu ben duoi.

## 1. Cap nhat va kiem thu

Trong CMD/PowerShell tai thu muc repo:

```powershell
git status
git fetch origin
git switch refactor/architecture
git pull --ff-only origin refactor/architecture
```

Dung lai neu co thay doi chua luu/xung dot. Khong reset --hard, khong push --force.
Tai `C:\Project\zauto-backend`:

```powershell
npm install
npm run test:payments
```

Khong thay doi dependency; khong can build APK cho backend nay. Neu da co du lieu,
backup data/ va .env truoc khi bat thanh toan. Khong xoa users.json/subscriptions.json.

## 2. Cau hinh .env

Ghep noi dung `.env.payments.example` vao `.env` hien co. Xac nhan so tai khoan
trong SePay la so VPBank thuc te, khong chi la so dien thoai/alias. Vi du:

```dotenv
SEPAY_ENABLED=true
SEPAY_BANK_ACCOUNT=0945785631
SEPAY_ACCOUNT_NAME=PHI TRONG DAT
SEPAY_WEBHOOK_SECRET=THAY_BANG_CHUOI_NGAU_NHIEN_64_KY_TU
PAYMENT_PORT=3001
SEPAY_ORDER_TTL_MINUTES=30
```

Tao khoa rieng tren may ban:

```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Khong gui khoa cho nguoi khac. Secret tren SePay va .env phai giong het nhau.
Khong dung khoa mac dinh/viet vi du. Doi secret se vo hieu hoa token xem don cu;
khach co the tao don moi. Khong doi secret giua luc co giao dich dang cho.

Gia VND mac dinh ke thua bang gia backend truoc do:
monthly30=139000, daily15=299000, daily30=499000, daily55=899000,
unlimited=9999999, extra10=20000, extra30=50000.
Kiem tra gia truoc khi cho khach thanh toan. Co the ghi de bang `SEPAY_PRICES_JSON`.
Khong nhan amount, months, userId hay status tu trinh duyet; moi don goi chinh la 1 thang.

## 3. Chay local va mo tunnel

Giu backend ung dung chay nhu cu (terminal 1):

```powershell
cd C:\Project\zauto-backend
npm start
```

Terminal 2, cung thu muc va .env:

```powershell
cd C:\Project\zauto-backend
npm run payments:local
```

Trang mua goi: `http://127.0.0.1:3001/checkout`.
Gateway dung cung user store/subscription store voi backend, khong khoi dong Zalo
workers hay tao Admin. File SUBSCRIPTIONS_DATA_FILE tuy chinh phai giong nhau.
Websocket cua backend chinh khong nhan broadcast tu process gateway; sau khi paid,
keo xuong Home de nap luot moi (khong can dang xuat).

Cai cloudflared theo tai lieu Cloudflare, sau do terminal 3:

```powershell
cloudflared tunnel --url http://127.0.0.1:3001
```

Cloudflared in URL HTTPS dang `https://TEN-NGAU-NHIEN.trycloudflare.com`.
Khong tunnel port 3000. Khong bat trang login/Access challenge cho webhook, vi
SePay la HTTP client khong the bam/xac minh dang nhap trinh duyet.

Quick Tunnel chi de thu: hostname thay doi khi restart, khong co dam bao uptime.
May Windows phai dang bat, khong sleep, co Internet, gateway va tunnel deu chay.
Dung tunnel co hostname co dinh/VPS de van hanh cho khach that.

## 4. Tao webhook SePay

Trong SePay: Webhooks -> Them webhook:

- Su kien: Co tien vao.
- Ngan hang: chi tai khoan VPBank da lien ket.
- URL: `https://TEN-NGAU-NHIEN.trycloudflare.com/api/payments/sepay/webhook`.
- Body: JSON (`application/json`).
- Bao mat: HMAC-SHA256, Secret Key giong SEPAY_WEBHOOK_SECRET.
- Bat tu dong gui lai khi server loi.
- Luc thu, tat bo loc "Chi gui khi co ma thanh toan" neu chua cau hinh ma ZCA.
  Khi bat bo loc, cau hinh ma dang `ZCA` + 18 ky tu hex (A-F, 0-9), khong co dau cach.

Gateway xac minh `X-SePay-Signature: sha256=...`, `X-SePay-Timestamp` va raw body.
Timestamp chap nhan lech toi da 5 phut. Dong bo dong ho Windows tu dong.
Chi tra HTTP 200 + {"success":true} sau khi luu bien nhan va cap goi hoan tat
HOAC luu giao dich can doi soat. Day la ACK nhan webhook, khong phai luc nao cung paid.
Loi xac thuc: 401; payload sai: 400; loi lock/disk: 503 de SePay gui lai.

## 5. Tao don va thu chuyen khoan

Mo trang `/checkout` tren URL HTTPS vua tao. Nhap so dien thoai tai khoan ZAutoChat
DA DANG KY, chon goi, kiem tra so dien thoai, bam tao don. Trang hien QR VPBank,
so tien va ma duy nhat dang `ZCA...`. Chuyen dung so tien VA noi dung.
Trang poll moi 5 giay; khi du dieu kien se hien thanh cong va goi duoc cap/gia han.
Goi extra10/extra30 co the dung thu khong can goi chinh.

Khong dung QR cu voi memo `ZCA ma-goi so-dien-thoai 1`: no khong gan don moi.
Khong co nut "Da chuyen tien" de tu cap goi; chi webhook da xac thuc moi cap.
QR ngoai loi van co so tai khoan/so tien/noi dung de chuyen khoan thu cong.

Neu muon thu webhook gia lap cua SePay, dung BO DU LIEU VA SECRET THU RIENG,
khong dung don cua khach/secret live: payload test da ky hop le co the cap goi
trong moi truong nhan. Chua co test-mode flag duoc SePay dam bao de tu phan biet.
Unit tests di kem chi dung thu muc tam, khong gui tien/khong goi ngan hang.

## API cho landing/app

- GET `/api/payments/catalog`: bang goi + gia server.
- POST `/api/payments/orders`: `{ "phone":"09...", "planId":"extra10", "requestId":"UUID-cua-client" }`.
  Tra order, bank, accountNumber, accountName, transferContent, qrUrl, checkoutToken.
- GET `/api/payments/orders/:id`, header `X-Checkout-Token`: token tra khi tao don.
  Tra pending / expired / paid, reviewRequired. Khong tra userId/raw bank payload.
- POST `/api/payments/sepay/webhook`: chi SePay, raw JSON + HMAC.

RequestId giu nguyen khi timeout/retry de khong tao don moi. Moi tai khoan toi da
5 don dang mo va 30 don/ngay; public endpoint co gioi han 60 lan tao/phut/process.
API tao don cong khai de ho tro mua goi theo SDT (co the mua ho), khong cap quyen
quan tri. Khong duoc tu doi goi chinh dang con han khac loai bang cach mua ho.

Landing HTML hien tai KHONG bi ghi de trong ban nay. De su dung ngay, cho nut mua
chuyen sang `https://TEN-TUNNEL/checkout?plan=extra10` (doi Plan ID tuong ung).
Hoac dung contract API tren de thay luong QR tinh. Khong thay localhost trong APK
bang dia chi tunnel nay: cong 3001 chi phuc vu thanh toan.

## Quy tac cap goi va doi soat

- Khong co/het goi chinh: cap goi moi tu luc xu ly; han cuoi ngay Viet Nam.
- Dang co cung goi: noi them 1 thang, giu ID/goi/luot da dung.
- Dang co goi chinh khac: tu choi tao don. Neu Admin doi goi trong khi cho tien:
  ghi review, khong ghi de quyen hien tai.
- Extra10/extra30: cong vao tung tinh nang, dung duoc khi chua co goi chinh;
  het han cuoi ngay. Khong ban them luot cho Unlimited dang hoat dong.
- So tien sai, code thieu/trung, sai tai khoan/ngan hang/VA, tai khoan da xoa,
  chuyen ngoai thoi han: khong tu cap goi. Luu reason va payload de doi soat.
- Dung transactionDate (gio VN) xet thoi han, KHONG lay gio webhook den lam gio
  chuyen tien. Chuyen dung han nhung webhook den tre co the duoc chap nhan.
- Rieng add-on den sang ngay VN khac: review, tranh cap nham luot cua ngay khac.
- Mot SePay id / bank reference chi duoc dung mot lan. Mot don chi duoc paid mot lan.
  Code/amount/bank cua giao dich trung ID bi thay doi se bi cach ly.
- Don cu thieu snapshot tai khoan nhan: review, khong tu xu ly bang thong tin moi.

Xem 100 giao dich gan nhat tai local (chi doc, khong in secret/payload):

```powershell
npm run payments:report
```

Kiem tra reason, lich su SePay va giao dich ngan hang truoc khi Admin xu ly thu cong.
Replay mot giao dich review khong tu doi ket qua. Chua co UI xu ly review/hoan tien;
khong sua amount/status trong JSON de ep thanh cong. Can giao dich dung moi hoac
Admin cap goi thu cong sau doi soat, ghi chu ma don/ID giao dich de tranh cap hai lan.

SePay retry tu dong co gioi han (tai lieu hien tai: toi da khoang 33 phut).
Neu local tat lau, mo lai va gui lai giao dich tu lich su SePay. Kiem tra tat ca
giao dich can review truoc khi cho khach mua tiep. Lock ton sau crash: dung cac
process, backup data, kiem tra PID trong file lock; chi xoa lock khi chac chan
khong con process dang ghi. Khong xoa file lock de vuot qua process dang chay.

## Nguon ky thuat

- https://developer.sepay.vn/vi/sepay-webhooks/xac-thuc
- https://developer.sepay.vn/vi/sepay-webhooks/tich-hop-webhook
- https://developer.sepay.vn/vi/sepay-webhooks/xu-ly-loi
- https://developer.sepay.vn/vi/sepay-webhooks/tao-qr-va-form-thanh-toan
- https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/

Kiem thu da chay trong sandbox Linux/Node 22: `npm run test:payments`.
Chua ket noi SePay/VPBank that, chua thu Windows tunnel va toan bo server/Zalo.
