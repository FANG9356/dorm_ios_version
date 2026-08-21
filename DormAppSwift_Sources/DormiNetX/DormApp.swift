import SwiftUI
import SwiftData

@main
struct DormApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DormUser.self,
            Payment.self,
            Room.self,
            Maintenance.self
        ])
        
        // ปิด CloudKit ทิ้ง แล้วใช้ Local Storage อย่างเดียว 
        // เพราะเราจะ Sync กับเซิร์ฟเวอร์ Go ของเราเอง
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
