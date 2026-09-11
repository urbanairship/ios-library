/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

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

    // MARK: - Restored state / authored page list alignment

    /// A snapshot shorter than the layout it lands in must not leave `pageIndex`
    /// out of range for `pageStates`. This is the expression `Pager.onTimer()`
    /// evaluates, and it trapped with "Index out of range" before the fix.
    @MainActor
    @Test
    func shortRestoredSnapshotStaysInBoundsForOnTimer() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.restorePersistentState(
            PagerState.Snapshot(
                pageStates: [PageState(identifier: "p0", delay: 5.0, automatedActions: nil)],
                currentPageId: "p2",
                progress: 0.0
            )
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "p0"), makePageItem(id: "p1"), makePageItem(id: "p2")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.pageStates.count == pagerState.pageItems.count)
        #expect(pagerState.pageIndex < pagerState.pageStates.count)
        #expect(pagerState.currentPageState != nil)

        // Verbatim the onTimer lookup.
        _ = pagerState.pageStates[pagerState.pageIndex].delay
    }

    /// An empty snapshot is `.some([])`, so it defeats a `??` fallback. It must fall
    /// back to freshly built states rather than restoring an empty array.
    @MainActor
    @Test
    func emptyRestoredSnapshotFallsBackToFreshStates() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.restorePersistentState(
            PagerState.Snapshot(pageStates: [], currentPageId: nil, progress: 0.0)
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "p0"), makePageItem(id: "p1")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.pageStates.count == 2)
        #expect(pagerState.pageIndex < pagerState.pageStates.count)
        _ = pagerState.pageStates[pagerState.pageIndex].delay
    }

    /// A snapshot naming pages that no longer exist must drop them and stay aligned.
    @MainActor
    @Test
    func restoredSnapshotWithStalePagesStaysAligned() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.restorePersistentState(
            PagerState.Snapshot(
                pageStates: [
                    PageState(identifier: "gone-1", delay: 1.0, automatedActions: nil),
                    PageState(identifier: "gone-2", delay: 1.0, automatedActions: nil),
                    PageState(identifier: "gone-3", delay: 1.0, automatedActions: nil)
                ],
                currentPageId: "p1",
                progress: 0.0
            )
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "p0"), makePageItem(id: "p1")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.pageStates.count == 2)
        #expect(pagerState.pageStates.map(\.identifier) == ["p0", "p1"])
        #expect(pagerState.pageIndex < pagerState.pageStates.count)
        _ = pagerState.pageStates[pagerState.pageIndex].delay
    }

    /// The alignment must not silently throw restored state away: a page that still
    /// exists keeps the state it was persisted with.
    @MainActor
    @Test
    func restoredStateIsPreservedForSurvivingPages() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.restorePersistentState(
            PagerState.Snapshot(
                pageStates: [PageState(identifier: "p1", delay: 99.0, automatedActions: nil)],
                currentPageId: "p1",
                progress: 0.0
            )
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "p0"), makePageItem(id: "p1")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        // authored items carry no automated actions, so a fresh state would be 0.0
        #expect(pagerState.pageStates.first(where: { $0.identifier == "p1" })?.delay == 99.0)
        #expect(pagerState.pageStates.first(where: { $0.identifier == "p0" })?.delay == 0.0)
        #expect(pagerState.pageStates.count == 2)
    }

    /// Reversal control: a snapshot that already matches the layout is unaffected.
    @MainActor
    @Test
    func matchingRestoredSnapshotIsUnchanged() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.restorePersistentState(
            PagerState.Snapshot(
                pageStates: [
                    PageState(identifier: "p0", delay: 3.0, automatedActions: nil),
                    PageState(identifier: "p1", delay: 4.0, automatedActions: nil)
                ],
                currentPageId: "p1",
                progress: 0.5
            )
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "p0"), makePageItem(id: "p1")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.pageStates.map(\.delay) == [3.0, 4.0])
        #expect(pagerState.progress == 0.5)
        #expect(pagerState.currentPageState != nil)
    }

    /// An empty pager still yields `pageIndex == 0`, which is not a valid index into
    /// either array. `Pager.onTimer()` depends on checking that before subscripting,
    /// so pin the contract it relies on.
    @MainActor
    @Test
    func emptyPagerYieldsNoValidPageIndex() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.setPagesAndListenForUpdates(
            pages: [],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.pageItems.isEmpty)
        #expect(pagerState.pageStates.isEmpty)
        #expect(pagerState.pageIndex == 0)
        #expect(pagerState.pageItems.indices.contains(pagerState.pageIndex) == false)
        #expect(pagerState.pageStates.indices.contains(pagerState.pageIndex) == false)
        #expect(pagerState.currentPageState == nil)
    }

    /// A snapshot persisted before the pager populated carries no page id. It must
    /// fall back to the first page rather than leaving the pager with no current page,
    /// which would mean the page is never reported.
    @MainActor
    @Test
    func snapshotWithNoPageIdSeedsFirstPage() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.restorePersistentState(
            PagerState.Snapshot(pageStates: [], currentPageId: nil, progress: 0.0)
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "p0"), makePageItem(id: "p1")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.currentPageId == "p0")
        #expect(pagerState.pageIndex == 0)
        #expect(pagerState.currentPageState != nil)
    }

    /// A snapshot naming a page this layout no longer has must not be used as the
    /// restore target - `currentPageId` would then disagree with `pageIndex`.
    @MainActor
    @Test
    func snapshotWithUnknownPageIdSeedsFirstPage() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.restorePersistentState(
            PagerState.Snapshot(
                pageStates: [PageState(identifier: "removed", delay: 2.0, automatedActions: nil)],
                currentPageId: "removed",
                progress: 0.8
            )
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "p0"), makePageItem(id: "p1")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.currentPageId == "p0")
        // progress belonged to the page we could not restore
        #expect(pagerState.progress == 0.0)
        #expect(pagerState.pageIndex < pagerState.pageStates.count)
    }

    /// A layout repeating an identifier consumes one restored state per occurrence.
    @MainActor
    @Test
    func repeatedIdentifiersConsumeOneRestoredStateEach() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.restorePersistentState(
            PagerState.Snapshot(
                pageStates: [
                    PageState(identifier: "dup", delay: 1.0, automatedActions: nil),
                    PageState(identifier: "dup", delay: 2.0, automatedActions: nil)
                ],
                currentPageId: "dup",
                progress: 0.0
            )
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "dup"), makePageItem(id: "dup")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.pageStates.map(\.delay) == [1.0, 2.0])
    }

    /// Control: a snapshot whose page still exists restores both the page and progress.
    @MainActor
    @Test
    func snapshotWithKnownPageIdRestoresPageAndProgress() {
        let pagerState = PagerState(identifier: "test", branching: nil)
        pagerState.restorePersistentState(
            PagerState.Snapshot(
                pageStates: [
                    PageState(identifier: "p0", delay: 1.0, automatedActions: nil),
                    PageState(identifier: "p1", delay: 2.0, automatedActions: nil)
                ],
                currentPageId: "p1",
                progress: 0.7
            )
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "p0"), makePageItem(id: "p1")],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.currentPageId == "p1")
        #expect(pagerState.progress == 0.7)
        #expect(pagerState.pageIndex == 1)
    }

    /// A branching pager's resolved path holds only the current route, so a restored
    /// page that exists in the layout but is off-route must still be honoured as the
    /// restore target rather than snapping back to the first page.
    @MainActor
    @Test
    func branchingRestoreHonoursOffRoutePage() {
        let branching = ThomasPagerControllerBranching(completions: [])
        let pagerState = PagerState(identifier: "branch", branching: branching)
        let thomasState = ThomasState(pagerState: pagerState, onStateChange: { _ in })

        pagerState.restorePersistentState(
            PagerState.Snapshot(
                pageStates: [PageState(identifier: "c", delay: 1.0, automatedActions: nil)],
                currentPageId: "c",
                progress: 0.4
            )
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [makePageItem(id: "a"), makePageItem(id: "b"), makePageItem(id: "c")],
            thomasState: thomasState,
            swipeDisableSelectors: nil
        )

        #expect(pagerState.currentPageId == "c")
        #expect(pagerState.progress == 0.4)
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
