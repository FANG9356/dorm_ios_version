import SwiftUI
import SwiftData

/// Creates one physical SwiftData store per authenticated dorm account.
///
/// The server already uses `admin_id` as the tenant boundary. The iOS app now
/// mirrors that boundary locally: account 101 and account 202 never share the
/// same SQLite store on the device.
enum AccountModelContainer {
    static let schema = Schema([
        DormUser.self,
        Payment.self,
        Room.self,
        Maintenance.self,
        RoomType.self,
        LocalSystemLog.self
    ])

    private static let legacyMigrationKey = "DormiNet.didMigrateLegacySharedStore.v1"

    static func make(for accountID: Int) throws -> ModelContainer {
        guard accountID > 0 else {
            throw AccountStoreError.invalidAccountID
        }

        let directory = try accountDirectory()
        let storeURL = directory.appendingPathComponent("account_\(accountID).store")

        // The first account opened after this architecture change receives the
        // old shared store. The legacy package is then renamed to a backup so a
        // second account can never inherit the first account's local data.
        try migrateLegacyStoreIfNeeded(to: storeURL)

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

    static func makeGuest() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    static func currentAccountID() -> Int? {
        let storedID = UserDefaults.standard.integer(forKey: "adminID")
        if storedID > 0 {
            return storedID
        }

        // Registration currently returns a JWT but not admin_id. The JWT is
        // only decoded locally to recover the tenant identifier; the server
        // remains responsible for validating the token on every API request.
        guard let token = UserDefaults.standard.string(forKey: "authToken"),
              !token.isEmpty,
              let payload = jwtPayload(token),
              let number = payload["admin_id"] as? NSNumber else {
            return nil
        }

        let accountID = number.intValue
        if accountID > 0 {
            UserDefaults.standard.set(accountID, forKey: "adminID")
            return accountID
        }
        return nil
    }

    private static func accountDirectory() throws -> URL {
        let fileManager = FileManager.default
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

    private static func migrateLegacyStoreIfNeeded(to targetURL: URL) throws {
        let defaults = UserDefaults.standard
        let fileManager = FileManager.default

        guard !defaults.bool(forKey: legacyMigrationKey) else {
            return
        }

        // Never overwrite an account store that already exists.
        if fileManager.fileExists(atPath: targetURL.path) {
            defaults.set(true, forKey: legacyMigrationKey)
            return
        }

        // ModelConfiguration exposes the same default store URL that the old
        // DormApp used when it created its shared SwiftData container.
        let legacyConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let legacyURL = legacyConfiguration.url

        guard fileManager.fileExists(atPath: legacyURL.path) else {
            defaults.set(true, forKey: legacyMigrationKey)
            return
        }

        let legacyPackage = persistentStorePackage(for: legacyURL)
        let targetPackage = persistentStorePackage(for: targetURL)
        var copiedTargets: [URL] = []

        do {
            for sourceURL in legacyPackage {
                guard fileManager.fileExists(atPath: sourceURL.path) else {
                    continue
                }

                let target = targetPackage.first {
                    $0.lastPathComponent == targetName(for: sourceURL, legacyURL: legacyURL, targetURL: targetURL)
                } ?? targetURL

                if sourceURL.hasDirectoryPath {
                    try fileManager.copyItem(at: sourceURL, to: target)
                } else {
                    try fileManager.copyItem(at: sourceURL, to: target)
                }
                copiedTargets.append(target)
            }

            // Keep a rollback copy. Renaming the legacy package prevents any
            // later account from accidentally reopening the old shared store.
            let backupSuffix = ".legacy-backup"
            for sourceURL in legacyPackage {
                guard fileManager.fileExists(atPath: sourceURL.path) else {
                    continue
                }

                let backupURL = sourceURL.deletingLastPathComponent()
                    .appendingPathComponent(sourceURL.lastPathComponent + backupSuffix)

                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }
                try fileManager.moveItem(at: sourceURL, to: backupURL)
            }

            defaults.set(true, forKey: legacyMigrationKey)
            print("✅ Migrated legacy local store into account store: \(targetURL.lastPathComponent)")
        } catch {
            // Roll back any partial target copies so the next launch can retry.
            for target in copiedTargets where fileManager.fileExists(atPath: target.path) {
                try? fileManager.removeItem(at: target)
            }
            throw error
        }
    }

    private static func persistentStorePackage(for storeURL: URL) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let stem = storeURL.deletingPathExtension().lastPathComponent

        return [
            storeURL,
            directory.appendingPathComponent(storeURL.lastPathComponent + "-shm"),
            directory.appendingPathComponent(storeURL.lastPathComponent + "-wal"),
            directory.appendingPathComponent(".\(stem)_SUPPORT", isDirectory: true),
            directory.appendingPathComponent("\(stem)_ckAssets", isDirectory: true)
        ]
    }

    private static func targetName(for sourceURL: URL, legacyURL: URL, targetURL: URL) -> String {
        let legacyStem = legacyURL.deletingPathExtension().lastPathComponent
        let targetStem = targetURL.deletingPathExtension().lastPathComponent
        let name = sourceURL.lastPathComponent

        if name == legacyURL.lastPathComponent {
            return targetURL.lastPathComponent
        }
        if name == legacyURL.lastPathComponent + "-shm" {
            return targetURL.lastPathComponent + "-shm"
        }
        if name == legacyURL.lastPathComponent + "-wal" {
            return targetURL.lastPathComponent + "-wal"
        }
        if name == ".\(legacyStem)_SUPPORT" {
            return ".\(targetStem)_SUPPORT"
        }
        if name == "\(legacyStem)_ckAssets" {
            return "\(targetStem)_ckAssets"
        }
        return name
    }

    private static func jwtPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var encoded = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = encoded.count % 4
        if remainder != 0 {
            encoded += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: encoded),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any] else {
            return nil
        }
        return payload
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

/// Keeps the SwiftData container aligned with the authenticated account.
///
/// Existing views continue to use @Query and @Environment(\.modelContext).
/// They automatically receive the store belonging to the current account.
struct AccountScopedRootView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("adminID") private var adminID: Int = 0
    @AppStorage("authToken") private var authToken: String = ""

    @State private var modelContainer: ModelContainer
    @State private var loadedStoreKey: String = ""

    init() {
        let initialContainer: ModelContainer

        if UserDefaults.standard.bool(forKey: "isLoggedIn"),
           let accountID = AccountModelContainer.currentAccountID(),
           let accountContainer = try? AccountModelContainer.make(for: accountID) {
            initialContainer = accountContainer
        } else {
            initialContainer = (try? AccountModelContainer.makeGuest())
                ?? Self.fallbackContainer()
        }

        _modelContainer = State(initialValue: initialContainer)
    }

    private static func fallbackContainer() -> ModelContainer {
        do {
            return try AccountModelContainer.makeGuest()
        } catch {
            fatalError("Could not create temporary SwiftData container: \(error)")
        }
    }

    private var storeKey: String {
        guard isLoggedIn else {
            return "guest"
        }

        let resolvedID = adminID > 0
            ? adminID
            : (AccountModelContainer.currentAccountID() ?? 0)

        // Include the token so a freshly registered account also causes the
        // container to be evaluated again, even before adminID is persisted.
        return "account-\(resolvedID)-\(authToken)"
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

        if isLoggedIn {
            guard let accountID = AccountModelContainer.currentAccountID() else {
                print("⚠️ Logged in but no adminID could be resolved")
                return
            }

            do {
                modelContainer = try AccountModelContainer.make(for: accountID)
                loadedStoreKey = storeKey
                print("✅ Opened local store for account \(accountID)")
            } catch {
                print("❌ Failed to open account-local SwiftData store: \(error.localizedDescription)")
            }
        } else {
            do {
                modelContainer = try AccountModelContainer.makeGuest()
                loadedStoreKey = "guest"
            } catch {
                print("❌ Failed to create guest SwiftData store: \(error.localizedDescription)")
            }
        }
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
