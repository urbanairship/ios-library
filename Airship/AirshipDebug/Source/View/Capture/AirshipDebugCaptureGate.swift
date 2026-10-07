/* Copyright Airship and Contributors */

import SwiftUI

/// The switch at the top of a capture screen, plus the prompts either side of it.
///
/// Turning a capture on asks first, because the answer is "yes, write my data to this
/// device until I say stop" and that shouldn't happen from a stray tap. Turning it off asks
/// too, because it deletes what was already recorded — the one destructive thing either
/// screen does.
struct AirshipDebugCaptureGate: View {

    let kind: AirshipDebugCaptureKind

    /// Called after consent changes, so the screen can start/stop its recorder and reload.
    let onChange: (Bool) -> Void

    @ObservedObject
    private var consent = AirshipDebugCaptureConsent.shared

    @State
    private var confirmingEnable = false

    @State
    private var confirmingDisable = false

    private var isEnabled: Bool {
        consent.isEnabled(kind)
    }

    var body: some View {
        Section {
            Toggle(isOn: consent.readOnlyBinding(for: kind)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Record to this device")
                    Text(isEnabled ? "Recording" : "Not recording")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            // The toggle's own binding is read-only, so the tap routes through a
            // confirmation instead of flipping first and asking after.
            .allowsHitTesting(false)
            .overlay {
                Button {
                    if isEnabled {
                        confirmingDisable = true
                    } else {
                        confirmingEnable = true
                    }
                } label: {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text(
                isEnabled
                ? "Turning this off deletes everything recorded so far."
                : "Nothing is recorded until you turn this on."
            )
        }
        .alert("Record \(kind.title)?", isPresented: $confirmingEnable) {
            Button("Cancel", role: .cancel) {}
            Button("Start recording") {
                consent.setEnabled(true, for: kind)
                onChange(true)
            }
        } message: {
            Text(kind.consentDetail)
        }
        .alert("Stop and delete?", isPresented: $confirmingDisable) {
            Button("Cancel", role: .cancel) {}
            Button("Stop and delete", role: .destructive) {
                consent.setEnabled(false, for: kind)
                onChange(false)
            }
        } message: {
            Text(
                "Recording stops and everything recorded for \(kind.title) is deleted from "
                + "this device. This can't be undone."
            )
        }
    }
}

extension View {
    /// `textSelection` is unavailable on tvOS, where there is no cursor to select with.
    /// Applied through a helper so the capture screens read the same on every platform.
    @ViewBuilder
    func airshipDebugSelectableText() -> some View {
#if os(tvOS)
        self
#else
        self.textSelection(.enabled)
#endif
    }
}
