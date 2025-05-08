import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class ThomasDisplayListener: ThomasDelegate {
    private let analytics: any InAppMessageAnalyticsProtocol
    private var onDismiss: (@MainActor @Sendable (DisplayResult) -> Void)?

    init(
        analytics: any InAppMessageAnalyticsProtocol,
        onDismiss: @escaping @MainActor @Sendable (DisplayResult) -> Void
    ) {
        self.analytics = analytics
        self.onDismiss = onDismiss
    }

    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {
        if isVisible, isForegrounded {
            analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        }
    }

    func onReportingEvent(_ event: ThomasReportingEvent) {
        switch(event) {
        case .buttonTap(let event, let layoutContext):
            analytics.recordEvent(
                InAppButtonTapEvent(data: event),
                layoutContext: layoutContext
            )
        case .formDisplay(let event, let layoutContext):
            analytics.recordEvent(
                InAppFormDisplayEvent(data: event),
                layoutContext: layoutContext
            )
        case .formResult(let event, let layoutContext):
            analytics.recordEvent(
                InAppFormResultEvent(data: event),
                layoutContext: layoutContext
            )
        case .gesture(let event, let layoutContext):
            analytics.recordEvent(
                InAppGestureEvent(data: event),
                layoutContext: layoutContext
            )
        case .pageAction(let event, let layoutContext):
            analytics.recordEvent(
                InAppPageActionEvent(data: event),
                layoutContext: layoutContext
            )
        case .pagerCompleted(let event, let layoutContext):
            analytics.recordEvent(
                InAppPagerCompletedEvent(data: event),
                layoutContext: layoutContext
            )
        case .pageSwipe(let event, let layoutContext):
            analytics.recordEvent(
                InAppPageSwipeEvent(data: event),
                layoutContext: layoutContext
            )
        case .pageView(let event, let layoutContext):
            analytics.recordEvent(
                InAppPageViewEvent(data: event),
                layoutContext: layoutContext
            )
        case .pagerSummary(let event, let layoutContext):
            analytics.recordEvent(
                InAppPagerSummaryEvent(data: event),
                layoutContext: layoutContext
            )
        case .dismiss(let event, let displayTime, let layoutContext):
            switch(event) {
            case .buttonTapped(identifier: let identifier, description: let description):
                analytics.recordEvent(
                    InAppResolutionEvent.buttonTap(
                        identifier: identifier,
                        description: description,
                        displayTime: displayTime
                    ),
                    layoutContext: layoutContext
                )
            case .timedOut:
                analytics.recordEvent(
                    InAppResolutionEvent.timedOut(displayTime: displayTime),
                    layoutContext: layoutContext
                )
            case .userDismissed:
                analytics.recordEvent(
                    InAppResolutionEvent.userDismissed(displayTime: displayTime),
                    layoutContext: layoutContext
                )
            @unknown default:
                AirshipLogger.error("Unhandled dismiss type event \(event)")
                analytics.recordEvent(
                    InAppResolutionEvent.userDismissed(displayTime: displayTime),
                    layoutContext: layoutContext
                )
            }


        @unknown default: AirshipLogger.error("Unhandled IAX event \(event)")
        }
    }

    func onDismissed(cancel: Bool) {
        self.onDismiss?(cancel ? .cancel : .finished)
        self.onDismiss = nil
    }
}
