/* Copyright Airship and Contributors */

import Foundation

import AirshipCore

struct PrefrenceCenterResponse: Decodable {
    let config: PreferenceCenterConfig

    enum CodingKeys: String, CodingKey {
        case config = "form"
    }
}
