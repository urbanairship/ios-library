/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipBasement

/// Taps exist so the debug kit can watch the log without taking
/// `AirshipConfig.logHandler`, which belongs to the app. The thing worth pinning down is
/// that adding one never changes what the app's own handler sees.
@MainActor
struct AirshipLoggerTapTest {

    private final class Recorder: AirshipLogHandler, @unchecked Sendable {
        let messages = AirshipAtomicValue<[String]>([])

        func log(
            logLevel: AirshipLogLevel,
            message: String,
            fileID: String,
            line: UInt,
            function: String
        ) {
            messages.update { $0.append(message) }
        }
    }

    /// Restores whatever the logger had configured, so these don't leak into other suites.
    private func withConfiguredHandler(
        _ handler: any AirshipLogHandler,
        _ body: () throws -> Void
    ) rethrows {
        AirshipLogger.configure(logLevel: .verbose, handler: handler)
        defer { AirshipLogger.configure(logLevel: .error, handler: DefaultLogHandler(privacyLevel: .private)) }
        try body()
    }

    @Test("A tap sees messages alongside the configured handler")
    func tapSeesMessages() throws {
        let app = Recorder()
        let tap = Recorder()

        try withConfiguredHandler(app) {
            let token = AirshipLogger.addTap(tap)
            defer { token.cancel() }

            AirshipLogger.error("boom")

            #expect(app.messages.value == ["boom"])
            #expect(tap.messages.value == ["boom"])
        }
    }

    @Test("Cancelling a tap stops it, and the app's handler carries on")
    func cancelledTapStops() throws {
        let app = Recorder()
        let tap = Recorder()

        try withConfiguredHandler(app) {
            let token = AirshipLogger.addTap(tap)
            AirshipLogger.error("first")
            token.cancel()
            AirshipLogger.error("second")

            #expect(tap.messages.value == ["first"])
            #expect(app.messages.value == ["first", "second"])
        }
    }

    @Test("A message below the log level reaches neither")
    func levelFilterAppliesToTaps() throws {
        let app = Recorder()
        let tap = Recorder()

        AirshipLogger.configure(logLevel: .error, handler: app)
        defer { AirshipLogger.configure(logLevel: .error, handler: DefaultLogHandler(privacyLevel: .private)) }

        let token = AirshipLogger.addTap(tap)
        defer { token.cancel() }

        AirshipLogger.debug("chatty")

        #expect(app.messages.value.isEmpty)
        #expect(tap.messages.value.isEmpty)
    }

    @Test("Several taps all see the message")
    func multipleTaps() throws {
        let app = Recorder()
        let first = Recorder()
        let second = Recorder()

        try withConfiguredHandler(app) {
            let tokenA = AirshipLogger.addTap(first)
            let tokenB = AirshipLogger.addTap(second)
            defer {
                tokenA.cancel()
                tokenB.cancel()
            }

            AirshipLogger.error("shared")

            #expect(first.messages.value == ["shared"])
            #expect(second.messages.value == ["shared"])
        }
    }
}
