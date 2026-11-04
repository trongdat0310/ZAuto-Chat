# Goi tai khoan va cham tin nhan de nhan cuoc

Nhanh: `feature/subscriptions-chat-accept-2026-10-14`.
Nhanh nay ke thua nguyen lich su tu `feature/account-subscription-plans`
(commit `4bbcd2e994628a282ceb089dc7228cd58ee95873`), khong sua `main`.
Khong co gia tien, thanh toan hoac tinh nang tu dong nhan cuoc trong dot nay.

## Quy tac

- `trip_screen_accept`: nhan trong man hinh cuoc.
- `chat_accept`: cham vao bong bong tin van ban cua nguoi khac, gui ngay
  `@TenNguoiGui <noi dung nhan cuoc da cau hinh>`; khong can bam Gui lan nua.
- `auto_accept`: chi du phong dinh danh/hạn muc; chua co endpoint/job tu dong.

Moi tinh nang co han muc rieng. Goi ngay reset luc 00:00 Asia/Ho_Chi_Minh.
Goi 30 luot/thang reset theo ngay ky niem bat dau goi (khong phai ngay 1).
Khi cap nhieu thang, moi chu ky thang duoc 30 luot; ngay cuoi thang duoc clamp.
Add-on 10/30 luot can goi chinh con han, het vao nua dem Viet Nam cung ngay.
Dung add-on sap het han truoc, khong tru vao quota thang cua ngay hom sau.

Mot tin goc chi duoc nhan mot lan cho moi tai khoan, ke ca doi man hinh,
doi goi, tai lai ung dung hay qua ngay moi. Nhan mot tin khac se tinh luot moi.
Day la quy tac chong gui/tru trung, khong phai ID ngau nhien do client cung cap.
Gui/tra loi bang o soan tin binh thuong khong tinh luot va khong bi thay doi.

## API

Tat ca endpoint sau yeu cau Bearer token hien tai:

- `GET /api/subscriptions/plans`
- `GET /api/subscriptions/me` (them `isAdmin`, `features` va quota chi tiet)
- `GET /api/subscriptions/me/usage/chat_accept`
- `POST /api/subscriptions/chat/accept`

```json
{"groupId":"111", "msgId":"222", "cliMsgId":"333", "replyText":"ok"}
```

Backend lay ten/UID nguoi gui tu tin nhan luu trong dung tai khoan/nhom.
Client khong chon `userId`, `feature`, `mentions`, `uidFrom` hoac `senderName`.
Khong nhan tu tin cua chinh minh, tin da thu hoi/xoa, media hoac nhom khong thuoc tai khoan.
Cac thao tac media, vuot tra loi, nhan giu va cham quote van do widget cu xu ly.

Endpoint man hinh cuoc hien co van la `POST /api/me/messages/:id/accept`.
Service duoc dung chung ledger voi chat; may chu cu co the tra HTTP 500 cho
loi `ACCEPT_IN_PROGRESS`/`ACCEPT_OUTCOME_UNKNOWN` o endpoint cu, nhung van khong gui lai.

## An toan luot va ket qua khong xac dinh

Truoc khi gui, backend ghi mot reservation vao dia; reservation giu cho,
khong duoc tinh la luot thanh cong. Khi Zalo xac nhan gui, moi cong vao `used`.
Loi truoc khi bat dau gui giai phong reservation. Timeout/loi sau khi bat dau gui
khong chung minh tin chua di: giu reservation o `uncertain`, tu choi gui lai.
Admin phai kiem tra ket qua tren Zalo truoc khi danh dau thanh cong hoac that bai:

`POST /api/subscriptions/admin/users/:id/resolve`

```json
{"targetKey":"<hash from pending>", "outcome":"failed", "note":"Da kiem tra tren Zalo: tin chua duoc gui"}
```

`GET /api/subscriptions/admin/users/:id` tra `pending`.
API resolve chi xu ly `uncertain`, khong giai phong mot yeu cau dang gui.
Neu process chet o giua thao tac, reservation `reserved`/`sending` duoc giu lai,
khong tu reset theo timer. Can dung cac worker va doi soat thu cong truoc khi sua;
chua co UI phuc hoi su co process chet trong dot nay.

Storage JSON dung file lock cho cac mutation ngan va ghi atomic rename.
Chi dung tren mot host voi local disk; KHONG coi day la giao dich phan tan
voi Zalo, multi-host hay network filesystem. Khong tu xoa lock dang ton tai.
Sau khi process crash, dung tat ca backend/worker, sao luu data, xac minh khong
con writer roi moi xoa lock mo coi. Nen chuyen DB truoc khi scale multi-host.
Luu ledger khong gioi han thoi gian de dedupe; can co ke hoach archive/DB khi lon.

V1 duoc backup thanh `subscriptions.json.v1.bak` truoc lan ghi V2 dau tien.
Bo dem V1 duoc migrate bao thu vao goi chinh, vi V1 khong tach luot add-on.
Khong reset hoac xoa lich su khi cap goi moi/thu hoi. Hay sao luu thu muc data
truoc khi thu nghiem/rollback; khong cho ban V1 cu ghi de file V2.

## Cau hinh Admin 0911111111

Khong tao tai khoan, khong dat mat khau, khong cap admin cho bat ky ai tu dang
ky trung so dien thoai. Gan quyen theo ID bat bien cua tai khoan da ton tai:

```sh
cd zauto-backend
node scripts/find-admin-user.js 0911111111
```

Copy dong `ADMIN_USER_ID=...` vao `.env` may chu, khoi dong lai backend.
`.env.subscriptions.example` la mau. Bo fallback hard-code `ADMIN_PHONES` cu.
Khong co `ADMIN_USER_ID` thi cac API admin tu choi truy cap (fail closed).
Script chi doc ID tai khoan; khong hien password/token va khong sua du lieu.

API Admin cap/thu hoi/tim tai khoan giu nguyen duong dan o ban truoc.
Giao dien Admin, gia han rieng va nhan tu dong chua duoc hoan thien trong dot nay.

## Kiem thu va trien khai

```sh
cd zauto-backend
npm run test:subscriptions
# Full existing suite, after installing original project dependencies:
npm ci
npm test

cd ../zauto_driver
flutter pub get
flutter analyze
flutter test test/chat_tap_accept_test.dart
```

Unit tests Node dung file tam va Zalo doubles, KHONG gui tin that.
Can thu Android/iOS voi Zalo that truoc khi phat hanh, dac biet cac gesture,
UI thong bao loi, tag ten co dau/emoji, mat mang, het luot va dong bo lich su cuoc.
Nhan tu chat ghi ledger va gui tin; man hinh cuoc se sua trang thai tu ledger
neu nhan lai cung tin. Chua co realtime dong bo lich su cuoc tu chat trong dot nay.

Reference for mention format (`pos`, `uid`, `len`):
https://zca-js.tdung.com/vi/apis/sendMessage
https://zca-js.tdung.com/vi/get-started/examples/welcome-bot
