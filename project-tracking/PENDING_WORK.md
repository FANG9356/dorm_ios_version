# รายการงานรอแก้ไข DormiNetX

อัปเดตล่าสุด: 1 ตุลาคม 2569

สถานะอ้างอิงปัจจุบันหลังเพิ่มระบบตรวจสลิปอัตโนมัติ: ความครบของฟีเจอร์ 94%, Controlled pilot ประมาณ 82% และ Production readiness ประมาณ 70% ตาม [แบบประเมิน 18 กันยายน](../project-review/DormiNetX-Assessment-2026-09-18.md) คะแนน readiness ลดลงเพราะพบ P0 ใหม่ ไม่ใช่เพราะฟีเจอร์เดิมถอยหลัง

## P0 — ต้องปิดก่อน Production เต็มรูปแบบ

| ลำดับ | งาน | สถานะ | ผู้ดำเนินการ/เงื่อนไข | เกณฑ์ปิดงาน |
| ---: | --- | --- | --- | --- |
| 1 | หมุนและ revoke JWT, LINE, Resend/email และ secret ที่เคยอยู่ใน Git history | **เสร็จสิ้น** | นำรหัสผ่านออกจากสคริปต์, ปรับใช้ SSH Key และดำเนินการหมุนเวียน (Rotate) คีย์ JWT, LINE Token และ Resend API Key ใหม่เรียบร้อยแล้ว | secret เก่าใช้ไม่ได้, session ถูกตัดตามแผน, login/LINE/email ผ่านหลังเปลี่ยน และมีหลักฐานวันเวลา |
| 2 | UAT สอง iPhone และสองบัญชี | รอดำเนินการ | ต้องมีอุปกรณ์และบัญชีทดสอบแยกกัน | ทดสอบแก้ข้อมูลชนกัน/คนละรายการ, ตัดเน็ต, force quit, backup/restore และไม่พบข้อมูลข้ามบัญชีหรือสูญหาย |
| 3 | ยืนยัน Sync Protocol 2 หลังปิด legacy push | เสร็จแล้ว | Production ปิด `ALLOW_LEGACY_SYNC_PUSH=false`; iPhone จริง sync/rebase ถึง snapshot v161 สำเร็จ | หลักฐานบนอุปกรณ์: รายการ LINE เข้า SwiftData, dirty 0, pending 0 และไม่มี protocol rejection ในเหตุการณ์ที่ตรวจ |
| 4 | ปิด Media lifecycle | กำลังทำบางส่วน | ownership, checksum, retry และ public `/uploads` closure เสร็จแล้ว | UAT ดาวน์โหลดข้ามสองเครื่องผ่าน, มี orphan cleanup และ retention policy โดย server เป็นเพียงตัวกลางตามสถาปัตยกรรม |
| 5 | ทำ Financial ledger เต็มรูปแบบ | รอดำเนินการ | เริ่มมี `PaymentTransaction` และ `FinancialReceipt` แล้ว | Invoice migration, refund, void, credit adjustment และ immutable actor/reason audit ผ่าน tests และ UAT |
| 6 | Production atomic restore/rollback drill | รอตรวจ | คำสั่งและ verify-only พร้อมแล้ว ต้องกำหนด maintenance window | restore archive จริง, health checklist และ rollback ผ่าน พร้อมบันทึกหลักฐาน |
| 7 | Harden การตรวจสลิปอัตโนมัติและ OCR ก่อนตัดยอดจริง | เร่งด่วน/ยังไม่ผ่าน | ระบบ deploy แล้ว แต่ fallback QR ยอมรับ payload กว้างและเปลี่ยน `paid`/`เสร็จสิ้น`; OCR service รัน root และยังไม่อยู่ใน atomic rollback/health gate | fail closed; ตรวจยอด ผู้รับ reference และ replay; ไม่ auto-paid เมื่อ OCR/API ล่ม; config/secret ไม่ hardcode; service ลดสิทธิ์; tests/UAT/rollback ผ่าน |

## P1 — ต้องปิดก่อน Rollout วงกว้าง

| งาน | สถานะ | เกณฑ์ปิดงาน |
| --- | --- | --- |
| UI automation: login, tenant lifecycle, billing, partial/full payment, receipt, room move, maintenance และ backup | รอดำเนินการ | ชุดทดสอบรันซ้ำได้ใน CI และครอบคลุม happy/error paths สำคัญ |
| Forgot-password บน staging และ concurrency หลาย instance | รอดำเนินการ | email จริงส่งถึง, OTP ใช้ครั้งเดียว, rate limit/expiry/concurrency ถูกต้อง |
| SwiftData schema migration/recovery และกรณีพื้นที่ไม่พอ | รอดำเนินการ | อัปเกรด schema และ disk-full ไม่ทำลายข้อมูลเดิม พร้อม recovery UI |
| ทำ error/offline/sync state ให้สม่ำเสมอทุกหน้า | รอตรวจ UI | ไม่มี silent failure และผู้ใช้เข้าใจว่ารายการอยู่ในเครื่อง, กำลังซิงก์ หรือส่งไม่สำเร็จ |
| Monitoring, alert, backup retention, incident runbook และ release rollback checklist | รอดำเนินการ | มี metric/log/alert และขั้นตอนตอบสนองที่ทดสอบได้ |
| ยืนยัน deployment target `iOS 26.2` | รอดำเนินการ | ตรงกับอุปกรณ์เป้าหมาย หรือปรับลดแล้วผ่าน compatibility test |
| UAT งานซ่อมแบบมี/ไม่มีค่าใช้จ่ายผ่าน LINE | รอตรวจ | paid flow ผ่าน quote approve/reject, re-quote, repair, bill, slip และ app sync; free flow ไม่ส่ง quote/bill; stale/unauthorized action ถูกปฏิเสธ |

## P2 — หลัง Controlled Pilot

- [ ] APNs และ local notifications พร้อม permission onboarding
- [ ] Localization จริงด้วย String Catalog
- [ ] VoiceOver, Dynamic Type, contrast, touch target, iPad และ landscape audit
- [ ] Performance/memory/thermal soak สำหรับรูปใหญ่ วิดีโอ ใบเสร็จ และ snapshot ขนาดใหญ่
- [ ] TestFlight pilot อย่างน้อยหนึ่งรอบบิลเต็ม

## งานเอกสาร

- [x] บันทึกผล iOS full suite รอบก่อน `52/52` และผล targeted maintenance/sync ล่าสุด `23/23` แยกกัน ไม่อ้างว่าเป็นชุดเดียวกัน
- [x] ลบข้อความเก่าที่ระบุว่า public `/uploads` ยังไม่ปิด เพราะ production ปิดแล้ว
- [x] เพิ่มเอกสารวิสัยทัศน์, สถานะงาน, คู่มือส่งต่อ และแบบประเมินวันที่ 17 กันยายน พร้อมเชื่อมจาก README/Project Tracking
- [x] เพิ่ม maintenance E2E checklist และ issue history `LINE-007`–`FLOW-011`
- [x] บันทึกผล sync อุปกรณ์จริงหลัง protocol-2 cutover: snapshot v161, dirty 0, pending 0 และรายการ LINE server id 183 ปรากฏใน SwiftData
- [x] อัปเดตคะแนนแบบประเมินหลังมีหลักฐานปิด protocol-2 device proof; ไม่เพิ่มคะแนนจาก build/test เพียงอย่างเดียว

## ปิดแล้วในรอบนี้

- [x] แก้ sync conflict ที่ทำให้รายการจาก LINE ไม่เข้าแอปเมื่อมี local dirty record: ดึง remote snapshot, rebase ข้อมูลในเครื่องแล้ว push ซ้ำอัตโนมัติ; เพิ่ม sync ตอนเปิด dashboard/หน้าแจ้งซ่อม และพิสูจน์บน iPhone จริงถึง snapshot v161 โดยข้อมูลเดิมไม่หาย
- [x] รองรับสถานะ `ปฏิเสธค่าใช้จ่าย` ใน backend materialization เป็น terminal branch ป้องกัน snapshot รับสำเร็จแต่ side-effect ตอบ HTTP 500; targeted iOS maintenance/sync tests ผ่าน 23/23 และ backend test/race/vet ผ่าน
- [x] แก้ Flex ปฏิเสธใบเสนอราคาเป็นโทนขาว–เทาแบบกระชับ deploy SHA-256 `0cb92224751a1456eedfcb3962b72df694c5219ea399cd59a663753671f55721`
- [x] ตัดข้อความยืนยันซ้ำหลังอนุมัติ/ปฏิเสธใบเสนอราคา ให้ success path ส่ง Flex ใบเดียวและใช้ text เฉพาะ fallback; production ล่าสุด SHA-256 `32a26c80c5793f533a1e658790c09aed423b51f104a4e3120496ce5793f07f89`, rollback set `/home/fang/line_migration_backups/20260917-201712-pre-flex-ui`
- [x] แก้ปัญหา "ลบรายการซ่อมด้วยตัวเองแล้วไม่หาย": แก้ไข Web UI / API `api_maintenances.go` ให้เรียก `publishLineChanges` ทุกครั้งเมื่อ Create, Update หรือ Delete เพื่อป้องกันไม่ให้ iOS sync ดึงเอา snapshot ข้อมูลที่ไม่ได้อัปเดตกลับมาทับข้อมูลใหม่
- [x] แก้ปัญหา "ระบบแสดงที่แอพว่ารอ": เพิ่ม `.onChange(of: scenePhase)` ลงใน `RoomListView` เพื่อบังคับ Sync จาก Backend ทันทีที่สลับแอปกลับมา และเพิ่ม `Pull to Refresh` ในทุกหน้า เพื่อให้ผู้ใช้ไม่ต้องรอ Timer 20 วินาที
- [x] แก้ปัญหา "ไม่แสดงวันที่และเวลาแจ้งซ่อม": ปรับ `AppDate.swift` ให้รองรับการแปลงวันที่แบบ Legacy (`yyyy-MM-dd HH:mm:ss`) นอกเหนือจาก ISO8601 เพื่อให้ข้อมูลเก่าแสดงผลเวลาแจ้งซ่อมได้ครบถ้วน

- [x] ออกแบบการ์ดแจ้งซ่อมใหม่เป็น read-only card แสดง timeline ครบ 6 ขั้นแบบ monochrome รวมขั้นอนุมัติค่าใช้จ่าย ตัดการเปลี่ยนสถานะ, swipe และเมนูกดค้างจากหน้ารายการ ให้แตะทั้งการ์ดก่อนแก้ไข บังคับ workflow ตามกฎพร้อม save validation และย้ายการลบเข้าไปในหน้ารายละเอียดพร้อม confirmation; ติดตั้ง build ใหม่บน iPhone “F” แล้ว
- [x] Redesign หน้าแก้ไขงานซ่อมเป็น premium thin-material cards ลดสีและกล่องซ้อน ทำสถานะเป็น vertical workflow timeline และปรับรายละเอียด ค่าใช้จ่าย ช่องทางชำระ หลักฐาน และปุ่มลบให้ใช้ visual language เดียวกัน
- [x] เปลี่ยนการยืนยันลบงานซ่อมจาก adaptive confirmation popover เป็น system alert กลางจอ ไม่ลอยไปเตือนด้านบนตามตำแหน่งปุ่ม
- [x] แก้สถานะแจ้งซ่อมไม่ส่ง Flex Card: เพิ่ม persistent outbox, event-key กันซ้ำ, retry สูงสุด 8 ครั้ง, startup recovery และ regression tests สำหรับส่งสำเร็จ/ล้มแล้วรอส่งใหม่
- [x] Deploy backend รุ่น workflow SHA-256 `f02deb959dde76647b366d24e1e804b7958af4552b4ca715b615333783e997c6`; service/public health และ schema checks ผ่าน มี rollback set `/home/fang/line_migration_backups/20260917-002953-pre-flex-ui`; รุ่น production ปัจจุบันอยู่ในรายการปิดล่าสุดด้านบน และยังเหลือ controlled E2E UAT ของ quote/approval/bill/slip
- [x] เพิ่ม workflow งานซ่อม 6 ขั้น: งานมีค่าใช้จ่ายต้องส่ง Flex ใบเสนอราคาและรอ linked resident อนุมัติก่อนซ่อม, ปฏิเสธเพื่อออกยอดใหม่ได้, ล็อกยอดที่เสนอ, ส่ง Flex บิลตอนรอตรวจชำระ และให้งานฟรีข้าม quote/payment ได้
- [x] เพิ่ม maintenance LINE action authorization, stale-action protection, snapshot publish กลับแอป, outbox internal record ID และแก้ retry due-time comparison ด้วย SQLite `julianday`
- [x] แก้ Flex ใบเสนอราคา/บิลถูก LINE API ปฏิเสธ 400 เพราะใช้ `alignItems: baseline`; เปลี่ยนเป็น baseline layout, เก็บ response body ใน error, deploy SHA-256 `2566537a63a22d3d591f2e845fe6389afc0412664094436999eaabb45e3aec4d` และ retry ใบเสนอราคาห้อง 103 ยอด 200 บาทสำเร็จ (`sent`)
- [x] แก้ callback อนุมัติราคาไม่ให้ข้ามจาก “รออนุมัติค่าใช้จ่าย” ไป “กำลังซ่อม”: กลับไปแสดง “กำลังติดต่อช่าง”, เก็บ approval marker ฝั่ง server, ล็อกยอด, ส่งการ์ดสถานะ และรอแอดมินเริ่มซ่อม; production/data ห้อง 103/snapshot v129/iPhone build อัปเดตแล้ว
- [x] แก้รายการแจ้งซ่อมจาก LINE ไม่เข้าแอปเพราะ UUID ต่างตัวพิมพ์: canonicalize/deduplicate โดยเก็บแถวล่าสุด, สำรองฐานข้อมูลก่อน cleanup และออก snapshot production `v82` ที่มี 2 รายการถูกต้อง; binary SHA-256 `ca4718cfa6f43451394df4fe2830cbc6f280c13b1074765f4379faad9b587717`
- [x] Dashboard นับงานซ่อมครบทุกสถานะ รวม “กำลังติดต่อช่าง” และ “รอตรวจสอบชำระเงิน”
- [x] Dashboard แสดงยอดรวม ตัวเลขบนกราฟ และ empty state ที่ชัดเจน
- [x] Regression tests ของ Dashboard และวันที่ผ่าน; iOS suite ล่าสุด 52/52
- [x] Build/sign/install รุ่นแก้ Dashboard บน iPhone “F” สำเร็จ
- [x] Commit `99f4dac` ถูก push เข้า `main`
- [x] แก้การ์ดสรุปการเงินให้ขนาดเท่ากัน และลบ swipe/context gesture ในหน้าบิลที่แย่งการเลื่อน
- [x] เพิ่ม `AppDate` กลาง รองรับ storage ปี พ.ศ./ค.ศ. เดิมโดยไม่เกิดปี 3112 และให้ข้อมูลใหม่บันทึกเป็น Gregorian
- [x] เพิ่มช่องค้นหาแบบเดียวกับทะเบียนลูกบ้านในหน้าบิล การเงิน ห้องพัก ตั้งราคา หลักฐานโอน และแจ้งซ่อม
- [x] รวมค้นหา รอบบิล และสถานะของหน้าการเงินในการ์ดกระจกฝ้าใบเดียว พร้อมตัวเลือกเดือน–ปีและแท็บสถานะแบบแตะ/ลากเลือก
- [x] Build/sign/install งาน UI รอบล่าสุดบน iPhone “F” สำเร็จ โดยใช้ฐานข้อมูลเดิม; รายการ `UI-001`–`UI-006` ยังรอผู้ใช้ตรวจซ้ำก่อนปิด issue
- [x] ตรวจสอบและแก้ไขบั๊ก HTTP Response Body Leak (Memory & Connection Leak) ในฟังก์ชันส่งข้อความของ `line_bot.go`
- [x] พัฒนาและอัปเกรด Tenant Portal บนเว็บแอปพลิเคชัน LIFF โดยดึงประวัติการชำระเงินบิลเก่าและประเมินยอดบิลล่วงหน้ามาแสดง 
- [x] เปลี่ยนการตอบกลับของปุ่ม "ประวัติการชำระ" จาก Carousel เป็น Flex Message ขนาดเล็กที่ลิงก์ไปหน้า Tenant Portal LIFF
- [x] อุดช่องโหว่ความปลอดภัยระดับ P0 โดยการทำ Passwordless SSH Key Authentication และลบสคริปต์ `.exp` ที่มีรหัสผ่านฮาร์ดโค้ดกว่า 30 ไฟล์ออกจาก Git History ของโค้ดปัจจุบัน
- [x] (ยังไม่ได้ Commit) แก้ไขปัญหา SwiftData `EXC_BREAKPOINT` จากการใช้ OR Condition ภายใน Predicate โดยเปลี่ยนวิธีตรวจสอบเพื่อป้องกันแอป Crash
- [x] (ยังไม่ได้ Commit) พัฒนาระบบ Multi-Tenant สำหรับ PromptPay ID ให้รองรับการตั้งค่าแยกตามลูกบ้าน/ผู้ดูแล และให้ LINE Bot สร้างสลิปถูกบัญชี
- [x] (ยังไม่ได้ Commit) ปรับปรุงความรัดกุม Maintenance Workflow (iOS/Backend) ป้องกันข้ามสถานะการอนุมัติ และแก้ `BackupTabView` ให้แสดงผลลัพธ์การทำงานครบถ้วน
