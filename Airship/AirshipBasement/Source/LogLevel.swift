/* Copyright Airship and Contributors */

import Foundation

/// Represents the possible log levels.
public enum AirshipLogLevel: String, Sendable, Decodable {
    /**
     * Undefined log level.
     */
    case undefined

    /**
     * No log messages.
     */
    case none

    /**
     * Log error messages.
     *
     * Used for critical errors, parse exceptions and other situations that cannot be gracefully handled.
     */
    case error

    /**
     * Log warning messages.
     *
     * Used for API deprecations, invalid setup and other potentially problematic situations.
     */
    case warn

    /**
     * Log informative messages.
     *
     * Used for reporting general SDK status.
     */
    case info

    /**
     * Log debugging messages.
     *
     * Used for reporting general SDK status with more detailed information.
     */
    case debug

    /**
     * Log detailed verbose messages.
     *
     * Used for reporting highly detailed SDK status that can be useful when debugging and troubleshooting.
     */
    case verbose
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            let stringValue = try container.decode(String.self)
            switch(stringValue.lowercased()) {
            case "undefined":
                self = .undefined
            case "none":
                self = .none
            case "error":
                self = .error
            case "warn":
                self = .warn
            case "info":
                self = .info
            case "debug":
                self = .debug
            case "verbose":
                self = .verbose
            default:
                self = .undefined
            }
        } catch {
            guard let intValue = try? container.decode(Int.self) else {
                throw error
            }
            
            switch(intValue) {
            case -1:
                self = .undefined
            case 0:
                self = .none
            case 1:
                self = .error
            case 2:
                self = .warn
            case 3:
                self = .info
            case 4:
                self = .debug
            case 5:
                self = .verbose
            default:
                throw error
            }
        }
    }
}
