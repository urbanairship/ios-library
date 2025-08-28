

@MainActor
final class ThomasPagerTracker {

    // Map of pager ID to trackers
    private var trackers: [String: Tracker] = [:]
    private var lastPagerPageEvent: [String: ThomasReportingEvent.PageViewEvent] = [:]

    func onPageView(
        pageEvent: ThomasReportingEvent.PageViewEvent,
        currentDisplayTime: TimeInterval
    ) {
        if trackers[pageEvent.identifier] == nil {
            trackers[pageEvent.identifier] = Tracker()
        }

        let page = Page(
            identifier: pageEvent.pageIdentifier,
            index: pageEvent.pageIndex
        )

        trackers[pageEvent.identifier]?.start(
            page: page,
            currentDisplayTime: currentDisplayTime
        )

        lastPagerPageEvent[pageEvent.identifier] = pageEvent
    }

    func stopAll(currentDisplayTime: TimeInterval) {
        self.trackers.values.forEach { $0.stop(currentDisplayTime: currentDisplayTime) }
    }

    func viewedPages(pagerIdentifier: String) -> [ThomasViewedPageInfo] {
        return trackers[pagerIdentifier]?.viewed ?? []
    }

    var summary: Set<ThomasReportingEvent.PagerSummaryEvent> {
        let summary = lastPagerPageEvent.map { id, event in
            ThomasReportingEvent.PagerSummaryEvent(
                identifier: id,
                viewedPages: trackers[id]?.viewed ?? [],
                pageCount: event.pageCount,
                completed: event.completed
            )
        }

        return Set(summary)
    }

    @MainActor
    fileprivate final class Tracker {
        private var currentPage: Page?
        var viewed: [ThomasViewedPageInfo] = []
        private var startTime: TimeInterval?

        func start(page: Page, currentDisplayTime: TimeInterval) {
            guard currentPage != page else { return }
            stop(currentDisplayTime: currentDisplayTime)
            self.currentPage = page
            self.startTime = currentDisplayTime
        }

        func stop(currentDisplayTime: TimeInterval) {
            guard let startTime, let currentPage else { return }

            viewed.append(
                ThomasViewedPageInfo(
                    identifier: currentPage.identifier,
                    index: currentPage.index,
                    displayTime: currentDisplayTime - startTime
                )
            )

            self.startTime = nil
            self.currentPage = nil
        }
    }

    fileprivate struct Page: Equatable {
        let identifier: String
        let index: Int
    }
}
