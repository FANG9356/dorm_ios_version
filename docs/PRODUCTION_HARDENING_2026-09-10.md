# บันทึก Production Hardening และการย้าย LINE

วันที่: 10 กันยายน 2569

ขอบเขต: ตรวจระบบจริงที่ `202.29.232.28`, ทดสอบ staging จากสำเนาฐานข้อมูล production, deploy backend ที่ `api.dorminet.studio` และย้าย LINE webhook จากโดเมนเดิม โดยไม่ย้อนหรือลบการแก้ไขใน working tree

## ผลที่ใช้งานจริงแล้ว

- เปลี่ยน LINE Messaging API webhook จาก `https://dorminet.me/api/webhook/line` เป็น `https://api.dorminet.studio/api/webhook/line`
- LINE รายงาน endpoint ใหม่เป็น active และ webhook test สำเร็จด้วย HTTP 200
- วันที่ 15 กันยายน 2569 ย้าย LIFF endpoint จาก `https://dorminet.me/liff` เป็น `https://api.dorminet.studio/liff` สำเร็จ LIFF URL ของ LINE redirect มาที่โดเมนใหม่แล้ว และหน้าใหม่ถูกฝังใน backend binary เพื่อไม่ให้ deployment ขาดไฟล์ static
- ปรับหน้า LIFF ให้ใช้ธีมเดียวกับแอป DormiNetX: indigo/purple glass UI, icon อาคาร, responsive layout, Light/Dark Mode และแยกสีเขียวไว้เป็นสถานะ LINE
- วันที่ 15 กันยายน 2569 ปรับขั้นตอน LIFF ให้กรอกเบอร์โทรก่อน แล้ว backend ค้นหาและแสดงเฉพาะห้องที่ผูกกับเบอร์นั้น ไม่ส่งรายการห้องทั้งหมดให้ browser; ถ้าเบอร์ตรงกับลูกบ้านที่ใช้งานอยู่มากกว่าหนึ่งห้องจะปฏิเสธแบบ fail closed และขั้นตอนบันทึกยังตรวจเบอร์กับห้องซ้ำอีกครั้ง
- deploy backend binary ใหม่เข้า `dormitory.service` ที่พอร์ต 4283 หลังทดสอบกับสำเนา master/tenant database บนพอร์ตแยก; binary รอบสุดท้ายที่ตรวจหลัง restart มี SHA-256 `2f26335be4df3ecad51687196c4a3924493bc86c751ee927f21403fc18c3fa6e`
- production health ผ่านทั้ง loopback และ `https://api.dorminet.studio/api/system/ping`
- session เดิมยังใช้ได้, token ผิดรูปแบบถูกปฏิเสธ 401, account scope ของรายชื่อผู้ดูแลและ sync metadata ตอบสำเร็จ
- LINE webhook ที่ลงลายเซ็นถูกต้องผ่านบน production
- LIFF ตรวจ `client_id` ของ access token ให้ตรงกับ channel ของโปรเจกต์และ token ต้องไม่หมดอายุ ไม่ยอมรับเพียงเพราะเป็น token ของ LINE channel อื่น
- จำกัดการลองจับคู่ห้อง/เบอร์โทรและการผูก LINE ที่ 8 ครั้งต่อ IP ใน 15 นาที โดยเชื่อ `CF-Connecting-IP` เฉพาะเมื่อ request มาจาก local/private reverse proxy
- จำกัด login ปกติและ login สำหรับ sync ทั้งตาม IP และบัญชี, จำกัด registration/QR login และบังคับรหัสผ่าน 8–72 ตัวอักษรที่มีทั้งตัวอักษรและตัวเลข
- ย้ายตัวนับ OTP request/OTP failure จาก process memory ไปตาราง `auth_rate_limits` ใน master SQLite ด้วย atomic upsert ทำให้ lockout ไม่หายเมื่อ restart และแชร์ข้าม process ที่ใช้ฐานข้อมูลเดียวกัน พร้อมจำกัด forgot-password ตาม IP เพิ่มเติม
- identity LINE เดิมมีหนึ่งรายการ แต่เป็นลูกบ้านข้อมูลเดิมห้อง 1 ซึ่งไม่ตรงกับลูกบ้านปัจจุบันห้อง 102/103 จึงย้ายเป็น `pending_relink` แทนการเดาว่าควรผูกกับใคร ผู้ใช้เดิมจะได้รับคำแนะนำให้ผูกบัญชีใหม่เมื่อส่งข้อความ
- เปิด compatibility flag `ALLOW_LEGACY_SYNC_PUSH=true` ชั่วคราว เพราะพบ snapshot จากอุปกรณ์เดิมเพียงเครื่องเดียวและยังยืนยันไม่ได้ว่าแอปบนเครื่องนั้นอัปเดต protocol 2 แล้ว ตัวเลือกนี้ป้องกัน rollout จากการตัด sync ของแอปรุ่นเดิม แต่ต้องปิดหลังอัปเดตทุกเครื่อง

## Backup และ rollback

ก่อน deploy มี rollback set สองชุดบนเซิร์ฟเวอร์:

- `/home/fang/line_migration_backups/20260910_013549_pre_hardening`
- `/home/fang/line_migration_backups/20260910_predeploy`
- `/home/fang/line_migration_backups/20260915_1130_pre_liff`
- `/home/fang/line_migration_backups/20260915_1210_pre_liff_ui`
- `/home/fang/line_migration_backups/20260915_1218_pre_phone_lookup` (server binary ก่อนเปลี่ยนเป็น phone-first flow)

ชุดก่อนหน้าเก็บ master database, tenant database และ server binary เดิม; ชุด predeploy เก็บ environment เดิมด้วย ส่วนชุด `pre_phone_lookup` เก็บเฉพาะ binary เพราะ deployment นี้ไม่เปลี่ยน schema หรือข้อมูล ไฟล์ถูกจำกัดสิทธิ์ตามประเภท

backend ใหม่สร้าง `server_backup_*.zip` แบบ multi-tenant ซึ่งประกอบด้วย snapshot ของ master/tenant SQLite และ manifest ที่มี SHA-256/ขนาดไฟล์ การทดสอบบน production ผ่านขั้นตอนต่อไปนี้:

1. สร้าง archive จาก API ที่มี session
2. ตรวจโครงสร้าง ZIP ว่าไม่มีข้อผิดพลาด
3. ตรวจ hash และขนาดทุกไฟล์กับ manifest
4. แตกไปยัง staging directory
5. รัน `PRAGMA quick_check` กับฐานข้อมูลที่แตกออกมาทุกไฟล์ ผลเป็น `ok`

แก้ตัวกรองชื่อไฟล์ของ list/download/delete ให้รองรับทั้ง `server_backup_*.zip` รุ่นใหม่และ `backup_*.zip` รุ่นเดิม โดยยังปฏิเสธ path traversal และนามสกุลอื่น หลัง deploy API เห็น server backup ที่มีอยู่จริงหนึ่งไฟล์แล้ว

บังคับ directory ของ backup เป็น permission 0700 และ archive เป็น 0600 รวม legacy ZIP export ด้วย ส่วน online restore endpoint เดิมถูกปิดแบบ fail closed ด้วย HTTP 501 เพราะ implementation เดิมแทนที่ uploads ก่อนยืนยันว่า transaction ฐานข้อมูลสำเร็จและไม่รองรับ archive แบบ master+tenant การกู้คืนจริงต้องทำใน maintenance window จนกว่า atomic restore จะเสร็จ

ก่อนแก้รอบนี้ scheduler เดิมล้มเหลวทุกคืนเพราะค้นหาตาราง `users` ใน master database หลังระบบแยก tenant แล้ว โค้ดและ production binary ปัจจุบันเปลี่ยน scheduler มาใช้ server backup แบบ multi-tenant จึงไม่เรียก legacy JSON backup นั้นแล้ว ต้องตรวจ job เวลา 22:00 อีกครั้งจาก journal หลังรอบอัตโนมัติถัดไป

## Security/session ที่แก้และ deploy แล้ว

- login ทุกเส้นทางออก token ผ่าน session store เดียวกัน รวม login ปกติ, sync auth, สมัครบัญชี และ QR login
- token มี nonce และตรวจ HS256 แบบเจาะจง; middleware ตรวจ session revocation และอ่าน role ปัจจุบันจากฐานข้อมูล ไม่เชื่อ role เก่าใน JWT
- ไม่รับ API bearer token จาก query string
- เปลี่ยน/รีเซ็ตรหัสผ่านแล้วลบ session เดิมทั้งหมดใน transaction เดียวกัน
- รายชื่อผู้ดูแลไม่มี fallback แสดงทุกบัญชีเมื่อหา account scope ไม่ได้
- create/update/delete/profile-image ของผู้ดูแลตรวจ owner account จากอีเมลหลักและ target ID ทุกครั้ง; ผู้ดูแลหอหนึ่งแก้บัญชีอีกหอไม่ได้
- เฉพาะ superadmin สร้าง/ลบ staff หรือเปลี่ยน role ได้, ไม่อนุญาตสร้าง superadmin ผ่าน staff endpoint และการเปลี่ยนรหัส/role เพิกถอน session ของเป้าหมาย
- แก้หน้าเพิ่มผู้ดูแล iOS ไม่ให้เรียก public registration ซึ่งเคยทำให้ได้ superadmin/tenant ใหม่ผิดบัญชี ปัจจุบันเรียก authenticated `/api/admins`, ส่ง recovery email กับรหัสชั่วคราวตามที่กรอก และ UI ไม่มีตัวเลือกสร้าง superadmin
- staff endpoint เลิกใช้รหัสเริ่มต้นที่คาดเดาได้และบังคับนโยบายรหัสผ่านเดียวกับระบบ ส่วน initial setup ใช้ atomic insert, rate limit และสร้าง owner เป็น superadmin เพียงบัญชีแรก
- การเปลี่ยนรหัสของตนเองผ่าน admin endpoint ต้องยืนยันรหัสเดิม แก้ชนิด context `admin_id` ที่เคยอ่านผิดจาก `int` เป็น `float64`
- profile upload อนุญาตเฉพาะตนเองหรือ owner ใน account เดียวกัน จำกัด 10 MB, ตรวจ magic MIME เป็น JPEG/PNG/WebP, สุ่มชื่อและเขียน permission 0600
- backend ไม่สร้างหรือเขียน JWT secret ใหม่เองเมื่อ config หาย; startup จะหยุดแบบ fail closed ถ้า secret สั้นกว่า 32 ตัวอักษร
- แยกสิทธิ์ system operator ออกจาก superadmin ของแต่ละหอ: backup/list/download/restore ระดับทั้งเซิร์ฟเวอร์ต้องเป็น superadmin ID ที่กำหนดใน `SYSTEM_OPERATOR_ADMIN_ID`; ส่วน reset ของหอใช้ได้เฉพาะ superadmin และฐานข้อมูล tenant ของบัญชีนั้น โดยไม่ fallback ไป master database และไม่ลบ uploads รวมของทั้งระบบ
- ถอน `backend-dorm/.env` ออกจาก Git index โดยคงไฟล์ local ไว้และตั้ง permission 0600; `.gitignore` ครอบไฟล์นี้อยู่แล้ว

## หลักฐานการทดสอบ

| รายการ | ผล |
| --- | --- |
| Backend `go test -count=1 -race ./...` | ผ่าน |
| Backend `go vet ./...` | ผ่าน |
| Staging build บน Linux/amd64 | ผ่าน |
| Staging migration บนสำเนา production DB | ผ่าน, SQLite quick check `ok` |
| Production health หลัง deploy | HTTP 200 |
| Production session/account/sync/system-operator endpoints | ผ่าน, HTTP 200 |
| Token ผิดรูปแบบ | ถูกปฏิเสธ HTTP 401 |
| Login rate limit บน production | ครั้งที่ 11 ของบัญชีทดสอบถูกปฏิเสธ HTTP 429 |
| OTP lockout persistence บน production | ครั้งที่ 5 ตอบ 429 และหลัง restart ยังตอบ 429; ลบ test row แล้ว |
| Production multi-tenant backup + restore drill | ผ่าน |
| Production backup list เห็น `server_backup_*.zip` | ผ่าน, พบ 1 ไฟล์ |
| Backup directory/archive permission | 0700 / 0600 |
| Legacy unsafe online restore | ปิดแบบ fail closed, HTTP 501 และไม่แก้ uploads |
| LINE signed webhook + LINE webhook test | ผ่าน, HTTP 200 |
| LIFF rate limit บน production | ครั้งที่ 9 ถูกปฏิเสธ HTTP 429 |
| LIFF phone-first lookup: เบอร์ตรงหนึ่งห้อง, ไม่รับสถานะย้ายออก, ปฏิเสธเบอร์ซ้ำ | ผ่าน automated tests |
| LIFF UI: browser ส่งเฉพาะเบอร์และรับห้องจาก server โดยไม่มี room selector/room-list request | ผ่าน static assertions; viewport เดิม 390px ไม่มี horizontal overflow |
| Production LIFF page/assets + LINE redirect หลังเปลี่ยน endpoint | ผ่าน, HTTP 200 และชี้ `api.dorminet.studio/liff` |
| Production room-list endpoint เดิม | ปิดการเปิดเผยรายการห้อง, HTTP 410 |
| Production phone lookup ด้วยเบอร์ที่ไม่มีในระบบ | ปฏิเสธ HTTP 401 โดยไม่เปิดเผยข้อมูลลูกบ้าน |
| Admin cross-account authorization regression tests | ผ่าน |
| System-operator authorization regression test | ผ่าน |
| Staff creation/account-scope regression test | ผ่าน; production request ที่ไม่มี password ตอบ 400 และจำนวนบัญชีไม่เปลี่ยน |
| iOS tests หลังแก้ staff flow/CI | ผ่าน 42/42 |
| iOS Release build + analyzer หลังแก้ staff flow | ผ่าน |
| CI workflow syntax และคำสั่ง local equivalent | ผ่าน; จะเริ่มทำงานบน GitHub หลัง commit/push |

## สิ่งที่ยังไม่ถือว่าผ่าน 100%

- ยังไม่ได้ UAT บน iPhone จริงสองเครื่อง, ทดสอบตัดเน็ตระหว่าง sync, Photos/AirPrint และ profile memory กับข้อมูลขนาดใหญ่
- ต้องปิด `ALLOW_LEGACY_SYNC_PUSH` หลังยืนยันว่าอุปกรณ์ใช้งานทุกเครื่องเป็น protocol 2
- รูปสลิป/สื่อยังไม่มี ownership-aware transfer ข้ามอุปกรณ์ และ URL `/uploads` ฝั่งเว็บเดิมยังเป็น public compatibility path
- ยังต้องทำ invoice/refund/void ledger เต็มรูปแบบ; ตอนนี้เพิ่ม transaction/receipt แบบ append-only และป้องกันลบบิลที่รับเงินแล้ว แต่ `Payment` ยังเป็น compatibility invoice
- APNs, localization เต็มระบบ และ maintenance SLA ไม่ใช่ core flow ที่ปิดในรอบนี้
- secret ที่เคยอยู่ใน Git history ต้องหมุนที่ผู้ให้บริการ LINE/Resend และเปลี่ยน JWT โดยวางแผน session cutover; การถอนจาก index ไม่ได้ลบ commit เก่า
- online restore ของ server archive ยังต้องทำเป็น workflow ที่ตรวจ manifest แล้วสลับฐานข้อมูลแบบ atomic; รอบนี้พิสูจน์ archive ด้วยการแตกไฟล์ ตรวจ hash/ขนาด และเปิดสำเนาด้วย `PRAGMA quick_check` โดยไม่เขียนทับ production

ดังนั้น backend production และ LINE domain migration พร้อมใช้งานในขอบเขตที่ทดสอบแล้ว แต่ยังไม่ควรเรียกระบบทั้งชุดว่า 100% จนกว่าจะผ่าน device UAT, media transfer, protocol-2 cutover และ provider secret rotation
