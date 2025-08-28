/* Copyright Airship and Contributors */



struct ThomasVisibilityInfo: ThomasSerializable {
    let invertWhenStateMatches: JSONPredicate
    let defaultVisibility: Bool

    private enum CodingKeys: String, CodingKey {
        case invertWhenStateMatches = "invert_when_state_matches"
        case defaultVisibility = "default"
    }
}
