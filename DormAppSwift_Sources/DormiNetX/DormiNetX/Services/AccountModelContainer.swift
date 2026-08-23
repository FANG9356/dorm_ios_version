import Foundation
import SwiftData

/// Owns the local SwiftData store for the currently authenticated account.
///
/// Each server `admin_id` gets a physically separate local store file. This
/// prevents records from one account from ever being visible to another account
/// on the same device, without requiring an `ownerAccountID` column on every
/// existing SwiftData model.
@MainActor
enum AccountModelContainer {
    static let schema = Schema([
        DormUser.self,
        Payment.self,
        Room.self,
        Maintenance.self,
        RoomType.self,
        LocalSystemLog.self
    ])

    static func make(for accountID: Int) throws -> ModelContainer {
        guard accountID > 0 else {
            throw AccountStoreError.invalidAccountID
        }

        let directory = try accountDirectory()
        let storeURL = directory.appendingPathComponent("account_\(accountID).store")
        let configuration = ModelConfiguration(
            "account_\(accountID)",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeGuest() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
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

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func currentAccountID() -> Int? {
        let storedID = UserDefaults.standard.integer(forKey: "adminID")
        if storedID > 0 {
            return storedID
        }

        guard let token = UserDefaults.standard.string(forKey: "authToken"),
              !token.isEmpty else {
            return nil
        }

        guard let payload = jwtPayload(token),
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
    case unableToCreateStore

    var errorDescription: String? {
        switch self {
        case .invalidAccountID:
            return "Invalid authenticated account ID."
        case .unableToCreateStore:
            return "Unable to create the local account data store."
        }
    }
}
