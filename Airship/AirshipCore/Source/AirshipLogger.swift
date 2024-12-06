/* Copyright Airship and Contributors */

import Foundation
import os

///
/// Airship logger.
///
/// - Note: For internal use only. :nodoc:
public final class AirshipLogger: Sendable {
    private static let _storage = Storage()
    
    @MainActor
    static func configure(
        logLevel: AirshipLogLevel,
        handler: (any AirshipLogHandler)
    ) {
        _storage.logLevel = logLevel
        _storage.handler = handler
    }
    
    static var logLevel: AirshipLogLevel {
        return _storage.logLevel
    }
    
    static var logHandler: AirshipLogHandler {
        return _storage.handler
    }
    
    fileprivate final class Storage: @unchecked Sendable {
        var logLevel: AirshipLogLevel
        var handler: AirshipLogHandler
        
        init(
            logLevel: AirshipLogLevel = .error,
            handler: any AirshipLogHandler = DefaultLogHandler(privacyLevel: .private)
        ) {
            self.logLevel = logLevel
            self.handler = handler
        }
        
        func copy() -> Storage {
            return Storage(logLevel: self.logLevel, handler: self.handler)
        }
    }

    public static func trace(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {

        log(
            logLevel: AirshipLogLevel.verbose,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func debug(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {

        log(
            logLevel: AirshipLogLevel.debug,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func info(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: AirshipLogLevel.info,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func importantInfo(
        _ message: String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: AirshipLogLevel.info,
            message: message,
            fileID: fileID,
            line: line,
            function: function,
            skipLogLevelCheck: true
        )
    }

    public static func warn(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: AirshipLogLevel.warn,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func error(
        _ message: @autoclosure () -> String,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: AirshipLogLevel.error,
            message: message(),
            fileID: fileID,
            line: line,
            function: function
        )
    }

    public static func impError(
        _ message: @autoclosure () -> String,
        skipLogLevelCheck: Bool = true,
        fileID: String = #fileID,
        line: UInt = #line,
        function: String = #function
    ) {
        log(
            logLevel: AirshipLogLevel.error,
            message: "🚨Airship Implementation Error🚨: \(message())",
            fileID: fileID,
            line: line,
            function: function,
            skipLogLevelCheck: skipLogLevelCheck
        )
    }

    static func log(
        logLevel: AirshipLogLevel,
        message: @autoclosure () -> String,
        fileID: String,
        line: UInt,
        function: String,
        skipLogLevelCheck: Bool = false
    ) {

        guard self.logLevel != .none, self.logLevel != .undefined else {
            return
        }

        if skipLogLevelCheck || self.logLevel.rawValue >= logLevel.rawValue {
            logHandler.log(
                logLevel: logLevel,
                message: message(),
                fileID: fileID,
                line: line,
                function: function
            )
        }
    }
}
