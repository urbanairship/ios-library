/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore

struct TestThomasLayoutEvent: ThomasLayoutEvent {
    var name: EventType
    var data: (any Encodable & Sendable)?

    init(name: EventType = .customEvent, data: (Encodable & Sendable)? = nil) {
        self.name = name
        self.data = data
    }
}


