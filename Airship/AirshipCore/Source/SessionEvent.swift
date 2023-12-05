/* Copyright Airship and Contributors */

import Foundation

struct SessionEvent: Sendable, Equatable {
    let type: EventType
    let date: Date
    let sessionState: SessionState

    enum EventType: Sendable, Equatable {
        case foregroundInit
        case backgroundInit
        case foreground
        case background
    }
}
