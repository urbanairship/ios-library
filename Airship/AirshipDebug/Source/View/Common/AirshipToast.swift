/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
/// Import AirshipCore for utilities
import AirshipCore
#endif

struct AirshipToast: View {
    struct Message: Equatable {
        let id: String
        let text: String
        let duration: TimeInterval
        
        init(id: String = UUID().uuidString, text: String, duration: TimeInterval = 1) {
            self.id = id
            self.text = text
            self.duration = duration
        }
    }

    @Binding
    var message: Message?

    @State
    private var toastTask: Task<(), Never>? = nil

    @State
    private var toastVisible: Bool = false

    @ViewBuilder
    private func makeView() -> some View {
        Text(message?.text ?? "")
            .padding()
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }

    @ViewBuilder
    var body: some View {
        makeView()
            .airshipOnChangeOf( self.message) { incoming in
                if incoming != nil {
                    showToast()
                }
            }
            .hideOpt(self.toastVisible == false || self.message == nil)
    }

    private func showToast() {
        self.toastTask?.cancel()

        guard let message = message else {
            return
        }

        let waitTask = Task {
            try? await Task.sleep(
                nanoseconds: UInt64(message.duration * 1_000_000_000)
            )
            return
        }

        Task {
            let _ = await waitTask.result
            await MainActor.run {
                if !waitTask.isCancelled {
                    self.toastVisible = false
                    self.message = nil
                }
            }
        }

        self.toastTask = waitTask
        self.toastVisible = true
    }
}

extension View {
    @ViewBuilder
    func hideOpt(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }
}
