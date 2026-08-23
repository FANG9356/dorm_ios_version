import Foundation
import SwiftData

/// Defines the authenticated account that owns all local SwiftData records.
///
/// The server already identifies a dorm by `admin_id`, so the iOS local store
/// uses that stable ID rather than email as the ownership key.
@MainActor
final class LocalAccountScope {
    static let shared = LocalAccountScope()

    private let accountIDKey = "adminID"
    private let emailKey = "userEmail"
    private let tokenKey = "authToken"
    private let legacyMigrationKey = "localAccountLegacyMigrationVersion"
    private let migrationVersion = 1

    private init() {}

    var accountID: Int? {
        let stored = UserDefaults.standard.integer(forKey: accountIDKey)
        if stored > 0 {
            return stored
        }

        // Registration currently receives a JWT but the response does not yet
        // include admin_id. Decode the JWT payload only as a local fallback for
        // the identifier; the token is still verified by the server on requests.
        guard let token = UserDefaults.standard.string(forKey: tokenKey),
              let payload = Self.jwtPayload(token),
              let id = payload["admin_id"] as? NSNumber else {
            return nil
        }

        let value = id.intValue
        if value > 0 {
            UserDefaults.standard.set(value, forKey: accountIDKey)
            return value
        }
        return nil
    }

    var email: String? {
        let value = UserDefaults.standard.string(forKey: emailKey)
        return value?.isEmpty == false ? value : nil
    }

    func requireAccountID() throws -> Int {
        guard let accountID else {
            throw LocalAccountScopeError.notAuthenticated
        }
        return accountID
    }

    /// Claims legacy records that were created before account isolation existed.
    /// This runs only once per installation. New records must always be created
    /// with the current account ID and must never rely on this migration.
    func migrateLegacyDataIfNeeded(modelContext: ModelContext) throws {
        guard accountID != nil else { return }
        guard UserDefaults.standard.integer(forKey: legacyMigrationKey) < migrationVersion else {
            return
        }

        let ownerID = try requireAccountID()

        // Room is migrated here first. Additional models are added to this
        // migration as their account ownership fields are introduced.
        let roomDescriptor = FetchDescriptor<Room>(
            predicate: #Predicate { $0.ownerAccountID == nil }
        )
        let legacyRooms = try modelContext.fetch(roomDescriptor)
        for room in legacyRooms {
            room.ownerAccountID = ownerID
        }

        try modelContext.save()
        UserDefaults.standard.set(migrationVersion, forKey: legacyMigrationKey)
    }

    private static func jwtPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var encoded = String(parts[1])
        let remainder = encoded.count % 4
        if remainder != 0 {
            encoded += String(repeating: "=", count: 4 - remainder)
        }
        encoded = encoded.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: encoded),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any] else {
            return nil
        }
        return payload
    }
}

enum LocalAccountScopeError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No authenticated local account is available."
        }
    }
}
