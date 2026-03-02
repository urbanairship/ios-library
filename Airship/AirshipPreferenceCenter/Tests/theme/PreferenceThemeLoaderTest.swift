/* Copyright Airship and Contributors */

import Testing
import SwiftUI

@testable
import AirshipPreferenceCenter

@Suite("Preference Theme Loader")
struct PreferenceThemeLoaderTest {
    
    private class BundleFinder {}
    let bundle: Bundle
    
    init() {
        bundle = Bundle(for: BundleFinder.self)
    }
    
    @Test
    func fromPlist() throws {
        
        let legacyTheme = try PreferenceCenterThemeLoader.fromPlist(
            "TestLegacyTheme",
            bundle: bundle
        )
        let theme = try PreferenceCenterThemeLoader.fromPlist(
            "TestTheme",
            bundle: bundle
        )
        
        #expect(legacyTheme == theme)
        #expect(PreferenceCenterTheme() != theme)
    }
    
    @Test
    func loadEmptyPlist() throws {
        _ = try PreferenceCenterThemeLoader.fromPlist(
            "TestThemeEmpty",
            bundle: bundle
        )
    }
    
    @Test
    func invalidFile() throws {
        #expect(throws: (any Error).self) {
            try PreferenceCenterThemeLoader.fromPlist("Not a file", bundle: bundle)
        }
    }
}
