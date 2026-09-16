# DormiNetX: การประเมินด้านสถาปัตยกรรมและความปลอดภัย

วันที่ประเมิน: 15 กันยายน 2569

> **ภาคผนวกด้านความปลอดภัย 16 กันยายน 2569:** สถาปัตยกรรมปัจจุบันดีขึ้นจากการเพิ่ม tenant-scoped media API, LINE → immutable snapshot publication, same-version repair, dirty-record rebase และการส่ง maintenance status หลัง transaction commit เท่านั้น แต่ความเสี่ยงระดับ P0 ยังไม่ปิดทั้งหมด

### สรุปปัจจุบัน

- สถาปัตยกรรม: **8.6/10**
- ความปลอดภัย/ข้อมูล: **7.4/10**
- operational readiness: **8.2/10**
- production readiness รวม: **7.8/10**

สิ่งที่พิสูจน์แล้ว: account-scoped store/session, optimistic sync version/checksum, exact retry/outbox, backup manifest/checksum/offline restore drill, Keychain, rate limit/session revocation, admin/system-operator boundary, LINE signature/LIFF validation, tenant-scoped media hydration และ regression tests สำหรับ authorization หลัก

สิ่งที่ยังเป็น release blocker: rotate/revoke secrets ที่เคยอยู่ใน Git history, ปิด public `/uploads` compatibility path, พิสูจน์ media ข้ามอุปกรณ์ทุก flow, UAT สองเครื่อง/สองบัญชี, record-level conflict strategy, full financial refund/void audit และ atomic online restore

## 1. สรุปแบบสั้น

ระบบนี้มีคุณภาพด้านสถาปัตยกรรมและการออกแบบความปลอดภัยที่ดีกว่าระบบหอพักทั่วไปหลายระบบ เพราะมีความคิดเรื่อง:

- local-first operation
- account isolation
- sync versioning
- backup/restore discipline
- rate limit และ session hardening
- role boundary ระหว่าง admin/system operator

แต่ในเชิง production safety ยังมี “work remaining” ที่ไม่ควรมองข้าม เพราะเรื่องที่นำไปสู่ความเสียหายจริงมักไม่ใช่ UI แต่มาจาก:

- secret exposure
- data overwrite
- media loss
- financial integrity issue
- authorization regression
- sync conflict / stale snapshot

ดังนั้นระบบนี้คือ “โครงสร้างที่ดีและน่าพัฒนา” แต่ยังไม่ควรเรียกว่า production-safe อย่างสมบูรณ์

---

## 2. มุมมองเรื่องสถาปัตยกรรม

### 2.1 จุดแข็งของสถาปัตยกรรม

#### a) ใช้ local-first architecture เป็นแนวคิดที่เหมาะสม

สำหรับแอปที่จัดการหอพัก การทำงานแบบ offline-first มีความสำคัญมาก เพราะ:

- ผู้ดูแลอาจไม่มีอินเทอร์เน็ตตลอดเวลา
- การเปลี่ยนข้อมูลมีความต่อเนื่องและจำเป็นมาก
- การบันทึกข้อมูลตอน offline ต้องไม่เสียหาย

ระบบนี้ออกแบบให้ local data เป็นแหล่งข้อมูลหลักก่อน แล้ว sync ขึ้นไปบน server ทำให้มีแนวคิดที่ถูกต้องและเหมาะกับความเป็นจริงของการใช้งานหอพัก

#### b) Account-scoped storage ช่วยลดความเสี่ยงจากข้อมูลข้ามบัญชี

เอกสารชัดเจนว่ามีการแยก store ตาม admin/account ID และมีการตรวจ account/tenant scope สำคัญมาก เพราะปัญหาที่พบบ่อยที่สุดในระบบหลายบัญชีคือ:

- ข้อมูลคนละบัญชีติดกัน
- data leakage ระหว่าง tenant
- sync cross-account contamination

นี่คือข้อดีที่ชัดเจนของระบบนี้

#### c) Versioning/checksum/retry เป็นสัญญาณของระบบที่คำนึงถึง reliability

ระบบมีการใช้:

- version control
- checksum
- outbox/retry queue
- base_version checks
- conflict detection

ซึ่งเป็นสิ่งที่แสดงว่าทีมไม่ได้คิดแค่ “ส่งข้อมูลได้” แต่คำนึงถึง “ส่งข้อมูลถูกต้องและไม่ลบข้อมูลอันเดิม”

### 2.2 จุดอ่อนของสถาปัตยกรรม

#### a) Whole-snapshot sync ยังไม่ใช่รูปแบบที่ robust enough

ระบบใช้ snapshot ทั้งชุดสำหรับ sync ซึ่งมีข้อดีคือ implementation ตรงไปตรงมา แต่ความเสี่ยงอยู่ที่:

- overwrite ของเครื่องที่แก้ข้อมูลพร้อมกัน
- last-write-wins behavior
- update conflict ที่ต้องมี merge policy
- snapshot size ที่ใหญ่ขึ้นเมื่อระบบโต

จุดนี้เป็นหนึ่งในจุดเสี่ยงสูงสุดของระบบนี้ เพราะหากแก้เครื่องสองเครื่องพร้อมกัน รอยต่อ data loss จะเกิดชัดเจน

#### b) Financial model ยังมีความซับซ้อนเกินกว่าการเก็บใน schema เดียว

ระบบการเงินมีความซับซ้อนมาก ไม่ใช่แค่ “จำนวนเงิน + สถานะ” เพราะต้องคำนึงถึง:

- โครงสร้างบิล
- รายการชำระ
- วันที่
- สัญญา
- การผ่อน
- ย้ายห้อง
- เก็บประวัติ
- ส่วนต่างจากบิลเก่า

จุดอ่อนคือการเงินยังเป็น domain ที่ “ผสมหลายความหมายใน object เดียว” เช่น การเก็บ payment, invoice, deposit, history ในชั้นข้อมูลเดียว อาจทำให้ auditability และ correctness ลดลงเมื่อระบบโตขึ้น

#### c) Media handling ยังเป็น area ที่ยังไม่ fully solved

จากเอกสารชัดเจนว่า media sync ยังไม่สมบูรณ์:

- สื่ออยู่ในเครื่อง
- snapshot ส่งเฉพาะ path ไม่ใช่ binary
- transfer ระหว่างเครื่องยังผูกกับเหลื่อมล้ำของ ownership และ path

นี่เป็นจุดสำคัญมาก เพราะสำหรับระบบหอพัก สลิปใบเสร็จ รูปห้อง รูปงานซ่อม คือข้อมูลที่ “ขาดไม่ได้” และมีความอ่อนไหวทางธุรกิจสูง

---

## 3. มุมมองเรื่องความปลอดภัย

### 3.1 จุดแข็งด้านความปลอดภัย

#### a) มีแนวคิดเรื่อง boundary ที่ชัดเจน

ระบบนี้มีแนวทางป้องกันที่ดี:

- account-scoped storage
- tenant/role separation
- session revocation
- rate limiting
- OTP lockout
- validation on auth flow
- admin/system-operator separation

สิ่งเหล่านี้แสดงว่า ทีมไม่ได้ทำแค่ auth แบบง่าย ๆ แต่มีความสนใจเรื่อง access control และ data ownership

#### b) มีการย้าย secrets/credential ไปอยู่ใน Keychain และลดความเสี่ยงจาก UserDefaults

นี่เป็นเรื่องที่ดีมาก และเป็นสัญญาณของการพัฒนาในทางที่ถูกต้อง เพราะ:

- JWT/OTP/passcode อยู่ใน Keychain
- local secret storage ถูกจัดการดีขึ้น
- lockout state เก็บใน SQLite หรือ Keychain แทน memory

การเปลี่ยนแปลงนี้ทำให้ความปลอดภัยระยะสั้นดีขึ้นมาก

#### c) มีการใช้ server-side session/state มากขึ้น

สิ่งนี้สำคัญมาก เพราะบางระบบที่ทำแอปมือถือใช้โหมด local-first มักปล่อยตรรกะ auth ไว้ฝั่ง client เอาเปรียบได้ง่าย แต่ระบบนี้พยายามชัดเจนว่า:

- session อยู่ฝั่ง backend
- validation ไม่ใช่แค่ local check
- revoke session ได้
- account scope ไม่ปล่อยให้ client เลือกเอง

### 3.2 จุดอ่อนด้านความปลอดภัย

#### a) Secret exposure history คือภัยคุกคามที่สุด

เอกสารชัดเจนว่ามี secret เคยอยู่ใน Git history และต้อง rotate รวมถึง JWT/LINE/Resend credential

นี่เป็นจุดที่อันตรายที่สุด เพราะการ “ลบไฟล์ออกจาก repo” ไม่ได้แปลว่าความเสี่ยงหายไป หาก commit เก่าอยู่ใน history แล้วบางคนเคยคัดลอกหรือเห็น ก็ยังมีความเสี่ยง

#### b) media transfer / ownership ยังไม่เป็น production-safe

ภาพ/สลิปเป็นข้อมูลที่บอบบางมาก เพราะ:

- อาจสูญหายขณะเปลี่ยนเครื่อง
- อาจผูกผิดบัญชี
- อาจถูกเก็บหรือแชร์โดยผิดสิทธิ์
- อาจ mismatch ระหว่าง metadata กับ binary file จริง

ระบบที่เก็บข้อมูลสำคัญแบบนี้ต้องให้ความสำคัญกับ ownership, checksum, file validation และ privacy boundary อย่างเข้มข้น

#### c) authorization ยังต้องพิสูจน์ต่อไปอย่างจริงจัง

เอกสารระบุว่า endpoint บางส่วนยังต้องเพิ่ม regression tests และ authorization coverage เพิ่มเติม

ความเสี่ยงในระบบประเภทนี้ไม่ได้อยู่ที่ “หลาย role” อย่างเดียว แต่อยู่ที่การคาดเดา/ลืมตั้งเงื่อนไข หรือ fallback logic ที่ไม่ถูกต้องใน production

#### d) sync conflict เหลือโอกาสถูกเขียนทับแบบ silent

เมื่อใช้ snapshot และ whole-state sync แม้จะมี version/checksum แต่ถ้าความผิดพลาดเกิดที่ merge หรือ conflict handling จะกลายเป็น data loss แบบเงียบ ๆ ซึ่งเป็นอันตรายมากที่สุดในฐานข้อมูลธุรกิจ

---

## 4. ความซับซ้อนของระบบ

### 4.1 ความซับซ้อนของธุรกิจสูงมาก

ระบบนี้ไม่ใช่แอปจัดการผู้เช่าแบบธรรมดา แต่มีความซับซ้อนดังนี้:

- การจอง
- การเข้าอยู่
- การย้ายห้อง
- การผ่อนชำระ
- การบันทึกสลิป
- การคำนวณค่าบริการ
- การออกบิลรายเดือน
- ประวัติห้อง/ผู้เช่า
- ข้อมูลเงินย้อนหลัง
- ตรวจสถานะห้อง/ผู้เช่า
- backup + restore

เมื่อรวมเข้ากับ sync ระหว่างหลายเครื่องและหลายบัญชี ความซับซ้อนจะเพิ่มขึ้นเป็นสองเท่า เพราะทุกความสัมพันธ์ต้องถือว่าอาจเกิดสมมติฐานผิดได้

### 4.2 ความซับซ้อนสูงสุดอยู่ที่ “ระบบข้อมูล” ไม่ใช่ UI

ถ้าจะประเมินแล้ว ระบบนี้มีความซับซ้อนมากกว่าที่หลายทีมเข้าใจ เพราะความท้าทายไม่ได้อยู่ที่หน้าจอ แต่อยู่ที่:

- ความถูกต้องของข้อมูล
- ความสัมพันธ์ระหว่าง entity
- กฎเกณฑ์การเงิน
- การ sync ที่ไม่มี data loss
- การแก้ conflict
- การเก็บประวัติที่ไม่เสียหาย

นี่คือเหตุผลหลักที่ทำให้ “ใช้ได้แค่ local” หรือ “AI generate ได้ฟีเจอร์” ไม่พอ ต้องมีความอดทนและแบบแผนจริง

---

## 5. สิ่งที่ควรแก้ก่อน production

### 5.1 P0: ต้องแก้ก่อนเปิดใช้งานจริง

1. Rotate all secrets และจัดการ Git history
   - JWT secret
   - LINE token/secret
   - Resend API key
   - email provider credentials
   - any system secret that could have been exposed

2. ปรับ media ownership and transfer model
   - สลิป/รูป/วิดีโอต้องมี ownership
   - checksum และ validation ของไฟล์จริง
   - sync ข้ามเครื่องต้องพิสูจน์ว่าไม่มีข้อมูลสูญหาย

3. ปรับ conflict resolution สำหรับ whole-snapshot sync
   - ระบุว่าเมื่อเกิด conflict ให้ทำอย่างไร
   - ให้มี safe fallback / backup before overwrite
   - มี audit log สำหรับการเลือกข้อมูลเซิร์ฟเวอร์หรือ local data

4. ปรับ financial ledger architecture
   - แยก invoice / payment transaction / receipt / deposit
   - ลดการบรรจุหลาย “ความหมาย” ใน object เดียว
   - เพิ่ม immutable audit trail

5. เพิ่ม production restore drill ที่พิสูจน์จริง
   - backup server
   - archive integrity
   - tenant database correctness
   - media restoration

### 5.2 P1: ต้องแก้ก่อน pilot ที่จริงจัง

1. Real-device UAT
   - iPhone จริง
   - 2 เครื่องขึ้นไป
   - 2 บัญชีขึ้นไป
   - sync conflict real world

2. Authorization regression coverage
   - ทุก role
   - ทุก critical endpoint
   - system operator/admin scope

3. Local data safety
   - data corruption handling
   - import/export validation
   - recovery UI

4. Better error handling and retry UX
   - แจ้งสถานะที่ชัดเจน
   - ไม่ให้ “silent failure” สำหรับ sync หรือ save

5. Formal audit log and transaction history
   - ใครเปลี่ยนอะไร
   - เมื่อไร
   - จากที่ไหน
   - ทำไม

### 5.3 P2: หลัง pilot แล้วค่อยทำ

1. LINE integration จริงและมี delivery status
2. APNs/local notifications
3. Localization กับ String Catalog
4. iPad/large-screen accessibility and UX hardening
5. performance tuning สำหรับภาพใหญ่, วิดีโอ, snapshot ขนาดใหญ่

---

## 6. ความเห็นเชิงสรุป

### ถ้าพูดแบบชัด ๆ

- ด้านสถาปัตยกรรม: มีความคิดที่ดีและมีโอกาสเอาไปต่อได้
- ด้านความปลอดภัย: มีฐานที่ดี แต่ยังไม่มีหลักฐานเพียงพอว่า production-safe
- ด้านความซับซ้อน: สูงกว่าระบบทั่วไปมาก และต้องได้รับการจัดการแบบจริงจัง

### คำสรุปสุดท้าย

ระบบนี้ “ไม่ได้เป็นแอปที่พัฒนาแค่ไปเล่น ๆ” แต่เป็นระบบที่มีโครงสร้างและความคิดระดับหนึ่งที่ดูมีศักยภาพสูงจริง แต่มันยังต้องผ่านการกำจัดความเสี่ยงเชิงข้อมูลและเชิง operational ก่อนที่จะถึงจุดที่สามารถบอกได้ว่า “พร้อมให้ใช้งานจริงแบบเต็มรูปแบบ”

---

## 7. ถ้าจะอธิบายให้คนที่ไม่ใช่ช่างเทคนิคเข้าใจ

“ระบบนี้มีการออกแบบที่ค่อนข้างดีสำหรับการทำงานจริงของหอพัก: ใช้ข้อมูลในเครื่องก่อน จากนั้น sync ขึ้นระบบกลาง และคำนึงถึงความปลอดภัยของบัญชีและข้อมูล. แต่ยังมีงานที่ต้องทำต่ออีกมาก เช่น ป้องกัน data loss, ป้องกันข้อมูลรั่ว, ป้องกันความผิดพลาดจาก sync, และป้องกันการแก้ข้อมูลเงินผิดพลาด. ถ้าไม่ทำเรื่องเหล่านี้ให้ดี ผลเสียจริงจะเกิดจากข้อมูลมากกว่า UI.”
