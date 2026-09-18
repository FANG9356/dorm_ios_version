# สถานะการทำงานปัจจุบัน

อัปเดตล่าสุด: 18 กันยายน 2569 (Asia/Bangkok)

## กำลังทำ / รอตรวจ

| งาน | สถานะ | สิ่งที่เสร็จแล้ว | สิ่งที่ต้องทำเพื่อปิด |
| --- | --- | --- | --- |
| Maintenance quote → approval/reject → repair → bill → slip | รอตรวจ UAT | โค้ด iOS/backend, validation, LINE Flex, outbox และ production deploy เสร็จ | สร้างข้อมูลทดสอบที่ได้รับอนุญาต แล้วทดสอบอนุมัติ/ปฏิเสธจาก LINE, sync กลับแอป, รับ Flex บิล และส่งสลิปครบวงจร |
| งานซ่อมไม่มีค่าใช้จ่าย | รอตรวจ UAT | อนุญาตข้าม quote และ payment ไปซ่อม/เสร็จสิ้นตามกฎ | ทดสอบบนอุปกรณ์จริงและยืนยันว่าไม่สร้างบิลหรือขออนุมัติโดยไม่จำเป็น |
| Protocol 2 production cutover | เสร็จแล้ว | production ตั้ง `ALLOW_LEGACY_SYNC_PUSH=false`; iPhone จริง rebase conflict และ sync ถึง snapshot v161 สำเร็จโดย dirty/pending เป็น 0 | ติดตาม log ต่อเนื่องและยังต้องทำ UAT สองเครื่อง/สองบัญชีแยกต่างหาก |
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
- รุ่น workflow approval ที่เคย deploy คือ SHA-256 `d4e0f718ff73c371796f8ca5adc4f9964d755d132cced1e9a94de7cc66db4351`; รุ่น production ปัจจุบันและ rollback ล่าสุดให้ยึดตารางหลักฐานด้านล่าง
- แก้ LINE API 400 ของ Flex ใบเสนอราคาและบิลค่าซ่อม: เปลี่ยน amount row จาก `alignItems: baseline` ที่ LINE ไม่รองรับเป็น baseline layout, เพิ่ม response body ใน delivery error และส่ง outbox ใบเสนอราคาห้อง 103 ยอด 200 บาทซ้ำสำเร็จเป็น `sent`
- แก้การอนุมัติราคาไม่ให้ข้ามไป “กำลังซ่อม”: LINE เปลี่ยนกลับเป็น “กำลังติดต่อช่าง”, เก็บ `quote_approved_at` เป็นสิทธิ์เริ่มซ่อมภายใน และให้แอดมินเป็นผู้บันทึก “กำลังซ่อม” เอง; ข้อมูลรอบนั้นถูก reconcile ที่ snapshot v129/outbox 34 และภายหลังปรับ success response ให้เหลือ Flex ใบเดียว
- build/sign/install แอปรอบ workflow ล่าสุดบน iPhone “F” สำเร็จ รวมการอ่านธงอนุมัติและล็อกยอดที่อนุมัติแล้ว
- แก้กรณีข้อมูลแจ้งซ่อมจาก LINE อยู่ใน tenant DB/snapshot แต่ไม่เข้าแอปเมื่ออุปกรณ์มี local dirty record: เมื่อ push พบ 409 แอปจะดึง snapshot ใหม่, rebase ข้อมูลในเครื่อง และ push ซ้ำ พร้อม sync เมื่อเปิด dashboard/หน้าแจ้งซ่อม
- ทำ `ปฏิเสธค่าใช้จ่าย` เป็นสถานะปลายทางที่ backend materialize ได้ ไม่ทำให้ snapshot ที่รับแล้วตอบ HTTP 500 และไม่ทำให้แอปติดวงจร conflict
- ปรับ Flex ปฏิเสธใบเสนอราคาเป็นขาว–เทาแบบกระชับ และให้ approve/reject success path ส่ง Flex เพียงใบเดียว; text reply ใช้เฉพาะ error/fallback

## หลักฐานทดสอบล่าสุด

| พื้นที่ | ผล |
| --- | --- |
| Backend | `go test ./...`, `go test -race ./handlers` และ `go vet ./...` ผ่าน |
| LINE maintenance payload | automated tests ครอบคลุม status, quote, approve/reject, bill, JSON/date, outbox persistence/retry และป้องกัน `alignItems: baseline` ที่ LINE ปฏิเสธ |
| iOS maintenance/sync | `MaintenanceWorkflowTests` 4/4 + `CoreDataSafetyTests` 19/19 รวม 23/23 ผ่าน รวม conflict rebase และ paid repair เริ่มได้หลังมี approval marker เท่านั้น |
| Production | external health ผ่าน; รายการ LINE server id 183 อยู่ใน tenant DB, snapshot และ SwiftData ตรงกัน; iPhone checkpoint v161, dirty 0, pending 0; backend ล่าสุด SHA-256 `32a26c80c5793f533a1e658790c09aed423b51f104a4e3120496ce5793f07f89` และมี backup/rollback |
| ข้อจำกัดหลักฐาน | ยังไม่ได้ทำ live quote/payment UAT ครบวงจร เพราะไม่ควรเปลี่ยนสถานะงานของลูกบ้านจริงโดยพลการ |

## สิ่งที่ต้องทำต่อทันที

1. เตรียม maintenance record และ LINE account สำหรับ UAT ที่ได้รับอนุญาต
2. ทดสอบทั้งอนุมัติและปฏิเสธใบเสนอราคา รวม stale/unauthorized action
3. ตรวจว่า snapshot หลัง LINE action ปรากฏในอุปกรณ์อีกเครื่องและบัญชีทดสอบแยก โดยไม่ข้าม tenant; เส้นทาง LINE → iPhone เครื่อง `F` ผ่านแล้วหนึ่งเหตุการณ์
4. ทดสอบ Flex บิล → ส่งสลิป → แอปเห็นหลักฐาน → ผู้ดูแลตรวจรับ
5. บันทึกเวลา, record ID แบบไม่เปิดเผยข้อมูลส่วนบุคคล, outbox state, attempts และภาพผลลัพธ์ลง checklist
6. หลัง workflow UAT ผ่าน ให้ทำ P0 ตามลำดับใน `PENDING_WORK.md`; อย่าเลื่อนฟีเจอร์ตกแต่งขึ้นมาก่อน data/security blockers

## สิ่งที่ยังไม่เสร็จ

สรุปเฉพาะหัวข้อหลัก: provider secret rotation, UAT สอง iPhone/สองบัญชี, maintenance quote/bill/slip UAT ครบวงจร, media cleanup/retention, full invoice/refund/void ledger, production restore drill, UI automation, monitoring/incident process, APNs, localization, accessibility และ performance soak รายละเอียดและเกณฑ์ปิดอยู่ใน [PENDING_WORK.md](PENDING_WORK.md)
