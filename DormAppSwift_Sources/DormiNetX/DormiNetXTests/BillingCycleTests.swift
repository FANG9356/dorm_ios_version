import XCTest
@testable import DormiNetX

@MainActor
final class BillingCycleTests: XCTestCase {
    func testMonthEndDueDatesAreClampedWithoutDrifting() {
        XCTAssertEqual(BillingCycle.dueDateKey(month: "2026-02", moveInDate: "2026-01-31"), "2026-02-28")
        XCTAssertEqual(BillingCycle.dueDateKey(month: "2028-02", moveInDate: "2026-01-31"), "2028-02-29")
        XCTAssertEqual(BillingCycle.dueDateKey(month: "2026-03", moveInDate: "2026-01-31"), "2026-03-31")
        XCTAssertEqual(BillingCycle.dueDateKey(month: "2026-04", moveInDate: "2026-01-31"), "2026-04-30")
    }

    func testFixedContractIncludesItsFinalMonthAndThaiYear() throws {
        let now = try XCTUnwrap(BillingCycle.date("2026-02-12"))
        let cycles = BillingCycle.generate(moveInDate: "2026-01-31", contractEndDate: "2026-03-31", indefiniteContract: false, now: now)
        XCTAssertEqual(cycles.map(\.monthId), ["2026-01", "2026-02", "2026-03"])
        XCTAssertEqual(cycles.map(\.dueDay), [31, 28, 31])
        XCTAssertEqual(cycles.map(\.isFuture), [false, false, true])
        XCTAssertTrue(try XCTUnwrap(cycles.first).label.contains("2569"))
    }

    func testIndefiniteContractStillShowsCurrentCyclesAfterYears() throws {
        let now = try XCTUnwrap(BillingCycle.date("2026-09-09"))
        let cycles = BillingCycle.generate(moveInDate: "2020-01-15", contractEndDate: "", indefiniteContract: true, now: now)
        XCTAssertTrue(cycles.contains { $0.monthId == "2026-09" })
        XCTAssertEqual(cycles.last?.monthId, "2027-09")
    }

    func testInvalidDatesNeverSilentlyBecomeToday() {
        XCTAssertNil(BillingCycle.date("2026-02-30"))
        XCTAssertEqual(BillingCycle.dueDateKey(month: "invalid", moveInDate: "2026-01-31"), "")
        XCTAssertTrue(BillingCycle.generate(moveInDate: "invalid", contractEndDate: "", indefiniteContract: true).isEmpty)
        XCTAssertTrue(BillingCycle.generate(moveInDate: "2026-01-31", contractEndDate: "2025-12-31", indefiniteContract: false).isEmpty)
    }
}
