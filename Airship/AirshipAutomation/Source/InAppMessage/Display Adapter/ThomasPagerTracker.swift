import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class ThomasPagerTracker {

    // Map of pager ID to trackers
    private var trackers: [String: Tracker] = [:]
    private var lastPagerInfo: [String: ThomasPagerInfo] = [:]

    private let timerFactory: @MainActor @Sendable () -> any ActiveTimerProtocol

    init(
        timerFactory: @escaping @MainActor @Sendable () -> any ActiveTimerProtocol = { return ActiveTimer() }
    ) {
        self.timerFactory = timerFactory
    }

    func onPageView(pagerInfo: ThomasPagerInfo) {
        if trackers[pagerInfo.identifier] == nil {
            trackers[pagerInfo.identifier] = Tracker()
        }

        let page = Page(
            identifier: pagerInfo.pageIdentifier,
            index: pagerInfo.pageIndex
        )

        trackers[pagerInfo.identifier]?.start(
            page,
            timer: timerFactory()
        )

        lastPagerInfo[pagerInfo.identifier] = pagerInfo
    }

    func stopAll() {
        self.trackers.values.forEach { $0.stop() }
    }

    func viewCount(pagerInfo: ThomasPagerInfo) -> Int {
        guard let tracker = trackers[pagerInfo.identifier] else {
            return 0
        }
        let page = Page(
            identifier: pagerInfo.pageIdentifier,
            index: pagerInfo.pageIndex
        )
        return tracker.viewCount(page)
    }

    var summary: [ThomasPagerInfo: [PageViewSummary]] {
        var result: [ThomasPagerInfo: [PageViewSummary]] = [:]
        lastPagerInfo.values.forEach { pagerInfo in
            result[pagerInfo] = trackers[pagerInfo.identifier]?.viewed ?? []
        }
        return result
    }

    @MainActor
    fileprivate final class Tracker {
        private var timer: (any ActiveTimerProtocol)?
        private var currentPage: Page?
        var viewed: [PageViewSummary] = []

        func start(_ page: Page, timer: any ActiveTimerProtocol) {
            guard currentPage != page else { return }
            stop()

            self.currentPage = page
            self.timer = timer
            timer.start()
        }

        func stop() {
            guard let timer = self.timer, let page = currentPage else { return }
            timer.stop()
            viewed.append(
                PageViewSummary(
                    identifier: page.identifier,
                    index: page.index,
                    displayTime: timer.time
                )
            )

            self.timer = nil
            self.currentPage = nil
        }

        func viewCount(_ page: Page) -> Int {
            var viewed = viewed.filter { summary in
                summary.identifier == page.identifier && summary.index == page.index
            }.count

            if (self.currentPage == page) {
                viewed += 1
            }
            return viewed
        }
    }

    fileprivate struct Page: Equatable {
        let identifier: String
        let index: Int
    }
}
