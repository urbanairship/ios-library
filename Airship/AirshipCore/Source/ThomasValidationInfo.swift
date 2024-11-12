/* Copyright Airship and Contributors */

import Foundation

struct ThomasValidationInfo: ThomasSerializable {
    var isRequired: Bool?
    enum CodingKeys: String, CodingKey {
        case isRequired = "required"
    }
}
