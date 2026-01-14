import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class InAppMessageDisplayListener: InAppMessageViewDelegate {

    private let analytics: any InAppMessageAnalyticsProtocol
    private let timer: any AirshipTimerProtocol
    private var onDismiss: (@MainActor @Sendable (DisplayResult) -> Void)?

    init(
        analytics: any InAppMessageAnalyticsProtocol,
        timer: (any AirshipTimerProtocol)? = nil,
        onDismiss: @MainActor @escaping @Sendable (DisplayResult) -> Void
    ) {
        self.analytics = analytics
        self.onDismiss = onDismiss
        self.timer = timer ?? ActiveTimer()
    }

    func onAppear() {
        timer.start()

        analytics.recordEvent(
            ThomasLayoutDisplayEvent(),
            layoutContext: nil
        )
    }

    func onButtonDismissed(buttonInfo: InAppMessageButtonInfo) {
        tryDismiss { time in
            analytics.recordEvent(
                ThomasLayoutResolutionEvent.buttonTap(
                    identifier: buttonInfo.identifier,
                    description: buttonInfo.label.text,
                    displayTime: time
                ),
                layoutContext: nil
            )
            return buttonInfo.behavior == .cancel ? .cancel : .finished
        }
    }

    func onTimedOut() {
        tryDismiss { time in
            analytics.recordEvent(
                ThomasLayoutResolutionEvent.timedOut(displayTime: time),
                layoutContext: nil
            )
            return .finished
        }
    }

    func onUserDismissed() {
        tryDismiss { time in
            analytics.recordEvent(
                ThomasLayoutResolutionEvent.userDismissed(displayTime: time),
                layoutContext: nil
            )
            return .finished
        }
    }

    func onMessageTapDismissed() {
        tryDismiss { time in
            analytics.recordEvent(
                ThomasLayoutResolutionEvent.messageTap(displayTime: time),
                layoutContext: nil
            )
            return .finished
        }
    }

    private func tryDismiss(dismissBlock: (TimeInterval) -> DisplayResult) {
        guard let onDismiss = onDismiss else {
            AirshipLogger.error("Dismissed already called!")
            return
        }

        self.timer.stop()
        let result = dismissBlock(self.timer.time)
        onDismiss(result)
        self.onDismiss = nil
    }
}
