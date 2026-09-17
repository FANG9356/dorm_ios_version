# แบบประเมิน DormiNetX — 17 กันยายน 2569

## คำตัดสิน

DormiNetX พร้อมสำหรับ **controlled pilot** ที่จำกัดจำนวนห้อง มี backup และมีผู้ดูแลติดตามผล แต่ยังไม่พร้อมประกาศ production เต็มรูปแบบ คะแนนรอบนี้ดีขึ้นเล็กน้อยจาก workflow งานซ่อมและ LINE delivery ที่ครบขึ้น ไม่ได้เพิ่มมากเพราะ release blockers ด้าน secret, multi-device, media lifecycle, financial audit และ restore drill ยังไม่ถูกปิดด้วยหลักฐานจริง

## คะแนนล่าสุด

| มิติ | คะแนน | เหตุผลย่อ |
| --- | ---: | --- |
| ความครบของฟีเจอร์ | 9.2/10 | งานหลักครบมากขึ้น และงานซ่อมมี consent/billing flow ที่เหมาะกับการใช้งานจริง |
| สถาปัตยกรรม | 8.7/10 | local-first, tenant isolation, snapshot protection, outbox และ rollback มีโครงสร้างชัด |
| ความปลอดภัยและข้อมูล | 8.0/10 | authorization/media hardening ดีขึ้น แต่ provider secret rotation และ full financial audit ยังไม่ปิด |
| UX และความสม่ำเสมอ | 8.6/10 | UI รายการ/ค้นหา/วันที่และงานซ่อมสม่ำเสมอขึ้น ลด gesture ที่กดพลาด แต่ accessibility/performance ยังขาดหลักฐาน |
| Operational readiness | 8.4/10 | deploy/backup/health/retry ดีขึ้น แต่ยังไม่มี production restore drill และ monitoring ครบวงจร |
| Controlled pilot | **8.9/10 (89%)** | ใช้ในวงจำกัดได้หากมีผู้ดูแลและ rollback |
| Production readiness | **7.9/10 (79%)** | ยังมี P0 ที่ต้องใช้สิทธิ์ provider, อุปกรณ์จริง และ maintenance window |

คะแนนนี้เป็น risk-weighted assessment ไม่ใช่ test coverage, uptime SLA หรือเปอร์เซ็นต์จำนวนงาน และไม่ควรเฉลี่ยกับคะแนน baseline เก่า

## สิ่งที่เพิ่มหรือแก้ในรอบล่าสุด

- workflow งานซ่อมจาก 5 เป็น 6 ขั้น โดยเพิ่ม `รออนุมัติค่าใช้จ่าย`
- งานมีค่าใช้จ่ายต้องแจ้งยอดและให้ linked resident อนุมัติผ่าน LINE ก่อนซ่อม; แอดมินข้ามไม่ได้
- ปฏิเสธใบเสนอราคาแล้วกลับไปติดต่อช่างเพื่อแก้ยอด/ออกใหม่ และป้องกัน stale/unauthorized action
- ล็อกยอดที่เสนอแล้ว และส่ง Flex บิลเมื่อเข้าสถานะรอตรวจสอบชำระเงิน
- งานฟรีข้าม quote และ payment ได้โดยไม่สร้างภาระที่ไม่จำเป็น
- LINE action publish สถานะกลับ snapshot เพื่อให้แอปเห็นข้อมูลเดียวกัน
- persistent outbox, idempotency, retry/backoff, recovery และ internal maintenance ID ลด silent failure
- Flex งานซ่อมใช้ขาว–เทาแบบกระชับ แสดงวันที่/เวลาไทย ข้อมูลค่าใช้จ่าย และ progress `n/6`
- UI งานซ่อมเป็น read-only timeline บนหน้ารายการ ต้องเข้ารายละเอียดจึงแก้ ลดโอกาสกดผิด
- backend รุ่น workflow `f02deb959dde76647b366d24e1e804b7958af4552b4ca715b615333783e997c6` deploy แล้ว และ hotfix LINE Flex quote/payment รุ่น `2566537a63a22d3d591f2e845fe6389afc0412664094436999eaabb45e3aec4d` ส่งใบเสนอราคาที่ค้างสำเร็จ พร้อม backup/rollback และ health ผ่าน
- approval workflow รุ่น `d4e0f718ff73c371796f8ca5adc4f9964d755d132cced1e9a94de7cc66db4351` แยก “ลูกบ้านอนุมัติราคา” ออกจาก “แอดมินเริ่มซ่อม” ด้วย server-side marker และ durable status notification; ข้อมูลจริงห้อง 103 ถูก reconcile และแอป signed รุ่นใหม่ติดตั้งแล้ว

## จุดแข็งที่ควรรักษา

1. Product intent ชัด: ผู้ดูแลทำงานในแอป ลูกบ้านติดต่อผ่าน LINE และทั้งสองฝั่งเห็นข้อมูลเดียวกัน
2. ให้ความสำคัญกับข้อมูลจริง: account scope, tenant ownership, checksum, conflict protection, retry และ backup
3. ตัดสินใจ UX จากการใช้งานจริง เช่น ตัด swipe ที่แย่ง scroll, รวมตัวกรอง, ลดสี และบังคับเข้า detail ก่อนแก้
4. ยอมแยก “deploy แล้ว” ออกจาก “UAT ผ่านแล้ว” ทำให้สถานะเอกสารเชื่อถือได้
5. วันที่และรอบบิลมี canonical conversion ลดความเสี่ยง ค.ศ./พ.ศ. ปะปน

## Release blockers

| ระดับ | ความเสี่ยง | เหตุผลที่ยังไม่ผ่าน | หลักฐานที่ต้องมี |
| --- | --- | --- | --- |
| P0 | Provider secret rotation | secret เคยอยู่ใน Git history | revoke/rotate ที่ provider, session cutover, login/LINE/email หลังเปลี่ยน |
| P0 | สอง iPhone/สองบัญชี | ยังไม่พิสูจน์ conflict, interruption และ account isolation ครบ | UAT matrix พร้อมผลและหลักฐานไม่สูญหาย/ไม่ข้ามบัญชี |
| P0 | Protocol 2 device proof | server ปิด legacy แล้วแต่ยังขาด manual device proof | sync จริงผ่านและ journal ไม่มี rejection |
| P0 | Media lifecycle | access/checksum/retry ผ่าน แต่ cleanup/retention/UAT ยังขาด | cross-device download, orphan cleanup และ retention policy |
| P0 | Financial ledger | transaction/receipt เริ่มมี แต่ refund/void/credit ยังไม่ครบ | immutable actor/reason audit และ migration/UAT |
| P0 | Production restore | verify-only/offline drill ผ่าน แต่ยังไม่สลับจริงใน maintenance window | restore, health checklist และ rollback สำเร็จ |
| P1 | Maintenance consent E2E | payload/tests/deploy ผ่าน แต่ยังไม่กดครบ flow บนบัญชีทดสอบจริง | approve, reject, re-quote, bill, slip และ app sync ครบ |

## เป้าหมายรอบถัดไป

1. ปิด maintenance consent/billing UAT ด้วย test record ที่ได้รับอนุญาต
2. ปิด protocol-2 proof และ UAT สองเครื่อง/สองบัญชี
3. หมุน provider secrets โดยมี cutover/rollback plan
4. ปิด media lifecycle และ production restore drill
5. ทำ refund/void/credit ledger ก่อน rollout ทางการเงินวงกว้าง
6. เพิ่ม UI automation, monitoring, APNs, localization, accessibility และ performance ตามลำดับ

## เกณฑ์ขยับคะแนน

- เกิน 85% production readiness: ต้องปิด secret rotation, two-device/account UAT, protocol-2 proof และ media lifecycle
- เกิน 90%: ต้องมี full financial adjustment audit และ production restore/rollback drill
- 100%: ไม่มี P0/P1 เปิดอยู่, release/UI/E2E tests ผ่าน, TestFlight pilot ครบหนึ่งรอบบิล, ไม่มี data-loss incident และเอกสาร incident/retention/privacy พร้อม

## เอกสารที่ใช้ส่งต่อ

- วิสัยทัศน์: [PROJECT_VISION.md](../project-tracking/PROJECT_VISION.md)
- สถานะล่าสุด: [WORK_STATUS.md](../project-tracking/WORK_STATUS.md)
- Backlog: [PENDING_WORK.md](../project-tracking/PENDING_WORK.md)
- คู่มือผู้รับช่วง: [HANDOFF.md](../project-tracking/HANDOFF.md)
- UAT: [UI_LINE_AUDIT_CHECKLIST.md](../project-tracking/UI_LINE_AUDIT_CHECKLIST.md)
