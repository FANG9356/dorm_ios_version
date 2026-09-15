# DormiNetX

DormiNetX เป็นระบบจัดการหอพักแบบ local-first สำหรับ iPhone/iPad พร้อม Go backend สำหรับบัญชีผู้ดูแลและการซิงก์ข้อมูลระหว่างเครื่อง ระบบครอบคลุมงานห้องพัก ลูกบ้าน ราคา บิล การรับชำระ หลักฐานการโอน งานซ่อม ผู้ดูแล สำรองข้อมูล และการปรับแต่งแอป

> สถานะ ณ 10 กันยายน 2569: backend hardening และการย้าย LINE webhook ไป `api.dorminet.studio` ถูก deploy แล้ว มี automated tests และ backup/restore drill แต่ **ยังไม่ใช่ production-ready 100%** จนกว่าจะผ่าน device UAT, media transfer, protocol-2 cutover และ provider secret rotation อ่าน [ผล production ล่าสุด](docs/PRODUCTION_HARDENING_2026-09-10.md), [งานการเงิน](docs/FINANCE_HARDENING_2026-09-10.md) และ [ข้อกำหนดระบบหลัก](docs/CORE_HARDENING_2026-09-09.md)

อ่านการประเมินรายหน้าและ roadmap ตั้งต้นได้ที่ [SYSTEM_READINESS_2026-09-09.md](docs/SYSTEM_READINESS_2026-09-09.md) ตัวเลขเปอร์เซ็นต์ในรายงานนั้นเป็นประมาณการก่อนรอบแก้ไขนี้ ไม่ใช่สัดส่วนการทดสอบที่ผ่าน

## จุดประสงค์ของระบบ

- ใช้บัญชีหลักหนึ่งบัญชีต่อหอพัก และแยกข้อมูลภายในเครื่องตามบัญชี
- ให้การทำงานประจำวันใช้ข้อมูลในเครื่องได้ก่อน แล้วค่อยซิงก์ snapshot ขึ้น backend
- ลดการกรอกข้อมูลซ้ำ โดยสร้างรอบบิลรายเดือนจากข้อมูลลูกบ้าน ห้อง และประเภทห้อง
- เก็บประวัติการเงินตามลูกบ้าน แม้มีการย้ายห้อง
- รองรับการแจ้งยอด/ใบเสร็จผ่าน LINE และการแจ้งเตือนเข้าเครื่องในเป้าหมายสุดท้าย

## สิ่งที่มีแล้ว

### แอป iOS

- เข้าสู่ระบบ สมัครบัญชี จดจำบัญชี และรหัสยืนยัน 6 หลักในเครื่อง
- ลืมรหัสผ่าน: ขอรหัสยืนยันทางอีเมล ตั้งรหัสใหม่ และกลับเข้าสู่ระบบ โดยไม่เก็บรหัสผ่าน/OTP ลงเครื่อง
- แยก SwiftData store ตาม `adminID` ป้องกันข้อมูลคนละบัญชีปะปนกัน
- Dashboard แสดงอัตราเข้าพัก ห้องว่าง รายรับ ยอดรอบบิล เงินมัดจำ และบิลค้าง
- จัดการลูกบ้าน: จอง กำลังพักอาศัย ย้ายออก สัญญา มัดจำ ช่องทางชำระ ผ่อนชำระ และแนบสลิปหลายรูป
- เปลี่ยนสถานะจองเป็นกำลังพักอาศัยอัตโนมัติเมื่อถึงวันเข้าอยู่ ขณะเปิด/กลับเข้าแอป
- ตั้งค่าประเภทห้อง ราคา ค่าน้ำ ค่าไฟ ค่าส่วนกลาง ค่าปรับ และสร้างเลขห้อง
- จัดการห้องและย้ายลูกบ้านไปห้องใหม่
- สร้างรายการชำระรายเดือนอัตโนมัติ พร้อมแก้ไข ลบ รับชำระบางส่วน/เต็มจำนวน และแนบสลิปหลายรูป
- เก็บบิลด้วย `userId`; บิลที่ยังไม่ชำระครบตามลูกบ้านเมื่อย้ายห้อง ส่วนบิลที่ชำระแล้วทุกเดือนคงเลขห้องเดิมเป็นประวัติ
- การแก้ทะเบียนลูกบ้านไม่คำนวณทับบิลที่ออกไปแล้ว ต้องแก้รายการการเงินโดยตรง
- ประวัติรายเดือนแสดงหลายบิลในเดือนเดียวกันได้ รวมงวดผ่อนและบิลค่าเช่า
- ฟอร์มการเงินรักษาสตางค์และส่วนต่างบิลเก่า แยกมัดจำในบิลใหม่แบบเต็มจำนวน/จอง ตรวจสถานะกับยอด และไม่ปิดฟอร์มถ้าบันทึกลงเครื่องไม่สำเร็จ
- ตรวจหลักฐานการโอน เปิดดูรูปเต็ม แก้ไข อนุมัติ หรือปฏิเสธ
- แสดงและส่งออกใบเสร็จเป็นภาพ แชร์ บันทึกลง Photos และสั่งพิมพ์
- จัดการงานซ่อม ค่าใช้จ่าย รูปอาการเสีย และสถานะงาน
- สำรอง/กู้คืนข้อมูลในเครื่อง รวมสลิปและพื้นหลังที่กำหนดเอง
- เลือกธีม ไอคอนแอป และพื้นหลังรูป/วิดีโอในเครื่อง
- บันทึกเหตุการณ์สำคัญของระบบ
- เก็บ JWT รหัส 6 หลัก และบัญชีที่จดจำไว้ใน Keychain พร้อมย้ายข้อมูลเดิมและพักรับรหัส 1 นาทีเมื่อกรอกผิด 5 ครั้ง
- ตรวจ expiry/account ID ของเซสชันก่อนเปิด store; การตรวจนี้ไม่แทนการตรวจสิทธิ์และลายเซ็น JWT บนเซิร์ฟเวอร์

### Backend

- Go + SQLite พร้อม authentication, JWT, ผู้ดูแล, users, rooms, room types, payments, maintenance และ logs APIs
- Snapshot sync แยกตามบัญชี พร้อม version/checksum/device ID และตรวจ `base_version` แบบ atomic ป้องกันการเขียนทับจากฐานข้อมูลคนละรุ่น
- ส่ง payload เดิมซ้ำได้เมื่อขาดการตอบกลับ โดยมี outbox บนเครื่องและตรวจ checksum ของข้อมูลจริง
- ระบบ backup ฝั่งเซิร์ฟเวอร์และ scheduler
- มีโค้ด LINE webhook, LIFF linking และการส่งข้อความ/ใบเสร็จในระบบเว็บเดิม
- Password reset เชื่อมจาก iOS แล้ว ตรวจจำนวนครั้งที่ลอง OTP และใช้ OTP ได้ครั้งเดียว โดยเปลี่ยนรหัสผ่านกับใช้สิทธิ์ OTP ใน transaction เดียวกัน
- Session ถูกเก็บและตรวจในฐานข้อมูล เพิกถอนเมื่อเปลี่ยน/รีเซ็ตรหัสผ่าน และ endpoint สาธารณะมี rate limit; OTP lockout เก็บใน SQLite จึงคงอยู่หลัง restart
- Backup ฝั่งเซิร์ฟเวอร์ครอบคลุม master/tenant database พร้อม manifest และ checksum; สิทธิ์จัดการ backup ทั้งระบบแยกเป็น system operator
- LINE webhook production ใช้ `https://api.dorminet.studio/api/webhook/line` แล้ว และ identity เก่าที่จับคู่คนปัจจุบันไม่ได้ถูกพักเป็น `pending_relink`
- การเพิ่มผู้ดูแลจาก iOS ใช้ authenticated staff endpoint ภายใต้หอเดิม ไม่สร้าง superadmin/tenant ใหม่ และไม่มีรหัสเริ่มต้นที่คาดเดาได้

## สิ่งที่ยังไม่เสร็จ

- แอป iOS ยังไม่ได้เชื่อมปุ่ม LINE กับ backend จริง และ snapshot ของแอปยังไม่มี `line_user_id`
- ยังไม่มี APNs/Push Notification และการจัดตาราง local notification
- หน้าเลือกภาษาบันทึกตัวเลือกได้ แต่ยังไม่ได้แปลข้อความด้วย localization resources จริง
- Cloud snapshot ซิงก์เพียงชื่อ/พาธสื่อ ไม่ส่งไฟล์จริง สถาปัตยกรรมกำหนดให้สื่ออยู่ในเครื่องและส่งตรง/relay ชั่วคราว ไม่ฝากไฟล์ถาวรบน backend; การรับส่งสื่อระหว่างเครื่องยังไม่เสร็จ
- การซิงก์เป็น snapshot ทั้งชุด ตรวจพบ conflict และให้เลือกใช้ข้อมูลเซิร์ฟเวอร์หลังสร้าง backup ได้ แต่ยังไม่ merge ระดับ record
- เส้นทางลืมรหัสผ่านยังต้องทดสอบการส่งอีเมลจริงบน staging และ concurrency หลาย instance
- ยังต้องหมุน secret ที่เคยอยู่ใน Git และเพิ่ม regression test ให้ authorization endpoint ที่เหลือ
- Online server restore ถูกปิดไว้แบบ fail closed จนกว่าจะมี maintenance-mode restore ที่ตรวจ manifest และสลับฐานข้อมูล/สื่อแบบ atomic; archive ปัจจุบันผ่าน offline restore drill แล้ว
- มี iOS unit tests, backend tests และ GitHub Actions workflow สำหรับ test/build/analyze แล้ว แต่ยังไม่มี UI automation ครบทุกหน้า; CI จะเริ่มทำงานเมื่อ commit/push
- ต้องทดสอบ Photos, Share Sheet, Print, alternate icons, video background และการซิงก์บน iPhone จริง

## โครงสร้างโปรเจกต์

```text
.
├── DormAppSwift_Sources/
│   ├── DormiNetX/                 # โปรเจกต์ iOS ที่ใช้งานปัจจุบัน
│   │   ├── DormiNetX.xcodeproj
│   │   └── DormiNetX/
│   │       ├── Models/            # SwiftData models
│   │       ├── Services/          # API, sync, รูปสลิป, icon/background
│   │       ├── Components/        # UI components ร่วม
│   │       └── Views/             # หน้าจอทั้งหมด
│   └── Backup_Outer/              # ชุดสำรองเก่า ไม่ใช่ target ปัจจุบัน
├── backend-dorm/                  # Go backend + static web build
└── docs/                          # เอกสารสถานะและ roadmap
```

ชุดทดสอบ iOS อยู่ที่ `DormAppSwift_Sources/DormiNetX/DormiNetXTests` และถูกรวมใน scheme `DormiNetX` แล้ว

## สถาปัตยกรรมข้อมูล

```text
SwiftUI Views
    ↓
SwiftData store แยกตามบัญชี (แหล่งข้อมูลหลักในแอป)
    ↓ บันทึกแล้ว auto-push
SyncManager สร้าง snapshot ทั้งชุด
    ↓ HTTPS + JWT
Go backend /api/sync/*
    ↓
SQLite sync_snapshots แยก account_id และ version
```

การดึงข้อมูลอัตโนมัติจะเกิดเฉพาะเมื่อไม่มี local changes ค้างอยู่และ snapshot จากเครื่องอื่นใหม่ไม่เกิน 120 วินาที ผู้ใช้สามารถสั่งดึงข้อมูลล่าสุดด้วยตนเองได้ เวอร์ชัน/งานที่ยังส่งไม่สำเร็จแยกตามบัญชี ผลตอบกลับของบัญชีเก่าจะไม่ถูกนำไปใช้กับบัญชีใหม่

**ข้อกำหนดการปล่อยรุ่น:** production backend รองรับ `sync_protocol: 2` แล้ว แต่เปิด `ALLOW_LEGACY_SYNC_PUSH=true` ชั่วคราว ต้องอัปเดตและตรวจอุปกรณ์ทุกเครื่องก่อนปิด compatibility flag; แอปจะเก็บข้อมูล local และแจ้งรออัปเดตเมื่อพบ backend ที่ไม่รองรับ protocol ใหม่

## วิธีเปิดและตรวจสอบ

### iOS

ต้องใช้ macOS, Xcode ที่รองรับ deployment target ของโปรเจกต์ และ iOS Simulator/อุปกรณ์ที่รองรับ

```bash
open DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj
```

ตรวจ build จาก command line:

```bash
xcodebuild -quiet \
  -project DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj \
  -scheme DormiNetX \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

รันทดสอบด้วย Simulator แยกจากเครื่องที่มีข้อมูลจริง:

```bash
xcrun simctl list devices available
xcodebuild -quiet \
  -project DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj \
  -scheme DormiNetX \
  -destination 'platform=iOS Simulator,id=<TEST_SIMULATOR_UDID>' \
  -parallel-testing-enabled NO test
```

### Backend

```bash
cd backend-dorm
go test ./...
go test -race ./handlers
go vet ./...
```

Backend ใช้ environment variables เช่น `DB_PATH`, `PORT`, `JWT_SECRET`, `LINE_CHANNEL_ACCESS_TOKEN`, `LINE_CHANNEL_SECRET` และ `RESEND_API_KEY` ตามฟีเจอร์ที่เปิดใช้ ห้าม commit ค่าจริงลง Git

ก่อน `go run .` ให้จัด environment/ฐานข้อมูลทดสอบแยกจาก production และตรวจการโหลด `.env` ก่อนเสมอ ชุด handler tests ด้านบนสร้าง SQLite ชั่วคราวเอง ไม่ต้องเปิดเซิร์ฟเวอร์จริง

## ลำดับพัฒนาต่อ

1. ตรวจและปล่อย sync protocol ใหม่แบบควบคุมรุ่น พร้อมสำรองข้อมูลก่อนอัปเกรดและทดสอบเครื่องเก่า/ใหม่
2. ปิดงาน data safety/security ที่เหลือ: หมุน secret, แผนล้าง secret จาก history, schema migration/recovery, media transfer แบบไม่เก็บถาวร และเพิ่ม tests ของ ledger/สิทธิ์/ทุกหน้าจอ
3. ทดสอบ end-to-end บน iPhone จริงอย่างน้อยสองเครื่องและบัญชีอย่างน้อยสองบัญชี
4. เชื่อม LINE ในแอปกับ backend เดิม พร้อมเก็บการเชื่อมต่อโดย tenant ID ไม่อิงเลขห้องอย่างเดียว
5. เพิ่ม APNs/local notifications สำหรับบิลใกล้ครบกำหนด ค้างชำระ งานซ่อม และผลตรวจสลิป
6. ทำ localization จริงด้วย String Catalog แล้วจึงเปิดหน้าเลือกภาษา
7. ทำ release hardening: accessibility, performance, privacy, retention, monitoring, backup drill และ TestFlight

## เกณฑ์ก่อนใช้งานจริง

ยังไม่ควรถือว่า production-ready จนกว่างาน P0 ในรายงานสถานะจะเสร็จ, ชุดทดสอบผ่าน, ทดสอบกู้คืน backup สำเร็จ และทดสอบข้อมูลข้ามสองเครื่องโดยรูปสลิปไม่หาย
