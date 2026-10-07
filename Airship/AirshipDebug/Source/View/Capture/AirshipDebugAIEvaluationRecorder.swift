/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipCore

/// One captured evaluation, flattened to strings at capture time.
///
/// `EvaluationRecord` isn't `Codable` — it carries an `Error` and a render closure — and
/// the screen only ever shows text, so the record is reduced here rather than at read time.
struct AirshipDebugAIEvaluationRecord: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var date: Date
    var usage: String
    var outcome: Outcome
    var durationMS: Int
    var attempts: Int
    var instructions: String
    var prompt: String
    var contextItems: [String]

    enum Outcome: Codable, Sendable, Equatable {
        case completed(output: String)
        case skipped(reason: String)
        case failed(error: String)
    }
}

/// Records on-device AI evaluations to disk while the capture is switched on.
///
/// Subscribes through `addEvaluationTap(_:)` rather than `setEvaluationObserver(_:)`, so the
/// app's own observer keeps working — the debug kit watches alongside it and never displaces
/// it.
///
/// The tap stays registered for the process's lifetime; consent is checked per record
/// instead. That keeps "is this recording?" a single question with a single answer, rather
/// than depending on whether a screen happened to be on-screen when the toggle flipped.
@MainActor
final class AirshipDebugAIEvaluationRecorder {

    static let shared = AirshipDebugAIEvaluationRecorder()

    let store = AirshipDebugCaptureStore<AirshipDebugAIEvaluationRecord>(
        name: "ai-evaluations"
    )

    private var token: AirshipAI.EvaluationTapToken?

    private init() {}

    /// Starts watching. Safe to call more than once; only the first call registers.
    func start(manager: any AirshipAI.InternalManager) {
        guard token == nil else { return }

        token = manager.addEvaluationTap { record in
            // The tap is delivered off the main actor. Hop back to read consent, which is
            // main-actor state, and hand the record to the store.
            Task { @MainActor in
                Self.shared.record(record)
            }
        }
    }

    private func record(_ record: AirshipAI.EvaluationRecord) {
        guard AirshipDebugCaptureConsent.shared.isEnabled(.aiEvaluations) else { return }

        let outcome: AirshipDebugAIEvaluationRecord.Outcome = switch record.outcome {
        case .completed(let json): .completed(output: json.prettyStringForDebug)
        case .skipped(let reason): .skipped(reason: reason)
        case .failed(let error): .failed(error: "\(error)")
        // `Outcome` is a non-frozen public enum, so a build against a newer Core has to
        // cope with a case this module has never heard of. Record it rather than drop it.
        @unknown default: .skipped(reason: "Unknown outcome")
        }

        store.append(
            AirshipDebugAIEvaluationRecord(
                id: UUID(),
                date: Date(),
                usage: record.usage.rawValue,
                outcome: outcome,
                durationMS: Int(record.duration * 1000),
                attempts: record.attempts,
                instructions: record.request.instructions,
                prompt: record.request.prompt(),
                contextItems: record.request.context.items.map { item in
                    "\(item.priority): \(item.content)"
                }
            )
        )
    }
}

extension AirshipJSON {
    /// Pretty-printed for display, falling back to the compact description when a value
    /// can't be encoded.
    var prettyStringForDebug: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? self.toString(encoder: encoder)) ?? "\(self)"
    }
}
