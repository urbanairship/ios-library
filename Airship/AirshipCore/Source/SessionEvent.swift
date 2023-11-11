/* Copyright Airship and Contributors */

import Foundation

struct SessionEvent: Sendable {
    let type: EventType
    let date: Date

    enum EventType: Sendable {
        case appInit
        case foreground
        case background
    }
}
