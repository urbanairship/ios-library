/* Copyright Airship and Contributors */

import Foundation
import os

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

class AirshipLogger {
    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    static let LOGGER = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Airship")
    
    public static func trace(_ message: String,
                             file: String = #file,
                             line: Int = #line,
                             function: String = #function) {

        log(logLevel: UALogLevel.trace,
            message: message,
            file:file,
            line: line,
            function: function)
    }

    public static func debug(_ message: String,
                             file: String = #file,
                             line: Int = #line,
                             function: String = #function) {

        log(logLevel: UALogLevel.debug,
            message: message,
            file:file,
            line: line,
            function: function)
    }
    

    public static func info(_ message: String,
                            file: String = #file,
                            line: Int = #line,
                            function: String = #function) {
        log(logLevel: UALogLevel.trace,
            message: message,
            file:file,
            line: line,
            function: function)
    }

    public static func warn(_ message: String,
                            file: String = #file,
                            line: Int = #line,
                            function: String = #function) {
        log(logLevel: UALogLevel.trace,
            message: message,
            file:file,
            line: line,
            function: function)
    }

    public static func error(_ message: String,
                            file: String = #file,
                            line: Int = #line,
                            function: String = #function) {

        log(logLevel: UALogLevel.trace,
            message: message,
            file:file,
            line: line,
            function: function)
    }

    private static func log(logLevel: UALogLevel,
                    message: String, file:
                        String = #file,
                    line: Int = #line,
                    function: String = #function) {

        if (uaLoggingEnabled.boolValue && logLevel.rawValue >= uaLogLevel.rawValue) {
            if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
                LOGGER.log(level: logType(logLevel), "[\(logInitial(logLevel))] \(function) [Line \(line)] \(message)")
            } else {
                print("[\(logInitial(logLevel))] \(function) [Line \(line)] \(message)")
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
