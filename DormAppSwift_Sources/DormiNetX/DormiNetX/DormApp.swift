import SwiftUI
import SwiftData

@main
struct DormApp: App {
    @AppStorage("appTheme") private var appTheme: Int = AppTheme.system.rawValue
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DormUser.self,
            Payment.self,
            Room.self,
            Maintenance.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .preferredColorScheme(AppTheme(rawValue: appTheme)?.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
