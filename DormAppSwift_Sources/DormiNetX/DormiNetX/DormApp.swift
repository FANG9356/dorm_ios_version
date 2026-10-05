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
    @State private var storeInitError: Error? = nil

    init() {
        var initialContainer: ModelContainer?
        var initialStoreKey: String = "guest"
        var initError: Error? = nil

        if UserDefaults.standard.bool(forKey: "isLoggedIn"),
           let accountID = Self.resolveAccountID() {
            do {
                initialContainer = try AccountScopedStore.makeContainer(accountID: accountID)
                let token = CredentialStore.shared.token ?? ""
                initialStoreKey = "account-\(accountID)-\(token)"
            } catch {
                initError = error
            }
        }

        if initialContainer == nil {
            do {
                initialContainer = try AccountScopedStore.makeGuestContainer()
            } catch {
                if initError == nil {
                    initError = error
                }
            }
        }

        _modelContainer = State(initialValue: initialContainer ?? Self.fallbackContainer())
        _loadedStoreKey = State(initialValue: initialStoreKey)
        if let initError = initError {
            _storeInitError = State(initialValue: initError)
        }
    }

    private static func fallbackContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Room.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Critical SwiftData failure: \(error)")
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
            if let error = storeInitError {
                SwiftDataRecoveryView(error: error, accountID: Self.resolveAccountID() ?? 0) {
                    storeInitError = nil
                    reloadContainerIfNeeded()
                } onLogout: {
                    storeInitError = nil
                    resetToGuestStore()
                }
            } else if isLoggedIn && loadedStoreKey != storeKey {
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
                storeInitError = nil
            } catch {
                print("❌ Failed to create guest SwiftData container: \(error)")
                storeInitError = error
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
            storeInitError = nil
            print("✅ Opened local SwiftData store for account \(accountID)")
        } catch {
            print("❌ Failed to open account-local SwiftData store: \(error)")
            storeInitError = error
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

private struct SwiftDataRecoveryView: View {
    let error: Error
    let accountID: Int
    let onRetry: () -> Void
    let onLogout: () -> Void
    
    @State private var isBusy = false
    
    private var isDiskFull: Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && (nsError.code == CocoaError.fileWriteOutOfSpace.rawValue || nsError.code == 512 || nsError.code == 640)
    }

    var body: some View {
        ZStack {
            GlassBackgroundView().ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: isDiskFull ? "externaldrive.fill.badge.xmark" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(isDiskFull ? .orange : .red)
                    .padding(.top, 20)
                
                VStack(spacing: 8) {
                    Text(isDiskFull ? "พื้นที่เก็บข้อมูลเต็ม" : "ข้อมูลมีปัญหา (Schema Mismatch)")
                        .font(.custom("SukhumvitSet-Bold", size: 22))
                    
                    Text(isDiskFull ? "ไม่สามารถเปิดฐานข้อมูลได้เนื่องจากพื้นที่ในเครื่องของคุณไม่เพียงพอ กรุณาลบข้อมูลที่ไม่จำเป็นแล้วลองใหม่" : "พบปัญหาขณะอัปเกรดโครงสร้างฐานข้อมูล หรือไฟล์ฐานข้อมูลในเครื่องเสียหาย\n(\(error.localizedDescription))")
                        .font(.custom("SukhumvitSet-Medium", size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    Button {
                        isBusy = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onRetry()
                            isBusy = false
                        }
                    } label: {
                        HStack {
                            if isBusy { ProgressView().padding(.trailing, 4) }
                            Text("ลองใหม่อีกครั้ง")
                                .font(.custom("SukhumvitSet-Bold", size: 16))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isBusy)
                    
                    if !isDiskFull {
                        Button {
                            isBusy = true
                            deleteLocalData()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onRetry()
                                isBusy = false
                            }
                        } label: {
                            Text("ล้างข้อมูลในเครื่องและโหลดใหม่")
                                .font(.custom("SukhumvitSet-Bold", size: 16))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                        }
                        .disabled(isBusy)
                    }
                    
                    Button {
                        onLogout()
                    } label: {
                        Text("ออกจากระบบ")
                            .font(.custom("SukhumvitSet-Medium", size: 16))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.secondarySystemBackground).opacity(0.95))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }
    
    private func deleteLocalData() {
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            .appendingPathComponent("DormiNet", isDirectory: true)
            .appendingPathComponent("Accounts", isDirectory: true)
            
            let storeURL = directory.appendingPathComponent("account_\(accountID).store")
            let shmURL = directory.appendingPathComponent("account_\(accountID).store-shm")
            let walURL = directory.appendingPathComponent("account_\(accountID).store-wal")
            
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: shmURL)
            try? FileManager.default.removeItem(at: walURL)
            print("🗑️ Deleted corrupted store for account \(accountID)")
        } catch {
            print("Failed to delete corrupted store: \(error)")
        }
    }
}

@main
struct DormApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appTheme") private var appTheme: Int = AppTheme.system.rawValue
    @AppStorage("appLanguageCode") private var appLanguageCode = "system"

    init() {
        UIScrollView.appearance().keyboardDismissMode = .interactive
    }

    var body: some Scene {
        WindowGroup {
            AccountScopedRootView()
                .globalKeyboardDismiss()
                .preferredColorScheme(AppTheme(rawValue: appTheme)?.colorScheme)
                .environment(\.locale, appLanguageCode == "system" ? .current : Locale(identifier: appLanguageCode))
        }
    }
}
