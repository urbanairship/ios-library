/* Copyright Airship and Contributors */

import Foundation

struct ThomasEventHandler: ThomasSerializable {
    let type: EventType
    let stateActions: [ThomasStateAction]
    /// If defined, `stateActions` will be ignored.
    let outcomes: [ThomasOutcome]?

    enum EventType: String, ThomasSerializable {
        case tap
        case formInput = "form_input"
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case stateActions = "state_actions"
        case outcomes
    }
}
