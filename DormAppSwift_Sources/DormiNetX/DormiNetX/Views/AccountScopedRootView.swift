import SwiftUI
import SwiftData

/// Keeps the SwiftData container aligned with the authenticated account.
///
/// When the user signs in to another account on the same device, the root view
/// swaps to that account's physical store. The existing SwiftUI views can keep
/// using @Query and @Environment(\.modelContext) without knowing which account
/// is active.
struct AccountScopedRootView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("adminID") private var adminID: Int = 0
    @AppStorage("authToken") private var authToken: String = ""

    @State private var modelContainer: ModelContainer
    @State private var loadedStoreKey: String = ""

    init() {
        let initialContainer: ModelContainer
        if let accountID = AccountModelContainer.currentAccountID(),
           UserDefaults.standard.bool(forKey: "isLoggedIn") {
            initialContainer = (try? AccountModelContainer.make(for: accountID))
                ?? (try! AccountModelContainer.makeGuest())
        } else {
            initialContainer = (try! AccountModelContainer.makeGuest())
        }

        _modelContainer = State(initialValue: initialContainer)
    }

    private var storeKey: String {
        guard isLoggedIn else { return "guest" }

        let resolvedID = adminID > 0 ? adminID : (AccountModelContainer.currentAccountID() ?? 0)
        return "account-\(resolvedID)-\(authToken)"
    }

    var body: some View {
        SplashView()
            .modelContainer(modelContainer)
            .task(id: storeKey) {
                await reloadContainerIfNeeded()
            }
    }

    @MainActor
    private func reloadContainerIfNeeded() async {
        guard storeKey != loadedStoreKey else { return }

        if isLoggedIn {
            guard let accountID = AccountModelContainer.currentAccountID() else {
                return
            }

            do {
                let newContainer = try AccountModelContainer.make(for: accountID)
                modelContainer = newContainer
                loadedStoreKey = storeKey
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
