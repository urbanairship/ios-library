/* Copyright Airship and Contributors */

import SwiftUI

struct ToastView: View {
    @ObservedObject
    private var toast: Toast

    init(toast: Toast) {
        self.toast = toast
    }
    
    @State
    private var toastTask: Task<(), Never>? = nil

    @State
    private var toastVisible: Bool = false

    @ViewBuilder
    private func makeView() -> some View {
        Text(toast.message?.text ?? "")
            .padding()
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }

    @ViewBuilder
    var body: some View {
        makeView()
            .airshipOnChangeOf(self.toast.message) { incoming in
                if incoming != nil {
                    showToast()
                }
            }
            .hideOpt(self.toastVisible == false || self.toast.message == nil)
    }

    private func showToast() {
        self.toastTask?.cancel()

        guard let message = toast.message else {
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
                        self.toast.message = nil
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
