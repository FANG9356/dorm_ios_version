import SwiftUI
import SwiftData
import UIKit

/// Owns the local SwiftData container for the currently authenticated account.
///
/// Each account gets a separate persistent store. This keeps local data isolated
/// even when multiple accounts use the same physical iPhone/iPad.
enum AccountScopedStore {
    static let schema = Schema([
        DormUser.self,
        Payment.self,
        PaymentTransaction.self,
        FinancialReceipt.self,
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

        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        if try PaymentLedger.migrateLegacyBalances(in: container.mainContext) > 0 {
            try container.mainContext.save()
        }
        return container
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
    @ObservedObject private var credentials = CredentialStore.shared

    @State private var modelContainer: ModelContainer
    @State private var loadedStoreKey: String = ""

    init() {
        let initialContainer: ModelContainer
        let initialStoreKey: String

        if UserDefaults.standard.bool(forKey: "isLoggedIn"),
           let accountID = Self.resolveAccountID(),
           let container = try? AccountScopedStore.makeContainer(accountID: accountID) {
            initialContainer = container
            let token = CredentialStore.shared.token ?? ""
            initialStoreKey = "account-\(accountID)-\(token)"
        } else {
            initialContainer = (try? AccountScopedStore.makeGuestContainer())
                ?? Self.fallbackContainer()
            initialStoreKey = "guest"
        }

        _modelContainer = State(initialValue: initialContainer)
        _loadedStoreKey = State(initialValue: initialStoreKey)
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

        return "account-\(adminID)-\(credentials.token ?? "")"
    }

    var body: some View {
        Group {
            if isLoggedIn && loadedStoreKey != storeKey {
                AccountStoreLoadingView()
            } else {
                SplashView()
            }
        }
            .modelContainer(modelContainer)
            .task(id: storeKey) {
                reloadContainerIfNeeded()
            }
            .alert("ข้อมูลความปลอดภัย", isPresented: Binding(
                get: { credentials.errorMessage != nil },
                set: { if !$0 { credentials.errorMessage = nil } }
            )) {
                Button("ตกลง", role: .cancel) { credentials.errorMessage = nil }
            } message: { Text(credentials.errorMessage ?? "") }
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
            print("⚠️ Logged in but no adminID is available; returning to login")
            resetToGuestStore()
            return
        }

        do {
            modelContainer = try AccountScopedStore.makeContainer(accountID: accountID)
            loadedStoreKey = storeKey
            print("✅ Opened local SwiftData store for account \(accountID)")
        } catch {
            print("❌ Failed to open account-local SwiftData store: \(error)")
            resetToGuestStore()
        }
    }

    private func resetToGuestStore() {
        APIService.shared.authToken = nil
        APIService.shared.currentEmail = nil
        APIService.shared.userRole = nil
        UserDefaults.standard.removeObject(forKey: "adminID")
        isLoggedIn = false

        do {
            modelContainer = try AccountScopedStore.makeGuestContainer()
            loadedStoreKey = "guest"
        } catch {
            print("❌ Failed to recover guest SwiftData container: \(error)")
        }
    }

    /// Resolve the local store from the saved session, never from a stale account preference.
    private static func resolveAccountID() -> Int? {
        guard let token = CredentialStore.shared.token,
              let accountID = APIService.shared.localSessionAccountID(token: token) else { return nil }
        UserDefaults.standard.set(accountID, forKey: "adminID")
        return accountID
    }
}

private struct AccountStoreLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            GlassBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(colorScheme == .dark ? .white : .indigo)
                    .scaleEffect(1.1)
                Text("กำลังเปิดข้อมูลของบัญชีนี้")
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                    .foregroundStyle(.primary)
                Text("เตรียมข้อมูลภายในเครื่อง")
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

@main
struct DormApp: App {
    @AppStorage("appTheme") private var appTheme: Int = AppTheme.system.rawValue

    init() {
        UIScrollView.appearance().keyboardDismissMode = .interactive
    }

    var body: some Scene {
        WindowGroup {
            AccountScopedRootView()
                .globalKeyboardDismiss()
                .preferredColorScheme(AppTheme(rawValue: appTheme)?.colorScheme)
        }
    }
}
