/* Copyright Airship and Contributors */

import Foundation

/// Channel scope.
public enum ChannelScope: String, Codable, Sendable, Equatable {
    /**
     * App channels - amazon, android, iOS
     */
    case app

    /**
     * Web channels
     */
    case web

    /**
     * Email channels
     */
    case email

    /**
     * SMS channels
     */
    case sms
}
