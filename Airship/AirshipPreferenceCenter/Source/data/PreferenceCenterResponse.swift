/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
    import AirshipCore
#endif

struct PrefrenceCenterResponse: Decodable {
    let config: PreferenceCenterConfig

    enum CodingKeys: String, CodingKey {
        case config = "form"
    }
}
