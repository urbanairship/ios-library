/* Copyright Airship and Contributors */

import Foundation

/// Protocol used by Airship to log all log messages within the SDK.
/// A custom log handlers should be set on `Airship.logHandler` before `Airship.takeOff`.
@objc(UAirshipLogHandler)
public protocol AirshipLogHandler {

    /// Called to log a message.
    /// - Parameters:
    ///     - logLevel: The Airship log level.
    ///     - logPrivacyLevel: The Airship log privacy level.
    ///     - message: The log message.
    ///     - fileID: The file ID.
    ///     - line: The line number.
    ///     - function: The function.
    @objc
    func log(
        logLevel: AirshipLogLevel,
        logPrivacyLevel: AirshipLogPrivacyLevel,
        message: String,
        fileID: String,
        line: UInt,
        function: String
    )
}
