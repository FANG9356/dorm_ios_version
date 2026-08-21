import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    
    // ฟังก์ชันนี้จะถูกเรียกเมื่อผู้ใช้กดปุ่มซิงค์ หรือเปิดแอพขึ้นมา
    func syncWithGoBackend(modelContext: ModelContext) async {
        guard let email = APIService.shared.currentEmail else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            print("🚀 เริ่มทำการ Sync ข้อมูลกับเซิร์ฟเวอร์ของโดเมนคุณ สำหรับ Email: \(email)")
            
            // 1. ดึงข้อมูล (Pull) จาก Go Backend
            // let roomsData = try await APIService.shared.fetchRooms()
            // 解析 JSON และเอามาอัพเดท/สร้างใหม่ ใน SwiftData (modelContext)
            
            // 2. ดันข้อมูล (Push) จากเครื่องที่ถูกแก้ไข (isDirty = true) ขึ้นไปให้ Go Backend
            let descriptor = FetchDescriptor<Room>(predicate: #Predicate { $0.isDirty == true })
            let dirtyRooms = try modelContext.fetch(descriptor)
            for room in dirtyRooms {
                print("กำลัง Push ข้อมูลห้อง \(room.roomNumber) ไปยังเซิร์ฟเวอร์...")
                // try await APIService.shared.pushRoom(room)
                room.isDirty = false // รีเซ็ตสถานะเมื่อดันสำเร็จ
            }
            
            // บันทึกการเปลี่ยนแปลงลงเครื่อง
            try modelContext.save()
            lastSyncTime = Date()
            
            // จำลองการดีเลย์เน็ตเวิร์ค 1 วินาที
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("✅ Sync สำเร็จ!")
            
        } catch {
            print("❌ Sync ล้มเหลว: \(error.localizedDescription)")
        }
    }
}
