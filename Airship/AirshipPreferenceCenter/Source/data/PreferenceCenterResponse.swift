/* Copyright Airship and Contributors */

import Foundation

import AirshipCore

fileprivate struct PrefrenceCenterResponse: Decodable {
    private let config: PreferenceCenterConfig

    enum CodingKeys: String, CodingKey {
        case config = "form"
    }
}
