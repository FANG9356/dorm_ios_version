import SwiftUI

struct ContentView: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("adminID") var adminID: Int = 0
    
    var body: some View {
        ZStack {
            // วางพื้นหลังกระจกไว้ชั้นนอกสุด ทะลุขอบจอ 100%
            GlassBackgroundView()
                .ignoresSafeArea(.all)
            
            if isLoggedIn {
                RoomListView()
                    .id("room-list-\(adminID)")
                    // ใช้แค่การเฟดเพียวๆ ไม่ต้องมีการย่อขยาย จะได้สมูทที่สุด
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        // ปรับเป็น easeInOut 0.8 วินาที ให้ภาพค่อยๆ ละลายเปลี่ยนหน้าเนียนๆ
        .animation(.easeInOut(duration: 0.8), value: isLoggedIn)
    }
}
