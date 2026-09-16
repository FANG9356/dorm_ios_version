# รายการงานรอแก้ไข DormiNetX

อัปเดตล่าสุด: 16 กันยายน 2569

สถานะอ้างอิงปัจจุบัน: Controlled pilot ประมาณ 88% และ Production readiness ประมาณ 78%

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

## P2 — หลัง Controlled Pilot

- [ ] APNs และ local notifications พร้อม permission onboarding
- [ ] Localization จริงด้วย String Catalog
- [ ] VoiceOver, Dynamic Type, contrast, touch target, iPad และ landscape audit
- [ ] Performance/memory/thermal soak สำหรับรูปใหญ่ วิดีโอ ใบเสร็จ และ snapshot ขนาดใหญ่
- [ ] TestFlight pilot อย่างน้อยหนึ่งรอบบิลเต็ม

## งานเอกสาร

- [ ] เปลี่ยนผล iOS tests ใน README/docs จาก `44/44` เป็น `46/46`
- [ ] ลบข้อความเก่าที่ระบุว่า public `/uploads` ยังไม่ปิด เพราะ production ปิดแล้ว
- [ ] บันทึกผล manual sync หลัง protocol-2 cutover
- [ ] อัปเดตคะแนนเมื่อมีหลักฐานปิด P0 เพิ่ม ไม่เพิ่มคะแนนจาก build/test เพียงอย่างเดียว

## ปิดแล้วในรอบนี้

- [x] Dashboard นับงานซ่อมครบทุกสถานะ รวม “กำลังติดต่อช่าง” และ “รอตรวจสอบชำระเงิน”
- [x] Dashboard แสดงยอดรวม ตัวเลขบนกราฟ และ empty state ที่ชัดเจน
- [x] Regression tests ของ Dashboard ผ่าน; iOS suite ล่าสุด 46/46
- [x] Build/sign/install รุ่นแก้ Dashboard บน iPhone “F” สำเร็จ
- [x] Commit `99f4dac` ถูก push เข้า `main`

