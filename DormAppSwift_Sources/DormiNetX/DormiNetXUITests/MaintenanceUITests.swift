import XCTest

final class MaintenanceUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMaintenanceFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let maintenanceTab = app.buttons["Tab_maintenance"]
        guard maintenanceTab.waitForExistence(timeout: 5) else { return }
        maintenanceTab.tap()
        
        // Add request
        let addButton = app.buttons["AddMaintenanceButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()
        
        let roomField = app.textFields["MaintenanceRoomField"]
        roomField.tap()
        roomField.typeText("102")
        
        let issueField = app.textFields["MaintenanceIssueField"]
        issueField.tap()
        issueField.typeText("แอร์ไม่เย็น")
        
        let saveButton = app.buttons["SaveMaintenanceButton"]
        saveButton.tap()
        
        XCTAssertTrue(app.buttons.matching(identifier: "MaintenanceRow").firstMatch.waitForExistence(timeout: 3))
    }
}
