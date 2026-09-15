import XCTest
import SwiftData
@testable import DormiNetX

@MainActor
final class PaymentLedgerTests: XCTestCase {
    func testPartialPaymentsCreateSeparateTransactionsAndImmutableReceiptFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let payment = Payment(month: "2026-09", amount: 1_500.25)
        payment.userId = 42
        payment.roomNumber = "A101"
        payment.method = "โอนผ่านธนาคาร"
        payment.paymentDate = "2026-09-10"
        payment.slipPathArray = ["first-slip.jpg"]
        payment.paidAmount = 500.10
        context.insert(payment)

        let first = try XCTUnwrap(PaymentLedger.recordUnrecordedBalance(for: payment, in: context, source: "test"))
        XCTAssertEqual(first.amount, 500.10)

        payment.paidAmount = 1_000.20
        payment.roomNumber = "B202"
        let second = try XCTUnwrap(PaymentLedger.recordUnrecordedBalance(for: payment, in: context, source: "test"))
        XCTAssertEqual(second.amount, 500.10)
        XCTAssertEqual(try PaymentLedger.recordedTotal(for: payment.id, in: context), 1_000.20)

        let receipts = try context.fetch(FetchDescriptor<FinancialReceipt>())
        XCTAssertEqual(receipts.count, 2)
        XCTAssertEqual(receipts.map(\.receivedAmount).reduce(0, +), 1_000.20, accuracy: 0.001)
        let firstReceipt = try XCTUnwrap(receipts.first { $0.transactionID == first.id })
        let secondReceipt = try XCTUnwrap(receipts.first { $0.transactionID == second.id })
        XCTAssertEqual(firstReceipt.roomNumber, "A101")
        XCTAssertEqual(secondReceipt.roomNumber, "B202")
        XCTAssertEqual(firstReceipt.invoiceAmount, 1_500.25)
        XCTAssertEqual(firstReceipt.balanceAfter, 1_000.15)
        XCTAssertEqual(firstReceipt.slipPaths, ["first-slip.jpg"])
    }

    func testLegacyMigrationIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let payment = Payment(month: "2026-08", amount: 800)
        payment.paidAmount = 300
        payment.paymentStatus = "partial"
        context.insert(payment)

        XCTAssertEqual(try PaymentLedger.migrateLegacyBalances(in: context), 1)
        XCTAssertEqual(try PaymentLedger.migrateLegacyBalances(in: context), 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PaymentTransaction>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FinancialReceipt>()).count, 1)
        XCTAssertEqual(try PaymentLedger.recordedTotal(for: payment.id, in: context), 300)
    }

    func testRecordedMoneyCannotBeReducedByEditingTheCompatibilityBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let payment = Payment(month: "2026-09", amount: 1_000)
        payment.paidAmount = 600
        context.insert(payment)
        try PaymentLedger.migrateLegacyBalances(in: context)

        payment.paidAmount = 500
        XCTAssertThrowsError(try PaymentLedger.recordUnrecordedBalance(for: payment, in: context, source: "test")) { error in
            XCTAssertEqual(error.localizedDescription, "มีรายการรับเงินในประวัติแล้ว ไม่สามารถลดยอดสะสมโดยแก้บิลทับได้")
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<PaymentTransaction>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FinancialReceipt>()).count, 1)
    }

    func testRecordedInvoiceCannotBeDeletedButUnpaidInvoiceCan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let paid = Payment(month: "2026-09", amount: 1_000)
        paid.paidAmount = 400
        let unpaid = Payment(month: "2026-10", amount: 1_000)
        context.insert(paid)
        context.insert(unpaid)
        try PaymentLedger.migrateLegacyBalances(in: context)

        XCTAssertNoThrow(try PaymentLedger.ensureInvoiceCanBeDeleted(unpaid, in: context))
        XCTAssertThrowsError(try PaymentLedger.ensureInvoiceCanBeDeleted(paid, in: context)) { error in
            XCTAssertEqual(error.localizedDescription, "บิลนี้มีประวัติรับเงินแล้ว ต้องใช้ขั้นตอนคืนเงินหรือปรับยอดแทนการลบ")
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<PaymentTransaction>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FinancialReceipt>()).count, 1)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Payment.self, PaymentTransaction.self, FinancialReceipt.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
