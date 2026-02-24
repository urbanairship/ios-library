/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
import AirshipCore

final class InAppMessageContentValidationTest: XCTestCase {

    private var validHeading: InAppMessageTextInfo!
    private var validBody: InAppMessageTextInfo!
    private var validMedia: InAppMessageMediaInfo!
    // Assuming invalid media would have an invalid URL or type, but keeping it simple here
    private var validButtonLabel: InAppMessageTextInfo!
    private var validButton: InAppMessageButtonInfo!

    private let validText = "Valid Text"
    private let validIdentifier = "d17a055c-ed67-4101-b65f-cd28b5904c84"

    private let validURL = "some://image.png"

    private let validColor = InAppMessageColor(hexColorString: "#ffffff")
    private let validFontFam = ["sans-serif"]


    private var emptyHeading: InAppMessageTextInfo!
    private var emptyBody: InAppMessageTextInfo!
    private var emptyMedia: InAppMessageMediaInfo!
    private var emptyButtonLabel: InAppMessageTextInfo!
    private var emptyButton: InAppMessageButtonInfo!

    private var validVideoMedia: InAppMessageMediaInfo!
    private var validYoutubeMedia: InAppMessageMediaInfo!

    override func setUp() {
        super.setUp()
        // Valid components
        validHeading = InAppMessageTextInfo(text: validText, color: validColor, size: 22.0, fontFamilies: validFontFam, alignment: .center)
        validBody = InAppMessageTextInfo(text: validText, color: validColor, size: 16.0, fontFamilies: validFontFam, alignment: .center)
        validMedia = InAppMessageMediaInfo(url: validURL, type: .image, description: validText)
        validButtonLabel = InAppMessageTextInfo(text: validText, color: validColor, size: 10, fontFamilies: validFontFam, style: [.bold])
        validButton = InAppMessageButtonInfo(identifier: validIdentifier, label: validButtonLabel, actions: [:], backgroundColor: validColor, borderColor: validColor, borderRadius: 2)

        // Empty components
        emptyHeading = InAppMessageTextInfo(text: "", color: validColor, size: 22.0, fontFamilies: validFontFam, alignment: .center)
        emptyBody = InAppMessageTextInfo(text: "", color: validColor, size: 16.0, fontFamilies: validFontFam, alignment: .center)
        emptyMedia = InAppMessageMediaInfo(url: "", type: .image, description: "")
        emptyButtonLabel = InAppMessageTextInfo(text: "", color: validColor, size: 10, fontFamilies: validFontFam, style: [.bold])
        emptyButton = InAppMessageButtonInfo(identifier: "", label: validButtonLabel, actions: [:], backgroundColor: validColor, borderColor: validColor, borderRadius: 2)

        validVideoMedia = InAppMessageMediaInfo(url: validURL, type: .video, description: validText)
        validYoutubeMedia = InAppMessageMediaInfo(url: validURL, type: .video, description: validText)
    }

    func testBanner() {
        let valid = InAppMessageDisplayContent.Banner(
            heading: validHeading,
            body: validBody,
            media: validMedia,
            buttons: [validButton],
            buttonLayoutType: .stacked,
            template: .mediaLeft,
            backgroundColor: validColor,
            dismissButtonColor: validColor,
            borderRadius: 5,
            duration: 100.0,
            placement: .top
        )

        XCTAssertTrue(valid.validate())
    }

    func testInvalidBanner() {
        /// No heading or body
        let noHeaderOrBodyContent = InAppMessageDisplayContent.Banner(
            heading: nil,
            body: nil,
            media: validMedia,
            buttons: [validButton],
            buttonLayoutType: .stacked,
            template: .mediaLeft,
            backgroundColor: validColor,
            dismissButtonColor: validColor,
            borderRadius: 5,
            duration: 100.0,
            placement: .top
        )

        let tooManyButtons = InAppMessageDisplayContent.Banner(
            heading: validHeading,
            body: validBody,
            media: validYoutubeMedia,
            buttons: [validButton, validButton, validButton],
            buttonLayoutType: .stacked,
            template: .mediaLeft,
            backgroundColor: validColor,
            dismissButtonColor: validColor,
            borderRadius: 5,
            duration: 100.0,
            placement: .top
        )

        XCTAssertFalse(noHeaderOrBodyContent.validate())
        XCTAssertFalse(tooManyButtons.validate())
    }

    func testModal() {
        let valid = InAppMessageDisplayContent.Modal(
            heading: validHeading,
            body: validBody,
            media: validMedia,
            footer: validButton,
            buttons: [validButton],
            buttonLayoutType: .stacked,
            template: .mediaHeaderBody,
            dismissButtonColor: validColor,
            backgroundColor: validColor,
            borderRadius: 5,
            allowFullscreenDisplay: true
        )

        XCTAssertTrue(valid.validate())
    }

    func testInvalidModal() {
        let emptyHeadingAndBody = InAppMessageDisplayContent.Modal(
            heading: emptyHeading,
            body: emptyBody,
            media: validMedia,
            footer: validButton,
            buttons: [validButton],
            buttonLayoutType: .stacked,
            template: .mediaHeaderBody,
            dismissButtonColor: validColor,
            backgroundColor: validColor,
            borderRadius: 5,
            allowFullscreenDisplay: true
        )

        let tooManyButtons = InAppMessageDisplayContent.Modal(
            heading: emptyHeading,
            body: emptyBody,
            media: validMedia,
            footer: validButton,
            buttons: [validButton, validButton, validButton],
            buttonLayoutType: .stacked,
            template: .mediaHeaderBody,
            dismissButtonColor: validColor,
            backgroundColor: validColor,
            borderRadius: 5,
            allowFullscreenDisplay: true
        )

        XCTAssertFalse(tooManyButtons.validate())
        XCTAssertFalse(emptyHeadingAndBody.validate())
    }

    func testFullscreen() {
        let valid = InAppMessageDisplayContent.Fullscreen(
            heading: validHeading,
            body: validBody,
            media: validMedia,
            footer: validButton,
            buttons: [validButton],
            buttonLayoutType: .stacked,
            template: .mediaHeaderBody,
            dismissButtonColor: validColor,
            backgroundColor: validColor
        )

        XCTAssertTrue(valid.validate())
    }

    func testInvalidFullscreen() {
        let emptyHeadingAndBody = InAppMessageDisplayContent.Fullscreen(
            heading: emptyHeading,
            body: emptyBody,
            media: validMedia,
            footer: validButton,
            buttons: [validButton, validButton, validButton, validButton, validButton, validButton],
            buttonLayoutType: .stacked,
            template: .mediaHeaderBody,
            dismissButtonColor: validColor,
            backgroundColor: validColor)

        XCTAssertFalse(emptyHeadingAndBody.validate())
    }

    func testHTML() {
        let valid = InAppMessageDisplayContent.HTML(
            url: validURL,
            height: 100,
            width: 100,
            aspectLock: true,
            requiresConnectivity: true,
            dismissButtonColor: validColor,
            backgroundColor: validColor,
            borderRadius: 5,
            allowFullscreen: true
        )

        XCTAssertTrue(valid.validate())
    }

    func testInvalidHTML() {
        let emptyURL = InAppMessageDisplayContent.HTML(
            url: "",
            height: 100,
            width: 100,
            aspectLock: true,
            requiresConnectivity: true,
            dismissButtonColor: validColor,
            backgroundColor: validColor,
            borderRadius: 5,
            allowFullscreen: true
        )

        XCTAssertFalse(emptyURL.validate())
    }

    func testTextInfo() {
        XCTAssertTrue(validHeading.validate())
        XCTAssertTrue(validBody.validate())
        XCTAssertFalse(emptyHeading.validate())
        XCTAssertFalse(emptyBody.validate())
    }

    func testButtonInfo() {
        XCTAssertTrue(validButton.validate())
        XCTAssertFalse(emptyButton.validate())
    }
}
