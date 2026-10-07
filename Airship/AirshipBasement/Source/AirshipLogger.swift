/* Copyright Airship and Contributors */

import Foundation
import os

/// Airship logger.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class AirshipLogger: Sendable {
    // Configuration for the logger
    private static let configuration: Configuration = Configuration()

    private static var logLevel: AirshipLogLevel {
        return configuration.storage.logLevel
    }

    private static var logHandler: any AirshipLogHandler {
        return configuration.storage.handler
    }

    /// Secondary sinks that see every message alongside the configured handler.
    ///
    /// `AirshipConfig.logHandler` is the app's single slot, so an SDK component that wants
    /// to watch the log — the debug kit's log viewer — can't take it without displacing the
    /// app's own handler. Taps sit beside it instead: they never replace it, never see
    /// anything it wouldn't, and are filtered by the same log level.
    private static let taps: AirshipAtomicValue<[UUID: any AirshipLogHandler]> = .init([:])

    /// Adds a secondary sink, returning a token that removes it again.
    ///
    /// The tap is called synchronously on whatever thread logged the message, so it must be
    /// cheap: hand the message off and return. Anything slower belongs on the tap's own
    /// queue. A tap that logs will recurse — don't.
    @_spi(AirshipInternal)
    public static func addTap(_ tap: any AirshipLogHandler) -> AirshipLogTapToken {
        let id = UUID()
        taps.update { $0[id] = tap }
        return AirshipLogTapToken { taps.update { $0[id] = nil } }
    }

    /// Configures the logger. Called once during takeOff before we use the logger, so it should be
    /// thread safe by convention. If we run into issues with this, we may need to introduce locking or
    /// create a single instance that we inject everywhere.
    /// - Parameters:
    ///     - logLevel: The log level
    ///     - handler: The log handler
    @MainActor
    @_spi(AirshipInternal)
    public static func configure(
        logLevel: AirshipLogLevel,
        handler: (any AirshipLogHandler)
    ) {
        configuration.configure(logLevel: logLevel, handler: handler)
    }

    private final class Configuration: @unchecked Sendable {
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

    private static func log(
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
            // Resolved once: `message` is an autoclosure, and a tap must not cause the
            // caller's string interpolation to run a second time.
            let resolved = message()

            logHandler.log(
                logLevel: logLevel,
                message: resolved,
                fileID: fileID,
                line: line,
                function: function
            )

            let taps = Self.taps.value
            guard !taps.isEmpty else { return }
            for tap in taps.values {
                tap.log(
                    logLevel: logLevel,
                    message: resolved,
                    fileID: fileID,
                    line: line,
                    function: function
                )
            }
        }
    }
}

/// Removes a log tap when cancelled or deallocated.
///
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class AirshipLogTapToken: Sendable {
    private let onCancel: AirshipAtomicValue<(@Sendable () -> Void)?>

    init(_ onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = .init(onCancel)
    }

    public func cancel() {
        let block = onCancel.value
        onCancel.set(nil)
        block?()
    }

    deinit {
        onCancel.value?()
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
