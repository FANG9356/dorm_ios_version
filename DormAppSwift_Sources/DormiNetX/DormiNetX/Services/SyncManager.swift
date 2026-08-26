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
    var maintenance: [MaintenanceSnapshot]
    var roomTypes: [RoomTypeSnapshot]
    var logs: [SystemLogSnapshot]
}

struct RoomSnapshot: Codable {
    var id: UUID
    var serverId: Int?
    var roomNumber: String
    var roomType: String
    var lastUpdated: Date
}

struct TenantSnapshot: Codable {
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

struct PaymentSnapshot: Codable {
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
}

struct MaintenanceSnapshot: Codable {
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
    var lastUpdated: Date
}

struct RoomTypeSnapshot: Codable {
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

struct SystemLogSnapshot: Codable {
    var id: UUID
    var action: String
    var details: String
    var timestamp: Date
}

struct SyncLatestResponse: Decodable {
    var status: String
    var hasSnapshot: Bool
    var version: Int?
    var checksum: String?
    var payload: SyncEnvelope?

    enum CodingKeys: String, CodingKey {
        case status
        case hasSnapshot = "has_snapshot"
        case version
        case checksum
        case payload
    }
}

struct SyncMetaResponse: Decodable {
    var status: String
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
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var state: SyncState = .idle
    @Published var operation: SyncOperation = .idle
    @Published var message: String = ""

    private let recentRemoteAutoPullWindow: TimeInterval = 120
    private let pendingLocalChangesKey = "syncHasPendingLocalChanges"
    
    func syncWithGoBackend(modelContext: ModelContext) async {
        if hasDirtyLocalChanges() {
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

            try await pushCurrentSnapshot(modelContext: modelContext)
            lastSyncTime = Date()
            state = .completed
        } catch {
            let text = error.localizedDescription
            state = .failed(text)
            message = text
        }
    }

    func pushCurrentLocalState(modelContext: ModelContext, reason: String = "บันทึกข้อมูลล่าสุด") async {
        markLocalChangesPending()
        guard !isSyncing else { return }

        isSyncing = true
        operation = .autoPush
        defer {
            isSyncing = false
            operation = .idle
            if case .completed = state {
                message = reason
            }
        }

        do {
            state = .preparing
            message = "กำลังบันทึกขึ้น cloud"
            try await pushCurrentSnapshot(modelContext: modelContext)
            lastSyncTime = Date()
            state = .completed
        } catch {
            let text = error.localizedDescription
            state = .failed(text)
            message = text
        }
    }

    func pullLatestSnapshot(modelContext: ModelContext) async {
        guard !isSyncing else { return }

        isSyncing = true
        operation = .manualPull
        defer {
            isSyncing = false
            operation = .idle
            if case .completed = state, message.isEmpty {
                message = "ดึงข้อมูลล่าสุดแล้ว"
            }
        }

        do {
            guard !hasDirtyLocalChanges() else {
                message = "มีข้อมูลในเครื่องที่ยังบันทึกขึ้น cloud อยู่"
                state = .failed(message)
                return
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
    }

    func autoPullRecentRemoteIfNeeded(modelContext: ModelContext) async {
        guard !isSyncing else { return }
        guard !hasDirtyLocalChanges() else { return }
        guard await shouldAutoPullRemoteSnapshot() else { return }

        isSyncing = true
        operation = .autoPull
        defer {
            isSyncing = false
            operation = .idle
        }

        do {
            state = .downloading
            try await fetchAndApplyLatestSnapshot(modelContext: modelContext, onlyIfRecent: true, silentWhenUnchanged: true)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func exportLocalBackupData(modelContext: ModelContext) throws -> Data {
        try encoded(buildSnapshot(modelContext: modelContext))
    }

    func restoreLocalBackupData(_ data: Data, modelContext: ModelContext) throws {
        let snapshot = try decoder().decode(SyncEnvelope.self, from: data)
        try applySnapshot(snapshot, modelContext: modelContext)
        UserDefaults.standard.set(snapshot.version, forKey: "lastSyncVersion")
        lastSyncTime = Date()
        state = .completed
        message = "กู้คืนข้อมูลในเครื่องเรียบร้อยแล้ว"
    }

    private func hasDirtyLocalChanges() -> Bool {
        UserDefaults.standard.bool(forKey: pendingLocalChangesKey)
    }

    private func shouldAutoPullRemoteSnapshot() async -> Bool {
        do {
            let data = try await APIService.shared.fetchSyncMetadata()
            let meta = try decoder().decode(SyncMetaResponse.self, from: data)
            guard meta.hasSnapshot, let remoteVersion = meta.version else { return false }

            let currentVersion = UserDefaults.standard.integer(forKey: "lastSyncVersion")
            guard remoteVersion > currentVersion else { return false }
            guard meta.deviceID != deviceID() else { return false }

            if let createdAt = meta.createdAt {
                guard Date().timeIntervalSince(createdAt) <= recentRemoteAutoPullWindow else { return false }
            }

            if let remoteEmail = meta.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !remoteEmail.isEmpty {
                let localEmail = (APIService.shared.currentEmail ?? UserDefaults.standard.string(forKey: "userEmail") ?? "")
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
        UserDefaults.standard.set(true, forKey: pendingLocalChangesKey)
    }

    private func buildSnapshot(modelContext: ModelContext) throws -> SyncEnvelope {
        let accountID = UserDefaults.standard.integer(forKey: "adminID")
        let version = UserDefaults.standard.integer(forKey: "lastSyncVersion") + 1

        return SyncEnvelope(
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
                PaymentSnapshot(id: $0.id, serverId: $0.serverId, userId: $0.userId, roomNumber: $0.roomNumber, rentFee: $0.rentFee, waterFee: $0.waterFee, electricFee: $0.electricFee, commonFee: $0.commonFee, lateFee: $0.lateFee, applianceFee: $0.applianceFee, amount: $0.amount, month: $0.month, paymentDate: $0.paymentDate, method: $0.method, slipPath: $0.slipPath, waterMeterPrev: $0.waterMeterPrev, waterMeterCurr: $0.waterMeterCurr, electricMeterPrev: $0.electricMeterPrev, electricMeterCurr: $0.electricMeterCurr, paymentPlan: $0.paymentPlan, installmentPhase: $0.installmentPhase, dueDate: $0.dueDate, paymentStatus: $0.paymentStatus, slipPathArray: $0.slipPathArray, paidAmount: $0.paidAmount, lastUpdated: $0.lastUpdated)
            },
            maintenance: try modelContext.fetch(FetchDescriptor<Maintenance>()).filter { !$0.isDeletedLocally }.map {
                MaintenanceSnapshot(id: $0.id, serverId: $0.serverId, roomNumber: $0.roomNumber, issue: $0.issue, status: $0.status, cost: $0.cost, reportedAt: $0.reportedAt, resolvedAt: $0.resolvedAt, paymentMethod: $0.paymentMethod, slipPath: $0.slipPath, issueImage: $0.issueImage, lastUpdated: $0.lastUpdated)
            },
            roomTypes: try modelContext.fetch(FetchDescriptor<RoomType>()).map {
                RoomTypeSnapshot(id: $0.id, serverId: $0.serverId, name: $0.name, price: $0.price, waterFee: $0.waterFee, electricFee: $0.electricFee, commonFee: $0.commonFee, lateFee: $0.lateFee, lastUpdated: $0.lastUpdated)
            },
            logs: try modelContext.fetch(FetchDescriptor<LocalSystemLog>()).map {
                SystemLogSnapshot(id: $0.id, action: $0.action, details: $0.details, timestamp: $0.timestamp)
            }
        )
    }

    private func pushCurrentSnapshot(modelContext: ModelContext) async throws {
        let snapshot = try buildSnapshot(modelContext: modelContext)
        let payload = try encoded(snapshot)
        state = .uploading
        message = "กำลังบันทึกขึ้น cloud"
        let responseData = try await APIService.shared.pushSyncSnapshot(payload: payload, deviceID: deviceID())
        let response = try JSONDecoder().decode(SyncPushResponse.self, from: responseData)
        guard response.status == "success" else {
            throw SyncError.invalidServerResponse
        }
        try markAllClean(modelContext: modelContext)
        UserDefaults.standard.set(response.version, forKey: "lastSyncVersion")
    }

    private func fetchAndApplyLatestSnapshot(modelContext: ModelContext, onlyIfRecent: Bool, silentWhenUnchanged: Bool) async throws {
        let data = try await APIService.shared.fetchLatestSyncSnapshot()
        let response = try decoder().decode(SyncLatestResponse.self, from: data)
        guard response.hasSnapshot, let snapshot = response.payload else {
            if !silentWhenUnchanged { message = "ยังไม่มีข้อมูลบน cloud" }
            return
        }

        let currentVersion = UserDefaults.standard.integer(forKey: "lastSyncVersion")
        guard let version = response.version, version > currentVersion else {
            if !silentWhenUnchanged { message = "ข้อมูลเป็นล่าสุดแล้ว" }
            return
        }

        if onlyIfRecent {
            guard snapshot.deviceID != deviceID() else { return }
            guard Date().timeIntervalSince(snapshot.createdAt) <= recentRemoteAutoPullWindow else { return }
        }

        let payload = try encoded(snapshot)
        if let checksum = response.checksum {
            try verifyChecksum(payload: payload, checksum: checksum)
        }
        state = .applying
        message = onlyIfRecent ? "รับข้อมูลใหม่จากเครื่องอื่น" : "เขียนทับข้อมูลในเครื่อง"
        try applySnapshot(snapshot, modelContext: modelContext)
        UserDefaults.standard.set(version, forKey: "lastSyncVersion")
    }

    private func applySnapshot(_ snapshot: SyncEnvelope, modelContext: ModelContext) throws {
        for item in try modelContext.fetch(FetchDescriptor<Room>()) { modelContext.delete(item) }
        for item in try modelContext.fetch(FetchDescriptor<DormUser>()) { modelContext.delete(item) }
        for item in try modelContext.fetch(FetchDescriptor<Payment>()) { modelContext.delete(item) }
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

        try markAllClean(modelContext: modelContext)
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
        for item in try modelContext.fetch(FetchDescriptor<Maintenance>()) {
            if item.isDeletedLocally { modelContext.delete(item) } else { item.isDirty = false }
        }
        for item in try modelContext.fetch(FetchDescriptor<RoomType>()) { item.isDirty = false }
        try modelContext.save()
        UserDefaults.standard.set(false, forKey: pendingLocalChangesKey)
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
        decoder.dateDecodingStrategy = .iso8601
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
}

enum SyncError: LocalizedError {
    case checksumMismatch
    case invalidServerResponse

    var errorDescription: String? {
        switch self {
        case .checksumMismatch:
            return "ข้อมูล sync ไม่ตรงกับ checksum"
        case .invalidServerResponse:
            return "server ตอบกลับข้อมูล sync ไม่ถูกต้อง"
        }
    }
}
