/* Copyright Airship and Contributors */

import Foundation

enum ThomasButtonClickBehavior: String, ThomasSerializable {
    case dismiss
    case cancel
    case pagerNext = "pager_next"
    case pagerPrevious = "pager_previous"
    case pagerNextOrDismiss = "pager_next_or_dismiss"
    case pagerNextOrFirst = "pager_next_or_first"
    case formSubmit = "form_submit"
    case formValidate = "form_validate"
    case pagerPause = "pager_pause"
    case pagerResume = "pager_resume"
    case asyncViewRetry = "async_view_retry"
    case pagerPauseToggle = "pager_toggle_pause"
    case videoPlay = "video_play"
    case videoPause = "video_pause"
    case videoTogglePlay = "video_toggle_play"
    case videoMute = "video_mute"
    case videoUnmute = "video_unmute"
    case videoToggleMute = "video_toggle_mute"
}

extension ThomasButtonClickBehavior {
    fileprivate var sortOrder: Int {
        switch self {
        case .dismiss:
            return 3
        case .cancel:
            return 3
        case .pagerPause:
            return 2
        case .pagerResume:
            return 2
        case .pagerPauseToggle:
            return 2
        case .videoPlay:
            return 2
        case .videoPause:
            return 2
        case .videoTogglePlay:
            return 2
        case .videoMute:
            return 2
        case .videoUnmute:
            return 2
        case .videoToggleMute:
            return 2
        case .pagerNextOrFirst:
            return 1
        case .pagerNextOrDismiss:
            return 1
        case .pagerNext:
            return 1
        case .pagerPrevious:
            return 1
        case .formSubmit:
            return 0
        case .formValidate:
            return -1
        case .asyncViewRetry:
            return 2
        }
    }
}

extension Array where Element == ThomasButtonClickBehavior {
    var sortedBehaviors: [Element] {
        return self.sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension ThomasButtonClickBehavior {
    var outcomeIdentifier: String {
        return "behavior_\(self.rawValue)"
    }
    
    var asOutcome: ThomasOutcome {
        return asOutcome(with: outcomeIdentifier)
    }
    
    func asOutcome(with identifier: String) -> ThomasOutcome {
        switch self {
        case .pagerNext: return .pagerStepNavigation(
            ThomasOutcome.PagerStepNavigationOutcome(
                direction: .next,
                identifier: identifier
            )
        )
        case .pagerPrevious: return .pagerStepNavigation(
            ThomasOutcome.PagerStepNavigationOutcome(
                direction: .previous,
                identifier: identifier
            )
        )
        case .pagerNextOrDismiss: return .pagerStepNavigation(
            ThomasOutcome.PagerStepNavigationOutcome(
                direction: .next,
                boundaryBehavior: .dismiss,
                identifier: identifier
            )
        )
        case .pagerNextOrFirst: return .pagerStepNavigation(
            ThomasOutcome.PagerStepNavigationOutcome(
                direction: .next,
                boundaryBehavior: .wrap,
                identifier: identifier
            )
        )
        case .pagerPause: return .pagerPlayback(.init(command: .pause, identifier: identifier))
        case .pagerResume: return .pagerPlayback(.init(command: .resume, identifier: identifier))
        case .pagerPauseToggle: return .pagerPlayback(.init(command: .toggle, identifier: identifier))
        case .videoPlay: return .mediaPlayback(.init(command: .play, identifier: identifier))
        case .videoPause: return .mediaPlayback(.init(command: .pause, identifier: identifier))
        case .videoTogglePlay: return .mediaPlayback(.init(command: .toggle, identifier: identifier))
        case .videoMute: return .mediaAudio(.init(command: .mute, identifier: identifier))
        case .videoUnmute: return .mediaAudio(.init(command: .unmute, identifier: identifier))
        case .videoToggleMute: return .mediaAudio(.init(command: .toggle, identifier: identifier))
        case .formSubmit: return .form(.init(command: .submit, identifier: identifier))
        case .formValidate: return .form(.init(command: .validate, identifier: identifier))
        case .dismiss: return .dismiss(.init(cancel: false, identifier: identifier))
        case .cancel: return .dismiss(.init(cancel: true, identifier: identifier))
        case .asyncViewRetry: return .asyncView(.init(command: .retry, identifier: identifier))
        }
    }
}
