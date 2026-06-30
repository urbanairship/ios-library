/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

private final class InAppMessageThemeTestBundleToken {}

struct InAppMessageThemeTest {

    private let testBundle: Bundle

    init() throws {
        testBundle = Bundle(for: InAppMessageThemeTestBundleToken.self)
    }

    @Test
    func testBannerParsing() throws {
        var bannerTheme = InAppMessageTheme.Banner.defaultTheme
        try bannerTheme.applyPlist(plistName: "Valid-UAInAppMessageBannerStyle", bundle: testBundle)

        // default is 24 horizontal padding
        #expect(1 == bannerTheme.padding.top)
        #expect(2 == bannerTheme.padding.bottom)
        #expect(27 == bannerTheme.padding.leading)
        #expect(28 == bannerTheme.padding.trailing)


        #expect(5 == bannerTheme.header.letterSpacing)
        #expect(6 == bannerTheme.header.lineSpacing)
        #expect(7 == bannerTheme.header.padding.top)
        #expect(8 == bannerTheme.header.padding.bottom)
        #expect(9 == bannerTheme.header.padding.leading)
        #expect(10 == bannerTheme.header.padding.trailing)
        #expect(11 == bannerTheme.body.letterSpacing)
        #expect(12 == bannerTheme.body.lineSpacing)
        #expect(13 == bannerTheme.body.padding.top)
        #expect(14 == bannerTheme.body.padding.bottom)
        #expect(15 == bannerTheme.body.padding.leading)
        #expect(16 == bannerTheme.body.padding.trailing)
        #expect(17 == bannerTheme.media.padding.top)
        #expect(18 == bannerTheme.media.padding.bottom)
        #expect(19 == bannerTheme.media.padding.leading)
        #expect(20 == bannerTheme.media.padding.trailing)
        #expect(21 == bannerTheme.buttons.height)
        #expect(22 == bannerTheme.buttons.padding.top)
        #expect(23 == bannerTheme.buttons.padding.bottom)
        #expect(24 == bannerTheme.buttons.padding.leading)
        #expect(25 == bannerTheme.buttons.padding.trailing)
        #expect(26 == bannerTheme.maxWidth)
        #expect(27 == bannerTheme.tapOpacity)
        #expect(28 == bannerTheme.shadow.radius)
        #expect(29 == bannerTheme.shadow.xOffset)
        #expect(30 == bannerTheme.shadow.yOffset)
        #expect("003100".airshipToColor() == bannerTheme.shadow.color)
    }

    @Test
    func testModalParsing() throws {
        var modalTheme = InAppMessageTheme.Modal.defaultTheme
        try modalTheme.applyPlist(plistName: "Valid-UAInAppMessageModalStyle", bundle: testBundle)


        // default is 24 horizontal, 48 vertical
        #expect(49 == modalTheme.padding.top)
        #expect(50 == modalTheme.padding.bottom)
        #expect(27 == modalTheme.padding.leading)
        #expect(28 == modalTheme.padding.trailing)

        #expect(5 == modalTheme.header.letterSpacing)
        #expect(6 == modalTheme.header.lineSpacing)
        #expect(7 == modalTheme.header.padding.top)
        #expect(8 == modalTheme.header.padding.bottom)
        #expect(9 == modalTheme.header.padding.leading)
        #expect(10 == modalTheme.header.padding.trailing)
        #expect(11 == modalTheme.body.letterSpacing)
        #expect(12 == modalTheme.body.lineSpacing)
        #expect(13 == modalTheme.body.padding.top)
        #expect(14 == modalTheme.body.padding.bottom)
        #expect(15 == modalTheme.body.padding.leading)
        #expect(16 == modalTheme.body.padding.trailing)

        /// Default is -24 horizontal padding
        #expect(17 == modalTheme.media.padding.top)
        #expect(18 == modalTheme.media.padding.bottom)
        #expect(-5 == modalTheme.media.padding.leading)
        #expect(-4 == modalTheme.media.padding.trailing)

        #expect(21 == modalTheme.buttons.height)
        #expect(22 == modalTheme.buttons.stackedSpacing)
        #expect(23 == modalTheme.buttons.separatedSpacing)
        #expect(24 == modalTheme.buttons.padding.top)
        #expect(25 == modalTheme.buttons.padding.bottom)
        #expect(26 == modalTheme.buttons.padding.leading)
        #expect(27 == modalTheme.buttons.padding.trailing)
        #expect(28 == modalTheme.maxWidth)
        #expect(29 == modalTheme.maxHeight)
        #expect("testDismissIconResourceName" == modalTheme.dismissIconResource)
    }

    @Test
    func testFullScreenParsing() throws {
        var fullscreenTheme = InAppMessageTheme.Fullscreen.defaultTheme
        try fullscreenTheme.applyPlist(plistName: "Valid-UAInAppMessageFullScreenStyle", bundle: testBundle)

        // default is 24 on all sides
        #expect(25 == fullscreenTheme.padding.top)
        #expect(26 == fullscreenTheme.padding.bottom)
        #expect(27 == fullscreenTheme.padding.leading)
        #expect(28 == fullscreenTheme.padding.trailing)

        #expect(5 == fullscreenTheme.header.letterSpacing)
        #expect(6 == fullscreenTheme.header.lineSpacing)
        #expect(7 == fullscreenTheme.header.padding.top)
        #expect(8 == fullscreenTheme.header.padding.bottom)
        #expect(9 == fullscreenTheme.header.padding.leading)
        #expect(10 == fullscreenTheme.header.padding.trailing)
        #expect(11 == fullscreenTheme.body.letterSpacing)
        #expect(12 == fullscreenTheme.body.lineSpacing)
        #expect(13 == fullscreenTheme.body.padding.top)
        #expect(14 == fullscreenTheme.body.padding.bottom)
        #expect(15 == fullscreenTheme.body.padding.leading)
        #expect(16 == fullscreenTheme.body.padding.trailing)

        /// Default is -24 horizontal padding
        #expect(17 == fullscreenTheme.media.padding.top)
        #expect(18 == fullscreenTheme.media.padding.bottom)
        #expect(-5 == fullscreenTheme.media.padding.leading)
        #expect(-4 == fullscreenTheme.media.padding.trailing)

        #expect(21 == fullscreenTheme.buttons.height)
        #expect(22 == fullscreenTheme.buttons.stackedSpacing)
        #expect(23 == fullscreenTheme.buttons.separatedSpacing)
        #expect(24 == fullscreenTheme.buttons.padding.top)
        #expect(25 == fullscreenTheme.buttons.padding.bottom)
        #expect(26 == fullscreenTheme.buttons.padding.leading)
        #expect(27 == fullscreenTheme.buttons.padding.trailing)
        #expect("testDismissIconResourceName" == fullscreenTheme.dismissIconResource)
    }

    @Test
    func testHTMLParsing() throws {
        var htmlTheme = InAppMessageTheme.HTML.defaultTheme
        try htmlTheme.applyPlist(plistName: "Valid-UAInAppMessageHTMLStyle", bundle: testBundle)

        #expect(htmlTheme.hideDismissIcon == true)

        // default is 24 horizontal, 48 vertical
        #expect(49 == htmlTheme.padding.top)
        #expect(50 == htmlTheme.padding.bottom)
        #expect(27 == htmlTheme.padding.leading)
        #expect(28 == htmlTheme.padding.trailing)

        #expect("testDismissIconResourceName" == htmlTheme.dismissIconResource)
        #expect(28 == htmlTheme.maxWidth)
        #expect(29 == htmlTheme.maxHeight)
    }


    /// Test when plist parsing fails the theme is equivalent to its default values
    @Test
    func testBannerDefaults() {
        var theme = InAppMessageTheme.Banner.defaultTheme
        try? theme.applyPlist(plistName: "Non-existent plist name", bundle: testBundle)

        #expect(theme == InAppMessageTheme.Banner.defaultTheme)
    }

    /// Test when plist parsing fails the theme is equivalent to its default values
    @Test
    func testModalDefaults() {
        var theme = InAppMessageTheme.Modal.defaultTheme
        try? theme.applyPlist(plistName: "Non-existent plist name", bundle: testBundle)

        #expect(theme == InAppMessageTheme.Modal.defaultTheme)
    }

    /// Test when plist parsing fails the theme is equivalent to its default values
    @Test
    func testFullscreenDefaults() {
        var theme = InAppMessageTheme.Fullscreen.defaultTheme
        try? theme.applyPlist(plistName: "Non-existent plist name", bundle: testBundle)

        #expect(theme == InAppMessageTheme.Fullscreen.defaultTheme)
    }
    
    /// Test when plist parsing fails the theme is equivalent to its default values
    @Test
    func testHTMLDefaults() {
        var theme = InAppMessageTheme.HTML.defaultTheme
        try? theme.applyPlist(plistName: "Non-existent plist name", bundle: testBundle)

        #expect(theme == InAppMessageTheme.HTML.defaultTheme)
    }
}
