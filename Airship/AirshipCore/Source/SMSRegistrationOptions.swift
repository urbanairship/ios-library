/* Copyright Airship and Contributors */

import Foundation

/// SMS registration options
public final class SMSRegistrationOptions: NSObject, Codable, Sendable {

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
    public static func optIn(senderID: String) -> SMSRegistrationOptions {
        return SMSRegistrationOptions(senderID: senderID)
    }

    func isEqual(to options: SMSRegistrationOptions) -> Bool {
        return senderID == options.senderID
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let options = object as? SMSRegistrationOptions else {
            return false
        }

        if self === options {
            return true
        }

        return isEqual(to: options)
    }

    func hash() -> Int {
        return senderID.hashValue
    }
}
