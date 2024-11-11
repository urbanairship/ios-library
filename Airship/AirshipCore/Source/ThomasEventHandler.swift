/* Copyright Airship and Contributors */

import Foundation

struct ThomasEventHandler: ThomasSerailizable {
    let type: EventType
    let stateActions: [ThomasStateAction]

    enum EventType: String, ThomasSerailizable {
        case tap
        case formInput = "form_input"
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case stateActions = "state_actions"
    }
}
