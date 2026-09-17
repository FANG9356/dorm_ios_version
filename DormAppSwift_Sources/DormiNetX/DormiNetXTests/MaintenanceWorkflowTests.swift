import XCTest
@testable import DormiNetX

final class MaintenanceWorkflowTests: XCTestCase {
    func testCardAndEditorExposeEveryMaintenanceStatus() {
        XCTAssertEqual(MaintenanceWorkflow.statuses, [
            "รอดำเนินการ",
            "กำลังติดต่อช่าง",
            "กำลังซ่อม",
            "รอตรวจสอบชำระเงิน",
            "เสร็จสิ้น"
        ])
        XCTAssertEqual(Set(MaintenanceWorkflow.statuses).count, 5)
        XCTAssertEqual(MaintenanceWorkflow.statuses.map(MaintenanceWorkflow.shortTitle), [
            "รอ", "ติดต่อช่าง", "ซ่อม", "ตรวจชำระ", "เสร็จ"
        ])
    }
}
