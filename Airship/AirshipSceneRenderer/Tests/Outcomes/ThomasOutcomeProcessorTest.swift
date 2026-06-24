/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(1)))
@MainActor
struct ThomasOutcomeProcessorTest {

    // MARK: - Delegation (processSync)

    @Test
    func processSyncDelegatesDismiss() {
        let processor = processor()
        var delegated: [DelegatedOutcome] = []
        processor.processSync(
            outcomes: [.dismiss(.init(cancel: true, identifier: "proc.dismiss"))],
            formFieldValue: nil,
            delegated: { delegated.append($0) }
        )
        #expect(delegated.count == 1)
        guard case .dismiss(let payload) = delegated[0] else {
            Issue.record("Expected dismiss delegation")
            return
        }
        #expect(payload.cancel == true)
    }

    @Test
    func processSyncDelegatesFormSubmit() {
        let processor = processor()
        var delegated: [DelegatedOutcome] = []
        processor.processSync(
            outcomes: [.form(.init(command: .submit, identifier: "proc.form"))],
            formFieldValue: nil,
            delegated: { delegated.append($0) }
        )
        #expect(delegated.count == 1)
        guard case .formAction(let payload) = delegated[0] else {
            Issue.record("Expected formAction delegation")
            return
        }
        #expect(payload.command == .submit)
    }

    @Test
    func processSyncDelegatesAirshipAction() {
        let payload = ThomasActionsPayload(value: .object(["add_tags": .array([.string("a")])]))
        let processor = processor()
        var delegated: [DelegatedOutcome] = []
        processor.processSync(
            outcomes: [.airshipAction(.init(actions: payload, identifier: "proc.action"))],
            formFieldValue: nil,
            delegated: { delegated.append($0) }
        )
        #expect(delegated.count == 1)
        guard case .runAction(let outcome) = delegated[0] else {
            Issue.record("Expected runAction delegation")
            return
        }
        #expect(outcome.actions == payload)
    }

    @Test
    func processSyncAppliesStateActionWithFormFieldValue() {
        let fieldValue = ThomasFormField.Value.text("hello")
        var recorded: [(ThomasStateAction, ThomasFormField.Value?)] = []
        let processor = processor(onStateAction: { action, value in
            recorded.append((action, value))
        })
        processor.processSync(
            outcomes: [ThomasStateAction.clearState.asOutcome],
            formFieldValue: fieldValue,
            delegated: { _ in }
        )
        #expect(recorded.count == 1)
        #expect(recorded[0].0 == .clearState)
        #expect(recorded[0].1 == fieldValue)
    }

    // MARK: - Pager (processSync)

    @Test
    func processSyncPagerPlaybackPause() {
        let pager = pagerState(pages: ["p1", "p2"])
        let processor = processor(pagerState: pager)
        #expect(pager.inProgress == true)
        processor.processSync(
            outcomes: [.pagerPlayback(.init(command: .pause, identifier: "proc.pager.pb"))],
            formFieldValue: nil,
            delegated: { _ in }
        )
        #expect(pager.inProgress == false)
    }

    @Test
    func processSyncPagerNextNavigatesForward() {
        let pager = pagerState(pages: ["p1", "p2"])
        #expect(pager.currentPageId == "p1")
        let processor = processor(pagerState: pager)
        processor.processSync(
            outcomes: [.pagerStepNavigation(.init(direction: .next, boundaryBehavior: .ignore, identifier: "proc.pager.step"))],
            formFieldValue: nil,
            delegated: { _ in }
        )
        #expect(pager.currentPageId == "p2")
    }

    @Test
    func processSyncPagerAtLastNextBoundaryDismiss() {
        let pager = pagerState(pages: ["p1", "p2"])
        pager.navigateToPage(id: "p2")
        var delegated: [DelegatedOutcome] = []
        let processor = processor(pagerState: pager)
        processor.processSync(
            outcomes: [.pagerStepNavigation(.init(direction: .next, boundaryBehavior: .dismiss, identifier: "proc.pager.boundary"))],
            formFieldValue: nil,
            delegated: { delegated.append($0) }
        )
        #expect(delegated.count == 1)
        guard case .dismiss(let outcome) = delegated[0] else {
            Issue.record("Expected dismiss at boundary")
            return
        }
        #expect(outcome.cancel == false)
        #expect(outcome.identifier == ThomasButtonClickBehavior.dismiss.outcomeIdentifier)
    }

    @Test
    func processSyncPagerAtLastNextBoundaryWrapsToFirst() {
        let pager = pagerState(pages: ["p1", "p2"])
        pager.navigateToPage(id: "p2")
        let processor = processor(pagerState: pager)
        processor.processSync(
            outcomes: [.pagerStepNavigation(.init(direction: .next, boundaryBehavior: .wrap, identifier: "proc.pager.wrap"))],
            formFieldValue: nil,
            delegated: { _ in }
        )
        #expect(pager.currentPageId == "p1")
    }

    @Test
    func processSyncPagerAtFirstPreviousBoundaryWrapsToLast() {
        let pager = pagerState(pages: ["p1", "p2"])
        #expect(pager.currentPageId == "p1")
        let processor = processor(pagerState: pager)
        processor.processSync(
            outcomes: [.pagerStepNavigation(.init(direction: .previous, boundaryBehavior: .wrap, identifier: "proc.pager.wrap2"))],
            formFieldValue: nil,
            delegated: { _ in }
        )
        #expect(pager.currentPageId == "p2")
    }

    @Test
    func processSyncPagerJumpToStartAndEnd() {
        let pager = pagerState(pages: ["a", "b", "c"])
        pager.navigateToPage(id: "b")
        let processor = processor(pagerState: pager)
        processor.processSync(
            outcomes: [.pagerJumpNavigation(.init(page: .start, identifier: "proc.jump.start"))],
            formFieldValue: nil,
            delegated: { _ in }
        )
        #expect(pager.currentPageId == "a")
        processor.processSync(
            outcomes: [.pagerJumpNavigation(.init(page: .end, identifier: "proc.jump.end"))],
            formFieldValue: nil,
            delegated: { _ in }
        )
        #expect(pager.currentPageId == "c")
    }

    // MARK: - Video (processSync)

    @Test
    func processSyncMediaPlaybackPlay() {
        let video = VideoState(identifier: "vc")
        let processor = processor(videoState: video)
        #expect(video.isPlaying == false)
        processor.processSync(
            outcomes: [.mediaPlayback(.init(command: .play, identifier: "proc.video.play"))],
            formFieldValue: nil,
            delegated: { _ in }
        )
        #expect(video.isPlaying == true)
    }

    @Test
    func processSyncMediaAudioMute() {
        let video = VideoState(identifier: "vc")
        let processor = processor(videoState: video)
        #expect(video.isMuted == false)
        processor.processSync(
            outcomes: [.mediaAudio(.init(command: .mute, identifier: "proc.video.mute"))],
            formFieldValue: nil,
            delegated: { _ in }
        )
        #expect(video.isMuted == true)
    }

    // MARK: - Async process

    @Test
    func processWithoutYieldingOutcomesMatchesDelegationOfProcessSync() async {
        let processor = processor()
        var asyncDelegated: [DelegatedOutcome] = []
        await processor.process(
            outcomes: [
                .dismiss(.init(cancel: false, identifier: "proc.async.dismiss")),
                .form(.init(command: .validate, identifier: "proc.async.form")),
            ],
            formFieldValue: nil,
            delegated: { asyncDelegated.append($0) }
        )
        var syncDelegated: [DelegatedOutcome] = []
        processor.processSync(
            outcomes: [
                .dismiss(.init(cancel: false, identifier: "proc.async.dismiss")),
                .form(.init(command: .validate, identifier: "proc.async.form")),
            ],
            formFieldValue: nil,
            delegated: { syncDelegated.append($0) }
        )
        #expect(asyncDelegated.count == syncDelegated.count)
        for (a, b) in zip(asyncDelegated, syncDelegated) {
            #expect(sameDelegation(a, b))
        }
    }

    @Test
    func processWithStateActionAppliesStateThenDelegates() async {
        var stateCalls: [ThomasStateAction] = []
        let processor = processor(onStateAction: { action, _ in
            stateCalls.append(action)
        })
        var delegated: [DelegatedOutcome] = []
        await processor.process(
            outcomes: [
                ThomasStateAction.clearState.asOutcome,
                .dismiss(.init(cancel: nil, identifier: "proc.state.then.dismiss")),
            ],
            formFieldValue: nil,
            delegated: { delegated.append($0) }
        )
        #expect(stateCalls.count == 1)
        if case .clearState = stateCalls[0] {
        } else {
            Issue.record("Expected clearState")
        }
        #expect(delegated.count == 1)
        guard case .dismiss = delegated[0] else {
            Issue.record("Expected dismiss after state action")
            return
        }
    }

    @Test
    func processWithNilDependenciesIgnoresPagerVideoAndAsyncOutcomes() async {
        let processor = processor()
        var delegationCount = 0
        await processor.process(
            outcomes: [
                .pagerPlayback(.init(command: .pause, identifier: "proc.nil.deps.pb")),
                .asyncView(.init(command: .retry, identifier: "proc.nil.deps.async")),
            ],
            formFieldValue: nil,
            delegated: { _ in delegationCount += 1 }
        )
        #expect(delegationCount == 0)
    }

    // MARK: - Helpers

    private func sameDelegation(_ a: DelegatedOutcome, _ b: DelegatedOutcome) -> Bool {
        switch (a, b) {
        case (.dismiss(let da), .dismiss(let db)):
            return da.cancel == db.cancel && da.identifier == db.identifier
        case (.formAction(let fa), .formAction(let fb)):
            return fa.command == fb.command && fa.identifier == fb.identifier
        case (.runAction(let ra), .runAction(let rb)):
            return ra.actions == rb.actions && ra.identifier == rb.identifier
        default:
            return false
        }
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

    private func pagerState(pages: [String]) -> PagerState {
        let pager = PagerState(identifier: "test", branching: nil)
        pager.setPagesAndListenForUpdates(
            pages: pages.map { makePageItem(id: $0) },
            thomasState: .empty,
            swipeDisableSelectors: nil
        )
        return pager
    }

    private func processor(
        pagerState: PagerState? = nil,
        videoState: VideoState? = nil,
        asyncViewState: ThomasAsyncViewState? = nil,
        onStateAction: @escaping @Sendable @MainActor (ThomasStateAction, ThomasFormField.Value?) -> Void = { _, _ in }
    ) -> DefaultThomasOutcomeProcessor {
        DefaultThomasOutcomeProcessor(
            pagerState: pagerState,
            videoState: videoState,
            asyncViewState: asyncViewState,
            onStateAction: onStateAction
        )
    }
}
