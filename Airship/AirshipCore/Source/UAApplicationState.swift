/* Copyright Airship and Contributors */

/// Platform independent representation of application state.
/// @note For internal use only. :nodoc:
@objc
public enum UAApplicationState : Int {
    /// The active state.
    case active
    /// The inactive state.
    case inactive
    /// The background state.
    case background
}
