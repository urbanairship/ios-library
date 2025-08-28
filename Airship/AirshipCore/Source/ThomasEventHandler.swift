/* Copyright Airship and Contributors */



struct ThomasEventHandler: ThomasSerializable {
    let type: EventType
    let stateActions: [ThomasStateAction]

    enum EventType: String, ThomasSerializable {
        case tap
        case formInput = "form_input"
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case stateActions = "state_actions"
    }
}
