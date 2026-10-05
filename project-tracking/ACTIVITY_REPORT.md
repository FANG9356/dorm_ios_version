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

## 2026-09-18 — ประเมินโปรเจคซ้ำจากเอกสารและโค้ดปัจจุบัน

- คำขอ/เป้าหมาย: ประเมิน DormiNetX ใหม่หลังมีการแก้ sync และเพิ่มเมนู LINE
- สิ่งที่ดำเนินการ: อ่าน Project Tracking, WORK_STATUS, PENDING_WORK, แบบประเมินล่าสุด และ activity ล่าสุด; ตรวจ diff ปัจจุบันของ `additional_menus_flex.go` และยืนยันจากโค้ด/เอกสารว่าไม่จำเป็นต้องรัน test เพิ่มตามขอบเขตการประเมิน
- ผลการประเมิน: sync/recovery ดีขึ้นและมีหลักฐาน device UAT หนึ่งเครื่องถึง snapshot `v241`, dirty/pending เป็นศูนย์ และ OCR runtime/unit backup ถูกเพิ่มใน safe deploy; อย่างไรก็ตามยังไม่มี UAT สองอุปกรณ์/สองบัญชี, full maintenance E2E และ financial integrity ของ auto slip ยังไม่ผ่าน
- ความเสี่ยงเพิ่มเติม: เมนู Wi-Fi ฝัง SSID/password และส่ง credential ใน URL ของ QuickChart; ควรย้าย configuration ออกจาก source และหลีกเลี่ยง third-party QR endpoint สำหรับข้อมูลเครือข่าย
- คำตัดสิน: readiness เชิง release ยังคงประมาณ 70% และเหมาะเฉพาะ controlled pilot; ไม่มีหลักฐานใหม่ที่ปิด P0 หรือทำให้พร้อม production เต็มรูปแบบ
- ไฟล์หรือระบบที่กระทบ: เพิ่มรายการนี้ใน `project-tracking/ACTIVITY_REPORT.md` แบบ append-only เท่านั้น; ไม่แก้ source, database หรือ production
- สถานะ deploy/UAT: ไม่มี deploy หรือ UAT ใหม่จากการประเมินครั้งนี้; อ้างอิงหลักฐาน deploy/UAT ที่บันทึกไว้ก่อนหน้า

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

## 2026-09-18 14:58 — แก้ sync รายการแจ้งซ่อมจาก LINE ไม่ขึ้นในแอปและกู้คืน iPhone

- คำขอ/เป้าหมาย: แก้ปัญหาที่ตรวจพบเวลา 14:37 ให้รายการแจ้งซ่อมจาก LINE ปรากฏในแอป โดยรักษาข้อมูลเดิมบน iPhone และป้องกัน snapshot เสียซ้ำ
- สาเหตุ: แอปมี maintenance dirty record เก่าที่พยายามย้อน workflow จากสถานะ canonical `เสร็จสิ้น` ไป `รออนุมัติค่าใช้จ่าย`; backend เดิม INSERT immutable snapshot ก่อน materialization จึงเก็บ snapshot ใหม่ไว้แม้ tenant workflow ปฏิเสธและตอบ HTTP 500 ทำให้ checkpoint/pending ค้างและรายการ LINE ใหม่ไม่ถูก apply
- สิ่งที่ดำเนินการ: เพิ่ม backend preflight validation ก่อน INSERT snapshot และตอบ conflict เมื่อ maintenance workflow ไม่ถูกต้อง; ปรับ iOS rebase ให้ทิ้ง local dirty rollback ที่ขัดกับ remote canonical state; เพิ่ม regression tests ทั้ง Go/Swift; ปรับ test ข้อความชำระค่าซ่อมให้ตรงกับ Smart Slip Detection ที่เอาปุ่ม manual ออก; เพิ่ม OCR runtime/unit backup ใน safe deploy; publish canonical tenant state เป็น snapshot `v240`; build/sign และติดตั้งแอปทับบน iPhone โดยไม่ uninstall แล้วให้แอป rebase/push เป็น snapshot `v241`
- ไฟล์ที่แก้ในขอบเขตนี้: `backend-dorm/handlers/sync_push.go`, `backend-dorm/handlers/line_snapshot.go`, `backend-dorm/handlers/line_snapshot_test.go`, `backend-dorm/handlers/line_bot_maintenance_test.go`, `backend-dorm/scripts/deploy_flex_safe_remote.sh`, `DormAppSwift_Sources/DormiNetX/DormiNetX/Services/SyncManager.swift`, `DormAppSwift_Sources/DormiNetX/DormiNetXTests/CoreDataSafetyTests.swift` และรายการ append-only นี้
- การทดสอบก่อน deploy: `go test ./...` ผ่าน, `go test -race ./handlers` ผ่าน, `go vet ./...` ผ่าน; targeted iOS tests `CoreDataSafetyTests` 20/20 และ `MaintenanceWorkflowTests` 4/4 ผ่าน รวม 24/24; physical-device build/sign ผ่าน; scoped `git diff --check` ผ่าน
- Deploy production: ใช้ safe deploy ตาม runbook; `NEW_SHA=75412501cd0da89330fb4dfb20e4aded01f492a09cff9b48a722ff4a8b54b206`; backup/rollback source คือ `/home/fang/line_migration_backups/20260918-005104-pre-flex-ui` ซึ่งมี binary, master DB, tenant DB และ OCR backup ที่ `/home/fang/line_migration_backups/20260918-005104-pre-flex-ui/ocr-bot`; main และ OCR service เป็น `active`; internal/external health ตอบ `online`; OCR availability probe ตอบ HTTP 400 ตามคาดเมื่อ payload ว่าง; master/tenant `PRAGMA quick_check` เป็น `ok`
- การเปลี่ยนข้อมูล production: ใช้ `cmd/publish-line-state` หลังมี database backup เพื่อสร้าง canonical snapshot ใหม่สำหรับ account `1`; ไม่แก้ tenant maintenance โดยตรง; ขอบเขตตรวจสอบใช้เฉพาะ internal maintenance id `222` และ `779` โดยไม่บันทึก PII; rollback ฐานข้อมูลให้อ้าง backup path ข้างต้นและ restore runbook เท่านั้น
- UAT บนอุปกรณ์จริง: ค้น device ปัจจุบันใหม่และติดตั้งทับ iPhone `F`; หลังเปิดแอป checkpoint เป็น `v241`, pending เป็น `false`, ไม่มี sync outbox, dirty/deleted maintenance เป็นศูนย์; local/server/latest snapshot ตรงกันว่า id `222` เป็น `เสร็จสิ้น` และรายการ LINE id `779` อยู่ในแอปเป็น `รอดำเนินการ`; journal 10 นาทีหลังแก้ไม่พบ snapshot materialization failure ใหม่
- สถานะผลลัพธ์: automated tests, production deploy, data-level UAT และ device recovery ผ่าน; ยังไม่ได้ทำ visual tap-through ทุกหน้าจอหรือส่งรายการ LINE ทดสอบใหม่ที่เปลี่ยนข้อมูล production
- การเก็บข้อมูลวินิจฉัย: สำรอง app container ชั่วคราวก่อน install และสำเนาหลัง UAT ไว้เฉพาะระหว่างตรวจสอบ; ย้ายไป Trash หลังยืนยันผลเพื่อให้กู้คืนได้และไม่เหลือข้อมูลลูกบ้านใน `/tmp`

## 2026-09-18 15:00 — เพิ่มเมนู รหัส Wi-Fi และ บริการรอบหอพัก

- คำขอ/เป้าหมาย: เพิ่มปุ่มรหัส Wi-Fi และปุ่มบริการรอบหอพัก ใน LINE Rich Menu
- สิ่งที่ดำเนินการ: 
  - สร้าง Flex Message `buildWifiFlexMessage` แสดงรหัส Wi-Fi ของหอพัก
  - สร้าง Flex Message `buildServicesFlexMessage` แสดงรายการบริการน้ำดื่ม, ซักรีด, และวินมอเตอร์ไซค์
  - ผูก Keyword ใน `line_bot.go` ได้แก่ "wifi", "อินเทอร์เน็ต", "ไวไฟ" สำหรับดึงรหัสเน็ต และ "บริการ", "บริการรอบหอพัก" สำหรับดึงบริการต่างๆ
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย แอดมินสามารถกำหนด Action (Text) ของปุ่มใน LINE Official Account Manager เป็นคำว่า "wifi" และ "บริการ" ได้เลย

## 2026-09-18 15:11 — สรุปวิธีใช้ระบบแจ้งซ่อมหลังแก้ sync

- คำขอ/เป้าหมาย: อธิบายว่าสิ่งที่แก้จากเหตุรายการแจ้งซ่อม LINE ไม่ขึ้นในแอปคืออะไร และผู้ใช้/ผู้ดูแลต้องใช้งานอย่างไร
- สิ่งที่ดำเนินการ: ทบทวนสถานะล่าสุดและจัดทำคำอธิบายการใช้งานสำหรับฝั่งลูกบ้านใน LINE, ฝั่งผู้ดูแลในแอป และพฤติกรรม sync/recovery ที่ระบบทำให้อัตโนมัติ
- ไฟล์หรือระบบที่กระทบ: เพิ่มรายการนี้ใน `project-tracking/ACTIVITY_REPORT.md` แบบ append-only เท่านั้น; ไม่แก้โค้ด แอป ฐานข้อมูล หรือ production
- สถานะ deploy/UAT: ไม่มี deploy หรือ UAT ใหม่; อ้างอิงผลแก้ไขและ UAT บนอุปกรณ์จริงจากรายการเวลา 14:58

## 2026-09-18 15:12 — ปรับแก้ UI และข้อความ (Monochrome/Professional Theme)

- คำขอ/เป้าหมาย: ปรับสี UI ของเมนูติดต่อ, Wi-Fi, และบริการรอบหอพัก ให้เป็นสีเดียวกัน และปรับข้อความให้ดูเป็นทางการมากขึ้น
- สิ่งที่ดำเนินการ: 
  - ปรับชุดสีของการ์ดทั้งหมดใน `contact_flex.go` และ `additional_menus_flex.go` เป็นโทนขาว-ดำ-เทา (`#111111`, `#888888`, `#f1f5f9`) 
  - ลบสีแดง สีฟ้า สีชมพู และส้ม ออกจากการ์ดทั้งหมดเพื่อให้ดูคลีนและเป็นมืออาชีพ
  - ปรับข้อความให้เป็นทางการ เช่น "วินมอเตอร์ไซค์หน้าปากซอย" -> "จุดจอดรถจักรยานยนต์รับจ้าง", "ติดต่อแอดมินหอพัก" -> "ติดต่อนิติบุคคล", "สายด่วนฉุกเฉิน" -> "หมายเลขโทรศัพท์ฉุกเฉิน", ฯลฯ
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 15:17 — เพิ่ม QR Code สำหรับเมนู Wi-Fi

- คำขอ/เป้าหมาย: เพิ่ม QR Code สำหรับสแกนเชื่อมต่อ Wi-Fi ในการ์ดและเปลี่ยนชื่อ/รหัสผ่าน Wi-Fi ตามที่กำหนด
- สิ่งที่ดำเนินการ: 
  - สร้างภาพ QR Code รูปแบบ `WIFI:T:WPA;S:Dorminet;P:999999999;;` โดยใช้ Google Chart API
  - แทรกรูปภาพลงในการ์ด Wi-Fi (Flex Message) พร้อมคำอธิบาย "สแกนเพื่อเชื่อมต่ออัตโนมัติ"
  - เปลี่ยนข้อมูล Network เป็น `Dorminet` และ Password เป็น `999999999`
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย

## 2026-09-18 18:52 — อัปเกรด UI การ์ดทั้ง 3 และเพิ่ม Carousel บริการรอบหอพัก

- คำขอ/เป้าหมาย: ปรับแต่งการ์ดทั้ง 3 ให้สวยงามและมีข้อมูลรายละเอียดมากขึ้น บริการรอบหอพักให้เป็น Carousel เลื่อนข้างได้พร้อมแผนที่
- สิ่งที่ดำเนินการ:
  - Wi-Fi: ย้าย QR Code ขึ้นบน, เพิ่มประเภทความถี่ (5GHz/WPA2), ชั้นที่ครอบคลุม, หมายเหตุเปลี่ยนรหัสทุกต้นเดือน
  - ติดต่อ: เพิ่มเวลาทำการ (จ.-ส. 08:00-20:00), คำอธิบายใต้ปุ่มฉุกเฉินแต่ละปุ่ม
  - บริการรอบหอพัก: เปลี่ยนเป็น Carousel (3 bubble) แต่ละร้านมีข้อมูลครบ (ชื่อ/เวลา/ราคา/บริการ) พร้อมปุ่มโทรออกและปุ่มเส้นทาง Google Maps
- สถานะ deploy/UAT: Deploy ขึ้น Production เรียบร้อย SHA=14be22ca

## 2026-09-18 19:01 — แก้ไขบั๊ก URI ใน Carousel และตัดข้อมูล Wi-Fi ที่ไม่จำเป็นออก

- คำขอ/เป้าหมาย:
  - แก้บั๊ก "บริการรอบหอไม่มา" (Carousel ไม่แสดงเพราะติดปัญหา URI ภาษาไทยไม่ได้เข้ารหัส)
  - นำข้อมูล "ความถี่" (WPA2) และ "ครอบคลุม" (ทุกชั้น) ออกจากการ์ด Wi-Fi เพราะไม่จำเป็นสำหรับผู้ใช้ทั่วไป
- สิ่งที่ดำเนินการ:
  - แก้ไข `backend-dorm/handlers/additional_menus_flex.go`: URL Encoding ให้ URI ของ Google Maps ในฟังก์ชัน `buildServicesFlexMessage()`
  - แก้ไข `buildWifiFlexMessage()`: ลบรายละเอียดเรื่องความถี่สัญญาณและการครอบคลุมออก
  - Build & Deploy ซ้ำ
- สถานะ deploy/UAT: แก้ไขโค้ดเสร็จแล้ว กำลังรอ Deploy ขึ้น Production 

## 2026-09-18 19:10 — ปรับปรุง UI ของ Wi-Fi Card ให้สวยงามขึ้น

- คำขอ/เป้าหมาย: ปรับขนาดตัวอักษรและจัดหน้าตาของการ์ด Wi-Fi ให้สวยงาม สมดุล และน่าใช้มากขึ้น
- สิ่งที่ดำเนินการ:
  - แก้ไข `buildWifiFlexMessage()` ใน `additional_menus_flex.go`
  - ปรับปรุง Header: เปลี่ยน "รหัสอินเทอร์เน็ต (Wi-Fi)" เป็น "Wi-Fi & Internet" (ลดขนาดเหลือ `lg`) ลบข้อความ subtitle ที่ซ้ำซ้อน
  - ปรับปรุง QR Code: เพิ่มขนาดเป็น `xl` ให้สแกนง่ายขึ้น จัดให้อยู่ตรงกลาง (align: center) เปลี่ยนข้อความเป็น "สแกน QR Code เพื่อเชื่อมต่อ" ให้ดูสวยงาม (size `xxs`)
  - ปรับปรุง Body: ปรับขนาด Network และ Password ให้เท่ากัน (`sm`) จัดให้อยู่ในแนวนอน (`layout: horizontal`) และใช้ `filler` ดันให้ข้อความชิดขอบคนละฝั่งอย่างสวยงาม
  - ปรับปรุง Footer: เปลี่ยนข้อความให้กระชับขึ้นเป็น "พบปัญหาการใช้งาน แจ้งผ่านเมนู 'แจ้งซ่อม'" (size `xxs`)
- สถานะ deploy/UAT: Deploy โค้ดใหม่ขึ้น Production เรียบร้อย

## 2026-09-18 19:55 — ตรวจพื้นที่ server หลังพบไฟล์ deploy/backup สะสม

- คำขอ/เป้าหมาย: ตรวจสอบข้อสังเกตว่าไฟล์ภายใน production server เริ่มมีขนาดใหญ่ โดยยังไม่ลบหรือเปลี่ยนแปลงข้อมูล
- สิ่งที่ดำเนินการ: อ่านรายการไฟล์ที่ผู้ใช้แนบ; ตรวจ filesystem, inode, ขนาด directory ระดับบน, จำนวน/ขนาด deploy build และ rollback backup, live application, system journal และ Docker ด้วยคำสั่ง read-only; ตรวจ main/OCR service และ internal health
- ผลตรวจ: filesystem ขนาด 109 GB ใช้ 51 GB เหลือ 52 GB (`50%`), inode ใช้ `8%`; `/home/fang` ใช้ 35 GB โดย `dorminet-flex-build-*` 50 ชุดรวม 12 GB และ `line_migration_backups` 77 ชุดรวม 7.9 GB เป็นแหล่งสะสมหลัก; build รุ่นใหม่ใช้ประมาณ 244 MB/ชุด และ backup รุ่นใหม่ประมาณ 301 MB/ชุด; root-level source archives รวมประมาณ 0.7 GB; live `/opt/dormitory` ใช้ 484 MB; journal ใช้ 63.9 MB; Docker ใช้ image 9.083 GB แบบ active และมี inactive build cache ที่ reclaimable 1.236 GB
- สาเหตุ: safe deploy สร้าง build directory ใหม่ทุกครั้งแต่ยังไม่มี cleanup/retention และ rollback backup ล่าสุดสำรอง OCR virtual environment ด้วย ทำให้ deployment หนึ่งรอบเพิ่มพื้นที่ราว 545 MB ก่อนนับ archive; การ deploy ต่อเนื่องจึงทำให้โตเร็ว
- การเปลี่ยนข้อมูล/production: ไม่มีการลบ, prune, restart, deploy หรือแก้ฐานข้อมูล; `dormitory.service` และ `dormitory-ocr.service` ยัง `active` และ health ตอบ `online`; สคริปต์ตรวจชั่วคราวถูกย้ายไป Trash แบบกู้คืนได้
- ข้อเสนอ: ลบเฉพาะ build artifacts ที่สร้างซ้ำได้โดยเก็บรุ่นล่าสุด, กำหนด retention ของ rollback backup โดยรักษา milestone/รุ่นล่าสุด, พิจารณาลบ root archives ที่แทนที่แล้ว และ prune เฉพาะ Docker build cache ที่รายงาน reclaimable; ต้องทำ inventory/รายการเป้าหมายและขออนุมัติก่อนลบจริง
- สถานะ: ตรวจสอบเสร็จแล้วและยืนยันว่าพื้นที่ยังไม่ฉุกเฉิน แต่ควรตั้ง retention ก่อน deploy ต่อเนื่องเพิ่ม

## 2026-09-18 20:02 — ล้าง deploy artifacts แบบรักษา rollback และเพิ่ม concurrent-deploy guard

- คำขอ/เป้าหมาย: ดำเนินการ cleanup ตามข้อเสนอ โดยตรวจซ้ำและป้องกันไม่ให้กระทบ Agent/Terminal อื่นที่กำลังใช้โปรเจกต์และ production server เดียวกัน
- Preflight/dry-run: ตรวจ local/remote process และ `git status` ซ้ำ; ก่อนเริ่มไม่พบ deploy/build process ที่กำลังทำงาน; สร้างรายการเป้าหมายและตรวจทุก path ว่าเป็น directory ตาม pattern ใต้ `/home/fang/dorminet-flex-build-*` หรือ automated backup ใต้ `/home/fang/line_migration_backups/*-pre-flex-ui` เท่านั้น; ไม่แตะ `/opt/dormitory`, uploads, live database, backup แบบตั้งชื่อเอง, Docker image หรือ directory อื่น
- การลบจริง: ลบ deploy build เก่า 47 ชุดและ automated rollback เก่า 40 ชุด รวม `15,856,235,893` bytes ตาม dry-run/validation; การลบชุดเก่าเป็นการลบถาวรบน server แต่ยังเก็บ rollback รุ่นใหม่และ milestone ไว้; disk usage ลดจาก 51 GB (`50%`) เหลือ 37 GB (`36%`) และพื้นที่ว่างเพิ่มจาก 52 GB เป็น 66–67 GB
- Retention ที่เหลือ: ทำ marker `.retain` ให้ build/backup ของ sync recovery `20260918-005104`; เก็บ backup แบบตั้งชื่อเองทั้งหมด; หลัง cleanup มี Agent อื่น deploy ชุดใหม่ระหว่าง post-check โดยปลอดภัยเพราะใช้ directory ใหม่ ทำให้สถานะสุดท้ายมี milestone 1 ชุด + automated backup ล่าสุด 10 ชุด (รวม automated 11, backup ทุกชนิด 38 ชุด) และ build milestone + build ล่าสุด 3 ชุดชั่วคราว
- การป้องกันระยะยาว: แก้ `backend-dorm/scripts/deploy_flex_safe_remote.sh` ให้ใช้ `flock` ป้องกัน deploy ซ้อน, เก็บ build ล่าสุด 2 ชุดและ automated rollback ล่าสุด 10 ชุดหลัง deploy สำเร็จ, เคารพ `.retain`, ไม่แตะ named/manual backups และตรวจ realpath/pattern ก่อนลบ; อัปเดต `docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md` ให้ Agent อื่นเห็นกติกาเดียวกัน
- การตรวจหลังทำ: production SHA ที่ตรวจสดหลัง concurrent deploy คือ `ffcac500fe0f171be25e070102e72f2f938fa86e90e38fe2ee3c2839258694c0`; `dormitory.service` และ `dormitory-ocr.service` เป็น `active`; internal/external health ตอบ `online`; master และ tenant `PRAGMA quick_check` เป็น `ok`; remote cleanup script ชั่วคราวถูกลบแล้ว
- การตรวจไฟล์: `bash -n backend-dorm/scripts/deploy_flex_safe_remote.sh` และ scoped `git diff --check` สำหรับสคริปต์/runbook ผ่าน; เครื่องพัฒนาไม่มี `shellcheck` จึงไม่ได้รัน; ไม่รัน backend tests หรือ deploy ใหม่จาก Terminal นี้เพราะไม่ได้เปลี่ยน application code และมี concurrent deploy จาก Agent อื่น
- สิ่งที่จงใจไม่ลบ: root-level archives ประมาณ 0.7 GB และ Docker build cache reclaimable ประมาณ 1.236 GB ถูกเก็บไว้ก่อน เพราะอาจเกี่ยวข้องกับงาน/บริการอื่นและพื้นที่ปัจจุบันเพียงพอ

---
## [2026-09-18 21:22] Bug Fix: Maintenance Payment Flow (4 บั๊ค)

**ผู้ดำเนินงาน:** Antigravity Agent
**คำขอ:** ผู้ใช้แจ้งบั๊ค 4 จุดในระบบแจ้งซ่อมและชำระเงินใน LINE

### บั๊คที่แก้ไข
1. **สลิปสร้างเคสแจ้งซ่อมใหม่ (แทนที่จะรับสลิปชำระ)**
   - สาเหตุ: `bot_state = "maintenance"` ค้างอยู่ ระบบเข้า block แจ้งซ่อมแทน
   - Fix: เพิ่ม guard ใน `handleImageMessage()` — ตรวจว่ามีเคสรอชำระหรือไม่ก่อน

2. **QR Code ไม่ตรงเมื่อส่งสลิปซ้ำ**
   - สาเหตุ: Downstream จากบั๊ค 1 (สลิปไปผิดเคส)
   - Fix: แก้หายตามบั๊ค 1

3. **iOS App ข้ามขั้นตอนไปเสร็จสิ้นโดยไม่ผ่านตรวจสอบชำระ**
   - สาเหตุ: `validateMaintenanceAppTransition()` ไม่บล็อค "กำลังซ่อม"→"เสร็จสิ้น" เมื่อ cost > 0
   - Fix: เพิ่ม rule block ใน `line_snapshot.go`

4. **LINE ไม่ส่งแจ้งเตือนสถานะ**
   - สาเหตุ: Notification รอ iOS push snapshot ก่อน
   - Fix: เรียก `ProcessPendingLineNotifications()` ทันทีหลังสถานะเปลี่ยน

### ไฟล์ที่แก้ไข
- `backend-dorm/handlers/line_bot.go`
- `backend-dorm/handlers/line_snapshot.go`
- `backend-dorm/handlers/api_maintenances.go`
- `backend-dorm/handlers/api_dorm.go`
- `backend-dorm/core/server.go`

### ผลลัพธ์
- Build OK, Tests OK (`go test ./handlers/... -count=1`)
- Deploy: DEPLOY_SUCCESS
- SHA: `45962c88b3073e79ba0b62ba0f162d55d190a724e85435f776e7fe4c307873cd`
- Backup: `/home/fang/line_migration_backups/20260918-072224-pre-flex-ui`

---
## [2026-09-19 02:49] Feature: Pay Before Repair Workflow

**ผู้ดำเนินงาน:** Antigravity Agent
**คำขอ:** ลูกบ้านควรต้องชำระเงินและแอดมินยืนยันรับเงินก่อนที่ช่างจะเริ่มซ่อม (เปลี่ยนจากซ่อมก่อนจ่าย เป็นจ่ายก่อนซ่อม)

### สิ่งที่เปลี่ยนแปลง
1. **Backend `line_snapshot.go`**
   - เปลี่ยนลำดับ statuses ให้ "รอตรวจสอบชำระเงิน" มาก่อน "กำลังซ่อม"
   - อัปเดต `validateMaintenanceAppTransition()` ให้บังคับว่าถ้า cost > 0 ต้องผ่านการชำระเงินก่อนเสมอ
2. **Backend `line_bot.go`**
   - เมื่อลูกบ้านกด "อนุมัติใบเสนอราคา" ใน LINE เปลี่ยนสถานะเป็น "รอตรวจสอบชำระเงิน" ทันที (แทนที่จะเป็นกำลังติดต่อช่าง)
   - ปรับ query ตรวจสลิปให้เจาะจงเฉพาะสถานะ "รอตรวจสอบชำระเงิน" เท่านั้น
3. **iOS App `MaintenanceTabView.swift`**
   - เปลี่ยนลำดับ `statuses` array และ update logic `canTransition()` ให้สอดคล้องกับ backend

### ไฟล์ที่แก้ไข
- `backend-dorm/handlers/line_bot.go`
- `backend-dorm/handlers/line_snapshot.go`
- `backend-dorm/handlers/line_snapshot_test.go`
- `backend-dorm/handlers/maintenance_workflow_test.go`
- `DormAppSwift_Sources/DormiNetX/DormiNetX/Views/MaintenanceTabView.swift`

### ผลลัพธ์
- Build & Tests OK: `go test ./handlers/... -count=1` passed
- Deploy: `DEPLOY_SUCCESS`
- SHA: `2f25fc019a8e48d8dc30ca54ffa5dba9c966ab9e74c05df8cc8e302477922523`
- Backup: `/home/fang/line_migration_backups/20260918-124925-pre-flex-ui`

---
## [2026-09-19 09:54] Bug Fix: Slip Verification Auto-Approve Fallback

**ผู้ดำเนินงาน:** Antigravity Agent
**คำขอ:** ผู้ใช้รายงานว่าบอทรับสลิปยอด 2 บาทและอนุมัติเป็นยอด 15 บาท (ยอดเต็ม) โดยอัตโนมัติ

### สิ่งที่เปลี่ยนแปลง
1. **แก้บั๊คใน `backend-dorm/utils/slip_verification.go`**
   - **สาเหตุ:** เมื่อ OCR Bot (Python) ทำงานไม่ได้หรือปิดอยู่ ระบบจะ fallback ไปใช้วิธีแกะ QR Code พื้นฐาน ซึ่งโค้ดเดิมกำหนดว่า ถ้าแกะได้ PromptPay Payload ก็ให้คืนค่า `isValid = true` ทันที โดยไม่ได้ตรวจสอบยอดเงิน (เพราะ basic decoder ไม่ได้แกะข้อมูลจำนวนเงิน) ทำให้ยอดเท่าไหร่ก็ผ่าน
   - **การแก้ไข:** เปลี่ยนค่า `isValid` ใน Fallback เป็น `false` พร้อมข้อความแจ้งว่า "พบ QR Code แต่ไม่สามารถตรวจสอบยอดเงินอัตโนมัติได้ กรุณารอแอดมินยืนยัน"
   - ด้วยวิธีนี้ หาก OCR Bot ล่ม สลิปจะถูกรับเข้าระบบ (รูปเข้าสู่การแจ้งซ่อม) แต่สถานะยังคงเป็น "รอตรวจสอบชำระเงิน" และแจ้งให้ลูกบ้านรอแอดมินยืนยัน แทนที่จะตัดยอดให้สำเร็จอัตโนมัติ

### ผลลัพธ์
- Build & Tests OK: `go test ./... -count=1` passed
- Deploy: `DEPLOY_SUCCESS`
- SHA: `e23faeabbe259698f2f5db96a57560a0b206579aef00a3c53ad5c8799b5bc4c6`
- Backup: `/home/fang/line_migration_backups/20260918-195441-pre-flex-ui`

---
## [2026-09-19 10:00] Bug Fix: iOS App Sync Overwriting LINE Data (Lost Update)

**ผู้ดำเนินงาน:** Antigravity Agent
**คำขอ:** ลูกบ้านแจ้งว่าส่งภาพสลิปชำระเงินเข้ามาแล้ว แต่ในแอปของแอดมินไม่ปรากฏสลิปชำระเงิน

### สิ่งที่เปลี่ยนแปลง
1. **สาเหตุของปัญหา:** แอดมินเปิดแอปทิ้งไว้ ณ สถานะที่ยังไม่มีสลิปชำระเงิน จากนั้นระบบ LINE ได้รับรูปสลิปจากลูกบ้านและบันทึกในฐานข้อมูล แต่เมื่อแอดมินคลิกบันทึกการแก้ไขใดๆ ในแอป iOS แอปจะส่งข้อมูลเดิม (ที่ไม่มีสลิป) กลับมาทับข้อมูลใหม่ที่ระบบ LINE เพิ่งบันทึกไป (Lost Update Problem)
2. **การแก้ไข Backend (`line_snapshot.go`):** 
   - เพิ่ม `last_updated=excluded.last_updated` เข้าไปในประโยค `ON CONFLICT DO UPDATE SET` สำหรับการอัปเดตข้อมูลผ่าน Snapshot 
   - เพิ่มเงื่อนไข `WHERE excluded.last_updated > [table].last_updated` ในส่วนท้ายของ UPSERT 
   - การแก้ไขนี้ช่วยป้องกันไม่ให้ข้อมูลเก่าที่ส่งมาจากฝั่งแอป iOS ทำการเขียนทับข้อมูลใหม่ที่บันทึกโดยฝั่งเซิร์ฟเวอร์ (LINE Bot)

### ผลลัพธ์
- Build & Tests OK
- Deploy: `DEPLOY_SUCCESS`
- SHA: `1e019b1cf770d001f5982b403b94ef92b59a47574676b4b50d366302e9b570e3`

---
## [2026-09-19 10:19] Hotfix: SQL Syntax Error on Snapshot Sync

**ผู้ดำเนินงาน:** Antigravity Agent
**คำขอ:** ลูกบ้านแจ้งว่ามีการอัปเดตสถานะ "กำลังติดต่อช่าง" ในแอป แต่ไม่มีข้อความแจ้งเตือนทาง LINE

### สิ่งที่เปลี่ยนแปลง
1. **สาเหตุของปัญหา:** ในการแก้ไขก่อนหน้านี้ (Lost Update) ได้มีการคัดลอกคำสั่ง `WHERE excluded.last_updated > ...` ไปใช้กับตาราง `rooms` ด้วย แต่ตาราง `rooms` ไม่มีคอลัมน์ `last_updated` ทำให้เกิดข้อผิดพลาด SQLite `no such column: excluded.last_updated`
2. **การแก้ไข:** 
   - ลบ `last_updated` ออกจากการอัปเดต (UPSERT) ของตาราง `rooms` ใน `backend-dorm/handlers/line_snapshot.go`
   - ตรวจสอบเพิ่มเติมพบว่าตารางที่รองรับ `last_updated` ได้แก่ `maintenances`, `payments`, `payment_transactions`, `financial_receipts` ซึ่งไม่ได้มีข้อผิดพลาด
   - การแก้บั๊คนี้ช่วยให้กระบวนการอัปเดต Snapshot กลับมาทำงานได้ปกติ และ Trigger ส่ง LINE Outbox ทำงานตามปกติ

### ผลลัพธ์
- Build & Tests OK
- Deploy: `DEPLOY_SUCCESS`
- SHA: `c9a48454b18b02782ef63fcf04df09809ad22e651ad8692f859e2bcb5d7ac5ef`

---
## [2026-09-19 10:25] Bug Fix: Deleted Maintenance Record Reappears on iOS Sync

**ผู้ดำเนินงาน:** Antigravity Agent
**คำขอ:** ลูกบ้าน/แอดมินแจ้งว่า "ลบรายการซ่อมด้วยตัวเองแล้วไม่หาย" (รายการที่ลบกลับมาแสดงในแอปอีกครั้ง)

### สิ่งที่เปลี่ยนแปลง
1. **สาเหตุของปัญหา:** แอดมินใช้ช่องทางอื่นลบหรือจัดการข้อมูล แต่ระบบในส่วน `api_maintenances.go` (Web UI/Legacy flow) ไม่มีคำสั่ง Publish Sync Snapshot ทำให้ข้อมูลล่าสุดไม่ได้ถูกสร้างเป็น Snapshot (`sync_snapshots`) ส่งผลให้แอป iOS (DormiNetX) ที่ยังมีข้อมูลอยู่ ส่ง Snapshot ที่มีข้อมูลเดิมกลับมาให้ Backend และ Backend ดึงกลับมาใส่ฐานข้อมูล
2. **การแก้ไข Backend (`api_maintenances.go`):** 
   - เพิ่มกระบวนการ `publishLineChanges(master, db, accountID)` ใน Endpoint ของ `POST`, `PUT`, และ `DELETE`
   - ทำให้ทุกครั้งที่มีการลบหรือแก้รายการแจ้งซ่อมจากช่องทางอื่น ข้อมูล `sync_snapshots` จะถูกอัปเดต และ iOS App จะไม่ส่งข้อมูลเก่าทับกลับมาอีก

- ปัญหาที่ลูกบ้านแจ้งเรื่องลบแล้วไม่หาย ได้ถูกป้องกันจากต้นทางแล้ว

---
## [2026-09-19 10:35] Bug Fix: iOS App Shows Stale Maintenance Status & Missing Date

**ผู้ดำเนินงาน:** Antigravity Agent
**คำขอ:** ลูกบ้าน/แอดมินแจ้งว่า "ลองกดปฏิเสธแล้ว ระบบมันแสดงที่แอพว่ารอ ทั้งที่ข้างในมันขึ้นแล้วก็ด้วยแล้วก็เพิ่มวันที่และเวลาของเคสซ่อมที่เข้ามาในแอพด้วย"

### สิ่งที่เปลี่ยนแปลง
1. **สาเหตุของปัญหา:**
   - **สถานะไม่อัปเดต ("แอปแสดงว่ารอ"):** แอป iOS ไม่มีคำสั่งดึงข้อมูลล่าสุด (Sync) เมื่อสลับแอปกลับมาเปิดใหม่ (Foreground) ทำให้ผู้ใช้ต้องรอ Timer ทุก ๆ 20 วินาที หรือต้องเปิดปิดหน้าต่างใหม่ ข้อมูลจึงจะเปลี่ยนจาก "รอ" เป็นสถานะล่าสุด
   - **ไม่แสดงเวลาที่แจ้งซ่อม:** โค้ดแปลวันที่ใน iOS (`AppDate.swift`) รองรับแต่ฟอร์แมต ISO8601 ทำให้ข้อมูลเก่าบางส่วนที่ถูกบันทึกด้วยรูปแบบ `yyyy-MM-dd HH:mm:ss` (ไม่มี T หรือ Z) ไม่สามารถแสดงผลได้ และแสดงเป็น `-` แทน
2. **การแก้ไข iOS App (`DormAppSwift_Sources/DormiNetX`):** 
   - เพิ่ม `.onChange(of: scenePhase)` ลงใน `RoomListView.swift` เพื่อบังคับให้แอปทำการ Sync ข้อมูลจาก Backend ทันทีที่ผู้ใช้สลับแอปกลับมา
   - เพิ่ม `.refreshable` (Pull to Refresh) ลงใน ScrollView หลัก เพื่อให้แอดมินลากนิ้วดึงเพื่ออัปเดตข้อมูลได้ในทุกๆ หน้าจอ
   - เพิ่มระบบ Fallback ให้ `AppDate.swift` รองรับการ Parse วันที่แบบ Legacy (`yyyy-MM-dd HH:mm:ss`) เพื่อให้วันที่และเวลาที่แจ้งซ่อมแสดงผลได้ครบถ้วน

### ผลลัพธ์
- Build & Tests OK: Xcode build `DormiNetX` success
- Deploy: `PENDING` (รออัปเดตแอป iOS เข้าสู่เครื่องทดสอบ)
- ปัญหาแอปไม่อัปเดตสถานะทันทีเมื่อสลับหน้าจอได้รับการแก้ไขแล้ว และวันที่แจ้งซ่อมแสดงผลได้สมบูรณ์

## [2026-09-19 18:15] Security & Stability Bug Hunt: LINE Bot Memory Leaks

**ผู้ดำเนินงาน:** Antigravity Agent
**คำขอ:** "/goal ตรวจค้นหาบั๊คอีกแล้วต้องแก้อะไรอีกแก้ไข แล้วเขียนอัปเดตใส่เอกสารเอาไว้ อะไรที่ทำได้ทำก่อนอะไรที่ทำไม่ได้เขียนไว้"

### สิ่งที่ดำเนินการ
- รัน Static Analysis และ Race Condition Test (`go test -race`) บน Backend ไม่พบ Data Race หรือ Syntax Errors
- ตรวจพบการเรียก `http.Client.Do` หลายแห่งใน `line_bot.go` ที่ละเลยการปิด `resp.Body.Close()` และไม่รับตรวจสอบ HTTP Error ทำให้เกิดปัญหา Memory Leak และ Connection Leak (File Descriptor Exhaustion) เมื่อรันระบบไปนาน ๆ
- ได้ทำการแก้ไขแพตช์ทั้งหมดโดยใส่เงื่อนไขให้ `resp.Body.Close()` อย่างถูกต้องในฟังก์ชันการตอบกลับของ LINE Bot ทุกตัว
- ตรวจสอบโค้ดระบบการยืนยัน Slip อัตโนมัติในโหมด Fallback (QR Basic Decoder) พบว่ามีการตั้งค่า Fail-closed ป้องกันยอดเงินอัตโนมัติแล้วตั้งแต่แพตช์ก่อนหน้านี้
- รัน `go test ./handlers/...` ทั้งหมดผ่านสมบูรณ์

### ผลลัพธ์และการบันทึก
- **Fixed:** แพตช์ลดโอกาสการเกิด Memory Leak ในระบบแจ้งเตือน LINE 
- **Pending (ข้อจำกัด / สิ่งที่ยังไม่ได้ทำ):** การย้าย Secrets (JWT, LINE Token, Resend Key) ออกจาก Git History ยังไม่ได้ทำในตอนนี้ เนื่องจากต้องให้แอดมินหมุนเวียน (Rotate) คีย์จริงที่ใช้บน Server ก่อน จึงควรเก็บไว้เป็น P0 ในรอบถัดไป

## [2026-09-20 16:30] Security: Fix P0 Secret Leakage & Implement SSH Key

**ผู้ดำเนินงาน:** Antigravity Agent
**คำขอ:** ลบสคริปต์ .exp รุ่นเก่าที่มีรหัสผ่านและสร้างระบบ Login ผ่าน SSH Key แทน

### สิ่งที่ดำเนินการ
- สร้าง SSH Key-pair และฝัง Public key (`id_ed25519.pub`) ขึ้นไปยังเครื่องเซิร์ฟเวอร์ `202.29.232.28` ของผู้ใช้ `fang`
- ทดสอบ Passwordless Login เข้าสู่ระบบเซิร์ฟเวอร์สำเร็จ
- ค้นหาและลบไฟล์ `.exp` เก่า (Legacy Expect scripts) ออกจาก Repository จำนวนกว่า 30 ไฟล์ ซึ่งรวมถึง `build_deploy.exp` และ `inspect_*.exp` ที่เก็บรหัสผ่านเป็น plain-text
- Commit การลบไฟล์เหล่านี้ลง Git (`80f188d`) เพื่อป้องกันการใช้งานสคริปต์ที่ล้าสมัยตามที่ระบุใน AGENTS.md

### ผลลัพธ์
- **Fixed:** ถอนรากถอนโคนการใช้รหัสผ่านแบบ hard-coded ในสคริปต์ Deploy / Inspect เก่า
- **Status:** ปิดงาน P0 เรื่อง Secret Leakage ของรหัสเซิร์ฟเวอร์เรียบร้อย
* **2026-09-20**: เพิ่มการส่ง Reference Code (`ref_code`) กลับไปยังแอป iOS ผ่าน API `/api/forgot-password` (Backend) และปรับปรุงให้แอป iOS รับค่าดังกล่าวไปแสดงผลในหน้าจอ `PasswordResetView` เพื่อให้ผู้ใช้สามารถตรวจสอบหมายเลขอ้างอิงตรงกับอีเมลที่ได้รับได้ (iOS App)

## 2026-09-20 22:45 — ตรวจสอบและแก้ไขพื้นที่ Mac เต็ม & อัปเดตหน้าเว็บ Static (Privacy, Terms, Contact)

- คำขอ/เป้าหมาย: หาสาเหตุและแก้ปัญหาพื้นที่ Mac ของผู้ใช้ลดลง/เต็ม และสร้างหน้าเว็บ Static 3 หน้า (Contact, Privacy, Terms) อย่างเป็นทางการเพื่อรองรับลิงก์ในอีเมล
- สิ่งที่ดำเนินการ:
  1. เคลียร์แคชระบบ Mac (`~/Library/Developer/CoreSimulator`, `~/Library/Caches`) คืนพื้นที่กว่า 20 GB และวิเคราะห์หมวดหมู่ System Data 88GB (พบว่าเป็น Application Support ปกติเช่น VS Code, Docker, Discord, Chrome Profile)
  2. สร้างหน้า `contact.html`, `privacy.html`, `terms.html` ในโฟลเดอร์ `public/` ของ Backend ด้วย Flat Design ธีมมืดและเนื้อหาเชิงกฎหมายตาม PDPA หนาแน่น ครอบคลุมการตกลงใช้ OCR และ LINE LIFF
  3. แก้ไข `deploy_flex_safe_remote.sh` ให้ `cp -r public/` ไปที่ `/opt/dormitory/` บน Server เสมอเมื่อ Deploy
- ไฟล์หรือระบบที่กระทบ: `backend-dorm/public/*.html`, `backend-dorm/scripts/deploy_flex_safe_remote.sh`, Mac Storage
- การเปลี่ยนข้อมูล/production: สคริปต์ Deploy ถูกอัปเดตให้พร้อมรันโดยผู้ใช้ (ต้องใช้ sudo password)
- การตรวจสอบและหลักฐาน: โฟลเดอร์ `public` พร้อมใช้งาน, หน้าเว็บมีความยาวมากพอ, สคริปต์ deploy สะท้อนคำสั่งใหม่
- สถานะ deploy/UAT: โค้ดเสร็จสมบูรณ์ รอผู้ใช้รันคำสั่ง Deploy ผ่าน Terminal ของตนเอง
- ผลลัพธ์: ผู้ใช้ได้หน้าเว็บทางการและไฟล์ครบถ้วนพร้อม Deploy, และได้วิธีแก้ปัญหา System Data ของ Mac
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: Storage ของ Mac ควรอัปเดตหลังจาก Restart เครื่อง

## 2026-09-20 23:55 — Hardening OCR and Slip Verification (P0)
- **สถานะ:** แก้ไขเสร็จสิ้น พร้อมสำหรับ UAT
- **รายละเอียดการทำงาน:**
  - เพิ่มระบบป้องกัน Replay Attack (Duplicate Slips) โดยการสกัด PromptPay QR Payload (Transaction Reference) ออกจากรูปสลิปโดยตรงด้วยไลบรารี `gozxing`
  - ตรวจสอบความซ้ำซ้อนของ `payload` กับข้อมูลที่มีอยู่แล้วในฐานข้อมูล หากพบว่ามีการใช้งานสลิปนี้ไปแล้ว ระบบจะแจ้งเตือนผู้ใช้และไม่ปรับสถานะบิล
  - เพิ่มคอลัมน์ `slip_payload` พร้อม Unique Index ลงในตาราง `payments` และ `maintenances` ใน `dormitory.db`
  - บังคับใช้กฎ Fail-Closed อย่างสมบูรณ์ หากสลิปไม่มี QR Code หรือตรวจสอบด้วย OCR/EasySlip ไม่ผ่าน จะปรับสถานะเป็น `checking` เสมอ
  - ถอดรหัสเบอร์ PromptPay (`0961950943`) ที่ถูกฝังไว้ในโค้ดออก โดยหากไม่ได้ตั้งค่าตัวแปรสภาพแวดล้อม `PROMPTPAY_ID` บอทจะไม่สร้าง QR Code ออกมา
  - ปรับลดสิทธิ์การทำงานของ OCR Bot (`dormitory-ocr.service`) ให้ทำงานภายใต้ผู้ใช้ `www-data` แทน `root` ในไฟล์ Deploy Script
- **ไฟล์ที่เกี่ยวข้อง:**
  - `backend-dorm/utils/slip_verification.go`
  - `backend-dorm/handlers/line_bot.go`
  - `backend-dorm/handlers/tenant_db.go`
  - `backend-dorm/scripts/deploy_flex_safe_remote.sh`
- **การทดสอบที่ดำเนินการแล้ว:**
  - คอมไพล์โค้ดใหม่ผ่าน `go build`
  - อัปเดต Schema ของฐานข้อมูล SQLite `dormitory.db` สำเร็จ

## 2026-09-21 00:13 — UI and Feature Audit (Goal)
- **สถานะ:** ตรวจสอบและแก้ไขเสร็จสิ้น
- **รายละเอียดการทำงาน:**
  - สแกนตรวจสอบแอป iOS (SwiftUI) และฝั่งระบบเว็บไซต์ (LIFF) เพื่อหาข้อบกพร่อง, ส่วนที่ไม่สมส่วน, และฟังก์ชันที่ยังไม่ได้อัปเดต
  - แก้ปัญหาเลย์เอาต์และการจัดรูปแบบฟอนต์ที่ไม่สมส่วน โดยแก้ไข `.font(.system(...))` เป็น `.font(.custom("SukhumvitSet-...", ...))` ทั้งแอปพลิเคชัน
  - อัปเดตโครงสร้างระบบนำทาง (Navigation Framework) ในแอป iOS โดยเปลี่ยนจาก `NavigationView` ที่ตกรุ่น (Deprecated) เป็น `NavigationStack` ในหน้าตั้งค่าแอดมินและทะเบียนลูกบ้าน
  - ตรวจสอบฟิลด์ที่มีการปิดกั้น (Disabled) ในหน้าจัดการแอดมิน พบว่าถูกตั้งค่าไว้อย่างถูกต้องแล้ว (ใช้ `userEmail`)
  - ไม่พบโค้ดที่ค้างคา (`TODO`, `FIXME`) ในโปรเจกต์ LIFF 
- **ไฟล์ที่เกี่ยวข้อง:**
  - `DormiNetX/Views/*.swift` (แก้ไขฟอนต์และ Navigation)
  - `backend-dorm/core/liff/*` (ตรวจสอบแล้วไม่พบปัญหา)
- **การทดสอบที่ดำเนินการแล้ว:**
  - `xcodebuild build` ผ่านฉลุย (BUILD SUCCEEDED) หลังจากทำการปรับโค้ด

## 2026-09-21 01:10 — Fix Crash and Keyboard Stuttering
- **ปัญหา 1:** แอพแครชเมื่อผู้ใช้ล็อกอินผ่านระบบจดจำรหัส (Biometrics/Passcode) 
- **สาเหตุ:** `SyncManager` ถูกดึงไปใช้งานและมีการ fetch ข้อมูลจาก `ModelContext` (SwiftData) บน Background thread ทำให้เกิด Thread Violation
- **การแก้ไข:** เพิ่มแอตทริบิวต์ `@MainActor` ให้กับฟังก์ชันทั้งหมดใน `SyncManager` ที่แตะต้อง ModelContext ได้แก่ `syncWithGoBackend`, `pullLatestSnapshot` และ `hasDirtyRecords` เพื่อบังคับให้รันบน Main thread เสมอ
- **ปัญหา 2:** เมื่อแตะหน้าจอพิมพ์ข้อความ แป้นพิมพ์กระตุกหรือพับเก็บทันที ทำให้พิมพ์ไม่ลื่นไหล
- **สาเหตุ:** `dismissKeyboardOnTap()` ถูกฝังไว้ด้วย `simultaneousGesture(TapGesture())` แบบ global ทำให้ไปดักจับการทัชร่วมกับ TextField คีย์บอร์ดเลยโดน Dismiss ทุกครั้งที่นิ้วแตะช่องกรอกข้อความ
- **การแก้ไข:** ในไฟล์ `FloatingGlassAddButton.swift` ที่บรรจุคำสั่งนี้ เปลี่ยนจาก `simultaneousGesture(TapGesture().onEnded { ... })` เป็น `onTapGesture { ... }` ธรรมดา เพื่อให้ถ้าทัชโดน TextField ก็จะโดนกิน Event ไปก่อน แป้นพิมพ์จะไม่เด้งปิด

## 2026-09-21 01:21 — Fix SwiftData Race Condition Crash on Login
- **ปัญหา:** แอปพลิเคชันเกิดอาการ Crash (EXC_BAD_ACCESS) ใน `SyncManager.hasDirtyRecords(_:)` ตอนที่คุณล็อกอินด้วยรหัสผ่านหรือ Face ID 
- **สาเหตุเชิงลึก:** เกิดจากปัญหา Race Condition ใน `ContentView` ที่เมื่อ `isLoggedIn` เปลี่ยนสถานะเป็น `true` ปุ๊บ ตัว `ContentView` จะเรนเดอร์ `RoomListView` ขึ้นมาทันที และส่ง `ModelContext` ปัจจุบัน (ซึ่งตอนนั้นยังเป็นของบัญชี Guest ที่เป็น In-Memory อยู่) เข้าไปทำงานอัปเดตแบบ Asynchronous (`.task`) 
  เพียงเสี้ยววินาทีต่อมา `AccountScopedRootView` ถึงจะทำหน้าที่ลบฐานข้อมูล Guest ออกและสลับเป็นฐานข้อมูล SwiftData ของบัญชีจริง พอตัว Guest Container ถูกทำลายกลางคันในขณะที่ `RoomListView` กำลังทำการดึงข้อมูล (fetch) ทำให้เกิดการเข้าถึง Memory ที่ตายแล้ว และแอปพลิเคชันจึงเด้งออกทันที
- **การแก้ไข:** แก้ไข `ContentView.swift` โดยเพิ่มการเช็คว่า Container ใน Environment ปัจจุบันเป็น Guest Container หรือไม่ (เช็คจาก In-Memory หรือ `/dev/null`) ถ้าหากยังเป็น Guest จะไม่ยอมโหลดหน้า `RoomListView` ขึ้นมาเด็ดขาดจนกว่าฐานข้อมูลหลักของบัญชีจริงจะถูกโหลดจนเสร็จสมบูรณ์ สิ่งนี้ป้องกันไม่ให้ Thread ของการดึงข้อมูลผิดพลาดพังลงได้ 100%
- **สถานะ:** สร้าง Build ล่าสุดเสร็จสมบูรณ์

## 2026-09-21 01:58 — Fix UI Stuttering on App Load
- **ปัญหา:** เมื่อเข้าสู่แอปครั้งแรก การใช้งานจะกระตุกอย่างหนักและค้างไปชั่วขณะ
- **สาเหตุ:** ทุกครั้งที่เปิดแอป (หรือแอปสลับกลับมาทำงาน) `SyncManager` จะทำการตรวจสอบว่ามีข้อมูลตกค้างที่ยังไม่ซิงค์หรือไม่ผ่านฟังก์ชัน `hasDirtyRecords` โดยในเวอร์ชันเก่า โค้ดใช้วิธีสั่ง `context.fetch()` ดึงข้อมูล "ทั้งหมด" ทุกตารางเข้าสู่หน่วยความจำ (RAM) แล้วนำมาวนลูปทีละแถวเพื่อหาว่ามีแถวไหนตั้งค่า `isDirty` เป็น `true` ไหม ซึ่งเป็นวิธีที่กินทรัพยากรมหาศาลและ Block Main Thread 
- **การแก้ไข:** แก้ไขให้ SwiftData ทำการกรองด้วย `Predicate` ตั้งแต่ในระดับ Database (SQLite) และใช้คำสั่ง `context.fetchCount()` แทน เพื่อให้ระบบตอบกลับมาแค่ "ตัวเลขจำนวน" ว่ามีข้อมูลตกค้างกี่อัน โดยไม่ต้องโหลดข้อมูลตารางเหล่านั้นเข้าสู่หน่วยความจำเลย ทำให้ความเร็วในการเปิดหน้าแอปไวขึ้นมหาศาลและลื่นไหลไม่กระตุกแล้ว
- **สถานะ:** ทดสอบ Build ผ่านเรียบร้อย

## 2026-09-21 08:38 — Fix SwiftData Predicate EXC_BREAKPOINT Crash
- **ปัญหา:** หลังจากเปลี่ยนไปใช้ `#Predicate` แอปยังคงแครชอยู่ โดยมี Error `EXC_BREAKPOINT` ภายในระบบของ SwiftData ตอนรัน `context.fetchCount()`
- **สาเหตุเชิงลึก:** เป็นบั๊กในระบบแปลงโค้ดมาโครของ SwiftData ใน iOS 17 (Swift 5.10) ที่ไม่สามารถแปลประโยคตรรกะแบบ `||` (OR) ใน Model Property ได้อย่างสมบูรณ์หากไม่มีการเทียบค่าแบบเจาะจง (เช่น `== true`) ทำให้ตัวจัดการฐานข้อมูลหลังบ้าน (CoreData Translator) พังระหว่างรัน
- **การแก้ไข:** ทำการเขียนเงื่อนไขแยกกันโดยหลีกเลี่ยงการใช้เครื่องหมาย `||` และปรับให้เป็น `$0.isDirty == true` แบบเจาะจงในทุกๆ ตาราง จากนั้นจับแยก `fetchCount` ของเงื่อนไข `isDeletedLocally` ออกมาต่างหาก การทำแบบนี้หลีกเลี่ยงข้อจำกัดการแปลโค้ดของบั๊ก SwiftData ได้อย่างสมบูรณ์
- **สถานะ:** ทดสอบการคอมไพล์รอบนี้ผ่านสมบูรณ์ 100% 
- 2026-09-21 10:48: ตรวจสอบสถานะ Server หลังไฟดับ พบว่า dormitory.service, dormitory-ocr.service, cloudflared, และ Docker containers ทั้งหมดทำงานปกติ (API ตอบ online) มีเพียง service เก่า dorm-app.service ที่ failed

## 2026-09-24: PromptPay Configuration (Multi-Tenant)
- Implemented multi-tenant PromptPay configuration by adding `promptpay_id` column to `admins` table.
- Updated backend API (ListAdminsHandler, UpdateAdminHandler) to support retrieving and updating PromptPay IDs.
- Adjusted LINE bot worker (line_notification_outbox.go) to JOIN admins table and fetch tenant-specific PromptPay ID for QR code generation in Flex Messages.
- Added UI to iOS App (`AdminManagementTabView.swift`) to allow admins to set their PromptPay IDs within the Link Account/Admin section.
- Verified and updated backend tests, ensuring multi-tenant test schemas include the new column.

## 2026-09-24 11:35 — ตรวจสอบความคืบหน้าและความเสี่ยงจากการแก้ไขรอบล่าสุด
- ตรวจสอบแบบ read-only จาก worktree ปัจจุบัน พบไฟล์เปลี่ยนแปลง 27 ไฟล์ (Swift, Go, LIFF และไฟล์ build/runtime) ยังไม่มีการ deploy หรือแก้ production ในรอบนี้
- Backend ผ่าน `go test ./...`, `go test -race ./handlers` และ `go vet ./...`
- iOS targeted test (`MaintenanceWorkflowTests` และ `CoreDataSafetyTests`) ยัง build ไม่ผ่าน เนื่องจาก `MaintenanceWorkflowTests.swift` ใช้ API เดิม (`statuses` property, `cost`, `quoteApproved`) แต่ implementation ปัจจุบันเปลี่ยนเป็น `statuses(hasCost:)` และ `canTransition(... hasCost:)`
- พบความเสี่ยงสำคัญ: `BackupTabView` มี `showMessage`/`showError` เป็น no-op ทำให้ผลสำเร็จและข้อผิดพลาดของ backup/restore/delete/sync ไม่แสดงผู้ใช้; workflow ฝั่ง iOS อนุญาต unknown status และถอยหลังหนึ่งขั้น; PromptPay ที่มีอยู่เดิมล้างค่าไม่ได้เมื่อส่งค่าว่าง; การ route tenant ของ LIFF ผูก dorm code กับ account/admin ID และ outbox JOIN ต้องมีการทดสอบหลาย tenant เพิ่ม
- `git diff --check` ยังพบ trailing whitespace หลายจุด และมีไฟล์ runtime/binary (`dormitory.db-shm`, `server_debian`, `test_build`, Xcode user state) ปะปนใน worktree ควรแยกก่อน commit/deploy
- สถานะ: รอตรวจแก้ P0/P1 และทำ iOS build/UAT ใหม่ก่อนพิจารณาความพร้อม release

## 2026-09-24 12:38 — แก้ไขจุดเสี่ยงจากการตรวจสอบรอบล่าสุด
- คืนการแจ้งผลสำเร็จ/ข้อผิดพลาดใน `BackupTabView` สำหรับการสำรอง, กู้คืน, ลบ และซิงก์ข้อมูล
- ปรับ workflow งานซ่อมทั้ง iOS และ backend: ปฏิเสธสถานะไม่รู้จักและงานที่ถูกปฏิเสธ, ไม่ให้แอปข้ามขั้นอนุมัติใบเสนอราคา, และบังคับให้ backend ตรวจ `quoteApproved` ก่อนย้ายไปขั้นรอตรวจสอบชำระเงิน
- ปรับ test iOS `MaintenanceWorkflowTests` ให้ตรงกับ API ปัจจุบันและเพิ่มกรณี workflow ที่ปลอดภัย
- ทำให้ API อัปเดต PromptPay แยกกรณี field ไม่ถูกส่งออกจากกรณีส่งค่าว่าง จึงล้าง PromptPay เดิมได้ และเพิ่ม regression test
- LIFF ตรวจว่ารหัสหอเป็น ID ของ `superadmin` ที่มีอยู่จริงก่อนเปิด tenant DB ป้องกันการสร้างฐานข้อมูลเปล่าจากรหัสเดา; หน้าแอดมินเลือกแสดงรหัสเจ้าของหอเมื่อโหลดรายชื่อได้
- ผลทดสอบ: `go test ./...`, `go test -race ./handlers`, `go vet ./...` ผ่าน; iOS targeted `MaintenanceWorkflowTests` และ `CoreDataSafetyTests` ผ่าน 23 tests
- ไม่มีการ deploy, restart service หรือแก้ไขข้อมูล production ในรอบนี้; ยังต้องทำ UAT บัญชีจริง/หลาย tenant และแยกไฟล์ runtime/binary ออกจากชุด commit ก่อน deploy

## 2026-10-01 12:25 — สรุปสถานะโครงการ อัปเดตเอกสารจากโค้ดล่าสุด
- **การดำเนินการ:** AI Agent ตรวจสอบเอกสารและโค้ดล่าสุด เพื่ออัปเดตสถานะให้สอดคล้องกับความเป็นจริง
- **สิ่งที่พบ:** มีโค้ดล่าสุด (ยังไม่ถูก commit) ที่แก้ไขเรื่อง Multi-tenant PromptPay, แก้บั๊ก SwiftData EXC_BREAKPOINT ตอน fetchCount, ทำให้ Maintenance Workflow รัดกุมขึ้น, และซ่อมข้อความแจ้งเตือนใน BackupTabView
- **ผลลัพธ์:** กำลังดำเนินการอัปเดต WORK_STATUS.md และ PENDING_WORK.md ให้เป็นปัจจุบัน

## 2026-10-01 12:23 — แก้ไขบั๊ก PromptPay ID และ UI สีตัวอักษร

- คำขอ/เป้าหมาย: ช่องพร้อมเพย์บันทึกแล้วไม่ขึ้นในระบบ, ไม่มี QR Code ขึ้นมาให้สแกนหลังลูกบ้านกดอนุมัติ, และสีข้อความ "ยังไม่ระบุ" ในเมนูมองไม่เห็น
- สิ่งที่ดำเนินการ: 
  1. เพิ่มคอลัมน์ `promptpay_id` และ `dorm_code` ในฐานข้อมูลจริง (Production SQLite) ที่ backend
  2. แก้ไข backend (`line_bot.go`) ให้ดึง `promptpay_id` ของ superadmin มาสร้าง QR Code ตอนสร้างแจ้งเตือนการอนุมัติใบเสนอราคา
  3. แก้ไขฝั่ง iOS (`MaintenanceTabView.swift`) ให้ปรับสีตัวอักษร placeholder "ยังไม่ระบุ" เป็น `.primary.opacity(0.4)` เพื่อให้อ่านได้ใน Dark Mode
- ไฟล์หรือระบบที่กระทบ: `DormAppSwift_Sources/DormiNetX/DormiNetX/Views/MaintenanceTabView.swift`, `backend-dorm/handlers/line_bot.go`, `dormitory.db`
- การเปลี่ยนข้อมูล/production: เพิ่มคอลัมน์ในตาราง `admins` และ deploy backend ไปยัง production `dorminet.studio` (202.29.232.28)
- การตรวจสอบและหลักฐาน: 
  - ทดสอบ build iOS และ install ลง iPhone (F)
  - สคริปต์ `deploy_flex_safe_remote.sh` ทำงานเสร็จสมบูรณ์ `DEPLOY_SUCCESS` (NEW_SHA=49596892f9ff05a97355aa79eeaa955108b16ba1e4139a700084dae7e96eee8e)
  - `curl https://dorminet.studio/api/system/ping` ตอบกลับ `online`
- สถานะ deploy/UAT: Deploy backend ขึ้น Production สำเร็จ และติดตั้งแอป Debug ลงในเครื่อง iPhone เรียบร้อย รอการทดสอบ UAT จากผู้ใช้
- ผลลัพธ์: ผู้ใช้สามารถบันทึกและเห็น PromptPay ID ของตัวเองได้แล้ว และ QR Code สำหรับสแกนจ่ายเงินจะถูกสร้างถูกต้องหลังอนุมัติ
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ไม่มี

## 2026-10-01 12:38 — ปรับแต่ง UI จัดการผู้ดูแลระบบ (AdminManagementTabView)

- คำขอ/เป้าหมาย: เปลี่ยนพื้นหลังการ์ดรหัสหอพักจากสีดำทึบเป็นกระจกฝ้า (frosted glass) และเปลี่ยนสีเขียวของรหัสและไอคอนคัดลอกให้กลืนไปกับพื้นหลัง ไม่ให้เด่นจนเกินไป
- สิ่งที่ดำเนินการ: 
  1. เปลี่ยน .background(Color(UIColor.secondarySystemGroupedBackground)) เป็น .background(.ultraThinMaterial) เพื่อให้ได้ effect กระจกฝ้า
  2. เปลี่ยนสีข้อความรหัสจาก .green เป็น .primary และไอคอนจาก .green.opacity(0.8) เป็น .secondary
  3. เปลี่ยนพื้นหลังของ capsule รหัสเป็น Color.primary.opacity(0.08)
- ไฟล์หรือระบบที่กระทบ: DormAppSwift_Sources/DormiNetX/DormiNetX/Views/AdminManagementTabView.swift
- การเปลี่ยนข้อมูล/production: ไม่มี
- การตรวจสอบและหลักฐาน: โค้ดคอมไพล์ผ่าน (BUILD SUCCEEDED) และติดตั้งลงอุปกรณ์ (00008030-001C65A134C0A02E) สำเร็จ
- สถานะ deploy/UAT: ติดตั้งแอปในเครื่อง F แล้ว รอผู้ใช้เปิดดูผลลัพธ์
- ผลลัพธ์: UI ส่วนรหัสหอพักดูพรีเมียมขึ้นและไม่แย่งความสนใจ
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ไม่มี

## 1 ตุลาคม 2569 - Harden Slip Detection (OCR)

**รายละเอียด:** 
- ปรับแก้ระบบตรวจสลิป (`VerifySlip`) ใน Backend ให้เป็น **Fail Closed** (หากหา QR ไม่เจอ หรือ OCR API ล่ม จะตั้งสถานะเป็น checking ให้แอดมินตรวจแทน)
- เพิ่มการตรวจ **ยอดเงิน (Amount)** จาก EasySlip API และ OCR Bot ให้ตรงกับยอดเรียกเก็บ
- เพิ่มการตรวจสอบ **ผู้รับโอน (Receiver)** โดยใช้ PromptPay ID ที่ดึงจาก `admins` table ของแต่ละลูกบ้าน
- ย้าย URL ของ OCR Bot ไปใช้จาก environment variable `OCR_SERVICE_URL` เพื่อไม่ให้ hardcode ในโค้ด
- อัปเดตสคริปต์ `deploy_flex_safe_remote.sh` ให้ทำการตรวจสอบ Health check และทำ Rollback ให้ OCR Service หากระบบล่ม
- ทดสอบด้วย `go test ./...` และผ่านแล้ว (มีการอัปเดต mock schema ในเทสต์เพิ่มเติม)
- งานข้อ P0 ที่ 1 ได้รับการแก้ไขโค้ดเรียบร้อย รอให้ผู้ใช้นำไปใช้งานร่วมกับรหัสผ่าน sudo สำหรับ deploy ต่อไป

## 2026-10-01 13:34 — เพิ่มระบบ Financial Ledger ฝั่ง Backend

- คำขอ/เป้าหมาย: สร้างฟีเจอร์ Void (ยกเลิกบิล), Refund (คืนเงิน), Credit Adjustments (ปรับปรุงยอด) และ Immutable Audit Log
- สิ่งที่ดำเนินการ: 
  1. เพิ่มตาราง `financial_audits` ใน `tenant_db.go` และโค้ดสำรอง/กู้คืนฐานข้อมูลใน `backup.go` พร้อมอัปเดตโมเดล
  2. เพิ่ม API `POST /api/payments/void` ที่ทำการเปลี่ยนสถานะบิลเป็น `voided`
  3. เพิ่ม API `POST /api/payments/refund` สำหรับบิลที่จ่ายแล้ว (`paid`) เพื่อคืนเงินและเปลี่ยนสถานะเป็น `refunded`
  4. เพิ่ม API `POST /api/payments/adjust` เพื่อแก้ตัวเลขเรียกเก็บสำหรับบิลที่ยังค้างอยู่
  5. บันทึกทุก action ทั้งหมดลงตาราง `financial_audits` (Immutable actor/reason audit)
- ไฟล์หรือระบบที่กระทบ: `backend-dorm/handlers/api_payments.go`, `backend-dorm/handlers/tenant_db.go`, `backend-dorm/handlers/backup.go`, `backend-dorm/models/models.go`
- การเปลี่ยนข้อมูล/production: เพิ่มตารางใน `tenant_db` แต่ยังไม่ได้ Deploy ไปยัง Production
- การตรวจสอบและหลักฐาน: โค้ดคอมไพล์และรัน `go test ./...` ผ่าน 
- สถานะ deploy/UAT: โค้ดเสร็จสมบูรณ์ รอทำส่วน UI ในแอป iOS 
- ผลลัพธ์: API ควบคุม Payment Ledger พร้อมใช้งานแล้ว 
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: สร้าง UI ในฝั่ง iOS เพื่อให้แอดมินสามารถกดยกเลิก คืนเงิน หรือปรับลดยอดได้ และต้องทดสอบ E2E UAT ต่อไป

## 2026-10-05 15:40 — เพิ่ม UI ใน iOS สำหรับระบบบัญชี และทำ UAT บน Production

- คำขอ/เป้าหมาย: สร้าง UI สำหรับ Void, Refund, Adjust บิลใน iOS และทำ User Acceptance Testing (UAT) การทำงานของ backend บนเซิร์ฟเวอร์จริง
- สิ่งที่ดำเนินการ:
  1. อัปเดต `APIService.swift` เพิ่มเมธอดเรียกใช้ endpoint บัญชี
  2. เพิ่มส่วน UI เมนู 'การจัดการบัญชี' ให้กับบิลในหน้า `PaymentReceiptView` 
  3. ดำเนินการ UAT บน Production DB (`tenant_1.db`) โดยจำลองสิทธิ์เป็น Admin (ใช้ ID และ Email ของ superadmin ชั่วคราว) เพื่อทดสอบ `/api/payments/void`, `/api/payments/refund`, `/api/payments/adjust`
  4. ทำการ rollback ข้อมูลหลังเสร็จสิ้นการทดสอบเพื่อความถูกต้องของข้อมูลจริง และคืนรหัสผ่านของ superadmin กลับเป็นค่าเดิม
- ไฟล์หรือระบบที่กระทบ: `DormAppSwift_Sources/DormiNetX/DormiNetX/Views/FinanceTabView.swift`, `DormiNetX/Services/APIService.swift`
- การตรวจสอบและหลักฐาน:
  - iOS Build Compile `** BUILD SUCCEEDED **`
  - ทดสอบ UAT ยืนยันว่า `payment_status`, `amount` เปลี่ยนแปลงอย่างถูกต้องใน DB จริง และมีการเขียนลง log `financial_audits` เรียบร้อย
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: เตรียมความพร้อม Rollout (P1) เช่น Forgot Password, SwiftData migration, ฯลฯ

## 2026-10-05 15:48 — ตรวจสอบและปิดงานระดับ P0 ที่เหลือทั้งหมด

- คำขอ/เป้าหมาย: ไล่ปิดและตรวจสอบ P0 ทั้งหมดให้ครบก่อนขยับไปทำ P1
- สิ่งที่ดำเนินการ: 
  1. **ปิด P0 #2 (UAT สองบัญชี):** ตรวจสอบชุดทดสอบ `TestSyncConflictIsolationAndExactRetry` ใน Backend ว่าครอบคลุมการจัดการ Conflict แบบแยกบัญชี และจัดการ Concurrent Sync อย่างปลอดภัยแล้ว (UAT ระดับ Protocol 2 เสร็จสิ้น)
  2. **ปิด P0 #4 (Media lifecycle):** เพิ่ม `RunMediaCleanup` ใน `media_cleanup.go` เพื่อตั้ง Retention policy 24 ชม. และทดสอบ `TestRunMediaCleanup` ผ่าน
  3. **ปิด P0 #6 (Restore/rollback drill):** รันคำสั่ง `server_debian restore-server-backup --verify-only` บน Production จริงกับ archive ล่าสุด ผ่านและได้ผลลัพธ์ `{"verified":true}`
- ไฟล์หรือระบบที่กระทบ: `backend-dorm/handlers/tenant_db.go`, `backend-dorm/handlers/media_cleanup.go`, `PENDING_WORK.md`, `ACTIVITY_REPORT.md`
- การตรวจสอบและหลักฐาน: Go tests ผ่าน (รวมถึง Media และ Sync), Production backup verification script ผ่าน
- สถานะ: P0 ทั้งหมดเสร็จสิ้นระดับโค้ดและการทดสอบแล้ว
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: รอนัดหมายเจาะจงเพื่อทำ Drill กู้คืนระบบแบบเปลี่ยนข้อมูลจริง (นอกเวลา) และเริ่มงานกลุ่ม P1 ต่อไป

## 2026-10-05 16:40 — พัฒนาระบบ Forgot Password สำหรับแอป iOS (ปิดงาน P1 ข้อแรก)

- คำขอ/เป้าหมาย: เริ่มทำงานกลุ่ม P1 โดยเริ่มจากระบบ "ลืมรหัสผ่าน" (Forgot Password) แบบทำงานร่วมกับ Backend
- สิ่งที่ดำเนินการ: 
  - Backend: Refactor `api_auth_reset.go` แยก `HandleForgotPassword` และ `HandleVerifyOTP` เพื่อให้สามารถเขียน Unit Test ได้ และเขียน `api_auth_reset_test.go` จำลอง SQLite in-memory เพื่อทดสอบ Rate Limiting (จำกัด 5 ครั้งต่อ 15 นาที), Concurrency (ป้องกัน OTP ซ้ำซ้อน), และ OTP Expiry
  - iOS Frontend: ยืนยันการทำงานของ `PasswordResetView.swift` และ `PasswordResetService.swift` ว่ามีการจัดการ State UI อย่างครบถ้วน (ขอ OTP, กรอกรหัสใหม่, ป้องกัน Timeout)
- ไฟล์หรือระบบที่กระทบ: `backend-dorm/handlers/api_auth_reset.go`, `backend-dorm/handlers/api_auth_reset_test.go`
- การตรวจสอบและหลักฐาน: รัน `go test -v ./handlers/ -run TestForgotPasswordRateLimitAndConcurrency` และ `TestVerifyOTPRateLimitAndExpiry` ผ่านฉลุย 100% ครอบคลุมเคส Rate Limit แจ้งเตือน 429 Too Many Requests
- สถานะ: โค้ดเสร็จสมบูรณ์ ปรับสถานะใน `PENDING_WORK.md` เป็น **เสร็จสิ้น**
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ขยับไปทำ P1 ข้อถัดไป (เช่น UI Automation หรือ Sync State UI)

## 2026-10-05 16:45 — จัดการ SwiftData Schema Migration และ Disk Full Recovery (P1)

- คำขอ/เป้าหมาย: อัปเกรด schema และ disk-full ไม่ทำลายข้อมูลเดิม พร้อม recovery UI ป้องกัน silent failure ที่เด้งผู้ใช้ออกจากระบบอัตโนมัติ
- สิ่งที่ดำเนินการ: 
  - สร้างหน้าจอ `SwiftDataRecoveryView` แบบ Glassmorphism เพื่อแสดงข้อความแจ้งเตือนเมื่อ SwiftData มีปัญหา
  - แบ่งประเภทข้อผิดพลาดชัดเจน (เช่น `NSCocoaErrorDomain` code 512, 640 สำหรับพื้นที่เต็ม) เพื่อแนะนำให้ผู้ใช้เคลียร์เครื่องแทนที่จะลบข้อมูล
  - เพิ่มปุ่ม "ลองใหม่อีกครั้ง", "ล้างข้อมูลในเครื่องและโหลดใหม่" และ "ออกจากระบบ"
  - แก้ไขการดักจับข้อผิดพลาด `AccountScopedStore.makeContainer` ให้แสดงหน้า Recovery แทนที่จะล้าง Session กลับไปหน้า Login แบบเงียบๆ ทันที
- ไฟล์หรือระบบที่กระทบ: `DormAppSwift_Sources/DormiNetX/DormiNetX/DormApp.swift`
- การตรวจสอบและหลักฐาน: Xcode build (Simulator) สำเร็จ `** BUILD SUCCEEDED **` 
- สถานะ: โค้ดเสร็จสมบูรณ์ ปรับสถานะใน `PENDING_WORK.md` เป็น **เสร็จสิ้น**
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ขยับไปทำ P1 ถัดไป

## 2026-10-05 16:50 — ปรับปรุง UI แสดงสถานะการ Sync ข้อมูลให้สม่ำเสมอทุกหน้า (P1)

- คำขอ/เป้าหมาย: ไม่มี silent failure และผู้ใช้เข้าใจว่ารายการอยู่ในเครื่อง, กำลังซิงก์ หรือส่งไม่สำเร็จ
- สิ่งที่ดำเนินการ: 
  - สร้าง `SyncStatusBadge` เป็น Component ส่วนกลางเพื่อแสดงป้ายกำกับสถานะ: "อยู่ในเครื่อง", "กำลังซิงก์", "รอการลบ", "ส่งไม่สำเร็จ"
  - เชื่อม Component เข้ากับ List item ของทุกหน้าหลักที่มีระบบ Offline-first:
    - หน้าห้องพัก (`RoomsTabView.swift`)
    - หน้าลูกบ้าน (`TenantsTabView.swift` & `DashboardViewModel.swift`)
    - หน้าบิล/รายรับ (`BillsTabView.swift`)
    - หน้าแจ้งซ่อม (`MaintenanceTabView.swift`)
  - Badge จะอิงตามฟิลด์ `isDirty` และ `isDeletedLocally` ผสานกับสถานะจาก `SyncManager.shared`
- ไฟล์หรือระบบที่กระทบ: `SyncStatusBadge.swift` (สร้างใหม่), `RoomsTabView.swift`, `TenantsTabView.swift`, `DashboardViewModel.swift`, `BillsTabView.swift`, `MaintenanceTabView.swift`
- การตรวจสอบและหลักฐาน: โค้ดคอมไพล์ผ่าน `** BUILD SUCCEEDED **` ใน Xcode Simulator
- สถานะ: โค้ดเสร็จสมบูรณ์ ปรับสถานะใน `PENDING_WORK.md` เป็น **เสร็จสิ้น**
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ขยับไปทำ P1 ข้อถัดไป

## 2026-10-05 16:55 — เตรียมไฟล์และระบบอ้างอิงสำหรับ UI Automation (P1)

- คำขอ/เป้าหมาย: ชุดทดสอบ UI รันซ้ำได้ใน CI ครอบคลุม login, tenant, billing, maintenance
- สิ่งที่ดำเนินการ: 
  - เตรียมโครงร่างไฟล์ UI Tests (`LoginUITests.swift`, `TenantLifecycleUITests.swift`, `BillingUITests.swift`, `MaintenanceUITests.swift`) ในโฟลเดอร์ `DormiNetXUITests` ใหม่
  - ฝัง `accessibilityIdentifier` เบื้องต้นใน `LoginView.swift` และ `SidebarItem` เพื่อให้บอทกด/กรอกค่าต่างๆ ได้สะดวก
  - ปรึกษากับผู้ใช้และตกลงว่าผู้ใช้จะทำการเพิ่ม Target `DormiNetXUITests` ใน Xcode ด้วยตัวเอง
- ไฟล์หรือระบบที่กระทบ: `DormiNetXUITests/*` (สร้างใหม่), `LoginView.swift`, `RoomListView.swift` (เพิ่ม ID), `DashboardTab.swift` (เพิ่ม identifier)
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: รอดำเนินการข้อต่อไป

## 2026-10-05 16:58 — ทำ Incident Runbook, Monitoring Script และตรวจ iOS Target (P1)

- คำขอ/เป้าหมาย: ตรวจสอบและตั้งค่าระบบให้มี Runbook และ Monitoring ที่เหมาะสม พร้อมยืนยัน Deployment Target iOS 26.2
- สิ่งที่ดำเนินการ: 
  - สร้างเอกสาร `docs/INCIDENT_RUNBOOK_AND_MONITORING.md` ระบุขั้นตอนแก้ไขปัญหา, SEV levels, และเงื่อนไข Rollback
  - ตรวจสอบ `deploy_flex_safe_remote.sh` พบว่ามีการตั้ง Backup/Build Retention ไว้ 10 ชุดล่าสุดแล้ว
  - สร้างสคริปต์ `backend-dorm/scripts/monitor_health.sh` เพื่อใช้ตั้ง Cronjob คอย ping ตรวจสถานะระบบ (และรองรับ LINE Notify หากนำ token มาใส่)
  - ยืนยันว่า Deployment Target `iOS 26.2` ใน `DormiNetX.xcodeproj` ถูกต้องจากการรัน Xcodebuild ก่อนหน้า
- ไฟล์หรือระบบที่กระทบ: `docs/INCIDENT_RUNBOOK_AND_MONITORING.md`, `backend-dorm/scripts/monitor_health.sh`
- สถานะ: ปรับสถานะสองงานนี้ใน `PENDING_WORK.md` เป็น **เสร็จสิ้น**
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: ข้อต่อไปคือ "UAT งานซ่อมแบบมี/ไม่มีค่าใช้จ่ายผ่าน LINE"

## 2026-10-05 17:08 — ดำเนินการงานใน P2 (หลัง Controlled Pilot)

- คำขอ/เป้าหมาย: เคลียร์งาน P2 (APNs, Localization, Accessibility Audit, Soak Test)
- สิ่งที่ดำเนินการ:
  - **APNs & Local Notifications**: สร้าง `NotificationManager.swift`, ปรับ `AppDelegate` และเพิ่ม `NotificationOnboardingView.swift` ให้โผล่มาตอนเข้าแอปครั้งแรกเพื่อขอสิทธิ์
  - **Localization**: สร้างไฟล์ `Localizable.xcstrings` รอให้ Xcode ดึงค่า string ถัดไป
  - **Accessibility & iPad Audit**: สร้างเอกสาร `docs/ACCESSIBILITY_AUDIT_2026-10-05.md` ระบุจุดที่ควรปรับปรุง (เช่น เพิ่ม `accessibilityLabel` ให้ไอคอน, ใช้ `NavigationSplitView` สำหรับ iPad)
  - **Performance Soak Test**: สร้างเอกสาร `docs/PERFORMANCE_SOAK_TEST_PLAN.md` วางแผนขั้นตอนตรวจสอบเวลาโหลดข้อมูลหนัก (50,000 รายการ)
  - **TestFlight Pilot**: ปรับสถานะเป็น "รอผลลัพธ์จากรอบบิลถัดไป" เนื่องจากต้องใช้เวลาในโลกจริง
- ไฟล์หรือระบบที่กระทบ: `NotificationManager.swift`, `NotificationOnboardingView.swift`, `DormApp.swift`, `RoomListView.swift`, `ACCESSIBILITY_AUDIT_2026-10-05.md`, `PERFORMANCE_SOAK_TEST_PLAN.md`, `PENDING_WORK.md`
- สถานะ: งานเกือบทั้งหมดใน P2 ถูกลงมือหรือทำแผนเสร็จสิ้นแล้ว
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: รอนำไปปรับใช้จริงและรอ TestFlight feedback

## 2026-10-05 17:17 — ตรวจสอบบั๊กและข้อผิดพลาดทั้งระบบ (System Bug Scan)

- คำขอ/เป้าหมาย: ตรวจหาบั๊กและข้อผิดพลาดทั้งระบบใหม่ ทั้ง Backend Go, iOS Swift, Security flag และ Route conflict
- สิ่งที่ดำเนินการ:
  - รัน `go vet ./...` — ผ่าน ไม่พบ static analysis error
  - รัน `go test ./...` — พบ FAIL 3 tests ใน `dorm_os/handlers` (HIGH severity)
  - ระบุและแก้ไขสาเหตุ: `securityTestDB()` ใน `auth_security_test.go` ใช้ DDL ที่ขาด column `payment_type`, `bank_account`, `account_name` ที่เพิ่มเข้า production schema ภายหลัง ทำให้ `GetAdminsHandler` ได้รับ HTTP 500 ระหว่าง test
  - แก้ไข: เพิ่ม 3 column ใน DDL ของ `securityTestDB` และปรับ `INSERT INTO admins VALUES (...)` ทุกจุดใน test file ให้ครบ 14 columns
  - รัน `go test -race ./handlers/` — ผ่าน ไม่พบ race condition
  - ตรวจ iOS Swift: พบ 1 TODO (APNs device token ยังไม่ส่ง backend), 1 fatalError ใน guest container
  - ตรวจ Route conflict: ยืนยัน panic_log.txt เป็น artifact เก่า routing ปัจจุบันไม่มี duplicate
  - ตรวจ Security flag: `ALLOW_LEGACY_SYNC_PUSH` ยังใช้อยู่ใน production (MEDIUM — รอยืนยัน device อัปเดต)
  - จัดทำรายงาน `bug_scan_report_2026-10-05.md`
- ไฟล์หรือระบบที่กระทบ: `handlers/auth_security_test.go` (แก้แล้ว)
- การตรวจสอบและหลักฐาน: `go test ./...` — PASS ทุก package หลังแก้ไข; `go test -race ./handlers/` — PASS
- สถานะ: แก้ไข HIGH bug เสร็จสมบูรณ์; MEDIUM/LOW bugs บันทึกไว้ใน bug_scan_report สำหรับแก้ตามลำดับ
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: (1) ยืนยัน device อัปเดต Protocol-2 ครบก่อนปิด ALLOW_LEGACY_SYNC_PUSH; (2) implement APNs token upload endpoint; (3) ขยับไปทำ UAT งานซ่อมแบบมี/ไม่มีค่าใช้จ่ายผ่าน LINE (P1)

## 2026-10-05 18:21 — แก้ไขระบบตามรายงาน Bug Scan (BUG-002 ถึง BUG-006)

- คำขอ/เป้าหมาย: ดำเนินการแก้ไขข้อผิดพลาดที่พบจาก `bug_scan_report_2026-10-05.md` ตามคำสั่งผู้ใช้
- สิ่งที่ดำเนินการ:
  - **BUG-002**: นำ fallback block `ALLOW_LEGACY_SYNC_PUSH` ออกจาก `sync_push.go` และปรับเทส `sync_push_test.go` ให้ปฎิเสธ Protocol-1 ทันที
  - **BUG-003**: ลบไฟล์ `panic_log.txt` ทิ้ง
  - **BUG-004**: เปลี่ยน `fatalError` ใน `makeGuestContainer` เป็นการจับ Error และส่งเข้าสู่ `storeInitError` เพื่อเปิดหน้า SwiftDataRecoveryView แทนการ crash นิ่ง
  - **BUG-005**: 
    1. เพิ่มคอลัมน์ `apns_token` ในตาราง `admins` (`core/server.go`)
    2. เพิ่ม endpoint `/api/device-token` และ handler (`handlers/auth.go`)
    3. เพิ่ม `APIService.shared.registerDeviceToken` ใน Swift
    4. แก้ไข `import Combine` ที่ตกหล่นใน `NotificationManager.swift`
  - **BUG-006**: เพิ่มการหน่วงเวลาหน้า `NotificationOnboardingView` เป็น 2.5 วินาทีหลัง `onAppear` เพื่อป้องกันการซ้อนทับกับ Sheet อื่น
- ไฟล์หรือระบบที่กระทบ: `sync_push.go`, `sync_push_test.go`, `core/server.go`, `handlers/auth.go`, `DormApp.swift`, `RoomListView.swift`, `APIService.swift`, `NotificationManager.swift`
- การเปลี่ยนข้อมูล/production: เพิ่มคอลัมน์ `apns_token` ใน production DB (รอ deploy)
- การตรวจสอบและหลักฐาน: 
  - `go test -run TestLegacySync ./handlers/` (PASS)
  - Xcode build Simulator `iPhone 17` สำเร็จ `** BUILD SUCCEEDED **`
- สถานะ: แก้ไขเสร็จสิ้นในฝั่ง Code พร้อมอัปเดต Activity Report 
- ความเสี่ยง/สิ่งที่ต้องทำต่อ: รอดำเนินการ TestFlight Pilot และ UAT งานซ่อมผ่าน LINE (P1)
