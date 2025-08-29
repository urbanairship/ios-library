/* Copyright Airship and Contributors */

import Foundation

struct SessionEvent: Sendable, Equatable {
    let type: SessionEventType
    let date: Date
    let sessionState: SessionState

    enum SessionEventType: Sendable, Equatable {
        case foregroundInit
        case backgroundInit
        case foreground
        case background
    }
}
