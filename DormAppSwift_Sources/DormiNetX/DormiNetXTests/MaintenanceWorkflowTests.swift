import XCTest
@testable import DormiNetX

final class MaintenanceWorkflowTests: XCTestCase {
    func testCardAndEditorExposeEveryMaintenanceStatus() {
        XCTAssertEqual(MaintenanceWorkflow.statuses, [
            "รอดำเนินการ",
            "กำลังติดต่อช่าง",
            "รออนุมัติค่าใช้จ่าย",
            "กำลังซ่อม",
            "รอตรวจสอบชำระเงิน",
            "เสร็จสิ้น"
        ])
        XCTAssertEqual(Set(MaintenanceWorkflow.statuses).count, 6)
        XCTAssertEqual(MaintenanceWorkflow.statuses.map(MaintenanceWorkflow.shortTitle), [
            "รอ", "ติดต่อช่าง", "อนุมัติราคา", "ซ่อม", "ตรวจชำระ", "เสร็จ"
        ])
    }

    func testStatusTransitionCannotSkipWorkflowSteps() {
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "รอดำเนินการ"))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "กำลังติดต่อช่าง"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "กำลังซ่อม"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "เสร็จสิ้น"))

        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังซ่อม", to: "รออนุมัติค่าใช้จ่าย", cost: 500))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังซ่อม", to: "รอตรวจสอบชำระเงิน"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "กำลังซ่อม", to: "เสร็จสิ้น", cost: 500))

        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "เสร็จสิ้น", to: "รอตรวจสอบชำระเงิน"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "เสร็จสิ้น", to: "กำลังซ่อม"))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "unknown", to: "รอดำเนินการ"))
    }

    func testPaidRepairRequiresResidentApprovalButFreeRepairCanSkipQuote() {
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "กำลังติดต่อช่าง", to: "รออนุมัติค่าใช้จ่าย", cost: 0))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังติดต่อช่าง", to: "รออนุมัติค่าใช้จ่าย", cost: 500))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังติดต่อช่าง", to: "กำลังซ่อม", cost: 0))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "กำลังติดต่อช่าง", to: "กำลังซ่อม", cost: 500))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังติดต่อช่าง", to: "กำลังซ่อม", cost: 500, quoteApproved: true))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "รออนุมัติค่าใช้จ่าย", to: "กำลังซ่อม", cost: 500))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังซ่อม", to: "เสร็จสิ้น", cost: 0))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "กำลังซ่อม", to: "เสร็จสิ้น", cost: 500))
    }
}
