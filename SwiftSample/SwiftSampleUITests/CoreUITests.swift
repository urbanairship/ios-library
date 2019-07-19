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
        let enablePushButton:XCUIElement = app.buttons["enablePushButton"]

        XCTAssert(airshipMark.exists)

        // Enable push button appears and can be touched
        XCTAssert(enablePushButton.isEnabled)
        XCTAssert(enablePushButton.isHittable)

        // Check localization on home view
        app.checkLocalization()
    }

    func testDebugDeviceInfoView() {
        app.tabBars.buttons["Debug"].tap()

        let tablesQuery = app.tables
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Device Info"]/*[[".cells.staticTexts[\"Device Info\"]",".staticTexts[\"Device Info\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        // Inside device info view
        app.checkLocalization()

        tablesQuery.staticTexts["Named User"].tap()
        // Inside named user addition view
        app.checkLocalization()

        app.navigationBars["AirshipDebugKit.AddNamedUserTableView"].buttons["Device Info"].tap()
        app.tables/*@START_MENU_TOKEN@*/.staticTexts["Tags"]/*[[".cells.staticTexts[\"Tags\"]",".staticTexts[\"Tags\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        // Inside tags view
        app.checkLocalization()

        app.navigationBars["Tags"].buttons["Add"].tap()
        // Inside tags addition view
        app.checkLocalization()

        app.navigationBars["AirshipDebugKit.AddTagsTableView"].buttons["Tags"].tap()
        app.navigationBars["Tags"].buttons["Device Info"].tap()

        tablesQuery.staticTexts["Associated Identifiers"].tap()
        // Inside Associated Identifiers view
        app.checkLocalization()

        app.navigationBars["AirshipDebugKit.AssociatedIdentifiersTableView"].buttons["Add"].tap()
        // Inside associated identifiers addition view
        app.checkLocalization()

        app.navigationBars["AirshipDebugKit.AddAssociatedIdentifiersTableView"].buttons["Back"].tap()
        app.navigationBars["AirshipDebugKit.AssociatedIdentifiersTableView"].buttons["Device Info"].tap()

        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Last Payload"]/*[[".cells.staticTexts[\"Last Payload\"]",".staticTexts[\"Last Payload\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        // Inside last payload view
        app.checkLocalization()
    }

    func testDebugEventsView() {
        app.tabBars.buttons["Debug"].tap()

        let tablesQuery = app.tables.element
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Events"]/*[[".cells.staticTexts[\"Events\"]",".staticTexts[\"Events\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        // Inside events view
        app.checkLocalization()

        app.tables.element.tap()

        // Inside first event view
        app.checkLocalization()
        app.navigationBars["AirshipDebugKit.EventsDetailTableView"].buttons["Events"].tap()
        app.navigationBars["Events"].buttons["Add"].tap()
        let eventsTextField = tablesQuery.cells.containing(.staticText, identifier:"Event Name").textFields["Required"]
        eventsTextField.tap()
        eventsTextField.typeText("ui test")

        let requiredTextField = tablesQuery/*@START_MENU_TOKEN@*/.textFields["Required"]/*[[".cells.textFields[\"Required\"]",".textFields[\"Required\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        requiredTextField.tap()
        requiredTextField.typeText("1111")

        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Add Custom Property"]/*[[".cells.staticTexts[\"Add Custom Property\"]",".staticTexts[\"Add Custom Property\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        // Inside add custom event view
        app.checkLocalization()

        requiredTextField.tap()
        requiredTextField.typeText("ui test custom property")

        tablesQuery.pickerWheels.element.adjust(toPickerWheelValue: "Boolean")
        tablesQuery.pickerWheels.element.adjust(toPickerWheelValue: "Number")
        tablesQuery.pickerWheels.element.adjust(toPickerWheelValue: "String")
        tablesQuery.pickerWheels.element.adjust(toPickerWheelValue: "Strings")

        app.tables/*@START_MENU_TOKEN@*/.staticTexts["Strings"]/*[[".cells.staticTexts[\"Strings\"]",".staticTexts[\"Strings\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        // Inside add strings event view
        app.checkLocalization()

        let addCustomStringsPropertyNavigationBar = app.navigationBars["Add Custom Strings Property"]
        addCustomStringsPropertyNavigationBar.buttons["Add"].tap()
        app.navigationBars["AirshipDebugKit.CustomPropertyAddStringsTableView"].buttons["Add Custom Strings Property"].tap()
        addCustomStringsPropertyNavigationBar.buttons["Add Custom Property"].tap()
        app.navigationBars["Add Custom Property"].buttons["Done"].tap()

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
