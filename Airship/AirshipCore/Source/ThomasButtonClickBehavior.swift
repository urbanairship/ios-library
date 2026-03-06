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
        }
    }
}

extension Array where Element == ThomasButtonClickBehavior {
    var sortedBehaviors: [Element] {
        return self.sorted { $0.sortOrder < $1.sortOrder }
    }
}
