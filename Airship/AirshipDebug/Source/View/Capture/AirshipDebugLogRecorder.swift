/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// One captured log message.
struct AirshipDebugLogRecord: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var date: Date
    /// `AirshipLogLevel.rawValue`. Stored as its string rather than the enum, which is
    /// `Decodable` but not `Encodable`.
    var level: String
    var message: String
    var fileID: String
    var line: Int
    var function: String
}

/// Records Airship SDK log messages to disk while the capture is switched on.
///
/// Attaches with `AirshipLogger.addTap(_:)` rather than taking
/// `AirshipConfig.logHandler`, which belongs to the app — an app that installed its own
/// handler keeps it, and sees no change in what reaches it.
///
/// The tap is called synchronously on whichever thread logged, so this does as little as
/// possible inline: check a flag, build a small struct, hand it to the store's queue. It
/// must never log, or it would recurse.
final class AirshipDebugLogRecorder: AirshipLogHandler, @unchecked Sendable {

    static let shared = AirshipDebugLogRecorder()

    let store = AirshipDebugCaptureStore<AirshipDebugLogRecord>(name: "logs")

    /// Mirrors the consent flag so the tap can read it without hopping to the main actor on
    /// every log line. Kept in step by `setRecording(_:)`.
    private let isRecording = AirshipAtomicValue<Bool>(false)

    private let token = AirshipAtomicValue<AirshipLogTapToken?>(nil)

    private init() {}

    /// Starts watching. Safe to call more than once; only the first call registers.
    ///
    /// Registering the tap does not start recording — `setRecording(_:)` does. The tap is
    /// installed up front so that switching capture on takes effect immediately, including
    /// for messages logged before any debug screen was opened.
    func start() {
        guard token.value == nil else { return }
        token.set(AirshipLogger.addTap(self))
    }

    /// Mirrors the consent flag into the tap.
    func setRecording(_ recording: Bool) {
        if recording { store.resume() }
        isRecording.set(recording)
    }

    func log(
        logLevel: AirshipLogLevel,
        message: String,
        fileID: String,
        line: UInt,
        function: String
    ) {
        guard isRecording.value else { return }

        store.append(
            AirshipDebugLogRecord(
                id: UUID(),
                date: Date(),
                level: logLevel.rawValue,
                message: message,
                fileID: fileID,
                line: Int(line),
                function: function
            )
        )
    }
}
