import Foundation
import SwiftData
import SwiftUI
import Combine
import CryptoKit

enum SyncState: Equatable {
    case idle
    case preparing
    case uploading
    case downloading
    case applying
    case completed
    case failed(String)
}

enum SyncOperation: Equatable {
    case idle
    case autoPush
    case manualPull
    case autoPull
}

struct SyncEnvelope: Codable {
    var snapshotID: String
    var accountID: Int
    var version: Int
    var createdAt: Date
    var deviceID: String
    var rooms: [RoomSnapshot]
    var tenants: [TenantSnapshot]
    var payments: [PaymentSnapshot]
    var paymentTransactions: [PaymentTransactionSnapshot]? = nil
    var financialReceipts: [FinancialReceiptSnapshot]? = nil
    var maintenance: [MaintenanceSnapshot]
    var roomTypes: [RoomTypeSnapshot]
    var logs: [SystemLogSnapshot]
}

struct RoomSnapshot: Codable, Identifiable {
    var id: UUID
    var serverId: Int?
    var roomNumber: String
    var roomType: String
    var lastUpdated: Date
}

struct TenantSnapshot: Codable, Identifiable {
    var id: UUID
    var serverId: Int?
    var prefix: String
    var firstName: String
    var lastName: String
    var roomNumber: String
    var status: String
    var nationalID: String
    var phone: String
    var address: String
    var moveInDate: String
    var contractEndDate: String
    var deposit: Double
    var bookingStatus: String
    var bookingEndDate: String?
    var paymentMethod: String
    var paymentChannel: String?
    var installmentMonths: Int?
    var installmentAmount: Double?
    var indefiniteContract: Int
    var bookingSlips: [String]
    var additionalAppliances: String
    var additionalApplianceFee: Double
    var additionalDetails: String
    var lastUpdated: Date
}

struct PaymentSnapshot: Codable, Identifiable {
    var id: UUID
    var serverId: Int?
    var userId: Int
    var roomNumber: String
    var rentFee: Double
    var waterFee: Double
    var electricFee: Double
    var commonFee: Double
    var lateFee: Double
    var applianceFee: Double
    var amount: Double
    var month: String
    var paymentDate: String
    var method: String
    var slipPath: String
    var waterMeterPrev: Double
    var waterMeterCurr: Double
    var electricMeterPrev: Double
    var electricMeterCurr: Double
    var paymentPlan: String
    var installmentPhase: Int
    var dueDate: String
    var paymentStatus: String
    var slipPathArray: [String]
    var paidAmount: Double
    var lastUpdated: Date
    var depositFee: Double? = nil
}

struct PaymentTransactionSnapshot: Codable, Identifiable {
    var id: UUID
    var paymentID: UUID
    var amount: Double
    var occurredAt: Date
    var method: String
    var kind: String
    var note: String
    var slipPaths: [String]
    var source: String
    var lastUpdated: Date
}

struct FinancialReceiptSnapshot: Codable, Identifiable {
    var id: UUID
    var transactionID: UUID
    var paymentID: UUID
    var receiptNumber: String
    var userID: Int
    var roomNumber: String
    var billingMonth: String
    var invoiceAmount: Double
    var receivedAmount: Double
    var balanceAfter: Double
    var method: String
    var slipPaths: [String]
    var issuedAt: Date
    var lastUpdated: Date
}

struct MaintenanceSnapshot: Codable, Identifiable {
    var id: UUID
    var serverId: Int?
    var roomNumber: String
    var issue: String
    var status: String
    var cost: Double
    var reportedAt: String
    var resolvedAt: String
    var paymentMethod: String
    var slipPath: String
    var issueImage: String
    var quoteApprovedAt: String? = nil
    var lastUpdated: Date
}

struct RoomTypeSnapshot: Codable, Identifiable {
    var id: UUID
    var serverId: Int?
    var name: String
    var price: Double
    var waterFee: Double
    var electricFee: Double
    var commonFee: Double
    var lateFee: Double
    var lastUpdated: Date
}

struct SystemLogSnapshot: Codable, Identifiable {
    var id: UUID
    var action: String
    var details: String
    var timestamp: Date
}

struct LocalBackupEnvelope: Codable {
    var formatVersion: Int = 2
    var snapshot: SyncEnvelope
    var slipFiles: [LocalBackupFilePayload]
    var appBackgroundKind: String?
    var appBackgroundFile: LocalBackupFilePayload?
}

struct LocalBackupFilePayload: Codable {
    var fileName: String
    var data: Data
}

struct SyncLatestResponse: Decodable {
    var status: String
    var hasSnapshot: Bool
    var version: Int?
    var checksum: String?
    var payload: SyncEnvelope?
    var payloadBase64: String?

    enum CodingKeys: String, CodingKey {
        case status
        case hasSnapshot = "has_snapshot"
        case version
        case checksum
        case payload
        case payloadBase64 = "payload_base64"
    }
}

struct SyncMetaResponse: Decodable {
    var status: String
    var syncProtocol: Int?
    var hasSnapshot: Bool
    var accountID: Int?
    var email: String?
    var version: Int?
    var createdAt: Date?
    var createdByAdminID: Int?
    var deviceID: String?
    var checksum: String?
    var size: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case syncProtocol = "sync_protocol"
        case hasSnapshot = "has_snapshot"
        case accountID = "account_id"
        case email
        case version
        case createdAt = "created_at"
        case createdByAdminID = "created_by_admin_id"
        case deviceID = "device_id"
        case checksum
        case size
    }
}

struct SyncPushResponse: Decodable {
    var status: String
    var version: Int
    var checksum: String
}

@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    private let api: APIService
    private let defaults: UserDefaults
    private let outbox: SyncOutbox

    init(api: APIService? = nil, defaults: UserDefaults = .standard, outbox: SyncOutbox? = nil) {
        self.api = api ?? .shared
        self.defaults = defaults
        self.outbox = outbox ?? SyncOutbox()
    }

    private var accountID: Int { defaults.integer(forKey: "adminID") }
    private var checkpoint: SyncCheckpoint { SyncCheckpoint(accountID: accountID, defaults: defaults) }
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var state: SyncState = .idle
    @Published var operation: SyncOperation = .idle
    @Published var message: String = ""

    private let recentRemoteAutoPullWindow: TimeInterval = 120
    
    @MainActor
    func syncWithGoBackend(modelContext: ModelContext) async {
        if hasDirtyLocalChanges() || hasDirtyRecords(modelContext) {
            await autoPushLocalChanges(modelContext: modelContext)
        } else {
            await pullLatestSnapshot(modelContext: modelContext)
        }
    }

    func autoPushLocalChanges(modelContext: ModelContext) async {
        markLocalChangesPending()
        guard !isSyncing else { return }
        
        isSyncing = true
        operation = .autoPush
        defer {
            isSyncing = false
            operation = .idle
            if case .completed = state {
                message = "บันทึกขึ้น cloud แล้ว"
            }
        }
        
        do {
            state = .preparing
            message = "กำลังบันทึกขึ้น cloud"

            let startingAccount = accountID
            repeat {
                do {
                    try await pushCurrentSnapshot(modelContext: modelContext)
                } catch SyncError.conflict {
                    // LINE and another device can publish a newer snapshot while
                    // this device still has unsent edits. Pull that snapshot and
                    // rebase the dirty records instead of leaving the user on a
                    // conflict screen where the new LINE record never appears.
                    state = .downloading
                    message = "กำลังรวมข้อมูลใหม่จาก LINE กับข้อมูลในเครื่อง"
                    print("ℹ️ Sync conflict detected; rebasing pending local records")
                    try await fetchAndApplyLatestSnapshot(
                        modelContext: modelContext,
                        onlyIfRecent: false,
                        silentWhenUnchanged: false
                    )
                }
            } while accountID == startingAccount && checkpoint.pending
            lastSyncTime = Date()
            state = .completed
        } catch {
            let text = error.localizedDescription
            print("❌ Automatic sync failed: \(text)")
            state = .failed(text)
            message = text
        }
    }

    func pushCurrentLocalState(modelContext: ModelContext, reason: String = "บันทึกข้อมูลล่าสุด") async {
        await autoPushLocalChanges(modelContext: modelContext)
    }

    @MainActor
    func pullLatestSnapshot(modelContext: ModelContext) async {
        guard !isSyncing else { return }

        isSyncing = true
        operation = .manualPull

        do {
            if hasDirtyLocalChanges(), !hasDirtyRecords(modelContext) {
                // A stale pending flag/outbox must not permanently block a
                // manual recovery when every local record is already clean.
                try outbox.remove(accountID: accountID)
                checkpoint.pending = false
            }

            state = .downloading
            message = "กำลังดึงข้อมูลล่าสุด"
            try await fetchAndApplyLatestSnapshot(modelContext: modelContext, onlyIfRecent: false, silentWhenUnchanged: false)
            lastSyncTime = Date()
            state = .completed
        } catch {
            let text = error.localizedDescription
            state = .failed(text)
            message = text
        }

        isSyncing = false
        operation = .idle
        if case .completed = state, message.isEmpty {
            message = "ดึงข้อมูลล่าสุดแล้ว"
        }
        // A save can occur while a pull is awaiting the network. The save
        // marks the checkpoint pending, but its immediate push returns because
        // this pull owns the sync slot. Drain that pending edit now instead of
        // leaving it local until the user manually syncs again.
        if hasDirtyLocalChanges() || hasDirtyRecords(modelContext) {
            await autoPushLocalChanges(modelContext: modelContext)
        }
    }

    func autoPullRecentRemoteIfNeeded(modelContext: ModelContext) async {
        guard !isSyncing else { return }
        if hasDirtyLocalChanges() || hasDirtyRecords(modelContext) {
            await autoPushLocalChanges(modelContext: modelContext)
            return
        }
        guard await shouldAutoPullRemoteSnapshot() else { return }
        guard !isSyncing, !hasDirtyLocalChanges() else { return }

        isSyncing = true
        operation = .autoPull

        do {
            state = .downloading
            try await fetchAndApplyLatestSnapshot(modelContext: modelContext, onlyIfRecent: true, silentWhenUnchanged: true)
        } catch {
            state = .failed(error.localizedDescription)
        }

        isSyncing = false
        operation = .idle
        if hasDirtyLocalChanges() || hasDirtyRecords(modelContext) {
            await autoPushLocalChanges(modelContext: modelContext)
        }
    }

    func replaceWithRemoteSnapshot(modelContext: ModelContext, backupURL: URL) async throws {
        guard !isSyncing else { throw SyncError.busy }
        isSyncing = true
        operation = .manualPull
        defer { isSyncing = false; operation = .idle }
        do {
            let startingAccount = accountID
            let token = api.authToken
            let revision = checkpoint.revision
            let content = try contentSignature(buildSnapshot(modelContext: modelContext))
            state = .downloading
            let data = try await api.fetchLatestSyncSnapshot()
            guard startingAccount == accountID, token == api.authToken else { throw SyncError.sessionChanged }
            guard revision == checkpoint.revision,
                  content == (try contentSignature(buildSnapshot(modelContext: modelContext))) else { throw SyncError.localChanges }
            let response = try decoder().decode(SyncLatestResponse.self, from: data)
            guard response.hasSnapshot, let raw = response.payloadBase64,
                  let payload = Data(base64Encoded: raw), let checksum = response.checksum,
                  let version = response.version, version > 0 else { throw SyncError.invalidServerResponse }
            try verifyChecksum(payload: payload, checksum: checksum)
            let snapshot = try decoder().decode(SyncEnvelope.self, from: payload)
            try validateSnapshot(snapshot)
            // This path is only called after explicit confirmation, and never without a recovery copy.
            try exportLocalBackupData(modelContext: modelContext).write(to: backupURL, options: .atomic)
            try outbox.remove(accountID: accountID)
            try applySnapshot(snapshot, modelContext: modelContext)
            checkpoint.version = version
            lastSyncTime = Date()
            state = .completed
            message = "ใช้ข้อมูลล่าสุดแล้ว และเก็บข้อมูลเดิมเป็นไฟล์สำรองไว้แล้ว"
        } catch {
            state = .failed(error.localizedDescription)
            message = error.localizedDescription
            throw error
        }
    }

    func exportLocalBackupData(modelContext: ModelContext) throws -> Data {
        let snapshot = try buildSnapshot(modelContext: modelContext)
        let backup = LocalBackupEnvelope(
            snapshot: snapshot,
            slipFiles: collectSlipFiles(from: snapshot),
            appBackgroundKind: UserDefaults.standard.string(forKey: AppBackgroundManager.kindKey),
            appBackgroundFile: collectAppBackgroundFile()
        )
        return try encoded(backup)
    }

    func restoreLocalBackupData(_ data: Data, modelContext: ModelContext) throws {
        guard !isSyncing else { throw SyncError.busy }
        let snapshot: SyncEnvelope

        if let backup = try? decoder().decode(LocalBackupEnvelope.self, from: data) {
            guard backup.formatVersion == 2, backup.snapshot.accountID == accountID else {
                throw SyncError.invalidBackup
            }
            try validateSnapshot(backup.snapshot)
            try restoreBackupFiles(backup)
            snapshot = backup.snapshot
        } else {
            snapshot = try decoder().decode(SyncEnvelope.self, from: data)
        }

        guard snapshot.accountID == accountID else { throw SyncError.invalidBackup }
        try validateSnapshot(snapshot)
        try outbox.remove(accountID: accountID)
        try applySnapshot(snapshot, modelContext: modelContext)
        checkpoint.markChanged()
        lastSyncTime = Date()
        state = .completed
        message = "กู้คืนข้อมูลในเครื่องเรียบร้อยแล้ว"
    }

    private func hasDirtyLocalChanges() -> Bool {
        checkpoint.pending
    }

    @MainActor
    private func hasDirtyRecords(_ context: ModelContext) -> Bool {
        do {
            let pRoomDirty = #Predicate<Room> { $0.isDirty == true }
            if try context.fetchCount(FetchDescriptor(predicate: pRoomDirty)) > 0 { return true }
            let pRoomDeleted = #Predicate<Room> { $0.isDeletedLocally == true }
            if try context.fetchCount(FetchDescriptor(predicate: pRoomDeleted)) > 0 { return true }
            
            let pUserDirty = #Predicate<DormUser> { $0.isDirty == true }
            if try context.fetchCount(FetchDescriptor(predicate: pUserDirty)) > 0 { return true }
            let pUserDeleted = #Predicate<DormUser> { $0.isDeletedLocally == true }
            if try context.fetchCount(FetchDescriptor(predicate: pUserDeleted)) > 0 { return true }
            
            let pPaymentDirty = #Predicate<Payment> { $0.isDirty == true }
            if try context.fetchCount(FetchDescriptor(predicate: pPaymentDirty)) > 0 { return true }
            let pPaymentDeleted = #Predicate<Payment> { $0.isDeletedLocally == true }
            if try context.fetchCount(FetchDescriptor(predicate: pPaymentDeleted)) > 0 { return true }
            
            let pTransaction = #Predicate<PaymentTransaction> { $0.isDirty == true }
            if try context.fetchCount(FetchDescriptor(predicate: pTransaction)) > 0 { return true }
            
            let pReceipt = #Predicate<FinancialReceipt> { $0.isDirty == true }
            if try context.fetchCount(FetchDescriptor(predicate: pReceipt)) > 0 { return true }
            
            let pMaintenanceDirty = #Predicate<Maintenance> { $0.isDirty == true }
            if try context.fetchCount(FetchDescriptor(predicate: pMaintenanceDirty)) > 0 { return true }
            let pMaintenanceDeleted = #Predicate<Maintenance> { $0.isDeletedLocally == true }
            if try context.fetchCount(FetchDescriptor(predicate: pMaintenanceDeleted)) > 0 { return true }
            
            let pRoomType = #Predicate<RoomType> { $0.isDirty == true }
            if try context.fetchCount(FetchDescriptor(predicate: pRoomType)) > 0 { return true }
            
            return false
        } catch { 
            return true 
        }
    }

    private func shouldAutoPullRemoteSnapshot() async -> Bool {
        do {
            let startingAccount = accountID
            let token = api.authToken
            let data = try await api.fetchSyncMetadata()
            guard accountID == startingAccount, api.authToken == token else { return false }
            let meta = try decoder().decode(SyncMetaResponse.self, from: data)
            guard meta.hasSnapshot, let remoteVersion = meta.version else { return false }

            let currentVersion = checkpoint.version
            guard remoteVersion > currentVersion else { return false }
            guard meta.deviceID != deviceID() else { return false }

            if let createdAt = meta.createdAt {
                guard Date().timeIntervalSince(createdAt) <= recentRemoteAutoPullWindow else { return false }
            }

            if let remoteEmail = meta.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !remoteEmail.isEmpty {
                let localEmail = (api.currentEmail ?? defaults.string(forKey: "userEmail") ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                guard localEmail.isEmpty || localEmail == remoteEmail else { return false }
            }

            return true
        } catch {
            return false
        }
    }

    private func markLocalChangesPending() {
        checkpoint.markChanged()
    }

    func resetCheckpoint() throws {
        guard !isSyncing else { throw SyncError.busy }
        try outbox.remove(accountID: accountID)
        checkpoint.reset()
    }

    private func buildSnapshot(modelContext: ModelContext) throws -> SyncEnvelope {
        let accountID = self.accountID
        let version = checkpoint.version + 1

        let snapshot = SyncEnvelope(
            snapshotID: UUID().uuidString,
            accountID: accountID,
            version: version,
            createdAt: Date(),
            deviceID: deviceID(),
            rooms: try modelContext.fetch(FetchDescriptor<Room>()).filter { !$0.isDeletedLocally }.map {
                RoomSnapshot(id: $0.id, serverId: $0.serverId, roomNumber: $0.roomNumber, roomType: $0.roomType, lastUpdated: $0.lastUpdated)
            },
            tenants: try modelContext.fetch(FetchDescriptor<DormUser>()).filter { !$0.isDeletedLocally }.map {
                TenantSnapshot(id: $0.id, serverId: $0.serverId, prefix: $0.prefix, firstName: $0.firstName, lastName: $0.lastName, roomNumber: $0.roomNumber, status: $0.status, nationalID: $0.nationalID, phone: $0.phone, address: $0.address, moveInDate: $0.moveInDate, contractEndDate: $0.contractEndDate, deposit: $0.deposit, bookingStatus: $0.bookingStatus, bookingEndDate: $0.bookingEndDate, paymentMethod: $0.paymentMethod, paymentChannel: $0.paymentChannel, installmentMonths: $0.installmentMonths, installmentAmount: $0.installmentAmount, indefiniteContract: $0.indefiniteContract, bookingSlips: $0.bookingSlips, additionalAppliances: $0.additionalAppliances, additionalApplianceFee: $0.additionalApplianceFee, additionalDetails: $0.additionalDetails, lastUpdated: $0.lastUpdated)
            },
            payments: try modelContext.fetch(FetchDescriptor<Payment>()).filter { !$0.isDeletedLocally }.map {
                PaymentSnapshot(id: $0.id, serverId: $0.serverId, userId: $0.userId, roomNumber: $0.roomNumber, rentFee: $0.rentFee, waterFee: $0.waterFee, electricFee: $0.electricFee, commonFee: $0.commonFee, lateFee: $0.lateFee, applianceFee: $0.applianceFee, amount: $0.amount, month: $0.month, paymentDate: $0.paymentDate, method: $0.method, slipPath: $0.slipPath, waterMeterPrev: $0.waterMeterPrev, waterMeterCurr: $0.waterMeterCurr, electricMeterPrev: $0.electricMeterPrev, electricMeterCurr: $0.electricMeterCurr, paymentPlan: $0.paymentPlan, installmentPhase: $0.installmentPhase, dueDate: $0.dueDate, paymentStatus: $0.paymentStatus, slipPathArray: $0.slipPathArray, paidAmount: $0.paidAmount, lastUpdated: $0.lastUpdated, depositFee: $0.depositFee)
            },
            paymentTransactions: try modelContext.fetch(FetchDescriptor<PaymentTransaction>()).map {
                PaymentTransactionSnapshot(id: $0.id, paymentID: $0.paymentID, amount: $0.amount, occurredAt: $0.occurredAt, method: $0.method, kind: $0.kind, note: $0.note, slipPaths: $0.slipPaths, source: $0.source, lastUpdated: $0.lastUpdated)
            },
            financialReceipts: try modelContext.fetch(FetchDescriptor<FinancialReceipt>()).map {
                FinancialReceiptSnapshot(id: $0.id, transactionID: $0.transactionID, paymentID: $0.paymentID, receiptNumber: $0.receiptNumber, userID: $0.userID, roomNumber: $0.roomNumber, billingMonth: $0.billingMonth, invoiceAmount: $0.invoiceAmount, receivedAmount: $0.receivedAmount, balanceAfter: $0.balanceAfter, method: $0.method, slipPaths: $0.slipPaths, issuedAt: $0.issuedAt, lastUpdated: $0.lastUpdated)
            },
            maintenance: try modelContext.fetch(FetchDescriptor<Maintenance>()).filter { !$0.isDeletedLocally }.map {
                MaintenanceSnapshot(id: $0.id, serverId: $0.serverId, roomNumber: $0.roomNumber, issue: $0.issue, status: $0.status, cost: $0.cost, reportedAt: $0.reportedAt, resolvedAt: $0.resolvedAt, paymentMethod: $0.paymentMethod, slipPath: $0.slipPath, issueImage: $0.issueImage, quoteApprovedAt: $0.quoteApprovedAt, lastUpdated: $0.lastUpdated)
            },
            roomTypes: try modelContext.fetch(FetchDescriptor<RoomType>()).map {
                RoomTypeSnapshot(id: $0.id, serverId: $0.serverId, name: $0.name, price: $0.price, waterFee: $0.waterFee, electricFee: $0.electricFee, commonFee: $0.commonFee, lateFee: $0.lateFee, lastUpdated: $0.lastUpdated)
            },
            logs: try modelContext.fetch(FetchDescriptor<LocalSystemLog>()).map {
                SystemLogSnapshot(id: $0.id, action: $0.action, details: $0.details, timestamp: $0.timestamp)
            }
        )
        try validateSnapshot(snapshot)
        return snapshot
    }

    private func collectSlipFiles(from snapshot: SyncEnvelope) -> [LocalBackupFilePayload] {
        let rawPaths = mediaCandidates(from: snapshot)

        var seen = Set<String>()
        return rawPaths.compactMap { path -> LocalBackupFilePayload? in
            guard let url = SlipImageManager.url(for: path),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }

            let fileName = url.lastPathComponent
            guard !fileName.isEmpty, seen.insert(fileName).inserted,
                  let data = try? Data(contentsOf: url) else {
                return nil
            }

            return LocalBackupFilePayload(fileName: fileName, data: data)
        }
    }

    private func collectAppBackgroundFile() -> LocalBackupFilePayload? {
        let kind = UserDefaults.standard.string(forKey: AppBackgroundManager.kindKey) ?? AppBackgroundKind.system.rawValue
        guard kind != AppBackgroundKind.system.rawValue,
              let fileName = UserDefaults.standard.string(forKey: AppBackgroundManager.fileNameKey),
              let url = AppBackgroundManager.url(for: fileName),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return LocalBackupFilePayload(fileName: url.lastPathComponent, data: data)
    }

    private func restoreBackupFiles(_ backup: LocalBackupEnvelope) throws {
        for file in backup.slipFiles {
            _ = try SlipImageManager.restoreImageData(file.data, fileName: file.fileName)
        }

        if let background = backup.appBackgroundFile,
           let kind = backup.appBackgroundKind,
           kind != AppBackgroundKind.system.rawValue {
            let fileName = try AppBackgroundManager.restoreFileData(background.data, fileName: background.fileName)
            UserDefaults.standard.set(kind, forKey: AppBackgroundManager.kindKey)
            UserDefaults.standard.set(fileName, forKey: AppBackgroundManager.fileNameKey)
            UserDefaults.standard.set(UUID().uuidString, forKey: AppBackgroundManager.updateTokenKey)
        }
    }

    private func pushCurrentSnapshot(modelContext: ModelContext) async throws {
        guard accountID > 0, let token = api.authToken, !token.isEmpty else { throw SyncError.sessionChanged }
        let sentCheckpoint = checkpoint
        let metadata = try decoder().decode(SyncMetaResponse.self, from: await api.fetchSyncMetadata())
        guard accountID == sentCheckpoint.accountID, api.authToken == token else { throw SyncError.sessionChanged }
        guard (metadata.syncProtocol ?? 0) >= 2 else { throw SyncError.serverUpgradeRequired }
        let revision = sentCheckpoint.revision
        let upload: PendingSyncUpload
        if let pending = try outbox.load(accountID: accountID) {
            upload = pending
        } else {
            upload = PendingSyncUpload(baseVersion: sentCheckpoint.version,
                                       payload: try encoded(buildSnapshot(modelContext: modelContext)))
            try outbox.save(upload, accountID: accountID)
        }
        let snapshot = try decoder().decode(SyncEnvelope.self, from: upload.payload)
        guard snapshot.accountID == accountID else { throw SyncError.invalidBackup }
        let content = try contentSignature(snapshot)
        let payload = upload.payload
        state = .uploading
        message = "กำลังบันทึกขึ้น cloud"
        let responseData = try await api.pushSyncSnapshot(payload: payload, deviceID: snapshot.deviceID, baseVersion: upload.baseVersion)
        guard accountID == sentCheckpoint.accountID, api.authToken == token else { throw SyncError.sessionChanged }
        let response = try JSONDecoder().decode(SyncPushResponse.self, from: responseData)
        guard response.status == "success", response.version == upload.baseVersion + 1 else {
            throw SyncError.invalidServerResponse
        }
        try verifyChecksum(payload: payload, checksum: response.checksum)
        sentCheckpoint.version = response.version
        try outbox.remove(accountID: accountID)
        // Only acknowledge the exact state that was uploaded. Edits during the await stay queued.
        let currentContent = try contentSignature(buildSnapshot(modelContext: modelContext))
        if revision == sentCheckpoint.revision && content == currentContent {
            try markAllClean(modelContext: modelContext)
        }
    }

    private func fetchAndApplyLatestSnapshot(modelContext: ModelContext, onlyIfRecent: Bool, silentWhenUnchanged: Bool) async throws {
        let startingAccount = accountID
        let token = api.authToken
        let revision = checkpoint.revision
        let content = try contentSignature(buildSnapshot(modelContext: modelContext))
        let data = try await api.fetchLatestSyncSnapshot()
        guard accountID == startingAccount, api.authToken == token else { throw SyncError.sessionChanged }
        guard revision == checkpoint.revision,
              content == (try contentSignature(buildSnapshot(modelContext: modelContext))) else { throw SyncError.localChanges }
        let response = try decoder().decode(SyncLatestResponse.self, from: data)
        guard response.hasSnapshot, let snapshot = response.payload else {
            if !silentWhenUnchanged { message = "ยังไม่มีข้อมูลบน cloud" }
            return
        }

        guard let version = response.version else { throw SyncError.invalidServerResponse }
        let payload: Data
        if let raw = response.payloadBase64 {
            guard let decoded = Data(base64Encoded: raw) else { throw SyncError.invalidServerResponse }
            payload = decoded
        } else { payload = try encoded(snapshot) }
        if let checksum = response.checksum {
            try verifyChecksum(payload: payload, checksum: checksum)
        }
        let verifiedSnapshot = try decoder().decode(SyncEnvelope.self, from: payload)

        let currentVersion = checkpoint.version
        if version < currentVersion {
            throw SyncError.invalidServerResponse
        }

        if !onlyIfRecent, hasDirtyRecords(modelContext) {
            try await rebasePendingLocalChanges(
                onto: verifiedSnapshot,
                remoteVersion: version,
                expectedRevision: revision,
                expectedContent: content,
                modelContext: modelContext
            )
            return
        }

        let remoteContent = try contentSignature(verifiedSnapshot)
        let localContent = try contentSignature(buildSnapshot(modelContext: modelContext))
        if version == currentVersion && remoteContent == localContent {
            if !silentWhenUnchanged { message = "ข้อมูลเป็นล่าสุดแล้ว" }
            return
        }
        if onlyIfRecent && version == currentVersion { return }

        if onlyIfRecent {
            guard snapshot.deviceID != deviceID() else { return }
            guard Date().timeIntervalSince(snapshot.createdAt) <= recentRemoteAutoPullWindow else { return }
        }

        state = .applying
        message = onlyIfRecent ? "รับข้อมูลใหม่จากเครื่องอื่น" : "เขียนทับข้อมูลในเครื่อง"
        try applySnapshot(verifiedSnapshot, modelContext: modelContext)
        await downloadMissingRemoteMedia(from: verifiedSnapshot)
        checkpoint.version = version
        if !onlyIfRecent {
            message = version == currentVersion ? "ซ่อมข้อมูลในเครื่องจาก cloud แล้ว" : "ดึงข้อมูลล่าสุดแล้ว"
        }
    }

    private func rebasePendingLocalChanges(
        onto remote: SyncEnvelope,
        remoteVersion: Int,
        expectedRevision: String,
        expectedContent: Data,
        modelContext: ModelContext
    ) async throws {
        let local = try buildSnapshot(modelContext: modelContext)
        var merged = remote

        let dirtyRooms = try modelContext.fetch(FetchDescriptor<Room>()).filter { $0.isDirty || $0.isDeletedLocally }
        let dirtyTenants = try modelContext.fetch(FetchDescriptor<DormUser>()).filter { $0.isDirty || $0.isDeletedLocally }
        let dirtyPayments = try modelContext.fetch(FetchDescriptor<Payment>()).filter { $0.isDirty || $0.isDeletedLocally }
        let dirtyTransactions = try modelContext.fetch(FetchDescriptor<PaymentTransaction>()).filter(\.isDirty)
        let dirtyReceipts = try modelContext.fetch(FetchDescriptor<FinancialReceipt>()).filter(\.isDirty)
        let dirtyMaintenance = try modelContext.fetch(FetchDescriptor<Maintenance>()).filter { $0.isDirty || $0.isDeletedLocally }
        let dirtyRoomTypes = try modelContext.fetch(FetchDescriptor<RoomType>()).filter(\.isDirty)

        let remoteMaintenance = Dictionary(uniqueKeysWithValues: remote.maintenance.map { ($0.id, $0) })
        let mergeableDirtyMaintenance = dirtyMaintenance.filter { item in
            guard !item.isDeletedLocally, let remoteItem = remoteMaintenance[item.id] else { return true }
            let hasCost = item.cost > 0 || ["รออนุมัติค่าใช้จ่าย", "ปฏิเสธค่าใช้จ่าย", "รอตรวจสอบชำระเงิน"].contains(item.status)
            let remoteStatus = remoteItem.status.isEmpty ? "รอดำเนินการ" : remoteItem.status
            let localStatus = item.status.isEmpty ? "รอดำเนินการ" : item.status
            return MaintenanceWorkflow.canTransition(
                from: remoteStatus,
                to: localStatus,
                hasCost: hasCost
            )
        }

        merged.rooms = mergeSnapshots(remote: remote.rooms, local: local.rooms,
                                      changed: Set(dirtyRooms.filter { !$0.isDeletedLocally }.map(\.id)),
                                      deleted: Set(dirtyRooms.filter(\.isDeletedLocally).map(\.id)))
        merged.tenants = mergeSnapshots(remote: remote.tenants, local: local.tenants,
                                        changed: Set(dirtyTenants.filter { !$0.isDeletedLocally }.map(\.id)),
                                        deleted: Set(dirtyTenants.filter(\.isDeletedLocally).map(\.id)))
        merged.payments = mergeSnapshots(remote: remote.payments, local: local.payments,
                                         changed: Set(dirtyPayments.filter { !$0.isDeletedLocally }.map(\.id)),
                                         deleted: Set(dirtyPayments.filter(\.isDeletedLocally).map(\.id)))
        merged.paymentTransactions = mergeSnapshots(remote: remote.paymentTransactions ?? [],
                                                     local: local.paymentTransactions ?? [],
                                                     changed: Set(dirtyTransactions.map(\.id)), deleted: [])
        merged.financialReceipts = mergeSnapshots(remote: remote.financialReceipts ?? [],
                                                  local: local.financialReceipts ?? [],
                                                  changed: Set(dirtyReceipts.map(\.id)), deleted: [])
        merged.maintenance = mergeSnapshots(remote: remote.maintenance, local: local.maintenance,
                                            changed: Set(mergeableDirtyMaintenance.filter { !$0.isDeletedLocally }.map(\.id)),
                                            deleted: Set(dirtyMaintenance.filter(\.isDeletedLocally).map(\.id)))
        merged.roomTypes = mergeSnapshots(remote: remote.roomTypes, local: local.roomTypes,
                                          changed: Set(dirtyRoomTypes.map(\.id)), deleted: [])
        merged.logs = mergeSnapshotLogs(remote: remote.logs, local: local.logs)
        merged.snapshotID = UUID().uuidString
        merged.version = remoteVersion + 1
        merged.createdAt = Date()
        merged.deviceID = deviceID()

        try validateSnapshot(merged)
        let mergedPayload = try encoded(merged)
        state = .uploading
        message = "กำลังรวมข้อมูลในเครื่องกับ cloud"
        let responseData = try await api.pushSyncSnapshot(
            payload: mergedPayload,
            deviceID: merged.deviceID,
            baseVersion: remoteVersion
        )
        guard expectedRevision == checkpoint.revision,
              expectedContent == (try contentSignature(buildSnapshot(modelContext: modelContext))) else {
            throw SyncError.localChanges
        }
        let response = try JSONDecoder().decode(SyncPushResponse.self, from: responseData)
        guard response.status == "success", response.version == remoteVersion + 1 else {
            throw SyncError.invalidServerResponse
        }
        try verifyChecksum(payload: mergedPayload, checksum: response.checksum)
        state = .applying
        try applySnapshot(merged, modelContext: modelContext)
        await downloadMissingRemoteMedia(from: merged)
        checkpoint.version = response.version
        try outbox.remove(accountID: accountID)
        message = "รวมข้อมูลในเครื่องกับ cloud แล้ว"
    }

    private func mergeSnapshots<T: Identifiable>(
        remote: [T],
        local: [T],
        changed: Set<T.ID>,
        deleted: Set<T.ID>
    ) -> [T] where T.ID: Hashable {
        var result = remote.filter { !deleted.contains($0.id) && !changed.contains($0.id) }
        result.append(contentsOf: local.filter { changed.contains($0.id) })
        return result
    }

    private func mergeSnapshotLogs(remote: [SystemLogSnapshot], local: [SystemLogSnapshot]) -> [SystemLogSnapshot] {
        var seen = Set(remote.map(\.id))
        return remote + local.filter { seen.insert($0.id).inserted }
    }

    private func downloadMissingRemoteMedia(from snapshot: SyncEnvelope) async {
        let candidates = mediaCandidates(from: snapshot)

        var seen = Set<String>()
        for storedPath in candidates {
            let fileName = URL(fileURLWithPath: storedPath).lastPathComponent
            guard !fileName.isEmpty, seen.insert(fileName).inserted,
                  let localURL = SlipImageManager.url(for: fileName),
                  !FileManager.default.fileExists(atPath: localURL.path) else { continue }
            do {
				let data = try await fetchTenantMediaWithRetry(fileName: fileName)
                _ = try SlipImageManager.restoreImageData(data, fileName: fileName)
            } catch {
                // Records remain usable even if an optional image cannot be downloaded.
            }
        }
    }

	private func fetchTenantMediaWithRetry(fileName: String) async throws -> Data {
		var lastError: Error = URLError(.unknown)
		for attempt in 0..<3 {
			do {
				return try await api.fetchTenantMedia(storedPath: fileName)
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				lastError = error
				if attempt < 2 {
					try await Task.sleep(for: .milliseconds(250 * (attempt + 1)))
				}
			}
		}
		throw lastError
	}

    private func mediaCandidates(from snapshot: SyncEnvelope) -> [String] {
        var paths = snapshot.tenants.flatMap { $0.bookingSlips }
        for payment in snapshot.payments {
            paths.append(contentsOf: payment.slipPathArray)
            if !payment.slipPath.isEmpty && !payment.slipPathArray.contains(payment.slipPath) {
                paths.append(payment.slipPath)
            }
        }
        for transaction in snapshot.paymentTransactions ?? [] {
            paths.append(contentsOf: transaction.slipPaths)
        }
        for maintenance in snapshot.maintenance {
            if !maintenance.slipPath.isEmpty {
                paths.append(maintenance.slipPath)
            }
            paths.append(contentsOf: mediaPaths(in: maintenance.issueImage))
        }
        return paths
    }

    private func mediaPaths(in value: String) -> [String] {
        value.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    private func applySnapshot(_ snapshot: SyncEnvelope, modelContext: ModelContext) throws {
        try validateSnapshot(snapshot)
        for item in try modelContext.fetch(FetchDescriptor<Room>()) { modelContext.delete(item) }
        for item in try modelContext.fetch(FetchDescriptor<DormUser>()) { modelContext.delete(item) }
        for item in try modelContext.fetch(FetchDescriptor<Payment>()) { modelContext.delete(item) }
        for item in try modelContext.fetch(FetchDescriptor<PaymentTransaction>()) { modelContext.delete(item) }
        for item in try modelContext.fetch(FetchDescriptor<FinancialReceipt>()) { modelContext.delete(item) }
        for item in try modelContext.fetch(FetchDescriptor<Maintenance>()) { modelContext.delete(item) }
        for item in try modelContext.fetch(FetchDescriptor<RoomType>()) { modelContext.delete(item) }
        for item in try modelContext.fetch(FetchDescriptor<LocalSystemLog>()) { modelContext.delete(item) }

        for item in snapshot.rooms {
            let room = Room(serverId: item.serverId, roomNumber: item.roomNumber, roomType: item.roomType)
            room.id = item.id
            room.lastUpdated = item.lastUpdated
            modelContext.insert(room)
        }
        for item in snapshot.tenants {
            let user = DormUser(serverId: item.serverId, firstName: item.firstName, lastName: item.lastName)
            user.id = item.id
            user.prefix = item.prefix
            user.roomNumber = item.roomNumber
            user.status = item.status
            user.nationalID = item.nationalID
            user.phone = item.phone
            user.address = item.address
            user.moveInDate = item.moveInDate
            user.contractEndDate = item.contractEndDate
            user.deposit = item.deposit
            user.bookingStatus = item.bookingStatus
            user.bookingEndDate = item.bookingEndDate ?? ""
            user.paymentMethod = item.paymentMethod
            user.paymentChannel = item.paymentChannel ?? ""
            user.installmentMonths = item.installmentMonths ?? 0
            user.installmentAmount = item.installmentAmount ?? 0
            user.indefiniteContract = item.indefiniteContract
            user.bookingSlips = item.bookingSlips
            user.additionalAppliances = item.additionalAppliances
            user.additionalApplianceFee = item.additionalApplianceFee
            user.additionalDetails = item.additionalDetails
            user.lastUpdated = item.lastUpdated
            modelContext.insert(user)
        }
        for item in snapshot.payments {
            let payment = Payment(serverId: item.serverId, month: item.month, amount: item.amount)
            payment.id = item.id
            payment.userId = item.userId
            payment.roomNumber = item.roomNumber
            payment.rentFee = item.rentFee
            payment.depositFee = item.depositFee ?? 0
            payment.waterFee = item.waterFee
            payment.electricFee = item.electricFee
            payment.commonFee = item.commonFee
            payment.lateFee = item.lateFee
            payment.applianceFee = item.applianceFee
            payment.paymentDate = item.paymentDate
            payment.method = item.method
            payment.slipPath = item.slipPath
            payment.waterMeterPrev = item.waterMeterPrev
            payment.waterMeterCurr = item.waterMeterCurr
            payment.electricMeterPrev = item.electricMeterPrev
            payment.electricMeterCurr = item.electricMeterCurr
            payment.paymentPlan = item.paymentPlan
            payment.installmentPhase = item.installmentPhase
            payment.dueDate = item.dueDate
            payment.paymentStatus = item.paymentStatus
            payment.slipPathArray = item.slipPathArray
            payment.paidAmount = item.paidAmount
            payment.lastUpdated = item.lastUpdated
            modelContext.insert(payment)
        }
        for item in snapshot.paymentTransactions ?? [] {
            let transaction = PaymentTransaction(paymentID: item.paymentID, amount: item.amount, occurredAt: item.occurredAt, method: item.method, source: item.source)
            transaction.id = item.id
            transaction.kind = item.kind
            transaction.note = item.note
            transaction.slipPaths = item.slipPaths
            transaction.lastUpdated = item.lastUpdated
            modelContext.insert(transaction)
        }
        for item in snapshot.financialReceipts ?? [] {
            let receipt = FinancialReceipt(transactionID: item.transactionID, paymentID: item.paymentID, receiptNumber: item.receiptNumber, issuedAt: item.issuedAt)
            receipt.id = item.id
            receipt.userID = item.userID
            receipt.roomNumber = item.roomNumber
            receipt.billingMonth = item.billingMonth
            receipt.invoiceAmount = item.invoiceAmount
            receipt.receivedAmount = item.receivedAmount
            receipt.balanceAfter = item.balanceAfter
            receipt.method = item.method
            receipt.slipPaths = item.slipPaths
            receipt.lastUpdated = item.lastUpdated
            modelContext.insert(receipt)
        }
        for item in snapshot.maintenance {
            let maintenance = Maintenance(serverId: item.serverId, roomNumber: item.roomNumber, issue: item.issue)
            maintenance.id = item.id
            maintenance.status = item.status
            maintenance.cost = item.cost
            maintenance.reportedAt = item.reportedAt
            maintenance.resolvedAt = item.resolvedAt
            maintenance.paymentMethod = item.paymentMethod
            maintenance.slipPath = item.slipPath
            maintenance.issueImage = item.issueImage
            maintenance.quoteApprovedAt = item.quoteApprovedAt ?? ""
            maintenance.lastUpdated = item.lastUpdated
            modelContext.insert(maintenance)
        }
        for item in snapshot.roomTypes {
            let roomType = RoomType(name: item.name, price: item.price)
            roomType.id = item.id
            roomType.serverId = item.serverId
            roomType.waterFee = item.waterFee
            roomType.electricFee = item.electricFee
            roomType.commonFee = item.commonFee
            roomType.lateFee = item.lateFee
            roomType.lastUpdated = item.lastUpdated
            modelContext.insert(roomType)
        }
        for item in snapshot.logs {
            let log = LocalSystemLog(action: item.action, details: item.details)
            log.id = item.id
            log.timestamp = item.timestamp
            modelContext.insert(log)
        }

        do {
            let migratedLegacyBalances = try PaymentLedger.migrateLegacyBalances(in: modelContext)
            try markAllClean(modelContext: modelContext)
            // A legacy snapshot is a valid input, but the generated ledger is
            // new local state and must be uploaded so every device converges on
            // the same transaction and receipt identifiers.
            if migratedLegacyBalances > 0 {
                checkpoint.markChanged()
            }
        }
        catch {
            modelContext.rollback()
            throw error
        }
    }

    private func markAllClean(modelContext: ModelContext) throws {
        for item in try modelContext.fetch(FetchDescriptor<Room>()) {
            if item.isDeletedLocally { modelContext.delete(item) } else { item.isDirty = false }
        }
        for item in try modelContext.fetch(FetchDescriptor<DormUser>()) {
            if item.isDeletedLocally { modelContext.delete(item) } else { item.isDirty = false }
        }
        for item in try modelContext.fetch(FetchDescriptor<Payment>()) {
            if item.isDeletedLocally { modelContext.delete(item) } else { item.isDirty = false }
        }
        for item in try modelContext.fetch(FetchDescriptor<PaymentTransaction>()) { item.isDirty = false }
        for item in try modelContext.fetch(FetchDescriptor<FinancialReceipt>()) { item.isDirty = false }
        for item in try modelContext.fetch(FetchDescriptor<Maintenance>()) {
            if item.isDeletedLocally { modelContext.delete(item) } else { item.isDirty = false }
        }
        for item in try modelContext.fetch(FetchDescriptor<RoomType>()) { item.isDirty = false }
        try modelContext.save()
        checkpoint.pending = false
    }

    private func validateSnapshot(_ snapshot: SyncEnvelope) throws {
        let transactions = snapshot.paymentTransactions ?? []
        let receipts = snapshot.financialReceipts ?? []
        let identifiers = [snapshot.rooms.map(\.id), snapshot.tenants.map(\.id), snapshot.payments.map(\.id),
                           transactions.map(\.id), receipts.map(\.id),
                           snapshot.maintenance.map(\.id), snapshot.roomTypes.map(\.id), snapshot.logs.map(\.id)]
        let paymentIDs = Set(snapshot.payments.map(\.id))
        let transactionsByID = transactions.reduce(into: [UUID: PaymentTransactionSnapshot]()) { result, transaction in
            result[transaction.id] = transaction
        }
        let receiptNumbers = receipts.map(\.receiptNumber)
        guard snapshot.accountID > 0, snapshot.version >= 0,
              identifiers.allSatisfy({ Set($0).count == $0.count }),
              Set(receipts.map(\.transactionID)).count == receipts.count,
              Set(receiptNumbers).count == receiptNumbers.count,
              receiptNumbers.allSatisfy({ !$0.isEmpty }),
              transactions.allSatisfy({ paymentIDs.contains($0.paymentID) && $0.amount.isFinite && $0.amount > 0 }),
              receipts.count == transactions.count,
              receipts.allSatisfy({ receipt in
                  guard let transaction = transactionsByID[receipt.transactionID] else { return false }
                  return paymentIDs.contains(receipt.paymentID) &&
                      receipt.paymentID == transaction.paymentID &&
                      PaymentAmounts.sum([receipt.receivedAmount, -transaction.amount]) == 0 &&
                      receipt.invoiceAmount.isFinite && receipt.receivedAmount.isFinite && receipt.balanceAfter.isFinite &&
                      receipt.invoiceAmount >= 0 && receipt.receivedAmount > 0 && receipt.balanceAfter >= 0
              }) else {
            throw SyncError.invalidBackup
        }
    }

    private func verifyChecksum(payload: Data, checksum: String) throws {
        let digest = SHA256.hash(data: payload)
        let local = digest.map { String(format: "%02x", $0) }.joined()
        guard local == checksum else {
            throw SyncError.checksumMismatch
        }
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: text) else { throw SyncError.invalidServerResponse }
            return date
        }
        return decoder
    }

    private func deviceID() -> String {
        if let existing = UserDefaults.standard.string(forKey: "deviceID"), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "deviceID")
        return id
    }

    private func contentSignature(_ snapshot: SyncEnvelope) throws -> Data {
        var value = snapshot
        value.snapshotID = ""
        value.version = 0
        value.createdAt = Date(timeIntervalSince1970: 0)
        value.rooms.sort { $0.id.uuidString < $1.id.uuidString }
        value.tenants.sort { $0.id.uuidString < $1.id.uuidString }
        value.payments.sort { $0.id.uuidString < $1.id.uuidString }
        value.paymentTransactions?.sort { $0.id.uuidString < $1.id.uuidString }
        value.financialReceipts?.sort { $0.id.uuidString < $1.id.uuidString }
        value.maintenance.sort { $0.id.uuidString < $1.id.uuidString }
        value.roomTypes.sort { $0.id.uuidString < $1.id.uuidString }
        value.logs.sort { $0.id.uuidString < $1.id.uuidString }
        return try encoded(value)
    }
}

enum SyncError: LocalizedError {
    case checksumMismatch
    case invalidServerResponse
    case conflict, updateRequired, serverUpgradeRequired, sessionChanged, localChanges, invalidBackup, busy

    var errorDescription: String? {
        switch self {
        case .checksumMismatch:
            return "ข้อมูล sync ไม่ตรงกับ checksum"
        case .invalidServerResponse:
            return "server ตอบกลับข้อมูล sync ไม่ถูกต้อง"
        case .conflict: return "มีข้อมูลใหม่จากอีกเครื่อง ข้อมูลในเครื่องนี้ยังอยู่ครบ กรุณาสำรองข้อมูลก่อนตรวจสอบรายการที่ต่างกัน"
        case .updateRequired: return "กรุณาอัปเดตแอปก่อนซิงก์ข้อมูล"
        case .serverUpgradeRequired: return "ข้อมูลบันทึกในเครื่องแล้ว รออัปเดตเซิร์ฟเวอร์ซิงก์เวอร์ชันใหม่"
        case .sessionChanged: return "บัญชีเข้าสู่ระบบเปลี่ยนแล้ว กรุณาซิงก์อีกครั้ง"
        case .localChanges: return "มีการแก้ไขระหว่างดาวน์โหลด จึงเก็บข้อมูลในเครื่องไว้ก่อน"
        case .invalidBackup: return "ไฟล์สำรองไม่ตรงกับบัญชีนี้หรือเป็นรูปแบบที่ยังไม่รองรับ"
        case .busy: return "กรุณารอให้การซิงก์เสร็จก่อน"
        }
    }
}
