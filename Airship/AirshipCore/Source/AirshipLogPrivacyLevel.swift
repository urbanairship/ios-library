/* Copyright Airship and Contributors */

import Foundation
import os

/// Represents the possible log privacy level.
@objc
public enum AirshipLogPrivacyLevel: Int, Sendable, CustomStringConvertible {
    /**
     * Private log privacy level. Set by default.
     */
    @objc(UALogPrivacyLevelPrivate)
    case `private` = 0

    /**
     * Public log privacy level. Logs publicly when set via the AirshipConfig.
     */
    @objc(UALogPrivacyLevelPublic)
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
