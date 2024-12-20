/* Copyright Airship and Contributors */

import Foundation

/// Airship core resources
public final class AirshipCoreResources {

    /// Bundle
    public static let bundle = findBundle()

    private class func findBundle() -> Bundle {
        let mainBundle = Bundle.main
        let sourceBundle = Bundle(for: AirshipCoreResources.self)

        // SPM
        if let path = mainBundle.path(
            forResource: "Airship_AirshipCore",
            ofType: "bundle"
        ) {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        // Cocoapods (static)
        if let path = mainBundle.path(
            forResource: "AirshipCoreResources",
            ofType: "bundle"
        ) {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        // Cocoapods (framework)
        if let path = sourceBundle.path(
            forResource: "AirshipCoreResources",
            ofType: "bundle"
        ) {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        // Fallback to source
        return sourceBundle
    }
}
