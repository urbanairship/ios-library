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
    private var isFirstDisplay: Bool = true

    init(
        analytics: InAppMessageAnalyticsProtocol,
        tracker: ThomasPagerTracker? = nil,
        timer: ActiveTimerProtocol? = nil,
        onDismiss: @escaping @MainActor @Sendable (DisplayResult) -> Void
    ) {
        self.analytics = analytics
        self.tracker = tracker ?? ThomasPagerTracker()
        self.onDismiss = onDismiss
        self.timer = timer ?? ActiveTimer()
    }

    // TODO make this part of the main delegate
    func onDisplay() {
        guard self.isFirstDisplay else {
            return
        }

        self.isFirstDisplay = false

        // TODO impression
        timer.start()
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
    }

    func onFormSubmitted(
        formResult: ThomasFormResult,
        layoutContext: ThomasLayoutContext
    ) {
        // TODO pass through AirshipJSON instead of Any
        do {
            let result = try AirshipJSON.wrap(formResult.formData)
            analytics.recordEvent(
                InAppFormResultEvent(forms: result),
                layoutContext: layoutContext
            )
        } catch {
            AirshipLogger.error("Failed to wrap form result \(error)")
        }
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
        metadata: Any?,
        layoutContext: ThomasLayoutContext
    ) {
        // TODO pass through AirshipJSON instead of Any
        analytics.recordEvent(
            InAppButtonTapEvent(
                identifier: buttonIdentifier,
                reportingMetadata: try? AirshipJSON.wrap(metadata)
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
    }
    
    func onPageGesture(
        identifier: String,
        metadata: Any?,
        layoutContext: ThomasLayoutContext
    ) {
        // TODO pass through AirshipJSON instead of Any
        analytics.recordEvent(
            InAppGestureEvent(
                identifier: identifier,
                reportingMetadata: try? AirshipJSON.wrap(metadata)
            ),
            layoutContext: layoutContext
        )
    }
    
    func onPageAutomatedAction(
        identifier: String,
        metadata: Any?,
        layoutContext: ThomasLayoutContext
    ) {
        // TODO pass through AirshipJSON instead of Any
        analytics.recordEvent(
            InAppPageActionEvent(
                identifier: identifier,
                reportingMetadata: try? AirshipJSON.wrap(metadata)
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
    
    func onPromptPermissionResult(
        permission: AirshipPermission,
        startingStatus: AirshipPermissionStatus,
        endingStatus: AirshipPermissionStatus,
        layoutContext: ThomasLayoutContext
    ) {
        analytics.recordEvent(
            InAppPermissionResultEvent(
                permission: permission,
                startingStatus: startingStatus,
                endingStatus: endingStatus
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
    }
}
