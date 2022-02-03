/* Copyright Airship and Contributors */

import Foundation

/**
 * Open registration options
 */
@objc(UAOpenRegistrationOptions)
public class OpenRegistrationOptions : NSObject, Codable {
    
    /**
     * Platform name
     */
    let platformName: String
    
    /**
     * Identifiers
     */
    let identifiers: [String : String]?
    
    private init(platformName: String, identifiers: [String : String]?) {
        self.platformName = platformName
        self.identifiers = identifiers
    }
    
    /// Returns an open registration options with opt-in status
    /// - Parameter platformName: The platform name
    /// - Parameter identifiers: The identifiers
    /// - Returns: An open registration options.
    @objc
    public static func optIn(platformName: String, identifiers: [String : String]?) -> OpenRegistrationOptions {
        return OpenRegistrationOptions(platformName: platformName, identifiers: identifiers)
    }
}
