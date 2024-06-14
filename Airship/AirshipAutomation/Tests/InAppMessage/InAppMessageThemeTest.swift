/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class InAppMessageThemeTest: XCTestCase {

    private var testBundle: Bundle!

    override func setUpWithError() throws {
        testBundle = Bundle(for: type(of: self))
    }

    func testBannerParsing() throws {
        var bannerTheme = InAppMessageTheme.Banner.defaultTheme
        try bannerTheme.applyPlist(plistName: "Valid-UAInAppMessageBannerStyle", bundle: testBundle)

        // default is 24 horizontal padding
        XCTAssertEqual(1, bannerTheme.padding.top)
        XCTAssertEqual(2, bannerTheme.padding.bottom)
        XCTAssertEqual(27, bannerTheme.padding.leading)
        XCTAssertEqual(28, bannerTheme.padding.trailing)


        XCTAssertEqual(5, bannerTheme.header.letterSpacing)
        XCTAssertEqual(6, bannerTheme.header.lineSpacing)
        XCTAssertEqual(7, bannerTheme.header.padding.top)
        XCTAssertEqual(8, bannerTheme.header.padding.bottom)
        XCTAssertEqual(9, bannerTheme.header.padding.leading)
        XCTAssertEqual(10, bannerTheme.header.padding.trailing)
        XCTAssertEqual(11, bannerTheme.body.letterSpacing)
        XCTAssertEqual(12, bannerTheme.body.lineSpacing)
        XCTAssertEqual(13, bannerTheme.body.padding.top)
        XCTAssertEqual(14, bannerTheme.body.padding.bottom)
        XCTAssertEqual(15, bannerTheme.body.padding.leading)
        XCTAssertEqual(16, bannerTheme.body.padding.trailing)
        XCTAssertEqual(17, bannerTheme.media.padding.top)
        XCTAssertEqual(18, bannerTheme.media.padding.bottom)
        XCTAssertEqual(19, bannerTheme.media.padding.leading)
        XCTAssertEqual(20, bannerTheme.media.padding.trailing)
        XCTAssertEqual(21, bannerTheme.buttons.height)
        XCTAssertEqual(22, bannerTheme.buttons.padding.top)
        XCTAssertEqual(23, bannerTheme.buttons.padding.bottom)
        XCTAssertEqual(24, bannerTheme.buttons.padding.leading)
        XCTAssertEqual(25, bannerTheme.buttons.padding.trailing)
        XCTAssertEqual(26, bannerTheme.maxWidth)
        XCTAssertEqual(27, bannerTheme.tapOpacity)
        XCTAssertEqual(28, bannerTheme.shadow.radius)
        XCTAssertEqual(29, bannerTheme.shadow.xOffset)
        XCTAssertEqual(30, bannerTheme.shadow.yOffset)
        XCTAssertEqual("003100".airshipToColor() , bannerTheme.shadow.color)
    }

    func testModalParsing() throws {
        var modalTheme = InAppMessageTheme.Modal.defaultTheme
        try modalTheme.applyPlist(plistName: "Valid-UAInAppMessageModalStyle", bundle: testBundle)


        // default is 24 horizontal, 48 vertical
        XCTAssertEqual(49, modalTheme.padding.top)
        XCTAssertEqual(50, modalTheme.padding.bottom)
        XCTAssertEqual(27, modalTheme.padding.leading)
        XCTAssertEqual(28, modalTheme.padding.trailing)

        XCTAssertEqual(5, modalTheme.header.letterSpacing)
        XCTAssertEqual(6, modalTheme.header.lineSpacing)
        XCTAssertEqual(7, modalTheme.header.padding.top)
        XCTAssertEqual(8, modalTheme.header.padding.bottom)
        XCTAssertEqual(9, modalTheme.header.padding.leading)
        XCTAssertEqual(10, modalTheme.header.padding.trailing)
        XCTAssertEqual(11, modalTheme.body.letterSpacing)
        XCTAssertEqual(12, modalTheme.body.lineSpacing)
        XCTAssertEqual(13, modalTheme.body.padding.top)
        XCTAssertEqual(14, modalTheme.body.padding.bottom)
        XCTAssertEqual(15, modalTheme.body.padding.leading)
        XCTAssertEqual(16, modalTheme.body.padding.trailing)

        /// Default is -24 horizontal padding
        XCTAssertEqual(17, modalTheme.media.padding.top)
        XCTAssertEqual(18, modalTheme.media.padding.bottom)
        XCTAssertEqual(-5, modalTheme.media.padding.leading)
        XCTAssertEqual(-4, modalTheme.media.padding.trailing)

        XCTAssertEqual(21, modalTheme.buttons.height)
        XCTAssertEqual(22, modalTheme.buttons.stackedSpacing)
        XCTAssertEqual(23, modalTheme.buttons.separatedSpacing)
        XCTAssertEqual(24, modalTheme.buttons.padding.top)
        XCTAssertEqual(25, modalTheme.buttons.padding.bottom)
        XCTAssertEqual(26, modalTheme.buttons.padding.leading)
        XCTAssertEqual(27, modalTheme.buttons.padding.trailing)
        XCTAssertEqual(28, modalTheme.maxWidth)
        XCTAssertEqual(29, modalTheme.maxHeight)
        XCTAssertEqual("testDismissIconResourceName", modalTheme.dismissIconResource)
    }

    func testFullScreenParsing() throws {
        var fullscreenTheme = InAppMessageTheme.Fullscreen.defaultTheme
        try fullscreenTheme.applyPlist(plistName: "Valid-UAInAppMessageFullScreenStyle", bundle: testBundle)

        // default is 24 on all sides
        XCTAssertEqual(25, fullscreenTheme.padding.top)
        XCTAssertEqual(26, fullscreenTheme.padding.bottom)
        XCTAssertEqual(27, fullscreenTheme.padding.leading)
        XCTAssertEqual(28, fullscreenTheme.padding.trailing)

        XCTAssertEqual(5, fullscreenTheme.header.letterSpacing)
        XCTAssertEqual(6, fullscreenTheme.header.lineSpacing)
        XCTAssertEqual(7, fullscreenTheme.header.padding.top)
        XCTAssertEqual(8, fullscreenTheme.header.padding.bottom)
        XCTAssertEqual(9, fullscreenTheme.header.padding.leading)
        XCTAssertEqual(10, fullscreenTheme.header.padding.trailing)
        XCTAssertEqual(11, fullscreenTheme.body.letterSpacing)
        XCTAssertEqual(12, fullscreenTheme.body.lineSpacing)
        XCTAssertEqual(13, fullscreenTheme.body.padding.top)
        XCTAssertEqual(14, fullscreenTheme.body.padding.bottom)
        XCTAssertEqual(15, fullscreenTheme.body.padding.leading)
        XCTAssertEqual(16, fullscreenTheme.body.padding.trailing)

        /// Default is -24 horizontal padding
        XCTAssertEqual(17, fullscreenTheme.media.padding.top)
        XCTAssertEqual(18, fullscreenTheme.media.padding.bottom)
        XCTAssertEqual(-5, fullscreenTheme.media.padding.leading)
        XCTAssertEqual(-4, fullscreenTheme.media.padding.trailing)

        XCTAssertEqual(21, fullscreenTheme.buttons.height)
        XCTAssertEqual(22, fullscreenTheme.buttons.stackedSpacing)
        XCTAssertEqual(23, fullscreenTheme.buttons.separatedSpacing)
        XCTAssertEqual(24, fullscreenTheme.buttons.padding.top)
        XCTAssertEqual(25, fullscreenTheme.buttons.padding.bottom)
        XCTAssertEqual(26, fullscreenTheme.buttons.padding.leading)
        XCTAssertEqual(27, fullscreenTheme.buttons.padding.trailing)
        XCTAssertEqual("testDismissIconResourceName", fullscreenTheme.dismissIconResource)
    }

    func testHTMLParsing() throws {
        var htmlTheme = InAppMessageTheme.HTML.defaultTheme
        try htmlTheme.applyPlist(plistName: "Valid-UAInAppMessageHTMLStyle", bundle: testBundle)

        XCTAssertTrue(htmlTheme.hideDismissIcon == true)

        // default is 24 horizontal, 48 vertical
        XCTAssertEqual(49, htmlTheme.padding.top)
        XCTAssertEqual(50, htmlTheme.padding.bottom)
        XCTAssertEqual(27, htmlTheme.padding.leading)
        XCTAssertEqual(28, htmlTheme.padding.trailing)

        XCTAssertEqual("testDismissIconResourceName", htmlTheme.dismissIconResource)
        XCTAssertEqual(28, htmlTheme.maxWidth)
        XCTAssertEqual(29, htmlTheme.maxHeight)
    }


    /// Test when plist parsing fails the theme is equivalent to its default values
    func testBannerDefaults() {
        var theme = InAppMessageTheme.Banner.defaultTheme
        try? theme.applyPlist(plistName: "Non-existent plist name", bundle: testBundle)

        XCTAssertEqual(theme, InAppMessageTheme.Banner.defaultTheme)
    }

    /// Test when plist parsing fails the theme is equivalent to its default values
    func testModalDefaults() {
        var theme = InAppMessageTheme.Modal.defaultTheme
        try? theme.applyPlist(plistName: "Non-existent plist name", bundle: testBundle)

        XCTAssertEqual(theme, InAppMessageTheme.Modal.defaultTheme)
    }

    /// Test when plist parsing fails the theme is equivalent to its default values
    func testFullscreenDefaults() {
        var theme = InAppMessageTheme.Fullscreen.defaultTheme
        try? theme.applyPlist(plistName: "Non-existent plist name", bundle: testBundle)

        XCTAssertEqual(theme, InAppMessageTheme.Fullscreen.defaultTheme)
    }
    
    /// Test when plist parsing fails the theme is equivalent to its default values
    func testHTMLDefaults() {
        var theme = InAppMessageTheme.HTML.defaultTheme
        try? theme.applyPlist(plistName: "Non-existent plist name", bundle: testBundle)

        XCTAssertEqual(theme, InAppMessageTheme.HTML.defaultTheme)
    }
}
