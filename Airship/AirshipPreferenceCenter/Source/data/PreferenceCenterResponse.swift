/* Copyright Airship and Contributors */

import Foundation

import AirshipCore

fileprivate struct PrefrenceCenterResponse: Decodable {
    let config: PreferenceCenterConfig

    enum CodingKeys: String, CodingKey {
        case config = "form"
    }
}
