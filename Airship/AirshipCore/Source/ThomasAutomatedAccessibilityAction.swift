/* Copyright Airship and Contributors */



struct ThomasAutomatedAccessibilityAction: ThomasSerializable {
    let type: ActionType

    enum ActionType: String, ThomasSerializable {
        case announce = "announce"
    }
}
