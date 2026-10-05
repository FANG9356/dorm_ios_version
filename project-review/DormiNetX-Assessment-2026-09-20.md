# แบบประเมิน DormiNetX — 20 กันยายน 2569

> **เอกสารประวัติ:** สถานะล่าสุดอยู่ที่ [DormiNetX-Assessment-2026-10-05.md](DormiNetX-Assessment-2026-10-05.md) และเอกสาร tracking ใน `project-tracking/` ห้ามใช้คะแนน 82% ในไฟล์นี้แทนสถานะปัจจุบัน

ปรับปรุงเพิ่มเติม: 20 กันยายน 2569 เวลา 16:30 น. หลังจากการทำ Web App LIFF (Tenant Portal) การลบสคริปต์สุ่มเสี่ยง P0 ออกจากประวัติ และแพตช์ปัญหา Memory Leak

เอกสารนี้เป็น historical baseline; ให้ใช้ [แบบประเมิน 5 ตุลาคม 2569](DormiNetX-Assessment-2026-10-05.md) สำหรับคะแนนและสถานะปัจจุบัน

## คำตัดสิน

DormiNetX ขยับเข้าใกล้ Production Readiness ขึ้นอีกขั้นหลังอุดช่องโหว่การฮาร์ดโค้ดรหัสผ่านเซิร์ฟเวอร์แบบ P0 ทิ้งไปแล้ว ฟีเจอร์ที่มอบประสบการณ์ใช้งานให้ลูกบ้านถูกปรับปรุงใหม่ด้วยพอร์ทัลบนเว็บ LIFF เพื่อลดความซับซ้อนของ Chatbot ทั้งนี้ ยังคงติดอยู่ในการเปิดใช้งานในวงจำกัด (Controlled pilot) เนื่องจากการปรับระบบ Fallback OCR ยังต้องได้รับการทดสอบอย่างรัดกุมก่อนให้ลูกบ้านจ่ายเงินจริง และยังคงมีคีย์ลับอื่นๆ ที่ต้องทำการ Rotation เพิ่มเติม

## คะแนนล่าสุด

| มิติ | คะแนน | เหตุผลย่อ |
| --- | ---: | --- |
| ความครบของฟีเจอร์ | 9.6/10 (96%) | เพิ่ม Tenant Portal (ประวัติการเงินและบิลประเมินบนหน้าเว็บ LIFF) |
| สถาปัตยกรรม | 8.6/10 | แพตช์ปัญหา HTTP Response Body Leak (Memory/Connection Leak) ในการส่งคำขอหา LINE |
| ความปลอดภัยและข้อมูล | 8.0/10 | อุดช่องโหว่รหัสผ่าน P0 ด้วย SSH Key แต่ Fallback การเงินยังรอดำเนินการ |
| UX และความสม่ำเสมอ | 9.2/10 | ปรับประวัติการชำระเป็นพอร์ทัล LIFF ใช้งานง่ายกว่า Carousel ที่กินพื้นที่ในแชท |
| Operational readiness | 8.0/10 | การเชื่อมต่อเซิร์ฟเวอร์ด้วย SSH Key ทำให้คำสั่ง Deploy ปลอดภัยและเสถียรขึ้น |
| Controlled pilot | **8.5/10 (85%)** | เพิ่มขึ้นจากการปิดช่องโหว่สำคัญ |
| Production readiness | **8.2/10 (82%)** | ความเสี่ยงระบบหลักลดลงมากหลังนำรหัสผ่านออกไปจาก Git |

คะแนนนี้เป็น risk-weighted assessment ไม่ใช่ test coverage, uptime SLA หรือเปอร์เซ็นต์จำนวนงาน

## สิ่งที่เพิ่มหรือแก้ตั้งแต่แบบประเมิน 18 กันยายน

- เปลี่ยนกลไกปุ่ม “ประวัติการชำระ” จากเดิมที่เป็น Carousel Flex ขนาดใหญ่รกแชท ไปใช้ Flex ขนาดเล็กเป็นปุ่มทางลัดเข้า LIFF แทน
- พัฒนาเว็บแอป Tenant Portal ดึงข้อมูลประวัติการชำระบิลย้อนหลัง (Paid) และยอดชำระที่ประเมินสำหรับเดือนหน้า (Projected) ไปจัดเรียงสวยงาม
- นำรหัสผ่าน `sudo`/`ssh` ออกจากไฟล์สคริปต์ `.exp` ในโปรเจกต์ และใช้กระบวนการเข้าสู่ระบบแบบ Passwordless (SSH Key-pair `id_ed25519`)
- ไล่ลบสคริปต์ที่เป็นอันตรายทิ้งกว่า 30 ไฟล์ และแก้ไขคู่มือให้สอดคล้องกับความปลอดภัยใหม่
- แก้ไขบั๊ก HTTP Response Body Leak ในโค้ดของฟังก์ชันติดต่อ LINE API

## Release blockers ที่ยังเปิด

| ระดับ | ความเสี่ยง | เหตุผลที่ยังไม่ผ่าน | หลักฐานที่ต้องมี |
| --- | --- | --- | --- |
| ~~P0~~ | ~~Provider secret rotation~~ | ~~JWT/LINE/Resend เคยอยู่ใน Git history~~ | ~~revoke/rotate ที่ provider, session cutover, login/LINE/email หลังเปลี่ยน~~ |
| P0 | สอง iPhone/สองบัญชี | ยังไม่พิสูจน์ conflict, interruption และ account isolation ครบ | UAT matrix พร้อมผลและหลักฐานไม่สูญหาย/ไม่ข้ามบัญชี |
| P0 | Media lifecycle | access/checksum/retry ผ่าน แต่ cleanup/retention/UAT ยังขาด | cross-device download, orphan cleanup และ retention policy |
| P0 | Financial ledger | transaction/receipt เริ่มมี แต่ refund/void/credit ยังไม่ครบ | immutable actor/reason audit และ migration/UAT |
| P0 | Production restore | verify-only/offline drill ผ่าน แต่ยังไม่สลับจริงใน maintenance window | restore, health checklist และ rollback สำเร็จ |
| P0 | Auto slip/OCR financial integrity | ตรวจแก้โค้ดให้ fail closed แล้วแต่ยังต้อง UAT ยืนยันบนโปรดักชัน | fail closed, immutable/replay audit, config secrets, least privilege และ controlled UAT |

## เป้าหมายรอบถัดไป

1. ~~หมุน provider secrets (JWT, LINE Token) ด้วย cutover/rollback plan~~ (เสร็จสิ้น)
2. ตรวจสอบการทำ Fallback แบบ Fail Closed ก่อนใช้งานตัดยอดจริง
3. ทำ UAT สอง iPhone/สองบัญชี รวม conflict, offline, force quit และ tenant isolation
4. ปิด media lifecycle, financial adjustment audit และ production restore drill

## เอกสารที่ใช้ส่งต่อ

- วิสัยทัศน์: [PROJECT_VISION.md](../project-tracking/PROJECT_VISION.md)
- สถานะล่าสุด: [WORK_STATUS.md](../project-tracking/WORK_STATUS.md)
- Backlog: [PENDING_WORK.md](../project-tracking/PENDING_WORK.md)
- คู่มือผู้รับช่วง: [HANDOFF.md](../project-tracking/HANDOFF.md)
- UAT: [UI_LINE_AUDIT_CHECKLIST.md](../project-tracking/UI_LINE_AUDIT_CHECKLIST.md)
- รายงานทุกการดำเนินงาน: [ACTIVITY_REPORT.md](../project-tracking/ACTIVITY_REPORT.md)
