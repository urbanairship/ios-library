/* Copyright Airship and Contributors */

import Foundation

/// Button layout type
public enum InAppMessageButtonLayoutType: String, Codable, Sendable, Equatable {
    /// Stacked vertically
    case stacked

    /// Joined horizontally
    case joined

    /// Seperated horizontally
    case seperate
}
