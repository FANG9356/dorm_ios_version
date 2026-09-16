import XCTest
@testable import DormiNetX

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testMaintenanceCountsIncludeEveryWorkflowStatus() {
        let counts = DashboardViewModel.maintenanceCounts(for: [
            "รอดำเนินการ",
            "กำลังติดต่อช่าง",
            "กำลังดำเนินการ",
            "กำลังซ่อม",
            "รอตรวจสอบชำระเงิน",
            "เสร็จสิ้น"
        ])

        XCTAssertEqual(counts, MaintenanceCounts(pending: 1, inProgress: 4, completed: 1))
        XCTAssertEqual(counts.total, 6)
    }

    func testMaintenanceCountsNeverHideBlankOrFutureStatuses() {
        let counts = DashboardViewModel.maintenanceCounts(for: [nil, "", "สถานะใหม่"])

        XCTAssertEqual(counts, MaintenanceCounts(pending: 2, inProgress: 1, completed: 0))
        XCTAssertEqual(counts.total, 3)
    }
}
