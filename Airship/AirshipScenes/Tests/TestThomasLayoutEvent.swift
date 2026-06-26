/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore
@testable import AirshipSceneRenderer
@testable import AirshipScenes

struct TestThomasLayoutEvent: ThomasLayoutEvent {
    var name: AirshipEventType
    var data: (any Encodable & Sendable)?

    init(name: AirshipEventType = .customEvent, data: (any Encodable & Sendable)? = nil) {
        self.name = name
        self.data = data
    }
}


