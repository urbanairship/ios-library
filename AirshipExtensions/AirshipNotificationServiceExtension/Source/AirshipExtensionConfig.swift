/* Copyright Airship and Contributors */

import Foundation

/// Airship extension config. Can be supplied with the property `airshipExtensionConfig` in `UANotificationServiceExtension`.
public struct AirshipExtensionConfig {
    /// Log level. For no logs, use `nil`. Defaults to `error`.
    public var logLevel: AirshipExtensionLogLevel?

    /// Log handler. If `nil`, no logs will be logged. Defaults to `.defaultLogger`.
    public var logHandler: (any AirshipExtensionLogHandler)?

    public init(
        logLevel: AirshipExtensionLogLevel? = .error,
        logHandler: (any AirshipExtensionLogHandler)? = .defaultLogger
    ) {
        self.logLevel = logLevel
        self.logHandler = logHandler
    }
}
