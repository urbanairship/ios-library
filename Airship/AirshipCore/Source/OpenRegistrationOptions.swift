/* Copyright Airship and Contributors */

import Foundation

/// Open registration options
public struct OpenRegistrationOptions: Codable, Sendable, Equatable, Hashable {

    /**
     * Platform name
     */
    let platformName: String

    /**
     * Identifiers
     */
    let identifiers: [String: String]?

    private init(platformName: String, identifiers: [String: String]?) {
        self.platformName = platformName
        self.identifiers = identifiers
    }

    /// Returns an open registration options with opt-in status
    /// - Parameter platformName: The platform name
    /// - Parameter identifiers: The identifiers
    /// - Returns: An open registration options.
    public static func optIn(
        platformName: String,
        identifiers: [String: String]?
    )
        -> OpenRegistrationOptions
    {
        return OpenRegistrationOptions(
            platformName: platformName,
            identifiers: identifiers
        )
    }
}
