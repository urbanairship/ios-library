/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore
@testable import AirshipSceneRenderer

struct TestThomasLayoutEvent: ThomasLayoutEvent {
    var name: EventType
    var data: (any Encodable & Sendable)?

    init(name: EventType = .customEvent, data: (any Encodable & Sendable)? = nil) {
        self.name = name
        self.data = data
    }
}


