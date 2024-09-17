/* Copyright Airship and Contributors */

import Foundation
import os

@objc
/// Represents the possible log privacy level.
public enum AirshipLogPrivacyLevel: Int, Sendable, CustomStringConvertible {
    /**
     * Private log privacy level. Set by default.
     */
    case `private` = 0

    /**
     * Public log privacy level. Logs publicly when set via the AirshipConfig.
     */
    case `public` = 1

    public var description: String {
        switch self {
        case .private:
            return "Private"
        case .public:
            return "Public"
        }
    }
}
