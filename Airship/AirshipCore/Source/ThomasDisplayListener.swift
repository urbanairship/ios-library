import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol ThomasLayoutMessageAnalyticsProtocol: AnyObject, Sendable {
    @MainActor
    func recordEvent(
        _ event: any ThomasLayoutEvent,
        layoutContext: ThomasLayoutContext?
    )
}

/// NOTE: For internal use only. :nodoc:
@MainActor
public final class ThomasDisplayListener: ThomasDelegate {
    /// NOTE: For internal use only. :nodoc:
    public enum DisplayResult: Sendable, Equatable {
        case cancel
        case finished
    }
    
    private let analytics: any ThomasLayoutMessageAnalyticsProtocol
    private var onDismiss: (@MainActor @Sendable (DisplayResult) -> Void)?

    public init(
        analytics: any ThomasLayoutMessageAnalyticsProtocol,
        onDismiss: @escaping @MainActor @Sendable (DisplayResult) -> Void
    ) {
        self.analytics = analytics
        self.onDismiss = onDismiss
    }

    public func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {
        if isVisible, isForegrounded {
            analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: nil)
        }
    }

    public func onReportingEvent(_ event: ThomasReportingEvent) {
        switch(event) {
        case .buttonTap(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutButtonTapEvent(data: event),
                layoutContext: layoutContext
            )
        case .formDisplay(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutFormDisplayEvent(data: event),
                layoutContext: layoutContext
            )
        case .formResult(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutFormResultEvent(data: event),
                layoutContext: layoutContext
            )
        case .gesture(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutGestureEvent(data: event),
                layoutContext: layoutContext
            )
        case .pageAction(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPageActionEvent(data: event),
                layoutContext: layoutContext
            )
        case .pagerCompleted(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPagerCompletedEvent(data: event),
                layoutContext: layoutContext
            )
        case .pageSwipe(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPageSwipeEvent(data: event),
                layoutContext: layoutContext
            )
        case .pageView(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPageViewEvent(data: event),
                layoutContext: layoutContext
            )
        case .pagerSummary(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPagerSummaryEvent(data: event),
                layoutContext: layoutContext
            )
        case .dismiss(let event, let displayTime, let layoutContext):
            switch(event) {
            case .buttonTapped(identifier: let identifier, description: let description):
                analytics.recordEvent(
                    ThomasLayoutResolutionEvent.buttonTap(
                        identifier: identifier,
                        description: description,
                        displayTime: displayTime
                    ),
                    layoutContext: layoutContext
                )
            case .timedOut:
                analytics.recordEvent(
                    ThomasLayoutResolutionEvent.timedOut(displayTime: displayTime),
                    layoutContext: layoutContext
                )
            case .userDismissed:
                analytics.recordEvent(
                    ThomasLayoutResolutionEvent.userDismissed(displayTime: displayTime),
                    layoutContext: layoutContext
                )
            @unknown default:
                AirshipLogger.error("Unhandled dismiss type event \(event)")
                analytics.recordEvent(
                    ThomasLayoutResolutionEvent.userDismissed(displayTime: displayTime),
                    layoutContext: layoutContext
                )
            }


        @unknown default: AirshipLogger.error("Unhandled IAX event \(event)")
        }
    }

    public func onDismissed(cancel: Bool) {
        self.onDismiss?(cancel ? .cancel : .finished)
        self.onDismiss = nil
    }
}
