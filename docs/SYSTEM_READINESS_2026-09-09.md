# รายงานความสมบูรณ์และความพร้อม DormiNetX

> รายงานนี้เป็น baseline ก่อนรอบ hardening ของวันที่เดียวกัน รายการ “ไม่มี tests”, “เก็บ token ใน UserDefaults”, “ไม่มี conflict protection” และ “save รูปแจ้งสำเร็จทันที” ด้านล่างได้รับการแก้ไขในโค้ดแล้ว อ่านผลปัจจุบันและข้อจำกัดที่ยังเหลือใน [CORE_HARDENING_2026-09-09.md](CORE_HARDENING_2026-09-09.md) ไม่ใช้คะแนนเดิมเป็นผลรับรองรุ่นใหม่

> **อัปเดต 16 กันยายน 2569:** ผลประเมิน production readiness ปัจจุบันคือ **78%** และ controlled-pilot readiness **88%** ตัวเลข 82/75/64 ใน baseline นี้ไม่ใช่สถานะปัจจุบัน ให้ใช้ [CURRENT_STATUS_2026-09-16.md](CURRENT_STATUS_2026-09-16.md), [PRODUCTION_HARDENING_2026-09-10.md](PRODUCTION_HARDENING_2026-09-10.md) และภาคผนวกล่าสุดใน `project-review/` สำหรับการตัดสินใจ

วันที่ประเมิน: 9 กันยายน 2569

Branch: `feature/local-account-isolation-v2`

Commit ที่ตรวจ: `e72d13a`

ขอบเขต: แอป iOS ใน `DormAppSwift_Sources/DormiNetX` และ backend ใน `backend-dorm`

## สรุปสำหรับตัดสินใจ

| มิติ | คะแนน | ความหมาย |
|---|---:|---|
| ความครบของฟีเจอร์ที่มองเห็น | 82% | หน้าหลักและ flow ธุรกิจส่วนใหญ่มี implementation แล้ว |
| ความพร้อมของระบบหลักแบบไม่รวม LINE/ภาษา | 75% | ใช้งานในเครื่องเดียวได้ค่อนข้างครบ แต่ยังต้องทดสอบข้อมูลจริงและ hardening |
| ความพร้อมใช้งาน production ทั้งระบบ | **64%** | ยังติดเรื่อง tests, security, media sync, LINE/Push และการทดสอบหลายเครื่อง |

คะแนน 64% ไม่ได้หมายความว่าหน้าจอทำงานเพียงครึ่งเดียว แต่หมายถึงระบบยังไม่มีหลักฐานเพียงพอว่าจะรักษาข้อมูลและทำงานได้ถูกต้องเมื่อใช้จริงต่อเนื่อง หลายบัญชี หลายเครื่อง และเกิด network/error conditions

การให้คะแนนพิจารณาจาก implementation ที่มีจริง, ความถูกต้องของกฎธุรกิจ, ความปลอดภัย/ความคงทนของข้อมูล, หลักฐานจากการทดสอบ และความพร้อมด้านการปฏิบัติการ คะแนนนี้จึงเป็น baseline สำหรับวางงาน ไม่ใช่ตัวเลขรับรองคุณภาพ และควรอัปเดตทุกครั้งที่ปิดงาน P0/P1 หรือมีผล UAT ใหม่

## ผลตรวจล่าสุด

| การตรวจ | ผล |
|---|---|
| iOS Debug build | ผ่าน |
| iOS Release build | ผ่าน |
| Xcode static analyzer | ผ่าน ไม่มี output เตือน |
| iOS unit/UI tests | รันไม่ได้ เพราะ scheme ไม่มี test action/ไม่มี test target |
| Backend `go test ./...` | ผ่านการ compile ทุก package แต่ทุก package รายงาน `[no test files]` |
| Backend `go vet ./...` | ผ่าน |
| Production health endpoint | `https://api.dorminet.studio/api/system/ping` ตอบ HTTP 200 และ `{"status":"online"}` ณ เวลาประเมิน |
| ทดสอบเปิดแอปบน Simulator | เคยผ่านถึงหน้า Login; ยังไม่ใช่ end-to-end test |
| ทดสอบ iPhone จริงสองเครื่อง | ยังไม่ได้ทำ |

เหตุการณ์ crash ที่เคยเห็นใน Simulator เป็น process `MobileCal` (`com.apple.mobilecal`) ของ Calendar ไม่ใช่ `DormiNetX` และไม่พบ crash report ชื่อ DormiNetX ในการตรวจครั้งนั้น อย่างไรก็ตามสิ่งนี้ไม่ได้ทดแทน crash testing ระยะยาวของแอป

## หลักการของระบบปัจจุบัน

### แหล่งข้อมูล

- SwiftData ในเครื่องเป็นแหล่งข้อมูลหลักของแอป
- แต่ละบัญชีใช้ไฟล์ `account_<adminID>.store` แยกกัน
- ตอน logout ใช้ in-memory guest store เพื่อตัด context ของบัญชีก่อนหน้า
- หลังแก้ข้อมูล แอปบันทึก local ก่อนแล้ว auto-push snapshot ขึ้น server
- เมื่อไม่มี local changes ค้าง แอปอาจ auto-pull snapshot จากเครื่องอื่นที่ใหม่ไม่เกิน 120 วินาที
- Manual pull เขียนทับข้อมูล local ทั้งชุดด้วย snapshot ล่าสุด

### ข้อมูลที่อยู่ใน snapshot

- ห้อง
- ประเภทห้องและราคา
- ลูกบ้าน
- รายการชำระ/บิล
- งานซ่อม
- บันทึกระบบ

### ข้อมูลที่ไม่ถูกส่งเป็นไฟล์ใน cloud snapshot

- รูปสลิปของลูกบ้านและรายการชำระ
- รูป/วิดีโอพื้นหลังแอป
- รูปโปรไฟล์ผู้ดูแลที่บันทึก local

Snapshot เก็บเพียง string path ของสื่อเหล่านี้ ดังนั้น path อาจถูกดึงไปเครื่องใหม่แต่ไฟล์จริงไม่อยู่ การสำรองข้อมูลแบบ local export ต่างออกไป เพราะรวม binary ของสลิปและพื้นหลังไว้แล้ว

## ความพร้อมรายส่วน

| ส่วน | คะแนน | มีแล้ว | ยังขาด/ต้องพิสูจน์ |
|---|---:|---|---|
| Login และ session | 75% | Login, register, saved account, รหัส 6 หลัก, แยก store ตามบัญชี | Forgot password ไม่ต่อ iOS, ไม่ validate token ตอนเปิดแอป, token อยู่ UserDefaults, ต้อง test token หมดอายุ |
| Dashboard | 85% | KPI และกราฟจาก SwiftData, refresh ตาม data key | ต้องเทียบตัวเลขกับ ledger จริงและ test empty/large dataset |
| จัดการลูกบ้าน | 84% | เพิ่ม/แก้ไข/สถานะ/สัญญา/จอง/ย้ายออก/ผ่อน/สลิปหลายรูป | ต้อง test validation, duplicate room/tenant และวันขอบเขตทั้งหมด |
| การเปลี่ยนสถานะจอง | 76% | เปลี่ยนเป็นกำลังพักอาศัยเมื่อ `moveInDate <= today` ตอนเปิด/กลับเข้าแอป | ไม่ใช่ background job; ถ้าไม่เปิดแอปจะยังไม่เปลี่ยนจนเปิดครั้งต่อไป |
| ตั้งค่าราคา | 88% | ประเภทห้อง ราคา ค่าใช้จ่าย มัดจำขั้นต่ำ 5% สร้างเลขห้อง | ต้องป้องกันชื่อประเภทซ้ำ/เลขห้องซ้ำและ test การแก้ราคากับบิลเดิม |
| จัดการห้อง | 86% | สถานะว่าง/มีผู้พัก แก้ไขห้อง ย้ายลูกบ้าน | ต้อง test ย้ายไปห้องมีผู้พักพร้อมกันและ race จากหลายเครื่อง |
| การเงินและชำระเงิน | 82% | สร้างรอบเดือนอัตโนมัติ, สรุปยอด, filter, edit/delete, pending/partial/paid | ต้อง test สูตรทุกสถานะ, due date สิ้นเดือน, rounding, timezone และ duplicate generation |
| แผนผ่อนชำระ | 78% | คำนวณจำนวนงวดและยอดต่องวด สร้างรายการแยก phase | ต้องกำหนดนโยบายเมื่อแก้จำนวนงวดหลังรับเงิน และ test ผลรวมเศษสตางค์ |
| การย้ายห้องกับบิล | 82% | บิลใช้ stable local user ID; บิลค้าง/อนาคตตามห้องใหม่ บิลอดีตที่ชำระแล้วเก็บห้องเดิม | ไม่มี entity ประวัติการย้ายห้องโดยตรง; ควรเก็บ tenancy/room assignment history |
| บิลค่าใช้จ่าย | 78% | รายการบิลและ swipe/context actions | ต้องยืนยันความหมาย “เข้า-ออก” ให้ไม่ซ้ำกับ Finance และ test gesture กับ sidebar |
| หลักฐานการโอน | 82% | หลายรูป, preview เต็ม, แก้ไข/อนุมัติ/ปฏิเสธ | ไฟล์ไม่ตาม cloud snapshot, ต้อง test รูปใหญ่/ไฟล์เสีย/permission denied |
| ใบเสร็จ | 80% | แบบไทย, render เป็นภาพ, share/save/print | save แจ้งสำเร็จทันทีโดยไม่มี completion callback; ต้อง test Share Sheet/Photos/Print บนเครื่องจริง |
| แจ้งซ่อม | 66% | เพิ่ม/แก้ไข/ลบ สถานะ ค่าใช้จ่าย รูปปัญหา | สื่อยังเป็น path เดี่ยว, iOS ยังไม่ต่อ LINE/tenant workflow เต็ม, ไม่มี SLA/ผู้รับงาน |
| ผู้ดูแลระบบ | 72% | list/add/edit/delete, role, เปลี่ยนรหัสผ่าน, รูปโปรไฟล์ local | ต้อง test authorization ทุก role, รูปไม่ sync, API error handling ยังไม่สม่ำเสมอ |
| โทเคน/รหัส 6 หลัก | 60% | เปิด/ปิด สุ่ม/ตั้งค่า และถามก่อนเข้าแอป | เป็น local gate ไม่ใช่ MFA; เก็บ UserDefaults; ไม่มี lockout/biometric/rate limit |
| ไอคอนแอป | 76% | standard/light/dark/minimal และ preview | alternate icon ต้องยืนยันบน iPhone จริงและ iOS อาจแสดง system confirmation |
| พื้นหลังแอป | 75% | system animated background, รูปและวิดีโอ local | memory/performance ของวิดีโอยังไม่ profile, custom media ไม่ sync cloud |
| สำรองและกู้คืน | 78% | local export/import, รวมสลิปและพื้นหลัง, reset local | ต้อง test backup ขนาดใหญ่, corrupted file, version migration และ restore drill |
| บันทึกระบบ | 68% | บันทึก action สำคัญและแสดงย้อนหลัง | ไม่มี actor/admin attribution ที่ครบ, retention/filter/export และ tamper protection |
| จัดการภาษา | 20% | เลือก system/th/en และจำค่าที่เลือก | ข้อความส่วนใหญ่ hard-coded; ยังไม่มี String Catalog/Localizable strings และ locale switching จริง |
| LINE | 35% | backend เว็บเดิมมี webhook, LIFF และ push helpers | ปุ่ม iOS แค่เขียน log “รอเชื่อมต่อ LINE”; snapshot ไม่มี LINE identity; ยังไม่ E2E |
| การแจ้งเตือนเข้าเครื่อง | 5% | มี haptic feedback บางจุด | ไม่มี APNs entitlement, device token, notification service หรือ local schedule |
| Cloud sync | 60% | account snapshot, version, checksum, device ID, auto-push/manual pull | whole-snapshot last-write-wins, ไม่มี record conflict UI, สื่อไม่ตาม, ต้อง soak test |
| Automated testing | 15% | build/analyze/vet ผ่าน | ไม่มี test files และ test target |

## Flow การเงินที่ระบบทำอยู่

1. สร้างประเภทห้องและกำหนดค่าเช่า/ค่าใช้จ่าย
2. เพิ่มห้องและผูกประเภทห้อง
3. เพิ่มลูกบ้าน เลือกสถานะ วันที่เข้าอยู่ รูปแบบชำระ และมัดจำ
4. ค่าเริ่มต้นเงินมัดจำคือ 5% และ UI จำกัดไม่ให้ต่ำกว่า 5%; ผู้ดูแลปรับขึ้นได้ถึง 100%
5. ถ้าเป็นผู้พักอาศัย เดือนแรกคิดค่าเช่า + มัดจำ ส่วนเดือนต่อไปคิดค่าเช่าตามประเภทห้อง
6. ถ้าเป็นการจอง รอบเริ่มต้นคิดเงินจอง/มัดจำตามข้อมูลลูกบ้าน
7. ถ้าเลือกผ่อน ระบบแบ่งยอดแรกเข้าเป็นจำนวนงวดและสร้าง payment records แยกงวด
8. ค่าน้ำ ค่าไฟ ค่าส่วนกลาง อุปกรณ์เสริม และค่าปรับเป็นองค์ประกอบของบิล แก้ไขได้ในรายการชำระ
9. สถานะ `pending` คือยังไม่ได้รับเงิน, `partial` คือรับบางส่วนและยังมียอดคงเหลือ, `paid` คือปิดบิล
10. เมื่อเลือก paid/partial ระบบเติมวันที่ชำระเป็นวันที่ปัจจุบันถ้ายังไม่มีวันที่

### ข้อจำกัดของโมเดลการเงิน

- `Payment.userId` เป็น `Int` ที่คำนวณจาก UUID ฝั่ง local ไม่ใช่ SwiftData relationship หรือ UUID โดยตรง
- `roomNumber` ถูกเก็บซ้ำใน payment เพื่อแสดงประวัติและช่วยรองรับข้อมูลเก่า
- ยังไม่มีโมเดล `Tenancy`, `RoomAssignment`, `Invoice`, `PaymentTransaction` และ `Receipt` แยกกัน จึงทำให้หนึ่ง record แบกรับหลายความหมาย
- การรับเงินหลายครั้งในบิลเดียวเก็บเป็นยอดรวม `paidAmount` ไม่ใช่ transaction ledger ทีละรายการ
- การแก้/ลบ payment อาจกระทบ auditability เพราะ system log ไม่ใช่ immutable accounting audit log

สำหรับ production ควรแยก Invoice ออกจาก PaymentTransaction เพื่อให้เก็บว่าใครจ่าย เมื่อไร ช่องทางใด สลิปใด และยอดเท่าไรในแต่ละครั้งได้แม่นยำ รวมทั้งสร้าง Receipt จาก transaction ที่รับเงินจริง

## ความเสี่ยงสำคัญ

### P0: ต้องแก้ก่อน production

1. **Secret ใน Git:** `backend-dorm/.env` ถูก track อยู่ แม้ `.gitignore` จะ ignore แล้ว ต้องถอนจาก index/history อย่างระมัดระวังและ rotate `JWT_SECRET`, LINE token/secret, email API key และ credential อื่นทั้งหมด ห้ามเพียงลบไฟล์ใน working tree แล้วถือว่าจบ
2. **ไม่มี automated tests:** การเงิน การย้ายห้อง และ sync มี branch จำนวนมากแต่ไม่มี regression protection
3. **ไฟล์สื่อไม่ sync ข้ามเครื่อง:** รูปสลิปเป็นหลักฐานทางการเงิน จึงยอมให้หายเมื่อเปลี่ยนเครื่องไม่ได้
4. **Whole-snapshot conflict:** เครื่องสองเครื่องแก้พร้อมกันอาจเขียนทับข้อมูลอีกเครื่อง ไม่มี merge/conflict resolution ระดับ record
5. **ข้อมูลลับใน UserDefaults:** JWT และรหัส 6 หลักควรอยู่ Keychain; ต้องมี token expiry/revocation validation
6. **Recovery path:** `DormApp.swift` ยังมี `fatalError` หากสร้าง guest ModelContainer ไม่ได้ และยังไม่มีหน้ากู้คืนฐานข้อมูลที่เปิดไม่ได้
7. **Deployment target:** โปรเจกต์กำหนด `IPHONEOS_DEPLOYMENT_TARGET = 26.2`; ต้องยืนยันว่าเป็นช่วงอุปกรณ์เป้าหมายจริง มิฉะนั้นผู้ใช้ iOS รุ่นก่อนติดตั้งไม่ได้

### P1: ต้องเสร็จก่อน pilot จริง

1. สร้าง accounting ledger แยก Invoice / PaymentTransaction / Receipt และ migration จาก Payment เดิม
2. เชื่อม forgot password iOS กับ `/api/forgot-password`, `/api/verify-otp`, `/api/reset-password`
3. เพิ่ม validation: ห้องซ้ำ, ผู้พักซ้ำ, ห้องถูกครอบครอง, วันที่ไม่สมเหตุผล, จำนวนเงินติดลบ, paid amount เกินยอด
4. เพิ่ม error UI ที่มองเห็นได้แทนการ `print` อย่างเดียว และ retry queue เมื่อ auto-push ล้มเหลว
5. เปลี่ยนการบันทึกรูปใบเสร็จให้ใช้ completion callback แล้วแจ้งผลจริง
6. เพิ่ม schema migration/versioning ทั้ง SwiftData, snapshot และ SQLite
7. ตรวจ authorization ทุก backend endpoint และทำ rate limit สำหรับ login/OTP/LIFF
8. เพิ่ม structured logs, server monitoring, backup retention และ restore drill
9. Profile การสร้างบิล, render ใบเสร็จ, รูปหลายใบ และ video background บนอุปกรณ์ RAM ต่ำ

### P2: ฟีเจอร์ที่ตกลงทำหลังระบบหลัก

1. LINE linking ต่อ tenant/tenancy ID ไม่ผูกกับเลขห้องอย่างเดียว
2. ส่งบิลใกล้ครบกำหนด ค้างชำระ ใบเสร็จ ผลตรวจสลิป และสถานะงานซ่อมผ่าน LINE
3. APNs และ local notifications พร้อม permission onboarding และการตั้งเวลาแจ้งเตือน
4. Localization จริงด้วย `.xcstrings` และทดสอบข้อความ/ตัวเลข/วันที่ทุกภาษา

## Roadmap ไปสู่ 100%

### ระยะ 1: Data safety และ security

เป้าหมาย: ข้อมูลไม่ปะปน ไม่หาย และ credential ไม่รั่ว

- จัดการ `.env` ที่ถูก track และ rotate secrets
- ย้าย token/passcode ไป Keychain
- ทำ media transfer แบบ peer-to-peer หรือ relay ชั่วคราว พร้อม checksum/ownership; ไม่เก็บรูปหรือวิดีโอถาวรบน backend ตามสถาปัตยกรรมโครงการ
- เพิ่ม sync operation queue, retry/backoff และ conflict strategy
- ทำ migration และ recovery UI
- เพิ่ม `.env.example` ที่มีเฉพาะชื่อ key

เกณฑ์ผ่าน: ทดสอบบัญชี A/B บนเครื่องเดียวและสองเครื่องแล้วข้อมูล/สื่อไม่ข้ามบัญชีหรือสูญหาย

### ระยะ 2: Automated test foundation

เป้าหมาย: ทุกการแก้โค้ดตรวจ regression ได้

- เพิ่ม iOS unit test target และ UI test target
- แยก calculator/services ออกจาก View เพื่อทดสอบได้
- เพิ่ม backend handler/integration tests ด้วย temporary SQLite
- ทำ fixture สำหรับห้อง ลูกบ้าน การจอง ผ่อนชำระ ย้ายห้อง และสลิปหลายรูป
- เพิ่ม CI ให้ build Debug/Release, run tests, vet และตรวจ secret

เกณฑ์ผ่าน: test action ผ่านและ critical business rules มี coverage อย่างน้อย 80%

### ระยะ 3: Core business hardening

เป้าหมาย: ระบบหลักทำงานครบโดยไม่ต้องแก้ข้อมูลนอกแอป

- ปรับ financial data model เป็น ledger
- ทดสอบรอบบิล 28/29/30/31, ปีอธิกสุรทิน และ timezone ไทย
- ทดสอบ flow จอง -> เข้าอยู่ -> ย้ายห้อง -> ผ่อน -> ชำระ -> ย้ายออก
- ทดสอบ delete rules และ audit trail
- เชื่อม forgot password
- ปรับ validation/error/empty/loading/offline states ทุกหน้า

เกณฑ์ผ่าน: manual UAT checklist ผ่าน 100% ด้วยข้อมูลสำเนา production และไม่พบ P0/P1 defect

### ระยะ 4: LINE และ Notification

เป้าหมาย: ลูกบ้านได้รับข้อมูลถูกห้อง ถูกคน และไม่ส่งซ้ำ

- เชื่อม iOS action กับ backend queue
- สร้าง template บิล/ค้างชำระ/ใบเสร็จ/งานซ่อม
- เพิ่ม idempotency key, delivery status, retry และ opt-out
- เพิ่ม APNs device registration และ local reminders
- ทำ consent/privacy และทดสอบ LINE unlink/relink หลังย้ายห้อง

เกณฑ์ผ่าน: staging E2E ส่งถึง LINE และอุปกรณ์เป้าหมาย พร้อมตรวจ delivery log ได้

### ระยะ 5: ภาษาและ Release

เป้าหมาย: พร้อม TestFlight และใช้งานระยะยาว

- ย้าย hard-coded strings เข้า String Catalog
- ทดสอบไทย/อังกฤษและ Dynamic Type
- ตรวจ VoiceOver, contrast, touch targets, landscape/iPad หากรองรับ
- ทำ privacy policy, data retention, App Store metadata และ release checklist
- pilot กับผู้ดูแลจริงก่อน rollout

เกณฑ์ผ่าน: TestFlight pilot อย่างน้อย 1 รอบบิลเต็ม ไม่มี data-loss incident และ restore backup สำเร็จ

## ชุดทดสอบด้วยมือที่ยังต้องทำ

### บัญชีและความปลอดภัย

- สมัครบัญชีใหม่ แล้ว login/logout/login ซ้ำ
- เปิด/ปิดรหัส 6 หลัก ใส่ถูก/ผิด และทดสอบหลัง force quit
- ทดสอบ token หมดอายุ ถูก revoke และ network offline
- ใช้บัญชี A และ B บนเครื่องเดียว ยืนยันว่าเห็นคนละ SwiftData store

### ห้อง ราคา และลูกบ้าน

- สร้างประเภทห้องหลายแบบและเลขห้องหลายรูปแบบ
- ทดลองเลขห้องซ้ำ ชื่อประเภทซ้ำ และลบประเภทที่ห้องใช้อยู่
- เพิ่มลูกบ้านสถานะจอง/พักอาศัย/ย้ายออก พร้อมและไม่มีสลิป
- ทดสอบวันที่เข้าอยู่วันนี้ อดีต อนาคต สิ้นเดือน และข้ามปี
- ย้ายลูกบ้านไปห้องว่างและลองย้ายไปห้องที่มีผู้พัก

### การเงิน

- ตรวจยอดเดือนแรก = ค่าเช่า + มัดจำ และเดือนถัดไป = ค่าเช่า + ค่าใช้จ่ายของรอบนั้น
- ตรวจเงินมัดจำ 5%, ค่าที่ปรับขึ้น และการปัดเศษ
- ตรวจแผนผ่อน 2, 3, 6 งวด รวมทุกงวดต้องเท่ากับยอดจริง
- รับชำระบางส่วนหลายครั้ง แล้วปิดบิล
- แก้ค่าใช้จ่าย/สถานะ/ห้อง/เดือน และตรวจ Dashboard/Bills/Transfers พร้อมกัน
- ย้ายห้องแล้วตรวจบิลอดีต บิลค้าง และบิลอนาคต
- ลบบิลและตรวจ log/sync/summary

### สื่อ ใบเสร็จ และ backup

- แนบสลิป 1, 2, 10 รูป รวมรูปความละเอียดสูง
- ทดสอบ Photos permission แบบอนุญาต/จำกัด/ปฏิเสธ
- เปิด preview, share, save และ print ใบเสร็จบน iPhone จริง
- ใช้ video background นาน 15 นาทีแล้วดู memory/thermal
- สร้าง backup, ลบข้อมูล, restore และเทียบ record/รูปทั้งหมด
- นำ backup เสียหรือคนละ version เข้ามา ต้องไม่ทำลายข้อมูลเดิม

### หลายเครื่อง

- เครื่อง A เพิ่มข้อมูล แล้วเครื่อง B ดึงข้อมูล
- A และ B แก้คนละ record พร้อมกัน
- A และ B แก้ record เดียวกันพร้อมกัน
- ปิดเน็ตระหว่าง push แล้วเปิดใหม่
- ยืนยันว่ารูปสลิปและพื้นหลังตามไปได้หลังทำ media sync แล้ว

## Definition of Done สำหรับคำว่า “พร้อมใช้ 100%”

- ไม่มี P0/P1 issue เปิดอยู่
- Debug/Release build, analyzer, unit, integration และ UI tests ผ่านใน CI
- critical business rules มี automated coverage อย่างน้อย 80%
- UAT ทุก flow ผ่านบน iPhone จริงอย่างน้อยสองรุ่นและสองบัญชี
- ทดสอบ sync สองเครื่องและ offline recovery ผ่าน
- backup/restore drill ผ่านและตรวจ checksum ได้
- รูปสลิปไม่สูญหายและมี ownership/access control
- LINE/Push มี delivery log, retry และไม่ส่งผิดห้อง
- token/secret ถูกจัดเก็บอย่างปลอดภัยและไม่มี secret ใน Git history
- มี monitoring, incident procedure, privacy/retention policy และ release rollback plan

## หมายเหตุสำหรับผู้พัฒนาคนถัดไป

- ใช้โปรเจกต์ `DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj`; อย่าแก้ `Backup_Outer` โดยคิดว่าเป็น target ปัจจุบัน
- รักษาหลัก local-first และ account-scoped store
- ห้ามสร้างรายการการเงินซ้ำจากหลายหน้าโดยไม่มี idempotency key
- อย่าผูกประวัติระยะยาวด้วยเลขห้องเพียงอย่างเดียว; ใช้ tenant/tenancy identity
- ก่อนเปลี่ยน snapshot schema ต้องทำ backward-compatible decoder และ migration plan
- ทุกครั้งที่แก้สูตรเงิน ให้เพิ่ม test ก่อนหรือพร้อมกับโค้ด
- ห้ามใส่ token, password, API key หรือข้อมูลลูกบ้านจริงใน fixture/commit
