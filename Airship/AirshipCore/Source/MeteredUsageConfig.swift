/* Copyright Airship and Contributors */

import Foundation

struct MeteredUsageConfig: Codable, Equatable {
    let isEnabled: Bool?
    let initialDelayMilliseconds: Int64?
    let intervalMilliseconds: Int64?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "enabled"
        case initialDelayMilliseconds = "initial_delay_ms"
        case intervalMilliseconds = "interval_ms"
    }
}
