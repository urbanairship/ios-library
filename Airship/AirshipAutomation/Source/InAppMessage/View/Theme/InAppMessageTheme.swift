/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

import AirshipCore

/// In-app message themes
public struct InAppMessageTheme {
    static func decode<T>(
        _ type: T.Type,
        plistName: String,
        bundle: Bundle? = Bundle.main
    ) throws -> T where T : Decodable {
        guard
            let bundle,
            let url = bundle.url(forResource: plistName, withExtension: "plist"),
            let data = try? Data(contentsOf: url)
        else {
            throw AirshipErrors.error("Unable to locate theme override \(plistName) from \(String(describing: bundle))")
        }

        return try PropertyListDecoder().decode(type, from: data)
    }

    static func decodeIfExists<T>(
        _ type: T.Type,
        plistName: String,
        bundle: Bundle? = Bundle.main
    ) throws -> T? where T : Decodable {
        guard
            let bundle,
            let url = bundle.url(forResource: plistName, withExtension: "plist"),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }

        return try PropertyListDecoder().decode(type, from: data)
    }
}

