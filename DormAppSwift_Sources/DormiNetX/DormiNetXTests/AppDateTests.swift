import XCTest
@testable import DormiNetX

final class AppDateTests: XCTestCase {
    func testGregorianAndLegacyBuddhistMonthsNormalizeToSameStorageKey() {
        XCTAssertEqual(AppDate.normalizedMonthKey("2026-09"), "2026-09")
        XCTAssertEqual(AppDate.normalizedMonthKey("2569-09"), "2026-09")
        XCTAssertEqual(AppDate.thaiMonth("2026-09"), AppDate.thaiMonth("2569-09"))
        XCTAssertFalse(AppDate.thaiMonth("2569-09").contains("3112"))
    }

    func testGregorianAndLegacyBuddhistDatesNormalizeToSameDate() {
        XCTAssertEqual(AppDate.normalizedDateKey("2026-09-30"), "2026-09-30")
        XCTAssertEqual(AppDate.normalizedDateKey("2569-09-30"), "2026-09-30")
        XCTAssertEqual(AppDate.date(fromStorageDate: "2026-09-30"), AppDate.date(fromStorageDate: "2569-09-30"))
        XCTAssertEqual(AppDate.thaiDate("2026-09-30"), AppDate.thaiDate("2569-09-30"))
        XCTAssertFalse(AppDate.thaiDate("2569-09-30").contains("3112"))
    }

    func testInvalidStorageDatesAreRejectedInsteadOfRollingOver() {
        XCTAssertNil(AppDate.normalizedMonthKey("2026-13"))
        XCTAssertNil(AppDate.normalizedDateKey("2026-02-30"))
        XCTAssertNil(AppDate.normalizedDateKey("not-a-date"))
    }

    func testDatePickerRoundTripAlwaysWritesGregorianStorage() throws {
        let legacyDate = try XCTUnwrap(AppDate.date(fromStorageDate: "2569-09-30"))
        let legacyMonth = try XCTUnwrap(AppDate.date(fromStorageMonth: "2569-09"))
        XCTAssertEqual(AppDate.dateKey(from: legacyDate), "2026-09-30")
        XCTAssertEqual(AppDate.monthKey(from: legacyMonth), "2026-09")
    }
}
