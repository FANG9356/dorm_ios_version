import Foundation
import Security
import Combine

protocol SecureValueStore {
    func read(_ key: String) throws -> Data?
    func write(_ data: Data?, key: String) throws
}

struct KeychainValueStore: SecureValueStore {
    var service = "com.dorminet.DormiNetX.credentials"

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    func read(_ key: String) throws -> Data? {
        var query = query(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw CredentialError.storage(status) }
        return data
    }

    func write(_ data: Data?, key: String) throws {
        let query = query(key)
        guard let data else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialError.storage(status) }
            return
        }
        let attributes: [String: Any] = [kSecValueData as String: data,
                                        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let insertion = query.merging(attributes) { _, new in new }
            let added = SecItemAdd(insertion as CFDictionary, nil)
            guard added == errSecSuccess else { throw CredentialError.storage(added) }
        } else if status != errSecSuccess { throw CredentialError.storage(status) }
    }
}

@MainActor
final class CredentialStore: ObservableObject {
    static let shared = CredentialStore()
    // No actor-bound cleanup; avoid the Swift 6.2 isolated-deinit runtime crash (swiftlang/swift#85663).
    nonisolated deinit {}
    @Published private(set) var token: String?
    @Published private(set) var passcode: String?
    @Published var errorMessage: String?
    private let secure: any SecureValueStore
    private let defaults: UserDefaults

    init(secure: (any SecureValueStore)? = nil, defaults: UserDefaults = .standard) {
        self.secure = secure ?? KeychainValueStore()
        self.defaults = defaults
        do {
            try migrateLegacyValues()
            token = try self.secure.read("authToken").flatMap { String(data: $0, encoding: .utf8) }
            passcode = try self.secure.read("securityPasscode").flatMap { String(data: $0, encoding: .utf8) }
        } catch { errorMessage = error.localizedDescription }
    }

    private func migrateLegacyValues() throws {
        for key in ["authToken", "securityPasscode", "savedAccountsHistory"] {
            let legacy = key == "savedAccountsHistory" ? defaults.data(forKey: key) : defaults.string(forKey: key)?.data(using: .utf8)
            if let legacy {
                if try secure.read(key) == nil { try secure.write(legacy, key: key) }
                defaults.removeObject(forKey: key)
            }
        }
        // Older builds supplied this default without necessarily persisting it.
        if !defaults.bool(forKey: "credentialsMigrated"), defaults.bool(forKey: "securityTokenEnabled"),
           try secure.read("securityPasscode") == nil {
            try secure.write(Data("123456".utf8), key: "securityPasscode")
        }
        defaults.set(true, forKey: "credentialsMigrated")
    }

    func setToken(_ value: String?) throws {
        if value == nil { token = nil }
        do {
            try secure.write(value?.data(using: .utf8), key: "authToken")
            defaults.removeObject(forKey: "authToken")
            token = value
        } catch { errorMessage = error.localizedDescription; throw error }
    }

    func setPasscode(_ value: String) throws {
        guard value.utf8.count == 6, value.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw CredentialError.invalidPasscode
        }
        do {
            try secure.write(nil, key: "passcodeAttempts")
            try secure.write(Data(value.utf8), key: "securityPasscode")
            defaults.removeObject(forKey: "securityPasscode")
            passcode = value
        } catch { errorMessage = error.localizedDescription; throw error }
    }

    func savedAccountsData() throws -> Data? { try secure.read("savedAccountsHistory") }

    func setSavedAccountsData(_ value: Data?) throws {
        do {
            try secure.write(value, key: "savedAccountsHistory")
            defaults.removeObject(forKey: "savedAccountsHistory")
        } catch { errorMessage = error.localizedDescription; throw error }
    }

    func verifyPasscode(_ candidate: String, now: Date = Date()) throws -> Bool {
        guard let stored = try secure.read("securityPasscode"), !stored.isEmpty else { throw CredentialError.missingPasscode }
        var attempts = try secure.read("passcodeAttempts").map { try JSONDecoder().decode(PasscodeAttempts.self, from: $0) } ?? PasscodeAttempts()
        if let until = attempts.lockedUntil, until > now { throw CredentialError.locked }
        if attempts.lockedUntil != nil { attempts = PasscodeAttempts() }
        if stored == Data(candidate.utf8) {
            try secure.write(nil, key: "passcodeAttempts")
            return true
        }
        attempts.count += 1
        if attempts.count >= 5 { attempts.lockedUntil = now.addingTimeInterval(60) }
        try secure.write(JSONEncoder().encode(attempts), key: "passcodeAttempts")
        if attempts.lockedUntil != nil { throw CredentialError.locked }
        return false
    }

    private struct PasscodeAttempts: Codable {
        var count = 0
        var lockedUntil: Date?
    }
}

enum CredentialError: LocalizedError {
    case storage(OSStatus), invalidPasscode, missingPasscode, locked, expiredSession
    var errorDescription: String? {
        switch self {
        case .storage: return "เข้าถึงที่เก็บข้อมูลลับไม่ได้ กรุณาปลดล็อกเครื่องแล้วลองใหม่"
        case .invalidPasscode: return "กรุณาระบุตัวเลข 0 ถึง 9 ให้ครบ 6 หลัก"
        case .missingPasscode: return "ไม่พบรหัสยืนยันของเครื่องนี้ กรุณาตรวจสอบการตั้งค่าความปลอดภัย"
        case .locked: return "กรอกรหัสผิดหลายครั้ง กรุณารอ 1 นาทีแล้วลองใหม่"
        case .expiredSession: return "เซสชันหมดอายุหรือไม่ถูกต้อง กรุณาเข้าสู่ระบบด้วยอีเมลและรหัสผ่านอีกครั้ง"
        }
    }
}
