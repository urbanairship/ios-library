/* Copyright Airship and Contributors */

struct ThomasAccessibleInfo: ThomasSerializable {
    var contentDescription: String?
    var localizedContentDescription: Localized?
    var accessibilityHidden: Bool?

    struct Localized: ThomasSerializable {
        var descriptionKey: String?
        var fallbackDescription: String

        enum CodingKeys: String, CodingKey {
            case descriptionKey = "ref"
            case fallbackDescription = "fallback"
        }
    }

    enum CodingKeys: String, CodingKey {
        case contentDescription = "content_description"
        case localizedContentDescription = "localized_conten cription"
        case accessibilityHidden = "accessibility_hidden"
    }
}

extension ThomasAccessibleInfo {
    var resolveContentDescription: String? {
        if let contentDescription = self.contentDescription {
            return contentDescription
        }

        return self.localizedContentDescription?.descriptionKey?.airshipLocalizedString(
            fallback: self.localizedContentDescription?.fallbackDescription
        )
    }
}
