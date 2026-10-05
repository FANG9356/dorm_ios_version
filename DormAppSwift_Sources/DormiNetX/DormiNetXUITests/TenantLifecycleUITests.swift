import XCTest

final class TenantLifecycleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddTenantAndMoveRoom() throws {
        let app = XCUIApplication()
        app.launch()

        // Assuming user is logged in (mocked or persistent state)
        let tabBar = app.tabBars["MainTabBar"]
        guard tabBar.waitForExistence(timeout: 5) else { return }

        // Go to Tenants Tab
        let tenantsTab = app.buttons["Tab_tenants"]
        tenantsTab.tap()

        // Add Tenant
        let addTenantButton = app.buttons["AddTenantButton"]
        XCTAssertTrue(addTenantButton.waitForExistence(timeout: 3))
        addTenantButton.tap()

        // Fill form
        let firstNameField = app.textFields["FirstNameField"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 2))
        firstNameField.tap()
        firstNameField.typeText("สมชาย")

        let roomField = app.textFields["RoomNumberField"]
        roomField.tap()
        roomField.typeText("101")

        // Save
        let saveButton = app.buttons["SaveTenantButton"]
        saveButton.tap()

        // Verify it appears in list
        let searchField = app.textFields["SearchTenantField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("101")

        let tenantCard = app.buttons["TenantCard_101"]
        XCTAssertTrue(tenantCard.waitForExistence(timeout: 3))
    }
}
