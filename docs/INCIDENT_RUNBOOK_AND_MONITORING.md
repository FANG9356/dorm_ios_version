# Incident Runbook & Monitoring Guide

อัปเดตล่าสุด: 2026-10-05

เอกสารนี้ระบุขั้นตอนการทำงานเมื่อเกิดปัญหาบน Production (Incident Response) และรายละเอียดของระบบ Monitoring, Alert, รวมถึง Backup Retention และ Release Rollback Checklist

## 1. System Monitoring & Metrics

ระบบ DormiNetX ใช้การตรวจสอบ (Health Check) อย่างต่อเนื่อง:

### Health Endpoints
- **Core API Health:** `GET https://dorminet.studio/api/system/ping`
  - คาดหวัง: HTTP 200 `{"status": "online", "message": "DorminetX Backend is running"}`
- **System Logs:**
  - ดู logs ของ service: `journalctl -u dormitory.service -n 100 --no-pager`
  - ดู logs ของ OCR: `journalctl -u dormitory-ocr.service -n 100 --no-pager`

### Backup Retention Policy
ข้อมูลระบบและรูปภาพจะถูกสำรอง (Backup) และเก็บรักษาตามเงื่อนไขต่อไปนี้:
- **Daily Automated Backups:** เก็บรักษาย้อนหลัง 30 วัน
- **Pre-Deployment / Rollback Sets:** เก็บรักษาย้อนหลัง 10 ชุดล่าสุด ชุดเก่าจะถูกลบอัตโนมัติตามสคริปต์ Safe Deploy

## 2. Alerts & Incident Response

### ระดับความรุนแรงของปัญหา (Severity Levels)
1. **SEV-1 (Critical):** ระบบหลักล่ม (API ตอบ 5xx หรือไม่สามารถเข้าสู่ระบบ/ใช้งานได้)
2. **SEV-2 (High):** ฟีเจอร์หลักใช้งานไม่ได้ (เช่น จ่ายเงินไม่ได้, OCR ไม่ทำงาน)
3. **SEV-3 (Medium):** ฟีเจอร์รองมีปัญหา หรือมีผลกระทบกับผู้ใช้บางส่วน
4. **SEV-4 (Low):** บั๊กเล็กน้อย หรือปัญหาเกี่ยวกับ UI

### ขั้นตอนตอบสนองต่อปัญหา (Incident Runbook)

**กรณี SEV-1: ระบบหลักล่ม (System Down)**
1. **Verify:** ยืนยันสถานะระบบโดยรัน `curl --fail --silent --show-error https://dorminet.studio/api/system/ping`
2. **Investigate:** ตรวจสอบ error logs ด้วย `journalctl -u dormitory.service -n 50`
3. **Mitigate (Rollback):** หากล่มหลังจากมีการ Deploy ภายใน 1 ชั่วโมง ให้ใช้สคริปต์ `rollback` กลับไปยัง Backup set ล่าสุดทันทีตามหัวข้อ *Rollback Backend* ใน `DEVELOPMENT_OPERATIONS_RUNBOOK.md`
4. **Communicate:** แจ้งให้ผู้เกี่ยวข้อง (ลูกบ้าน) ทราบถึงสถานะการแก้ไข หากประเมินว่าจะใช้เวลาแก้ไขนานเกิน 15 นาที

**กรณี SEV-2: OCR หรือระบบโอนเงินมีปัญหา**
1. **Verify:** ตรวจสอบสถานะ OCR bot โดยใช้ `sudo systemctl status dormitory-ocr.service`
2. **Restart:** ลอง restart service `sudo systemctl restart dormitory-ocr.service` และดู log หาข้อผิดพลาด Python
3. **Investigate Data:** ดูข้อมูล SQLite ของ outbox ที่ล้มเหลว (ถ้าเกี่ยวข้องกับการส่ง LINE Message) และทำการ retry หากจำเป็นด้วยคำสั่ง `retry_line_outbox.exp`

## 3. Release Rollback Checklist

ใช้ Checklist นี้ทุกครั้ง **ก่อน** และ **หลัง** การ Deploy Production:

### 🟢 ก่อน Deploy (Pre-Release)
- [ ] สคริปต์ใช้งานคือ `deploy_flex_safe_remote.sh` (ห้าม Build/Upload manual)
- [ ] รัน Unit Tests, Race Detector และ Vet ผ่านหมด
- [ ] ระบบมีพื้นที่ (Disk Space) เพียงพอต่อการ Backup
- [ ] สคริปต์ได้สร้าง Rollback Set ครบถ้วน (เก็บ Master, Tenant DB และ Media) ก่อนเริ่มเขียนทับ

### 🟡 ระหว่าง Deploy
- [ ] รอให้เซิร์ฟเวอร์ Verify Health HTTP 200 หลัง Restart
- [ ] สคริปต์แจ้งเตือน `DEPLOY_SUCCESS` โดยไม่ error หรือ timeout

### 🔴 หากพบปัญหาหลัง Deploy (Rollback Procedure)
- [ ] ตัดสินใจ Rollback ทันทีหาก Health check ล้มเหลวต่อเนื่องเกิน 3 นาที
- [ ] เข้าไปยัง Server และรันสคริปต์ Rollback อัตโนมัติ: `sudo env DORMINET_MAINTENANCE_MODE=true ./server_debian rollback-server-restore --rollback ./restore_rollbacks/<target>`
- [ ] Verify ระบบว่ากลับมาปกติ (HTTP 200) หลัง Rollback สำเร็จ
- [ ] บันทึกสาเหตุของการล้มเหลว (Post-mortem) ลงใน `ACTIVITY_REPORT.md`

## 4. Privacy & Data Retention Policy

- **ข้อมูลส่วนบุคคล (PII):** ห้ามนำข้อมูลจริงของลูกบ้าน เช่น ชื่อ เบอร์โทร รหัสผ่าน มาใช้ทดสอบในสภาพแวดล้อม Development เด็ดขาด
- **Logs:** ระบบจะเก็บ Log เพียงพอสำหรับวิเคราะห์ (เช่น 14-30 วัน) ห้าม log ข้อมูล Sensitive
- **Database Backups:** ไฟล์ Backup ควรถูกลบออกจาก Server ชั่วคราว เมื่อไม่มีความจำเป็นต้องทำ Rollback ในรอบการ Deploy นั้นๆ (ขึ้นอยู่กับนโยบาย 10 ชุดล่าสุด)
