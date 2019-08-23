/* Copyright Airship and Contributors */

import XCTest

class CoreUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        // Ensure we don't try to continue to run after entering an unexpected state
        continueAfterFailure = false
        XCUIApplication().launch()

        self.addUIInterruptionMonitor(withDescription: "Alert handler") { (element) -> Bool in

            if element.label == "Notice" {
                element.buttons["Disable Warning"].tap()
            }

            return true
        }
    }

    /// Tests app launches to expected initial home screen
    func testHomeView() {
        // Note: these string identifiers are accessibility identifers set in the storyboard
        let airshipMark = app.images["airshipMark"]

        XCTAssert(airshipMark.exists)

        // Check localization on home view
        app.checkLocalization()
    }

    func testDebugDeviceInfoView() {
        app.tabBars.buttons["Debug"].tap()

        let tablesQuery = app.tables
        tablesQuery.staticTexts["Device Info"].tap()
        // Inside device info view
        app.checkLocalization()

        tablesQuery.staticTexts["Named User"].tap()
        // Inside named user addition view
        app.checkLocalization()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tables.staticTexts["Tags"].tap()
        // Inside tags view
        app.checkLocalization()

        app.navigationBars["Tags"].buttons["Add"].tap()
        // Inside tags addition view
        app.checkLocalization()

        app.goBack()
        app.goBack()
        tablesQuery.staticTexts["Associated Identifiers"].tap()
        // Inside Associated Identifiers view
        app.checkLocalization()

        app.navigationBars["AirshipDebugKit.AssociatedIdentifiersTableView"].buttons["Add"].tap()
        // Inside associated identifiers addition view
        app.checkLocalization()

        app.goBack()
        app.goBack()

        // Don't check in last payload view
        tablesQuery.staticTexts["Last Push Payload"].tap()
    }

    func testDebugEventsView() {
        app.tabBars.buttons["Debug"].tap()

        let tablesQuery = app.tables.element
        tablesQuery.staticTexts["Events"].tap()

        // Inside events view
        app.checkLocalization()

        app.tables.element.tap()

        // Inside first event view
        app.checkLocalization()

        app.buttons["Add"].tap()
        let eventNameTextField = tablesQuery.cells.containing(.staticText, identifier:"Event Name").textFields["Required"]
        eventNameTextField.tap()
        eventNameTextField.typeText("ui test")

        let eventValueTextField = XCUIApplication().tables.cells.containing(.staticText, identifier:"Event Value").textFields["Required"]
        eventValueTextField.tap()
        eventValueTextField.typeText("1111")

        tablesQuery.staticTexts["Add Custom Property"].tap()

        // Inside add custom event view
        app.checkLocalization()

        let identifierTextField = XCUIApplication().tables.cells.containing(.staticText, identifier:"Identifier").textFields["Required"]
        identifierTextField.tap()
        identifierTextField.typeText("ui test custom property")

        tablesQuery.pickerWheels.element.adjust(toPickerWheelValue: "Boolean")
        tablesQuery.pickerWheels.element.adjust(toPickerWheelValue: "Number")
        tablesQuery.pickerWheels.element.adjust(toPickerWheelValue: "String")
        tablesQuery.pickerWheels.element.adjust(toPickerWheelValue: "Strings")

        app.tables.staticTexts["Strings"].tap()

        // Inside add strings event view
        app.checkLocalization()

        let addCustomStringsPropertyNavigationBar = app.navigationBars["Add Custom Strings Property"]
        addCustomStringsPropertyNavigationBar.buttons["Add"].tap()
        app.goBack()
        app.goBack()
        app.goBack()
        let createCustomEventNavigationBar = app.navigationBars["Create Custom Event"]
        createCustomEventNavigationBar.buttons["Done"].tap()

        // Inside alert view
        app.checkLocalization()

        app.alerts["Notice"].buttons["OK"].tap()
        createCustomEventNavigationBar.buttons["Cancel"].tap()
    }

    func testMessageCenterView() {
        app.tabBars.buttons["Message Center"].tap()

        // Inside message center view
        app.checkLocalization()

        let messageCenterNavigationBar = app.navigationBars["Message Center"]
        messageCenterNavigationBar.buttons["Edit"].tap()
        messageCenterNavigationBar.buttons["Cancel"].tap()
    }
}
