/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

import XCTest
@testable import AirshipMessageCenter
class MessageCenterThemeLoaderTests: XCTestCase {

    var themeLoader: MessageCenterThemeLoader!

    override func setUp() {
        super.setUp()
        themeLoader = MessageCenterThemeLoader()
    }

    override func tearDown() {
        themeLoader = nil
        super.tearDown()
    }

    func testFromPlist() {
        let testBundle = Bundle(for: type(of: self))

        do {
            let theme = try MessageCenterThemeLoader.fromPlist("ValidTestMessageCenterTheme", bundle: testBundle)

            let expectedHexColor = Color(AirshipColorUtils.color("#990099")!)
            let expectedExtendedHexColor = Color(AirshipColorUtils.color("#99009999")!)
            let expectedHexColorDark = Color(AirshipColorUtils.color("#000001")!)

            XCTAssertNotNil(theme)
            
            XCTAssertEqual(theme.refreshTintColor, expectedHexColor)
            XCTAssertEqual(theme.refreshTintColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.iconsEnabled, true)
            XCTAssertEqual(theme.placeholderIcon, Image("placeholderIcon"))
            XCTAssertEqual(theme.cellTitleFont, Font.custom("cellTitleFont", size: 16))
            XCTAssertEqual(theme.cellDateFont, Font.custom("cellDateFont", size: 14))
            XCTAssertEqual(theme.cellColor, expectedHexColor)
            XCTAssertEqual(theme.cellColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.cellTitleColor, expectedExtendedHexColor)
            XCTAssertEqual(theme.cellTitleColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.cellDateColor, expectedHexColor)
            XCTAssertEqual(theme.cellDateColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.cellSeparatorStyle, AirshipMessageCenter.SeparatorStyle.none)
            XCTAssertEqual(theme.cellSeparatorColor, Color("testNamedColor", bundle: testBundle))
            XCTAssertEqual(theme.cellSeparatorColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.cellTintColor, expectedHexColor)
            XCTAssertEqual(theme.cellTintColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.unreadIndicatorColor, expectedHexColor)
            XCTAssertEqual(theme.unreadIndicatorColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.selectAllButtonTitleColor, expectedHexColor)
            XCTAssertEqual(theme.selectAllButtonTitleColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.deleteButtonTitleColor, expectedHexColor)
            XCTAssertEqual(theme.deleteButtonTitleColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.markAsReadButtonTitleColor, expectedHexColor)
            XCTAssertEqual(theme.markAsReadButtonTitleColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.hideDeleteButton, true)
            XCTAssertEqual(theme.editButtonTitleColor, expectedHexColor)
            XCTAssertEqual(theme.editButtonTitleColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.cancelButtonTitleColor, expectedHexColor)
            XCTAssertEqual(theme.cancelButtonTitleColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.backButtonColor, expectedHexColor)
            XCTAssertEqual(theme.backButtonColorDark, expectedHexColorDark)
            XCTAssertEqual(theme.navigationBarTitle, "Test Navigation Bar Title")
        } catch {
            XCTFail("Failed to load theme from plist: \(error)")
        }
    }

    /// Tests that fonts of multiple sizings can be converted properly into CGFloat
    /// Users can specify font size in plist at String or Number
    func testFontConfigToFont() {
        /// Test CGFloat
        let fontConfigCGFloat = MessageCenterThemeLoader.FontConfig(fontName: "testFont", fontSize: .cgFloat(CGFloat(10)))

        do {
            let font = try fontConfigCGFloat.toFont()
            XCTAssertEqual(font, Font.custom("testFont", size: 10))
        } catch {
            XCTFail("Failed to convert FontConfig to Font: \(error)")
        }

        /// Test string
        let fontConfigString = MessageCenterThemeLoader.FontConfig(fontName: "testFont", fontSize: .string("12"))

        do {
            let font = try fontConfigString.toFont()
            XCTAssertEqual(font, Font.custom("testFont", size: 12))
        } catch {
            XCTFail("Failed to convert FontConfig to Font: \(error)")
        }
    }

    func testStringOrNamedToColor() {
        let testBundle = Bundle(for: type(of: self))
        /// This is testing the implementation:
        /// we want to be sure both conversions from hex OR named color name work as expected
        let colorHexString = "#990099"
        let expectedColor = Color(AirshipColorUtils.color(colorHexString)!)
        let hexColor = colorHexString.toColor(testBundle)
        XCTAssertEqual(hexColor, expectedColor)

        let colorName = "testNamedColor"
        let color = colorName.toColor(testBundle)
        XCTAssertEqual(color, Color(colorName, bundle:testBundle))
    }

    func testStringToSeparatorStyle() {
        let noneString = "none"
        let noneStyle = noneString.toSeparatorStyle()
        XCTAssertEqual(noneStyle, .none)

        let defaultString = "default"
        let defaultStyle = defaultString.toSeparatorStyle()
        XCTAssertEqual(defaultStyle, .singleLine)
    }
}
