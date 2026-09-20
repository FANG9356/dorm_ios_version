# กฎการทำงานในโปรเจกต์ DormiNetX

กฎนี้ใช้กับคนและ Terminal/Agent ทุกตัวที่ทำงานจาก repository นี้

## ต้องอ่านก่อนเริ่ม

1. อ่าน `project-tracking/README.md` เพื่อดูสถานะและลำดับเอกสารล่าสุด
2. ถ้างานแตะ server, production, backend deploy, database หรือการ build/install แอป ให้อ่าน `docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md` จบก่อนลงมือ
3. ตรวจ `git status --short` ก่อนแก้ ห้ามลบหรือเขียนทับงานเดิมที่ไม่เกี่ยวข้อง
4. ทุกคำขอและทุกการดำเนินงานต้องเพิ่มรายการใหม่แบบ append-only ใน `project-tracking/ACTIVITY_REPORT.md` ก่อนรายงานผล แม้เป็นเพียงการตรวจสอบหรือไม่มีไฟล์เปลี่ยน

## กฎ Server และ Production

- Production SSH คือผู้ใช้และ host ที่ระบุใน runbook; credential จริงให้อ่านจากแหล่ง local ที่ runbook ระบุ ห้ามคัดลอกรหัสผ่าน, token, `.env` หรือข้อมูลลูกบ้านลงเอกสาร, chat, log หรือ commit
- เริ่มด้วยคำสั่ง read-only เสมอ: health, service status, journal และ schema/check ที่ไม่เปลี่ยนข้อมูล
- ห้ามแก้ source, binary, `.env` หรือ SQLite production โดยตรงผ่าน editor/`sed`/คำสั่ง SQL เว้นแต่มีขั้นตอนเฉพาะที่เจ้าของระบบอนุมัติและมี backup/rollback ชัดเจน
- การ deploy backend ต้องใช้ safe deploy ใน runbook ซึ่ง build บน Linux, สำรอง binary/master/tenant DB, restart, health check และ rollback อัตโนมัติ (ห้ามใช้การอัปโหลดไฟล์/build ตรงๆ แบบระบบเก่า)
- ห้ามรัน `./server_debian` ซ้อนกับ `dormitory.service`
- การทดสอบที่เปลี่ยนข้อมูล production ต้องใช้รายการ/บัญชีที่ได้รับอนุญาต บันทึก ID ที่ไม่เปิดเผย PII และมีแผนคืนสถานะ
- ทุก deploy ต้องบันทึก SHA-256, backup path, service/health, database check, ขอบเขต UAT และ rollback ลง activity report และเอกสาร production ที่เกี่ยวข้อง

## กฎ Build และ Test

- Backend ต้องผ่านอย่างน้อย `go test ./...`, `go test -race ./handlers` และ `go vet ./...` ก่อน production deploy
- iOS ให้ค้น destination ปัจจุบันด้วย `xcodebuild -showdestinations`/`xcrun devicectl list devices`; อย่าเชื่อ device ID เก่าหากอุปกรณ์ไม่พบ
- การ install แอปจริงต้อง build/sign สำเร็จก่อน และติดตั้งทับโดยไม่ล้าง app data เว้นแต่ testcase ต้องการ clean install และได้รับอนุญาต
- แยกคำว่า build ผ่าน, automated tests ผ่าน, deploy แล้ว และ UAT ผ่านออกจากกันเสมอ

## ความปลอดภัยของ Secret

- มีการเปลี่ยนไปใช้ SSH Key แทน Password บนเซิร์ฟเวอร์แล้ว (P0 แก้ไขแล้ว) ห้ามบันทึกรหัสผ่านลงสคริปต์อัตโนมัติใดๆ อีก
- ห้ามสร้างเอกสารใหม่ที่ใส่รหัสผ่านจริง หาก credential source ที่ runbook ระบุไม่มีหรือใช้ไม่ได้ ให้หยุดและขอเจ้าของระบบ ไม่เดาและไม่ใส่รหัสลง command history
- เป้าหมายระยะถัดไปคือหมุนเวียน (Rotate) credential เดิมที่หลุดไปในประวัติ (Git history) เช่น JWT Secret, LINE Token และ Resend API Key
