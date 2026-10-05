# แบบประเมิน DormiNetX — 5 ตุลาคม 2569

## คำตัดสิน

DormiNetX พัฒนาจากระบบที่มีฟีเจอร์จำนวนมากมาเป็นระบบธุรกิจที่มี security boundary, financial audit, sync recovery, media lifecycle และ operational tooling ค่อนข้างครบแล้ว

สถานะปัจจุบันเหมาะกับ **controlled pilot ระดับสูง** และมี engineering readiness ประมาณ 90% แต่ยังไม่ควรประกาศ production-ready 100% เพราะยังขาดหลักฐานภาคสนามบางส่วน โดยเฉพาะ maintenance E2E, production restore ที่เปลี่ยนข้อมูลจริง, UI automation target และ TestFlight เต็มรอบบิล

## คะแนนล่าสุด

| มิติ | คะแนน | หมายเหตุ |
| --- | ---: | --- |
| ความครบของฟีเจอร์ | **9.7/10 (97%)** | ครอบคลุมห้อง ลูกบ้าน การเงิน งานซ่อม LINE/LIFF OCR และ notification groundwork |
| สถาปัตยกรรม | **8.8/10** | local-first, multi-tenant, sync recovery, ledger และ backup มีโครงสร้างชัดเจน |
| ความปลอดภัยและข้อมูล | **8.5/10** | secret/SSH hardening, Keychain, authorization, fail-closed OCR และ immutable audit |
| UX และความสม่ำเสมอ | **9.0/10** | workflow งานซ่อม, search/filter, sync status และ recovery UI ดีขึ้นมาก |
| Controlled pilot | **9.2/10 (92%)** | P0 ระดับโค้ดและ automated verification ปิดแล้ว แต่ยังต้องมี field UAT ตาม flow |
| Engineering readiness | **ประมาณ 90%** | backend และโครงสร้าง release พร้อมในระดับ implementation |
| Release confidence | **8.6/10** | หักคะแนนจากหลักฐาน production UAT ที่ยังไม่ครบ |

คะแนนเป็น risk-weighted assessment ไม่ใช่ test coverage หรือ uptime SLA

## สิ่งที่ปิดได้แล้ว

### ความปลอดภัย

- นำ password ที่ฝังในสคริปต์ออก และเปลี่ยนเป็น passwordless SSH key
- หมุน/revoke provider secrets ตามหลักฐานใน tracking
- ใช้ Keychain สำหรับ JWT, passcode และ saved sessions
- มี session revocation, rate limit, OTP lockout และ account/tenant authorization
- ปิด public media access และใช้ authenticated media API หรือ signed URL
- OCR และ slip verification ใช้ fail-closed ไม่ auto-paid เมื่อการตรวจสอบไม่ครบ
- ลดสิทธิ์ OCR service และเพิ่ม health/rollback handling

### สถาปัตยกรรมและข้อมูล

- local-first SwiftData แยกตาม account
- protocol 2, version/checksum, exact retry, conflict isolation และ rebase
- media ownership, checksum, retry และ retention cleanup
- Financial Ledger รองรับ Void, Refund และ Adjust พร้อม immutable audit log
- SwiftData recovery และ disk-full recovery
- Sync Status UI แสดงสถานะ local, syncing, pending deletion และ failure
- APNs/local notification groundwork และ device-token endpoint เริ่มพร้อม

### คุณภาพการทดสอบ

- backend `go test ./...`, `go test -race ./handlers` และ `go vet ./...` ผ่านตาม activity report
- iOS regression/targeted tests ผ่านตามหลักฐานแต่ละรอบ
- มี UI automation skeleton และ accessibility/performance plans
- มี incident runbook, monitoring script และ retention/rollback guidance

## ความเสี่ยงที่ยังเหลือ

### 1. Maintenance E2E ยังรอตรวจจริง

ต้องทดสอบด้วยข้อมูลที่ได้รับอนุญาตครบวงจร:

- paid path: quote → approve/reject → repair → bill → slip → sync
- free path: repair → complete โดยไม่มี quote/bill
- stale action และ unauthorized action
- Flex message, outbox, retry และสถานะกลับเข้า iOS

### 2. Restore ยังไม่ใช่ production drill เต็มรูปแบบ

`--verify-only` พิสูจน์ archive/hash/database integrity แต่ยังไม่เท่ากับการสลับข้อมูลจริงใน maintenance window ต้องพิสูจน์ restore, health checklist และ rollback จากเหตุการณ์ล้มเหลว

### 3. UI automation ยังไม่ได้เข้าผูก target ใน Xcode

มีไฟล์และ accessibility identifiers แล้ว แต่ยังต้องเพิ่ม `DormiNetXUITests` target และรันซ้ำได้ใน CI ครอบคลุม login, billing, maintenance, backup และ error paths

### 4. TestFlight ยังไม่ผ่านหนึ่งรอบบิล

การ build/sign/install บนอุปกรณ์จริงเป็นหลักฐานระดับ device build ไม่ใช่หลักฐานว่า workflow ทางธุรกิจใช้งานต่อเนื่องครบหนึ่งรอบบิล

### 5. APNs ยังต้องพิสูจน์ปลายทาง

มี notification onboarding และ device-token endpoint แล้ว แต่ต้องยืนยัน schema/deploy production, token registration และการส่ง notification จริง

## ประเมินความซับซ้อน

| ระบบ | ระดับ |
| --- | ---: |
| ธุรกิจหอพัก | 8.5/10 |
| Data model และ history | 9/10 |
| iOS local-first app | 8.5/10 |
| Backend/auth/tenant | 8.5/10 |
| Multi-device sync | 9/10 |
| Financial ledger | 9/10 |
| Media/OCR | 8.5/10 |
| LINE/LIFF | 8/10 |
| Backup/restore | 8.5/10 |
| Operations/release | 8/10 |

ความซับซ้อนหลักอยู่ที่ความถูกต้องของข้อมูลและการประสานหลายระบบ ไม่ใช่จำนวนหน้าจอ

## คำแนะนำก่อนเปิด production เต็มรูปแบบ

1. ปิด maintenance paid/free E2E UAT
2. ทำ production restore/rollback drill แบบเปลี่ยนข้อมูลจริงใน maintenance window
3. เพิ่ม Xcode UI test target และรัน UI automation ใน CI
4. ยืนยัน APNs device-token registration หลัง deploy
5. ทำ TestFlight pilot ครบหนึ่งรอบบิล
6. รวมคะแนนและสถานะทั้งหมดให้ชี้มาที่เอกสารฉบับนี้เพียงแห่งเดียว

## สรุปสุดท้าย

ระบบนี้มี architecture และ security maturity สูงพอสำหรับ controlled pilot และใกล้ production มากแล้ว แต่คำว่า production-ready ควรสงวนไว้จนกว่าจะมีหลักฐานจาก E2E UAT, restore/rollback จริง, UI automation และ TestFlight ครบตามเกณฑ์
