/* Copyright Airship and Contributors */

import Foundation

/// Protocol used by Airship to log all log messages within the SDK.
/// A custom log handlers should be set on `Airship.logHandler` before `Airship.takeOff`.
public protocol AirshipLogHandler: Sendable {

    /// Called to log a message.
    /// - Parameters:
    ///     - logLevel: The Airship log level.
    ///     - message: The log message.
    ///     - fileID: The file ID.
    ///     - line: The line number.
    ///     - function: The function.
    func log(
        logLevel: AirshipLogLevel,
        message: String,
        fileID: String,
        line: UInt,
        function: String
    )
}
