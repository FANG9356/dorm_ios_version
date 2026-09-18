# รายงานการดำเนินงานทุกครั้ง — DormiNetX

เริ่มใช้: 17 กันยายน 2569 เวลา 19:47 น. (Asia/Bangkok)

เอกสารนี้เป็นบันทึกแบบ append-only สำหรับทุกงานที่ทำกับโปรเจกต์ ไม่ว่าจะเป็นการตรวจสอบ วิเคราะห์ แก้โค้ด แก้เอกสาร ทดสอบ build deploy เปลี่ยนข้อมูล หรือประสานงาน เพื่อให้ผู้รับช่วงทราบว่าเกิดอะไรขึ้นและตรวจสอบต่อได้

## กติกาบังคับ

- เพิ่มรายการใหม่ทุกครั้งก่อนส่งมอบผลของงาน ห้ามแก้ทับหรือลบรายการเก่า ยกเว้นแก้คำผิดโดยต้องระบุว่าแก้ไขย้อนหลัง
- บันทึกแม้งานนั้นเป็นเพียงการตรวจสอบและไม่มีไฟล์เปลี่ยนแปลง
- ระบุให้ชัดว่าเป็นเพียงการแก้ในเครื่อง, ทดสอบแล้ว, deploy แล้ว หรือผ่าน UAT จริงแล้ว ห้ามใช้แทนกัน
- ถ้ามีการเปลี่ยนข้อมูล ให้ระบุขอบเขตข้อมูล วิธีสำรอง และวิธีย้อนกลับ โดยไม่ใส่ข้อมูลส่วนบุคคลจริง
- ห้ามบันทึก token, password, API key, session, secret หรือข้อมูลลูกบ้านที่ระบุตัวตนได้
- หากผลทดสอบไม่ผ่านหรือยังตรวจไม่ได้ ให้บันทึกตามจริงพร้อมความเสี่ยงและงานที่ต้องทำต่อ

## รูปแบบรายการมาตรฐาน

```md
## YYYY-MM-DD HH:mm — ชื่องาน

- คำขอ/เป้าหมาย:
- สิ่งที่ดำเนินการ:
- ไฟล์หรือระบบที่กระทบ:
- การเปลี่ยนข้อมูล/production: ไม่มี หรือรายละเอียดที่ไม่เปิดเผยข้อมูลสำคัญ
- การตรวจสอบและหลักฐาน:
- สถานะ deploy/UAT:
- ผลลัพธ์:
- ความเสี่ยง/สิ่งที่ต้องทำต่อ:
```

## 2026-09-17 19:47 — จัดตั้งรายงานการดำเนินงานถาวร

- คำขอ/เป้าหมาย: ให้บันทึกทุกการแก้ไขและทุกการดำเนินงานเป็นรายงานในไฟล์ใหม่ภายในโฟลเดอร์ `project-tracking`
- สิ่งที่ดำเนินการ: สร้างเอกสารรายงานแบบ append-only พร้อมกำหนดหัวข้อบังคับ และปรับหน้าเริ่มต้นของโฟลเดอร์ให้ชี้มายังรายงานนี้
- ไฟล์หรือระบบที่กระทบ: `project-tracking/ACTIVITY_REPORT.md`, `project-tracking/README.md`
- การเปลี่ยนข้อมูล/production: ไม่มี
- การตรวจสอบและหลักฐาน: ตรวจรูปแบบ Markdown และตรวจ diff ของไฟล์เอกสาร
- สถานะ deploy/UAT: เป็นการเปลี่ยนเอกสารใน working tree ยังไม่เกี่ยวกับการ deploy หรือ UAT ของระบบ
- ผลลัพธ์: ตั้งแต่งานนี้เป็นต้นไป ทุกงานต้องเพิ่มรายการใหม่ในไฟล์นี้ก่อนรายงานผลแก่ผู้ใช้
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ผู้ทำงานรายถัดไปต้องปฏิบัติตามกติกานี้อย่างสม่ำเสมอ และไม่บันทึกข้อมูลลับหรือข้อมูลส่วนบุคคล

## 2026-09-18 09:24 — แก้ขั้นตอนหลังลูกบ้านอนุมัติค่าซ่อมในแอป iOS

- คำขอ/เป้าหมาย: ทำงานต่อจากปัญหาที่หลังลูกบ้านอนุมัติใบเสนอราคาแล้ว ระบบต้องแสดง “กำลังติดต่อช่าง” ก่อน และให้แอดมินเป็นผู้บันทึก “กำลังซ่อม” เองโดยไม่ข้ามขั้น
- สิ่งที่ดำเนินการ: ตรวจเส้นทาง LINE approval, outbox, snapshot และกติกาสถานะใน iOS; พบ regression ที่ iOS ยังล็อกการเปลี่ยนจาก “กำลังติดต่อช่าง” เป็น “กำลังซ่อม” สำหรับงานที่มีค่าใช้จ่ายแม้มี `quoteApprovedAt`; แก้กติกาให้ปลดล็อกเฉพาะเมื่อมี approval marker; ห้ามข้ามตรงจาก “รออนุมัติค่าใช้จ่าย” ไป “กำลังซ่อม”; ทำ “ปฏิเสธค่าใช้จ่าย” เป็นสถานะปลายทาง; ปรับ tests ให้ครอบคลุมสถานะทั้ง 7 ค่าและเงื่อนไขดังกล่าว
- ไฟล์หรือระบบที่กระทบ: `DormAppSwift_Sources/DormiNetX/DormiNetX/Views/MaintenanceTabView.swift`, `DormAppSwift_Sources/DormiNetX/DormiNetXTests/MaintenanceWorkflowTests.swift`, แอป Debug บนอุปกรณ์ iPhone ชื่อ `F`
- การเปลี่ยนข้อมูล/production: ไม่มีการแก้ฐานข้อมูลหรือ deploy backend; ติดตั้งแอป Debug รุ่นที่แก้แล้วทับบนอุปกรณ์ทดสอบ โดยไม่ล้างข้อมูลแอป
- การตรวจสอบและหลักฐาน: ก่อนแก้ targeted iOS tests ล้ม 7 จุด; หลังแก้ `MaintenanceWorkflowTests` ผ่าน 4/4, `MaintenanceWorkflowTests + CoreDataSafetyTests` ผ่าน 22/22, `go test ./...` ผ่าน, `go test -race ./handlers` ผ่าน, `go vet ./...` ผ่าน, signed device build สำเร็จ และ `git diff --check` ผ่านหลังแก้ whitespace
- สถานะ deploy/UAT: build, ติดตั้ง และเปิดแอปบน iPhone `F` สำเร็จแล้ว; backend production ไม่ได้เปลี่ยนในรอบนี้; ยังไม่ถือว่า end-to-end UAT จริงผ่านจนกว่าจะสร้างใบเสนอราคาใหม่ กดอนุมัติจาก LINE แล้วตรวจการ sync/บันทึก “กำลังซ่อม” บนอุปกรณ์จริง
- ผลลัพธ์: ลำดับที่ตั้งใจคือ `รออนุมัติค่าใช้จ่าย` → ลูกบ้านอนุมัติใน LINE → `กำลังติดต่อช่าง` → แอดมินเปิดการ์ดและบันทึก `กำลังซ่อม`; ระบบไม่ข้ามขั้นให้อัตโนมัติ
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ทำ controlled UAT ด้วยรายการทดสอบใหม่หนึ่งรายการ ตรวจว่า LINE ส่งทั้งข้อความยืนยันและ Flex “กำลังติดต่อช่าง” เพียงครั้งเดียว ตรวจว่าแอปได้รับ `quoteApprovedAt` และให้แอดมินบันทึก “กำลังซ่อม” ได้ จากนั้นตรวจ Flex สถานะ “กำลังซ่อม” ที่ส่งกลับไปยังลูกบ้าน

## 2026-09-18 09:53 — แก้รายการแจ้งซ่อมจาก LINE ไม่เข้าแอปเมื่อมีข้อมูลในเครื่องรอซิงก์

- คำขอ/เป้าหมาย: แก้กรณีลูกบ้านแจ้ง “ไฟดับ” ผ่าน LINE สำเร็จ แต่รายการไม่ปรากฏในหน้าแจ้งซ่อมของแอปและแอปแจ้งว่ามีข้อมูลใหม่จากอีกเครื่อง
- สิ่งที่ดำเนินการ: ตรวจฐานข้อมูล production และยืนยันว่ารายการใหม่ถูกสร้างเป็น maintenance server id 183 และอยู่ใน snapshot แล้ว; ตรวจฐานข้อมูล SwiftData/จุดตรวจการซิงก์บน iPhone จริง; พบสองสาเหตุต่อเนื่อง ได้แก่ (1) เมื่ออุปกรณ์มี local dirty record การ auto-push พบ HTTP 409 แล้วหยุดแทนที่จะดึง snapshot ใหม่มารวม และ (2) backend บันทึก snapshot ที่รวมแล้วแต่ materialize ไปยังฐานข้อมูล LINE ไม่ผ่าน เพราะตัวตรวจสถานะไม่รู้จักสาขา `ปฏิเสธค่าใช้จ่าย` จึงตอบ HTTP 500 และทำให้แอปพยายามซิงก์ซ้ำ; แก้ iOS ให้ conflict แล้ว rebase local dirty records บน remote snapshot อัตโนมัติ, เพิ่มการซิงก์เมื่อหน้าหลักและหน้าแจ้งซ่อมเปิด, เพิ่ม regression test; แก้ backend ให้รับการปฏิเสธจาก `กำลังติดต่อช่าง` หรือ `รออนุมัติค่าใช้จ่าย` และกำหนดให้การปฏิเสธเป็นสถานะปลายทาง พร้อมบันทึกสาเหตุ materialization ลง server log; เพิ่มสคริปต์ตรวจ maintenance/snapshot โดยไม่แสดง credential
- ไฟล์หรือระบบที่กระทบ: `DormAppSwift_Sources/DormiNetX/DormiNetX/Services/SyncManager.swift`, `DormAppSwift_Sources/DormiNetX/DormiNetX/Views/RoomListView.swift`, `DormAppSwift_Sources/DormiNetX/DormiNetX/Views/MaintenanceTabView.swift`, `DormAppSwift_Sources/DormiNetX/DormiNetXTests/CoreDataSafetyTests.swift`, `backend-dorm/handlers/line_snapshot.go`, `backend-dorm/handlers/maintenance_workflow_test.go`, `backend-dorm/handlers/sync_push.go`, `backend-dorm/scripts/inspect_recent_maintenance.exp`, backend production และแอป Debug บน iPhone `F`
- การเปลี่ยนข้อมูล/production: deploy backend production แล้วด้วยกระบวนการที่สำรอง binary, master database และ tenant databases ก่อนสลับรุ่น; backup อยู่ที่ `/home/fang/line_migration_backups/20260917-195110-pre-flex-ui`; ระหว่างวิเคราะห์ snapshot version เพิ่มจาก 148 ถึง 159 เพราะ server รุ่นเดิมบันทึก snapshot ก่อนตอบ materialization error และแอปลอง rebase ซ้ำ รายการธุรกิจไม่ถูกลบ; หลัง deploy การรวมข้อมูลสำเร็จที่ version 161 และฐาน tenant ปรับสถานะรายการเดิมที่ถูกปฏิเสธให้ตรงกับ snapshot; ติดตั้ง Debug app ทับบน iPhone โดยไม่ล้าง app data
- การตรวจสอบและหลักฐาน: production ก่อนแก้มี server id 183 ห้อง 103 รายการ “ไฟดับ” สถานะ `รอดำเนินการ` ใน tenant DB และ snapshot แต่ฐาน iPhone มีเพียงรายการเดิม, checkpoint version 142 และ pending 1; console จากเครื่องจริงแสดง `Sync conflict detected` ตามด้วย `Sync stored, but LINE data preparation failed`; `go test ./...`, `go test -race ./handlers` และ `go vet ./...` ผ่าน; iOS `CoreDataSafetyTests` 19/19 และ `MaintenanceWorkflowTests` 4/4 รวม 23/23 ผ่าน; signed physical-device build สำเร็จ; หลัง deploy/เปิดแอปใหม่ ฐานบน iPhone มี server id 183 “ไฟดับ” สถานะ `รอดำเนินการ`, dirty 0, pending 0 และ checkpoint version 161 ขณะที่ production latest snapshot เป็น version 161 และ tenant DB ตรงกัน; health check ตอบ `online`
- สถานะ deploy/UAT: backend production deploy สำเร็จและ service active; แอปที่แก้แล้ว build, ติดตั้ง และเปิดบน iPhone `F` สำเร็จ; data-level end-to-end UAT สำหรับเหตุการณ์ที่รายงานผ่านแล้ว เพราะตรวจทั้ง tenant DB → snapshot → SwiftData บนอุปกรณ์จริง; ยังไม่ได้ให้ผู้ใช้ยืนยันรูปลักษณ์หน้าแจ้งซ่อมด้วยสายตาหลัง refresh
- ผลลัพธ์: รายการที่แจ้งจาก LINE เข้าสู่แอปแล้วโดยข้อมูลเดิมในเครื่องไม่สูญหาย; แอปสามารถรวมข้อมูลจาก LINE กับ local dirty record และปิด pending ได้; backend รองรับสถานะปฏิเสธค่าใช้จ่ายตาม workflow จริงและไม่ค้าง materialization ในกรณีนี้
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ให้ผู้ใช้เปิดหน้าแจ้งซ่อมหรือกด refresh หนึ่งครั้งเพื่อยืนยันการ์ด “ไฟดับ” บน UI; ติดตาม server log ว่าไม่มี `LINE materialization failed` เพิ่ม; งานระยะถัดไปควรปรับเส้นทาง sync push ให้ไม่ทิ้ง accepted snapshot พร้อม HTTP 500 เมื่อ side-effect หลังบันทึกล้มเหลว เพื่อลดโอกาส snapshot version เพิ่มซ้ำจาก failure ประเภทอื่น

## 2026-09-18 10:04 — ปรับ Flex การ์ดปฏิเสธใบเสนอราคาเป็นโทนขาว–เทา

- คำขอ/เป้าหมาย: ลดการใช้สีแดงในการ์ด LINE หลังลูกบ้านปฏิเสธใบเสนอราคา และทำให้หน้าตากระชับพรีเมียมขึ้น
- สิ่งที่ดำเนินการ: เปลี่ยนหัวการ์ดจากข้อความปฏิเสธสีแดงเป็นหัวกลาง `แจ้งซ่อม` สี charcoal; ทำชื่อรายการเป็นตัวหนาสีดำ; เพิ่มเส้นคั่นบาง; เปลี่ยนกล่องแจ้งเตือนแดงเป็นกล่องเทาอ่อนที่แยก label `ผลการพิจารณา`, สถานะ `ไม่อนุมัติใบเสนอราคา` และคำอธิบายสั้น `ระบบจะยกเลิกรายการนี้ภายใน 24 ชั่วโมง`; ลด padding และ margin เพื่อให้การ์ดสั้นลง; เปลี่ยน alt text ให้สื่อว่าเป็นผลการพิจารณา; เพิ่ม regression test ที่ตรวจข้อความ วันเวลา โทนสี และห้ามสีแดงเดิมกลับมา
- ไฟล์หรือระบบที่กระทบ: `backend-dorm/handlers/line_bot.go`, `backend-dorm/handlers/line_bot_maintenance_test.go`, backend production
- การเปลี่ยนข้อมูล/production: ไม่มีการแก้ข้อมูลลูกบ้านหรือส่งข้อความ LINE ซ้ำ; deploy binary backend production แล้ว โดยสำรอง binary, master database และ tenant databases ไว้ที่ `/home/fang/line_migration_backups/20260917-200400-pre-flex-ui`
- การตรวจสอบและหลักฐาน: test ใหม่ยืนยันว่าการ์ดมี `#F3F4F6` และไม่มี `#DC2626`, `#B91C1C`, `#FEE2E2`; `go test ./...`, `go test -race ./handlers` และ `go vet ./...` ผ่าน; deployment health check ตอบ `online` และ service เป็น `active`; binary SHA-256 หลัง deploy คือ `0cb92224751a1456eedfcb3962b72df694c5219ea399cd59a663753671f55721`
- สถานะ deploy/UAT: backend production deploy สำเร็จ; การ์ดที่ส่งใหม่หลัง deploy จะใช้ UI ใหม่ ส่วนการ์ดเก่าในประวัติ LINE จะไม่เปลี่ยนย้อนหลัง; ยังไม่ได้สร้างเหตุการณ์ปฏิเสธใหม่เพื่อส่งข้อความจริงเพราะจะกระทบ workflow/ลูกบ้าน
- ผลลัพธ์: Flex การ์ดปฏิเสธใช้โทนขาว ดำ และเทาเหมือนการ์ดสถานะอื่น ไม่มีพื้นแดงหรือหัวแดง และมีความสูงลดลง
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ทดสอบด้วยรายการทดลองที่ผูกกับบัญชีทดสอบเมื่อพร้อม เพื่อยืนยันการเรนเดอร์บน LINE iOS จริง; หากต้องการ accent เพิ่ม ควรใช้สีเพียงจุดเล็ก เช่น icon หรือเส้นสถานะ แทนการถมพื้นทั้งกล่อง

## 2026-09-18 10:17 — ตัดข้อความยืนยันซ้ำหลังตอบใบเสนอราคางานซ่อม

- คำขอ/เป้าหมาย: แก้ประสบการณ์ LINE ที่หลังลูกบ้านอนุมัติใบเสนอราคาแล้วได้รับทั้ง text bubble และ Flex Card ซึ่งสื่อยอดเงิน/สถานะเดียวกันซ้ำสองครั้ง
- สิ่งที่ดำเนินการ: ปรับ `handleMaintenanceQuoteDecision` ให้หลังบันทึกผลสำเร็จ enqueue และส่ง Flex Card สถานะผ่าน notification outbox เพียงช่องทางเดียว; ยกเลิก text reply บน success path ทั้งกรณีอนุมัติและปฏิเสธเพื่อให้พฤติกรรมสอดคล้องกัน; คง text reply ไว้เฉพาะกรณี validation, กดซ้ำ, สถานะเปลี่ยนแล้ว หรือ enqueue Flex ล้มเหลว โดยกรณี enqueue ล้มเหลวใช้ข้อความกลางเป็น fallback เพื่อไม่ให้ผู้ใช้ไม่ได้รับการตอบสนอง
- ไฟล์หรือระบบที่กระทบ: `backend-dorm/handlers/line_bot.go`, backend production
- การเปลี่ยนข้อมูล/production: ไม่มีการแก้ข้อมูลลูกบ้านและไม่ได้สร้าง/ตอบใบเสนอราคาทดลอง; deploy backend production แล้ว พร้อมสำรอง binary, master database และ tenant databases ที่ `/home/fang/line_migration_backups/20260917-201712-pre-flex-ui`
- การตรวจสอบและหลักฐาน: ตรวจเส้นทาง postback → conditional update → notification outbox → Flex sender; `go test ./...`, `go test -race ./handlers` และ `go vet ./...` ผ่าน; deployment health check ตอบ `online`, service เป็น `active`; binary SHA-256 หลัง deploy คือ `32a26c80c5793f533a1e658790c09aed423b51f104a4e3120496ce5793f07f89`
- สถานะ deploy/UAT: backend production deploy สำเร็จ; ยังไม่ได้กดอนุมัติใบเสนอราคาใหม่บนบัญชี LINE จริง เพราะจะเปลี่ยนสถานะงานซ่อมจริง
- ผลลัพธ์: การตอบใบเสนอราคาสำเร็จหนึ่งครั้งจะได้ Flex Card เพียงใบเดียว ไม่มีข้อความยืนยันธรรมดาซ้ำด้านบน; ความทนทานของ outbox และ retry ยังอยู่ครบ
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ทดสอบกับรายการทดลองหนึ่งรายการเมื่อพร้อม และตรวจว่าหลังแตะ `อนุมัติ` หรือ `ไม่อนุมัติ` มีเพียงการ์ดเดียว; หาก LINE push ล่าช้าชั่วคราว การ์ดอาจมาช้าตามรอบ retry แต่จะไม่ถูกแทนด้วยข้อความซ้ำ เว้นแต่ระบบ enqueue ล้มเหลวจริง

## 2026-09-18 10:22 — อัปเดตเอกสารสถานะ แบบประเมิน และคู่มือส่งต่อ

- คำขอ/เป้าหมาย: อัปเดตเอกสารให้ผู้รับช่วงเห็นตรงกันว่าระบบแก้อะไรแล้ว มีหลักฐานใด งานใดยังค้าง และควรทำอะไรต่อ
- สิ่งที่ดำเนินการ: ปรับหน้าเริ่มต้นของ tracking, วิสัยทัศน์, สถานะงาน, backlog, handoff และ LINE/UI audit ให้รวมผลแก้ sync conflict, terminal rejection, Flex ปฏิเสธแบบ monochrome และการตัดข้อความซ้ำ; ปิดรายการ protocol-2 device proof จากหลักฐานบน iPhone จริง; เพิ่ม issue `SYNC-014`, `LINE-015`, `LINE-016`; เพิ่มแบบประเมินฉบับวันที่ 18 กันยายนและเชื่อมเป็นฉบับล่าสุด
- ไฟล์หรือระบบที่กระทบ: `project-tracking/README.md`, `PROJECT_VISION.md`, `WORK_STATUS.md`, `PENDING_WORK.md`, `HANDOFF.md`, `UI_LINE_AUDIT_CHECKLIST.md`, `ACTIVITY_REPORT.md` และ `project-review/DormiNetX-Assessment-2026-09-18.md`
- การเปลี่ยนข้อมูล/production: ไม่มีการแก้โค้ด, ฐานข้อมูล, LINE message หรือ production deployment ในงานเอกสารรอบนี้
- การตรวจสอบและหลักฐาน: ตรวจ `git diff --check`; ตรวจข้อความอ้างอิงเวอร์ชัน/ผลทดสอบเก่า; ตรวจลิงก์ Markdown ภายในไฟล์ที่แก้; ใช้หลักฐานเดิมที่บันทึกไว้ ได้แก่ targeted iOS 23/23, backend test/race/vet, production snapshot v161, dirty 0, pending 0 และ backend SHA-256 `32a26c80c5793f533a1e658790c09aed423b51f104a4e3120496ce5793f07f89`
- สถานะ deploy/UAT: เอกสารอัปเดตแล้วเท่านั้น ไม่มี deploy/UAT ใหม่; คะแนนขยับเป็น Feature 93%, Controlled pilot 90%, Production readiness 81% เพราะปิด protocol-2 device proof ด้วยหลักฐานจริง ไม่ใช่จาก build/test อย่างเดียว
- ผลลัพธ์: ผู้รับช่วงสามารถเริ่มจาก `project-tracking/README.md` และเห็น production รุ่นล่าสุด, rollback, behavior ที่ห้าม regression, release blockers และเกณฑ์ UAT ที่ยังเหลือในชุดเอกสารเดียวกัน
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ยังต้องทำ maintenance consent/billing controlled UAT, LINE live render ของ Flex รุ่นล่าสุด, UAT สอง iPhone/สองบัญชี, secret rotation, media lifecycle, financial ledger และ production restore drill; เมื่อมีการทำงานครั้งถัดไปต้องเพิ่มรายการใหม่ในรายงานนี้ตามกติกา append-only

## 2026-09-18 10:33 — เพิ่มกฎและ runbook สำหรับ Server, Deploy และ iOS Build

- คำขอ/เป้าหมาย: ทำเอกสารให้ Terminal/Agent อื่นสามารถเข้า server, ตรวจหรือรันระบบ, deploy backend และ build/install แอปต่อได้ โดยทราบ user, IP, path และขั้นตอนที่ถูกต้อง
- สิ่งที่ดำเนินการ: เพิ่ม `AGENTS.md` เป็นกฎระดับ repository; เพิ่ม operations runbook ที่ระบุ production host `202.29.232.28`, user `fang`, service/path/database/port, ตำแหน่งอ้างอิง credential, read-only checks, local backend tests, source archive, safe deploy/rollback, Xcode simulator/device discovery, targeted tests และ build/sign/install บน iPhone; เชื่อม runbook จาก tracking README และ handoff
- ไฟล์หรือระบบที่กระทบ: `AGENTS.md`, `docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md`, `project-tracking/README.md`, `project-tracking/HANDOFF.md`, `project-tracking/ACTIVITY_REPORT.md`
- การเปลี่ยนข้อมูล/production: ไม่มีการ SSH เข้า production, ไม่ restart/deploy service, ไม่เปลี่ยนฐานข้อมูล และไม่ build/install แอปในรอบเอกสารนี้
- การตรวจสอบและหลักฐาน: ตรวจค่า host/user/service/path จากสคริปต์ deploy และเอกสาร production; ตรวจ Xcode destinations และอุปกรณ์จริงด้วย `xcodebuild -showdestinations` และ `xcrun devicectl list devices`; ตรวจ branch/remote ปัจจุบัน; ตรวจ `git diff --check`, ลิงก์ Markdown และยืนยันว่าเอกสารใหม่ไม่มีสำเนารหัสผ่านจริง
- สถานะ deploy/UAT: เป็นการจัดทำเอกสารและกฎเท่านั้น ไม่มี deploy หรือ UAT ใหม่
- ผลลัพธ์: Terminal ใหม่เริ่มจาก `AGENTS.md` และทำตาม `docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md` ได้ โดยใช้ safe deploy ที่สำรอง/health/rollback อัตโนมัติและมีคำสั่ง build/install iOS ที่ตรวจ device ID ก่อนทุกครั้ง
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: credential ยังฝังใน `.exp` รุ่นเก่าที่ Git ติดตามอยู่ ถือเป็น P0 เดิม; ต้อง rotate/revoke แล้วเปลี่ยนเป็น SSH key/local secret store ห้ามทำสำเนารหัสลงเอกสารหรือ command history เพิ่ม

## 2026-09-18 10:37 — อ่านเอกสารโปรเจกต์ทั้งหมด (session เริ่มต้น)

- คำขอ/เป้าหมาย: อ่านและสรุปเอกสารโปรเจกต์ DormiNetX เพื่อทำความเข้าใจสถานะและบริบทของระบบ
- สิ่งที่ดำเนินการ: อ่าน `project-tracking/README.md`, `WORK_STATUS.md`, `PENDING_WORK.md`, `HANDOFF.md`, `PROJECT_VISION.md`, `ACTIVITY_REPORT.md` ครบทุกไฟล์; ตรวจ `git status --short` พบไฟล์ที่แก้แล้วใน working tree
- ไฟล์หรือระบบที่กระทบ: ไม่มีการแก้ไขไฟล์โค้ดหรือระบบ; เพิ่มรายการนี้ใน `ACTIVITY_REPORT.md` เท่านั้นตามกติกา
- การเปลี่ยนข้อมูล/production: ไม่มี
- การตรวจสอบและหลักฐาน: อ่านเอกสารครบ; git status แสดง M project-tracking/ACTIVITY_REPORT.md, M project-tracking/HANDOFF.md, M project-tracking/README.md และไฟล์ untracked ใหม่ AGENTS.md กับ docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md
- สถานะ deploy/UAT: การอ่านเอกสารเท่านั้น ไม่มี deploy หรือ UAT ใหม่
- ผลลัพธ์: เข้าใจบริบทระบบ ดูสรุปด้านล่าง
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: รอคำสั่งถัดไปจากผู้ใช้

## 2026-09-18 10:45 — Phase 1: แก้ Bug GET /api/maintenances และเพิ่ม Test Coverage

- คำขอ/เป้าหมาย: ดำเนินการตามแผนที่ผู้ใช้อนุมัติ — Phase 1 Code Audit & Bug Fix
- สิ่งที่ดำเนินการ:
  1. เพิ่ม `LastUpdated`, `QuoteApprovedAt`, `ExternalID` ใน `models.Maintenance` struct
  2. แก้ `GET /api/maintenances` query ใน `api_maintenances.go` บรรทัด 25 ให้ดึง `last_updated`, `quote_approved_at`, `external_id` ด้วย และแก้ `Scan()` ให้รับ 3 field ใหม่ — iOS จะเห็น approval marker ผ่าน REST path นี้ได้แล้ว
  3. แก้ `notifyMaintenanceStatus` บรรทัด 256 จากใช้เฉพาะ `'กำลังพักอาศัย'` เป็นรวม `'จอง'` ด้วย (ตรงกับ `maintenanceHasLineRecipient`) — ลูกบ้านที่ยัง `'จอง'` จะได้รับ LINE notification หลังสถานะซ่อมเปลี่ยนแล้ว
  4. เพิ่ม test 4 รายการใน `line_bot_maintenance_test.go`: `TestMaintenanceFreeJobFlexHasNoQuoteButton`, `TestMaintenanceQuoteFlexRejectsZeroCost`, `TestMaintenanceStaleApproveDetection`, `TestMaintenanceNonQuoteStatusDoesNotRequireID`
- ไฟล์หรือระบบที่กระทบ: `backend-dorm/models/models.go`, `backend-dorm/handlers/api_maintenances.go`, `backend-dorm/handlers/line_bot_maintenance_test.go`
- การเปลี่ยนข้อมูล/production: ไม่มีการ deploy production หรือเปลี่ยนข้อมูลในรอบนี้ — แก้โค้ดในเครื่องและทดสอบเท่านั้น
- การตรวจสอบและหลักฐาน: `go test ./...` ผ่าน; `go test -race ./handlers` ผ่าน 7.5s; `go vet ./...` ผ่าน; `go test -v -run TestMaintenance ./handlers` แสดง 12 test PASS (รวม 4 test ใหม่)
- สถานะ deploy/UAT: แก้ในเครื่องแล้ว ยังไม่ deploy production; รอผลตรวจจากผู้ใช้เรื่อง LINE ก่อนดำเนิน Phase 2 deploy
- ผลลัพธ์: โค้ด backend มีความถูกต้องขึ้น 3 จุด และมี regression test เพิ่มอีก 4 รายการที่ครอบคลุม free-job bypass, stale action detection, zero-cost quote, และ non-quote status path
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: รอผลตรวจ LINE จากผู้ใช้ก่อน deploy Phase 2; Phase 3 iOS และ controlled UAT ตามลำดับหลังจากนั้น

## 2026-09-18 11:55 — แก้ Bug LINE Flex Card ซ้ำ (Duplicate Notification)

- คำขอ/เป้าหมาย: แก้ปัญหา LINE ส่งการ์ดสถานะซ้ำ 2 ครั้งจาก action เดียว (เช่น "กำลังติดต่อช่าง" ส่งมา 2 การ์ด)
- สาเหตุ: มี 2 notification path ยิงพร้อมกัน สำหรับ action เดียว:
  - Path A (REST API): PUT /api/maintenances → go notifyMaintenanceStatus() → ส่ง LINE โดยตรง (ไม่มี idempotency)
  - Path B (Snapshot): iOS push snapshot → MaterializeLineSnapshotAndNotify → outbox → ส่ง LINE (มี idempotency ผ่าน event_key)
  - เมื่อ admin เปลี่ยนสถานะผ่านแอป iOS ทำทั้ง 2 path พร้อมกัน จึงส่งซ้ำ
- สิ่งที่ดำเนินการ: ลบ go notifyMaintenanceStatus() ออกจาก REST PUT handler ทั้ง 2 จุด (JSON-body และ multipart) — เหลือเฉพาะ PushReceiptFlexMessage สำหรับกรณี slip payment confirmation
- ไฟล์ที่แก้: backend-dorm/handlers/api_maintenances.go
- การเปลี่ยนข้อมูล/production: ไม่มีการ deploy production — แก้โค้ดในเครื่องเท่านั้น
- การตรวจสอบและหลักฐาน: go build ./... ผ่าน; go test -count=1 ./handlers ผ่าน 1.396s; go test -race ./handlers ผ่าน; go vet ./... ผ่าน
- สถานะ deploy/UAT: รอ deploy production; ต้อง UAT ทดสอบ approve/reject บน LINE จริงว่าส่งครั้งเดียว
- ผลลัพธ์: LINE จะไม่ส่ง Flex card ซ้ำอีกเมื่อ admin เปลี่ยนสถานะในแอป — notification ส่งครั้งเดียวผ่าน outbox event_key
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: กรณี iOS offline notification จะล่าช้าจนกว่า iOS sync ใหม่ (ยอมรับได้ outbox มี retry); deploy แล้ว UAT end-to-end

## 2026-09-18 12:21 — แก้ไขการแสดงผล LINE Flex Message เมื่อลูกบ้านอนุมัติใบเสนอราคา

- คำขอ/เป้าหมาย: เปลี่ยนข้อความสถานะหลังจากลูกบ้านกด "อนุมัติ" ให้แสดงว่า "อนุมัติใบเสนอราคา" แทนคำว่า "กำลังติดต่อช่าง" และแนบ QR Code ช่องทางชำระเงินมาพร้อมกัน
- สิ่งที่ดำเนินการ: 
  - เพิ่มการตรวจสอบ `EventKey` ว่าเป็น `maintenance-quote-approved:` ในฟังก์ชัน `buildMaintenanceStatusFlexMessage`
  - สร้างฟังก์ชัน `buildMaintenanceQuoteApprovedFlexMessage` ที่คืนค่า Flex Message แบบ Carousel โดยประกอบด้วย 2 การ์ด (การ์ดอนุมัติ และ การ์ด QR Code ชำระเงิน)
  - เพิ่ม Unit Test `TestMaintenanceQuoteApprovedFlexMessage` เพื่อยืนยันว่าการสร้าง Carousel และข้อความอนุมัติทำงานได้ถูกต้อง
- ไฟล์ที่แก้: `backend-dorm/handlers/line_bot.go`, `backend-dorm/handlers/line_bot_maintenance_test.go`
- การตรวจสอบและหลักฐาน: รัน `go test ./...` ผ่านหมด, `go test -race ./handlers` ไม่มี race condition ตรวจพบ
- สถานะ deploy/UAT: โค้ดเสร็จสมบูรณ์ใน local รอการนำขึ้นทดสอบบน production ต่อไป

## 2026-09-18 12:29 — Deploy Backend (Flex Message UI Update)

- ขอบเขตการเปลี่ยน: นำโค้ดอัปเดต LINE Flex Message (เพิ่มการตรวจสอบ `EventKey` สำหรับ `maintenance-quote-approved:` และสร้าง Carousel พร้อม QR Code จำลอง) ขึ้น Production
- Test commands: `go test -count=1 ./handlers` (ผ่านทั้งหมด), `go test -race ./handlers` (ผ่านไม่มี race)
- NEW_SHA: `027834edbe68308eb32b29e51bc474fc90a1388dc037a5a74fe218fdcf487079`
- BACKUP_DIR: `/home/fang/line_migration_backups/20260917-222923-pre-flex-ui`
- Health / Service State: `active`, endpoint `/api/system/ping` ตอบ `{"status":"online"}`
- Schema/Data check: Table `maintenances` มี column ใหม่ครบถ้วน (cost, quote_approved_at, etc.)
- UAT ที่ทำจริง: รอทดสอบกด "อนุมัติ" บนใบเสนอราคาใน LINE จริงโดยผู้ใช้
- สิ่งที่ยังไม่ได้ทดสอบ: Edge case กรณี iOS ส่ง Sync ซ้ำซ้อนตอนเปลี่ยนสถานะ (แต่มี Unit test ครอบคลุมแล้ว)

## 2026-09-18 12:31 — แก้สี Flex Message UI อนุมัติใบเสนอราคา

- คำขอ/เป้าหมาย: ลูกบ้านแจ้งว่ากล่อง "อนุมัติใบเสนอราคา" ที่มีพื้นหลังสีเขียวและช่องทางการชำระเงินที่ใช้สีน้ำเงินนั้นใช้สีมากไป ไม่กลมกลืนกับ UI เดิม จึงต้องการเปลี่ยนให้เป็นโทนสีเดียว (เทา/ดำ)
- สิ่งที่ดำเนินการ: 
  - แก้ไขฟังก์ชัน `buildMaintenanceQuoteApprovedFlexMessage` ใน `backend-dorm/handlers/line_bot.go`
  - เปลี่ยนพื้นหลังของกล่องอนุมัติเป็น `#F3F4F6` (เทาอ่อน) 
  - เปลี่ยนสีข้อความจากสีเขียว/น้ำเงิน เป็น `#111827`, `#374151`, และ `#6B7280` (เทาเข้ม/ดำ) ตามลำดับ เพื่อให้กลมกลืนกับการ์ดส่วนอื่น
- ไฟล์ที่แก้: `backend-dorm/handlers/line_bot.go`
- การตรวจสอบและหลักฐาน: รัน `go test ./...` ผ่าน
- สถานะ deploy/UAT: ทำการ Deploy ทับบน Production อีกครั้ง

## 2026-09-18 12:51 — ปรับ Layout Flex Message อนุมัติใบเสนอราคา

- คำขอ/เป้าหมาย: ลูกบ้านแจ้งว่ากล่อง "อนุมัติใบเสนอราคา" มีพื้นที่ว่างด้านล่างมากเกินไปเมื่อเทียบกับการ์ด QR Code ด้านข้าง จึงต้องการให้จัด Layout และใช้พื้นที่ให้เหมาะสม
- สิ่งที่ดำเนินการ: 
  - เพิ่มแถวข้อมูล `แจ้งเมื่อ` และ `ค่าใช้จ่าย` กลับเข้ามาในการ์ดอนุมัติ
  - เพิ่ม Progress Bar (แถบสถานะ) เข้าไปในกล่องอนุมัติ โดยให้แสดงเป็น Step 3/6 (อนุมัติใบเสนอราคา)
  - Layout ใหม่นี้ใช้พื้นที่ในแนวตั้งได้คุ้มค่าขึ้น สมดุลกับการ์ดภาพ QR Code และมีหน้าตาไปในทิศทางเดียวกับการ์ดสถานะปกติ
- ไฟล์ที่แก้: `backend-dorm/handlers/line_bot.go`
- การตรวจสอบและหลักฐาน: รัน `go test ./...` ผ่าน
- สถานะ deploy/UAT: ทำการ Deploy ทับบน Production อีกครั้ง

## 2026-09-18 12:56 — ปรับแก้ Flex Message (Space Justification)

- คำขอ/เป้าหมาย: พื้นที่ว่างระหว่างรายละเอียดซ่อมกับปุ่มอนุมัติมีมากเกินไป (กล่องแรกถูกยืดตามขนาดรูป QR Code ในกล่องที่สอง)
- สิ่งที่ดำเนินการ: 
  - จัดโครงสร้างกล่อง `body` ใน `buildMaintenanceQuoteApprovedFlexMessage` 
  - จัดกลุ่มข้อมูลส่วนบนเข้าด้วยกัน และตั้งค่า `justifyContent: "space-between"` ในกล่องหลัก
  - วิธีนี้จะดันส่วนรายละเอียดขึ้นชิดขอบบน และดันส่วน Progress bar (อนุมัติใบเสนอราคา) ลงชิดขอบล่างอัตโนมัติ ทำให้ใช้พื้นที่อย่างเหมาะสมตามที่ LINE Flex Message แนะนำ
- ไฟล์ที่แก้: `backend-dorm/handlers/line_bot.go`
- การตรวจสอบและหลักฐาน: รัน `go test ./...` ผ่าน
- สถานะ deploy/UAT: Deploy ขึ้น Production

## 2026-09-18 13:01 — เพิ่มกล่องข้อความตรงกลาง Flex Message

- คำขอ/เป้าหมาย: ลูกบ้านแจ้งว่าพื้นที่ตรงกลางการ์ดยังคงเว้นว่างอยู่แม้จะจัด `space-between` แล้ว และต้องการใช้การ์ด 2 ใบ (Carousel) ตามเดิม
- สิ่งที่ดำเนินการ: 
  - แทรกกล่องข้อความตกแต่ง (Middle box) เข้าไปในกล่อง `body` ของใบแรก โดยมีข้อความนำทางว่า "👉 กรุณาเลื่อนขวา เพื่อดู QR Code และยอดชำระเงิน"
  - ใช้คุณสมบัติของ `space-between` จัดให้กล่องนี้ลอยอยู่ตรงกลางพื้นที่ว่างพอดี เพื่อลดพื้นที่ว่างเปล่าและเพิ่ม UX ที่ดีให้ลูกบ้านเลื่อนการ์ดถัดไป
- ไฟล์ที่แก้: `backend-dorm/handlers/line_bot.go`
- การตรวจสอบและหลักฐาน: รัน `go test ./...` ผ่าน
- สถานะ deploy/UAT: Deploy ขึ้น Production

## 2026-09-18 13:05 — แทนที่กล่องเลื่อนขวาด้วยข้อความหมายเหตุ

- คำขอ/เป้าหมาย: กล่อง "กรุณาเลื่อนขวา" ตรงกลางการ์ดดูแปลกและไม่สวยงาม
- สิ่งที่ดำเนินการ: 
  - ลบกล่อง "กรุณาเลื่อนขวา" ออก
  - ใส่ส่วน "📝 หมายเหตุ" เข้าไปแทนที่ในครึ่งบนของการ์ด โดยระบุข้อมูลที่เป็นประโยชน์ เช่น "กรุณาชำระเงินตามช่องทางด้านข้าง", "ช่างจะเข้าดำเนินการหลังตรวจสอบยอด" เป็นต้น
  - การทำเช่นนี้ทำให้พื้นที่ว่างถูกเติมเต็มด้วยข้อความที่มีประโยชน์แบบเดียวกับใบแจ้งหนี้ทั่วไป ดูเป็นทางการและสวยงามกว่าเดิมมาก
- ไฟล์ที่แก้: `backend-dorm/handlers/line_bot.go`
- การตรวจสอบและหลักฐาน: รัน `go test ./...` ผ่าน
- สถานะ deploy/UAT: Deploy ขึ้น Production

## 2026-09-18 13:14 — เปลี่ยนภาพ Mock QR เป็น PromptPay QR แบบสแกนได้จริง

- คำขอ/เป้าหมาย: รูป QR ในหน้าอนุมัติใบเสนอราคาเป็นแค่ตัวอย่าง (Mock) ลูกบ้านต้องการสแกนจ่ายค่าซ่อมจริงตามยอดที่เรียกเก็บเข้าบัญชีเจ้าของ
- สิ่งที่ดำเนินการ: 
  - สร้างไฟล์ `utils/promptpay.go` พร้อมฟังก์ชัน `GeneratePromptPayPayload` เพื่อสร้าง EMVCo Payload ของ PromptPay ตามมาตรฐาน
  - ใช้ `github.com/sigurn/crc16` เพื่อสร้าง Checksum ท้าย Payload (Tag 63)
  - ผูกฟังก์ชันนี้เข้ากับ `buildMaintenanceQuoteApprovedFlexMessage` โดยดึงหมายเลขพร้อมเพย์เจ้าของหอพักจากตัวแปร `PROMPTPAY_ID` และยอดเงินจาก `notification.Cost`
  - นำ Payload ที่ได้ไปเข้ารหัส URL แล้วสร้างเป็นลิงก์ภาพผ่าน `api.qrserver.com` และแสดงผลใน Flex Message แทนภาพ Mock เดิม
- ไฟล์ที่แก้: `backend-dorm/utils/promptpay.go` (ใหม่), `backend-dorm/handlers/line_bot.go`
- การตรวจสอบและหลักฐาน: รัน `go test ./...` ผ่าน
- สถานะ deploy/UAT: Deploy ขึ้น Production แจ้งให้ผู้ดูแลตั้งค่าตัวแปร `PROMPTPAY_ID` บนเซิร์ฟเวอร์

## 2026-09-18 13:17 — ตั้งค่าเบอร์พร้อมเพย์เริ่มต้นเป็น 0961950943 สำหรับการทดสอบ

- คำขอ/เป้าหมาย: ผู้ใช้ต้องการทดสอบสแกนจ่ายเงินจริง จึงขอให้เปลี่ยนเบอร์รับเงินเป็น `0961950943`
- สิ่งที่ดำเนินการ: 
  - เข้าไปแก้ไขฟังก์ชัน `buildMaintenanceQuoteApprovedFlexMessage` ในไฟล์ `line_bot.go`
  - เปลี่ยน Default fallback ของตัวแปร `promptPayID` จากเบอร์จำลอง `0812345678` เป็นเบอร์จริง `0961950943` ตามที่ผู้ใช้ระบุ
- ไฟล์ที่แก้: `backend-dorm/handlers/line_bot.go`
- สถานะ deploy/UAT: Deploy ขึ้น Production

## 2026-09-18 13:21 — ปรับขนาด QR Code ให้ดูสวยงามและไม่ล้นพื้นที่

- คำขอ/เป้าหมาย: รูป QR Code เดิมกินพื้นที่เต็มความกว้างของการ์ด (Edge-to-edge) ทำให้ดูใหญ่เกินไปและดูอึดอัด
- สิ่งที่ดำเนินการ: 
  - ย้ายบล็อกรูปภาพ QR จาก `hero` (ที่บังคับขยายเต็มขอบ) มาไว้ในส่วน `body`
  - สร้างกล่อง (Box) ห่อหุ้ม QR Code ไว้ พร้อมตั้งค่า padding (เช่น 20px) เพื่อให้ภาพ QR มีระยะขอบด้านข้างและไม่ขยายล้นจนเกินไป
  - จัดให้อยู่กึ่งกลางเพื่อความสวยงาม
- ไฟล์ที่แก้: `backend-dorm/handlers/line_bot.go`
- การตรวจสอบและหลักฐาน: รัน `go test ./...` ผ่าน
- สถานะ deploy/UAT: Deploy ขึ้น Production

## 2026-09-18 13:28 — ระบบตรวจสอบสลิปโอนเงินอัตโนมัติผ่าน LINE Bot (Automated Slip Verification)

- คำขอ/เป้าหมาย: นำสลิปการโอนเงิน (ค่าเช่าและค่าซ่อมแซม) มาตรวจสอบแบบอัตโนมัติ เพื่อให้ระบบอนุมัติบิลเป็น "ชำระเงินแล้ว" ทันทีโดยไม่ต้องรอแอดมิน (ใช้ Mock แบบ Offline สำหรับโปรเจกต์จบ)
- สิ่งที่ดำเนินการ: 
  - สร้างไฟล์ `utils/slip_verification.go` ใช้ Go Library `github.com/makiuchi-d/gozxing` ในการดึงข้อมูลและสแกน QR Code จากไฟล์ภาพ
  - สร้างระบบ **Dual-Mode**: 
    1. **Real API**: หากใส่ `EASYSLIP_TOKEN` ระบบจะยิง API ไปที่ EasySlip เพื่อยืนยันยอดเงินจริง 
    2. **Mock Mode (ค่าเริ่มต้น)**: อ่าน QR บนภาพ และตรวจสอบรูปแบบเบื้องต้น เหมาะสำหรับทดสอบโปรเจกต์จบโดยไม่ต้องพึ่ง API โควตา
  - แก้ไข `handlers/line_bot.go` (ฟังก์ชัน `handleImageMessage`) ให้รันตรวจสอบอัตโนมัติเมื่อผู้ใช้ส่งรูปสลิป 
  - หากผ่าน: เปลี่ยนสถานะเป็น `paid` (ค่าเช่า) หรือ `เสร็จสิ้น` (ค่าซ่อมแซม) พร้อมส่งข้อความ Flex สำเร็จ
  - หากไม่ผ่าน: เปลี่ยนเป็น `checking` เพื่อส่งต่อให้แอดมินตรวจ manual แบบเดิม (Fallback)
- ไฟล์ที่สร้างและแก้: `backend-dorm/utils/slip_verification.go`, `backend-dorm/handlers/line_bot.go`
- การตรวจสอบและหลักฐาน: รัน `go test ./...` ผ่านเรียบร้อย นำขึ้น Production
- สถานะ deploy/UAT: Deploy ขึ้น Production

## 2026-09-18 13:35 — เพิ่มระบบ Python OCR Bot สำหรับตรวจสลิปแบบ Offline 100% ฟรี

- คำขอ/เป้าหมาย: สร้างระบบตรวจสอบสลิปแบบออฟไลน์ 100% รันบนเซิร์ฟเวอร์ โดยใช้ OCR ในการสกัดตัวหนังสือและยอดเงินจากรูปสลิป 
- สิ่งที่ดำเนินการ: 
  - สร้าง `ocr-bot` เป็น Python Flask API (Microservice)
  - กำหนดชื่อผู้รับเงินเป็น `ภคพล` ตามที่ระบุ
  - ปรับแก้ Go backend (`utils/slip_verification.go`) ให้ยิง `POST http://localhost:5001/verify` เพื่อเรียกใช้งาน OCR
  - อัปเดตสคริปต์ `deploy_flex_safe_remote.sh` ให้ติดตั้ง `tesseract-ocr`, `python3-venv` และตั้งค่า Systemd Service (`dormitory-ocr.service`) ให้รันคู่กับ Go บนเซิร์ฟเวอร์
- ไฟล์ที่สร้างและแก้: 
  - `backend-dorm/ocr-bot/app.py`
  - `backend-dorm/ocr-bot/requirements.txt`
  - `backend-dorm/utils/slip_verification.go`
  - `backend-dorm/scripts/deploy_flex_safe_remote.sh`
- สถานะ deploy/UAT: Deploy ขึ้น Production และรัน OCR Bot เป็น Systemd Service เรียบร้อย

## 2026-09-18 13:42 — เพิ่มปุ่มส่งหลักฐานในข้อความอนุมัติแจ้งซ่อม

- คำขอ/เป้าหมาย: ลูกบ้านอัปโหลดสลิปแจ้งซ่อมแล้วระบบตอบกลับให้กดเมนูการเงินก่อน เนื่องจากข้อความ Flex แจ้งซ่อมที่อนุมัติแล้วยังขาดปุ่มกดตั้งค่าสถานะ
- สิ่งที่ดำเนินการ: 
  - เพิ่มปุ่ม "ส่งหลักฐานการชำระ" (`action=pay_maint&id=...`) ใน `buildMaintenanceQuoteApprovedFlexMessage` 
- ไฟล์ที่แก้: 
  - `backend-dorm/handlers/line_bot.go`
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 13:46 — แก้บั๊กกดส่งหลักฐานการชำระเงินแจ้งซ่อมไม่ได้

- คำขอ/เป้าหมาย: ลูกบ้านกดปุ่ม "ส่งหลักฐานการชำระ" แล้วได้ข้อความ "บิลนี้ไม่พร้อมรับชำระ" 
- สาเหตุ: ระบบเช็คว่าสถานะต้องเป็น `รอตรวจสอบชำระเงิน` เท่านั้น ถึงจะให้จ่ายเงินได้ แต่ตอนที่แอดมินกดอนุมัติใบเสนอราคา สถานะจะถูกเปลี่ยนเป็น `กำลังซ่อม` (ตาม Workflow เดิม) ทำให้เงื่อนไขไม่ตรง
- สิ่งที่ดำเนินการ: 
  - แก้เงื่อนไขใน SQL query ให้รองรับสถานะ `กำลังซ่อม` และ `รอตรวจสอบชำระเงิน` ในฟังก์ชัน `handleImageMessage` (บรรทัด 438) และตอนเช็คคลิกปุ่ม (บรรทัด 1051)
- ไฟล์ที่แก้: 
  - `backend-dorm/handlers/line_bot.go`
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 13:55 — เพิ่มระบบ Smart Slip Detection (รับสลิปโดยไม่ต้องกดปุ่ม)

- คำขอ/เป้าหมาย: ลูกบ้านไม่อยากกดปุ่มส่งหลักฐาน ต้องการส่งรูปสลิปเข้ามาในแชทแล้วให้ระบบรับรู้เองว่าเป็นค่าเช่าหรือค่าซ่อม และตัดยอดอัตโนมัติ
- สิ่งที่ดำเนินการ: 
  - ลบปุ่ม "ส่งหลักฐานการชำระ" ออกจาก Flex แจ้งซ่อม (Quote Approved และ Payment Request)
  - ปรับปรุงฟังก์ชัน `handleImageMessage` ให้ตรวจสอบสถานะลูกบ้าน ถ้าส่งรูปมาตอนที่ไม่ได้กดเมนู (`bot_state == "none"`) ระบบจะดึงยอดค้างชำระ (Rent และ Maintenance) ขึ้นมาตรวจหาบิลที่สอดคล้อง หากเจอจะเซ็ต `bot_state` อัตโนมัติและส่งให้ OCR Bot ทำงานทันที
- ไฟล์ที่แก้: 
  - `backend-dorm/handlers/line_bot.go`
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 14:06 — ส่งบิล (Flex Message) เมื่อตรวจสอบสลิปค่าซ่อมสำเร็จ

- คำขอ/เป้าหมาย: เมื่อระบบตรวจสอบสลิปค่าซ่อมด้วยบอทสำเร็จ อยากให้ออกบิล (ใบเสร็จรับเงิน) ให้ลูกบ้านด้วย แทนที่จะส่งแค่ข้อความเฉยๆ
- สิ่งที่ดำเนินการ: 
  - เพิ่มโค้ดการสร้าง `Flex Message` รูปแบบใบเสร็จรับเงิน (MAINTENANCE RECEIPT) ในฟังก์ชัน `handleImageMessage` 
  - ส่ง Flex Message ไปพร้อมกับข้อความแจ้งผลการตรวจสอบสำเร็จ
- ไฟล์ที่แก้: 
  - `backend-dorm/handlers/line_bot.go`
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 14:11 — เพิ่มข้อความแจ้งเตือนให้ส่งสลิปหลังได้ QR Code ค่าซ่อม

- คำขอ/เป้าหมาย: ลูกบ้านไม่สังเกตเห็นข้อความใน Flex Message ว่าต้องส่งสลิปในแชท (หลังจากสแกนจ่ายเงิน) ทำให้สับสน
- สิ่งที่ดำเนินการ: 
  - เพิ่มข้อความแจ้งเตือนแบบ Text Message ("📸 เมื่อชำระเงินเรียบร้อยแล้ว สามารถส่งรูปสลิปเข้ามาในแชทนี้ได้เลยนะคะ...") ส่งตามหลัง Flex Message อนุมัติใบเสนอราคาและเรียกเก็บเงินทันที เพื่อให้เห็นเด่นชัดขึ้น
- ไฟล์ที่แก้: 
  - `backend-dorm/handlers/line_bot.go`
  - `backend-dorm/handlers/line_snapshot.go`
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 14:18 — อัปเดตกฎปฏิบัติงานและประเมินความเสี่ยง OCR/ตรวจสลิปหลังมีการเปลี่ยนจาก Terminal อื่น

- คำขอ/เป้าหมาย: อัปเดตเอกสารต่อให้ Terminal/Agent อื่นทำงาน server, deploy และ build แอปต่อได้ตรงกับระบบล่าสุด
- สิ่งที่ดำเนินการ: ตรวจการเปลี่ยนแปลงล่าสุดโดยไม่แก้โค้ดของ Terminal อื่น; ปรับ operations runbook ให้รวม `dormitory-ocr.service`, localhost:5001, Tesseract/Python dependencies, post-deploy probe และข้อจำกัด rollback; ตัด `.exp` ออกจาก source archive เพื่อไม่ upload credential ที่ฝังในสคริปต์เก่า; อัปเดต tracking, handoff, checklist, backlog และ assessment ให้บันทึก P0 ด้าน financial integrity ของ auto slip
- ไฟล์หรือระบบที่กระทบ: `AGENTS.md`, `docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md`, `project-tracking/README.md`, `WORK_STATUS.md`, `PENDING_WORK.md`, `HANDOFF.md`, `UI_LINE_AUDIT_CHECKLIST.md`, `ACTIVITY_REPORT.md` และ `project-review/DormiNetX-Assessment-2026-09-18.md`
- การเปลี่ยนข้อมูล/production: เข้า production แบบ read-only เพื่อตรวจ SHA, service state และ health เท่านั้น; ไม่มี restart/deploy, ไม่มี SQL write และไม่มีการเปลี่ยนข้อมูลลูกบ้าน
- การตรวจสอบและหลักฐาน: production Go binary SHA-256 `4262b9c08a3a6cef0721a2249e7e743bd9a98dce42c44c01a596a64934faab0c`; `dormitory.service` และ `dormitory-ocr.service` เป็น `active`; main health ตอบ `online`; OCR `/verify` ตอบ HTTP 400 เมื่อ payload ไม่ครบ; rollback set ล่าสุดที่พบคือ `/home/fang/line_migration_backups/20260918-002045-pre-flex-ui`; ตรวจ syntax ของ `devicectl install/launch`, Markdown links และ diff ของไฟล์เอกสารที่แก้
- สถานะ deploy/UAT: ไม่มี deploy/UAT ใหม่ในรอบนี้; OCR HTTP 400 พิสูจน์เฉพาะ service availability ไม่ใช่ความถูกต้องของการตรวจสลิป
- ผลลัพธ์: Terminal ใหม่มีขั้นตอนเข้า server, ตรวจสอง service, safe deploy, rollback และ build/install iOS ที่ชัดเจน พร้อมเห็นข้อจำกัดจริงของ OCR deployment และเหตุผลที่ห้ามถือ fallback เป็นหลักฐานรับเงินจริง
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: fallback ปัจจุบันยอมรับ QR กว้างโดยไม่ยืนยันยอด/ผู้รับ/reference/replay และอาจ auto-paid/auto-complete; OCR รัน root, config บางส่วนอยู่ใน source และ safe deploy ไม่ rollback OCR แบบ atomic จึงเปิด `SEC-017` เป็น P0 ปรับ readiness เป็น Feature 94%, Controlled pilot 82%, Production readiness 70% จนกว่าจะ harden และผ่าน controlled UAT

## 2026-09-18 14:20 — ปรับปรุงข้อความแจ้งส่งสลิป (แก้คำซ้ำ)

- คำขอ/เป้าหมาย: ลูกบ้านแจ้งว่าข้อความแจ้งเตือนส่งสลิปซ้ำซ้อนกับใน Flex Message ต้องการให้เปลี่ยนข้อความใน Flex Message และคงข้อความแชทไว้
- สิ่งที่ดำเนินการ: 
  - เปลี่ยนข้อความใน Flex Message (ช่องทางชำระเงิน) จาก "เมื่อชำระแล้ว..." เป็น "รองรับการสแกนผ่านทุกแอปธนาคาร"
  - เปลี่ยนข้อความแชท (Text Message) ให้กลับมาแสดงครบถ้วนเป็น "📸 เมื่อชำระเงินเรียบร้อยแล้ว สามารถส่งรูปสลิปเข้ามาในแชทนี้ได้เลยนะคะ ระบบจะตรวจสอบและตัดยอดให้อัตโนมัติค่ะ"
- ไฟล์ที่แก้: 
  - `backend-dorm/handlers/line_bot.go`
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 14:22 — ปรับเอกสารรองรับการทำงานพร้อมกันหลาย Terminal

- คำขอ/เป้าหมาย: อัปเดตเอกสารต่อหลังพบว่ามี Terminal อื่น deploy production ระหว่างการจัดทำ runbook
- สิ่งที่ดำเนินการ: เปลี่ยนการอ้าง SHA/backup เวลา 14:18 ให้เป็นหลักฐานตามเวลา ไม่ใช่ค่า current; เพิ่มกฎให้ตรวจ `sha256sum` และ backup directory สดก่อนทุกงาน production เพื่อป้องกันเอกสารแข่งกับ deployment ล่าสุด
- ไฟล์หรือระบบที่กระทบ: `docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md`, `project-tracking/WORK_STATUS.md`, `project-tracking/HANDOFF.md`, `project-tracking/ACTIVITY_REPORT.md`
- การเปลี่ยนข้อมูล/production: ไม่มีการเข้า server, deploy, restart หรือเปลี่ยนข้อมูลในรายการนี้
- การตรวจสอบและหลักฐาน: activity report มี deploy ใหม่เวลา 14:20 หลัง read-only verification เวลา 14:18 จึงไม่อ้าง SHA เดิมเป็น current
- สถานะ deploy/UAT: เอกสารเท่านั้น ไม่มี deploy/UAT ใหม่
- ผลลัพธ์: Terminal ถัดไปจะใช้ค่า production ที่ตรวจสดแทนการเชื่อค่า snapshot ในเอกสาร และยังมีค่าตามเวลาไว้ตรวจย้อนหลัง
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ทุก Terminal ที่ deploy ต้องบันทึก `NEW_SHA` และ `BACKUP_DIR`; รายการ deploy เวลา 14:20 ยังไม่มีสองค่านี้ในบันทึก จึงต้องตรวจและเติมก่อนถือว่าหลักฐาน deploy สมบูรณ์

## 2026-09-18 14:26 — อ่านเอกสารและประเมินลำดับงานใหม่หลังเพิ่ม PromptPay/OCR

- คำขอ/เป้าหมาย: อ่านเอกสารโปรเจกต์ฉบับใหม่อีกครั้งและทำความเข้าใจสถานะล่าสุด
- สิ่งที่ดำเนินการ: อ่าน `AGENTS.md`, `project-tracking/README.md`, `WORK_STATUS.md`, `PENDING_WORK.md`, `HANDOFF.md`, `UI_LINE_AUDIT_CHECKLIST.md`, รายการล่าสุดใน `ACTIVITY_REPORT.md`, `docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md` และ `project-review/DormiNetX-Assessment-2026-09-18.md`; ตรวจสถานะ Git ก่อนดำเนินการและแยกงานเดิมของ Terminal อื่นออกจากรายการบันทึกนี้
- ไฟล์หรือระบบที่กระทบ: เพิ่มรายการนี้ใน `project-tracking/ACTIVITY_REPORT.md` แบบ append-only เท่านั้น; ไม่แก้โค้ดหรือเอกสารสถานะอื่น
- การเปลี่ยนข้อมูล/production: ไม่มีการเข้า server, deploy, restart, เรียก provider หรือเปลี่ยนข้อมูล production
- การตรวจสอบและหลักฐาน: เอกสารล่าสุดระบุ Feature 94%, Controlled pilot 82% และ Production readiness 70%; `SEC-017` เปิดเป็น P0 เพราะ auto slip fallback ยังไม่ fail closed และ OCR deployment/rollback ยังไม่ครอบคลุม; พบว่า deploy เวลา 14:20 ยังไม่มี `NEW_SHA`/`BACKUP_DIR` ใน activity report และพบข้อความ workflow บางส่วนที่ต้อง reconcile กับพฤติกรรมหลัง deploy ล่าสุด
- สถานะ deploy/UAT: เป็นการอ่านและประเมินเอกสารเท่านั้น ไม่มี automated test, build, deploy หรือ UAT ใหม่
- ผลลัพธ์: ลำดับงานเร่งด่วนคือหยุด auto-paid/auto-complete เมื่อยืนยันสลิปไม่ได้, ตรวจ amount/receiver/reference/replay, ย้าย config/secret ออกจาก source, ลดสิทธิ์และเพิ่ม atomic health/rollback ให้ OCR แล้วจึงทำ controlled maintenance/slip UAT และ UAT สองอุปกรณ์/สองบัญชี
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ระหว่างยังไม่ปิด P0 ต้องให้ผู้ดูแลตรวจรายการการเงินจริงทุกครั้ง; ก่อนงาน production ถัดไปต้องตรวจ SHA/backup สดและ reconcile เอกสาร workflow/ข้อความ LINE ให้ตรงกับโค้ดที่ deploy จริง

## 2026-09-18 14:27 — แก้ไขบั๊กการตรวจสอบสลิปผิดประเภท

- คำขอ/เป้าหมาย: ลูกบ้านแจ้งว่าระบบตรวจสลิปพัง (ส่งสลิปค่าซ่อม 2.00 บาท แต่ระบบตอบว่า Expected amount 40.00)
- สาเหตุของบั๊ก: การเช็คบิลค่าซ่อมอัตโนมัติในกรณีที่ลูกบ้านไม่ได้กดปุ่ม (bot_state = "none") มีเงื่อนไข `(slip_path IS NULL OR slip_path = '')` ทำให้ถ้าระบบเคยบันทึกรูปสลิปไปแล้วครั้งหนึ่ง (เช่น ส่งผิดหรือตรวจไม่ผ่าน) ระบบจะหาบิลค่าซ่อมไม่เจอ แล้วเด้งไปตรวจบิลค่าเช่า (ซึ่งมียอด 40.00) แทน
- สิ่งที่ดำเนินการ: 
  - แก้ไข query ดึงข้อมูลใน `line_bot.go` บรรทัด 284 โดยเอาเงื่อนไข `(slip_path IS NULL OR slip_path = '')` ออก เพื่อให้ลูกบ้านสามารถอัปโหลดสลิปซ้ำได้ตราบใดที่สถานะการซ่อมยังเป็น "รอตรวจสอบชำระเงิน"
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 14:31 — ปรับ UI ใบเสร็จรับเงิน และเอา emoji ออก

- คำขอ/เป้าหมาย: ลูกบ้านแจ้งว่าต้องการให้ปรับแต่ง UI ของสลิป (ใบเสร็จรับเงิน) และเอาอีโมจิออกทั้งหมด
- สิ่งที่ดำเนินการ: 
  - ลบอีโมจิ "✅", "⚠️" ออกจากข้อความตอบกลับเมื่อตรวจสอบสลิปเสร็จสิ้น (ทั้งค่าเช่าและค่าซ่อม)
  - เปลี่ยนรูปแบบการแสดงยอดเงินใน Flex Message ใบเสร็จรับเงิน จาก `฿X.XX` เป็น `X.XX บาท` เพื่อให้อ่านง่ายและดูสะอาดตาขึ้น
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 14:37 — ตรวจเหตุรายการแจ้งซ่อมจาก LINE ไม่ปรากฏในแอป

- คำขอ/เป้าหมาย: ตรวจสอบเหตุที่ส่งรายการแจ้งซ่อมผ่าน LINE สำเร็จแล้ว แต่รายการใหม่ไม่ปรากฏในแอป iOS
- สิ่งที่ดำเนินการ: ตรวจ production health, tenant database และ latest sync snapshot ด้วยคำสั่ง read-only; ตรวจ service journal; ตรวจไฟล์ SwiftData, sync checkpoint และ sync outbox จาก app data container ของ iPhone แบบ read-only; เทียบ record ที่ค้างระหว่าง tenant, snapshot และ local store; อ่านเส้นทาง sync/materialization ในโค้ดปัจจุบันโดยไม่แก้ไข
- ไฟล์หรือระบบที่กระทบ: เพิ่มรายการนี้ใน `project-tracking/ACTIVITY_REPORT.md` เท่านั้น; สำเนา app container ชั่วคราวที่ใช้วิเคราะห์ถูกย้ายไป Trash หลังตรวจเสร็จ
- การเปลี่ยนข้อมูล/production: ไม่มีการเขียนฐานข้อมูล, deploy, restart, retry outbox หรือเปลี่ยนข้อมูล production/iPhone
- การตรวจสอบและหลักฐาน: health ตอบ `online`; รายการแจ้งซ่อมใหม่ internal server id `779` อยู่ใน tenant database และ latest snapshot `v239` แล้ว แต่ไม่อยู่ใน SwiftData บน iPhone; iPhone checkpoint ยังอยู่ `v226`, pending เป็น `true`, outbox ใช้ base version `226`; พบ local dirty เพียงหนึ่งรายการคือ maintenance server id `222` ซึ่ง local อยู่สถานะ `รออนุมัติค่าใช้จ่าย` ขณะที่ tenant database เป็น `เสร็จสิ้น`; journal แสดง snapshot `v228`–`v239` ถูกเก็บแล้วแต่ LINE materialization ล้มด้วย `status must move one step at a time` สำหรับ UUID ของรายการ `222`
- สถานะ deploy/UAT: ตรวจสอบและยืนยันสาเหตุแล้วเท่านั้น ยังไม่ได้แก้โค้ดหรือ reconcile ข้อมูล
- ผลลัพธ์: LINE → tenant database → snapshot สำหรับรายการใหม่ทำงานสำเร็จ แต่แอปไม่ apply snapshot เพราะ local dirty record พยายามย้อนสถานะรายการเดิม; backend บันทึก snapshot ก่อน materialization แล้วตอบ HTTP 500 ทำให้แอปไม่เลื่อน checkpoint/ล้าง pending และวนส่งซ้ำ
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ห้ามล้าง local store/outbox โดยไม่สำรอง แม้พบ dirty เพียงหนึ่งรายการ; แนวทางแก้ต้องรักษาสถานะ `เสร็จสิ้น` จาก LINE เป็น canonical, ป้องกัน rebase ย้อน workflow และทำให้ sync push ไม่สร้าง accepted snapshot พร้อมตอบ 500 เมื่อ side effect ล้มเหลว จากนั้นจึง reconcile snapshot/iPhone และยืนยันรายการ `779` ปรากฏโดย dirty/pending เป็นศูนย์

## 2026-09-18 14:49 — เพิ่มเมนู ติดต่อ/ฉุกเฉิน

- คำขอ/เป้าหมาย: เพิ่มปุ่มให้ลูกบ้านสามารถเลือกช่องทางติดต่อแอดมินหรือเบอร์ฉุกเฉินได้ในปุ่มเดียว
- สิ่งที่ดำเนินการ: 
  - สร้าง Flex Message `buildContactMenuFlexMessage` สำหรับแสดงช่องทางการติดต่อ (โทรหาแอดมิน, แชทฝากข้อความ) และเบอร์สายด่วนฉุกเฉิน (1669, 199, 191)
  - เพิ่ม Trigger คำว่า "ติดต่อ" หรือ "ติดต่อนิติบุคคล" ใน `line_bot.go` ให้เรียกใช้ Flex Message นี้
  - เพิ่ม Trigger คำว่า "ฝากข้อความถึงแอดมิน" เพื่อใช้เป็น Action เมื่อผู้ใช้กดปุ่มแชท
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย แอดมินสามารถนำคำว่า "ติดต่อ" ไปผูกกับปุ่มบน LINE Rich Menu ได้เลย
