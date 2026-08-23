import SwiftUI
import SwiftData

/// Owns the local SwiftData container for the currently authenticated account.
///
/// Each account gets a separate persistent store. This keeps local data isolated
/// even when multiple accounts use the same physical iPhone/iPad.
enum AccountScopedStore {
    static let schema = Schema([
        DormUser.self,
        Payment.self,
        Room.self,
        Maintenance.self,
        RoomType.self,
        LocalSystemLog.self
    ])

    private static let fileManager = FileManager.default

    static func makeContainer(accountID: Int) throws -> ModelContainer {
        guard accountID > 0 else {
            throw AccountStoreError.invalidAccountID
        }

        let directory = try accountsDirectory()
        let storeURL = directory.appendingPathComponent("account_\(accountID).store")

        let configuration = ModelConfiguration(
            "account_\(accountID)",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    /// A temporary in-memory container is used while the user is logged out.
    /// It prevents the previous account's persistent context from remaining
    /// attached to the login screen.
    static func makeGuestContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    private static func accountsDirectory() throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = applicationSupport
            .appendingPathComponent("DormiNet", isDirectory: true)
            .appendingPathComponent("Accounts", isDirectory: true)

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }
}

enum AccountStoreError: LocalizedError {
    case invalidAccountID

    var errorDescription: String? {
        switch self {
        case .invalidAccountID:
            return "Invalid authenticated account ID."
        }
    }
}

/// Keeps SwiftData attached to the same account as the authentication state.
/// Existing views can continue using @Query and @Environment(\.modelContext).
struct AccountScopedRootView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("adminID") private var adminID: Int = 0
    @AppStorage("authToken") private var authToken: String = ""

    @State private var modelContainer: ModelContainer
    @State private var loadedStoreKey: String = ""

    init() {
        let initialContainer: ModelContainer

        if UserDefaults.standard.bool(forKey: "isLoggedIn"),
           let accountID = Self.resolveAccountID(),
           let container = try? AccountScopedStore.makeContainer(accountID: accountID) {
            initialContainer = container
        } else {
            initialContainer = (try? AccountScopedStore.makeGuestContainer())
                ?? Self.fallbackContainer()
        }

        _modelContainer = State(initialValue: initialContainer)
    }

    private static func fallbackContainer() -> ModelContainer {
        do {
            return try AccountScopedStore.makeGuestContainer()
        } catch {
            fatalError("Could not create guest ModelContainer: \(error)")
        }
    }

    private var storeKey: String {
        guard isLoggedIn else {
            return "guest"
        }

        return "account-\(adminID)-\(authToken)"
    }

    var body: some View {
        SplashView()
            .modelContainer(modelContainer)
            .task(id: storeKey) {
                reloadContainerIfNeeded()
            }
    }

    private func reloadContainerIfNeeded() {
        guard storeKey != loadedStoreKey else {
            return
        }

        guard isLoggedIn else {
            do {
                modelContainer = try AccountScopedStore.makeGuestContainer()
                loadedStoreKey = "guest"
            } catch {
                print("❌ Failed to create guest SwiftData container: \(error)")
            }
            return
        }

        guard let accountID = Self.resolveAccountID() else {
            print("⚠️ Logged in but no adminID is available; keeping current store")
            return
        }

        do {
            modelContainer = try AccountScopedStore.makeContainer(accountID: accountID)
            loadedStoreKey = storeKey
            print("✅ Opened local SwiftData store for account \(accountID)")
        } catch {
            print("❌ Failed to open account-local SwiftData store: \(error)")
        }
    }

    /// The login API already persists adminID in UserDefaults. This fallback
    /// decodes the JWT only when adminID has not yet been persisted.
    private static func resolveAccountID() -> Int? {
        let storedID = UserDefaults.standard.integer(forKey: "adminID")
        if storedID > 0 {
            return storedID
        }

        guard let token = UserDefaults.standard.string(forKey: "authToken"),
              !token.isEmpty else {
            return nil
        }

        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            return nil
        }

        var encodedPayload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = encodedPayload.count % 4
        if remainder != 0 {
            encodedPayload += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: encodedPayload),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any],
              let value = payload["admin_id"] as? NSNumber else {
            return nil
        }

        let accountID = value.intValue
        guard accountID > 0 else {
            return nil
        }

        UserDefaults.standard.set(accountID, forKey: "adminID")
        return accountID
    }
}

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
