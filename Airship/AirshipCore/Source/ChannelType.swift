/* Copyright Airship and Contributors */

import Foundation

/// Channel type
public enum ChannelType: String, Codable, Sendable, Equatable {

    /**
     * Email channel
     */
    case email

    /**
     * SMS channel
     */
    case sms

    /**
     * Open channel
     */
    case open
}
