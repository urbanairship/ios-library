/* Copyright Airship and Contributors */

import Foundation

struct ThomasValidationInfo: ThomasSerailizable {
    var isRequired: Bool?
    enum CodingKeys: String, CodingKey {
        case isRequired = "required"
    }
}
