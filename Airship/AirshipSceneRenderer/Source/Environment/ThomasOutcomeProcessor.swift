/* Copyright Airship and Contributors */

import Foundation

/// Outcomes from Thomas layout resolution that must be handled outside this processor
/// (dismissal, form submission, or running an Airship action).
///
enum DelegatedOutcome {
    case dismiss(ThomasOutcome.DismissOutcome)
    case formAction(ThomasOutcome.FormOutcome)
    case runAction(ThomasOutcome.AirshipActionOutcome)
}

/// Resolves ``ThomasOutcome`` values from layout interactions into state updates and delegated work.
protocol ThomasOutcomeProcessor {
    /// Processes outcomes, yielding between steps when a ``ThomasOutcome`` requires it
    /// (e.g. after state actions) so the main actor can process UI updates before continuing.
    /// - Parameters:
    ///   - outcomes: Ordered outcomes to apply.
    ///   - formFieldValue: Current form field value, when resolving in a form context.
    ///   - delegated: Callback for outcomes that leave this processor (dismiss, form, actions).
    @MainActor
    func process(
        outcomes: [ThomasOutcome],
        formFieldValue: ThomasFormField.Value?,
        delegated: @escaping @MainActor (DelegatedOutcome) -> Void
    ) async
    
    /// Processes all outcomes synchronously.
    /// - Parameters:
    ///   - outcomes: Ordered outcomes to apply.
    ///   - formFieldValue: Current form field value, when resolving in a form context.
    ///   - delegated: Callback for outcomes that leave this processor (dismiss, form, actions).
    @MainActor
    func processSync(
        outcomes: [ThomasOutcome],
        formFieldValue: ThomasFormField.Value?,
        delegated: @Sendable @escaping @MainActor (DelegatedOutcome) -> Void
    )
}

@MainActor
final class DefaultThomasOutcomeProcessor: ThomasOutcomeProcessor {
    private let pagerState: PagerState?
    private let videoState: VideoState?
    private let asyncViewState: ThomasAsyncViewState?
    private let applyStateAction: (ThomasStateAction, ThomasFormField.Value?) -> Void
    
    init(
        pagerState: PagerState?,
        videoState: VideoState?,
        asyncViewState: ThomasAsyncViewState?,
        onStateAction: @Sendable @escaping @MainActor (ThomasStateAction, ThomasFormField.Value?) -> Void
    ) {
        self.pagerState = pagerState
        self.videoState = videoState
        self.asyncViewState = asyncViewState
        self.applyStateAction = onStateAction
    }
    
    func process(
        outcomes: [ThomasOutcome],
        formFieldValue: ThomasFormField.Value?,
        delegated: @escaping @MainActor (DelegatedOutcome) -> Void
    ) async {
        guard outcomes.contains(where: { $0.shouldYieldAfterwards }) else {
            processSync(outcomes: outcomes, formFieldValue: formFieldValue, delegated: delegated)
            return
        }
        
        for index in 0..<outcomes.count {
            let outcome = outcomes[index]
            resolve(outcome: outcome, formFieldValue: formFieldValue, delegate: delegated)
            
            if index != outcomes.count - 1, outcomes[index + 1].shouldYieldAfterwards {
                continue
            }
            
            if outcome.shouldYieldAfterwards {
                await Task.yield()
            }
        }
    }
    
    func processSync(
        outcomes: [ThomasOutcome],
        formFieldValue: ThomasFormField.Value?,
        delegated: @Sendable @escaping @MainActor (DelegatedOutcome) -> Void
    ) {
        for outcome in outcomes {
            resolve(outcome: outcome, formFieldValue: formFieldValue, delegate: delegated)
        }
    }
    
    private func resolve(
        outcome: ThomasOutcome,
        formFieldValue: ThomasFormField.Value?,
        delegate: @Sendable @escaping @MainActor (DelegatedOutcome) -> Void
    ) {
        switch(outcome) {
        case .pagerPlayback(let outcome):
            performPagerPlayback(outcome: outcome)
        case .pagerStepNavigation(let outcome):
            performPagerNavigation(outcome: outcome, delegate: delegate)
        case .pagerJumpNavigation(let outcome):
            performPagerJumpNavigation(outcome: outcome)
        case .mediaPlayback(let outcome):
            performVideoPlayback(outcome: outcome)
        case .mediaAudio(let outcome):
            performAudioPlayback(outcome: outcome)
        case .airshipAction(let outcome):
            delegate(.runAction(outcome))
        case .stateAction(let outcome):
            self.applyStateAction(outcome.action, formFieldValue)
        case .dismiss(let outcome):
            delegate(.dismiss(outcome))
        case .form(let outcome):
            delegate(.formAction(outcome))
        case .asyncView(let outcome):
            performAsyncView(outcome: outcome)
        }
    }
    
    private func performPagerPlayback(outcome: ThomasOutcome.PagerPlaybackOutcome) {
        guard let pager = pagerState else { return }
        
        switch outcome.command {
        case .pause:
            pager.pause()
        case .resume:
            pager.resume()
        case .toggle:
            pager.togglePause()
        } 
    }
    
    private func performPagerNavigation(
        outcome: ThomasOutcome.PagerStepNavigationOutcome,
        delegate: @escaping @Sendable @MainActor (DelegatedOutcome) -> Void
    ) {
        guard let pager = pagerState else { return }
        
        let result = switch(outcome.direction) {
        case.next: pager.process(request: .next)
        case .previous: pager.process(request: .back)
        }
        
        if result != nil {
            return
        }
        
        switch (outcome.boundaryBehavior) {
        case .ignore: break
        case .dismiss:
            delegate(.dismiss(ThomasOutcome.DismissOutcome(
                cancel: false,
                identifier: ThomasButtonClickBehavior.dismiss.outcomeIdentifier)))
        case .wrap:
            let next: PageRequest = switch(outcome.direction) {
            case .next: .first
            case .previous: .last
            }
            pager.process(request: next)
        }
    }
    
    private func performPagerJumpNavigation(outcome: ThomasOutcome.PagerJumpNavigationOutcome) {
        switch(outcome.page) {
        case .start: pagerState?.process(request: .first)
        case .end: pagerState?.process(request: .last)
        }
    }
    
    private func performVideoPlayback(outcome: ThomasOutcome.MediaPlaybackOutcome) {
        guard let videoState else { return }
        
        switch outcome.command {
        case .pause: videoState.pause()
        case .play: videoState.play()
        case .toggle: videoState.togglePlay()
        }
    }
    
    private func performAudioPlayback(outcome: ThomasOutcome.MediaAudioOutcome) {
        guard let videoState else { return }
        
        switch outcome.command {
        case .mute: videoState.mute()
        case .unmute: videoState.unmute()
        case .toggle: videoState.toggleMute()
        }
    }
    
    private func performAsyncView(outcome: ThomasOutcome.AsyncViewOutcome) {
        guard let asyncViewState else { return }
        
        switch outcome.command {
        case .retry: asyncViewState.retry()
        }
    }
}

extension Array where Element == ThomasOutcome {
    var hasFormOutcome: Bool {
        contains {
            if case .form = $0 {
                return true
            }
            return false
        }
    }
    
    var hasForwardOutcome: Bool {
        contains {
            switch $0 {
            case .pagerStepNavigation(let o) where o.direction == .next: return true
            default : return false
            }
        }
    }
}

fileprivate extension ThomasOutcome {
    var shouldYieldAfterwards: Bool {
        switch self {
        case .stateAction: return true
        default : return false
        }
    }
}
