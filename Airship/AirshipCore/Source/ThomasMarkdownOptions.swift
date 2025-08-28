/* Copyright Airship and Contributors */



struct ThomasMarkDownOptions: ThomasSerializable {
    var disabled: Bool?
    var appearance: Appearance?

    struct Appearance: ThomasSerializable {
        var anchor: Anchor?

        struct Anchor: ThomasSerializable {
            var color: ThomasColor?
            // Currently we only support underlined styles
            var styles: [ThomasTextAppearance.TextStyle]?
        }
    }
}
