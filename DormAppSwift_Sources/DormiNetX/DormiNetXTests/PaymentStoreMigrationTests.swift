import XCTest
import SwiftData
@testable import DormiNetX

@MainActor
final class PaymentStoreMigrationTests: XCTestCase {
    func testExistingStoreRetainsAmountsWhenDepositFieldIsAdded() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("migration.store")
        let paymentID = UUID()
        try autoreleasepool {
            let schema = Schema([LegacyPaymentSchema.Payment.self, DormUser.self, Room.self,
                                 Maintenance.self, RoomType.self, LocalSystemLog.self])
            let config = ModelConfiguration("migration", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let old = LegacyPaymentSchema.Payment()
            old.id = paymentID
            old.rentFee = 1500.25
            old.amount = 1575.25
            old.paidAmount = 500.25
            old.paymentStatus = "partial"
            old.slipPathArray = ["original-slip.jpg"]
            container.mainContext.insert(old)
            try container.mainContext.save()
        }
        let schema = AccountScopedStore.schema
        let config = ModelConfiguration("migration", schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let payment = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Payment>()).first)
        XCTAssertEqual(payment.id, paymentID)
        XCTAssertEqual(payment.depositFee, 0)
        XCTAssertEqual(payment.amount, 1575.25)
        XCTAssertEqual(payment.paidAmount, 500.25)
        XCTAssertEqual(payment.slipPathArray, ["original-slip.jpg"])
        XCTAssertEqual(PaymentAmounts.unallocated(in: payment), 75)
    }
}

// Frozen pre-deposit schema. Keep this fixture unchanged when the live model evolves.
private enum LegacyPaymentSchema {
    @Model final class Payment {
        @Attribute(.unique) var id: UUID = UUID()
        var serverId: Int?
        var userId: Int = 0
        var roomNumber: String = ""
        var rentFee: Double = 0.0
        var waterFee: Double = 0.0
        var electricFee: Double = 0.0
        var commonFee: Double = 0.0
        var lateFee: Double = 0.0
        var applianceFee: Double = 0.0
        var amount: Double = 0.0
        var month: String = ""
        var paymentDate: String = ""
        var method: String = ""
        var slipPath: String = ""
        var waterMeterPrev: Double = 0.0
        var waterMeterCurr: Double = 0.0
        var electricMeterPrev: Double = 0.0
        var electricMeterCurr: Double = 0.0
        var paymentPlan: String = ""
        var installmentPhase: Int = 0
        var dueDate: String = ""
        var paymentStatus: String = ""
        var slipPathArray: [String] = []
        var paidAmount: Double = 0.0
        var lastUpdated: Date = Date()
        var isDirty: Bool = false
        var isDeletedLocally: Bool = false
        init() {}
    }
}
