# บันทึก Production Hardening และการย้าย LINE

วันที่: 10 กันยายน 2569

ขอบเขต: ตรวจระบบจริงที่ `202.29.232.28`, ทดสอบ staging จากสำเนาฐานข้อมูล production, deploy backend ที่ `api.dorminet.studio` และย้าย LINE webhook จากโดเมนเดิม โดยไม่ย้อนหรือลบการแก้ไขใน working tree

## ผลที่ใช้งานจริงแล้ว

- เปลี่ยน LINE Messaging API webhook จาก `https://dorminet.me/api/webhook/line` เป็น `https://api.dorminet.studio/api/webhook/line`
- LINE รายงาน endpoint ใหม่เป็น active และ webhook test สำเร็จด้วย HTTP 200
- วันที่ 15 กันยายน 2569 ย้าย LIFF endpoint จาก `https://dorminet.me/liff` เป็น `https://api.dorminet.studio/liff` สำเร็จ LIFF URL ของ LINE redirect มาที่โดเมนใหม่แล้ว และหน้าใหม่ถูกฝังใน backend binary เพื่อไม่ให้ deployment ขาดไฟล์ static
- ปรับหน้า LIFF ให้ใช้ธีมเดียวกับแอป DormiNetX: indigo/purple glass UI, icon อาคาร, responsive layout, Light/Dark Mode และแยกสีเขียวไว้เป็นสถานะ LINE
- วันที่ 15 กันยายน 2569 ปรับขั้นตอน LIFF ให้กรอกเบอร์โทรก่อน แล้ว backend ค้นหาและแสดงเฉพาะห้องที่ผูกกับเบอร์นั้น ไม่ส่งรายการห้องทั้งหมดให้ browser; ถ้าเบอร์ตรงกับลูกบ้านที่ใช้งานอยู่มากกว่าหนึ่งห้องจะปฏิเสธแบบ fail closed และขั้นตอนบันทึกยังตรวจเบอร์กับห้องซ้ำอีกครั้ง
- ปรับ LIFF รอบ UI ให้กลับเป็น minimal single-card layout ตัด stepper/ambient layers/การ์ดซ้อนออก คงสี indigo ของ DormiNetX และสีเขียวเฉพาะ LINE; หน้ากรอกกับหน้ายืนยันสูงเท่ากัน 304px ที่ viewport 390px และ input ใช้ 16px พร้อม blur ก่อนค้นหาเพื่อป้องกัน iOS auto-zoom
- หลังตรวจ source ของระบบเดิมที่ `/home/fang/dorm_project/frontend/src/pages/LiffLinkAccount.jsx` ปรับหน้าปัจจุบันกลับมาใช้ visual language แบบเดิม ได้แก่รูปโปรไฟล์ LINE, หัวข้อ Resident Access, พื้น slate, การ์ดขาวและปุ่มสีเข้ม แต่คง phone-first API และไม่เปิด room dropdown แบบ implementation เดิม
- ปรับตาม UAT เพิ่มเติมโดยขยายรูปโปรไฟล์เป็น 108px, เปลี่ยนหัวข้อเป็น `ยืนยันบัญชีลูกบ้าน`, เอาพื้น/ขอบ/เงาการ์ดขาวออก และใช้ flex layout วางชุดกรอก/ยืนยันไว้ด้านล่างเหนือ safe area โดยไม่ใช้ fixed positioning ที่อาจถูกคีย์บอร์ดบัง
- เติมพื้นที่กลางด้วยรายการประโยชน์หลังเชื่อมบัญชีแบบไม่มีการ์ด 3 รายการ ได้แก่ดูใบแจ้งหนี้, แจ้งชำระ และติดตามงานซ่อม เพื่อสื่อความสามารถของระบบโดยไม่รบกวนลำดับการกรอกข้อมูล
- หลังทบทวนหน้าที่ Rich Menu เปลี่ยนรายการประโยชน์ซึ่งอาจถูกเข้าใจว่าเป็นปุ่ม มาเป็น progress 3 ขั้น `กรอกเบอร์ → ตรวจสอบห้อง → เชื่อมบัญชี`; เมื่อค้นหาสำเร็จขั้น 1–2 เปลี่ยนเป็น complete และขั้น 3 เป็น active โดยไม่เปลี่ยนการทำงานของ Rich Menu
- เพิ่ม motion system สำหรับ LIFF: staggered page entrance, animated progress line/circle, form-to-confirmation cross-fade และ success-card scale โดยใช้ easing เดียวกันทั้งหน้า; การเปลี่ยนจากขั้น 1 ถึงผลยืนยันใช้เวลาประมาณ 0.7 วินาที และเคารพ `prefers-reduced-motion`
- แก้ microcopy ของขั้น 3 และปุ่ม action เป็น `เชื่อมต่อบัญชี` เพื่อไม่สื่อว่าเสร็จก่อน API บันทึกสำเร็จ; ข้อความสำเร็จจะแสดงหลัง `/api/liff/link` ตอบสำเร็จเท่านั้น
- เพิ่ม `/api/liff/status` ให้ LIFF ตรวจ access token กับ LINE และยืนยันสถานะจากทั้ง master link กับ tenant ปัจจุบันก่อนแสดงฟอร์ม; บัญชีที่ผูกอยู่แล้วจะเห็นสถานะ `เชื่อมต่อแล้ว` พร้อมเลขห้องและปุ่มกลับแชทแทนการผูกซ้ำ ส่วนข้อมูลผู้เช่าที่ย้ายออกหรือ link ค้างจะไม่ถูกนับว่าเชื่อมต่อ
- ขยายสถานะบัญชีที่ผูกแล้วเป็นหน้า `ข้อมูลของฉัน` แสดงชื่อ ห้อง/ประเภทห้อง สถานะการพัก วันที่เริ่ม/สิ้นสุดสัญญา ยอดคงเหลือ และบิลล่าสุดจาก materialized tenant database; การเงินค้นด้วย stable user ID ไม่ใช่เลขห้อง จึงไม่ปนกับผู้เช่าคนก่อน และไม่ส่งเลขบัตรประชาชน เบอร์โทร หรือที่อยู่ไปยัง LIFF
- ลด visual noise ของหน้า `ข้อมูลของฉัน` หลัง UAT: ตัด gradient, glow, icon tiles และ status badges ออก เหลือพื้นเรียบ ลำดับตัวอักษรสองส่วน เส้นคั่น และปุ่มกลับแชทเพียงปุ่มเดียว โดยคงข้อมูลและ authorization เดิมทั้งหมด
- ออกแบบข้อมูลการเงินในหน้า `ข้อมูลของฉัน` ใหม่ให้แสดงใบแจ้งหนี้ค้างทุกใบ เรียงล่าสุดก่อน แต่ละใบเปิดดูเลขที่บิล รอบบิล วันครบกำหนด วัน–เวลาอัปเดต สถานะ ค่าเช่า/น้ำ/ไฟ/ส่วนกลาง/ค่าปรับ/ค่าใช้จ่ายเพิ่มเติม ยอดบิล ยอดชำระ และยอดคงเหลือได้ โดยเปิดใบล่าสุดไว้และพับใบเก่าเพื่อลดความรก
- แก้การแสดงปี พ.ศ. ซ้ำจาก `2569` เป็น `3112` ด้วยการ normalize ปีที่จัดเก็บก่อนส่งให้ Thai date formatter และเพิ่มข้อความเตือนแบบเรียบเมื่อพบมากกว่าหนึ่งบิลในรอบเดียวกัน; production พบ `INV-00010` (`2569-09`) กับ `INV-00007` (`2026-09`) ซึ่งคือกันยายน 2569 เหมือนกัน จึงยังแสดงทั้งสองรายการตามข้อมูลจริงและไม่ได้ลบหรือแก้ข้อมูลการเงินเดิม
- แก้ DateFormatter ของหน้าการเงินและ dashboard ในแอป iOS ให้สร้าง month key ด้วย `en_US_POSIX` + Gregorian + Asia/Bangkok เสมอ ป้องกันข้อมูลใหม่ใช้ปี พ.ศ. เป็น storage key และชนกับรอบเดือนแบบ ค.ศ.
- ปรับ Flex Message ใบแจ้งหนี้ของบอทให้ใช้แม่แบบเดียวกันทั้งคำสั่ง `การเงิน`, การส่งจากแอดมิน และการ push อัตโนมัติ: ใช้เลขบิล `INV-%05d` ตรงกับหน้า LIFF, แสดงรอบบิล/วันครบกำหนด/วัน–เวลาอัปเดต/สถานะ/รายการค่าใช้จ่าย/ยอดบิล/ยอดชำระ/ยอดคงเหลือครบ, รองรับทั้ง storage year แบบ ค.ศ. และ พ.ศ. โดยไม่เกิดปี 3112 และเปลี่ยนการค้นหาบิลจากเลขห้องเป็น stable user ID เพื่อไม่ปนกับผู้เช่าคนก่อน
- จัด layout Flex Message รอบ UAT ให้กระชับและอ่านยอดเต็ม: ใช้ bubble ขนาด `mega`, นำยอดคงเหลือขึ้นเป็นข้อมูลหลัก, วางรอบบิลคู่กับสถานะ, ขยายสัดส่วนคอลัมน์ข้อมูล/ยอดเงินเพื่อไม่เกิด ellipsis และแยกข้อมูลบิล รายละเอียดค่าใช้จ่าย และยอดรวมด้วยเส้นคั่นแทนพื้นที่ว่างขนาดใหญ่
- วันที่ 16 กันยายน 2569 แก้เส้นทางข้อมูลจาก LINE เข้าสู่แอป: เมื่อบอทรอรับสลิปหรือรายการแจ้งซ่อม ระบบจะรวมการเปลี่ยนแปลงกลับเข้า immutable sync snapshot ของบัญชีแบบ optimistic versioning ทันที และก่อน startup materialization จะกู้การเปลี่ยนแปลงจาก LINE ที่ยังไม่เคย publish เพื่อไม่ให้ snapshot เก่าเขียนทับ
- เพิ่ม authenticated tenant-scoped media hydration สำหรับไฟล์ที่ฐานข้อมูลของบัญชีนั้นอ้างถึงเท่านั้น แอป build ใหม่ดาวน์โหลดสลิป/รูปแจ้งซ่อมที่ขาดมาเก็บใน local `PaymentSlips`; path traversal และไฟล์ของบัญชีอื่นถูกปฏิเสธ โดยยังคงใช้ server เป็นตัวกลางและไม่ฝัง binary media ลงใน snapshot
- production สร้าง snapshot `v66` จาก `line-bot` สำเร็จ ครอบคลุมสลิปสถานะ `checking` และรายการแจ้งซ่อมที่ทดสอบก่อนแก้ พร้อมกำหนด UUID ให้รายการแจ้งซ่อมเพื่อให้ sync ต่อเนื่องโดยไม่สร้างข้อมูลซ้ำ
- หลัง UAT พบว่า checkpoint ใน iPhone อาจเท่ากับ remote version ทั้งที่ local store ขาดบางรายการ จึงเพิ่ม manual-sync self-healing ให้เทียบ content signature และ apply snapshot ซ้ำเมื่อเนื้อหาไม่ตรง พร้อมแก้ overlay ไม่ให้แสดง “ซิงค์สำเร็จ” ตามเวลาเมื่อการทำงานจริงล้มเหลว; republish production เป็น `v67` เพื่อให้อุปกรณ์ที่ติดตั้ง build เดิมดึงข้อมูลได้ทันที โดยไม่ได้เปลี่ยนรายละเอียดรายการแจ้งซ่อม
- UAT รอบถัดมาพบ local dirty records ทำให้ pull ถูกปฏิเสธตาม data-safety guard จึงเพิ่ม manual-sync rebase: รวมเฉพาะ local records ที่ dirty/deleted เข้ากับ remote snapshot ล่าสุด, push ด้วย remote base version แล้ว apply ผลรวมกลับเข้า SwiftData; stale pending flag ที่ไม่มี dirty record จะถูกล้างอย่างปลอดภัย แอป Debug รุ่นนี้ build/sign/install ทับบน iPhone “F” สำเร็จโดยคง app container เดิม
- deploy backend binary ใหม่เข้า `dormitory.service` ที่พอร์ต 4283 หลังทดสอบบน Linux/amd64; binary รอบสุดท้ายที่ตรวจหลัง restart มี SHA-256 `2e6486679666bfe10640ac2ac60f6ed349603481b9aa3728b3750d2880f15386`
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
- `/home/fang/line_migration_backups/20260915_1232_pre_minimal_ui` (server binary ก่อนปรับ LIFF เป็น minimal UI)
- `/home/fang/line_migration_backups/20260915_1243_pre_legacy_style` (server binary ก่อนนำ visual language ของหน้าเดิมกลับมา)
- `/home/fang/line_migration_backups/20260915_1250_pre_bottom_layout` (server binary ก่อนขยายรูปและย้ายฟอร์มลงล่าง)
- `/home/fang/line_migration_backups/20260915_1637_pre_benefits` (server binary ก่อนเติมรายการประโยชน์ในพื้นที่กลาง)
- `/home/fang/line_migration_backups/20260915_1648_pre_steps` (server binary ก่อนเปลี่ยนพื้นที่กลางเป็น progress 3 ขั้น)
- `/home/fang/line_migration_backups/20260915_1659_pre_motion` (server binary ก่อนเพิ่ม motion system)
- `/home/fang/line_migration_backups/20260915_1703_pre_microcopy` (server binary ก่อนแก้ข้อความ action เป็น `เชื่อมต่อบัญชี`)
- `/home/fang/line_migration_backups/20260915_1715_pre_link_status` (server binary ก่อนเพิ่มการตรวจบัญชีที่เชื่อมต่ออยู่แล้ว)
- `/home/fang/line_migration_backups/20260915_1728_pre_resident_dashboard` (server binary ก่อนเพิ่มหน้า `ข้อมูลของฉัน`)
- `/home/fang/line_migration_backups/20260915_2156_pre_dashboard_minimal` (server binary ก่อนลด visual noise ของหน้า `ข้อมูลของฉัน`)
- `/home/fang/line_migration_backups/20260915_2214_pre_invoice_detail` (server binary, master/tenant database และ environment ก่อนเพิ่มรายละเอียดใบแจ้งหนี้)
- `/home/fang/line_migration_backups/20260915_2217_pre_invoice_duplicate_warning` (server binary ก่อนเพิ่มข้อความเตือนบิลซ้ำรอบเดียวกัน)
- `/home/fang/line_migration_backups/20260915_2222_pre_snapshot_date_normalization` (server binary และฐานข้อมูลก่อนทดสอบ normalize storage key ฝั่ง server; ยกเลิก binary ทดลองและกลับมาใช้ SHA รอบก่อนหลังพบว่าข้อมูลซ้ำเดิมชน unique constraint โดย transaction ไม่ได้เปลี่ยนฐานข้อมูล)
- `/home/fang/line_migration_backups/20260915_2245_pre_line_invoice_redesign` (server binary ก่อนปรับ Flex Message ใบแจ้งหนี้ของบอท)
- `/home/fang/line_migration_backups/20260915_225228_pre_line_invoice_layout` (server binary ก่อนจัด layout Flex Message ให้กระชับและไม่ตัดข้อความ/ยอดเงิน)
- `/home/fang/line_migration_backups/20260915_195350_pre_line_snapshot_sync` (rollback จาก deployment validation รอบแรก; binary/master/tenant database)
- `/home/fang/line_migration_backups/20260915_195516_pre_line_snapshot_sync` (SQLite-native master/tenant backup และ binary ก่อน deploy LINE-to-app snapshot sync รอบสำเร็จ)
- `/home/fang/line_migration_backups/20260915_200616_pre_line_republish` (SQLite-native master/tenant backup ก่อน republish snapshot v67 สำหรับ device UAT)

ชุดก่อนหน้าเก็บ master database, tenant database และ server binary เดิม; ชุด predeploy เก็บ environment เดิมด้วย ส่วนชุด `pre_phone_lookup` เก็บเฉพาะ binary เพราะ deployment นี้ไม่เปลี่ยน schema หรือข้อมูล ไฟล์ถูกจำกัดสิทธิ์ตามประเภท

backend ใหม่สร้าง `server_backup_*.zip` แบบ multi-tenant ซึ่งประกอบด้วย snapshot ของ master/tenant SQLite และ manifest ที่มี SHA-256/ขนาดไฟล์ การทดสอบบน production ผ่านขั้นตอนต่อไปนี้:

1. สร้าง archive จาก API ที่มี session
2. ตรวจโครงสร้าง ZIP ว่าไม่มีข้อผิดพลาด
3. ตรวจ hash และขนาดทุกไฟล์กับ manifest
4. แตกไปยัง staging directory
5. รัน `PRAGMA quick_check` กับฐานข้อมูลที่แตกออกมาทุกไฟล์ ผลเป็น `ok`

แก้ตัวกรองชื่อไฟล์ของ list/download/delete ให้รองรับทั้ง `server_backup_*.zip` รุ่นใหม่และ `backup_*.zip` รุ่นเดิม โดยยังปฏิเสธ path traversal และนามสกุลอื่น หลัง deploy API เห็น server backup ที่มีอยู่จริงหนึ่งไฟล์แล้ว

บังคับ directory ของ backup เป็น permission 0700 และ archive เป็น 0600 รวม legacy ZIP export ด้วย ส่วน online restore endpoint เดิมถูกปิดแบบ fail closed ด้วย HTTP 501 เพราะ implementation เดิมแทนที่ uploads ก่อนยืนยันว่า transaction ฐานข้อมูลสำเร็จและไม่รองรับ archive แบบ master+tenant การกู้คืนจริงต้องทำใน maintenance window จนกว่า atomic restore จะเสร็จ

ก่อนแก้รอบนี้ scheduler เดิมล้มเหลวทุกคืนเพราะค้นหาตาราง `users` ใน master database หลังระบบแยก tenant แล้ว โค้ดและ production binary ปัจจุบันเปลี่ยน scheduler มาใช้ server backup แบบ multi-tenant จึงไม่เรียก legacy JSON backup นั้นแล้ว ตรวจ journal หลังรอบอัตโนมัติจริงพบว่า job เวลา 22:00 สำเร็จต่อเนื่อง พร้อมสร้าง `server_backup_2026-09-14_05-00-00.zip` และ `server_backup_2026-09-15_05-00-00.zip`; archive ล่าสุดมี master/tenant database และ manifest ครบ ทดสอบ ZIP แล้วไม่พบข้อผิดพลาด

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
| Production automatic backup scheduler เวลา 22:00 | ผ่านต่อเนื่อง; archive ล่าสุด permission 0600 และ `unzip -t` ผ่านทุก entry |
| Production backup list เห็น `server_backup_*.zip` | ผ่าน, พบ 1 ไฟล์ |
| Backup directory/archive permission | 0700 / 0600 |
| Legacy unsafe online restore | ปิดแบบ fail closed, HTTP 501 และไม่แก้ uploads |
| LINE signed webhook + LINE webhook test | ผ่าน, HTTP 200 |
| LIFF rate limit บน production | ครั้งที่ 9 ถูกปฏิเสธ HTTP 429 |
| LIFF phone-first lookup: เบอร์ตรงหนึ่งห้อง, ไม่รับสถานะย้ายออก, ปฏิเสธเบอร์ซ้ำ | ผ่าน automated tests |
| LIFF UI: browser ส่งเฉพาะเบอร์และรับห้องจาก server โดยไม่มี room selector/room-list request | ผ่าน static assertions; viewport เดิม 390px ไม่มี horizontal overflow |
| LIFF minimal UI ก่อน/หลังค้นหาห้องที่ viewport 390×844 | ผ่าน; panel 304px เท่ากัน, horizontal overflow ไม่มี, visual viewport scale 1, input 16px |
| LIFF legacy-style UI ที่ดัดแปลงเป็น phone-first บน viewport 390×844 | ผ่าน; card 282px เท่ากันก่อน/หลัง, horizontal overflow ไม่มี, visual viewport scale 1, input 16px |
| LIFF bottom-aligned UI บน viewport 390×844 | ผ่าน; form/result สูง 228px เท่ากัน, avatar 108px, พื้นชุดฟอร์มโปร่งใส, scale 1 และไม่มี horizontal overflow |
| LIFF benefits layout บน viewport 390×844 | ผ่าน; เนื้อหากลางไม่ดันฟอร์มออกจาก safe area, หน้าไม่ scroll, card position/height คงเดิมก่อนและหลังค้นหาห้อง |
| LIFF onboarding progress บน viewport 390×844 | ผ่าน; ลำดับ active/complete ถูกต้อง, หน้าไม่ scroll, form/result position และความสูงคงเดิม |
| LIFF motion flow บน viewport 390×844 | ผ่าน; intermediate step 2 มองเห็นก่อน step 3, confirmation แสดงหลังประมาณ 708ms, scale 1 และ layout ไม่ขยับ |
| LIFF `ข้อมูลของฉัน` ที่ viewport 390×844 และ 320×700 | ผ่าน; ซ่อนฟอร์ม/ขั้นตอนเมื่อผูกแล้ว, ชื่อและประเภทห้องยาวตัดบรรทัดได้ และไม่มี horizontal overflow |
| LIFF `ข้อมูลของฉัน` แบบลด visual noise ที่ viewport 390×844 | ผ่าน; สูงพอดี viewport, ไม่ scroll, ไม่มี horizontal overflow และฟอร์มผูกบัญชียังคงถูกซ่อน |
| LIFF invoice detail ที่ viewport 390×844 | ผ่าน; แสดงบิลค้าง 2 ใบ, ใบล่าสุดเปิดอยู่, รายการค่าใช้จ่ายครบ, ปี `2569` ไม่ถูกแปลงเป็น `3112`, แสดงวัน–เวลา และไม่มี horizontal overflow |
| LINE invoice Flex Message | ผ่าน unit/race tests และ Messaging API `validate/push` ตอบ HTTP 200; ครอบคลุมปี ค.ศ./พ.ศ., รายการค่าใช้จ่าย, ยอดชำระ/คงเหลือ, การเลือกบิลด้วย stable user ID และ layout `mega` ที่เพิ่มพื้นที่ให้ข้อความ/ยอดเงิน |
| LINE → app snapshot publish | ผ่าน unit/race tests และ production reconciliation; snapshot เพิ่มจาก v65 เป็น v66, `device_id=line-bot`, มีสลิป `checking` และ maintenance 1 รายการโดย publish ซ้ำไม่เพิ่ม version |
| Tenant-scoped media API | ผ่าน unit/race tests; ต้องมี session, ไฟล์ต้องถูกอ้างถึงในฐานข้อมูล tenant และ unauthenticated production request ถูกปฏิเสธ HTTP 401 |
| iOS build หลังเพิ่ม remote media hydration/self-healing | ผ่าน Debug Simulator build; sync regression tests รวมกรณี version เท่ากันแต่ local ขาดข้อมูลผ่าน และ XCTest ผ่าน 42/43 โดย 1 test เป็น Keychain Simulator entitlement `-34018` ไม่เกี่ยวกับ sync/media |
| iOS pending-local + LINE remote rebase | CoreDataSafetyTests ผ่าน 18/18 รวม preservation ของ local dirty room และ remote maintenance; signed Debug device build/install บน iPhone 11 ผ่าน |
| iOS unit tests หลังบังคับ month key เป็น Gregorian | ผ่านทุก test ใน scheme `DormiNetX` |
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
- รูปสลิป/รูปแจ้งซ่อมจาก LINE มี ownership-aware hydration เข้าแอป build ใหม่แล้ว แต่ media ประเภทอื่นยังไม่มี transfer ข้ามอุปกรณ์ครบทุก flow และ URL `/uploads` ฝั่งเว็บเดิมยังเป็น public compatibility path
- ยังต้องทำ invoice/refund/void ledger เต็มรูปแบบ; ตอนนี้เพิ่ม transaction/receipt แบบ append-only และป้องกันลบบิลที่รับเงินแล้ว แต่ `Payment` ยังเป็น compatibility invoice
- APNs, localization เต็มระบบ และ maintenance SLA ไม่ใช่ core flow ที่ปิดในรอบนี้
- secret ที่เคยอยู่ใน Git history ต้องหมุนที่ผู้ให้บริการ LINE/Resend และเปลี่ยน JWT โดยวางแผน session cutover; การถอนจาก index ไม่ได้ลบ commit เก่า
- online restore ของ server archive ยังต้องทำเป็น workflow ที่ตรวจ manifest แล้วสลับฐานข้อมูลแบบ atomic; รอบนี้พิสูจน์ archive ด้วยการแตกไฟล์ ตรวจ hash/ขนาด และเปิดสำเนาด้วย `PRAGMA quick_check` โดยไม่เขียนทับ production

ดังนั้น backend production และ LINE domain migration พร้อมใช้งานในขอบเขตที่ทดสอบแล้ว แต่ยังไม่ควรเรียกระบบทั้งชุดว่า 100% จนกว่าจะผ่าน device UAT, media transfer, protocol-2 cutover และ provider secret rotation
