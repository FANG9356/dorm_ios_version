# แบบประเมิน DormiNetX — 18 กันยายน 2569

## คำตัดสิน

DormiNetX พร้อมสำหรับ **controlled pilot** ที่จำกัดจำนวนห้อง มี backup และมีผู้ดูแลติดตามผล แต่ยังไม่พร้อมประกาศ production เต็มรูปแบบ รอบนี้เพิ่มคะแนนอย่างระมัดระวังเพราะมีหลักฐานจากอุปกรณ์จริงว่า LINE → tenant DB → snapshot → SwiftData ทำงานผ่านหลังปิด legacy sync และ conflict rebase ไม่ทำข้อมูลในเครื่องหาย อย่างไรก็ตาม maintenance consent/billing ยังไม่ได้ UAT ครบทุกสาขา และ P0 ด้าน secret, สองอุปกรณ์/สองบัญชี, media, financial audit และ restore drill ยังเปิดอยู่

## คะแนนล่าสุด

| มิติ | คะแนน | เหตุผลย่อ |
| --- | ---: | --- |
| ความครบของฟีเจอร์ | 9.3/10 | งานหลักครบขึ้น รวม consent, rejection terminal branch, billing และ sync recovery |
| สถาปัตยกรรม | 8.8/10 | local-first, tenant isolation, snapshot conflict rebase, outbox และ rollback มีเส้นทางชัดขึ้น |
| ความปลอดภัยและข้อมูล | 8.1/10 | protocol-2 device proof ผ่านหนึ่งเครื่องและข้อมูลไม่สูญหาย แต่ secret rotation/full financial audit ยังไม่ปิด |
| UX และความสม่ำเสมอ | 8.8/10 | LINE ตอบหนึ่งเหตุการณ์ด้วยการ์ดเดียว Flex ลดสี และ iOS ลด action ที่กดพลาด; accessibility/performance ยังขาดหลักฐาน |
| Operational readiness | 8.5/10 | deploy/backup/health/retry และ device-level sync evidence ดีขึ้น แต่ยังไม่มี production restore drill/monitoring ครบวงจร |
| Controlled pilot | **9.0/10 (90%)** | ใช้ในวงจำกัดได้หากมีผู้ดูแลและ rollback |
| Production readiness | **8.1/10 (81%)** | ปิด protocol-2 device proof แล้วหนึ่ง P0 แต่ยังมี P0 สำคัญหลายรายการ |

คะแนนนี้เป็น risk-weighted assessment ไม่ใช่ test coverage, uptime SLA หรือเปอร์เซ็นต์จำนวนงาน และไม่ควรเฉลี่ยกับคะแนน baseline เก่า

## สิ่งที่เพิ่มหรือแก้ตั้งแต่แบบประเมิน 17 กันยายน

- แก้ iOS sync conflict: เมื่อ local dirty snapshot ชนกับข้อมูลใหม่จาก LINE แอปดึง remote, rebase local records และ push ซ้ำแทนการหยุดที่ HTTP 409
- เพิ่ม sync ตอนเปิด dashboard และหน้าแจ้งซ่อม ทำให้ข้อมูลจาก LINE เข้าหน้ารายการโดยไม่ต้องพึ่งการเปิดหน้าอื่นก่อน
- แก้ backend materialization ให้รองรับ `ปฏิเสธค่าใช้จ่าย` เป็น terminal branch และไม่ทำให้ snapshot ที่บันทึกแล้วตอบ HTTP 500
- พิสูจน์เส้นทาง production บนอุปกรณ์จริง: รายการ LINE server id 183 อยู่ตรงกันใน tenant DB, snapshot v161 และ SwiftData; dirty 0, pending 0
- targeted iOS `MaintenanceWorkflowTests` 4/4 และ `CoreDataSafetyTests` 19/19 รวม 23/23 ผ่าน; backend test/race/vet ผ่าน
- ปรับ Flex ปฏิเสธใบเสนอราคาเป็นขาว–ดำ–เทาแบบกระชับ ไม่มีพื้น/หัวสีแดงเดิม
- ตัด text bubble ที่ซ้ำกับ Flex หลังอนุมัติ/ปฏิเสธสำเร็จ; text เหลือเฉพาะ validation, stale/repeated action หรือ fallback เมื่อ enqueue ไม่สำเร็จ
- backend production ล่าสุด SHA-256 `32a26c80c5793f533a1e658790c09aed423b51f104a4e3120496ce5793f07f89`; rollback set ล่าสุด `/home/fang/line_migration_backups/20260917-201712-pre-flex-ui`

## หลักฐานที่ใช้ขยับคะแนน

| หลักฐาน | ผล | ขอบเขตที่พิสูจน์ได้ |
| --- | --- | --- |
| iPhone “F” หลัง conflict/rebase | snapshot v161, dirty 0, pending 0, รายการใหม่ปรากฏ | ปิด protocol-2 device proof สำหรับหนึ่งอุปกรณ์และหนึ่งเหตุการณ์ |
| Tenant DB + latest snapshot | server id 183 และสถานะตรงกับ SwiftData | LINE-created record เดินทางถึงแอปโดยข้อมูล local ไม่สูญหาย |
| iOS targeted tests | 23/23 ผ่าน | workflow, approval marker, terminal rejection และ conflict rebase |
| Backend verification | `go test ./...`, `go test -race ./handlers`, `go vet ./...` ผ่าน | workflow/snapshot/outbox regression ระดับอัตโนมัติ |
| Production deploy | health online, service active, backup ก่อนสลับรุ่น | รุ่นล่าสุดย้อนกลับได้ตาม backup ที่ระบุ |

หลักฐานนี้ยังไม่ถือเป็น UAT สอง iPhone/สองบัญชี และยังไม่พิสูจน์ quote → approve/reject → re-quote → bill → slip ครบวงจร

## จุดแข็งที่ควรรักษา

1. ผู้ดูแลทำงานในแอป ลูกบ้านทำรายการสำคัญผ่าน LINE และข้อมูลทั้งสองฝั่งต้องกลับมาตรงกัน
2. ความถูกต้องของข้อมูลมาก่อนความสะดวกชั่วคราว: conflict ต้องรวมข้อมูล ไม่ทับหรือละทิ้งเงียบ ๆ
3. งานซ่อมที่มีค่าใช้จ่ายต้องรู้ยอดและได้รับความยินยอมก่อนเริ่มซ่อม
4. หนึ่งเหตุการณ์ใน LINE ควรให้ผลตอบกลับที่ชัดเจนหนึ่งรายการ ไม่สร้างข้อความซ้ำ
5. แยก “automated tests ผ่าน”, “deploy แล้ว”, “data-level UAT ผ่าน” และ “full E2E UAT ผ่าน” ออกจากกันเสมอ

## Release blockers ที่ยังเปิด

| ระดับ | ความเสี่ยง | เหตุผลที่ยังไม่ผ่าน | หลักฐานที่ต้องมี |
| --- | --- | --- | --- |
| P0 | Provider secret rotation | secret เคยอยู่ใน Git history | revoke/rotate ที่ provider, session cutover, login/LINE/email หลังเปลี่ยน |
| P0 | สอง iPhone/สองบัญชี | ยังไม่พิสูจน์ conflict, interruption และ account isolation ครบ | UAT matrix พร้อมผลและหลักฐานไม่สูญหาย/ไม่ข้ามบัญชี |
| P0 | Media lifecycle | access/checksum/retry ผ่าน แต่ cleanup/retention/UAT ยังขาด | cross-device download, orphan cleanup และ retention policy |
| P0 | Financial ledger | transaction/receipt เริ่มมี แต่ refund/void/credit ยังไม่ครบ | immutable actor/reason audit และ migration/UAT |
| P0 | Production restore | verify-only/offline drill ผ่าน แต่ยังไม่สลับจริงใน maintenance window | restore, health checklist และ rollback สำเร็จ |
| P1 | Maintenance consent E2E | payload/tests/deploy และ LINE → app หนึ่งเหตุการณ์ผ่าน แต่ยังไม่กดทุกสาขาบนบัญชีทดสอบ | approve, reject, re-quote, bill, slip, single-Flex rendering และ multi-device app sync ครบ |

## เป้าหมายรอบถัดไป

1. ทำ maintenance controlled UAT ด้วย record/LINE account ที่ได้รับอนุญาต โดยตรวจทั้ง approve, reject, re-quote, bill และ slip
2. ตรวจการ์ด LINE รุ่นล่าสุดบน LINE iOS จริงว่าใช้โทนขาว–เทาและไม่ส่ง text ซ้ำ
3. ทำ UAT สอง iPhone/สองบัญชี รวม conflict, offline, force quit และ tenant isolation
4. หมุน provider secrets ด้วย cutover/rollback plan
5. ปิด media lifecycle, financial adjustment audit และ production restore drill

## เกณฑ์ขยับคะแนนครั้งต่อไป

- ไม่เพิ่มคะแนนจาก build/unit test เพียงอย่างเดียว
- เกิน 85% production readiness: ต้องปิด secret rotation, two-device/account UAT และ media lifecycle พร้อมหลักฐาน
- เกิน 90%: ต้องมี full financial adjustment audit และ production restore/rollback drill
- 100%: ไม่มี P0/P1 เปิดอยู่, release/UI/E2E tests ผ่าน, TestFlight pilot ครบหนึ่งรอบบิล, ไม่มี data-loss incident และเอกสาร incident/retention/privacy พร้อม

## เอกสารที่ใช้ส่งต่อ

- วิสัยทัศน์: [PROJECT_VISION.md](../project-tracking/PROJECT_VISION.md)
- สถานะล่าสุด: [WORK_STATUS.md](../project-tracking/WORK_STATUS.md)
- Backlog: [PENDING_WORK.md](../project-tracking/PENDING_WORK.md)
- คู่มือผู้รับช่วง: [HANDOFF.md](../project-tracking/HANDOFF.md)
- UAT: [UI_LINE_AUDIT_CHECKLIST.md](../project-tracking/UI_LINE_AUDIT_CHECKLIST.md)
- รายงานทุกการดำเนินงาน: [ACTIVITY_REPORT.md](../project-tracking/ACTIVITY_REPORT.md)
