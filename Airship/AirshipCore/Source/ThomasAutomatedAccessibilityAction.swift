/* Copyright Airship and Contributors */

import Foundation

struct ThomasAutomatedAccessibilityAction: ThomasSerializable {
    let type: ActionType

    enum ActionType: String, ThomasSerializable {
        case announce = "announce"
    }
}
