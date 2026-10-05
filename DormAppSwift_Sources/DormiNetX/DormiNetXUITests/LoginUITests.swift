import XCTest

final class LoginUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLoginSuccess() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify we are on login screen
        let loginButton = app.buttons["LoginButton"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))

        // Enter credentials
        let usernameField = app.textFields["UsernameField"]
        usernameField.tap()
        usernameField.typeText("admin")

        let passwordField = app.secureTextFields["PasswordField"]
        passwordField.tap()
        passwordField.typeText("password123")

        // Tap login
        loginButton.tap()

        // Verify successful login (TabBar appears)
        let tabBar = app.tabBars["MainTabBar"]
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    }
    
    func testLoginFailure() throws {
        let app = XCUIApplication()
        app.launch()

        let loginButton = app.buttons["LoginButton"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))

        let usernameField = app.textFields["UsernameField"]
        usernameField.tap()
        usernameField.typeText("wrongadmin")

        let passwordField = app.secureTextFields["PasswordField"]
        passwordField.tap()
        passwordField.typeText("wrongpass")

        loginButton.tap()

        // Verify error message
        let errorAlert = app.staticTexts["LoginErrorText"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5))
    }
}
