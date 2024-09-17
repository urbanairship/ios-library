/* Copyright Airship and Contributors */

import Foundation

/// Open registration options
public final class OpenRegistrationOptions: NSObject, Codable, Sendable {

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


    func isEqual(to options: OpenRegistrationOptions) -> Bool {
        return platformName == options.platformName && identifiers == options.identifiers
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let options = object as? OpenRegistrationOptions else {
            return false
        }

        if self === options {
            return true
        }

        return isEqual(to: options)
    }

    func hash() -> Int {
        var result = 1
        result = 31 * result + platformName.hashValue
        result = 31 * result + (identifiers?.hashValue ?? 0)
        return result
    }
}
