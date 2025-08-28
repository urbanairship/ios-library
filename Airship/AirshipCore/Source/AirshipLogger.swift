/* Copyright Airship and Contributors */


import os

///
/// Airship logger.
///
/// - Note: For internal use only. :nodoc:
public final class AirshipLogger: Sendable {
    // Configuration for the logger
    private static let configuration = Configuration()

    static var logLevel: AirshipLogLevel {
        return configuration.storage.logLevel
    }

    static var logHandler: any AirshipLogHandler {
        return configuration.storage.handler
    }

    /// Configures the logger. Called once during takeOff before we use the logger, so it should be
    /// thread safe by convention. If we run into issues with this, we may need to introduce locking or
    /// create a single instance that we inject everywhere.
    /// - Parameters:
    ///     - logLevel: The log level
    ///     - handler: The log handler
    @MainActor
    static func configure(
        logLevel: AirshipLogLevel,
        handler: (any AirshipLogHandler)
    ) {
        configuration.configure(logLevel: logLevel, handler: handler)
    }

    fileprivate final class Configuration: @unchecked Sendable {
        struct Storage: Sendable {
            var logLevel: AirshipLogLevel
            var handler: any AirshipLogHandler
        }

        var storage: Storage = .init(
            logLevel: .error,
            handler: DefaultLogHandler(privacyLevel: .private)
        )

        @MainActor
        func configure(
            logLevel: AirshipLogLevel,
            handler: (any AirshipLogHandler)
        ) {
            let storage = Storage(logLevel: logLevel, handler: handler)
            // Replace both logLevel and handler at the same time
            self.storage = storage
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

        if skipLogLevelCheck || self.logLevel.intValue >= logLevel.intValue {
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

fileprivate extension AirshipLogLevel {
    var intValue: Int {
        switch(self) {
        case .undefined:
            -1
        case .none:
            0
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
