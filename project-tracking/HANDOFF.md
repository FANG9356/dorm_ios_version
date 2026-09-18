# คู่มือส่งต่องาน DormiNetX

อัปเดตล่าสุด: 18 กันยายน 2569

## อ่านก่อนแก้โค้ด

- โปรเจกต์ iOS ที่ใช้งานจริงคือ `DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj`; `Backup_Outer` เป็นสำเนาเก่า
- backend อยู่ที่ `backend-dorm` ใช้ Go + SQLite
- ระบบเป็น local-first: แอปบันทึก local ก่อน แล้ว sync snapshot แยกตามบัญชีไป backend
- LINE เป็น resident-facing channel; action จาก LINE ที่เปลี่ยนข้อมูลต้องตรวจ tenant/ผู้พักปัจจุบันและ publish snapshot กลับเข้าแอป
- production มีข้อมูลจริง ห้ามสร้าง/เปลี่ยนสถานะเพื่อ UAT โดยไม่มีรายการทดสอบที่ได้รับอนุญาต

## แผนที่โค้ดสำคัญ

| เรื่อง | ไฟล์/โฟลเดอร์ |
| --- | --- |
| UI และกฎ workflow งานซ่อม | `DormAppSwift_Sources/DormiNetX/DormiNetX/Views/MaintenanceTabView.swift` |
| iOS workflow tests | `DormAppSwift_Sources/DormiNetX/DormiNetXTests/MaintenanceWorkflowTests.swift` |
| iOS sync/data safety tests | `DormAppSwift_Sources/DormiNetX/DormiNetXTests/CoreDataSafetyTests.swift` |
| Maintenance API/materialization | `backend-dorm/handlers/api_maintenances.go` |
| LINE webhook/actions/Flex | `backend-dorm/handlers/line_bot.go` |
| LINE notification outbox | `backend-dorm/handlers/line_notification_outbox.go` |
| LINE → app snapshot | `backend-dorm/handlers/line_snapshot.go` |
| Workflow backend tests | `backend-dorm/handlers/maintenance_workflow_test.go` |
| LINE/outbox/snapshot tests | `backend-dorm/handlers/line_bot_maintenance_test.go`, `line_notification_outbox_test.go`, `line_snapshot_test.go` |
| Safe deploy | `backend-dorm/scripts/deploy_flex_safe_remote.sh` |
| Restore | `docs/SERVER_RESTORE_RUNBOOK_2026-09-16.md` |

## กฎ workflow งานซ่อม

| จาก | ไป | เงื่อนไขสำคัญ |
| --- | --- | --- |
| รอดำเนินการ | กำลังติดต่อช่าง | แอดมินรับเรื่อง |
| กำลังติดต่อช่าง | รออนุมัติค่าใช้จ่าย | ต้องมียอดมากกว่า 0; ส่ง quote ไป LINE |
| รออนุมัติค่าใช้จ่าย | กำลังซ่อม | เฉพาะ linked resident อนุมัติผ่าน LINE |
| รออนุมัติค่าใช้จ่าย | กำลังติดต่อช่าง | linked resident ปฏิเสธ; แอดมินแก้ยอดและออก quote ใหม่ได้ |
| กำลังติดต่อช่าง | กำลังซ่อม | ทำได้เฉพาะงานไม่มีค่าใช้จ่าย |
| กำลังซ่อม | รอตรวจสอบชำระเงิน | งานมีค่าใช้จ่าย; ส่ง Flex บิล |
| กำลังซ่อม | เสร็จสิ้น | ทำได้เฉพาะงานไม่มีค่าใช้จ่าย |
| รอตรวจสอบชำระเงิน | เสร็จสิ้น | หลังตรวจการชำระ/หลักฐานแล้ว |
| กำลังติดต่อช่าง / รออนุมัติค่าใช้จ่าย | ปฏิเสธค่าใช้จ่าย | ลูกบ้านไม่อนุมัติใบเสนอราคา; เป็น terminal branch ของรายการนั้น ไม่เดินหน้าซ่อมอัตโนมัติ |

หากแก้สถานะหรือชื่อสถานะ ต้องแก้พร้อมกันทั้ง Swift, backend, Flex progress, dashboard/filter และ tests ห้ามแก้เฉพาะ UI

## คำสั่งตรวจสอบหลัก

### iOS workflow และ sync

```bash
cd DormAppSwift_Sources/DormiNetX
xcodebuild test -project DormiNetX.xcodeproj -scheme DormiNetX \
  -destination 'platform=iOS Simulator,id=F1A878C6-F57D-4231-8368-A824D8923F21' \
  -only-testing:DormiNetXTests/MaintenanceWorkflowTests \
  -only-testing:DormiNetXTests/CoreDataSafetyTests \
  CODE_SIGNING_ALLOWED=NO
```

Simulator ID เป็นค่าของเครื่องพัฒนาปัจจุบัน หากไม่มีให้ใช้ `xcrun simctl list devices available` หา ID ใหม่

### Backend

```bash
cd backend-dorm
go test ./...
go test -race ./handlers
go vet ./...
```

### ก่อนส่งงาน

```bash
git diff --check
git status --short
curl --fail --silent --show-error https://api.dorminet.studio/api/system/ping
```

## Production และ rollback

- production binary ปัจจุบัน: SHA-256 `32a26c80c5793f533a1e658790c09aed423b51f104a4e3120496ce5793f07f89`
- rollback set ล่าสุด: `/home/fang/line_migration_backups/20260917-201712-pre-flex-ui` (รวม binary, master และ tenant databases)
- health endpoint: `https://api.dorminet.studio/api/system/ping`
- safe deployment script จะสำรอง binary/master DB ตรวจ health และตรวจ schema additive ของ outbox
- credential deploy อยู่ในไฟล์ ignored ของเครื่องพัฒนา ห้ามพิมพ์ค่าออก log หรือ commit
- ตรวจ outbox production แบบไม่แสดง LINE user ID ด้วย `backend-dorm/scripts/inspect_line_outbox.exp`; บังคับ retry เฉพาะรายการที่ยืนยัน ID แล้วด้วย `backend-dorm/scripts/retry_line_outbox.exp OUTBOX_ID`
- ตรวจสถานะงานซ่อมทั้ง tenant DB และ snapshot ที่แอปจะดึงด้วย `backend-dorm/scripts/inspect_maintenance_workflow.exp MAINTENANCE_ID`
- ทุก production deploy ต้องบันทึก SHA, backup path, health, database check และขอบเขต UAT ลง `docs/PRODUCTION_HARDENING_2026-09-10.md`

## วิธีทำ controlled maintenance UAT

1. ใช้ห้อง/บัญชี LINE ทดสอบที่เจ้าของระบบอนุญาตเท่านั้น
2. เก็บสถานะเริ่มต้นและ record ID ก่อนทดสอบ
3. ทดสอบ paid path: ติดต่อช่าง → quote → approve → repair → payment check → bill/slip → complete
4. ทดสอบ reject path และยืนยันว่าออก quote ใหม่ได้แต่ยอดที่ส่งเดิมไม่ถูกแก้ย้อนหลัง
5. ทดสอบ free path และยืนยันว่าไม่มี quote/bill
6. ตรวจ outbox เป็น `sent`, attempts ไม่ผิดปกติ, เวลาใน Flex เป็นเวลาประเทศไทยและปี พ.ศ. ถูกต้อง
7. กด sync ในแอปและยืนยันว่า iPhone อีกเครื่องเห็นสถานะ/หลักฐานตรงกัน
8. หากพบปัญหา ให้บันทึกใน `UI_LINE_AUDIT_CHECKLIST.md` ก่อนแก้ และเก็บ rollback target ไว้

## พฤติกรรมล่าสุดที่ต้องไม่ทำให้ถอยหลัง

- เมื่อ iOS push snapshot แล้วพบ HTTP 409 เพราะมีข้อมูลใหม่จาก LINE ให้ดึง remote snapshot, rebase local dirty records และ push ซ้ำ; ห้ามหยุดที่ข้อความ conflict จนข้อมูลใหม่ไม่เข้าแอป
- เปิด dashboard หรือหน้าแจ้งซ่อมต้องเริ่ม sync เพื่อให้รายการจาก LINE ปรากฏโดยไม่ต้องรอผู้ใช้กดปุ่มในหน้าอื่น
- การอนุมัติใบเสนอราคาจาก LINE เปลี่ยนกลับเป็น `กำลังติดต่อช่าง` พร้อม approval marker; แอดมินต้องเป็นผู้บันทึก `กำลังซ่อม` ในแอปเอง
- การอนุมัติหรือปฏิเสธสำเร็จส่ง Flex เพียงใบเดียว ไม่ส่ง text bubble ที่ซ้ำความหมาย; text ใช้เฉพาะ error, stale/repeated action หรือ fallback เมื่อ enqueue ไม่สำเร็จ
- สถานะ `ปฏิเสธค่าใช้จ่าย` ต้อง materialize ลงฐาน tenant/snapshot ได้และเป็นสถานะปลายทาง
- หลักฐาน production ล่าสุดของ LINE → app คือ snapshot v161, iPhone dirty 0/pending 0 และรายการ server id 183 ปรากฏใน SwiftData; นี่ไม่ทดแทน UAT สองเครื่อง/สองบัญชี

## จุดเสี่ยงที่ผู้รับช่วงต้องรู้

- เอกสารเก่าบางฉบับเป็น baseline ก่อน hardening ให้ยึดเอกสารวันที่ล่าสุด
- `Payment` ยังเป็น compatibility invoice; แม้มี transaction/receipt แบบ append-only แต่ refund/void/credit audit ยังไม่ครบ
- whole-snapshot sync มี conflict protection/self-healing/rebase แต่ยังไม่ใช่ record-level merge เต็มรูปแบบ
- media business flow ปลอดภัยขึ้นแล้ว แต่ orphan cleanup/retention และ cross-device UAT ยังไม่ปิด
- Keychain test บางชุดบน Simulator อาจล้มด้วย entitlement `-34018`; ต้องแยก environment failure ออกจาก product regression และยืนยัน signed-device path
- online restore endpoint เดิมถูกปิดแบบ fail closed; production restore ต้องทำตาม maintenance-mode runbook เท่านั้น

## Definition of Done สำหรับงานใหม่

- behavior และ acceptance criteria ถูกเขียนก่อนหรือพร้อมโค้ด
- validation อยู่ในชั้นที่เชื่อถือได้ ไม่พึ่งการ disable ปุ่มอย่างเดียว
- เพิ่ม/แก้ automated tests สำหรับ business rule ที่เปลี่ยน
- iOS/backend build และ test ที่เกี่ยวข้องผ่าน
- งานที่แตะ LINE/sync มี idempotency, authorization และ retry/error path
- งาน production มี backup, health check, rollback และ UAT evidence
- อัปเดต `WORK_STATUS.md`, `PENDING_WORK.md`, checklist และ assessment เมื่อความเสี่ยงเปลี่ยนจริง
