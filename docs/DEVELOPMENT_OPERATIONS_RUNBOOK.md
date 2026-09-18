# คู่มือเข้า Server, รัน Backend และ Build แอป DormiNetX

อัปเดตล่าสุด: 18 กันยายน 2569 (Asia/Bangkok)

เอกสารนี้เป็น runbook สำหรับ Terminal/Agent ตัวใหม่ให้ทำงานต่อได้โดยไม่ต้องเดาเส้นทาง ระบบนี้มี production data จริง ทุกขั้นที่เปลี่ยน server, database หรือแอปบนอุปกรณ์ต้องบันทึกใน `project-tracking/ACTIVITY_REPORT.md`

## 1. ค่าระบบที่ใช้งานอยู่

| รายการ | ค่า |
| --- | --- |
| Workspace บนเครื่องพัฒนา | `/Volumes/FangB/dorm_project` |
| Git branch หลัก | `main` |
| Git remote | `git@github.com:FANG9356/dorm_ios_version.git` |
| Production API | `https://api.dorminet.studio` |
| Health endpoint | `https://api.dorminet.studio/api/system/ping` |
| Production SSH host/IP | `202.29.232.28` |
| SSH port | `22` |
| SSH user | `fang` |
| SSH/sudo password | อ่านค่าปัจจุบันจาก `set password` ใน `backend-dorm/build_deploy.exp` บนเครื่องพัฒนาเท่านั้น ไฟล์นี้เป็นแหล่ง credential ชั่วคราว **ห้าม execute เป็น deploy script** และห้ามคัดลอกค่าจริงลงเอกสาร/chat/log/commit |
| systemd service | `dormitory.service` |
| OCR systemd service | `dormitory-ocr.service` |
| Backend working directory | `/opt/dormitory` |
| Production binary | `/opt/dormitory/server_debian` |
| OCR working directory | `/opt/dormitory/ocr-bot` |
| Master database | `/opt/dormitory/dormitory.db` |
| Tenant databases | `/opt/dormitory/dorm_data/tenant_*.db` |
| Local backend port บน server | `4283` |
| Local OCR port บน server | `5001` บน `127.0.0.1` เท่านั้น |
| iOS project | `DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj` |
| Xcode scheme | `DormiNetX` |
| App bundle ID | `com.dorminet.DormiNetX` |

### คำเตือนเรื่องรหัสผ่าน

ไฟล์ `.exp` รุ่นเก่าหลายไฟล์มีรหัสฝังและถูก Git ติดตามอยู่แล้ว นี่เป็น known P0 ที่ต้อง rotate/revoke ในอนาคต ไม่ควรเพิ่มสำเนารหัสอีก หากไฟล์ credential ไม่มีหรือใช้ไม่ได้ให้ขอเจ้าของระบบ ห้ามเดารหัสหรือพิมพ์รหัสลงคำสั่งที่ถูกเก็บใน shell history

## 2. เริ่มงานจาก Terminal ใหม่

```bash
cd /Volumes/FangB/dorm_project
git branch --show-current
git status --short
curl --fail --silent --show-error https://api.dorminet.studio/api/system/ping
```

ผลที่คาดหวัง:

- branch ปกติคือ `main`
- `git status` อาจมีงานค้างของผู้อื่น ห้าม reset/checkout/delete โดยพลการ
- health endpoint ควรตอบ JSON ที่มีสถานะ `online`
- อย่าคัดลอก “SHA ล่าสุด” จากเอกสารเก่า เพราะ Terminal อื่นอาจ deploy ระหว่างทำงาน ให้ตรวจ `sha256sum /opt/dormitory/server_debian` และ backup directory สดทุกครั้ง

ก่อนแก้ให้อ่านตามลำดับ:

1. `AGENTS.md`
2. `project-tracking/README.md`
3. `project-tracking/WORK_STATUS.md`
4. `project-tracking/PENDING_WORK.md`
5. `project-tracking/HANDOFF.md`
6. runbook ฉบับนี้

## 3. เข้า Production Server แบบปลอดภัย

### เข้าแบบ interactive

```bash
ssh fang@202.29.232.28
```

ใช้ SSH/sudo credential จากแหล่งที่ระบุในตารางด้านบน หลังเข้าแล้วให้ตรวจแบบ read-only ก่อน:

```bash
hostname
cd /opt/dormitory
sudo systemctl status dormitory.service --no-pager
sudo systemctl status dormitory-ocr.service --no-pager
sudo journalctl -u dormitory.service -n 100 --no-pager
sudo journalctl -u dormitory-ocr.service -n 100 --no-pager
curl --fail --silent --show-error http://127.0.0.1:4283/api/system/ping
sha256sum /opt/dormitory/server_debian
```

ออกจาก server ด้วย `exit` เมื่อเสร็จ ห้ามเปิด process `./server_debian` เองขณะที่ systemd service ทำงานอยู่

### ตรวจจากเครื่องพัฒนาโดยไม่เปิด shell ค้าง

```bash
ssh -t fang@202.29.232.28 'sudo systemctl is-active dormitory.service'
ssh -t fang@202.29.232.28 'sudo systemctl is-active dormitory-ocr.service'
ssh -t fang@202.29.232.28 'sudo journalctl -u dormitory.service -n 100 --no-pager'
ssh -t fang@202.29.232.28 'sudo journalctl -u dormitory-ocr.service -n 100 --no-pager'
curl --fail --silent --show-error https://api.dorminet.studio/api/system/ping
```

ถ้าต้องตรวจ LINE outbox/workflow ให้ใช้สคริปต์ที่ลดการเปิดเผยข้อมูล:

```bash
cd /Volumes/FangB/dorm_project
backend-dorm/scripts/inspect_line_outbox.exp
backend-dorm/scripts/inspect_maintenance_workflow.exp MAINTENANCE_ID
backend-dorm/scripts/inspect_recent_maintenance.exp
```

ใช้ `retry_line_outbox.exp OUTBOX_ID` เฉพาะเมื่อยืนยัน record และเหตุผลที่จะ retry แล้ว เพราะเป็นการเปลี่ยนสถานะงานส่งจริง

## 4. รันและทดสอบ Backend ในเครื่อง

```bash
cd /Volumes/FangB/dorm_project/backend-dorm
go test ./...
go test -race ./handlers
go vet ./...
```

การรัน backend local ต้องมี `backend-dorm/.env` ของเครื่องนั้นและต้องไม่ commit ไฟล์นี้:

```bash
cd /Volumes/FangB/dorm_project/backend-dorm
go run .
```

ก่อนรันให้ตรวจว่า port ที่ config กำหนดไม่ชนกับ process อื่น และอย่าใช้สำเนาฐาน production โดยไม่มีการทำให้ข้อมูลส่วนบุคคลปลอดภัย หากเพียงต้องตรวจ compile/tests ไม่ต้องเปิด server local

## 5. Deploy Backend Production

### 5.1 Preflight บนเครื่องพัฒนา

```bash
cd /Volumes/FangB/dorm_project
git status --short
cd backend-dorm
go test ./...
go test -race ./handlers
go vet ./...
cd ..
curl --fail --silent --show-error https://api.dorminet.studio/api/system/ping
```

อ่าน diff ที่จะ deploy และยืนยันว่า archive ไม่มี `.env`, database, uploads, log หรือ binary เก่า

### 5.2 สร้าง source archive จาก working tree

```bash
cd /Volumes/FangB/dorm_project
DORMINETX_DEPLOY_TMP="$(mktemp -d /tmp/dorminetx-deploy.XXXXXX)"
tar -czf "$DORMINETX_DEPLOY_TMP/dorminet-backend.tar.gz" \
  --exclude='.git' \
  --exclude='backend-dorm/.env' \
  --exclude='backend-dorm/.env.*' \
  --exclude='backend-dorm/*.exp' \
  --exclude='backend-dorm/scripts/*.exp' \
  --exclude='backend-dorm/*.db' \
  --exclude='backend-dorm/*.db-shm' \
  --exclude='backend-dorm/*.db-wal' \
  --exclude='backend-dorm/dorm_data' \
  --exclude='backend-dorm/uploads' \
  --exclude='backend-dorm/backups' \
  --exclude='backend-dorm/backups_zip' \
  --exclude='backend-dorm/*.log' \
  --exclude='backend-dorm/server' \
  --exclude='backend-dorm/server_debian' \
  backend-dorm
tar -tzf "$DORMINETX_DEPLOY_TMP/dorminet-backend.tar.gz" | sed -n '1,80p'
if tar -tzf "$DORMINETX_DEPLOY_TMP/dorminet-backend.tar.gz" | \
  rg '(^|/)(\.env($|\.)|.*\.exp$|.*\.db($|-|\.)|uploads/|dorm_data/)'; then
  printf '%s\n' 'พบ credential/runtime data ใน archive — ห้าม deploy' >&2
  exit 1
fi
```

ตรวจรายชื่อใน archive ก่อน deploy หากเห็น `.env`, `.exp`, `.db`, uploads หรือข้อมูล runtime ให้หยุดและสร้าง archive ใหม่ ไฟล์ `.exp` ถูกตัดออกเพราะสคริปต์เก่าบางไฟล์มี credential และ backend build ไม่ต้องใช้ไฟล์เหล่านี้

### 5.3 Safe deploy

```bash
cd /Volumes/FangB/dorm_project
backend-dorm/scripts/run_flex_safe_deploy.exp \
  "$DORMINETX_DEPLOY_TMP/dorminet-backend.tar.gz"
```

สคริปต์นี้จะ:

1. upload source และ remote deploy script
2. ล็อก deployment ด้วย `flock` เพื่อไม่ให้ Agent/Terminal สองตัว deploy ทับกัน
3. build ด้วย Linux/CGO บน server
4. สำรอง binary, master DB และ tenant DB ลง `/home/fang/line_migration_backups/TIMESTAMP-pre-flex-ui`
5. stop/install/start `dormitory.service`
6. health check ที่ `127.0.0.1:4283`
7. rollback binary อัตโนมัติถ้า install/start/health ล้มเหลว
8. หลัง deploy สำเร็จ เก็บ build ล่าสุด 2 ชุดและ automated rollback ล่าสุด 10 ชุด แล้วลบชุดเก่าตาม retention
9. แสดง `NEW_SHA`, `BACKUP_DIR` และจำนวน artifact ที่ retention ลบ

หาก build หรือ automated backup ใดเป็น milestone ที่ต้องเก็บข้าม retention ให้สร้างไฟล์ marker ชื่อ `.retain` ภายใน directory นั้นก่อน deploy รอบถัดไป ระบบจะไม่ลบ backup แบบตั้งชื่อเองที่อยู่นอก pattern `TIMESTAMP-pre-flex-ui` และจะไม่แตะ `/opt/dormitory`, uploads หรือฐานข้อมูล live ระหว่าง cleanup

รุ่นปัจจุบันยังติดตั้ง OCR service เพิ่มด้วย ได้แก่ Tesseract ภาษาไทย, Python virtual environment, dependencies ใน `backend-dorm/ocr-bot/requirements.txt` และ systemd unit `dormitory-ocr.service`

ข้อจำกัดสำคัญ: safe deploy ปัจจุบัน rollback อัตโนมัติเฉพาะ Go binary เมื่อ main health ล้มเหลว ยังไม่สำรอง/rollback OCR directory, Python dependencies หรือ systemd unit และคำสั่งติดตั้ง OCR บางส่วนยอมให้ล้มแล้ว deploy ดำเนินต่อ ดังนั้นข้อความ `DEPLOY_SUCCESS` เพียงอย่างเดียวไม่ยืนยันว่า OCR ใช้งานได้

### 5.4 ตรวจหลัง deploy

```bash
curl --fail --silent --show-error https://api.dorminet.studio/api/system/ping
ssh -t fang@202.29.232.28 'sudo systemctl is-active dormitory.service'
ssh -t fang@202.29.232.28 'sudo systemctl is-active dormitory-ocr.service'
ssh -t fang@202.29.232.28 'sudo journalctl -u dormitory.service -n 100 --no-pager'
ssh -t fang@202.29.232.28 'sudo journalctl -u dormitory-ocr.service -n 100 --no-pager'
ssh -t fang@202.29.232.28 \
  "curl --fail --silent --show-error -X POST \
  -H 'Content-Type: application/json' \
  -d '{}' http://127.0.0.1:5001/verify >/dev/null || test \$? -eq 22"
```

OCR probe ที่ส่ง `{}` ควรได้ HTTP 400 ซึ่งยืนยันว่า process ตอบสนอง; ไม่ได้ยืนยันความแม่นยำของ OCR หรือการตรวจสลิป

บันทึกอย่างน้อย: เวลา, ขอบเขตการเปลี่ยน, test commands, `NEW_SHA`, `BACKUP_DIR`, health, main/OCR service state, schema/data check ที่ไม่เปิด PII, UAT ที่ทำจริง และสิ่งที่ยังไม่ได้ทดสอบ

ห้ามใช้ `backend-dorm/deploy.exp` หรือ `backend-dorm/build_deploy.exp` เป็น deployment flow ปกติ เพราะเป็น legacy script ที่หยุด service ก่อนขั้น upload/build และไม่มี safety เท่า flow ปัจจุบัน

## 6. Rollback Backend

หาก safe deploy รายงาน health failure สคริปต์จะคืน binary เดิมอัตโนมัติ หากปัญหาเกิดหลังจากนั้น:

1. หยุดการเปลี่ยนข้อมูล/UAT เพิ่ม
2. เก็บ health, journal, SHA ปัจจุบัน และ backup path
3. ใช้ binary จาก `BACKUP_DIR` ที่ safe deploy แสดง ห้ามเลือก directory ด้วยการเดา
4. หากต้อง rollback database หรือ restore ทั้งระบบ ให้อ่าน `docs/SERVER_RESTORE_RUNBOOK_2026-09-16.md` และทำใน maintenance window เท่านั้น

ห้าม copy SQLite ทับขณะ service ยัง active และห้ามใช้ online restore endpoint เดิม

OCR ไม่มี atomic rollback ในสคริปต์ปัจจุบัน หาก deployment แตะ `ocr-bot`, requirements หรือ unit file ต้องสำรอง `/opt/dormitory/ocr-bot` และ `/etc/systemd/system/dormitory-ocr.service` แยกก่อน deploy และบันทึก path ไว้ ห้ามอ้างว่า rollback ครบทั้งระบบจาก backup ของ Go binary อย่างเดียว

## 7. เปิดและ Build แอป iOS

### เปิดใน Xcode

```bash
cd /Volumes/FangB/dorm_project
open DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj
```

### ค้น Simulator และอุปกรณ์จริงทุกครั้ง

```bash
xcodebuild \
  -project DormAppSwift_Sources/DormiNetX/DormiNetX.xcodeproj \
  -scheme DormiNetX \
  -showdestinations
xcrun simctl list devices available
xcrun devicectl list devices
```

ค่าที่พบ ณ วันที่เขียนเอกสาร ซึ่งอาจเปลี่ยนได้:

| ปลายทาง | ID |
| --- | --- |
| Simulator `DormiNetX Core Tests` | `F1A878C6-F57D-4231-8368-A824D8923F21` |
| iPhone ชื่อ `F` สำหรับ xcodebuild | `00008030-001C65A134C0A02E` |
| iPhone ชื่อ `F` สำหรับ devicectl | `8443F450-FF77-56AB-BE70-0CCCCFDE5C76` |

ถ้าคำสั่ง discovery ให้ค่าใหม่ ให้ใช้ค่าใหม่ ไม่แก้โค้ดเพื่อให้ตรง ID เก่า

### Build สำหรับ Simulator

```bash
cd /Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX
xcodebuild build \
  -project DormiNetX.xcodeproj \
  -scheme DormiNetX \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=F1A878C6-F57D-4231-8368-A824D8923F21' \
  CODE_SIGNING_ALLOWED=NO
```

### รัน targeted tests หลัก

```bash
cd /Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX
xcodebuild test \
  -project DormiNetX.xcodeproj \
  -scheme DormiNetX \
  -destination 'platform=iOS Simulator,id=F1A878C6-F57D-4231-8368-A824D8923F21' \
  -only-testing:DormiNetXTests/MaintenanceWorkflowTests \
  -only-testing:DormiNetXTests/CoreDataSafetyTests \
  CODE_SIGNING_ALLOWED=NO
```

### Build, sign และติดตั้งบน iPhone `F`

ปลดล็อก iPhone, เชื่อมต่อ/จับคู่เครื่อง และยืนยันว่า `xcrun devicectl list devices` แสดง `available` ก่อน:

```bash
cd /Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX
DORMINETX_DERIVED_DATA="$(mktemp -d /tmp/dorminetx-derived.XXXXXX)"
xcodebuild build \
  -project DormiNetX.xcodeproj \
  -scheme DormiNetX \
  -configuration Debug \
  -destination 'platform=iOS,id=00008030-001C65A134C0A02E' \
  -derivedDataPath "$DORMINETX_DERIVED_DATA" \
  -allowProvisioningUpdates
xcrun devicectl device install app \
  --device 8443F450-FF77-56AB-BE70-0CCCCFDE5C76 \
  "$DORMINETX_DERIVED_DATA/Build/Products/Debug-iphoneos/DormiNetX.app"
xcrun devicectl device process launch \
  --device 8443F450-FF77-56AB-BE70-0CCCCFDE5C76 \
  com.dorminet.DormiNetX
```

การติดตั้งคำสั่งนี้เป็นการติดตั้งทับเพื่อเก็บ app data เดิม ห้าม uninstall ก่อนเว้นแต่ testcase ต้องการ clean install และได้รับอนุญาต เพราะการ uninstall จะลบข้อมูล local ของแอป

## 8. Checklist ก่อนส่งต่องานให้ Terminal ถัดไป

- [ ] ตรวจ `git status --short` และแยกงานเดิม/งานใหม่ชัดเจน
- [ ] ระบุไฟล์ที่แก้และเหตุผล
- [ ] ระบุ test/build ที่รันจริงพร้อมจำนวนผ่าน/ล้มเหลว
- [ ] ถ้า deploy: ระบุ SHA, backup path, service, internal/external health และ rollback target
- [ ] ถ้าแตะ OCR/slip: ตรวจ `dormitory-ocr.service`, localhost:5001, Python dependency, main fallback behavior และระบุว่าได้ทดสอบความถูกต้องของยอด/ผู้รับเงินจริงหรือยัง
- [ ] ถ้าเปลี่ยนข้อมูล: ระบุ record scope, backup และวิธีย้อนกลับโดยไม่ใส่ PII
- [ ] ระบุสิ่งที่ยังไม่ได้ทดสอบ ห้ามเรียก deploy ว่า UAT ผ่าน
- [ ] เพิ่มรายการใหม่ใน `project-tracking/ACTIVITY_REPORT.md`
- [ ] อัปเดต `WORK_STATUS.md`, `PENDING_WORK.md`, checklist หรือ assessment หากสถานะความเสี่ยงเปลี่ยนจริง

## 9. งาน Security ที่ต้องทำต่อ

- rotate/revoke SSH/sudo password และ provider secrets ที่เคยอยู่ใน Git history
- เปลี่ยน server access เป็น SSH key แยกผู้ปฏิบัติงานและปิด password login เมื่อทดสอบ recovery access แล้ว
- ย้าย credential ออกจาก `.exp` ที่ Git ติดตามไปยัง local secret store/ignored file
- ล้าง Git history อย่างมีแผนหลัง rotate แล้ว ไม่ใช่เพียงลบข้อความจากไฟล์ล่าสุด
- ย้าย PromptPay ID, ชื่อผู้รับ และ EasySlip token ไป secret/config store; ห้าม hardcode ข้อมูลรับเงินจริงใน source
- ทำ slip verification ให้ fail closed: ห้ามถือว่า QR ใด ๆ ที่ยาวเกินเกณฑ์คือชำระถูกต้อง และห้ามเปลี่ยนบิลเป็น `paid`/งานเป็น `เสร็จสิ้น` จนตรวจยอด ผู้รับ เลขอ้างอิง และ replay ได้ครบ
- ลดสิทธิ์ `dormitory-ocr.service` จาก root, เพิ่ม request authentication/allowlist ที่เหมาะสม และทำ OCR deploy/health/rollback ให้เป็นส่วนหนึ่งของ safe deploy
- ประเมินการส่ง PromptPay payload/ยอดไปผู้ให้บริการสร้าง QR ภายนอกก่อนใช้กับข้อมูลจริง

จนกว่างานนี้เสร็จ ห้ามนำรหัสปัจจุบันไปทำสำเนาในไฟล์หรือระบบอื่น
