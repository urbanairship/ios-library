/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct PagerStateLastPageTest {

    @MainActor
    @Test
    func lastNavigatesToFinalPageInMultiPagePager() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "page-1"), makePageItem(id: "page-2")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )
        #expect(pagerState.process(request: .last) != nil)
        #expect(pagerState.pageIndex == 1)
        #expect(pagerState.isLastPage == true)
    }

    @MainActor
    @Test
    func lastOnSinglePageDoesNotReportNavigation() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "only")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )
        #expect(pagerState.process(request: .last) == nil)
        #expect(pagerState.pageIndex == 0)
        #expect(pagerState.isLastPage == true)
    }

    @MainActor
    @Test
    func lastOnEmptyPagerReturnsNil() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.setPagesAndListenForUpdates(
            pages: [],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )
        #expect(pagerState.pageItems.isEmpty)
        #expect(pagerState.process(request: .last) == nil)
    }

    @MainActor
    @Test
    func lastFromMiddleGoesToLastPage() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.setPagesAndListenForUpdates(
            pages: [
                makePageItem(id: "p0"),
                makePageItem(id: "p1"),
                makePageItem(id: "p2")
            ],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )
        #expect(pagerState.process(request: .next) != nil)
        #expect(pagerState.currentPageId == "p1")
        #expect(pagerState.process(request: .last) != nil)
        #expect(pagerState.isLastPage == true)
        #expect(pagerState.pageIndex == 2)
    }

    @MainActor
    @Test
    func branchingPagerLastReachesFinalPage() {
        let branching = ThomasPagerControllerBranching(completions: [])
        let pagerState = PagerState(identifier: "branch", branching: branching)
        let thomasState = ThomasState(
            pagerState: pagerState,
            onStateChange: { _ in }
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "a"), makePageItem(id: "b")],
            thomasState: thomasState,
            swipeDisableSelectors: nil
        )
        #expect(pagerState.pageItems.count >= 1)
        _ = pagerState.process(request: .last)
        #expect(pagerState.isLastPage == true)
    }

    private func makePageItem(id: String) -> ThomasViewInfo.Pager.Item {
        ThomasViewInfo.Pager.Item(
            identifier: id,
            view: .emptyView(.init(commonProperties: .init(), properties: .init())),
            displayActions: nil,
            automatedActions: nil,
            accessibilityActions: nil,
            stateActions: nil,
            displayOutcomes: nil,
            branching: nil
        )
    }
}
