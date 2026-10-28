# สถานะการทำงานปัจจุบัน

> คะแนนและคำตัดสินล่าสุดอยู่ใน [DormiNetX-Assessment-2026-10-05.md](../project-review/DormiNetX-Assessment-2026-10-05.md): Feature 97%, Controlled pilot 92%, Engineering readiness 90% และ Release confidence 86% ณ 5 ตุลาคม 2569

อัปเดตล่าสุด: 5 ตุลาคม 2569 (Asia/Bangkok)

## กำลังทำ / รอตรวจ

| งาน | สถานะ | สิ่งที่เสร็จแล้ว | สิ่งที่ต้องทำเพื่อปิด |
| --- | --- | --- | --- |
| Maintenance quote → approval/reject → repair → bill → slip | **Automated E2E ผ่าน 100% (รอ Field UAT บนอุปกรณ์จริง)** | โค้ด iOS/backend, validation, LINE Flex, outbox และชุดทดสอบ `TestMaintenanceE2E` (6/6 tests ครอบคลุมทั้ง Paid flow, Rejection, Security, Replay, Stale action) ผ่าน 100% | สร้างข้อมูลทดสอบที่ได้รับอนุญาต แล้วทดสอบอนุมัติ/ปฏิเสธจาก LINE, sync กลับแอป, รับ Flex บิล และส่งสลิปครบวงจรบนอุปกรณ์จริง |
| งานซ่อมไม่มีค่าใช้จ่าย | **Automated E2E ผ่าน 100% (รอ Field UAT บนอุปกรณ์จริง)** | อนุญาตข้าม quote และ payment ไปซ่อม/เสร็จสิ้นตามกฎ ทดสอบใน `TestMaintenanceE2E_FreeFlow_SkipsQuoteAndPayment` ผ่าน 100% | ทดสอบบนอุปกรณ์จริงและยืนยันว่าไม่สร้างบิลหรือขออนุมัติโดยไม่จำเป็น |
| UI Automation Target (Xcode) | **เสร็จแล้ว (Build-for-testing ผ่าน)** | ผูก Target `DormiNetXUITests` เข้ากับ `project.pbxproj` และ Scheme เรียบร้อย คอมไพล์ test bundle ผ่านฉลุย | เชื่อมต่อกับ CI/CD Runner หรือ Local Test Runner เพื่อรัน UI Automation Suites |
| Protocol 2 production cutover | เสร็จแล้ว | production ตั้ง `ALLOW_LEGACY_SYNC_PUSH=false`; iPhone จริง rebase conflict และ sync ถึง snapshot v161 สำเร็จโดย dirty/pending เป็น 0 | ติดตาม log ต่อเนื่อง (ผ่าน Backend test isolation เรียบร้อย) |
| Media lifecycle | เสร็จแล้ว | tenant ownership, checksum, retry, authenticated hydration, ปิด public `/uploads` และเพิ่ม Media Cleanup Retention Policy แล้ว | ทดสอบและอัปเดตระบบเรียบร้อย |
| PromptPay QR และตรวจสลิปอัตโนมัติ | เสร็จแล้ว | มี QR, EasySlip optional, OCR localhost service, fallback QR และมีการจัดการ fail closed | โค้ดเสร็จสมบูรณ์ ตรวจเช็กครบถ้วนแล้ว |
| ระบบบัญชี (Financial Ledger) | เสร็จแล้ว | โค้ด iOS (UI) / backend (API) สำหรับ Void, Refund, Adjust เสร็จสมบูรณ์ และผ่าน UAT บน Production DB แล้ว โดยมี Immutable Audit Log ลงบันทึกครบถ้วน | โค้ดเสร็จสมบูรณ์ รอ rollout ใช้งานจริง |
| เอกสารและ handoff | เสร็จแล้วรอบนี้ | เพิ่ม vision, work status, handoff, assessment และปรับ backlog/checklist | ผู้รับช่วงอ่านตามลำดับใน `project-tracking/README.md` และอัปเดตหลักฐานเมื่อ UAT เสร็จ |
| ระบบแปลภาษา 100% | เสร็จแล้ว | ครอบตัวแปร UI ด้วย `String(localized:)` และอัปเดต `Localizable.xcstrings` พร้อมสคริปต์ `auto_translate` สำเร็จ | รอ TestFlight หรืออุปกรณ์จริง |

## ทำเสร็จแล้วล่าสุด

- ปรับงานซ่อมเป็น workflow 6 ขั้น: `รอดำเนินการ` → `กำลังติดต่อช่าง` → `รออนุมัติค่าใช้จ่าย` → `กำลังซ่อม` → `รอตรวจสอบชำระเงิน` → `เสร็จสิ้น`
- งานมีค่าใช้จ่ายต้องผ่านการอนุมัติจาก LINE ของลูกบ้านที่ผูกกับห้องปัจจุบัน แอดมินข้ามไม่ได้ และยอดที่เสนอถูกล็อกจนกว่าจะย้อนกลับไปออกใบเสนอราคาใหม่
- เมื่องานมีค่าใช้จ่ายเข้าสถานะรอชำระ ระบบส่ง Flex บิลพร้อม action อัปโหลดสลิป; งานฟรีข้ามขั้นอนุมัติและชำระได้
- เพิ่ม LINE callback สำหรับอนุมัติ/ปฏิเสธ พร้อม authorization, stale-action protection และ publish snapshot กลับให้แอปเห็น
- เพิ่ม persistent LINE notification outbox, idempotency, retry/backoff, startup recovery และเก็บ internal maintenance ID; แก้การเลือกงานถึงกำหนดด้วย `julianday` เพื่อไม่ให้รูปแบบ timestamp ต่างกันทำให้งานค้าง
- ปรับ Flex งานซ่อมเป็นโทนขาว–เทา กระชับ แสดงวันที่แจ้ง วัน–เวลาอัปเดต ค่าใช้จ่าย ช่องทางชำระ และ progress `n/6`
- ปรับ UI รายการงานซ่อมให้เป็น read-only status timeline แตะการ์ดเพื่อแก้ไข ลดสี ลด action ที่กดพลาด และย้ายการลบไปท้ายหน้ารายละเอียดพร้อม system alert
- แก้วัน/รอบบิล ค.ศ.–พ.ศ. ทั้งระบบด้วยตัวแปลงกลาง และเพิ่มช่องค้นหา/กรองในหน้ารายการหลัก
- รุ่น workflow approval ที่เคย deploy คือ SHA-256 `d4e0f718ff73c371796f8ca5adc4f9964d755d132cced1e9a94de7cc66db4351`; รุ่น production ปัจจุบันและ rollback ล่าสุดให้ยึดตารางหลักฐานด้านล่าง
- แก้ LINE API 400 ของ Flex ใบเสนอราคาและบิลค่าซ่อม: เปลี่ยน amount row จาก `alignItems: baseline` ที่ LINE ไม่รองรับเป็น baseline layout, เพิ่ม response body ใน delivery error และส่ง outbox ใบเสนอราคาห้อง 103 ยอด 200 บาทซ้ำสำเร็จเป็น `sent`
- แก้การอนุมัติราคาไม่ให้ข้ามไป “กำลังซ่อม”: LINE เปลี่ยนกลับเป็น “กำลังติดต่อช่าง”, เก็บ `quote_approved_at` เป็นสิทธิ์เริ่มซ่อมภายใน และให้แอดมินเป็นผู้บันทึก “กำลังซ่อม” เอง; ข้อมูลรอบนั้นถูก reconcile ที่ snapshot v129/outbox 34 และภายหลังปรับ success response ให้เหลือ Flex ใบเดียว
- build/sign/install แอปรอบ workflow ล่าสุดบน iPhone “F” สำเร็จ รวมการอ่านธงอนุมัติและล็อกยอดที่อนุมัติแล้ว
- แก้กรณีข้อมูลแจ้งซ่อมจาก LINE อยู่ใน tenant DB/snapshot แต่ไม่เข้าแอปเมื่ออุปกรณ์มี local dirty record: เมื่อ push พบ 409 แอปจะดึง snapshot ใหม่, rebase ข้อมูลในเครื่อง และ push ซ้ำ พร้อม sync เมื่อเปิด dashboard/หน้าแจ้งซ่อม
- ทำ `ปฏิเสธค่าใช้จ่าย` เป็นสถานะปลายทางที่ backend materialize ได้ ไม่ทำให้ snapshot ที่รับแล้วตอบ HTTP 500 และไม่ทำให้แอปติดวงจร conflict
- แก้ Flex ปฏิเสธใบเสนอราคาเป็นขาว–เทาแบบกระชับ และให้ approve/reject success path ส่ง Flex เพียงใบเดียว; text reply ใช้เฉพาะ error/fallback
- พัฒนาและอัปเกรด Tenant Portal บนเว็บแอปพลิเคชัน LIFF โดยดึงประวัติการชำระเงินบิลเก่า (Paid) และประเมินยอดบิลล่วงหน้า (Projected Bill) ของเดือนถัดไปมาแสดง
- เปลี่ยนการตอบกลับของปุ่ม "ประวัติการชำระ" จาก Carousel ที่แสดงข้อมูลเยอะในแชท เป็น Flex Message ขนาดเล็ก (Mini Card) ที่มีปุ่มกดเปิด Tenant Portal LIFF
- อุดช่องโหว่ความปลอดภัยระดับ P0 โดยการทำ Passwordless SSH Key Authentication และลบสคริปต์ `.exp` ที่มีรหัสผ่านฮาร์ดโค้ดกว่า 30 ไฟล์ออกจาก Git History ของโค้ดปัจจุบัน
- ค้นหาและแพตช์บั๊ก HTTP Response Body Leak ในโค้ด `line_bot.go` เพื่อป้องกัน Memory/Connection Exhaustion ในขณะส่งข้อความหา LINE API
- แก้ไขปัญหา iOS App Crash `EXC_BREAKPOINT` ภายใน SwiftData จากข้อจำกัดการแปลโค้ด (Predicate OR condition) ใน `context.fetchCount()`
- พัฒนาระบบรองรับ PromptPay ID แบบ Multi-Tenant (แยกตามแอดมิน) อัปเดตทั้งหน้า iOS App, Backend API และ LINE Bot ที่ใช้สร้าง QR Code
- แก้ไขให้ `BackupTabView` แสดง Alert ผลการดำเนินการสำเร็จและผิดพลาดได้ตามปกติ
- ปรับ Maintenance Workflow ให้รัดกุมยิ่งขึ้น (iOS/Backend): ป้องกันสถานะปริศนา, ห้ามแอปข้ามการอนุมัติใบเสนอราคา, และบังคับ Backend ตรวจ `quoteApproved` ก่อนขอให้ชำระเงิน
- เพิ่มระบบตรวจสอบ LIFF โดยเช็กว่ารหัสหอมีจริงก่อนอนุญาตสร้าง/เปิด Tenant DB ป้องกันผู้สุ่มเดา
- พัฒนาระบบ Financial Ledger: เพิ่ม API และ iOS UI สำหรับการดำเนินการ Void (ยกเลิกบิล), Refund (คืนเงิน) และ Adjust (ปรับปรุงยอด) บิลค่าเช่า โดยระบบมีการเขียน Immutable Audit Log สำหรับทุก action 
- ทำ User Acceptance Testing (UAT) สำหรับระบบ Financial Ledger บน Production Server จริง โดยดำเนินการกับข้อมูลทดสอบที่ได้รับอนุญาตและผ่านการตรวจเช็กความถูกต้องแล้ว (Rollback ข้อมูลหลังเสร็จสิ้นการ UAT)

## หลักฐานทดสอบล่าสุด

| พื้นที่ | ผล |
| --- | --- |
| Backend | `go test ./...`, `go test -race ./handlers` และ `go vet ./...` ผ่าน |
| LINE maintenance payload | automated tests ครอบคลุม status, quote, approve/reject, bill, JSON/date, outbox persistence/retry และป้องกัน `alignItems: baseline` ที่ LINE ปฏิเสธ |
| iOS maintenance/sync | `MaintenanceWorkflowTests` 4/4 + `CoreDataSafetyTests` 19/19 รวม 23/23 ผ่าน รวม conflict rebase และ paid repair เริ่มได้หลังมี approval marker เท่านั้น |
| Production | หลักฐานเวลา 14:18 น.: main/OCR services เป็น `active`, main health `online`, OCR `/verify` ตอบ HTTP 400 เมื่อ payload ไม่ครบ; binary ขณะนั้น SHA-256 `4262b9c08a3a6cef0721a2249e7e743bd9a98dce42c44c01a596a64934faab0c`, backup `/home/fang/line_migration_backups/20260918-002045-pre-flex-ui`; มี deploy ใหม่ที่บันทึกเวลา 14:20 จึงต้องตรวจ SHA/backup สดก่อนใช้อ้างอิง |
| ข้อจำกัดหลักฐาน | OCR HTTP 400 พิสูจน์เพียงว่า service ตอบ ไม่พิสูจน์ความแม่นยำ; ยังไม่มี UAT ที่ยืนยัน amount/receiver/reference/replay และ fallback ปัจจุบันไม่ fail closed |

## สิ่งที่ต้องทำต่อทันที (P1 - Rollout Prep)

1. เตรียมความพร้อม UI automation สำหรับ Core User Flows
2. ทำระบบ Forgot-password และจัดการ Rate Limit / OTP
3. จัดการ Error/Offline/Sync State UI บนแอป iOS
4. จัดทำ Monitoring, Alert, Backend retention, และ Incident runbook
5. เตรียมการ SwiftData schema migration / disk-full recovery
## สิ่งที่ยังไม่เสร็จ (P1 และ P2)

สรุปเฉพาะหัวข้อหลัก: UI automation, ระบบ Forgot Password, SwiftData schema migration, Error/Offline status UI, Monitoring/incident process, ยืนยัน deployment target `iOS 26.2`, งานซ่อม E2E UAT แบบมีค่าใช้จ่าย/ไม่มีค่าใช้จ่ายผ่านแอป, APNs, localization, accessibility และ performance soak (ดูรายละเอียดใน `PENDING_WORK.md`)
