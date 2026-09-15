import XCTest
@testable import DormiNetX

@MainActor
final class PaymentAmountsTests: XCTestCase {
    func testDecimalArithmeticAndInputPreserveSatang() {
        XCTAssertEqual(PaymentAmounts.sum([0.1, 0.2]), 0.3)
        XCTAssertEqual(PaymentAmounts.sum([1500.25, 75.01, 0.04]), 1575.30)
        XCTAssertEqual(PaymentAmounts.input(1500.25), "1500.25")
        XCTAssertEqual(PaymentAmounts.input(75.01), "75.01")
        XCTAssertTrue(PaymentAmounts.sum([.infinity]).isNaN)
    }

    func testLegacyUnlabelledAmountSurvivesUnchangedAndEditedCharges() {
        let payment = Payment(amount: 1575.25)
        payment.rentFee = 1500.25
        let retained = PaymentAmounts.unallocated(in: payment)
        XCTAssertEqual(retained, 75)
        XCTAssertEqual(PaymentAmounts.sum([payment.rentFee, retained]), payment.amount)
        XCTAssertEqual(PaymentAmounts.sum([1600.25, retained]), 1675.25)
        payment.amount = 1450.25
        XCTAssertEqual(PaymentAmounts.unallocated(in: payment), -50)
    }

    func testExplicitDepositIsNotCountedTwice() {
        let payment = Payment(amount: 1575.25)
        payment.rentFee = 1500.25
        payment.depositFee = 75
        XCTAssertEqual(PaymentAmounts.unallocated(in: payment), 0)
        XCTAssertEqual(PaymentAmounts.sum([payment.rentFee, payment.depositFee]), payment.amount)
    }

    func testSettlementRejectsContradictoryStatusesAndOverpayment() throws {
        try PaymentAmounts.validate(total: 1500, paid: 0, status: "pending")
        try PaymentAmounts.validate(total: 1500, paid: 500.25, status: "partial")
        try PaymentAmounts.validate(total: 1500, paid: 1500, status: "paid")
        for (paid, status) in [(0.0, "partial"), (1500, "partial"), (500, "paid"), (500, "pending"), (1600, "paid"), (-1, "partial")] {
            XCTAssertThrowsError(try PaymentAmounts.validate(total: 1500, paid: paid, status: status))
        }
        XCTAssertThrowsError(try PaymentAmounts.validate(total: .nan, paid: 0, status: "pending"))
    }

    func testEditingCannotEraseMoneyPreviouslyReceived() throws {
        try PaymentAmounts.validate(total: 0.3, paid: 0.3, status: "paid", previousPaid: 0.1 + 0.2)
        XCTAssertThrowsError(try PaymentAmounts.validate(total: 1500, paid: 0, status: "pending", previousPaid: 500))
        XCTAssertThrowsError(try PaymentAmounts.validate(total: 400, paid: 400, status: "paid", previousPaid: 500))
        try PaymentAmounts.validate(total: 1500, paid: 1000, status: "partial", previousPaid: 500)
    }
}
