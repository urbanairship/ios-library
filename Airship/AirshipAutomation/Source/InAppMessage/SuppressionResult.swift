/* Copyright Airship and Contributors */

import Foundation

/// Result of an app suppression check for in-app automation.
public enum SuppressionResult: Sendable {
    /// Allow the message to display.
    case show
    /// Suppress the message.
    case suppress(AutomationAudience.MissBehavior)
}
