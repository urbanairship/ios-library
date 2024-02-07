/* Copyright Urban Airship and Contributors */

import SwiftUI

struct Toast: View {
    struct Message: Equatable {
        let id: String = UUID().uuidString
        let text: String
        let duration: TimeInterval
    }

    @Binding
    var message: Message?

    @State
    private var toastTask: Task<(), Never>? = nil

    @State
    private var toastVisible: Bool = false

    @ViewBuilder
    private func makeView() -> some View {
        if #available(iOS 15.0, *) {
            Text(message?.text ?? "")
                .padding()
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        } else {
            Text(message?.text ?? "")
                .padding()
                .background(Color.white.opacity(0.4))
                .cornerRadius(16)
        }
    }

    @ViewBuilder
    var body: some View {
        makeView()
            .onChange(of: self.message) { incoming in
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
                    withAnimation {
                        self.toastVisible = false
                        self.message = nil
                    }
                }
            }
        }

        self.toastTask = waitTask

        withAnimation {
            self.toastVisible = true
        }
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
