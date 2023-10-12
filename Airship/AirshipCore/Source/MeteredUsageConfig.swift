/* Copyright Airship and Contributors */

import Foundation

struct MeteredUsageConfig: Codable, Equatable {
    let isEnabled: Bool?
    let initialDelay: TimeInterval?
    let interval: TimeInterval?
}
