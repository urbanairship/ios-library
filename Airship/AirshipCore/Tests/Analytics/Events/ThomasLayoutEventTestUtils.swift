/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore

extension ThomasLayoutEvent {
    var bodyJSON: AirshipJSON {
        get throws {
            guard let data = self.data else {
                return AirshipJSON.null
            }

            return try AirshipJSON.wrap(EventBody(data: data))
        }
    }
}

fileprivate struct EventBody: Encodable {
    var data: (any Encodable&Sendable)?

    func encode(to encoder: Encoder) throws {
        try data?.encode(to: encoder)
    }
}

extension AirshipJSON {
    func log() {
        let string = try! self.toString()
        print("\(string)")
    }
}
