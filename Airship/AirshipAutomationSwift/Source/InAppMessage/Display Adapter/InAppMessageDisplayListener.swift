import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class InAppMessageDisplayListener: InAppMessageResolutionDelegate {

    private let analytics: InAppMessageAnalyticsProtocol
    private let timer: ActiveTimerProtocol
    private var onDismiss: (@MainActor @Sendable (DisplayResult) -> Void)?
    private var isFirstDisplay: Bool = true

    init(
        analytics: InAppMessageAnalyticsProtocol,
        timer: ActiveTimerProtocol? = nil,
        onDismiss: @MainActor @escaping @Sendable (DisplayResult) -> Void
    ) {
        self.analytics = analytics
        self.onDismiss = onDismiss
        self.timer = timer ?? ActiveTimer()
    }

    // TODO make this part of the main delegate
    func onDisplay() {
        guard isFirstDisplay else { return }
        self.isFirstDisplay = false

        // TODO impression
        timer.start()

        analytics.recordEvent(
            InAppDisplayEvent(),
            layoutContext: nil
        )
    }

    func onButtonDismissed(buttonInfo: InAppMessageButtonInfo) {
        tryDismiss { time in
            analytics.recordEvent(
                InAppResolutionEvent.buttonTap(
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
                InAppResolutionEvent.timedOut(displayTime: time),
                layoutContext: nil
            )
            return .finished
        }
    }

    func onUserDismissed() {
        tryDismiss { time in
            analytics.recordEvent(
                InAppResolutionEvent.userDismissed(displayTime: time),
                layoutContext: nil
            )
            return .finished
        }
    }

    func onMessageTapDismissed() {
        tryDismiss { time in
            analytics.recordEvent(
                InAppResolutionEvent.messageTap(displayTime: time),
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
    }
}
