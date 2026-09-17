# สถานะการทำงานปัจจุบัน

อัปเดตล่าสุด: 17 กันยายน 2569 (Asia/Bangkok)

## กำลังทำ / รอตรวจ

| งาน | สถานะ | สิ่งที่เสร็จแล้ว | สิ่งที่ต้องทำเพื่อปิด |
| --- | --- | --- | --- |
| Maintenance quote → approval/reject → repair → bill → slip | รอตรวจ UAT | โค้ด iOS/backend, validation, LINE Flex, outbox และ production deploy เสร็จ | สร้างข้อมูลทดสอบที่ได้รับอนุญาต แล้วทดสอบอนุมัติ/ปฏิเสธจาก LINE, sync กลับแอป, รับ Flex บิล และส่งสลิปครบวงจร |
| งานซ่อมไม่มีค่าใช้จ่าย | รอตรวจ UAT | อนุญาตข้าม quote และ payment ไปซ่อม/เสร็จสิ้นตามกฎ | ทดสอบบนอุปกรณ์จริงและยืนยันว่าไม่สร้างบิลหรือขออนุมัติโดยไม่จำเป็น |
| Protocol 2 production cutover | รอตรวจ | production ตั้ง `ALLOW_LEGACY_SYNC_PUSH=false` | กด manual sync จาก iPhone รุ่นใช้งานจริงและตรวจ journal ว่าไม่มี protocol rejection |
| Media lifecycle | กำลังทำบางส่วน | tenant ownership, checksum, retry, authenticated hydration และปิด public `/uploads` แล้ว | UAT ข้ามสองเครื่อง, orphan cleanup และ retention policy |
| เอกสารและ handoff | เสร็จแล้วรอบนี้ | เพิ่ม vision, work status, handoff, assessment และปรับ backlog/checklist | ผู้รับช่วงอ่านตามลำดับใน `project-tracking/README.md` และอัปเดตหลักฐานเมื่อ UAT เสร็จ |

## ทำเสร็จแล้วล่าสุด

- ปรับงานซ่อมเป็น workflow 6 ขั้น: `รอดำเนินการ` → `กำลังติดต่อช่าง` → `รออนุมัติค่าใช้จ่าย` → `กำลังซ่อม` → `รอตรวจสอบชำระเงิน` → `เสร็จสิ้น`
- งานมีค่าใช้จ่ายต้องผ่านการอนุมัติจาก LINE ของลูกบ้านที่ผูกกับห้องปัจจุบัน แอดมินข้ามไม่ได้ และยอดที่เสนอถูกล็อกจนกว่าจะย้อนกลับไปออกใบเสนอราคาใหม่
- เมื่องานมีค่าใช้จ่ายเข้าสถานะรอชำระ ระบบส่ง Flex บิลพร้อม action อัปโหลดสลิป; งานฟรีข้ามขั้นอนุมัติและชำระได้
- เพิ่ม LINE callback สำหรับอนุมัติ/ปฏิเสธ พร้อม authorization, stale-action protection และ publish snapshot กลับให้แอปเห็น
- เพิ่ม persistent LINE notification outbox, idempotency, retry/backoff, startup recovery และเก็บ internal maintenance ID; แก้การเลือกงานถึงกำหนดด้วย `julianday` เพื่อไม่ให้รูปแบบ timestamp ต่างกันทำให้งานค้าง
- ปรับ Flex งานซ่อมเป็นโทนขาว–เทา กระชับ แสดงวันที่แจ้ง วัน–เวลาอัปเดต ค่าใช้จ่าย ช่องทางชำระ และ progress `n/6`
- ปรับ UI รายการงานซ่อมให้เป็น read-only status timeline แตะการ์ดเพื่อแก้ไข ลดสี ลด action ที่กดพลาด และย้ายการลบไปท้ายหน้ารายละเอียดพร้อม system alert
- แก้วัน/รอบบิล ค.ศ.–พ.ศ. ทั้งระบบด้วยตัวแปลงกลาง และเพิ่มช่องค้นหา/กรองในหน้ารายการหลัก
- production backend รุ่นล่าสุด SHA-256 `f02deb959dde76647b366d24e1e804b7958af4552b4ca715b615333783e997c6`; rollback set `/home/fang/line_migration_backups/20260917-002953-pre-flex-ui`
- build/sign/install แอปรอบ workflow ล่าสุดบน iPhone “F” สำเร็จ

## หลักฐานทดสอบล่าสุด

| พื้นที่ | ผล |
| --- | --- |
| Backend | `go test ./...`, `go test -race ./handlers` และ `go vet ./...` ผ่าน |
| LINE maintenance payload | automated tests ครอบคลุม status, quote, approve/reject, bill, JSON/date และ outbox persistence/retry |
| iOS maintenance/sync | `MaintenanceWorkflowTests` + `CoreDataSafetyTests` รวม 21 tests ผ่านหลังเพิ่มกฎงานฟรี |
| Production | external health HTTP 200; outbox schema มีฟิลด์รายละเอียดและ `maintenance_record_id`; deploy มี backup/rollback |
| ข้อจำกัดหลักฐาน | ยังไม่ได้ทำ live quote/payment UAT ครบวงจร เพราะไม่ควรเปลี่ยนสถานะงานของลูกบ้านจริงโดยพลการ |

## สิ่งที่ต้องทำต่อทันที

1. เตรียม maintenance record และ LINE account สำหรับ UAT ที่ได้รับอนุญาต
2. ทดสอบทั้งอนุมัติและปฏิเสธใบเสนอราคา รวม stale/unauthorized action
3. ตรวจว่า snapshot หลัง LINE action ปรากฏในแอป และอุปกรณ์อีกเครื่องเห็นสถานะเดียวกัน
4. ทดสอบ Flex บิล → ส่งสลิป → แอปเห็นหลักฐาน → ผู้ดูแลตรวจรับ
5. บันทึกเวลา, record ID แบบไม่เปิดเผยข้อมูลส่วนบุคคล, outbox state, attempts และภาพผลลัพธ์ลง checklist
6. หลัง workflow UAT ผ่าน ให้ทำ P0 ตามลำดับใน `PENDING_WORK.md`; อย่าเลื่อนฟีเจอร์ตกแต่งขึ้นมาก่อน data/security blockers

## สิ่งที่ยังไม่เสร็จ

สรุปเฉพาะหัวข้อหลัก: provider secret rotation, UAT สอง iPhone/สองบัญชี, protocol-2 device proof, media cleanup/retention, full invoice/refund/void ledger, production restore drill, UI automation, monitoring/incident process, APNs, localization, accessibility และ performance soak รายละเอียดและเกณฑ์ปิดอยู่ใน [PENDING_WORK.md](PENDING_WORK.md)
