# Accessibility & iPad Optimization Audit

อัปเดตล่าสุด: 2026-10-05

เอกสารนี้สรุปผลการตรวจสอบ (Audit) ด้าน Accessibility (การเข้าถึง) และการรองรับ iPad/Landscape สำหรับแอป DormiNetX เพื่อใช้เป็นแนวทางในการปรับปรุงใน Phase ถัดไป

## 1. VoiceOver & Accessibility Labels
- **ปุ่มและไอคอน (Touch Targets & Icons):**
  - ปัจจุบันแอปมีการใช้ `Image(systemName:)` จำนวนมาก ซึ่งบางตัวยังไม่มี `accessibilityLabel` ที่ชัดเจน
  - **ข้อเสนอแนะ:** ควรเพิ่ม `.accessibilityLabel("ชื่อปุ่ม")` และ `.accessibilityAddTraits(.isButton)` ให้กับคอมโพเนนต์ที่กดได้ทั้งหมด โดยเฉพาะในหน้า Dashboard และการตั้งค่า
- **การเรียงลำดับการอ่าน (Reading Order):**
  - ในหน้าที่มีข้อมูลแน่น (เช่น Maintenance Card) VoiceOver อาจอ่านแบบกระจัดกระจาย
  - **ข้อเสนอแนะ:** ใช้ `.accessibilityElement(children: .combine)` หรือจัดกลุ่มข้อมูลด้วย `.accessibilityElement(children: .contain)` ในหน้าสรุปข้อมูลการเงิน

## 2. Dynamic Type & Text Scaling
- ปัจจุบันแอปมีการใช้ฟอนต์ `SukhumvitSet` ผ่าน `.font(.custom(..., size: ...))` เป็นหลัก
- **ปัญหา:** การกำหนดขนาดแบบ Hardcode `size: 16` จะไม่รองรับ Dynamic Type (เมื่อผู้ใช้ปรับตัวอักษรใหญ่ใน iOS Settings)
- **ข้อเสนอแนะ:** 
  - ใช้ `relativeTo: .body` เช่น `.font(.custom("SukhumvitSet-Medium", size: 16, relativeTo: .body))`
  - ตรวจสอบไม่ให้กล่องข้อความถูกตัด (Truncated) เมื่อตัวอักษรใหญ่ขึ้น

## 3. Touch Target & Contrast
- **Touch Target:** Apple แนะนำให้พื้นที่สัมผัสขั้นต่ำอยู่ที่ `44x44 pt` ปุ่มในแอปบางส่วน (เช่น ปุ่มกากบาทมุมจอ) มีขนาดเล็กเกินไป
- **ข้อเสนอแนะ:** เพิ่ม `.frame(minWidth: 44, minHeight: 44)` หรือใช้ `.contentShape(Rectangle())` เพื่อเพิ่มพื้นที่กดให้ง่ายขึ้น
- **Color Contrast:** ส่วนใหญ่โทนสี Indigo/White มี Contrast ที่ดี แต่ต้องระวังโหมด Dark Mode ในส่วนปุ่มที่เป็นสีเทาอ่อนบนพื้นหลังเทาเข้ม (เช่น ปุ่มยกเลิกในหน้า Maintenance)

## 4. iPad & Landscape Support
- ปัจจุบันแอปถูกออกแบบโครงสร้างแบบ 1 Column (iPhone-centric)
- **ปัญหา:** เมื่อเปิดบน iPad แบบ Landscape พื้นที่ตรงกลางจะถูกยืด (Stretched) หรือมีที่ว่างซ้าย-ขวาเหลือเยอะ
- **ข้อเสนอแนะ:**
  - นำ `NavigationSplitView` มาประยุกต์ใช้กับเมนู Sidebar เพื่อให้ iPad แสดงเมนูด้านซ้ายและเนื้อหาหลักด้านขวาได้เต็มรูปแบบ
  - เพิ่ม Environment ตรวจสอบ Size Class: `@Environment(\.horizontalSizeClass) var horizontalSizeClass` และเปลี่ยน Layout (เช่น จาก `VStack` เป็น `HStack`) เมื่อหน้าจอกว้างขึ้น
  - จัดการ Safe Area ในแนวนอนเพื่อไม่ให้ Content ชนรอยบาก (Notch/Dynamic Island) เมื่อหมุนเครื่อง

## สรุปแผนปฏิบัติงาน (Next Steps)
1. ทยอยเพิ่ม `accessibilityLabel` ให้ปุ่มสำคัญใน `RoomListView`
2. ปรับ Custom Font ทั้งหมดให้รองรับ `relativeTo:`
3. เปลี่ยน Custom Sidebar ปัจจุบันให้สลับไปใช้ `NavigationSplitView` สำหรับ iPad
