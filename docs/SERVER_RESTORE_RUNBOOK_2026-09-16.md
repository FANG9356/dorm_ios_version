# คู่มือกู้คืน Server Backup แบบ Maintenance Mode

วันที่อัปเดต: 16 กันยายน 2569

คำสั่งนี้ใช้กับ `server_backup_*.zip` ที่สร้างโดย `PerformServerBackup` เท่านั้น และกู้คืน master database, tenant databases และ compatibility media directory เป็นชุดเดียวกัน ห้ามใช้กับ ZIP export รุ่นเก่าที่มีเพียง `data.json`

## คุณสมบัติความปลอดภัย

- ตรวจ `manifest.json`, format version, รายการไฟล์, ขนาด และ SHA-256 ก่อนแตะข้อมูลจริง
- ปฏิเสธ path traversal, symlink, entry ซ้ำ, entry ที่ไม่อยู่ใน manifest และไฟล์ฐานข้อมูล tenant ที่ชื่อไม่ถูกต้อง
- เปิดฐานข้อมูลทุกไฟล์แบบ read-only แล้วรัน `PRAGMA quick_check`
- แตกไฟล์ลง staging directory บน filesystem เดียวกับข้อมูลจริง
- สลับ master database, tenant directory และ media directory ด้วย rename ใน maintenance window
- ถ้าการสลับหรือการตรวจหลังสลับล้มเหลว จะนำข้อมูลเดิมกลับอัตโนมัติ
- เมื่อสำเร็จจะเก็บข้อมูลก่อน restore ไว้ใน `restore_rollbacks/restore_rollback_*`
- มีคำสั่ง rollback ที่เก็บชุด restore ซึ่งใช้งานไม่ได้ไว้ใน `failed_restore_*` แทนการลบทิ้ง

## 1. ตรวจ archive โดยไม่เปลี่ยนข้อมูล

ทำขั้นตอนนี้ได้ก่อน maintenance window:

```bash
cd /opt/dormitory
./server_debian restore-server-backup \
  --verify-only \
  --archive ./backups_zip/server_backup_YYYY-MM-DD_HH-MM-SS.zip
```

ผลที่ผ่านต้องมี `"verified":true` พร้อมจำนวนฐานข้อมูลและไฟล์ media ที่ตรวจพบ คำสั่งนี้จะลบ staging หลังตรวจและไม่สร้าง rollback set

## 2. เตรียม maintenance window

1. แจ้งผู้ดูแลให้งดแก้ข้อมูลและซิงก์จากอุปกรณ์ทุกเครื่อง
2. สร้าง backup ใหม่ก่อน restore และเก็บ archive เป้าหมายไว้อีกเครื่องหนึ่ง
3. บันทึกชื่อ binary/SHA-256, archive, เวลาเริ่ม และผู้ดำเนินการใน incident log
4. หยุด backend และยืนยันว่าหยุดจริง:

```bash
sudo systemctl stop dormitory.service
sudo systemctl is-active dormitory.service
```

ผลของคำสั่งที่สองต้องเป็น `inactive` ห้ามทำ restore ถ้ายังเป็น `active`, `activating` หรือ service กำลัง restart

5. ตรวจว่า clean shutdown ไม่เหลือ WAL ที่มีข้อมูล:

```bash
cd /opt/dormitory
test ! -s dormitory.db-wal
test ! -s dormitory.db-shm
```

ตัว restore จะปฏิเสธเองหากพบ sidecar ที่มีขนาดมากกว่า 0 แต่ผู้ดำเนินการต้องยืนยันว่า service หยุดแล้วเสมอ

## 3. Restore

```bash
cd /opt/dormitory
sudo env DORMINET_MAINTENANCE_MODE=true ./server_debian restore-server-backup \
  --archive ./backups_zip/server_backup_YYYY-MM-DD_HH-MM-SS.zip \
  --master ./dormitory.db \
  --tenants ./dorm_data \
  --uploads ./uploads \
  --rollbacks ./restore_rollbacks
```

เมื่อสำเร็จให้จดค่า `rollback_path` จาก JSON ห้ามลบ directory นี้ก่อนผ่าน health check, session test, tenant test และ sync smoke test

## 4. เปิดระบบและตรวจสุขภาพ

```bash
sudo systemctl start dormitory.service
sudo systemctl is-active dormitory.service
curl --fail --silent --show-error https://dorminet.studio/api/system/ping
```

จากนั้นต้องตรวจอย่างน้อย:

1. login/session ของบัญชีทดสอบ
2. account scope และเปิด tenant database ที่ถูกต้อง
3. จำนวนห้อง ลูกบ้าน บิล งานซ่อม และ sync version เทียบกับ archive
4. media ตัวอย่างของแต่ละ tenant ต้องเปิดได้เฉพาะ tenant เจ้าของ
5. push/pull smoke test จากอุปกรณ์ทดสอบหนึ่งเครื่อง

หากทุกข้อผ่าน ให้บันทึกผลและคง rollback set ตาม retention policy ก่อนลบอย่างควบคุม

## 5. Rollback เมื่อ health check ไม่ผ่าน

หยุด service ก่อน และใช้ `rollback_path` ที่ได้จากขั้น Restore:

```bash
sudo systemctl stop dormitory.service
cd /opt/dormitory
sudo env DORMINET_MAINTENANCE_MODE=true ./server_debian rollback-server-restore \
  --rollback ./restore_rollbacks/restore_rollback_TIMESTAMP \
  --master ./dormitory.db \
  --tenants ./dorm_data \
  --uploads ./uploads \
  --failed-restores ./restore_rollbacks
sudo systemctl start dormitory.service
curl --fail --silent --show-error https://dorminet.studio/api/system/ping
```

คำสั่ง rollback จะตรวจฐานข้อมูลใน rollback set ก่อนสลับ และเก็บชุดที่ล้มเหลวไว้ใน path ที่คืนเป็น `failed_restore_path` เพื่อวิเคราะห์ภายหลัง

## สิ่งที่ยังต้องพิสูจน์บน production

- production deploy binary ที่มีคำสั่ง restore/rollback แล้ว และ `--verify-only` ผ่าน archive จริงโดยไม่แตะ live data
- ทำ drill ด้วยสำเนา production ใน maintenance environment
- ทำ production maintenance-window drill ที่มีผู้รับผิดชอบ, health checklist และเวลาการกู้คืนที่บันทึกไว้
- ยืนยัน retention และสิทธิ์ filesystem ของ `restore_rollbacks`

จนกว่ารายการข้างต้นจะผ่าน หัวข้อ atomic restore ให้ถือว่า “โค้ดและ automated tests พร้อม แต่ production drill ยังไม่ปิด”
