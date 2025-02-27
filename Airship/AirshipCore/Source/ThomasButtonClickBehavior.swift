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
}

extension ThomasButtonClickBehavior {
    var sortOrder: Int {
        switch self {
        case .dismiss:
            return 3
        case .cancel:
            return 3
        case .pagerPause:
            return 2
        case .pagerResume:
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
