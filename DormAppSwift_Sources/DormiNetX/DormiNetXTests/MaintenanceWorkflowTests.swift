import XCTest
@testable import DormiNetX

final class MaintenanceWorkflowTests: XCTestCase {
    func testCardAndEditorExposeEveryMaintenanceStatus() {
        XCTAssertEqual(MaintenanceWorkflow.statuses(hasCost: true), [
            "รอดำเนินการ",
            "กำลังติดต่อช่าง",
            "รออนุมัติค่าใช้จ่าย",
            "รอตรวจสอบชำระเงิน",
            "กำลังซ่อม",
            "เสร็จสิ้น"
        ])
        XCTAssertEqual(MaintenanceWorkflow.statuses(hasCost: false), [
            "รอดำเนินการ", "กำลังติดต่อช่าง", "กำลังซ่อม", "เสร็จสิ้น"
        ])
        XCTAssertEqual(MaintenanceWorkflow.statuses(hasCost: true).map(MaintenanceWorkflow.shortTitle), [
            "รอ", "ติดต่อช่าง", "อนุมัติราคา", "ตรวจชำระ", "ซ่อม", "เสร็จ"
        ])
    }

    func testStatusTransitionCannotSkipWorkflowSteps() {
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "กำลังติดต่อช่าง", hasCost: true))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "รอดำเนินการ", to: "กำลังซ่อม", hasCost: true))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "เสร็จสิ้น", to: "กำลังซ่อม", hasCost: true))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "unknown", to: "รอดำเนินการ", hasCost: true))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "ปฏิเสธค่าใช้จ่าย", to: "กำลังติดต่อช่าง", hasCost: true))
    }

    func testPaidRepairRequiresResidentApprovalButFreeRepairCanSkipQuote() {
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังติดต่อช่าง", to: "รออนุมัติค่าใช้จ่าย", hasCost: true))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "กำลังติดต่อช่าง", to: "กำลังซ่อม", hasCost: true))
        XCTAssertFalse(MaintenanceWorkflow.canTransition(from: "รออนุมัติค่าใช้จ่าย", to: "รอตรวจสอบชำระเงิน", hasCost: true))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "รออนุมัติค่าใช้จ่าย", to: "กำลังติดต่อช่าง", hasCost: true))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังติดต่อช่าง", to: "กำลังซ่อม", hasCost: false))
        XCTAssertTrue(MaintenanceWorkflow.canTransition(from: "กำลังซ่อม", to: "เสร็จสิ้น", hasCost: false))
    }
}
