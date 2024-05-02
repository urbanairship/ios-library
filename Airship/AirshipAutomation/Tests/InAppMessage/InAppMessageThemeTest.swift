/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation

#if canImport(AirshipCore)
import AirshipCore
#endif

final class InAppMessageThemeTest: XCTestCase {

    private var testBundle: Bundle!

    override func setUpWithError() throws {
        testBundle = Bundle(for: type(of: self))
    }

    func testBannerParsing() {
        let bannerTheme = BannerTheme(plistName: "Valid-UAInAppMessageBannerStyle", bundle: testBundle)

        XCTAssertEqual(1, bannerTheme.additionalPadding.top)
        XCTAssertEqual(2, bannerTheme.additionalPadding.bottom)
        XCTAssertEqual(3, bannerTheme.additionalPadding.leading)
        XCTAssertEqual(4, bannerTheme.additionalPadding.trailing)
        XCTAssertEqual(5, bannerTheme.headerTheme.letterSpacing)
        XCTAssertEqual(6, bannerTheme.headerTheme.lineSpacing)
        XCTAssertEqual(7, bannerTheme.headerTheme.additionalPadding.top)
        XCTAssertEqual(8, bannerTheme.headerTheme.additionalPadding.bottom)
        XCTAssertEqual(9, bannerTheme.headerTheme.additionalPadding.leading)
        XCTAssertEqual(10, bannerTheme.headerTheme.additionalPadding.trailing)
        XCTAssertEqual(11, bannerTheme.bodyTheme.letterSpacing)
        XCTAssertEqual(12, bannerTheme.bodyTheme.lineSpacing)
        XCTAssertEqual(13, bannerTheme.bodyTheme.additionalPadding.top)
        XCTAssertEqual(14, bannerTheme.bodyTheme.additionalPadding.bottom)
        XCTAssertEqual(15, bannerTheme.bodyTheme.additionalPadding.leading)
        XCTAssertEqual(16, bannerTheme.bodyTheme.additionalPadding.trailing)
        XCTAssertEqual(17, bannerTheme.mediaTheme.additionalPadding.top)
        XCTAssertEqual(18, bannerTheme.mediaTheme.additionalPadding.bottom)
        XCTAssertEqual(19, bannerTheme.mediaTheme.additionalPadding.leading)
        XCTAssertEqual(20, bannerTheme.mediaTheme.additionalPadding.trailing)
        XCTAssertEqual(21, bannerTheme.buttonTheme.buttonHeight)
        XCTAssertEqual(22, bannerTheme.buttonTheme.additionalPadding.top)
        XCTAssertEqual(23, bannerTheme.buttonTheme.additionalPadding.bottom)
        XCTAssertEqual(24, bannerTheme.buttonTheme.additionalPadding.leading)
        XCTAssertEqual(25, bannerTheme.buttonTheme.additionalPadding.trailing)
        XCTAssertEqual(26, bannerTheme.maxWidth)
        XCTAssertEqual(27, bannerTheme.tapOpacity)
        XCTAssertEqual(28, bannerTheme.shadowTheme.radius)
        XCTAssertEqual(29, bannerTheme.shadowTheme.xOffset)
        XCTAssertEqual(30, bannerTheme.shadowTheme.yOffset)
        XCTAssertEqual("003100".airshipToColor() , bannerTheme.shadowTheme.color)
    }

    func testModalParsing() {
        let modalTheme = ModalTheme(plistName: "Valid-UAInAppMessageModalStyle", bundle: testBundle)

        XCTAssertEqual(1, modalTheme.additionalPadding.top)
        XCTAssertEqual(2, modalTheme.additionalPadding.bottom)
        XCTAssertEqual(3, modalTheme.additionalPadding.leading)
        XCTAssertEqual(4, modalTheme.additionalPadding.trailing)
        XCTAssertEqual(5, modalTheme.headerTheme.letterSpacing)
        XCTAssertEqual(6, modalTheme.headerTheme.lineSpacing)
        XCTAssertEqual(7, modalTheme.headerTheme.additionalPadding.top)
        XCTAssertEqual(8, modalTheme.headerTheme.additionalPadding.bottom)
        XCTAssertEqual(9, modalTheme.headerTheme.additionalPadding.leading)
        XCTAssertEqual(10, modalTheme.headerTheme.additionalPadding.trailing)
        XCTAssertEqual(11, modalTheme.bodyTheme.letterSpacing)
        XCTAssertEqual(12, modalTheme.bodyTheme.lineSpacing)
        XCTAssertEqual(13, modalTheme.bodyTheme.additionalPadding.top)
        XCTAssertEqual(14, modalTheme.bodyTheme.additionalPadding.bottom)
        XCTAssertEqual(15, modalTheme.bodyTheme.additionalPadding.leading)
        XCTAssertEqual(16, modalTheme.bodyTheme.additionalPadding.trailing)
        XCTAssertEqual(17, modalTheme.mediaTheme.additionalPadding.top)
        XCTAssertEqual(18, modalTheme.mediaTheme.additionalPadding.bottom)
        XCTAssertEqual(19, modalTheme.mediaTheme.additionalPadding.leading)
        XCTAssertEqual(20, modalTheme.mediaTheme.additionalPadding.trailing)
        XCTAssertEqual(21, modalTheme.buttonTheme.buttonHeight)
        XCTAssertEqual(22, modalTheme.buttonTheme.stackedButtonSpacing)
        XCTAssertEqual(23, modalTheme.buttonTheme.separatedButtonSpacing)
        XCTAssertEqual(24, modalTheme.buttonTheme.additionalPadding.top)
        XCTAssertEqual(25, modalTheme.buttonTheme.additionalPadding.bottom)
        XCTAssertEqual(26, modalTheme.buttonTheme.additionalPadding.leading)
        XCTAssertEqual(27, modalTheme.buttonTheme.additionalPadding.trailing)
        XCTAssertEqual(28, modalTheme.maxWidth)
        XCTAssertEqual(29, modalTheme.maxHeight)
        XCTAssertEqual("testDismissIconResourceName", modalTheme.dismissIconResource)

    }

    func testFullScreenParsing() {
        let fullScreenTheme = FullScreenTheme(plistName: "Valid-UAInAppMessageFullScreenStyle", bundle: testBundle)

        XCTAssertEqual(1, fullScreenTheme.additionalPadding.top)
        XCTAssertEqual(2, fullScreenTheme.additionalPadding.bottom)
        XCTAssertEqual(3, fullScreenTheme.additionalPadding.leading)
        XCTAssertEqual(4, fullScreenTheme.additionalPadding.trailing)
        XCTAssertEqual(5, fullScreenTheme.headerTheme.letterSpacing)
        XCTAssertEqual(6, fullScreenTheme.headerTheme.lineSpacing)
        XCTAssertEqual(7, fullScreenTheme.headerTheme.additionalPadding.top)
        XCTAssertEqual(8, fullScreenTheme.headerTheme.additionalPadding.bottom)
        XCTAssertEqual(9, fullScreenTheme.headerTheme.additionalPadding.leading)
        XCTAssertEqual(10, fullScreenTheme.headerTheme.additionalPadding.trailing)
        XCTAssertEqual(11, fullScreenTheme.bodyTheme.letterSpacing)
        XCTAssertEqual(12, fullScreenTheme.bodyTheme.lineSpacing)
        XCTAssertEqual(13, fullScreenTheme.bodyTheme.additionalPadding.top)
        XCTAssertEqual(14, fullScreenTheme.bodyTheme.additionalPadding.bottom)
        XCTAssertEqual(15, fullScreenTheme.bodyTheme.additionalPadding.leading)
        XCTAssertEqual(16, fullScreenTheme.bodyTheme.additionalPadding.trailing)
        XCTAssertEqual(17, fullScreenTheme.mediaTheme.additionalPadding.top)
        XCTAssertEqual(18, fullScreenTheme.mediaTheme.additionalPadding.bottom)
        XCTAssertEqual(19, fullScreenTheme.mediaTheme.additionalPadding.leading)
        XCTAssertEqual(20, fullScreenTheme.mediaTheme.additionalPadding.trailing)
        XCTAssertEqual(21, fullScreenTheme.buttonTheme.buttonHeight)
        XCTAssertEqual(22, fullScreenTheme.buttonTheme.stackedButtonSpacing)
        XCTAssertEqual(23, fullScreenTheme.buttonTheme.separatedButtonSpacing)
        XCTAssertEqual(24, fullScreenTheme.buttonTheme.additionalPadding.top)
        XCTAssertEqual(25, fullScreenTheme.buttonTheme.additionalPadding.bottom)
        XCTAssertEqual(26, fullScreenTheme.buttonTheme.additionalPadding.leading)
        XCTAssertEqual(27, fullScreenTheme.buttonTheme.additionalPadding.trailing)
        XCTAssertEqual("testDismissIconResourceName", fullScreenTheme.dismissIconResource)
    }

    func testHTMLParsing() {
        let htmlTheme = HTMLTheme(plistName: "Valid-UAInAppMessageHTMLStyle", bundle: testBundle)
        XCTAssertTrue(htmlTheme.hideDismissIcon == true)
        XCTAssertEqual(1, htmlTheme.additionalPadding.top)
        XCTAssertEqual(2, htmlTheme.additionalPadding.bottom)
        XCTAssertEqual(3, htmlTheme.additionalPadding.leading)
        XCTAssertEqual(4, htmlTheme.additionalPadding.trailing)
        XCTAssertEqual("testDismissIconResourceName", htmlTheme.dismissIconResource)
        XCTAssertEqual(28, htmlTheme.maxWidth)
        XCTAssertEqual(29, htmlTheme.maxHeight)
    }

    /// Test parsing an invalid style plist fails gracefully
    func testInvalidParsing() {
        XCTAssertNoThrow(BannerTheme(plistName: "Invalid-UAInAppMessageBannerStyle", bundle: testBundle))
        XCTAssertNoThrow(ModalTheme(plistName: "Invalid-UAInAppMessageModalStyle", bundle: testBundle))
        XCTAssertNoThrow(FullScreenTheme(plistName: "Invalid-UAInAppMessageFullScreenStyle", bundle: testBundle))
        XCTAssertNoThrow(HTMLTheme(plistName: "Invalid-UAInAppMessageHTMLStyle", bundle: testBundle))
    }

    /// Test when plist parsing fails the theme is equivalent to its default values
    func testBannerDefaults() {
        let theme = BannerTheme(plistName: "Non-existent plist name", bundle: testBundle)

        XCTAssertEqual(theme, BannerTheme.defaultValues)
    }

    /// Test when plist parsing fails the theme is equivalent to its default values
    func testModalDefaults() {
        let theme = ModalTheme(plistName: "Non-existent plist name", bundle: testBundle)

        XCTAssertEqual(theme, ModalTheme.defaultValues)
    }

    /// Test when plist parsing fails the theme is equivalent to its default values
    func testFullscreenDefaults() {
        let theme = FullScreenTheme(plistName: "Non-existent plist name", bundle: testBundle)

        XCTAssertEqual(theme, FullScreenTheme.defaultValues)
    }
    
    /// Test when plist parsing fails the theme is equivalent to its default values
    func testHTMLDefaults() {
        let theme = HTMLTheme(plistName: "Non-existent plist name", bundle: testBundle)

        XCTAssertEqual(theme, HTMLTheme.defaultValues)
    }
}
