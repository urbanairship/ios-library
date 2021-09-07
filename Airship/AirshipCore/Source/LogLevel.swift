/* Copyright Airship and Contributors */

import Foundation

/**
 * Represents the possible log levels.
 */
@objc(UALogLevel)
public enum LogLevel: Int {
    /**
     * Undefined log level.
     */
    @objc(UALogLevelUndefined)
    case undefined = -1

    /**
     * No log messages.
     */
    @objc(UALogLevelNone)
    case none = 0

    /**
     * Log error messages.
     *
     * Used for critical errors, parse exceptions and other situations that cannot be gracefully handled.
     */
    @objc(UALogLevelError)
    case error = 1

    /**
     * Log warning messages.
     *
     * Used for API deprecations, invalid setup and other potentially problematic situations.
     */
    @objc(UALogLevelWarn)
    case warn = 2

    /**
     * Log informative messages.
     *
     * Used for reporting general SDK status.
     */
    @objc(UALogLevelInfo)
    case info = 3

    /**
     * Log debugging messages.
     *
     * Used for reporting general SDK status with more detailed information.
     */
    @objc(UALogLevelDebug)
    case debug = 4

    /**
     * Log detailed tracing messages.
     *
     * Used for reporting highly detailed SDK status that can be useful when debugging and troubleshooting.
     */
    @objc(UALogLevelTrace)
    case trace = 5
}
