/* Copyright Airship and Contributors */

import Foundation
import os

/**
 * Airship logger.
 * @note For internal use only. :nodoc:
 */
@objc(UAirshipLogger)
public class AirshipLogger : NSObject {

    @objc
    public static var loggingEnabled = true

    @objc
    public static var implementationErrorLoggingEnabled = true

    @objc
    public static var logLevel: UALogLevel = .error

    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    static let LOGGER = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "Airship")

    public static func trace(_ message: String,
                             fileID: String = #fileID,
                             line: Int = #line,
                             function: String = #function) {

        log(logLevel: UALogLevel.trace,
            message: message,
            fileID: fileID,
            line: line,
            function: function)
    }

    public static func debug(_ message: String,
                             fileID: String = #fileID,
                             line: Int = #line,
                             function: String = #function) {

        log(logLevel: UALogLevel.debug,
            message: message,
            fileID: fileID,
            line: line,
            function: function)
    }


    public static func info(_ message: String,
                            fileID: String = #fileID,
                            line: Int = #line,
                            function: String = #function) {
        log(logLevel: UALogLevel.trace,
            message: message,
            fileID: fileID,
            line: line,
            function: function)
    }

    public static func warn(_ message: String,
                            fileID: String = #fileID,
                            line: Int = #line,
                            function: String = #function) {
        log(logLevel: UALogLevel.trace,
            message: message,
            fileID: fileID,
            line: line,
            function: function)
    }

    public static func error(_ message: String,
                             fileID: String = #fileID,
                             line: Int = #line,
                             function: String = #function) {

        log(logLevel: UALogLevel.trace,
            message: message,
            fileID: fileID,
            line: line,
            function: function)
    }

    public static func impError(_ message: String,
                                fileID: String = #fileID,
                                line: Int = #line,
                                function: String = #function) {

        if (self.implementationErrorLoggingEnabled) {
            log(logLevel: UALogLevel.error,
                message: "🚨Airship Implementation Error🚨: \(message)",
                fileID: fileID,
                line: line,
                function: function)
        } else {
            log(logLevel: UALogLevel.error,
                message: "Airship Implementation Error: \(message)",
                fileID: fileID,
                line: line,
                function: function)
        }
    }

    private static func log(logLevel: UALogLevel,
                            message: String,
                            fileID: String,
                            line: Int,
                            function: String) {

        if (loggingEnabled && self.logLevel.rawValue >= logLevel.rawValue) {
            if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
                LOGGER.log(level: logType(logLevel), "[\(logInitial(logLevel))] \(fileID) \(function) [Line \(line)] \(message)")
            } else {
                print("[\(logInitial(logLevel))] \(fileID) \(function) [Line \(line)] \(message)")
            }
        }
    }

    private static func logInitial(_ logLevel: UALogLevel) -> String {
        switch logLevel {
        case .trace: return "T"
        case .debug: return "D"
        case .info: return "I"
        case .warn: return "W"
        case .error: return "E"
        default: return ""
        }
    }

    private static func logType(_ logLevel: UALogLevel) -> OSLogType {
        switch logLevel {
        case .trace: return OSLogType.debug
        case .debug: return OSLogType.debug
        case .info: return OSLogType.info
        case .warn: return OSLogType.info
        case .error: return OSLogType.error
        default: return OSLogType.default
        }
    }
}

