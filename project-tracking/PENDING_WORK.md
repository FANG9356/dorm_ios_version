# รายการงานรอแก้ไข DormiNetX

อัปเดตล่าสุด: 17 กันยายน 2569

สถานะอ้างอิงปัจจุบัน: ความครบของฟีเจอร์ 92%, Controlled pilot ประมาณ 89% และ Production readiness ประมาณ 79% ตาม [แบบประเมิน 17 กันยายน](../project-review/DormiNetX-Assessment-2026-09-17.md)

## P0 — ต้องปิดก่อน Production เต็มรูปแบบ

| ลำดับ | งาน | สถานะ | ผู้ดำเนินการ/เงื่อนไข | เกณฑ์ปิดงาน |
| ---: | --- | --- | --- | --- |
| 1 | หมุนและ revoke JWT, LINE, Resend/email และ secret ที่เคยอยู่ใน Git history | รอดำเนินการ | ต้องเข้าถึงหน้า provider และวางแผน session cutover ร่วมกับเจ้าของระบบ | secret เก่าใช้ไม่ได้, session ถูกตัดตามแผน, login/LINE/email ผ่านหลังเปลี่ยน และมีหลักฐานวันเวลา |
| 2 | UAT สอง iPhone และสองบัญชี | รอดำเนินการ | ต้องมีอุปกรณ์และบัญชีทดสอบแยกกัน | ทดสอบแก้ข้อมูลชนกัน/คนละรายการ, ตัดเน็ต, force quit, backup/restore และไม่พบข้อมูลข้ามบัญชีหรือสูญหาย |
| 3 | ยืนยัน Sync Protocol 2 หลังปิด legacy push | รอตรวจ | Production ปิด `ALLOW_LEGACY_SYNC_PUSH=false` แล้ว | manual sync จากอุปกรณ์ใช้งานจริงผ่าน และ server log ไม่มี protocol rejection |
| 4 | ปิด Media lifecycle | กำลังทำบางส่วน | ownership, checksum, retry และ public `/uploads` closure เสร็จแล้ว | UAT ดาวน์โหลดข้ามสองเครื่องผ่าน, มี orphan cleanup และ retention policy โดย server เป็นเพียงตัวกลางตามสถาปัตยกรรม |
| 5 | ทำ Financial ledger เต็มรูปแบบ | รอดำเนินการ | เริ่มมี `PaymentTransaction` และ `FinancialReceipt` แล้ว | Invoice migration, refund, void, credit adjustment และ immutable actor/reason audit ผ่าน tests และ UAT |
| 6 | Production atomic restore/rollback drill | รอตรวจ | คำสั่งและ verify-only พร้อมแล้ว ต้องกำหนด maintenance window | restore archive จริง, health checklist และ rollback ผ่าน พร้อมบันทึกหลักฐาน |

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

- [x] บันทึกผล iOS full suite รอบก่อน `52/52` และผล targeted maintenance/sync ล่าสุด `21/21` แยกกัน ไม่อ้างว่าเป็นชุดเดียวกัน
- [x] ลบข้อความเก่าที่ระบุว่า public `/uploads` ยังไม่ปิด เพราะ production ปิดแล้ว
- [x] เพิ่มเอกสารวิสัยทัศน์, สถานะงาน, คู่มือส่งต่อ และแบบประเมินวันที่ 17 กันยายน พร้อมเชื่อมจาก README/Project Tracking
- [x] เพิ่ม maintenance E2E checklist และ issue history `LINE-007`–`FLOW-011`
- [ ] บันทึกผล manual sync หลัง protocol-2 cutover
- [ ] อัปเดตคะแนนเมื่อมีหลักฐานปิด P0 เพิ่ม ไม่เพิ่มคะแนนจาก build/test เพียงอย่างเดียว

## ปิดแล้วในรอบนี้

- [x] ออกแบบการ์ดแจ้งซ่อมใหม่เป็น read-only card แสดง timeline ครบ 6 ขั้นแบบ monochrome รวมขั้นอนุมัติค่าใช้จ่าย ตัดการเปลี่ยนสถานะ, swipe และเมนูกดค้างจากหน้ารายการ ให้แตะทั้งการ์ดก่อนแก้ไข บังคับ workflow ตามกฎพร้อม save validation และย้ายการลบเข้าไปในหน้ารายละเอียดพร้อม confirmation; ติดตั้ง build ใหม่บน iPhone “F” แล้ว
- [x] Redesign หน้าแก้ไขงานซ่อมเป็น premium thin-material cards ลดสีและกล่องซ้อน ทำสถานะเป็น vertical workflow timeline และปรับรายละเอียด ค่าใช้จ่าย ช่องทางชำระ หลักฐาน และปุ่มลบให้ใช้ visual language เดียวกัน
- [x] เปลี่ยนการยืนยันลบงานซ่อมจาก adaptive confirmation popover เป็น system alert กลางจอ ไม่ลอยไปเตือนด้านบนตามตำแหน่งปุ่ม
- [x] แก้สถานะแจ้งซ่อมไม่ส่ง Flex Card: เพิ่ม persistent outbox, event-key กันซ้ำ, retry สูงสุด 8 ครั้ง, startup recovery และ regression tests สำหรับส่งสำเร็จ/ล้มแล้วรอส่งใหม่
- [x] Deploy backend production รุ่นล่าสุด SHA-256 `f02deb959dde76647b366d24e1e804b7958af4552b4ca715b615333783e997c6`; service/public health และ schema checks ผ่าน มี rollback set `/home/fang/line_migration_backups/20260917-002953-pre-flex-ui`; ยังเหลือ controlled E2E UAT ของ quote/approval/bill/slip
- [x] เพิ่ม workflow งานซ่อม 6 ขั้น: งานมีค่าใช้จ่ายต้องส่ง Flex ใบเสนอราคาและรอ linked resident อนุมัติก่อนซ่อม, ปฏิเสธเพื่อออกยอดใหม่ได้, ล็อกยอดที่เสนอ, ส่ง Flex บิลตอนรอตรวจชำระ และให้งานฟรีข้าม quote/payment ได้
- [x] เพิ่ม maintenance LINE action authorization, stale-action protection, snapshot publish กลับแอป, outbox internal record ID และแก้ retry due-time comparison ด้วย SQLite `julianday`
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
