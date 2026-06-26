/* Copyright Airship and Contributors */

struct ThomasAccessibleInfo: ThomasSerializable {
    var contentDescription: String?
    var localizedContentDescription: Localized?
    var accessibilityHidden: Bool?

    struct Localized: ThomasSerializable {
        var ref: String?
        var refs: [String]?
        var fallback: String
    }

    enum CodingKeys: String, CodingKey {
        case contentDescription = "content_description"
        case localizedContentDescription = "localized_content_description"
        case accessibilityHidden = "accessibility_hidden"
    }
}
