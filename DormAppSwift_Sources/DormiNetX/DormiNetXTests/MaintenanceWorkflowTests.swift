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

    func testStatusTransitionCannotSkipWorkflowSteps() {
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "รอดำเนินการ"))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "กำลังติดต่อช่าง"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "กำลังซ่อม"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "เสร็จสิ้น"))

        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังซ่อม", to: "กำลังติดต่อช่าง"))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังซ่อม", to: "รอตรวจสอบชำระเงิน"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "กำลังซ่อม", to: "เสร็จสิ้น"))

        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "เสร็จสิ้น", to: "รอตรวจสอบชำระเงิน"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "เสร็จสิ้น", to: "กำลังซ่อม"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "unknown", to: "รอดำเนินการ"))
    }
}
