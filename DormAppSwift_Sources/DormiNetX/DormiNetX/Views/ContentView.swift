import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @Environment(\.modelContext) private var context
    
    private var isGuestContainer: Bool {
        context.container.configurations.first?.url.absoluteString == "file:///dev/null" ||
        context.container.configurations.first?.isStoredInMemoryOnly == true
    }
    
    var body: some View {
        ZStack {
            // วางพื้นหลังกระจกไว้ชั้นนอกสุด ทะลุขอบจอ 100%
            GlassBackgroundView()
                .ignoresSafeArea(.all)
            
            if isLoggedIn && !isGuestContainer {
                RoomListView()
                    // ใช้แค่การเฟดเพียวๆ ไม่ต้องมีการย่อขยาย จะได้สมูทที่สุด
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        // ปรับเป็น easeInOut 0.8 วินาที ให้ภาพค่อยๆ ละลายเปลี่ยนหน้าเนียนๆ
        .animation(.easeInOut(duration: 0.8), value: isLoggedIn && !isGuestContainer)
    }
}