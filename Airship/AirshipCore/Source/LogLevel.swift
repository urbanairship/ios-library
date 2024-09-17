/* Copyright Airship and Contributors */

import Foundation

@objc
/// Represents the possible log levels.
public enum AirshipLogLevel: Int, Sendable {
    /**
     * Undefined log level.
     */
    case undefined = -1

    /**
     * No log messages.
     */
    case none = 0

    /**
     * Log error messages.
     *
     * Used for critical errors, parse exceptions and other situations that cannot be gracefully handled.
     */
    case error = 1

    /**
     * Log warning messages.
     *
     * Used for API deprecations, invalid setup and other potentially problematic situations.
     */
    case warn = 2

    /**
     * Log informative messages.
     *
     * Used for reporting general SDK status.
     */
    case info = 3

    /**
     * Log debugging messages.
     *
     * Used for reporting general SDK status with more detailed information.
     */
    case debug = 4

    /**
     * Log detailed verbose messages.
     *
     * Used for reporting highly detailed SDK status that can be useful when debugging and troubleshooting.
     */
    case verbose = 5
}
