/* Copyright Airship and Contributors */



/// Button layout type
public enum InAppMessageButtonLayoutType: String, Codable, Sendable, Equatable {
    /// Stacked vertically
    case stacked

    /// Joined horizontally
    case joined

    /// Separated horizontally
    case separate
}
