/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

/// The kinds of data the debug kit can record to disk.
///
/// Each is off until someone turns it on from its own screen, and each keeps its own
/// consent — enabling the evaluation log says nothing about the log viewer.
enum AirshipDebugCaptureKind: String, CaseIterable, Sendable {
    /// On-device AI evaluations: what the model was asked and what it answered.
    case aiEvaluations = "ai_evaluations"

    /// Airship SDK log messages.
    case logs = "logs"

    /// Shown in the confirmation prompt, as "Record <title>?".
    var title: String {
        switch self {
        case .aiEvaluations: "AI evaluations"
        case .logs: "SDK logs"
        }
    }

    /// What the reader is actually agreeing to keep on the device. Specific rather than
    /// generic, because the two differ in how sensitive they are: an evaluation record
    /// carries the app's own context, which is the whole reason the on-device model exists.
    var consentDetail: String {
        switch self {
        case .aiEvaluations:
            """
            Every evaluation will be written to this device's storage — including the \
            instructions, the context your app supplied, the rendered prompt and the \
            model's answer — until you turn this off.

            That context is the data the on-device model exists to keep local. Recording \
            it here keeps it on the device, but it does put it on disk in a readable form.
            """
        case .logs:
            """
            Airship SDK log messages will be written to this device's storage until you \
            turn this off. Anything the SDK logs — identifiers, payload fragments, error \
            detail — is written as-is.
            """
        }
    }
}

/// Remembers which captures the user has turned on, and tells the capture sites whether to
/// record.
///
/// Consent is the only gate: nothing is written before it is given, and turning a capture
/// off deletes what it has already stored rather than merely stopping the writes. The
/// intent is that a developer can always answer "is this app holding my data?" with "only
/// what I switched on, and not after I switch it off."
///
/// Stored in `UserDefaults`, which is enough for a debug preference and survives relaunches
/// the way the screens' other state does.
@MainActor
final class AirshipDebugCaptureConsent: ObservableObject {

    static let shared = AirshipDebugCaptureConsent()

    private static let keyPrefix = "com.urbanairship.debug.capture.enabled."

    private let defaults: UserDefaults

    /// Bumped on every change so SwiftUI redraws; the values themselves live in `defaults`.
    @Published private var revision: Int = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(_ kind: AirshipDebugCaptureKind) -> Bool {
        defaults.bool(forKey: Self.keyPrefix + kind.rawValue)
    }

    func setEnabled(_ enabled: Bool, for kind: AirshipDebugCaptureKind) {
        defaults.set(enabled, forKey: Self.keyPrefix + kind.rawValue)
        revision &+= 1
    }

    /// A binding for a toggle that must not flip on its own — reading reflects the stored
    /// value, but writing is ignored, so the screen can route the change through its
    /// confirmation prompt instead.
    func readOnlyBinding(for kind: AirshipDebugCaptureKind) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isEnabled(kind) ?? false },
            set: { _ in }
        )
    }
}
