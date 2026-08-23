import SwiftUI
import SwiftData

@main
struct DormApp: App {
    @AppStorage("appTheme") private var appTheme: Int = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            AccountScopedRootView()
                .preferredColorScheme(AppTheme(rawValue: appTheme)?.colorScheme)
        }
    }
}
