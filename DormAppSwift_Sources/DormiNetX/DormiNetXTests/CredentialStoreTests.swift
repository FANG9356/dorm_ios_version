import XCTest
import Security
@testable import DormiNetX

@MainActor
final class CredentialStoreTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "CredentialTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    func testMigratesLegacySecretsBeforeRemovingDefaults() throws {
        try withDefaults { defaults in
            defaults.set("sample-token", forKey: "authToken")
            defaults.set("135790", forKey: "securityPasscode")
            defaults.set(Data("sample-accounts".utf8), forKey: "savedAccountsHistory")
            let secure = MemorySecrets()
            let store = CredentialStore(secure: secure, defaults: defaults)
            XCTAssertEqual(store.token, "sample-token")
            XCTAssertTrue(try store.verifyPasscode("135790"))
            XCTAssertEqual(try store.savedAccountsData(), Data("sample-accounts".utf8))
            for key in ["authToken", "securityPasscode", "savedAccountsHistory"] {
                XCTAssertNil(defaults.object(forKey: key))
                XCTAssertNotNil(secure.values[key])
            }
        }
    }

    func testMigrationFailureDoesNotDeleteLegacyTokenOrExposeSession() throws {
        try withDefaults { defaults in
            defaults.set("sample-token", forKey: "authToken")
            let secure = MemorySecrets()
            secure.failWrites = true
            let store = CredentialStore(secure: secure, defaults: defaults)
            XCTAssertNil(store.token)
            XCTAssertNotNil(store.errorMessage)
            XCTAssertEqual(defaults.string(forKey: "authToken"), "sample-token")
            XCTAssertFalse(defaults.bool(forKey: "credentialsMigrated"))
        }
    }

    func testSecureValueWinsOverStaleLegacyDefaults() throws {
        try withDefaults { defaults in
            defaults.set("old-token", forKey: "authToken")
            let secure = MemorySecrets()
            secure.values["authToken"] = Data("new-token".utf8)
            let store = CredentialStore(secure: secure, defaults: defaults)
            XCTAssertEqual(store.token, "new-token")
            XCTAssertNil(defaults.object(forKey: "authToken"))
        }
    }

    func testLockoutSurvivesStoreRecreationAndExpires() throws {
        try withDefaults { defaults in
            let secure = MemorySecrets()
            let store = CredentialStore(secure: secure, defaults: defaults)
            try store.setPasscode("246810")
            let now = Date(timeIntervalSince1970: 1000)
            for _ in 0..<4 { XCTAssertFalse(try store.verifyPasscode("000000", now: now)) }
            XCTAssertThrowsError(try store.verifyPasscode("000000", now: now))
            let reopened = CredentialStore(secure: secure, defaults: defaults)
            XCTAssertThrowsError(try reopened.verifyPasscode("246810", now: now.addingTimeInterval(30)))
            XCTAssertTrue(try reopened.verifyPasscode("246810", now: now.addingTimeInterval(61)))
            XCTAssertNil(secure.values["passcodeAttempts"])
        }
    }

    func testMissingMigratedPasscodeNeverFallsBackToKnownDefault() throws {
        try withDefaults { defaults in
            defaults.set(true, forKey: "credentialsMigrated")
            defaults.set(true, forKey: "securityTokenEnabled")
            let store = CredentialStore(secure: MemorySecrets(), defaults: defaults)
            XCTAssertNil(store.passcode)
            XCTAssertThrowsError(try store.verifyPasscode("123456"))
        }
    }

    func testTokenRemovalAndPasscodeValidation() throws {
        try withDefaults { defaults in
            let secure = MemorySecrets()
            let store = CredentialStore(secure: secure, defaults: defaults)
            try store.setToken("sample")
            try store.setToken(nil)
            XCTAssertNil(store.token)
            XCTAssertNil(secure.values["authToken"])
            XCTAssertThrowsError(try store.setPasscode("123"))
            XCTAssertThrowsError(try store.setPasscode("abcdef"))
            XCTAssertThrowsError(try store.setPasscode("๑๒๓๔๕๖"))
        }
    }

    func testLocalSessionCheckRejectsExpiredMalformedAndOutOfRangeClaims() throws {
        func token(_ claims: [String: Any]) throws -> String {
            let encoded = try JSONSerialization.data(withJSONObject: claims).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            return "header.\(encoded).test-signature"
        }
        let api = APIService()
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(api.localSessionAccountID(token: try token(["admin_id": 3, "exp": 2000]), now: now), 3)
        XCTAssertNil(api.localSessionAccountID(token: try token(["admin_id": 3, "exp": 1000]), now: now))
        XCTAssertNil(api.localSessionAccountID(token: try token(["admin_id": 1e50, "exp": 2000]), now: now))
        XCTAssertNil(api.localSessionAccountID(token: "invalid", now: now))
        XCTAssertNil(api.localSessionAccountID(token: try token(["admin_id": 3]), now: now))
    }

    func testKeychainRoundTripUpdateAndScopedDeletion() throws {
        let secure = KeychainValueStore(service: "com.dorminet.tests.\(UUID().uuidString)")
        defer {
            try? secure.write(nil, key: "one")
            try? secure.write(nil, key: "two")
        }
        try secure.write(Data("old".utf8), key: "one")
        try secure.write(Data("new".utf8), key: "one")
        try secure.write(Data("keep".utf8), key: "two")
        XCTAssertEqual(try secure.read("one"), Data("new".utf8))
        try secure.write(nil, key: "one")
        XCTAssertNil(try secure.read("one"))
        XCTAssertEqual(try secure.read("two"), Data("keep".utf8))
    }
}

@MainActor
private final class MemorySecrets: SecureValueStore {
    var values: [String: Data] = [:]
    var failWrites = false
    func read(_ key: String) throws -> Data? { values[key] }
    func write(_ data: Data?, key: String) throws {
        if failWrites { throw CredentialError.storage(errSecInteractionNotAllowed) }
        values[key] = data
    }
}
