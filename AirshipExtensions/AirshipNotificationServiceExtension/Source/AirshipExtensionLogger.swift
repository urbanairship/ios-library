/* Copyright Airship and Contributors */

import Foundation
import os

/// Represents the possible log levels.
public enum AirshipExtensionLogLevel: String, Sendable, Decodable {
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
}

/// Protocol used by AirshipExtension to log all messages..
public protocol AirshipExtensionLogHandler: Sendable {

    /// Called to log a message.
    /// - Parameters:
    ///     - logLevel: The Airship log level.
    ///     - message: The log message.
    ///     - fileID: The file ID.
    ///     - line: The line number.
    ///     - function: The function.
    func log(
        logLevel: AirshipExtensionLogLevel,
        message: String,
        fileID: String,
        line: UInt,
        function: String
    )
}

///
/// Airship extension logger.
///
final class AirshipExtensionLogger: Sendable {

    private let logHandler: (any AirshipExtensionLogHandler)?
    private let logLevel: AirshipExtensionLogLevel?

    init(
        logHandler: (any AirshipExtensionLogHandler)? = .defaultLogger,
        logLevel: AirshipExtensionLogLevel? = .error
    ) {
        self.logHandler = logHandler
        self.logLevel = logLevel
    }

    func trace(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: .verbose,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    func debug(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: .debug,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    func info(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: .info,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    func warn(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: .warn,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    func error(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: .error,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    func log(
        logLevel: AirshipExtensionLogLevel,
        message: @autoclosure () -> String,
        fileID: String,
        line: UInt,
        function: String
    ) {
        guard
            let logHandler,
            let configuredLevel = self.logLevel,
            configuredLevel.intValue >= logLevel.intValue
        else {
            return
        }

        logHandler.log(
            logLevel: logLevel,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }
}

public extension AirshipExtensionLogHandler where Self == DefaultAirshipExtensionLogHandler {
    /// Default logger
    static var defaultLogger: Self {
        return .init(logPublic: false)
    }

    /// Logger that logs publically
    static var publicLogger: Self {
        return .init(logPublic: true)
    }
}


public final class DefaultAirshipExtensionLogHandler: AirshipExtensionLogHandler {

    private let logPublic: Bool

    init(logPublic: Bool = false) {
        self.logPublic = logPublic
    }

    private static let logger: Logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "AirshipNotificationExtension"
    )

    public func log(
        logLevel: AirshipExtensionLogLevel,
        message: String,
        fileID: String,
        line: UInt,
        function: String
    ) {
        let logMessage = "[\(logLevel.initial)] \(fileID) \(function) [Line \(line)] \(message)"
        if (logPublic) {
            Self.logger.notice(
                "\(logMessage, privacy: .public)"
            )
        } else {
            Self.logger.log(
                level: logLevel.logType,
                "\(logMessage, privacy: .private)"
            )
        }
    }
}

extension AirshipExtensionLogLevel {
    fileprivate var initial: String {
        switch self {
        case .verbose: return "V"
        case .debug: return "D"
        case .info: return "I"
        case .warn: return "W"
        case .error: return "E"
        }
    }

    fileprivate var logType: OSLogType {
        switch self {
        case .verbose: return OSLogType.debug
        case .debug: return OSLogType.debug
        case .info: return OSLogType.info
        case .warn: return OSLogType.default
        case .error: return OSLogType.error
        }
    }

    fileprivate var intValue: Int {
        switch(self) {
        case .error:
            1
        case .warn:
            2
        case .info:
            3
        case .debug:
            4
        case .verbose:
            5
        }
    }
}

