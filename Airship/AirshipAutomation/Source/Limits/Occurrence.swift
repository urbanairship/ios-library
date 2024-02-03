/* Copyright Airship and Contributors */

import Foundation

struct Occurrence: Sendable, Equatable, Hashable {
    let constraintID: String
    let timestamp: Date
}
