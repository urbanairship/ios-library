/* Copyright Airship and Contributors */

/// Platform independent representation of application state.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum ApplicationState: Int, Sendable {
    /// The active state.
    case active
    /// The inactive state.
    case inactive
    /// The background state.
    case background
}
