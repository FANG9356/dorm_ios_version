import Foundation

struct SyncCheckpoint {
    let accountID: Int
    let defaults: UserDefaults

    private func key(_ suffix: String) -> String { "sync.account.\(accountID).\(suffix)" }
    var version: Int {
        get { defaults.integer(forKey: key("version")) }
        nonmutating set { defaults.set(newValue, forKey: key("version")) }
    }
    var pending: Bool {
        get { defaults.bool(forKey: key("pending")) }
        nonmutating set { defaults.set(newValue, forKey: key("pending")) }
    }
    var revision: String { defaults.string(forKey: key("revision")) ?? "" }
    func markChanged() {
        pending = true
        defaults.set(UUID().uuidString, forKey: key("revision"))
    }
    func reset() {
        version = 0
        pending = false
        defaults.set(UUID().uuidString, forKey: key("revision"))
    }
}
