/* Copyright Airship and Contributors */



@testable import AirshipCore
@testable import AirshipAutomation

struct TestInAppEvent: InAppEvent {
    var name: EventType
    var data: (any Encodable & Sendable)?

    init(name: EventType = .customEvent, data: (Encodable & Sendable)? = nil) {
        self.name = name
        self.data = data
    }
}


