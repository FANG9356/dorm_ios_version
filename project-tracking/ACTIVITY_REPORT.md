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
