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

extension ThomasAccessibleInfo {
    var resolveContentDescription: String? {
        if let contentDescription = self.contentDescription {
            return contentDescription
        }

        guard let localizedContentDescription else {
            return nil
        }

        if let refs = localizedContentDescription.refs {
            for ref in refs {
                if let string = AirshipResources.localizedString(key: ref) {
                    return string
                }
            }
        } else if let ref = localizedContentDescription.ref {
            if let string = AirshipResources.localizedString(key: ref) {
                return string
            }
        }

        return localizedContentDescription.fallback
    }
}
