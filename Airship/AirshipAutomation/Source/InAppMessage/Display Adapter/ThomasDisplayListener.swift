import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class ThomasDisplayListener: ThomasDelegate {
    private let analytics: InAppMessageAnalyticsProtocol
    
    private let timer: ActiveTimerProtocol
    private let tracker: ThomasPagerTracker
    private var onDismiss: (@MainActor @Sendable (DisplayResult) -> Void)?
    private var completedPagers: Set<String> = Set()

    init(
        analytics: InAppMessageAnalyticsProtocol,
        tracker: ThomasPagerTracker? = nil,
        timer: ActiveTimerProtocol? = nil,
        onDismiss: @escaping @MainActor @Sendable (DisplayResult) -> Void
    ) {
        self.analytics = analytics
        self.tracker = tracker ?? ThomasPagerTracker()
        self.onDismiss = onDismiss
        self.timer = timer ?? ManualActiveTimer()
    }

    func onVisbilityChanged(isVisible: Bool, isForegrounded: Bool) {
        if isVisible, isForegrounded {
            analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
            timer.start()
        } else {
            timer.stop()
        }
    }

    func onFormSubmitted(
        formResult: ThomasFormResult,
        layoutContext: ThomasLayoutContext
    ) {
        analytics.recordEvent(
            InAppFormResultEvent(forms: formResult.formData),
            layoutContext: layoutContext
        )
    }
    
    func onFormDisplayed(
        formInfo: ThomasFormInfo,
        layoutContext: ThomasLayoutContext
    ) {
        analytics.recordEvent(
            InAppFormDisplayEvent(formInfo: formInfo),
            layoutContext: layoutContext
        )
    }
    
    func onButtonTapped(
        buttonIdentifier: String,
        metadata: AirshipJSON?,
        layoutContext: ThomasLayoutContext
    ) {
        analytics.recordEvent(
            InAppButtonTapEvent(
                identifier: buttonIdentifier,
                reportingMetadata: metadata
            ),
            layoutContext: layoutContext
        )
    }
    
    func onDismissed(
        layoutContext: ThomasLayoutContext?
    ) {
        tryDismiss(layoutContext: layoutContext) { time in
            analytics.recordEvent(
                InAppResolutionEvent.userDismissed(displayTime: time),
                layoutContext: layoutContext
            )
            return .finished
        }
    }
    
    func onDismissed(
        buttonIdentifier: String,
        buttonDescription: String,
        cancel: Bool,
        layoutContext: ThomasLayoutContext
    ) {
        tryDismiss(layoutContext: layoutContext) { time in
            analytics.recordEvent(
                InAppResolutionEvent.buttonTap(
                    identifier: buttonIdentifier,
                    description: buttonDescription,
                    displayTime: time
                ),
                layoutContext: layoutContext
            )
            return cancel ? .cancel : .finished
        }

    }
    
    func onTimedOut(
        layoutContext: ThomasLayoutContext?
    ) {
        tryDismiss(layoutContext: layoutContext) { time in
            analytics.recordEvent(
                InAppResolutionEvent.timedOut(displayTime: time),
                layoutContext: layoutContext
            )
            return  .finished
        }

    }
    
    func onPageViewed(
        pagerInfo: ThomasPagerInfo,
        layoutContext: ThomasLayoutContext
    ) {
        self.tracker.onPageView(pagerInfo: pagerInfo)
        analytics.recordEvent(
            InAppPageViewEvent(
                pagerInfo: pagerInfo,
                viewCount: self.tracker.viewCount(pagerInfo: pagerInfo)
            ),
            layoutContext: layoutContext
        )

        if pagerInfo.completed, !completedPagers.contains(pagerInfo.identifier) {
            completedPagers.insert(pagerInfo.identifier)
            analytics.recordEvent(
                InAppPagerCompletedEvent(
                    pagerInfo: pagerInfo
                ),
                layoutContext: layoutContext
            )
        }
    }
    
    func onPageGesture(
        identifier: String,
        metadata: AirshipJSON?,
        layoutContext: ThomasLayoutContext
    ) {
        analytics.recordEvent(
            InAppGestureEvent(
                identifier: identifier,
                reportingMetadata: metadata
            ),
            layoutContext: layoutContext
        )
    }
    
    func onPageAutomatedAction(
        identifier: String,
        metadata: AirshipJSON?,
        layoutContext: ThomasLayoutContext
    ) {
        analytics.recordEvent(
            InAppPageActionEvent(
                identifier: identifier,
                reportingMetadata: metadata
            ),
            layoutContext: layoutContext
        )
    }

    func onPageSwiped(
        from: ThomasPagerInfo,
        to: ThomasPagerInfo,
        layoutContext: ThomasLayoutContext
    ) {
        analytics.recordEvent(
            InAppPageSwipeEvent(
                from: from,
                to: to
            ),
            layoutContext: layoutContext
        )
    }

    private func tryDismiss(
        layoutContext: ThomasLayoutContext? = nil,
        dismissBlock: (TimeInterval) -> DisplayResult
    ) {
        guard let onDismiss = onDismiss else {
            AirshipLogger.error("Dismissed already called!")
            return
        }

        self.timer.stop()

        self.tracker.stopAll()

        self.tracker.summary.forEach { pagerInfo, viewedPages in
            analytics.recordEvent(
                InAppPagerSummaryEvent(
                    pagerInfo: pagerInfo,
                    viewedPages: viewedPages
                ),
                layoutContext: layoutContext
            )
        }

        let result = dismissBlock(self.timer.time)
        onDismiss(result)
        self.onDismiss = nil
    }
}
