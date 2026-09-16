# สถานะปัจจุบันของ DormiNetX

วันที่อัปเดต: 16 กันยายน 2569

เอกสารนี้เป็นสรุปสถานะล่าสุดสำหรับใช้ตัดสินใจ เอกสารวันที่ 9–15 กันยายนยังเก็บไว้เป็นประวัติการพัฒนา แต่คะแนนและรายการงานปัจจุบันให้ยึดเอกสารนี้และ [PRODUCTION_HARDENING_2026-09-10.md](PRODUCTION_HARDENING_2026-09-10.md) เป็นหลัก

## สรุปความพร้อม

| ขอบเขต | ความพร้อม | คำตัดสิน |
| --- | ---: | --- |
| ความครบของฟีเจอร์ | 90% | งานหลักของห้อง ลูกบ้าน การเงิน งานซ่อม และ LINE มีแล้ว |
| Controlled pilot | 88% | ใช้กับหอจำกัดได้เมื่อมี backup และผู้ดูแลติดตามปัญหา |
| Production readiness | **78%** | ยังมี release blockers ด้าน secret, multi-device, media, ledger และ restore |

คะแนนเป็น risk-weighted readiness ไม่ใช่ test coverage หรือ SLA ผล build/test ผ่านไม่ได้ทำให้ release blocker หายไปโดยอัตโนมัติ

## สิ่งที่ทำเสร็จแล้ว

### แอป iOS และข้อมูลในเครื่อง

- แยก SwiftData store ตาม account ID และตรวจ account/session ก่อนเปิด store
- เก็บ JWT, local passcode และ saved sessions ใน Keychain พร้อม migration และ lockout
- มี flow ห้อง ราคา ลูกบ้าน จอง เข้าพัก ย้ายห้อง ย้ายออก และงานซ่อม
- บิลรอบเดือนใช้ Gregorian storage key และแสดงปี พ.ศ. โดยไม่แปลงซ้ำ
- รองรับรับชำระบางส่วน/เต็มจำนวน สตางค์ มัดจำ รายการเดิมที่ยังไม่แยก และป้องกันลดยอดที่รับแล้ว
- เริ่ม append-only `PaymentTransaction` และ `FinancialReceipt` พร้อม referential-integrity checks
- บิลค้างตาม stable user ID เมื่อย้ายห้อง ส่วนบิลที่ชำระแล้วเก็บห้องเดิมเป็นประวัติ
- มี local backup/import ที่ตรวจ account, format, UUID ซ้ำ และ ledger integrity ก่อนแทนที่ข้อมูล
- หน้าจัดการงานซ่อมแสดงห้องแบบคงที่ มีปุ่มสถานะขนาดเท่ากัน ตัวเลือกช่องทางชำระ และเปิดรูปหลักฐานเต็มจอ/ซูมได้

### Sync และความปลอดภัยของข้อมูล

- แยก snapshot/checkpoint/outbox ตามบัญชี
- มี protocol 2, version, checksum, device ID และ atomic `base_version` conflict check
- exact-payload retry รองรับกรณี server บันทึกแล้วแต่อุปกรณ์ไม่ได้รับคำตอบ
- ไม่ mark clean ให้รายการที่ถูกแก้ระหว่าง upload และไม่ apply ผลของบัญชีเก่าหลังสลับบัญชี
- manual sync ซ่อม local data ที่ขาดแม้ version เท่ากันได้
- manual sync รวม local dirty/deleted records เข้ากับ remote snapshot แล้ว push บน remote base version ได้
- เมื่อ LINE รับสลิปหรือแจ้งซ่อม backend รวมการเปลี่ยนแปลงกลับเข้า immutable snapshot ทันที
- มี tenant-scoped authenticated media hydration สำหรับสลิป รูปแจ้งซ่อม รูปจอง และหลักฐานสภาพห้อง พร้อมตรวจ SHA-256 และ retry สูงสุด 3 ครั้งก่อนบันทึกลงเครื่อง

### Backend และความปลอดภัย

- session อยู่ฝั่ง server และถูก revoke เมื่อเปลี่ยน/รีเซ็ตรหัสผ่าน
- ตรวจ HS256, nonce, expiry, role และ account scope ฝั่ง server
- มี login/OTP/LIFF rate limits และ OTP lockout ที่คงอยู่หลัง restart
- แยก admin, superadmin และ system operator พร้อม regression tests สำหรับ cross-account และ staff scope
- ถอน `.env` ออกจาก Git index และบังคับ backend หยุดเมื่อ JWT secret หายหรือสั้นเกินไป
- server backup รวม master/tenant database, uploads, manifest, checksum และ scheduler
- offline restore drill ผ่านการตรวจ archive/hash/size และ SQLite `PRAGMA quick_check`
- online restore รุ่นที่ไม่ปลอดภัยถูกปิดแบบ fail closed ด้วย HTTP 501
- ปิด static `/uploads` แบบสาธารณะแล้ว; LINE ใช้ HMAC signed URL อายุ 24 ชั่วโมง ส่วนแอปใช้ `/api/media` ที่ตรวจ session, account และการอ้างอิงไฟล์ใน tenant database

### LINE, LIFF และลูกบ้าน

- production webhook ใช้ `https://api.dorminet.studio/api/webhook/line`
- LIFF ใช้ `https://api.dorminet.studio/liff` และตรวจ LINE client ID/access token
- ผูกบัญชีแบบกรอกเบอร์ก่อน ไม่เปิดรายการห้องทั้งหมด และ fail closed เมื่อเบอร์ตรงหลายห้อง
- บัญชีที่ผูกแล้วเห็นหน้า “ข้อมูลของฉัน” แทนฟอร์มผูกซ้ำ
- ข้อมูลห้อง/สัญญา/บิลค้างอ่านจาก tenant database ปัจจุบัน จึงเปลี่ยนตามเมื่อแอดมินย้ายห้องและซิงก์
- ใบแจ้งหนี้ของบอทแสดงเลขบิล รอบบิล ครบกำหนด วัน–เวลาอัปเดต รายการค่าใช้จ่าย ยอดชำระและคงเหลือ
- rich menu เชื่อมไปยังผูกบัญชี การเงิน และแจ้งซ่อม
- เมื่อแอดมินเปลี่ยนสถานะงานซ่อมจากแอป backend จะ push สถานะไป LINE หลัง transaction commit และไม่ส่งซ้ำสำหรับ snapshot เดิม

### หลักฐานการทดสอบและ deploy

- iOS unit tests ล่าสุดผ่าน **44/44**
- backend `go test -count=1 -race ./...` และ `go vet ./...` ผ่าน
- Debug device build/sign/install บน iPhone “F” ผ่าน และมี UAT จริงบาง flow
- production binary ก่อนรอบ restore/media hardening คือ SHA-256 `a7d882c536839ba86c78382499d8a074341211580168539e90445ec7f3ea5e51` และถูกเก็บไว้ใน rollback set
- production health ที่ `https://api.dorminet.studio/api/system/ping` ตอบ HTTP 200
- production deploy binary ที่มี maintenance-mode restore/rollback แล้ว SHA-256 `2f069031e35d1a57eb5cefa8760849f651c5c6c57eaccc79f683f9b7660e5d6b`; archive ล่าสุดผ่าน `--verify-only` โดยพบ 2 databases และ 2 media files
- production deploy private-media/checksum binary SHA-256 `75e357083809fce83d28a13c0b4332329a5cecc6318feaa0dd14e8a3a5ff68cd`; health ทั้ง loopback/โดเมนตอบ 200, known public upload ตอบ 404, tenant media ที่ไม่มี session ตอบ 401 และ unsigned LINE media ตอบ 404
- ปิด `ALLOW_LEGACY_SYNC_PUSH=false` บน production แล้ว หลังไม่พบ legacy push ใน journal ตั้งแต่ 15 กันยายนและ snapshot จากอุปกรณ์ปัจจุบันเดินต่อถึง v76; ยังต้องกด manual sync จาก iPhone หลัง cutover เพื่อบันทึกหลักฐานปลายทาง
- มี rollback set ก่อน deployment สำคัญและตรวจ SQLite master/tenant เป็น `ok`
- CI workflow ถูก commit/push แล้ว แต่การประเมินรอบนี้ไม่สามารถอ่านผล GitHub Actions ของ private repository ได้ จึงไม่อ้างว่า online CI ผ่าน

## สิ่งที่ทำแล้วบางส่วน

| หัวข้อ | ส่วนที่มีแล้ว | ส่วนที่ยังขาด |
| --- | --- | --- |
| Financial ledger | append-only transaction/receipt, migration จากยอดเก่า, delete guard | Invoice migration เต็มรูปแบบ, refund, void, credit adjustment และ actor/reason audit |
| Media | tenant-scoped hydration สำหรับสื่อธุรกิจ, SHA-256 verification, bounded retry, signed LINE URL และปิด public `/uploads` | orphan cleanup/retention policy และ UAT ดาวน์โหลดจริงข้ามสองเครื่อง; พื้นหลัง/วิดีโอเป็น client-local ตามสถาปัตยกรรมและรวมใน local backup |
| Sync conflict | atomic version check, exact retry, backup-before-replace, self-healing, dirty rebase | UAT ชนกันจริงสองเครื่อง และ record-level merge/policy |
| LINE delivery | core linking/invoice/payment/maintenance ทำงาน | delivery log/retry/idempotency ครบทุก message, opt-out และ monitoring |
| Restore | archive/manifest/checksum/offline drill, คำสั่ง maintenance-mode atomic swap/rollback, automated tests, production deploy และ verify-only ผ่าน | ทำ production maintenance-window restore/rollback drill พร้อม health checklist |
| Device UAT | ทดสอบบาง flow บน iPhone จริงหนึ่งเครื่อง | สองเครื่อง/สองบัญชี, offline/interruption, Photos/AirPrint, disk-full และ performance soak |

## งานที่ยังเหลือ

### P0 — ต้องปิดก่อน production เต็มรูปแบบ

1. หมุน/revoke JWT, LINE, Resend/email และ secret อื่นที่เคยอยู่ใน Git history พร้อม session cutover และบันทึกหลักฐานจาก provider
2. ทำ UAT สอง iPhone/สองบัญชี: เพิ่ม/แก้ record เดียวกันและคนละ record, ตัดเน็ตกลาง push/pull, force quit และกู้จาก backup
3. ยืนยัน manual sync จาก iPhone หลัง production ปิด `ALLOW_LEGACY_SYNC_PUSH` และเฝ้าดู rejection/log; ฝั่ง server cutover เป็น `false` แล้ว
4. ทำ media lifecycle ส่วนสุดท้าย: orphan cleanup/retention และ UAT ข้ามสองเครื่อง; ownership, checksum, retry และ public `/uploads` closure deploy แล้ว
5. ทำ Invoice/refund/void/credit-adjustment workflow และ immutable actor/reason audit พร้อม migration จาก `Payment` compatibility model
6. ทำ production drill ของ atomic restore ใน maintenance mode ตาม [SERVER_RESTORE_RUNBOOK_2026-09-16.md](SERVER_RESTORE_RUNBOOK_2026-09-16.md); ตัวคำสั่ง deploy แล้วและ verify-only ผ่าน archive จริง แต่ยังต้องมีหลักฐาน restore, health checklist และ rollback จาก maintenance window

### P1 — ต้องปิดก่อน rollout วงกว้าง

1. เพิ่ม UI automation สำหรับ login, tenant lifecycle, billing, partial/full payment, receipt, room move, maintenance และ backup
2. ทดสอบอีเมล forgot-password จริงบน staging และ concurrency หลาย instance
3. เพิ่ม SwiftData schema migration/recovery UI เมื่อ store เปิดไม่ได้ หรือพื้นที่ไม่พอ
4. ทำ error/offline/sync state ให้สม่ำเสมอทุกหน้า และไม่มี silent failure
5. เพิ่ม structured monitoring/alert, backup retention, incident runbook, privacy/retention policy และ release rollback checklist
6. ยืนยัน deployment target `iOS 26.2` กับอุปกรณ์เป้าหมายจริง หรือลด target พร้อม compatibility testing

### P2 — หลัง pilot

- APNs และ local notification พร้อม permission onboarding
- localization จริงด้วย String Catalog
- VoiceOver, Dynamic Type, contrast, touch target, iPad/landscape และ accessibility audit
- performance/memory/thermal soak สำหรับรูปใหญ่ วิดีโอ ใบเสร็จ และ snapshot ขนาดใหญ่
- TestFlight pilot อย่างน้อยหนึ่งรอบบิลเต็ม

## ลำดับที่ควรทำต่อ

1. Secret rotation/session cutover
2. UAT สองเครื่องและ protocol-2 cutover
3. Media lifecycle/UAT ส่วนที่เหลือ หลัง ownership/checksum/retry และ public-upload closure deploy แล้ว
4. Financial refund/void/full invoice migration
5. Atomic restore drill
6. UI automation, monitoring และ release hardening
7. APNs, localization, accessibility และ TestFlight pilot

## เกณฑ์ที่จะขยับคะแนน

- ขยับเกิน 85% เมื่อ secret rotation, UAT สองเครื่อง, protocol-2 cutover และ public-media closure มีหลักฐานครบ
- ขยับเกิน 90% เมื่อ media ทุก flow, refund/void ledger และ atomic restore ผ่าน
- 100% เมื่อไม่มี P0/P1 ค้าง, CI/Release/UI tests ผ่าน, TestFlight pilot ครบหนึ่งรอบบิล, ไม่เกิด data-loss incident และ restore drill ผ่าน
