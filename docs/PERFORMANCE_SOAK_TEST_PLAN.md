# Performance, Memory & Thermal Soak Test Plan

อัปเดตล่าสุด: 2026-10-05

เอกสารนี้ระบุแผนการทดสอบประสิทธิภาพของแอป DormiNetX เพื่อให้มั่นใจว่าเมื่อมีข้อมูลขนาดใหญ่ (Large Snapshot) หรือไฟล์สื่อความละเอียดสูง แอปจะไม่แครชและเครื่องไม่ร้อนจนเกินไป (Thermal Throttling)

## 1. ขอบเขตการทดสอบ (Scope)
- **Large Snapshot Sync:** ทดสอบการซิงก์ข้อมูลลูกบ้าน 1,000 รายการ และบิล 50,000 รายการในการรันครั้งเดียว
- **Media Handling:** ทดสอบการโหลด/อัปโหลดไฟล์รูปภาพขนาดใหญ่ (5MB - 15MB) และการแนบวิดีโอ (ถ้ามี) แจ้งซ่อมพร้อมกัน 5-10 รายการ
- **Memory Leaks & Retain Cycles:** ตรวจสอบ Instruments (Leaks / Allocations) ขณะสลับไปมาระหว่างแถบ Dashboard อย่างรวดเร็ว

## 2. ขั้นตอนการทำ Soak Test

**Pre-requisite:**
- ติดตั้ง DormiNetX (Release Build) บนอุปกรณ์จริง (iPhone และ iPad)
- ไม่เสียบสายชาร์จขณะทดสอบ (เพื่อดูแบตเตอรี่และอุณหภูมิที่แท้จริง)
- ใช้เซิร์ฟเวอร์ Staging ที่ถูกยัดข้อมูล Mock data จำนวนมหาศาลไว้ล่วงหน้า

**Step 1: Initial Sync & Parsing (Heavy Load)**
1. ลบแอปแล้วติดตั้งใหม่ (Clean Install)
2. เข้าสู่ระบบด้วยแอคเคาท์ Staging (ที่มีข้อมูล 50,000 รายการ)
3. ปล่อยให้แอปทำ Initial Sync 
   - **Expectation:** แอปไม่ควรแครชจาก OOM (Out of Memory)
   - **Expectation:** อุณหภูมิเครื่องควรอยู่ระดับอุ่นปกติ ไม่ทะลุขั้น Thermal Critical

**Step 2: Continuous Media Scrolling**
1. เข้าไปที่แท็บ "หลักฐานการโอน"
2. ไถดูสลิปโอนเงิน (Thumbnails) เป็นเวลาต่อเนื่อง 10 นาที
3. กดดูรูปเต็ม (Full Image) และกดปิดสลับไปมาอย่างน้อย 100 ครั้ง
   - **Expectation:** Frame rate ควรอยู่ที่ 60fps (หรือ 120fps บน ProMotion) 
   - **Expectation:** Memory usage ควรคงที่ (plateau) ไม่พุ่งทะยานต่อเนื่องตามการเลื่อน

**Step 3: Background & Foreground Transition**
1. พับแอปไปพื้นหลัง (Background) เป็นเวลา 15 นาที
2. กลับเข้าแอปใหม่ บังคับให้เกิด Background Sync
   - **Expectation:** แอปตื่นขึ้นมาตอบสนองทันที ไม่ค้างเกิน 2 วินาที

## 3. การมอนิเตอร์และจับปัญหา
ให้นักพัฒนาเปิดใช้งาน **Xcode Instruments** 
- **Time Profiler:** สำหรับจับ UI thread block (เช่น การแปลง JSON ใน Main thread)
- **Allocations & Leaks:** หาก Memory ทะลุ 1.5 GB บนอุปกรณ์ RAM น้อยให้แจ้งเตือน
- **Energy Log:** สำหรับประเมินอัตราการใช้แบตเตอรี่ใน 1 ชั่วโมง หากเกิน 10% ให้ทำ Code Review หา Background process ที่ไม่ยอมหยุดทำงาน
