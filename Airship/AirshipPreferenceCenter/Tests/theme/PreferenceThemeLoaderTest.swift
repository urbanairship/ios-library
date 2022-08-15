/* Copyright Airship and Contributors */

import XCTest
import SwiftUI

@testable
import AirshipPreferenceCenter

class PreferenceThemeLoaderTest: XCTestCase {

    func testFromPlist() throws {
        let bundle = Bundle(for: Self.self)

        let legacyTheme = try PreferenceCenterThemeLoader.fromPlist("TestLegacyTheme", bundle: bundle)
        let theme = try PreferenceCenterThemeLoader.fromPlist("TestTheme", bundle: bundle)

        XCTAssertEqual(legacyTheme, theme)
        XCTAssertNotEqual(PreferenceCenterTheme(), theme)
    }

    func testLoadEmptyPlist() throws {
        let bundle = Bundle(for: Self.self)

        let emptyTheme = try PreferenceCenterThemeLoader.fromPlist("TestThemeEmpty", bundle: bundle)

        XCTAssertNotNil(emptyTheme)
    }

    func testLoadInvalidPlist() throws {
        let bundle = Bundle(for: Self.self)

        XCTAssertThrowsError(
            try PreferenceCenterThemeLoader.fromPlist("TestThemeInvalid", bundle: bundle)
        )
    }

    func testInvalidFile() throws {
        let bundle = Bundle(for: Self.self)

        XCTAssertThrowsError(
            try PreferenceCenterThemeLoader.fromPlist("Not a file", bundle: bundle)
        )
    }
}
