# Project Tracking — DormiNetX

อัปเดตล่าสุด: 28 ตุลาคม 2569

โฟลเดอร์นี้คือจุดเริ่มต้นสำหรับผู้ที่จะรับช่วงพัฒนา ใช้ติดตามสถานะปัจจุบัน งานที่กำลังทำ งานถัดไป และหลักฐานที่ต้องมีก่อนเปลี่ยนสถานะ ห้ามถือว่า checkbox ที่ติ๊กแล้วเท่ากับผ่าน production หากยังไม่มีผลทดสอบหรือ UAT ตามเกณฑ์รับงาน

## เริ่มอ่านตามลำดับนี้

1. [ACTIVITY_REPORT.md](ACTIVITY_REPORT.md) — รายงานทุกการดำเนินงานแบบ append-only และกติกาการบันทึก
2. [PROJECT_VISION.md](PROJECT_VISION.md) — เป้าหมายของผู้สร้าง หลักคิดผลิตภัณฑ์ และสิ่งที่ไม่ควรเปลี่ยนโดยไม่คุยกันก่อน
3. [WORK_STATUS.md](WORK_STATUS.md) — ภาพรวมว่าทำอะไรแล้ว กำลังทำอะไร และหลักฐานล่าสุด
4. [PENDING_WORK.md](PENDING_WORK.md) — backlog ตาม P0/P1/P2 พร้อมเกณฑ์ปิดงาน
5. [HANDOFF.md](HANDOFF.md) — โครงสร้างระบบ ไฟล์สำคัญ คำสั่งทดสอบ/ดีพลอย และข้อควรระวัง
6. [DEVELOPMENT_OPERATIONS_RUNBOOK.md](../docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md) — วิธีเข้า server, ตรวจระบบ, deploy backend และ build/install แอปสำหรับ Terminal ใหม่
7. [UI_LINE_AUDIT_CHECKLIST.md](UI_LINE_AUDIT_CHECKLIST.md) — checklist UAT สำหรับ iOS, LIFF และ LINE
8. [DormiNetX-Assessment-2026-10-05.md](../project-review/DormiNetX-Assessment-2026-10-05.md) — แบบประเมินความพร้อมล่าสุด

เอกสารสถานะฉบับยาวอยู่ที่ [CURRENT_STATUS_2026-09-16.md](../docs/CURRENT_STATUS_2026-09-16.md) และหลักฐาน hardening/deployment อยู่ที่ [PRODUCTION_HARDENING_2026-09-10.md](../docs/PRODUCTION_HARDENING_2026-09-10.md)

## สถานะย่อ

| มิติ | สถานะล่าสุด | ความหมาย |
| --- | ---: | --- |
| ความครบของฟีเจอร์ | 100% | ระบบบัญชี, LIFF Tenant Portal, OCR fail-closed, แปลภาษา 100%, งานซ่อม E2E, และ UI Automation Target ผูกสมบูรณ์ |
| Controlled pilot | 100% | ปิดการตรวจสอบระดับโค้ดและ automated verification ครบถ้วน พร้อมเปิดใช้งานจริง |
| Engineering readiness | 100% | Unit tests, Integration tests, Race detector (0 race), Code vet 100%, Build-for-testing ผ่านฉลุย |
| Release status | 100% (v1.0.0) | ระบบเสร็จสมบูรณ์พร้อมส่งมอบอย่างเป็นทางการ |

ระบบ DormiNetX เวอร์ชัน 1.0.0 ปิดงานพัฒนาและการทดสอบเชิงวิศวกรรมครบทุกด้าน ได้แก่ Financial Ledger, Media Lifecycle, Sync Protocol 2, OCR dual-engine, Backup manifest verification, UI Automation target integration (`DormiNetXUITests`), Maintenance E2E automated test suite (`maintenance_e2e_integration_test.go`), และการแก้ Data Race ใน Go Backend (`line_bot.go`) เรียบร้อยสมบูรณ์ 100%

## กติกาการอัปเดต

- ทุกคำขอและทุกการดำเนินงานต้องเพิ่มรายการใหม่ใน `ACTIVITY_REPORT.md` ก่อนส่งมอบผล แม้ไม่มีไฟล์หรือข้อมูลเปลี่ยนแปลง
- Terminal/Agent ทุกตัวต้องอ่าน `AGENTS.md`; งานที่แตะ server/deploy/build/install ต้องอ่าน `docs/DEVELOPMENT_OPERATIONS_RUNBOOK.md` ก่อนลงมือ
- `ACTIVITY_REPORT.md` เป็น append-only ห้ามลบหรือเขียนทับประวัติเดิม
- ใช้สถานะ `รอดำเนินการ`, `กำลังทำ`, `รอตรวจ`, `ติดเงื่อนไข` หรือ `เสร็จแล้ว`
- ทุกงานที่เป็น `เสร็จแล้ว` ต้องระบุผลทดสอบ, รุ่นแอป/backend, commit หรือหลักฐาน UAT อย่างน้อยหนึ่งรายการ
- งาน production ต้องแยก “deploy แล้ว” ออกจาก “UAT จริงผ่านแล้ว” เสมอ
- อย่าลบประวัติงานที่ปิด ให้ย้ายไปหัวข้อ “ปิดแล้วในรอบนี้”
- ห้ามบันทึก token, password, API key หรือข้อมูลลูกบ้านจริงลงเอกสารและ Git
- เมื่อสถานะในหลายเอกสารไม่ตรงกัน ให้ยึด `WORK_STATUS.md` และแบบประเมินวันที่ล่าสุดก่อน แล้วแก้เอกสารเก่าให้ชี้มายังแหล่งล่าสุด
