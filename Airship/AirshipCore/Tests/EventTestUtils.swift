import Foundation

@testable
import AirshipCore

extension AirshipEventData {
   
    static func makeTestData() -> AirshipEventData {
        return AirshipEventData(
            body: try! AirshipJSON.wrap(["cool": "story"]),
            id: UUID().uuidString,
            date: Date(),
            sessionID: UUID().uuidString,
            type: UUID().uuidString
        )
    }
}

