import XCTest
import SwiftData
import CryptoKit
@testable import DormiNetX

@MainActor
final class CoreDataSafetyTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) async throws -> Void) async throws {
        let name = "DormiNetXTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        defaults.set(directory.path, forKey: "testOutboxPath")
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
        defaults.set(1, forKey: "adminID")
        try await body(defaults)
    }

    private func manager(api: APIService, defaults: UserDefaults) -> SyncManager {
        SyncManager(api: api, defaults: defaults,
                    outbox: SyncOutbox(directory: URL(fileURLWithPath: defaults.string(forKey: "testOutboxPath")!)))
    }

    func testRoomTransferPreservesReceiptsAndFollowsUnpaidBills() throws {
        let container = try AccountScopedStore.makeGuestContainer()
        let context = container.mainContext
        context.insert(Room(roomNumber: "101"))
        context.insert(Room(roomNumber: "102"))
        let tenant = DormUser(firstName: "Tenant")
        tenant.roomNumber = "101"
        context.insert(tenant)
        let paid = Payment(month: "2026-09", amount: 1500)
        paid.userId = stableLocalUserID(for: tenant)
        paid.roomNumber = "101"
        paid.paymentStatus = "paid"
        paid.paidAmount = 1500
        let open = Payment(month: "2026-10", amount: 1500)
        open.userId = paid.userId
        open.roomNumber = "101"
        let other = Payment(month: "2026-09", amount: 900)
        other.userId = paid.userId + 1
        other.roomNumber = "101"
        [paid, open, other].forEach { context.insert($0) }
        try context.save()
        try RoomTransferService.move(tenant, to: "102", in: context)
        XCTAssertEqual(tenant.roomNumber, "102")
        XCTAssertEqual(paid.roomNumber, "101")
        XCTAssertEqual(paid.paidAmount, 1500)
        XCTAssertEqual(open.roomNumber, "102")
        XCTAssertEqual(other.roomNumber, "101")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocalSystemLog>()), 1)
    }

    func testRoomTransferRejectsOccupiedAndMissingRooms() throws {
        let container = try AccountScopedStore.makeGuestContainer()
        let context = container.mainContext
        let tenant = DormUser(firstName: "One")
        tenant.roomNumber = "101"
        let occupant = DormUser(firstName: "Two")
        occupant.roomNumber = "102"
        occupant.status = "จอง"
        context.insert(tenant)
        context.insert(occupant)
        context.insert(Room(roomNumber: "102"))
        try context.save()
        XCTAssertThrowsError(try RoomTransferService.move(tenant, to: "102", in: context))
        XCTAssertThrowsError(try RoomTransferService.move(tenant, to: "999", in: context))
        XCTAssertEqual(tenant.roomNumber, "101")
    }

    func testCheckpointIsAccountScoped() async throws {
        try await withDefaults { defaults in
            let first = SyncCheckpoint(accountID: 1, defaults: defaults)
            let second = SyncCheckpoint(accountID: 2, defaults: defaults)
            first.version = 12
            first.markChanged()
            XCTAssertEqual(second.version, 0)
            XCTAssertFalse(second.pending)
            second.reset()
            XCTAssertEqual(first.version, 12)
            XCTAssertTrue(first.pending)
        }
    }

    func testEditsDuringUploadAreSentAgainBeforeAcknowledgment() async throws {
        try await withDefaults { defaults in
            let container = try AccountScopedStore.makeGuestContainer()
            let context = container.mainContext
            let room = Room(roomNumber: "101", roomType: "original")
            room.isDirty = true
            context.insert(room)
            try context.save()
            let api = SyncTestAPI()
            let manager = manager(api: api, defaults: defaults)
            api.onPush = { _, _ in
                if api.payloads.count == 1 {
                    room.roomType = "edited during upload"
                    room.isDirty = true
                    try context.save()
                    await manager.autoPushLocalChanges(modelContext: context)
                }
            }
            await manager.autoPushLocalChanges(modelContext: context)
            XCTAssertEqual(api.bases, [0, 1])
            XCTAssertEqual(api.payloads.count, 2)
            XCTAssertTrue(String(decoding: try XCTUnwrap(api.payloads.last), as: UTF8.self).contains("edited during upload"))
            XCTAssertFalse(room.isDirty)
            XCTAssertFalse(SyncCheckpoint(accountID: 1, defaults: defaults).pending)
            XCTAssertEqual(manager.state, .completed)
        }
    }

    func testSwitchingAccountDuringUploadDoesNotAcknowledgeOldStore() async throws {
        try await withDefaults { defaults in
            let container = try AccountScopedStore.makeGuestContainer()
            let context = container.mainContext
            let room = Room(roomNumber: "101")
            room.isDirty = true
            context.insert(room)
            try context.save()
            let api = SyncTestAPI()
            let manager = manager(api: api, defaults: defaults)
            api.onPush = { _, _ in defaults.set(2, forKey: "adminID") }
            await manager.autoPushLocalChanges(modelContext: context)
            XCTAssertTrue(room.isDirty)
            XCTAssertTrue(SyncCheckpoint(accountID: 1, defaults: defaults).pending)
            XCTAssertEqual(SyncCheckpoint(accountID: 2, defaults: defaults).version, 0)
            guard case .failed = manager.state else { return XCTFail("Session change must fail") }
        }
    }

    func testConflictPreservesLocalChanges() async throws {
        try await withDefaults { defaults in
            let container = try AccountScopedStore.makeGuestContainer()
            let room = Room(roomNumber: "101")
            room.isDirty = true
            container.mainContext.insert(room)
            let api = SyncTestAPI()
            api.onPush = { _, _ in throw SyncError.conflict }
            let manager = manager(api: api, defaults: defaults)
            await manager.autoPushLocalChanges(modelContext: container.mainContext)
            XCTAssertTrue(room.isDirty)
            XCTAssertTrue(SyncCheckpoint(accountID: 1, defaults: defaults).pending)
            XCTAssertEqual(SyncCheckpoint(accountID: 1, defaults: defaults).version, 0)
        }
    }

    func testAutoPushRebasesDirtyLocalRecordsAfterLinePublishesNewSnapshot() async throws {
        try await withDefaults { defaults in
            let remote = try AccountScopedStore.makeGuestContainer()
            let reportedFromLine = Maintenance(roomNumber: "103", issue: "ไฟดับ")
            reportedFromLine.isDirty = false
            remote.mainContext.insert(reportedFromLine)
            try remote.mainContext.save()

            let api = SyncTestAPI()
            let manager = manager(api: api, defaults: defaults)
            let remoteBackup = try manager.exportLocalBackupData(modelContext: remote.mainContext)
            let backupObject = try XCTUnwrap(JSONSerialization.jsonObject(with: remoteBackup) as? [String: Any])
            let remotePayload = try JSONSerialization.data(withJSONObject: XCTUnwrap(backupObject["snapshot"]))
            api.onFetch = { try self.snapshotResponse(remotePayload) }
            api.onPush = { _, baseVersion in
                if baseVersion == 0 { throw SyncError.conflict }
            }

            let local = try AccountScopedStore.makeGuestContainer()
            let unsentRoom = Room(roomNumber: "local-room")
            unsentRoom.isDirty = true
            local.mainContext.insert(unsentRoom)
            try local.mainContext.save()

            await manager.autoPushLocalChanges(modelContext: local.mainContext)

            XCTAssertEqual(manager.state, .completed)
            XCTAssertEqual(api.bases, [0, 1])
            XCTAssertEqual(SyncCheckpoint(accountID: 1, defaults: defaults).version, 2)
            XCTAssertFalse(SyncCheckpoint(accountID: 1, defaults: defaults).pending)
            XCTAssertEqual(try local.mainContext.fetch(FetchDescriptor<Maintenance>()).map(\.issue), ["ไฟดับ"])
            let mergedRooms = try local.mainContext.fetch(FetchDescriptor<Room>())
            XCTAssertEqual(mergedRooms.map(\.roomNumber), ["local-room"])
            XCTAssertFalse(try XCTUnwrap(mergedRooms.first).isDirty)
        }
    }

    func testRebaseKeepsCompletedLineMaintenanceOverInvalidDirtyRollback() async throws {
        try await withDefaults { defaults in
            let sharedID = UUID()
            let remote = try AccountScopedStore.makeGuestContainer()
            let completed = Maintenance(roomNumber: "103", issue: "existing")
            completed.id = sharedID
            completed.serverId = 222
            completed.status = "เสร็จสิ้น"
            completed.cost = 2
            completed.isDirty = false
            let reportedFromLine = Maintenance(roomNumber: "103", issue: "new from LINE")
            reportedFromLine.serverId = 779
            reportedFromLine.status = "รอดำเนินการ"
            reportedFromLine.isDirty = false
            remote.mainContext.insert(completed)
            remote.mainContext.insert(reportedFromLine)
            try remote.mainContext.save()

            let api = SyncTestAPI()
            let manager = manager(api: api, defaults: defaults)
            let remoteBackup = try manager.exportLocalBackupData(modelContext: remote.mainContext)
            let backupObject = try XCTUnwrap(JSONSerialization.jsonObject(with: remoteBackup) as? [String: Any])
            let remotePayload = try JSONSerialization.data(withJSONObject: XCTUnwrap(backupObject["snapshot"]))
            api.onFetch = { try self.snapshotResponse(remotePayload) }
            api.onPush = { _, baseVersion in
                if baseVersion == 0 { throw SyncError.conflict }
            }

            let local = try AccountScopedStore.makeGuestContainer()
            let stale = Maintenance(roomNumber: "103", issue: "existing")
            stale.id = sharedID
            stale.serverId = 222
            stale.status = "รออนุมัติค่าใช้จ่าย"
            stale.cost = 2
            stale.isDirty = true
            local.mainContext.insert(stale)
            try local.mainContext.save()

            await manager.autoPushLocalChanges(modelContext: local.mainContext)

            XCTAssertEqual(manager.state, .completed)
            XCTAssertEqual(api.bases, [0, 1])
            XCTAssertEqual(SyncCheckpoint(accountID: 1, defaults: defaults).version, 2)
            XCTAssertFalse(SyncCheckpoint(accountID: 1, defaults: defaults).pending)
            let records = try local.mainContext.fetch(FetchDescriptor<Maintenance>())
            XCTAssertEqual(records.first(where: { $0.id == sharedID })?.status, "เสร็จสิ้น")
            XCTAssertEqual(records.first(where: { $0.serverId == 779 })?.issue, "new from LINE")
            XCTAssertFalse(try XCTUnwrap(records.first(where: { $0.id == sharedID })).isDirty)

            let mergedPayload = try XCTUnwrap(api.payloads.last)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let merged = try decoder.decode(SyncEnvelope.self, from: mergedPayload)
            XCTAssertEqual(merged.maintenance.first(where: { $0.id == sharedID })?.status, "เสร็จสิ้น")
            XCTAssertNotNil(merged.maintenance.first(where: { $0.serverId == 779 }))
        }
    }

    func testDownloadDoesNotOverwriteEditsMadeWhileWaiting() async throws {
        try await withDefaults { defaults in
            let container = try AccountScopedStore.makeGuestContainer()
            let context = container.mainContext
            let room = Room(roomNumber: "101")
            room.isDirty = false
            context.insert(room)
            try context.save()
            let api = SyncTestAPI()
            api.onFetch = {
                room.roomType = "local edit"
                room.isDirty = true
                try context.save()
                return Data("{\"status\":\"success\",\"has_snapshot\":false}".utf8)
            }
            let manager = manager(api: api, defaults: defaults)
            await manager.pullLatestSnapshot(modelContext: context)
            XCTAssertEqual(room.roomType, "local edit")
            XCTAssertFalse(room.isDirty)
            XCTAssertEqual(api.payloads.count, 1)
            XCTAssertTrue(String(decoding: try XCTUnwrap(api.payloads.first), as: UTF8.self).contains("local edit"))
            XCTAssertFalse(SyncCheckpoint(accountID: 1, defaults: defaults).pending)
            XCTAssertEqual(manager.state, .completed)
        }
    }

    func testBackupRejectsOtherAccountBeforeReplacingData() async throws {
        try await withDefaults { defaults in
            let container = try AccountScopedStore.makeGuestContainer()
            let context = container.mainContext
            context.insert(Room(roomNumber: "101"))
            try context.save()
            let manager = manager(api: SyncTestAPI(), defaults: defaults)
            let data = try manager.exportLocalBackupData(modelContext: context)
            defaults.set(2, forKey: "adminID")
            XCTAssertThrowsError(try manager.restoreLocalBackupData(data, modelContext: context))
            XCTAssertEqual(try context.fetch(FetchDescriptor<Room>()).map(\.roomNumber), ["101"])
        }
    }

    func testLostResponseRetriesExactPayloadAfterRestartThenUploadsNewEdits() async throws {
        try await withDefaults { defaults in
            let container = try AccountScopedStore.makeGuestContainer()
            let context = container.mainContext
            let room = Room(roomNumber: "101", roomType: "original")
            room.isDirty = true
            context.insert(room)
            try context.save()
            let api = SyncTestAPI()
            api.onPush = { _, _ in
                if api.payloads.count == 1 { throw URLError(.networkConnectionLost) }
            }
            await manager(api: api, defaults: defaults).autoPushLocalChanges(modelContext: context)
            room.roomType = "new edit"
            try context.save()
            let restarted = manager(api: api, defaults: defaults)
            await restarted.autoPushLocalChanges(modelContext: context)
            XCTAssertEqual(api.bases, [0, 0, 1])
            XCTAssertEqual(api.payloads.count, 3)
            XCTAssertEqual(api.payloads.first, api.payloads.dropFirst().first)
            XCTAssertEqual(restarted.state, .completed)
            XCTAssertFalse(room.isDirty)
        }
    }

    func testDuplicateBackupIDsAreRejectedWithoutDeletingLocalData() async throws {
        try await withDefaults { defaults in
            let container = try AccountScopedStore.makeGuestContainer()
            let context = container.mainContext
            context.insert(Room(roomNumber: "101"))
            try context.save()
            let manager = manager(api: SyncTestAPI(), defaults: defaults)
            let data = try manager.exportLocalBackupData(modelContext: context)
            var backup = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            var snapshot = try XCTUnwrap(backup["snapshot"] as? [String: Any])
            let rooms = try XCTUnwrap(snapshot["rooms"] as? [[String: Any]])
            snapshot["rooms"] = rooms + rooms
            backup["snapshot"] = snapshot
            XCTAssertThrowsError(try manager.restoreLocalBackupData(JSONSerialization.data(withJSONObject: backup), modelContext: context))
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Room>()), 1)
        }
    }

    func testOrphanLedgerBackupIsRejectedWithoutDeletingLocalData() async throws {
        try await withDefaults { defaults in
            let source = try AccountScopedStore.makeGuestContainer()
            let payment = Payment(month: "2026-09", amount: 1_000)
            payment.paidAmount = 400
            source.mainContext.insert(payment)
            _ = try PaymentLedger.recordUnrecordedBalance(for: payment, in: source.mainContext, source: "test")
            try source.mainContext.save()

            let manager = manager(api: SyncTestAPI(), defaults: defaults)
            let data = try manager.exportLocalBackupData(modelContext: source.mainContext)
            var backup = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            var snapshot = try XCTUnwrap(backup["snapshot"] as? [String: Any])
            snapshot["payments"] = []
            backup["snapshot"] = snapshot

            let local = try AccountScopedStore.makeGuestContainer()
            local.mainContext.insert(Room(roomNumber: "local"))
            try local.mainContext.save()
            XCTAssertThrowsError(try manager.restoreLocalBackupData(
                JSONSerialization.data(withJSONObject: backup),
                modelContext: local.mainContext
            ))
            XCTAssertEqual(try local.mainContext.fetch(FetchDescriptor<Room>()).map(\.roomNumber), ["local"])
            XCTAssertEqual(try local.mainContext.fetchCount(FetchDescriptor<PaymentTransaction>()), 0)
        }
    }

    func testDepositBackupRoundTripAndLegacyMissingField() async throws {
        try await withDefaults { defaults in
            let container = try AccountScopedStore.makeGuestContainer()
            let context = container.mainContext
            let payment = Payment(month: "2026-09", amount: 1575.25)
            payment.rentFee = 1500.25
            payment.depositFee = 75
            context.insert(payment)
            try context.save()
            let manager = manager(api: SyncTestAPI(), defaults: defaults)
            let data = try manager.exportLocalBackupData(modelContext: context)
            try manager.restoreLocalBackupData(data, modelContext: context)
            let restored = try XCTUnwrap(context.fetch(FetchDescriptor<Payment>()).first)
            XCTAssertEqual(restored.depositFee, 75)
            XCTAssertEqual(restored.amount, 1575.25)
            XCTAssertEqual(PaymentAmounts.unallocated(in: restored), 0)

            var backup = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            var snapshot = try XCTUnwrap(backup["snapshot"] as? [String: Any])
            var payments = try XCTUnwrap(snapshot["payments"] as? [[String: Any]])
            payments[0].removeValue(forKey: "depositFee")
            snapshot["payments"] = payments
            backup["snapshot"] = snapshot
            try manager.restoreLocalBackupData(JSONSerialization.data(withJSONObject: backup), modelContext: context)
            let legacy = try XCTUnwrap(context.fetch(FetchDescriptor<Payment>()).first)
            XCTAssertEqual(legacy.depositFee, 0)
            XCTAssertEqual(legacy.amount, 1575.25)
            XCTAssertEqual(PaymentAmounts.unallocated(in: legacy), 75)
        }
    }

    func testRawSnapshotChecksumSupportsFractionalDatesAndThai() async throws {
        try await withDefaults { defaults in
            let container = try AccountScopedStore.makeGuestContainer()
            let context = container.mainContext
            let payload = Data("""
            {"snapshotID":"sample","accountID":1,"version":1,"createdAt":"2026-09-09T12:00:00.123Z","deviceID":"other","rooms":[{"id":"00000000-0000-0000-0000-000000000001","roomNumber":"101","roomType":"ห้องแอร์","lastUpdated":"2026-09-09T12:00:00.123Z"}],"tenants":[],"payments":[],"maintenance":[],"roomTypes":[],"logs":[]}
            """.utf8)
            let checksum = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
            let response = try JSONSerialization.data(withJSONObject: [
                "status": "success", "has_snapshot": true, "version": 1,
                "payload": JSONSerialization.jsonObject(with: payload),
                "payload_base64": payload.base64EncodedString(), "checksum": checksum
            ])
            let api = SyncTestAPI()
            api.onFetch = { response }
            let manager = manager(api: api, defaults: defaults)
            await manager.pullLatestSnapshot(modelContext: context)
            XCTAssertEqual(manager.state, .completed)
            XCTAssertEqual(try context.fetch(FetchDescriptor<Room>()).first?.roomType, "ห้องแอร์")
            XCTAssertEqual(SyncCheckpoint(accountID: 1, defaults: defaults).version, 1)
        }
    }

    func testManualPullRepairsMissingLocalDataAtSameVersion() async throws {
        try await withDefaults { defaults in
            let remote = try AccountScopedStore.makeGuestContainer()
            let maintenance = Maintenance(roomNumber: "103", issue: "ไฟดับ")
            maintenance.isDirty = false
            remote.mainContext.insert(maintenance)
            try remote.mainContext.save()

            let api = SyncTestAPI()
            let manager = manager(api: api, defaults: defaults)
            let backupData = try manager.exportLocalBackupData(modelContext: remote.mainContext)
            let backup = try XCTUnwrap(JSONSerialization.jsonObject(with: backupData) as? [String: Any])
            let payload = try JSONSerialization.data(withJSONObject: XCTUnwrap(backup["snapshot"]))
            api.onFetch = { try self.snapshotResponse(payload) }

            let local = try AccountScopedStore.makeGuestContainer()
            SyncCheckpoint(accountID: 1, defaults: defaults).version = 1
            await manager.pullLatestSnapshot(modelContext: local.mainContext)

            XCTAssertEqual(manager.state, .completed)
            XCTAssertEqual(try local.mainContext.fetch(FetchDescriptor<Maintenance>()).map(\.issue), ["ไฟดับ"])
            XCTAssertEqual(manager.message, "ซ่อมข้อมูลในเครื่องจาก cloud แล้ว")
        }
    }

    func testManualPullRebasesDirtyLocalRecordsOntoRemoteSnapshot() async throws {
        try await withDefaults { defaults in
            let remote = try AccountScopedStore.makeGuestContainer()
            let maintenance = Maintenance(roomNumber: "103", issue: "ไฟดับ")
            maintenance.isDirty = false
            remote.mainContext.insert(maintenance)
            try remote.mainContext.save()

            let api = SyncTestAPI()
            let manager = manager(api: api, defaults: defaults)
            let backupData = try manager.exportLocalBackupData(modelContext: remote.mainContext)
            let backup = try XCTUnwrap(JSONSerialization.jsonObject(with: backupData) as? [String: Any])
            let payload = try JSONSerialization.data(withJSONObject: XCTUnwrap(backup["snapshot"]))
            api.onFetch = { try self.snapshotResponse(payload) }

            let local = try AccountScopedStore.makeGuestContainer()
            let localRoom = Room(roomNumber: "local-room")
            localRoom.isDirty = true
            local.mainContext.insert(localRoom)
            try local.mainContext.save()

            await manager.pullLatestSnapshot(modelContext: local.mainContext)

            XCTAssertEqual(manager.state, .completed)
            XCTAssertEqual(api.bases, [1])
            XCTAssertEqual(SyncCheckpoint(accountID: 1, defaults: defaults).version, 2)
            XCTAssertEqual(try local.mainContext.fetch(FetchDescriptor<Maintenance>()).map(\.issue), ["ไฟดับ"])
            XCTAssertEqual(try local.mainContext.fetch(FetchDescriptor<Room>()).map(\.roomNumber), ["local-room"])
            XCTAssertEqual(manager.message, "รวมข้อมูลในเครื่องกับ cloud แล้ว")
        }
    }

    func testPullingLegacyPaidBalanceQueuesGeneratedLedgerForUpload() async throws {
        try await withDefaults { defaults in
            let remote = try AccountScopedStore.makeGuestContainer()
            let payment = Payment(month: "2026-09", amount: 1_000)
            payment.paidAmount = 400
            payment.paymentStatus = "partial"
            remote.mainContext.insert(payment)
            try remote.mainContext.save()

            let api = SyncTestAPI()
            let manager = manager(api: api, defaults: defaults)
            let backupData = try manager.exportLocalBackupData(modelContext: remote.mainContext)
            let backup = try XCTUnwrap(JSONSerialization.jsonObject(with: backupData) as? [String: Any])
            var snapshot = try XCTUnwrap(backup["snapshot"] as? [String: Any])
            snapshot.removeValue(forKey: "paymentTransactions")
            snapshot.removeValue(forKey: "financialReceipts")
            let payload = try JSONSerialization.data(withJSONObject: snapshot)
            api.onFetch = { try self.snapshotResponse(payload) }

            let local = try AccountScopedStore.makeGuestContainer()
            await manager.pullLatestSnapshot(modelContext: local.mainContext)

            XCTAssertEqual(manager.state, .completed)
            XCTAssertEqual(try local.mainContext.fetch(FetchDescriptor<PaymentTransaction>()).count, 1)
            XCTAssertEqual(try local.mainContext.fetch(FetchDescriptor<FinancialReceipt>()).count, 1)
            XCTAssertEqual(api.bases, [1])
            XCTAssertEqual(SyncCheckpoint(accountID: 1, defaults: defaults).version, 2)
            XCTAssertFalse(SyncCheckpoint(accountID: 1, defaults: defaults).pending)
        }
    }

    func testConfirmedRemoteRecoveryCreatesBackupBeforeReplacingLocalData() async throws {
        try await withDefaults { defaults in
            let local = try AccountScopedStore.makeGuestContainer()
            let remote = try AccountScopedStore.makeGuestContainer()
            local.mainContext.insert(Room(roomNumber: "local"))
            remote.mainContext.insert(Room(roomNumber: "remote"))
            let api = SyncTestAPI()
            let manager = manager(api: api, defaults: defaults)
            let remoteBackup = try manager.exportLocalBackupData(modelContext: remote.mainContext)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: remoteBackup) as? [String: Any])
            let payload = try JSONSerialization.data(withJSONObject: XCTUnwrap(object["snapshot"]))
            let response = try snapshotResponse(payload)
            api.onFetch = { response }
            let directory = URL(fileURLWithPath: defaults.string(forKey: "testOutboxPath")!)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let backup = directory.appendingPathComponent("recovery.dorminetbackup")
            try await manager.replaceWithRemoteSnapshot(modelContext: local.mainContext, backupURL: backup)
            XCTAssertTrue(String(decoding: try Data(contentsOf: backup), as: UTF8.self).contains("local"))
            XCTAssertEqual(try local.mainContext.fetch(FetchDescriptor<Room>()).map(\.roomNumber), ["remote"])
            XCTAssertEqual(SyncCheckpoint(accountID: 1, defaults: defaults).version, 1)
        }
    }

    func testRemoteRecoveryCannotReplaceDataWhenBackupCannotBeWritten() async throws {
        try await withDefaults { defaults in
            let local = try AccountScopedStore.makeGuestContainer()
            let room = Room(roomNumber: "local")
            local.mainContext.insert(room)
            try local.mainContext.save()
            let api = SyncTestAPI()
            let manager = manager(api: api, defaults: defaults)
            let backup = try manager.exportLocalBackupData(modelContext: local.mainContext)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
            let response = try snapshotResponse(JSONSerialization.data(withJSONObject: XCTUnwrap(object["snapshot"])))
            api.onFetch = { response }
            let missingDirectory = URL(fileURLWithPath: defaults.string(forKey: "testOutboxPath")!)
            do {
                try await manager.replaceWithRemoteSnapshot(modelContext: local.mainContext,
                                                            backupURL: missingDirectory.appendingPathComponent("missing/file"))
                XCTFail("Must fail before modifying local data")
            } catch {
                XCTAssertEqual(try local.mainContext.fetch(FetchDescriptor<Room>()).map(\.roomNumber), ["local"])
                XCTAssertEqual(SyncCheckpoint(accountID: 1, defaults: defaults).version, 0)
            }
        }
    }

    private func snapshotResponse(_ payload: Data) throws -> Data {
        let checksum = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        return try JSONSerialization.data(withJSONObject: [
            "status": "success", "has_snapshot": true, "version": 1,
            "payload": JSONSerialization.jsonObject(with: payload),
            "payload_base64": payload.base64EncodedString(), "checksum": checksum
        ])
    }
}

@MainActor
private final class SyncTestAPI: APIService {
    private var token: String? = "test-only-token"
    override var authToken: String? {
        get { token }
        set { token = newValue }
    }
    var payloads: [Data] = []
    var bases: [Int] = []
    var onPush: ((Data, Int) async throws -> Void)?
    var onFetch: (() async throws -> Data)?
    override func fetchSyncMetadata() async throws -> Data {
        Data("{\"status\":\"success\",\"sync_protocol\":2,\"has_snapshot\":false}".utf8)
    }
    override func pushSyncSnapshot(payload: Data, deviceID: String, baseVersion: Int) async throws -> Data {
        payloads.append(payload)
        bases.append(baseVersion)
        try await onPush?(payload, baseVersion)
        let checksum = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        return try JSONSerialization.data(withJSONObject: ["status": "success", "version": baseVersion + 1, "checksum": checksum])
    }
    override func fetchLatestSyncSnapshot() async throws -> Data {
        guard let onFetch else { throw URLError(.notConnectedToInternet) }
        return try await onFetch()
    }
}
