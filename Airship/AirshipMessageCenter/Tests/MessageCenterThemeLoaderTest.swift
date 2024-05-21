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

            let expectedRefreshTintColor = Color(AirshipColorUtils.color("#990099")!)
            let expectedRefreshTintColorDark = Color(AirshipColorUtils.color("#000001")!)
            let expectedCellColor = Color(AirshipColorUtils.color("#009900")!)
            let expectedCellColorDark = Color(AirshipColorUtils.color("#000002")!)
            let expectedCellTitleColor = Color(AirshipColorUtils.color("#000099")!)
            let expectedCellTitleColorDark = Color(AirshipColorUtils.color("#000003")!)
            let expectedCellDateColor = Color(AirshipColorUtils.color("#999900")!)
            let expectedCellDateColorDark = Color(AirshipColorUtils.color("#000004")!)
            let expectedCellSeparatorColorDark = Color(AirshipColorUtils.color("#000005")!)
            let expectedCellTintColor = Color(AirshipColorUtils.color("#990000")!)
            let expectedCellTintColorDark = Color(AirshipColorUtils.color("#000006")!)
            let expectedUnreadIndicatorColor = Color(AirshipColorUtils.color("#009999")!)
            let expectedUnreadIndicatorColorDark = Color(AirshipColorUtils.color("#000007")!)
            let expectedSelectAllButtonTitleColor = Color(AirshipColorUtils.color("#999999")!)
            let expectedSelectAllButtonTitleColorDark = Color(AirshipColorUtils.color("#000008")!)
            let expectedDeleteButtonTitleColor = Color(AirshipColorUtils.color("#123456")!)
            let expectedDeleteButtonTitleColorDark = Color(AirshipColorUtils.color("#000009")!)
            let expectedMarkAsReadButtonTitleColor = Color(AirshipColorUtils.color("#654321")!)
            let expectedMarkAsReadButtonTitleColorDark = Color(AirshipColorUtils.color("#000010")!)
            let expectedEditButtonTitleColor = Color(AirshipColorUtils.color("#abcdef")!)
            let expectedEditButtonTitleColorDark = Color(AirshipColorUtils.color("#000011")!)
            let expectedCancelButtonTitleColor = Color(AirshipColorUtils.color("#fedcba")!)
            let expectedCancelButtonTitleColorDark = Color(AirshipColorUtils.color("#000012")!)
            let expectedBackButtonColor = Color(AirshipColorUtils.color("#112233")!)
            let expectedBackButtonColorDark = Color(AirshipColorUtils.color("#000013")!)
            let expectedMessageListBackgroundColor = Color(AirshipColorUtils.color("#334455")!)
            let expectedMessageListBackgroundColorDark = Color(AirshipColorUtils.color("#000014")!)
            let expectedMessageListContainerBackgroundColor = Color(AirshipColorUtils.color("#556677")!)
            let expectedMessageListContainerBackgroundColorDark = Color(AirshipColorUtils.color("#000015")!)

            XCTAssertNotNil(theme)

            XCTAssertEqual(theme.refreshTintColor, expectedRefreshTintColor)
            XCTAssertEqual(theme.refreshTintColorDark, expectedRefreshTintColorDark)
            XCTAssertEqual(theme.iconsEnabled, true)
            XCTAssertEqual(theme.placeholderIcon, Image("placeholderIcon"))
            XCTAssertEqual(theme.cellTitleFont, Font.custom("cellTitleFont", size: 16))
            XCTAssertEqual(theme.cellDateFont, Font.custom("cellDateFont", size: 14))
            XCTAssertEqual(theme.cellColor, expectedCellColor)
            XCTAssertEqual(theme.cellColorDark, expectedCellColorDark)
            XCTAssertEqual(theme.cellTitleColor, expectedCellTitleColor)
            XCTAssertEqual(theme.cellTitleColorDark, expectedCellTitleColorDark)
            XCTAssertEqual(theme.cellDateColor, expectedCellDateColor)
            XCTAssertEqual(theme.cellDateColorDark, expectedCellDateColorDark)
            XCTAssertEqual(theme.cellSeparatorStyle, AirshipMessageCenter.SeparatorStyle.none)
            XCTAssertEqual(theme.cellSeparatorColor, Color("testNamedColor", bundle: testBundle))
            XCTAssertEqual(theme.cellSeparatorColorDark, expectedCellSeparatorColorDark)
            XCTAssertEqual(theme.cellTintColor, expectedCellTintColor)
            XCTAssertEqual(theme.cellTintColorDark, expectedCellTintColorDark)
            XCTAssertEqual(theme.unreadIndicatorColor, expectedUnreadIndicatorColor)
            XCTAssertEqual(theme.unreadIndicatorColorDark, expectedUnreadIndicatorColorDark)
            XCTAssertEqual(theme.selectAllButtonTitleColor, expectedSelectAllButtonTitleColor)
            XCTAssertEqual(theme.selectAllButtonTitleColorDark, expectedSelectAllButtonTitleColorDark)
            XCTAssertEqual(theme.deleteButtonTitleColor, expectedDeleteButtonTitleColor)
            XCTAssertEqual(theme.deleteButtonTitleColorDark, expectedDeleteButtonTitleColorDark)
            XCTAssertEqual(theme.markAsReadButtonTitleColor, expectedMarkAsReadButtonTitleColor)
            XCTAssertEqual(theme.markAsReadButtonTitleColorDark, expectedMarkAsReadButtonTitleColorDark)
            XCTAssertEqual(theme.hideDeleteButton, true)
            XCTAssertEqual(theme.editButtonTitleColor, expectedEditButtonTitleColor)
            XCTAssertEqual(theme.editButtonTitleColorDark, expectedEditButtonTitleColorDark)
            XCTAssertEqual(theme.cancelButtonTitleColor, expectedCancelButtonTitleColor)
            XCTAssertEqual(theme.cancelButtonTitleColorDark, expectedCancelButtonTitleColorDark)
            XCTAssertEqual(theme.backButtonColor, expectedBackButtonColor)
            XCTAssertEqual(theme.backButtonColorDark, expectedBackButtonColorDark)
            XCTAssertEqual(theme.navigationBarTitle, "Test Navigation Bar Title")
            XCTAssertEqual(theme.messageListBackgroundColor, expectedMessageListBackgroundColor)
            XCTAssertEqual(theme.messageListBackgroundColorDark, expectedMessageListBackgroundColorDark)
            XCTAssertEqual(theme.messageListContainerBackgroundColor, expectedMessageListContainerBackgroundColor)
            XCTAssertEqual(theme.messageListContainerBackgroundColorDark, expectedMessageListContainerBackgroundColorDark)
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
