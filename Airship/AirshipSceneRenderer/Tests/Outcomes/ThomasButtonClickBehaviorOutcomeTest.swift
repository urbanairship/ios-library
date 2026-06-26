/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasButtonClickBehaviorOutcomeTest {

    // MARK: Pager navigation

    @Test
    func pagerNextMapsToStepNavigationNext() {
        guard case .pagerStepNavigation(let o) = ThomasButtonClickBehavior.pagerNext.asOutcome else {
            Issue.record("Expected .pagerStepNavigation")
            return
        }
        #expect(o.direction == .next)
        #expect(o.boundaryBehavior == .ignore)
        #expect(o.identifier == ThomasButtonClickBehavior.pagerNext.outcomeIdentifier)
    }

    @Test
    func pagerPreviousMapsToStepNavigationPrevious() {
        guard case .pagerStepNavigation(let o) = ThomasButtonClickBehavior.pagerPrevious.asOutcome else {
            Issue.record("Expected .pagerStepNavigation")
            return
        }
        #expect(o.direction == .previous)
        #expect(o.boundaryBehavior == .ignore)
        #expect(o.identifier == ThomasButtonClickBehavior.pagerPrevious.outcomeIdentifier)
    }

    @Test
    func pagerNextOrDismissMapsToStepNavigationWithDismissBoundary() {
        guard case .pagerStepNavigation(let o) = ThomasButtonClickBehavior.pagerNextOrDismiss.asOutcome else {
            Issue.record("Expected .pagerStepNavigation")
            return
        }
        #expect(o.direction == .next)
        #expect(o.boundaryBehavior == .dismiss)
        #expect(o.identifier == ThomasButtonClickBehavior.pagerNextOrDismiss.outcomeIdentifier)
    }

    @Test
    func pagerNextOrFirstMapsToStepNavigationWithWrapBoundary() {
        guard case .pagerStepNavigation(let o) = ThomasButtonClickBehavior.pagerNextOrFirst.asOutcome else {
            Issue.record("Expected .pagerStepNavigation")
            return
        }
        #expect(o.direction == .next)
        #expect(o.boundaryBehavior == .wrap)
        #expect(o.identifier == ThomasButtonClickBehavior.pagerNextOrFirst.outcomeIdentifier)
    }

    // MARK: Pager playback

    @Test
    func pagerPauseMapsToPlaybackPause() {
        guard case .pagerPlayback(let o) = ThomasButtonClickBehavior.pagerPause.asOutcome else {
            Issue.record("Expected .pagerPlayback")
            return
        }
        #expect(o.command == .pause)
        #expect(o.identifier == ThomasButtonClickBehavior.pagerPause.outcomeIdentifier)
    }

    @Test
    func pagerResumeMapsToPlaybackResume() {
        guard case .pagerPlayback(let o) = ThomasButtonClickBehavior.pagerResume.asOutcome else {
            Issue.record("Expected .pagerPlayback")
            return
        }
        #expect(o.command == .resume)
        #expect(o.identifier == ThomasButtonClickBehavior.pagerResume.outcomeIdentifier)
    }

    @Test
    func pagerPauseToggleMapsToPlaybackToggle() {
        guard case .pagerPlayback(let o) = ThomasButtonClickBehavior.pagerPauseToggle.asOutcome else {
            Issue.record("Expected .pagerPlayback")
            return
        }
        #expect(o.command == .toggle)
        #expect(o.identifier == ThomasButtonClickBehavior.pagerPauseToggle.outcomeIdentifier)
    }

    // MARK: Media playback

    @Test
    func videoPlayMapsToMediaPlaybackPlay() {
        guard case .mediaPlayback(let o) = ThomasButtonClickBehavior.videoPlay.asOutcome else {
            Issue.record("Expected .mediaPlayback")
            return
        }
        #expect(o.command == .play)
        #expect(o.identifier == ThomasButtonClickBehavior.videoPlay.outcomeIdentifier)
    }

    @Test
    func videoPauseMapsToMediaPlaybackPause() {
        guard case .mediaPlayback(let o) = ThomasButtonClickBehavior.videoPause.asOutcome else {
            Issue.record("Expected .mediaPlayback")
            return
        }
        #expect(o.command == .pause)
        #expect(o.identifier == ThomasButtonClickBehavior.videoPause.outcomeIdentifier)
    }

    @Test
    func videoTogglePlayMapsToMediaPlaybackToggle() {
        guard case .mediaPlayback(let o) = ThomasButtonClickBehavior.videoTogglePlay.asOutcome else {
            Issue.record("Expected .mediaPlayback")
            return
        }
        #expect(o.command == .toggle)
        #expect(o.identifier == ThomasButtonClickBehavior.videoTogglePlay.outcomeIdentifier)
    }

    // MARK: Media audio

    @Test
    func videoMuteMapsToMediaAudioMute() {
        guard case .mediaAudio(let o) = ThomasButtonClickBehavior.videoMute.asOutcome else {
            Issue.record("Expected .mediaAudio")
            return
        }
        #expect(o.command == .mute)
        #expect(o.identifier == ThomasButtonClickBehavior.videoMute.outcomeIdentifier)
    }

    @Test
    func videoUnmuteMapsToMediaAudioUnmute() {
        guard case .mediaAudio(let o) = ThomasButtonClickBehavior.videoUnmute.asOutcome else {
            Issue.record("Expected .mediaAudio")
            return
        }
        #expect(o.command == .unmute)
        #expect(o.identifier == ThomasButtonClickBehavior.videoUnmute.outcomeIdentifier)
    }

    @Test
    func videoToggleMuteMapsToMediaAudioToggle() {
        guard case .mediaAudio(let o) = ThomasButtonClickBehavior.videoToggleMute.asOutcome else {
            Issue.record("Expected .mediaAudio")
            return
        }
        #expect(o.command == .toggle)
        #expect(o.identifier == ThomasButtonClickBehavior.videoToggleMute.outcomeIdentifier)
    }

    // MARK: Form

    @Test
    func formSubmitMapsToFormSubmit() {
        guard case .form(let o) = ThomasButtonClickBehavior.formSubmit.asOutcome else {
            Issue.record("Expected .form")
            return
        }
        #expect(o.command == .submit)
        #expect(o.identifier == ThomasButtonClickBehavior.formSubmit.outcomeIdentifier)
    }

    @Test
    func formValidateMapsToFormValidate() {
        guard case .form(let o) = ThomasButtonClickBehavior.formValidate.asOutcome else {
            Issue.record("Expected .form")
            return
        }
        #expect(o.command == .validate)
        #expect(o.identifier == ThomasButtonClickBehavior.formValidate.outcomeIdentifier)
    }

    // MARK: Dismiss

    @Test
    func dismissMapsToNonCancelDismiss() {
        guard case .dismiss(let o) = ThomasButtonClickBehavior.dismiss.asOutcome else {
            Issue.record("Expected .dismiss")
            return
        }
        #expect(o.cancel == false)
        #expect(o.identifier == ThomasButtonClickBehavior.dismiss.outcomeIdentifier)
    }

    @Test
    func cancelMapsToCancelDismiss() {
        guard case .dismiss(let o) = ThomasButtonClickBehavior.cancel.asOutcome else {
            Issue.record("Expected .dismiss")
            return
        }
        #expect(o.cancel == true)
        #expect(o.identifier == ThomasButtonClickBehavior.cancel.outcomeIdentifier)
    }

    // MARK: Async view

    @Test
    func asyncViewRetryMapsToAsyncViewRetry() {
        guard case .asyncView(let o) = ThomasButtonClickBehavior.asyncViewRetry.asOutcome else {
            Issue.record("Expected .asyncView")
            return
        }
        #expect(o.command == .retry)
        #expect(o.identifier == ThomasButtonClickBehavior.asyncViewRetry.outcomeIdentifier)
    }

    // MARK: Outcome identifier contract

    @Test("outcomeIdentifier is behavior_ plus schema raw string", arguments: [
        (ThomasButtonClickBehavior.dismiss, "behavior_dismiss"),
        (.cancel, "behavior_cancel"),
        (.pagerNext, "behavior_pager_next"),
        (.pagerPrevious, "behavior_pager_previous"),
        (.pagerNextOrDismiss, "behavior_pager_next_or_dismiss"),
        (.pagerNextOrFirst, "behavior_pager_next_or_first"),
        (.formSubmit, "behavior_form_submit"),
        (.formValidate, "behavior_form_validate"),
        (.pagerPause, "behavior_pager_pause"),
        (.pagerResume, "behavior_pager_resume"),
        (.asyncViewRetry, "behavior_async_view_retry"),
        (.pagerPauseToggle, "behavior_pager_toggle_pause"),
        (.videoPlay, "behavior_video_play"),
        (.videoPause, "behavior_video_pause"),
        (.videoTogglePlay, "behavior_video_toggle_play"),
        (.videoMute, "behavior_video_mute"),
        (.videoUnmute, "behavior_video_unmute"),
        (.videoToggleMute, "behavior_video_toggle_mute"),
    ] as [(ThomasButtonClickBehavior, String)])
    func outcomeIdentifierUsesConcreteString(behavior: ThomasButtonClickBehavior, expected: String) {
        #expect(behavior.outcomeIdentifier == expected)
    }

    // MARK: Exhaustiveness

    @Test("Every behavior produces a non-nil outcome", arguments: ThomasButtonClickBehaviorParsingTest.allBehaviors)
    func everyBehaviorProducesAnOutcome(behavior: ThomasButtonClickBehavior) {
        // Calling .asOutcome must not crash; the switch is exhaustive by construction,
        // so this test acts as a compile-time + runtime exhaustiveness guard.
        _ = behavior.asOutcome
    }
}
