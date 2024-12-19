/* Copyright Airship and Contributors */

import Foundation

/// SMS registration options
public struct SMSRegistrationOptions: Codable, Sendable, Equatable, Hashable {

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
}
