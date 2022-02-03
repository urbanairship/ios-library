/* Copyright Airship and Contributors */

import Foundation

/**
 * SMS registration options
 */
@objc(UASMSRegistrationOptions)
public class SMSRegistrationOptions : NSObject, Codable {
    
    /**
     * Sender ID
     */
    let senderID: String
    
    private init(senderID: String) {
        self.senderID = senderID
    }
    
    /// Returns a SMS registration options with opt-in status
    /// - Parameter senderID: The sender ID
    /// - Returns: A SMS registration options.
    @objc
    public static func optIn(senderID: String) -> SMSRegistrationOptions {
        return SMSRegistrationOptions(senderID: senderID)
    }
}
