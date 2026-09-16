# สถานะพัฒนาระบบหลักหลังอ่านเอกสาร

วันที่: 9 กันยายน 2569

ขอบเขต: local working tree ต่อจาก `e72d13a` บน `feature/local-account-isolation-v2`

เอกสารนี้อัปเดตข้อเท็จจริงจาก README และรายงาน baseline สถานะ deploy และการตรวจ production ที่เกิดภายหลังอยู่ใน [PRODUCTION_HARDENING_2026-09-10.md](PRODUCTION_HARDENING_2026-09-10.md)

> อัปเดต 16 กันยายน 2569: LINE/LIFF, LINE → app media/snapshot sync, same-version self-healing, dirty-record rebase และ maintenance status notification ถูก deploy แล้ว ผลทดสอบปัจจุบัน iOS 44/44 และ backend race/vet ผ่าน ระบบยังเหลือ secret rotation, UAT สองเครื่อง, media ทุก flow, full financial refund/void ledger และ atomic online restore

## งานที่แก้ในรอบนี้

### การเงิน ห้อง และลูกบ้าน

- ใช้ `RoomTransferService` ร่วมกันระหว่างหน้าย้ายห้องกับหน้าแก้ลูกบ้าน
- ตรวจห้องปลายทางและผู้พัก/ผู้จองก่อนย้าย ป้องกันการย้ายไปห้องที่มีคนอยู่
- บิลค้าง/ชำระบางส่วนตามลูกบ้านไปห้องใหม่ บิลที่ชำระแล้วคงเลขห้องเดิม รวมบิลเดือนปัจจุบัน
- การแก้ข้อมูลทะเบียนไม่คำนวณทับรายการที่ออกบิลไปแล้ว ต้องแก้บิลจากหน้าการเงิน กรณีเปลี่ยนแผนผ่อนหลังออกบิลยังต้องพัฒนากระบวนการปรับสัญญาอย่างชัดเจน
- การจับคู่บิลที่มี `userId` จะไม่ใช้เลขห้องเป็นเงื่อนไข OR เพื่อหยิบบิลของคนอื่นมาแก้
- ประวัติรายเดือนแสดงทุกรายการในเดือน ไม่เลือกเฉพาะบิลล่าสุด และเก็บทางเข้าบิลที่อยู่นอกช่วงสัญญาหลังแก้วันที่
- แยก `BillingCycle` ออกจาก View: คำนวณวันที่ครบกำหนดตามวันเข้าอยู่ ปรับ 31 เป็น 28/29/30 ในเดือนสั้นโดยไม่ทำให้เดือนต่อไปเลื่อนตาม
- สัญญาไม่กำหนดสิ้นสุดสร้างรอบถึง 12 เดือนจากปัจจุบัน ไม่หยุดหลังปีแรก; บิลใหม่อัตโนมัติไม่ออกเกินเดือนสิ้นสุดสัญญาที่ระบุ
- แสดงชื่อเดือนภาษาไทยและปี พ.ศ. โดย key ภายในยังเป็น ค.ศ.
- บันทึกรูปใบเสร็จด้วย Photos completion จริง มีสถานะกำลังบันทึก และแจ้งทั้งสำเร็จ/ปฏิเสธสิทธิ์/ล้มเหลว

### Sync และ Backup

- แยก checkpoint ตาม account ID แทน global `lastSyncVersion`
- `base_version` เป็น optimistic concurrency check ใน SQL statement เดียว ถ้าอีกเครื่องมีข้อมูลใหม่จะตอบ 409 ไม่เขียนทับ
- payload แบบ base64 รักษา bytes ที่ใช้ checksum โดยไม่ถูก JSON encoder ของ Go เปลี่ยนรูปแบบวันที่/จำนวนเงิน/ภาษาไทย
- outbox แยกบัญชีที่ `Application Support/DormiNet/SyncOutbox` เก็บ request ที่ยังไม่ได้รับ acknowledgment แบบ atomic
- เมื่อเน็ตหลุดหลังส่ง สามารถส่ง request เดิมซ้ำแม้ปิด/เปิดแอปใหม่ จากนั้นส่งการแก้ไขใหม่ที่เกิดระหว่างรอ
- ไม่ mark clean ให้การแก้ไขที่เกิดหลังเริ่มส่ง และไม่ apply ผลของ session เก่าหลังเปลี่ยนบัญชี
- การดาวน์โหลดตรวจว่าข้อมูล local ไม่ได้เปลี่ยนระหว่างรอ ก่อนแทนที่ SwiftData
- import backup ตรวจ account, format version และ UUID ซ้ำก่อนแทนที่ข้อมูล เพิ่มไฟล์สลิป/รูปงานซ่อมที่มีอยู่จริงใน local backup
- เมื่อ sync ล้มเหลว หน้า backup มีคำสั่ง “ใช้ข้อมูลล่าสุดจากเซิร์ฟเวอร์” ต้องยืนยัน และต้องสร้างไฟล์สำรองข้อมูลเดิมสำเร็จก่อนแทนที่ หาก backup เขียนไม่ได้จะไม่ลบ local data
- ยังไม่ merge ข้อมูลสองเครื่องระดับ record; การเลือกข้อมูลเซิร์ฟเวอร์ไม่รวมการแก้ไขในไฟล์สำรองเข้าด้วยกัน

### ข้อมูลลับและเซสชัน

- JWT, รหัส 6 หลัก และ saved account sessions ย้ายจาก UserDefaults ไป Keychain
- ลบค่าเก่าหลังบันทึก Keychain สำเร็จเท่านั้น เมื่อ migration ล้มเหลวเก็บข้อมูลเก่าไว้และไม่เปิดเซสชันจาก fallback
- ใช้ `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; เป็นข้อมูลของเครื่องนี้ ไม่ใช่ไฟล์สำรองบัญชีหรือสื่อที่ส่งข้ามเครื่อง ดู [เอกสาร Apple](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)
- เมื่อกรอกรหัสผิด 5 ครั้ง พักรับรหัส 60 วินาที เก็บตัวนับใน Keychain เพื่อไม่ให้ปิด/เปิดหน้าจอแล้วเริ่มนับใหม่
- รักษารหัสเดิมระหว่าง migration; รุ่นเก่าที่เปิด gate โดยใช้ default 123456 จะยังใช้รหัสนั้นได้ครั้งแรกหลังอัปเกรด ผู้ใช้ควรเปลี่ยนรหัสในหน้าความปลอดภัย
- หลัง migration แล้ว ถ้ารหัสหาย จะไม่ย้อนกลับไปใช้ 123456 อัตโนมัติ
- ตรวจ expiry และ admin ID ก่อน restore session/open store การตรวจ claims ฝั่งเครื่องไม่ใช่การตรวจลายเซ็น JWT และไม่แทน authorization/revocation บน backend
- รหัส 6 หลักยังเป็น local gate ไม่ใช่ OTP/MFA จากเซิร์ฟเวอร์; การล็อกทุกครั้งเมื่อกลับจาก background และ biometric ยังไม่เสร็จ
- ทดสอบพบ runtime crash ตอนทำลาย instance ของ MainActor class ใน synchronous XCTest จึงกำหนด `nonisolated deinit` เฉพาะ `APIService` และ `CredentialStore` ที่ไม่มี actor-bound cleanup แล้วทดสอบซ้ำผ่าน ดู [Swift issue 85663](https://github.com/swiftlang/swift/issues/85663) ไม่ได้อ้างว่าการแก้นี้พิสูจน์สาเหตุของ crash บนเครื่องผู้ใช้ทุกกรณี

### ลืมรหัสผ่าน

- เปลี่ยน placeholder ใน iOS เป็นขอรหัสทางอีเมล -> กรอกรหัสยืนยันและรหัสผ่านใหม่ -> กลับเข้าสู่ระบบ
- มีช่องรหัสยืนยันพร้อม autofill, ยืนยันรหัสผ่าน, ขอรหัสใหม่, สถานะรอ/ผิดพลาด/สำเร็จ; ไม่บันทึกรหัสผ่านหรือ OTP ลง defaults/Keychain
- API client ตรวจ HTTP status และ JSON response ก่อนแสดงสำเร็จ ไม่ส่ง session token ไป endpoint สาธารณะเหล่านี้
- `/api/reset-password` ตรวจ OTP lockout โดยตรง ไม่อาศัยว่าผู้ใช้ต้องผ่าน `/api/verify-otp` มาก่อน
- การใช้ OTP และเปลี่ยน password hash อยู่ใน transaction เดียวกัน ถ้าเขียนฐานข้อมูลล้มเหลว OTP ไม่ถูกใช้ทิ้ง และ OTP ที่สำเร็จแล้วใช้ซ้ำไม่ได้
- การสร้าง OTP หยุดเมื่อ crypto random ล้มเหลว ไม่ใช้ค่า fallback ที่คาดเดาได้
- ลบบัญชีที่จดจำไว้ของอีเมลนั้นจากอุปกรณ์หลัง reset สำเร็จ และ backend เพิกถอน session ของบัญชีหลังเปลี่ยน/รีเซ็ตรหัสผ่านแล้ว
- ยังไม่ได้ทดสอบส่งอีเมลจริง; backend ตอบข้อความกลางแม้ไม่พบบัญชีหรือผู้ให้บริการอีเมลส่งไม่สำเร็จ เพื่อไม่เปิดเผยการมีบัญชี

## หลักฐานการทดสอบ

มี target `DormiNetXTests` ใน scheme จริง ใช้ SwiftData in-memory, UserDefaults suite แยก, temporary outbox และ mock API ไม่ส่งข้อมูลทดสอบเข้า production

- `CoreDataSafetyTests`: ย้ายห้อง/ใบเสร็จ, ห้องไม่ว่าง, checkpoint, แก้ระหว่างส่ง/ดึง, เปลี่ยนบัญชี, conflict, lost response/restart, checksum ภาษาไทย, backup คนละบัญชี/UUID ซ้ำ และ recovery ต้องสำรองก่อน
- `BillingCycleTests`: เดือนสั้น, leap year, รอบสิ้นสุดสัญญา, สัญญาหลายปี, วันผิดรูปแบบ และปีแสดงผลไทย
- `CredentialStoreTests`: migration, failure, stale defaults, lockout ข้าม instance, missing passcode, validation, session expiry และ Keychain round-trip ด้วย service ชั่วคราว
- `PasswordResetServiceTests`: payload/endpoint, normalize อีเมล, validation ก่อนส่ง, rate limit และ response ผิดรูปแบบ ผ่าน injected transport ไม่ส่งอีเมลจริง
- Backend มี 9 test functions ใช้ SQLite ชั่วคราว: sync 4 กลุ่ม (รวม subtests ตรวจ request) และ password reset 5 กลุ่ม ครอบคลุม account isolation, stale base, exact retry, concurrent writers, OTP lockout/หมดอายุ/ใช้ซ้ำ/rollback

ผลการรันล่าสุดจะบันทึกในหัวข้อปิดรอบด้านล่าง ไม่ใช้ build ผ่านแทนผล UI/E2E

## ข้อกำหนดก่อนปล่อย Sync รุ่นใหม่

1. สำรอง SQLite บนเซิร์ฟเวอร์และ export local backup จากทุกเครื่องที่มีการแก้ไขค้าง รวมถึงตรวจไฟล์สื่อให้เปิดได้
2. ทดสอบ staging ด้วยสำเนาข้อมูลที่ลบข้อมูลส่วนบุคคลก่อน ห้ามใช้ test suite นี้กับฐานข้อมูล production
3. backend ใหม่ต้องตอบ `sync_protocol: 2` จาก `/api/sync/meta` และมี `payload_base64` ใน `/api/sync/latest`
4. แอปใหม่จะไม่ push ไป backend ที่ไม่ประกาศ protocol นี้ ข้อมูลยังบันทึกในเครื่อง
5. backend ใหม่ปฏิเสธ app เก่าที่ไม่มี `base_version` ด้วย HTTP 428 จึงต้องประสานการอัปเดตทุกเครื่องก่อนเปิด sync ใช้งานจริง ไม่ใช่ rolling upgrade แบบไม่มีผลกระทบ
6. checkpoint ใหม่เริ่มแยกบัญชีที่ version 0 ไม่ย้าย global version เก่าที่ระบุบัญชีไม่ได้ เมื่อมี remote snapshot เดิมและ local changes จะพบ conflict ได้ ให้ตรวจ/สำรองก่อนเลือกใช้ข้อมูลเซิร์ฟเวอร์ ห้ามแก้เลข version เองเพื่อข้ามการตรวจ
7. ทดสอบ A/B แก้พร้อมกันและขาดการตอบกลับจริง ยืนยันว่าไม่เขียนทับข้อมูลและสามารถนำ backup กลับมาเปรียบเทียบได้

สถานะข้างต้นเป็นผลของรอบ local hardening เดิม ส่วน backend รุ่นใหม่ถูก deploy ภายหลังแล้วตาม [PRODUCTION_HARDENING_2026-09-10.md](PRODUCTION_HARDENING_2026-09-10.md) การหมุน provider secret และจัดการ Git history ยังไม่เสร็จ

## งานที่ยังต้องทำก่อนใช้จริง

### ลำดับถัดไป: ระบบหลัก

1. Financial ledger/migration: แยก Invoice, PaymentTransaction, Receipt รองรับรับชำระหลายครั้ง แก้แผนผ่อนหลังรับเงิน ย้ายเข้า/จอง/ย้ายออก และการปรับยอดโดยมีประวัติ ไม่แก้ทับหลักฐานที่ออกแล้ว
2. เพิ่ม integration/UI tests ที่กดฟอร์มจริง: เพิ่มลูกบ้าน -> รอบบิล -> รับบางส่วน -> รับครบ -> ใบเสร็จ -> ย้ายห้อง -> ย้ายออก; เทียบ Dashboard/Bills/Transfers กับยอดเดียวกัน
3. คืนไฟล์สื่อเก่าที่อ้าง absolute path ให้เปิดได้หลังย้ายเครื่อง พร้อม transaction/rollback ของไฟล์ backup; ทดสอบไฟล์ใหญ่ ไฟล์เสีย พื้นที่เต็ม และบัญชีแยกกัน
4. Media transfer ตามสถาปัตยกรรม: สื่ออยู่บนเครื่อง รับส่งตรงหรือ relay ชั่วคราวพร้อม ownership/checksum ไม่อัปโหลดถาวรบน backend
5. หมุน provider secret และ JWT ด้วยแผน session cutover แล้วจัดการ secret ใน Git history; ทบทวน authorization ของ endpoint ที่ยังไม่ได้ครอบคลุมด้วย regression test
6. Forgot password: ทดสอบการส่งอีเมลจริงบน staging; ตัวนับ request/failure ย้ายลง SQLite และมี concurrent/persistence tests แล้ว
7. SwiftData schema migration, recovery เมื่อเปิด store ไม่ได้, การล็อกแอปหลัง background และการกู้คืน local passcode ที่หายโดยยืนยันตัวตนจริง
8. ลดงานหนักบน main actor: snapshot/backup ขนาดใหญ่ รูปใบเสร็จและสลิปหลายรูป พร้อม profile บน iPhone รุ่นเป้าหมาย
9. CI + Release build/analyzer + manual UAT บน iPhone จริงสองเครื่อง และ restore drill ก่อน TestFlight

เพิ่ม workflow `.github/workflows/ci.yml` แล้ว ครอบคลุม backend race tests/vet และ iOS tests/Release/analyzer; คำสั่งเทียบเท่าบนเครื่องผ่านทั้งหมด แต่ workflow บน GitHub จะยังไม่เริ่มจนกว่าจะ commit/push

### หลังระบบหลัก

- LINE linking/ส่งบิล/ผลชำระเงินจริง แยก tenant identity จากเลขห้อง พร้อม delivery status/retry
- APNs/local notifications และ permission onboarding
- งานแจ้งซ่อมเต็ม workflow และระบบหลายภาษาด้วย String Catalog

## เกณฑ์ประเมินความพร้อม

ยังไม่เพิ่มเปอร์เซ็นต์เพียงเพราะมีการแก้โค้ด คะแนนเดิม 82/75/64 เป็น baseline เชิงประมาณ ไม่ใช่ coverage หรือ SLA ให้ประเมินใหม่หลัง critical E2E, UAT และ migration/rollback ผ่าน มี automated tests แล้วไม่ได้แปลว่าทุกหน้าจอผ่านทดสอบ

## ปิดรอบการตรวจ

ทดสอบวันที่ 9 กันยายน 2569 บน macOS 15.7.7 ใช้ iPhone 16e Simulator / iOS 26.3.1 แยกจากข้อมูลจริง

| รายการ | ผล |
| --- | --- |
| iOS unit tests | ผ่าน 29/29, ล้มเหลว 0, ข้าม 0 |
| `go test -count=1 -race ./...` | ผ่าน; handlers 9 test functions และ request-validation subtests |
| `go vet ./...` | ผ่าน |
| Debug build ระหว่าง test | ผ่าน; รอบสุดท้ายไม่มี compiler warning ใน output |
| Release build + analyzer | ผ่าน (`generic/platform=iOS Simulator`); ไม่มี warning/error ใน output ของคำสั่งรอบสุดท้าย |
| `git diff --check` | ผ่าน |

ผล XCTest อ้างอิง bundle `Test-DormiNetX-2569.09.09_22-35-32-+0700.xcresult` ใน DerivedData ของเครื่องพัฒนา; ตรวจด้วย `xcresulttool get test-results summary` ไม่ใช่นับจากจำนวนฟังก์ชันใน source อย่างเดียว

### สิ่งที่ต้องทดสอบด้วยมือก่อนปล่อย

1. สำรองข้อมูลจริงก่อน ใช้ staging/ข้อมูลทดสอบสำหรับการทดลองต่อไปนี้ ไม่แก้ข้อมูลลูกบ้านจริงเพื่อทดสอบ
2. เข้าบัญชี A -> เปิดทุกหน้าทันที -> ออกจากระบบ -> เข้าบัญชี B -> ยืนยันว่าข้อมูล/สลิป/backup ของ A ไม่ปรากฏใน B; ทดลองรหัสผิดและปิด/เปิดแอป
3. ขอ OTP ทางอีเมลจริง -> รหัสผิด -> หมดอายุ -> ขอใหม่ -> reset สำเร็จ -> เข้าด้วยรหัสใหม่ ตรวจนโยบาย session เก่าก่อนปล่อย production
4. สร้างผู้จอง -> ถึงวันเข้าอยู่ -> รับบางส่วน -> รับครบ -> ใบเสร็จ -> ย้ายห้อง -> ย้ายออก เทียบยอดทุกหน้ากับรายการเดียวกัน และตรวจบิลที่ชำระแล้วคงห้องเดิม
5. ปฏิเสธ/อนุญาตสิทธิ์ Photos, บันทึกรูป, แชร์, AirPrint, สลิปหลายรูป และไฟล์ใหญ่บน iPhone จริง
6. เครื่อง A/B แก้พร้อมกันและตัดเน็ตกลางส่ง ยืนยันว่าเกิด conflict ที่กู้คืนได้ ไม่เขียนทับเงียบ ๆ และ backup ก่อนเลือกข้อมูลเซิร์ฟเวอร์เปิดได้จริง
7. กู้คืน backup ไปอีกเครื่อง ตรวจทุกรูป/วิดีโอ กรณีนี้ยังมีงาน media-path/transfer ค้างอยู่ จึงยังไม่ผ่านเกณฑ์ release

ไม่มีการ deploy, ส่งอีเมลจริง, เปลี่ยน secret หรือแก้ข้อมูล production ในรอบนี้ งานลำดับแรกถัดไปคือ financial ledger และ migration เพื่อเก็บรายการรับเงิน/มัดจำ/ใบเสร็จแยกจากยอดบิล โดยไม่เปลี่ยนหลักฐานเก่าทับ
