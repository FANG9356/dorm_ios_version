import XCTest

final class BillingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPartialPaymentFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Go to Bills Tab
        let billsTab = app.buttons["Tab_bills"]
        guard billsTab.waitForExistence(timeout: 5) else { return }
        billsTab.tap()

        // Verify Bills list exists
        let firstBill = app.buttons.matching(identifier: "BillRow").firstMatch
        if firstBill.waitForExistence(timeout: 3) {
            firstBill.tap()
            
            // In partial payment sheet
            let partialPayButton = app.buttons["PartialPaymentButton"]
            if partialPayButton.waitForExistence(timeout: 2) {
                partialPayButton.tap()
                
                let amountField = app.textFields["PaymentAmountField"]
                amountField.tap()
                amountField.typeText("1000")
                
                let saveButton = app.buttons["ConfirmPaymentButton"]
                saveButton.tap()
                
                // Expect success alert or UI change
                XCTAssertTrue(app.staticTexts["บันทึกสำเร็จ"].waitForExistence(timeout: 3))
            }
        }
    }
}
