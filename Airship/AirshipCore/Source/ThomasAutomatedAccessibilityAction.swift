/* Copyright Airship and Contributors */

import Foundation

struct ThomasAutomatedAccessibilityAction: ThomasSerailizable {
    let type: ActionType

    enum ActionType: String, ThomasSerailizable {
        case announce = "announce"
    }
}
