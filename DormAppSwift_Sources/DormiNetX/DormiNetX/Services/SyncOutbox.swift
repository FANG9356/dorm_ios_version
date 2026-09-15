import Foundation

struct PendingSyncUpload: Codable {
    let baseVersion: Int
    let payload: Data
}

struct SyncOutbox {
    var directory: URL?

    private func fileURL(accountID: Int) throws -> URL {
        guard accountID > 0 else { throw SyncError.sessionChanged }
        let base = try directory ?? FileManager.default.url(for: .applicationSupportDirectory,
                                                            in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("DormiNet/SyncOutbox", isDirectory: true)
        return base.appendingPathComponent("account_\(accountID).json")
    }

    func load(accountID: Int) throws -> PendingSyncUpload? {
        let url = try fileURL(accountID: accountID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(PendingSyncUpload.self, from: Data(contentsOf: url))
    }

    func save(_ upload: PendingSyncUpload, accountID: Int) throws {
        let url = try fileURL(accountID: accountID)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(upload).write(to: url, options: .atomic)
    }

    func remove(accountID: Int) throws {
        let url = try fileURL(accountID: accountID)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
