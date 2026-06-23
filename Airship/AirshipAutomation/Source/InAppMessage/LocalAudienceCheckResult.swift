/* Copyright Airship and Contributors */

import Foundation

/// Result of a local audience check for in-app automation.
@_spi(AirshipInternal)
public enum LocalAudienceCheckResult: Sendable {
    /// The check passed — continue with normal evaluation.
    case match
    /// The check failed.
    case miss(AutomationAudience.MissBehavior)
}
